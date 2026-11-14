extends RefCounted
## ShopPanelLayout —— 商店 overlay 的控件树构建与配色（从 [ShopPanelScreen] 拆出）。[br]
## [br][b]为什么单独一处[/b]：面板本轮要加键盘/手柄导航，再加构建代码会越过 300 行
## 软上限；而「控件怎么搭、焦点环长什么样」与「货架怎么呈现、意图怎么发」是两件事
## （同 [code]shop_panel_navigator.gd[/code]、[code]node_graph_component_assembly.gd[/code]
## 拆分先例）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本模块只 new 节点与 StyleBox，不持有任何
## 引用（[method build] 把引用交回面板）——它没有可被写坏的玩法状态。[br]
## [br][b]焦点环走 focus stylebox[/b]（而非自绘）：商品行是 [Button]，引擎的
## [code]focus[/code] 主题样式只在获得焦点时绘制，因此「键盘焦点可见」由引擎随
## 焦点自动跟随——面板不必在每次焦点变化时重画（零轮询）。[br]
## [br][b]文字即标记[/b]：行文案把名称与状态（已售罄/灵石不足）都写进按钮文本，
## 不靠颜色单独承载信息（色盲可读）。[br]
##
## 来源: design/ux/deck-editing-ui.md §布局/§状态/§错误-灵石不足、
## design/gdd/exploration-ui-system.md §4c、.claude/rules/ui-code.md（双输入 +
## 色盲模式强制）、ADR-0031 §2、先例 [code]event_panel_screen.gd[/code] 的纯代码构建。

const PANEL_WIDTH: int = 760
const PANEL_HEIGHT: int = 520
## 商品行高度（含名称/稀有度/价格一行 + 间距）。
const ITEM_HEIGHT: int = 48
const FONT_SIZE_TITLE: int = 26
const FONT_SIZE_BODY: int = 16

## 焦点环——松石青粗边（与 node_graph_renderer 的键盘焦点环同色系）。
const FOCUS_BORDER_COLOR: Color = Color(0.35, 0.85, 0.8, 1.0)
const FOCUS_BORDER_WIDTH: int = 3
const FOCUS_CORNER_RADIUS: int = 4
## 焦点行的底色（双通道标记：颜色 + 边框——不只靠颜色承载「选中」语义）。
const FOCUS_BG_COLOR: Color = Color(1.0, 1.0, 1.0, 0.10)

## 状态标记文案（双编码：文字 + 禁用态，不只靠颜色）。
const TEXT_SOLD: String = "已售罄"
const TEXT_UNAFFORDABLE: String = "灵石不足"
## 「离开」按钮文案。
const TEXT_LEAVE: String = "离开"


## 构建面板控件树。[br]
## [br][param p_panel] 面板根节点（[method Control.add_child] 的宿主）。[br]
## [param p_title] 标题文案（由面板给出——本模块不持有面向玩家的词条）。[br]
## [param p_leave_signal] 「离开」按钮转发哪个信号名。[b]必须传面板自己声明过的信号[/b]
## ——[method Object.emit_signal] 对未声明的信号名不报编译错、只在运行时静默失败
## （[code]ERR_UNAVAILABLE[/code]），届时按钮点了没反应。默认值是商店面板的信号名；
## 「返回」语义的面板（背包/角色状态）要显式传自己的 [code]&"back_requested"[/code]。[br]
## [br][b]返回[/b]：[code]{panel, title_label, balance_label, item_box, message_label,
## leave_button}[/code]——面板持有这些引用（不按控件路径查找：容器层级是构建细节，
## 路径会随布局改动碎掉）。[br]
## [br][b][code]panel[/code] 为什么也交出去[/b]：后建的面板若要往「标题与列表之间」
## 插一行（如分类栏），需要一个不靠数 [code]get_parent()[/code] 层级的落点——
## 从 [code]item_box[/code] 上溯到 [PanelContainer] 其实隔了四层，数错了就会拿到
## [VBoxContainer]/[MarginContainer] 并在赋值时报类型错。交出引用比让调用方猜层级稳。
## [br][b]「离开」按钮的意图出口[/b]：直接转发面板的 [param p_leave_signal] 信号
## （本模块不持有任何回调）。
static func build(p_panel: Control, p_title: String,
		p_leave_signal: StringName = &"leave_requested") -> Dictionary:
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

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	column.add_child(header)

	var title_label := Label.new()
	title_label.name = "TitleLabel"
	title_label.text = p_title
	title_label.add_theme_font_size_override("font_size", FONT_SIZE_TITLE)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)

	var balance_label := Label.new()
	balance_label.name = "BalanceLabel"
	balance_label.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
	balance_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(balance_label)

	var scroll := ScrollContainer.new()
	scroll.name = "ItemScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	var item_box := VBoxContainer.new()
	item_box.name = "ItemBox"
	item_box.add_theme_constant_override("separation", 8)
	item_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(item_box)

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
	leave.text = TEXT_LEAVE
	leave.pressed.connect(func() -> void: p_panel.emit_signal(p_leave_signal))
	apply_focus_ring(leave)
	footer.add_child(leave)

	return {
		"panel": panel,
		"title_label": title_label,
		"balance_label": balance_label,
		"item_box": item_box,
		"message_label": message_label,
		"leave_button": leave,
	}


## 追加一行商品（禁用态 = 售罄或灵石不足，双击不会重复购买）。[br]
## [br][b]行文案[/b]：名称 · 稀有度 · 价格灵石 [+ 状态标记]——名称与状态都在
## [b]按钮文本[/b]里（屏幕阅读器可读，不只靠颜色/图标）。[br]
## [br][b]键盘可达[/b]：[code]focus_mode = FOCUS_ALL[/code] + 焦点环样式——未点过
## 鼠标的玩家也能看到「当前选中的是哪一行」（.claude/rules/ui-code.md 双输入）。[br]
## [br][param p_on_pressed] 点击/确认回调 [code]func(index: int) -> void[/code]。
static func add_item_row(p_item_box: VBoxContainer, p_item: Dictionary,
		p_fallback_index: int, p_on_pressed: Callable) -> Button:
	var price: int = int(p_item.get("price", 0))
	var sold: bool = bool(p_item.get("sold", false))
	var affordable: bool = bool(p_item.get("affordable", true))
	var parts: Array = [
		str(p_item.get("name", "")),
		rarity_name(int(p_item.get("rarity", 0))),
		"%d 灵石" % price,
	]
	if sold:
		parts.append(TEXT_SOLD)
	elif not affordable:
		parts.append(TEXT_UNAFFORDABLE)

	var index: int = int(p_item.get("index", p_fallback_index))
	var button := Button.new()
	button.name = "Item%d" % index
	button.text = " · ".join(parts)
	button.custom_minimum_size = Vector2(0.0, ITEM_HEIGHT)
	button.disabled = sold or not affordable
	button.focus_mode = Control.FOCUS_ALL
	apply_focus_ring(button)
	button.pressed.connect(func() -> void: p_on_pressed.call(index))
	p_item_box.add_child(button)
	return button


## 挂上焦点环样式（引擎只在获得焦点时绘制——焦点可见随焦点自动跟随）。[br]
## [br][b]幂等[/b]：重复调用只覆盖同一个键，不叠加样式。
static func apply_focus_ring(p_button: Button) -> void:
	p_button.add_theme_stylebox_override(&"focus", focus_stylebox())


## 焦点环样式（松石青粗边 + 极淡底色——两通道标记「选中」，不只靠颜色）。[br]
## [br]底色是 [constant FOCUS_BG_COLOR] 的半透明白，叠在按钮自身的常态/悬停样式
## 之上（引擎把 [code]focus[/code] 样式画在其余状态之后），既提亮当前行又不遮蔽文案。
static func focus_stylebox() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = FOCUS_BG_COLOR
	box.set_border_width_all(FOCUS_BORDER_WIDTH)
	box.border_color = FOCUS_BORDER_COLOR
	box.set_corner_radius_all(FOCUS_CORNER_RADIUS)
	return box


## 稀有度 int → 中文名（未知/缺失返回空串，不臆造档位）。
static func rarity_name(p_rarity: int) -> String:
	return str(RARITY_NAMES.get(p_rarity, ""))


## 稀有度中文名（CardTemplate.Rarity 1-5——与 combat_reward_roller.RARITY_NAMES 同口径）。
const RARITY_NAMES: Dictionary = {1: "白", 2: "蓝", 3: "紫", 4: "金", 5: "暗金"}
