extends GutTest
## Story 001 验收测试：卡组验证器（卡组上限/添加/移除校验）。
##
## 覆盖 AC-001 到 AC-010（10 条 AC）。
## 测试策略：
##   - 使用 GSM Autoload + DeckEditingSystem 实例 + RealmSystem mock
##   - 验证上限/下限校验 + 统一增删 + 变更日志 + GSM deck 域
##
## 设计文档来源：GDD deck-editing-system.md §核心规则 #3/#7
## Story 来源：production/epics/deck-editing-system/story-001-deck-validator.md

const DS_SCRIPT := preload("res://src/feature/deck_editing_system.gd")

var ds: Node = null
var gsm: Node = null
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
	gsm.set("_signal_chain_depth", 0)
	gsm.get("_signal_router").set("_pending_changes", [])
	_batch_updates.clear()
	gsm.batch_updated.connect(_on_batch_updated)
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
	if ds != null:
		ds.free()
		ds = null
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


# ============================================================================
# AC-001：can_add_to_deck 满时拒绝，未满时允许
# ============================================================================

func test_ac001_can_add_allowed() -> void:
	gsm.deck.current_deck = [1, 2, 3]
	var result: Dictionary = ds.call("can_add_to_deck", 1)
	assert_eq(result["allowed"], true, "3张+1未满20→允许")


func test_ac001_can_add_at_limit_rejected() -> void:
	gsm.deck.current_deck = range(1, 21)  # 20张
	var result: Dictionary = ds.call("can_add_to_deck", 1)
	assert_eq(result["allowed"], false, "20张+1=21>20→拒绝")


func test_ac001_can_add_with_modifier() -> void:
	gsm.deck.current_deck = range(1, 21)  # 20张
	gsm.deck.deck_limit_modifier = 5  # 万法归宗 +5
	var result: Dictionary = ds.call("can_add_to_deck", 1)
	assert_eq(result["allowed"], true, "20张+modifier5=25上限→21≤25允许")


# ============================================================================
# AC-002：can_remove_from_deck 低于5张时拒绝
# ============================================================================

func test_ac002_can_remove_allowed() -> void:
	gsm.deck.current_deck = [1, 2, 3, 4, 5, 6, 7]
	var result: Dictionary = ds.call("can_remove_from_deck", 1)
	assert_eq(result["allowed"], true, "7张-1=6≥5→允许")


func test_ac002_can_remove_below_minimum_rejected() -> void:
	gsm.deck.current_deck = [1, 2, 3, 4, 5]
	var result: Dictionary = ds.call("can_remove_from_deck", 1)
	assert_eq(result["allowed"], false, "5张-1=4<5→拒绝")


func test_ac002_can_remove_at_minimum_rejected() -> void:
	gsm.deck.current_deck = [1, 2, 3, 4]
	var result: Dictionary = ds.call("can_remove_from_deck", 1)
	assert_eq(result["allowed"], false, "4张-1=3<5→拒绝")


# ============================================================================
# AC-003：get_deck_limit 返回境界对应上限
# ============================================================================

func test_ac003_deck_limit_realm_1() -> void:
	gsm.player.realm = 1
	assert_eq(ds.call("get_deck_limit"), 20, "炼气期 deck_limit=20")


func test_ac003_deck_limit_realm_3() -> void:
	gsm.player.realm = 3
	assert_eq(ds.call("get_deck_limit"), 30, "金丹期 deck_limit=30")


func test_ac003_deck_limit_with_modifier() -> void:
	gsm.player.realm = 1
	gsm.deck.deck_limit_modifier = 5
	assert_eq(ds.call("get_deck_limit"), 25, "20+5=25")


# ============================================================================
# AC-004：add_cards_to_deck 成功写入 + 变更日志
# ============================================================================

func test_ac004_add_cards_writes() -> void:
	gsm.deck.current_deck = [1, 2, 3]
	ds.call("add_cards_to_deck", [4, 5], "loot", "战利品")
	await _flush()
	assert_eq(gsm.deck.current_deck.size(), 5, "卡组从3→5张")
	assert_eq(gsm.deck.current_deck[3], 4, "第4张=4")
	assert_eq(gsm.deck.current_deck[4], 5, "第5张=5")


func test_ac004_add_cards_change_log() -> void:
	ds.call("add_cards_to_deck", [10], "event", "事件获得")
	await _flush()
	var log: Array = gsm.deck.change_log
	assert_eq(log.size(), 1, "变更日志含1条")
	assert_eq(int(log[0]["card_id"]), 10, "card_id=10")
	assert_eq(str(log[0]["action"]), "add", "action=add")
	assert_eq(str(log[0]["source"]), "event", "source=event")


func test_ac004_add_cards_at_limit_rejected() -> void:
	gsm.deck.current_deck = range(1, 21)  # 20张
	var result: bool = ds.call("add_cards_to_deck", [21], "loot", "")
	assert_eq(result, false, "满时添加被拒绝")
	assert_eq(gsm.deck.current_deck.size(), 20, "卡组仍为20张")


# ============================================================================
# AC-005：remove_cards_from_deck 成功写入 + 变更日志
# ============================================================================

func test_ac005_remove_cards_writes() -> void:
	gsm.deck.current_deck = [1, 2, 3, 4, 5, 6, 7]
	ds.call("remove_cards_from_deck", [3, 5], "shop_delete", "散功")
	await _flush()
	assert_eq(gsm.deck.current_deck.size(), 5, "卡组从7→5张")
	assert_false(3 in gsm.deck.current_deck, "卡3已移除")
	assert_false(5 in gsm.deck.current_deck, "卡5已移除")


func test_ac005_remove_cards_change_log() -> void:
	gsm.deck.current_deck = [1, 2, 3, 4, 5, 6]
	ds.call("remove_cards_from_deck", [2], "shop_delete", "散功")
	await _flush()
	var log: Array = gsm.deck.change_log
	assert_eq(log.size(), 1, "变更日志含1条")
	assert_eq(str(log[0]["action"]), "remove", "action=remove")


func test_ac005_remove_below_minimum_rejected() -> void:
	gsm.deck.current_deck = [1, 2, 3, 4, 5]
	var result: bool = ds.call("remove_cards_from_deck", [1], "shop_delete", "")
	assert_eq(result, false, "低于5张时删除被拒绝")
	assert_eq(gsm.deck.current_deck.size(), 5, "卡组仍为5张")


# ============================================================================
# AC-006：_append_change_log 追加日志条目
# ============================================================================

func test_ac006_append_change_log_multiple() -> void:
	ds.call("_append_change_log", [1, 2, 3], "add", "loot", "战利品")
	await _flush()
	var log: Array = gsm.deck.change_log
	assert_eq(log.size(), 3, "3张卡→3条日志")
	assert_eq(int(log[0]["card_id"]), 1, "第1条 card_id=1")
	assert_eq(int(log[1]["card_id"]), 2, "第2条 card_id=2")
	assert_eq(int(log[2]["card_id"]), 3, "第3条 card_id=3")


# ============================================================================
# AC-007：serializer deck 域含 ADR-0023 结构
# ============================================================================

func test_ac007_serializer_deck_defaults() -> void:
	var serializer: RefCounted = gsm.get("_serializer")
	var defaults: Dictionary = serializer._get_default_for_domain("deck")
	assert_true(defaults.has("current_deck"), "含 current_deck")
	assert_true(defaults.has("slots"), "含 slots")
	assert_true(defaults.has("change_log"), "含 change_log")
	assert_true(defaults.has("session_remove_count"), "含 session_remove_count")
	assert_true(defaults.has("deck_limit_modifier"), "含 deck_limit_modifier")
	assert_false(defaults.has("character_slots"), "不含旧 character_slots")
	assert_false(defaults.has("presets"), "不含旧 presets")


# ============================================================================
# AC-008：_set_deck_cards / _set_deck_session_remove_count 写入 + batch_updated
# ============================================================================

func test_ac008_set_deck_cards_writes() -> void:
	gsm._set_deck_cards([10, 20, 30])
	await _flush()
	assert_eq(gsm.deck.current_deck, [10, 20, 30], "_set_deck_cards 写入成功")


func test_ac008_set_deck_cards_batch_updated() -> void:
	gsm._set_deck_cards([10, 20])
	await _flush()
	assert_true(_has_path("deck.current_deck"), "batch_updated 含 deck.current_deck")


func test_ac008_set_deck_session_remove_count() -> void:
	gsm._set_deck_session_remove_count(3)
	await _flush()
	assert_eq(gsm.deck.session_remove_count, 3, "session_remove_count=3")
	assert_true(_has_path("deck.session_remove_count"), "batch_updated 含 session_remove_count")


func test_ac008_set_deck_cards_dedup() -> void:
	gsm._set_deck_cards([1, 2])
	await _flush()
	_batch_updates.clear()
	gsm._set_deck_cards([1, 2])  # 同值
	await _flush()
	assert_eq(_batch_updates.size(), 0, "同值去重")


# ============================================================================
# AC-009：DeckEditingSystem 实例化无报错
# ============================================================================

func test_ac009_instance_creation() -> void:
	assert_not_null(ds, "DeckEditingSystem 实例化成功")
	assert_true(ds is Node, "是 Node 类型")


# ============================================================================
# AC-010：get_deck_cards 返回 current_deck 副本
# ============================================================================

func test_ac010_get_deck_cards_returns_copy() -> void:
	gsm.deck.current_deck = [1, 2, 3]
	var cards: Array = ds.call("get_deck_cards")
	assert_eq(cards, [1, 2, 3], "返回正确卡组列表")
	assert_eq(cards.size(), 3, "3张卡")


func test_ac010_get_deck_cards_is_copy() -> void:
	gsm.deck.current_deck = [1, 2, 3]
	var cards: Array = ds.call("get_deck_cards")
	cards.append(999)  # 修改副本
	assert_eq(gsm.deck.current_deck.size(), 3, "修改副本不影响 GSM 内部状态")
