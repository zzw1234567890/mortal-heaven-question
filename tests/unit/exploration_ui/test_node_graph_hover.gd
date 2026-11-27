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


## 注入的本图配置优先于探明表——[code]ap_cost[/code] 配成 2 时文案跟着变。[br]
## [br][b]为什么这条重要[/b]：悬停文案里那个数字若与系统扣费不同源，玩家按提示走发现
## 扣得更多——两处各算一遍必然分叉。
func test_hover_text_cost_follows_injected_map_config() -> void:
	renderer.set_place_overrides({101: "碎石坡"})
	renderer.set_ap_cost_hint({"ap_cost": 2})
	var text: String = renderer.hover_text_for(101)
	assert_true(text.ends_with("消耗 2 行动力"),
			"注入 ap_cost=2 后文案应读作「消耗 2 行动力」，实为: %s" % text)


## 纯函数：同一份输入连问两次给出同一行（无副作用、无缓存漂移）。[br]
func test_hover_text_is_pure_and_repeatable() -> void:
	renderer.set_place_overrides({101: "碎石坡"})
	var first: String = renderer.hover_text_for(101)
	var second: String = renderer.hover_text_for(101)
	assert_eq(first, second, "同一份快照下悬停文案应可重复（纯函数）")
	assert_eq(HOVER_TEXT.text_for(renderer, 101), first,
			"转发方法与组装模块应给出同一行文案")


## 消耗短语的两档说法——0 与正数各一条（判据取自 [code]ExplorationApRules[/code]）。[br]
func test_cost_text_distinguishes_free_from_paid() -> void:
	assert_eq(HOVER_TEXT.cost_text({}, 6), "不消耗行动力",
			"传送（6）是 AP 豁免类型——应读作「不消耗行动力」")
	assert_eq(HOVER_TEXT.cost_text({}, 1), "消耗 1 行动力",
			"战斗节点在缺配置时应按 GDD 默认开销 1 读")
