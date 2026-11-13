class_name ShopPanelScreen
extends Control
## ShopPanelScreen —— 坊市 overlay 面板（纯代码构建 UI）。[br]
## [br][b]职责[/b]：把 [code]ExplorationShop[/code] 给出的货架渲染成一列可点商品，
## 并把点击意图发出去（[signal purchase_requested] / [signal leave_requested]）；
## 购买结果文案由 [method show_message] 回填。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本面板不持有货架、不算价格、不读写灵石
## ——[method present] 收到的每条目已含 [code]name / rarity / price / sold /
## affordable[/code] 与是否可买，面板只决定怎么显示。[br]
## [br][b]不直调系统[/b]（control-manifest）：购买需改 GSM/资源，面板只发意图，
## 由 [ShopNodePresenter] 调 [code]ExplorationShop.purchase[/code]。[br]
## [br][b]为什么不用 .tscn[/b]：与 [code]event_panel_screen.gd[/code] 同源理由——
## 一次性覆盖层，条目随库存变化，代码构建比维护场景文件更短。[br]
## [br][b]文案本地化豁免[/b]：与 node_move_interactor / node_interaction_rules 同源
## 口径（项目暂无本地化系统）。
##
## 来源: design/ux/deck-editing-ui.md §布局/§状态/§错误-灵石不足、
## design/gdd/exploration-ui-system.md §4c（商店确认 → overlay，B9 裁决）、
## ADR-0031 §2、先例 [code]event_panel_screen.gd[/code]。

## 玩家点了某件商品（[param p_index] 为货架下标）。
signal purchase_requested(p_index: int)
## 玩家点「离开」。
signal leave_requested

const PANEL_WIDTH: int = 760
const PANEL_HEIGHT: int = 520
## 商品行高度（含名称/稀有度/价格一行 + 间距）。
const ITEM_HEIGHT: int = 48
const FONT_SIZE_TITLE: int = 26
const FONT_SIZE_BODY: int = 16

## 稀有度中文名（CardTemplate.Rarity 1-5——与 combat_reward_roller.RARITY_NAMES 同口径）。
const RARITY_NAMES: Dictionary = {1: "白", 2: "蓝", 3: "紫", 4: "金", 5: "暗金"}

## 状态标记文案（双编码：文字 + 禁用态，不只靠颜色）。
const TEXT_SOLD: String = "已售罄"
const TEXT_UNAFFORDABLE: String = "灵石不足"

var _title_label: Label = null
var _balance_label: Label = null
var _item_box: VBoxContainer = null
var _message_label: Label = null
## 离开按钮（存引用而非按控件路径查找——容器层级是构建细节，路径会随布局改动碎掉）。
var _leave_button: Button = null
## 当前展示的条目数（测试/断言用——与控件数一致）。
var _item_count: int = 0


func _init() -> void:
	name = "ShopPanel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_layout()


# ═══════════════════════════════════════════════════════════════════════════════
# 对外
# ═══════════════════════════════════════════════════════════════════════════════

## 上架货架。[br]
## [br][param p_balance] 当前灵石余额（由系统读取后传入——面板不自己查）。[br]
## [param p_items] 条目数组（[code]{index, name, rarity, price, sold, affordable}[/code]）。[br]
## [br][b]空货架[/b]：显示「货架空空」提示而非空白面板（可读的失败形态）。
func present(p_balance: int, p_items: Array) -> void:
	_balance_label.text = "灵石：%d" % p_balance
	_clear_items()
	_item_count = 0
	if p_items.is_empty():
		_show_message("货架空空——这里暂时没有可买的东西。")
		return
	_show_message("点击商品即可购买。")
	for raw: Variant in p_items:
		if raw is Dictionary:
			_add_item_row(raw as Dictionary)
			_item_count += 1


## 回填一条结果文案（购买成功/被拒——文案由系统给出，面板不自行措辞判断）。
func show_message(p_message: String) -> void:
	_show_message(p_message)


# === 查询（测试断言用——不触及内部控件路径）==================================

## 当前商品行数。
func item_count() -> int:
	return _item_count


## 全部商品行的按钮文本（渲染实证）。
func item_texts() -> Array:
	var out: Array = []
	for child: Node in _item_box.get_children():
		if child is Button:
			out.append((child as Button).text)
	return out


## 某行是否可点（售罄 / 灵石不足为 false）。
func is_item_enabled(p_index: int) -> bool:
	var button: Button = _item_box.get_child(p_index) as Button
	return button != null and not button.disabled


## 当前结果文案。
func message_text() -> String:
	return _message_label.text if _message_label.visible else ""


## 灵石标签文本。
func balance_text() -> String:
	return _balance_label.text


## 测试用：按下第 [param p_index] 件商品（不依赖真实输入事件）。[br]
## [b]禁用行不发意图[/b]——与真实按钮行为一致。
func press_item(p_index: int) -> void:
	var button: Button = _item_box.get_child(p_index) as Button
	if button == null or button.disabled:
		return
	button.emit_signal(&"pressed")


## 测试用：按下「离开」。
func press_leave() -> void:
	if _leave_button != null:
		_leave_button.emit_signal(&"pressed")


# ═══════════════════════════════════════════════════════════════════════════════
# 构建
# ═══════════════════════════════════════════════════════════════════════════════

func _build_layout() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -PANEL_WIDTH / 2
	panel.offset_top = -PANEL_HEIGHT / 2
	panel.offset_right = PANEL_WIDTH / 2
	panel.offset_bottom = PANEL_HEIGHT / 2
	add_child(panel)

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

	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = "🏪 坊市"
	_title_label.add_theme_font_size_override("font_size", FONT_SIZE_TITLE)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	_balance_label = Label.new()
	_balance_label.name = "BalanceLabel"
	_balance_label.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
	_balance_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_balance_label)

	var scroll := ScrollContainer.new()
	scroll.name = "ItemScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	_item_box = VBoxContainer.new()
	_item_box.name = "ItemBox"
	_item_box.add_theme_constant_override("separation", 8)
	_item_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_item_box)

	_message_label = Label.new()
	_message_label.name = "MessageLabel"
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
	_message_label.visible = false
	column.add_child(_message_label)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(footer)

	var leave := Button.new()
	leave.name = "LeaveButton"
	leave.text = "离开"
	leave.pressed.connect(func() -> void: leave_requested.emit())
	footer.add_child(leave)
	_leave_button = leave


## 追加一行商品（禁用态 = 售罄或灵石不足，双击不会重复购买）。[br]
## [br][b]行文案[/b]：名称 · 稀有度 · 价格灵石 [+ 状态标记]——名称与状态都在
## [b]按钮文本[/b]里（屏幕阅读器可读，不只靠颜色/图标）。
func _add_item_row(p_item: Dictionary) -> void:
	var price: int = int(p_item.get("price", 0))
	var sold: bool = bool(p_item.get("sold", false))
	var affordable: bool = bool(p_item.get("affordable", true))
	var parts: Array = [
		str(p_item.get("name", "")),
		_rarity_name(int(p_item.get("rarity", 0))),
		"%d 灵石" % price,
	]
	if sold:
		parts.append(TEXT_SOLD)
	elif not affordable:
		parts.append(TEXT_UNAFFORDABLE)

	var index: int = int(p_item.get("index", _item_count))
	var button := Button.new()
	button.name = "Item%d" % index
	button.text = " · ".join(parts)
	button.custom_minimum_size = Vector2(0.0, ITEM_HEIGHT)
	button.disabled = sold or not affordable
	button.pressed.connect(func() -> void: purchase_requested.emit(index))
	_item_box.add_child(button)


func _clear_items() -> void:
	for child: Node in _item_box.get_children():
		_item_box.remove_child(child)
		child.queue_free()


func _show_message(p_text: String) -> void:
	_message_label.text = p_text
	_message_label.visible = not p_text.strip_edges().is_empty()


## 稀有度 int → 中文名（未知/缺失返回空串，不臆造档位）。
static func _rarity_name(p_rarity: int) -> String:
	return str(RARITY_NAMES.get(p_rarity, ""))
