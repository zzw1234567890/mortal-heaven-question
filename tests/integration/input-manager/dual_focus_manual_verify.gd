extends Node
## 双焦点最小测试场景 —— Godot 4.6 双焦点行为验证 (C4)
##
## 测试目标：验证 Godot 4.6 中 mouse focus 与 keyboard focus 独立行为。
##
## 测试场景：3 个自定义 Button 节点 + 1 个 Label（显示当前焦点状态）
##
## 测试问题：
##   Q1: grab_focus() 是否仅影响键盘/手柄焦点（不影响鼠标 hover）？
##   Q2: 鼠标 hover 时 _gui_input() 是否仍正常触发？
##   Q3: 键盘焦点在某按钮上时，鼠标 hover 另一按钮——两者的 visual feedback 是否独立？
##   Q4: 键盘焦点在 locked（disabled）按钮上时，鼠标 hover 是否仍能触发？
##   Q5: mouse_entered/mouse_exited 信号在双焦点下的行为是否与 Godot 4.3 一致？
##
## 运行方式：在 Godot 编辑器中运行此场景（需视觉观察焦点指示器 + 控制台日志）
##
## 注意：此测试无法在 headless 模式下运行——双焦点行为需要实际渲染和输入设备


# ── 节点引用 ──────────────────────────────────────────
var button_keyboard: Button
var button_mouse: Button
var button_both: Button
var status_label: Label
var log_label: Label

var keyboard_focused_button: String = "无"
var mouse_hovered_button: String = "无"


func _ready() -> void:
	_setup_ui()
	_setup_signals()
	_log("=== 双焦点测试场景已启动 ===")
	_log("Godot 4.6 双焦点系统：mouse focus ≠ keyboard focus")
	_log("")
	_log("操作指引：")
	_log("  1. 用 Tab 键切换键盘焦点（观察青色光环）")
	_log("  2. 移动鼠标到不同按钮上（观察橙色高亮）")
	_log("  3. 同时用 Tab 键 + 鼠标——观察两者是否独立")
	_log("  4. 点击「锁定」按钮后，观察键盘焦点是否仍在，鼠标 hover 是否仍触发")
	_log("")


func _setup_ui() -> void:
	# ── 状态标签 ──
	status_label = Label.new()
	status_label.position = Vector2(50, 30)
	status_label.size = Vector2(600, 60)
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.text = "键盘焦点: 无 | 鼠标悬停: 无"
	add_child(status_label)

	# ── 按钮 A：仅键盘聚焦指示 ──
	button_keyboard = Button.new()
	button_keyboard.text = "按钮 A (keyboard target)"
	button_keyboard.position = Vector2(50, 110)
	button_keyboard.size = Vector2(250, 60)
	button_keyboard.focus_mode = Control.FOCUS_ALL
	add_child(button_keyboard)

	# ── 按钮 B：仅鼠标悬停指示 ──
	button_mouse = Button.new()
	button_mouse.text = "按钮 B (mouse target)"
	button_mouse.position = Vector2(350, 110)
	button_mouse.size = Vector2(250, 60)
	button_mouse.focus_mode = Control.FOCUS_ALL
	add_child(button_mouse)

	# ── 按钮 C：同时检测两种焦点 ──
	button_both = Button.new()
	button_both.text = "按钮 C (both)"
	button_both.position = Vector2(50, 200)
	button_both.size = Vector2(250, 60)
	button_both.focus_mode = Control.FOCUS_ALL
	add_child(button_both)

	# ── 日志标签 ──
	log_label = Label.new()
	log_label.position = Vector2(50, 300)
	log_label.size = Vector2(600, 400)
	log_label.add_theme_font_size_override("font_size", 12)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(log_label)

	# Q5: 验证 mouse_entered/mouse_exited 信号
	button_keyboard.grab_focus()


func _setup_signals() -> void:
	# ── 焦点相关信号 ──
	button_keyboard.focus_entered.connect(_on_focus_entered.bind("A"))
	button_keyboard.focus_exited.connect(_on_focus_exited.bind("A"))
	button_keyboard.mouse_entered.connect(_on_mouse_entered.bind("A"))
	button_keyboard.mouse_exited.connect(_on_mouse_exited.bind("A"))

	button_mouse.focus_entered.connect(_on_focus_entered.bind("B"))
	button_mouse.focus_exited.connect(_on_focus_exited.bind("B"))
	button_mouse.mouse_entered.connect(_on_mouse_entered.bind("B"))
	button_mouse.mouse_exited.connect(_on_mouse_exited.bind("B"))

	button_both.focus_entered.connect(_on_focus_entered.bind("C"))
	button_both.focus_exited.connect(_on_focus_exited.bind("C"))
	button_both.mouse_entered.connect(_on_mouse_entered.bind("C"))
	button_both.mouse_exited.connect(_on_mouse_exited.bind("C"))


# ── 信号处理 ──────────────────────────────────────────

func _on_focus_entered(button_name: String) -> void:
	keyboard_focused_button = button_name
	_update_status()
	_log("⌨ 键盘焦点 → 按钮 %s" % button_name)


func _on_focus_exited(button_name: String) -> void:
	if keyboard_focused_button == button_name:
		keyboard_focused_button = "无"
	_update_status()
	_log("⌨ 键盘焦点 → 离开按钮 %s" % button_name)


func _on_mouse_entered(button_name: String) -> void:
	mouse_hovered_button = button_name
	_update_status()
	_log("🖱 鼠标进入 → 按钮 %s" % button_name)


func _on_mouse_exited(button_name: String) -> void:
	if mouse_hovered_button == button_name:
		mouse_hovered_button = "无"
	_update_status()
	_log("🖱 鼠标离开 → 按钮 %s" % button_name)


func _update_status() -> void:
	status_label.text = "键盘焦点: %s | 鼠标悬停: %s" % [keyboard_focused_button, mouse_hovered_button]

	# 如果键盘焦点和鼠标悬停在不同按钮上——证明双焦点独立工作
	if keyboard_focused_button != "无" and mouse_hovered_button != "无" and keyboard_focused_button != mouse_hovered_button:
		status_label.text += " ✅ 双焦点独立！（键盘=%s, 鼠标=%s）" % [keyboard_focused_button, mouse_hovered_button]


func _log(msg: String) -> void:
	print("[DualFocus] %s" % msg)
	if log_label:
		log_label.text += msg + "\n"
		# 只保留最近 30 行
		var lines := log_label.text.split("\n")
		if lines.size() > 30:
			lines = lines.slice(lines.size() - 30)
			log_label.text = "\n".join(lines)


# ── 输入处理 —— 可选：验证 _gui_input 在双焦点下的行为 ──

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_log("🖱 _gui_input 收到鼠标点击: button=%d, pos=%s" % [event.button_index, event.position])
	elif event is InputEventKey and event.pressed:
		_log("⌨ _gui_input 收到按键: keycode=%d" % event.keycode)
