class_name HarvestPanelScreen
extends Control
## HarvestPanelScreen —— 采集点（灵草/矿脉）的采集 overlay（纯代码构建 UI）。[br]
## [br][b]职责[/b]：把 [code]ExplorationHarvest.entries_for[/code] 给出的可采列表
## 渲染成一列可点材料，并把采集意图发出去（[signal harvest_requested] /
## [signal leave_requested]）；采集结果文案由 [method show_message] 回填。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本面板不持有材料列表、不判已采、不写
## GSM——[method present] 收到的每条目已含 [code]name / kind_name / quality_name /
## amount / harvested / room[/code]，面板只决定怎么显示；「真的入库」由
## [HarvestNodePresenter] 调系统 API。[br]
## [br][b]不自行计算**：数量与剩余容量都来自条目（UI 零数值计算）。[br]
## [br][b]键盘/手柄导航[/b]（.claude/rules/ui-code.md「所有交互元素必须同时支持
## 键盘/鼠标和手柄输入」）：复用 [ShopPanelNavigator]——它的契约就是「一组
## [Button] + 确认 + 取消」，与货架无关（行数、禁用态、游标语义都一致）。[br]
## [br][b]事件层级 = _input[/b]：与 [ShopPanelScreen] 同源理由——焦点落在 [Button]
## 上时引擎的内置焦点导航会在 GUI 阶段吃掉方向键，[code]_unhandled_key_input[/code]
## 收不到；[code]_input[/code] 排在 GUI 派发之前，是唯一能拦住的层。消费走
## [method Viewport.set_input_as_handled]，顺带挡住 [code]InputManager[/code]
## 的 Esc → 暂停菜单。[br]
## [br][b]控件树在 [HarvestPanelLayout][/b]（复用商店面板的尺寸与焦点环）：
## 面板只编排（同商店/传送面板先例）。[br]
## [br][b]为什么不用 .tscn[/b]：与 [code]shop_panel_screen.gd[/code] 同源理由——
## 一次性覆盖层，条目数随节点载荷变化，代码构建比维护场景文件更短。[br]
## [br][b]文案本地化豁免[/b]：与 node_interaction_rules / shop_panel_screen 同源
## 口径（项目暂无本地化系统）。
##
## 来源: design/gdd/resource-system.md §资源表（灵材）/ §边界（AC-19）、
## design/gdd/exploration-ui-system.md §4c（overlay 先例）、ADR-0031 §2/§4、
## .claude/rules/ui-code.md、先例 [code]shop_panel_screen.gd[/code]。

## 玩家点了某种材料（[param p_slot] 为材料槽位）。
signal harvest_requested(p_slot: int)
## 玩家点了「离开」或按了取消键。
signal leave_requested

## 控件树构建（尺寸/边距/焦点环与商店面板同源——只在一处定义）。
const LayoutScript := preload("res://src/ui/exploration/harvest_panel_layout.gd")
## 材料载荷表（品质中文名词条的来源——本面板不自建一份）。
const TableScript := preload("res://src/feature/exploration/exploration_harvest_table.gd")
## 键盘/手柄游标（纯逻辑，不碰控件树——与商店/传送共用同一实现）。
const NavigatorScript := preload("res://src/ui/exploration/shop_panel_navigator.gd")

## 标题与空载荷文案。
const TEXT_TITLE: String = "🌿 采集"
const TEXT_HINT: String = "点击即可采集（方向键选行，回车确认，Esc 离开）。"
const TEXT_EMPTY: String = "此处灵脉枯竭——无物可采。"

var _title_label: Label = null
## 顶部摘要标签（复用商店布局的余额位——这里显示灵材持有量）。
var _bag_label: Label = null
var _item_box: VBoxContainer = null
var _message_label: Label = null
var _leave_button: Button = null
## 当前展示的条目数（测试/断言用——与控件数一致）。
var _entry_count: int = 0
## 各行对应的材料槽位（行序 → slot——按下标取，不按控件路径）。
var _slots: Array = []
## 键盘/手柄游标。
var _navigator: RefCounted = null


func _init() -> void:
	name = "HarvestPanel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_layout()
	_navigator = NavigatorScript.new()
	_navigator.call(&"bind", _rows, _activate_row, _request_leave)
	_navigator.connect(&"focus_changed", _on_focus_changed)


# ═══════════════════════════════════════════════════════════════════════════════
# 对外
# ═══════════════════════════════════════════════════════════════════════════════

## 上架可采列表。[br]
## [br][param p_bag_counts] 各品质档位当前持有量 [code]{quality: count}[/code]
## （由系统读取后传入——面板不自己查）。[br]
## [param p_entries] 条目数组（[code]ExplorationHarvest.entries_for[/code] 的产出）。[br]
## [br][b]空列表[/b]：显示「无物可采」而非空白面板（可读的失败形态）。[br]
## [br][b]游标复位[/b]：每次上架都把游标落到首个可选行（采集后重上架时旧控件
## 已被移除重建，不复位会指错行）。
func present(p_bag_counts: Dictionary, p_entries: Array) -> void:
	_bag_label.text = LayoutScript.bag_text(p_bag_counts, TableScript.QUALITY_NAMES)
	_clear_entries()
	_entry_count = 0
	_slots.clear()
	if p_entries.is_empty():
		_show_message(TEXT_EMPTY)
		_navigator.call(&"reset")
		return
	_show_message(TEXT_HINT)
	for raw: Variant in p_entries:
		if not (raw is Dictionary):
			continue
		var entry: Dictionary = raw
		LayoutScript.add_entry_row(_item_box, entry, _entry_count, _on_entry_pressed)
		_slots.append(int(entry.get(TableScript.KEY_SLOT, -1)))
		_entry_count += 1
	_navigator.call(&"reset")


## 回填一条结果文案（采集成功/被拒——文案由系统给出，面板不自行措辞判断）。
func show_message(p_message: String) -> void:
	_show_message(p_message)


# === 查询（测试断言用——不触及内部控件路径）==================================

## 当前材料行数。
func entry_count() -> int:
	return _entry_count


## 全部材料行的按钮文本（渲染实证）。
func entry_texts() -> Array:
	var out: Array = []
	for child: Node in _item_box.get_children():
		if child is Button:
			out.append((child as Button).text)
	return out


## 某行是否可点（已采集 / 背包已满为 false）。
func is_entry_enabled(p_index: int) -> bool:
	var button: Button = _item_box.get_child(p_index) as Button
	return button != null and not button.disabled


## 行序 → 材料槽位（-1 = 越界）。
func slot_at(p_index: int) -> int:
	if p_index < 0 or p_index >= _slots.size():
		return -1
	return int(_slots[p_index])


## 当前结果文案。
func message_text() -> String:
	return _message_label.text if _message_label.visible else ""


## 顶部背包摘要文本。
func bag_text() -> String:
	return _bag_label.text


## 键盘/手柄游标当前所在行（-1 = 无可选行）。
func focused_index() -> int:
	return int(_navigator.call(&"focus_index"))


## 某行当前是否持有键盘焦点（焦点可见的实证）。
func is_entry_focused(p_index: int) -> bool:
	var button: Button = _item_box.get_child(p_index) as Button
	return button != null and button.has_focus()


## 测试用：按下第 [param p_index] 行（不依赖真实输入事件）。[br]
## [b]禁用行不发意图[/b]——与真实按钮行为一致。
func press_entry(p_index: int) -> void:
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

## 输入事件——上下选行 / 确认采集 / 取消离开，未映射的动作原样放行。[br]
## [br][b]「离开」按钮保有焦点时不吃确认键[/b]：此时 Enter 应触发那个按钮本身
## （玩家用 Tab/鼠标把焦点放过去，意图明确），游标确认让位。
func _input(p_event: InputEvent) -> void:
	if _leave_has_focus() and p_event.is_action_pressed(&"ui_accept"):
		return
	if not bool(_navigator.call(&"handle_event", p_event)):
		return
	get_viewport().set_input_as_handled()


## 游标变化——把键盘焦点搬到新行。
func _on_focus_changed(p_index: int) -> void:
	if p_index < 0 or p_index >= _item_box.get_child_count():
		return
	var button: Button = _item_box.get_child(p_index) as Button
	if button != null and not button.disabled:
		button.grab_focus()


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 构建控件树（遮罩 + 居中面板 + 标题 + 持有量 + 材料列表 + 文案 + 离开按钮）。[br]
## [br][b]引用不按控件路径查找[/b]：容器层级是构建细节，路径会随布局改动碎掉。
func _build_layout() -> void:
	var parts: Dictionary = LayoutScript.build(self, TEXT_TITLE)
	_title_label = parts.get("title_label")
	_bag_label = parts.get("balance_label")
	_item_box = parts.get("item_box")
	_message_label = parts.get("message_label")
	_leave_button = parts.get("leave_button")


## 行被点击——发采集意图（禁用行的按钮不会发 [signal Button.pressed]，天然被拦）。
func _on_entry_pressed(p_slot: int) -> void:
	harvest_requested.emit(p_slot)


## 行数组（游标的取数口——每次现取不缓存：上架会换一批控件）。
func _rows() -> Array:
	var out: Array = []
	for child: Node in _item_box.get_children():
		out.append(child)
	return out


## 游标确认——复用按钮自身的 [signal Button.pressed]（鼠标与键盘一条实现）。
func _activate_row(p_index: int) -> void:
	press_entry(p_index)


## 请求离开（「离开」按钮 / 取消键 / 手柄取消键）。
func _request_leave() -> void:
	leave_requested.emit()


## 「离开」按钮是否持有键盘焦点（未挂载时为 false——不臆造）。
func _leave_has_focus() -> bool:
	return _leave_button != null and is_instance_valid(_leave_button) \
			and _leave_button.has_focus()


func _clear_entries() -> void:
	for child: Node in _item_box.get_children():
		_item_box.remove_child(child)
		child.queue_free()


func _show_message(p_text: String) -> void:
	_message_label.text = p_text
	_message_label.visible = not p_text.strip_edges().is_empty()
