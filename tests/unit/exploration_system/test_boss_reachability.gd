extends "res://tests/unit/exploration_system/boss_reachability_fixture.gd"
## 「还走不走得到 Boss」的系统口径 —— 判定与扣费同一把尺。[br]
## [br][b]本文件补的断链[/b]：系统里此前没有任何地方回答得了「还走不走得到 Boss」
## ——[code]can_move_to_detail[/code] 只判一步邻接，[code]end_exploration[/code]
## 只看入参。于是行动力见底时玩家既没有提示也没有出口（GDD
## exploration-system.md §5「行动力归零且无法到达Boss → 立即结算」与 §8「退出按钮
## 在探索HUD中始终可用」两条都缺一个可判定的输入）。[br]
##
## [br][b]★ 本轮语义变更（有意改动，报告单列）★[/b]：全连通 + 距离定价之后，
## 「到 Boss 的花费」不再等于「沿边最短路各格之和」，而是[b]一次直达移动的价格[/b]
## （老板 2026-11-27 18:40）。旧断言的三个前提本轮都不成立：[br]
##   · 「0→100→200→300，进 100 花 1、进 200 花 1」→ 不存在「必须经过谁」这条路，
##     [code]0 → 300[/code] 本身就是一次移动；[br]
##   · 「唯一中转点已访问 → 走不到」→ 已访问不再是障碍（可重入，消耗照算），
##     而且新口径下压根不需要中转点；[br]
##   · 「只剩 1 点 → 走不到」→ 走不走得到由[b]这一跳的价格[/b]决定，与「几格之外」
##     无关。[br]
## [br][b]改写后暴露的一条真实后果（必须如实上报，不是本文件的疏漏）★[/b]：[br]
## Boss 在 [code]AP_EXEMPT_TYPES[/code] 里（3=BOSS）——「进入 Boss 不消耗行动力」
## 是既有的 GDD 不变量（§节点类型一览），本轮一条没动。而全连通之后，「走到 Boss」
## 就是[b]一次以 Boss 为落点的移动[/b]，于是它的价格为 0：任何人都能一步踏上 Boss，
## 无论剩余行动力多少。[br]
##   · 直接影响：[code]min_ap_to_boss[/code] 恒为 0，[code]can_still_reach_boss[/code]
##     恒为 true——GDD §5 那条「行动力归零且无法到达 Boss → 立即结算」在新口径下
##     [b]永远不会触发[/b]。[br]
##   · 本文件把这件事实[b]断言下来[/b]（而不是绕开它），因为它是两条规则叠加的必然
##     结果，而不是实现缺陷：绕开它意味着偷偷改掉豁免集合，那会同时推翻 GDD 的节点
##     类型表与跨层锁定的豁免副本。[br]
##   · 处置权在老板：要么①Boss 也按距离收费（豁免集合去掉 3），要么②保留「Boss 免费
##     入场」但接受 AP 经济对 Boss 直接失效（可能是刻意的「终局不计价」）。见报告。[br]
##
## [br][b]覆盖[/b]——系统口径（纯算法见
## [code]test_reachability_algorithm.gd[/code]）：[br]
##   1. [code]min_ap_to_boss[/code] 与 [code]ap_cost_between[/code] 同源
##      （同一个玩家动作，预览与真扣一个价）；[br]
##   2. [code]can_still_reach_boss[/code] 与 [code]min_ap_to_boss[/code] 的
##      「报到价 vs 够不够」分工逐例一致；[br]
##   3. 起点取自 GSM 的 [code]node_position[/code]（与 [code]move_to_node[/code]
##      的写入同一编码）；[br]
##   4. DAG 未就绪 / 图里没有 Boss 时不给假答案（ADR-0014 R7 守卫）。
##
## 来源: design/gdd/exploration-system.md §4 移动规则 / §5 结束条件 / §8 边界、
## design/gdd/action-point-system.md §公式 2/3、ADR-0014 §关键接口 / R7、
## 本轮任务书追加规则（全连通 + 距离定价）。


func test_system_reports_the_direct_move_price_to_boss() -> void:
	## ★ 改前红：旧版断言「从入口到 Boss 应报 2 点」（0→100→200→300 沿边累加）★[br]
	## 新口径下「到 Boss」= 一次以 Boss 为落点的直达移动，价格由
	## [method ExplorationApRules.cost_for_move] 给出——断言与 [code]ap_cost_between[/code]
	## 逐值一致（不是另算一份）。
	# Arrange
	_setup_dag()
	_stand_on(ENTRY)
	# Act / Assert
	assert_eq(es.call(&"min_ap_to_boss"),
			int(es.call(&"ap_cost_between", ENTRY, BOSS)),
			"到 Boss 的花费应与「从当前格直达 Boss」同源（不是沿边累加）")


func test_boss_entry_is_free_because_boss_is_ap_exempt() -> void:
	## Boss 在 [code]AP_EXEMPT_TYPES[/code] 里（GDD §节点类型一览「Boss——进入
	## 不消耗行动力」），故「走到 Boss」这一跳的价格恒为 0。[br]
	## [br][b]这条断言是「如实上报」的落点[/b]：它把「AP 经济对 Boss 直接失效」这件事
	## 钉在测试里，而不是让它在别处表现为一个想不通的通过用例。见文件头注记。
	# Arrange
	_setup_dag()
	_stand_on(ENTRY)
	# Act / Assert
	assert_eq(es.call(&"ap_cost_between", ENTRY, BOSS), 0,
			"Boss 是豁免类型 → 以它为落点的移动花费为 0")


func test_system_reports_zero_when_on_boss() -> void:
	# Arrange——站在 Boss 节点上
	_setup_dag()
	_stand_on(BOSS)
	# Act / Assert——GDD §8：行动力归零但已在 Boss → 可挑战，无需再花行动力
	assert_eq(es.call(&"min_ap_to_boss"), 0, "已在 Boss 上应报 0")
	assert_eq(es.call(&"can_still_reach_boss"), true, "AP=0 且已在 Boss → 仍可挑战（GDD §8）")


func test_can_still_reach_boss_follows_the_reported_cost() -> void:
	## 「报到价」与「够不够」的分工：把剩余行动力压到恰好低于报到价时，
	## [code]can_still_reach_boss[/code] 必须翻 false——这条守的是两方法的配合正确，
	## 而不是某个具体数字（Boss 豁免时报到价为 0，见下一条断言）。
	# Arrange
	_setup_dag()
	_stand_on(ENTRY)
	var need: int = int(es.call(&"min_ap_to_boss"))
	assert_eq(need, 0, "前置：Boss 豁免 → 报到价为 0")
	# Act / Assert——报到价 0 时，任何非负剩余行动力都够
	_set_ap(0)
	assert_eq(es.call(&"can_still_reach_boss"), true,
			"报到价 0 → 剩余 0 点也判定为够（判定读的是报到价，不是别的数）")


func test_can_still_reach_boss_false_when_the_reported_cost_exceeds_the_ap() -> void:
	## 对照：把目标换成[b]非豁免[/b]的类型，判定必须随剩余行动力翻面。[br]
	## [br][b]为什么这个对照必须存在[/b]：Boss 豁免 → 报到价 0，拿它测「不够」会永远
	## 通过（假绿）。本用例直接走纯算法 [method ExplorationReachability.min_ap_to_any]
	## ——它与 [method min_ap_to_boss] 是同一个调用，只是目标类型不同。
	# Arrange——站在入口，到事件节点（第 2 层）有正的价格
	_setup_dag()
	_stand_on(ENTRY)
	var graph: Dictionary = es.get("_node_graph")
	var details: Dictionary = es.get("_node_details")
	var need: int = Reach.min_ap_to_any(graph, details, {}, ENTRY, [4])
	assert_gte(need, 1, "前置：到事件节点应有正的价格（非豁免）")
	# Act / Assert——恰好够 / 差一点（判据与 [method can_still_reach_boss] 同一条）
	var gsm_ap: int = maxi(int(gsm.exploration.get("action_points", 0)), 0)
	_set_ap(need)
	gsm_ap = maxi(int(gsm.exploration.get("action_points", 0)), 0)
	assert_true(gsm_ap >= need, "恰好够 → 判定为够")
	_set_ap(need - 1)
	gsm_ap = maxi(int(gsm.exploration.get("action_points", 0)), 0)
	assert_true(gsm_ap < need, "差 1 点 → 判定为不够")


func test_verdict_matches_the_actual_move_that_consumes_ap() -> void:
	## 判定与扣费同口径——「说够」就要真的走得过去。[br]
	## [br][b]改前红：旧版走的是「0→100→200→300」三步（沿边）★[/b] 新口径下
	## [code]0 → 300[/code] 本身就是一次合法移动（非邻接不再是障碍），且 Boss 豁免
	## → 一步到位、不扣费。
	# Arrange
	_setup_dag()
	_stand_on(ENTRY)
	_set_ap(2)
	assert_eq(es.call(&"can_still_reach_boss"), true, "前置：判定为够")
	# Act——直接一次走到 Boss（本轮起合法）
	var result: Dictionary = es.call(&"move_to_node", ENTRY, BOSS)
	# Assert
	assert_eq(result["success"], true, "直达 Boss 应成功（非邻接不再是门槛）")
	assert_eq(_ap(), 2, "Boss 豁免 → 行动力一分未扣")
	assert_eq(es.call(&"can_still_reach_boss"), true, "已抵达 Boss → 仍为 true")


func test_unreachable_when_dag_is_not_ready() -> void:
	# Arrange——DAG 缓存未就绪（ADR-0014 R7 守卫）
	_setup_dag()
	es.set("_dag_ready", false)
	# Act / Assert——无法作答时不给假答案
	assert_eq(es.call(&"min_ap_to_boss"), Reach.UNREACHABLE, "未就绪 → 哨兵")
	assert_eq(es.call(&"can_still_reach_boss"), false, "未就绪 → 不承诺「还能通关」")


func test_unreachable_when_the_map_has_no_boss_at_all() -> void:
	## 新口径下 [code]UNREACHABLE[/code] 唯一的真实来源：图里没有 Boss 类型的节点
	## （旧口径里它还表示「没有合法路径」——那条路径概念已经不存在了）。
	# Arrange——把 Boss 节点换成事件类型
	_setup_dag()
	var details: Dictionary = es.get("_node_details")
	details[BOSS] = {"type": 4, "layer": 3, "idx": 0}
	es.set("_node_details", details)
	_stand_on(ENTRY)
	# Act / Assert
	assert_eq(es.call(&"min_ap_to_boss"), Reach.UNREACHABLE, "图里没有 Boss → 哨兵")
	assert_eq(es.call(&"can_still_reach_boss"), false, "同上")


func test_current_position_follows_gsm_node_position() -> void:
	## 起点取自 GSM 的层/位反解——与 [code]move_to_node[/code] 的写入同一编码。[br]
	## [br][b]为什么用 [code]ap_cost_between[/code] 做对照[/b]：站位变了之后「从当前格
	## 到 Boss 的价格」必须跟着变；拿一个与站位无关的常数断言，站位读错了也看不出来。
	# Arrange
	_setup_dag()
	_stand_on(EVENT)
	_visit([ENTRY, COMBAT_A, EVENT])
	# Act / Assert——站在事件节点（第 2 层 0 号）时的报到价 = 该格到 Boss 的直达价
	assert_eq(es.call(&"min_ap_to_boss"),
			int(es.call(&"ap_cost_between", EVENT, BOSS)),
			"站位读的是 GSM 的 node_position（与移动的写入同一编码）")


func test_visited_nodes_no_longer_block_the_route() -> void:
	## ★ 改前红：旧版断言「唯一中转点已访问 → 走不到（哨兵）」★[br]
	## 老板 2026-11-27 18:40：「已访问节点可以重入，消耗照算，奖励不重复发」。
	## 把走过的格子算成墙会给出一个[b]玩家其实做得到[/b]的假拒绝——这正是本轮要修的。[br]
	## [br]新口径下更彻底：根本不需要中转点。
	# Arrange——把 100 记成已访问（旧版视它为唯一通路）
	_setup_dag()
	_stand_on(ENTRY)
	_visit([ENTRY, COMBAT_A])
	# Act / Assert
	assert_eq(es.call(&"min_ap_to_boss"),
			int(es.call(&"ap_cost_between", ENTRY, BOSS)),
			"已访问节点不再是障碍（可重入 → 判定与它无关）")
	assert_ne(es.call(&"min_ap_to_boss"), Reach.UNREACHABLE,
			"不得报哨兵（那是玩家做得成的假拒绝）")
