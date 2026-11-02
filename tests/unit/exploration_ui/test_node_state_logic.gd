extends GutTest
## exploration-ui Story S16-3 单元测试：节点六态分类器 + 样式查询 + 辅助纯函数。
##
## 覆盖故事 AC-1/AC-2/AC-5/AC-8/AC-10 的 Logic 内核：[br]
##   - classify_node_state：六态分类（当前/可达/已访问/不可达/行动力不足/迷雾）[br]
##   - node_state_style：六态 → 视觉样式映射（边框/标记/发光/暗化/斜线）[br]
##   - is_revealed：迷雾揭示判定（AC-6 走过分支不重新迷雾）[br]
##   - is_tribulation_not_ready：渡劫台修为未满（AC-8）[br]
##   - tooltip_text：悬停预览（AC-10；迷雾节点显示「?」不显示敌人构成）[br]
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
