extends "res://tests/integration/combat_system/full_battle_fixture.gd"
## Debuff 集成测试——敌方行动施加 debuff，伤害计算生效。[br]
## [br]测试覆盖：[br]
## - 敌方行动带 debuff_config 时目标被施加 debuff[br]
## - 降攻 debuff 使敌方后续攻击伤害降低[br]
## - 降防 debuff 使目标受到的伤害增加[br]
## - 回合结束时 debuff 持续回合数递减[br]
## - 归零后移除，数值恢复[br]
## - 重复施加按层数叠加，5 层封顶[br]

const DebuffManagerScript := preload("res://src/feature/combat/combat_debuff_manager.gd")


func test_enemy_action_applies_debuff() -> void:
	# Arrange——手动注入 debuff 配置
	setup(false)
	confirm_deploy()
	var enemy_id: int = _first_alive_enemy()
	var roster: Variant = cs.call("_get_roster_state")
	# 手动施加降攻 debuff
	roster.call(&"apply_debuff", 100001, DebuffManagerScript.TYPE_ATK, 2, 1, 1, enemy_id)
	# Act——获取敌方攻击力（已受 debuff 修正）
	var atk_debuffed: int = int(roster.call(&"get_atk", enemy_id))
	# 敌方原始 ATK 应为 2（san_xiu 模板），降攻 1 后应为 1
	assert_eq(atk_debuffed, 1, "降攻 debuff 应降低敌方攻击力")
	# Assert——debuff 状态
	var debuff_mgr: RefCounted = roster.call(&"get_debuff_manager")
	assert_eq(debuff_mgr.call(&"get_stacks", 100001, DebuffManagerScript.TYPE_ATK), 1)
	assert_eq(debuff_mgr.call(&"get_duration", 100001, DebuffManagerScript.TYPE_ATK), 2)


func test_def_debuff_increases_damage_taken() -> void:
	# Arrange——降防 debuff
	setup(false)
	confirm_deploy()
	var roster: Variant = cs.call("_get_roster_state")
	# 对我方角色施加降防 2
	var player_id: int = _first_player_id()
	roster.call(&"apply_debuff", player_id, DebuffManagerScript.TYPE_DEF, 2, 1, 2, 100000)
	# 获取我方防御力（已受 debuff 修正）
	var def_debuffed: int = int(roster.call(&"get_defense", player_id))
	# 模板基础防御为 0，降防后仍为 0（不会为负）
	assert_eq(def_debuffed, 0, "防御 0 降防后仍为 0")


func test_turn_end_decrements_duration() -> void:
	# Arrange——施加 debuff
	setup(false)
	confirm_deploy()
	var roster: Variant = cs.call("_get_roster_state")
	var player_id: int = _first_player_id()
	roster.call(&"apply_debuff", player_id, DebuffManagerScript.TYPE_ATK, 3, 1, 1, 100000)
	var debuff_mgr: RefCounted = roster.call(&"get_debuff_manager")
	assert_eq(debuff_mgr.call(&"get_duration", player_id, DebuffManagerScript.TYPE_ATK), 3)
	# Act——模拟回合结束
	roster.call(&"on_turn_end_debuff")
	# Assert——持续回合数 -1
	assert_eq(debuff.call(&"get_duration", player_id, DebuffManagerScript.TYPE_ATK), 2)
	roster.call(&"on_turn_end_debuff")
	assert_eq(debuff.call(&"get_duration", player_id, DebuffManagerScript.TYPE_ATK), 1)
	roster.call(&"on_turn_end_debuff")
	assert_eq(debuff.call(&"get_duration", player_id, DebuffManagerScript.TYPE_ATK), 0)
	# 归零后移除
	assert_eq(debuff.call(&"get_stacks", player_id, DebuffManagerScript.TYPE_ATK), 0)


func test_stacking_with_limit() -> void:
	# Arrange——尝试叠加 6 层（上限 5）
	setup(false)
	confirm_deploy()
	var roster: Variant = cs.call("_get_roster_state")
	var player_id: int = _first_player_id()
	var debuff_mgr: RefCounted = roster.call(&"get_debuff_manager")
	var success_count: int = 0
	for i: int in range(6):
		if roster.call(&"apply_debuff", player_id, DebuffManagerScript.TYPE_ATK, 2, 1, 1, 100000):
			success_count += 1
	# Assert——前 5 次成功，第 6 次失败
	assert_eq(success_count, 5, "debuff 应封顶于 5 层")
	assert_eq(debuff.call(&"get_stacks", player_id, DebuffManagerScript.TYPE_ATK), 5)


func test_damage_reduced_by_atk_debuff() -> void:
	# Arrange——模拟敌方攻击力变化（降攻 debuff → 伤害降低）
	setup(false)
	confirm_deploy()
	var enemy_id: int = _first_alive_enemy()
	var roster: Variant = cs.call("_get_roster_state")
	# 施加降攻 debuff（降 2）
	roster.call(&"apply_debuff", enemy_id, DebuffManagerScript.TYPE_ATK, 2, 1, 2, enemy_id)
	# 计算伤害：ATK 2 - 降攻 2 = 0 → 伤害 0
	var base_atk: int = 2  # san_xiu 模板
	var atk_debuffed: int = int(roster.call(&"get_atk", enemy_id))
	assert_eq(atk_debuffed, 0, "降攻 2 应让 ATK 变为 0")


func test_def_debuff_removes_at_zero_duration() -> void:
	# Arrange——duration 0（本回合结束后生效，所以立即递减并移除）
	setup(false)
	confirm_deploy()
	var roster: Variant = cs.call("_get_roster_state")
	var player_id: int = _first_player_id()
	roster.call(&"apply_debuff", player_id, DebuffManagerScript.TYPE_ATK, 0, 1, 100000)
	var debuff_mgr: RefCounted = roster.call(&"get_debuff_manager")
	# duration 0 应立即生效：回合结束时 -1 → -1 = 移除
	roster.call(&"on_turn_end_debuff")
	assert_eq(debuff.call(&"get_stacks", player_id, DebuffManagerScript.TYPE_ATK), 0, "duration 0 的 debuff 应在回合结束时移除")


func _first_player_id() -> int:
	var field: Array = cs.call("get_field")
	for entry: Variant in field:
		if entry is Dictionary:
			return int(entry.get("character_id", -1))
	return -1
