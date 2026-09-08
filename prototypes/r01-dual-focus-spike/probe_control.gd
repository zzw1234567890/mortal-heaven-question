extends Control
## R-01 spike：自定义 Control 测试探针。
##
## 记录自身收到的所有输入事件回调（mouse_entered/exited、focus_entered/exited、
## _gui_input、_unhandled_input），供 spike 脚本在注入事件后核对实际行为。
## 按 prototype-code.md 放宽标准：不做文档注释以外的生产化处理。

signal event_logged(source: String, detail: Dictionary)

var log: Array[Dictionary] = []

var hover_visual_active := false      # 鼠标悬停视觉（墨色边框加粗——UX 规范悬停态）
var focus_visual_active := false      # 键盘焦点视觉（松石青 2px 焦点环）

func _init() -> void:
	custom_minimum_size = Vector2(240, 80)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL

func _record(source: String, detail: Dictionary = {}) -> void:
	var entry := {"source": source, "hover": hover_visual_active,
	              "focus": focus_visual_active, "has_kbd_focus": has_focus(),
	              "detail": detail}
	log.append(entry)
	event_logged.emit(source, detail)

## --- 模拟 UI 组件的双视觉状态机（与 UX 规范的双焦点策略对应）---

func _on_hover_changed(active: bool) -> void:
	hover_visual_active = active

func _on_focus_changed(active: bool) -> void:
	focus_visual_active = active

## --- 引擎回调——全部记录 ---

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventKey:
		_record("gui_input", {"event": event})
	if event is InputEventMouseButton and event.pressed:
		accept_event()  # 与生产 UI 一致：点击被组件消耗

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventKey:
		_record("unhandled_input", {"event": event})

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_MOUSE_ENTER:
			hover_visual_active = true
			_record("mouse_entered")
		NOTIFICATION_MOUSE_EXIT:
			hover_visual_active = false
			_record("mouse_exited")
		NOTIFICATION_FOCUS_ENTER:
			focus_visual_active = true
			_record("focus_entered")
		NOTIFICATION_FOCUS_EXIT:
			focus_visual_active = false
			_record("focus_exited")

## --- 供信号连接的包装（_notification 不可被外部触发）---

func simulate_mouse_enter() -> void: _notification(NOTIFICATION_MOUSE_ENTER)
func simulate_mouse_exit() -> void: _notification(NOTIFICATION_MOUSE_EXIT)
