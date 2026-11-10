extends "res://tests/integration/combat_ui/turn_cycle_fixture.gd"
## 敌方回合：按阵位顺序行动、结果可观测、期间玩家输入被屏蔽。[br]
## [br]夹具见 [code]turn_cycle_fixture.gd[/code]。


func before_each() -> void:
	setup()


func after_each() -> void:
	teardown()

# ═══════════════════════════════════════════════════════════════════════════════
# 2. 敌方按阵位顺序行动
# ═══════════════════════════════════════════════════════════════════════════════

## 多个敌人各自行动一次，且结算顺序按阵位升序（与画面从上到下一致）。[br]
## [br][b]故意把名册数组顺序与阵位反着放[/b]：若实现直接用 AI 返回顺序，
## 战报顺序会与玩家看到的阵位对不上。
func test_enemy_actions_follow_slot_order() -> void:
	# Arrange——名册顺序 [阵位 4, 阵位 0, 阵位 2]
	var back: Object = _enemy_state(&"back", 4)
	var front: Object = _enemy_state(&"front", 0)
	var mid: Object = _enemy_state(&"mid", 2)
	var actions: Array = _capture_enemy_actions()
	_start([back, front, mid])
	_advance_to(2)
	# Act
	cs.call("confirm_end_turn")
	_advance_to(0)
	# Assert——三次行动，顺序按阵位 0 → 2 → 4
	assert_eq(actions.size(), 3, "三个敌人各行动一次")
	var ids: Array = []
	for payload: Dictionary in actions:
		ids.append(int(payload["enemy_id"]))
	assert_eq(ids, _expected_ids_in_slot_order([back, front, mid]),
			"按阵位升序结算（阵位 0 → 2 → 4），而非名册数组顺序")


## 按阵位升序预期的敌人 ID 列表（ID 派生口径与状态表同源）。
func _expected_ids_in_slot_order(p_enemies: Array) -> Array:
	var sorted: Array = p_enemies.duplicate()
	sorted.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int(a.field_position) < int(b.field_position))
	var ids: Array = []
	for i: int in range(sorted.size()):
		ids.append(_roster_id_of(sorted[i], p_enemies))
	return ids


## 某敌人在开战名册里的落键 ID（下标派生——与 CombatRosterState 同源）。
func _roster_id_of(p_enemy: Object, p_roster: Array) -> int:
	for idx: int in range(p_roster.size()):
		if p_roster[idx] == p_enemy:
			return 100000 + idx * 10000
	return -1


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 敌方行动的可观测结果
# ═══════════════════════════════════════════════════════════════════════════════

## 载荷带齐「选中谁 / 造成多少 / 是否击杀」三件事。[br]
## [br][b]为什么三件都要[/b]：选中目标是战报的必要信息（否则玩家不知道谁被打），
## 伤害是数值，击杀决定是否播放阵亡表现——缺任何一项表现层都要再想办法反推。
func test_enemy_action_payload_is_observable() -> void:
	# Arrange
	_start([_enemy_state(&"grunt", 0)])
	var actions: Array = _capture_enemy_actions()
	_advance_to(2)
	# Act
	cs.call("confirm_end_turn")
	_advance_to(0)
	# Assert
	var payload: Dictionary = actions[0]
	assert_true(payload.has("target_id"), "载荷含选中目标")
	assert_true(int(payload["target_id"]) in [CHAR_A, CHAR_B], "目标是场上我方角色")
	assert_eq(int(payload["damage"]), ENEMY_ATK, "载荷含伤害数值")
	assert_true(payload.has("is_kill"), "载荷含是否击杀")
	assert_eq(StringName(str(payload["action"])), EnemyTurn.ACTION_SKILL, "行动类型为技能")


## 击杀可观测：敌人打死后 is_kill 为真。[br]
## [br][b]构造方式[/b]：把我方角色设成 1 血、敌人 4 攻——一次攻击必杀。
func test_enemy_kill_is_observable() -> void:
	# Arrange——CHAR_A 只有 1 血
	var enemies: Array = [_enemy_state(&"executioner", 0, 9)]
	_start(enemies)
	cs.call("_get_roster_state").call(&"apply_damage", CHAR_A, 9)  # 打到 1 血
	assert_eq(_hp(CHAR_A), 1, "前置：CHAR_A 剩 1 血")
	var actions: Array = _capture_enemy_actions()
	_advance_to(2)
	# Act
	cs.call("confirm_end_turn")
	_advance_to(0)
	# Assert
	var target_hit: Dictionary = {}
	for payload: Dictionary in actions:
		if int(payload["target_id"]) == CHAR_A:
			target_hit = payload
			break
	assert_false(target_hit.is_empty(), "CHAR_A 被攻击")
	assert_true(bool(target_hit["is_kill"]), "击杀在载荷中可观测")
	assert_eq(_hp(CHAR_A), 0, "CHAR_A 的 HP 归零")


## 撤退行动不造成伤害，但同样有可观测记录（不是静默跳过）。[br]
## [br][b]为什么允许零伤害的行动也发信号[/b]：战报要能显示「敌人撤退了」；
## 静默跳过会让玩家以为是卡住了。
func test_retreat_action_reported_without_damage() -> void:
	# Arrange——直接驱动结算模块，构造一条撤退行动（AI 撤退判定依赖 HP 比例与概率，
	# 走全流程会有随机性；这里验的是「撤退这条路径的结算形状」）
	var hp_before: int = 0
	_start([_enemy_state(&"coward", 0)])
	hp_before = _hp(CHAR_A) + _hp(CHAR_B)
	var module: RefCounted = cs.call("_get_enemy_turn")
	var settled: Array = module.call(&"resolve", [{
		"enemy_id": AISystem.get_enemy_roster()[0],
		"skill_id": &"",
		"target_ids": [],
		"is_retreat": true,
	}])
	# Assert
	assert_eq(settled.size(), 1, "撤退也产生一条记录")
	assert_eq(StringName(str(settled[0]["action"])), EnemyTurn.ACTION_RETREAT, "标注为撤退")
	assert_eq(int(settled[0]["damage"]), 0, "撤退不造成伤害")
	assert_eq(_hp(CHAR_A) + _hp(CHAR_B), hp_before, "我方 HP 未变")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 敌方回合期间玩家输入被屏蔽
# ═══════════════════════════════════════════════════════════════════════════════

## 敌方行动阶段出牌被拒（系统侧），且卡牌留在手牌、费用不扣。[br]
## [br][b]这是最该拦住的一条[/b]：敌方回合给玩家出牌 = 直接改变战斗结果。
func test_play_card_rejected_during_enemy_turn() -> void:
	# Arrange——注入一张 0 费卡（排除费用因素的干扰）
	_start([_enemy_state(&"grunt", 0)])
	cs.call("set_card_instances", {7001: {
		"card_instance_id": 7001, "cost": 0, "template_id": "test_turn_cycle",
		"target_type": &"single_enemy",
		"effects": [],
	}})
	cs.call("set_hand", [{"card_instance_id": 7001, "cost": 0}])
	_advance_to(5)  # 敌方行动阶段
	var cost_before: int = CostSystem.get_current_cost()
	# Act
	var result: Dictionary = cs.call("play_card_detailed", 7001, [])
	# Assert
	assert_false(bool(result["ok"]), "敌方回合出牌被拒")
	assert_eq(StringName(str(result["reason"])), &"wrong_phase", "拒绝原因是阶段不对")
	assert_eq(cs.call("get_hand").size(), 1, "卡牌留在手牌")
	assert_eq(CostSystem.get_current_cost(), cost_before, "拒绝时不扣费")


## 敌方行动阶段持有 ANIMATION 锁（阶段 4/5 收窄后的口径）。[br]
## [br][b]为什么锁与阶段守卫两条都要[/b]：锁管「动画期间不许动」，
## 阶段守卫管「这个阶段本来就不是出牌的时候」——两者失效方式不同，
## 缺任一条都会留下一条能出牌的路。
func test_enemy_turn_holds_animation_lock() -> void:
	# Arrange + Act
	_start([_enemy_state(&"grunt", 0)])
	_advance_to(5)
	# Assert
	assert_eq(int(cs.call("get_current_phase")), 5, "前置：敌方行动阶段")
	assert_true(InputManager.has_lock(&"combat_system"), "阶段 5 持有动画锁")
	assert_false(InputManager.is_input_allowed(
			InputManager.ActionType.GAMEPLAY, InputManager.DeviceType.MOUSE),
			"玩法输入被锁拦截")
