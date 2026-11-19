extends GutTest
## 缺口二（可玩性收尾）单元测试：走过的节点与连线在图上看得出来。
##
## [b]覆盖[/b]：六态样式里的 [code]plate[/code] 底衬（实色块——不靠透明度区分）与
## [code]edge_is_walked[/code] 连线判定（判定只有一处）。[br]
## [br][b]为什么单独一个文件[/b]：[code]test_node_state_logic.gd[/code] 已 300 行，
## 且那里锁的是「六态分类」这条主链；本文件锁的是本轮补的「走过/没走过怎么读出来」。[br]
## [br][b]断言口径[/b]：读纯函数返回的规格——渲染器画的正是这一份（转发关系在
## 集成测试 [code]test_node_graph_render.gd[/code] 里锁）。[br]
##
## 来源: 本轮任务书缺口二、design/gdd/exploration-ui-system.md §2 界面规则表。

const NODE_LOGIC := preload("res://src/ui/exploration/node_state_logic.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 已走过 / 当前节点有实色底衬——不是只靠透明度压暗
# ═══════════════════════════════════════════════════════════════════════════════

## 已访问节点：底衬是实色（alpha 高到画出来就是一块颜色），且与未访问节点不同。
func test_visited_node_has_solid_plate() -> void:
	# Act
	var visited: Dictionary = NODE_LOGIC.node_state_style(NODE_LOGIC.NodeState.VISITED)
	var plate: Color = visited["plate"]
	# Assert
	assert_gt(plate.a, 0.6, "已访问底衬应足够实（不是轻微压暗）")
	assert_gt(plate.r + plate.g + plate.b, 0.0, "底衬不能是纯黑（读不出颜色）")


## 当前节点：底衬与已访问[b]不同色[/b]——当前所在处有自己的标识，不是跟着走过的一起变绿。
func test_current_plate_differs_from_visited_plate() -> void:
	# Act
	var cur: Color = NODE_LOGIC.node_state_style(NODE_LOGIC.NodeState.CURRENT)["plate"]
	var vis: Color = NODE_LOGIC.node_state_style(NODE_LOGIC.NodeState.VISITED)["plate"]
	# Assert
	assert_gt(cur.a, 0.6, "当前节点底衬也应是实色")
	assert_ne(cur, vis, "当前节点与已访问节点底衬必须不同色（各有各的标识）")


## 没走过的三种态（可达 / 不可达 / 行动力不足）与迷雾：不画底衬。
func test_unwalked_states_have_no_plate() -> void:
	for state: int in [NODE_LOGIC.NodeState.REACHABLE,
			NODE_LOGIC.NodeState.UNREACHABLE,
			NODE_LOGIC.NodeState.AP_INSUFFICIENT,
			NODE_LOGIC.NodeState.FOGGED]:
		var style: Dictionary = NODE_LOGIC.node_state_style(state)
		assert_eq(float(style["plate"].a), 0.0,
				"状态 %d 不应有底衬（类型色边框本身就是信息）" % state)


## 每种状态的样式字典都带 plate 键——渲染层 `.get("plate", TRANSPARENT)` 不会漏画。
func test_every_state_exposes_plate_key() -> void:
	for state: int in [NODE_LOGIC.NodeState.CURRENT, NODE_LOGIC.NodeState.REACHABLE,
			NODE_LOGIC.NodeState.VISITED, NODE_LOGIC.NodeState.UNREACHABLE,
			NODE_LOGIC.NodeState.AP_INSUFFICIENT, NODE_LOGIC.NodeState.FOGGED]:
		var style: Dictionary = NODE_LOGIC.node_state_style(state)
		assert_true(style.has("plate"), "状态 %d 的样式应含 plate 键" % state)


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 连线「走过」判定——与节点六态同源，不与渲染层各判一套
# ═══════════════════════════════════════════════════════════════════════════════

## 两端都走过 → 走过；只要有一端没走过 → 没走过。
func test_edge_is_walked_requires_both_ends() -> void:
	assert_true(NODE_LOGIC.edge_is_walked([0, 101, 201], 0, 101),
			"两端都已访问 → 走过的路")
	assert_false(NODE_LOGIC.edge_is_walked([0, 101], 101, 201),
			"一端未访问 → 没走过的路")
	assert_false(NODE_LOGIC.edge_is_walked([0, 101], 0, 999),
			"目标节点不在 visited 里 → 没走过")


## 判定与方向无关（无向图——谁先谁后都一样）。
func test_edge_is_walked_is_direction_agnostic() -> void:
	var visited: Array = [0, 101]
	assert_eq(NODE_LOGIC.edge_is_walked(visited, 0, 101),
			NODE_LOGIC.edge_is_walked(visited, 101, 0),
			"同一条连线换个方向问，答案必须一样")


## 空 visited（刚进图）时任何连线都没走过。
func test_edge_is_walked_empty_visited_is_never_walked() -> void:
	assert_false(NODE_LOGIC.edge_is_walked([], 0, 101), "空 visited 不应判出走过的路")
