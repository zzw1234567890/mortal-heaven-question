extends GutTest
## 探索薄容器 —— 玩家选中的地图 ID 必须传到节点图。[br]
## [br][b]本文件补的断链[/b]：`ExplorationScene._on_enter_map_requested` 原先丢弃
## 地图 ID（无参），节点图固定进青云剑宗——「点哪张图都看到同一张 DAG」的第二处
## 根因。[br]
## [br][b]覆盖[/b]：[br]
##   1. 地图选择界面的 `enter_map_requested(map_id)` 携带的 ID 被原样转交；[br]
##   2. 进入后节点图渲染的确实是那张图的 DAG；[br]
##   3. 重复进入意图不重复挂载节点图（防双击生成两张图）。[br]
## [br][b]用真实 Autoload[/b]：容器内的节点图屏幕走 `_get_exploration_system()`，
## 没有注入点——本文件验证的正是生产接线，故断言对象也取 Autoload。
##
## 来源: exploration_scene.gd、story-002/story-003 编排、本轮任务要求。

const SceneScript := preload("res://src/feature/exploration/exploration_scene.gd")
const BootstrapScript := preload("res://src/feature/exploration/exploration_bootstrap.gd")

var gsm: Node = null
var es: Node = null
var scene: Control = null


func before_each() -> void:
	gsm = get_node_or_null(NodePath("/root/GameStateManager"))
	es = get_node_or_null(NodePath("/root/ExplorationSystem"))
	assert_not_null(es, "本文件需要真实 ExplorationSystem Autoload")
	# 生产装配（地图配置 + 敌人池）——与 MainMenu._ready 同一条路径
	BootstrapScript.mount(es, get_node_or_null(NodePath("/root/AISystem")))
	if es.has_method(&"set_rng_seed"):
		es.call("set_rng_seed", 42)
	_reset_gsm()
	scene = SceneScript.new()
	# _ready 会挂地图选择界面（读 GSM / ResourceSystem）——测试走同一条生产路径
	add_child_autofree(scene)


func after_each() -> void:
	_reset_gsm()
	if es != null and es.has_method(&"clear_dag_cache"):
		es.call("clear_dag_cache")


func test_enter_map_request_carries_map_id_to_node_graph() -> void:
	# Act——玩家在卡片上点「丹霞谷」
	scene.call("_on_enter_map_requested", &"dan_xia_gu")
	var screen: Control = scene.get("node_graph_screen")
	# Assert——节点图已挂载，且系统当前地图就是玩家点的那张
	assert_not_null(screen, "进入地图后应挂载节点图界面")
	assert_eq(gsm.exploration.get("current_map"), &"dan_xia_gu",
			"地图 ID 应原样传给探索系统（不是固定青云剑宗）")


func test_enter_map_renders_selected_map_dag() -> void:
	# Act
	scene.call("_on_enter_map_requested", &"xue_yuan_mi_jing")
	var screen: Control = scene.get("node_graph_screen")
	var renderer: Node = screen.get("viewport").renderer
	# Assert——渲染的邻接表 = 系统为血渊秘境生成的图
	assert_eq(renderer.graph, es.get("_node_graph"),
			"节点图应渲染玩家选中的那张地图")


func test_repeated_enter_does_not_mount_twice() -> void:
	# Act——进入动画期间连点两下
	scene.call("_on_enter_map_requested", &"qing_yun_jian_zong")
	var first: Control = scene.get("node_graph_screen")
	scene.call("_on_enter_map_requested", &"dan_xia_gu")
	var second: Control = scene.get("node_graph_screen")
	# Assert——只挂一个节点图（第二下被忽略，不生成第二张图）
	assert_same(first, second, "重复进入意图不应重复挂载节点图")


## 重置 GSM 探索域（enter_map 会写 current_map / visited / ap / map_states）。
func _reset_gsm() -> void:
	if gsm == null:
		return
	gsm.exploration = {
		"current_map": &"",
		"node_position": {"layer": 0, "idx": 0},
		"visited_nodes": [],
		"action_points": 0,
		"max_action_points": 0,
		"map_states": {},
	}
	gsm.set("_signal_chain_depth", 0)
	var router: Variant = gsm.get("_signal_router")
	if router != null:
		router.set("_pending_changes", [])
