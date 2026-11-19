extends GutTest
## 缺口二（可玩性收尾）集成测试：节点图渲染层与纯函数判定同源。
##
## [b]覆盖[/b]：渲染器 [code]_is_edge_visited[/code] 转发
## [code]NodeStateLogic.edge_is_walked[/code]（判定只有一处，渲染层不得重写）；
## 已访问节点在渲染器持有的 [code]states[/code] 里确实是
## [code]NodeState.VISITED[/code]，其样式带实色底衬。[br]
## [br][b]为什么不截图[/b]：本轮锁的是「渲染层用的是哪一套判定」——颜色画出来长
## 什么样归手动走查（[code]_draw_node_stated[/code] 读的正是这一份样式）。[br]
##
## 来源: 本轮任务书缺口二、ADR-0031 §2、story-003-node-graph-data-states.md。

const NodeGraphScreenScene: PackedScene = preload("res://src/ui/exploration/node_graph_screen.tscn")
const NODE_LOGIC := preload("res://src/ui/exploration/node_state_logic.gd")
const DATA_STUB := preload("res://src/ui/exploration/node_graph_data_stub.gd")

var screen: Control = null


func before_each() -> void:
	screen = NodeGraphScreenScene.instantiate()
	screen.animate = false
	add_child_autofree(screen)
	screen._on_map_generated(&"qing_yun_jian_zong", DATA_STUB.stub_snapshot())


func renderer() -> NodeGraphRenderer:
	return screen.get("viewport").renderer


## 渲染器的连线判定 = 纯函数判定（逐对取样——两套实现会在某一对上分叉）。
func test_renderer_edge_judgment_matches_pure_function() -> void:
	# Arrange
	var r: NodeGraphRenderer = renderer()
	var visited: Array = [0, 101, 201]
	r.visited = visited
	var pairs: Array = [[0, 101], [0, 201], [101, 201], [101, 301]]
	# Act + Assert
	for pair: Array in pairs:
		assert_eq(r._is_edge_visited(pair[0], pair[1]),
				NODE_LOGIC.edge_is_walked(visited, pair[0], pair[1]),
				"连线 %d-%d 的判定应在渲染层与纯函数间一致" % [pair[0], pair[1]])


## 已访问节点在渲染快照里是 VISITED 态，且拿到的样式带实色底衬。
func test_visited_node_state_style_has_solid_plate() -> void:
	# Arrange —— 走一步：入口 → 101（node_moved 驱动快照更新）
	screen._on_node_moved(0, 101, 2)
	var r: NodeGraphRenderer = renderer()
	assert_true(r.visited.has(0), "入口应记为已访问")
	assert_eq(int(r.states.get(0, -1)), NODE_LOGIC.NodeState.VISITED,
			"走过的入口在渲染快照里应是已访问态")
	# Act
	var style: Dictionary = NODE_LOGIC.node_state_style(int(r.states[0]))
	# Assert
	assert_gt(float(style["plate"].a), 0.6,
			"渲染器读到的已访问样式应带实色底衬（不是只压暗）")
	assert_eq(str(style["marker"]), "check", "已访问节点仍带 ✓ 标记")


## 当前节点在渲染快照里是 CURRENT 态——底衬与已访问不同色（各自有标识）。
func test_current_node_plate_differs_from_visited_in_render() -> void:
	# Arrange
	screen._on_node_moved(0, 101, 2)
	var states: Dictionary = renderer().states
	assert_eq(int(states.get(101, -1)), NODE_LOGIC.NodeState.CURRENT,
			"走到 101 后它应是当前态")
	# Act
	var cur_plate: Color = NODE_LOGIC.node_state_style(
			int(states[101]))["plate"]
	var vis_plate: Color = NODE_LOGIC.node_state_style(
			int(states[0]))["plate"]
	# Assert
	assert_gt(cur_plate.a, 0.6, "当前节点底衬应是实色")
	assert_ne(cur_plate, vis_plate, "当前与已访问底衬必须不同色")
