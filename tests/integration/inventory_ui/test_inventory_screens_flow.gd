extends "res://tests/integration/inventory_ui/inventory_screens_fixture.gd"
## 背包页端到端测试（真实 Autoload + 真实存档 + 真实界面控件）。[br]
## [br][b]覆盖本轮点名验收[/b]：[br]
##   ① 背包分类过滤与排序——真实 [code]ResourceSystem[/code] / [code]CardSystem[/code]
##      写入的数据在界面上按分类与稀有度呈现；[br]
##   ④ 空态文案——各分类各一条中文空态；[br]
##   另加：开关与页签、方向键切分类、返回不掉状态（含「不改状态」）。[br]
## [br][b]角色状态那一半在[/b] [code]test_character_status_flow.gd[/code]
## （两个文件共用 [inventory_screens_fixture.gd]，各自回 300 行内）。[br]
## [br][b]装置见 [inventory_screens_fixture.gd][/b]（快照还原 + 真实写入入口 + 模板就位）。
##
## 来源: 本轮任务书第 1-4 条、先例
## [code]tests/integration/exploration_ui/test_shop_and_rest_node_flow.gd[/code]。


# ═══════════════════════════════════════════════════════════════════════════════
# 开关与页签
# ═══════════════════════════════════════════════════════════════════════════════

func test_open_shows_inventory_page_and_hides_status_page() -> void:
	## 打开后默认停在背包页，另一页隐藏——一次只呈现一件事。
	# Act
	host.open()
	# Assert
	assert_true(host.is_open(), "open 后应处于打开态")
	assert_true(inventory_page().visible, "默认应显示背包页")
	assert_false(status_page().visible, "角色状态页应隐藏")


func test_tab_button_switches_between_pages() -> void:
	## 点页签切到下一页；再点回来——两页互斥可见。
	# Act
	open_page(0)
	host.press_tab()
	# Assert
	assert_eq(host.page_index(), 1, "点页签应切到第 2 页")
	assert_true(status_page().visible, "角色状态页应显示")
	assert_false(inventory_page().visible, "背包页应隐藏")
	# Act
	host.press_tab()
	# Assert
	assert_eq(host.page_index(), 0, "再点一次应绕回第 1 页")


func test_tab_key_switches_pages() -> void:
	## Tab（[code]ui_focus_next[/code]）换页——键盘路径与点页签同一出口。
	# Act
	open_page(0)
	host.call(&"_input", key_event(KEY_TAB))
	# Assert
	assert_eq(host.page_index(), 1, "Tab 应切到角色状态页")
	assert_true(get_viewport().is_input_handled(), "宿主应把 Tab 标记为已处理")


func test_back_button_closes_the_whole_overlay() -> void:
	## 任一页的「返回」关的都是整个界面（两页共用一次开合）。
	# Act
	open_page(1)
	status_page().call(&"press_back")
	# Assert
	assert_false(host.is_open(), "点返回后应关闭界面")


# ═══════════════════════════════════════════════════════════════════════════════
# 背包：分类过滤与排序（点名验收 ①）
# ═══════════════════════════════════════════════════════════════════════════════

func test_inventory_lists_real_ling_cai_counts() -> void:
	## 灵材行显示的是真实存档里的数量——下品 3 / 上品 1，中品与极品为 0。
	# Arrange
	give_ling_cai(3, 0, 1, 0)
	# Act
	open_page(0)
	var rows: Array = rows_of(inventory_page())
	# Assert
	assert_eq(rows.size(), 2, "只有两个非零档位应出行（数量为 0 不显示）")
	var joined: String = " | ".join(rows)
	assert_true(joined.contains("下品灵材 · ×3"),
			"下品灵材应显示 3 个: %s" % joined)
	assert_true(joined.contains("上品灵材 · ×1"),
			"上品灵材应显示 1 个: %s" % joined)


func test_inventory_ling_cai_rows_sorted_by_quality_descending() -> void:
	## 四档都有时按品质由高到低排列（极品在最前）——分类过滤与排序的排序半边。
	# Arrange
	give_ling_cai(1, 1, 1, 1)
	# Act
	open_page(0)
	var rows: Array = rows_of(inventory_page())
	# Assert
	assert_eq(rows.size(), 4, "四档都有应出行 4 行")
	assert_true(str(rows[0]).contains("极品灵材"), "首行应为极品: %s" % str(rows[0]))
	assert_true(str(rows[3]).contains("下品灵材"), "末行应为下品: %s" % str(rows[3]))


func test_inventory_empty_state_per_category() -> void:
	## 数据为空时给中文空态文案——三个分类各一条，且互不相同。
	# Act + Assert
	open_page(0)
	assert_eq(str(inventory_page().call(&"message_text")),
			Catalog.empty_text(0), "背包空时应显示灵材分类的空态文案")
	# Act
	host.show_page(0)
	inventory_page().call(&"_move_category", 1)
	# Assert
	assert_eq(str(inventory_page().call(&"message_text")),
			Catalog.empty_text(1), "丹药为空时应显示丹药的空态文案")
	assert_ne(Catalog.empty_text(0), Catalog.empty_text(1),
			"两条空态文案应不同（指向不同的下一步）")


func test_category_switch_by_arrow_keys() -> void:
	## 方向键左右切换分类（背包页的键盘主导航）。
	# Arrange
	give_ling_cai(2, 0, 0, 0)
	open_page(0)
	assert_eq(int(inventory_page().call(&"category_index")), 0,
			"前置：应从灵材分类开始")
	# Act
	inventory_page().call(&"_input", key_event(KEY_RIGHT))
	# Assert
	assert_eq(int(inventory_page().call(&"category_index")), 1,
			"→ 应切到丹药分类")
	assert_eq(int(inventory_page().call(&"entry_count")), 0,
			"丹药分类不应含灵材行")
	assert_true(str(inventory_page().call(&"category_bar_text")).contains("[丹药]"),
			"分类栏应把当前分类标为选中")
	# Act
	inventory_page().call(&"_input", key_event(KEY_LEFT))
	# Assert
	assert_eq(int(inventory_page().call(&"category_index")), 0, "← 应切回灵材分类")
	assert_eq(int(inventory_page().call(&"entry_count")), 1, "切回后灵材行应回来")


func test_pill_category_filters_out_artifacts_and_ling_cai() -> void:
	## 丹药分类只出丹药——法宝与灵材都不该混进来（分类过滤的实证）。
	# Arrange
	give_ling_cai(5, 0, 0, 0)
	give_card(PILL_ID)
	give_card(ARTIFACT_ID)
	# Act
	open_page(0)
	inventory_page().call(&"press_category")  # 切到丹药
	var rows: Array = rows_of(inventory_page())
	# Assert
	assert_eq(rows.size(), 1, "丹药分类应恰有 1 行")
	var joined: String = " | ".join(rows)
	assert_true(joined.contains("玉灵丹"), "应显示真实模板名: %s" % joined)
	assert_true(joined.contains("紫"), "应显示模板稀有度中文名: %s" % joined)
	assert_false(joined.contains("灵材"), "灵材不应出现在丹药分类: %s" % joined)
	assert_false(joined.contains("法器"), "法宝不应出现在丹药分类: %s" % joined)


func test_artifact_category_lists_only_artifacts_sorted() -> void:
	## 法宝分类只出法宝，且按稀有度降序（同一个排序口径跨分类复用）。
	# Arrange
	give_card(ARTIFACT_ID)          # 中品法器 · 紫(3)
	give_card(ARTIFACT_ID_2)        # 上品法器 · 金(4)
	give_card(PILL_ID)              # 玉灵丹——不该出现
	# Act
	open_page(0)
	inventory_page().call(&"press_category")
	inventory_page().call(&"press_category")  # 切到法宝
	var rows: Array = rows_of(inventory_page())
	# Assert
	assert_eq(rows.size(), 2, "法宝分类应恰有 2 行")
	assert_true(str(rows[0]).contains("上品法器"), "首行应为稀有度更高的法宝")
	assert_true(str(rows[1]).contains("中品法器"), "次行应为中品法器")


func test_same_pill_twice_merges_into_one_row_with_count() -> void:
	## 同名多张合并成一行「×2」——不铺成两行重复项。
	# Arrange
	give_card(PILL_ID)
	give_card(PILL_ID)
	# Act
	open_page(0)
	inventory_page().call(&"press_category")
	var rows: Array = rows_of(inventory_page())
	# Assert
	assert_eq(rows.size(), 1, "同一模板的两张应合并为一行")
	assert_true(str(rows[0]).contains("×2"), "合并行应显示数量 2: %s" % str(rows[0]))


# ═══════════════════════════════════════════════════════════════════════════════
# 返回不掉状态
# ═══════════════════════════════════════════════════════════════════════════════

func test_closing_and_reopening_preserves_data_and_state() -> void:
	## 开 → 看 → 返回 → 再开：数据仍在（界面零缓存，每次现读），且存档一字未动
	## （这两个界面是只读的——「不掉状态」的另一半是「不改状态」）。
	# Arrange
	give_ling_cai(4, 0, 0, 0)
	give_card(PILL_ID)
	var player_before: Dictionary = (GameStateManager.player as Dictionary).duplicate(true)
	var collection_before: Dictionary = \
			(GameStateManager.collection as Dictionary).duplicate(true)
	# Act
	open_page(0)
	var first_rows: Array = rows_of(inventory_page())
	inventory_page().call(&"press_back")
	var was_closed: bool = not host.is_open()
	host.open()
	var second_rows: Array = rows_of(inventory_page())
	# Assert
	assert_true(was_closed, "返回后应已关闭")
	assert_eq(second_rows, first_rows, "再打开应看到同一批数据（不掉状态）")
	assert_eq(GameStateManager.player, player_before, "只读界面不得改动 player 域")
	assert_eq(GameStateManager.collection, collection_before,
			"只读界面不得改动 collection 域")


func test_inventory_reflects_card_granted_while_closed() -> void:
	## 关闭期间新到的丹药在下次打开时出现——零缓存（界面不揣一份过期快照）。
	# Arrange
	open_page(0)
	inventory_page().call(&"press_category")  # 切到丹药（此时为空）
	assert_eq(int(inventory_page().call(&"entry_count")), 0, "前置：丹药分类为空")
	inventory_page().call(&"press_back")
	# Act
	var gained: int = give_card(PILL_ID)
	host.open()
	# Assert
	assert_ne(gained, -1, "前置：丹药应已入收藏")
	assert_eq(int(inventory_page().call(&"entry_count")), 1,
			"重新打开后应看到新到的丹药")
