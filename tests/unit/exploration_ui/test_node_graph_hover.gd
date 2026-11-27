extends GutTest
## 节点图悬停/焦点高亮 + 悬停文案——[b]六态全覆盖[/b]与三段文案的纯函数契约。[br]
##
## [b]为什么这两条要单独立文件[/b]：本轮的两处新接口都被既有断言限制了实现方式——
##   · 放大倍率（[method NodeGraphRenderer.get_node_draw_scale]）的语义被
##     [code]test_node_move_interaction.gd[/code] 钉死为「只有可达态悬停才放大」，
##     六态全覆盖因此必须走独立的 [method NodeGraphRenderer.is_node_highlighted]；
##   · 悬停文案（[method NodeGraphRenderer.hover_text_for]）是任务书要求「仅预留接口」
##     的那个纯函数——它的价值全在「能被逐字断言」上。[br]
## [br][b]不碰命中检测[/b]：[code]_has_point[/code] / [code]hit_test_*[/code] 归
## [code]test_node_graph_pick_region.gd[/code] 守护，本文件不写任何拾取断言。[br]
##
## [br]来源: 本轮任务书任务 D（悬停高亮 + 悬停提示接口预留）、
## .claude/rules/ui-code.md（双输入对等）、ADR-0031 §2/§4、
## design/gdd/exploration-ui-system.md §2（AC-10）。

const RENDERER := preload("res://src/ui/exploration/node_graph_renderer.gd")
const HOVER_TEXT := preload("res://src/ui/exploration/node_graph_hover_text.gd")
const NODE_LOGIC := preload("res://src/ui/exploration/node_state_logic.gd")
const DATA_STUB := preload("res://src/ui/exploration/node_graph_data_stub.gd")
const Style := preload("res://src/ui/exploration/node_graph_style.gd")
## 布局几何（悬停文案里那个消耗数字的来源——与扣费同源）。
const GEOMETRY := preload("res://src/feature/exploration/exploration_node_geometry.gd")

## 六态全集（取样池——顺序即枚举顺序）。
const ALL_STATES: Array[int] = [
	NODE_LOGIC.NodeState.CURRENT, NODE_LOGIC.NodeState.REACHABLE,
	NODE_LOGIC.NodeState.VISITED, NODE_LOGIC.NodeState.UNREACHABLE,
	NODE_LOGIC.NodeState.AP_INSUFFICIENT, NODE_LOGIC.NodeState.FOGGED,
]

var renderer: NodeGraphRenderer = null


func before_each() -> void:
	renderer = RENDERER.new()
	var snap: Dictionary = DATA_STUB.stub_snapshot()
	renderer.setup(snap["graph"], snap["nodes"], snap["visited"], snap["current_node"])
	renderer.map_id = &"qing_yun_jian_zong"


func after_each() -> void:
	renderer.free()
	renderer = null


## 把 101 号节点打成指定六态（其余节点状态不影响本文件的断言）。
func _force_state(p_node_id: int, p_state: int) -> void:
	var states: Dictionary = {}
	for node_id: int in renderer.nodes.keys():
		states[node_id] = NODE_LOGIC.NodeState.FOGGED
	states[p_node_id] = p_state
	renderer.set_states(states)


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 悬停 / 焦点统一高亮（六态全覆盖）
# ═══════════════════════════════════════════════════════════════════════════════

## 六态[b]每一种[/b]悬停时都应被判为高亮——这是任务书「鼠标移上去节点要亮」的
## 自动化落点。[br]
## [br][b]为什么不复用放大倍率[/b]：那条通道被既有断言限定为只有可达态生效
## （放大 = 可操作承诺），见文件头注记。
func test_every_state_is_highlighted_on_hover() -> void:
	for state: int in ALL_STATES:
		_force_state(101, state)
		renderer.hovered_node = 101
		assert_true(renderer.is_node_highlighted(101),
				"六态 %d 悬停时都应高亮（悬停反馈不得因状态而消失）" % state)


## 无悬停、无焦点时任何节点都不高亮（未悬停不得亮）。
func test_no_highlight_without_hover_or_focus() -> void:
	renderer.hovered_node = -1
	renderer.set_focused_node(-1)
	for node_id: int in renderer.nodes.keys():
		assert_false(renderer.is_node_highlighted(node_id),
				"无悬停无焦点时节点 %d 不该高亮" % node_id)


## 键盘/手柄焦点获得[b]与鼠标悬停相同[/b]的高亮（双输入对等——.claude/rules/ui-code.md）。[br]
## [br][b]为什么断言的是同一个布尔而不是两个**相似**的视觉[/b]：两条通道各自演进的
## 结果就是「键盘焦点长得像悬停但不一样」，而那种漂移只能靠肉眼发现。
func test_keyboard_focus_highlights_the_same_way_as_hover() -> void:
	renderer.hovered_node = -1
	renderer.set_focused_node(202)
	assert_true(renderer.is_node_highlighted(202),
			"键盘/手柄焦点节点应获得与鼠标悬停相同的高亮")
	assert_false(renderer.is_node_highlighted(101), "非焦点节点不该高亮")


## 焦点清除后高亮随之消失（[method set_focused_node] 传 -1）。
func test_clearing_focus_removes_highlight() -> void:
	renderer.set_focused_node(202)
	assert_true(renderer.is_node_highlighted(202), "前置：焦点已注入")
	renderer.set_focused_node(-1)
	assert_false(renderer.is_node_highlighted(202), "清除焦点后不该再高亮")


## 越界 / 负数节点 ID 不高亮——绘制侧不会因为 -1 画出幽灵高亮。[br]
func test_out_of_range_node_id_is_never_highlighted() -> void:
	renderer.hovered_node = 101
	renderer.set_focused_node(101)
	assert_false(renderer.is_node_highlighted(-1), "-1 不该高亮（无悬停哨兵值）")
	assert_false(renderer.is_node_highlighted(99999), "快照外的节点不该高亮")


## 高亮是[b]独立通道[/b]——它不改变放大倍率（既有断言守的那条语义）。[br]
## [br][b]为什么这条重要[/b]：六态全覆盖若靠扩 [code]get_node_draw_scale[/code] 实现，
## 就会与 [code]test_node_move_interaction.gd[/code] 的两条 hover 倍率断言打架；
## 这条断言把「两条通道各管各的」钉下来。
func test_highlight_channel_does_not_change_draw_scale() -> void:
	_force_state(101, NODE_LOGIC.NodeState.VISITED)
	renderer.hovered_node = 101
	assert_true(renderer.is_node_highlighted(101), "已访问态悬停应高亮（新通道）")
	assert_eq(renderer.get_node_draw_scale(101), 1.0,
			"已访问态悬停的放大倍率仍是 1.0（既有语义不得被新通道改写）")


## 高亮环的线宽不落在既有边框宽度表里——不与任何六态的描边粗细撞宽。[br]
## [br][b]为什么断言的是「不相等」而不是某个具体数[/b]：具体数值是美术可调的，
## 而「不与状态撞宽」才是这条设计的约束本身。
func test_highlight_ring_width_collides_with_no_border_width() -> void:
	assert_ne(Style.HIGHLIGHT_RING_WIDTH, Style.BORDER_WIDTH,
			"高亮环宽不得等于普通态边框宽（会被读成状态变了）")
	assert_ne(Style.HIGHLIGHT_RING_WIDTH, Style.EMPHASIS_BORDER_WIDTH,
			"高亮环宽不得等于强调态边框宽（会被读成状态变了）")
	assert_gt(Style.HIGHLIGHT_RING_WIDTH, 0.0, "高亮环宽应为正")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 悬停文案（hover_text_for —— 地名 + 类型 + 行动力消耗）
# ═══════════════════════════════════════════════════════════════════════════════

## 三段齐全：地名 · 类型与描述 · 消耗（战斗类还带敌人构成）。[br]
## [br][b]为什么逐字断言整行[/b]：这是「接口预留」的验收形态——将来的浮动提示直接消费
## 这一行，格式变了要有断言拦。
func test_hover_text_has_all_three_segments() -> void:
	renderer.set_place_overrides({101: "碎石坡"})
	var text: String = renderer.hover_text_for(101)
	assert_eq(text, "碎石坡 · 战斗：山道巡守（敌人：青云剑宗外门弟子×2） · 消耗 1 行动力",
			"悬停文案应为「地名 · 类型描述 · 行动力消耗」三段")


## 豁免类型（Boss / 传送 / 灵泉）读作[b]「不消耗」[/b]而不是「消耗 0」——
## 与系统扣费同源（[code]ExplorationApRules.cost_for[/code]）。[br]
## [br][b]为什么这条必须有[/b]：就地写死「消耗 1」会让提示与系统实际扣费说两套话，
## 而这正是 [code]exploration_ap_rules.gd[/code] 存在的理由。
func test_hover_text_marks_ap_exempt_types_as_free() -> void:
	renderer.set_place_overrides({203: "灵泉眼", 402: "古传送阵", 500: "剑宗大殿"})
	for node_id: int in [203, 402, 500]:
		var text: String = renderer.hover_text_for(node_id)
		assert_true(text.ends_with("不消耗行动力"),
				"豁免类型节点 %d 的悬停文案应以「不消耗行动力」收尾，实为: %s"
				% [node_id, text])


## 迷雾节点：第 2 段是「?」，但[b]地名照旧给[/b]（玩家要先知道去哪儿）。[br]
func test_hover_text_fogged_keeps_place_and_hides_type() -> void:
	_force_state(101, NODE_LOGIC.NodeState.FOGGED)
	renderer.set_place_overrides({101: "碎星外环"})
	var text: String = renderer.hover_text_for(101)
	assert_true(text.begins_with("碎星外环 · "), "迷雾节点仍应给出地名: %s" % text)
	assert_true(text.contains(" · ? · "), "迷雾节点的类型与描述应读作「?」: %s" % text)


## 快照外的节点返回空串（调用方据此不显示）。[br]
func test_hover_text_empty_for_unknown_node() -> void:
	assert_eq(renderer.hover_text_for(99999), "", "未知节点应返回空串")
	assert_eq(renderer.hover_text_for(-1), "", "负数节点应返回空串")


## 注入的本图配置优先于探明表——调小「单位距离」= 整图涨价，文案跟着变。[br]
## [br][b]★ 本轮语义变更（有意改动，报告单列）★[/b]：旧版注入的是 [code]{"ap_cost": 2}[/code]
## （按格定价的遗留键），断言「消耗 2 行动力」。本轮起移动开销按[b]两节点的布局距离[/b]
## 定价（老板 2026-11-27 18:40：「每个节点之间都可达，只是消耗的行动力不一样」），
## [code]ap_cost[/code] 已不参与计算——那条断言留着会变成「测一个已经被忽略的键」：
## 绿着，但什么都没守住。涨价旋钮改为 [code]ap_distance_unit[/code]。[br]
## [br][b]数值怎么定的[/b]：文案里那个数字来自 [code]ExplorationApRules.cost_for_move[/code]
## ——它读的是「当前节点 → 目标节点」在布局坐标里的[b]真实距离[/b]（由
## [code]ExplorationNodeGeometry[/code] 算，与画出来的位置同源）。本用例把单位距离设成
## 该距离的[b]一半[/b]，于是比值恰好 2.0 → 取整后 2 点，不靠任何凑出来的常数。
func test_hover_text_cost_follows_injected_map_config() -> void:
	renderer.set_place_overrides({101: "碎石坡"})
	var baseline: String = renderer.hover_text_for(101)
	assert_true(baseline.ends_with("消耗 1 行动力"),
			"前置：出厂配置下应读作「消耗 1 行动力」，实为: %s" % baseline)
	var distance: float = _distance_from_current(101)
	assert_gt(distance, 0.0, "前置：两个节点应相距一个正的距离")
	renderer.set_ap_cost_hint({"ap_distance_unit": distance * 0.5})
	var text: String = renderer.hover_text_for(101)
	assert_true(text.ends_with("消耗 2 行动力"),
			"把单位距离调成半程之后文案应读作「消耗 2 行动力」，实为: %s" % text)


## 行动力不够时最后一段换成[b]「行动力不足（需 N）」[/b]（老板 2026-11-27 18:40）。[br]
## [br][b]为什么括号里还要写需求量[/b]：同一句话里「要多少」与「你有没有」是两件事，
## 而玩家在这一刻只关心后者；但「差多少」决定了要不要先去别处晃一圈。[br]
## [br][b]判据取自六态而非「剩余 < 消耗」[/b]：节点若被画成可达、悬停却说行动力不足，
## 同一张图上就出现了两种说法（见 [method NodeGraphHoverText.needs_more_ap]）。
func test_hover_text_says_ap_short_when_state_is_ap_insufficient() -> void:
	_force_state(101, NODE_LOGIC.NodeState.AP_INSUFFICIENT)
	renderer.set_place_overrides({101: "碎石坡"})
	var text: String = renderer.hover_text_for(101)
	assert_true(text.ends_with("行动力不足（需 1）"),
			"行动力不足的节点应读作「行动力不足（需 N）」，实为: %s" % text)


## 快照[b]没给[/b]剩余行动力（-1）时不得谎报「行动力不足」。[br]
## [br][b]为什么单列这条[/b]：把「不知道」当成「是 0」，会让每一行悬停文案都写成
## 「行动力不足」——比不写更误导，且渲染器的默认值就是 -1（[method setup] 的
## [code]p_ap_remaining[/code] 不传时），这条是那条默认值的护栏。
func test_hover_text_does_not_guess_when_ap_is_unknown() -> void:
	renderer.set_place_overrides({101: "碎石坡"})
	assert_eq(renderer.ap_remaining, -1, "前置：本用例不应注入剩余行动力")
	renderer.set_states({})
	var text: String = renderer.hover_text_for(101)
	assert_false(text.contains("行动力不足"),
			"不知道剩余行动力时不得谎报不足，实为: %s" % text)


## 注入剩余行动力为 0 且六态未注入时，仍按剩余行动力判不足。[br]
## [br][b]为什么与上一条成对[/b]：两条合起来才把「-1（不知道）」与「0（确实没有）」
## 这两个值分开——它们只差 1，语义却相反。
func test_hover_text_reports_short_when_ap_really_is_zero() -> void:
	var snap: Dictionary = DATA_STUB.stub_snapshot()
	renderer.setup(snap["graph"], snap["nodes"], snap["visited"], snap["current_node"],
			&"", 0)
	renderer.set_place_overrides({101: "碎石坡"})
	assert_eq(renderer.ap_remaining, 0, "前置：剩余行动力已注入为 0")
	var text: String = renderer.hover_text_for(101)
	assert_true(text.contains("行动力不足"),
			"剩余行动力确实是 0 时应报不足，实为: %s" % text)


## 纯函数：同一份输入连问两次给出同一行（无副作用、无缓存漂移）。[br]
func test_hover_text_is_pure_and_repeatable() -> void:
	renderer.set_place_overrides({101: "碎石坡"})
	var first: String = renderer.hover_text_for(101)
	var second: String = renderer.hover_text_for(101)
	assert_eq(first, second, "同一份快照下悬停文案应可重复（纯函数）")
	assert_eq(HOVER_TEXT.text_for(renderer, 101), first,
			"转发方法与组装模块应给出同一行文案")


## 消耗短语的两档说法——0 与正数各一条（判据取自 [code]ExplorationApRules[/code]）。[br]
## [br][b]为什么用「无距离版」入口[/b]：[method NodeGraphHoverText.cost_text] 回答的是
## 「这一类格子贵不贵」（距离按 0 算，即公式下限 1），与出发位置无关——图鉴、攻略、
## 调试面板问的都是这个问题。从某个具体位置走过去要付多少走 [method cost_segment]。
func test_cost_text_distinguishes_free_from_paid() -> void:
	assert_eq(HOVER_TEXT.cost_text({}, 6), "不消耗行动力",
			"传送（6）是 AP 豁免类型——应读作「不消耗行动力」")
	assert_eq(HOVER_TEXT.cost_text({}, 1), "消耗 1 行动力",
			"战斗节点在缺配置时应按距离定价的下限 1 读")


## === 夹具 ===================================================================

## 当前节点到 [param p_node_id] 的布局距离（px）——与扣费读的是同一个几何模块。[br]
## [br][b]为什么在测试里现算而不是写一个数[/b]：布局标定（层间距 / 同层间距 / 错开量）
## 是可调的，写死的数会在标定变化后失效，而这条断言要守的正是「文案的数字与实际
## 距离同源」。
func _distance_from_current(p_node_id: int) -> float:
	var nodes: Dictionary = renderer.nodes
	return GEOMETRY.distance_between(nodes.get(renderer.current_node, {}),
			nodes.get(p_node_id, {}), GEOMETRY.layer_counts(nodes))
