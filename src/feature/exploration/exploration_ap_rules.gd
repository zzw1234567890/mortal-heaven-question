extends RefCounted
## ExplorationApRules —— 节点移动的行动力（AP）开销规则（纯函数）。[br]
## [br][b]为什么单独一处[/b]：扣费此前是 [code]move_to_node[/code] /
## [code]can_move_to[/code] 里各写一遍的就地逻辑（[code]ap_cost = 1[/code] +
## [code]AP_EXEMPT_TYPES.has(type)[/code]），而消耗规则要求「按地图配置扣」
## ——配置化之后若两处仍各解析一遍，判定与扣费必然漂移（查询说能走、移动扣不起）。
## 本模块是解析的唯一入口，两个调用方都转发到它。[br]
##
## [br][b]★ 本轮核心变更：按「距离」定价，不再按「格」定价 ★[/b]（老板 2026-11-27
## 18:40：「每个节点之间都可达，只是消耗的行动力不一样」）：[br]
## [br]   [code]cost = clamp(round(distance / UNIT), 1, MAX)[/code][br]
## [br][param distance] 是两节点在[b]布局坐标[/b]里的欧氏距离（px）——由
## [code]exploration_node_geometry.gd[/code] 算，与 UI 画出来的位置[b]同源[/b]
## （否则「走过去花了 2 点、看起来只有一格远」这种漂移玩家看得出来、单测抓不到）。[br]
## [br][b]为什么不按步数/邻接[/b]：DAG 的边表已经不再决定可达性（取消路径限制），
## 剩下的「远近」只能由几何表达；而几何恰好是玩家唯一看得见的东西——按它定价，
## 「贵」这件事在画面上是自明的。[br]
##
## [br][b]配置键[/b]（地图配置字典）：[br]
##   · [code]ap_distance_unit[/code] —— [b]每 1 点行动力值多少 px[/b]
##     （缺键 / ≤ 0 → [constant DEFAULT_DISTANCE_UNIT] = 120.0）；[br]
##   · [code]ap_move_max[/code] —— 单次移动的行动力上限（缺键 / < 1 →
##     [constant DEFAULT_MOVE_MAX] = 4）；[br]
##   · [code]ap_cost[/code] —— [b]旧口径（按格定价）的遗留键[/b]，本轮起不再参与
##     移动开销计算（见下方「★ 有意改动 ★」）；保留在配置表里只为旧存档与旧地图表
##     不报错，读取它不会改变任何行为。[br]
##   · [code]ap_costs[/code] —— 同上，按类型的覆盖表，本轮起不参与移动定价。[br]
##
## [br][b]★ 有意改动（需在报告单列）★[/b]：移动开销[b]不再[/b]读 [code]ap_cost[/code] /
## [code]ap_costs[/code]。原口径下「把某张图的 ap_cost 调成 2」能整图涨价，现在涨价
## 靠调小 [code]ap_distance_unit[/code]（同样的用途，但以距离为准，不是每格一刀切）。[br]
##
## [b]豁免优先[/b]：豁免类型（Boss / 传送 / 灵泉）恒为 0——即使配置里给它们
## 写了非零值也不生效。豁免是系统级不变量（GDD §节点类型一览「传送——不消耗
## 行动力」「行动力泉——0」），不是地图可调项。[br]
## [br][b]纯函数[/b]：无状态、不访问 Autoload、不读 GSM——GUT 直调可测
## （先例 [code]node_state_logic.gd[/code] / [code]ap_display_rules.gd[/code]）。[br]
## [br][b]与 UI 侧 [code]NodeStateLogic.AP_EXEMPT_TYPES[/code] 的关系[/b]：那份是
## UI 的数值副本（headless 下不加载 Feature 层），单测锁定两者同源；本文件的
## [constant AP_EXEMPT_TYPES] 是 Feature 层的规范副本（供本模块与继承链共用）。[br]
##
## 来源: design/gdd/exploration-system.md §4 移动规则 / §节点类型一览、
## design/gdd/action-point-system.md §公式 3 移动后行动力 + §调优参数、
## 本轮任务书追加规则（全连通 + 距离定价）、
## 先例 [code]exploration_action_spring.gd[/code]（公式单一来源）。

## 每 1 点行动力值的距离（px）——配置缺 [code]ap_distance_unit[/code] 键时的口径。[br]
## [br][b]为什么是 120[/b]：布局的层间距 104、同层间距 200（见
## [code]exploration_node_geometry.gd[/code]），120 落在这两者之间——于是
## 「上下相邻一层」≈ 0.87 → 取整后 1 点，「同层隔一格」≈ 1.67 → 2 点。这是最贴近
## 玩家直觉的一档：「挪一层」便宜、「跨一片」贵，而两端都读得出区别。[br]
## [br][b]为什么不用 104（层间距本身）[/b]：那样「任何一次相邻移动」都恰好是 1.0，
## 取整后恒为 1——距离定价退化成「按格定价」且还多了一次浮点运算，本轮的目的
## （让远近真的影响价格）落空。[br]
## [br][b]为什么不做成「按图的平均间距现算」[/b]：那会让同一张图的规格随节点增删
## 浮动，同一对节点的消耗在两次生成之间不一样——玩家感知为「这游戏价钱会变」。
const DEFAULT_DISTANCE_UNIT: float = 120.0

## 单次移动的行动力上限——配置缺 [code]ap_move_max[/code] 键时的口径。[br]
## [br][b]为什么必须有上限[/b]：全连通之后，「从第一层直接跳到最后一层」在几何上是
## 一次移动，若按纯距离算可以一次吃掉十几点——玩家点一下就没行动力了，而画面上
## 那只是一次点击。上限把「一次点击最多付多少」钉在可预期的区间里。[br]
## [br][b]为什么是 4[/b]：出厂图的行动力上限是 10（[code]enter_map[/code] 的默认
## [code]max_ap[/code]），4 让一次最贵的移动最多占 40%——两次长跳之后仍留有余量
## 走到 Boss，不会出现「一步走死」。[br]
## [br][b]与 GDD 的关系[/b]：GDD §调优参数给的「每格消耗 1，安全范围 1-2」是
## [b]旧口径[/b]（按格定价）；按距离定价后「单次上限」是它在新口径下的对应旋钮，
## 取值区间由本常量与地图配置的 [code]ap_move_max[/code] 共同决定。
const DEFAULT_MOVE_MAX: int = 4

## AP 豁免节点类型——不消耗行动力，且 AP=0 时仍可移入。[br]
## Feature 层规范副本，与继承链的 [code]ExplorationSystem.AP_EXEMPT_TYPES[/code]
## 逐项同源（3=BOSS / 6=TELEPORT / 7=ACTION_SPRING）——两处都是
## [code]NodeType[/code] 枚举值，改一处必须同改另一处，单测锁定。
const AP_EXEMPT_TYPES: Array[int] = [3, 6, 7]

## 布局几何——两节点距离的来源（与 UI 画出来的位置同源，见类文档）。
const Geometry := preload("res://src/feature/exploration/exploration_node_geometry.gd")


## 单次移动的 AP 开销——[b]按两节点在布局坐标里的距离定价[/b]。[br]
## [br][param p_map_config] 地图配置字典（可空——空字典按全默认处理）。[br]
## [param p_from_detail] 出发节点详情（含 layer/idx）。[br]
## [param p_to_detail] 目标节点详情（含 layer/idx/type）。[br]
## [param p_counts] 层计数表（[method ExplorationNodeGeometry.layer_counts] 的结果）。[br]
## [br][b]返回[/b]：非负整数开销。[br]
## [br][b]公式[/b]：[code]clamp(round(distance / UNIT), 1, MAX)[/code]；豁免类型恒 0。[br]
## [br][b]为什么下限是 1 而不是 0[/b]：0 意味着「白走」——玩家会找一个 0 消耗的
## 落点反复横跳来刷访问状态。最小 1 让每次移动都有代价，而豁免类型（Boss/传送/
## 灵泉）的 0 是[b]类型级[/b]的规则，两者不是一回事。[br]
## [br][b]为什么负数/非法配置按默认值处理[/b]：配置是外部数据（地图表 / 存档 /
## 手改），unit ≤ 0 会让除法爆炸、max < 1 会让 clamp 出 0 或负数——按默认值处理比
## 按 0 处理更不容易被无声利用。[br]
## [br][b]为什么豁免先判[/b]：豁免类型即使被配置写成非零也必须是 0（见类注释），
## 且它连距离都不必算——先判能省掉一次开方。
static func cost_for_move(p_map_config: Dictionary, p_from_detail: Dictionary,
		p_to_detail: Dictionary, p_counts: Dictionary) -> int:
	var node_type: int = int(p_to_detail.get("type", 1))
	if AP_EXEMPT_TYPES.has(node_type):
		return 0
	return cost_by_distance(p_map_config, node_type,
			Geometry.distance_between(p_from_detail, p_to_detail, p_counts))


## 距离 → 开销（[method cost_for_move] 的核心，单独一个入口便于逐值断言）。[br]
## [br][b]为什么要拆出来[/b]：单测要验的正是「距离翻倍 → 消耗单调不减」这类
## 纯数值性质，而构造两个真实节点的详情反而绕远（还要凑层计数表）。[br]
## [br][param p_distance] 两节点在布局坐标里的距离（px）；负值按 0 处理。[br]
## [br][b]返回[/b]：非负整数开销（豁免类型恒 0）。
static func cost_by_distance(p_map_config: Dictionary, p_node_type: int,
		p_distance: float) -> int:
	var node_type: int = int(p_node_type)
	if AP_EXEMPT_TYPES.has(node_type):
		return 0
	var unit: float = _distance_unit(p_map_config)
	var cap: int = _move_max(p_map_config)
	var raw: float = maxf(p_distance, 0.0) / unit
	return clampi(int(roundf(raw)), 1, cap)


## 本图的「每 1 点行动力值多少 px」。[br]
## [br][b]返回[/b]：正浮点数（缺键 / 非数 / ≤ 0 → [constant DEFAULT_DISTANCE_UNIT]）。
static func distance_unit_of(p_map_config: Dictionary) -> float:
	return _distance_unit(p_map_config)


## 本图的「单次移动上限」。[br]
## [br][b]返回[/b]：≥ 1 的整数（缺键 / 非数 / < 1 → [constant DEFAULT_MOVE_MAX]）。
static func move_max_of(p_map_config: Dictionary) -> int:
	return _move_max(p_map_config)


## 每 1 点行动力值的距离——配置解析（缺键 / 非法 → 默认值）。[br]
## [br][b]为什么先判类型再转型[/b]：配置是外部数据，[code]float([])[/code] /
## [code]int([])[/code] 在 Godot 里会打一条 engine error 再返回 0——值虽然被下面的
## 范围检查兜住了，但那行报错会污染每一次调用的日志（本项目的测试对「Unexpected
## Errors」是零容忍的）。[br]
## [br][b]非数按缺键处理[/b]：字符串 "bad" 与「没写这个键」在语义上是同一件事
## ——配置写坏了就当没写。
static func _distance_unit(p_map_config: Dictionary) -> float:
	var raw: Variant = p_map_config.get("ap_distance_unit", DEFAULT_DISTANCE_UNIT)
	var configured: float = float(raw) if (raw is float or raw is int) \
			else DEFAULT_DISTANCE_UNIT
	return configured if configured > 0.0 else DEFAULT_DISTANCE_UNIT


## 单次移动上限——配置解析（缺键 / 非法 → 默认值）。
static func _move_max(p_map_config: Dictionary) -> int:
	var raw: Variant = p_map_config.get("ap_move_max", DEFAULT_MOVE_MAX)
	var configured: int = int(raw) if (raw is int or raw is float) else DEFAULT_MOVE_MAX
	return configured if configured >= 1 else DEFAULT_MOVE_MAX
