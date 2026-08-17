extends GutTest
## Story 005 验收测试：AI 干跑评估接口（GameStateSnapshot 不可变纯计算）。
##
## 覆盖 AC-001（evaluate_effect 与 get_accumulated_value 一致 + floor 取整）、
## AC-002（simulate_chain 返回触发链）、AC-003（性能预算，宽松阈值）
## + QA Edge cases（快照不可变、无连锁时 chain 只含根、would_overflow、is_overkill/is_overheal）。
##
## [b]简化模型说明[/b]：本 Story 评估逻辑是确定性简化（伤害/治疗 = effect_value × binding_multiplier
## floor 取整），完整效果结算在 CardEffectEngine 接线后展开。测试针对简化模型的确定性契约。
##
## [b]性能断言[/b]：QA 计划缺口 #3 要求性能断言设宽松阈值（无头/CI 波动）——
## AC-003 用 < 100ms（而非 GDD 的 30ms）作宽松门槛，锁定无对象泄漏导致的退化。

const EvaluatorClass := preload("res://src/feature/card_effect_engine/card_effect_evaluator.gd")
const SnapshotClass := preload("res://src/feature/card_effect_engine/game_state_snapshot.gd")
const EvaluationClass := preload("res://src/feature/card_effect_engine/effect_evaluation.gd")


# === 测试辅助 =====================================================================

func _make_snapshot() -> RefCounted:
	## 目标 1：HP=5/max=10，绑定 ×1.0；目标 2：HP=3/max=8，绑定 ×1.5
	var chars := {
		1: {"hp": 5, "max_hp": 10, "atk": 0, "statuses": [], "binding_multiplier": 1.0},
		2: {"hp": 3, "max_hp": 8, "atk": 0, "statuses": [], "binding_multiplier": 1.5},
	}
	return SnapshotClass.build(chars)


# ============================================================================
# AC-001：evaluate_effect 与 get_accumulated_value 一致 + floor 取整
# ============================================================================

func test_ac001_damage_matches_effective_value_no_binding() -> void:
	var evaluator: RefCounted = EvaluatorClass.new()
	var snapshot := _make_snapshot()
	var card := {"effect_type": &"damage", "effect_value": 3, "card_id": &"talisman_damage_3"}

	var eval: RefCounted = evaluator.evaluate_effect(card, 1, snapshot)
	assert_eq(eval.damage, 3, "无绑定 damage=3 → floor(3×1.0)=3")


func test_ac001_damage_floor_with_binding_multiplier() -> void:
	var evaluator: RefCounted = EvaluatorClass.new()
	var snapshot := _make_snapshot()
	var card := {"effect_type": &"damage", "effect_value": 3, "card_id": &"talisman_damage_3"}

	var eval: RefCounted = evaluator.evaluate_effect(card, 2, snapshot)  # 目标 2 绑定 ×1.5
	assert_eq(eval.damage, 4, "本命绑定 ×1.5 → floor(3×1.5)=4")


func test_ac001_evaluation_does_not_mutate_snapshot() -> void:
	var evaluator: RefCounted = EvaluatorClass.new()
	var snapshot := _make_snapshot()
	var card := {"effect_type": &"damage", "effect_value": 3, "card_id": &"x"}

	evaluator.evaluate_effect(card, 1, snapshot)
	assert_eq(snapshot.get_hp(1), 5, "评估后目标 HP 不变（不可变快照）")
	assert_eq(snapshot.get_binding_multiplier(2), 1.5, "评估后绑定乘数不变")


# ============================================================================
# is_overkill / is_overheal
# ============================================================================

func test_damage_overkill_detected() -> void:
	var evaluator: RefCounted = EvaluatorClass.new()
	var snapshot := _make_snapshot()
	var card := {"effect_type": &"damage", "effect_value": 10, "card_id": &"x"}
	var eval: RefCounted = evaluator.evaluate_effect(card, 1, snapshot)  # 目标 1 HP=5
	assert_true(eval.is_overkill, "伤害 10 > HP 5 应溢出")


func test_heal_overheal_detected() -> void:
	var evaluator: RefCounted = EvaluatorClass.new()
	var snapshot := _make_snapshot()
	var card := {"effect_type": &"heal", "effect_value": 10, "card_id": &"x"}
	var eval: RefCounted = evaluator.evaluate_effect(card, 1, snapshot)  # 目标 1 HP=5/max=10
	assert_true(eval.is_overheal, "治疗 10 → 5+10>10 应溢出")


# ============================================================================
# AC-002：simulate_chain 返回触发链
# ============================================================================

func test_ac002_simulate_chain_contains_root_effect() -> void:
	var evaluator: RefCounted = EvaluatorClass.new()
	var snapshot := _make_snapshot()
	var card := {"effect_type": &"damage", "effect_value": 3, "card_id": &"talisman_damage_3"}

	var preview: Dictionary = evaluator.simulate_chain(card, 1, snapshot, 5)
	assert_eq(preview["chain"].size(), 1, "无连锁时 chain 只含根效果")
	assert_eq(preview["would_overflow"], false, "深度 1 不溢出")
	assert_eq(preview["chain"][0]["source"], &"talisman_damage_3", "根效果来源正确")
	assert_eq(preview["chain"][0]["step"], 1, "根效果 step=1")


# ============================================================================
# 效果类型标签（get_effect_categories）
# ============================================================================

func test_get_effect_categories_damage() -> void:
	var evaluator: RefCounted = EvaluatorClass.new()
	var cat: Array = evaluator.get_effect_categories({"effect_type": &"damage", "effect_value": 3})
	assert_eq(cat.size(), 1, "单一类型标签")
	assert_eq(cat[0], EvaluatorClass.EffectCategory.DAMAGE, "damage 应归类 DAMAGE")


func test_get_effect_categories_unevaluable_default() -> void:
	var evaluator: RefCounted = EvaluatorClass.new()
	var cat: Array = evaluator.get_effect_categories({"effect_type": &"steal_unknown"})
	assert_eq(cat[0], EvaluatorClass.EffectCategory.UNEVALUABLE, "未知类型应 UNEVALUABLE")


# ============================================================================
# BUFF/DEBUFF/CONTROL 分支（stat_changes / statuses_applied 契约）
# ============================================================================

func test_buff_produces_positive_stat_change() -> void:
	var evaluator: RefCounted = EvaluatorClass.new()
	var snapshot := _make_snapshot()
	var card := {"effect_type": &"buff", "effect_value": 2, "card_id": &"x"}
	var eval: RefCounted = evaluator.evaluate_effect(card, 1, snapshot)
	assert_eq(eval.stat_changes.get("ATK"), 2, "增益 → ATK +2")
	assert_eq(eval.damage, 0, "增益无伤害")


func test_debuff_produces_negative_stat_change() -> void:
	var evaluator: RefCounted = EvaluatorClass.new()
	var snapshot := _make_snapshot()
	var card := {"effect_type": &"debuff", "effect_value": 2, "card_id": &"x"}
	var eval: RefCounted = evaluator.evaluate_effect(card, 2, snapshot)  # 绑定 ×1.5 → floor(2×1.5)=3
	assert_eq(eval.stat_changes.get("ATK"), -3, "减益 → ATK -3（含绑定乘数）")


func test_control_applies_status_id() -> void:
	var evaluator: RefCounted = EvaluatorClass.new()
	var snapshot := _make_snapshot()
	var card := {"effect_type": &"control_freeze", "effect_value": 0, "card_id": &"x"}
	var eval: RefCounted = evaluator.evaluate_effect(card, 1, snapshot)
	assert_eq(eval.statuses_applied.size(), 1, "控制 → 施加 1 状态")
	assert_eq(eval.statuses_applied[0], &"control_freeze", "状态模板 ID 正确")


# ============================================================================
# AC-003 单点性能子断言（QA 缺口 #3 放宽阈值）
# ============================================================================

func test_ac003_single_evaluate_under_loose_microsecond_budget() -> void:
	## 单次 evaluate_effect < 100μs（GDD 指标），无头/CI 波动放宽为 < 1ms（1000μs）锁定无退化。
	var evaluator: RefCounted = EvaluatorClass.new()
	var snapshot := _make_snapshot()
	var card := {"effect_type": &"damage", "effect_value": 3, "card_id": &"x"}

	# 预热一次，排除 JIT/缓存首次成本
	evaluator.evaluate_effect(card, 1, snapshot)

	var start: int = Time.get_ticks_usec()
	for i in range(50):
		evaluator.evaluate_effect(card, 1, snapshot)
	var avg_us: float = (Time.get_ticks_usec() - start) / 50.0

	assert_lt(avg_us, 1000.0, "单次评估应 < 1000μs（宽松阈值），实测 %.1fμs" % avg_us)


func test_ac003_simulate_chain_depth5_under_loose_budget() -> void:
	## simulate_chain 深度 5 < 500μs（GDD），放宽为 < 5ms 锁定无退化。
	var evaluator: RefCounted = EvaluatorClass.new()
	var snapshot := _make_snapshot()
	var card := {"effect_type": &"damage", "effect_value": 3, "card_id": &"x"}

	# 预热一次
	evaluator.simulate_chain(card, 1, snapshot, 5)

	var start: int = Time.get_ticks_usec()
	for i in range(50):
		evaluator.simulate_chain(card, 1, snapshot, 5)
	var avg_us: float = (Time.get_ticks_usec() - start) / 50.0

	assert_lt(avg_us, 5000.0, "simulate_chain 深度 5 应 < 5000μs（宽松阈值），实测 %.1fμs" % avg_us)


# ============================================================================
# evaluate_effect_probabilistic 单结果
# ============================================================================

func test_evaluate_probabilistic_single_deterministic_outcome() -> void:
	var evaluator: RefCounted = EvaluatorClass.new()
	var snapshot := _make_snapshot()
	var card := {"effect_type": &"damage", "effect_value": 3, "card_id": &"x"}
	var outcomes: Array = evaluator.evaluate_effect_probabilistic(card, 1, snapshot)
	assert_eq(outcomes.size(), 1, "非 RNG 效果单结果")
	assert_eq(outcomes[0]["probability"], 1.0, "确定性概率 1.0")
	assert_eq(outcomes[0]["outcome"].damage, 3, "结果正确")


# ============================================================================
# 快照只读（getter 深拷贝）
# ============================================================================

func test_snapshot_getter_returns_deep_copy() -> void:
	var snapshot := _make_snapshot()
	var char_data: Dictionary = snapshot.get_character(1)
	char_data["hp"] = 999  # 修改返回的拷贝不应污染快照
	assert_eq(snapshot.get_hp(1), 5, "getter 返回深拷贝，修改不影响快照")


func test_snapshot_unknown_character_returns_empty() -> void:
	var snapshot := _make_snapshot()
	assert_eq(snapshot.get_character(99), {}, "未知角色返回空字典")
	assert_eq(snapshot.get_hp(99), 0, "未知角色 HP 为 0")
	assert_eq(snapshot.get_binding_multiplier(99), 1.0, "未知角色绑定乘数默认 1.0")


# ============================================================================
# AC-003：性能预算（宽松阈值——QA 缺口 #3）
# ============================================================================

func test_ac003_evaluate_288_calls_under_loose_budget() -> void:
	## 288 次（6敌 ×8技 ×6目标）评估——宽松阈值 100ms（GDD 30ms，无头/CI 波动放宽）。
	var evaluator: RefCounted = EvaluatorClass.new()
	var snapshot := _make_snapshot()
	var card := {"effect_type": &"damage", "effect_value": 3, "card_id": &"x"}

	var start: int = Time.get_ticks_usec()
	var total: int = 0
	for i in range(288):
		var eval: RefCounted = evaluator.evaluate_effect(card, 1, snapshot)
		total += eval.damage
	var elapsed_ms: float = (Time.get_ticks_usec() - start) / 1000.0

	assert_lt(elapsed_ms, 100.0, "288 次评估应 < 100ms（宽松阈值），实测 %.2fms" % elapsed_ms)
	assert_eq(total, 288 * 3, "评估结果确定性——288×3=864")
