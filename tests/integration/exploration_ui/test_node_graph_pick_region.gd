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
## [br][b]测试口径[/b]：挂真 [code]NodeGraphViewport[/code]（真缩放/平移）+ 真
## [code]Viewport.push_input[/code]，断言终点落在 mock 系统的递交记录上。[br]
## [br]来源: 真机走查记录 [code]run_out_pt4_f.txt[/code]（[code]node-click[/code] /
## [code]node-hit-geom[/code]）、ADR-0031 §4（可见性与可点性同源）、
## exploration-ui Story 001 AC-2/AC-10。

const ViewportScript := preload("res://src/ui/exploration/node_graph_viewport.gd")
const InteractorScript := preload("res://src/ui/exploration/node_move_interactor.gd")
const DATA_STUB := preload("res://src/ui/exploration/node_graph_data_stub.gd")
const MockSystem := preload("res://tests/integration/exploration_ui/mocks/mock_exploration_system.gd")

## 宿主尺寸——与真机走查同一量级（1920×1080，视口占满）。
const HOST_SIZE: Vector2 = Vector2(1920.0, 1080.0)

## 缺陷节点：stub 第 1 层有 2 格，[code]idx = 1[/code] 的那格局部 x = 45 - 90 = -45。
const BUGGY_NODE: int = 102
## 该格的起始节点（stub graph 里 0 → [101, 102]）。
const CURRENT_NODE: int = 0

## 拾取区域之外的一点（用于断言「扩出去的不是整张画布」）。
const OUTSIDE_POINT: Vector2 = Vector2(-400.0, -400.0)

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
# 一、真实点击必须落到节点上（本轮缺陷的现场）
# ═══════════════════════════════════════════════════════════════════════════════

## 局部坐标为负的节点，经真实左键投递也要提交移动。[br]
## [b]改前红[/b]：事件被父级视口吃掉，[code]move_calls[/code] 为空。
func test_click_node_at_negative_local_x_submits_move() -> void:
	# Arrange
	var renderer: Control = vp.get(&"renderer") as Control
	var world: Vector2 = renderer.call(&"get_node_position", BUGGY_NODE) as Vector2
	assert_lt(world.x, 0.0,
			"前置：本用例的节点应落在渲染器矩形左缘之外（缺陷现场）")
	assert_eq(int(renderer.call(&"hit_test_any", world)), BUGGY_NODE,
			"前置：渲染器自检应命中该节点（画得出来）")
	mock.move_result = {"success": true, "reason": "", "ap_remaining": 2}
	# Act
	_click_canvas(renderer.get_global_transform_with_canvas() * world)
	# Assert
	assert_eq(mock.move_calls, [[CURRENT_NODE, BUGGY_NODE]],
			"画得出来的节点也必须点得到（引擎拾取不得把它判在控件之外）")


## 对照：局部坐标为正的节点一直点得动——证明上面的红不是「压根没投对坐标」。
func test_click_node_at_positive_local_x_submits_move() -> void:
	# Arrange
	var renderer: Control = vp.get(&"renderer") as Control
	var world: Vector2 = renderer.call(&"get_node_position", 101) as Vector2
	assert_gt(world.x, 0.0, "前置：对照节点应落在渲染器矩形内")
	mock.move_result = {"success": true, "reason": "", "ap_remaining": 2}
	# Act
	_click_canvas(renderer.get_global_transform_with_canvas() * world)
	# Assert
	assert_eq(mock.move_calls, [[CURRENT_NODE, 101]], "矩形内的节点应点得动")


# ═══════════════════════════════════════════════════════════════════════════════
# 二、拾取区域 = 绘制内容区域（同源，不再依赖节点恰好落在原点的象限）
# ═══════════════════════════════════════════════════════════════════════════════

## 节点中心一律在拾取区域内；内容区域之外不吃事件（画布平移仍归视口）。[br]
## [b]改前红[/b]：渲染器不声明 [code]_has_point[/code]，负局部坐标处恒为 false。[br]
## [br][b]为什么边界点取 [constant OUTSIDE_POINT][/b]：拾取区域是「自身矩形 ∪ 内容
## 包围盒」——本图内容包围盒 x ∈ [-138, 138]、y ∈ [-48, 598]（实测），自身矩形是
## (0,0,1920,1080)，故并集左侧到 -138、上方到 -48；[code](-400, -400)[/code] 落在
## 并集之外，正是「扩出去的只有内容那一块，不是整张画布」的判据。
func test_pick_region_covers_drawn_content() -> void:
	# Arrange
	var renderer: Control = vp.get(&"renderer") as Control
	var all_inside: bool = true
	for node_id: int in (DATA_STUB.stub_node_details() as Dictionary).keys():
		var world: Vector2 = renderer.call(&"get_node_position", node_id) as Vector2
		if not bool(renderer.call(&"_has_point", world)):
			all_inside = false
	assert_true(all_inside, "全部节点中心都应落在拾取区域内（画得到=点得到）")
	# Assert：并集之外不吃——否则等于把无限画布认成自己的
	assert_false(bool(renderer.call(&"_has_point", OUTSIDE_POINT)),
			"拾取区域之外不应由渲染器认领")


# ═══════════════════════════════════════════════════════════════════════════════
# 装置：真实输入投递
# ═══════════════════════════════════════════════════════════════════════════════

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
