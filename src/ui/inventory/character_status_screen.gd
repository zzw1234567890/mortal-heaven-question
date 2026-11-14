class_name CharacterStatusScreen
extends Control
## CharacterStatusScreen —— 角色状态界面（纯代码构建 UI）。[br]
## [br][b]职责[/b]：把 [CharacterStatusModel] 按小节取出的行渲染出来——境界与属性两节
## 是[b]只读文本[/b]（点了没有下一步动作），角色节是[b]可选行[/b]（确认后展开该角色的
## 卡牌详情）；小节切换（点小节栏 / 方向键左右）与返回也在这里。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本面板不持有任何数值、不算任何公式——
## [method refresh] 每次向模型现取；[b]详情也一样现取[/b]（[method _show_detail] 只发一次
## 「第 N 行是谁」，字段值全部来自 [code]CharacterStatusModel.character_detail[/code]，
## 面板连「灵能消耗」这四个字怎么写都交给
## [code]CharacterStatusRows.detail_rows[/code]）。[br]
## [br][b]为什么详情不塞进列表[/b]：把某一行展开成多行文本再收回，会改变列表的行数与
## 游标下标（刚看完详情的下一行是哪个就说不清了）。列表与详情各占一块：列表恒为
## 「一个角色一行」，详情空时隐藏、不占版面。[br]
## [br][b]阵亡角色照样可选[/b]（本轮任务点 3）：不可出战 ≠ 不可查看——玩家点开才知道
## 他是怎么个「不可出战」法；详情里的出战状态沿用名册的同一句标记。[br]
## [br][b]事件层级 = _input[/b]：与 [InventoryScreen] 同源理由（见该文件类文档）。[br]
## [br][b]文案本地化豁免[/b]：与 inventory_screen / shop_panel_screen 同源口径。
##
## 来源: GDD realm-system.md §2 境界属性表、GDD combat-system.md §7、
## GDD deployment-system.md §10、GDD card-system.md §卡牌类型、ADR-0010 §境界值所有权、
## ADR-0031 §2/§4、.claude/rules/ui-code.md、先例 [code]inventory_screen.gd[/code]。

## 玩家点了「返回」或按了取消键。
signal back_requested

## 控件树构建（含分类栏 + 详情区——见该文件类文档）。
const LayoutScript := preload("res://src/ui/inventory/inventory_panel_layout.gd")
const ModelScript := preload("res://src/feature/inventory/character_status_model.gd")
## 各小节的行文案组装（本面板不含任何数值口径——见该文件类文档）。
const RowsScript := preload("res://src/ui/inventory/character_status_rows.gd")
## 键盘/手柄输入翻译（左右切小节 + 上下选行 + 确认 + 取消）。
const NavigatorScript := preload("res://src/ui/inventory/paged_panel_navigator.gd")

const TEXT_TITLE: String = "🧑 角色状态"
## 提示文案两版：另两节没有可选行，写着「回车看详情」会承诺一个不存在的操作。
const TEXT_HINT: String = "← → 切换小节，Esc 返回。"
const TEXT_HINT_SELECTABLE: String = "← → 切换小节，↑ ↓ 选行，回车看详情，Esc 返回。"
## 模型缺失时的文案（与「这一节是空的」分开，见 InventoryScreen 同源注记）。
const TEXT_UNAVAILABLE: String = "道友信息暂不可查——读取链路未就绪。"
## 角色行的条目载荷键（与 [code]CharacterStatusRows.character_rows[/code] 的产出对应）。
const KEY_CHARACTER_ID: String = "character_id"

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
var _detail_box: VBoxContainer = null
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
	_navigator.call(&"bind", _rows, _activate_row, _request_back, _move_section)
	_navigator.connect(&"focus_changed", _on_focus_changed)


# ═══════════════════════════════════════════════════════════════════════════════
# 对外
# ═══════════════════════════════════════════════════════════════════════════════

## 注入只读模型（生产路径：装配处把已接好 Autoload 的模型交进来）。
func set_model(p_model: RefCounted) -> void:
	_model = p_model


## 刷新显示——每次都向模型现读（零缓存：刚打完一场的残血不该迟到一帧）。[br]
## [br][b]空态按小节各一条[/b]（见 [constant SECTIONS] 注记）；[b]模型缺失[/b]时
## 显示 [constant TEXT_UNAVAILABLE]。[br]
## [br][b]游标复位 + 收起详情[/b]：切小节或换了一批控件之后，旧的游标下标与旧的详情
## 文本都会指着一个已经不是那个角色的东西——两者一起清掉（与背包面板同口径）。
func refresh() -> void:
	var model: RefCounted = _resolve_model()
	LayoutScript.clear_box(_item_box)
	LayoutScript.clear_box(_detail_box)
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
	_show_message(TEXT_HINT_SELECTABLE if _has_selectable(rows) else TEXT_HINT)
	_row_count = LayoutScript.add_rows(_item_box, rows, "Row", _on_row_pressed)
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


## 全部行的文本（渲染实证——只读行与可选行都读）。
func row_texts() -> Array:
	var out: Array = []
	for child: Node in _item_box.get_children():
		out.append(LayoutScript.row_text(child))
	return out


## 当前详情区的文本行（未展开详情时为空数组）。
func detail_texts() -> Array:
	var out: Array = []
	for child: Node in _detail_box.get_children():
		out.append(LayoutScript.row_text(child))
	return out


## 当前结果/空态文案。
func message_text() -> String:
	return _message_label.text if _message_label.visible else ""


## 键盘/手柄游标当前所在行（-1 = 无可选行——如境界/属性两节）。
func focused_index() -> int:
	return int(_navigator.call(&"focus_index"))


## 某行当前是否持有键盘焦点（焦点可见的实证）。
func is_row_focused(p_index: int) -> bool:
	var row: Node = _row_at(p_index)
	return row is Button and (row as Button).has_focus()


## 测试用：点小节栏（切到下一节）。
func press_section() -> void:
	_section_button.emit_signal(&"pressed")


## 测试用：按下「返回」。
func press_back() -> void:
	if _leave_button != null:
		_leave_button.emit_signal(&"pressed")


## 测试用：确认第 [param p_index] 行（不依赖真实输入事件）。[br]
## [br][b]越界/只读行是安全的空操作[/b]：没有行可确认时什么也不发生（不崩）。
func press_row(p_index: int) -> void:
	var row: Node = _row_at(p_index)
	if row is Button:
		(row as Button).emit_signal(&"pressed")


# ═══════════════════════════════════════════════════════════════════════════════
# 键盘导航（见类文档「事件层级 = _input」）
# ═══════════════════════════════════════════════════════════════════════════════

## 输入事件——左右切小节 / 上下选行 / 回车确认 / 取消返回，其余原样放行。
func _input(p_event: InputEvent) -> void:
	if not bool(_navigator.call(&"handle_event", p_event, _section_has_focus())):
		return
	get_viewport().set_input_as_handled()


## 切到相邻小节并刷新（下标环绕——只有三节，走到头绕回来；理由同背包面板）。[br]
## [br][b]切换必重置游标与详情[/b]：新小节的行是另一批控件（只有角色节可选），
## 停在旧下标上会指错行。[method refresh] 里已经复位。
func _move_section(p_delta: int) -> void:
	var total: int = SECTIONS.size()
	if total <= 0:
		return
	_section_index = (_section_index + p_delta + total) % total
	refresh()


## 小节栏被点击——切到下一节（接线在本面板，见 [method _build_layout] 注记）。
func _cycle_section() -> void:
	_move_section(1)


## 游标焦点变化——把键盘焦点搬到新行（焦点环由样式的 focus 状态随焦点绘制）。
func _on_focus_changed(p_index: int) -> void:
	var row: Node = _row_at(p_index)
	if row is Button and not (row as Button).disabled:
		(row as Button).grab_focus()


## 游标确认——角色行据此展开详情；只读行（无载荷）什么也不做。[br]
## [br][b]空列表时不会被调到[/b]：游标在无行时恒为 -1，
## [code]ShopPanelNavigator.activate[/code] 已保证这一点；这里再判一次是防御式的。
func _activate_row(p_index: int) -> void:
	_show_detail(LayoutScript.row_payload(_row_at(p_index)))


## 某一行被鼠标点击——与游标确认走同一个出口（[method _activate_row]）。
func _on_row_pressed(p_index: int) -> void:
	_activate_row(p_index)


## 请求返回（「返回」按钮 / Esc / 手柄取消键）。
func _request_back() -> void:
	back_requested.emit()


# ═══════════════════════════════════════════════════════════════════════════════
# 行与详情（文案组装委托给 CharacterStatusRows——本面板不含任何数值口径）
# ═══════════════════════════════════════════════════════════════════════════════

## 按当前小节向模型取行（[code]Array[{text, payload}][/code]——见 RowsScript 类文档）。
func _rows_of(p_model: RefCounted) -> Array:
	return RowsScript.rows_for(str(_section().get("id", "")), p_model)


## 这串行里是否有可确认的（有载荷才算——只读行不承诺操作）。
func _has_selectable(p_rows: Array) -> bool:
	for raw: Variant in p_rows:
		if raw is Dictionary and not (raw as Dictionary).get("payload", {}).is_empty():
			return true
	return false


## 展开某行的详情（[param p_payload] 为空 = 该行不可确认，什么也不做）。[br]
## [br][b]详情文案现取[/b]：面板只把角色 ID 交给 [code]CharacterStatusRows[/code]，
## 字段值一路来自模型——面板既不知道「灵能消耗」怎么措辞，也不留上一次的详情。
func _show_detail(p_payload: Dictionary) -> void:
	if p_payload.is_empty():
		return
	var character_id: int = int(p_payload.get(KEY_CHARACTER_ID, -1))
	var rows: Array = RowsScript.detail_rows(_resolve_model(), character_id)
	LayoutScript.fill_detail(_detail_box, rows)


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 建控件树并接线。[br]
## [br][b]小节栏的接线在这里[/b]（同背包面板：布局只交回按钮，接线由面板做）。
func _build_layout() -> void:
	var parts: Dictionary = LayoutScript.build(self, TEXT_TITLE)
	_leave_button = parts.get("leave_button")
	_item_box = parts.get("item_box")
	_detail_box = parts.get("detail_box")
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


## 第 [param p_index] 行（越界返回 null——调用方据此安全跳过）。
func _row_at(p_index: int) -> Node:
	if p_index < 0 or p_index >= _item_box.get_child_count():
		return null
	return _item_box.get_child(p_index)


## 模型——注入优先，否则本地 new（它自己去找 Autoload；全缺时其读取方法返回空）。
func _resolve_model() -> RefCounted:
	if _model != null:
		return _model
	return ModelScript.new()


## 小节栏是否持有键盘焦点（未挂载时为 false——不臆造）。
func _section_has_focus() -> bool:
	return _section_button != null and is_instance_valid(_section_button) \
			and _section_button.has_focus()


func _show_message(p_text: String) -> void:
	_message_label.text = p_text
	_message_label.visible = not p_text.strip_edges().is_empty()
