extends GutTest
## InventoryCatalog 单元测试：三分类表 / 分类栏文案 / 属性中文标签 / 排序。[br]
## [br][b]纯函数直调[/b]——无场景树、无 Autoload。风格先例
## [code]tests/unit/main_menu/test_continue_button_state.gd[/code]（arrange/act/assert）。
##
## 覆盖本轮点名验收：① 分类过滤口径的「分类表本身」是什么（三分类 + 各自数据源）；
## ④ 空态文案（每分类各一条，且不为空）；排序（稀有度降序 → 名称升序）。

const Catalog := preload("res://src/feature/inventory/inventory_catalog.gd")


func _entry(p_name: String, p_rarity: int) -> Dictionary:
	## 测试数据：排序用例的最小条目（只有比较器用到的两个键）。
	return {"name": p_name, "rarity": p_rarity}


# ═══════════════════════════════════════════════════════════════════════════════
# 分类表
# ═══════════════════════════════════════════════════════════════════════════════

func test_catalog_has_three_categories_in_declared_order() -> void:
	## 分类表恰三类（灵材 / 丹药 / 法宝），且顺序即界面顺序——本轮点名的三类。
	# Arrange + Act + Assert
	assert_eq(Catalog.category_count(), 3, "背包应恰有三个分类")
	assert_eq(Catalog.category_name(0), "灵材", "第 1 类应为灵材")
	assert_eq(Catalog.category_name(1), "丹药", "第 2 类应为丹药")
	assert_eq(Catalog.category_name(2), "法宝", "第 3 类应为法宝")


func test_catalog_categories_declare_their_data_source() -> void:
	## 每个分类都必须声明「去哪儿取数」——灵材在 resources.ling_cai，
	## 丹药/法宝在 collection（数据形态不同，见类文档）。
	# Arrange + Act + Assert
	assert_eq(Catalog.category_at(0).get("source"), Catalog.SOURCE_LING_CAI,
			"灵材应声明显式数据源 ling_cai")
	for index: int in [1, 2]:
		assert_eq(Catalog.category_at(index).get("source"),
				Catalog.SOURCE_COLLECTION,
				"分类 %d 应声明显式数据源 collection" % index)


func test_catalog_collection_categories_map_to_card_types() -> void:
	## 丹药 → CardType.PILL(4)、法宝 → CardType.ARTIFACT(2)——与
	## [code]CardTemplate.CardType[/code] 的枚举值一致（过滤口径的唯一真理来源）。
	# Arrange + Act + Assert
	assert_eq(int(Catalog.category_at(1).get("card_type")), 4, "丹药应映射 PILL=4")
	assert_eq(int(Catalog.category_at(2).get("card_type")), 2, "法宝应映射 ARTIFACT=2")


func test_catalog_out_of_range_category_is_empty_dictionary() -> void:
	## 越界取分类返回空字典（调用方据此显示空态而非崩溃）——含负下标。
	# Arrange + Act + Assert
	assert_true((Catalog.category_at(-1) as Dictionary).is_empty(),
			"负下标应返回空字典")
	assert_true((Catalog.category_at(3) as Dictionary).is_empty(),
			"越界下标应返回空字典")
	assert_eq(Catalog.category_name(9), "", "越界分类名应为空串")


# ═══════════════════════════════════════════════════════════════════════════════
# 空态文案（点名验收 ④）
# ═══════════════════════════════════════════════════════════════════════════════

func test_catalog_every_category_has_non_empty_chinese_empty_text() -> void:
	## 三个分类各有一条非空中态文案（「数据为空时给中文空态文案」）。
	# Arrange + Act + Assert
	for index: int in range(Catalog.category_count()):
		var text: String = Catalog.empty_text(index)
		assert_false(text.strip_edges().is_empty(),
				"分类 %d 应有空态文案" % index)
		assert_true(text.contains("——"),
				"空态文案应与既有面板同一格式（此处 XXX——YYY）: %s" % text)


func test_catalog_empty_texts_are_distinct_per_category() -> void:
	## 三条空态文案互不相同——「没有丹药」与「没有法宝」对玩家的下一步提示不同，
	## 共用一句会让玩家以为是同一个问题。
	# Arrange
	var seen: Array = []
	# Act
	for index: int in range(Catalog.category_count()):
		seen.append(Catalog.empty_text(index))
	# Assert
	assert_eq(seen.size(), 3, "应有三条文案")
	assert_eq(seen.size(), _unique_count(seen), "三条空态文案应互不相同")


func test_catalog_out_of_range_empty_text_falls_back() -> void:
	## 越界分类的空态文案回退为通用句（不返回空串——空串会让面板一片空白）。
	# Arrange + Act + Assert
	assert_false(Catalog.empty_text(99).strip_edges().is_empty(),
			"越界空态文案不应为空串")


func _unique_count(p_values: Array) -> int:
	var unique: Array = []
	for value: Variant in p_values:
		if not unique.has(value):
			unique.append(value)
	return unique.size()


# ═══════════════════════════════════════════════════════════════════════════════
# 分类栏文案（角标 + 选中态）
# ═══════════════════════════════════════════════════════════════════════════════

func test_category_bar_text_marks_selected_and_counts() -> void:
	## 选中项用方括号标记；有内容的分类带角标。选中在第 0 类时形如
	## 「[灵材 (3)]  丹药  法宝」。
	# Arrange
	var counts: Dictionary = {0: 3, 1: 0, 2: 0}
	# Act
	var text: String = Catalog.category_bar_text(counts, 0)
	# Assert
	assert_true(text.begins_with("[灵材 (3)]"), "选中项应带方括号与角标: %s" % text)
	assert_true(text.contains("丹药"), "未选中项应仍列出")
	assert_false(text.contains("丹药 ("), "数量为 0 的分类不显示数字")


func test_category_bar_text_selection_follows_index() -> void:
	## 选中标记跟随下标移动（不是恒标第一项）。
	# Arrange
	var counts: Dictionary = {0: 1, 1: 2, 2: 5}
	# Act
	var text: String = Catalog.category_bar_text(counts, 2)
	# Assert
	assert_true(text.contains("[法宝 (5)]"), "第 3 类应被标为选中: %s" % text)
	assert_false(text.contains("[灵材"), "未选中项不应带方括号")


func test_category_bar_text_all_zero_still_lists_every_category() -> void:
	## 全空时分类名仍在（玩家要看得见「这里本该有哪几类」），只是没有角标。
	# Arrange + Act
	var text: String = Catalog.category_bar_text({}, 0)
	# Assert
	assert_true(text.contains("灵材") and text.contains("丹药") and text.contains("法宝"),
			"全空时三个分类名都应出现: %s" % text)
	assert_false(text.contains("("), "全空时不应出现任何角标")


# ═══════════════════════════════════════════════════════════════════════════════
# 属性中文标签（境界配置表 → 界面词条）
# ═══════════════════════════════════════════════════════════════════════════════

func test_attribute_label_translates_known_realm_table_keys() -> void:
	## 境界配置表里的键都能译成中文标签——数值现查表，标签在这一处。
	# Arrange
	var realm_table: Dictionary = preload(
			"res://src/core/realm_system.gd").realm_table
	# Act + Assert
	for key: Variant in (realm_table[1] as Dictionary).keys():
		var text_key: String = str(key)
		if text_key == "name":
			continue  # 境界名不是「属性行」，面板单独展示
		var label: String = Catalog.attribute_label(text_key)
		assert_ne(label, text_key,
				"境界表键 '%s' 应已登记中文标签（否则界面会露出英文键名）" % text_key)


func test_attribute_label_unknown_key_falls_back_to_key_name() -> void:
	## 未登记的键回退为键名本身（不返回空串）——境界表将来加键时界面自动多一行，
	## 宁可显示得朴素，也不静默吞掉一个已配置的属性。
	# Arrange + Act + Assert
	assert_eq(Catalog.attribute_label("some_new_key"), "some_new_key",
			"未登记键应回退键名而非空串")


# ═══════════════════════════════════════════════════════════════════════════════
# 排序（点名验收「分类过滤与排序」的排序半边）
# ═══════════════════════════════════════════════════════════════════════════════

func test_sort_puts_higher_rarity_first() -> void:
	## 稀有度降序——金卡排在紫卡之前，与商店/收藏的展示惯例一致。
	# Arrange
	var entries: Array = [
		_entry("丙", 1), _entry("甲", 5), _entry("乙", 3),
	]
	# Act
	entries.sort_custom(Catalog.sort_desc_by_rarity)
	# Assert
	assert_eq([entries[0]["name"], entries[1]["name"], entries[2]["name"]],
			["甲", "乙", "丙"], "应按稀有度降序")


func test_sort_breaks_ties_by_name_ascending() -> void:
	## 同稀有度按名称升序——收藏池的追加顺序随玩法变化，按名称排才能让「同一份
	## 存档每次打开看到的顺序一致」。
	# Arrange
	var entries: Array = [_entry("丙", 3), _entry("甲", 3), _entry("乙", 3)]
	# Act
	entries.sort_custom(Catalog.sort_desc_by_rarity)
	# Assert
	assert_eq([entries[0]["name"], entries[1]["name"], entries[2]["name"]],
			["丙", "乙", "甲"], "同稀有度应按名称升序（中文按码位比较）")


func test_sort_missing_rarity_treated_as_lowest() -> void:
	## 缺 rarity 键的条目按 0 处理 → 排到最后（不臆造稀有度，也不因此崩溃）。
	# Arrange
	var entries: Array = [{"name": "无档"}, _entry("有档", 1)]
	# Act
	entries.sort_custom(Catalog.sort_desc_by_rarity)
	# Assert
	assert_eq(entries[0]["name"], "有档", "有稀有度的条目应排在前面")
	assert_eq(entries[1]["name"], "无档", "缺稀有度的条目应排在最后")


func test_sort_is_stable_across_repeated_calls() -> void:
	## 同一份输入排序两次结果一致——界面刷新不该让行序跳动。
	# Arrange
	var first: Array = [_entry("乙", 2), _entry("甲", 2), _entry("丙", 4)]
	var second: Array = [_entry("乙", 2), _entry("甲", 2), _entry("丙", 4)]
	# Act
	first.sort_custom(Catalog.sort_desc_by_rarity)
	second.sort_custom(Catalog.sort_desc_by_rarity)
	# Assert
	assert_eq(first, second, "同输入两次排序应得到同一顺序")


# ═══════════════════════════════════════════════════════════════════════════════
# 灵材品质口径
# ═══════════════════════════════════════════════════════════════════════════════

func test_ling_cai_quality_tables_cover_four_tiers() -> void:
	## 灵材四档（下品/中品/上品/极品）各有中文名与展示稀有度，键与
	## [code]GSM.player.resources.ling_cai[/code] 的键一致。
	# Arrange + Act + Assert
	assert_eq(Catalog.LING_CAI_QUALITY_KEYS.size(), 4, "灵材应有四档")
	for key: String in Catalog.LING_CAI_QUALITY_KEYS:
		assert_true(Catalog.LING_CAI_QUALITY_NAMES.has(key),
				"档位 '%s' 应有中文名" % key)
		assert_true(Catalog.LING_CAI_QUALITY_RARITY.has(key),
				"档位 '%s' 应有展示稀有度" % key)
	assert_eq(Catalog.LING_CAI_QUALITY_KEYS, ["low", "medium", "high", "top"],
			"档位键应与存档里的 ling_cai 字典同序同键")
