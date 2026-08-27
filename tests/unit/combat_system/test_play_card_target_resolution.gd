extends GutTest
## Story 003 验收测试：play_card 出牌 + 目标解析 + 自动推进调度。
##
## 覆盖 AC-001 到 AC-012（12 条 AC）。
## 测试策略：
##   - CS_SCRIPT.new() 构造 CombatSystem 实例
##   - set_auto_advance(false) + set_scene_change(false) 禁用帧依赖
##   - set_battle_active(true) 桩进入战斗
##   - 卡牌实例用 Dictionary 桩 + set_card_instances / set_hand 注入
##   - CostSystem 为真实 Autoload（init_for_battle 设置费用上限）
##   - validate_targets_cb / resolve_cb 用 Callable 注入桩
##   - RealmSystem 为真实 Autoload（已注册）
##   - 伤害计算直接调用 calculate_damage 纯函数
##
## 设计文档来源：ADR-0008 §出牌结算流程 + GDD §8 境界压制规则
## Story 来源：production/epics/combat-system/story-003-play-card-target-resolution.md

const CS_SCRIPT := preload("res://src/feature/combat_system.gd")

var cs: Node = null


func before_each() -> void:
	cs = CS_SCRIPT.new()
	cs.call("set_auto_advance", false)
	cs.call("set_scene_change", false)
	cs.call("set_battle_active", true)
	cs.call("set_rng_seed", 42)


func after_each() -> void:
	if cs != null:
		cs.free()
		cs = null


# === 辅助 ================================================================

## 构造测试用卡牌 Dictionary 桩。
func _make_card(card_id: int, cost: int) -> Dictionary:
	return {"card_instance_id": card_id, "cost": cost, "template_id": "test_card"}


## 注入手牌 + 卡牌实例缓存。
func _setup_hand(cards: Array) -> void:
	var instances: Dictionary = {}
	for card in cards:
		instances[card["card_instance_id"]] = card
	cs.call("set_card_instances", instances)
	cs.call("set_hand", cards.duplicate())


# ============================================================================
# AC-001：非 PLAY 阶段调用 play_card 拒绝
# ============================================================================

func test_ac001_play_card_rejected_outside_play() -> void:
	# 当前 PREPARATION(0)，非 PLAY(2)
	var ok: bool = cs.call("play_card", 1, [])
	assert_false(ok, "非 PLAY 阶段 play_card 返回 false")
	assert_eq(cs.call("get_current_phase"), 0, "阶段不变")


func test_ac001_play_card_in_play_succeeds() -> void:
	# 推进到 PLAY(2)
	cs.call("advance_phase")  # 0→1
	cs.call("advance_phase")  # 1→2
	# 注入 0 费卡牌
	_setup_hand([_make_card(1, 0)])
	var ok: bool = cs.call("play_card", 1, [])
	assert_true(ok, "PLAY 阶段 play_card 成功")


# ============================================================================
# AC-002：费用不足拒绝
# ============================================================================

func test_ac002_insufficient_cost_rejected() -> void:
	cs.call("advance_phase")  # 0→1
	cs.call("advance_phase")  # 1→2
	# 注入 100 费卡牌——CostSystem 默认 max_cost=0 → can_afford(100)=false
	_setup_hand([_make_card(1, 100)])
	var ok: bool = cs.call("play_card", 1, [])
	assert_false(ok, "费用不足 play_card 返回 false")
	# 手牌仍非空（未移除）
	assert_eq(cs.call("get_hand").size(), 1, "卡牌未从手牌移除")


func test_ac002_zero_cost_always_affordable() -> void:
	cs.call("advance_phase")
	cs.call("advance_phase")
	# 0 费卡牌始终可出
	_setup_hand([_make_card(1, 0)])
	var ok: bool = cs.call("play_card", 1, [])
	assert_true(ok, "0 费卡牌 play_card 成功")


# ============================================================================
# AC-003：目标验证失败拒绝
# ============================================================================

func test_ac003_target_validation_failure_rejected() -> void:
	cs.call("advance_phase")
	cs.call("advance_phase")
	_setup_hand([_make_card(1, 0)])
	# 注入 validate_targets_cb 返回 false
	cs.set("validate_targets_cb", Callable(
		func(_card, _targets): return false
	))
	var ok: bool = cs.call("play_card", 1, [0])
	assert_false(ok, "目标验证失败 play_card 返回 false")


func test_ac003_target_validation_pass_proceeds() -> void:
	cs.call("advance_phase")
	cs.call("advance_phase")
	_setup_hand([_make_card(1, 0)])
	cs.set("validate_targets_cb", Callable(
		func(_card, _targets): return true
	))
	var ok: bool = cs.call("play_card", 1, [0])
	assert_true(ok, "目标验证通过 play_card 成功")


func test_ac003_cost_checked_before_target_validation() -> void:
	cs.call("advance_phase")
	cs.call("advance_phase")
	# 注入 100 费卡牌（费用不足）+ validate_targets_cb 间谍计数器
	_setup_hand([_make_card(1, 100)])
	var validate_called: Array = [0]
	cs.set("validate_targets_cb", Callable(
		func(_card, _targets):
			validate_called[0] += 1
			return false
	))
	var ok: bool = cs.call("play_card", 1, [0])
	assert_false(ok, "费用不足时 play_card 返回 false")
	assert_eq(validate_called[0], 0, "费用检查先于目标检查——validate_targets_cb 未被调用")


# ============================================================================
# AC-004：扣费执行
# ============================================================================

func test_ac004_spend_called_on_success() -> void:
	cs.call("advance_phase")
	cs.call("advance_phase")
	# 注入 0 费卡牌——_spend(0) 在 CostSystem 中为 no-op，不阻塞
	_setup_hand([_make_card(1, 0)])
	var ok: bool = cs.call("play_card", 1, [])
	assert_true(ok, "0 费卡牌扣费成功")


func test_ac004_spend_called_with_nonzero_cost() -> void:
	cs.call("advance_phase")
	cs.call("advance_phase")
	# 注入 3 费卡牌 + 预设 CostSystem 可支付
	_setup_hand([_make_card(1, 3)])
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var cost_system: Node = tree.root.get_node_or_null("/root/CostSystem")
	if cost_system != null:
		cost_system.clear_for_battle_end()
		cost_system.init_for_battle(10)  # 10 费上限
		var ok: bool = cs.call("play_card", 1, [])
		assert_true(ok, "3 费卡牌扣费成功")
		assert_eq(cost_system.get_current_cost(), 7, "扣费后剩余 7 费")
		cost_system.clear_for_battle_end()
	else:
		pass  # CostSystem 未注册时跳过


# ============================================================================
# AC-005：效果结算执行
# ============================================================================

func test_ac005_resolve_called_on_success() -> void:
	cs.call("advance_phase")
	cs.call("advance_phase")
	_setup_hand([_make_card(1, 0)])
	# 注入 resolve_cb 返回非空结果
	var resolve_called: Array = [0]
	cs.set("resolve_cb", Callable(
		func(_card, _targets):
			resolve_called[0] += 1
			return [{"effect": "damage", "target_id": 2, "is_kill": false}]
	))
	var ok: bool = cs.call("play_card", 1, [0])
	assert_true(ok, "出牌成功")
	assert_eq(resolve_called[0], 1, "resolve_cb 被调用 1 次")


func test_ac005_resolve_returns_empty_without_cb() -> void:
	cs.call("advance_phase")
	cs.call("advance_phase")
	_setup_hand([_make_card(1, 0)])
	# 不注入 resolve_cb → 桩返回空 Array
	var ok: bool = cs.call("play_card", 1, [])
	assert_true(ok, "无 resolve_cb 时仍成功（桩返回空结果）")


func test_play_card_card_not_found_rejected() -> void:
	cs.call("advance_phase")
	cs.call("advance_phase")
	# 不注入卡牌实例缓存 → _get_card_instance 返回 null
	cs.call("set_card_instances", {})
	cs.call("set_hand", [_make_card(999, 0)])
	var ok: bool = cs.call("play_card", 999, [])
	assert_false(ok, "卡牌实例不存在时 play_card 返回 false")
	assert_eq(cs.call("get_hand").size(), 1, "手牌不变")
	assert_eq(cs.call("get_current_phase"), 2, "阶段不变")


# ============================================================================
# AC-006：阵亡检查
# ============================================================================

func test_ac006_death_check_emits_character_died() -> void:
	cs.call("advance_phase")
	cs.call("advance_phase")
	_setup_hand([_make_card(1, 0)])
	# 注入 resolve 返回 is_kill=true 的结果
	cs.set("resolve_cb", Callable(
		func(_card, _targets):
			return [{"target_id": 5, "is_kill": true, "side": 1, "binding_card_ids": [10]}]
	))
	# 捕获 character_died 信号
	var sig := {"received": false, "char_id": -1, "count": 0}
	cs.connect("character_died", func(char_id: int, _side: int, _ids: Array):
		sig["received"] = true
		sig["char_id"] = char_id
		sig["count"] += 1)
	var ok: bool = cs.call("play_card", 1, [0])
	assert_true(ok, "出牌成功")
	assert_true(sig["received"], "character_died 信号已发射")
	assert_eq(sig["char_id"], 5, "target_id=5")
	assert_eq(sig["count"], 1, "信号发射 1 次")


func test_ac006_no_kill_no_signal() -> void:
	cs.call("advance_phase")
	cs.call("advance_phase")
	_setup_hand([_make_card(1, 0)])
	cs.set("resolve_cb", Callable(
		func(_card, _targets):
			return [{"target_id": 5, "is_kill": false}]
	))
	var sig := {"received": false, "count": 0}
	cs.connect("character_died", func(_c: int, _s: int, _i: Array):
		sig["received"] = true
		sig["count"] += 1)
	cs.call("play_card", 1, [0])
	assert_false(sig["received"], "无击杀时不发射 character_died")


func test_ac006_multiple_kills_emits_multiple_signals() -> void:
	cs.call("advance_phase")
	cs.call("advance_phase")
	_setup_hand([_make_card(1, 0)])
	# resolve 返回 2 个 is_kill=true 结果
	cs.set("resolve_cb", Callable(
		func(_card, _targets):
			return [
				{"target_id": 5, "is_kill": true, "side": 1, "binding_card_ids": [10]},
				{"target_id": 6, "is_kill": true, "side": 1, "binding_card_ids": []},
			]
	))
	var received_ids: Array = []
	cs.connect("character_died", func(char_id: int, _side: int, _ids: Array):
		received_ids.append(char_id))
	var ok: bool = cs.call("play_card", 1, [0])
	assert_true(ok, "出牌成功")
	assert_eq(received_ids.size(), 2, "character_died 发射 2 次")
	assert_eq(received_ids[0], 5, "第 1 次 char_id=5")
	assert_eq(received_ids[1], 6, "第 2 次 char_id=6")


# ============================================================================
# AC-007：空手牌自动推进
# ============================================================================

func test_ac007_empty_hand_auto_advances() -> void:
	cs.call("advance_phase")  # 0→1
	cs.call("advance_phase")  # 1→2
	# 单张 0 费卡牌——打出后手牌空 + 无费可出 → 自动推进
	_setup_hand([_make_card(1, 0)])
	var ok: bool = cs.call("play_card", 1, [])
	assert_true(ok, "出牌成功")
	# 手牌空 + _can_afford_any_card（桩）返回 false（hand 空） → advance_phase
	assert_eq(cs.call("get_current_phase"), 3, "自动推进到 ATK_DEC(3)")


func test_ac007_non_empty_hand_no_auto_advance() -> void:
	cs.call("advance_phase")
	cs.call("advance_phase")
	# 两张 0 费卡牌——打出 1 张后手牌仍非空
	_setup_hand([_make_card(1, 0), _make_card(2, 0)])
	cs.call("play_card", 1, [])
	# 手牌非空 → 不自动推进
	assert_eq(cs.call("get_current_phase"), 2, "手牌非空时不自动推进")
	assert_eq(cs.call("get_hand").size(), 1, "手牌剩 1 张")


# ============================================================================
# AC-008：伤害公式 max(1, ATK - DEF)
# ============================================================================

func test_ac008_damage_formula_basic() -> void:
	# ATK=4, DEF=0 → max(1, 4-0) = 4
	var result: Dictionary = cs.call("calculate_damage", 4, 0, 1, 1)
	assert_eq(result["actual_damage"], 4, "ATK=4 DEF=0 → actual=4")
	assert_eq(result["final_damage"], 4, "同境界 penalty=1.0 → final=4")


func test_ac008_damage_min_1() -> void:
	# ATK=0, DEF=10 → max(1, 0-10) = max(1, -10) = 1
	var result: Dictionary = cs.call("calculate_damage", 0, 10, 1, 1)
	assert_eq(result["actual_damage"], 1, "ATK<DEF → actual 最低 1")
	assert_eq(result["final_damage"], 1, "final 最低 1")


func test_ac008_zero_def_damage_equals_atk() -> void:
	# AC-008 边缘：0 防御时伤害 = ATK
	var result: Dictionary = cs.call("calculate_damage", 7, 0, 1, 1)
	assert_eq(result["actual_damage"], 7, "0 防御 → actual=ATK")
	assert_eq(result["final_damage"], 7, "同境界 → final=actual")


# ============================================================================
# AC-009：境界压制伤害修正 floor(actual × penalty)
# ============================================================================

func test_ac009_realm_penalty_applied() -> void:
	# ATK=10, DEF=0, 高 1 级 → penalty=0.8 → floor(10×0.8)=8
	var result: Dictionary = cs.call("calculate_damage", 10, 0, 1, 2)
	assert_eq(result["actual_damage"], 10, "actual=10")
	assert_eq(result["realm_penalty"], 0.8, "高 1 级 penalty=0.8")
	assert_eq(result["final_damage"], 8, "floor(10×0.8)=8")


func test_ac009_floor_truncation() -> void:
	# ATK=3, DEF=0, 高 1 级 → penalty=0.8 → floor(3×0.8)=floor(2.4)=2
	var result: Dictionary = cs.call("calculate_damage", 3, 0, 1, 2)
	assert_eq(result["final_damage"], 2, "floor(3×0.8)=floor(2.4)=2")


# ============================================================================
# AC-010：高 1 级敌人压制 0.8
# ============================================================================

func test_ac010_high_1_level_penalty_08() -> void:
	# ATK=4, DEF=0, attacker_realm=1, defender_realm=2 → penalty=0.8
	var result: Dictionary = cs.call("calculate_damage", 4, 0, 1, 2)
	assert_eq(result["realm_penalty"], 0.8, "高 1 级 penalty=0.8")
	assert_eq(result["final_damage"], 3, "floor(4×0.8)=floor(3.2)=3")


# ============================================================================
# AC-011：高 2 级及以上压制 0.5
# ============================================================================

func test_ac011_high_2_level_penalty_05() -> void:
	# ATK=4, DEF=0, attacker_realm=1, defender_realm=3 → penalty=0.5
	var result: Dictionary = cs.call("calculate_damage", 4, 0, 1, 3)
	assert_eq(result["realm_penalty"], 0.5, "高 2 级 penalty=0.5")
	assert_eq(result["final_damage"], 2, "floor(4×0.5)=2")


func test_ac011_high_3_level_penalty_05() -> void:
	# ATK=4, DEF=0, attacker_realm=1, defender_realm=4 → penalty=0.5
	var result: Dictionary = cs.call("calculate_damage", 4, 0, 1, 4)
	assert_eq(result["realm_penalty"], 0.5, "高 3 级 penalty=0.5")
	assert_eq(result["final_damage"], 2, "floor(4×0.5)=2")


# ============================================================================
# AC-012：同境界或低于无压制 1.0
# ============================================================================

func test_ac012_same_realm_no_penalty() -> void:
	# ATK=4, DEF=0, attacker_realm=2, defender_realm=2 → penalty=1.0
	var result: Dictionary = cs.call("calculate_damage", 4, 0, 2, 2)
	assert_eq(result["realm_penalty"], 1.0, "同境界 penalty=1.0")
	assert_eq(result["final_damage"], 4, "final=actual=4")


func test_ac012_lower_realm_no_penalty() -> void:
	# ATK=4, DEF=0, attacker_realm=3, defender_realm=1 → penalty=1.0
	var result: Dictionary = cs.call("calculate_damage", 4, 0, 3, 1)
	assert_eq(result["realm_penalty"], 1.0, "攻击方更高 penalty=1.0")
	assert_eq(result["final_damage"], 4, "final=actual=4")


func test_calculate_damage_large_numbers_no_overflow() -> void:
	# 大数输入——验证无整数溢出
	var result: Dictionary = cs.call("calculate_damage", 99999, 99998, 1, 1)
	assert_eq(result["actual_damage"], 1, "ATK=99999 DEF=99998 → actual=1")
	assert_eq(result["final_damage"], 1, "同境界 final=1")


func test_calculate_damage_negative_atk_clamped_to_1() -> void:
	# 负数 ATK 输入——maxi(1, -5-0)=1
	var result: Dictionary = cs.call("calculate_damage", -5, 0, 1, 1)
	assert_eq(result["actual_damage"], 1, "ATK=-5 → actual 最低 1")
	assert_eq(result["final_damage"], 1, "final 最低 1")


func test_calculate_damage_final_min_1_with_penalty() -> void:
	# actual=1, penalty=0.5 → floor(0.5)=0 → maxi(1,0)=1
	var result: Dictionary = cs.call("calculate_damage", 1, 0, 1, 3)
	assert_eq(result["actual_damage"], 1, "actual=1")
	assert_eq(result["realm_penalty"], 0.5, "高 2 级 penalty=0.5")
	assert_eq(result["final_damage"], 1, "floor(1×0.5)=0 → final 保底 1")


# ============================================================================
# 综合：完整出牌流程
# ============================================================================

func test_full_play_card_flow() -> void:
	cs.call("advance_phase")  # 0→1
	cs.call("advance_phase")  # 1→2
	# 注入 2 张卡牌 + resolve 回调
	_setup_hand([_make_card(1, 0), _make_card(2, 0)])
	var resolve_count: Array = [0]
	cs.set("resolve_cb", Callable(
		func(_card, _targets):
			resolve_count[0] += 1
			return []
	))
	# 打出第 1 张
	var ok1: bool = cs.call("play_card", 1, [])
	assert_true(ok1, "第 1 张出牌成功")
	assert_eq(resolve_count[0], 1, "resolve 调用 1 次")
	assert_eq(cs.call("get_hand").size(), 1, "手牌剩 1 张")
	assert_eq(cs.call("get_current_phase"), 2, "未自动推进（手牌非空）")
	# 打出第 2 张——手牌空 → 自动推进
	var ok2: bool = cs.call("play_card", 2, [])
	assert_true(ok2, "第 2 张出牌成功")
	assert_eq(resolve_count[0], 2, "resolve 调用 2 次")
	assert_eq(cs.call("get_hand").size(), 0, "手牌空")
	assert_eq(cs.call("get_current_phase"), 3, "手牌空 → 自动推进到 ATK_DEC(3)")