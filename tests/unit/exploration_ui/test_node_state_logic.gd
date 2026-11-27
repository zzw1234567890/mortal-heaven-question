extends GutTest
## exploration-ui Story S16-3 单元测试：节点六态分类器 + 样式查询 + 辅助纯函数。
##
## 覆盖故事 AC-1/AC-2/AC-5/AC-8/AC-10 的 Logic 内核：[br]
##   - classify_node_state：六态分类（当前/可达/已访问/不可达/行动力不足/迷雾）[br]
##   - verdict_for / state_from_verdict：可判别版移动判定与六态映射（本轮新增——
##     三态混叠拆开，见文件末段）[br]
##   - node_state_style：六态 → 视觉样式映射（边框/标记/发光/暗化/斜线）[br]
##   - is_revealed：迷雾揭示（AC-6 走过分支不重新迷雾）；is_tribulation_not_ready：
##     渡劫台修为未满（AC-8）；tooltip_text：悬停预览（AC-10；迷雾只显示「?」）[br]
##
## [b]纯函数直调[/b]：static 函数以 [code]NODE_LOGIC.func(...)[/code] 直接调用
## （GUT 直调模式——S16-1/2 先例）。stub 载荷来自 [NodeGraphDataStub]。
##
## [br][b]★ 本轮语义变更（有意改动，报告单列）★[/b]：老板 2026-11-27 18:40
## 「每个节点之间都可达，只是消耗的行动力不一样」+「已访问节点可以重入」之后，
## [method NodeStateLogic.verdict_for] 的判据只剩两条（目标存在 → 行动力足够），
## 本文件三条用例的前提随之作废：[br]
##   · [code]test_classify_unreachable_node_returns_unreachable[/code]——「已揭示
##     但非当前邻接」不再等于不可达（改成「已揭示但本图没有这一格」）；[br]
##   · [code]test_verdict_distinguishes_the_three_refusals[/code]——可发生的拒绝
##     从三条降到两条（邻接 / 已访问两条不再拒绝），改名收窄为两条 + 另立守卫态
##     对照用例；[br]
##   · [code]test_verdict_checks_visited_before_ap[/code]——「已访问」退出判定，
##     顺序断言换成[b]存在性先于行动力[/b]（新口径下仍要求顺序、且错序会误伤玩家
##     的那一条），另立一例钉「visited 不改变判定」。[br]
## 三条[c]都不是删断言[/c]：判别力等价，只是判别集合随口径变小。词表常量一条没删
## （[constant NodeStateLogic.REASON_VISITED] 仍是跨层契约，[method state_from_verdict]
## 仍认它）。[br]
##
## 来源: story-003-node-graph-data-states.md QA Test Cases AC-1/AC-2、
## ADR-0031 §2、design/gdd/exploration-ui-system.md §2 界面规则表、
## 本轮任务书追加规则（全连通 + 已访问可重入）。

const NODE_LOGIC := preload("res://src/ui/exploration/node_state_logic.gd")
const DATA_STUB := preload("res://src/ui/exploration/node_graph_data_stub.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1：classify_node_state 六态分类
# ═══════════════════════════════════════════════════════════════════════════════

func test_classify_current_node_returns_current() -> void:
	## AC-1: 当前节点 → CURRENT（金色边框 + 玩家标记）
	var snap: Dictionary = DATA_STUB.stub_snapshot()
	assert_eq(NODE_LOGIC.classify_node_state(0, snap["graph"], snap["visited"],
			snap["current_node"], snap["ap_remaining"], snap["nodes"]),
			NODE_LOGIC.NodeState.CURRENT, "入口节点应为当前态")


func test_classify_reachable_child_returns_reachable() -> void:
	## AC-2: 可达子节点（当前前向邻接 + AP 足够）→ REACHABLE
	var snap: Dictionary = DATA_STUB.stub_snapshot()
	assert_eq(NODE_LOGIC.classify_node_state(101, snap["graph"], snap["visited"],
			snap["current_node"], snap["ap_remaining"], snap["nodes"]),
			NODE_LOGIC.NodeState.REACHABLE, "入口前向邻接 101 应为可达")


func test_classify_current_beats_visited() -> void:
	## AC-1 Edge: 节点同时是当前与已访问 → 当前优先（CURRENT 而非 VISITED）
	var snap: Dictionary = DATA_STUB.stub_snapshot()
	assert_eq(NODE_LOGIC.classify_node_state(0, snap["graph"], snap["visited"],
			0, snap["ap_remaining"], snap["nodes"]),
			NODE_LOGIC.NodeState.CURRENT, "入口同时是当前与已访问——当前优先")


func test_classify_visited_non_current_returns_visited() -> void:
	## AC-4: 已访问非当前节点 → VISITED（绿色边框 + ✓）
	var snap: Dictionary = DATA_STUB.stub_snapshot()
	snap["current_node"] = 101
	snap["visited"] = [0, 101]
	assert_eq(NODE_LOGIC.classify_node_state(0, snap["graph"], snap["visited"],
			101, snap["ap_remaining"], snap["nodes"]),
			NODE_LOGIC.NodeState.VISITED, "已访问非当前节点应为已访问态")


func test_classify_unrevealed_node_returns_fogged() -> void:
	## AC-6: 未揭示节点（非 visited/current/邻接）→ FOGGED
	var snap: Dictionary = DATA_STUB.stub_snapshot()
	assert_eq(NODE_LOGIC.classify_node_state(500, snap["graph"], snap["visited"],
			snap["current_node"], snap["ap_remaining"], snap["nodes"]),
			NODE_LOGIC.NodeState.FOGGED, "Boss 未揭示应为迷雾")


func test_classify_ap_insufficient_returns_ap_insufficient() -> void:
	## AC-5: 可达但行动力不足（AP=0 且非豁免）→ AP_INSUFFICIENT（区别于不可达）
	var snap: Dictionary = DATA_STUB.stub_snapshot()
	snap["ap_remaining"] = 0
	# 101 战斗节点（非豁免）——可达但 AP 不足
	assert_eq(NODE_LOGIC.classify_node_state(101, snap["graph"], snap["visited"],
			snap["current_node"], 0, snap["nodes"]),
			NODE_LOGIC.NodeState.AP_INSUFFICIENT,
			"战斗节点可达但 AP=0 应为行动力不足（非不可达）")


func test_classify_ap_exempt_reachable_when_ap_zero() -> void:
	## AC-5 Edge: Boss（豁免类型）AP=0 时仍可达——可达而非行动力不足
	var snap: Dictionary = DATA_STUB.stub_snapshot()
	snap["ap_remaining"] = 0
	snap["current_node"] = 402  # 传送节点 → Boss 邻接
	snap["visited"] = [0, 101, 202, 301, 402]
	assert_eq(NODE_LOGIC.classify_node_state(500, snap["graph"], snap["visited"],
			402, 0, snap["nodes"]),
			NODE_LOGIC.NodeState.REACHABLE, "Boss 豁免类型 AP=0 仍可达")


func test_classify_unreachable_node_returns_unreachable() -> void:
	## AC-5: 已揭示但[b]本图没有这一格[/b] → UNREACHABLE。[br]
	## [br][b]★ 改前红：旧版拿「已揭示但非当前邻接」当不可达的样本（102，
	## 当前=201）★[/b] 老板 2026-11-27 18:40「每个节点之间都可达，只是消耗的行动力
	## 不一样」之后，邻接不再是门槛——102 在详情里存在，就会被判可达，旧断言必然红。[br]
	## [br][b]改写方式（不是删断言，也不是换一个「比较好过」的样本）[/b]：新口径下
	## 「不可达」只剩一个真实来源——目标节点根本不在本图（越界 ID / 存档脏数据）。
	## 构造仍然走「已揭示」这条路：给当前节点的前向邻接表里塞一个只存在于边表、
	## 不在节点详情里的 103——它会被揭示（[method is_revealed] 只看边表），
	## 但判定问不出这一格是什么，于是落在 UNREACHABLE。[br]
	## [br][b]为什么必须仍然「已揭示」[/b]：不揭示就会先落 FOGGED，测到的是迷雾
	## 而不是不可达——六态之间那条边界正是本用例要钉的东西。
	var snap: Dictionary = DATA_STUB.stub_snapshot()
	snap["current_node"] = 201
	snap["visited"] = [0, 101, 201]
	var graph: Dictionary = (snap["graph"] as Dictionary).duplicate(true)
	graph[201] = [301, 103]  # 103 只在边表里——详情里没有它（脏数据 / 越界 ID）
	assert_false((snap["nodes"] as Dictionary).has(103),
			"前置：103 必须在节点详情里缺席，否则测的是可达而不是不可达")
	assert_eq(NODE_LOGIC.classify_node_state(103, graph, snap["visited"],
			201, snap["ap_remaining"], snap["nodes"]),
			NODE_LOGIC.NodeState.UNREACHABLE, "已揭示但本图没有这一格 → 不可达")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1：node_state_style 六态样式映射
# ═══════════════════════════════════════════════════════════════════════════════

func test_style_current_has_gold_border_and_player_marker() -> void:
	var style: Dictionary = NODE_LOGIC.node_state_style(NODE_LOGIC.NodeState.CURRENT)
	assert_eq(style["border"], Color("#FFD700"), "当前节点金色边框")
	assert_eq(style["marker"], "player", "当前节点玩家标记")


func test_style_reachable_has_pulse_glow_and_type_border() -> void:
	var style: Dictionary = NODE_LOGIC.node_state_style(NODE_LOGIC.NodeState.REACHABLE)
	assert_eq(style["glow"], "pulse_blue", "可达节点脉冲外发光")
	assert_true(style["border_is_type"], "可达节点边框用类型主色")


func test_style_visited_has_check_marker_and_dim() -> void:
	var style: Dictionary = NODE_LOGIC.node_state_style(NODE_LOGIC.NodeState.VISITED)
	assert_eq(style["marker"], "check", "已访问节点 ✓ 标记")
	assert_true(style["dim"], "已访问节点稍暗")


func test_style_unreachable_has_lock_marker() -> void:
	var style: Dictionary = NODE_LOGIC.node_state_style(NODE_LOGIC.NodeState.UNREACHABLE)
	assert_eq(style["marker"], "lock", "不可达节点锁标记")


func test_style_ap_insufficient_has_slash() -> void:
	var style: Dictionary = NODE_LOGIC.node_state_style(NODE_LOGIC.NodeState.AP_INSUFFICIENT)
	assert_true(style["slash"], "行动力不足节点红色斜线")


func test_style_fogged_hides_type() -> void:
	var style: Dictionary = NODE_LOGIC.node_state_style(NODE_LOGIC.NodeState.FOGGED)
	assert_true(style["fogged"], "迷雾节点不显示类型")
	assert_eq(style["marker"], "question", "迷雾节点 ❓ 标记")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-2：is_revealed 迷雾揭示判定
# ═══════════════════════════════════════════════════════════════════════════════

func test_is_revealed_visited_branch_stays_revealed() -> void:
	## AC-6 Edge: 已走过的分支不重新迷雾——visited 节点前向邻接仍揭示
	var graph: Dictionary = DATA_STUB.stub_graph()
	var visited: Array = [0, 101, 201]
	# 301 是 visited(201) 的前向邻接 → 揭示（走过的分支持续可见）
	assert_true(NODE_LOGIC.is_revealed(301, graph, visited, 201),
			"已访问节点的前向邻接应保持揭示")


func test_is_revealed_unvisited_far_node_hidden() -> void:
	var graph: Dictionary = DATA_STUB.stub_graph()
	var visited: Array = [0, 101]
	# 500 Boss 距 visited/current 前向邻接过远 → 不揭示
	assert_false(NODE_LOGIC.is_revealed(500, graph, visited, 101),
			"远处未揭示节点应保持迷雾")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-8：is_tribulation_not_ready 渡劫台修为未满
# ═══════════════════════════════════════════════════════════════════════════════

func test_is_tribulation_not_ready_returns_true_when_unready() -> void:
	## AC-8: 渡劫台(9) + tribulation_ready=false → 可进入不可触发
	var detail: Dictionary = {"type": 9, "tribulation_ready": false}
	assert_true(NODE_LOGIC.is_tribulation_not_ready(detail),
			"渡劫台修为未满应不可触发")


func test_is_tribulation_not_ready_returns_false_when_ready() -> void:
	var detail: Dictionary = {"type": 9, "tribulation_ready": true}
	assert_false(NODE_LOGIC.is_tribulation_not_ready(detail),
			"渡劫台修为已满应可触发")


func test_is_tribulation_not_ready_ignores_non_tribulation() -> void:
	## AC-8 Edge: 非渡劫台类型即使 tribulation_ready=false 也不受影响
	var detail: Dictionary = {"type": 1, "tribulation_ready": false}
	assert_false(NODE_LOGIC.is_tribulation_not_ready(detail),
			"非渡劫台节点不应受 tribulation_ready 字段影响")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-10：tooltip_text 悬停预览
# ═══════════════════════════════════════════════════════════════════════════════

func test_tooltip_combat_includes_enemy_detail() -> void:
	## AC-10: 战斗类节点 tooltip = 名称 + 描述 + 敌人详情
	var detail: Dictionary = {"type": 1, "label": "战斗", "description": "山道巡守",
			"enemy_detail": "外门弟子×2"}
	assert_eq(NODE_LOGIC.tooltip_text(detail, false),
			"战斗：山道巡守（敌人：外门弟子×2）", "战斗节点悬停应含敌人详情")


func test_tooltip_non_combat_omits_enemy_detail() -> void:
	## AC-10 Edge: 非战斗节点 tooltip = 名称 + 描述（无敌人详情）
	var detail: Dictionary = {"type": 5, "label": "商店", "description": "坊市",
			"enemy_detail": ""}
	assert_eq(NODE_LOGIC.tooltip_text(detail, false), "商店：坊市",
			"非战斗节点悬停不应含敌人详情")


func test_tooltip_fogged_shows_question_mark_only() -> void:
	## AC-2 Edge: 迷雾节点 tooltip 显示「?」不显示敌人构成
	var detail: Dictionary = {"type": 1, "label": "战斗", "description": "未知",
			"enemy_detail": "外门弟子×2"}
	assert_eq(NODE_LOGIC.tooltip_text(detail, true), "?",
			"迷雾节点悬停应只显示 ? 不暴露敌人构成")


# ═══════════════════════════════════════════════════════════════════════════════
# 可判别版移动判定（本轮新增——三态混叠拆开）
# ═══════════════════════════════════════════════════════════════════════════════

func test_verdict_reachable_is_ok_without_reason() -> void:
	## 可达 → ok，reason 为空串（与系统侧 can_move_to_detail 同形状）
	var snap: Dictionary = DATA_STUB.stub_snapshot()
	var verdict: Dictionary = NODE_LOGIC.verdict_for(0, 101, snap["graph"],
			snap["visited"], snap["ap_remaining"], snap["nodes"])
	assert_true(bool(verdict["ok"]), "入口前向邻接应为可达")
	assert_eq(str(verdict["reason"]), "", "通过时 reason 为空串")


func test_verdict_distinguishes_the_two_refusals() -> void:
	## 病根是「都返回 false」——[b]本轮起可发生的拒绝只剩两条[/b]（老板
	## 2026-11-27 18:40），它们必须给出两个不同的 reason。[br]
	## [br][b]★ 改前红：旧版是「三条拒绝路径给三个不同 reason」，其中两条分别用
	## 「不相邻」与「已访问」当样本 ★[/b] 新口径下这两条[b]都通过[/b]——邻接不再是
	## 门槛、已访问可重入，旧断言拿到的会是空串。[br]
	## [br][b]改写方式（判别力一条没减）[/b]：判别集合随口径收窄为两条，但
	## 「不许都返回同一个 reason」这条病根仍然被钉住，且[b]多加了守卫态的第三项
	## 对照[/b]——守卫态（DAG 未就绪）与两条拒绝态三者两两不同。[br]
	## [br][b]词表本身没删[/b]：[constant NODE_LOGIC.REASON_VISITED] 仍是跨层契约
	## 常量（[method state_from_verdict] 还认它），见本文件末段的映射穷尽断言。
	var snap: Dictionary = DATA_STUB.stub_snapshot()
	var nodes: Dictionary = snap["nodes"]
	# 不可达：0 → 999，本图没有这一格
	var unreachable: String = str(NODE_LOGIC.verdict_for(0, 999, snap["graph"],
			[0], 3, nodes)["reason"])
	# 行动力不足：101 战斗节点（非豁免）在 AP=0 时
	var ap_short: String = str(NODE_LOGIC.verdict_for(0, 101, snap["graph"],
			[0], 0, nodes)["reason"])
	assert_eq(unreachable, NODE_LOGIC.REASON_UNREACHABLE, "本图没有这一格 → 存在性原因")
	assert_eq(ap_short, NODE_LOGIC.REASON_AP_SHORT, "走不起 → 资源原因")
	assert_ne(unreachable, ap_short, "不可达与行动力不足必须不同")


func test_verdict_distinguishes_the_guard_state_from_both_refusals() -> void:
	## 守卫态（DAG 未就绪 / GSM 不可用）是第三类 —— 它不在 [method verdict_for]
	## 的产出里（纯函数不碰 DAG 缓存与 GSM，由系统侧产出），但 UI 拿系统的返回值
	## 来问同一件事时必须能分开。此处直接拿词表常量做判别力断言。
	var refusals: Array[String] = [
		NODE_LOGIC.REASON_UNREACHABLE, NODE_LOGIC.REASON_AP_SHORT,
	]
	for guard: String in [NODE_LOGIC.REASON_NOT_READY, NODE_LOGIC.REASON_NO_GSM]:
		for refusal: String in refusals:
			assert_ne(guard, refusal,
					"守卫态「%s」必须与拒绝态「%s」不同" % [guard, refusal])
	assert_ne(NODE_LOGIC.REASON_NOT_READY, NODE_LOGIC.REASON_NO_GSM,
			"两条守卫态彼此也不同（UI 的 toast 映射表拿它们当键）")


func test_verdict_exempt_type_passes_at_zero_ap() -> void:
	## 对照（防「AP=0 一律拒绝」的假通过）：Boss 豁免，AP=0 仍判可达
	var snap: Dictionary = DATA_STUB.stub_snapshot()
	var verdict: Dictionary = NODE_LOGIC.verdict_for(402, 500, snap["graph"],
			[0, 101, 202, 301, 402], 0, snap["nodes"])
	assert_true(bool(verdict["ok"]), "Boss 豁免类型 AP=0 仍可达")


func test_verdict_checks_existence_before_ap() -> void:
	## 顺序不是风格问题：[b]本图没有的那一格，无论 AP 多少都只能报「不可达」[/b]。
	## 若先判 AP，AP=0 时它会被报成「行动力不足」——玩家会把行动力补满再来点，
	## 而那一格永远点不动。[br]
	## [br][b]★ 改前红：旧版断言的是「已访问先于 AP」（AP=0 且已访问 → 报『已访问』）★[/b]
	## 「已访问」整条已退出移动判定（老板 2026-11-27 18:40「已访问节点可以重入」），
	## 那条顺序断言的前提随之消失。[br]
	## [br][b]改写方式[/b]：不删「顺序」这个断言形状，而是换成[b]新口径下仍然存在、
	## 且同样要求特定顺序[/b]的那一条——存在性检查必须挡在 AP 检查之前。判别力与
	## 旧版等价（旧版守「先判进度再判资源」，本版守「先判存在再判资源」），
	## 而且本版守的是真的会误伤玩家的那种错序。
	var snap: Dictionary = DATA_STUB.stub_snapshot()
	var nodes: Dictionary = snap["nodes"]
	var verdict: Dictionary = NODE_LOGIC.verdict_for(0, 999, snap["graph"],
			[0], 0, nodes)
	assert_eq(str(verdict["reason"]), NODE_LOGIC.REASON_UNREACHABLE,
			"AP=0 且目标不存在时，先判出的应是「不可达」而不是「行动力不足」")
	assert_false(bool(verdict["ok"]), "该路径必须是拒绝")


func test_verdict_ignores_visited_so_visited_nodes_can_be_reentered() -> void:
	## 老板 2026-11-27 18:40：「已访问节点可以重入，消耗照算，奖励不重复发」。
	## 同一对节点，visited 里有与没有必须给出同一个判定——UI 若拿 visited 去挡，
	## 就会画出「系统允许点、界面画成不可达」的分家。[br]
	## [br][b]★ 改前红：旧版此处是「已访问 → reason『已访问』」★[/b] 本条把旧口径的
	## 拒绝理由翻成正向期望（照样断言，不是删断言）。
	var snap: Dictionary = DATA_STUB.stub_snapshot()
	var nodes: Dictionary = snap["nodes"]
	var without: Dictionary = NODE_LOGIC.verdict_for(101, 0, snap["graph"],
			[0], 3, nodes)
	var with_visited: Dictionary = NODE_LOGIC.verdict_for(101, 0, snap["graph"],
			[0, 101], 3, nodes)
	assert_true(bool(without["ok"]), "前置：该目标在 AP 够时可达")
	assert_eq(with_visited, without,
			"visited 里有没有这个节点不改变判定（已访问可重入）")
	assert_ne(str(with_visited["reason"]), NODE_LOGIC.REASON_VISITED,
			"reason 不得再是「已访问」（该理由已退出移动判定）")


func test_state_from_verdict_maps_to_six_states() -> void:
	## 六态映射穷尽词表：通过 / 行动力不足 / 已访问各归其位，其余两条守卫态
	## （DAG 未就绪、GSM 不可用）按不可达处理（UI 没有第四种视觉）。
	assert_eq(NODE_LOGIC.state_from_verdict({"ok": true, "reason": ""}),
			NODE_LOGIC.NodeState.REACHABLE, "通过 → 可达")
	assert_eq(NODE_LOGIC.state_from_verdict(
			{"ok": false, "reason": NODE_LOGIC.REASON_AP_SHORT}),
			NODE_LOGIC.NodeState.AP_INSUFFICIENT, "行动力不足 → 红色斜线")
	assert_eq(NODE_LOGIC.state_from_verdict(
			{"ok": false, "reason": NODE_LOGIC.REASON_VISITED}),
			NODE_LOGIC.NodeState.VISITED, "已访问 → 绿色勾")
	assert_eq(NODE_LOGIC.state_from_verdict(
			{"ok": false, "reason": NODE_LOGIC.REASON_UNREACHABLE}),
			NODE_LOGIC.NodeState.UNREACHABLE, "不可达 → 锁标记")
	assert_eq(NODE_LOGIC.state_from_verdict(
			{"ok": false, "reason": NODE_LOGIC.REASON_NOT_READY}),
			NODE_LOGIC.NodeState.UNREACHABLE, "DAG 未就绪 → 按不可达画")
	assert_eq(NODE_LOGIC.state_from_verdict(
			{"ok": false, "reason": NODE_LOGIC.REASON_NO_GSM}),
			NODE_LOGIC.NodeState.UNREACHABLE, "GSM 不可用 → 按不可达画")


func test_classify_agrees_with_verdict_path() -> void:
	## 分类器走的就是 verdict_for 这条路——两处对同一次判定必须同结论
	## （防「改了 verdict_for 但分类器还留着一份旧推导」）。
	var snap: Dictionary = DATA_STUB.stub_snapshot()
	for ap: int in [3, 0]:
		var expected: int = NODE_LOGIC.state_from_verdict(
				NODE_LOGIC.verdict_for(0, 101, snap["graph"], [0], ap, snap["nodes"]))
		assert_eq(NODE_LOGIC.classify_node_state(101, snap["graph"], [0], 0, ap,
				snap["nodes"]), expected,
				"AP=%d 时分类器应与 verdict_for 同结论" % ap)
