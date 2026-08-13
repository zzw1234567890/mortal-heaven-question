extends GutTest
## Story 3-7 验收测试：SchoolSystem 流派库 + 纯查询接口。
##
## 覆盖 AC-001 到 AC-018（18 条 AC）。
##
## 测试策略：
##   - SS_SCRIPT.new() 构造 SchoolSystem 实例
##   - var ss: Node 持有 + 动态分派
##   - before_each/after_each 清理实例状态
##   - state Dictionary 作为纯入参注入（不依赖 GSM/FactionSystem 场景树）

const SS_SCRIPT: GDScript = preload("res://src/core/school_system/school_system.gd")

var ss: Node = null


func before_each() -> void:
	ss = SS_SCRIPT.new()


func after_each() -> void:
	if ss != null:
		ss.free()
		ss = null


# ============================================================================
# 辅助方法
# ============================================================================

## 构建测试用 state Dictionary——最小有效状态。
func _make_state(
	field_chars: Array = [],
	deck_cards: Array = [],
	player_realm: int = 1,
	alchemy_count: int = 0,
	collected_characters: Array[StringName] = []
) -> Dictionary:
	return {
		field_characters = field_chars,
		deck_cards = deck_cards,
		player_realm = player_realm,
		alchemy_count = alchemy_count,
		collected_characters = collected_characters,
	}


## 创建测试用场上角色。
func _make_char(faction_tags: Array[StringName], rarity: String = "blue", card_type: String = "character", cost: int = 3, character_id: StringName = &"") -> Dictionary:
	return {
		faction_tags = faction_tags,
		rarity = rarity,
		card_type = card_type,
		cost = cost,
		character_id = character_id,
	}


## 创建测试用卡组卡牌。
func _make_card(card_type: String = "character", cost: int = 3, rarity: String = "blue", is_modao_exclusive: bool = false) -> Dictionary:
	return {
		card_type = card_type,
		cost = cost,
		rarity = rarity,
		is_modao_exclusive = is_modao_exclusive,
	}


# ============================================================================
# AC-001：extends Node + 不声明 class_name
# ============================================================================

func test_ac001_extends_node_no_class_name() -> void:
	assert_eq(SS_SCRIPT.get_instance_base_type(), "Node",
		"SchoolSystem 应 extends Node")
	assert_eq(SS_SCRIPT.get_global_name(), &"",
		"SchoolSystem 不应声明 class_name")
	var instance: Node = SS_SCRIPT.new()
	assert_not_null(instance, "SS_SCRIPT.new() 应返回非 null 实例")
	instance.free()


# ============================================================================
# AC-002：SCHOOL_LIBRARY 5 流派 entry
# ============================================================================

func test_ac002_school_library_has_5_entries() -> void:
	var library: Dictionary = ss.SCHOOL_LIBRARY
	assert_eq(library.size(), 5, "SCHOOL_LIBRARY 应含 5 流派")
	assert_true(library.has(&"righteous_dev"), "应含 righteous_dev")
	assert_true(library.has(&"demonic_aggro"), "应含 demonic_aggro")
	assert_true(library.has(&"mixed_alignment"), "应含 mixed_alignment")
	assert_true(library.has(&"spirit_realm_beast"), "应含 spirit_realm_beast")
	assert_true(library.has(&"alchemy_mastery"), "应含 alchemy_mastery")


# ============================================================================
# AC-003：流派 entry 字段完整
# ============================================================================

func test_ac003_school_entry_fields_complete() -> void:
	var school: Dictionary = ss.SCHOOL_LIBRARY[&"righteous_dev"]
	assert_true(school.has("id"), "应有 id")
	assert_true(school.has("name"), "应有 name")
	assert_true(school.has("tagline"), "应有 tagline")
	assert_true(school.has("description"), "应有 description")
	assert_true(school.has("priority"), "应有 priority")
	assert_true(school.has("detection"), "应有 detection")
	assert_true(school.has("effects"), "应有 effects")
	assert_true(school.has("weakness"), "应有 weakness")
	assert_true(school.has("visual_theme"), "应有 visual_theme")
	# 验证 5 流派均含全部 9 字段
	for school_id in ss.SCHOOL_LIBRARY:
		var s = ss.SCHOOL_LIBRARY[school_id]
		for field in ["id", "name", "tagline", "description", "priority", "detection", "effects", "weakness", "visual_theme"]:
			assert_true(s.has(field), "%s 应含 %s 字段" % [school_id, field])


# ============================================================================
# AC-004：优先级数值
# ============================================================================

func test_ac004_priority_values() -> void:
	assert_eq(ss.SCHOOL_LIBRARY[&"spirit_realm_beast"].priority, 1, "归墟真灵流 priority=1")
	assert_eq(ss.SCHOOL_LIBRARY[&"righteous_dev"].priority, 2, "正道发育流 priority=2")
	assert_eq(ss.SCHOOL_LIBRARY[&"demonic_aggro"].priority, 3, "魔道快攻流 priority=3")
	assert_eq(ss.SCHOOL_LIBRARY[&"mixed_alignment"].priority, 4, "正邪混合流 priority=4")
	assert_eq(ss.SCHOOL_LIBRARY[&"alchemy_mastery"].priority, 5, "百艺炼丹流 priority=5")


# ============================================================================
# AC-005：detect 返回流派 ID
# ============================================================================

func test_ac005_detect_returns_righteous_dev() -> void:
	# 正道≥3 + 正道占比≥60% + 无魔道限定卡
	var chars: Array = [
		_make_char([&"qixuanmen"], "blue", "character", 3),
		_make_char([&"dangxia_valley"], "blue", "character", 3),
		_make_char([&"dongyu"], "blue", "character", 3),
	]
	var state: Dictionary = _make_state(chars, [])
	var result: StringName = ss.detect(state)
	assert_eq(result, &"righteous_dev", "应返回 righteous_dev")


func test_ac005_detect_empty_field_returns_empty() -> void:
	var state: Dictionary = _make_state([], [])
	var result: StringName = ss.detect(state)
	assert_eq(result, &"", "空场应返回空 StringName")


# ============================================================================
# AC-006：calculate_match 返回结构
# ============================================================================

func test_ac006_calculate_match_returns_structure() -> void:
	var chars: Array = [
		_make_char([&"qixuanmen"], "blue", "character", 3),
		_make_char([&"dangxia_valley"], "blue", "character", 3),  # 2/3 正道
	]
	var state: Dictionary = _make_state(chars, [])
	var result: Dictionary = ss.calculate_match(&"righteous_dev", state)
	assert_true(result.has("score"), "应含 score")
	assert_true(result.has("missing"), "应含 missing")
	assert_true(result["score"] >= 0.0, "score ≥ 0")
	assert_true(result["score"] <= 100.0, "score ≤ 100")


# ============================================================================
# AC-007：get_school_info 返回元数据
# ============================================================================

func test_ac007_get_school_info_returns_metadata() -> void:
	var info: Dictionary = ss.get_school_info(&"righteous_dev")
	assert_eq(info["name"], "正道发育流", "name 应为 正道发育流")
	assert_true(info.has("tagline"), "应有 tagline")
	assert_true(info.has("description"), "应有 description")
	assert_true(info.has("effects"), "应有 effects")
	assert_true(info.has("weakness"), "应有 weakness")
	assert_true(info.has("visual_theme"), "应有 visual_theme")


func test_ac007_unknown_school_returns_empty() -> void:
	var info: Dictionary = ss.get_school_info(&"unknown_school")
	assert_eq(info.size(), 0, "未知 school_id 应返回空字典")


# ============================================================================
# AC-008：get_school_effects 返回增益列表
# ============================================================================

func test_ac008_get_school_effects_returns_list() -> void:
	var effects: Array[Dictionary] = ss.get_school_effects(&"righteous_dev")
	assert_true(effects.size() > 0, "应有增益效果")
	# 检查第一个增益的 type 字段
	var first: Dictionary = effects[0]
	assert_true(first.has("type"), "增益应有 type 字段")


func test_ac008_unknown_school_returns_empty_array() -> void:
	var effects: Array[Dictionary] = ss.get_school_effects(&"unknown_school")
	assert_eq(effects.size(), 0, "未知 school_id 应返回空数组")


# ============================================================================
# AC-009：get_all_schools 返回 5 流派 ID
# ============================================================================

func test_ac009_get_all_schools_returns_5_ids() -> void:
	var schools: Array[StringName] = ss.get_all_schools()
	assert_eq(schools.size(), 5, "应返回 5 流派 ID")
	# 按 priority 升序
	assert_eq(schools[0], &"spirit_realm_beast", "第一个应为归墟（priority 1）")
	assert_eq(schools[4], &"alchemy_mastery", "最后一个应为百艺（priority 5）")


# ============================================================================
# AC-010：school_changed 信号声明
# ============================================================================

func test_ac010_school_changed_signal_declared() -> void:
	var script_signals: Array = SS_SCRIPT.get_script_signal_list()
	var signal_names: Array[String] = []
	for sig in script_signals:
		signal_names.append(sig.name)
	assert_true(signal_names.has("school_changed"), "应声明 school_changed 信号")


# ============================================================================
# AC-011：detect 优先级——正道 > 正邪混合
# ============================================================================

func test_ac011_detect_priority_righteous_over_mixed() -> void:
	# 同时满足正道（priority 2）和正邪混合（priority 4）条件
	# 正道≥3 + 正道占比≥60% + 无魔道限定卡
	# 同时正道≥2 + 魔道≥2（正邪混合条件）
	var chars: Array = [
		_make_char([&"qixuanmen"], "blue", "character", 3),
		_make_char([&"dangxia_valley"], "blue", "character", 3),
		_make_char([&"xuanbing_palace"], "blue", "character", 3),
		_make_char([&"xuehai_temple"], "blue", "character", 3),
		_make_char([&"meiying_pavilion"], "blue", "character", 3),
	]
	var state: Dictionary = _make_state(chars, [])
	var result: StringName = ss.detect(state)
	assert_eq(result, &"righteous_dev",
		"同时满足正道+正邪混合 → 应返回正道（priority 2 < 4）")


# ============================================================================
# AC-012：detect 优先级——归墟 > 正道
# ============================================================================

func test_ac012_detect_priority_spirit_realm_over_righteous() -> void:
	# 同时满足归墟（priority 1）和正道（priority 2）条件
	# 归墟需要：金丹期、归墟/真灵≥2、平均费用≥3.0、无低于蓝色稀有度
	# 正道需要：正道≥3、正道占比≥60%
	var chars: Array = [
		_make_char([&"guixu_abyss"], "blue", "character", 4),
		_make_char([&"guixu_abyss"], "blue", "character", 4),
		_make_char([&"qixuanmen"], "blue", "character", 3),
		_make_char([&"dangxia_valley"], "blue", "character", 3),
		_make_char([&"dongyu"], "blue", "character", 3),
	]
	var deck: Array = [
		_make_card("character", 4, "blue"),
		_make_card("character", 4, "blue"),
	]
	var state: Dictionary = _make_state(chars, deck, 3)  # 金丹期
	var result: StringName = ss.detect(state)
	assert_eq(result, &"spirit_realm_beast",
		"同时满足归墟+正道 → 应返回归墟（priority 1 最高）")


# ============================================================================
# AC-013：detect 无流派满足返回空
# ============================================================================

func test_ac013_detect_no_match_returns_empty() -> void:
	var chars: Array = [
		_make_char([&"qixuanmen"], "blue", "character", 3),  # 仅 1 个正道——不足
	]
	var state: Dictionary = _make_state(chars, [])
	var result: StringName = ss.detect(state)
	assert_eq(result, &"", "不满足任何流派应返回空 StringName")


# ============================================================================
# AC-014：calculate_match 权重
# ============================================================================

func test_ac014_calculate_match_weights() -> void:
	# 阵营人数 = 2/3（权重 40）→ 40 × 2/3 ≈ 26.67
	# 条件全部满足 → 权重 40 + 30 + 20 + 10 = 100... 但没有必备角色和卡牌类型占比条件
	# 正道条件：阵营人数（权重 40）+ 阵营占比（权重 40）= 80
	# 阵营人数 2/3 → 40 * 2/3 = 26.67
	# 阵营占比 2/2 = 100% ≥ 60% → 40 * 1.0 = 40
	# total = 66.67 / 80 * 100 ≈ 83
	var chars: Array = [
		_make_char([&"qixuanmen"], "blue", "character", 3),
		_make_char([&"dangxia_valley"], "blue", "character", 3),  # 2/3 正道
	]
	var state: Dictionary = _make_state(chars, [])
	var result: Dictionary = ss.calculate_match(&"righteous_dev", state)
	# 阵营人数 2/3 → 40 * 2/3 = 26.67
	# 阵营占比 2/2 = 100% → 40 * 1.0 = 40
	# total = 66.67 / 80 * 100 ≈ 83
	assert_true(result["score"] >= 80.0, "score 应 ≥ 80")
	assert_true(result["score"] <= 90.0, "score 应 ≤ 90")
	assert_true(result["missing"].size() > 0, "应有一条 missing（阵营人数不足）")


# ============================================================================
# AC-015：calculate_match score 范围 [0, 100]
# ============================================================================

func test_ac015_calculate_match_score_range() -> void:
	# 全满足 → 100
	var chars: Array = [
		_make_char([&"qixuanmen"], "blue", "character", 3),
		_make_char([&"dangxia_valley"], "blue", "character", 3),
		_make_char([&"dongyu"], "blue", "character", 3),
	]
	var state: Dictionary = _make_state(chars, [])
	var result: Dictionary = ss.calculate_match(&"righteous_dev", state)
	assert_eq(result["score"], 100.0, "全满足应 score=100")
	assert_eq(result["missing"].size(), 0, "全满足 missing 应为空")

	# 全不满足 → 0 或接近 0
	var empty_state: Dictionary = _make_state([], [])
	var result2: Dictionary = ss.calculate_match(&"righteous_dev", empty_state)
	assert_true(result2["score"] >= 0.0, "全不满足 score ≥ 0")
	assert_true(result2["score"] <= 10.0, "全不满足 score 应接近 0")


# ============================================================================
# AC-016：calculate_match missing 人类可读
# ============================================================================

func test_ac016_calculate_match_missing_human_readable() -> void:
	var chars: Array = [
		_make_char([&"qixuanmen"], "blue", "character", 3),
		_make_char([&"dangxia_valley"], "blue", "character", 3),  # 2/3 正道
	]
	var state: Dictionary = _make_state(chars, [])
	var result: Dictionary = ss.calculate_match(&"righteous_dev", state)
	assert_true(result["missing"].size() > 0, "应有 missing 条目")
	# 检查含人类可读描述
	var first_missing: String = result["missing"][0]
	assert_true(first_missing.contains("需"), "missing 应含描述性文字")


# ============================================================================
# AC-017：未知 school_id 返回空
# ============================================================================

func test_ac017_unknown_school_id_error_handling() -> void:
	assert_eq(ss.get_school_info(&"nonexistent").size(), 0, "get_school_info 未知ID→空字典")
	assert_eq(ss.get_school_effects(&"nonexistent").size(), 0, "get_school_effects 未知ID→空数组")
	var match: Dictionary = ss.calculate_match(&"nonexistent", _make_state())
	assert_eq(match["score"], 0.0, "calculate_match 未知ID→score=0")
	assert_true(match["missing"].size() > 0, "calculate_match 未知ID→含 missing")


# ============================================================================
# AC-018：const SCHOOL_LIBRARY 不可变性
# ============================================================================

func test_ac018_school_library_const_integrity() -> void:
	# 验证流派模板内容未被运行时修改
	assert_eq(ss.SCHOOL_LIBRARY[&"righteous_dev"].name, "正道发育流",
		"正道发育流 name 应不变")
	assert_eq(ss.SCHOOL_LIBRARY[&"spirit_realm_beast"].priority, 1,
		"归墟真灵流 priority 应不变")
	assert_eq(ss.SCHOOL_LIBRARY[&"alchemy_mastery"].priority, 5,
		"百艺炼丹流 priority 应不变")
	# 5 流派 ID 不变
	var schools: Array[StringName] = ss.get_all_schools()
	assert_eq(schools.size(), 5, "流派总数应不变")


# ============================================================================
# 边缘情况补强
# ============================================================================

func test_detect_demonic_aggro() -> void:
	var chars: Array = [
		_make_char([&"xuehai_temple"], "blue", "character", 2),
		_make_char([&"meiying_pavilion"], "blue", "character", 1),
		_make_char([&"samsara_hall"], "blue", "character", 2),
	]
	var deck: Array = [
		_make_card("character", 2, "blue"),
		_make_card("character", 1, "blue"),
		_make_card("character", 2, "blue"),
	]
	var state: Dictionary = _make_state(chars, deck)
	var result: StringName = ss.detect(state)
	assert_eq(result, &"demonic_aggro", "应返回魔道快攻流")


func test_detect_mixed_alignment() -> void:
	var chars: Array = [
		_make_char([&"qixuanmen"], "blue", "character", 3),
		_make_char([&"dongyu"], "blue", "character", 3),
		_make_char([&"xuehai_temple"], "blue", "character", 3),
		_make_char([&"meiying_pavilion"], "blue", "character", 3),
	]
	var state: Dictionary = _make_state(chars, [])
	var result: StringName = ss.detect(state)
	# 正道 2/4 = 50% < 60% → 不满足正道发育流
	# 魔道 2/4 = 50% < 60% → 不满足魔道快攻流
	# 正道≥2 + 魔道≥2 + 正道占比 50% ∈ [30%,70%] + 魔道占比 50% ∈ [30%,70%] → 正邪混合流
	assert_eq(result, &"mixed_alignment", "应返回正邪混合流")


func test_detect_spirit_realm_beast() -> void:
	var chars: Array = [
		_make_char([&"guixu_abyss"], "blue", "character", 4),
		_make_char([&"guixu_abyss"], "purple", "character", 4),
	]
	var deck: Array = [
		_make_card("character", 4, "blue"),
		_make_card("character", 3, "blue"),
	]
	var state: Dictionary = _make_state(chars, deck, 3)
	var result: StringName = ss.detect(state)
	assert_eq(result, &"spirit_realm_beast", "应返回归墟真灵流")


func test_detect_alchemy_mastery() -> void:
	var chars: Array = [
		_make_char([&"wanxiang_pavilion"], "blue", "character", 3, &"wanxiang_zhenren"),
	]
	var deck: Array = []
	for i in range(5):
		deck.append(_make_card("pill", 2, "blue"))
	for i in range(15):
		deck.append(_make_card("character", 3, "blue"))
	# 丹药占比 5/20 = 25% ≥ 20%
	var state: Dictionary = _make_state(chars, deck, 1, 3, [&"wanxiang_zhenren"])
	var result: StringName = ss.detect(state)
	assert_eq(result, &"alchemy_mastery", "应返回百艺炼丹流")


func test_detect_excluded_modao_blocks_righteous() -> void:
	# 有魔道限定卡 → 正道发育流不激活
	var chars: Array = [
		_make_char([&"qixuanmen"], "blue", "character", 3),
		_make_char([&"dangxia_valley"], "blue", "character", 3),
		_make_char([&"dongyu"], "blue", "character", 3),
	]
	var deck: Array = [
		_make_card("character", 3, "blue", true),  # 魔道限定卡
	]
	var state: Dictionary = _make_state(chars, deck)
	var result: StringName = ss.detect(state)
	assert_ne(result, &"righteous_dev", "含魔道限定卡不应激活正道发育流")


func test_calculate_match_full_score_100() -> void:
	var chars: Array = [
		_make_char([&"qixuanmen"], "blue", "character", 3),
		_make_char([&"dangxia_valley"], "blue", "character", 3),
		_make_char([&"dongyu"], "blue", "character", 3),
	]
	var state: Dictionary = _make_state(chars, [])
	var result: Dictionary = ss.calculate_match(&"righteous_dev", state)
	assert_eq(result["score"], 100.0, "全满足应 score=100")
	assert_eq(result["missing"].size(), 0, "全满足应无 missing")


func test_calculate_match_score_zero_on_empty() -> void:
	var state: Dictionary = _make_state([], [])
	var result: Dictionary = ss.calculate_match(&"righteous_dev", state)
	assert_eq(result["score"], 0.0, "空场应 score=0")
	assert_true(result["missing"].size() > 0, "空场应有 missing")


func test_school_changed_signal_emission() -> void:
	# 验证信号可连接和发射
	var payload: Array = []
	ss.school_changed.connect(func(old_s, new_s): payload.append([old_s, new_s]))
	ss.school_changed.emit(&"righteous_dev", &"demonic_aggro")
	assert_eq(payload.size(), 1, "信号应发射 1 次")
	assert_eq(payload[0][0], &"righteous_dev", "old_school_id 应匹配")
	assert_eq(payload[0][1], &"demonic_aggro", "new_school_id 应匹配")


func test_detect_min_rarity_blocks_spirit_realm() -> void:
	# 归墟流派要求场上无低于蓝色稀有度角色
	var chars: Array = [
		_make_char([&"guixu_abyss"], "blue", "character", 4),
		_make_char([&"guixu_abyss"], "green", "character", 4),  # 绿色 < 蓝色！
	]
	var deck: Array = [
		_make_card("character", 4, "blue"),
		_make_card("character", 3, "blue"),
	]
	var state: Dictionary = _make_state(chars, deck, 3)
	var result: StringName = ss.detect(state)
	assert_ne(result, &"spirit_realm_beast", "含绿色稀有度角色不应激活归墟真灵流")


func test_detect_max_dark_gold_blocks_mixed() -> void:
	# 正邪混合流要求暗金卡不超过 1 张
	var chars: Array = [
		_make_char([&"qixuanmen"], "blue", "character", 3),
		_make_char([&"dongyu"], "blue", "character", 3),
		_make_char([&"xuehai_temple"], "blue", "character", 3),
		_make_char([&"meiying_pavilion"], "blue", "character", 3),
	]
	var deck: Array = [
		_make_card("character", 5, "dark_gold"),
		_make_card("character", 5, "dark_gold"),
	]
	var state: Dictionary = _make_state(chars, deck)
	var result: StringName = ss.detect(state)
	assert_ne(result, &"mixed_alignment", "暗金卡 >1 不应激活正邪混合流")


func test_detect_avg_card_cost_blocks_spirit_realm() -> void:
	# 归墟流派要求平均费用 ≥3.0
	var chars: Array = [
		_make_char([&"guixu_abyss"], "blue", "character", 4),
		_make_char([&"guixu_abyss"], "blue", "character", 4),
	]
	var deck: Array = [
		_make_card("character", 1, "blue"),  # 低费卡——拉低均值
		_make_card("character", 1, "blue"),
	]
	var state: Dictionary = _make_state(chars, deck, 3)
	var result: StringName = ss.detect(state)
	assert_ne(result, &"spirit_realm_beast", "平均费用 <3.0 不应激活归墟真灵流")


func test_detect_alchemy_count_blocks_alchemy_mastery() -> void:
	# 百艺流派要求炼丹 ≥3 次
	var chars: Array = [
		_make_char([&"wanxiang_pavilion"], "blue", "character", 3, &"wanxiang_zhenren"),
	]
	var deck: Array = []
	for i in range(5):
		deck.append(_make_card("pill", 2, "blue"))
	for i in range(15):
		deck.append(_make_card("character", 3, "blue"))
	# 丹药占比 25% ≥ 20%，万象真人在场，但炼丹次数=0
	var state: Dictionary = _make_state(chars, deck, 1, 0, [&"wanxiang_zhenren"])
	var result: StringName = ss.detect(state)
	assert_eq(result, &"", "炼丹次数不足不应激活百艺炼丹流")