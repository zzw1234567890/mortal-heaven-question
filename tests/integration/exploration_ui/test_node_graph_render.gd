extends GutTest
## exploration-ui Story S16-3 集成测试：节点图数据接入与节点状态渲染。
##
## Story 类型 Integration——此文件为 BLOCKING 证据（story-003 Test Evidence 路径）。[br]
## [br]覆盖 QA Test Cases：[br]
##   - AC-1：节点状态渲染映射——stub 信号发射器驱动构建，renderer.states 与
##     [NodeStateLogic.classify_node_state] 纯函数返回值逐项一致 + node_type_to_icon
##     映射（10 类型 label+color+region）[br]
##   - AC-2：迷雾揭散——node_moved 后迷雾节点 classify 返回非迷雾（自动化只断言
##     揭示集合变更，动画时序归 AC-3 手动走查）[br]
## [br][b]信号驱动路径[/b]：实例化 [NodeGraphScreen] 场景（真实 .tscn 节点树——
## PackedScene.instantiate 而非脚本 new），经 [MapGeneratedStub] stub 发射器驱动
## [method NodeGraphScreen._on_map_generated]，断言渲染路径不依赖真实探索系统。[br]
## [br][b]animate=false[/b]：测试注入关闭逐层展开动画（时序归手动证据），避免
## Tween 挂起。
##
## 来源: story-003-node-graph-data-states.md QA Test Cases、
## ADR-0031 §2、design/gdd/exploration-ui-system.md §公式 1。

const NodeGraphScreenScene: PackedScene = preload("res://src/ui/exploration/node_graph_screen.tscn")
const NODE_LOGIC := preload("res://src/ui/exploration/node_state_logic.gd")
const DATA_STUB := preload("res://src/ui/exploration/node_graph_data_stub.gd")
const ATLAS := preload("res://src/ui/exploration/node_icon_atlas.gd")
const MapGeneratedStubScript := preload("res://src/ui/exploration/map_generated_stub.gd")

## 命中检测「远离」判定偏移量（px）——大于节点图标半径，确保落在图标外。
const NODE_SIZE_CLEARANCE: float = 80.0

var screen: Control = null


func before_each() -> void:
	screen = NodeGraphScreenScene.instantiate()
	screen.animate = false
	add_child_autofree(screen)
	# 直接驱动信号处理路径（渲染路径验证——stub/真实源选择分支依赖 Autoload
	# 环境，不在此断言；MapGeneratedStub 单独测）
	screen._on_map_generated(&"qing_yun_jian_zong", DATA_STUB.stub_snapshot())


func renderer() -> NodeGraphRenderer:
	return screen.get("viewport").renderer


## 独立验证 stub 信号发射器——emit_map_generated 发射正确载荷（AC-1 stub 先行）。
func test_stub_emitter_emits_map_generated_signal() -> void:
	var emitter: Node = MapGeneratedStubScript.new()
	add_child_autofree(emitter)
	var received: Array = []
	emitter.map_generated.connect(
			func(map_id: StringName, map_data: Dictionary) -> void:
				received.append([map_id, map_data]))
	emitter.emit_map_generated()
	assert_eq(received.size(), 1, "stub 发射器应发射一次 map_generated")
	assert_eq(received[0][0], &"qing_yun_jian_zong", "默认地图 ID 应为青云剑宗")
	var data: Dictionary = received[0][1]
	assert_eq(data.get("current_node"), DATA_STUB.ENTRY_NODE_ID,
			"stub 载荷当前节点应为入口")
	assert_true(data.has("graph") and data.has("nodes"), "stub 载荷应含 graph/nodes")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1：节点状态渲染映射——六态样式与纯函数逐项一致
# ═══════════════════════════════════════════════════════════════════════════════

func test_map_generated_builds_all_node_states() -> void:
	# Then: 全部 12 节点都注入了六态（states 覆盖每个 node_id）
	var nodes: Dictionary = DATA_STUB.stub_node_details()
	var states: Dictionary = renderer().states
	assert_eq(states.size(), nodes.size(), "每个节点都应注入六态样式")
	for node_id: int in nodes.keys():
		assert_true(states.has(node_id), "节点 %d 应有六态样式" % node_id)


func test_map_generated_states_match_classifier() -> void:
	# AC-1 断言：renderer.states 与 classify_node_state 纯函数返回值逐项一致
	var snap: Dictionary = DATA_STUB.stub_snapshot()
	var states: Dictionary = renderer().states
	for node_id: int in states.keys():
		var expected: int = NODE_LOGIC.classify_node_state(
				node_id, snap["graph"], snap["visited"],
				snap["current_node"], snap["ap_remaining"], snap["nodes"])
		assert_eq(int(states[node_id]), expected,
				"节点 %d 六态应与纯函数一致" % node_id)


func test_map_generated_entry_is_current_state() -> void:
	# AC-1：入口节点为当前态（金色边框 + 玩家标记）
	var states: Dictionary = renderer().states
	assert_eq(int(states[0]), NODE_LOGIC.NodeState.CURRENT, "入口应为当前态")
	var style: Dictionary = NODE_LOGIC.node_state_style(int(states[0]))
	assert_eq(style["marker"], "player", "当前节点应带玩家标记")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1 补充：node_type_to_icon 映射契约（10 类型 label+color+region 可断言）
# ═══════════════════════════════════════════════════════════════════════════════

func test_node_type_to_icon_ten_types_label_color_region() -> void:
	# GDD 公式 1 映射——10 类型 label/color/region 契约（emoji 仅视觉目标）
	var expected_labels: Array = ["入口", "战斗", "精英", "Boss", "事件",
			"商店", "传送", "灵泉", "回复点", "渡劫台"]
	var expected_colors: Array = ["#8B7355", "#CC4444", "#FF4444", "#FFD700", "#4488CC",
			"#44CC88", "#9944CC", "#44AAFF", "#44CC66", "#FFAA00"]
	for type_id: int in 10:
		assert_eq(ATLAS.get_label(type_id), expected_labels[type_id],
				"类型 %d label 应符合 GDD 公式 1" % type_id)
		assert_eq(ATLAS.get_color(type_id), Color(expected_colors[type_id]),
				"类型 %d color 应符合 GDD 公式 1" % type_id)
		var region: Rect2 = ATLAS.get_region(type_id)
		assert_eq(region.position, Vector2(float(type_id * ATLAS.CELL), 0.0),
				"类型 %d region 起点" % type_id)
		assert_eq(region.size, Vector2(float(ATLAS.CELL), float(ATLAS.CELL)),
				"类型 %d region 尺寸" % type_id)


func test_node_type_to_icon_tribulation_uses_bolt_not_elite() -> void:
	# GAP-5 裁决：渡劫台(9) 用 🌩（glyph bolt）与精英(2)⚡（diamond）区分
	assert_eq(ATLAS.TYPE_SPECS[9]["glyph"], "bolt", "渡劫台应 bolt（🌩 视觉目标）")
	assert_eq(ATLAS.TYPE_SPECS[2]["glyph"], "diamond", "精英应 diamond（⚡ 视觉目标）")
	assert_ne(ATLAS.TYPE_SPECS[9]["color"], ATLAS.TYPE_SPECS[2]["color"],
			"渡劫台与精英颜色应区分")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-2：迷雾揭散——node_moved 后迷雾节点 classify 返回非迷雾
# ═══════════════════════════════════════════════════════════════════════════════

func test_node_moved_reveals_adjacent_layer() -> void:
	# AC-2 Given: 初始快照 201 未揭示（FOGGED）
	var states: Dictionary = renderer().states
	assert_eq(int(states.get(201, -1)), NODE_LOGIC.NodeState.FOGGED,
			"前置：201 商店节点初始应为迷雾")
	# When: node_moved 信号（玩家从入口 0 到达 101）
	screen._on_node_moved(0, 101, 2)
	# Then: 201/202 成为 101 前向邻接 → 揭示（classify 返回非迷雾）
	states = renderer().states
	assert_ne(int(states.get(201, -1)), NODE_LOGIC.NodeState.FOGGED,
			"node_moved 后 201 迷雾应揭散（非迷雾）")
	assert_ne(int(states.get(202, -1)), NODE_LOGIC.NodeState.FOGGED,
			"node_moved 后 202 迷雾应揭散（非迷雾）")


func test_node_moved_updates_current_and_visited() -> void:
	# AC-6：node_moved 后 current_node 翻转 + visited 记录
	screen._on_node_moved(0, 101, 2)
	var states: Dictionary = renderer().states
	assert_eq(int(states.get(101, -1)), NODE_LOGIC.NodeState.CURRENT,
			"移动后 101 应为当前态")
	assert_eq(int(states.get(0, -1)), NODE_LOGIC.NodeState.VISITED,
			"移动后入口 0 应为已访问态")


func test_node_moved_far_node_stays_fogged() -> void:
	# AC-2 Edge：远处 Boss 仍在迷雾（揭示集合只扩散到邻接）
	screen._on_node_moved(0, 101, 2)
	var states: Dictionary = renderer().states
	assert_eq(int(states.get(500, -1)), NODE_LOGIC.NodeState.FOGGED,
			"远处 Boss 未揭示应保持迷雾")


func test_ap_label_reflects_snapshot() -> void:
	# AC：右上角 AP 标签反映快照 ap_remaining
	screen._on_node_moved(0, 101, 2)
	var ap_label: Label = screen.get_node_or_null("TopBar/APLabel") as Label
	assert_eq(ap_label.text, "AP: 2", "行动力标签应反映移动后的剩余行动力")


# ═══════════════════════════════════════════════════════════════════════════════
# B-1 回归：stub 回退激活路径（走 trigger_map_load 端到端）
# ═══════════════════════════════════════════════════════════════════════════════

func test_stub_fallback_activates_via_trigger_map_load() -> void:
	# B-1 回归：Autoload 已注册（ExplorationSystem 存在）但未声明 map_generated
	# 信号 → stub 回退分支仍建立，trigger_map_load 端到端驱动节点图构建。
	# （before_each 的 screen 直调 _on_map_generated 绕过此分支，本测试补齐盲区）
	var screen2: Control = NodeGraphScreenScene.instantiate()
	screen2.animate = false
	add_child_autofree(screen2)
	screen2.trigger_map_load()
	var states: Dictionary = screen2.get("viewport").renderer.states
	assert_eq(states.size(), DATA_STUB.stub_node_details().size(),
			"stub 回退应驱动全部节点注入六态（走 trigger_map_load 而非直调）")
	assert_eq(int(states.get(0, -1)), NODE_LOGIC.NodeState.CURRENT,
			"入口应为当前态（stub 回退路径端到端接通）")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-10：节点悬停命中检测（tooltip 内容由纯函数覆盖，此处测命中判定）
# ═══════════════════════════════════════════════════════════════════════════════

func test_hit_test_node_returns_node_id_on_icon() -> void:
	# AC-10：画布坐标落在节点图标矩形内 → 返回该节点 ID（悬停触发判定）
	var r: NodeGraphRenderer = renderer()
	var entry_pos: Vector2 = r.get_node_position(0)
	assert_eq(r.hit_test_node(0, entry_pos), true, "入口图标中心应命中入口节点")


func test_hit_test_node_misses_empty_space() -> void:
	# AC-10 Edge：远离节点图标的坐标 → 不命中
	var r: NodeGraphRenderer = renderer()
	var entry_pos: Vector2 = r.get_node_position(0)
	var far: Vector2 = entry_pos + Vector2(NODE_SIZE_CLEARANCE, NODE_SIZE_CLEARANCE)
	assert_eq(r.hit_test_node(0, far), false, "远离图标的坐标不应命中")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-8：渡劫台「修为尚未圆满」渲染判定（渲染层消费纯函数）
# ═══════════════════════════════════════════════════════════════════════════════

func test_renderer_tribulation_unready_detection() -> void:
	# AC-8：渡劫台(401) tribulation_ready=false → 渲染层判定为「未圆满」
	var r: NodeGraphRenderer = renderer()
	assert_true(r._is_tribulation_unready(DATA_STUB.stub_node_details()[401]),
			"渡劫台修为未满应判定未圆满（灰色斜线视觉）")
	assert_false(r._is_tribulation_unready(DATA_STUB.stub_node_details()[402]),
			"传送节点非渡劫台不应判定未圆满")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-9：节点连线已走过金色实线 / 未走过暗色虚线（_is_edge_visited 判定分支）
# ═══════════════════════════════════════════════════════════════════════════════

func test_is_edge_visited_returns_true_when_both_ends_visited() -> void:
	# AC-9：连线两端均在 visited → 已走过（金色实线判定）
	var r: NodeGraphRenderer = renderer()
	r.visited = [0, 101]
	assert_true(r._is_edge_visited(0, 101),
			"两端均已访问的边应为已走过（金色实线）")


func test_is_edge_visited_returns_false_when_end_unvisited() -> void:
	# AC-9 Edge：连线任一端未访问 → 未走过（暗色虚线判定）
	var r: NodeGraphRenderer = renderer()
	r.visited = [0]
	assert_false(r._is_edge_visited(0, 101),
			"一端未访问的边应为未走过（暗色虚线）")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-11：渡劫台金色脉冲 / 精英红色边框（类型恒常视觉——GDD 界面规则表）
# ═══════════════════════════════════════════════════════════════════════════════

func test_tribulation_node_glows_gold_regardless_of_state() -> void:
	# AC-11：渡劫台(401) 类型恒常金色脉冲——非当前/非可达态（VISITED）也触发
	var r: NodeGraphRenderer = renderer()
	# 401 渡劫台初始为迷雾态（快照当前=0）——渲染层 type==9 恒常发光与状态无关
	assert_eq(r.TRIBULATION_TYPE, 9, "渡劫台类型 ID 应锚定 NodeType.TRIBULATION")
	assert_eq(r.TRIBULATION_GLOW_COLOR, Color(1.0, 0.667, 0.0, 0.4),
			"渡劫台金色脉冲色应为 #FFAA00 带透明度")


func test_elite_border_uses_type_color_when_reachable() -> void:
	# AC-11：精英(301) 可达态 border_is_type → 类型主色 #FF4444 红色边框
	var r: NodeGraphRenderer = renderer()
	var states: Dictionary = r.states
	# 初始快照 301 为迷雾；构造 301 可达需当前节点为其父级 201 且 visited 含 201
	r.visited = [0, 101, 201]
	r.current_node = 201
	var snap: Dictionary = DATA_STUB.stub_snapshot()
	snap["visited"] = [0, 101, 201]
	snap["current_node"] = 201
	var state: int = NODE_LOGIC.classify_node_state(301, snap["graph"],
			snap["visited"], 201, snap["ap_remaining"], snap["nodes"])
	assert_eq(state, NODE_LOGIC.NodeState.REACHABLE, "精英 301 在 201 下应为可达态")
	var style: Dictionary = NODE_LOGIC.node_state_style(state)
	assert_true(style["border_is_type"], "可达态应为类型主色边框")
	assert_eq(ATLAS.get_color(2), Color("#FF4444"), "精英类型主色应为红色")
