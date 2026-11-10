class_name CombatActorSelection
extends RefCounted
## CombatActorSelection —— 「当前操作角色」显式状态（combat-ui-interaction 001 /
## 本轮：施法者从阵位顺序裁定改为显式状态）。
##
## [b]职责[/b]：维护「现在我方由谁行动」——[br]
##   - [method refresh]：按我方阵位快照[b]自动筛出[/b]候选（已占用且未阵亡），
##     当前角色仍合法则保留，否则顺位到第一个候选（阵亡/离场后自动换人）；[br]
##   - [method select]：玩家显式切换——只接受候选里的人（点了阵亡/空位不生效）；[br]
##   - [method current_id]：出牌施法者的[b]唯一读取入口[/b]。[br]
## [br][b]为什么独立成状态类[/b]：此前施法者由 [code]CombatCasterRules[/code]
## 按阵位顺序临时裁定——多角色阵容里无论玩家点谁，出牌一律记在阵位首位身上。
## 把「谁在行动」提成显式状态后：玩家可切换、阵亡自动顺位、测试可断言，
## 施法者口径不再依赖「数组第一个」这种隐式约定。[br]
## [br][b]纯状态[/b]（ADR-0031 Logic 内核模式）：不持有节点、无信号、无副作用——
## 阵位快照由调用方现读传入（n ≤ 6，成本可忽略）。
##
## @experimental
## 来源: ADR-0031、ADR-0016 §阵位数据模型、design/gdd/combat-ui-system.md §手牌交互、
## production/epics/combat-ui-interaction/story-003-drag-play-flow.md。

## 施法者裁定纯函数（阵位常量与 NO_CASTER 哨兵的单一定义处——本类不裸写）。
const CasterRules := preload("res://src/ui/combat/shared/combat_caster_rules.gd")

## 无当前角色（全灭 / 空阵位 / 快照不可用）——与 [constant CombatCasterRules.NO_CASTER] 同值。
const NO_ACTOR: int = CasterRules.NO_CASTER

## 当前操作角色 ID（[constant NO_ACTOR] = 无）。
var _current: int = NO_ACTOR
## 候选列表（近一次 refresh 的结果——供 UI 灰显/切换用）。
var _candidates: Array[int] = []


## 用阵位快照刷新候选与当前角色。[br]
## [br][b]顺位规则[/b]：当前角色仍在候选里 → 保留（玩家选的不能被自动改掉）；
## 否则取候选第一个；候选为空 → [constant NO_ACTOR]。[br]
## [br][param p_field] [code]DeploymentSystem.get_field()[/code] 快照（或同形状数组）。[br]
## [b]返回[/b]: 刷新后的当前角色 ID。
func refresh(p_field: Variant) -> int:
	_candidates = eligible_ids(p_field)
	if _current != NO_ACTOR and _candidates.has(_current):
		return _current
	_current = _candidates[0] if not _candidates.is_empty() else NO_ACTOR
	return _current


## 显式切换当前操作角色。[br]
## [br][b]只接受候选里的角色[/b]：阵亡 / 未上场 / 空位的 ID 不生效（返回 false 且
## 保留原当前角色——不把「点错了」变成「没人行动」）。[br]
## [br][b]返回[/b]: 是否切换成功。
func select(p_character_id: int, p_field: Variant) -> bool:
	_candidates = eligible_ids(p_field)
	if not _candidates.has(p_character_id):
		return false
	_current = p_character_id
	return true


## 当前操作角色 ID（[constant NO_ACTOR] = 无）。
func current_id() -> int:
	return _current


## 候选角色 ID 列表（副本——调用方改它不会污染状态）。
func candidates() -> Array[int]:
	return _candidates.duplicate()


## 某角色是否可当当前操作角色（阵位里已占用且未阵亡）。
func is_eligible(p_character_id: int, p_field: Variant) -> bool:
	return eligible_ids(p_field).has(p_character_id)


## 清空状态（战斗结束 / 重开战）。
func clear() -> void:
	_current = NO_ACTOR
	_candidates.clear()


## 阵位快照 → 可行动角色 ID（按 slot_index 升序，空位/阵亡跳过）。[br]
## [br][b]排序口径复用 [code]CombatCasterRules[/code][/b]：两处若各排各的，会出现
## 「自动顺位」与「兜底裁定」选出不同的人。
static func eligible_ids(p_field: Variant) -> Array[int]:
	var ids: Array[int] = []
	for raw: Variant in CasterRules.sorted_field(p_field):
		if not (raw is Dictionary):
			continue
		var entry: Dictionary = raw
		var character_id: int = int(entry.get("character_id", NO_ACTOR))
		if character_id < 0:
			continue
		var state: int = int(entry.get("state", CasterRules.FIELD_STATE_READY))
		if state == CasterRules.FIELD_STATE_DEAD or state == CasterRules.FIELD_STATE_EMPTY:
			continue
		ids.append(character_id)
	return ids
