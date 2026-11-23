extends GutTest
## 节点图视口「整图适配」与「玩家手动缩放」的交接回归（2026-11-23 节点图版式走查）。
##
## [b]背景[/b]：玩家反馈「节点图节点簇偏左」。探针
## （[code]tools/probe_layout_geometry.gd[/code]，非 headless）在 1920×1080 下实测
## 终态 [code]cluster_center = viewport_center = (960, 516)[/code]，
## [code]center_dx = center_dy = 0[/code]，[code]fit_to_content[/code] 恰好被调 2 次
## 且两次看到的 [code]size[/code] 都是布局后的真实值 [code](1920, 1032)[/code]；
## 在真实 [code]exploration_scene[/code] 链路上，四档分辨率（1280×720 / 1600×900 /
## 1920×1080 / 2560×1440）的 [code]dx_frac_of_vp[/code] 与 [code]dy_frac_of_vp[/code]
## 也全部是 [code]0[/code]。所以「偏左」在当前 HEAD 上[b]复现不出来[/b]——
## 它已由 [code]d007e5c[/code]（[code]NOTIFICATION_RESIZED[/code] 里补适配）修掉。[br]
## [br][b]但同一次探针抓到另一条真缺陷[/b]：[code]NOTIFICATION_RESIZED[/code] 的处理
## 是[b]无条件[/b]重新整图适配的。实测：自动适配到 [code]zoom = 1.5[/code] 后，
## 玩家手动缩到 [code]0.9[/code] 并平移，再把宿主尺寸从 1920×1080 改成 1760×990，
## [code]zoom[/code] 被打回 [code]1.5[/code]、[code]offset[/code] 被打回自动适配值——
## 玩家刚拉近看的那条支线被拽走了。窗口拖边框、切全屏、切分辨率都会踩到。[br]
## [br][b]修法[/b]（任务点名要的口径）：[code]fit_to_content[/code] 记下自己上一次
## 落到画面上的变换；[code]NOTIFICATION_RESIZED[/code] 只在「当前变换仍等于那次自动
## 适配值」时才重新适配——玩家动过就不动，没动过才跟（不是每帧重适配，
## 每帧重适配会打断手动缩放，那是另一条错）。[br]
## [br][b]测试口径[/b]：断言全是「两块实测值的关系」或「占视口宽/高的几分之几」，
## 没有裸的屏幕像素阈值——本文件要在四档分辨率下同时成立。[br]
## [br]来源: design/ux/interaction-patterns.md「画布缩放平移」（50%-150%、空格复位）、
## exploration-ui Story 001 AC-2；缺陷证据见上述探针输出。

const SCREEN_SCENE := preload("res://src/ui/exploration/node_graph_screen.tscn")

## 四档待测分辨率。
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440),
]

## 测试用地图 ID（真实图，节点数稳定）。
const MAP_ID: StringName = &"qing_yun_jian_zong"

## 玩家手动缩放的目标值——刻意取在自动适配值（本图触顶 1.5）之外的档位，
## 这样「有没有被打回」在数值上可判，而不是靠近似相等蒙混。
const MANUAL_ZOOM: float = 0.9

## 相对误差容限——占视口尺寸的比例。
const EPS_FRAC: float = 0.02

var _holder: Control = null
var _gsm: Node = null
var _exploration_before: Dictionary = {}


func before_each() -> void:
	_gsm = get_node_or_null(NodePath("/root/GameStateManager"))
	assert_not_null(_gsm, "本文件需要真实 GameStateManager Autoload")
	if _gsm == null:
		return
	# 落图会写 gsm.exploration（current_map / visited / map_states）——本文件是
	# 只读几何的用例，跑完必须把探索域复位，否则后面的存档用例会看到脏 map_states
	# （实测：不复位时 test_legacy_save_migration 的「失败时内存状态不得被部分写入」变红）。
	_exploration_before = (_gsm.get(&"exploration") as Dictionary).duplicate(true)


func after_each() -> void:
	if _holder != null and is_instance_valid(_holder):
		remove_child(_holder)
		_holder.free()
	_holder = null
	if _gsm != null and is_instance_valid(_gsm) and not _exploration_before.is_empty():
		_gsm.set(&"exploration", _exploration_before)
	_exploration_before = {}


# ═══════════════════════════════════════════════════════════════════════════════
# 一、进图即居中（「节点簇偏左」的守卫——当前已绿，防回归）
# ═══════════════════════════════════════════════════════════════════════════════

## 四档分辨率下节点簇都要落在视口中心——这是玩家一进图看到的那一屏。
func test_node_cluster_lands_at_viewport_center_on_entry() -> void:
	for res: Vector2i in RESOLUTIONS:
		var vp: Control = await _mount_graph(res)
		var center: Vector2 = _sample_cluster_center(vp)
		var viewport_center: Vector2 = vp.size * 0.5
		assert_lte(absf(center.x - viewport_center.x), vp.size.x * EPS_FRAC,
				"[%s] 节点簇横向居中误差应 ≤ 视口宽 2%%，实测中心 %.1f / 视口 %.1f"
				% [_tag(res), center.x, viewport_center.x])
		assert_lte(absf(center.y - viewport_center.y), vp.size.y * EPS_FRAC,
				"[%s] 节点簇纵向居中误差应 ≤ 视口高 2%%，实测中心 %.1f / 视口 %.1f"
				% [_tag(res), center.y, viewport_center.y])


## 内容要真的适配到视口里，而不是停在初始 [code]zoom = 1.0 / offset = 0[/code]
## （那正是 [code]d007e5c[/code] 修掉的「挤左上角」）。
func test_entry_fit_actually_moves_the_transform() -> void:
	var vp: Control = await _mount_graph(RESOLUTIONS[2])
	assert_ne(vp.get(&"offset"), Vector2.ZERO,
			"进图后 offset 应已由整图适配写入，而不是停在初始的 (0,0)")
	assert_gt(float(vp.get(&"zoom")), 0.0, "zoom 应为正数")


## 适配跑在「布局已定尺寸」之后——探针记录到的每一次调用看到的 size 都非零。
## 这条锁住候选根因①「延迟执行时拿到布局前尺寸」不再复发。
func test_fit_never_runs_against_a_collapsed_viewport() -> void:
	var vp: Control = await _mount_graph(RESOLUTIONS[2])
	assert_gt(vp.size.x, 0.0, "适配后视口宽度应为真实布局值")
	assert_gt(vp.size.y, 0.0, "适配后视口高度应为真实布局值")
	var content: Rect2 = (vp.get(&"renderer") as Control).call(&"get_content_rect") as Rect2
	assert_gt(content.size.x, 0.0, "内容包围盒应已算好（适配的前提）")
	# 内容在屏幕空间的包围盒要落在视口内——适配没跑的话会被裁掉一角
	var zoom: float = float(vp.get(&"zoom"))
	var offset: Vector2 = vp.get(&"offset")
	var screen_end: Vector2 = (content.position + content.size) * zoom + offset
	var screen_start: Vector2 = content.position * zoom + offset
	assert_gte(screen_start.x, -vp.size.x * EPS_FRAC, "内容左缘应落在视口内")
	assert_gte(screen_start.y, -vp.size.y * EPS_FRAC, "内容上缘应落在视口内")
	assert_lte(screen_end.x, vp.size.x * (1.0 + EPS_FRAC), "内容右缘应落在视口内")
	assert_lte(screen_end.y, vp.size.y * (1.0 + EPS_FRAC), "内容下缘应落在视口内")


# ═══════════════════════════════════════════════════════════════════════════════
# 二、尺寸变化不打断玩家（本轮修复的缺陷）
# ═══════════════════════════════════════════════════════════════════════════════

## 玩家手动缩放/平移之后，窗口尺寸变化不该把视角拽回整图。
## [b]改前红[/b]：zoom 被打回 1.5、offset 被打回自动适配值。
func test_resize_preserves_manual_zoom_and_pan() -> void:
	var vp: Control = await _mount_graph(RESOLUTIONS[2])
	var manual_offset: Vector2 = Vector2(vp.size.x * 0.2, vp.size.y * 0.25)
	# 玩家的滚轮缩放与拖拽平移都汇到 _apply_transform（单一写入点）
	vp.call(&"_apply_transform", MANUAL_ZOOM, manual_offset, 0.0)
	await wait_frames(2)
	assert_almost_eq(float(vp.get(&"zoom")), MANUAL_ZOOM, 0.0001,
			"前置：手动缩放应已生效")

	_resize_holder(Vector2(1760, 990))
	await wait_frames(4)

	assert_almost_eq(float(vp.get(&"zoom")), MANUAL_ZOOM, 0.0001,
			"窗口尺寸变化后玩家手动缩放应保留（不被拽回自动整图适配值）")
	var after: Vector2 = vp.get(&"offset") as Vector2
	assert_almost_eq(after.y, manual_offset.y, 1.0,
			"窗口尺寸变化后玩家平移量应保留（高度未变的那一维不该被重置）")


## 手动平移但没缩放时同样保住——只比 zoom 会漏掉「平移量被重置」这一半。
func test_resize_preserves_manual_pan_when_zoom_untouched() -> void:
	var vp: Control = await _mount_graph(RESOLUTIONS[2])
	var auto_zoom: float = float(vp.get(&"zoom"))
	var panned: Vector2 = (vp.get(&"offset") as Vector2) + Vector2(120.0, 90.0)
	vp.call(&"_apply_transform", auto_zoom, panned, 0.0)
	await wait_frames(2)

	_resize_holder(Vector2(1760, 990))
	await wait_frames(4)

	assert_almost_eq((vp.get(&"offset") as Vector2).x, panned.x, 1.0,
			"平移量应保留——即使缩放值恰好等于自动适配值")
	assert_almost_eq((vp.get(&"offset") as Vector2).y, panned.y, 1.0,
			"平移量应保留（纵向）")


## 玩家没动过视角时，尺寸变化[b]仍然[/b]要重新整图适配——
## 这是 [code]d007e5c[/code] 的原始意图，不能被本轮修复顺手拿掉。
## 判据用相对量：重新适配后节点簇仍应落在新视口的中心。
func test_resize_still_refits_when_view_was_untouched() -> void:
	var vp: Control = await _mount_graph(RESOLUTIONS[1])
	var new_size: Vector2 = Vector2(1760, 990)
	_resize_holder(new_size)
	await wait_frames(4)

	var center: Vector2 = _sample_cluster_center(vp)
	var viewport_center: Vector2 = vp.size * 0.5
	assert_lte(absf(center.x - viewport_center.x), vp.size.x * EPS_FRAC,
			"未动过视角时，尺寸变化后应重新居中（横向）")
	assert_lte(absf(center.y - viewport_center.y), vp.size.y * EPS_FRAC,
			"未动过视角时，尺寸变化后应重新居中（纵向）")


## 空格复位把视角交还给自动适配——之后再改尺寸，应当恢复「跟着适配走」。
func test_space_reset_hands_the_view_back_to_auto_fit() -> void:
	var vp: Control = await _mount_graph(RESOLUTIONS[2])
	vp.call(&"_apply_transform", MANUAL_ZOOM, Vector2(200.0, 120.0), 0.0)
	await wait_frames(2)
	vp.call(&"fit_to_content", true)
	await wait_frames(2)

	_resize_holder(Vector2(1760, 990))
	await wait_frames(4)

	var center: Vector2 = _sample_cluster_center(vp)
	var viewport_center: Vector2 = vp.size * 0.5
	assert_lte(absf(center.x - viewport_center.x), vp.size.x * EPS_FRAC,
			"复位后视角应交还自动适配——尺寸变化时重新居中")


# ═══════════════════════════════════════════════════════════════════════════════
# 辅助
# ═══════════════════════════════════════════════════════════════════════════════

## 挂真实 [code]node_graph_screen[/code] 到指定尺寸的宿主上，落一张真实图并等布局稳定。
func _mount_graph(p_res: Vector2i) -> Control:
	_holder = Control.new()
	_holder.name = "ViewportFitHolder"
	_holder.size = Vector2(p_res)
	add_child(_holder)
	var screen: Control = SCREEN_SCENE.instantiate() as Control
	screen.set(&"animate", false)
	_holder.add_child(screen)
	screen.call(&"trigger_map_load", MAP_ID)
	await wait_frames(20)
	return screen.get_node(^"NodeGraphViewport") as Control


## 改宿主尺寸——全矩形锚点的视口随之收到 [code]NOTIFICATION_RESIZED[/code]。
func _resize_holder(p_size: Vector2) -> void:
	_holder.size = p_size


## 节点簇在屏幕空间的中心：位置 × zoom + offset 的包围盒中点。
func _sample_cluster_center(p_vp: Control) -> Vector2:
	var renderer: Control = p_vp.get(&"renderer") as Control
	var positions: Dictionary = renderer.get(&"_positions")
	var zoom: float = float(p_vp.get(&"zoom"))
	var offset: Vector2 = p_vp.get(&"offset")
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for pos: Vector2 in positions.values():
		var screen_pos: Vector2 = pos * zoom + offset
		min_p = min_p.min(screen_pos)
		max_p = max_p.max(screen_pos)
	return (min_p + max_p) * 0.5


func _tag(p_res: Vector2i) -> String:
	return "%dx%d" % [p_res.x, p_res.y]
