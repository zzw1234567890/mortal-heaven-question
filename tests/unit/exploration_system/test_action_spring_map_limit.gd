extends GutTest
## 行动力泉「每图限次」——生成侧与结算侧共用判据。[br]
## [br][b]本文件补的两条断链[/b]：[br]
##   1. [b]生成侧[/b]——权重表此前不含灵泉键，生产路径根本刷不出灵泉节点
##      （GDD §节点表「行动力泉 | 全回复 | 地图上特定节点（每个地图限1次）」）；[br]
##   2. [b]结算侧[/b]——「每图限 1 次」此前无计数位，同一次进入可以反复用。[br]
## [br][b]覆盖[/b]（本轮任务点名的断言）：[br]
##   · 地图生成真的会产出灵泉节点，且[b]数量不超过本图限次[/b]；[br]
##   · 用掉一次后[b]重新进图不再刷出灵泉[/b]（次数写在 [code]map_states[/code]，
##     重新生成不重置）；[br]
##   · 结算侧：第二次使用被拒绝且不再写行动力；满行动力时不占次数。[br]
## [br][b]隔离[/b]：GSM 的 exploration 域在 [code]before_each[/code] 快照、
## [code]after_each[/code] 原样还原（同 [code]test_exploration_action_spring.gd[/code] 先例）。
##
## 来源: design/gdd/exploration-system.md §节点类型一览 / §8 边界、
## design/gdd/action-point-system.md §3 行动力回复 / §调优参数。

const ES_SCRIPT := preload("res://src/feature/exploration_system.gd")
const SpringScript := preload("res://src/feature/exploration/exploration_action_spring.gd")

## 灵泉节点类型值（与 [code]ExplorationSystem.NodeType.ACTION_SPRING[/code] 同源）。
const TYPE_ACTION_SPRING: int = 7

## 用例地图（写 [code]map_states[/code] 用；与真实地图 ID 一致以便走探明表配置）。
const MAP_ID: StringName = &"qing_yun_jian_zong"

## 扫描生成的最大进入次数——灵泉权重 8/100 出头，12 次几乎必然命中
## （同 [code]test_exploration_bootstrap.gd[/code] 的 SHOP_SCAN_LIMIT 口径）。
const SPRING_SCAN_LIMIT: int = 12

var es: Node = null
var _exploration_before: Dictionary = {}


func before_each() -> void:
	_exploration_before = (GameStateManager.exploration as Dictionary).duplicate(true)
	GameStateManager.exploration = {
		"current_map": MAP_ID,
		"node_position": {"layer": 0, "idx": 0},
		"visited_nodes": [],
		"action_points": 0,
		"max_action_points": 0,
		"map_states": {},
	}
	es = ES_SCRIPT.new()
	es.call("set_rng_seed", 42)
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
# 1. 生成侧：灵泉真的刷得出来，且不超限次
# ═══════════════════════════════════════════════════════════════════════════════

func test_generated_map_contains_action_spring_nodes() -> void:
	## 生产路径（探明表配置 + 权重表）必须能刷出灵泉节点——权重键存在且映射到了
	## [code]NodeType.ACTION_SPRING[/code]。
	var springs: Array = _scan_for_springs()
	assert_true(not springs.is_empty(),
			"扫 %d 张图应至少刷出一次灵泉节点（权重表含 action_spring 键时才有）"
			% SPRING_SCAN_LIMIT)


func test_generated_map_has_at_most_one_spring_per_map() -> void:
	## 「每图限 1 次」在生成侧表现为「每张图最多一个灵泉节点」——
	## 上限之外的权重键会被 [code]_assign_node_types[/code] 摘掉。
	for attempt: int in range(SPRING_SCAN_LIMIT):
		var result: Dictionary = _enter()
		var count: int = _spring_ids(result["nodes"]).size()
		assert_true(count <= SpringScript.DEFAULT_MAP_LIMIT,
				"第 %d 张图的灵泉节点数 %d 不应超过限次 %d"
				% [attempt, count, SpringScript.DEFAULT_MAP_LIMIT])


func test_spent_spring_is_not_regenerated_on_reentry() -> void:
	## 次数写在 [code]map_states[/code]——用掉一次后重新进图不再刷出灵泉。
	## 这条锁的是「重新进图不重置成可无限刷」。
	# Arrange——本图已用满一次
	GameStateManager.call(&"update_exploration_map_state", MAP_ID,
			{SpringScript.KEY_SPRING_USES: SpringScript.DEFAULT_MAP_LIMIT})
	# Act——反复重进（每次都会重新生成 DAG）
	for attempt: int in range(SPRING_SCAN_LIMIT):
		var result: Dictionary = _enter()
		# Assert——一次都不该再刷出来
		assert_eq(_spring_ids(result["nodes"]), [],
				"第 %d 张图不该有灵泉（本图已用满 %d 次）"
				% [attempt, SpringScript.DEFAULT_MAP_LIMIT])


func test_spring_reappears_when_the_map_has_room_left() -> void:
	## 对照（防「一票否决」的假通过）：次数没用满时照常刷得出来。
	# Arrange——记录里是 0 次（未用）
	GameStateManager.call(&"update_exploration_map_state", MAP_ID,
			{SpringScript.KEY_SPRING_USES: 0})
	# Act / Assert
	assert_true(not _scan_for_springs().is_empty(),
			"余量为 1 时仍应刷得出灵泉")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 结算侧：第二次使用被拒
# ═══════════════════════════════════════════════════════════════════════════════

func test_second_use_in_the_same_map_restores_nothing() -> void:
	## 第一次用完，行动力又被消耗掉之后（第二次进图 / 走了几步），
	## 同一张图里再用一次灵泉应是 0——「每图限 1 次」。
	# Arrange——2/5，第一次
	_set_ap(2, 5)
	assert_eq(int(es.call(&"use_action_spring", 203)), 3, "第一次应回复 3 点")
	assert_eq(_ap(), 5, "第一次后应回满")
	# Act——再耗掉 3 点再试
	_set_ap(2, 5)
	var second: int = int(es.call(&"use_action_spring", 203))
	# Assert
	assert_eq(second, 0, "同一张图第二次使用应回复 0（已用满）")
	assert_eq(_ap(), 2, "拒绝路径不应写行动力")
	assert_push_warning("本图灵泉已用尽")


func test_first_use_records_the_count_in_map_states() -> void:
	## 计数落 [code]map_states[/code]——持久化形态可直接断言（重新进图不重置，
	## 因为进图只改写 entry_count / graph / nodes，不动这个键）。
	# Arrange
	_set_ap(1, 5)
	# Act
	es.call(&"use_action_spring", 203)
	# Assert
	var state: Dictionary = GameStateManager.exploration.map_states[MAP_ID]
	assert_eq(int(state.get(SpringScript.KEY_SPRING_USES, -1)), 1,
			"使用次数应写进 map_states[map_id][%s]" % SpringScript.KEY_SPRING_USES)


func test_full_action_points_does_not_consume_the_map_quota() -> void:
	## 满行动力时回复 0 且[b]不占次数[/b]——「用掉一次机会」与「白跑一趟」
	## 不是一回事：路过的第一眼泉不该把本图的唯一一次机会吃掉。
	# Arrange——满行动力
	_set_ap(5, 5)
	# Act
	assert_eq(int(es.call(&"use_action_spring", 203)), 0, "满行动力应回复 0")
	# Assert
	var state: Dictionary = GameStateManager.exploration.map_states.get(MAP_ID, {})
	assert_eq(int(state.get(SpringScript.KEY_SPRING_USES, 0)), 0,
			"没有真回复就不应记次数")
	# 后续仍能正常使用
	_set_ap(1, 5)
	assert_eq(int(es.call(&"use_action_spring", 203)), 4,
			"次数未被占用时应能正常回复")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 限次判据（纯函数——生成侧与结算侧共用）
# ═══════════════════════════════════════════════════════════════════════════════

func test_limit_of_reads_map_config_with_fallback() -> void:
	assert_eq(SpringScript.limit_of({"action_spring_count": 2}), 2, "配置值优先")
	assert_eq(SpringScript.limit_of({}), SpringScript.DEFAULT_MAP_LIMIT,
			"缺键回退出厂值（GDD §调优参数：每图限次 1，范围 1-2）")
	assert_eq(SpringScript.limit_of({"action_spring_count": 0}), 0,
			"0 = 本图不刷灵泉（合法配置）")
	assert_eq(SpringScript.limit_of({"action_spring_count": -3}), 0,
			"负数按 0（不静默放大）")


func test_is_exhausted_shared_predicate() -> void:
	assert_false(SpringScript.is_exhausted({}, {"action_spring_count": 1}),
			"没用过 → 未用尽")
	assert_true(SpringScript.is_exhausted({SpringScript.KEY_SPRING_USES: 1},
			{"action_spring_count": 1}), "用满 1 次 → 用尽")
	assert_false(SpringScript.is_exhausted({SpringScript.KEY_SPRING_USES: 1},
			{"action_spring_count": 2}), "限 2 次时用 1 次 → 还有余量")
	assert_true(SpringScript.is_exhausted({}, {"action_spring_count": 0}),
			"限次为 0 → 直接算用尽（不刷也不回）")


func test_uses_of_tolerates_dirty_save() -> void:
	assert_eq(SpringScript.uses_of({}), 0, "缺键 → 0（没记录不是已用满）")
	assert_eq(SpringScript.uses_of({SpringScript.KEY_SPRING_USES: -5}), 0,
			"脏存档负数 → 0")


# ═══════════════════════════════════════════════════════════════════════════════
# 装置
# ═══════════════════════════════════════════════════════════════════════════════

## 生成一张图（[code]generate_map[/code] 是纯生成，不写导航状态；[code]entry_count[/code]
## 递增会让 seed 加扰，从而遍历不同图）。
func _enter() -> Dictionary:
	var entry_count: int = 1 + int((GameStateManager.exploration.map_states
			.get(MAP_ID, {}) as Dictionary).get("entry_count", 0))
	GameStateManager.call(&"update_exploration_map_state", MAP_ID,
			{"entry_count": entry_count})
	return es.call("generate_map", MAP_ID, 1, entry_count)


## 反复生成直到某张图产出灵泉节点，返回那一张图的灵泉节点 ID 列表。
func _scan_for_springs() -> Array:
	for _attempt: int in range(SPRING_SCAN_LIMIT):
		var springs: Array = _spring_ids(_enter()["nodes"])
		if not springs.is_empty():
			return springs
	return []


## 节点详情表里类型为灵泉的节点 ID（升序）。
func _spring_ids(p_nodes: Dictionary) -> Array:
	var ids: Array = []
	for node_id: Variant in p_nodes:
		if int((p_nodes[node_id] as Dictionary).get("type", -1)) == TYPE_ACTION_SPRING:
			ids.append(int(node_id))
	ids.sort()
	return ids


func _set_ap(p_current: int, p_max: int) -> void:
	GameStateManager.call(&"set_exploration_ap", p_current, p_max)


func _ap() -> int:
	return int(GameStateManager.exploration.get("action_points", -1))
