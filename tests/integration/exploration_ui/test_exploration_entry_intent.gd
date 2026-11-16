extends GutTest
## 探索薄容器「本次进入意图」的验收：新开局直落第一张图 / 读档续玩回上次那张图。[br]
## [br][b]本文件补的断路[/b]：探索场景是三条路径的共同终点，而它挂载那一刻无从分辨
## 自己是被谁叫来的——此前无论从哪条路进来，玩家都停在选图界面，得再点一次地图卡
## 才看到节点图（新开局因此多两跳，读档则完全回不到上次那张图）。[br]
## [br][b]覆盖[/b]：[br]
##   1. FIRST_MAP：直接挂节点图并进第一张图（探明表首项，不硬编码 ID）；[br]
##   2. RESUME：按 GSM 的 [code]current_map[/code] 回到存档里那张图，且
##      [b]不重新生成[/b]（图与已访问节点取自存档快照）；[br]
##   3. RESUME 但存档里没有进行中的图 → 停在选图界面（不臆造一张图）；[br]
##   4. 无意图（从暂停菜单等路径回来）→ 维持现状，不自动进图；[br]
##   5. 意图取走即清——同一份意图不会让玩家进两次图。[br]
## [br][b]用真实 Autoload[/b]：容器内的节点图屏幕走 [code]_get_exploration_system()[/code]，
## 没有注入点——本文件验证的正是生产接线。[br]
##
## 来源: exploration_scene.gd、exploration_entry_intent.gd、
## design/gdd/exploration-system.md §1（探明表顺序 = 剧情顺序）、
## design/gdd/main-menu-system.md（三条路径）。

const SceneScript := preload("res://src/feature/exploration/exploration_scene.gd")
const BootstrapScript := preload("res://src/feature/exploration/exploration_bootstrap.gd")
const IntentScript := preload("res://src/feature/exploration/exploration_entry_intent.gd")

## 用例地图（探明表里青云剑宗为炼气期地图）。
const MAP_ID: StringName = &"qing_yun_jian_zong"

var gsm: Node = null
var es: Node = null
var scene: Control = null


func before_each() -> void:
	gsm = get_node_or_null(NodePath("/root/GameStateManager"))
	es = get_node_or_null(NodePath("/root/ExplorationSystem"))
	assert_not_null(es, "本文件需要真实 ExplorationSystem Autoload")
	BootstrapScript.mount(es, get_node_or_null(NodePath("/root/AISystem")))
	if es.has_method(&"set_rng_seed"):
		es.call("set_rng_seed", 42)
	IntentScript.clear()
	_reset_gsm()


func after_each() -> void:
	IntentScript.clear()
	_reset_gsm()
	if es != null and es.has_method(&"clear_dag_cache"):
		es.call("clear_dag_cache")
	if scene != null and is_instance_valid(scene):
		scene.free()
	scene = null


## 挂载薄容器（[code]_ready[/code] 里消费意图）。
func _mount() -> Control:
	scene = SceneScript.new()
	add_child(scene)
	return scene


## 进一张真实的图并把「玩过一阵」的导航状态写进 GSM。[br]
## [br]用真实的 [code]enter_map[/code]（含 map_states 快照写入），再模拟玩家走了
## 两步——这样「续玩」要恢复的东西（图 / 走过的路 / 剩余行动力）全是真的。
func _play_map() -> Dictionary:
	var map_data: Dictionary = es.call(&"enter_map", MAP_ID, 1, 10)
	var graph: Dictionary = map_data.get("graph", {})
	var children: Array = graph.get(0, [])
	assert_false(children.is_empty(), "前置：入口节点应有后继（图才走得动）")
	var first: int = int(children[0])
	gsm.add_visited_node(first)
	gsm.set_exploration_position(first / 100, first % 100)
	gsm.set_exploration_ap(4, 10)
	return map_data


## 重置 GSM 探索域与跨场景静态缓存（enter_map 会写 current_map / visited / ap）。
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


# ═══════════════════════════════════════════════════════════════════════════════
# 意图模块本身
# ═══════════════════════════════════════════════════════════════════════════════

func test_intent_take_clears_so_it_fires_once() -> void:
	# Arrange
	IntentScript.request_new_run()
	# Act + Assert
	assert_eq(IntentScript.take_entry_mode(), IntentScript.EntryMode.FIRST_MAP,
			"新开局请求应留下 FIRST_MAP 意图")
	assert_eq(IntentScript.take_entry_mode(), IntentScript.EntryMode.NONE,
			"取走即清——同一份意图不会让玩家进两次图")
	assert_false(IntentScript.has_pending(), "取走后不应还有待消费意图")


func test_first_map_id_follows_catalog_order_not_hardcoded() -> void:
	## 第一张图不在意图模块里硬编码——新增 / 重排地图只改探明表，这里自动跟随。
	# Arrange
	var Catalog := preload("res://src/feature/exploration/exploration_map_catalog.gd")
	var ids: Array = Catalog.MAPS.keys()
	# Act
	var first: StringName = IntentScript.first_map_id()
	# Assert
	assert_eq(first, StringName(str(ids[0])), "第一张图应为探明表首项（表序即剧情序）")
	assert_eq(first, MAP_ID, "本轮探明表首项即青云剑宗（新开局的落点）")


# ═══════════════════════════════════════════════════════════════════════════════
# 新开局：直接进第一张图
# ═══════════════════════════════════════════════════════════════════════════════

func test_first_map_intent_enters_first_map_without_map_card_click() -> void:
	# Arrange——身份选择侧已留下「新开局」意图
	IntentScript.request_new_run()
	# Act——挂载薄容器（_ready 消费意图）
	var mounted: Control = _mount()
	# Assert——节点图直接挂上，系统当前地图即第一张图
	assert_not_null(mounted.get("node_graph_screen"),
			"新开局应直接挂载节点图（不必玩家再点一次地图卡）")
	assert_eq(gsm.exploration.get("current_map"), MAP_ID,
			"新开局的落点应为探明表首项（青云剑宗）")
	assert_false(IntentScript.has_pending(), "意图应已被消费（不会残留到下一次进入）")


func test_consume_returns_none_when_no_intent() -> void:
	## 从暂停菜单 / 占位场景回来的路径没有意图——不该被自动拽进图里。
	# Act
	var mounted: Control = _mount()
	# Assert
	assert_null(mounted.get("node_graph_screen"), "无意图时应停在选图界面")
	assert_not_null(mounted.get("map_select_screen"), "选图界面仍在（玩家自己挑一张）")
	assert_eq(gsm.exploration.get("current_map"), &"", "无意图时不得写探索状态")


# ═══════════════════════════════════════════════════════════════════════════════
# 读档续玩：回到上次那张图，且不重生成
# ═══════════════════════════════════════════════════════════════════════════════

func test_resume_intent_returns_to_saved_map_with_state_intact() -> void:
	# Arrange——先玩过一阵（图 / 走过的路 / 剩余行动力都在存档里）
	var original: Dictionary = _play_map()
	var visited_before: Array = gsm.exploration.visited_nodes.duplicate()
	var ap_before: int = int(gsm.exploration.action_points)
	assert_ne(ap_before, 10, "前置：行动力已被消耗过（与「回满」可区分）")
	# 模拟「重启后读档」——只留 GSM 里的导航状态与 map_states 快照，
	# 内存里的 DAG 缓存按重启语义清空
	es.call(&"clear_dag_cache")
	es.call(&"rebuild_cache_from_storage", MAP_ID)
	IntentScript.request_resume()
	# Act
	var mounted: Control = _mount()
	# Assert——回到了那张图（而不是停在选图界面）
	assert_not_null(mounted.get("node_graph_screen"), "读档续玩应直接回到存档里那张图")
	assert_eq(gsm.exploration.get("current_map"), MAP_ID, "当前地图应为存档里那张图")
	# Assert——进度没被抹掉：走过的路与剩余行动力原样恢复
	assert_eq(gsm.exploration.visited_nodes, visited_before,
			"已访问节点不得被重置为入口（重生成地图的典型症状）")
	assert_eq(int(gsm.exploration.action_points), ap_before,
			"剩余行动力不得回满（重生成地图的典型症状）")
	# Assert——渲染出来的是存档里那张图本身
	var screen: Control = mounted.get("node_graph_screen")
	var renderer: Node = screen.get("viewport").renderer
	assert_eq(renderer.graph, original.get("graph", {}),
			"节点图应渲染存档快照里的那张 DAG，而不是重新生成的新图")


func test_resume_without_active_map_stays_on_map_select() -> void:
	## 存档里没有进行中的图（在选图界面存的档 / 第一次进探索）——不臆造一张。
	# Arrange——current_map 为空，但 map_states 里有旧快照（不能据此乱进）
	gsm.update_exploration_map_state(MAP_ID, {"graph": {0: []}, "nodes": {}, "entry_count": 1})
	IntentScript.request_resume()
	# Act
	var mounted: Control = _mount()
	# Assert
	assert_null(mounted.get("node_graph_screen"),
			"没有进行中的图时应停在选图界面（让玩家自己挑一张）")
	assert_eq(gsm.exploration.get("current_map"), &"", "不得凭空写入一个地图 ID")


func test_resume_without_snapshot_falls_back_to_map_select() -> void:
	## current_map 非空但那张图在 map_states 里没有图快照（存档残缺）——
	## 加载如实失败，薄容器拆掉那块空画板退回选图界面。
	# Arrange——只写导航状态，不写 graph/nodes 快照
	gsm.set_exploration_map(MAP_ID)
	IntentScript.request_resume()
	# Act
	var mounted: Control = _mount()
	# Assert——不把玩家留在一块什么都没有的画板上
	assert_null(mounted.get("node_graph_screen"),
			"无快照时不得让玩家停在空节点图上（退回选图界面）")
	assert_not_null(mounted.get("map_select_screen"),
			"退回的是选图界面（玩家能自己挑一张能玩的图）")


# ═══════════════════════════════════════════════════════════════════════════════
# 系统侧：resume_map 与 enter_map 的差别
# ═══════════════════════════════════════════════════════════════════════════════

func test_resume_map_rebuilds_cache_without_regenerating() -> void:
	# Arrange——玩过一阵后清掉内存缓存（重启语义）
	var original: Dictionary = _play_map()
	var visited_before: Array = gsm.exploration.visited_nodes.duplicate()
	es.call(&"clear_dag_cache")
	assert_false(bool(es.get("_dag_ready")), "前置：缓存已清空")
	# Act
	var snapshot: Dictionary = es.call(&"resume_map", MAP_ID)
	# Assert——缓存重建为存档里那张图（不是新生成的）
	assert_false(snapshot.is_empty(), "有快照时 resume_map 应重建成功")
	assert_eq(es.get("_node_graph"), original.get("graph", {}),
			"重建出来的邻接表应为存档里那份（程序化生成会得到不同的图）")
	assert_eq(snapshot.get("visited", []), visited_before,
			"快照里的已访问节点应取自 GSM 现读状态")
	assert_eq(int(snapshot.get("ap_remaining", -1)),
			int(gsm.exploration.action_points), "快照里的剩余行动力应为存档值")
	assert_eq(int(snapshot.get("current_node", -1)),
			int(es.call(&"_current_node_id", gsm)), "快照里的当前节点应为存档位置")


func test_resume_map_without_snapshot_returns_empty() -> void:
	# Arrange——没有任何存档快照的图
	# Act
	var snapshot: Dictionary = es.call(&"resume_map", &"dan_xia_gu")
	# Assert
	assert_true(snapshot.is_empty(), "无快照时应返回空字典（调用方据此退回选图界面）")


func test_rebuild_cache_from_storage_writes_nothing_to_gsm() -> void:
	## 读档续玩是[b]读[/b]操作——不该改变存档内容（ADR-0031 §2 同类取向）。
	# Arrange
	_play_map()
	var before: Dictionary = (gsm.exploration as Dictionary).duplicate(true)
	es.call(&"clear_dag_cache")
	# Act
	es.call(&"rebuild_cache_from_storage", MAP_ID)
	# Assert
	assert_eq(gsm.exploration, before, "重建缓存不得写入 GSM 任何字段")
