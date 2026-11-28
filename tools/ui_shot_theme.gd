extends Node
## ui_shot_theme —— 本轮（控件族补进主题）的视觉取证，出三张图：[br]
## [code]tools/ui_shot_theme_menu.png[/code]（真实主菜单）、
## [code]tools/ui_shot_theme_widgets.png[/code]（自搭的控件陈列屏，见
## [code]tools/ui_shot_theme_widgets.gd[/code]）、
## [code]tools/ui_shot_theme_battle.png[/code]（真实战斗场景）。[br]
## [br][b]为什么不是 [code]-s[/code] 脚本模式[/b]：[code]-s[/code] 下 Autoload 只是运行时
## 节点，[b]编译期没有全局标识符[/b]——凡直接写 [code]IdentitySelectionSystem[/code] 这类
## 名字的生产脚本会编译失败、界面静默退化成空白（先例 [code]tools/ui_shot_ui_art.gd[/code]
## 文件头的同一段注记）。走真实场景（[code].tscn[/code]）跑，Autoload 全局标识符照常成立。[br]
## [br][b]为什么不用 headless[/b]：headless 下 [code]root.get_texture()[/code] 拿不到真实
## 渲染结果，而本脚本要看的就是玩家实际看到的画面。[br]
## [br][b]陈列屏为什么比主菜单更重要[/b]：本轮补的九个控件族（进度条 / 滑杆 / 滚动条 /
## 输入框 / 弹出层 / 工具提示 / 窗口标题栏 / 下拉框 / 勾选框）在主菜单里[b]只出现三个[/b]
## （HSlider / OptionButton / CheckBox）；不搭一屏把它们摆齐，另外六个就没法用肉眼验收。[br]
## [br][b]本脚本只留流程[/b]（挂场景 → 等 → 截图 → 拆场景），陈列屏的构件在
## [code]ui_shot_theme_widgets.gd[/code]——两册合起来会越过 300 行软上限。[br]
## [br][b]运行[/b]（非 headless，否则无渲染）：[br]
## [code]Godot_v4.6.3-stable_win64.exe res://tools/ui_shot_theme.tscn[/code]

const OUT_DIR: String = "res://tools/"
const SHOT_W: int = 1920
const SHOT_H: int = 1080

const MainMenuScene := preload("res://src/ui/main_menu/MainMenu.tscn")
const CombatScene := preload("res://src/feature/combat/combat_scene.tscn")
const Widgets: GDScript = preload("res://tools/ui_shot_theme_widgets.gd")


func _ready() -> void:
	await _run()
	get_tree().quit(0)


func _run() -> void:
	_force_window_size(SHOT_W, SHOT_H)
	await _shot_scene(MainMenuScene, "ui_shot_theme_menu.png", 1.2)
	await _shot_widgets()
	await _shot_scene(CombatScene, "ui_shot_theme_battle.png", 1.3)
	print("[shot-theme] 三张图完成，在 ", OUT_DIR)


## 把某个场景挂进 1920×1080 宿主、等过渡走完、截图、再把宿主拆掉。[br]
## [br][b]拆掉是必须的[/b]：主菜单与战斗都有 Autoload 级的状态与 BGM，三张图连着跑时不拆
## 会让后一张叠在前一张的残影上（实测战斗屏会被主菜单的入场 Tween 压住）。
func _shot_scene(p_packed: PackedScene, p_file: String, p_wait: float) -> void:
	var holder: Control = Control.new()
	holder.name = "ThemeShotHolder"
	holder.size = Vector2(SHOT_W, SHOT_H)
	add_child(holder)
	var scene: Node = p_packed.instantiate()
	holder.add_child(scene)
	_settle_animation(scene)
	await _frames(8)
	await get_tree().create_timer(p_wait).timeout
	await _capture(p_file)
	holder.queue_free()
	await _frames(4)


## 关掉场景自己的入场动画（主菜单有个 0.8s 的 Tween，不关截到的是半透明中间态）。
func _settle_animation(p_scene: Node) -> void:
	if p_scene == null:
		return
	if "animate" in p_scene:
		p_scene.set("animate", false)


## 控件陈列屏：构件全在 [code]ui_shot_theme_widgets.gd[/code]，本方法只跑
## 「建 → 等 → 弹层 → 压鼠标 → 截 → 拆」。[br]
## [br][b]为什么建完还要等 10 帧才弹层[/b]：弹层的坐标是 popup 那一刻算的，节点得先进树、
## 容器得先排完版（[code]NOTIFICATION_SORT_CHILDREN[/code] 晚于 [code]add_child[/code] 那一帧），
## 否则下拉列表会落在旧位置上。
func _shot_widgets() -> void:
	var holder: Control = Widgets.build(self)
	await _frames(10)
	Widgets.popup_demos(holder)
	await _frames(6)
	# 悬停 / 按下两个瞬时态只能用真鼠标事件压出来（[code]theme_override[/code] 够不着它们）。
	# 顺序：先按住、后悬停——两个控件不重叠，但鼠标只有一只，最后那次移动决定谁在「悬停」；
	# 「按下」态是按下那一刻锁进 [code]BaseButton[/code] 的，后续移动不会把它抹掉（实测）。
	await _press_at(holder, "PressDemo")
	await _hover_at(holder, "HoverDemo")
	await _frames(12)
	await _capture("ui_shot_theme_widgets.png")
	holder.queue_free()
	await _frames(4)


## 把鼠标「移」到某个控件中心——推真 [InputEventMouseMotion]，走正常的 GUI 命中判定。
func _hover_at(p_holder: Control, p_name: String) -> void:
	var pos: Vector2 = _center_of(p_holder, p_name)
	if pos == Vector2.INF:
		return
	await _send_motion(pos)


## 把鼠标「按」在某个控件中心并[b]不松开[/b]（松开就回到常态了，截不到按下态）。
func _press_at(p_holder: Control, p_name: String) -> void:
	var pos: Vector2 = _center_of(p_holder, p_name)
	if pos == Vector2.INF:
		return
	await _send_motion(pos)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	get_viewport().push_input(down)
	await _frames(3)


## 取控件在视口坐标系里的中心；找不到（被拆掉 / 名字打错）返回 [constant Vector2.INF]。
func _center_of(p_holder: Control, p_name: String) -> Vector2:
	var node: Control = p_holder.find_child(p_name, true, false) as Control
	if node == null:
		push_warning("[shot-theme] 陈列屏里没有 %s，该瞬时态截不到" % p_name)
		return Vector2.INF
	return node.get_global_rect().get_center()


func _send_motion(p_pos: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = p_pos
	move.global_position = p_pos
	get_viewport().push_input(move)
	await _frames(3)


# ═══════════════════════════════════════════════════════════════════════════════
# 流程工具
# ═══════════════════════════════════════════════════════════════════════════════

func _frames(p_count: int) -> void:
	for i: int in range(p_count):
		await get_tree().process_frame


func _force_window_size(p_w: int, p_h: int) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(p_w, p_h))
	get_window().content_scale_size = Vector2i(p_w, p_h)
	get_window().size = Vector2i(p_w, p_h)


func _capture(p_file: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if image == null:
		print("[shot-theme] 截图失败：拿不到 viewport 图像（", p_file, "）")
		return
	var path: String = OUT_DIR + p_file
	var err: int = image.save_png(ProjectSettings.globalize_path(path))
	# 字节数走 get_file_as_bytes——PNG 是二进制，get_file_as_string 会在解码处刷
	# 「Unicode parsing error ... Invalid UTF-8 leading byte」的假警告（实测每张图一条）。
	var size: int = FileAccess.get_file_as_bytes(path).size() if err == OK else -1
	print("[shot-theme] ", path, " save err=", err, " bytes=", size)
