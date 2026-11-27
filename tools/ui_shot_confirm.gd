extends Node
## ui_shot_confirm —— 身份页「确认选择」弹窗取证。[br]
## [br][b]为什么单独一个工具[/b]：老板 2026-11-27 报「选择身份后，确认选择弹框提示显示有问题」，
## 要修就得先看见它长什么样。`ui_shot_ui_art.gd` 只截了卡片网格，没打开弹窗。[br]
## [br][b]运行[/b]（非 headless，否则 [code]root.get_texture()[/code] 拿不到真实渲染）：
## [code]Godot_v4.6.3-stable_win64.exe res://tools/ui_shot_confirm.tscn[/code][br]
## 输出：[code]tools/ui_shot_confirm_1920.png[/code] / [code]tools/ui_shot_confirm_1280.png[/code]

const OUT_DIR: String = "res://tools/"
const IdentitySelectScene := preload("res://src/ui/identity_select/identity_select.tscn")
const IntentScript := preload("res://src/ui/identity_select/identity_select_intent.gd")

var _holder: Control = null


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_run()


func _run() -> void:
	await _settle(10)
	await _shot(1920, 1080, "ui_shot_confirm_1920")
	await _shot(1280, 720, "ui_shot_confirm_1280")
	print("[shot-confirm] 完成")
	get_tree().quit()


func _shot(p_w: int, p_h: int, p_name: String) -> void:
	await _clear()
	_force_window_size(p_w, p_h)
	IntentScript.request_force_show()
	var screen: Control = IdentitySelectScene.instantiate() as Control
	screen.set(&"animate", false)
	_holder.add_child(screen)
	await _settle(45)
	var grid: GridContainer = screen.get_node_or_null("LayoutAnchor/GridContainer")
	if grid == null or grid.get_child_count() == 0:
		print("[shot-confirm] 网格未挂载，无法取证")
		return
	# 选第一张卡——走真实 GUI 输入路径（卡片靠 gui_input 而非 pressed 信号）
	var card: Control = grid.get_child(0) as Control
	var center: Vector2 = card.get_global_rect().get_center()
	for ev: InputEvent in [_click(center, true), _click(center, false)]:
		get_viewport().push_input(ev)
	await _settle(6)
	var confirm_button: Button = screen.get_node_or_null("LayoutAnchor/ConfirmButton") as Button
	if confirm_button == null:
		confirm_button = screen.get_node_or_null("LayoutAnchor/Button") as Button
	if confirm_button != null:
		confirm_button.emit_signal("pressed")
	await _settle(20)
	_report(screen)
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT_DIR + p_name + ".png"))
	print("[shot-confirm] 已存 %s (%dx%d)" % [p_name, p_w, p_h])


## 把弹窗内部结构打出来：每个可见子节点的类、矩形、字号、文字。
## 这样「文字被裁 / 互相压 / 弹窗太小」都能被读出来，而不是靠我盯图猜。
func _report(p_screen: Control) -> void:
	var dialog: ConfirmationDialog = p_screen.get_node_or_null("ConfirmDialog") \
			as ConfirmationDialog
	if dialog == null:
		print("[shot-confirm] 没有 ConfirmDialog")
		return
	print("[shot-confirm] 弹窗 visible=%s size=%s min=%s text='%s'"
			% [dialog.visible, dialog.size, dialog.get_contents_minimum_size(),
			dialog.dialog_text])
	_walk(dialog, 0)


func _walk(p_node: Node, p_depth: int) -> void:
	if p_depth > 4:
		return
	for child: Node in p_node.get_children():
		var ctrl: Control = child as Control
		if ctrl == null or not ctrl.visible:
			continue
		var extra: String = ""
		var label: Label = child as Label
		if label != null:
			extra = " fs=%d text='%s' want=%s" % [label.get("theme_override_font_sizes/font_size")
					if label.has_theme_font_size_override("font_size") else -1,
					label.text, label.get_minimum_size()]
		print("[shot-confirm] %s%s %s rect=%s%s"
				% ["  ".repeat(p_depth), child.name, child.get_class(),
				ctrl.get_global_rect(), extra])
		_walk(child, p_depth + 1)


func _click(p_pos: Vector2, p_press: bool) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = p_press
	ev.position = p_pos
	ev.global_position = p_pos
	return ev


func _clear() -> void:
	if _holder != null and is_instance_valid(_holder):
		_holder.queue_free()
		_holder = null
	_holder = Control.new()
	_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_holder)


func _force_window_size(p_w: int, p_h: int) -> void:
	var win: Window = get_window()
	win.size = Vector2i(p_w, p_h)
	DisplayServer.window_set_size(Vector2i(p_w, p_h))


func _settle(p_frames: int) -> void:
	for _i: int in range(p_frames):
		await get_tree().process_frame
