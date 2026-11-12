class_name EventPanelScreen
extends Control
## EventPanelScreen —— 探索事件节点的选择面板（纯代码构建 UI）。
##
## 流程：两段式。
## [br]1. [b]选项段[/b]——[method present] 显示标题 / 正文 / 2~3 个选项按钮；
## 点击发出 [signal option_chosen]（只声明意图，不结算）。
## [br]2. [b]结果段[/b]——结算方回调 [method show_result]，面板切成结果文案 +
## 明细行 + 「离开」按钮；点「离开」自毁。
##
## [b]为什么不用 .tscn[/b]：面板是一次性覆盖层，节点树随事件内容变化，
## 代码构建比维护场景文件更短也更不容易与占位场景打架。
##
## 来源: Sprint 18 探索事件节点。

## 玩家点了某个选项——参数是事件 id 与选项下标；结算由外面做。
signal option_chosen(p_event_id: String, p_option_index: int)

const PANEL_WIDTH: int = 720
const PANEL_HEIGHT: int = 480

var _event_id: String = ""
var _title_label: Label = null
var _body_label: Label = null
var _option_box: VBoxContainer = null
var _inline_message: Label = null
var _options_disabled: bool = false


func _init() -> void:
	name = "EventPanel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_layout()


# === 构建 =====================================================================

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
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.add_theme_font_size_override("font_size", 26)
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_title_label)

	_body_label = Label.new()
	_body_label.name = "BodyLabel"
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_body_label)

	_inline_message = Label.new()
	_inline_message.name = "MessageLabel"
	_inline_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inline_message.visible = false
	column.add_child(_inline_message)

	_option_box = VBoxContainer.new()
	_option_box.name = "OptionBox"
	_option_box.add_theme_constant_override("separation", 10)
	column.add_child(_option_box)


# === 对外 =====================================================================

## 显示事件选项段。[param p_def] 是 [code]EventDef[/code]（弱类型，避免硬依赖）。
func present(p_def: Variant) -> void:
	if p_def == null:
		return
	_event_id = str(p_def.get(&"event_id"))
	_title_label.text = str(p_def.get(&"title"))
	_body_label.text = str(p_def.get(&"body"))
	_inline_message.visible = false
	_clear_options()
	var raw_options: Variant = p_def.get(&"options")
	if raw_options is Array:
		var options: Array = raw_options
		for i in range(options.size()):
			var option: Variant = options[i]
			if option == null:
				continue
			_add_option_button(i, str(option.get(&"text")))
	if _option_box.get_child_count() == 0:
		_inline_message.text = "这件事没有可选的应对。"
		_inline_message.visible = true


## 切到结果段：显示结果文案与明细，只留一个「离开」。[br]
## [param p_result] 来自 [code]ExplorationEventSystem.resolve_option[/code]。
func show_result(p_result: Dictionary) -> void:
	_options_disabled = true
	_clear_options()
	_body_label.text = str(p_result.get("result_text", ""))
	var lines: Variant = p_result.get("lines", [])
	var detail: Array = []
	if lines is Array:
		for raw: Variant in lines:
			detail.append(str(raw))
	_inline_message.text = "\n".join(detail)
	_inline_message.visible = not detail.is_empty()
	var leave := Button.new()
	leave.name = "LeaveButton"
	leave.text = "离开"
	leave.pressed.connect(queue_free)
	_option_box.add_child(leave)


func option_count() -> int:
	return _option_box.get_child_count()


## 测试用：按下第 [param p_index] 个选项按钮（不依赖真实输入事件）。
func press_option(p_index: int) -> void:
	if p_index < 0 or p_index >= _option_box.get_child_count():
		return
	var node: Node = _option_box.get_child(p_index)
	if node is Button:
		(node as Button).emit_signal(&"pressed")


func displayed_event_id() -> String:
	return _event_id


# === 内部 =====================================================================

func _clear_options() -> void:
	for child: Node in _option_box.get_children():
		_option_box.remove_child(child)
		child.queue_free()


func _add_option_button(p_index: int, p_text: String) -> void:
	var button := Button.new()
	button.name = "Option%d" % p_index
	button.text = p_text
	button.disabled = _options_disabled
	button.pressed.connect(func() -> void: _on_option_pressed(p_index))
	_option_box.add_child(button)


func _on_option_pressed(p_index: int) -> void:
	if _options_disabled:
		return
	_options_disabled = true
	for child: Node in _option_box.get_children():
		if child is Button:
			(child as Button).disabled = true
	option_chosen.emit(_event_id, p_index)
