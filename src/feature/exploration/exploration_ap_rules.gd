extends RefCounted
## ExplorationApRules —— 节点移动的行动力（AP）开销规则（纯函数）。[br]
## [br][b]为什么要单独一处[/b]：扣费此前是 [code]move_to_node[/code] /
## [code]can_move_to[/code] 里各写一遍的就地逻辑（[code]ap_cost = 1[/code] +
## [code]AP_EXEMPT_TYPES.has(type)[/code]），而本轮的消耗规则要求「按地图配置扣」
## ——配置化之后若两处仍各解析一遍，判定与扣费必然漂移（查询说能走、移动扣不起）。
## 本模块是解析的唯一入口，两个调用方都转发到它。[br]
## [br][b]配置键[/b]（地图配置字典）：[br]
##   · [code]ap_cost[/code] —— 本图每次移动的默认开销（缺键 → 1，GDD 默认值；
##     GDD §调优参数「每格消耗 1，安全范围 1-2」）；[br]
##   · [code]ap_costs[/code] —— 按节点类型的覆盖表 [code]{类型ID: 开销}[/code]
##     （缺该类型的键 → 回落 [code]ap_cost[/code]）。[br]
## [br][b]豁免优先[/b]：豁免类型（Boss / 传送 / 灵泉）恒为 0——即使配置里给它们
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
## 先例 [code]exploration_action_spring.gd[/code]（公式单一来源）。

## 默认每格开销——配置缺 [code]ap_cost[/code] 键时的口径（GDD 默认值 1）。
const DEFAULT_COST: int = 1

## AP 豁免节点类型——不消耗行动力，且 AP=0 时仍可移入。[br]
## Feature 层规范副本，与继承链的 [code]ExplorationSystem.AP_EXEMPT_TYPES[/code]
## 逐项同源（3=BOSS / 6=TELEPORT / 7=ACTION_SPRING）——两处都是
## [code]NodeType[/code] 枚举值，改一处必须同改另一处，单测锁定。
const AP_EXEMPT_TYPES: Array[int] = [3, 6, 7]


## 单次移动的 AP 开销——配置优先，缺键回落默认值；豁免类型恒为 0。[br]
## [br][param p_map_config] 地图配置字典（可空——空字典按全默认处理）。[br]
## [param p_node_type] 目标节点的 [code]NodeType[/code] 枚举值。[br]
## [br][b]返回[/b]：非负整数开销。[br]
## [br][b]为什么负数/非法值按默认值处理[/b]：配置是外部数据（地图表 / 存档 /
## 手改），负开销会让移动「回血」——按默认值处理比按 0 处理更不容易被无声利用。[br]
## [br][b]为什么豁免先判[/b]：豁免类型即使被配置写成非零也必须是 0（见类注释）。
static func cost_for(p_map_config: Dictionary, p_node_type: int) -> int:
	var node_type: int = int(p_node_type)
	if AP_EXEMPT_TYPES.has(node_type):
		return 0
	var per_type: Variant = p_map_config.get("ap_costs", {})
	if per_type is Dictionary and (per_type as Dictionary).has(node_type):
		var configured: int = int((per_type as Dictionary)[node_type])
		return configured if configured >= 0 else DEFAULT_COST
	var default_cost: int = int(p_map_config.get("ap_cost", DEFAULT_COST))
	return default_cost if default_cost >= 0 else DEFAULT_COST
