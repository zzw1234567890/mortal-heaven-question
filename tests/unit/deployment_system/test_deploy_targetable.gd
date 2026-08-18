extends GutTest
## Story 002 验收测试：deploy / remove / is_targetable 前后排保护 O(1)。
##
## 覆盖 AC-001 到 AC-015（15 条 AC）。
## 测试策略：
##   - DS_SCRIPT.new() 构造 DeploymentSystem 实例（不调 _ready）
##   - 真实 RealmSystem/GSM Autoload——before_each 设置 player.realm 控制 max_deploy
##   - 信号时序：character_deployed/character_removed/front_line_breached 均为 Cat 2b 即时发射
##   - 动态分派：var ds: Node 持有，返回值显式类型注解（控制清单 2026-08-05 规则）
##
## 设计文档来源：ADR-0016 §前后排保护查询 §战中补位流程 §验证标准
## Story 来源：production/epics/deployment-system/story-002-deploy-remove-targetable.md

const DS_SCRIPT := preload("res://src/feature/deployment_system.gd")

var ds: Node = null
var _signal_callables: Array = []


func before_each() -> void:
	ds = DS_SCRIPT.new()
	_signal_callables.clear()


func after_each() -> void:
	_reset_realm()
	if ds != null:
		for callable: Callable in _signal_callables:
			for sig in [&"character_deployed", &"character_removed", &"front_line_breached"]:
				if ds.is_connected(sig, callable):
					ds.disconnect(sig, callable)
		_signal_callables.clear()
		ds.free()
		ds = null


func _set_realm(level: int) -> void:
	GameStateManager.player.realm = level


func _reset_realm() -> void:
	GameStateManager.player.realm = GameStateManager.RealmLevel.QI_REFINING


func _track_signal(signal_name: StringName, callable: Callable) -> void:
	ds.connect(signal_name, callable)
	_signal_callables.append(callable)


# ============================================================================
# AC-001：deploy 自动分配前排优先空位
# ============================================================================

func test_ac001_deploy_auto_front_first_empty() -> void:
	_set_realm(GameStateManager.RealmLevel.GOLDEN_CORE)  # max_deploy=4，前排配额 2
	# 手动布局：103 放后排 → slot 0/1（前排）+ slot 3（后排）占，slot 2（前排）+ 4/5（后排）空
	ds.setup_field([101, 102, 103], {103: false})
	var result: Dictionary = ds.deploy(200, 201, -1)
	assert_true(result["success"], "有 3 空位应成功")
	assert_eq(result["slot_index"], 2, "前排空位（slot 2）优先于后排（slot 4/5）")
	assert_eq(result["reason"], "deployed", "reason=deployed")


# ============================================================================
# AC-002：deploy 满员拒绝
# ============================================================================

func test_ac002_deploy_field_full_rejected() -> void:
	_set_realm(GameStateManager.RealmLevel.SPIRIT_TRANSFORMATION)
	ds.setup_field([101, 102, 103, 104, 105, 106], {})  # 满阵
	var result: Dictionary = ds.deploy(200, 201, -1)
	assert_false(result["success"], "满员应失败")
	assert_eq(result["slot_index"], -1, "slot_index=-1")
	assert_eq(result["reason"], "field_full", "reason=field_full")


# ============================================================================
# AC-003：deploy 无效槽位拒绝
# ============================================================================

func test_ac003_deploy_invalid_slot_occupied() -> void:
	_set_realm(GameStateManager.RealmLevel.SPIRIT_TRANSFORMATION)
	ds.setup_field([101, 102], {})  # slot 0/1 占用
	var result: Dictionary = ds.deploy(200, 201, 0)  # slot 0 已占用
	assert_false(result["success"], "已占用槽位应失败")
	assert_eq(result["reason"], "invalid_slot", "reason=invalid_slot")


func test_ac003_deploy_invalid_slot_out_of_range() -> void:
	_set_realm(GameStateManager.RealmLevel.SPIRIT_TRANSFORMATION)
	ds.setup_field([101], {})
	assert_false(ds.deploy(200, 201, 6)["success"], "slot 6 越界应失败")
	assert_false(ds.deploy(200, 201, -2)["success"], "slot -2 越界应失败")


# ============================================================================
# AC-004：deploy 不可用角色拒绝
# ============================================================================

func test_ac004_deploy_unavailable_character_rejected() -> void:
	_set_realm(GameStateManager.RealmLevel.SPIRIT_TRANSFORMATION)
	ds.setup_field([101], {})
	ds._unavailable_characters[999] = {"death_turn": 3, "death_battle_id": "b1"}
	var result: Dictionary = ds.deploy(200, 999, -1)
	assert_false(result["success"], "不可用角色应失败")
	assert_eq(result["reason"], "character_unavailable", "reason=character_unavailable")


# ============================================================================
# AC-005：deploy 后 STANDBY
# ============================================================================

func test_ac005_deploy_sets_standby() -> void:
	_set_realm(GameStateManager.RealmLevel.SPIRIT_TRANSFORMATION)
	ds.setup_field([101], {})
	ds.deploy(200, 201, -1)
	var slot: int = ds.get_character_slot(201)
	assert_eq(ds._field[slot]["state"], DS_SCRIPT.FieldState.STANDBY, "补位角色 STANDBY")
	assert_true(ds.is_standby(201), "is_standby(201) true")


# ============================================================================
# AC-006：character_deployed 信号载荷
# ============================================================================

func test_ac006_character_deployed_signal_payload() -> void:
	_set_realm(GameStateManager.RealmLevel.SPIRIT_TRANSFORMATION)
	ds.setup_field([101, 102, 103], {})  # 前 3 占
	var captured: Array = [null]
	var handler := func(cid: int, slot: int, is_front: bool, turn: int) -> void:
		captured[0] = {"cid": cid, "slot": slot, "is_front": is_front, "turn": turn}
	_track_signal(&"character_deployed", handler)

	ds.deploy(200, 201, 3)  # 指定 slot 3（后排）
	assert_not_null(captured[0], "信号应发射")
	assert_eq(captured[0]["cid"], 201, "载荷 character_id=201")
	assert_eq(captured[0]["slot"], 3, "载荷 slot_index=3")
	assert_false(captured[0]["is_front"], "slot 3 → 后排 false")
	assert_eq(captured[0]["turn"], 0, "载荷 deploy_turn=0（临时桩，待 CombatSystem 接入）")


# ============================================================================
# AC-007：remove_character 清空阵位
# ============================================================================

func test_ac007_remove_character_clears_slot() -> void:
	_set_realm(GameStateManager.RealmLevel.QI_REFINING)
	ds.setup_field([101, 102], {})  # slot 0/1
	var captured: Array = [null]
	var handler := func(cid: int, slot: int, reason: String) -> void:
		captured[0] = {"cid": cid, "slot": slot, "reason": reason}
	_track_signal(&"character_removed", handler)

	ds.remove_character(101)
	assert_eq(ds.get_character_slot(101), -1, "101 已离场")
	assert_eq(ds._field[0]["character_id"], -1, "slot 0 空位")
	assert_eq(ds._field[0]["state"], DS_SCRIPT.FieldState.EMPTY, "slot 0 EMPTY")
	assert_not_null(captured[0], "character_removed 信号发射")
	assert_eq(captured[0]["cid"], 101, "载荷 character_id=101")
	assert_eq(captured[0]["slot"], 0, "载荷 slot_index=0")


# ============================================================================
# AC-008：前排角色始终可攻击
# ============================================================================

func test_ac008_front_character_always_targetable() -> void:
	_set_realm(GameStateManager.RealmLevel.QI_REFINING)
	ds.setup_field([101], {})  # slot 0 前排
	assert_true(ds.is_targetable(101), "前排角色可攻击")


# ============================================================================
# AC-009：后排受保护（前排有存活）
# ============================================================================

func test_ac009_back_character_protected() -> void:
	_set_realm(GameStateManager.RealmLevel.GOLDEN_CORE)  # 前 2 后 2
	ds.setup_field([101, 102, 103, 104], {})  # 103/104 后排（slot 3/4）
	assert_false(ds.is_targetable(103, false), "前排有存活 → 后排受保护 false")


# ============================================================================
# AC-010：前排全灭后排暴露 + front_line_breached 信号
# ============================================================================

func test_ac010_back_exposed_when_front_dead() -> void:
	_set_realm(GameStateManager.RealmLevel.GOLDEN_CORE)
	ds.setup_field([101, 102, 103, 104], {})  # 前 2（slot 0/1）后 2（slot 3/4）
	# 前排 2 人全 DEAD
	ds._field[0]["state"] = DS_SCRIPT.FieldState.DEAD
	ds._field[1]["state"] = DS_SCRIPT.FieldState.DEAD

	var emitted: Array = [0]
	var handler := func() -> void:
		emitted[0] += 1
	_track_signal(&"front_line_breached", handler)

	assert_true(ds.is_targetable(103, false), "前排全灭 → 后排可攻击")
	assert_eq(emitted[0], 1, "front_line_breached 发射一次")
	assert_true(ds.is_targetable(103, false), "第二次调用仍可攻击")
	assert_eq(emitted[0], 1, "标志守卫——不重复发射")


# ============================================================================
# AC-011：穿透无视保护
# ============================================================================

func test_ac011_penetration_ignores_protection() -> void:
	_set_realm(GameStateManager.RealmLevel.GOLDEN_CORE)
	ds.setup_field([101, 102, 103, 104], {})
	assert_true(ds.is_targetable(103, true), "穿透 → 后排可攻击 true")


# ============================================================================
# AC-012：未上场角色不可攻击
# ============================================================================

func test_ac012_not_on_field_not_targetable() -> void:
	_set_realm(GameStateManager.RealmLevel.QI_REFINING)
	ds.setup_field([101], {})
	assert_false(ds.is_targetable(999), "未上场角色不可攻击")


# ============================================================================
# AC-013：阵亡角色不可攻击
# ============================================================================

func test_ac013_dead_character_not_targetable() -> void:
	_set_realm(GameStateManager.RealmLevel.QI_REFINING)
	ds.setup_field([101], {})  # slot 0 前排
	ds._field[0]["state"] = DS_SCRIPT.FieldState.DEAD
	assert_false(ds.is_targetable(101), "阵亡角色不可攻击")


# ============================================================================
# AC-014：补位前排恢复保护
# ============================================================================

func test_ac014_refill_front_restores_protection() -> void:
	_set_realm(GameStateManager.RealmLevel.GOLDEN_CORE)
	ds.setup_field([101, 102, 103, 104], {})  # 前 2（0/1）后 2（3/4）
	# 前排 2 人阵亡 → remove_character 清位（slot 0/1 变 EMPTY）
	ds.remove_character(101)
	ds.remove_character(102)
	assert_true(ds.is_targetable(103, false), "破防后后排可攻击")
	assert_true(ds._front_line_breached_emitted, "破防标志已置位")

	# 补位前排（slot 0 空位）
	var result: Dictionary = ds.deploy(200, 201, 0)
	assert_true(result["success"], "补位前排成功")
	assert_false(ds.is_targetable(103, false), "前排恢复 → 后排重新受保护")


# ============================================================================
# AC-015：Cat 2b 信号运行时行为
# ============================================================================

func test_ac015_signal_declared_and_emits() -> void:
	_set_realm(GameStateManager.RealmLevel.SPIRIT_TRANSFORMATION)
	ds.setup_field([101], {})
	var deployed_count: Array = [0]
	var removed_count: Array = [0]
	var breached_count: Array = [0]
	_track_signal(&"character_deployed", func(_a: int, _b: int, _c: bool, _d: int) -> void: deployed_count[0] += 1)
	_track_signal(&"character_removed", func(_a: int, _b: int, _c: String) -> void: removed_count[0] += 1)
	_track_signal(&"front_line_breached", func() -> void: breached_count[0] += 1)

	ds.deploy(200, 201, -1)
	ds.remove_character(201)
	assert_eq(deployed_count[0], 1, "deployed 发射")
	assert_eq(removed_count[0], 1, "removed 发射")


func test_ac015_front_line_breached_emits_runtime() -> void:
	_set_realm(GameStateManager.RealmLevel.GOLDEN_CORE)
	ds.setup_field([101, 102, 103, 104], {})  # 前 2 后 2
	ds.remove_character(101)
	ds.remove_character(102)
	var breached_count: Array = [0]
	_track_signal(&"front_line_breached", func() -> void: breached_count[0] += 1)

	ds.is_targetable(103, false)  # 前排全灭 → 后排可攻击 + 破防信号
	assert_eq(breached_count[0], 1, "front_line_breached 运行时发射一次")


# ============================================================================
# 实现暴露分支的回归测试（QA 预写用例之外）
# ============================================================================

func test_get_character_slot_negative_one_sentinel_guard() -> void:
	_set_realm(GameStateManager.RealmLevel.QI_REFINING)
	ds.setup_field([101], {})
	assert_eq(ds.get_character_slot(-1), -1, "-1 哨兵值不应误命中空位")


func test_deploy_already_on_field_rejected() -> void:
	_set_realm(GameStateManager.RealmLevel.SPIRIT_TRANSFORMATION)
	ds.setup_field([101], {})
	var result: Dictionary = ds.deploy(200, 101, -1)
	assert_false(result["success"], "已上场角色再 deploy 应失败")
	assert_eq(result["reason"], "invalid_slot", "reason=invalid_slot")


func test_remove_character_not_on_field_noop() -> void:
	_set_realm(GameStateManager.RealmLevel.QI_REFINING)
	ds.setup_field([101], {})
	ds.remove_character(999)  # 不在场上——无副作用
	assert_eq(ds.get_character_slot(101), 0, "场上角色不受影响")
	assert_eq(ds.get_field().size(), 6, "阵位结构不变")


func test_penetration_does_not_trigger_breach() -> void:
	_set_realm(GameStateManager.RealmLevel.GOLDEN_CORE)
	ds.setup_field([101, 102, 103, 104], {})  # 前 2 后 2
	# 前排有存活，穿透查询在第 4 步短路返回 true——不应触发破防信号
	var breached_count: Array = [0]
	_track_signal(&"front_line_breached", func() -> void: breached_count[0] += 1)
	assert_true(ds.is_targetable(103, true), "穿透后排可攻击")
	assert_eq(breached_count[0], 0, "穿透查询不触发破防信号")


func test_deploy_respects_max_deploy_limit() -> void:
	_set_realm(GameStateManager.RealmLevel.QI_REFINING)  # max_deploy=2
	ds.setup_field([101, 102], {})  # 已 2 人 = 境界上限
	var result: Dictionary = ds.deploy(200, 201, -1)
	assert_false(result["success"], "达 max_deploy 上限（未满 6 人）应失败")
	assert_eq(result["reason"], "field_full", "reason=field_full")
