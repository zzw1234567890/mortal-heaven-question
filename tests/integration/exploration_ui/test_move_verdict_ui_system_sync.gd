extends GutTest
## UI 六态的可达性判定跟着[b]系统的可判别结果[/b]走——真实地图对照。[br]
## [br][b]本文件补的断链[/b]：本轮把 [code]can_move_to[/code] 拆出可判别结果
## （[code]can_move_to_detail → {ok, reason}[/code]）之后，UI 若仍自己推导一遍
## 可达性，两份实现就又分家了——系统按本图的距离定价判、UI 只看
## [code]ap_remaining < 1[/code]，某张图把单位距离调小后，玩家会看到「可达」的节点
## 一点就报「行动力不足」。本文件让节点图渲染真实地图，断言画出来的六态与系统的
## 判定[b]逐节点一致[/b]。[br]
## [br][b]★ 本轮语义变更（有意改动，报告单列）★[/b]：制造「只有系统判得出来」这个
## 局面的手段换了——移动开销本轮起按[b]两节点布局距离[/b]定价（老板 2026-11-27
## 18:40），遗留键 [code]ap_cost[/code] 不再参与计算。旧版注入
## [code]ap_cost = 99[/code] 并断言「本图开销应为注入值」——那个键现在被完全忽略，
## 断言已无处可依。[br]
## [br][b]改用新旋钮[/b]：[code]ap_distance_unit[/code] 压到 1.0px/点，于是任意一跳
## 都会顶到 [code]ap_move_max[/code] 上限（出厂 4 点）；AP=1 时非豁免子节点全部
## 判不足，而 UI 自算（[code]1 >= 1[/code]）会画成可达。[b]断言的判别力与旧版等价[/b]
## ——仍是「系统算得出距离、UI 算不出」的那条缝。[br]
## [br][b]前置断言不再钉某个常量[/b]：改成问系统「到该子节点这一跳要几点」，要求它
## [b]大于[/b] LOW_AP——从前钉的是「配置被读到了」，现在钉的是「本用例的构造真的
## 制造出了不足」，后者才是用例能不能测出东西的关键。[br]
## [br][b]覆盖[/b]：[br]
##   1. 真实地图 + 紧单位距离 → 非豁免子节点全部为行动力不足，豁免类型不受影响；[br]
##   2. 全图逐节点比对——UI 六态 == 系统 verdict 翻出来的六态；[br]
##   3. 反向对照——快照不出自系统时（测试直调 stub 样本 / stub 降级路径）回落
##      自算，不被系统缓存里那张无关的 DAG 误判成一片不可达。[br]
## [br][b]隔离[/b]：GSM 的 exploration 域 + [code]player.realm[/code] 快照还原；
## 探索系统用 [code]ES_SCRIPT.new()[/code] 构造，不进 Autoload。[br]
##
## 来源: design/gdd/action-point-system.md §公式 2/3 + §调优参数、
## design/gdd/exploration-ui-system.md §2 界面规则表、ADR-0014 §关键接口、
## ADR-0031 §2、本轮任务书第 3 条 + 追加规则（距离定价）。

const NodeGraphScreenScene: PackedScene = preload("res://src/ui/exploration/node_graph_screen.tscn")
const ES_SCRIPT := preload("res://src/feature/exploration_system.gd")
const NODE_LOGIC := preload("res://src/ui/exploration/node_state_logic.gd")
const DATA_STUB := preload("res://src/ui/exploration/node_graph_data_stub.gd")
## 距离定价规则——本文件把单位距离压到极小让它顶到上限（见文件头）。
const ApRules := preload("res://src/feature/exploration/exploration_ap_rules.gd")

## 用例地图（真实生成——探明表里青云剑宗为炼气期地图）。
const MAP_ID: StringName = &"qing_yun_jian_zong"

## 本图单位距离（px/点）——刻意压到极小：任何一跳都达到 [code]ap_move_max[/code]
## 上限，制造「只有系统的距离定价判得出不足」的局面。
const TIGHT_UNIT: float = 1.0

## 用例中的剩余行动力（1 点：出厂定价下够走一格，本图定价下不够）。
const LOW_AP: int = 1

## AP=0 豁免类型（与两条 [code]AP_EXEMPT_TYPES[/code] 同源：Boss/传送/灵泉）。
const EXEMPT_TYPES: Array = [3, 6, 7]

var es: Node = null
var gsm: Node = null
## 本用例挂载的节点图屏幕（每次 [method _mount_screen] 重新赋值——不靠子节点顺序取）。
var screen: Control = null
var _exploration_before: Dictionary = {}
var _realm_before: int = 1


func before_each() -> void:
	gsm = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/GameStateManager")
	_exploration_before = (GameStateManager.exploration as Dictionary).duplicate(true)
	_realm_before = int(gsm.player.get("realm", 1)) if gsm != null else 1
	if gsm != null:
		gsm.player.realm = 1
	_reset_gsm()
	es = ES_SCRIPT.new()
	es.call("set_rng_seed", 42)
	# 地图配置——本图单位距离极小（1px/点），故任意一跳都顶到 ap_move_max 上限
	#（与出厂的 120px/点判出不同结果）。遗留键 ap_cost 本轮起被忽略（见文件头）。
	es.set("get_map_config_cb", Callable(func(_map_id, _realm):
		var config: Dictionary = (es.get("DIFFICULTY_CONFIGS")[0] as Dictionary).duplicate(true)
		config["ap_distance_unit"] = TIGHT_UNIT
		return config))
	es.set("generate_enemy_roster_cb", Callable(func(_mid, _r, _is_elite):
		return [{"enemy_id": 1}]))
	es.set("get_event_pool_cb", Callable(func(_mid, _r):
		return ["event_a"]))
	es.set("generate_shop_inventory_cb", Callable(func(_r):
		return {"items": []}))


func after_each() -> void:
	_reset_gsm()
	if gsm != null:
		gsm.player.realm = _realm_before
	GameStateManager.exploration = _exploration_before
	if es != null:
		es.free()
		es = null


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 高开销地图：UI 画出的正是系统的口径
# ═══════════════════════════════════════════════════════════════════════════════

func test_high_cost_map_paints_children_as_ap_insufficient() -> void:
	## 前置：本图任意一跳都贵过 LOW_AP（出厂定价下这一跳只值 1 点）——UI 若自算
	## （只看 ap < 1）会画成可达。[br]
	## [br][b]前置改问系统而不是钉常量[/b]：旧版钉的是「配置里的 99 被读到了」，
	## 那只能证明配置被读，证明不了本用例真的制造出了「不足」。改成问
	## [method ExplorationSystem.can_move_to_detail] 的直接依据——报到价。
	# Arrange——进真实地图，行动力压到 1 点
	_enter_map()
	_apply_ap(LOW_AP)
	assert_true(is_equal_approx(_map_unit(), TIGHT_UNIT),
			"前置：本图单位距离应为注入值（否则测的还是出厂定价）")
	var current: int = int(_renderer().current_node)
	var children: Array = _children_of(current)
	assert_true(not children.is_empty(), "前置：当前节点应有前向邻接（否则本用例无所指）")
	var priced: int = 0
	var cap: int = ApRules.move_max_of(es.get("_map_config"))
	assert_gt(cap, LOW_AP, "前置：本图单跳上限应大于剩余行动力（否则判不出不足）")
	for child: int in children:
		if _is_exempt(child):
			continue
		assert_eq(int(es.call(&"ap_cost_between", current, child)), cap,
				"前置：单位距离极小时，非豁免子节点 %d 的报到价应顶到上限 %d"
				% [child, cap])
		priced += 1
	assert_true(priced > 0, "前置：当前节点应至少有一个非豁免子节点（否则本用例无所指）")
	# Act
	var states: Dictionary = _renderer().states
	# Assert——非豁免子节点都应是行动力不足
	var checked: int = 0
	for child: int in children:
		if _is_exempt(child):
			assert_ne(int(states[child]), NODE_LOGIC.NodeState.AP_INSUFFICIENT,
					"豁免节点 %d 不该被判行动力不足" % child)
			continue
		checked += 1
		assert_eq(int(states[child]), NODE_LOGIC.NodeState.AP_INSUFFICIENT,
				"非豁免子节点 %d 在本图定价下应画成行动力不足（自算会画成可达）" % child)
	assert_true(checked > 0, "前置：入口应至少有一个非豁免子节点（否则本用例无所指）")


func test_every_node_state_matches_the_system_verdict() -> void:
	## 全图逐节点比对——迷雾/当前/已访问由快照决定，其余一格一格问系统。
	## 绑定缺失（UI 自算）时本用例会红：AP=1 自算是可达，系统判行动力不足。
	# Arrange
	_enter_map()
	_apply_ap(LOW_AP)
	var renderer: Node = _renderer()
	var states: Dictionary = renderer.states
	var current: int = int(renderer.current_node)
	# Act / Assert
	var compared: int = 0
	for node_id: int in (renderer.nodes as Dictionary).keys():
		var expected: int = NODE_LOGIC.classify_with_verdict(node_id, renderer.graph,
				renderer.visited, current,
				es.call(&"can_move_to_detail", current, node_id))
		assert_eq(int(states[node_id]), expected,
				"节点 %d 六态应与系统的可判别判定一致" % node_id)
		compared += 1
	assert_eq(compared, (renderer.nodes as Dictionary).size(), "每个节点都应比对到")


func test_exempt_node_is_never_painted_ap_insufficient() -> void:
	## 对照（防「高开销一律拒」的假通过）：豁免类型（Boss/传送/灵泉）不受开销影响。
	# Arrange
	_enter_map()
	_apply_ap(LOW_AP)
	var renderer: Node = _renderer()
	var states: Dictionary = renderer.states
	var exempt_ids: Array = []
	for node_id: int in (renderer.nodes as Dictionary).keys():
		if _is_exempt(node_id):
			exempt_ids.append(node_id)
	assert_true(not exempt_ids.is_empty(), "本图应有豁免类型节点（Boss 恒在）")
	# Assert——系统与 UI 两侧都不得判它「行动力不足」
	for node_id: int in exempt_ids:
		var verdict: Dictionary = es.call(&"can_move_to_detail",
				int(renderer.current_node), node_id)
		assert_ne(str(verdict.get("reason", "")), ES_SCRIPT.REASON_AP_SHORT,
				"豁免节点 %d 不该报行动力不足（系统口径）" % node_id)
		assert_ne(int(states[node_id]), NODE_LOGIC.NodeState.AP_INSUFFICIENT,
				"豁免节点 %d 不该画成行动力不足（UI 口径）" % node_id)


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 快照不出自系统时回落自算（不被无关 DAG 误判）
# ═══════════════════════════════════════════════════════════════════════════════

func test_stub_snapshot_keeps_self_computed_states() -> void:
	## 系统在场但快照是直调传进来的 stub 样本——若拿系统的判定去翻，图上每个节点
	## 都会报「不可达」（stub 的节点 ID 不在系统缓存的那张图里）。
	# Arrange——真实系统在场，却直调渲染入口喂 stub 快照
	_mount_screen(es)
	screen._on_map_generated(MAP_ID, DATA_STUB.stub_snapshot())
	# Assert——101 是 stub 里入口的前向邻接、AP=3 够走 → 可达（自算口径）
	assert_eq(int(_renderer().states.get(101, -1)), NODE_LOGIC.NodeState.REACHABLE,
			"快照不出自系统时应回落自算（否则会被无关 DAG 判成一片不可达）")


func test_stub_fallback_path_keeps_self_computed_states() -> void:
	## 降级路径同理：无 [code]map_generated[/code] 信号的桩 + stub 样本。
	# Arrange
	var bare: Node = Node.new()
	var bare_script: GDScript = GDScript.new()
	bare_script.source_code = "extends Node\n"
	bare_script.reload()
	bare.set_script(bare_script)
	add_child_autofree(bare)
	_mount_screen(bare)
	# Act
	screen.trigger_map_load(MAP_ID)
	# Assert
	assert_true(screen.is_using_stub_source(), "无信号源时应在 stub 降级路径上")
	assert_eq(int(_renderer().states.get(101, -1)), NODE_LOGIC.NodeState.REACHABLE,
			"降级路径的六态仍按 stub 快照自算")


# ═══════════════════════════════════════════════════════════════════════════════
# 装置
# ═══════════════════════════════════════════════════════════════════════════════

## 挂载节点图屏幕并注入探索系统（注入必须在 add_child 之前——_ready 据此选数据源）。
func _mount_screen(p_system: Node) -> void:
	screen = NodeGraphScreenScene.instantiate()
	screen.animate = false
	screen.exploration_system = p_system
	add_child_autofree(screen)


## 进真实地图（走屏幕自己的加载入口——系统命令 + 信号广播 + 渲染全链）。
func _enter_map() -> void:
	_mount_screen(es)
	screen.trigger_map_load(MAP_ID)


func _renderer() -> Node:
	return screen.get("viewport").renderer


## 某节点的前向邻接（渲染器持有的邻接表）。
func _children_of(p_node: int) -> Array:
	return (_renderer().graph as Dictionary).get(p_node, [])


## 某节点是否为 AP 豁免类型（读渲染快照的节点详情）。
func _is_exempt(p_node: int) -> bool:
	var nodes: Dictionary = _renderer().nodes
	return EXEMPT_TYPES.has(int((nodes.get(p_node, {}) as Dictionary).get("type", -1)))


## 本图配置里被真正读到的那个旋钮（生成期写入系统缓存的配置快照）。[br]
## [br][b]为什么查 [code]ap_distance_unit[/code] 而不是旧版的 [code]ap_cost[/code][/b]：
## 后者本轮起是遗留键（保留只为旧存档与旧地图表不报错），读它只会读到「填了什么」
## 而不是「系统按什么算」。
func _map_unit() -> float:
	return float((es.get("_map_config") as Dictionary).get("ap_distance_unit", -1.0))


## 把行动力压到 [param p_current] 点并重渲染。[br]
## [br][b]两边都要改[/b]：系统判定读 GSM，UI 自算读快照——只改一边就分不出「谁在
## 作答」，用例也就测不出绑定是否生效。重渲染走屏幕自己的
## [method NodeGraphScreen._on_map_generated]（与真实信号同一条路），快照 ap 值
## 因此与实际存档一致。
func _apply_ap(p_current: int) -> void:
	var max_ap: int = maxi(int(GameStateManager.exploration.get("max_action_points", 10)), 1)
	GameStateManager.call(&"set_exploration_ap", p_current, max_ap)
	var snapshot: Dictionary = (screen.get("_current_snapshot") as Dictionary).duplicate(true)
	snapshot["ap_remaining"] = p_current
	screen._on_map_generated(MAP_ID, snapshot)


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
