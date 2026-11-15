extends RefCounted
## NodeGraphRevealAnimator —— 节点图「六态重算 + 逐层展开」的渲染辅助（从
## NodeGraphScreen 拆出）。[br]
## [br][b]为什么单独一处[/b]：屏幕脚本已贴近 300 行软上限；「快照 → 六态映射」
## 与「逐层浮现的 Tween 编排」是纯渲染职责，与信号接线/交互挂载互相独立。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本模块不改游戏状态——六态映射是纯函数
## 判定结果，reveal_max_layer 是渲染参数。[br]
## [br][b]可达性判定可外接[/b]：[member verdict_provider] 接系统
## [code]can_move_to_detail[/code] 时以系统作答（它才算得出本图 [code]ap_cost[/code]），
## 未接时回落 [NodeStateLogic.verdict_for] 纯函数——两条路是同一套形状与词表。[br]
## [br][b]零轮询[/b]：不使用 [code]_process()[/code]——逐层展开走 Tween，
## 完成即停（停靠宿主提供的 Tween 宿主节点）。[br]
## [br]来源: story-003-node-graph-data-states.md AC-1/AC-3、ADR-0031 §2/§5。

## NodeStateLogic 脚本常量——六态分类器（class_name 在 headless 动态加载下不可靠）。
const NodeStateLogicScript := preload("res://src/ui/exploration/node_state_logic.gd")

## 逐层展开浮现动画总时长（秒）——AC-1「逐层从入口向 Boss 展开浮现（0.8s）」。
const REVEAL_DURATION: float = 0.8

## 当前 Tween 句柄（重入时 kill 防悬挂）。
var _tween: Tween = null

## 可达性判定的外部答主（可选）——接 [code]ExplorationSystem.can_move_to_detail[/code]，
## 签名 [code](from_node, to_node) -> {ok, reason}[/code]。[br]
## [br][b]为什么可以接外部判定[/b]：真实系统才算得出本图的 [code]ap_cost[/code]
## （渲染快照里没有地图配置），也可能有快照之外的规则；由它作答比 UI 再推导一遍
## 更接近玩家点击时会发生的事。[br]
## [br][b]无效时回落自算[/b]：[NodeStateLogic.verdict_for]（纯函数，同形状同词表）
## ——stub 快照、headless、系统未就绪等路径不受影响。[br]
## [br][b]只在不一致时才分流[/b]：两者对同一格给出不同结论时以外部判定为准，
## 这正是接线它的目的。
var verdict_provider: Callable = Callable()


## 重算六态并注入渲染器——每个节点经 [NodeStateLogic.classify_node_state] 判定，
## 有外部答主时可达性那一格改问它（见 [member verdict_provider]）。[br]
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
		state_map[node_id] = NodeStateLogicScript.classify_with_verdict(
				node_id, graph, visited, current_node,
				_verdict_of(current_node, node_id, graph, visited, ap_remaining, nodes))
	p_renderer.call(&"set_states", state_map)


## 一格的可达性判定——外部答主优先（返回形状不符时回落自算，不把 UI 拖进错误态）。
func _verdict_of(p_from: int, p_to: int, p_graph: Dictionary, p_visited: Array,
		p_ap: int, p_nodes: Dictionary) -> Dictionary:
	if verdict_provider.is_valid():
		var external: Variant = verdict_provider.call(p_from, p_to)
		if external is Dictionary and (external as Dictionary).has("ok"):
			return external
	return NodeStateLogicScript.verdict_for(p_from, p_to, p_graph, p_visited,
			p_ap, p_nodes)


## 装配可达性判定的来源。[br]
## [br][b]只在快照真的出自系统时才接[/b]（[param p_from_system] 来自
## [code]NodeGraphLoadSource.from_system[/code]）：系统在场不等于眼前这份快照出自
## 它——stub 降级与测试直调快照时系统照样在场，此时拿系统缓存里那张无关的 DAG 去
## 判定，会把节点画成一片不可达。标记为假时清空答主、回落纯函数自算。[br]
## [br][param p_system] 探索系统（可为 null）。[br]
## [param p_from_system] 当前快照是否由系统的 [code]enter_map[/code] 产出。
func bind_verdict_provider(p_system: Node, p_from_system: bool) -> void:
	if p_from_system and p_system != null and p_system.has_method(&"can_move_to_detail"):
		verdict_provider = Callable(p_system, &"can_move_to_detail")
		return
	verdict_provider = Callable()


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
