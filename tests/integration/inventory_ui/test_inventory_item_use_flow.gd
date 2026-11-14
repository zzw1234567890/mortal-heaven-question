extends "res://tests/integration/inventory_ui/inventory_screens_fixture.gd"
## 背包页的[b]可操作性[/b]测试（真实 Autoload + 真实存档 + 真实界面控件）。[br]
## [br][b]覆盖本轮点名验收[/b]：[br]
##   ① 条目可聚焦——上下键选行、行内高亮、切分类时游标回到首行、点条目不崩；[br]
##   ② 丹药可在背包里直接使用——用掉后数量减一，非丹药条目给中文提示；[br]
##   ④ 空列表时按键不崩。[br]
## [br][b]为什么与 [code]test_inventory_screens_flow.gd[/code] 分开[/b]：那一份管
## 「看得对不对」（分类过滤/排序/空态/零缓存），这一份管「按下去会怎样」（游标、
## 结算、提示）——两份各自离 300 行软上限更远，读的人也少一层心智切换（同
## [code]test_shop_panel_navigation.gd[/code] 从商店流程里拆出的先例）。[br]
## [br][b]装置见 [inventory_screens_fixture.gd][/b]（快照还原 + 真实写入入口 + 模板就位）。
##
## 来源: 本轮任务书第 1-2 / 4 条、先例
## [code]tests/integration/exploration_ui/test_shop_panel_navigation.gd[/code]。

## 丹药分类下标（[code]InventoryCatalog.CATEGORIES[/code] 的顺序：灵材 0 / 丹药 1 / 法宝 2）。
const CATEGORY_PILL: int = 1
const CATEGORY_ARTIFACT: int = 2


# ═══════════════════════════════════════════════════════════════════════════════
# 行李查询（本文件的用例都靠它省掉重复的取数样板）
# ═══════════════════════════════════════════════════════════════════════════════

## 当前行的文本（越界返回空串——用例据此断言而不必先判下标）。
func _row_text(p_index: int) -> String:
	var rows: Array = rows_of(inventory_page())
	if p_index < 0 or p_index >= rows.size():
		return ""
	return str(rows[p_index])


## 收藏里某模板的实例数（「用掉一枚」的存档侧实证——界面少一行只是表象）。
func _owned_count(p_template_id: StringName) -> int:
	var count: int = 0
	for raw: Variant in (GameStateManager.collection as Dictionary)["owned_cards"]:
		if raw is Dictionary and str((raw as Dictionary).get("template_id", "")) \
				== str(p_template_id):
			count += 1
	return count


## 某角色的 HP 账本条目（读到手写体：GSM 是唯一存取口）。
func _hp_entry(p_character_id: int) -> Dictionary:
	var table: Dictionary = (GameStateManager.player as Dictionary)["character_hp"]
	return table.get(p_character_id, table.get(str(p_character_id), {}))


# ═══════════════════════════════════════════════════════════════════════════════
# 条目可聚焦（点名验收 ①）
# ═══════════════════════════════════════════════════════════════════════════════

func test_inventory_rows_are_focusable_with_cursor_on_first() -> void:
	## 刷新后游标落在首行，且[b]真的是键盘焦点[/b]（焦点可见的实证，不只是内部状态）。
	# Arrange
	give_ling_cai(1, 1, 1, 0)
	# Act
	open_page(0)
	# Assert
	assert_eq(int(inventory_page().call(&"entry_count")), 3, "前置：应有三行灵材")
	assert_eq(int(inventory_page().call(&"focused_index")), 0, "刷新后游标应落在首行")
	assert_true(bool(inventory_page().call(&"is_row_focused", 0)),
			"首行应真的持有键盘焦点（焦点环随焦点绘制）")
	assert_false(bool(inventory_page().call(&"is_row_focused", 1)),
			"未选中的行不应持有焦点")


func test_inventory_down_key_moves_cursor_and_focus() -> void:
	## ↓ 把游标与键盘焦点一起搬到下一行（不出现「游标走了焦点没走」）。
	# Arrange
	give_ling_cai(1, 1, 1, 0)
	open_page(0)
	# Act
	inventory_page().call(&"_input", key_event(KEY_DOWN))
	# Assert
	assert_eq(int(inventory_page().call(&"focused_index")), 1, "↓ 应把游标移到第 2 行")
	assert_true(bool(inventory_page().call(&"is_row_focused", 1)),
			"第 2 行应随游标拿到焦点")
	assert_false(bool(inventory_page().call(&"is_row_focused", 0)),
			"焦点应离开第 1 行")
	# Act——↑ 回到首行
	inventory_page().call(&"_input", key_event(KEY_UP))
	# Assert
	assert_eq(int(inventory_page().call(&"focused_index")), 0, "↑ 应把游标移回第 1 行")


func test_inventory_category_switch_resets_cursor_to_first_row() -> void:
	## [b]切分类后游标回到首行[/b]：新分类是另一批控件，停在旧下标上会指错行。
	# Arrange
	give_ling_cai(1, 1, 1, 0)
	give_card(PILL_ID)
	give_card(PILL_ID)
	open_page(0)
	inventory_page().call(&"_input", key_event(KEY_DOWN))
	inventory_page().call(&"_input", key_event(KEY_DOWN))
	assert_eq(int(inventory_page().call(&"focused_index")), 2, "前置：游标应已移到第 3 行")
	# Act——切到丹药分类
	inventory_page().call(&"press_category")
	# Assert
	assert_eq(int(inventory_page().call(&"category_index")), CATEGORY_PILL,
			"应切到丹药分类")
	assert_eq(int(inventory_page().call(&"focused_index")), 0,
			"切分类后游标应回到首行（不是停在上一类的第 3 行）")
	assert_true(bool(inventory_page().call(&"is_row_focused", 0)),
			"复位后首行应持有焦点")


func test_inventory_arrow_keys_do_not_move_cursor_sideways() -> void:
	## 左右键归分类切换、上下键归行游标——两组键各管一件事，不互相串台。
	## [br]（← 从首个分类绕到末个分类是既有的环绕口径，见
	## [code]InventoryScreen._move_category[/code]；这里走 → ← 一来一回，落在
	## 同一个分类上再看行游标是否已复位。）
	# Arrange
	give_ling_cai(1, 1, 0, 0)
	give_card(PILL_ID)
	open_page(0)
	inventory_page().call(&"_input", key_event(KEY_DOWN))
	var before: int = int(inventory_page().call(&"focused_index"))
	# Act——→ 切到丹药，再 ← 切回灵材
	inventory_page().call(&"_input", key_event(KEY_RIGHT))
	inventory_page().call(&"_input", key_event(KEY_LEFT))
	# Assert
	assert_ne(before, -1, "前置：↓ 之后应有一个游标")
	assert_eq(int(inventory_page().call(&"category_index")), 0, "→ ← 应回到原分类")
	assert_eq(int(inventory_page().call(&"entry_count")), 2, "切回后灵材两行应都在")
	assert_eq(int(inventory_page().call(&"focused_index")), 0,
			"两次切分类后游标应回到首行（而不是停在切走前的下标）")


# ═══════════════════════════════════════════════════════════════════════════════
# 丹药直接使用（点名验收 ②）
# ═══════════════════════════════════════════════════════════════════════════════

func test_using_pill_in_inventory_heals_and_decrements_count() -> void:
	## 确认一枚丹药：数量由 ×2 变 ×1、残血角色回到满血、存档里确实少了一张，
	## 且提示文案来自结算层（面板不自行措辞）。
	# Arrange——一名残血角色 + 两枚玉灵丹（回复 8，缺口 7）
	give_character(0, CHAR_INSTANCE_A, 3, 10)
	give_card(PILL_ID)
	give_card(PILL_ID)
	open_page(0)
	inventory_page().call(&"press_category")  # 切到丹药
	assert_eq(int(inventory_page().call(&"entry_count")), 1, "前置：应有一行合并的丹药")
	assert_true(_row_text(0).contains("×2"), "前置：应显示两枚: %s" % _row_text(0))
	# Act——确认那一行
	inventory_page().call(&"press_row", 0)
	# Assert——界面侧
	assert_true(_row_text(0).contains("×1"), "用掉一枚后应显示 ×1: %s" % _row_text(0))
	assert_true(str(inventory_page().call(&"message_text")).contains("玉灵丹已服下"),
			"应回填结算层给的文案: %s" % str(inventory_page().call(&"message_text")))
	# Assert——存档侧（界面少一行只是表象，存档才是事实）
	assert_eq(_owned_count(PILL_ID), 1, "收藏里应只剩一枚")
	assert_eq(int(_hp_entry(CHAR_INSTANCE_A).get("current_hp", -1)), 10,
			"残血角色应被治好（缺口 7 < 回复 8）")


func test_using_last_pill_removes_the_row() -> void:
	## 用掉最后一枚后整行消失（回到该分类的空态），不是留一行 ×0。
	# Arrange
	give_character(0, CHAR_INSTANCE_A, 3, 10)
	give_card(PILL_ID)
	open_page(0)
	inventory_page().call(&"press_category")
	assert_eq(int(inventory_page().call(&"entry_count")), 1, "前置：应有一行丹药")
	# Act
	inventory_page().call(&"press_row", 0)
	# Assert
	assert_eq(int(inventory_page().call(&"entry_count")), 0, "用完最后一件后不应再出行")
	assert_eq(int(inventory_page().call(&"focused_index")), -1,
			"无行时游标应为 -1（不指向不存在的行）")
	assert_eq(_owned_count(PILL_ID), 0, "收藏里应已没有这枚丹药")


func test_using_pill_fails_when_nobody_needs_it() -> void:
	## 全队满血时用丹药：[b]给提示但不消耗[/b]——不白吃玩家的东西。
	# Arrange——角色满血（仍有账本记录，只是没有缺口）
	give_character(0, CHAR_INSTANCE_A, 10, 10)
	give_card(PILL_ID)
	open_page(0)
	inventory_page().call(&"press_category")
	# Act
	inventory_page().call(&"press_row", 0)
	# Assert
	assert_eq(_owned_count(PILL_ID), 1, "无人需要时不应消耗丹药")
	assert_true(_row_text(0).contains("×1"), "数量应保持 ×1: %s" % _row_text(0))
	assert_false(str(inventory_page().call(&"message_text")).contains("已服下"),
			"不应报告成功: %s" % str(inventory_page().call(&"message_text")))
	assert_false(str(inventory_page().call(&"message_text")).strip_edges().is_empty(),
			"应给出中文原因（不是静默失败）")


func test_using_non_pill_entry_shows_chinese_refusal() -> void:
	## 非丹药条目（法宝）确认后给中文提示、不改存档——点下去必须有回音。
	# Arrange
	give_card(ARTIFACT_ID)
	var collection_before: Dictionary = \
			(GameStateManager.collection as Dictionary).duplicate(true)
	open_page(0)
	inventory_page().call(&"press_category")
	inventory_page().call(&"press_category")  # 切到法宝
	assert_eq(int(inventory_page().call(&"category_index")), CATEGORY_ARTIFACT,
			"前置：应停在法宝分类")
	# Act
	inventory_page().call(&"press_row", 0)
	# Assert
	assert_eq(str(inventory_page().call(&"message_text")), Catalog.TEXT_NOT_A_PILL,
			"非丹药条目应给统一的中文提示")
	assert_eq(GameStateManager.collection, collection_before,
			"被拒的条目不得改动 collection 域")


func test_using_ling_cai_entry_shows_chinese_refusal() -> void:
	## 灵材（不是卡片）同样给中文提示——「不能直接用」这条判据覆盖非卡片行。
	# Arrange
	give_ling_cai(2, 0, 0, 0)
	var player_before: Dictionary = (GameStateManager.player as Dictionary).duplicate(true)
	open_page(0)
	# Act——首行即灵材行
	inventory_page().call(&"press_row", 0)
	# Assert
	assert_eq(str(inventory_page().call(&"message_text")), Catalog.TEXT_NOT_A_PILL,
			"灵材行应给同一条「不能直接使用」提示")
	assert_eq(GameStateManager.player, player_before, "被拒的条目不得改动 player 域")


# ═══════════════════════════════════════════════════════════════════════════════
# 空列表与边界（点名验收 ④）
# ═══════════════════════════════════════════════════════════════════════════════

func test_empty_category_arrow_keys_do_not_crash() -> void:
	## 空分类下按上下左右与确认：不崩、不产生游标、空态文案不变。
	# Arrange——仓库全空
	open_page(0)
	inventory_page().call(&"press_category")  # 切到空的丹药分类
	var empty_text: String = str(inventory_page().call(&"message_text"))
	# Act
	inventory_page().call(&"_input", key_event(KEY_DOWN))
	inventory_page().call(&"_input", key_event(KEY_UP))
	inventory_page().call(&"_input", key_event(KEY_ENTER))
	# Assert
	assert_eq(int(inventory_page().call(&"entry_count")), 0, "空分类不应凭空出现行")
	assert_eq(int(inventory_page().call(&"focused_index")), -1, "无行时游标应为 -1")
	assert_eq(str(inventory_page().call(&"message_text")), empty_text,
			"空态文案不应被按键改写")


func test_pressing_out_of_range_row_is_a_safe_noop() -> void:
	## 确认一个不存在的行（越界下标）是安全空操作——「点条目不崩溃」的边界半边。
	# Arrange
	give_ling_cai(1, 0, 0, 0)
	var player_before: Dictionary = (GameStateManager.player as Dictionary).duplicate(true)
	open_page(0)
	# Act
	inventory_page().call(&"press_row", 5)
	inventory_page().call(&"press_row", -1)
	# Assert
	assert_eq(int(inventory_page().call(&"entry_count")), 1, "越界确认不应影响行数")
	assert_eq(GameStateManager.player, player_before, "越界确认不得改动存档")


func test_using_unknown_character_instance_does_not_crash() -> void:
	## 丹药存在的分类里确认「无实例可移除」的脏条目：不崩且给出中文原因（防御性路径）。
	## [br][b]为什么值得测[/b]：真实存档可能被旧版本写坏（收藏条目缺
	## [code]card_instance_id[/code]）——界面在那种档上仍须给一句话而不是崩掉。
	# Arrange——手写一条缺实例 ID 的脏收藏条目
	give_character(0, CHAR_INSTANCE_A, 3, 10)
	prime_templates([PILL_ID])
	var dirty: Dictionary = {"card_instance_id": 0, "template_id": str(PILL_ID),
			"rarity": 3}
	(GameStateManager.collection as Dictionary)["owned_cards"].append(dirty)
	open_page(0)
	inventory_page().call(&"press_category")
	# Act + Assert——脏条目还在列表里（模型没崩），确认它给出中文原因
	assert_eq(int(inventory_page().call(&"entry_count")), 1, "脏条目应仍能被列出")
	inventory_page().call(&"press_row", 0)
	assert_false(str(inventory_page().call(&"message_text")).strip_edges().is_empty(),
			"应给中文原因而不是静默失败")
