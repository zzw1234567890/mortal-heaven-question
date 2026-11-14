extends RefCounted
## TeleportPanelLayout —— 传送 overlay 的控件树构建（从 [TeleportPanelScreen] 拆出）。[br]
## [br][b]为什么单独一处[/b]：与 [code]shop_panel_layout.gd[/code] 同源理由——
## 「控件怎么搭、焦点环长什么样」与「可跳层怎么呈现、意图怎么发」是两件事，且
## 面板脚本要守在 300 行软上限内。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本模块只 new 节点，不持有任何引用
## （[method build] 把引用交回面板）——它没有可被写坏的玩法状态。[br]
## [br][b]与商店面板同构[/b]：遮罩 + 居中面板 + 标题 + 滚动列表 + 文案 + 底栏，
## 尺寸/边距/焦点环全部复用 [ShopPanelLayout] 的常量与样式助手——两处不各画一套
## （焦点环颜色或行高改一次即两处生效）。[br]
## [br][b]「离开」按钮的意图出口[/b]：直接转发面板的 [code]leave_requested[/code]
## 信号（本模块不持有任何回调）。[br]
##
## 来源: design/gdd/exploration-system.md §4 移动规则、ADR-0031 §2、
## .claude/rules/ui-code.md（双输入 + 焦点可见）、先例 [code]shop_panel_layout.gd[/code]。

## 控件树样式来源（尺寸与焦点环只在那一处定义）。
const ShopLayoutScript := preload("res://src/ui/exploration/shop_panel_layout.gd")

const FONT_SIZE_BODY: int = ShopLayoutScript.FONT_SIZE_BODY
const ITEM_HEIGHT: int = ShopLayoutScript.ITEM_HEIGHT
const PANEL_WIDTH: int = 560
const PANEL_HEIGHT: int = 420


## 构建面板控件树。[br]
## [br][param p_panel] 面板根节点（[method Control.add_child] 的宿主）。[br]
## [param p_title] 标题文案（由面板给出——本模块不持有面向玩家的词条）。[br]
## [br][b]返回[/b]：[code]{title_label, message_label, layer_box, leave_button}[/code]
## ——面板持有这些引用（不按控件路径查找：容器层级是构建细节，路径会随布局改动
## 碎掉）。[br]
static func build(p_panel: Control, p_title: String) -> Dictionary:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	p_panel.add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -PANEL_WIDTH / 2
	panel.offset_top = -PANEL_HEIGHT / 2
	panel.offset_right = PANEL_WIDTH / 2
	panel.offset_bottom = PANEL_HEIGHT / 2
	p_panel.add_child(panel)

	var margin := MarginContainer.new()
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	for side: String in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var title_label := Label.new()
	title_label.name = "TitleLabel"
	title_label.text = p_title
	title_label.add_theme_font_size_override("font_size", ShopLayoutScript.FONT_SIZE_TITLE)
	column.add_child(title_label)

	var scroll := ScrollContainer.new()
	scroll.name = "LayerScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	var layer_box := VBoxContainer.new()
	layer_box.name = "LayerBox"
	layer_box.add_theme_constant_override("separation", 8)
	layer_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(layer_box)

	var message_label := Label.new()
	message_label.name = "MessageLabel"
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
	message_label.visible = false
	column.add_child(message_label)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(footer)

	var leave := Button.new()
	leave.name = "LeaveButton"
	leave.text = ShopLayoutScript.TEXT_LEAVE
	leave.pressed.connect(func() -> void: p_panel.emit_signal(&"leave_requested"))
	ShopLayoutScript.apply_focus_ring(leave)
	footer.add_child(leave)

	return {
		"title_label": title_label,
		"message_label": message_label,
		"layer_box": layer_box,
		"leave_button": leave,
	}


## 追加一行可跳层。[br]
## [br][param p_layer_box] 层列表容器。[br]
## [param p_text] 行文案（由面板给出——层号 1 基与落点数的措辞归面板）。[br]
## [param p_layer] 该行对应的层索引（0 基——写进控件名，读控件树时可对回层）。[br]
## [param p_on_pressed] 点击/确认回调 [code]func(p_layer: int) -> void[/code]。[br]
## [br][b]键盘可达[/b]：[code]focus_mode = FOCUS_ALL[/code] + 焦点环样式——
## 未点过鼠标的玩家也能看到「当前选中的是哪一行」（.claude/rules/ui-code.md）。
static func add_layer_row(p_layer_box: VBoxContainer, p_text: String, p_layer: int,
		p_on_pressed: Callable) -> Button:
	var button := Button.new()
	button.name = "Layer%d" % p_layer
	button.text = p_text
	button.custom_minimum_size = Vector2(0.0, ITEM_HEIGHT)
	button.focus_mode = Control.FOCUS_ALL
	ShopLayoutScript.apply_focus_ring(button)
	button.pressed.connect(func() -> void: p_on_pressed.call(p_layer))
	p_layer_box.add_child(button)
	return button
