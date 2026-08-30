extends GutTest
## Story 001 验收测试：渡劫流程编排 + TribulationState 状态机。
##
## 覆盖 AC-001 到 AC-010（10 条 AC）。
## 测试策略：
##   - 使用 GSM Autoload + TribulationSystem 实例
##   - 验证枚举值 + 状态转换 + 触发条件 + 信号声明 + GSM 持久化
##
## 设计文档来源：GDD tribulation-system.md §1-7 + §状态与转换
## Story 来源：production/epics/tribulation-system/story-001-tribulation-state-machine.md

const TS_SCRIPT := preload("res://src/feature/tribulation_system.gd")

var ts: Node = null
var gsm: Node = null
var _batch_updates: Array = []


func before_each() -> void:
	ts = TS_SCRIPT.new()
	gsm = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/GameStateManager")
	if gsm == null:
		fail_test("GSM Autoload 未注册")
		return
	gsm.player.cultivation = 0
	gsm.player.max_cultivation = 1000
	gsm.player.cultivation_full = false
	gsm.player.realm = 1
	gsm.player.tribulation_state = 0
	gsm.player.consecutive_tribulation_failures = 0
	gsm.set("_signal_chain_depth", 0)
	gsm.get("_signal_router").set("_pending_changes", [])
	_batch_updates.clear()
	gsm.batch_updated.connect(_on_batch_updated)


func after_each() -> void:
	if gsm != null:
		if gsm.batch_updated.is_connected(_on_batch_updated):
			gsm.batch_updated.disconnect(_on_batch_updated)
		gsm.player.cultivation = 0
		gsm.player.max_cultivation = 1000
		gsm.player.cultivation_full = false
		gsm.player.realm = 1
		gsm.player.tribulation_state = 0
		gsm.player.consecutive_tribulation_failures = 0
	if ts != null:
		ts.free()
		ts = null
	_batch_updates.clear()


func _on_batch_updated(changes: Dictionary) -> void:
	_batch_updates.append(changes.duplicate(true))


func _flush() -> void:
	await get_tree().process_frame


# ============================================================================
# AC-001：TribulationState + TribulationType 枚举值正确
# ============================================================================

func test_ac001_tribulation_state_enum_values() -> void:
	assert_eq(TS_SCRIPT.TribulationState.NOT_READY, 0, "NOT_READY=0")
	assert_eq(TS_SCRIPT.TribulationState.READY, 1, "READY=1")
	assert_eq(TS_SCRIPT.TribulationState.PREPARING, 2, "PREPARING=2")
	assert_eq(TS_SCRIPT.TribulationState.IN_COMBAT, 3, "IN_COMBAT=3")
	assert_eq(TS_SCRIPT.TribulationState.SUCCESS, 4, "SUCCESS=4")
	assert_eq(TS_SCRIPT.TribulationState.FAILED, 5, "FAILED=5")


func test_ac001_tribulation_type_enum_values() -> void:
	assert_eq(TS_SCRIPT.TribulationType.NORMAL, 0, "NORMAL=0")
	assert_eq(TS_SCRIPT.TribulationType.CROSS_REALM, 1, "CROSS_REALM=1")


# ============================================================================
# AC-002：TribulationSystem 实例化无报错
# ============================================================================

func test_ac002_instance_creation() -> void:
	assert_not_null(ts, "TribulationSystem 实例化成功")
	assert_true(ts is Node, "是 Node 类型")


# ============================================================================
# AC-003：serializer 默认值包含新字段
# ============================================================================

func test_ac003_serializer_defaults_tribulation_state() -> void:
	var serializer: RefCounted = gsm.get("_serializer")
	var defaults: Dictionary = serializer._get_default_for_domain("player")
	assert_true(defaults.has("tribulation_state"), "player 默认值含 tribulation_state")
	assert_eq(defaults["tribulation_state"], 0, "默认 tribulation_state=0 (NOT_READY)")


func test_ac003_serializer_defaults_consecutive_failures() -> void:
	var serializer: RefCounted = gsm.get("_serializer")
	var defaults: Dictionary = serializer._get_default_for_domain("player")
	assert_true(defaults.has("consecutive_tribulation_failures"), "player 默认值含 consecutive_tribulation_failures")
	assert_eq(defaults["consecutive_tribulation_failures"], 0, "默认 consecutive_tribulation_failures=0")


# ============================================================================
# AC-004：_set_tribulation_state / _set_consecutive_tribulation_failures 写入 + batch_updated 传播
# ============================================================================

func test_ac004_set_tribulation_state_writes() -> void:
	gsm._set_tribulation_state(TS_SCRIPT.TribulationState.PREPARING)
	await _flush()
	assert_eq(gsm.player.tribulation_state, TS_SCRIPT.TribulationState.PREPARING, "tribulation_state 写入 PREPARING")


func test_ac004_set_tribulation_state_batch_updated() -> void:
	gsm._set_tribulation_state(TS_SCRIPT.TribulationState.IN_COMBAT)
	await _flush()
	var found: bool = false
	for changes in _batch_updates:
		if changes.has("player.tribulation_state"):
			found = true
	assert_true(found, "batch_updated 含 player.tribulation_state 路径")


func test_ac004_set_tribulation_state_dedup() -> void:
	gsm._set_tribulation_state(TS_SCRIPT.TribulationState.PREPARING)
	await _flush()
	_batch_updates.clear()
	gsm._set_tribulation_state(TS_SCRIPT.TribulationState.PREPARING)  # 同值
	await _flush()
	assert_eq(_batch_updates.size(), 0, "同值去重——不发射 batch_updated")


func test_ac004_set_consecutive_failures_writes() -> void:
	gsm._set_consecutive_tribulation_failures(3)
	await _flush()
	assert_eq(gsm.player.consecutive_tribulation_failures, 3, "consecutive_tribulation_failures 写入 3")


func test_ac004_set_consecutive_failures_batch_updated() -> void:
	gsm._set_consecutive_tribulation_failures(2)
	await _flush()
	var found: bool = false
	for changes in _batch_updates:
		if changes.has("player.consecutive_tribulation_failures"):
			found = true
	assert_true(found, "batch_updated 含 player.consecutive_tribulation_failures 路径")


func test_ac004_set_consecutive_failures_negative_rejected() -> void:
	gsm._set_consecutive_tribulation_failures(-1)
	await _flush()
	assert_eq(gsm.player.consecutive_tribulation_failures, 0, "负值被拒绝")


# ============================================================================
# AC-005：check_tribulation_ready 满值时 true
# ============================================================================

func test_ac005_ready_true_when_full() -> void:
	gsm.player.cultivation = 1000
	gsm.player.max_cultivation = 1000
	assert_eq(ts.call("check_tribulation_ready"), true, "修为满值时可渡劫")


func test_ac005_ready_false_when_not_full() -> void:
	gsm.player.cultivation = 800
	gsm.player.max_cultivation = 1000
	assert_eq(ts.call("check_tribulation_ready"), false, "修为未满不可渡劫")


func test_ac005_ready_false_when_in_progress() -> void:
	gsm.player.cultivation = 1000
	gsm.player.max_cultivation = 1000
	gsm.player.tribulation_state = TS_SCRIPT.TribulationState.PREPARING
	assert_eq(ts.call("check_tribulation_ready"), false, "已在渡劫流程中不可再次触发")


# ============================================================================
# AC-006：trigger_tribulation 进入 PREPARING + 发射信号
# ============================================================================

func test_ac006_trigger_enters_preparing() -> void:
	gsm.player.cultivation = 1000
	gsm.player.max_cultivation = 1000
	ts.call("trigger_tribulation", TS_SCRIPT.TribulationType.NORMAL)
	await _flush()
	assert_eq(gsm.player.tribulation_state, TS_SCRIPT.TribulationState.PREPARING, "trigger 后进入 PREPARING")


func test_ac006_trigger_not_ready_rejected() -> void:
	gsm.player.cultivation = 500
	gsm.player.max_cultivation = 1000
	ts.call("trigger_tribulation", TS_SCRIPT.TribulationType.NORMAL)
	await _flush()
	assert_eq(gsm.player.tribulation_state, TS_SCRIPT.TribulationState.NOT_READY, "未满时 trigger 被拒绝")


func test_ac006_trigger_cross_realm_realm_5_rejected() -> void:
	gsm.player.cultivation = 1000
	gsm.player.max_cultivation = 1000
	gsm.player.realm = 5  # 最高境界
	ts.call("trigger_tribulation", TS_SCRIPT.TribulationType.CROSS_REALM)
	await _flush()
	assert_eq(gsm.player.tribulation_state, TS_SCRIPT.TribulationState.NOT_READY, "最高境界越阶渡劫被拒绝")


func test_ac006_trigger_cross_realm_realm_4_allowed() -> void:
	gsm.player.cultivation = 1000
	gsm.player.max_cultivation = 1000
	gsm.player.realm = 4  # 可越阶到 5
	ts.call("trigger_tribulation", TS_SCRIPT.TribulationType.CROSS_REALM)
	await _flush()
	assert_eq(gsm.player.tribulation_state, TS_SCRIPT.TribulationState.PREPARING, "realm=4 越阶渡劫允许")


# ============================================================================
# AC-007：5 个 Cat 2b 信号声明存在
# ============================================================================

func test_ac007_signals_exist() -> void:
	assert_true(ts.has_signal("tribulation_triggered"), "信号 tribulation_triggered 存在")
	assert_true(ts.has_signal("tribulation_preparation_started"), "信号 tribulation_preparation_started 存在")
	assert_true(ts.has_signal("tribulation_succeeded"), "信号 tribulation_succeeded 存在")
	assert_true(ts.has_signal("tribulation_failed"), "信号 tribulation_failed 存在")
	assert_true(ts.has_signal("tribulation_protection_unlocked"), "信号 tribulation_protection_unlocked 存在")


# ============================================================================
# AC-008：非法状态转换被拒绝
# ============================================================================

func test_ac008_illegal_transition_not_ready_to_in_combat() -> void:
	# NOT_READY → IN_COMBAT 非法
	ts.call("_set_state", TS_SCRIPT.TribulationState.IN_COMBAT)
	await _flush()
	assert_eq(gsm.player.tribulation_state, TS_SCRIPT.TribulationState.NOT_READY, "NOT_READY→IN_COMBAT 被拒绝")


func test_ac008_illegal_transition_not_ready_to_success() -> void:
	ts.call("_set_state", TS_SCRIPT.TribulationState.SUCCESS)
	await _flush()
	assert_eq(gsm.player.tribulation_state, TS_SCRIPT.TribulationState.NOT_READY, "NOT_READY→SUCCESS 被拒绝")


func test_ac008_legal_transition_not_ready_to_preparing() -> void:
	ts.call("_set_state", TS_SCRIPT.TribulationState.PREPARING)
	await _flush()
	assert_eq(gsm.player.tribulation_state, TS_SCRIPT.TribulationState.PREPARING, "NOT_READY→PREPARING 合法")


func test_ac008_legal_transition_preparing_to_in_combat() -> void:
	ts.call("_set_state", TS_SCRIPT.TribulationState.PREPARING)
	await _flush()
	ts.call("_set_state", TS_SCRIPT.TribulationState.IN_COMBAT)
	await _flush()
	assert_eq(gsm.player.tribulation_state, TS_SCRIPT.TribulationState.IN_COMBAT, "PREPARING→IN_COMBAT 合法")


func test_ac008_legal_transition_in_combat_to_success() -> void:
	ts.call("_set_state", TS_SCRIPT.TribulationState.PREPARING)
	await _flush()
	ts.call("_set_state", TS_SCRIPT.TribulationState.IN_COMBAT)
	await _flush()
	ts.call("_set_state", TS_SCRIPT.TribulationState.SUCCESS)
	await _flush()
	assert_eq(gsm.player.tribulation_state, TS_SCRIPT.TribulationState.SUCCESS, "IN_COMBAT→SUCCESS 合法")


func test_ac008_legal_transition_success_to_not_ready() -> void:
	ts.call("_set_state", TS_SCRIPT.TribulationState.PREPARING)
	await _flush()
	ts.call("_set_state", TS_SCRIPT.TribulationState.IN_COMBAT)
	await _flush()
	ts.call("_set_state", TS_SCRIPT.TribulationState.SUCCESS)
	await _flush()
	ts.call("_set_state", TS_SCRIPT.TribulationState.NOT_READY)
	await _flush()
	assert_eq(gsm.player.tribulation_state, TS_SCRIPT.TribulationState.NOT_READY, "SUCCESS→NOT_READY 合法")


# ============================================================================
# AC-009：get_tribulation_status 返回正确结构
# ============================================================================

func test_ac009_get_status_initial() -> void:
	var status: Dictionary = ts.call("get_tribulation_status")
	assert_eq(status["state"], TS_SCRIPT.TribulationState.NOT_READY, "初始 state=NOT_READY")
	assert_eq(status["consecutive_failures"], 0, "初始 consecutive_failures=0")
	assert_eq(status["trib_type"], TS_SCRIPT.TribulationType.NORMAL, "初始 trib_type=NORMAL")


func test_ac009_get_status_after_trigger() -> void:
	gsm.player.cultivation = 1000
	gsm.player.max_cultivation = 1000
	gsm.player.consecutive_tribulation_failures = 2
	ts.call("trigger_tribulation", TS_SCRIPT.TribulationType.CROSS_REALM)
	await _flush()
	var status: Dictionary = ts.call("get_tribulation_status")
	assert_eq(status["state"], TS_SCRIPT.TribulationState.PREPARING, "trigger 后 state=PREPARING")
	assert_eq(status["consecutive_failures"], 2, "consecutive_failures=2")
	assert_eq(status["trib_type"], TS_SCRIPT.TribulationType.CROSS_REALM, "trib_type=CROSS_REALM")


# ============================================================================
# AC-010：consecutive_tribulation_failures serialize/deserialize 往返
# ============================================================================

func test_ac010_consecutive_failures_serialize_roundtrip() -> void:
	gsm.player.consecutive_tribulation_failures = 3
	var serializer: RefCounted = gsm.get("_serializer")
	var data: Dictionary = serializer.serialize()
	assert_true(data["player"].has("consecutive_tribulation_failures"), "serialize 包含 consecutive_tribulation_failures")
	assert_eq(data["player"]["consecutive_tribulation_failures"], 3, "serialize 值=3")


func test_ac010_consecutive_failures_deserialize_roundtrip() -> void:
	gsm.player.consecutive_tribulation_failures = 5
	var serializer: RefCounted = gsm.get("_serializer")
	var data: Dictionary = serializer.serialize()

	# 重置然后反序列化
	gsm.player.consecutive_tribulation_failures = 0
	var ok: bool = serializer.deserialize(data)
	assert_true(ok, "deserialize 成功")
	assert_eq(gsm.player.consecutive_tribulation_failures, 5, "deserialize 后 consecutive_tribulation_failures=5")


func test_ac010_tribulation_state_serialize_roundtrip() -> void:
	gsm.player.tribulation_state = TS_SCRIPT.TribulationState.PREPARING
	var serializer: RefCounted = gsm.get("_serializer")
	var data: Dictionary = serializer.serialize()
	assert_true(data["player"].has("tribulation_state"), "serialize 包含 tribulation_state")
