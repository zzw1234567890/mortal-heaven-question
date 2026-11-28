extends Node
## 战斗屏取证 + 截图（**非 headless 跑**）：
##   godot res://tools/ui_shot_battle.tscn
##
## 做三件事：
##   1. 把 combat_scene 挂到 1920×1080 宿主里，等进场过渡走完；
##   2. 打印「结束出牌」按钮的矩形 / 是否可见 / 该点最顶层 Control；
##   3. 用真实鼠标事件点它，打印阶段是否推进（老板 2026-11-28 反馈「点了没反应」）；
##   4. 存一张全屏截图。

const COMBAT_SCENE: String = "res://src/feature/combat/combat_scene.tscn"
const OUT_PATH: String = "res://tools/ui_shot_battle.png"
const SHOT_W: int = 1920
const SHOT_H: int = 1080


func _ready() -> void:
	await _run()
	get_tree().quit(0)


func _run() -> void:
	_force_window_size(SHOT_W, SHOT_H)
	var holder: Control = Control.new()
	holder.name = "BattleShotHolder"
	holder.size = Vector2(SHOT_W, SHOT_H)
	add_child(holder)

	var packed: PackedScene = load(COMBAT_SCENE)
	if packed == null:
		print("[shot-battle] 战斗场景加载失败")
		return
	var scene: Node = packed.instantiate()
	holder.add_child(scene)
	await _settle(20)
	await get_tree().create_timer(1.2).timeout

	var root_node: Variant = scene.get(&"combat_root")
	var bar: Variant = root_node.get(&"combat_bottombar") if root_node != null else null
	var holder_btn: Variant = bar.get(&"end_turn_button") if bar != null else null
	var button: Button = holder_btn.get(&"button") if holder_btn != null else null
	var phase_before: int = -1
	if root_node != null and root_node.has_method(&"current_phase"):
		phase_before = int(root_node.call(&"current_phase"))
	print("[shot-battle] root=%s bar=%s button=%s phase_before=%d" % [
			str(root_node != null), str(bar != null), str(button != null), phase_before])

	if button != null:
		var rect: Rect2 = button.get_global_rect()
		print("[shot-battle] button rect=%s visible=%s disabled=%s" % [
				str(rect), str(button.is_visible_in_tree()), str(button.disabled)])
		var center: Vector2 = rect.get_center()
		var top: Control = _topmost_at(holder, center)
		print("[shot-battle] 该点最顶层 = %s（%s）" % [
				top.name if top != null else "<null>", top.get_class() if top != null else "-"])
		_push_click(center)
		await _settle(6)
		var phase_after: int = -1
		if root_node != null and root_node.has_method(&"current_phase"):
			phase_after = int(root_node.call(&"current_phase"))
		print("[shot-battle] 点击后 phase=%d（%s）" % [
				phase_after, "推进了" if phase_after != phase_before else "**没反应**"])

	await _capture()
	print("[shot-battle] 完成，图在 %s" % OUT_PATH)


func _topmost_at(p_root: Control, p_pos: Vector2) -> Control:
	var hit: Control = null
	var stack: Array[Control] = [p_root]
	while not stack.is_empty():
		var node: Control = stack.pop_back()
		if not node.is_visible_in_tree():
			continue
		if node != p_root and node.get_global_rect().has_point(p_pos) \
				and node.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			hit = node
		for child: Node in node.get_children():
			if child is Control:
				stack.push_back(child as Control)
	return hit


func _push_click(p_pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = p_pos
	motion.global_position = p_pos
	get_viewport().push_input(motion)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = p_pos
		event.global_position = p_pos
		get_viewport().push_input(event)


func _settle(p_frames: int) -> void:
	for i: int in range(p_frames):
		await get_tree().process_frame


func _force_window_size(p_w: int, p_h: int) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(p_w, p_h))
	get_window().content_scale_size = Vector2i(p_w, p_h)
	get_window().size = Vector2i(p_w, p_h)


func _capture() -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if image == null:
		print("[shot-battle] 截图失败：拿不到 viewport 图像")
		return
	image.save_png(ProjectSettings.globalize_path(OUT_PATH))
