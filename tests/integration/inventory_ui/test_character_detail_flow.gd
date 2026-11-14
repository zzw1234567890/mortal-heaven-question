extends "res://tests/integration/inventory_ui/inventory_screens_fixture.gd"
## 角色状态页的[b]详情展开[/b]测试（真实 Autoload + 真实存档 + 真实界面控件）。[br]
## [br][b]覆盖本轮点名验收[/b]：[br]
##   ③ 角色行可选中、按确认看该角色的卡牌详情摘要（名称 / 类型 / 攻击 / 灵能等
##      模板字段），不可用的角色也能看且标注不可出战；[br]
##   ④ 详情字段与模板一致、空名册时按键不崩。[br]
## [br][b]为什么与 [code]test_character_status_flow.gd[/code] 分开[/b]：那一份管
## 「三节数值读得对不对」（境界/属性/名册），这一份管「选中角色之后看到什么」——
## 拆开两份各自离 300 行软上限更远（同本轮背包侧拆出
## [code]test_inventory_item_use_flow.gd[/code] 的理由）。[br]
## [br][b]装置见 [inventory_screens_fixture.gd][/b]（快照还原 + 真实写入入口 + 模板就位）。
##
## 来源: 本轮任务书第 3-4 条、先例
## [code]tests/integration/exploration_ui/test_shop_panel_navigation.gd[/code]。

## 角色小节下标（[code]CharacterStatusScreen.SECTIONS[/code] 的顺序：境界 0 / 属性 1 / 角色 2）。
const SECTION_CHARACTERS: int = 2


## 切到角色小节并返回该页。
func _open_roster() -> Control:
	open_page(1)
	status_page().call(&"_move_section", SECTION_CHARACTERS)
	return status_page()


## 详情区文本的合并串（用例断言「某个字段值出现了」用）。
func _detail_joined() -> String:
	return " | ".join(status_page().call(&"detail_texts"))


# ═══════════════════════════════════════════════════════════════════════════════
# 选中角色行（点名验收 ③）
# ═══════════════════════════════════════════════════════════════════════════════

func test_character_rows_are_focusable_with_cursor_on_first() -> void:
	## 角色小节的行可聚焦，刷新后游标落在首行且真的有键盘焦点。
	# Arrange
	give_character(0, CHAR_INSTANCE_A, 6, 10)
	# Act
	var page: Control = _open_roster()
	# Assert
	assert_eq(int(page.call(&"row_count")), 1, "前置：应有一名角色")
	assert_eq(int(page.call(&"focused_index")), 0, "角色行应可选中，游标落在首行")
	assert_true(bool(page.call(&"is_row_focused", 0)), "首行应真的持有键盘焦点")


func test_readonly_sections_have_no_selectable_rows() -> void:
	## 境界与属性两节的行是纯信息——游标恒为 -1（不做「点了没反应」的按钮）。
	# Act
	open_page(1)
	# Assert——境界节
	assert_eq(int(status_page().call(&"focused_index")), -1,
			"境界节不应有可选行")
	# Act——属性节
	status_page().call(&"_move_section", 1)
	# Assert
	assert_eq(str(status_page().call(&"section_name")), "属性", "前置：应切到属性节")
	assert_eq(int(status_page().call(&"focused_index")), -1,
			"属性节不应有可选行")


func test_confirming_character_row_shows_detail_summary() -> void:
	## 确认角色行后展开详情摘要，字段与卡牌模板逐字一致——本轮的「详情字段与模板
	## 一致」验收（界面不加工任何模板字段）。
	# Arrange
	give_character(0, CHAR_INSTANCE_A, 6, 10)
	var template: Variant = CardSystem.get_template(CHARACTER_ID)
	assert_not_null(template, "前置：角色模板应已就位")
	# Act
	var page: Control = _open_roster()
	assert_eq(status_page().call(&"detail_texts"), [], "前置：未确认时详情区应为空")
	page.call(&"press_row", 0)
	var joined: String = _detail_joined()
	# Assert——名称 / 类型 / 攻击 / 灵能（成本）四项逐字对照模板
	assert_true(joined.contains("名称 · %s" % str(template.get("name"))),
			"详情应含模板名: %s" % joined)
	assert_true(joined.contains("类型 · 角色"), "详情应含卡牌类型中文名: %s" % joined)
	assert_true(joined.contains("攻击 · %d" % int(template.get("base_attack"))),
			"详情应含模板攻击力: %s" % joined)
	assert_true(joined.contains("灵能消耗 · %d" % int(template.get("cost"))),
			"详情应含模板灵能消耗: %s" % joined)
	assert_true(joined.contains("基础生命 · %d" % int(template.get("base_hp"))),
			"详情应含模板基础生命: %s" % joined)


func test_detail_shows_ledger_hp_not_template_hp() -> void:
	## 详情里的当前生命取 HP 账本（残血显示残血），与列表行同一口径。
	# Arrange
	give_character(0, CHAR_INSTANCE_A, 4, 10)
	# Act
	var page: Control = _open_roster()
	page.call(&"press_row", 0)
	# Assert
	assert_true(_detail_joined().contains("当前生命 · 4 / 10"),
			"详情应显示账本里的残血: %s" % _detail_joined())


func test_dead_character_can_still_be_inspected_and_is_marked() -> void:
	## [b]不可出战的角色也能看[/b]，且详情里照样标注不可出战——「不能上场」不等于
	## 「查不到」；玩家点开才知道他是怎么个不可出战法。
	# Arrange
	var dead_id: int = give_character(0, CHAR_INSTANCE_A, 0, 10)
	mark_dead(dead_id)
	# Act
	var page: Control = _open_roster()
	assert_eq(int(page.call(&"focused_index")), 0, "前置：阵亡角色行仍应可选中")
	page.call(&"press_row", 0)
	# Assert
	var joined: String = _detail_joined()
	assert_false(joined.is_empty(), "阵亡角色应仍能展开详情")
	assert_true(joined.contains("出战状态 · 已阵亡"),
			"详情应标注不可出战: %s" % joined)
	assert_true(joined.contains("当前生命 · 0 / 10"),
			"详情应显示阵亡后的 0 血: %s" % joined)


func test_confirming_another_row_switches_detail() -> void:
	## 确认另一行后详情随之换人——详情不缓存上一次的角色。
	# Arrange
	give_character(0, CHAR_INSTANCE_A, 5, 10)
	give_character(1, CHAR_INSTANCE_B, 7, 10)
	var page: Control = _open_roster()
	# Act——第 2 行
	page.call(&"press_row", 1)
	# Assert
	assert_true(_detail_joined().contains("当前生命 · 7 / 10"),
			"应显示第 2 名角色的生命: %s" % _detail_joined())
	assert_false(_detail_joined().contains("当前生命 · 5 / 10"),
			"不应同时留着上一名角色的详情")
	# Act——切回第 1 行
	page.call(&"press_row", 0)
	# Assert
	assert_true(_detail_joined().contains("当前生命 · 5 / 10"),
			"切回后应显示第 1 名角色的生命: %s" % _detail_joined())


func test_switching_section_collapses_detail() -> void:
	## 切小节后详情收起——旧的详情文本会指着一个已经不在当前列表里的角色。
	# Arrange
	give_character(0, CHAR_INSTANCE_A, 5, 10)
	var page: Control = _open_roster()
	page.call(&"press_row", 0)
	assert_false(page.call(&"detail_texts").is_empty(), "前置：详情应已展开")
	# Act——切到境界节
	page.call(&"_move_section", 1)
	# Assert
	assert_eq(page.call(&"detail_texts"), [], "切小节后详情应收起")


# ═══════════════════════════════════════════════════════════════════════════════
# 空名册与边界（点名验收 ④）
# ═══════════════════════════════════════════════════════════════════════════════

func test_empty_roster_arrow_and_confirm_keys_do_not_crash() -> void:
	## 空名册下按上下与确认：不崩、不产生游标、不展开任何详情、空态文案不变。
	# Act
	var page: Control = _open_roster()
	var empty_text: String = str(page.call(&"message_text"))
	# Act
	page.call(&"_input", key_event(KEY_DOWN))
	page.call(&"_input", key_event(KEY_UP))
	page.call(&"_input", key_event(KEY_ENTER))
	# Assert
	assert_eq(int(page.call(&"row_count")), 0, "空名册不应凭空出现角色行")
	assert_eq(int(page.call(&"focused_index")), -1, "无行时游标应为 -1")
	assert_eq(page.call(&"detail_texts"), [], "无行可确认时不应展开详情")
	assert_eq(str(page.call(&"message_text")), empty_text, "空态文案不应被按键改写")


func test_confirming_out_of_range_row_is_a_safe_noop() -> void:
	## 确认不存在的行是安全空操作——「点条目不崩溃」的边界半边。
	# Arrange
	give_character(0, CHAR_INSTANCE_A, 5, 10)
	var page: Control = _open_roster()
	# Act
	page.call(&"press_row", 9)
	page.call(&"press_row", -1)
	# Assert
	assert_eq(page.call(&"detail_texts"), [], "越界确认不应展开任何详情")
	assert_eq(int(page.call(&"row_count")), 1, "越界确认不应影响行数")


func test_confirming_readonly_row_does_not_open_detail() -> void:
	## 只读行（境界/属性）即便被程序化「确认」也不展开详情——载荷为空即无可展开之物。
	# Act
	open_page(1)
	# Act
	status_page().call(&"press_row", 0)
	# Assert
	assert_eq(status_page().call(&"detail_texts"), [],
			"只读行被确认时不应展开详情")
