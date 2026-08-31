extends GutTest
## Story 002 验收测试：apply_identity 原子操作（编排现有服务 API）。
##
## 覆盖 AC-001 到 AC-011（11 条 AC）。
## 测试策略：
##   - 实例化 IdentitySelectionSystem + CardSystem/ResourceSystem/ProgressionSystem mock
##   - 验证 apply_identity 原子操作 + GSM 状态写入 + 信号发射 + 回滚
##
## 设计文档来源：GDD identity-selection-system.md §3 身份选择流程、§公式#1 天赋效果注册
## Story 来源：production/epics/identity-selection-system/story-002-apply-identity.md

const IS_SCRIPT := preload("res://src/feature/identity_selection_system.gd")

var isys: Node = null
var gsm: Node = null
var _card_mock: Node = null
var _res_mock: Node = null
var _prog_mock: Node = null
var _deck_override: Node = null
var _signal_received: Array = []


func before_each() -> void:
	isys = IS_SCRIPT.new()
	gsm = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/GameStateManager")
	if gsm == null:
		fail_test("GSM Autoload 未注册")
		return
	# 重置 GSM 状态
	gsm.player.identity_id = ""
	gsm.player.resources.ling_shi = 0
	gsm.player.talents = []
	gsm.player["talent_map"] = {}
	gsm.deck.current_deck = []
	gsm.deck.slots = [null, null, null, null, null, null]
	gsm.deck.change_log = []
	gsm.deck.session_remove_count = 0
	gsm.deck.deck_limit_modifier = 0
	gsm.collection.owned_cards = []
	gsm.collection.total_count = 0
	gsm.narrative.story_flags = {}
	gsm.set("_signal_chain_depth", 0)
	gsm.get("_signal_router").set("_pending_changes", [])
	gsm.set("_next_card_instance_id", 1)
	# CardSystem mock——注册所有身份模板中的 card_id
	_card_mock = Node.new()
	_card_mock.set_script(load("res://tests/unit/identity_selection_system/card_system_mock.gd"))
	_card_mock._templates = {}
	for tid: StringName in isys.IDENTITY_TEMPLATES:
		var tmpl: Dictionary = isys.IDENTITY_TEMPLATES[tid]
		for card_entry: Dictionary in tmpl["initial_deck"]["cards"]:
			_card_mock._templates[str(card_entry["card_id"])] = true
		for char_entry: Dictionary in tmpl["initial_deck"]["character_slots"]:
			_card_mock._templates[str(char_entry["card_id"])] = true
	isys.set("_card_override", _card_mock)
	# ResourceSystem mock
	_res_mock = Node.new()
	_res_mock.set_script(load("res://tests/unit/identity_selection_system/resource_mock.gd"))
	isys.set("_resource_override", _res_mock)
	# ProgressionSystem mock——不解锁阵道双杰
	_prog_mock = Node.new()
	_prog_mock.set_script(load("res://tests/unit/identity_selection_system/progression_mock.gd"))
	_prog_mock._unlocked_talents = []
	isys.set("_progression_override", _prog_mock)
	# DeckEditingSystem——使用 Autoload（已注册）
	isys.set("_deck_override", null)
	# 信号监听
	_signal_received.clear()
	isys.identity_selected.connect(_on_identity_selected)
	# 启用 GSM 卡牌校验（add_card_to_collection 需要）
	gsm.enable_validation(_card_mock._templates)


func after_each() -> void:
	if isys != null:
		if isys.identity_selected.is_connected(_on_identity_selected):
			isys.identity_selected.disconnect(_on_identity_selected)
		isys.free()
		isys = null
	if _card_mock != null:
		_card_mock.free()
		_card_mock = null
	if _res_mock != null:
		_res_mock.free()
		_res_mock = null
	if _prog_mock != null:
		_prog_mock.free()
		_prog_mock = null
	if gsm != null:
		gsm.validation_enabled = false
		gsm._card_template_database = {}
	_signal_received.clear()


func _on_identity_selected(identity_id: StringName) -> void:
	_signal_received.append(identity_id)


func _flush() -> void:
	await get_tree().process_frame


# ============================================================================
# AC-001：apply_identity(有效ID) 返回 true
# ============================================================================

func test_apply_identity_valid_id_returns_true() -> void:
	# Act
	var result: bool = isys.apply_identity(&"azure_sword_disciple")

	# Assert
	assert_true(result, "有效 ID 应返回 true")


# ============================================================================
# AC-002：apply 后 GSM.player.identity_id 正确写入
# ============================================================================

func test_apply_identity_writes_identity_id_to_gsm() -> void:
	# Act
	isys.apply_identity(&"azure_sword_disciple")

	# Assert
	assert_eq(str(gsm.player.identity_id), "azure_sword_disciple",
		"identity_id 应写入 GSM")


# ============================================================================
# AC-003：apply 后 GSM.player.resources.ling_shi 正确设置
# ============================================================================

func test_apply_identity_sets_initial_ling_shi() -> void:
	# Act
	isys.apply_identity(&"star_isles_wanderer")

	# Assert
	assert_eq(int(gsm.player.resources.ling_shi), 18,
		"碎星群岛初始灵石应为 18")


# ============================================================================
# AC-004：apply 后 GSM.player.talent_map[talent_id] == magnitude
# ============================================================================

func test_apply_identity_registers_talent_map() -> void:
	# Act
	isys.apply_identity(&"blood_sea_orphan")

	# Assert
	var talent_map: Dictionary = gsm.player.get("talent_map", {})
	assert_true(talent_map.has("first_strike_extra_cost"),
		"talent_map 应包含 first_strike_extra_cost")
	assert_eq(int(talent_map["first_strike_extra_cost"]), 1,
		"first_strike_extra_cost magnitude 应为 1")


# ============================================================================
# AC-005：apply 后 deck.current_deck 含初始卡牌实例 ID
# ============================================================================

func test_apply_identity_writes_initial_deck_cards() -> void:
	# Act
	isys.apply_identity(&"azure_sword_disciple")

	# Assert
	var deck: Array = gsm.deck.current_deck
	# 青云剑宗 7 张卡（枯木逢春诀×1+烟云步×1+影刺×1+基础攻击×2+简易护盾×2）
	assert_eq(deck.size(), 7, "卡组应有 7 张卡")


# ============================================================================
# AC-006：apply 后 deck.slots 含初始角色实例 ID
# ============================================================================

func test_apply_identity_writes_initial_character_slots() -> void:
	# Act
	isys.apply_identity(&"azure_sword_disciple")

	# Assert
	var slots: Array = gsm.deck.slots
	assert_not_null(slots[0], "位 1 应有角色")
	assert_not_null(slots[1], "位 2 应有角色")
	assert_null(slots[2], "位 3 应为空")


# ============================================================================
# AC-007：apply 后 narrative.story_flags.opening_text 写入 flavor_text
# ============================================================================

func test_apply_identity_writes_opening_text() -> void:
	# Act
	isys.apply_identity(&"frost_palace_disciple")

	# Assert
	var opening: String = str(gsm.narrative.story_flags.get("opening_text", ""))
	assert_false(opening.is_empty(), "opening_text 不应为空")
	assert_true(opening.find("玄冰宫") >= 0, "opening_text 应包含身份相关文本")


# ============================================================================
# AC-008：apply 后 identity_selected 信号已发射
# ============================================================================

func test_apply_identity_emits_identity_selected_signal() -> void:
	# Act
	isys.apply_identity(&"azure_sword_disciple")

	# Assert
	assert_eq(_signal_received.size(), 1, "应发射一次 identity_selected 信号")
	assert_eq(_signal_received[0], &"azure_sword_disciple",
		"信号应携带 identity_id")


# ============================================================================
# AC-009：apply_identity(无效ID) 返回 false，GSM 不变
# ============================================================================

func test_apply_identity_invalid_id_returns_false() -> void:
	# Arrange
	var identity_before: String = str(gsm.player.identity_id)

	# Act
	var result: bool = isys.apply_identity(&"invalid_fake_identity")

	# Assert
	assert_false(result, "无效 ID 应返回 false")
	assert_eq(str(gsm.player.identity_id), identity_before,
		"identity_id 不应变")


# ============================================================================
# AC-010：apply_identity(未解锁ID) 返回 false，GSM 不变
# ============================================================================

func test_apply_identity_locked_id_returns_false() -> void:
	# Arrange——阵道双杰未解锁（_prog_mock._unlocked_talents = []）
	var identity_before: String = str(gsm.player.identity_id)

	# Act
	var result: bool = isys.apply_identity(&"formation_duo")

	# Assert
	assert_false(result, "未解锁 ID 应返回 false")
	assert_eq(str(gsm.player.identity_id), identity_before,
		"identity_id 不应变")


# ============================================================================
# AC-011：ResourceSystem 失败时 identity_id 回滚为空
# ============================================================================

func test_apply_identity_rolls_back_on_resource_failure() -> void:
	# Arrange
	_res_mock._fail_mode = true

	# Act
	var result: bool = isys.apply_identity(&"azure_sword_disciple")

	# Assert
	assert_false(result, "ResourceSystem 失败时应返回 false")
	assert_eq(str(gsm.player.identity_id), "",
		"identity_id 应回滚为空字符串")
