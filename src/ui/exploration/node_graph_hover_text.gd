extends RefCounted
## NodeGraphHoverText —— 悬停提示的[b]文案组装[/b]（纯函数，同行内的 tooltip 一致）。[br]
##
## [b]为什么单独成文件[/b]：[code]node_graph_renderer.gd[/code] 的方法面已贴 300 行
## 软上限（coding-standards），而「悬停时说哪三句话」与「画什么、什么时候画」是两件事
## ——前者读渲染快照拼一行字，后者每帧画满整图。拆分口径同 [code]node_graph_tooltip_painter.gd[/code]
## 与 [code]node_graph_landmark.gd[/code]：静态纯函数，宿主经参数传入。[br]
##
## [br][b]★ 三段 = 三个不同的问题 ★[/b]：[br]
##   · [b]地名[/b]（「我去哪儿」）← [code]NodeGraphRenderer.place_name_of[/code]，
##     与画在节点下方的那一行[b]同源[/b]（覆盖表 / 地名池的择优只写在那一个入口）；[br]
##   · [b]类型 + 描述 + 敌人[/b]（「那儿是什么」）← [NodeStateLogic.tooltip_text]
##     既有纯函数（迷雾给「?」，战斗类附敌人构成）；[br]
##   · [b]行动力消耗[/b]（「走过去要付多少」）← [code]ExplorationApRules.cost_for_move[/code]
##     ——[b]按两节点在布局坐标里的距离定价[/b]。[br]
## [br][b]消耗为什么必须走 ApRules[/b]：一是 Boss / 传送 / 灵泉三类[b]不消耗[/b]行动力，
## 就地写死「消耗 1」会让悬停提示与系统实际扣费说两套话；二是本轮起消耗与[b]远近[/b]有关
## （老板 2026-11-27 18:40：「每个节点之间都可达，只是消耗的行动力不一样」），就地写死
## 连「这一跳要几行动力」都答不出来。消灭这种漂移正是
## [code]exploration_ap_rules.gd[/code] 存在的理由。[br]
##
## [br][b]★ 行动力不足时换掉最后一段 ★[/b]：不再是「消耗 N 行动力」而是
## 「行动力不足（需 N）」——同一句话里「要多少」与「你有没有」是两件事，而玩家在这一刻
## 只关心后者。需求量仍写在括号里，因为「差多少」决定了要不要先去别处晃一圈。[br]
##
## [br][b]零状态所有权[/b]（ADR-0031 §2）：纯函数——不读 GSM、不写状态、不建任何 UI。
## 它是给将来那层浮动提示预留的[b]接口[/b]（本轮仍不构建浮动 UI，见
## [code]docs/tech-debt-register.md[/code] 的 DEBT-EUI-008-1）。[br]
##
## 来源: 本轮任务书任务 D 第 3 条（悬停提示接口）、追加规则（距离定价 + 行动力不足文案）、
## ADR-0031 §2、design/gdd/exploration-ui-system.md §2（AC-10 悬停提示）。

## 六态样式查询（迷雾判定——与渲染器画的那一版同源）。
const NodeStateLogicScript := preload("res://src/ui/exploration/node_state_logic.gd")
## 行动力开销规则（距离定价 + 豁免类型恒 0——与系统扣费同源）。
const ApRulesScript := preload("res://src/feature/exploration/exploration_ap_rules.gd")
## 布局几何（两节点距离——与 UI 画出来的位置同源，见 [method cost_of_move]）。
const GeometryScript := preload(
		"res://src/feature/exploration/exploration_node_geometry.gd")
## 地图探明表（按地图 ID 取本图配置——渲染快照里没有它，见 [method map_config_of]）。
const MapCatalogScript := preload(
		"res://src/feature/exploration/exploration_map_catalog.gd")


## 悬停文案——地名 · 类型与描述 · 行动力消耗（三段以「 · 」相连）。[br]
## [br][b]为什么用「 · 」而不是换行[/b]：单行文案既能直接画进现有的 tooltip 盒子
## （[code]NodeGraphTooltipPainter[/code] 按字符数估宽），也能在将来换成多行浮动面板时
## 直接按分隔符拆成三行——两种形态都不必改这里。[br]
## [br][b]迷雾节点的第 2 段是「?」[/b]（[method NodeStateLogic.tooltip_text] 的口径）：
## 玩家确实不知道那儿是什么，但[b]地名照旧给[/b]——未访问的格子正是最需要知道去哪儿
## 的地方（与节点下方那一行地名的可见性规则一致）。[br]
## [br][param p_host] 渲染器（读它的 nodes / states / place_name_of / 地图配置 /
## 当前节点 / 剩余行动力）。[br]
## [param p_node_id] 节点 ID。[br]
## [br][b]返回[/b]：一行文案；节点不在快照里时返回空串（调用方据此不显示）。[br]
## [br][b]纯函数[/b]：同一份快照 + 同一个 ID 永远同一行字（可被单测逐字断言）。
static func text_for(p_host: Control, p_node_id: int) -> String:
	var nodes: Dictionary = p_host.get(&"nodes")
	if not nodes.has(p_node_id):
		return ""
	var detail: Dictionary = nodes[p_node_id]
	var body: String = NodeStateLogicScript.tooltip_text(detail,
			is_fogged(p_host, p_node_id))
	var place: String = str(p_host.call(&"place_name_of", p_node_id))
	if body.is_empty():
		body = place
	return "%s · %s · %s" % [place, body, cost_segment(p_host, p_node_id)]


## 第三段（行动力）——按[b]这一跳的距离[/b]算消耗，行动力不够时换说法。[br]
## [br][b]为什么这一段要读宿主而不只是一个 type_id[/b]：距离定价需要出发节点、目标节点、
## 层计数表三样，而它们全在渲染快照里——收在宿主上比让调用方各传一遍更不容易漏项。[br]
## [br][b]从哪儿出发[/b]：快照的 [code]current_node[/code]（玩家此刻站的那一格）。
## 当前节点未知（-1 / 不在快照里）时退回「从目标自身出发」，即距离 0 → 消耗 1——
## 比不显示消耗更有用，且不会因为一次快照缺字段就让整行文案消失。[br]
## [br][b]返回[/b]：豁免类型 → 「不消耗行动力」；行动力不足 → 「行动力不足（需 N）」；
## 否则 → 「消耗 N 行动力」。[br]
static func cost_segment(p_host: Control, p_node_id: int) -> String:
	var cost: int = cost_of_move(p_host, p_node_id)
	if cost <= 0:
		return "不消耗行动力"
	if needs_more_ap(p_host, p_node_id):
		return "行动力不足（需 %d）" % cost
	return "消耗 %d 行动力" % cost


## 这一跳的行动力消耗（纯计算——供 [method cost_segment] 与单测直调）。[br]
## [br][b]为什么单独一个入口[/b]：单测要断言「同一对节点消耗稳定」「距离翻倍消耗单调
## 不减」这类数值性质，而 [method cost_segment] 只管文案。[br]
## [br][param p_host] 渲染器（读 nodes / current_node / 地图配置 / 剩余行动力）。[br]
## [br][b]返回[/b]：非负整数（豁免类型恒 0）。
static func cost_of_move(p_host: Control, p_node_id: int) -> int:
	var nodes: Dictionary = p_host.get(&"nodes")
	var detail: Dictionary = nodes.get(p_node_id, {})
	var type_id: int = int(detail.get("type", 1))
	if NodeStateLogicScript.AP_EXEMPT_TYPES.has(type_id):
		return 0
	var from_id: int = int(p_host.get(&"current_node"))
	var from_detail: Dictionary = nodes.get(from_id, detail)
	return ApRulesScript.cost_for_move(map_config_of(p_host), from_detail, detail,
			GeometryScript.layer_counts(nodes))


## 是否行动力不足（[b]与六态同一判据[/b]）。[br]
## [br][b]为什么不直接用「剩余 AP < 消耗」[/b]：六态里的行动力不足走的是
## [method NodeStateLogic.verdict_for]（它算不出本图的距离，只看剩余是否 ≥ 1），
## 而文案若按精确消耗判，就会出现「节点画成可达、悬停说行动力不足」——[b]同一张图上
## 两种说法打架[/b]。故这里以六态为准，精确消耗只用于把「还需多少」写进括号。[br]
## [br][b]-1（快照没给）不算不足[/b]：渲染器与单测都可能拿不到剩余行动力，把它当成
## 「是 0」会让每一行悬停文案都写成「行动力不足」——比不写更误导。见
## [member NodeGraphRenderer.ap_remaining] 的「不知道 vs 是 0」注记。
static func needs_more_ap(p_host: Control, p_node_id: int) -> bool:
	var states: Dictionary = p_host.get(&"states")
	if states.has(p_node_id):
		return int(states[p_node_id]) \
				== NodeStateLogicScript.NodeState.AP_INSUFFICIENT
	var ap: int = int(p_host.get(&"ap_remaining"))
	if ap < 0:
		return false
	var nodes: Dictionary = p_host.get(&"nodes")
	return ap < 1 and not NodeStateLogicScript.AP_EXEMPT_TYPES.has(
			int(nodes.get(p_node_id, {}).get("type", 1)))


## 本图的地图配置——[b]注入优先，否则按 map_id 查探明表[/b]。[br]
## [br][b]为什么不用「让宿主把消耗当字符串传进来」[/b]：那样悬停文案的口径会散到调用方；
## 收在这里，全项目只有一个地方决定「消耗怎么读」。[br]
## [br][b]为什么默认能自己查到[/b]：[code]MapCatalog.config_for[/code] 是纯静态函数
## （不需要系统在场），所以生产路径[b]不必[/b]有任何注入就得到正确的 [code]ap_cost[/code]
## ——注入口只为「探明表之外的本图配置」（将来配置进存档时）留的。[br]
## [br][b]查不到时的口径[/b]：[code]config_for[/code] 对未登记地图返回空字典，
## [code]ApRules[/code] 于是回落出厂默认（单位距离 120px、单次上限 4）——与
## 「配置缺失时系统怎么扣」逐字一致。[br]
## [br][param p_host] 渲染器。[br]
## [br][b]返回[/b]：地图配置字典（可能为空）。
static func map_config_of(p_host: Control) -> Dictionary:
	var injected: Variant = p_host.get(&"_map_config")
	if injected is Dictionary and not (injected as Dictionary).is_empty():
		return injected
	var map_id: StringName = p_host.get(&"map_id") as StringName
	if str(map_id).is_empty():
		return {}
	return MapCatalogScript.config_for(map_id)


## 行动力消耗短语（[b]无距离版[/b]——纯函数，按「最小一跳」算）。[br]
## [br][b]返回[/b]：豁免类型 / 开销 0 → [code]"不消耗行动力"[/code]；
## 否则 [code]"消耗 N 行动力"[/code]。[br]
## [br][b]为什么区分「不消耗」与「消耗 0」两种说法[/b]：只给数字的话，玩家看到
## 「消耗 0 行动力」会以为是配置漏了；「不消耗」才是类别（Boss / 传送 / 灵泉）的说法。[br]
## [br][b]★ 与 [method cost_segment] 的分工 ★[/b]：本方法回答「这类格子要付多少」
## （与出发位置无关——距离按 0 算，即公式的下限 1）；[method cost_segment] 回答
## 「从玩家此刻站的地方走过去要付多少」，它还要读快照里的当前节点与剩余行动力。[br]
## [br][b]为什么保留这个无距离入口[/b]：签名被既有单测直接调用（
## [code]test_node_graph_hover.gd[/code] 的 [code]test_cost_text_distinguishes_free_from_paid[/code]），
## 且「这一类格子贵不贵」本身是个有意义的问题（图鉴、攻略、调试面板都要问它）。[br]
## [br][param p_map_config] 地图配置（缺键按默认单位/上限）；[param p_type_id] 节点类型。
static func cost_text(p_map_config: Dictionary, p_type_id: int) -> String:
	var cost: int = ApRulesScript.cost_by_distance(p_map_config, p_type_id, 0.0)
	if cost <= 0:
		return "不消耗行动力"
	return "消耗 %d 行动力" % cost


## 节点是否迷雾覆盖（[method text_for] 的判定）——六态注入时按六态，否则回退
## legacy 直判（与渲染器画的那一版同口径，不会出现「画成亮的、文案说不知道」）。
static func is_fogged(p_host: Control, p_node_id: int) -> bool:
	var states: Dictionary = p_host.get(&"states")
	if states.has(p_node_id):
		return int(states[p_node_id]) == NodeStateLogicScript.NodeState.FOGGED
	return bool(p_host.call(&"_is_fogged", p_node_id))
