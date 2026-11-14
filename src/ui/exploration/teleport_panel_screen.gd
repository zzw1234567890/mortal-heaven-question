class_name TeleportPanelScreen
extends Control
## TeleportPanelScreen —— 传送节点的可跳转层 overlay（纯代码构建 UI）。[br]
## [br][b]职责[/b]：把 [code]ExplorationTeleport.targets_from[/code] 给出的可跳转层
## 列表渲染成一列可点层，并把选择意图发出去（[signal layer_chosen] /
## [signal leave_requested]）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本面板不持有层列表、不判定解锁、不写
## GSM——[method present] 收到的每条目已含 [code]layer / node_ids[/code]，
## 面板只决定怎么显示；「真的移动」由 [TeleportNodePresenter] 调系统 API。[br]
## [br][b]不自行计算落点[/b]：层内落点（同层多个未访问节点时选哪个）不由面板决定
## ——面板只报「选了哪一层」，落点选择是 Feature 层的口径（UI 零数值计算）。[br]
## [br][b]键盘/手柄导航[/b]（.claude/rules/ui-code.md「所有交互元素必须同时支持
## 键盘/鼠标和手柄输入」）：复用 [ShopPanelNavigator]——它的契约就是「一组
## [Button] + 确认 + 取消」，与商店货架无关（行数、禁用态、游标语义都一致）。[br]
## [br][b]事件层级 = _input[/b]：与 [ShopPanelScreen] 同源理由——焦点落在 [Button]
## 上时引擎的内置焦点导航会在 GUI 阶段吃掉方向键，[code]_unhandled_key_input[/code]
## 收不到；[code]_input[/code] 排在 GUI 派发之前，是唯一能拦住的层。消费走
## [method Viewport.set_input_as_handled]，顺带挡住 [code]InputManager[/code]
## 的 Esc → 暂停菜单。[br]
## [br][b]控件树在 [TeleportPanelLayout][/b]：面板只编排（同商店面板先例）。[br]
## [br][b]为什么不用 .tscn[/b]：与 [code]shop_panel_screen.gd[/code] /
## [code]event_panel_screen.gd[/code] 同源理由——一次性覆盖层，条目数随地图变化，
## 代码构建比维护场景文件更短。[br]
## [br][b]文案本地化豁免[/b]：与 node_move_interactor / node_interaction_rules
## 同源口径（项目暂无本地化系统）。
##
## 来源: design/gdd/exploration-system.md §4 移动规则 / §8 边界、
## design/gdd/exploration-ui-system.md §4c（overlay 先例）、ADR-0031 §2/§4、
## .claude/rules/ui-code.md、先例 [code]shop_panel_screen.gd[/code]。

## 玩家选了某一层（[param p_layer] 为 0 基层索引）。
signal layer_chosen(p_layer: int)
## 玩家点了「离开」或按了取消键。
signal leave_requested

## 控件树构建（尺寸/边距/焦点环与商店面板同源——只在一处定义）。
const LayoutScript := preload("res://src/ui/exploration/teleport_panel_layout.gd")
## 键盘/手柄游标（纯逻辑，不碰控件树——与商店共用同一实现）。
const NavigatorScript := preload("res://src/ui/exploration/shop_panel_navigator.gd")

## 标题与文案。
const TEXT_TITLE: String = "✦ 传送"
const TEXT_HINT: String = "选择要跳转的层（方向键选行，回车确认，Esc 离开）。"
const TEXT_EMPTY: String = "此处灵脉未通——暂无可跳转的层。"
## 层行文案（[code]%d[/code] 为 1 基层号、节点落点数）。
const TEXT_LAYER_ROW: String = "第 %d 层 · 落点 %d 处"

var _title_label: Label = null
var _message_label: Label = null
var _layer_box: VBoxContainer = null
var _leave_button: Button = null
## 层行数（测试/断言用——与控件数一致）。
var _row_count: int = 0
## 各行的层索引（行序 → 层——按下标取，不按控件路径）。
var _layers: Array = []
## 键盘/手柄游标。
var _navigator: RefCounted = null


func _init() -> void:
	name = "TeleportPanel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_layout()
	_navigator = NavigatorScript.new()
	_navigator.call(&"bind", _rows, _activate_row, _request_leave)
	_navigator.connect(&"focus_changed", _on_focus_changed)


# ═══════════════════════════════════════════════════════════════════════════════
# 对外
# ═══════════════════════════════════════════════════════════════════════════════

## 上架可跳转层列表。[br]
## [br][param p_targets] [code]ExplorationTeleport.targets_from[/code] 的产出
## （[code][{layer: int, node_ids: Array}][/code]，按层升序）。[br]
## [br][b]空列表[/b]：显示「暂无可跳转的层」而非空白面板（可读的失败形态）——
## 与 GDD §8 边界「传送节点不可激活」的语义一致。[br]
## [br][b]游标复位[/b]：每次上架都落到首个可选行（重上架时旧控件已被移除重建）。
func present(p_targets: Array) -> void:
	_clear_rows()
	_row_count = 0
	_layers.clear()
	if p_targets.is_empty():
		_show_message(TEXT_EMPTY)
		_navigator.call(&"reset")
		return
	_show_message(TEXT_HINT)
	for raw: Variant in p_targets:
		if not (raw is Dictionary):
			continue
		var entry: Dictionary = raw
		var layer: int = int(entry.get("layer", -1))
		if layer < 0:
			continue
		var ids: Array = entry.get("node_ids", [])
		LayoutScript.add_layer_row(_layer_box, TEXT_LAYER_ROW % [layer + 1, ids.size()],
				layer, _on_row_pressed)
		_layers.append(layer)
		_row_count += 1
	_navigator.call(&"reset")


# === 查询（测试断言用——不触及内部控件路径）==================================

## 当前层行数。
func row_count() -> int:
	return _row_count


## 全部层行的按钮文本（渲染实证）。
func row_texts() -> Array:
	var out: Array = []
	for child: Node in _layer_box.get_children():
		if child is Button:
			out.append((child as Button).text)
	return out


## 行序 → 层索引（-1 = 越界）。
func layer_at(p_index: int) -> int:
	if p_index < 0 or p_index >= _layers.size():
		return -1
	return int(_layers[p_index])


## 当前结果文案。
func message_text() -> String:
	return _message_label.text if _message_label.visible else ""


## 键盘/手柄游标当前所在行（-1 = 无可选行）。
func focused_index() -> int:
	return int(_navigator.call(&"focus_index"))


## 某行当前是否持有键盘焦点（焦点可见的实证）。
func is_row_focused(p_index: int) -> bool:
	var button: Button = _layer_box.get_child(p_index) as Button
	return button != null and button.has_focus()


## 测试用：按下第 [param p_index] 行（不依赖真实输入事件）。
func press_row(p_index: int) -> void:
	var button: Button = _layer_box.get_child(p_index) as Button
	if button != null and not button.disabled:
		button.emit_signal(&"pressed")


## 测试用：按下「离开」。
func press_leave() -> void:
	if _leave_button != null:
		_leave_button.emit_signal(&"pressed")


# ═══════════════════════════════════════════════════════════════════════════════
# 键盘 / 手柄导航（见类文档「事件层级 = _input」）
# ═══════════════════════════════════════════════════════════════════════════════

## 输入事件——上下选层 / 确认 / 取消离开，未映射的动作原样放行。[br]
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
	if p_index < 0 or p_index >= _layer_box.get_child_count():
		return
	var button: Button = _layer_box.get_child(p_index) as Button
	if button != null and not button.disabled:
		button.grab_focus()


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 构建控件树（遮罩 + 居中面板 + 标题 + 层列表 + 文案 + 离开按钮）。[br]
## [br][b]引用不按控件路径查找[/b]：容器层级是构建细节，路径会随布局改动碎掉。
func _build_layout() -> void:
	var parts: Dictionary = LayoutScript.build(self, TEXT_TITLE)
	_title_label = parts.get("title_label")
	_message_label = parts.get("message_label")
	_layer_box = parts.get("layer_box")
	_leave_button = parts.get("leave_button")


## 行被点击/确认——发选层意图（层索引随信号出去，落点由 Feature 层定）。
func _on_row_pressed(p_layer: int) -> void:
	layer_chosen.emit(p_layer)


## 行数组（游标的取数口——每次现取不缓存：上架会换一批控件）。
func _rows() -> Array:
	var out: Array = []
	for child: Node in _layer_box.get_children():
		out.append(child)
	return out


## 游标确认——复用按钮自身的 [signal Button.pressed]（鼠标与键盘一条实现）。
func _activate_row(p_index: int) -> void:
	press_row(p_index)


## 请求离开（「离开」按钮 / 取消键 / 手柄取消键）。
func _request_leave() -> void:
	leave_requested.emit()


## 「离开」按钮是否持有键盘焦点（未挂载时为 false——不臆造）。
func _leave_has_focus() -> bool:
	return _leave_button != null and is_instance_valid(_leave_button) \
			and _leave_button.has_focus()


func _clear_rows() -> void:
	for child: Node in _layer_box.get_children():
		_layer_box.remove_child(child)
		child.queue_free()


func _show_message(p_text: String) -> void:
	_message_label.text = p_text
	_message_label.visible = not p_text.strip_edges().is_empty()
