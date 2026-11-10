extends "res://tests/integration/combat_ui/turn_cycle_fixture.gd"
## 敌方行动播报集成测试：逐条节奏 / 输入屏蔽 / 防御减免 / 去重 / 阵亡不重复出场。
##
## 链路：真实 CombatSystem + 真实 AISystem 名册 + 真实状态表
## → [code]enemy_action_resolved[/code] → [code]EnemyActionBroadcast[/code]
## （含注入调度器与真实 Timer 两条路径）。

const BroadcastScript := preload("res://src/ui/combat/feedback/enemy_action_broadcast.gd")
const TextScript := preload("res://src/ui/combat/feedback/enemy_action_text.gd")
const CardScript := preload("res://src/ui/combat/layout/character_status_card.gd")
const CoordinatorScript := preload("res://src/ui/combat/feedback/combat_feedback_coordinator.gd")

## 飘字池探针——记录每次 spawn 的数值，用于证明播报不会重播伤害。
class SpyPool extends FloaterPool:
	var spawns: Array = []

	func spawn(_pos: Vector2, value: int, _kind: int, _reduced: bool = false) -> void:
		spawns.append(value)


var broadcast: Control = null
var coordinator: Control = null


func before_each() -> void:
	setup()
	broadcast = BroadcastScript.new()
	add_child(broadcast)


func after_each() -> void:
	if is_instance_valid(broadcast):
		broadcast.free()
	broadcast = null
	if coordinator != null and is_instance_valid(coordinator):
		coordinator.free()
	coordinator = null
	InputManager.clear_locks(&"enemy_broadcast")
	teardown()


func _wait_frames(p_frames: int) -> void:
	for i: int in p_frames:
		await get_tree().process_frame


## 即时调度器——记录每次间隔并立刻回调（把「节奏」变成确定性断言）。
func _use_immediate_scheduler(p_delays: Array) -> void:
	broadcast.set_scheduler(func(delay_ms: int, callback: Callable) -> void:
		p_delays.append(delay_ms)
		callback.call())


func _resolver() -> Callable:
	return TextScript.make_name_resolver(cs, null)


func _capture_damaged() -> Array:
	var captured: Array = []
	cs.connect("character_damaged", Callable(func(data: Dictionary) -> void:
		captured.append(data.duplicate(true))))
	return captured


## 行列表 → 单串（避免 Array[String] 与 Array 直接比较的类型差异）。
func _joined(p_lines: Array) -> String:
	var out: String = ""
	for line: Variant in p_lines:
		out += str(line) + "\n"
	return out


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 三条行动逐条播报，顺序 = 阵位顺序，间隔可注入
# ═══════════════════════════════════════════════════════════════════════════════

func test_three_enemy_actions_broadcast_in_slot_order_with_injected_interval() -> void:
	# Arrange——名册顺序 [阵位 4, 阵位 0, 阵位 2]，播报应按阵位 0 → 2 → 4
	var delays: Array = []
	var logged: Array = []
	_use_immediate_scheduler(delays)
	broadcast.set_interval_ms(10)
	broadcast.setup([cs], 10, _resolver(),
			func(line: String) -> void: logged.append(line))
	var back: Object = _enemy_state(&"back", 4)
	var front: Object = _enemy_state(&"front", 0)
	var mid: Object = _enemy_state(&"mid", 2)
	_start([back, front, mid])
	_advance_to(2)
	# Act
	cs.call("confirm_end_turn")
	_advance_to(0)
	await _wait_frames(2)
	# Assert——三条、顺序、间隔
	var lines: Array[String] = broadcast.get_lines()
	assert_eq(lines.size(), 3, "三次行动各播一条")
	assert_eq(delays, [10, 10, 10], "每条之间（含末条停留）都走注入间隔")
	assert_string_contains(lines[0], "front", "第一条 = 阵位 0")
	assert_string_contains(lines[1], "mid", "第二条 = 阵位 2")
	assert_string_contains(lines[2], "back", "第三条 = 阵位 4")
	assert_eq(_joined(logged), _joined(lines), "同一批文本同步进战斗日志")
	assert_false(broadcast.is_playing(), "播完即结束")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 播报期间输入被屏蔽（真实 Timer 路径）
# ═══════════════════════════════════════════════════════════════════════════════

func test_input_blocked_while_broadcast_playing_then_released() -> void:
	# Arrange
	broadcast.setup([cs], 80, _resolver())
	_start([_enemy_state(&"grunt", 0), _enemy_state(&"grunt2", 1)])
	_advance_to(2)
	# Act
	cs.call("confirm_end_turn")
	_advance_to(0)
	await _wait_frames(1)
	# Assert——阶段已回我方，但播报锁仍在（阶段守卫之外的第三层保险）
	assert_true(broadcast.is_playing(), "播报进行中")
	assert_true(InputManager.has_lock(&"enemy_broadcast"), "播报持有输入锁")
	assert_false(InputManager.is_input_allowed(
			InputManager.ActionType.GAMEPLAY, InputManager.DeviceType.MOUSE),
			"玩法输入被播报锁拦截")
	await get_tree().create_timer(0.5).timeout
	assert_false(broadcast.is_playing(), "播报结束")
	assert_false(InputManager.has_lock(&"enemy_broadcast"), "输入锁已释放")
	assert_true(InputManager.is_input_allowed(
			InputManager.ActionType.GAMEPLAY, InputManager.DeviceType.MOUSE),
			"播完恢复玩法输入")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 防御减免：max(0, 伤害 − 防御)
# ═══════════════════════════════════════════════════════════════════════════════

func test_player_defense_can_fully_block_enemy_damage() -> void:
	# Arrange——CHAR_A 5 HP（AI 集火最低血）+ 4 防御，敌人 4 攻 → 0 伤害
	var actions: Array = _capture_enemy_actions()
	var damaged: Array = _capture_damaged()
	_start([_enemy_state(&"grunt", 0)], true, {
		CHAR_A: {"current_hp": 5, "max_hp": 10, "atk": 3, "defense": 4},
		CHAR_B: {"current_hp": 10, "max_hp": 10, "atk": 3},
	})
	_advance_to(2)
	# Act
	cs.call("confirm_end_turn")
	_advance_to(0)
	# Assert
	assert_eq(int(actions[0]["target_id"]), CHAR_A, "目标是最低血的 CHAR_A")
	assert_eq(int(actions[0]["damage"]), 0, "4 攻 − 4 防 = 0（允许完全免伤）")
	assert_eq(_hp(CHAR_A), 5, "HP 未变化")
	assert_eq(damaged.size(), 0, "零增量不广播（无飘字可播）")


func test_player_defense_reduces_enemy_damage_to_remaining_value() -> void:
	# Arrange——2 防御 → 4 − 2 = 2 伤害
	var actions: Array = _capture_enemy_actions()
	var damaged: Array = _capture_damaged()
	_start([_enemy_state(&"grunt", 0)], true, {
		CHAR_A: {"current_hp": 5, "max_hp": 10, "atk": 3, "defense": 2},
		CHAR_B: {"current_hp": 10, "max_hp": 10, "atk": 3},
	})
	_advance_to(2)
	# Act
	cs.call("confirm_end_turn")
	_advance_to(0)
	# Assert
	assert_eq(int(actions[0]["target_id"]), CHAR_A, "目标是最低血的 CHAR_A")
	assert_eq(int(actions[0]["damage"]), 2, "4 攻 − 2 防 = 2")
	assert_eq(_hp(CHAR_A), 3, "HP 5 → 3")
	assert_eq(damaged.size(), 1, "一次实际伤害广播一次")
	assert_eq(int(damaged[0]["damage"]), 2, "广播增量 = 播报伤害 = 2")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 阵亡角色在播报期间不重复出场
# ═══════════════════════════════════════════════════════════════════════════════

func test_dead_target_not_repeated_in_broadcast() -> void:
	# Arrange——CHAR_A 3 血，两个敌人先后打 4 点（第二次应为落空）
	_use_immediate_scheduler([])
	broadcast.set_interval_ms(0)
	broadcast.setup([cs], 0, _resolver())
	_start([_enemy_state(&"one", 0), _enemy_state(&"two", 1)])
	var roster_state: RefCounted = cs.call("_get_roster_state")
	roster_state.call("apply_damage", CHAR_A, 7)
	assert_eq(_hp(CHAR_A), 3, "前置：CHAR_A 剩 3 血")
	var roster: Array = AISystem.get_enemy_roster()
	var module: RefCounted = cs.call("_get_enemy_turn")
	# Act
	var settled: Array = module.call("resolve", [
		{"enemy_id": roster[0], "target_ids": [{"id": CHAR_A}], "damage": 4},
		{"enemy_id": roster[1], "target_ids": [{"id": CHAR_A}], "damage": 4},
	])
	await _wait_frames(2)
	# Assert——第一次击杀；第二次不落库、不显示阵亡角色名
	assert_true(bool(settled[0]["is_kill"]), "第一次击杀")
	assert_eq(StringName(str(settled[1]["action"])), EnemyTurn.ACTION_NONE,
			"第二次对尸体发 none，不再造成伤害")
	assert_eq(int(settled[1]["damage"]), 0, "落空无伤害")
	var lines: Array[String] = broadcast.get_lines()
	assert_eq(lines.size(), 2, "两次行动各一条记录")
	assert_string_contains(lines[0], "将其击倒", "第一条显示击杀")
	assert_string_contains(lines[1], "没有可攻击的目标", "第二条不重复显示阵亡角色")
	var joined: String = _joined(lines)
	assert_eq(joined.count(str(CHAR_A)), 1, "阵亡角色名全批只出现一次")


# ═══════════════════════════════════════════════════════════════════════════════
# 5. 去重：播报不重播伤害飘字，批内重复载荷只播一次
# ═══════════════════════════════════════════════════════════════════════════════

func test_broadcast_does_not_replay_damage_floaters_and_dedupes_payloads() -> void:
	# Arrange——真实协调器 + 飘字探针；卡面注册两名角色（AI 可能选中任一）
	_use_immediate_scheduler([])
	broadcast.set_interval_ms(0)
	broadcast.setup([cs], 0, _resolver())
	_start([_enemy_state(&"grunt", 0)])
	var spy: SpyPool = SpyPool.new()
	coordinator = CoordinatorScript.new()
	add_child(coordinator)
	coordinator.call(&"setup", [cs], spy, Callable(cs, "get_character_hp"), false)
	for character_id: int in [CHAR_A, CHAR_B]:
		var card: Control = CardScript.new()
		add_child_autofree(card)
		coordinator.call(&"register_card", character_id, card)
	var damaged: Array = _capture_damaged()
	_advance_to(2)
	# Act——真实敌方行动
	cs.call("confirm_end_turn")
	_advance_to(0)
	await _wait_frames(2)
	# Assert——一次伤害：一次增量广播 / 一次飘字 / 一条战报
	assert_eq(damaged.size(), 1, "一次伤害只广播一次 character_damaged")
	assert_eq(spy.spawns.size(), 1, "只飘一次伤害数字")
	assert_eq(int(spy.spawns[0]), int(damaged[0]["damage"]), "飘字数值 = 落库增量")
	assert_eq(broadcast.line_count(), 1, "一条战报")
	assert_string_contains(broadcast.get_lines()[0], str(int(spy.spawns[0])),
			"战报与飘字描述同一次伤害")
	# Act——同一载荷重复投递两次（批内）
	var payload: Dictionary = {
		"enemy_id": 100000, "action": &"skill", "target_id": CHAR_A,
		"damage": 4, "is_kill": false, "known": true, "hp_after": 6,
	}
	broadcast.call(&"on_enemy_action", payload)
	broadcast.call(&"on_enemy_action", payload)
	await _wait_frames(2)
	# Assert——只播一条，且没有再飘字
	assert_eq(broadcast.line_count(), 1, "批内完全相同载荷只播一次")
	assert_eq(spy.spawns.size(), 1, "重播拦截不会触发第二次伤害飘字")
