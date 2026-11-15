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
## 来源: story-003-node-graph-data-states.md QA Test Cases AC-1/AC-2、
## ADR-0031 §2、design/gdd/exploration-ui-system.md §2 界面规则表。

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
	## AC-5: 已揭示但非当前邻接、未访问 → UNREACHABLE。[br]
	## 构造：当前=201、visited=[0,101,201] 时，102 已在揭示集合（visited 前向
	## 邻接可达）但非 201 的邻接 → 不可达（与迷雾/可达区分）。
	var snap: Dictionary = DATA_STUB.stub_snapshot()
	snap["current_node"] = 201
	snap["visited"] = [0, 101, 201]
	assert_eq(NODE_LOGIC.classify_node_state(102, snap["graph"], snap["visited"],
			201, snap["ap_remaining"], snap["nodes"]),
			NODE_LOGIC.NodeState.UNREACHABLE, "已揭示但非当前邻接应为不可达")


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


func test_verdict_distinguishes_the_three_refusals() -> void:
	## 病根是「都返回 false」——三条拒绝路径必须给出三个不同的 reason。
	## 图里给 101 加一条回退边到 0：stub 的邻接表没有它（真实 DAG 无回退边），
	## 不加则「已访问」那一格会被拓扑判定先拦下，测不到进度原因。
	var snap: Dictionary = DATA_STUB.stub_snapshot()
	var graph: Dictionary = (snap["graph"] as Dictionary).duplicate(true)
	graph[101] = [201, 202, 0]
	var nodes: Dictionary = snap["nodes"]
	# 不可达：0 与远处 Boss 不相邻
	var unreachable: String = str(NODE_LOGIC.verdict_for(0, 500, graph,
			[0], 3, nodes)["reason"])
	# 已访问：0 已在 visited（且 101→0 邻接）
	var visited: String = str(NODE_LOGIC.verdict_for(101, 0, graph,
			[0, 101], 3, nodes)["reason"])
	# 行动力不足：101 战斗节点可达但 AP=0
	var ap_short: String = str(NODE_LOGIC.verdict_for(0, 101, graph,
			[0], 0, nodes)["reason"])
	assert_eq(unreachable, NODE_LOGIC.REASON_UNREACHABLE, "走不到 → 拓扑原因")
	assert_eq(visited, NODE_LOGIC.REASON_VISITED, "走过了 → 进度原因")
	assert_eq(ap_short, NODE_LOGIC.REASON_AP_SHORT, "走不起 → 资源原因")
	assert_ne(unreachable, visited, "不可达与已访问必须不同")
	assert_ne(unreachable, ap_short, "不可达与行动力不足必须不同")
	assert_ne(visited, ap_short, "已访问与行动力不足必须不同")


func test_verdict_exempt_type_passes_at_zero_ap() -> void:
	## 对照（防「AP=0 一律拒绝」的假通过）：Boss 豁免，AP=0 仍判可达
	var snap: Dictionary = DATA_STUB.stub_snapshot()
	var verdict: Dictionary = NODE_LOGIC.verdict_for(402, 500, snap["graph"],
			[0, 101, 202, 301, 402], 0, snap["nodes"])
	assert_true(bool(verdict["ok"]), "Boss 豁免类型 AP=0 仍可达")


func test_verdict_checks_visited_before_ap() -> void:
	## 顺序不是风格问题：已访问且邻接的节点在系统里报「已访问」，UI 若先判 AP
	## 就会对同一个节点给出另一种说法。
	var snap: Dictionary = DATA_STUB.stub_snapshot()
	var graph: Dictionary = (snap["graph"] as Dictionary).duplicate(true)
	graph[101] = [201, 202, 0]
	var verdict: Dictionary = NODE_LOGIC.verdict_for(101, 0, graph,
			[0, 101], 0, snap["nodes"])
	assert_eq(str(verdict["reason"]), NODE_LOGIC.REASON_VISITED,
			"AP=0 且已访问时，先判出的应是「已访问」")


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
