extends "res://tests/unit/exploration_system/boss_reachability_fixture.gd"
## 抵达 Boss 的行动力最短路（系统口径） —— 判定与扣费同一把尺。[br]
## [br][b]本文件补的断链[/b]：系统里此前没有任何地方回答得了「还走不走得到 Boss」
## ——[code]can_move_to_detail[/code] 只判一步邻接，[code]end_exploration[/code]
## 只看入参。于是行动力见底时玩家既没有提示也没有出口（GDD
## exploration-system.md §5「行动力归零且无法到达Boss → 立即结算」与 §8「退出按钮
## 在探索HUD中始终可用」两条都缺一个可判定的输入）。[br]
## [br][b]覆盖[/b]——系统口径（纯算法见
## [code]test_reachability_algorithm.gd[/code]）：[br]
##   1. [code]min_ap_to_boss[/code] 报要花多少、[code]can_still_reach_boss[/code]
##      答够不够，起点取自 GSM 的 node_position、已访问集合算障碍；[br]
##   2. [b]与真实扣费一致[/b]——判定说够就真的走得过去，且扣完正好见底；[br]
##   3. DAG 未就绪时不给假答案（ADR-0014 R7 守卫）。[br]
## [br][b]装置[/b]见 [code]boss_reachability_fixture.gd[/code]（固定 DAG + GSM 隔离）。
##
## 来源: design/gdd/exploration-system.md §4 移动规则 / §5 结束条件 / §8 边界、
## design/gdd/action-point-system.md §公式 2/3、ADR-0014 §关键接口 / R7。


func test_system_reports_cost_to_boss_from_current_position() -> void:
	# Arrange——线性图，站在入口
	_setup_dag()
	_stand_on(ENTRY)
	# Act / Assert——0→100→200→300：进 100 花 1、进 200 花 1、进 Boss 豁免
	assert_eq(es.call(&"min_ap_to_boss"), 2, "从入口到 Boss 应报 2 点")


func test_system_reports_zero_when_on_boss() -> void:
	# Arrange——站在 Boss 节点上
	_setup_dag()
	_stand_on(BOSS)
	# Act / Assert
	assert_eq(es.call(&"min_ap_to_boss"), 0, "已在 Boss 上应报 0")
	assert_eq(es.call(&"can_still_reach_boss"), true, "AP=0 且已在 Boss → 仍可挑战（GDD §8）")


func test_can_still_reach_boss_follows_remaining_ap() -> void:
	# Arrange——走到事件节点（还剩最后一步到 Boss，且那一步豁免）
	_setup_dag()
	_stand_on(EVENT)
	_visit([ENTRY, COMBAT_A, EVENT])
	# Act / Assert——AP=0 也够（Boss 豁免），不会把玩家误判成走投无路
	_set_ap(0)
	assert_eq(es.call(&"can_still_reach_boss"), true,
			"下一格是豁免的 Boss → AP=0 也走得到（GDD §8 反过来也成立）")


func test_can_still_reach_boss_false_when_ap_is_short() -> void:
	# Arrange——站在入口，前面还有两格非豁免（共 2 点）
	_setup_dag()
	_stand_on(ENTRY)
	_set_ap(1)
	# Act / Assert
	assert_eq(es.call(&"min_ap_to_boss"), 2, "前置：还差 2 点")
	assert_eq(es.call(&"can_still_reach_boss"), false, "只剩 1 点 → 走不到，应报 false")


func test_verdict_matches_the_actual_move_that_consumes_ap() -> void:
	## 判定与扣费同口径——「说够」就要真的走得过去、且扣完正好见底。
	# Arrange——从入口出发需要 2 点
	_setup_dag()
	_stand_on(ENTRY)
	_set_ap(2)
	assert_eq(es.call(&"can_still_reach_boss"), true, "前置：2 点判定为够")
	# Act——真的走完这条最短路
	assert_eq(es.call(&"move_to_node", ENTRY, COMBAT_A)["success"], true, "第一跳")
	assert_eq(es.call(&"move_to_node", COMBAT_A, EVENT)["success"], true, "第二跳")
	var last: Dictionary = es.call(&"move_to_node", EVENT, BOSS)
	# Assert——Boss 豁免，扣完恰好为 0；此时仍在 Boss 上，判定依旧为 true
	assert_eq(last["success"], true, "最后一跳（Boss 豁免）应成功")
	assert_eq(_ap(), 0, "两次非豁免移动扣完正好见底")
	assert_eq(es.call(&"can_still_reach_boss"), true, "已抵达 Boss → 仍为 true")


func test_unreachable_when_dag_is_not_ready() -> void:
	# Arrange——DAG 缓存未就绪（ADR-0014 R7 守卫）
	_setup_dag()
	es.set("_dag_ready", false)
	# Act / Assert——无法作答时不给假答案
	assert_eq(es.call(&"min_ap_to_boss"), Reach.UNREACHABLE, "未就绪 → 哨兵")
	assert_eq(es.call(&"can_still_reach_boss"), false, "未就绪 → 不承诺「还能通关」")


func test_current_position_follows_gsm_node_position() -> void:
	## 起点取自 GSM 的层/位反解——与 [code]move_to_node[/code] 的写入同一编码。
	# Arrange
	_setup_dag()
	_stand_on(EVENT)
	_visit([ENTRY, COMBAT_A, EVENT])
	# Act / Assert——站在事件节点（第 2 层 0 号）时只剩豁免的最后一跳
	assert_eq(es.call(&"min_ap_to_boss"), 0, "站在 200 时到 Boss 的花费为 0")


func test_visited_nodes_are_not_counted_as_a_route() -> void:
	## 已访问节点在系统口径里同样是障碍（与 [code]move_to_node[/code] 的验证 2 一致）。
	# Arrange——把唯一的中转点 100 记成已访问
	_setup_dag()
	_stand_on(ENTRY)
	_visit([ENTRY, COMBAT_A])
	# Act / Assert
	assert_eq(es.call(&"min_ap_to_boss"), Reach.UNREACHABLE,
			"唯一中转点已访问 → 走不到（不能承诺一条点不动的路线）")
	assert_eq(es.call(&"can_still_reach_boss"), false, "同上")
