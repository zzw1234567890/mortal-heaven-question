class_name CombatTargetPicking
extends RefCounted
## CombatTargetPicking —— 目标点选的累加规则（纯函数，combat-ui-interaction 001 /
## 本轮：卡面 target_type 驱动单/多目标）。
##
## [b]职责[/b]：把「玩家点了哪个角色」按卡面的目标模式折进已选目标列表——[br]
##   - [b]单体[/b]：新目标[b]替换[/b]旧目标（绝不累加——单目标卡选两个会让
##     「打谁」变得含糊，系统侧也会打两次）；[br]
##   - [b]多选[/b]：再点同一目标[b]取消[/b]（可纠错），点新目标追加；[br]
##   - [b]自身 / 全体[/b]：目标由系统决定，玩家的点选被忽略；[br]
##   - [b]未知词[/b]：保持旧行为（允许多选，同多选规则）。[br]
## [br][b]为什么独立成纯函数[/b]：「单目标卡拒绝多选」是本轮的验收点之一，
## 把它写进输入组件的 if 里就只能靠手测；抽出来后边界可零 UI 依赖断言。
## [br][b]纯函数[/b]（ADR-0031 Logic 内核模式）：无状态、无副作用、不改入参数组。
##
## @experimental
## 来源: ADR-0031、design/gdd/card-effect-engine.md §5 目标选择规则、
## production/epics/combat-ui-interaction/story-003-drag-play-flow.md、
## story-005-target-selection.md。

## 目标模式（引用 [CombatTargetPolicy] 的单一定义处——本类不裸写枚举值）。
const Policy := preload("res://src/ui/combat/shared/combat_target_policy.gd")

## 无目标哨兵（与 [code]CombatTargetRules.NO_TARGET[/code] 同口径）。
const NO_TARGET: int = -1


## 把一次点选折进已选目标。[br]
## [br][param p_existing] 已选目标（只读——返回新数组）。[br]
## [param p_target_id] 本次点选的角色 ID（负数 / 无效 → 原样返回副本）。[br]
## [param p_mode] 目标模式（[code]CombatTargetPolicy.MODE_*[/code]）。[br]
## [b]返回[/b]: 新的目标列表。
static func apply(p_existing: Array, p_target_id: int, p_mode: int) -> Array[int]:
	var picked: Array[int] = _ints(p_existing)
	if p_target_id < 0:
		return picked
	match p_mode:
		Policy.MODE_SELF, Policy.MODE_AUTO_ALL:
			# 目标由系统决定——玩家的点选不参与（返回原值，避免「点了没反应」被误读成 bug）。
			return picked
		Policy.MODE_SINGLE:
			# 单体：替换（不累加——这就是「单目标卡拒绝多选」的落点）。
			return [p_target_id]
		_:
			# 多选 / 未知词：再点取消，新点追加。
			if picked.has(p_target_id):
				picked.erase(p_target_id)
			else:
				picked.append(p_target_id)
			return picked


## 该模式是否允许一次持有多个目标（单体恒 false）。
static func allows_multiple(p_mode: int) -> bool:
	return p_mode != Policy.MODE_SINGLE and p_mode != Policy.MODE_SELF \
			and p_mode != Policy.MODE_AUTO_ALL


## 点选后是否应立即确认出牌（单体——点完即出；多选要留给玩家点卡确认）。
static func confirms_immediately(p_mode: int) -> bool:
	return p_mode == Policy.MODE_SINGLE


## 是否已完成目标选择（空目标不算完成——默认策略兜底，见 CombatTargetRules）。
static func is_complete(p_targets: Array, p_mode: int) -> bool:
	if p_mode == Policy.MODE_SELF or p_mode == Policy.MODE_AUTO_ALL:
		return true
	return not p_targets.is_empty()


## 宽松转 int 数组（跳过非整型 / 负值 / 重复）。
static func _ints(p_raw: Array) -> Array[int]:
	var out: Array[int] = []
	for raw: Variant in p_raw:
		var value: int = int(raw)
		if value < 0 or out.has(value):
			continue
		out.append(value)
	return out
