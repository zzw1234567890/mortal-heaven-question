extends GutTest
## 效果词表验收测试（DEBT-CBT-018-8）——[CardEffectEvaluator] 的新增类别。[br]
## [br][b]锁定的四件事[/b]：[br]
##   1. [b]解析[/b]：[code]effect_type[/code] 字符串 → [code]EffectCategory[/code]，具体前缀必须先于泛前缀
##      （[code]damage_reduce[/code] 不能被 [code]damage[/code] 吞掉、[code]heal_bonus[/code] 不能被 [code]heal[/code] 吞掉）；[br]
##   2. [b]分发[/b]：各类别写到各自字段，且 [code]damage_reduce[/code] 与 [code]buff[/code] 严格区分
##      （减伤[b]绝不写[/b] [code]stat_changes.ATK[/code]）；[br]
##   3. [b]边界[/b]：0% / 100% / 越界 / 负值 / 上限 60%，以及概率 0、1、越界；
##   4. [b]未知类型[/b]落 [code]UNEVALUABLE[/code] 且返回空评估——[b]不静默当 buff[/b]。
##
## 纯单元测试：[code]EvaluatorClass.new()[/code]，不触碰 Autoload/文件系统。

const EvaluatorClass: GDScript = preload("res://src/feature/card_effect_engine/card_effect_evaluator.gd")
const SnapshotClass: GDScript = preload("res://src/feature/card_effect_engine/game_state_snapshot.gd")

var evaluator: RefCounted = null


func before_each() -> void:
	evaluator = EvaluatorClass.new()


## 目标 1：HP 5/10、ATK 4、绑定 ×1.0；目标 2：HP 3/8、ATK 2、绑定 ×1.5。
func _make_snapshot() -> RefCounted:
	return SnapshotClass.build({
		1: {"hp": 5, "max_hp": 10, "atk": 4, "statuses": [], "binding_multiplier": 1.0},
		2: {"hp": 3, "max_hp": 8, "atk": 2, "statuses": [], "binding_multiplier": 1.5},
	})


func _category(effect_type: StringName) -> int:
	return int(evaluator.get_effect_categories({"effect_type": effect_type})[0])


# === 1. 解析：新增类别归类 =========================================================

func test_new_categories_map_to_own_enum_values() -> void:
	assert_eq(_category(&"damage_reduce"), EvaluatorClass.EffectCategory.DAMAGE_REDUCE)
	assert_eq(_category(&"damage_multiplier"), EvaluatorClass.EffectCategory.DAMAGE_MULTIPLIER)
	assert_eq(_category(&"damage_bonus"), EvaluatorClass.EffectCategory.DAMAGE_BONUS)
	assert_eq(_category(&"heal_bonus"), EvaluatorClass.EffectCategory.HEAL_BONUS)
	assert_eq(_category(&"formation_attune"), EvaluatorClass.EffectCategory.FORMATION_ATTUNE)


func test_specific_prefixes_win_over_generic_prefixes() -> void:
	# 顺序即语义：damage_reduce 若不先判会被 "damage" 吞成 DAMAGE（打出伤害），
	# heal_bonus 若不先判会被 "heal" 吞成 HEAL（直接治疗）——两者数值口径完全不同。
	assert_ne(_category(&"damage_reduce"), EvaluatorClass.EffectCategory.DAMAGE,
		"damage_reduce 不能被 damage 前缀吞掉")
	assert_ne(_category(&"damage_multiplier"), EvaluatorClass.EffectCategory.DAMAGE,
		"damage_multiplier 不能被 damage 前缀吞掉")
	assert_ne(_category(&"heal_bonus"), EvaluatorClass.EffectCategory.HEAL,
		"heal_bonus 不能被 heal 前缀吞掉")
	assert_eq(_category(&"damage"), EvaluatorClass.EffectCategory.DAMAGE, "裸 damage 仍归 DAMAGE")


func test_chinese_alias_damage_reduction_classified_before_damage() -> void:
	# 「受到伤害降低」含「伤害」二字——中文分支同样必须先判减伤。
	assert_eq(_category(&"受到伤害降低"), EvaluatorClass.EffectCategory.DAMAGE_REDUCE)
	assert_eq(_category(&"减伤"), EvaluatorClass.EffectCategory.DAMAGE_REDUCE)


# === 2. 分发：damage_reduce 与 buff 严格区分 =======================================

func test_damage_reduce_writes_reduction_fields_only() -> void:
	var card := {"effect_type": &"damage_reduce", "effect_value": 10, "card_id": &"x"}
	var eval: RefCounted = evaluator.evaluate_effect(card, 1, _make_snapshot())
	assert_eq(eval.damage_reduction_pct, 10.0, "减伤 10%")
	assert_almost_eq(eval.damage_reduction_multiplier, 0.9, 0.0001, "受击伤害应 ×0.9")
	assert_eq(eval.stat_changes, {}, "减伤绝不写 stat_changes（否则会被当成 ATK 增益）")
	assert_eq(eval.damage, 0, "减伤不产生伤害")
	assert_eq(eval.healing, 0, "减伤不产生治疗")


func test_buff_still_writes_atk_and_no_reduction() -> void:
	var card := {"effect_type": &"buff", "effect_value": 2, "card_id": &"x"}
	var eval: RefCounted = evaluator.evaluate_effect(card, 1, _make_snapshot())
	assert_eq(eval.stat_changes.get("ATK"), 2, "buff 仍为 ATK 增量")
	assert_eq(eval.damage_reduction_pct, 0.0, "buff 不产生减伤")


func test_damage_bonus_heal_bonus_formation_attune_dispatch() -> void:
	var snapshot := _make_snapshot()
	var bonus: RefCounted = evaluator.evaluate_effect(
		{"effect_type": &"damage_bonus", "effect_value": 1}, 1, snapshot)
	var heal_bonus: RefCounted = evaluator.evaluate_effect(
		{"effect_type": &"heal_bonus", "effect_value": 2}, 1, snapshot)
	var attune: RefCounted = evaluator.evaluate_effect(
		{"effect_type": &"formation_attune", "effect_value": 2}, 1, snapshot)
	assert_eq(bonus.damage_bonus, 1, "首击伤害 +1")
	assert_eq(bonus.stat_changes, {}, "伤害加成不是 ATK 面板增益")
	assert_eq(heal_bonus.healing_bonus, 2, "丹药额外回复 2")
	assert_eq(heal_bonus.healing, 0, "额外治疗不是一次性治疗")
	assert_eq(attune.formation_attunement, 2, "视为 2 人满足阵法条件")
	assert_eq(attune.stat_changes, {}, "阵法亲和不改变属性")


# === 3. 边界：0% / 100% / 越界 =====================================================

func test_damage_reduce_zero_percent_is_noop() -> void:
	var eval: RefCounted = evaluator.evaluate_effect(
		{"effect_type": &"damage_reduce", "effect_value": 0}, 1, _make_snapshot())
	assert_eq(eval.damage_reduction_pct, 0.0)
	assert_almost_eq(eval.damage_reduction_multiplier, 1.0, 0.0001, "0% 减伤 → ×1.0")


func test_damage_reduce_hundred_percent_clamped_to_cap() -> void:
	var eval: RefCounted = evaluator.evaluate_effect(
		{"effect_type": &"damage_reduce", "effect_value": 100}, 1, _make_snapshot())
	assert_eq(eval.damage_reduction_pct, 60.0, "100% 应钳制到 GDD 上限 60%")
	assert_almost_eq(eval.damage_reduction_multiplier, 0.4, 0.0001)


func test_damage_reduce_negative_clamped_to_zero() -> void:
	var eval: RefCounted = evaluator.evaluate_effect(
		{"effect_type": &"damage_reduce", "effect_value": -5}, 1, _make_snapshot())
	assert_eq(eval.damage_reduction_pct, 0.0, "负减伤钳制为 0（不会变成增伤）")
	assert_almost_eq(eval.damage_reduction_multiplier, 1.0, 0.0001)


func test_combine_damage_reduction_stacks_multiplicatively() -> void:
	var none: Dictionary = EvaluatorClass.combine_damage_reduction([])
	assert_almost_eq(none["multiplier"], 1.0, 0.0001, "无减伤 → ×1.0")
	var two: Dictionary = EvaluatorClass.combine_damage_reduction([10, 15])
	assert_almost_eq(two["multiplier"], 0.9 * 0.85, 0.0001, "叠加按乘算 0.9×0.85")
	assert_almost_eq(two["reduction_pct"], 23.5, 0.0001, "等效减伤 23.5%")


func test_combine_damage_reduction_caps_at_sixty_percent() -> void:
	var many: Dictionary = EvaluatorClass.combine_damage_reduction([30, 30, 30, 30])
	assert_almost_eq(many["multiplier"], 0.4, 0.0001, "叠加超限应封顶 60% → ×0.4")
	assert_almost_eq(many["reduction_pct"], 60.0, 0.0001)


# === 4. 未知类型 → UNEVALUABLE（不静默当 buff） ====================================

func test_unknown_effect_type_is_unevaluable_and_empty() -> void:
	var card := {"effect_type": &"steal_soul", "effect_value": 5, "card_id": &"x"}
	var eval: RefCounted = evaluator.evaluate_effect(card, 1, _make_snapshot())
	assert_eq(_category(&"steal_soul"), EvaluatorClass.EffectCategory.UNEVALUABLE)
	assert_eq(eval.stat_changes, {}, "未知类型不得静默降级成 buff（ATK 增量）")
	assert_eq(eval.damage, 0)
	assert_eq(eval.healing, 0)
	assert_eq(eval.damage_reduction_pct, 0.0)
	assert_eq(eval.statuses_applied.size(), 0)


func test_empty_effect_type_is_unevaluable() -> void:
	# 空 effect_type 是「尚未建模」的显式标记——必须落 UNEVALUABLE，不能猜成任何类别。
	assert_eq(_category(&""), EvaluatorClass.EffectCategory.UNEVALUABLE)


# === 5. damage_multiplier 分支 ====================================================

func test_damage_multiplier_uses_attacker_atk() -> void:
	var card := {"effect_type": &"damage_multiplier", "effect_value": 150, "attacker_atk": 4}
	var eval: RefCounted = evaluator.evaluate_effect(card, 1, _make_snapshot())
	assert_almost_eq(eval.damage_multiplier, 1.5, 0.0001)
	assert_eq(eval.damage, 6, "floor(4 × 1.5) = 6")
	assert_true(eval.is_overkill, "6 > 目标 HP 5 → 溢出")


func test_damage_multiplier_falls_back_to_snapshot_atk() -> void:
	var card := {"effect_type": &"damage_multiplier", "effect_value": 100}
	var eval: RefCounted = evaluator.evaluate_effect(card, 2, _make_snapshot())
	assert_eq(eval.damage, 2, "未传 attacker_atk 时回退快照 ATK=2，×1.0")


func test_damage_multiplier_zero_percent_deals_no_damage() -> void:
	var card := {"effect_type": &"damage_multiplier", "effect_value": 0, "attacker_atk": 4}
	var eval: RefCounted = evaluator.evaluate_effect(card, 1, _make_snapshot())
	assert_eq(eval.damage, 0, "×0.0 不应造成伤害")
	assert_almost_eq(eval.damage_multiplier, 0.0, 0.0001)


# === 6. 触发概率分布 ===============================================================

func test_trigger_chance_absent_yields_single_outcome() -> void:
	var card := {"effect_type": &"control_confuse", "effect_value": 1}
	var outcomes: Array = evaluator.evaluate_effect_probabilistic(card, 1, _make_snapshot())
	assert_eq(outcomes.size(), 1, "未声明概率 → 单一确定性结果")
	assert_eq(outcomes[0]["probability"], 1.0)


func test_trigger_chance_splits_into_hit_and_miss() -> void:
	var card := {"effect_type": &"control_confuse", "effect_value": 1, "trigger_chance": 0.3}
	var outcomes: Array = evaluator.evaluate_effect_probabilistic(card, 1, _make_snapshot())
	assert_eq(outcomes.size(), 2, "30% 概率 → 命中 + 落空两个分支")
	assert_almost_eq(outcomes[0]["probability"], 0.3, 0.0001, "命中概率 0.3")
	assert_almost_eq(outcomes[1]["probability"], 0.7, 0.0001, "落空概率 0.7")
	assert_eq(outcomes[0]["outcome"].statuses_applied.size(), 1, "命中分支带状态")
	assert_eq(outcomes[1]["outcome"].statuses_applied.size(), 0, "落空分支为空评估")


func test_trigger_chance_full_or_out_of_range_yields_single_outcome() -> void:
	var full: Array = evaluator.evaluate_effect_probabilistic(
		{"effect_type": &"control_freeze", "effect_value": 1, "trigger_chance": 1.0}, 1, _make_snapshot())
	var over: Array = evaluator.evaluate_effect_probabilistic(
		{"effect_type": &"control_freeze", "effect_value": 1, "trigger_chance": 1.7}, 1, _make_snapshot())
	assert_eq(full.size(), 1, "100% 概率 → 单一结果")
	assert_eq(over.size(), 1, "越界概率钳制为 100% → 单一结果")


func test_native_trigger_chance_overrides_base_chance() -> void:
	var card := {
		"effect_type": &"control_confuse", "effect_value": 1,
		"trigger_chance": 0.3, "native_trigger_chance": 0.5, "is_native": true,
	}
	var outcomes: Array = evaluator.evaluate_effect_probabilistic(card, 1, _make_snapshot())
	assert_almost_eq(outcomes[0]["probability"], 0.5, 0.0001, "本命 50% 覆盖基础 30%")


# === 7. 本命数值覆盖（非线性加成不走 ×1.5） ========================================

func test_native_effect_value_overrides_binding_multiplier() -> void:
	# 目标 2 绑定 ×1.5：10% 减伤若乘 1.5 会变成 15%——恰好与 GDD 的本命值巧合，
	# 但 15%→20% 的幻花迷踪步会被算成 22.5%。故本命值取原值、跳过绑定倍率。
	var card := {
		"effect_type": &"damage_reduce", "effect_value": 10,
		"native_effect_value": 15, "is_native": true,
	}
	var eval: RefCounted = evaluator.evaluate_effect(card, 2, _make_snapshot())
	assert_eq(eval.damage_reduction_pct, 15.0, "本命值 15% 原值采用，不做 ×1.5")


func test_non_native_uses_base_value_and_multiplier() -> void:
	var card := {"effect_type": &"damage", "effect_value": 10, "native_effect_value": 15}
	var eval: RefCounted = evaluator.evaluate_effect(card, 2, _make_snapshot())
	assert_eq(eval.damage, 15, "非本命仍按 10 × 1.5 = 15（旧行为不变）")
