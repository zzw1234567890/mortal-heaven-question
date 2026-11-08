extends GutTest
## Sprint 18 集成测试：费用系统激活 + Phase 6 END 战斗结束检查接线。
##
## 覆盖三处补链：[br]
##   1. [code]battle_start[/code] → [code]CostSystem.init_for_battle(境界费用上限)[/code]；[br]
##   2. [code]battle_end[/code] → [code]CostSystem.clear_for_battle_end[/code]；[br]
##   3. END 阶段判定命中 → 自动收尾 [code]battle_end(VICTORY/DEFEAT)[/code]，
##      且 7 阶段序列与 [code]phase_changed[/code] 完整走完后再退出（ADR-0008 §Phase 6）。[br]
## [br]测试策略（先例 test_battle_lifecycle_gsm.gd）：[code]CS_SCRIPT.new()[/code] +
## [code]set_auto_advance(false)[/code] + [code]set_scene_change(false)[/code]；
## 真实 CostSystem / RealmSystem / DeploymentSystem Autoload 参与（这正是被测接线）。

const CS_SCRIPT := preload("res://src/feature/combat_system.gd")
const RealmSystemScript := preload("res://src/core/realm_system.gd")

var cs: Node = null
var _release_ids: Array = []
var _realm_before: int = 1
var _ai_roster_before: Array = []


func before_each() -> void:
	cs = CS_SCRIPT.new()
	cs.call("set_auto_advance", false)
	cs.call("set_scene_change", false)
	GameStateManager.battle = null
	GameStateManager._pending_changes.clear()
	GameStateManager._flush_scheduled = false
	_release_ids.clear()
	# 快照全局单例状态——套件结束原样还原（Autoload 跨套件共享）
	_realm_before = int(GameStateManager.player.realm)
	_ai_roster_before = AISystem.get_enemy_roster().duplicate()


func after_each() -> void:
	if cs != null:
		cs.free()
		cs = null
	# 阵位/费用/境界/AI 阵容归零——不清理会污染后续测试
	for cid: int in _release_ids:
		DeploymentSystem.remove_character(cid)
	_release_ids.clear()
	CostSystem.clear_for_battle_end()
	# 未分胜负的用例会让战斗停在活跃态——清掉它推入的 ANIMATION 锁
	InputManager.clear_locks(&"combat_system")
	GameStateManager.player.realm = _realm_before
	AISystem.set_enemy_roster(_ai_roster_before)
	GameStateManager.battle = null
	GameStateManager._pending_changes.clear()
	GameStateManager._flush_scheduled = false


## 从境界表读期望费用上限（不硬编码——RealmSystem 是唯一真理来源）。
func _expected_cap(realm: int) -> int:
	return int(RealmSystemScript.realm_table[realm]["cost_per_turn"])


## 推进到 END 阶段（PREPARATION → … → END，共 6 次推进）。
func _advance_to_end() -> void:
	for i: int in range(6):
		cs.call("advance_phase")


## 推进到 END（按当前阶段计算步数——出牌自动推进后阶段已前移）。[br]
## 战斗已结束时提前退出（battle_end 会把 _is_active 置 false）。
func _advance_to_end_from_current() -> void:
	while bool(cs.call("is_battle_active")) and int(cs.call("get_current_phase")) != 6:
		if not bool(cs.call("advance_phase")):
			break
	if bool(cs.call("is_battle_active")) and int(cs.call("get_current_phase")) == 6:
		cs.call("advance_phase")


## 上场一名角色并登记清理（模拟备战确认后的阵位）。
func _deploy_character(character_id: int) -> bool:
	var ok: bool = DeploymentSystem.setup_field([character_id], {})
	if ok:
		_release_ids.append(character_id)
	return ok


# ═══════════════════════════════════════════════════════════════════════════════
# 费用系统激活（battle_start / battle_end）
# ═══════════════════════════════════════════════════════════════════════════════

func test_battle_start_initializes_cost_from_realm_table() -> void:
	# Arrange——炼气期（realm 1）
	GameStateManager.player.realm = GameStateManager.RealmLevel.QI_REFINING
	var expected: int = _expected_cap(GameStateManager.RealmLevel.QI_REFINING)
	# Act
	cs.call("battle_start", {})
	# Assert
	assert_eq(CostSystem.get_max_cost(), expected, "战斗开始应把境界费用上限推入 CostSystem")
	assert_eq(CostSystem.get_current_cost(), expected, "首个回合费用应回满至上限")
	assert_true(CostSystem._is_active, "费用系统应处于激活状态")


func test_battle_start_cost_cap_follows_realm() -> void:
	# Arrange——金丹期（realm 3，费用上限高于炼气）
	GameStateManager.player.realm = 3
	var expected: int = _expected_cap(3)
	# Act
	cs.call("battle_start", {})
	# Assert
	assert_eq(CostSystem.get_max_cost(), expected, "费用上限应按当前境界取值（非硬编码）")


func test_battle_end_clears_cost_state() -> void:
	# Arrange
	cs.call("battle_start", {})
	assert_true(CostSystem._is_active, "前置：费用系统已激活")
	# Act
	cs.call("battle_end", CS_SCRIPT.CombatResult.DEFEAT)
	# Assert
	assert_false(CostSystem._is_active, "战斗结束后费用系统应失活")
	assert_eq(CostSystem.get_current_cost(), 0, "战斗结束后当前费用应清零")


# ═══════════════════════════════════════════════════════════════════════════════
# END 阶段判定 → 自动收尾
# ═══════════════════════════════════════════════════════════════════════════════

func test_end_all_enemies_dead_ends_battle_with_victory() -> void:
	# Arrange——敌方名册全灭（config 直供，不依赖 AISystem 现状）
	var sig: Dictionary = {"result": -1, "count": 0}
	cs.connect("battle_ended", func(result: int, _rewards: Dictionary) -> void:
		sig["result"] = result
		sig["count"] += 1)
	cs.call("battle_start", {"enemy_roster": [{"is_alive": false}], "character_ids": [101]})
	# Act——推进到 END（第 6 次推进触发判定）
	_advance_to_end()
	# Assert
	assert_false(cs.call("is_battle_active"), "敌方全灭后战斗应结束")
	assert_eq(sig["count"], 1, "battle_ended 应发射一次")
	assert_eq(int(sig["result"]), CS_SCRIPT.CombatResult.VICTORY, "结局应为 VICTORY")


func test_end_all_allies_dead_ends_battle_with_defeat() -> void:
	# Arrange——我方上场 + 打牌击杀（DEBT-CBT-018-1 端到端：不再手工 remove_character）
	assert_true(_deploy_character(101), "前置：角色上场成功")
	cs.call("battle_start", {
		"enemy_roster": [{"is_alive": true}],
		"character_ids": [101],
		"player_stats": {101: {"current_hp": 6, "max_hp": 6}},
	})
	assert_true(DeploymentSystem.get_character_slot(101) != -1, "前置：角色在阵位上")
	# 推进到 PLAY，注入一张 0 费「斩杀自己」的卡（效果结算打空当前 HP）
	cs.call("set_card_instances", {7: {"card_instance_id": 7, "cost": 0, "template_id": "test_card"}})
	cs.call("set_hand", [{"card_instance_id": 7, "cost": 0, "template_id": "test_card"}])
	cs.call("advance_phase")  # PREPARATION → DRAW
	cs.call("advance_phase")  # DRAW → PLAY
	cs.set("resolve_cb", Callable(func(_card, _targets) -> Array:
		return [{"target_id": 101, "damage": 6, "side": 0, "binding_card_ids": []}]))
	var deaths: Array = []
	cs.connect("character_died", func(char_id: int, side: int, _ids: Array) -> void:
		deaths.append({"id": char_id, "side": side}))
	var sig: Dictionary = {"result": -1}
	cs.connect("battle_ended", func(result: int, _rewards: Dictionary) -> void:
		sig["result"] = result)
	# Act——打牌击杀 → 自动清位 → END 判负
	assert_true(cs.call("play_card", 7, []), "出牌成功")
	assert_eq(deaths.size(), 1, "击杀应发射一次 character_died")
	assert_eq(int(deaths[0]["side"]), 0, "我方 side=0")
	assert_true(DeploymentSystem.get_character_slot(101) == -1, "阵亡后阵位应被自动清空")
	_release_ids.clear()  # 已清位
	_advance_to_end_from_current()
	# Assert
	assert_false(cs.call("is_battle_active"), "己方全灭后战斗应结束")
	assert_eq(int(sig["result"]), CS_SCRIPT.CombatResult.DEFEAT, "结局应为 DEFEAT")


func test_end_with_both_sides_alive_continues_to_next_turn() -> void:
	# Arrange——双方都有人
	assert_true(_deploy_character(101), "前置：角色上场成功")
	cs.call("battle_start", {"enemy_roster": [{"is_alive": true}], "character_ids": [101]})
	# Act——推进到 END 再回绕
	_advance_to_end()
	assert_eq(cs.call("get_current_phase"), 6, "未分胜负应停在本回合 END")
	assert_true(cs.call("is_battle_active"), "未分胜负战斗应继续")
	cs.call("advance_phase")  # END → PREPARATION
	# Assert
	assert_eq(cs.call("get_current_phase"), 0, "应回绕到下一回合 PREPARATION")
	assert_eq(cs.call("get_turn_number"), 2, "回合数应递增")


func test_end_without_enemy_data_does_not_declare_victory() -> void:
	# Arrange——无敌方信息（config 与 AISystem 均无阵容）
	AISystem.set_enemy_roster([])
	cs.call("battle_start", {"character_ids": [101]})
	var sig: Dictionary = {"count": 0}
	cs.connect("battle_ended", func(_result: int, _rewards: Dictionary) -> void:
		sig["count"] += 1)
	# Act
	_advance_to_end()
	# Assert
	assert_eq(sig["count"], 0, "无敌方数据不得判胜利结束")
	assert_true(cs.call("is_battle_active"), "战斗应继续（信息不足则不判）")


func test_end_phase_changed_emitted_before_battle_end() -> void:
	# Arrange——断言 7 阶段序列完整走完再退出（信号顺序）
	var order: Array = []
	cs.connect("phase_changed", func(_old: int, new_phase: int, _turn: int) -> void:
		order.append(new_phase))
	cs.connect("battle_ended", func(_result: int, _rewards: Dictionary) -> void:
		order.append(-1))
	cs.call("battle_start", {"enemy_roster": [{"is_alive": false}], "character_ids": [101]})
	# Act
	_advance_to_end()
	# Assert
	assert_eq(order, [1, 2, 3, 4, 5, 6, -1],
			"phase_changed 应依次到 END(6)，battle_ended 在其后发射")
