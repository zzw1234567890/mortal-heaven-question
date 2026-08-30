extends GutTest
## Story 004 验收测试：渡劫结果 GSM 同步 + 场景恢复（cancel）。
##
## 覆盖 AC-001 到 AC-010（10 条 AC）。
## 测试策略：
##   - 使用 GSM Autoload + TribulationSystem 实例 + RealmSystem mock
##   - 验证 batch_updated 传播 + cancel + 清理 + serialize 最终状态
##
## 设计文档来源：GDD tribulation-system.md §状态与转换 + §2 渡劫准备阶段
## Story 来源：production/epics/tribulation-system/story-004-gsm-sync-cancel.md

const TS_SCRIPT := preload("res://src/feature/tribulation_system.gd")

var ts: Node = null
var gsm: Node = null
var _realm_mock: Node = null
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
	# RealmSystem mock
	_realm_mock = Node.new()
	_realm_mock.set_script(load("res://tests/unit/tribulation_system/realm_mock.gd"))
	_realm_mock._realm_up_calls = []
	ts.set("_realm_override", _realm_mock)


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
	if _realm_mock != null:
		_realm_mock.free()
		_realm_mock = null
	_batch_updates.clear()


func _on_batch_updated(changes: Dictionary) -> void:
	_batch_updates.append(changes.duplicate(true))


func _flush() -> void:
	await get_tree().process_frame


func _setup_preparing() -> void:
	gsm.player.cultivation = 1000
	gsm.player.max_cultivation = 1000
	ts.call("trigger_tribulation", TS_SCRIPT.TribulationType.NORMAL)


func _setup_in_combat() -> void:
	_setup_preparing()
	ts.call("_set_state", TS_SCRIPT.TribulationState.IN_COMBAT)


func _has_path(path: String) -> bool:
	for changes in _batch_updates:
		if changes.has(path):
			return true
	return false


# ============================================================================
# AC-001：渡劫成功后 batch_updated 传播 tribulation_state 变更
# ============================================================================

func test_ac001_success_batch_updated_tribulation_state() -> void:
	_setup_in_combat()
	_batch_updates.clear()
	ts.call("_handle_tribulation_success")
	await _flush()
	assert_true(_has_path("player.tribulation_state"), "成功后 batch_updated 含 tribulation_state")


# ============================================================================
# AC-002：渡劫失败后 batch_updated 传播 tribulation_state + cultivation 变更
# ============================================================================

func test_ac002_failure_batch_updated_tribulation_state() -> void:
	_setup_in_combat()
	gsm.player.cultivation = 1200
	gsm.player.max_cultivation = 1500
	_batch_updates.clear()
	ts.call("_handle_tribulation_failure")
	await _flush()
	assert_true(_has_path("player.tribulation_state"), "失败后 batch_updated 含 tribulation_state")


func test_ac002_failure_batch_updated_cultivation() -> void:
	_setup_in_combat()
	gsm.player.cultivation = 1200
	gsm.player.max_cultivation = 1500
	_batch_updates.clear()
	ts.call("_handle_tribulation_failure")
	await _flush()
	assert_true(_has_path("player.cultivation"), "失败后 batch_updated 含 cultivation")


# ============================================================================
# AC-003：渡劫成功后 batch_updated 传播 consecutive_tribulation_failures 重置
# ============================================================================

func test_ac003_success_batch_updated_failures_reset() -> void:
	_setup_in_combat()
	gsm.player.consecutive_tribulation_failures = 3
	_batch_updates.clear()
	ts.call("_handle_tribulation_success")
	await _flush()
	assert_true(_has_path("player.consecutive_tribulation_failures"), "成功后 batch_updated 含 consecutive_tribulation_failures")


# ============================================================================
# AC-004：cancel_tribulation 回到 NOT_READY
# ============================================================================

func test_ac004_cancel_returns_to_not_ready() -> void:
	_setup_preparing()
	ts.call("cancel_tribulation")
	await _flush()
	assert_eq(gsm.player.tribulation_state, TS_SCRIPT.TribulationState.NOT_READY, "cancel 后回到 NOT_READY")


# ============================================================================
# AC-005：取消渡劫后 _active_pills 清空 + _trib_type 重置
# ============================================================================

func test_ac005_cancel_clears_pills() -> void:
	_setup_preparing()
	ts.call("use_tribulation_pill", {"type": "lightning_protection", "rarity_tier": 1})
	ts.call("cancel_tribulation")
	var pills: Array = ts.get("_active_pills")
	assert_eq(pills.size(), 0, "cancel 后 _active_pills 清空")


func test_ac005_cancel_resets_trib_type() -> void:
	gsm.player.cultivation = 1000
	gsm.player.max_cultivation = 1000
	ts.call("trigger_tribulation", TS_SCRIPT.TribulationType.CROSS_REALM)
	ts.call("cancel_tribulation")
	assert_eq(ts.get("_trib_type"), TS_SCRIPT.TribulationType.NORMAL, "cancel 后 _trib_type=NORMAL")


# ============================================================================
# AC-006：非 PREPARING 状态调用 cancel_tribulation 被拒绝
# ============================================================================

func test_ac006_cancel_not_preparing_rejected() -> void:
	# NOT_READY 状态
	ts.call("cancel_tribulation")
	await _flush()
	assert_eq(gsm.player.tribulation_state, TS_SCRIPT.TribulationState.NOT_READY, "NOT_READY 状态 cancel 无效果")


func test_ac006_cancel_in_combat_rejected() -> void:
	_setup_in_combat()
	ts.call("cancel_tribulation")
	await _flush()
	assert_eq(gsm.player.tribulation_state, TS_SCRIPT.TribulationState.IN_COMBAT, "IN_COMBAT 状态 cancel 被拒绝")


# ============================================================================
# AC-007：渡劫结算后 _trib_type 和 _active_pills 被清理
# ============================================================================

func test_ac007_success_clears_trib_type() -> void:
	gsm.player.cultivation = 1000
	gsm.player.max_cultivation = 1000
	ts.call("trigger_tribulation", TS_SCRIPT.TribulationType.CROSS_REALM)
	ts.call("_set_state", TS_SCRIPT.TribulationState.IN_COMBAT)
	ts.call("_handle_tribulation_success")
	await _flush()
	assert_eq(ts.get("_trib_type"), TS_SCRIPT.TribulationType.NORMAL, "成功后 _trib_type=NORMAL")


func test_ac007_success_clears_pills() -> void:
	_setup_preparing()
	ts.call("use_tribulation_pill", {"type": "lightning_protection", "rarity_tier": 1})
	ts.call("_set_state", TS_SCRIPT.TribulationState.IN_COMBAT)
	ts.call("_handle_tribulation_success")
	await _flush()
	var pills: Array = ts.get("_active_pills")
	assert_eq(pills.size(), 0, "成功后 _active_pills 清空")


func test_ac007_failure_clears_trib_type() -> void:
	gsm.player.cultivation = 1000
	gsm.player.max_cultivation = 1000
	ts.call("trigger_tribulation", TS_SCRIPT.TribulationType.CROSS_REALM)
	ts.call("_set_state", TS_SCRIPT.TribulationState.IN_COMBAT)
	ts.call("_handle_tribulation_failure")
	await _flush()
	assert_eq(ts.get("_trib_type"), TS_SCRIPT.TribulationType.NORMAL, "失败后 _trib_type=NORMAL")


func test_ac007_failure_clears_pills() -> void:
	_setup_preparing()
	ts.call("use_tribulation_pill", {"type": "lightning_protection", "rarity_tier": 1})
	ts.call("_set_state", TS_SCRIPT.TribulationState.IN_COMBAT)
	ts.call("_handle_tribulation_failure")
	await _flush()
	var pills: Array = ts.get("_active_pills")
	assert_eq(pills.size(), 0, "失败后 _active_pills 清空")


# ============================================================================
# AC-008：get_tribulation_status 在结算后返回 NOT_READY
# ============================================================================

func test_ac008_status_after_success() -> void:
	_setup_in_combat()
	ts.call("_handle_tribulation_success")
	await _flush()
	var status: Dictionary = ts.call("get_tribulation_status")
	assert_eq(status["state"], TS_SCRIPT.TribulationState.NOT_READY, "成功后 state=NOT_READY")


func test_ac008_status_after_failure() -> void:
	_setup_in_combat()
	ts.call("_handle_tribulation_failure")
	await _flush()
	var status: Dictionary = ts.call("get_tribulation_status")
	assert_eq(status["state"], TS_SCRIPT.TribulationState.NOT_READY, "失败后 state=NOT_READY")


func test_ac008_status_after_cancel() -> void:
	_setup_preparing()
	ts.call("cancel_tribulation")
	await _flush()
	var status: Dictionary = ts.call("get_tribulation_status")
	assert_eq(status["state"], TS_SCRIPT.TribulationState.NOT_READY, "cancel 后 state=NOT_READY")


# ============================================================================
# AC-009：连续失败计数器在成功后重置为 0
# ============================================================================

func test_ac009_success_resets_failures_zero() -> void:
	_setup_in_combat()
	gsm.player.consecutive_tribulation_failures = 5
	ts.call("_handle_tribulation_success")
	await _flush()
	assert_eq(gsm.player.consecutive_tribulation_failures, 0, "成功后 consecutive_failures=0")


func test_ac009_failure_increments_failures() -> void:
	_setup_in_combat()
	gsm.player.consecutive_tribulation_failures = 0
	ts.call("_handle_tribulation_failure")
	await _flush()
	assert_eq(gsm.player.consecutive_tribulation_failures, 1, "失败后 consecutive_failures=1")


# ============================================================================
# AC-010：渡劫结算后 GSM serialize 包含正确的最终状态
# ============================================================================

func test_ac010_serialize_after_success() -> void:
	_setup_in_combat()
	gsm.player.consecutive_tribulation_failures = 3
	ts.call("_handle_tribulation_success")
	await _flush()
	var serializer: RefCounted = gsm.get("_serializer")
	var data: Dictionary = serializer.serialize()
	assert_eq(data["player"]["tribulation_state"], 0, "serialize tribulation_state=0 (NOT_READY)")
	assert_eq(data["player"]["consecutive_tribulation_failures"], 0, "serialize consecutive_failures=0")
	# realm_up mock 将 realm +1
	assert_eq(data["player"]["realm"], 2, "serialize realm=2（升级后）")


func test_ac010_serialize_after_failure() -> void:
	_setup_in_combat()
	gsm.player.cultivation = 1200
	gsm.player.max_cultivation = 1500
	gsm.player.consecutive_tribulation_failures = 1
	ts.call("_handle_tribulation_failure")
	await _flush()
	var serializer: RefCounted = gsm.get("_serializer")
	var data: Dictionary = serializer.serialize()
	assert_eq(data["player"]["tribulation_state"], 0, "serialize tribulation_state=0 (NOT_READY)")
	assert_eq(data["player"]["consecutive_tribulation_failures"], 2, "serialize consecutive_failures=2")
	assert_eq(data["player"]["cultivation"], 975, "serialize cultivation=975（扣除后）")
	assert_eq(data["player"]["realm"], 1, "serialize realm=1（未升级）")
