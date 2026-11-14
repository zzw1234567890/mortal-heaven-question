extends RefCounted
## ExplorationActionSpring —— 行动力泉（灵泉）节点的效果执行子模块。[br]
## [br][b]职责[/b]：把 GDD §节点类型一览「行动力泉——回复全部行动力」落到
## [code]GameStateManager.exploration.action_points[/code] 上。[br]
## [br][b]为什么要单独一处[/b]：与 [ExplorationRest] / [ExplorationEconomy] 同层——
## [code]ExplorationSystem[/code] 只做节点导航与委托分发，数值结算放进它会让
## 「地图怎么长」与「行动力怎么回」耦在一处；宿主只留一个转发方法。[br]
## [br][b]读写都走既有设施[/b]：[br]
##   · 读——GSM [code]exploration.action_points[/code] / [code]max_action_points[/code]；[br]
##   · 写——GSM 第二层原子方法 [code]set_exploration_ap[/code]（与
##     [code]move_to_node[/code] 的扣费写入口同一个，不另开第二条 AP 通路）。[br]
## [br][b]夹到上限[/b]：回复量 = [code]max(上限 - 当前, 0)[/code]——满行动力时回复 0，
## 绝不越过 [code]max_action_points[/code]。存档里越界的 [code]action_points[/code]
## （负数 / 大于上限）先按 [code][0, 上限][/code] 夹一次再算缺口，不放大也不倒扣。[br]
## [br][b]公式只有一个来源[/b]：[method restore_for] 是「回复量 = 上限 - 当前」的
## 唯一实现——UI 侧 [code]NodeInteractionRules.spring_restore_all[/code] 转发到这里，
## 两侧不会各算一套。[br]
## [br][b]返回实际回复量[/b]：写回不可用时返回 0（宁可提示「回复 0 点」也不虚报
## ——UI 展示的是系统返回值，不自行计算）。[br]
## [br][b]不做「每图限 1 次」计数[/b]：GDD 节点表提到「每图限 1 次」，但当前 DAG
## 生成器的权重表（[code]DIFFICULTY_CONFIGS.weights[/code]）不含灵泉键，
## 生产路径不会刷出灵泉节点；次数上限需要新的 map_states 计数位，与本轮
## 「最小可用交互」一并留待生成器接入时定（见会话遗留）。[br]
##
## 来源: design/gdd/exploration-system.md §节点类型一览 / §4 节点导航 / §8 边界、
## design/gdd/exploration-ui-system.md §4 灵泉弹窗（AC-4）、
## 先例 [code]exploration_rest.gd[/code]。

## 父节点引用——ExplorationSystem 实例（仅用于表明归属，查找走 SceneTree）。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


# ═══════════════════════════════════════════════════════════════════════════════
# 公式（纯函数——不读不写任何状态，GUT 直调可测）
# ═══════════════════════════════════════════════════════════════════════════════

## 回复量——[code]max(上限 - 当前, 0)[/code]（夹到上限的算术形式）。[br]
## [b]单一来源[/b]：UI 的 [code]NodeInteractionRules.spring_restore_all[/code]
## 转发到本方法（交叉校验系统返回值时用同一份公式，不重复实现）。[br]
## [param p_current_ap] 当前行动力（≤0 视为已耗尽）。[br]
## [param p_max_ap] 行动力上限（≤0 视为无上限可回——不臆造）。
static func restore_for(p_current_ap: int, p_max_ap: int) -> int:
	if p_max_ap <= 0:
		return 0
	return maxi(p_max_ap - clampi(p_current_ap, 0, p_max_ap), 0)


# ═══════════════════════════════════════════════════════════════════════════════
# 结算（读 → 计划 → 写回）
# ═══════════════════════════════════════════════════════════════════════════════

## 行动力泉结算——行动力回复至上限，返回[b]实际写入[/b]的回复量。[br]
## [br][param p_node_id] 节点 ID（本模块不使用；由调用方在「到达灵泉」后触发，
## 保留形参以对齐探索系统的节点 API 口径）。[br]
## [br][b]返回[/b]：实际回复量（已满 / GSM 不可用 / 写回入口缺失时为 0）。[br]
## [br][b]满行动力不写状态[/b]：回复量为 0 时直接返回，不做无意义写回
## （避免污染变更记录）。
func use_action_spring(p_node_id: int) -> int:
	var gsm: Node = _get_gsm()
	if gsm == null:
		push_warning("ExplorationActionSpring: GSM 不可用，灵泉未结算（node=%d）" % p_node_id)
		return 0
	if not gsm.has_method(&"set_exploration_ap"):
		push_warning("ExplorationActionSpring: GSM 缺少 set_exploration_ap，灵泉未结算")
		return 0

	var max_ap: int = int(gsm.exploration.get("max_action_points", 0))
	var current: int = int(gsm.exploration.get("action_points", 0))
	var restored: int = restore_for(current, max_ap)
	if restored <= 0:
		return 0

	var clamped: int = clampi(current, 0, maxi(max_ap, 0))
	gsm.call(&"set_exploration_ap", clamped + restored, max_ap)
	return restored


## GSM 引用——经父节点的 [code]_get_gsm[/code]（查找口径单一）。
func _get_gsm() -> Node:
	if _parent == null:
		return null
	return _parent.call("_get_gsm")
