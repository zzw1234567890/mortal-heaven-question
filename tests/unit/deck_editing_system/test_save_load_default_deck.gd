extends GutTest
## Story 003 验收测试：卡组保存/加载 + 默认卡组。
##
## 覆盖 AC-001 到 AC-010（10 条 AC）。
## 测试策略：
##   - 使用 GSM Autoload + DeckEditingSystem 实例
##   - 验证 initialize_initial_deck + serialize/deserialize 往返
##
## 设计文档来源：GDD deck-editing-system.md §核心规则 #1/#8
## Story 来源：production/epics/deck-editing-system/story-003-save-load-default-deck.md

const DS_SCRIPT := preload("res://src/feature/deck_editing_system.gd")

var ds: Node = null
var gsm: Node = null


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


func _flush() -> void:
	await get_tree().process_frame


# ============================================================================
# AC-001：initialize_initial_deck 写入卡组
# ============================================================================

func test_ac001_initialize_writes_deck() -> void:
	ds.call("initialize_initial_deck", [101, 102, 103, 104, 105, 106, 107])
	await _flush()
	assert_eq(gsm.deck.current_deck.size(), 7, "卡组写入7张")
	assert_eq(int(gsm.deck.current_deck[0]), 101, "第1张=101")
	assert_eq(int(gsm.deck.current_deck[6]), 107, "第7张=107")


# ============================================================================
# AC-002：初始化后 deck 域全部重置
# ============================================================================

func test_ac002_initialize_resets_deck_domain() -> void:
	# 先设置非默认值
	gsm.deck.current_deck = [1, 2, 3]
	gsm.deck.change_log = [{"card_id": 1, "action": "add"}]
	gsm.deck.session_remove_count = 5
	gsm.deck.deck_limit_modifier = 3
	# 初始化
	ds.call("initialize_initial_deck", [101, 102, 103])
	await _flush()
	assert_eq(gsm.deck.current_deck, [101, 102, 103], "current_deck 被覆盖")
	assert_eq(gsm.deck.change_log.size(), 0, "change_log 被清空")
	assert_eq(gsm.deck.session_remove_count, 0, "session_remove_count 重置为0")
	assert_eq(gsm.deck.deck_limit_modifier, 0, "deck_limit_modifier 重置为0")


func test_ac002_initialize_resets_slots() -> void:
	gsm.deck.slots = ["char_1", "char_2", null, null, null, null]
	ds.call("initialize_initial_deck", [101])
	await _flush()
	assert_eq(gsm.deck.slots.size(), 6, "slots 6 个")
	assert_null(gsm.deck.slots[0], "slots[0]=null")
	assert_null(gsm.deck.slots[1], "slots[1]=null")


# ============================================================================
# AC-003：serialize/deserialize 往返——current_deck 完整保留
# ============================================================================

func test_ac003_roundtrip_current_deck() -> void:
	ds.call("initialize_initial_deck", [101, 102, 103, 104, 105, 106, 107])
	await _flush()
	var serializer: RefCounted = gsm.get("_serializer")
	var data: Dictionary = serializer.serialize()
	# 重置然后反序列化
	gsm.deck.current_deck = []
	var ok: bool = serializer.deserialize(data)
	assert_true(ok, "deserialize 成功")
	assert_eq(gsm.deck.current_deck.size(), 7, "current_deck 往返7张")
	assert_eq(int(gsm.deck.current_deck[0]), 101, "第1张=101")
	assert_eq(int(gsm.deck.current_deck[6]), 107, "第7张=107")


# ============================================================================
# AC-004：deserialize 后 session_remove_count 正确恢复
# ============================================================================

func test_ac004_roundtrip_session_remove_count() -> void:
	gsm.deck.session_remove_count = 3
	var serializer: RefCounted = gsm.get("_serializer")
	var data: Dictionary = serializer.serialize()
	gsm.deck.session_remove_count = 0
	var ok: bool = serializer.deserialize(data)
	assert_true(ok, "deserialize 成功")
	assert_eq(gsm.deck.session_remove_count, 3, "session_remove_count 往返=3")


# ============================================================================
# AC-005：deserialize 后 change_log 完整恢复
# ============================================================================

func test_ac005_roundtrip_change_log() -> void:
	gsm.deck.change_log = [
		{"card_id": 1, "action": "add", "source": "loot", "detail": "战利品"},
		{"card_id": 2, "action": "remove", "source": "shop_delete", "detail": "散功"},
	]
	var serializer: RefCounted = gsm.get("_serializer")
	var data: Dictionary = serializer.serialize()
	gsm.deck.change_log = []
	var ok: bool = serializer.deserialize(data)
	assert_true(ok, "deserialize 成功")
	assert_eq(gsm.deck.change_log.size(), 2, "change_log 往返2条")
	assert_eq(int(gsm.deck.change_log[0]["card_id"]), 1, "第1条 card_id=1")
	assert_eq(str(gsm.deck.change_log[1]["action"]), "remove", "第2条 action=remove")


# ============================================================================
# AC-006：deserialize 后 deck_limit_modifier 正确恢复
# ============================================================================

func test_ac006_roundtrip_deck_limit_modifier() -> void:
	gsm.deck.deck_limit_modifier = 5  # 万法归宗
	var serializer: RefCounted = gsm.get("_serializer")
	var data: Dictionary = serializer.serialize()
	gsm.deck.deck_limit_modifier = 0
	var ok: bool = serializer.deserialize(data)
	assert_true(ok, "deserialize 成功")
	assert_eq(gsm.deck.deck_limit_modifier, 5, "deck_limit_modifier 往返=5")


# ============================================================================
# AC-007：默认卡组常量存在
# ============================================================================

func test_ac007_default_decks_constant() -> void:
	assert_true(DS_SCRIPT.DEFAULT_DECKS.has(1), "身份1 存在")
	assert_true(DS_SCRIPT.DEFAULT_DECKS.has(6), "身份6 存在")
	assert_eq(DS_SCRIPT.DEFAULT_DECKS.size(), 6, "共6个身份")


func test_ac007_default_deck_sizes() -> void:
	assert_eq(DS_SCRIPT.DEFAULT_DECKS[1].size(), 7, "身份1 初始7张")
	assert_eq(DS_SCRIPT.DEFAULT_DECKS[6].size(), 6, "身份6 初始6张")


# ============================================================================
# AC-008：get_default_deck 返回正确卡组
# ============================================================================

func test_ac008_get_default_deck_identity_1() -> void:
	var deck: Array = ds.call("get_default_deck", 1)
	assert_eq(deck.size(), 7, "身份1 返回7张")
	assert_eq(int(deck[0]), 101, "第1张=101")


func test_ac008_get_default_deck_identity_6() -> void:
	var deck: Array = ds.call("get_default_deck", 6)
	assert_eq(deck.size(), 6, "身份6 返回6张")
	assert_eq(int(deck[0]), 601, "第1张=601")


func test_ac008_get_default_deck_invalid() -> void:
	var deck: Array = ds.call("get_default_deck", 99)
	assert_eq(deck.size(), 0, "无效身份返回空数组")


func test_ac008_get_default_deck_returns_copy() -> void:
	var deck: Array = ds.call("get_default_deck", 1)
	deck.append(999)  # 修改副本
	assert_eq(DS_SCRIPT.DEFAULT_DECKS[1].size(), 7, "修改副本不影响常量")


# ============================================================================
# AC-009：初始化卡组不受上限约束
# ============================================================================

func test_ac009_initialize_bypasses_limit() -> void:
	# 炼气期上限20，初始化7张不应被拒绝
	gsm.player.realm = 1
	ds.call("initialize_initial_deck", [101, 102, 103, 104, 105, 106, 107])
	await _flush()
	assert_eq(gsm.deck.current_deck.size(), 7, "7张写入成功（不受上限约束）")


# ============================================================================
# AC-010：重复初始化覆盖旧卡组
# ============================================================================

func test_ac010_reinitialize_overwrites() -> void:
	ds.call("initialize_initial_deck", [101, 102, 103, 104, 105, 106, 107])
	await _flush()
	ds.call("initialize_initial_deck", [201, 202, 203, 204, 205, 206, 207])
	await _flush()
	assert_eq(gsm.deck.current_deck.size(), 7, "重复初始化后7张")
	assert_eq(int(gsm.deck.current_deck[0]), 201, "第1张=201（新卡组）")
	assert_false(101 in gsm.deck.current_deck, "旧卡101已覆盖")
