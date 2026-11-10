extends RefCounted
## NodeGraphRevealAnimator —— 节点图「六态重算 + 逐层展开」的渲染辅助（从
## NodeGraphScreen 拆出）。[br]
## [br][b]为什么单独一处[/b]：屏幕脚本已贴近 300 行软上限；「快照 → 六态映射」
## 与「逐层浮现的 Tween 编排」是纯渲染职责，与信号接线/交互挂载互相独立。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本模块不改游戏状态——六态映射是纯函数
## 判定结果，reveal_max_layer 是渲染参数。[br]
## [br][b]零轮询[/b]：不使用 [code]_process()[/code]——逐层展开走 Tween，
## 完成即停（停靠宿主提供的 Tween 宿主节点）。[br]
## [br]来源: story-003-node-graph-data-states.md AC-1/AC-3、ADR-0031 §2/§5。

## NodeStateLogic 脚本常量——六态分类器（class_name 在 headless 动态加载下不可靠）。
const NodeStateLogicScript := preload("res://src/ui/exploration/node_state_logic.gd")

## 逐层展开浮现动画总时长（秒）——AC-1「逐层从入口向 Boss 展开浮现（0.8s）」。
const REVEAL_DURATION: float = 0.8

## 当前 Tween 句柄（重入时 kill 防悬挂）。
var _tween: Tween = null


## 重算六态并注入渲染器——每个节点经 [NodeStateLogic.classify_node_state] 判定。[br]
## [br][param p_renderer] 渲染器（消费 [code]set_states[/code]）。[br]
## [param p_snapshot] 渲染快照（graph / nodes / visited / current_node / ap_remaining）。[br]
func recompute_states(p_renderer: Control, p_snapshot: Dictionary) -> void:
	var graph: Dictionary = p_snapshot.get("graph", {})
	var nodes: Dictionary = p_snapshot.get("nodes", {})
	var visited: Array = p_snapshot.get("visited", [])
	var current_node: int = int(p_snapshot.get("current_node", -1))
	var ap_remaining: int = int(p_snapshot.get("ap_remaining", 0))
	var state_map: Dictionary = {}
	for node_id: int in nodes.keys():
		state_map[node_id] = NodeStateLogicScript.classify_node_state(
				node_id, graph, visited, current_node, ap_remaining, nodes)
	p_renderer.call(&"set_states", state_map)


## 逐层展开浮现（0.8s）——reveal_max_layer 从 -1 递增到最大层。[br]
## [br][b]动画时序不纳入集成测试自动化断言[/b]（Integration 正常边界），由
## QA Test Cases AC-3 手动走查覆盖。[br]
## [br][param p_tween_host] 提供 [code]create_tween()[/code] 的节点（屏幕自身）。[br]
## [param p_renderer] 渲染器（写 [code]reveal_max_layer[/code]）。[br]
## [param p_nodes] 节点详情（算最大层）。
func play_reveal(p_tween_host: Node, p_renderer: Control, p_nodes: Dictionary) -> void:
	kill()
	var max_layer: int = max_layer_of(p_nodes)
	p_renderer.set(&"reveal_max_layer", -1)
	_tween = p_tween_host.create_tween()
	_tween.tween_method(func(t: float) -> void:
		p_renderer.set(&"reveal_max_layer", int(round(t * float(max_layer))))
		p_renderer.call(&"queue_redraw"), 0.0, 1.0, REVEAL_DURATION)


## 跳过动画——直接全显（animate=false 的测试/无动画偏好路径）。
func reveal_all(p_renderer: Control, p_nodes: Dictionary) -> void:
	kill()
	p_renderer.set(&"reveal_max_layer", max_layer_of(p_nodes))


## 杀掉进行中的展开 Tween（重入 / 退出树时调用——防悬挂回调）。
func kill() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


## 最大层索引（-1 = 空）。
func max_layer_of(p_nodes: Dictionary) -> int:
	var max_layer: int = -1
	for node_id: int in p_nodes.keys():
		max_layer = maxi(max_layer, int((p_nodes[node_id] as Dictionary).get("layer", 0)))
	return max_layer
