extends GutTest
## 节点图「一眼看得出状态与类型」单元测试（本轮任务书任务四）。
##
## [b]覆盖[/b]：
##   1. 六态样式取值互不相同——【亮度（veil）+ 描边粗细（emphasis）+ 是否发光（glow）】
##      三根轴合起来必须把六态两两分开（任务书「四态差异要能靠亮度 + 描边粗细 +
##      是否发光直接分辨」的自动化落点）。[br]
##   2. 每种节点类型都能取到标签与图标——14 类各有一个非空短标签（≥1 字）与一个
##      独立图集 region，绘制侧不会画出空标签/无图标节点。[br]
## [br][b]为什么不测绘制结果[/b]：headless 下拿不到真实帧缓冲（同
## [code]ui_pass_shot.gd[/code] 头部注记）；「画出来长什么样」归截图取证
## （[code]tools/ui_shot_node_graph.png[/code]），这里锁的是绘制侧消费的那份规格。[br]
## [br][b]不碰命中检测[/b]：本轮不动 [code]NodeGraphRenderer._has_point[/code]
## （那是负坐标节点拾取 bug 的修复点），故这里不写任何拾取断言。
##
## 来源: 本轮任务书任务二 / 任务四、ADR-0031 §5、
## design/gdd/exploration-ui-system.md §2 界面规则表。

const NODE_LOGIC := preload("res://src/ui/exploration/node_state_logic.gd")
const ATLAS := preload("res://src/ui/exploration/node_icon_atlas.gd")
const Style := preload("res://src/ui/exploration/node_graph_style.gd")

## 六态全集——两两比较的取样池（顺序即枚举顺序）。
const ALL_STATES: Array[int] = [
	NODE_LOGIC.NodeState.CURRENT, NODE_LOGIC.NodeState.REACHABLE,
	NODE_LOGIC.NodeState.VISITED, NODE_LOGIC.NodeState.UNREACHABLE,
	NODE_LOGIC.NodeState.AP_INSUFFICIENT, NODE_LOGIC.NodeState.FOGGED,
]


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 六态样式取值互不相同
# ═══════════════════════════════════════════════════════════════════════════════

## 四种「已揭示」态（当前/可达/已访问/不可达）两两不同——任意两态之间至少有一根轴
## 取值不同。[br]
## [br][b]为什么是「至少一根轴」而不是「每根轴都不同」[/b]：可达与当前都是全亮
## （veil = 0），它们靠描边粗细与发光区分，硬要求每根轴都不同等于给可达伪造一个
## 它不需要的亮度档。
func test_four_revealed_states_are_pairwise_distinct() -> void:
	var states: Array[int] = [NODE_LOGIC.NodeState.CURRENT,
			NODE_LOGIC.NodeState.REACHABLE, NODE_LOGIC.NodeState.VISITED,
			NODE_LOGIC.NodeState.UNREACHABLE]
	for i: int in states.size():
		for j: int in range(i + 1, states.size()):
			var a: int = states[i]
			var b: int = states[j]
			var sa: Dictionary = NODE_LOGIC.node_state_style(a)
			var sb: Dictionary = NODE_LOGIC.node_state_style(b)
			assert_true(_differs(sa, sb),
					"状态 %d 与 %d 在亮度/描边粗细/发光三根轴上完全相同——玩家分不开"
					% [a, b])


## 六态全集两两不同——含行动力不足与迷雾（后两态不参与「已揭示」比较，
## 但它们也必须与前四态分得开）。
func test_all_six_states_are_pairwise_distinct() -> void:
	for i: int in ALL_STATES.size():
		for j: int in range(i + 1, ALL_STATES.size()):
			var a: int = ALL_STATES[i]
			var b: int = ALL_STATES[j]
			assert_true(_differs(NODE_LOGIC.node_state_style(a),
					NODE_LOGIC.node_state_style(b)),
					"六态中的 %d 与 %d 判定不出差别" % [a, b])


## 亮度档（veil）本身是单调可读的：当前/可达最亮，已访问次之，不可达再暗，
## 行动力不足更暗，迷雾最暗。[br]
## [br][b]为什么单独断言这一条[/b]：上一条只保证「两两不同」，而一组
## 0.1/0.2/0.3/0.4/0.5 也满足两两不同却读不出「哪些跟我有关」——档位顺序才是
## 「亮度也是一层信息」的实际含义。
func test_veil_ladder_orders_states_by_relevance() -> void:
	var cur: float = _veil(NODE_LOGIC.NodeState.CURRENT)
	var reach: float = _veil(NODE_LOGIC.NodeState.REACHABLE)
	var visited: float = _veil(NODE_LOGIC.NodeState.VISITED)
	var unreach: float = _veil(NODE_LOGIC.NodeState.UNREACHABLE)
	var ap: float = _veil(NODE_LOGIC.NodeState.AP_INSUFFICIENT)
	var fog: float = _veil(NODE_LOGIC.NodeState.FOGGED)
	assert_eq(cur, 0.0, "当前节点不该被压暗（玩家现在就在这）")
	assert_eq(reach, 0.0, "可达节点不该被压暗（下一步就该看它）")
	assert_lt(visited, unreach, "已访问应比不可达亮（走过 > 走不到）")
	assert_lt(unreach, ap, "不可达应比行动力不足亮（前面还压着一道红斜线）")
	assert_lt(ap, fog, "迷雾应是最暗的一档")
	assert_lt(visited, 1.0, "已访问不该被压成全黑")


## 强调态（当前/可达/已访问）真的比非强调态（不可达/行动力不足/迷雾）描边粗一档。[br]
## [br]判定旗标由 [test_node_type_icons.gd] 锁；这里锁的是「旗标落到线宽上」——
## 光有旗标而线宽相等，粗细这层信息就不存在。
func test_emphasis_states_draw_thicker_than_non_emphasis() -> void:
	assert_gt(Style.EMPHASIS_BORDER_WIDTH, Style.BORDER_WIDTH,
			"强调态线宽必须大于非强调态——否则 emphasis 旗标形同虚设")
	# 强调态取 EMphasis 宽、非强调态取 BORDER 宽——差值足以在 50% 缩放下分辨
	assert_gte(Style.EMPHASIS_BORDER_WIDTH, Style.BORDER_WIDTH * 1.5,
			"粗细差应至少 1.5 倍（同宽或 1px 差在 50% 缩放下读不出来）")


## 发光只给「当前 + 可达」两态——发光是稀缺资源，给了三态就等于没给。[br]
## [br]渡劫台的类型恒常金色脉冲是另一回事（类型视觉，与状态无关），
## 不在这条状态轴的断言范围内。
func test_glow_is_reserved_for_current_and_reachable() -> void:
	var glow_states: Array[int] = []
	for state: int in ALL_STATES:
		if not str(NODE_LOGIC.node_state_style(state).get("glow", "")).is_empty():
			glow_states.append(state)
	assert_eq(glow_states, [NODE_LOGIC.NodeState.CURRENT,
			NODE_LOGIC.NodeState.REACHABLE] as Array[int],
			"只有当前与可达该发光（两态各用自己的颜色，见 test_node_state_logic）")


## 每种状态都带 veil 键且取值落在 [0, 1]——绘制侧 `.get("veil", 0.0)` 当 alpha 用，
## 越界会画出反色（负 alpha）或整块黑（> 1）。
func test_every_state_exposes_valid_veil() -> void:
	for state: int in ALL_STATES:
		var style: Dictionary = NODE_LOGIC.node_state_style(state)
		assert_true(style.has("veil"), "状态 %d 的样式应含 veil 键" % state)
		var veil: float = float(style["veil"])
		assert_between(veil, 0.0, 1.0,
				"状态 %d 的 veil 应在 [0,1] 内（当 alpha 用）" % state)


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 每种节点类型都能取到标签与图标
# ═══════════════════════════════════════════════════════════════════════════════

## 14 类节点各有一个非空短标签——绘制侧画出「空标签」等于节点没有名字。[br]
## [br][b]为什么限长[/b]：标签排在 48px 的节点下方，超过 4 字就会横向溢出到相邻
## 节点上（同层节点间距 90px）——短标签是布局约束，不是文案偏好。
func test_every_node_type_has_a_short_label() -> void:
	for type_id: int in ATLAS.ATLAS_COLS:
		var label: String = ATLAS.get_label(type_id)
		assert_false(label.is_empty(), "类型 %d 的标签不能为空" % type_id)
		assert_lte(label.length(), 4,
				"类型 %d 的标签 '%s' 超过 4 字——会溢出到相邻节点" % [type_id, label])


## 14 类标签两两不同——同名的两个类型玩家认不出区别。[br]
## [br]「入口」与「洞府」都曾是候选名，这类撞名只有断言拦得住。
func test_every_node_type_label_is_unique() -> void:
	var seen: Dictionary = {}
	for type_id: int in ATLAS.ATLAS_COLS:
		var label: String = ATLAS.get_label(type_id)
		assert_false(seen.has(label),
				"类型 %d 的标签 '%s' 与类型 %d 重复" % [type_id, label, seen.get(label, -1)])
		seen[label] = type_id


## 每种类型都能同时取到标签与图标 region——绘制侧两个取用点都不会落空。[br]
## [br][b]契约两侧对齐[/b]：标签来自 [method NodeIconAtlas.get_label]、
## 图标来自 [method NodeIconAtlas.get_region]；两者都按
## [constant NodeIconAtlas.ATLAS_COLS] 分格，格数不一致就会出现「有标签没图标」。
func test_every_node_type_resolves_label_and_region() -> void:
	var atlas: Texture2D = ATLAS.get_atlas()
	assert_not_null(atlas, "图集纹理应可懒加载构建")
	for type_id: int in ATLAS.ATLAS_COLS:
		var label: String = ATLAS.get_label(type_id)
		var region: Rect2 = ATLAS.get_region(type_id)
		assert_false(label.is_empty(), "类型 %d 应有标签" % type_id)
		assert_gt(region.size.x, 0.0, "类型 %d 图标 region 宽度应 > 0" % type_id)
		assert_gt(region.size.y, 0.0, "类型 %d 图标 region 高度应 > 0" % type_id)
		# region 必须落在图集纹理内——否则 draw_texture_rect_region 画出来是空白
		assert_lte(region.end.x, float(atlas.get_width()),
				"类型 %d 的 region 右沿越过图集宽度（会画出空白）" % type_id)
		assert_lte(region.end.y, float(atlas.get_height()),
				"类型 %d 的 region 下沿越过图集高度（会画出空白）" % type_id)


## 越界的类型 ID 也取得到标签与图标（钳制到合法区间）——不崩、不空。[br]
## [br][b]为什么测这个[/b]：真实 DAG 的类型值来自地图配置，配置写错一个数字
## 不该让整个节点图画出空白格。钳制契约在 [method NodeIconAtlas._clamp_id]。
func test_out_of_range_type_id_falls_back_to_a_real_label_and_region() -> void:
	for bad_id: int in [-1, ATLAS.ATLAS_COLS, 999]:
		assert_false(ATLAS.get_label(bad_id).is_empty(),
				"越界类型 %d 的标签不能为空（应钳制回合法区间）" % bad_id)
		assert_gt(ATLAS.get_region(bad_id).size.x, 0.0,
				"越界类型 %d 的 region 应钳制到合法格" % bad_id)


# ═══════════════════════════════════════════════════════════════════════════════
# 辅助
# ═══════════════════════════════════════════════════════════════════════════════

## 两态样式在三根轴上是否至少有一根不同——
## 亮度（veil）/ 描边粗细（emphasis）/ 发光（glow）。
static func _differs(p_a: Dictionary, p_b: Dictionary) -> bool:
	return _veil_of(p_a) != _veil_of(p_b) \
			or bool(p_a.get("emphasis", false)) != bool(p_b.get("emphasis", false)) \
			or str(p_a.get("glow", "")) != str(p_b.get("glow", ""))


static func _veil_of(p_style: Dictionary) -> float:
	return float(p_style.get("veil", 0.0))


static func _veil(p_state: int) -> float:
	return _veil_of(NODE_LOGIC.node_state_style(p_state))
