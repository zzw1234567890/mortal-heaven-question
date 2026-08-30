extends GutTest
## Story 002 验收测试：卡组编辑 API + GSM deck.* 存储。
##
## 覆盖 AC-001 到 AC-010（10 条 AC）。
## 测试策略：
##   - 使用 GSM Autoload + DeckEditingSystem 实例 + ResourceSystem mock
##   - 验证散功/拆解 + 战利品编排
##
## 设计文档来源：GDD deck-editing-system.md §核心规则 #2/#3
## Story 来源：production/epics/deck-editing-system/story-002-deck-edit-api.md

const DS_SCRIPT := preload("res://src/feature/deck_editing_system.gd")

var ds: Node = null
var gsm: Node = null
var _resource_mock: Node = null
var _realm_mock: Node = null
var _batch_updates: Array = []


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
	gsm.player.resources.ling_shi = 1000
	gsm.set("_signal_chain_depth", 0)
	gsm.get("_signal_router").set("_pending_changes", [])
	_batch_updates.clear()
	gsm.batch_updated.connect(_on_batch_updated)
	# ResourceSystem mock
	_resource_mock = Node.new()
	_resource_mock.set_script(load("res://tests/unit/deck_editing_system/resource_mock.gd"))
	_resource_mock._ling_shi = 1000
	ds.set("_resource_override", _resource_mock)
	# RealmSystem mock
	_realm_mock = Node.new()
	_realm_mock.set_script(load("res://tests/unit/deck_editing_system/realm_mock.gd"))
	_realm_mock._deck_limits = {1: 20, 2: 25, 3: 30, 4: 35, 5: 40}
	ds.set("_realm_override", _realm_mock)


func after_each() -> void:
	if gsm != null:
		if gsm.batch_updated.is_connected(_on_batch_updated):
			gsm.batch_updated.disconnect(_on_batch_updated)
		gsm.deck.current_deck = []
		gsm.deck.slots = [null, null, null, null, null, null]
		gsm.deck.change_log = []
		gsm.deck.session_remove_count = 0
		gsm.deck.deck_limit_modifier = 0
		gsm.player.realm = 1
		gsm.player.resources.ling_shi = 0
	if ds != null:
		ds.free()
		ds = null
	if _resource_mock != null:
		_resource_mock.free()
		_resource_mock = null
	if _realm_mock != null:
		_realm_mock.free()
		_realm_mock = null
	_batch_updates.clear()


func _on_batch_updated(changes: Dictionary) -> void:
	_batch_updates.append(changes.duplicate(true))


func _flush() -> void:
	await get_tree().process_frame


func _has_path(path: String) -> bool:
	for changes in _batch_updates:
		if changes.has(path):
			return true
	return false


func _setup_deck_with_cards(count: int) -> void:
	var ids: Array = []
	for i in range(count):
		ids.append(i + 1)
	gsm.deck.current_deck = ids


# ============================================================================
# AC-001：execute_delete 成功扣灵石+移除卡牌+计数+1
# ============================================================================

func test_ac001_execute_delete_success() -> void:
	_setup_deck_with_cards(10)
	var result: bool = ds.call("execute_delete", 5)
	await _flush()
	assert_eq(result, true, "散功成功")
	assert_eq(gsm.deck.current_deck.size(), 9, "卡组从10→9张")
	assert_false(5 in gsm.deck.current_deck, "卡5已移除")
	assert_eq(_resource_mock._ling_shi, 1000 - 50, "灵石扣除50（首次散功）")
	assert_eq(gsm.deck.session_remove_count, 1, "session_remove_count=1")


# ============================================================================
# AC-002：get_delete_cost 首次=50，第二次=75
# ============================================================================

func test_ac002_delete_cost_first() -> void:
	assert_eq(ds.call("get_delete_cost"), 50, "首次散功费用=50")


func test_ac002_delete_cost_second() -> void:
	gsm.deck.session_remove_count = 1
	assert_eq(ds.call("get_delete_cost"), 75, "第二次散功费用=50+25=75")


func test_ac002_delete_cost_third() -> void:
	gsm.deck.session_remove_count = 2
	assert_eq(ds.call("get_delete_cost"), 100, "第三次散功费用=50+25×2=100")


# ============================================================================
# AC-003：execute_sell 成功加灵石+移除卡牌
# ============================================================================

func test_ac003_execute_sell_success() -> void:
	_setup_deck_with_cards(10)
	var result: bool = ds.call("execute_sell", 3)
	await _flush()
	assert_eq(result, true, "拆解成功")
	assert_eq(gsm.deck.current_deck.size(), 9, "卡组从10→9张")
	assert_false(3 in gsm.deck.current_deck, "卡3已移除")
	assert_eq(_resource_mock._ling_shi, 1000 + 10, "灵石增加10（白色拆解值）")


# ============================================================================
# AC-004：get_sell_price 返回 dismantle_value
# ============================================================================

func test_ac004_sell_price() -> void:
	var price: int = ds.call("get_sell_price", 1)
	assert_eq(price, 10, "白色卡等级1拆解值=10")


# ============================================================================
# AC-005：散功后 session_remove_count 递增（batch_updated 传播）
# ============================================================================

func test_ac005_session_remove_count_batch_updated() -> void:
	_setup_deck_with_cards(10)
	ds.call("execute_delete", 1)
	await _flush()
	assert_true(_has_path("deck.session_remove_count"), "batch_updated 含 session_remove_count")


# ============================================================================
# AC-006：散功时灵石不足被拒绝
# ============================================================================

func test_ac006_delete_insufficient_lingshi() -> void:
	_setup_deck_with_cards(10)
	_resource_mock._ling_shi = 30  # 不足50
	var result: bool = ds.call("execute_delete", 1)
	await _flush()
	assert_eq(result, false, "灵石不足被拒绝")
	assert_eq(gsm.deck.current_deck.size(), 10, "卡组不变")
	assert_eq(gsm.deck.session_remove_count, 0, "计数不递增")


# ============================================================================
# AC-007：拆解时灵石正确增加（batch_updated 传播）
# ============================================================================

func test_ac007_sell_lingshi_batch_updated() -> void:
	_setup_deck_with_cards(10)
	ds.call("execute_sell", 1)
	await _flush()
	assert_eq(_resource_mock._ling_shi, 1010, "灵石增加10")


# ============================================================================
# AC-008：散功低于最低张数保护时被拒绝
# ============================================================================

func test_ac008_delete_below_minimum_rejected() -> void:
	_setup_deck_with_cards(5)  # 最低5张
	var result: bool = ds.call("execute_delete", 1)
	await _flush()
	assert_eq(result, false, "5张时散功被拒绝（会低于5张）")
	assert_eq(gsm.deck.current_deck.size(), 5, "卡组不变")
	assert_eq(gsm.deck.session_remove_count, 0, "计数不递增")


# ============================================================================
# AC-009：generate_loot_options 返回 3 选项
# ============================================================================

func test_ac009_generate_loot_options_count() -> void:
	var options: Array = ds.call("generate_loot_options", {"type": "normal"})
	assert_eq(options.size(), 3, "返回3个选项")


func test_ac009_generate_loot_options_structure() -> void:
	var options: Array = ds.call("generate_loot_options", {"type": "normal"})
	for opt in options:
		assert_true(opt.has("type"), "选项含 type")
		assert_true(opt.has("data"), "选项含 data")


# ============================================================================
# AC-010：apply_loot_choice 应用选择
# ============================================================================

func test_ac010_apply_loot_choice_card() -> void:
	ds.call("generate_loot_options", {"type": "normal"})
	# 选项0和1是卡牌
	var result: bool = ds.call("apply_loot_choice", 0)
	await _flush()
	assert_eq(result, true, "选择卡牌选项成功")
	assert_eq(gsm.deck.current_deck.size(), 1, "卡组+1张")
	assert_eq(int(gsm.deck.current_deck[0]), 1001, "加入卡1001")


func test_ac010_apply_loot_choice_lingshi() -> void:
	ds.call("generate_loot_options", {"type": "normal"})
	# 选项2是灵石
	var result: bool = ds.call("apply_loot_choice", 2)
	await _flush()
	assert_eq(result, true, "选择灵石选项成功")
	assert_eq(_resource_mock._ling_shi, 1015, "灵石+15")


func test_ac010_apply_loot_choice_invalid_index() -> void:
	ds.call("generate_loot_options", {"type": "normal"})
	var result: bool = ds.call("apply_loot_choice", 99)
	assert_eq(result, false, "无效索引被拒绝")
