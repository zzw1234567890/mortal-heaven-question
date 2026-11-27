extends Node
## ui_shot_ui_art —— 本轮视觉化取证：身份选择页（1920×1080 + 1280×720）与节点图。[br]
## [br][b]为什么不是 [code]-s[/code] 脚本模式[/b]：同 [code]ui_pass_shot.gd[/code] 头部
## 注记——[code]-s[/code] 下 Autoload 只是运行时节点，[b]编译期没有全局标识符[/b]，
## 凡直接写 [code]IdentitySelectionSystem[/code] 这类名字的生产脚本会编译失败、
## 界面静默退化成空白。走真实场景（[code].tscn[/code]）跑，Autoload 全局标识符照常成立。[br]
## [br][b]为什么不用 headless[/b]：headless 下 [code]root.get_texture()[/code] 拿不到
## 真实渲染结果，本脚本要看的就是玩家实际看到的画面。[br]
## [br][b]运行[/b]（非 headless，否则无渲染）：[br]
## [code]Godot_v4.6.3-stable_win64.exe res://tools/ui_shot_ui_art.tscn[/code][br]
## [br]输出：[code]tools/ui_shot_identity.png[/code] /
## [code]tools/ui_shot_identity_720.png[/code] / [code]tools/ui_shot_node_graph.png[/code]。[br]
## [br]来源: 本轮任务书任务三、先前先例 [code]tools/ui_pass_shot.gd[/code]。

const OUT_DIR: String = "res://tools/"
const OUT_W: int = 1920
const OUT_H: int = 1080
const OUT_W_720: int = 1280
const OUT_H_720: int = 720

const IdentitySelectScene := preload("res://src/ui/identity_select/identity_select.tscn")
const ExplorationScene := preload("res://src/feature/exploration/exploration_scene.tscn")

const IntentScript := preload("res://src/ui/identity_select/identity_select_intent.gd")
const ExplorationIntentScript := preload("res://src/feature/exploration/exploration_entry_intent.gd")

var _holder: Control = null


func _ready() -> void:
	var abs_dir: String = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	print("[ui-art] 输出目录: " + abs_dir)
	_run()


## 取证主流程（协程——[method _ready] 不 await，让它在后台逐屏推进）。
func _run() -> void:
	await _settle(10)
	await _shot_identity(OUT_W, OUT_H, "ui_shot_identity")
	await _shot_identity(OUT_W_720, OUT_H_720, "ui_shot_identity_720")
	await _shot_node_graph()
	print("[ui-art] 完成，三张图在 " + ProjectSettings.globalize_path(OUT_DIR))
	get_tree().quit()


# ═══════════════════════════════════════════════════════════════════════════════
# 一、身份选择页（两种分辨率）
# ═══════════════════════════════════════════════════════════════════════════════

## 发「强制显示」意图再挂身份选择场景——否则已选过身份时场景会整体跳过选择 UI。[br]
## [br][b]不动画[/b]：入场 tween 会把卡片从 alpha 0 拉起，截图要取稳定态。
func _shot_identity(p_w: int, p_h: int, p_name: String) -> void:
	await _clear_holder()
	_force_window_size(p_w, p_h)
	IntentScript.request_force_show()
	var screen: Control = IdentitySelectScene.instantiate() as Control
	screen.set(&"animate", false)
	_mount(screen)
	await _settle(45)
	_report_cards(screen)
	await _capture(p_name)
	_force_window_size(OUT_W, OUT_H)


## 打印每张卡片的角色小块数量与「有没有立绘」——截图之外的结构性取证。
func _report_cards(p_screen: Control) -> void:
	var grid: GridContainer = p_screen.get_node_or_null("LayoutAnchor/GridContainer")
	if grid == null:
		print("[ui-art] 网格未挂载")
		return
	for i: int in range(grid.get_child_count()):
		var card: Control = grid.get_child(i) as Control
		var name_label: Label = card.get_child(0).get_child(0) as Label
		var row: Node = _find_row(card)
		var tiles: int = 0
		var portraits: int = 0
		if row != null:
			tiles = row.get_child_count()
			for child: Node in row.get_children():
				if child.get_node_or_null("Portrait") != null:
					portraits += 1
		print("[ui-art] 卡%d '%s' 小块=%d 立绘=%d"
				% [i, name_label.text, tiles, portraits])


# ═══════════════════════════════════════════════════════════════════════════════
# 二、节点图（真实生成）
# ═══════════════════════════════════════════════════════════════════════════════

## 发「新开局」意图再挂探索容器——容器消费意图后直落第一张图并生成真实 DAG。
func _shot_node_graph() -> void:
	await _clear_holder()
	IntentScript.clear()
	ExplorationIntentScript.clear()
	ExplorationIntentScript.request_new_run()
	var scene: Control = ExplorationScene.instantiate() as Control
	_mount(scene)
	await _settle(150)
	var screen: Variant = scene.get(&"node_graph_screen")
	print("[ui-art] 节点图屏幕: %s" % ("已挂载" if screen != null else "未挂载"))
	await _capture("ui_shot_node_graph")


# ═══════════════════════════════════════════════════════════════════════════════
# 挂载 / 等待 / 截图
# ═══════════════════════════════════════════════════════════════════════════════

## 窗口与视口都锁到给定尺寸——取证图的尺寸由这里定，不受本机桌面分辨率影响。
func _force_window_size(p_w: int, p_h: int) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(p_w, p_h))
	var window: Window = get_window()
	window.content_scale_size = Vector2i(p_w, p_h)
	window.size = Vector2i(p_w, p_h)


## 把节点挂到一个尺寸确定的宿主上（父级给尺寸，避免「_ready 后改 size」告警）。
func _mount(p_node: Node) -> void:
	if _holder == null:
		_holder = Control.new()
		_holder.name = "UIArtHolder"
		_holder.size = Vector2(float(_viewport_w()), float(_viewport_h()))
		get_tree().root.add_child(_holder)
	_holder.add_child(p_node)


func _viewport_w() -> int:
	return int(get_window().content_scale_size.x)


func _viewport_h() -> int:
	return int(get_window().content_scale_size.y)


## 拆掉上一屏的宿主（连同它下面的一切）。
func _clear_holder() -> void:
	if _holder != null and is_instance_valid(_holder):
		get_tree().root.remove_child(_holder)
		_holder.free()
	_holder = null
	await _settle(3)


## 等 [param p_frames] 帧并确保这一帧已画完（截图取的是画完的纹理）。
func _settle(p_frames: int) -> void:
	for _i: int in range(maxi(p_frames, 1)):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


## 抓当前根视口并存成 png。
func _capture(p_name: String) -> void:
	var image: Image = get_tree().root.get_texture().get_image()
	var path: String = OUT_DIR + p_name + ".png"
	var err: int = image.save_png(path)
	print("[ui-art] %s -> %s (%dx%d, err=%d)"
			% [p_name, path, image.get_width(), image.get_height(), err])


## 递归找名为 AvatarRow 的容器（VBox 由代码建，名字不作硬约定）。
func _find_row(p_node: Node) -> Node:
	if p_node.name == &"AvatarRow":
		return p_node
	for child: Node in p_node.get_children():
		var found: Node = _find_row(child)
		if found != null:
			return found
	return null
