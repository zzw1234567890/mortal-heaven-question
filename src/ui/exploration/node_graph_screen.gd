class_name NodeGraphScreen
extends Control
## NodeGraphScreen —— 节点图主界面（exploration-ui Story S16-3）。
##
## [b]节点形态[/b]（ADR-0031 §1）：场景内 Control 树（零新增 Autoload），由
## [code]ExplorationScene[/code] 薄容器挂载（进入地图后替代/叠加于 MapSelectScreen）。[br]
## [br][b]结构[/b]：NodeGraphViewport（缩放平移容器）承载 NodeGraphRenderer（渲染
## 基座）+ 右上角行动力标签 + 返回按钮。[br]
## [br][b]信号驱动路径[/b]（stub 先行，2026-10-26 裁决）：[method _on_map_generated]
## 消费 [signal map_generated]——遍历 map_data.nodes/graph 构建节点控件快照 →
## 六态经 [NodeStateLogic.classify_node_state] 纯函数判定 → 样式经
## [NodeStateLogic.node_state_style] 渲染（注入 renderer.set_states）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：[code]_current_snapshot[/code] 为渲染
## 输入快照（瞬态交互状态，不进存档）；节点状态每次信号周期从系统 API/信号载荷
## 重读。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]——逐层展开动画（0.8s）经 Tween
## 驱动 renderer.reveal_max_layer（Tween 完成即停，非 _process 常驻）。[br]
## [br][b]迷雾消散[/b]（0.3s）：node_moved 信号触发后重算六态并 queue_redraw——
## 迷雾状态判定归探索系统（stub 阶段以 stub 迷雾揭示集合近似）；消散动画时序归
## 手动证据（AC-2/AC-3）。
##
## 来源: story-003-node-graph-data-states.md、ADR-0031 §2/§3、
## ADR-0014 §决策 3（map_generated/node_moved 信号）、story-001 基座。

## === 依赖（测试可替换）======================================================

## 探索系统引用——map_generated/node_moved 信号源（null 时回退 stub 发射器）。
var exploration_system: Node = null
## 动画开关——测试注入（S16-1 先例）；false 时跳过逐层展开动画直接全显。
var animate: bool = true

## === 场景常量 ==============================================================

const MapGeneratedStubScript := preload("res://src/ui/exploration/map_generated_stub.gd")
## NodeStateLogic 脚本常量——六态分类器（class_name 在 headless 动态加载下
## 不可靠，preload 脚本常量——S16-1/2 先例）。
const NodeStateLogicScript := preload("res://src/ui/exploration/node_state_logic.gd")

## 逐层展开浮现动画总时长（秒）——AC-1「逐层从入口向 Boss 展开浮现（0.8s）」。
const REVEAL_DURATION: float = 0.8

## 固定 UI 词条（项目暂无本地化系统——S16-1 TEXT_* 同源豁免注记）。
const TEXT_AP_PREFIX: String = "AP"

## === 信号 ==================================================================

## 返回地图选择意图——[param back_button] 点击后发出（场景编排归探索系统）。
signal back_to_map_select_requested

## === 节点引用 ==============================================================

@onready var viewport: NodeGraphViewport = $NodeGraphViewport
@onready var ap_label: Label = $TopBar/APLabel
@onready var back_button: Button = $TopBar/BackButton

## === 瞬态渲染状态（ADR-0031 §2.1 瞬态交互状态）============================

## 当前渲染快照（graph/nodes/visited/current_node/ap_remaining）——node_moved
## 后重算六态用；不进存档。
var _current_snapshot: Dictionary = {}
## stub 信号发射器实例（Feature 层补齐后删除）。
var _stub_emitter: Node = null
## 逐层展开 Tween 句柄（重入时 kill 防悬挂）。
var _reveal_tween: Tween = null


func _ready() -> void:
	_connect_signals()
	# stub 先行：无 [code]map_generated[/code] 信号源时建立 stub 发射器（不立即
	# 发射——由宿主进入地图时调用 [method trigger_map_load]；Feature 层
	# [code]map_generated[/code] 落盘后删除本分支）。[br]
	# [b]判定依据[/b]：信号源是否存在（而非 Autoload 是否存在）——当前项目
	# ExplorationSystem 已注册 Autoload 但未声明 map_generated 信号，仅判
	# Autoload 存在会导致 stub 永不建立、节点图空白（B-1）。
	var es: Node = _get_exploration_system()
	if es == null or not es.has_signal(&"map_generated"):
		_stub_emitter = MapGeneratedStubScript.new()
		add_child(_stub_emitter)
		_stub_emitter.map_generated.connect(_on_map_generated)
	back_button.pressed.connect(_on_back_pressed)


## 触发地图加载——真实源（es）已连 map_generated 时无操作（enter_map 会发射）；
## stub 源时发射 stub map_generated 驱动节点图构建。
func trigger_map_load() -> void:
	if _stub_emitter != null:
		_stub_emitter.emit_map_generated()


func _exit_tree() -> void:
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()


## 连接探索系统信号——map_generated / node_moved（事件驱动，无轮询）。
func _connect_signals() -> void:
	var es: Node = _get_exploration_system()
	if es == null:
		return
	if es.has_signal(&"map_generated"):
		es.map_generated.connect(_on_map_generated)
	if es.has_signal(&"node_moved"):
		es.node_moved.connect(_on_node_moved)


## === map_generated 消费（信号驱动构建路径——AC-1）==========================

## map_generated 信号处理——构建节点图 + 六态渲染 + 逐层展开动画。[br]
## [b]替换 story-001 的 [code]setup()[/code] 直连为信号驱动路径[/b]：Feature 层
## [code]map_generated[/code] 落盘后仅替换信号源、不改本方法渲染路径。
func _on_map_generated(_map_id: StringName, map_data: Dictionary) -> void:
	_current_snapshot = map_data
	renderer().setup(
			map_data.get("graph", {}),
			map_data.get("nodes", {}),
			map_data.get("visited", []),
			int(map_data.get("current_node", -1)))
	_refresh_ap_label(map_data)
	_recompute_states(map_data)
	if animate:
		_play_reveal_animation()
	else:
		renderer().reveal_max_layer = _max_layer(map_data.get("nodes", {}))


## node_moved 信号处理——迷雾消散（0.3s）+ 状态翻转重算（AC-2/AC-6）。
func _on_node_moved(_from_node: int, to_node: int, ap_remaining: int) -> void:
	if _current_snapshot.is_empty():
		return
	var visited: Array = (_current_snapshot.get("visited", []) as Array).duplicate()
	if not visited.has(to_node):
		visited.append(to_node)
	_current_snapshot["visited"] = visited
	_current_snapshot["current_node"] = to_node
	_current_snapshot["ap_remaining"] = ap_remaining
	renderer().setup(
			_current_snapshot.get("graph", {}),
			_current_snapshot.get("nodes", {}),
			visited,
			to_node)
	_refresh_ap_label(_current_snapshot)
	_recompute_states(_current_snapshot)


## === 六态判定（消费 NodeStateLogic 纯函数——Logic 内核）====================

## 重算六态并注入 renderer——每个节点经 [NodeStateLogic.classify_node_state]
## 判定后写入 states 映射。
func _recompute_states(snapshot: Dictionary) -> void:
	var graph: Dictionary = snapshot.get("graph", {})
	var nodes: Dictionary = snapshot.get("nodes", {})
	var visited: Array = snapshot.get("visited", [])
	var current_node: int = int(snapshot.get("current_node", -1))
	var ap_remaining: int = int(snapshot.get("ap_remaining", 0))
	var state_map: Dictionary = {}
	for node_id: int in nodes.keys():
		state_map[node_id] = NodeStateLogicScript.classify_node_state(
				node_id, graph, visited, current_node, ap_remaining, nodes)
	renderer().set_states(state_map)


## === 动画（时序归手动证据——AC-3 走查）====================================

## 逐层展开浮现（0.8s）——reveal_max_layer 从 -1 递增到最大层。[br]
## [b]动画时序不纳入集成测试自动化断言[/b]（Integration 类型正常边界），由
## QA Test Cases AC-3 手动走查覆盖。
func _play_reveal_animation() -> void:
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
	var max_layer: int = _max_layer(_current_snapshot.get("nodes", {}))
	renderer().reveal_max_layer = -1
	_reveal_tween = create_tween()
	_reveal_tween.tween_method(_reveal_step.bind(max_layer), 0.0, 1.0, REVEAL_DURATION)


## 展开步进——[code]reveal_max_layer = round(t * max_layer)[/code]（逐层浮现）。
func _reveal_step(t: float, max_layer: int) -> void:
	renderer().reveal_max_layer = int(round(t * float(max_layer)))
	renderer().queue_redraw()


## === 内部辅助 ==============================================================

## 渲染器引用——viewport 的内容宿主（[NodeGraphViewport.renderer]）。
func renderer() -> NodeGraphRenderer:
	return viewport.renderer


## 刷新行动力标签（右上角 AP 显示；数据源 = 快照 ap_remaining）。
func _refresh_ap_label(snapshot: Dictionary) -> void:
	ap_label.text = "%s: %d" % [TEXT_AP_PREFIX, int(snapshot.get("ap_remaining", 0))]


## 最大层索引（-1 = 空）。
func _max_layer(nodes: Dictionary) -> int:
	var max_layer: int = -1
	for node_id: int in nodes.keys():
		max_layer = maxi(max_layer, int(nodes[node_id].get("layer", 0)))
	return max_layer


## 获取探索系统——注入对象优先，否则回退 Autoload。
func _get_exploration_system() -> Node:
	if exploration_system != null:
		return exploration_system
	return get_node_or_null("/root/ExplorationSystem")


func _on_back_pressed() -> void:
	back_to_map_select_requested.emit()
