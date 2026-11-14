extends "res://tests/unit/inventory/inventory_model_fixture.gd"
## InventoryModel 单元测试（收藏类分类）：按模板类型过滤 / 同名合并 / 排序 /
## 模板查不到不臆造。[br]
## [br][b]装置见 [inventory_model_fixture.gd][/b]（内嵌桩 + 造数据小工具）；
## 灵材分类与分类栏的用例在 [code]test_inventory_model.gd[/code]
## （两个文件共用装置，各自回 300 行内）。[br]
##
## 覆盖本轮点名验收：① 背包分类过滤与排序（丹药 / 法宝两侧）。


# ═══════════════════════════════════════════════════════════════════════════════
# 按模板类型过滤
# ═══════════════════════════════════════════════════════════════════════════════

func test_pill_category_filters_by_card_type() -> void:
	## 丹药分类只出 PILL(4) 的卡——功法(1)、法宝(2)、角色(0) 都不该混进来。
	# Arrange
	cards.templates = {
		"hui_chun": _template("回春丹", 4, 2),
		"jin_dan": _template("九转金丹", 4, 5),
		"fa_qi": _template("基础法器", 2, 2),
		"gong_fa": _template("吐纳诀", 1, 1),
		"char": _template("林渊", 0, 2),
	}
	set_owned(["hui_chun", "jin_dan", "fa_qi", "gong_fa", "char"])
	# Act
	var entries: Array = model.category_entries(CATEGORY_PILL)
	# Assert
	assert_eq(entries.size(), 2, "丹药分类应只剩两张丹药")
	for entry: Dictionary in entries:
		assert_false(str(entry["name"]).is_empty(), "条目应有名称")


func test_artifact_category_filters_by_card_type() -> void:
	## 法宝分类只出 ARTIFACT(2) 的卡。
	# Arrange
	cards.templates = {
		"hui_chun": _template("回春丹", 4, 2),
		"fa_qi": _template("基础法器", 2, 2),
		"ling_bao": _template("通天灵宝", 2, 5),
	}
	set_owned(["hui_chun", "fa_qi", "ling_bao"])
	# Act
	var entries: Array = model.category_entries(CATEGORY_ARTIFACT)
	# Assert
	assert_eq(entries.size(), 2, "法宝分类应只剩两件法宝")
	var names: Array = [entries[0]["name"], entries[1]["name"]]
	assert_false(names.has("回春丹"), "丹药不应出现在法宝分类: %s" % str(names))


func test_unknown_template_is_skipped_not_fabricated() -> void:
	## 模板查不到（异步加载未完成 / 未知 ID）时跳过该实例——不臆造名称与档位。
	# Arrange
	cards.templates = {"hui_chun": _template("回春丹", 4, 2)}
	set_owned(["hui_chun", "not_loaded_yet"])
	# Act
	var entries: Array = model.category_entries(CATEGORY_PILL)
	# Assert
	assert_eq(entries.size(), 1, "查不到模板的实例应被跳过")
	assert_eq(int((entries[0] as Dictionary).get("count", 0)), 1,
			"跳过后计数不应把未知实例算进去")


func test_entry_without_template_id_is_skipped() -> void:
	## 收藏条目缺 template_id（脏数据）——跳过而非拿空串去查表。
	# Arrange
	cards.templates = {"hui_chun": _template("回春丹", 4, 2)}
	gsm.collection = {"owned_cards": [{"card_instance_id": 1}, "not_a_dict"]}
	# Act + Assert
	assert_eq(model.category_entries(CATEGORY_PILL), [], "脏条目应被跳过（含非字典项）")


func test_missing_card_system_yields_no_collection_entries() -> void:
	## 卡牌系统不可用（Autoload 未就绪）——收藏类分类返回空，不崩。
	# Arrange
	model.set_dependencies(gsm, null)
	# Act + Assert
	assert_eq(model.category_entries(CATEGORY_PILL), [], "卡牌系统不可用时不应产出条目")


# ═══════════════════════════════════════════════════════════════════════════════
# 同名合并
# ═══════════════════════════════════════════════════════════════════════════════

func test_same_template_merges_into_one_row_with_count() -> void:
	## 同名多张合并成一行「名称 ×N」（GDD card-system.md §边界「收藏池允许同名多张」）
	## ——不铺成 N 行重复项。
	# Arrange
	cards.templates = {"hui_chun": _template("回春丹", 4, 2)}
	set_owned(["hui_chun", "hui_chun", "hui_chun"])
	# Act
	var entries: Array = model.category_entries(CATEGORY_PILL)
	# Assert
	assert_eq(entries.size(), 1, "同一 template_id 的三张应合并为一行")
	assert_eq(int((entries[0] as Dictionary).get("count", 0)), 3,
			"合并行的数量应为 3")
	assert_eq(str((entries[0] as Dictionary).get("name", "")), "回春丹",
			"合并行应显示模板名")


# ═══════════════════════════════════════════════════════════════════════════════
# 排序（点名验收「分类过滤与排序」的排序半边）
# ═══════════════════════════════════════════════════════════════════════════════

func test_collection_entries_sorted_by_rarity_descending() -> void:
	## 丹药按稀有度降序——九转金丹(5) 在 天罗丹(4) 之前，玉灵丹(3) 殿后。
	# Arrange
	cards.templates = {
		"yu_ling": _template("玉灵丹", 4, 3),
		"jin_dan": _template("九转金丹", 4, 5),
		"tian_luo": _template("天罗丹", 4, 4),
	}
	set_owned(["yu_ling", "jin_dan", "tian_luo"])
	# Act
	var entries: Array = model.category_entries(CATEGORY_PILL)
	# Assert
	assert_eq([entries[0]["name"], entries[1]["name"], entries[2]["name"]],
			["九转金丹", "天罗丹", "玉灵丹"], "应按稀有度降序排列")


func test_repeated_reads_return_identical_order() -> void:
	## 同一份存档连读两次顺序一致（零缓存 + 确定性排序）——界面刷新不该让行序跳动。
	# Arrange
	cards.templates = {
		"a": _template("乙丹", 4, 2), "b": _template("甲丹", 4, 2),
	}
	set_owned(["a", "b"])
	# Act
	var first: Array = model.category_entries(CATEGORY_PILL)
	var second: Array = model.category_entries(CATEGORY_PILL)
	# Assert
	assert_eq(first, second, "两次读取应得到完全相同的条目数组")
