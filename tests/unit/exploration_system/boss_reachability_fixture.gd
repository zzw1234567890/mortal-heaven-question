extends GutTest
## BossReachabilityFixture —— 抵达 Boss 行动力最短路用例的共享夹具。[br]
## [br][b]为什么单独一处[/b]：用例文件要守在 300 行软上限内
## （.claude/docs/coding-standards.md），而「怎么搭那张固定 DAG」与「断言什么」
## 是两件事（同 [code]craft_node_fixture.gd[/code] 先例）。[br]
## [br][b]用法[/b]：子类 [code]extends "res://…/boss_reachability_fixture.gd"[/code]，
## 直接写 [code]test_*[/code] 方法即可；[code]before_each[/code] /
## [code]after_each[/code] 由本夹具提供，子类若要扩展需先 [code]super()[/code]。[br]
## [br][b]文件前缀[/b]：本文件不以 [code]test_[/code] 开头——GUT 按前缀收集，
## 因此它只作为基类被继承，不会被当作用例文件单独执行。[br]
## [br][b]隔离[/b]：GSM 的 exploration 域在 [code]before_each[/code] 快照、
## [code]after_each[/code] 原样还原；探索系统用 [code]ES_SCRIPT.new()[/code] 构造，
## 不进 Autoload（本组用例测的是算法与系统口径，不依赖生产接线）。
##
## 来源: design/gdd/exploration-system.md §4 移动规则 / §5 结束条件 / §8 边界、
## design/gdd/action-point-system.md §公式 2/3、ADR-0014 §关键接口。

const ES_SCRIPT := preload("res://src/feature/exploration_system.gd")
const Reach := preload("res://src/feature/exploration/exploration_reachability.gd")

## 节点 ID（编码 layer * 100 + idx）。
const ENTRY: int = 0
const COMBAT_A: int = 100
const COMBAT_B: int = 110
const SPRING: int = 120
const EVENT: int = 200
const BOSS: int = 300

## Boss 类型值（与 [code]ExplorationSystem.NodeType.BOSS[/code] 同源）。
const TYPE_BOSS: int = 3

var es: Node = null
var gsm: Node = null
var _exploration_before: Dictionary = {}


func before_each() -> void:
	gsm = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/GameStateManager")
	_exploration_before = (GameStateManager.exploration as Dictionary).duplicate(true)
	_reset_gsm()
	es = ES_SCRIPT.new()
	es.call("set_rng_seed", 42)
	es.set("generate_enemy_roster_cb", Callable(func(_mid, _r, _is_elite):
		return [{"enemy_id": 1}]))
	es.set("get_event_pool_cb", Callable(func(_mid, _r):
		return ["event_a"]))


func after_each() -> void:
	if es != null:
		es.free()
		es = null
	_reset_gsm()
	GameStateManager.exploration = _exploration_before


## 固定 DAG：0 入口 → 100 战斗 → 200 事件 → 300 Boss（Boss 豁免）。[br]
## 另挂一个 120 灵泉作对照节点（也在豁免集合里），但不参与最短路的必经路径。
func _setup_dag(p_map_config: Dictionary = {}) -> void:
	es.set("_node_graph", {
		ENTRY: [COMBAT_A, SPRING],
		COMBAT_A: [EVENT],
		SPRING: [],
		EVENT: [BOSS],
		BOSS: [],
	})
	es.set("_node_details", {
		ENTRY: {"type": 0, "layer": 0, "idx": 0},
		COMBAT_A: {"type": 1, "layer": 1, "idx": 0, "enemy_roster": [{"enemy_id": 1}]},
		SPRING: {"type": 7, "layer": 1, "idx": 2},
		EVENT: {"type": 4, "layer": 2, "idx": 0, "event_pool": ["event_a"]},
		BOSS: {"type": TYPE_BOSS, "layer": 3, "idx": 0, "enemy_roster": []},
	})
	es.set("_map_config", p_map_config)
	es.set("_dag_ready", true)


## 把玩家放到 [param p_node_id]（写 GSM 的层/位——与 move_to_node 同一编码）。
func _stand_on(p_node_id: int) -> void:
	gsm.exploration.node_position = {"layer": p_node_id / 100, "idx": p_node_id % 100}


## 写已访问集合（走 GSM 第二层方法）。
func _visit(p_nodes: Array) -> void:
	gsm.call(&"reset_exploration_visited", p_nodes)


func _set_ap(p_current: int) -> void:
	gsm.call(&"set_exploration_ap", p_current, 5)


func _ap() -> int:
	return int(gsm.exploration.action_points)


## 重置 GSM 探索域。
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
