extends GutTest
## 抵达某种节点（如 Boss）的最少行动力 —— [b]纯算法[/b]（本轮改为直达距离）。[br]
##
## [b]本文件补的断链[/b]：系统里此前没有任何地方回答得了「还走不走得到 Boss」
## ——[code]can_move_to_detail[/code] 只判一步邻接，[code]end_exploration[/code]
## 只看入参。于是行动力见底时玩家既没有提示也没有出口（GDD
## exploration-system.md §5「行动力归零且无法到达Boss → 立即结算」与 §8「退出按钮
## 在探索HUD中始终可用」两条都缺一个可判定的输入）。[br]
##
## [br][b]★ 本轮语义变更（有意改动，报告单列）★[/b]：全连通之后「沿边搜索」这套口径
## 整体作废（老板 2026-11-27 18:40：「每个节点之间都可达，只是消耗的行动力不一样」）。
## 旧口径的三个前提本轮都不成立：[br]
##   · 「不相邻即不可达」→ 任何节点都可达，只有消耗不同；[br]
##   · 「已访问节点是墙」→ 已访问可以重入；[br]
##   · 「花费 = 路径上各格之和」→ 花费 = 一次直达移动的距离定价。[br]
## 故旧断言里的「绕路更便宜 / 已访问当墙 / 按 ap_cost 计步 / 按类型覆盖」都改写成新
## 口径，而[b]数据层的边表与邻接图测试一条未动[/b]（任务书硬约束）。[br]
##
## [br][b]覆盖[/b]——算法部分（系统口径见 [code]test_boss_reachability.gd[/code]）：[br]
##   1. 取[b]最近[/b]的那个目标类型节点（多个 Boss 时玩家会挑近的）；[br]
##   2. 花费由距离定价给出——与 [code]move_to_node[/code] 的扣费同一份解析；[br]
##   3. 豁免类型恒为 0——站在 Boss 上时为 0（GDD §8）；[br]
##   4. 走不到时给哨兵而不是假答案。[br]
##
## 来源: 本轮任务书追加规则（全连通 + 距离定价 + 测试改法）、
## design/gdd/exploration-system.md §4 移动规则 / §5 结束条件 / §8 边界、
## design/gdd/action-point-system.md §公式 2/3、ADR-0014 §关键接口。

const Reach := preload("res://src/feature/exploration/exploration_reachability.gd")
const ApRules := preload("res://src/feature/exploration/exploration_ap_rules.gd")
const Geometry := preload("res://src/feature/exploration/exploration_node_geometry.gd")

## 节点 ID（编码 layer * 100 + idx）。
const ENTRY: int = 0
const COMBAT_A: int = 100
const EVENT: int = 200
const BOSS: int = 300
## 单调性那条用的三个战斗节点（层 1 / 2 / 5 的第 0 格）。
const NEAR: int = 100
const MID: int = 200
const FAR: int = 500

## 节点类型（与 [code]ExplorationSystem.NodeType[/code] 同源）。
const TYPE_COMBAT: int = 1
const TYPE_BOSS: int = 3
const TYPE_EVENT: int = 4


func test_pure_algorithm_charges_the_nearest_target_by_distance() -> void:
	## 同层隔一格（距离 = NODE_GAP）——花费由「直达距离」算出，与扣费同一份解析。
	# Arrange
	var graph: Dictionary = {ENTRY: [], COMBAT_A: []}
	var details: Dictionary = {
		ENTRY: {"type": 0, "layer": 0, "idx": 0},
		COMBAT_A: {"type": TYPE_COMBAT, "layer": 0, "idx": 1},
	}
	# Act
	var cost: int = Reach.min_ap_to_any(graph, details, {}, ENTRY, [TYPE_COMBAT])
	# Assert
	assert_eq(cost, ApRules.cost_for_move({}, details[ENTRY], details[COMBAT_A],
			Geometry.layer_counts(details)), "应报直达距离算出的花费")
	assert_eq(cost, ApRules.cost_by_distance({}, TYPE_COMBAT, Geometry.NODE_GAP),
			"同层隔一格的标定值（%.0fpx / 单位距离 → 2）" % Geometry.NODE_GAP)


func test_pure_algorithm_takes_the_cheaper_of_several_targets() -> void:
	## 两个同类型节点：近的（同层隔一格）与远的（第 2 层）——玩家会挑近的那个去，
	## 报远处会把花费报高。
	# Arrange
	var graph: Dictionary = {ENTRY: [], NEAR: [], FAR: []}
	var details: Dictionary = {
		ENTRY: {"type": 0, "layer": 0, "idx": 0},
		NEAR: {"type": TYPE_EVENT, "layer": 0, "idx": 1},
		FAR: {"type": TYPE_EVENT, "layer": 4, "idx": 0},
	}
	# Act
	var cost: int = Reach.min_ap_to_any(graph, details, {}, ENTRY, [TYPE_EVENT])
	# Assert——近的那个更便宜，且等于它的直达花费
	var near_cost: int = ApRules.cost_for_move({}, details[ENTRY], details[NEAR],
			Geometry.layer_counts(details))
	var far_cost: int = ApRules.cost_for_move({}, details[ENTRY], details[FAR],
			Geometry.layer_counts(details))
	assert_true(near_cost < far_cost, "前置：远的那一个更贵（否则本条测不出「取近的」）")
	assert_eq(cost, near_cost, "应取最近的那个目标节点的花费")


func test_pure_algorithm_charges_by_distance_not_by_step_count() -> void:
	## 花费随距离单调不减，且被单次上限夹住（不是「路径上各格之和」——全连通之后
	## 根本没有「路径」这回事）。
	# Arrange——入口 + 层 1 / 2 / 5 三个战斗节点（各自独占一层，层计数全为 1）
	## [b]每档的边表只列该档真正存在的节点[/b]：边表是「本图有哪些节点」的权威定义，
	## 而详情缺 [code]type[/code] 时 [_type_of] 会兜底成战斗（COMBAT）——若造一个
	## 「边表里有、详情里没有」的幽灵键，它会以距离 0 的花费 1 赢得「取最小」，
	## 断言就测不到真正的那个目标了（本轮第一版夹具正是这么写错的）。
	var entry_detail: Dictionary = {"type": 0, "layer": 0, "idx": 0}
	var near_detail: Dictionary = {"type": TYPE_COMBAT, "layer": 1, "idx": 0}
	var mid_detail: Dictionary = {"type": TYPE_COMBAT, "layer": 2, "idx": 0}
	var far_detail: Dictionary = {"type": TYPE_COMBAT, "layer": 5, "idx": 0}
	var counts: Dictionary = Geometry.layer_counts({ENTRY: entry_detail,
			NEAR: near_detail, MID: mid_detail, FAR: far_detail})
	# Act——逐档只留一个目标，看花费怎么走
	var near: int = Reach.min_ap_to_any({ENTRY: [], NEAR: []},
			{ENTRY: entry_detail, NEAR: near_detail}, {}, ENTRY, [TYPE_COMBAT])
	var mid: int = Reach.min_ap_to_any({ENTRY: [], MID: []},
			{ENTRY: entry_detail, MID: mid_detail}, {}, ENTRY, [TYPE_COMBAT])
	var far: int = Reach.min_ap_to_any({ENTRY: [], FAR: []},
			{ENTRY: entry_detail, FAR: far_detail}, {}, ENTRY, [TYPE_COMBAT])
	# Assert——每一档都等于该节点自身的直达花费（不是「步数」，也不是别档的值）
	assert_eq(near, ApRules.cost_for_move({}, entry_detail, near_detail, counts),
			"只剩层 1 那个时按它的直达距离算")
	assert_eq(mid, ApRules.cost_for_move({}, entry_detail, mid_detail, counts),
			"只剩层 2 那个时按它的直达距离算")
	assert_eq(far, ApRules.cost_for_move({}, entry_detail, far_detail, counts),
			"只剩层 5 那个时按它的直达距离算")
	# 单调不减：越远越贵（上限之内）
	assert_true(mid >= near, "层 2 不比层 1 便宜：%d → %d" % [near, mid])
	assert_true(far >= mid, "层 5 不比层 2 便宜：%d → %d" % [mid, far])
	# 上限生效：层 5 的实际距离超过上限所值的距离，按上限收（不是无限增长）
	var far_px: float = Geometry.distance_between(entry_detail, far_detail, counts)
	assert_true(far_px / ApRules.DEFAULT_DISTANCE_UNIT > float(ApRules.DEFAULT_MOVE_MAX),
			"前置：层 5 的原始比值（%.2f）应超过上限 %d，否则本条测不出「夹住」"
			% [far_px / ApRules.DEFAULT_DISTANCE_UNIT, ApRules.DEFAULT_MOVE_MAX])
	assert_eq(far, ApRules.DEFAULT_MOVE_MAX, "超过单次上限的距离按上限收")
	assert_true(ApRules.cost_by_distance({}, TYPE_COMBAT, 2.0 * Geometry.LAYER_GAP)
			> ApRules.cost_by_distance({}, TYPE_COMBAT, 1.0 * Geometry.LAYER_GAP),
			"上限之内的两档应看得出贵贱（否则上面的「按上限收」是巧合）")


func test_pure_algorithm_returns_zero_when_standing_on_the_target() -> void:
	# Arrange——已在 Boss 节点上
	var graph: Dictionary = {BOSS: []}
	var details: Dictionary = {BOSS: {"type": TYPE_BOSS, "layer": 0, "idx": 0}}
	# Act / Assert——GDD §8：行动力归零但已在 Boss → 可挑战，无需再花行动力
	assert_eq(Reach.min_ap_to_any(graph, details, {}, BOSS, [TYPE_BOSS]), 0,
			"站在 Boss 上应为 0（不是「一步都没走所以 -1」）")


func test_pure_algorithm_reports_unreachable_without_guessing() -> void:
	# Arrange——目标类型在图里不存在 / 出发节点不在图里 / 目标类型集为空
	var graph: Dictionary = {ENTRY: [], COMBAT_A: [], BOSS: []}
	var details: Dictionary = {
		ENTRY: {"type": 0, "layer": 0, "idx": 0},
		COMBAT_A: {"type": TYPE_COMBAT, "layer": 1, "idx": 0},
		BOSS: {"type": 6, "layer": 2, "idx": 0},
	}
	# Assert——三条都得哨兵，不给「0 点也能到」这种假答案
	assert_eq(Reach.min_ap_to_any(graph, details, {}, COMBAT_A, [TYPE_BOSS]),
			Reach.UNREACHABLE, "图里没有 Boss 类型的节点 → 哨兵")
	assert_eq(Reach.min_ap_to_any(graph, details, {}, 999, [TYPE_BOSS]),
			Reach.UNREACHABLE, "出发节点不在图里 → 哨兵")
	assert_eq(Reach.min_ap_to_any(graph, details, {}, ENTRY, []),
			Reach.UNREACHABLE, "目标类型集为空 → 哨兵（不把「任何节点」当目标）")
	assert_eq(Reach.UNREACHABLE, -1, "哨兵值与调用方的约定一致")


func test_pure_algorithm_finds_target_even_when_not_adjacent() -> void:
	## ★ 新口径的核心：目标不在邻接表里也照样可达（只是消耗按距离算）★
	## [br][b]改前红[/b]：旧口径沿边搜索，[code]ENTRY[/code] 的出边为空 → 返回哨兵。
	# Arrange——入口的出边是空的，而图里存在远处的节点
	var graph: Dictionary = {ENTRY: [], EVENT: []}
	var details: Dictionary = {
		ENTRY: {"type": 0, "layer": 0, "idx": 0},
		EVENT: {"type": TYPE_EVENT, "layer": 2, "idx": 0},
	}
	# Act
	var cost: int = Reach.min_ap_to_any(graph, details, {}, ENTRY, [TYPE_EVENT])
	# Assert——算得出正数花费，而不是哨兵
	assert_true(cost >= 1, "不相邻的普通节点同样可达（按距离付费），实为 %d" % cost)
	assert_eq(cost, ApRules.cost_for_move({}, details[ENTRY], details[EVENT],
			Geometry.layer_counts(details)), "花费按直达距离算（与扣费同源）")


func test_pure_algorithm_ignores_visited_nodes_as_obstacles() -> void:
	## ★ 已访问节点不再是墙 ★（本轮起可重入，「已访问当墙」会给出玩家做得到的假拒绝）。
	## [br][b]改前红[/b]：旧口径把已访问节点排除在搜索之外，唯一通路被它截断时报哨兵。
	##  [br][b]签名层面**：旧签名的第 5 个参数（[code]p_blocked[/code]）本轮整体移除——
	## 「永远传空数组的参数」比没有参数更危险（下一个人会以为它有意义），故这里断言的
	## 是「答案与访问状态无关」这件事本身。
	# Arrange——同层两个节点，其中一个「已经走过」
	var graph: Dictionary = {ENTRY: [], COMBAT_A: []}
	var details: Dictionary = {
		ENTRY: {"type": 0, "layer": 0, "idx": 0},
		COMBAT_A: {"type": TYPE_COMBAT, "layer": 0, "idx": 1},
	}
	# Act
	var cost: int = Reach.min_ap_to_any(graph, details, {}, ENTRY, [TYPE_COMBAT])
	# Assert——可达性判定与「谁被访问过」无关（已访问可重入、消耗照算）
	assert_eq(cost, ApRules.cost_by_distance({}, TYPE_COMBAT, Geometry.NODE_GAP),
			"目标可达性与「谁被访问过」无关（已访问可重入）")
