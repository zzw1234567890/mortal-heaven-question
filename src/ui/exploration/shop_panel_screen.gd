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
## [br][b]键盘/手柄导航[/b]（.claude/rules/ui-code.md「所有交互元素必须同时支持
## 键盘/鼠标和手柄输入」）：上下选行、确认购买、取消关闭由 [ShopPanelNavigator]
## 统一翻译；四个动作走 [code]ui_up[/code] / [code]ui_down[/code] /
## [code]ui_accept[/code] / [code]ui_cancel[/code]——这套默认动作在键鼠与手柄上
## 都有绑定，故一条实现同时覆盖两种设备。[br]
## [br][b]焦点可见[/b]：游标所在行 [method Control.grab_focus]，焦点环由
## [ShopPanelLayout] 挂的 [code]focus[/code] 样式随焦点自动绘制（引擎只在控件获得
## 焦点时绘制该样式，故面板不必手工重画）——「选中的是哪一行」不依赖鼠标悬停。[br]
## [br][b]事件层级 = _input[/b]：实测（Godot 4.6.3 headless）焦点落在 [Button] 上时，
## 引擎的内置焦点导航在 GUI 阶段就把方向键吃了，[code]_unhandled_key_input[/code]
## 根本收不到；[code]_input[/code] 排在 GUI 派发之前，是唯一能拦住的层。消费走
## [method Viewport.set_input_as_handled]（实测 Autoload 挂在树的前段、当前场景在后段，
## 而 [code]_input[/code] 按树序倒序派发，故本面板先于 [code]InputManager[/code]
## 收到事件——商店开着时按 Esc 只关商店，不会顺带弹出暂停菜单）。[br]
## [br][b]为什么不用 .tscn[/b]：与 [code]event_panel_screen.gd[/code] 同源理由——
## 一次性覆盖层，条目随库存变化，代码构建比维护场景文件更短。[br]
## [br][b]文案本地化豁免[/b]：与 node_move_interactor / node_interaction_rules 同源
## 口径（项目暂无本地化系统）。
##
## 来源: design/ux/deck-editing-ui.md §布局/§状态/§错误-灵石不足、
## design/gdd/exploration-ui-system.md §4c（商店确认 → overlay，B9 裁决）、
## ADR-0031 §2/§4、.claude/rules/ui-code.md、先例 [code]event_panel_screen.gd[/code]。

## 玩家点了某件商品（[param p_index] 为货架下标）。
signal purchase_requested(p_index: int)
## 玩家点了「离开」或按了取消键。
signal leave_requested

## 控件树构建与配色（本面板只编排）。
const LayoutScript := preload("res://src/ui/exploration/shop_panel_layout.gd")
## 键盘/手柄游标（纯逻辑，不碰控件树）。
const NavigatorScript := preload("res://src/ui/exploration/shop_panel_navigator.gd")

## 结果文案字号（与布局同源——避免两处各写一个数）。
const FONT_SIZE_BODY: int = LayoutScript.FONT_SIZE_BODY

## 标题与空货架文案。
const TEXT_TITLE: String = "🏪 坊市"
const TEXT_EMPTY: String = "货架空空——这里暂时没有可买的东西。"
const TEXT_HINT: String = "点击商品即可购买（方向键选行，回车确认，Esc 离开）。"

var _title_label: Label = null
var _balance_label: Label = null
var _item_box: VBoxContainer = null
var _message_label: Label = null
## 离开按钮（存引用而非按控件路径查找——容器层级是构建细节，路径会随布局改动碎掉）。
var _leave_button: Button = null
## 当前展示的条目数（测试/断言用——与控件数一致）。
var _item_count: int = 0
## 键盘/手柄游标（见 [ShopPanelNavigator]）。
var _navigator: RefCounted = null


func _init() -> void:
	name = "ShopPanel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_layout()
	_navigator = NavigatorScript.new()
	_navigator.call(&"bind", _rows, _activate_row, _request_leave)
	_navigator.connect(&"focus_changed", _on_focus_changed)


# ═══════════════════════════════════════════════════════════════════════════════
# 对外
# ═══════════════════════════════════════════════════════════════════════════════

## 上架货架。[br]
## [br][param p_balance] 当前灵石余额（由系统读取后传入——面板不自己查）。[br]
## [param p_items] 条目数组（[code]{index, name, rarity, price, sold, affordable}[/code]）。[br]
## [br][b]空货架[/b]：显示「货架空空」提示而非空白面板（可读的失败形态）。[br]
## [br][b]游标复位[/b]：每次上架都把游标落到首个可买行——否则买走一件后重上架时，
## 游标会停在被移除重建的旧控件上（下标错位）。
func present(p_balance: int, p_items: Array) -> void:
	_balance_label.text = "灵石：%d" % p_balance
	_clear_items()
	_item_count = 0
	if p_items.is_empty():
		_show_message(TEXT_EMPTY)
		_navigator.call(&"reset")
		return
	_show_message(TEXT_HINT)
	for raw: Variant in p_items:
		if raw is Dictionary:
			LayoutScript.add_item_row(_item_box, raw, _item_count, _on_item_pressed)
			_item_count += 1
	_navigator.call(&"reset")


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


## 键盘/手柄游标当前所在行（-1 = 无可选行）。
func focused_index() -> int:
	return int(_navigator.call(&"focus_index"))


## 某行当前是否持有键盘焦点（焦点可见的实证——不只读游标的内部状态）。
func is_item_focused(p_index: int) -> bool:
	var button: Button = _item_box.get_child(p_index) as Button
	return button != null and button.has_focus()


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
# 键盘 / 手柄导航（见类文档「事件层级 = _input」）
# ═══════════════════════════════════════════════════════════════════════════════

## 输入事件——上下选行 / 确认购买 / 取消离开，未映射的动作原样放行。[br]
## [br][b]「离开」按钮保有焦点时不吃确认键[/b]：此时 Enter 应触发那个按钮本身
## （玩家用 Tab/鼠标把焦点放过去，意图明确），游标确认让位。[br]
## [br][b]消费即拦断[/b]：向上不再经过引擎焦点导航、向下不给节点图键盘走位，
## 也顺带挡住了 [code]InputManager[/code] 的 Esc → 暂停菜单。
func _input(p_event: InputEvent) -> void:
	if _leave_has_focus() and p_event.is_action_pressed(&"ui_accept"):
		return
	if not bool(_navigator.call(&"handle_event", p_event)):
		return
	get_viewport().set_input_as_handled()


## 游标变化——把键盘焦点搬到新行（焦点环由样式的 focus 状态随焦点绘制）。
func _on_focus_changed(p_index: int) -> void:
	if p_index < 0 or p_index >= _item_box.get_child_count():
		return
	var button: Button = _item_box.get_child(p_index) as Button
	if button != null and not button.disabled:
		button.grab_focus()


## 行被点击——发购买意图（禁用行的按钮不会发 [signal Button.pressed]，故天然被拦）。
func _on_item_pressed(p_index: int) -> void:
	purchase_requested.emit(p_index)


## 游标确认——复用按钮自身的 [signal Button.pressed]（鼠标与键盘一条实现）。
func _activate_row(p_index: int) -> void:
	press_item(p_index)


## 请求离开（「离开」按钮 / 取消键 / 手柄取消键）。
func _request_leave() -> void:
	leave_requested.emit()


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

func _build_layout() -> void:
	var parts: Dictionary = LayoutScript.build(self, TEXT_TITLE)
	_title_label = parts.get("title_label")
	_balance_label = parts.get("balance_label")
	_item_box = parts.get("item_box")
	_message_label = parts.get("message_label")
	_leave_button = parts.get("leave_button")


## 当前行数组（游标的取数口——每次现取不缓存：货架重建会换一批控件）。
func _rows() -> Array:
	var out: Array = []
	for child: Node in _item_box.get_children():
		out.append(child)
	return out


## 「离开」按钮是否持有键盘焦点（未挂载时为 false——不臆造）。
func _leave_has_focus() -> bool:
	return _leave_button != null and is_instance_valid(_leave_button) \
			and _leave_button.has_focus()


func _clear_items() -> void:
	for child: Node in _item_box.get_children():
		_item_box.remove_child(child)
		child.queue_free()


func _show_message(p_text: String) -> void:
	_message_label.text = p_text
	_message_label.visible = not p_text.strip_edges().is_empty()
