extends "res://tests/unit/inventory/inventory_model_fixture.gd"
## InventoryModel 单元测试：灵材分类 / 数量为 0 不显示 / 排序 / 分类栏。[br]
## [br][b]装置见 [inventory_model_fixture.gd][/b]（内嵌桩 + 造数据小工具）；
## 丹药与法宝分类的用例在 [code]test_inventory_model_collection.gd[/code]
## （两个文件共用装置，各自回 300 行内）。[br]
##
## 覆盖本轮点名验收：① 背包分类过滤与排序；④ 空态（数量为 0 不显示）。


# ═══════════════════════════════════════════════════════════════════════════════
# 灵材分类（数量为 0 不显示）
# ═══════════════════════════════════════════════════════════════════════════════

func test_ling_cai_category_lists_only_non_zero_tiers() -> void:
	## 数量为 0 的档位不出行（本轮硬性要求）——下品 3 / 上品 1，中品与极品为 0。
	# Arrange
	set_ling_cai(3, 0, 1, 0)
	# Act
	var entries: Array = model.category_entries(CATEGORY_LING_CAI)
	# Assert
	assert_eq(entries.size(), 2, "只有两个非零档位应出行（0 的不显示）")
	var names: Array = [entries[0]["name"], entries[1]["name"]]
	assert_true(names.has("下品灵材"), "下品有 3 个应出行为: %s" % str(names))
	assert_true(names.has("上品灵材"), "上品有 1 个应出行为: %s" % str(names))


func test_ling_cai_category_carries_real_counts_and_quality_rarity() -> void:
	## 数量取自存档原值（不加工），稀有度取自档位表（下品=1…极品=4）。[br]
	## [br][b]行序即排序结果[/b]——极品（稀有度 4）在前、下品（1）在后，故断言按
	## 「名字找行」而不是「按下标取行」：下标会随排序口径变化，名字不会。
	# Arrange
	set_ling_cai(7, 0, 0, 2)
	# Act
	var entries: Array = model.category_entries(CATEGORY_LING_CAI)
	var top: Dictionary = {}
	var low: Dictionary = {}
	for entry: Dictionary in entries:
		if entry["name"] == "极品灵材":
			top = entry
		elif entry["name"] == "下品灵材":
			low = entry
	# Assert
	assert_eq(int(top.get("count", 0)), 2, "极品灵材的行数量应为存档里的 2")
	assert_eq(int(top.get("rarity", 0)), 4, "极品档的排序刻度应为 4")
	assert_eq(str(top.get("rarity_name", "")), "",
			"灵材不借卡牌稀有度词条（品阶与金/暗金是两套刻度，见模型注记）")
	assert_eq(int(low.get("count", 0)), 7, "下品灵材的行数量应为 7")
	assert_eq(entries[0]["name"], "极品灵材", "稀有度高的档位应排在前")


func test_ling_cai_empty_storage_yields_no_entries() -> void:
	## 四档全 0 → 无条目（空态由面板按分类文案显示，模型不产出占位行）。
	# Arrange
	set_ling_cai(0, 0, 0, 0)
	# Act + Assert
	assert_eq(model.category_entries(CATEGORY_LING_CAI), [], "全 0 时不应产出任何条目")


func test_ling_cai_legacy_flat_storage_does_not_crash() -> void:
	## 旧存档的扁平 int 形态（迁移前格式）读不出四档——按「没有灵材」处理，不报错。
	# Arrange
	gsm.player = {"resources": {"ling_cai": 0}}
	# Act + Assert
	assert_eq(model.category_entries(CATEGORY_LING_CAI), [],
			"旧档扁平形态应视作无灵材而非崩溃")


func test_ling_cai_missing_player_domain_yields_no_entries() -> void:
	## GSM 域缺失（player 不是字典）——同样按空处理。
	# Arrange
	gsm.player = null
	# Act + Assert
	assert_eq(model.category_entries(CATEGORY_LING_CAI), [], "player 域不可用时不应产出条目")


func test_ling_cai_entries_sorted_by_quality_rarity_descending() -> void:
	## 灵材按展示稀有度降序（极品在前、下品在后）——与丹药/法宝共用一套排序口径。
	# Arrange
	set_ling_cai(1, 1, 1, 1)
	# Act
	var entries: Array = model.category_entries(CATEGORY_LING_CAI)
	# Assert
	assert_eq([entries[0]["name"], entries[3]["name"]],
			["极品灵材", "下品灵材"], "灵材应按品质由高到低排列")


# ═══════════════════════════════════════════════════════════════════════════════
# 分类计数与分类栏
# ═══════════════════════════════════════════════════════════════════════════════

func test_category_counts_cover_every_category() -> void:
	## 计数返回全部分类（含 0 的分类）——分类栏要能显示「这一类是空的」。
	# Arrange
	set_ling_cai(1, 0, 0, 0)
	cards.templates = {"hui_chun": _template("回春丹", 4, 2)}
	set_owned(["hui_chun"])
	# Act
	var counts: Dictionary = model.category_counts()
	# Assert
	assert_eq(counts.size(), Catalog.category_count(), "计数应覆盖每个分类")
	assert_eq(int(counts.get(CATEGORY_LING_CAI, 0)), 1, "灵材分类应有 1 行")
	assert_eq(int(counts.get(CATEGORY_PILL, 0)), 1, "丹药分类应有 1 行")
	assert_eq(int(counts.get(CATEGORY_ARTIFACT, 0)), 0, "无法宝时法宝分类应为 0")


func test_category_bar_text_reflects_real_counts() -> void:
	## 分类栏文案里的角标就是真实行数（面板不自己数——口径单一）。
	# Arrange
	set_ling_cai(2, 0, 0, 0)
	# Act
	var text: String = model.category_bar_text(CATEGORY_LING_CAI)
	# Assert
	assert_true(text.begins_with("[灵材 (1)]"), "选中分类应带方括号与真实行数: %s" % text)


func test_out_of_range_category_returns_empty_array() -> void:
	## 越界分类取条目返回空数组（面板显示空态，不崩）。
	# Arrange + Act + Assert
	assert_eq(model.category_entries(42), [], "越界分类不应产出条目")
	assert_eq(model.category_entries(-1), [], "负下标分类不应产出条目")


func test_model_without_any_dependency_is_silent() -> void:
	## 两个依赖都缺——所有分类返回空，且不抛错（剥离 Autoload 的测试环境路径）。
	# Arrange
	var bare: RefCounted = ModelScript.new(null, null)
	# Act + Assert
	for index: int in range(Catalog.category_count()):
		var entries: Array = bare.call(&"category_entries", index)
		assert_true(entries is Array, "分类 %d 应返回数组而非 null" % index)
