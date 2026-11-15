extends GutTest
## 灵泉「每图限次」在[b]读档重建后[/b]仍取自地图配置。[br]
## [br][b]本文件补的断链[/b]：[code]ExplorationActionSpring._map_config()[/code] 此前只读
## 宿主的 [code]_map_config[/code] 字段，而那个字段由 [code]ExplorationDAGBuilder[/code]
## 在生成期写入、由 [code]rebuild_dag_cache[/code] 在读档重建时置空
## （[code]map_states[/code] 只存 graph/nodes）——于是「读档后进图用灵泉」会拿空配置去问
## [code]limit_of[/code]，静默回退到出厂值 1。[br]
## [br][b]为什么这条缺口值得单独一个文件[/b]：失败形态是「限次悄悄变少」而不是报错——
## 地图表写着限 2 次的图，读档后只给 1 次，玩家只会以为这眼泉坏了。且它与
## [code]test_action_spring_map_limit.gd[/code] 的场景正交：那边全程在[b]同一进程内[/b]
## 生成即用，宿主快照一直有效；这边专测[b]快照失效[/b]后的解析兜底。[br]
## [br][b]覆盖[/b]：[br]
##   1. 限 2 次的图读档重建后仍给 2 次（旧实现会给 1 次 → 本用例红）；[br]
##   2. 限 1 次的图读档重建后仍只给 1 次（防「恒为 2」的假通过）；[br]
##   3. 限次跟着[b]存档里的地图 ID[/b] 走——同一份空快照下换图，解析结果随该图配置变。[br]
## [br][b]隔离[/b]：GSM 的 exploration 域在 [code]before_each[/code] 快照、
## [code]after_each[/code] 原样还原（同 [code]test_action_spring_map_limit.gd[/code] 口径）。
##
## 来源: design/gdd/action-point-system.md §3 行动力回复 / §调优参数、
## design/gdd/exploration-system.md §节点类型一览、ADR-0014 §决策 1 状态分层模型、
## 本轮任务书第 2 条。

const ES_SCRIPT := preload("res://src/feature/exploration_system.gd")
const SpringScript := preload("res://src/feature/exploration/exploration_action_spring.gd")

## 灵泉节点 ID（结算不使用，仅透传日志——与探索系统的节点 API 口径一致）。
const SPRING_NODE: int = 203

## 两张用例地图：一张限 2 次、一张限 1 次（限次由注入的配置回调按地图 ID 给出）。
const MAP_LIMIT_TWO: StringName = &"map_limit_two"
const MAP_LIMIT_ONE: StringName = &"map_limit_one"
const LIMIT_TWO: int = 2
const LIMIT_ONE: int = 1

var es: Node = null
var _exploration_before: Dictionary = {}


func before_each() -> void:
	_exploration_before = (GameStateManager.exploration as Dictionary).duplicate(true)
	GameStateManager.exploration = {
		"current_map": &"",
		"node_position": {"layer": 0, "idx": 0},
		"visited_nodes": [],
		"action_points": 0,
		"max_action_points": 0,
		"map_states": {},
	}
	es = ES_SCRIPT.new()
	es.call("set_rng_seed", 42)
	# 地图配置按地图 ID 给限次——生产对应 ExplorationMapCatalog.config_for。
	es.set("get_map_config_cb", Callable(func(mid, _r):
		var config: Dictionary = (es.get("DIFFICULTY_CONFIGS")[1] as Dictionary).duplicate(true)
		config["action_spring_count"] = LIMIT_TWO \
				if StringName(str(mid)) == MAP_LIMIT_TWO else LIMIT_ONE
		return config))
	es.set("generate_enemy_roster_cb", Callable(func(_mid, _r, _is_elite):
		return [{"enemy_id": 1}]))
	es.set("get_event_pool_cb", Callable(func(_mid, _r):
		return ["event_a"]))
	es.set("generate_shop_inventory_cb", Callable(func(_r):
		return {"items": []}))


func after_each() -> void:
	GameStateManager.exploration = _exploration_before
	if es != null:
		es.free()
		es = null


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 读档重建后：限 2 次的图仍给 2 次
# ═══════════════════════════════════════════════════════════════════════════════

func test_limit_two_map_keeps_its_quota_after_save_reload() -> void:
	## 旧实现下第二次会返回 0（空配置 → 出厂值 1）——本用例正是钉住那条缺口。
	# Arrange——进图后模拟读档重建（宿主 _map_config 快照被置空）
	_enter_then_reload(MAP_LIMIT_TWO)
	assert_true((es.get("_map_config") as Dictionary).is_empty(),
			"前置：读档重建后宿主 _map_config 快照应为空（这正是本用例要盖的场景）")
	# Act——两次独立使用（每次先把行动力耗掉）
	_set_ap(1, 5)
	var first: int = int(es.call(&"use_action_spring", SPRING_NODE))
	_set_ap(1, 5)
	var second: int = int(es.call(&"use_action_spring", SPRING_NODE))
	# Assert
	assert_eq(first, 4, "第一次应回复 4 点")
	assert_eq(second, 4, "限 %d 次的图读档后仍应给出第 %d 次机会（不是回退出厂值 1）"
			% [LIMIT_TWO, LIMIT_TWO])
	assert_eq(_uses(), LIMIT_TWO, "两次使用都应记进 map_states")
	# 第三次才该被拒——限次是 2 而不是无限
	_set_ap(1, 5)
	assert_eq(int(es.call(&"use_action_spring", SPRING_NODE)), 0,
			"超出限次（第 3 次）应被拒")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 对照组：限 1 次的图读档后仍只给 1 次（防「恒为 2」的假通过）
# ═══════════════════════════════════════════════════════════════════════════════

func test_limit_one_map_still_refuses_the_second_use_after_reload() -> void:
	# Arrange
	_enter_then_reload(MAP_LIMIT_ONE)
	# Act
	_set_ap(1, 5)
	var first: int = int(es.call(&"use_action_spring", SPRING_NODE))
	_set_ap(1, 5)
	var second: int = int(es.call(&"use_action_spring", SPRING_NODE))
	# Assert
	assert_eq(first, 4, "第一次应回复 4 点")
	assert_eq(second, 0, "限 %d 次的图读档后第二次应被拒" % LIMIT_ONE)
	assert_eq(_ap(), 1, "拒绝路径不应写行动力")
	assert_push_warning("本图灵泉已用尽")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 限次跟着存档里的地图 ID 走
# ═══════════════════════════════════════════════════════════════════════════════

func test_resolved_limit_follows_the_saved_map_id() -> void:
	## 同一份（已置空的）宿主快照下换图，解析出来的限次随该图配置变——
	## 证明重解析用的是 [code]exploration.current_map[/code]，不是任何残留快照。
	# Arrange——限 1 次的图，读档重建后解析结果应为限 1
	_enter_then_reload(MAP_LIMIT_ONE)
	assert_eq(_resolved_limit(), LIMIT_ONE, "前置：当前图的解析限次应为 1")
	# Act——把存档里的当前地图换成限 2 次的那张
	GameStateManager.call(&"set_exploration_map", MAP_LIMIT_TWO)
	# Assert
	assert_eq(_resolved_limit(), LIMIT_TWO,
			"换图后限次应重新解析为新图的配置（%d）" % LIMIT_TWO)


# ═══════════════════════════════════════════════════════════════════════════════
# 装置
# ═══════════════════════════════════════════════════════════════════════════════

## 进图（生成期写满宿主快照）→ 模拟读档重建（清缓存 + 走 [code]_ready[/code]）。
func _enter_then_reload(p_map_id: StringName) -> void:
	es.call(&"enter_map", p_map_id, 1, 5)
	es.call(&"clear_dag_cache")
	assert_eq(es.get("_dag_ready"), false, "前置：清缓存后应未就绪")
	es.call(&"_ready")
	assert_eq(es.get("_dag_ready"), true, "前置：读档重建后应就绪")


## 灵泉模块当前解析出来的本图限次（走被测的那条解析路径）。
func _resolved_limit() -> int:
	var module: RefCounted = es.call(&"_get_action_spring")
	return SpringScript.limit_of(module.call(&"_map_config"))


## 本图已记下的灵泉使用次数。
func _uses() -> int:
	var state: Dictionary = (GameStateManager.exploration.map_states as Dictionary) \
			.get(GameStateManager.exploration.current_map, {})
	return SpringScript.uses_of(state)


func _set_ap(p_current: int, p_max: int) -> void:
	GameStateManager.call(&"set_exploration_ap", p_current, p_max)


func _ap() -> int:
	return int(GameStateManager.exploration.get("action_points", -1))
