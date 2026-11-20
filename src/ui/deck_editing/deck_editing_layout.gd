extends RefCounted
## DeckEditingLayout —— 卡组编辑界面的[b]控件树构建与配色[/b]（纯代码构建）。[br]
## [br][b]两栏骨架[/b]：左「收藏」右「卡组」两个等宽滚动列表——增删就是「从左挑一张
## 搬到右边」「从右边挑一张搬回左边」，两栏并排才看得出这件事。规格
## （design/ux/deck-editing-ui.md §布局）画的是顶部统计条 + 工具栏 + 中央网格；
## 本轮交付的是[b]最小可用[/b]版本：统计条有（卡组 N/上限），筛选/排序工具栏不做
## （它属于「浏览」而非「编辑」，且卡组浏览面板已有分类读法）。[br]
## [br][b]为什么单独一处[/b]：界面本体要守 300 行软上限
## （.claude/docs/coding-standards.md），而「控件怎么搭、焦点环长什么样」与
## 「游标怎么动、按键意味着什么」是两件事（同 [code]shop_panel_layout.gd[/code] /
## [code]deck_card_rows.gd[/code] 的拆因）。[br]
## [br][b]配色与骨架尺寸不另写一份[/b]：面板宽度、字号、焦点环样式全部取自
## [code]ShopPanelLayout[/code]——商店 / 背包 / 卡组查看 / 角色状态四个面板与这里
## 是同一种视觉语言，各写一份必然漂移。[br]
## [br][b]为什么不用 [method ShopPanelLayout.build][/b]：那个入口搭的是「单列表 +
## 底栏」的骨架（遮罩 + 居中面板 + 一个 ScrollContainer），两栏要塞进去得先把它
## 建出来的单列表拆掉再拼——不如直接搭，但共用同一套常量与焦点环函数。[br]
## [br][b]文字即标记[/b]：栏标题与统计条都是可读文本（不靠颜色区分「哪栏是哪栏」），
## 色盲可读（.claude/rules/ui-code.md）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本模块只 new 节点与 StyleBox，把引用交回
## 界面（[method build] 的返回值）——它没有可被写坏的玩法状态。[br]
## [br][b]文案本地化豁免[/b]：项目暂无本地化系统——界面标题类词条集中在此，与
## [code]ShopPanelLayout.TEXT_*[/code] 同源口径。
##
## 来源: design/ux/deck-editing-ui.md（§Layout Zones 卡组浏览 / §Component Inventory）、
## design/gdd/deck-editing-system.md §5、.claude/rules/ui-code.md（双输入 + 焦点可见 +
## 文字即标记）、ADR-0031 §2、先例 [code]shop_panel_layout.gd[/code]。

## 焦点环 / 字号 / 行高的单一真理来源（见类文档）。
const ShopLayoutScript := preload("res://src/ui/exploration/shop_panel_layout.gd")

## 面板四周留白（px）。
const MARGIN: int = 40
## 栏间距（px）。
const COLUMN_GAP: int = 24
## 两栏等宽（各占一半——[code]SIZE_EXPAND_FILL[/code] 由下方赋值，宽度只作最小保证）。
const COLUMN_MIN_WIDTH: int = 420
## 栏标题字号（px）。
const FONT_SIZE_COLUMN: int = 18

## 界面底色（深墨基底——与占位场景 / 身份选择同源 BG-0 口径）。
const BG_COLOR: Color = Color(0.071, 0.071, 0.086)
## 列表底色（比面板底略亮一档，让「列表有边界」可见而不靠边框）。
const LIST_BG_COLOR: Color = Color(0.12, 0.13, 0.16)

## 栏标题文案。
const TEXT_COLLECTION: String = "收藏"
const TEXT_DECK: String = "卡组"
## 底部主按钮文案（唯一出口——见界面类文档「保存即出口」）。
const TEXT_SAVE_EXIT: String = "保存并返回"


## 构建界面控件树。[br]
## [br][param p_screen] 界面根节点（[method Control.add_child] 的宿主）。[br]
## [param p_title] 标题文案（由界面给出——本模块不持有面向玩家的整句）。[br]
## [br][b]返回[/b]：[code]{panel, title_label, summary_label, left_box, right_box,
## message_label, save_button}[/code]——界面持有这些引用（不按控件路径查找：容器层级
## 是构建细节，路径会随布局改动碎掉——同 [method ShopPanelLayout.build] 的注记）。
static func build(p_screen: Control, p_title: String) -> Dictionary:
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = BG_COLOR
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p_screen.add_child(bg)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MARGIN)
	p_screen.add_child(margin)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 16)
	column.add_child(header)

	var title_label := Label.new()
	title_label.name = "TitleLabel"
	title_label.text = p_title
	title_label.add_theme_font_size_override("font_size", ShopLayoutScript.FONT_SIZE_TITLE)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)

	var summary_label := Label.new()
	summary_label.name = "SummaryLabel"
	summary_label.add_theme_font_size_override("font_size", ShopLayoutScript.FONT_SIZE_BODY)
	summary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(summary_label)

	var columns := HBoxContainer.new()
	columns.name = "Columns"
	columns.add_theme_constant_override("separation", COLUMN_GAP)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(columns)

	var left: Dictionary = _build_list(columns, TEXT_COLLECTION, "CollectionList")
	var right: Dictionary = _build_list(columns, TEXT_DECK, "DeckList")

	var message_label := Label.new()
	message_label.name = "MessageLabel"
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", ShopLayoutScript.FONT_SIZE_BODY)
	message_label.visible = false
	column.add_child(message_label)

	var footer := HBoxContainer.new()
	footer.name = "Footer"
	footer.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(footer)

	var save_button := Button.new()
	save_button.name = "SaveExitButton"
	save_button.text = TEXT_SAVE_EXIT
	save_button.custom_minimum_size = Vector2(0.0, ShopLayoutScript.ITEM_HEIGHT)
	ShopLayoutScript.apply_focus_ring(save_button)
	footer.add_child(save_button)

	return {
		"panel": margin,
		"title_label": title_label,
		"summary_label": summary_label,
		"left_box": left["item_box"],
		"left_title": left["title_label"],
		"left_empty": left["empty_label"],
		"right_box": right["item_box"],
		"right_title": right["title_label"],
		"right_empty": right["empty_label"],
		"message_label": message_label,
		"save_button": save_button,
	}


## 一栏（标题 + 空态提示 + 滚动列表）。[br]
## [br][b]空态提示常驻但默认隐藏[/b]：它由界面按行数开关——建在这里是为了让「哪一栏
## 空着」与「空的时候说什么」在同一个地方定义（内容由界面给，见
## [method DeckEditingScreen._show_empty]）。
static func _build_list(p_columns: HBoxContainer, p_title: String,
		p_node_name: String) -> Dictionary:
	var wrap := VBoxContainer.new()
	wrap.name = p_node_name
	wrap.add_theme_constant_override("separation", 8)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.custom_minimum_size = Vector2(COLUMN_MIN_WIDTH, 0.0)
	p_columns.add_child(wrap)

	var title_label := Label.new()
	title_label.name = "TitleLabel"
	title_label.text = p_title
	title_label.add_theme_font_size_override("font_size", FONT_SIZE_COLUMN)
	wrap.add_child(title_label)

	var empty_label := Label.new()
	empty_label.name = "EmptyLabel"
	empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_label.add_theme_font_size_override("font_size", ShopLayoutScript.FONT_SIZE_BODY)
	empty_label.visible = false
	wrap.add_child(empty_label)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	wrap.add_child(scroll)

	var box_bg := PanelContainer.new()
	box_bg.name = "ListBg"
	box_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = LIST_BG_COLOR
	style.set_corner_radius_all(4)
	box_bg.add_theme_stylebox_override(&"panel", style)
	scroll.add_child(box_bg)

	var item_box := VBoxContainer.new()
	item_box.name = "ItemBox"
	item_box.add_theme_constant_override("separation", 8)
	item_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box_bg.add_child(item_box)

	return {"title_label": title_label, "empty_label": empty_label, "item_box": item_box}
