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
## [code]tools/ui_shot_identity_720.png[/code] / [code]tools/ui_shot_node_graph.png[/code]
## （1920×1080，节点图地图化总览）/ [code]tools/ui_shot_node_graph_720.png[/code]
## （1280×720，小屏可读性）/ [code]tools/ui_shot_node_graph_closeup.png[/code]
## （放大到 150% 的特写——节点地名的字面对比取证）/
## [code]tools/ui_shot_node_graph_zoomed_out.png[/code]（俯瞰——地形铺满视口）/
## [code]tools/ui_shot_node_hover.png[/code]（悬停高亮——真实鼠标事件驱动，见
## [method _shot_node_hover]）。[br]
## [br][b]本轮只跑节点图五张[/b]（背景清晰化 + 悬停高亮两处改动的取证图）：身份页那两张
## 与本轮改动无关，重拍只会把三张已提交的 PNG 重新编码一遍（无意义的 diff 噪声）。要全跑时
## 把 [code]_shot_identity[/code] 两行放回 [method _run] 即可（方法原样保留）。[br]
## [br]来源: 本轮任务书任务三（地图化）/ 任务四（地名可读性取证）、先前先例
## [code]tools/ui_pass_shot.gd[/code]。

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


## 取证主流程（协程——[method _ready] 不 await，让它在后台逐屏推进）。[br]
## [br][b]节点图先跑、身份页后跑[/b]：身份页那张要 [code]request_force_show[/code]
## 意图，跑完不清会污染后续；节点图跑在先、身份页留在最后，中途不必担心意图串味。
func _run() -> void:
	await _settle(10)
	await _shot_node_graph(OUT_W, OUT_H, "ui_shot_node_graph", 1.0, false)
	await _shot_node_graph(OUT_W_720, OUT_H_720, "ui_shot_node_graph_720", 1.0, false)
	await _shot_node_graph(OUT_W, OUT_H, "ui_shot_node_graph_closeup", CLOSEUP_ZOOM, true)
	await _shot_node_graph(OUT_W, OUT_H, "ui_shot_node_graph_zoomed_out",
			ZOOMED_OUT_ZOOM, false)
	await _shot_node_hover()
	print("[ui-art] 完成，五张图在 " + ProjectSettings.globalize_path(OUT_DIR))
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

## 节点图特写倍率——取视口缩放上限 [code]NodeGraphViewport.ZOOM_MAX[/code] 的同值，
## 让地名的字面在同一张图里大到能直接判读（正投影放大，不改变任何绘制比例）。
const CLOSEUP_ZOOM: float = 1.5

## 全图俯瞰倍率——比自动适配再缩一档，四边（尤其是左右）留出可见的地形边缘，
## 用来验证「地形铺满视口、左右没有纯黑带」（任务书任务二取证）。[br]
## [br][b]为什么是 0.6 而不是 0.5[/b]：0.5 正好是
## [code]NodeGraphViewport.LABEL_HIDE_ZOOM[/code]——再低一档地名就整体隐藏了，
## 而这张图要同时回答「有没有黑带」与「地名还读不读得出」。[br]
## [br][b]低于自动适配时才生效[/b]：[method _focus_node_graph] 直接覆盖 zoom，
## 与自动适配值的大小关系无关（本图自动适配触顶 1.5，0.6 一定更小）。
const ZOOMED_OUT_ZOOM: float = 0.6


## 发「新开局」意图再挂探索容器——容器消费意图后直落第一张图并生成真实 DAG。[br]
## [br][param p_zoom] > 0 时在整图适配之后覆盖视口缩放（特写取证用；[code]1.0[/code]
## = 保持自动适配的缩放）。[br]
## [param p_verbose] 打印每个节点的地名与六态——特写图的字面与状态可被文本核对。
func _shot_node_graph(p_w: int, p_h: int, p_name: String, p_zoom: float,
		p_verbose: bool) -> void:
	await _clear_holder()
	IntentScript.clear()
	ExplorationIntentScript.clear()
	_force_window_size(p_w, p_h)
	ExplorationIntentScript.request_new_run()
	var scene: Control = ExplorationScene.instantiate() as Control
	_mount(scene)
	await _settle(150)
	var screen: Variant = scene.get(&"node_graph_screen")
	print("[ui-art] 节点图屏幕: %s" % ("已挂载" if screen != null else "未挂载"))
	if screen != null:
		await _focus_node_graph(screen, p_zoom)
		if p_verbose:
			_report_places(screen)
	await _capture(p_name)
	_force_window_size(OUT_W, OUT_H)


## 整图适配之后按 [param p_zoom] 覆盖视口缩放（特写取证）。[br]
## [br][b]为什么要等一帧[/b]：[method NodeGraphScreen.trigger_map_load] 走
## [code]call_deferred(fit_to_content)[/code]，立刻写 zoom 会被随后那次适配覆盖回去。
func _focus_node_graph(p_screen: Variant, p_zoom: float) -> void:
	if p_zoom <= 0.0 or is_equal_approx(p_zoom, 1.0):
		return
	await _settle(2)
	var graph_viewport: Variant = p_screen.get(&"viewport")
	if graph_viewport == null:
		print("[ui-art] 视口缺失——无法设置特写缩放")
		return
	graph_viewport.call(&"fit_to_content", true)
	await _settle(2)
	graph_viewport.call(&"_apply_transform", p_zoom, graph_viewport.get(&"offset"), 0.0)
	await _settle(2)
	print("[ui-art] 特写缩放 %.2f（偏移 %s）" % [p_zoom, str(graph_viewport.get(&"offset"))])


## 打印每个节点的「地名 = ？类型 / 六态」——截图之外的字面取证（地名的字面对比
## 比对靠它，[code]ui_shot_node_graph_closeup.png[/code] 只作肉眼旁证）。
func _report_places(p_screen: Variant) -> void:
	var r: Variant = p_screen.call(&"renderer")
	if r == null:
		print("[ui-art] 渲染器缺失")
		return
	var detail: Dictionary = r.get(&"nodes") as Dictionary
	var states: Dictionary = r.get(&"states") as Dictionary
	var ids: Array = detail.keys()
	ids.sort()
	for node_id: int in ids:
		print("[ui-art] 节点 %d 地名 '%s' 类型 %d 六态 %d" % [node_id,
				str(r.call(&"place_name_of", node_id)),
				int((detail[node_id] as Dictionary).get("type", -1)),
				int(states.get(node_id, -1))])


## 悬停高亮取证（本轮任务 D）——[b]真实鼠标事件驱动[/b]，不直接写 [code]hovered_node[/code]：
## 悬停这条路只有走 [code]NodeGraphRenderer._gui_input[/code] 的 [code]mouse_motion[/code]
## 分支才算验证过，直接赋值只能证明「画得出来」。[br]
## [br][b]落点怎么算[/b]：屏幕坐标 = 局部坐标 × zoom + offset（[NodeGraphViewport] 的
## 变换口径），故把节点中心换算到视口坐标再 [code]push_input[/code]。[br]
## [br][b]为什么优先选可达节点[/b]：可达态还有 110% 放大，取证图信息量最大；迷雾节点
## 的文案是「?」，看不出地名那一行。
func _shot_node_hover() -> void:
	await _clear_holder()
	IntentScript.clear()
	ExplorationIntentScript.clear()
	_force_window_size(OUT_W, OUT_H)
	ExplorationIntentScript.request_new_run()
	var scene: Control = ExplorationScene.instantiate() as Control
	_mount(scene)
	await _settle(150)
	var screen: Variant = scene.get(&"node_graph_screen")
	if screen == null:
		print("[ui-art] 悬停取证：节点图屏幕未挂载")
		return
	var graph_viewport: Variant = screen.get(&"viewport")
	var r: Variant = screen.call(&"renderer")
	await _settle(3)
	# 教程覆盖层带着 MOUSE_FILTER_STOP 铺在节点图上（首次进入必然出现），
	# 不关掉它真实的鼠标事件会被它吃掉、永远走不到渲染器的悬停分支。
	_dismiss_tutorial()
	await _settle(3)
	var target: int = _pick_hover_target(r)
	var local: Vector2 = r.call(&"get_node_position", target)
	var at: Vector2 = (graph_viewport as Control).global_position \
			+ local * float(graph_viewport.get(&"zoom")) \
			+ (graph_viewport.get(&"offset") as Vector2)
	_mouse_move_to(at)
	await _settle(5)
	print("[ui-art] 悬停目标 %d 落点 %s → hovered=%d 高亮=%s"
			% [target, str(at), int(r.get(&"hovered_node")),
			str(r.call(&"is_node_highlighted", target))])
	print("[ui-art] 悬停文案: %s" % str(r.call(&"hover_text_for", target)))
	print("[ui-art] 调试 rect=%s scale=%s pos=%s viewport=%s/%s 命中=%s"
			% [str((r as Control).get_global_rect()), str((r as Control).scale),
			str((r as Control).position), str((graph_viewport as Control).global_position),
			str((graph_viewport as Control).size),
			str(r.call(&"_has_point", local))])
	await _capture("ui_shot_node_hover")
	_force_window_size(OUT_W, OUT_H)


## 关掉首次进入的教程覆盖层——[method _shot_node_hover] 的前置条件。[br]
## [br][b]为什么必须关[/b]：[code]NodeTutorialOverlay[/code] 是整屏
## [code]MOUSE_FILTER_STOP[/code] 的 Control，铺在节点图之上，只对左键与回车有反应
## ——真实鼠标移动被它吃掉，[code]NodeGraphRenderer._gui_input[/code] 永远收不到
## [code]mouse_motion[/code]，取证图会拍成「跑通了但什么都没发生」。[br]
## [br][b]为什么走它自己的 [code]skip(3)[/code] 而不是直接 [code]visible = false[/code][/b]：
## 那条公开出口会停表、释放焦点、写完成标记并发 [code]tutorial_skipped[/code]——
## 与玩家点一下跳过是同一条路，取证状态与真机一致。
func _dismiss_tutorial() -> void:
	if _holder == null:
		return
	var overlay: Node = _holder.find_child("NodeTutorialOverlay", true, false)
	if overlay == null:
		print("[ui-art] 悬停取证：未见教程覆盖层（很可能已完成过）")
		return
	overlay.call(&"skip", 3)
	print("[ui-art] 悬停取证：教程覆盖层已跳过 visible=%s"
			% str((overlay as Control).visible))


## 悬停目标——优先可达态（=1），否则取第一个已揭示节点（六态 0-4）。
func _pick_hover_target(p_r: Variant) -> int:
	var states: Dictionary = p_r.get(&"states") as Dictionary
	var ids: Array = (p_r.get(&"nodes") as Dictionary).keys()
	ids.sort()
	var fallback: int = int(ids[0]) if not ids.is_empty() else -1
	for node_id: int in ids:
		var state: int = int(states.get(node_id, -1))
		if state == 1:
			return node_id
		if fallback == int(ids[0]) and state >= 0 and state <= 4:
			fallback = node_id
	return fallback


## 派发一次真实鼠标移动事件到根视口（见 [method _shot_node_hover]）。[br]
## [br][b]为什么要 warp + parse 两下[/b]：只做 [code]push_input[/code] 时引擎的 GUI
## 悬停分发不认（[code]gui_get_hovered_control[/code] 仍为空）——取证图会拍到一张
## 没有高亮的图，而那种「跑通了但什么都没发生」是最难发现的一类失败。故先把系统光标
## 真的挪过去（引擎随即产出一次真实 motion），再补一次显式投递兜底。
func _mouse_move_to(p_at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = p_at
	event.global_position = p_at
	Input.warp_mouse(p_at)
	get_viewport().push_input(event)
	print("[ui-art] 悬停控制: %s" % str(get_viewport().gui_get_hovered_control()))


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
