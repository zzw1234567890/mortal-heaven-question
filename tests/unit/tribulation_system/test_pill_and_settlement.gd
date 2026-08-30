extends GutTest
## Story 003 验收测试：渡劫丹辅助 + 成功/失败分支处理。
##
## 覆盖 AC-001 到 AC-010（10 条 AC）。
## 测试策略：
##   - 使用 GSM Autoload + TribulationSystem 实例 + RealmSystem mock
##   - 验证渡劫丹管理 + 成功/失败结算 + 信号发射 + 状态回转
##
## 设计文档来源：GDD tribulation-system.md §2/§4/§5/§7 + §公式 1
## Story 来源：production/epics/tribulation-system/story-003-pill-and-settlement.md

const TS_SCRIPT := preload("res://src/feature/tribulation_system.gd")

var ts: Node = null
var gsm: Node = null
var _realm_mock: Node = null
var _realm_up_calls: Array = []
var _signals_received: Dictionary = {}


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
	# RealmSystem mock
	_realm_mock = Node.new()
	_realm_mock.set_script(load("res://tests/unit/tribulation_system/realm_mock.gd"))
	_realm_mock._realm_up_calls = []
	ts.set("_realm_override", _realm_mock)
	_signals_received.clear()
	ts.tribulation_succeeded.connect(_on_succeeded)
	ts.tribulation_failed.connect(_on_failed)
	ts.tribulation_protection_unlocked.connect(_on_protection)


func after_each() -> void:
	if ts != null:
		if ts.tribulation_succeeded.is_connected(_on_succeeded):
			ts.tribulation_succeeded.disconnect(_on_succeeded)
		if ts.tribulation_failed.is_connected(_on_failed):
			ts.tribulation_failed.disconnect(_on_failed)
		if ts.tribulation_protection_unlocked.is_connected(_on_protection):
			ts.tribulation_protection_unlocked.disconnect(_on_protection)
		ts.free()
		ts = null
	if _realm_mock != null:
		_realm_mock.free()
		_realm_mock = null
	if gsm != null:
		gsm.player.cultivation = 0
		gsm.player.max_cultivation = 1000
		gsm.player.cultivation_full = false
		gsm.player.realm = 1
		gsm.player.tribulation_state = 0
		gsm.player.consecutive_tribulation_failures = 0
	_signals_received.clear()


func _on_succeeded(old_realm: int, new_realm: int, is_cross: bool) -> void:
	_signals_received["succeeded"] = {"old": old_realm, "new": new_realm, "is_cross": is_cross}


func _on_failed(penalty: int, realm_level: int) -> void:
	_signals_received["failed"] = {"penalty": penalty, "realm": realm_level}


func _on_protection() -> void:
	_signals_received["protection"] = true


func _flush() -> void:
	await get_tree().process_frame


func _setup_preparing() -> void:
	gsm.player.cultivation = 1000
	gsm.player.max_cultivation = 1000
	ts.call("trigger_tribulation", TS_SCRIPT.TribulationType.NORMAL)


func _setup_in_combat() -> void:
	_setup_preparing()
	ts.call("_set_state", TS_SCRIPT.TribulationState.IN_COMBAT)


# ============================================================================
# AC-001：use_tribulation_pill 返回 true
# ============================================================================

func test_ac001_use_pill_success() -> void:
	_setup_preparing()
	var pill := {"type": "lightning_protection", "rarity_tier": 1}
	assert_eq(ts.call("use_tribulation_pill", pill), true, "使用渡劫丹成功")


func test_ac001_use_pill_added_to_list() -> void:
	_setup_preparing()
	var pill := {"type": "lightning_protection", "rarity_tier": 1}
	ts.call("use_tribulation_pill", pill)
	var status: Dictionary = ts.call("get_tribulation_status")
	# _active_pills 不直接暴露，通过 _build_tribulation_config 检查
	ts.call("_set_state", TS_SCRIPT.TribulationState.IN_COMBAT)
	# _active_pills 在 start_tribulation_combat 中通过 config 传播——这里直接检查内部
	var pills: Array = ts.get("_active_pills")
	assert_eq(pills.size(), 1, "_active_pills 含 1 枚")


# ============================================================================
# AC-002：渡劫丹总上限 2 枚——第 3 枚被拒绝
# ============================================================================

func test_ac002_third_pill_rejected() -> void:
	_setup_preparing()
	ts.call("use_tribulation_pill", {"type": "lightning_protection", "rarity_tier": 1})
	ts.call("use_tribulation_pill", {"type": "focus", "rarity_tier": 1})
	var result: bool = ts.call("use_tribulation_pill", {"type": "break_through", "rarity_tier": 1})
	assert_eq(result, false, "第 3 枚渡劫丹被拒绝")


func test_ac002_max_two_pills_allowed() -> void:
	_setup_preparing()
	assert_eq(ts.call("use_tribulation_pill", {"type": "lightning_protection", "rarity_tier": 1}), true, "第1枚成功")
	assert_eq(ts.call("use_tribulation_pill", {"type": "focus", "rarity_tier": 1}), true, "第2枚成功")


# ============================================================================
# AC-003：同种不叠加——取最高稀有度版本
# ============================================================================

func test_ac003_same_type_higher_rarity_replaces() -> void:
	_setup_preparing()
	ts.call("use_tribulation_pill", {"type": "lightning_protection", "rarity_tier": 1})
	assert_eq(ts.call("use_tribulation_pill", {"type": "lightning_protection", "rarity_tier": 2}), true, "更高稀有度同种替换成功")
	var pills: Array = ts.get("_active_pills")
	assert_eq(pills.size(), 1, "仍为 1 枚（替换不新增）")
	assert_eq(int(pills[0]["rarity_tier"]), 2, "稀有度=2（更高版本）")


func test_ac003_same_type_lower_rarity_rejected() -> void:
	_setup_preparing()
	ts.call("use_tribulation_pill", {"type": "lightning_protection", "rarity_tier": 2})
	assert_eq(ts.call("use_tribulation_pill", {"type": "lightning_protection", "rarity_tier": 1}), false, "更低稀有度被拒绝")


func test_ac003_same_type_equal_rarity_rejected() -> void:
	_setup_preparing()
	ts.call("use_tribulation_pill", {"type": "lightning_protection", "rarity_tier": 1})
	assert_eq(ts.call("use_tribulation_pill", {"type": "lightning_protection", "rarity_tier": 1}), false, "等同稀有度被拒绝")


# ============================================================================
# AC-004：非 PREPARING 状态使用渡劫丹被拒绝
# ============================================================================

func test_ac004_not_preparing_rejected() -> void:
	# NOT_READY 状态
	var result: bool = ts.call("use_tribulation_pill", {"type": "lightning_protection", "rarity_tier": 1})
	assert_eq(result, false, "NOT_READY 状态被拒绝")


func test_ac004_in_combat_rejected() -> void:
	_setup_in_combat()
	var result: bool = ts.call("use_tribulation_pill", {"type": "lightning_protection", "rarity_tier": 1})
	assert_eq(result, false, "IN_COMBAT 状态被拒绝")


# ============================================================================
# AC-005：_handle_tribulation_success 调用 realm_up + 重置计数 + 发射信号
# ============================================================================

func test_ac005_success_calls_realm_up() -> void:
	_setup_in_combat()
	gsm.player.consecutive_tribulation_failures = 2
	ts.call("_handle_tribulation_success")
	var calls: Array = _realm_mock._realm_up_calls
	assert_eq(calls.size(), 1, "realm_up 被调用 1 次")
	assert_eq(int(calls[0]), 1, "realm_up 参数 = old_realm=1")


func test_ac005_success_resets_failures() -> void:
	_setup_in_combat()
	gsm.player.consecutive_tribulation_failures = 3
	ts.call("_handle_tribulation_success")
	await _flush()
	assert_eq(gsm.player.consecutive_tribulation_failures, 0, "失败计数重置为 0")


func test_ac005_success_emits_signal() -> void:
	_setup_in_combat()
	ts.call("_handle_tribulation_success")
	assert_true(_signals_received.has("succeeded"), "tribulation_succeeded 信号已发射")
	assert_eq(_signals_received["succeeded"]["old"], 1, "old_realm=1")
	# realm_up mock 会将 realm +1
	assert_eq(_signals_received["succeeded"]["new"], 2, "new_realm=2")


# ============================================================================
# AC-006：_handle_tribulation_failure 修为扣除 + 失败计数+1 + 发射信号
# ============================================================================

func test_ac006_failure_penalty_calculation() -> void:
	_setup_in_combat()
	gsm.player.cultivation = 1200
	gsm.player.max_cultivation = 1500
	ts.call("_handle_tribulation_failure")
	await _flush()
	# penalty = floor(1500 × 0.15) = 225; new_cult = 1200 - 225 = 975
	assert_eq(gsm.player.cultivation, 975, "修为从1200扣除225→975")


func test_ac006_failure_penalty_floor_zero() -> void:
	_setup_in_combat()
	gsm.player.cultivation = 30
	gsm.player.max_cultivation = 1500
	ts.call("_handle_tribulation_failure")
	await _flush()
	# penalty=225, current=30 → max(30-225, 0) = 0
	assert_eq(gsm.player.cultivation, 0, "修为不会低于0")


func test_ac006_failure_increments_count() -> void:
	_setup_in_combat()
	gsm.player.consecutive_tribulation_failures = 0
	ts.call("_handle_tribulation_failure")
	await _flush()
	assert_eq(gsm.player.consecutive_tribulation_failures, 1, "失败计数 0→1")


func test_ac006_failure_emits_signal() -> void:
	_setup_in_combat()
	gsm.player.cultivation = 1200
	gsm.player.max_cultivation = 1500
	ts.call("_handle_tribulation_failure")
	assert_true(_signals_received.has("failed"), "tribulation_failed 信号已发射")
	assert_eq(_signals_received["failed"]["penalty"], 225, "penalty=225")
	assert_eq(_signals_received["failed"]["realm"], 1, "realm=1")


# ============================================================================
# AC-007：连续失败 ≥3 时发射 tribulation_protection_unlocked
# ============================================================================

func test_ac007_protection_unlocked_at_3() -> void:
	_setup_in_combat()
	gsm.player.consecutive_tribulation_failures = 2  # 本次失败后 = 3
	ts.call("_handle_tribulation_failure")
	assert_true(_signals_received.has("protection"), "连续3次失败发射 protection_unlocked")


func test_ac007_protection_not_unlocked_below_3() -> void:
	_setup_in_combat()
	gsm.player.consecutive_tribulation_failures = 1  # 本次失败后 = 2
	ts.call("_handle_tribulation_failure")
	assert_false(_signals_received.has("protection"), "连续2次不发射 protection")


func test_ac007_protection_unlocked_above_3() -> void:
	_setup_in_combat()
	gsm.player.consecutive_tribulation_failures = 5  # 本次失败后 = 6
	ts.call("_handle_tribulation_failure")
	assert_true(_signals_received.has("protection"), "连续6次仍发射 protection")


# ============================================================================
# AC-008：_on_battle_ended VICTORY→_handle_success，DEFEAT→_handle_failure
# ============================================================================

func test_ac008_victory_calls_success() -> void:
	_setup_in_combat()
	ts.call("_on_battle_ended", 0, {})  # VICTORY
	await _flush()
	assert_true(_signals_received.has("succeeded"), "VICTORY 触发 _handle_success")


func test_ac008_defeat_calls_failure() -> void:
	_setup_in_combat()
	ts.call("_on_battle_ended", 1, {})  # DEFEAT
	await _flush()
	assert_true(_signals_received.has("failed"), "DEFEAT 触发 _handle_failure")


# ============================================================================
# AC-009：渡劫成功后状态回到 NOT_READY
# ============================================================================

func test_ac009_success_returns_to_not_ready() -> void:
	_setup_in_combat()
	ts.call("_handle_tribulation_success")
	await _flush()
	assert_eq(gsm.player.tribulation_state, TS_SCRIPT.TribulationState.NOT_READY, "成功后回到 NOT_READY")


# ============================================================================
# AC-010：渡劫失败后状态回到 NOT_READY
# ============================================================================

func test_ac010_failure_returns_to_not_ready() -> void:
	_setup_in_combat()
	ts.call("_handle_tribulation_failure")
	await _flush()
	assert_eq(gsm.player.tribulation_state, TS_SCRIPT.TribulationState.NOT_READY, "失败后回到 NOT_READY")
