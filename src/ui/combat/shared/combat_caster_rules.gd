class_name CombatCasterRules
extends RefCounted
## CombatCasterRules —— 出牌施法者裁定纯函数（DEBT-CBT-018-10 第四阶段：caster_id 接线）。
##
## [b]职责[/b]：从「我方阵位快照」判定本次出牌的施法者角色 ID——[br]
##   - 按 slot_index 升序取[b]第一个已占用且未阵亡[/b]的角色；[br]
##   - 判不出（空阵位 / 全阵亡 / 快照不可用）返回 [code]-1[/code]（[b]不猜[/b]）。
## [br][b]为什么是「阵位第一个存活角色」[/b]：combat-ui-interaction epic（0/9 未实现）
## 尚无「当前操作角色」概念——玩家点谁、谁在行动都还没建模。本裁定是[b]临时口径[/b]：
## 出牌施法者取我方阵位第一个存活角色，理由是它与 [DeployPanel] 确认出战时经
## [code]DeploymentSystem.setup_field()[/code] 写入的名册[b]同源[/b]（同一份「谁上场了」），
## 不引入第二份真理来源；interaction epic 落地「当前角色」后应改为显式传入，
## 本裁定降级为兜底。[br]
## [br][b]「不猜」的含义[/b]：判不出时返回 [code]-1[/code]，由调用方原样传给
## [code]CombatSystem.play_card()[/code]——下游据此不结算倍率伤害与治疗
## （不臆造「谁出的牌」，与击杀触发同口径）。[br]
## [br][b]纯函数[/b]（ADR-0031 Logic 内核模式）：无状态、无副作用、确定映射——
## 单元测试零依赖。[br]
##
## @experimental
## 来源: ADR-0031、ADR-0016 §阵位数据模型、design/gdd/card-system.md §多效果承载（执行端）、
## production/epics/combat-ui-interaction/story-003-drag-play-flow.md。

## 阵位状态常量——镜像 [code]deployment_system.gd[/code] 的 [code]FieldState[/code]
## （本模块不依赖全局单例，故按值镜像；改动枚举须同步两处）。
## 同步绊线：[code]tests/unit/combat_ui/test_combat_caster_rules.gd[/code] 有一条
## 断言三者与 [code]DeploymentScript.FieldState[/code] 逐一对齐，改枚举会让它变红。
const FIELD_STATE_EMPTY: int = 0
const FIELD_STATE_READY: int = 2
const FIELD_STATE_DEAD: int = 4

## 无施法者哨兵——下游 [code]play_card(..., caster_id = -1)[/code] 的既有口径。
const NO_CASTER: int = -1

## slot_index 未知哨兵（缺键 / 非字典条目）——排序时排到末尾，不抢施法者。
const SLOT_INDEX_UNKNOWN: int = 1 << 30


## 施法者裁定——我方阵位快照里第一个已占用且未阵亡的角色 ID。[br]
## [br][param field] [code]DeploymentSystem.get_field()[/code] 快照（或同形状数组）：
## 每项 [code]{slot_index, character_id, is_front, state, deploy_turn}[/code]；
## 空位为 [code]character_id = -1[/code] + [code]state = EMPTY[/code]。[br]
## [br][b]按 slot_index 升序[/b]：入口先稳定排序再扫描——[code]get_field()[/code] 本就
## 升序，但桩数据 / 将来过滤合并过的快照未必有序，而「出牌角色错了」在游戏里极难归因。
## 排序用 [method Array.sort_custom] 且对非字典条目回落到末尾，n ≤ 6 成本可忽略。[br]
## [br][b]跳过规则[/b]：空位（[code]character_id < 0[/code]）、[code]EMPTY[/code]、
## [code]DEAD[/code] 一律跳过；非字典条目跳过（宽松兼容桩数据，不崩）；
## [code]state[/code] 缺失[b]不判死[/b]——按 [constant FIELD_STATE_READY] 乐观处理
## （只有显式 DEAD 才排除，不靠「字段缺失」推定阵亡）。[br]
## [br][b]返回[/b]: 施法者角色 ID；判不出返回 [constant NO_CASTER]（-1）。
static func resolve_caster(field: Variant) -> int:
	for raw: Variant in sorted_field(field):
		if not (raw is Dictionary):
			continue
		var entry: Dictionary = raw
		var character_id: int = int(entry.get("character_id", NO_CASTER))
		if character_id < 0:
			continue
		var state: int = int(entry.get("state", FIELD_STATE_READY))
		if state == FIELD_STATE_DEAD or state == FIELD_STATE_EMPTY:
			continue
		return character_id
	return NO_CASTER


## 阵位快照副本 → 按 [code]slot_index[/code] 升序（[b]不改入参[/b]）。[br]
## [br][b]为什么公开[/b]：[code]CombatActorSelection[/code] 的「自动顺位」必须与这里的
## 兜底裁定同序——两处各排各的，会选出不同的施法者。非数组输入返回空数组。
static func sorted_field(field: Variant) -> Array:
	if not (field is Array):
		return []
	var ordered: Array = (field as Array).duplicate()
	ordered.sort_custom(_slot_before)
	return ordered


## 排序谓词——按 [code]slot_index[/code] 升序；缺该键或非字典条目排到末尾
## （无法定位的条目不当第一位，免得抢走施法者）。[br]
## 稳定性：Godot 的 [method Array.sort_custom] 不保证稳定，但阵位快照里
## [code]slot_index[/code] 唯一，无需稳定性。
static func _slot_before(a: Variant, b: Variant) -> bool:
	return _slot_index_of(a) < _slot_index_of(b)


## 条目的 slot_index——非字典 / 缺键时返回一个大哨兵（排末尾）。
static func _slot_index_of(raw: Variant) -> int:
	if not (raw is Dictionary):
		return SLOT_INDEX_UNKNOWN
	return int((raw as Dictionary).get("slot_index", SLOT_INDEX_UNKNOWN))
