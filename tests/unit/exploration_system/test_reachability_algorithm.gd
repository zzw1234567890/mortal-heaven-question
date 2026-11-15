extends GutTest
## 抵达 Boss 的最短路（纯算法） —— 最短路确实是最少花费。[br]
## [br][b]本文件补的断链[/b]：系统里此前没有任何地方回答得了「还走不走得到 Boss」
## ——[code]can_move_to_detail[/code] 只判一步邻接，[code]end_exploration[/code]
## 只看入参。于是行动力见底时玩家既没有提示也没有出口（GDD
## exploration-system.md §5「行动力归零且无法到达Boss → 立即结算」与 §8「退出按钮
## 在探索HUD中始终可用」两条都缺一个可判定的输入）。[br]
## [br][b]覆盖[/b]——算法部分（系统口径见 [code]test_boss_reachability.gd[/code]）：[br]
##   1. 最短路确实是最少花费（两条路开销不同时取便宜的那条、绕路不被选中）；[br]
##   2. [b]按本图配置算[/b]——[code]ap_cost[/code] 与按类型覆盖（[code]ap_costs[/code]）
##      都要生效（数步数会在此处失手）；[br]
##   3. [b]豁免类型恒为 0[/b]——Boss / 传送 / 灵泉不花行动力，站在 Boss 上时为 0
##      （GDD §8「行动力归零但已在Boss节点 → 可挑战Boss」）；[br]
##   4. 已访问节点算障碍；走不到时给哨兵而不是假答案。[br]
##
## 来源: design/gdd/exploration-system.md §4 移动规则 / §5 结束条件 / §8 边界、
## design/gdd/action-point-system.md §公式 2/3、ADR-0014 §关键接口。

const Reach := preload("res://src/feature/exploration/exploration_reachability.gd")

## 节点 ID（编码 layer * 100 + idx）。
const ENTRY: int = 0
const COMBAT_A: int = 100
const COMBAT_B: int = 110
const EVENT: int = 200
const BOSS: int = 300

## Boss 类型值（与 [code]ExplorationSystem.NodeType.BOSS[/code] 同源）。
const TYPE_BOSS: int = 3


func test_pure_algorithm_takes_the_cheaper_of_two_paths() -> void:
	## 上支 2 步、下支 1 步（下支经豁免的传送）——最短路必须报便宜的那条。
	# Arrange——入口 →（100 战斗 → 200 战斗 → 300 Boss）／（110 传送 → 300 Boss）
	var graph: Dictionary = {
		ENTRY: [COMBAT_A, COMBAT_B],
		COMBAT_A: [EVENT],
		EVENT: [BOSS],
		COMBAT_B: [BOSS],
		BOSS: [],
	}
	var details: Dictionary = {
		ENTRY: {"type": 0},
		COMBAT_A: {"type": 1},
		EVENT: {"type": 4},
		COMBAT_B: {"type": 6},   # 传送——豁免
		BOSS: {"type": TYPE_BOSS},
	}
	# Act——本图开销 1
	var cost: int = Reach.min_ap_to_any(graph, details, {"ap_cost": 1},
			ENTRY, [], [TYPE_BOSS])
	# Assert——下支：传送 0（豁免）+ Boss 0（豁免）= 0，比上支的 2 便宜
	assert_eq(cost, 0, "最短路应取豁免支（0 花费），不是节点更少的那条")


func test_pure_algorithm_counts_steps_when_nothing_is_exempt() -> void:
	# Arrange——一条无豁免的线性图：0 → 100 → 200 → 300
	var graph: Dictionary = {ENTRY: [COMBAT_A], COMBAT_A: [EVENT], EVENT: [BOSS], BOSS: []}
	var details: Dictionary = {
		ENTRY: {"type": 0}, COMBAT_A: {"type": 1},
		EVENT: {"type": 4}, BOSS: {"type": TYPE_BOSS},
	}
	# Act / Assert——三次移动，每次 1 点
	assert_eq(Reach.min_ap_to_any(graph, details, {"ap_cost": 1}, ENTRY, [], [TYPE_BOSS]),
			2, "0→100→200→300：进 100 与进 200 花钱，进 Boss 豁免 → 2")


func test_pure_algorithm_respects_map_cost_not_step_count() -> void:
	## 本图开销 2（GDD §调优参数安全范围 1-2）——数步数会给出一个玩家付不起的答案。
	# Arrange
	var graph: Dictionary = {ENTRY: [COMBAT_A], COMBAT_A: [EVENT], EVENT: [BOSS], BOSS: []}
	var details: Dictionary = {
		ENTRY: {"type": 0}, COMBAT_A: {"type": 1},
		EVENT: {"type": 4}, BOSS: {"type": TYPE_BOSS},
	}
	# Act
	var cost: int = Reach.min_ap_to_any(graph, details, {"ap_cost": 2}, ENTRY, [], [TYPE_BOSS])
	# Assert——2 步花钱（100 与 200 各 2 点）= 4，不是 2
	assert_eq(cost, 4, "开销 2 时两步要 4 点（数步数会错报 2）")


func test_pure_algorithm_respects_per_type_override() -> void:
	# Arrange——默认 1，战斗节点被覆盖成 5
	var graph: Dictionary = {ENTRY: [COMBAT_A], COMBAT_A: [BOSS], BOSS: []}
	var details: Dictionary = {ENTRY: {"type": 0}, COMBAT_A: {"type": 1}, BOSS: {"type": TYPE_BOSS}}
	# Act
	var cost: int = Reach.min_ap_to_any(graph, details, {"ap_cost": 1, "ap_costs": {1: 5}},
			ENTRY, [], [TYPE_BOSS])
	# Assert
	assert_eq(cost, 5, "按类型覆盖生效（与 move_to_node 的扣费同一份解析）")


func test_pure_algorithm_treats_blocked_nodes_as_walls() -> void:
	## 已访问节点是障碍——[code]move_to_node[/code] 拒绝进入，把它们算进路径
	## 等于承诺一条玩家点不动的路线。
	# Arrange——唯一通路要经过 200，而 200 已访问
	var graph: Dictionary = {ENTRY: [COMBAT_A], COMBAT_A: [EVENT], EVENT: [BOSS], BOSS: []}
	var details: Dictionary = {
		ENTRY: {"type": 0}, COMBAT_A: {"type": 1},
		EVENT: {"type": 4}, BOSS: {"type": TYPE_BOSS},
	}
	# Act / Assert——封住 200 后无路可走
	assert_eq(Reach.min_ap_to_any(graph, details, {"ap_cost": 1},
			ENTRY, [EVENT], [TYPE_BOSS]), Reach.UNREACHABLE,
			"唯一通路被已访问节点截断时应报走不到")
	# 对照——不封 200 时走得通（防「一律返回哨兵」的假通过）
	assert_eq(Reach.min_ap_to_any(graph, details, {"ap_cost": 1},
			ENTRY, [], [TYPE_BOSS]), 2, "不封路时应报得出花费")


func test_pure_algorithm_returns_zero_when_standing_on_the_target() -> void:
	# Arrange——已在 Boss 节点上
	var graph: Dictionary = {BOSS: []}
	var details: Dictionary = {BOSS: {"type": TYPE_BOSS}}
	# Act / Assert——GDD §8：行动力归零但已在 Boss → 可挑战，无需再花行动力
	assert_eq(Reach.min_ap_to_any(graph, details, {"ap_cost": 1}, BOSS, [], [TYPE_BOSS]),
			0, "站在 Boss 上应为 0（不是「一步都没走所以 -1」）")


func test_pure_algorithm_reports_unreachable_without_guessing() -> void:
	# Arrange——目标不在图里 / 出发节点不在图里 / 目标类型集为空
	var graph: Dictionary = {ENTRY: [COMBAT_A], COMBAT_A: [], BOSS: []}
	var details: Dictionary = {ENTRY: {"type": 0}, COMBAT_A: {"type": 1}, BOSS: {"type": TYPE_BOSS}}
	# Assert——三条都得哨兵，不给「0 点也能到」这种假答案
	assert_eq(Reach.min_ap_to_any(graph, details, {}, COMBAT_A, [], [TYPE_BOSS]),
			Reach.UNREACHABLE, "图里没有通往 Boss 的路 → 哨兵")
	assert_eq(Reach.min_ap_to_any(graph, details, {}, 999, [], [TYPE_BOSS]),
			Reach.UNREACHABLE, "出发节点不在图里 → 哨兵")
	assert_eq(Reach.min_ap_to_any(graph, details, {}, ENTRY, [], []),
			Reach.UNREACHABLE, "目标类型集为空 → 哨兵（不把「任何节点」当目标）")
	assert_eq(Reach.UNREACHABLE, -1, "哨兵值与调用方的约定一致")


func test_pure_algorithm_ignores_unvisited_detours() -> void:
	## 环与绕路不该让花费变大——最短路只报最少花费。
	# Arrange——入口直通 Boss（豁免 0），另有一条绕远的三步路
	var graph: Dictionary = {ENTRY: [BOSS, COMBAT_A], COMBAT_A: [EVENT], EVENT: [BOSS], BOSS: []}
	var details: Dictionary = {
		ENTRY: {"type": 0}, COMBAT_A: {"type": 1},
		EVENT: {"type": 4}, BOSS: {"type": TYPE_BOSS},
	}
	# Act / Assert
	assert_eq(Reach.min_ap_to_any(graph, details, {"ap_cost": 1}, ENTRY, [], [TYPE_BOSS]),
			0, "直连 Boss 时花费 0（绕路那条不该被选中）")
