class_name CharacterStatusScreen
extends Control
## CharacterStatusScreen —— 角色状态界面（纯代码构建 UI）。[br]
## [br][b]职责[/b]：把 [CharacterStatusModel] 按小节取出的行渲染成一列只读文本，
## 并处理小节切换（点小节栏 / 方向键左右）与返回。[br]
## [br][b]三个小节[/b]：境界与修为 / 属性 / 角色名册——本轮任务点名的四类信息
## （境界、修为与上限、生命与属性、阵亡标记）各有归属，不挤成一坨。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本面板不持有任何数值、不算任何公式
## ——[method refresh] 每次向模型现取；属性行是境界配置表的原样投影，面板连
## 「标签怎么起名」都交给 [code]InventoryCatalog.attribute_label[/code]。[br]
## [br][b]生命为什么在这里而不在背包[/b]：背包管「有什么东西」，角色状态管
## 「人怎么样」——HP 是角色属性（GDD combat-system.md §7 的跨场残血），不是道具。[br]
## [br][b]事件层级 = _input[/b]：与 [InventoryScreen] 同源理由（见该文件类文档）。[br]
## [br][b]文案本地化豁免[/b]：与 inventory_screen / shop_panel_screen 同源口径。
##
## 来源: GDD realm-system.md §2 境界属性表、GDD combat-system.md §7、
## GDD deployment-system.md §10、ADR-0010 §境界值所有权、ADR-0031 §2/§4、
## .claude/rules/ui-code.md、先例 [code]inventory_screen.gd[/code]。

## 玩家点了「返回」或按了取消键。
signal back_requested

const LayoutScript := preload("res://src/ui/inventory/inventory_panel_layout.gd")
const ModelScript := preload("res://src/feature/inventory/character_status_model.gd")
## 各小节的行文案组装（本面板不含任何数值口径——见该文件类文档）。
const RowsScript := preload("res://src/ui/inventory/character_status_rows.gd")
const NavigatorScript := preload("res://src/ui/exploration/shop_panel_navigator.gd")

const TEXT_TITLE: String = "🧑 角色状态"
const TEXT_HINT: String = "← → 切换小节，Esc 返回。"
## 模型缺失时的文案（与「这一节是空的」分开，见 InventoryScreen 同源注记）。
const TEXT_UNAVAILABLE: String = "道友信息暂不可查——读取链路未就绪。"

## 小节定义（顺序即界面上的小节顺序，也是左右键的切换顺序）。[br]
## [br][code]empty_text[/code] 分别写：属性节为空说明境界配置表没给出条目；
## 名册节为空说明角色位还空着——两句提示指向不同的下一步动作。
const SECTIONS: Array = [
	{"id": &"realm", "name": "境界", "empty_text": "境界信息暂不可查。"},
	{"id": &"attributes", "name": "属性",
		"empty_text": "当前境界没有可展示的属性——境界配置表未给出条目。"},
	{"id": &"characters", "name": "角色",
		"empty_text": "角色位上还没有人——先去身份选择安置道友。"},
]

var _section_button: Button = null
var _item_box: VBoxContainer = null
var _message_label: Label = null
var _leave_button: Button = null
var _section_index: int = 0
var _row_count: int = 0
var _navigator: RefCounted = null
var _model: RefCounted = null


func _init() -> void:
	name = "CharacterStatusScreen"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_layout()
	_navigator = NavigatorScript.new()
	_navigator.call(&"bind", _rows, _activate_row, _request_back)
	_navigator.connect(&"focus_changed", _on_focus_changed)


# ═══════════════════════════════════════════════════════════════════════════════
# 对外
# ═══════════════════════════════════════════════════════════════════════════════

## 注入只读模型（生产路径：装配处把已接好 Autoload 的模型交进来）。
func set_model(p_model: RefCounted) -> void:
	_model = p_model


## 刷新显示——每次都向模型现读（零缓存：刚打完一场的残血不该迟到一帧）。[br]
## [br][b]空态按小节各一条[/b]（见 [constant SECTIONS] 注记）；[b]模型缺失[/b]时
## 显示 [constant TEXT_UNAVAILABLE]。
func refresh() -> void:
	var model: RefCounted = _resolve_model()
	_clear_rows()
	_row_count = 0
	if model == null:
		_section_button.text = LayoutScript.TEXT_CATEGORY_PREFIX + TEXT_UNAVAILABLE
		_show_message(TEXT_UNAVAILABLE)
		_navigator.call(&"reset")
		return
	var rows: Array = _rows_of(model)
	LayoutScript.set_category_text(_section_button, _section_bar_text())
	if rows.is_empty():
		_show_message(str(_section().get("empty_text", "")))
		_navigator.call(&"reset")
		return
	_show_message(TEXT_HINT)
	for raw: Variant in rows:
		if raw is String:
			LayoutScript.add_text_row(_item_box, raw, "Row%d" % _row_count)
			_row_count += 1
	_navigator.call(&"reset")


# === 查询（测试断言用——不触及内部控件路径）==================================

## 当前小节下标。
func section_index() -> int:
	return _section_index


## 当前小节中文名。
func section_name() -> String:
	return str(_section().get("name", ""))


## 小节栏文本（含当前节标记与切换提示）。
func section_bar_text() -> String:
	return _section_button.text


## 当前行数。
func row_count() -> int:
	return _row_count


## 全部行的文本（渲染实证）。
func row_texts() -> Array:
	var out: Array = []
	for child: Node in _item_box.get_children():
		if child is Label:
			out.append((child as Label).text)
	return out


## 当前结果/空态文案。
func message_text() -> String:
	return _message_label.text if _message_label.visible else ""


## 键盘/手柄游标当前所在行（本面板行不可选，恒为 -1）。
func focused_index() -> int:
	return int(_navigator.call(&"focus_index"))


## 测试用：点小节栏（切到下一节）。
func press_section() -> void:
	_section_button.emit_signal(&"pressed")


## 测试用：按下「返回」。
func press_back() -> void:
	if _leave_button != null:
		_leave_button.emit_signal(&"pressed")


# ═══════════════════════════════════════════════════════════════════════════════
# 键盘导航（见类文档「事件层级 = _input」）
# ═══════════════════════════════════════════════════════════════════════════════

## 输入事件——左右切小节 / 取消返回。[br]
## [br][b]小节栏按钮保有焦点时，左右键交给它自己[/b]（同 InventoryScreen 注记）。
func _input(p_event: InputEvent) -> void:
	if _section_has_focus() \
			and (p_event.is_action_pressed(&"ui_left")
				or p_event.is_action_pressed(&"ui_right")):
		return
	if p_event.is_action_pressed(&"ui_left"):
		_move_section(-1)
		get_viewport().set_input_as_handled()
		return
	if p_event.is_action_pressed(&"ui_right"):
		_move_section(1)
		get_viewport().set_input_as_handled()
		return
	if not bool(_navigator.call(&"handle_event", p_event)):
		return
	get_viewport().set_input_as_handled()


## 切到相邻小节并刷新（下标环绕——只有三节，走到头绕回来；理由同背包面板）。
func _move_section(p_delta: int) -> void:
	var total: int = SECTIONS.size()
	if total <= 0:
		return
	_section_index = (_section_index + p_delta + total) % total
	refresh()


## 小节栏被点击——切到下一节（接线在本面板，见 [method _build_layout] 注记）。
func _cycle_section() -> void:
	_move_section(1)


## 游标焦点变化——本面板没有可选行，故只在可行时搬运焦点（防御式，不臆造）。
func _on_focus_changed(p_index: int) -> void:
	if p_index < 0 or p_index >= _item_box.get_child_count():
		return
	var row: Node = _item_box.get_child(p_index)
	if row is Button and not (row as Button).disabled:
		(row as Button).grab_focus()


## 游标确认——无可选行时不做任何事（[ShopPanelNavigator.activate] 已保证）。
func _activate_row(_p_index: int) -> void:
	pass


## 请求返回（「返回」按钮 / Esc / 手柄取消键）。
func _request_back() -> void:
	back_requested.emit()


# ═══════════════════════════════════════════════════════════════════════════════
# 各小节的行（文案组装委托给 CharacterStatusRows——本面板不含任何数值口径）
# ═══════════════════════════════════════════════════════════════════════════════

## 按当前小节向模型取行（行是字符串——数值来自模型，措辞在 RowsScript 里）。
func _rows_of(p_model: RefCounted) -> Array:
	return RowsScript.rows_for(str(_section().get("id", "")), p_model)


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 建控件树并接线。[br]
## [br][b]小节栏的接线在这里[/b]（同背包面板：布局只交回按钮，接线由面板做）。
func _build_layout() -> void:
	var parts: Dictionary = LayoutScript.build(self, TEXT_TITLE)
	_leave_button = parts.get("leave_button")
	_item_box = parts.get("item_box")
	_message_label = parts.get("message_label")
	_section_button = parts.get("category_button")
	_section_button.pressed.connect(_cycle_section)
	_leave_button.text = LayoutScript.TEXT_BACK


## 当前小节定义（越界返回空字典——调用方走空态分支）。
func _section() -> Dictionary:
	if _section_index < 0 or _section_index >= SECTIONS.size():
		return {}
	return SECTIONS[_section_index]


## 小节栏文本——「[境界]  属性  角色」（当前节用方括号标记，同宿主页签口径）。[br]
## [br]行数不写进小节栏：这里的小节标题本身就是内容摘要（「属性」有几行由境界
## 配置表决定，写成数字反而让人以为那是可变的配额）。
func _section_bar_text() -> String:
	var parts: Array = []
	for index: int in range(SECTIONS.size()):
		var label: String = str((SECTIONS[index] as Dictionary).get("name", ""))
		parts.append("[%s]" % label if index == _section_index else label)
	return "  ".join(parts)


## 行数组（游标的取数口——每次现取不缓存：刷新会换一批控件）。
func _rows() -> Array:
	var out: Array = []
	for child: Node in _item_box.get_children():
		out.append(child)
	return out


## 模型——注入优先，否则本地 new（它自己去找 Autoload；全缺时其读取方法返回空）。
func _resolve_model() -> RefCounted:
	if _model != null:
		return _model
	return ModelScript.new()


## 小节栏是否持有键盘焦点（未挂载时为 false——不臆造）。
func _section_has_focus() -> bool:
	return _section_button != null and is_instance_valid(_section_button) \
			and _section_button.has_focus()


func _clear_rows() -> void:
	for child: Node in _item_box.get_children():
		_item_box.remove_child(child)
		child.queue_free()


func _show_message(p_text: String) -> void:
	_message_label.text = p_text
	_message_label.visible = not p_text.strip_edges().is_empty()
