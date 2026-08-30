extends GutTest
## Story 004 验收测试：卡组验证 UI 数据源接口。
##
## 覆盖 AC-001 到 AC-010（10 条 AC）。
## 测试策略：
##   - 使用 GSM Autoload + DeckEditingSystem 实例
##   - 验证 UI 查询接口返回正确数据 + 只读不修改 GSM
##
## 设计文档来源：GDD deck-editing-system.md §核心规则 #2/#3/#5/#7
## Story 来源：production/epics/deck-editing-system/story-004-ui-data-source.md

const DS_SCRIPT := preload("res://src/feature/deck_editing_system.gd")

var ds: Node = null
var gsm: Node = null
var _realm_mock: Node = null
var _resource_mock: Node = null


func before_each() -> void:
	ds = DS_SCRIPT.new()
	gsm = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/GameStateManager")
	if gsm == null:
		fail_test("GSM Autoload 未注册")
		return
	gsm.deck.current_deck = []
	gsm.deck.slots = [null, null, null, null, null, null]
	gsm.deck.change_log = []
	gsm.deck.session_remove_count = 0
	gsm.deck.deck_limit_modifier = 0
	gsm.player.realm = 1
	gsm.set("_signal_chain_depth", 0)
	gsm.get("_signal_router").set("_pending_changes", [])
	# RealmSystem mock
	_realm_mock = Node.new()
	_realm_mock.set_script(load("res://tests/unit/deck_editing_system/realm_mock.gd"))
	_realm_mock._deck_limits = {1: 20, 2: 25, 3: 30, 4: 35, 5: 40}
	ds.set("_realm_override", _realm_mock)
	# ResourceSystem mock
	_resource_mock = Node.new()
	_resource_mock.set_script(load("res://tests/unit/deck_editing_system/resource_mock.gd"))
	_resource_mock._ling_shi = 1000
	ds.set("_resource_override", _resource_mock)


func after_each() -> void:
	if gsm != null:
		gsm.deck.current_deck = []
		gsm.deck.slots = [null, null, null, null, null, null]
		gsm.deck.change_log = []
		gsm.deck.session_remove_count = 0
		gsm.deck.deck_limit_modifier = 0
		gsm.player.realm = 1
	if ds != null:
		ds.free()
		ds = null
	if _realm_mock != null:
		_realm_mock.free()
		_realm_mock = null
	if _resource_mock != null:
		_resource_mock.free()
		_resource_mock = null


func _flush() -> void:
	await get_tree().process_frame


func _setup_deck(count: int) -> void:
	var ids: Array = []
	for i in range(count):
		ids.append(i + 1)
	gsm.deck.current_deck = ids


# ============================================================================
# AC-001：get_deck_summary 返回正确摘要
# ============================================================================

func test_ac001_deck_summary_structure() -> void:
	var summary: Dictionary = ds.call("get_deck_summary")
	assert_true(summary.has("total"), "含 total")
	assert_true(summary.has("limit"), "含 limit")
	assert_true(summary.has("is_full"), "含 is_full")
	assert_true(summary.has("is_minimal"), "含 is_minimal")


func test_ac001_deck_summary_values() -> void:
	_setup_deck(10)
	var summary: Dictionary = ds.call("get_deck_summary")
	assert_eq(summary["total"], 10, "total=10")
	assert_eq(summary["limit"], 20, "limit=20（炼气）")
	assert_eq(summary["is_full"], false, "10<20→未满")
	assert_eq(summary["is_minimal"], false, "10>5→非最低")


func test_ac001_deck_summary_full() -> void:
	_setup_deck(20)
	var summary: Dictionary = ds.call("get_deck_summary")
	assert_eq(summary["is_full"], true, "20=20→已满")


func test_ac001_deck_summary_minimal() -> void:
	_setup_deck(5)
	var summary: Dictionary = ds.call("get_deck_summary")
	assert_eq(summary["is_minimal"], true, "5<=5→最低")


# ============================================================================
# AC-002：get_change_log 返回日志副本
# ============================================================================

func test_ac002_get_change_log() -> void:
	gsm.deck.change_log = [{"card_id": 1, "action": "add"}]
	var log: Array = ds.call("get_change_log")
	assert_eq(log.size(), 1, "返回1条日志")
	assert_eq(int(log[0]["card_id"]), 1, "card_id=1")


func test_ac002_get_change_log_is_copy() -> void:
	gsm.deck.change_log = [{"card_id": 1, "action": "add"}]
	var log: Array = ds.call("get_change_log")
	log.clear()
	assert_eq(gsm.deck.change_log.size(), 1, "修改副本不影响 GSM")


# ============================================================================
# AC-003：get_deck_limit 返回境界上限
# ============================================================================

func test_ac003_get_deck_limit() -> void:
	gsm.player.realm = 3
	assert_eq(ds.call("get_deck_limit"), 30, "金丹期 limit=30")


# ============================================================================
# AC-004：get_session_remove_count 返回散功次数
# ============================================================================

func test_ac004_get_session_remove_count() -> void:
	gsm.deck.session_remove_count = 4
	assert_eq(ds.call("get_session_remove_count"), 4, "remove_count=4")


# ============================================================================
# AC-005：get_delete_cost 返回散功费用
# ============================================================================

func test_ac005_get_delete_cost() -> void:
	gsm.deck.session_remove_count = 0
	assert_eq(ds.call("get_delete_cost"), 50, "首次散功费用=50")


func test_ac005_get_delete_cost_second() -> void:
	gsm.deck.session_remove_count = 1
	assert_eq(ds.call("get_delete_cost"), 75, "第二次散功费用=75")


# ============================================================================
# AC-006：can_add_to_deck reason 可供 UI 显示
# ============================================================================

func test_ac006_can_add_reason_displayable() -> void:
	_setup_deck(20)
	var result: Dictionary = ds.call("can_add_to_deck", 1)
	assert_eq(result["allowed"], false, "已满拒绝")
	assert_true(str(result["reason"]).length() > 0, "reason 非空")
	assert_true("上限" in str(result["reason"]), "reason 含'上限'关键字")


func test_ac006_can_add_reason_when_allowed() -> void:
	_setup_deck(5)
	var result: Dictionary = ds.call("can_add_to_deck", 1)
	assert_eq(result["allowed"], true, "允许添加")
	assert_eq(str(result["reason"]), "", "reason 为空（允许时）")


# ============================================================================
# AC-007：can_remove_from_deck reason 可供 UI 显示
# ============================================================================

func test_ac007_can_remove_reason_displayable() -> void:
	_setup_deck(5)
	var result: Dictionary = ds.call("can_remove_from_deck", 1)
	assert_eq(result["allowed"], false, "5张不可删")
	assert_true(str(result["reason"]).length() > 0, "reason 非空")
	assert_true("5" in str(result["reason"]), "reason 含'5'关键字")


func test_ac007_can_remove_reason_when_allowed() -> void:
	_setup_deck(10)
	var result: Dictionary = ds.call("can_remove_from_deck", 1)
	assert_eq(result["allowed"], true, "允许删除")
	assert_eq(str(result["reason"]), "", "reason 为空（允许时）")


# ============================================================================
# AC-008：get_loot_options 返回缓存选项
# ============================================================================

func test_ac008_get_loot_options_empty_initially() -> void:
	var options: Array = ds.call("get_loot_options")
	assert_eq(options.size(), 0, "初始无缓存选项")


func test_ac008_get_loot_options_after_generate() -> void:
	ds.call("generate_loot_options", {"type": "normal"})
	var options: Array = ds.call("get_loot_options")
	assert_eq(options.size(), 3, "generate 后返回3个选项")


func test_ac008_get_loot_options_is_copy() -> void:
	ds.call("generate_loot_options", {"type": "normal"})
	var options: Array = ds.call("get_loot_options")
	options.clear()
	var options2: Array = ds.call("get_loot_options")
	assert_eq(options2.size(), 3, "修改副本不影响内部缓存")


# ============================================================================
# AC-009：get_deck_status 返回综合状态
# ============================================================================

func test_ac009_deck_status_structure() -> void:
	var status: Dictionary = ds.call("get_deck_status")
	assert_true(status.has("deck_count"), "含 deck_count")
	assert_true(status.has("deck_limit"), "含 deck_limit")
	assert_true(status.has("is_full"), "含 is_full")
	assert_true(status.has("remove_count"), "含 remove_count")
	assert_true(status.has("can_delete"), "含 can_delete")
	assert_true(status.has("delete_cost"), "含 delete_cost")


func test_ac009_deck_status_values() -> void:
	_setup_deck(10)
	gsm.deck.session_remove_count = 2
	var status: Dictionary = ds.call("get_deck_status")
	assert_eq(status["deck_count"], 10, "deck_count=10")
	assert_eq(status["deck_limit"], 20, "deck_limit=20")
	assert_eq(status["is_full"], false, "is_full=false")
	assert_eq(status["remove_count"], 2, "remove_count=2")
	assert_eq(status["can_delete"], true, "can_delete=true（10张>5可删）")
	assert_eq(status["delete_cost"], 100, "delete_cost=100（第三次）")


func test_ac009_deck_status_cannot_delete() -> void:
	_setup_deck(5)
	var status: Dictionary = ds.call("get_deck_status")
	assert_eq(status["can_delete"], false, "can_delete=false（5张不可删）")


# ============================================================================
# AC-010：UI 数据源接口全部为只读查询（不修改 GSM 状态）
# ============================================================================

func test_ac010_readonly_no_modification() -> void:
	_setup_deck(8)
	gsm.deck.change_log = [{"card_id": 1, "action": "add"}]
	gsm.deck.session_remove_count = 3
	# 调用所有查询接口
	ds.call("get_deck_summary")
	ds.call("get_change_log")
	ds.call("get_deck_limit")
	ds.call("get_session_remove_count")
	ds.call("get_delete_cost")
	ds.call("can_add_to_deck", 1)
	ds.call("can_remove_from_deck", 1)
	ds.call("get_loot_options")
	ds.call("get_deck_status")
	# 验证 GSM 状态未变
	assert_eq(gsm.deck.current_deck.size(), 8, "current_deck 不变")
	assert_eq(gsm.deck.change_log.size(), 1, "change_log 不变")
	assert_eq(gsm.deck.session_remove_count, 3, "session_remove_count 不变")
