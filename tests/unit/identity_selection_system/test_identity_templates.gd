extends GutTest
## Story 001 验收测试：身份模板 const Dictionary（6 个）+ 查询 API。
##
## 覆盖 AC-001 到 AC-013（13 条 AC）。
## 测试策略：
##   - 实例化 IdentitySelectionSystem + ProgressionSystem mock
##   - 验证模板完整性 + 解锁状态 + 预览数据 + GDD 数值
##
## 设计文档来源：GDD identity-selection-system.md §1-2
## Story 来源：production/epics/identity-selection-system/story-001-identity-templates.md

const IS_SCRIPT := preload("res://src/feature/identity_selection_system.gd")

var isys: Node = null
var _prog_mock: Node = null


func before_each() -> void:
	isys = IS_SCRIPT.new()
	_prog_mock = Node.new()
	_prog_mock.set_script(load("res://tests/unit/identity_selection_system/progression_mock.gd"))
	isys.set("_progression_override", _prog_mock)


func after_each() -> void:
	if isys != null:
		isys.free()
		isys = null
	if _prog_mock != null:
		_prog_mock.free()
		_prog_mock = null


# ============================================================================
# AC-001：IDENTITY_TEMPLATES 包含恰好 6 个身份模板
# ============================================================================

func test_identity_templates_contains_exactly_six_templates() -> void:
	# Arrange
	var templates: Dictionary = isys.IDENTITY_TEMPLATES

	# Act
	var count: int = templates.size()

	# Assert
	assert_eq(count, 6, "IDENTITY_TEMPLATES 应包含 6 个模板")


# ============================================================================
# AC-002：每个模板含全部必需字段
# ============================================================================

func test_each_template_has_all_required_fields() -> void:
	# Arrange
	var required_keys: Array = [
		"name", "description", "flavor_text", "style_tag",
		"initial_deck", "initial_resources", "talent",
		"character_details", "unlock_condition",
	]

	# Act & Assert
	for id: StringName in isys.IDENTITY_TEMPLATES:
		var tmpl: Dictionary = isys.IDENTITY_TEMPLATES[id]
		for key: String in required_keys:
			assert_true(tmpl.has(key), "身份 '%s' 缺少必需字段 '%s'" % [id, key])


# ============================================================================
# AC-003：get_available_identities 返回 6 个条目
# ============================================================================

func test_get_available_identities_returns_six_entries() -> void:
	# Act
	var entries: Array = isys.get_available_identities()

	# Assert
	assert_eq(entries.size(), 6, "应返回 6 个身份条目")


# ============================================================================
# AC-004：5 个默认身份 is_unlocked == true（ProgressionSystem 无解锁天赋时）
# ============================================================================

func test_default_five_identities_unlocked_without_talents() -> void:
	# Arrange
	_prog_mock._unlocked_talents = []

	# Act
	var entries: Array = isys.get_available_identities()

	# Assert
	var unlocked_count: int = 0
	for entry: Dictionary in entries:
		if entry["is_unlocked"]:
			unlocked_count += 1
	assert_eq(unlocked_count, 5, "5 个默认身份应解锁")


# ============================================================================
# AC-005：阵道双杰 is_unlocked == false（无 cang_xuan_walker 时）
# ============================================================================

func test_formation_duo_locked_without_cang_xuan_walker() -> void:
	# Arrange
	_prog_mock._unlocked_talents = []

	# Act
	var entries: Array = isys.get_available_identities()

	# Assert
	var formation_entry: Dictionary = {}
	for entry: Dictionary in entries:
		if entry["identity_id"] == &"formation_duo":
			formation_entry = entry
			break
	assert_false(formation_entry["is_unlocked"], "阵道双杰应锁定")


# ============================================================================
# AC-006：阵道双杰 is_unlocked == true（有 cang_xuan_walker 时）
# ============================================================================

func test_formation_duo_unlocked_with_cang_xuan_walker() -> void:
	# Arrange
	_prog_mock._unlocked_talents = ["cang_xuan_walker"]

	# Act
	var entries: Array = isys.get_available_identities()

	# Assert
	var formation_entry: Dictionary = {}
	for entry: Dictionary in entries:
		if entry["identity_id"] == &"formation_duo":
			formation_entry = entry
			break
	assert_true(formation_entry["is_unlocked"], "阵道双杰应解锁")


# ============================================================================
# AC-007：get_identity_preview 有效 ID 返回完整模板数据
# ============================================================================

func test_get_identity_preview_valid_id_returns_full_data() -> void:
	# Act
	var preview: Dictionary = isys.get_identity_preview(&"azure_sword_disciple")

	# Assert
	assert_false(preview.is_empty(), "有效 ID 应返回非空预览")
	assert_eq(preview["name"], "青云剑宗·外门弟子")
	assert_eq(preview["identity_id"], &"azure_sword_disciple")
	assert_true(preview.has("flavor_text"))
	assert_true(preview.has("initial_deck_cards"))
	assert_true(preview.has("character_slots"))
	assert_true(preview.has("character_details"))
	assert_true(preview.has("talent"))
	assert_true(preview.has("unlock_condition"))
	assert_true(preview.has("playstyle_hint"))


# ============================================================================
# AC-008：get_identity_preview 无效 ID 返回空字典
# ============================================================================

func test_get_identity_preview_invalid_id_returns_empty() -> void:
	# Act
	var preview: Dictionary = isys.get_identity_preview(&"invalid_fake_identity")

	# Assert
	assert_true(preview.is_empty(), "无效 ID 应返回空字典")


# ============================================================================
# AC-009：青云剑宗 is_recommended == true
# ============================================================================

func test_azure_sword_disciple_is_recommended() -> void:
	# Act
	var entries: Array = isys.get_available_identities()

	# Assert
	var azure_entry: Dictionary = {}
	for entry: Dictionary in entries:
		if entry["identity_id"] == &"azure_sword_disciple":
			azure_entry = entry
			break
	assert_true(azure_entry["is_recommended"], "青云剑宗应标记为新手推荐")


# ============================================================================
# AC-010：每个身份 ling_shi 符合 GDD（15/10/18/15/14/25）
# ============================================================================

func test_identity_ling_shi_matches_gdd() -> void:
	# Arrange
	var expected: Dictionary = {
		&"azure_sword_disciple": 15,
		&"blood_sea_orphan": 10,
		&"star_isles_wanderer": 18,
		&"frost_palace_disciple": 15,
		&"crimson_valley_disciple": 14,
		&"formation_duo": 25,
	}

	# Act
	var entries: Array = isys.get_available_identities()

	# Assert
	for entry: Dictionary in entries:
		var id: StringName = entry["identity_id"]
		assert_eq(entry["initial_ling_shi"], expected[id],
			"身份 '%s' 灵石不匹配" % id)


# ============================================================================
# AC-011：每个身份 talent.id + magnitude 符合 GDD
# ============================================================================

func test_identity_talent_matches_gdd() -> void:
	# Arrange
	var expected: Dictionary = {
		&"azure_sword_disciple": {"id": "ling_shi_boost", "magnitude": 15},
		&"blood_sea_orphan": {"id": "first_strike_extra_cost", "magnitude": 1},
		&"star_isles_wanderer": {"id": "re_forge_opportunity", "magnitude": 1},
		&"frost_palace_disciple": {"id": "frost_guard_shield", "magnitude": 2},
		&"crimson_valley_disciple": {"id": "alchemy_affinity", "magnitude": 20},
		&"formation_duo": {"id": "formation_master", "magnitude": 1},
	}

	# Act & Assert
	for id: StringName in isys.IDENTITY_TEMPLATES:
		var tmpl: Dictionary = isys.IDENTITY_TEMPLATES[id]
		var talent: Dictionary = tmpl["talent"]
		var exp: Dictionary = expected[id]
		assert_eq(str(talent["id"]), exp["id"], "身份 '%s' 天赋 ID 不匹配" % id)
		assert_eq(int(talent["magnitude"]), exp["magnitude"], "身份 '%s' 天赋 magnitude 不匹配" % id)


# ============================================================================
# AC-012：每个身份 initial_deck.cards 符合 GDD 卡牌组成
# ============================================================================

func test_identity_initial_deck_cards_match_gdd() -> void:
	# Arrange
	var expected_cards: Dictionary = {
		&"azure_sword_disciple": [
			{"card_id": "ku_mu_feng_chun_jue", "count": 1},
			{"card_id": "yan_yun_bu", "count": 1},
			{"card_id": "ying_ci", "count": 1},
			{"card_id": "basic_attack", "count": 2},
			{"card_id": "jian_yi_hu_dun", "count": 2},
		],
		&"blood_sea_orphan": [
			{"card_id": "wan_hun_fan", "count": 1},
			{"card_id": "you_ying_bu", "count": 1},
			{"card_id": "sha_qi_zhan", "count": 2},
			{"card_id": "xue_sha_zhang", "count": 1},
			{"card_id": "basic_attack", "count": 2},
		],
		&"star_isles_wanderer": [
			{"card_id": "huan_hua_mi_zong_bu", "count": 1},
			{"card_id": "yin_po_ning_hun_shu", "count": 1},
			{"card_id": "jian_bo_zhan", "count": 2},
			{"card_id": "xun_bao_fu", "count": 1},
			{"card_id": "basic_attack", "count": 2},
		],
		&"frost_palace_disciple": [
			{"card_id": "han_yu_lun_hui_gong", "count": 1},
			{"card_id": "shuang_po_jian_jue", "count": 1},
			{"card_id": "bing_leng_ci", "count": 2},
			{"card_id": "jin_zhong_fu", "count": 1},
			{"card_id": "basic_attack", "count": 2},
		],
		&"crimson_valley_disciple": [
			{"card_id": "san_yuan_ju_qi_gong", "count": 1},
			{"card_id": "dan_xia_jian_qi", "count": 1},
			{"card_id": "zhu_ji_dan", "count": 1},
			{"card_id": "basic_attack", "count": 2},
			{"card_id": "pei_yuan_dan", "count": 2},
		],
		&"formation_duo": [
			{"card_id": "wan_xiang_zhen_dian", "count": 1},
			{"card_id": "qi_xing_kun_long_zhen", "count": 1},
			{"card_id": "yin_yang_shou_yu_zhen", "count": 1},
			{"card_id": "jin_qian_biao", "count": 2},
			{"card_id": "basic_attack", "count": 1},
		],
	}

	# Act & Assert
	for id: StringName in isys.IDENTITY_TEMPLATES:
		var tmpl: Dictionary = isys.IDENTITY_TEMPLATES[id]
		var cards: Array = tmpl["initial_deck"]["cards"]
		var exp: Array = expected_cards[id]
		assert_eq(cards.size(), exp.size(), "身份 '%s' 卡牌种类数不匹配" % id)
		for i: int in range(cards.size()):
			var actual_card: Dictionary = cards[i]
			var exp_card: Dictionary = exp[i]
			assert_eq(str(actual_card["card_id"]), str(exp_card["card_id"]),
				"身份 '%s' 卡牌[%d] card_id 不匹配" % [id, i])
			assert_eq(int(actual_card["count"]), int(exp_card["count"]),
				"身份 '%s' 卡牌[%d] count 不匹配" % [id, i])


# ============================================================================
# AC-013：每个身份 character_slots 符合 GDD 角色位配置
# ============================================================================

func test_identity_character_slots_match_gdd() -> void:
	# Arrange
	var expected_slots: Dictionary = {
		&"azure_sword_disciple": [
			{"card_id": "lin_yuan", "slot_index": 1},
			{"card_id": "su_jian_ming", "slot_index": 2},
		],
		&"blood_sea_orphan": [
			{"card_id": "yin_ruo_han", "slot_index": 1},
			{"card_id": "tu_ye", "slot_index": 2},
		],
		&"star_isles_wanderer": [
			{"card_id": "xi_yin", "slot_index": 1},
			{"card_id": "mu_yao", "slot_index": 2},
		],
		&"frost_palace_disciple": [
			{"card_id": "ling_shuang_yue", "slot_index": 1},
			{"card_id": "jiang_xue", "slot_index": 2},
		],
		&"crimson_valley_disciple": [
			{"card_id": "fang_ling_su", "slot_index": 1},
			{"card_id": "shi_yan", "slot_index": 2},
		],
		&"formation_duo": [
			{"card_id": "mu_xing_he", "slot_index": 1},
			{"card_id": "yun_su_xin", "slot_index": 2},
		],
	}

	# Act & Assert
	for id: StringName in isys.IDENTITY_TEMPLATES:
		var tmpl: Dictionary = isys.IDENTITY_TEMPLATES[id]
		var slots: Array = tmpl["initial_deck"]["character_slots"]
		var exp: Array = expected_slots[id]
		assert_eq(slots.size(), exp.size(), "身份 '%s' 角色位数不匹配" % id)
		for i: int in range(slots.size()):
			var actual_slot: Dictionary = slots[i]
			var exp_slot: Dictionary = exp[i]
			assert_eq(str(actual_slot["card_id"]), str(exp_slot["card_id"]),
				"身份 '%s' 角色位[%d] card_id 不匹配" % [id, i])
			assert_eq(int(actual_slot["slot_index"]), int(exp_slot["slot_index"]),
				"身份 '%s' 角色位[%d] slot_index 不匹配" % [id, i])
