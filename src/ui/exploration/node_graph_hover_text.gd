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
##   · [b]行动力消耗[/b]（「走过去要付多少」）← [code]ExplorationApRules.cost_for[/code]。[br]
## [br][b]消耗为什么必须走 ApRules[/b]：Boss / 传送 / 灵泉三类[b]不消耗[/b]行动力，
## 就地写死「消耗 1」会让悬停提示与系统实际扣费说两套话——而消灭这种漂移正是
## [code]exploration_ap_rules.gd[/code] 存在的理由。[br]
##
## [br][b]零状态所有权[/b]（ADR-0031 §2）：纯函数——不读 GSM、不写状态、不建任何 UI。
## 它是给将来那层浮动提示预留的[b]接口[/b]（本轮不构建浮动 UI，见
## [code]docs/tech-debt-register.md[/code] 的 DEBT-EUI-008-1）。[br]
##
## 来源: 本轮任务书任务 D 第 3 条（仅预留悬停提示接口）、ADR-0031 §2、
## design/gdd/exploration-ui-system.md §2（AC-10 悬停提示）。

## 六态样式查询（迷雾判定——与渲染器画的那一版同源）。
const NodeStateLogicScript := preload("res://src/ui/exploration/node_state_logic.gd")
## 行动力开销规则（豁免类型恒 0——与系统扣费同源）。
const ApRulesScript := preload("res://src/feature/exploration/exploration_ap_rules.gd")
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
## [br][param p_host] 渲染器（读它的 nodes / states / place_name_of / 地图配置）。[br]
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
	var type_id: int = int(detail.get("type", 1))
	return "%s · %s · %s" % [place, body,
			cost_text(map_config_of(p_host), type_id)]


## 本图的地图配置——[b]注入优先，否则按 map_id 查探明表[/b]。[br]
## [br][b]为什么不用「让宿主把消耗当字符串传进来」[/b]：那样悬停文案的口径会散到调用方；
## 收在这里，全项目只有一个地方决定「消耗怎么读」。[br]
## [br][b]为什么默认能自己查到[/b]：[code]MapCatalog.config_for[/code] 是纯静态函数
## （不需要系统在场），所以生产路径[b]不必[/b]有任何注入就得到正确的 [code]ap_cost[/code]
## ——注入口只为「探明表之外的本图配置」（将来配置进存档时）留的。[br]
## [br][b]查不到时的口径[/b]：[code]config_for[/code] 对未登记地图返回空字典，
## [code]ApRules.cost_for[/code] 于是回落 GDD 默认开销 1——与「配置缺失时系统怎么扣」
## 逐字一致。[br]
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


## 行动力消耗短语（第 3 段——纯函数）。[br]
## [br][b]返回[/b]：豁免类型 / 开销 0 → [code]"不消耗行动力"[/code]；
## 否则 [code]"消耗 N 行动力"[/code]。[br]
## [br][b]为什么区分「不消耗」与「消耗 0」两种说法[/b]：只给数字的话，玩家看到
## 「消耗 0 行动力」会以为是配置漏了；「不消耗」才是类别（Boss / 传送 / 灵泉）的说法。
static func cost_text(p_map_config: Dictionary, p_type_id: int) -> String:
	var cost: int = ApRulesScript.cost_for(p_map_config, p_type_id)
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
