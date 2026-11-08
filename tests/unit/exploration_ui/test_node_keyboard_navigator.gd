extends GutTest
## exploration-ui S17-005 单元测试：键盘焦点空间跳转纯函数。[br]
##
## Story 类型 Integration——本文件为交互层键盘路径（AC-9）的 Logic 内核证据；
## 集成路径在 `test_node_move_interaction.gd::test_keyboard_navigate_and_confirm_moves`。
## 纯函数无外部依赖：节点表 + 可达判定 Callable 注入。
##
## 来源: story-005-node-move-interaction.md AC-9、node_keyboard_navigator.gd、
## S17-005 代码审查 H3/M9（键盘寻路拆为可单测纯函数）。

const Navigator := preload("res://src/ui/exploration/node_keyboard_navigator.gd")

## 三节点表：0（层0）、101（层1）、102（层1 右侧）。
var _nodes: Dictionary = {}


func before_each() -> void:
	_nodes = {
		0: {"layer": 0, "idx": 0},
		101: {"layer": 1, "idx": 0},
		102: {"layer": 1, "idx": 1},
	}


func _all_reachable(_node_id: int) -> bool:
	return true


func test_down_from_entry_selects_next_layer() -> void:
	# Arrange: 全部可达
	# Act
	var target: int = Navigator.find_target(Vector2i(0, 1), 0, _nodes, _all_reachable)
	# Assert: 下一层最近节点（索引差 0 优先）
	assert_eq(target, 101, "↓ 应选中层差最小的下一层节点")


func test_right_selects_same_layer_neighbor() -> void:
	# Arrange: 从 101 向右
	# Act
	var target: int = Navigator.find_target(Vector2i(1, 0), 101, _nodes, _all_reachable)
	# Assert
	assert_eq(target, 102, "→ 应选中同层右侧相邻节点")


func test_left_at_leftmost_returns_minus_one() -> void:
	# Arrange: 101 已是同层最左
	# Act
	var target: int = Navigator.find_target(Vector2i(-1, 0), 101, _nodes, _all_reachable)
	# Assert
	assert_eq(target, -1, "同层最左再按 ← 应无候选")


func test_unreachable_nodes_skipped() -> void:
	# Arrange: 仅 102 可达——101 不可达
	var only_102 := func(node_id: int) -> bool: return node_id == 102
	# Act
	var target: int = Navigator.find_target(Vector2i(0, 1), 0, _nodes, only_102)
	# Assert: 跳过不可达的 101，选中同层可达的 102
	assert_eq(target, 102, "不可达节点不应成为键盘候选")


func test_no_reachable_candidate_returns_minus_one() -> void:
	# Arrange: 无任何可达节点
	var none := func(_node_id: int) -> bool: return false
	# Act
	var target: int = Navigator.find_target(Vector2i(0, 1), 0, _nodes, none)
	# Assert
	assert_eq(target, -1, "无可达候选应返回 -1（焦点保持原地）")


func test_unknown_origin_returns_minus_one() -> void:
	# Arrange: 起点不在节点表内
	# Act
	var target: int = Navigator.find_target(Vector2i(0, 1), 999, _nodes, _all_reachable)
	# Assert
	assert_eq(target, -1, "未知起点不应抛错，返回 -1")


func test_zero_direction_returns_minus_one() -> void:
	# Arrange: 零向量（无效方向）
	# Act
	var target: int = Navigator.find_target(Vector2i.ZERO, 0, _nodes, _all_reachable)
	# Assert
	assert_eq(target, -1, "零向量方向不应匹配任何节点")
