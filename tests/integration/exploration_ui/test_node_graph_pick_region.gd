extends GutTest
## 节点图「看得见的节点点得到」回归（2026-11-26 第四轮真机试玩走查）。[br]
## [br][b]缺陷现场[/b]：真机走查在「结算后回到选图 → 重进地图 → 再打一场」这一步上复现
## ——同一个可达节点，第一张图点得动、第二张图点不动。取证记录：
## [code]局部=(-45.0, 110.0)｜渲染器自检命中=101｜可达=true｜拾取落到=NodeGraphViewport[/code]，
## 而点得动的那次是 [code]局部=(0.0, 110.0)｜拾取落到=@Control@222（渲染器）[/code]。[br]
## [br][b]根因[/b]：引擎的 GUI 拾取对 Control 的判据是
## [code]Rect2(Vector2.ZERO, size).has_point(local)[/code]——矩形[b]永远从局部原点起[/b]。
## 而 [code]NodeGraphLayout.compute_positions[/code] 把同层节点摆在
## [code](row_width * 0.5) - idx * NODE_GAP[/code]，即中点右侧的节点落在[b]局部负 x[/b]；
## [code]NodeGraphViewport.fit_to_content[/code] 再把 [code]renderer.position[/code] 推到
## [code]size * 0.5 - content_center * zoom[/code]（本机实测 [code](960, 316.5)[/code]，
## [code]zoom = 1.5[/code]），于是渲染器自己的矩形只覆盖屏幕右半边
## [code]x ∈ [960, 3840][/code]。局部 x 为负的节点[b]画得出来[/b]（[code]_draw[/code] 溢出
## 不受矩形约束，玩家在截图里看得见）却[b]点不到[/b]——落在渲染器矩形之外，事件被父级
## [code]NodeGraphViewport[/code] 当成画布拖拽吃掉了。[br]
## [br][b]为什么此前没被发现[/b]：节点局部 x 恰好为 [code]0.0[/code] 时
## [code]Rect2.has_point[/code] 认（左边缘算在内），而 0 正是「该层只有 1 个节点」的形态；
## 组件级用例又都直调 [code]request_move[/code] 或直发 [code]renderer.gui_input[/code]，
## 两条都绕过了引擎拾取——本缺陷只在「真实右键 + 真实视口变换」下现形。[br]
##
## [br][b]★ 本轮语义变更（有意改动，报告单列）★[/b]：命中判据从「点中了那枚印吗」改成
## 「这一点属于哪块地」——[code]point-in-rect[/code] → [code]point-in-region[/code]。[br]
## 老板 2026-11-27：「我想要一个节点一块地区，鼠标移上去都能高亮有交互的那种」。旧口径
## 要求精确点中那 56px（悬停时 61.6px）的圆印；地图化之后节点只是小小一枚印，移上去的
## 手感极差，而玩家看到的却是一大片地区。新口径下鼠标移到这块地的[b]任何一处[/b]都算
## 命中该节点。[br]
## [br][b]改法（不是放宽）[/b]：三条判据[b]逐条保留并加强[/b]——[br]
##   · 「区域内点命中」：旧版只用一个中心点，新版取该地区的[b]四分之三点采样[/b]，
##     且断言采样点全都归属同一节点（旧版做不到这件事，因为它只认中心）；[br]
##   · 「边界外不命中」：判据从「内容包围盒之外」升级为「地区铺满矩形之外」，
##     并[b]实测[/b]该点确实在矩形外（前置断言），而不是靠一个魔数碰巧成立；[br]
##   · 「两区交界取最近种子」：全新一条。垂直平分线上的点被相邻两块同时包含
##     （裁剪保留边界点），逐块 [code]is_point_in_polygon[/code] 判定会撞出两个命中
##     ——新口径改走「最近种子」，本用例把这条口径钉死。[br]
## 而 [code]_has_point[/code]（控件要不要认领事件）[b]仍是矩形判据[/b]，含义没变窄也没
## 放宽：画布留白处必须继续能吃事件，否则空地上拖不动画布。两件事本轮正式分开。[br]
##
## [br][b]测试口径[/b]：挂真 [code]NodeGraphViewport[/code]（真缩放/平移）+ 真
## [code]Viewport.push_input[/code]，断言终点落在 mock 系统的递交记录上。[br]
## [br]来源: 真机走查记录 [code]run_out_pt4_f.txt[/code]（[code]node-click[/code] /
## [code]node-hit-geom[/code]）、本轮任务书任务四（拾取改多边形）、
## ADR-0031 §4（可见性与可点性同源）、exploration-ui Story 001 AC-2/AC-10。

const ViewportScript := preload("res://src/ui/exploration/node_graph_viewport.gd")
const InteractorScript := preload("res://src/ui/exploration/node_move_interactor.gd")
const DATA_STUB := preload("res://src/ui/exploration/node_graph_data_stub.gd")
const MockSystem := preload("res://tests/integration/exploration_ui/mocks/mock_exploration_system.gd")
## 地区命中判据（[code]node_at[/code]）与铺满矩形（[code]bounds_for[/code]）——
## 与渲染器内部读的是[b]同一个[/b]模块，不是照抄一份判据。
const RegionCommon := preload("res://src/ui/exploration/node_graph_region_common.gd")

## 宿主尺寸——与真机走查同一量级（1920×1080，视口占满）。
const HOST_SIZE: Vector2 = Vector2(1920.0, 1080.0)

## 缺陷节点：stub 第 1 层有 2 格，[code]idx = 1[/code] 的那格局部 x 为负。
const BUGGY_NODE: int = 102
## 该格的起始节点（stub graph 里 0 → [101, 102]）。
const CURRENT_NODE: int = 0

## 拾取区域之外的一点（用于断言「扩出去的不是整张画布」）。[br]
## [br][b]前置断言会实测它在地区矩形之外[/b]——地区铺满矩形随布局标定变化，
## 写死的点一旦落回矩形内，用例必须[b]红[/b]而不是静默退化成空断言。
const OUTSIDE_POINT: Vector2 = Vector2(-400.0, -400.0)

## 同层相邻两格——「两区交界取最近种子」那条的种子对（stub 第 1 层的两格）。[br]
## [br][b]ID 与左右的关系不是顺着的[/b]：布局把同层第 [code]idx[/code] 格摆在
## [code](row_width * 0.5) - idx * NODE_GAP[/code]，故 [code]idx = 0[/code]（ID 较小）
## 落在[b]右[/b]边（+x）、[code]idx = 1[/code]（ID 较大）落在[b]左[/b]边（-x）。
## 下面按「ID 大小」命名而不是按左右，免得平局断言读起来自相矛盾。
const SMALL_ID: int = 101
const BIG_ID: int = 102

var mock: Node = null
var host: Control = null
var vp: Control = null
var interactor: NodeMoveInteractor = null


func before_each() -> void:
	mock = MockSystem.new()
	add_child_autofree(mock)
	host = Control.new()
	host.size = HOST_SIZE
	add_child_autofree(host)
	# 真视口（承载缩放平移变换）+ 真渲染器（[code]_init[/code] 里自建并挂为子节点）
	vp = ViewportScript.new()
	vp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(vp)
	var snap: Dictionary = DATA_STUB.stub_snapshot()
	vp.call(&"setup", snap["graph"], snap["nodes"], snap["visited"],
			snap["current_node"])
	vp.call(&"fit_to_content", true)
	interactor = InteractorScript.new()
	interactor.set_reduce_motion(true)
	add_child_autofree(interactor)
	interactor.setup(vp.get(&"renderer") as Control, mock)
	interactor.apply_snapshot(snap)
	await wait_frames(2)


# ═══════════════════════════════════════════════════════════════════════════════
# 一、真实点击必须落到节点上（第四轮缺陷的现场——判据换了，回归不许丢）
# ═══════════════════════════════════════════════════════════════════════════════

## 局部坐标为负的节点，经真实左键投递也要提交移动。[br]
## [b]改前红[/b]：事件被父级视口吃掉，[code]move_calls[/code] 为空。
func test_click_node_at_negative_local_x_submits_move() -> void:
	# Arrange
	var renderer: Control = _renderer()
	var world: Vector2 = renderer.call(&"get_node_position", BUGGY_NODE) as Vector2
	assert_lt(world.x, 0.0,
			"前置：本用例的节点应落在渲染器矩形左缘之外（缺陷现场）")
	assert_eq(_hit_any(renderer, world), BUGGY_NODE,
			"前置：地区判据应命中该节点（画得出来）")
	mock.move_result = {"success": true, "reason": "", "ap_remaining": 2}
	# Act
	_click_canvas(renderer.get_global_transform_with_canvas() * world)
	# Assert
	assert_eq(mock.move_calls, [[CURRENT_NODE, BUGGY_NODE]],
			"画得出来的节点也必须点得到（引擎拾取不得把它判在控件之外）")


## 对照：局部坐标为正的节点一直点得动——证明上面的红不是「压根没投对坐标」（局部 x 为
## 正的是 [constant SMALL_ID]，见常量注记：ID 小的一格反而在右边）。
func test_click_node_at_positive_local_x_submits_move() -> void:
	# Arrange
	var renderer: Control = _renderer()
	var world: Vector2 = renderer.call(&"get_node_position", SMALL_ID) as Vector2
	assert_gt(world.x, 0.0, "前置：对照节点应落在渲染器矩形内")
	mock.move_result = {"success": true, "reason": "", "ap_remaining": 2}
	# Act
	_click_canvas(renderer.get_global_transform_with_canvas() * world)
	# Assert
	assert_eq(mock.move_calls, [[CURRENT_NODE, SMALL_ID]], "矩形内的节点应点得动")


# ═══════════════════════════════════════════════════════════════════════════════
# 二、判据一：区域内的点命中该区域（不只是一枚印的中心）
# ═══════════════════════════════════════════════════════════════════════════════

## 地区内部四分之三点采样，全部命中同一个节点。[br]
## [b]改前红[/b]：旧口径只认「点中了那枚 56px 的印」——四分之三点全部落空。[br]
## [br][b]采样点的取法[/b]：节点中心与地区四个顶点之间各取中点——这些点确定在
## 该节点的 Voronoi 单元内部（顶点本身就是单元的角），而它们离中心足够远，
## 「印章半径之内」解释不了命中。
func test_point_inside_a_region_hits_that_region() -> void:
	# Arrange
	var renderer: Control = _renderer()
	var cells: Dictionary = renderer.get(&"cells") as Dictionary
	assert_true(cells.has(BIG_ID), "前置：分块表应含该节点")
	var cell: PackedVector2Array = cells[BIG_ID]
	assert_gte(cell.size(), 3, "前置：地区至少 3 个顶点（凸多边形）")
	var center: Vector2 = renderer.call(&"get_node_position", BIG_ID) as Vector2
	var samples: Array[Vector2] = []
	for vertex: Vector2 in cell:
		samples.append(center.lerp(vertex, 0.75))
	# Act / Assert——每一个采样点都必须落回该节点
	for point: Vector2 in samples:
		assert_eq(_hit_any(renderer, point), BIG_ID,
				"地区内部的点 %s 应命中该地区（旧口径只认中心那一枚印）" % point)


## 地区中心与节点中心必须一致口径（[code]node_at[/code] 是「最近种子」——
## 种子就是节点坐标，不是多边形质心）。[br]
## [b]为什么单列[/b]：这是「点地区」与「点印」两种口径唯一的交集点；若哪天有人把
## 命中改成「按多边形质心排序」，中心点还能过、偏心的地区会全错，这条会先红。
func test_region_center_is_the_node_position() -> void:
	# Arrange
	var renderer: Control = _renderer()
	for node_id: int in (DATA_STUB.stub_node_details() as Dictionary).keys():
		var center: Vector2 = renderer.call(&"get_node_position", node_id) as Vector2
		# Assert
		assert_eq(_hit_any(renderer, center), node_id,
				"节点 %d 的中心应命中它自己的地区" % node_id)


# ═══════════════════════════════════════════════════════════════════════════════
# 三、判据二：地区之外不命中（控件仍认领矩形区域——两件事分开）
# ═══════════════════════════════════════════════════════════════════════════════

## 地区铺满矩形之外不吃事件；矩形之内处处有主（地区铺满，不留缝）。[br]
## [b]改前红（加强版）[/b]：旧版只断言「内容包围盒之外不命中」，而新版地区铺得更远
## ——判据必须跟到 [method NodeGraphRegionCommon.bounds_for] 给的矩形为止，
## 否则「画出来的边界之外还能点到地」这种说不清的空白会溜过去。
func test_point_outside_the_region_bounds_hits_nothing() -> void:
	# Arrange
	var renderer: Control = _renderer()
	var bounds: Rect2 = RegionCommon.bounds_for(renderer.call(&"get_content_rect"))
	# 前置：写死的那个点必须[实测]在地区矩形之外（标定一变，这条先红）
	assert_false(bounds.has_point(OUTSIDE_POINT),
			"前置：%s 应在地区矩形 %s 之外（否则本用例是空断言）"
			% [OUTSIDE_POINT, bounds])
	# Assert：矩形之外不给节点
	assert_eq(_hit_any(renderer, OUTSIDE_POINT), -1,
			"地区矩形之外不应认领任何节点（画布拖拽仍归视口）")
	# 对照：矩形内部四角稍稍内收处，处处有主——地区不留缝
	for corner: Vector2 in [bounds.position + Vector2.ONE * 4.0,
			Vector2(bounds.end.x - 4.0, bounds.position.y + 4.0),
			bounds.end - Vector2.ONE * 4.0,
			Vector2(bounds.position.x + 4.0, bounds.end.y - 4.0)]:
		assert_ne(_hit_any(renderer, corner), -1,
				"地区矩形内 %s 处应有归属（铺满不留缝）" % corner)


## 控件认领范围（[code]_has_point[/code]）仍是矩形——本轮[b]没有[/b]把它收窄到地区。[br]
## [br][b]为什么必须留着这条[/b]：画布留白处若不再认领事件，空地上就拖不动画布了
## （[code]NodeGraphViewport[/code] 的平移靠子控件把事件冒上来）。两条判据并存 =
## 「点哪个节点」可以随视觉规格演进，「控件认领到哪」不受牵连。
func test_pick_rect_still_claims_the_canvas_for_dragging() -> void:
	# Arrange
	var renderer: Control = _renderer()
	# Assert：留白（渲染器自身矩形内、内容之外）仍认领
	assert_true(bool(renderer.call(&"_has_point", Vector2(1500.0, 900.0))),
			"渲染器自身矩形内的留白应仍认领事件（否则空地上拖不动画布）")
	# 而「认领」不等于「命中某节点」——两件事本轮正式分开
	assert_eq(_hit_any(renderer, Vector2(1500.0, 900.0)), -1,
			"认领事件不等于命中节点（地区之外无主）")


# ═══════════════════════════════════════════════════════════════════════════════
# 四、判据三：两区交界取最近种子（旧口径做不到——逐块判会撞出两个命中）
# ═══════════════════════════════════════════════════════════════════════════════

## 垂直平分线上的点归属唯一，且由「离哪个种子近」决定。[br]
## [br][b]为什么这条必须存在[/b]：分块裁剪[b]保留了边界点[/b]（相邻两块各自都把
## 平分线算作自己的边，不留零宽缝隙），于是逐块 [code]is_point_in_polygon[/code]
## 判定会在交界处撞出[b]两个[/b]命中——而「哪块地该亮起来」只能有一个答案。
## 新口径走「最近种子」，天然唯一。[br]
## [br][b]平局怎么算[/b]：正中点两粒种子等距——按较小 ID 取胜（与
## [method NodeGraphRegionCells.nearest_seed_index] 的「平局取较小索引」同一条口径，
## 只把「索引」换成对外的节点 ID）。这条不是随便定的：没有它，同一个点在不同帧
## 可能给出不同答案，高亮就会闪。
func test_point_on_the_border_between_two_regions_picks_the_nearer_seed() -> void:
	# Arrange
	var renderer: Control = _renderer()
	var small: Vector2 = renderer.call(&"get_node_position", SMALL_ID) as Vector2
	var big: Vector2 = renderer.call(&"get_node_position", BIG_ID) as Vector2
	assert_lt(SMALL_ID, BIG_ID, "前置：SMALL_ID 确实是较小的那个 ID（平局取胜方）")
	assert_true(is_equal_approx(small.y, big.y),
			"前置：两粒种子必须同高，平分线才是竖直线（本用例的几何前提）")
	assert_true(is_equal_approx((small + big).x * 0.5, 0.0),
			"前置：两粒种子以 x = 0 为轴对称（分层错开量在第 1 层为 0）")
	var middle: Vector2 = (small + big) * 0.5
	var left_id: int = BIG_ID if big.x < small.x else SMALL_ID
	var right_id: int = SMALL_ID if big.x < small.x else BIG_ID
	# Assert 1——正中点：等距，按较小 ID 取胜，且答案唯一（不是「两个都算」）
	assert_eq(_hit_any(renderer, middle), SMALL_ID,
			"平分线上的正中点应唯一归属较小 ID（不得撞出两个命中）")
	# Assert 2——偏向左侧那粒：归属必须跟着最近的种子变
	assert_eq(_hit_any(renderer, middle + Vector2(-0.5, 0.0)), left_id,
			"偏向 x 较小的那粒种子一丝，应归它")
	# Assert 3——偏向右侧那粒：归属翻到另一块
	assert_eq(_hit_any(renderer, middle + Vector2(0.5, 0.0)), right_id,
			"偏向 x 较大的那粒种子一丝，应归它（交界处不得含糊）")


# ═══════════════════════════════════════════════════════════════════════════════
# 装置：真实输入投递
# ═══════════════════════════════════════════════════════════════════════════════

## 渲染器控件（视口里自建的那个）。
func _renderer() -> Control:
	return vp.get(&"renderer") as Control


## 宿主自己的命中判据——走 [method NodeGraphRenderer.hit_test_any]。[br]
## [br][b]为什么断言用宿主而不是直调 [method RegionCommon.node_at][/b]：宿主多了
## 「逐层浮现未显现的层不命中」这条过滤，而玩家点的是宿主。直调纯函数会绕过它，
## 用例就守不住「未浮现的层点不到」。
func _hit_any(renderer: Control, point: Vector2) -> int:
	return int(renderer.call(&"hit_test_any", point))


## 在画布坐标投递一对真实左键事件（按下 + 抬起）。[br]
## [br][b]第二参必须为 true[/b]（[code]in_local_coords[/code]）：默认口径会把坐标
## 当屏幕坐标再乘一次拉伸逆变换（[code]real_input_click_driver.gd[/code] 头注释记的坑）。
func _click_canvas(p_point: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = p_point
		event.global_position = p_point
		get_viewport().push_input(event, true)
