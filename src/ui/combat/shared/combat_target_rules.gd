class_name CombatTargetRules
extends RefCounted
## CombatTargetRules —— 出牌目标解析纯函数（combat-ui-interaction 001）。
##
## [b]职责[/b]：把「玩家点了哪张卡 + 有没有点目标」解析成实际要交给
## [code]CombatSystem.play_card()[/code] 的目标 ID 列表——[br]
##   - [b]默认策略[/b]：玩家没指定目标 → 取[b]候选池中第一个存活敌人[/b]；[br]
##   - [b]显式覆盖[/b]：玩家指定了目标 → 以其为准，但只保留候选池里存活的那些。[br]
## [br][b]为什么默认是「首个存活敌人」[/b]：单敌场景（本 epic 之前的全部战斗路径）
## 里玩家点卡就是要点那个敌人，不点目标等于多点一次；多敌场景里默认打第一个
## 存活者是「最不意外」的选择，且玩家随时能用显式目标覆盖。默认与显式走同一个
## 出口，交互层不必写两条链路。[br]
## [br][b]「不猜」的两条边界[/b]（同 [code]combat_caster_rules.gd[/code] 的精神）：[br]
##   1. 候选池[b]读不到[/b]（敌方名册缺失）时，显式目标[b]原样透传[/b]——拿不到
##      名册 ≠ 玩家选的目标非法，越权否决会让 UI 在数据源未接线时完全不能出牌；
##      真正的合法性判定交系统侧 [code]_validate_targets[/code]。[br]
##   2. 候选池[b]读得到[/b]但显式目标全无效（阵亡 / 不存在的 ID）时[b]拒绝[/b]
##      （[constant SOURCE_NONE]）——不把玩家的显式意图悄悄改成另一个人。[br]
## [br][b]纯函数[/b]（ADR-0031 Logic 内核模式）：无状态、无副作用、确定映射——
## 单元测试零依赖（候选池由调用方按当前 HP 组装）。[br]
##
## @experimental
## 来源: ADR-0008 §出牌结算流程、ADR-0016 §目标合法性、ADR-0031、
## design/gdd/combat-ui-system.md §7 攻击目标选择、
## production/epics/combat-ui-interaction/story-003-drag-play-flow.md、
## story-005-target-selection.md。

## 目标解析来源枚举——调用方据此知道「这个目标是谁定的」。
## 读不到候选池，无从解析——原样透传（显式）/ 空数组（未指定）。
const SOURCE_UNRESOLVED: int = 0
## 默认策略命中：候选池首个存活敌人。
const SOURCE_DEFAULT: int = 1
## 显式覆盖命中：调用方给的目标被采纳。
const SOURCE_EXPLICIT: int = 2
## 解析失败：显式目标全部无效——[b]调用方应据此拒绝出牌[/b]。
const SOURCE_NONE: int = 3

## 无目标哨兵（与 [code]CombatCasterRules.NO_CASTER[/code] 同为 -1 口径）。
const NO_TARGET: int = -1

## 解析明细原因（[code]reason[/code] 字段——测试与日志可读性，不影响控制流）。
const REASON_FIRST_ALIVE: StringName = &"first_alive"
const REASON_EXPLICIT_VERIFIED: StringName = &"explicit_verified"
const REASON_EXPLICIT_UNVERIFIED: StringName = &"explicit_unverified"
const REASON_NO_ENEMY: StringName = &"no_enemy"
const REASON_EXPLICIT_INVALID: StringName = &"explicit_invalid"
const REASON_UNRESOLVED: StringName = &"unresolved"


## 解析本次出牌的目标列表。[br]
## [br][param explicit] 玩家显式指定的目标 ID 列表（空 = 未指定 → 走默认策略）；
## 非整数项与负值跳过（宽松兼容 UI 传入的 Variant 数组）。[br]
## [param candidates] 敌方候选池——[code][{character_id, is_alive}][/code]，
## 数组顺序即优先序（建卡顺序 = 名册顺序）；非字典条目跳过。[br]
## [br][b]返回[/b]： [code]{targets: Array[int], source: int, reason: StringName}[/code]。[br]
##   - [code]source == SOURCE_NONE[/code] → [code]targets[/code] 必为空，
##     调用方据此拒绝出牌（[b]不可把空数组当「打所有人」[/b]）；[br]
##   - 其余三种 source 的 [code]targets[/code] 可直接交给系统侧。
static func resolve(explicit: Array, candidates: Array) -> Dictionary:
	var alive: Array[int] = _alive_ids(candidates)
	if explicit.is_empty():
		if alive.is_empty():
			# 名册读不到 / 敌方全灭：无默认可选，原样透传空数组交系统侧判定。
			return _result([], SOURCE_UNRESOLVED, REASON_UNRESOLVED)
		return _result([alive[0]], SOURCE_DEFAULT, REASON_FIRST_ALIVE)
	var picked: Array[int] = []
	for raw: Variant in explicit:
		var target_id: int = int(raw)
		if target_id < 0 or picked.has(target_id):
			continue
		if alive.is_empty():
			# 候选池不可用——不越权否决玩家的显式选择（见类文档边界 1）。
			picked.append(target_id)
			continue
		if alive.has(target_id):
			picked.append(target_id)
	if picked.is_empty():
		return _result([], SOURCE_NONE, REASON_EXPLICIT_INVALID)
	var reason: StringName = REASON_EXPLICIT_UNVERIFIED if alive.is_empty() \
			else REASON_EXPLICIT_VERIFIED
	return _result(picked, SOURCE_EXPLICIT, reason)


## 候选池里的存活 ID（保序）。[br]
## [br][b]存活判定[/b]：[code]is_alive[/code] 键优先；缺失时按 [method is_alive_hp]
## 从 HP 派生——[b]缺失不判死[/b]（信息不足乐观处理，同 caster rules 的 state 口径）。
static func _alive_ids(candidates: Array) -> Array[int]:
	var alive: Array[int] = []
	for raw: Variant in candidates:
		if not (raw is Dictionary):
			continue
		var entry: Dictionary = raw
		var character_id: int = int(entry.get("character_id", NO_TARGET))
		if character_id < 0:
			continue
		var is_alive: bool = bool(entry.get("is_alive", true))
		if entry.has("is_alive"):
			is_alive = bool(entry["is_alive"])
		else:
			is_alive = is_alive_hp(int(entry.get("current_hp", 0)),
					int(entry.get("max_hp", 0)))
		if is_alive:
			alive.append(character_id)
	return alive


## HP → 存活判定（候选池只给得到 HP 时的派生口径）。[br]
## [br][b]三态[/b]：[br]
##   - [code]current > 0[/code] → 存活；[br]
##   - [code]current == 0 且 max > 0[/code] → 阵亡（有上限却归零 = 打死了）；[br]
##   - [code]current == 0 且 max == 0[/code] → [b]未知[/b] → 按存活处理
##     （读不到 HP 不等于死了——不因此把敌人从候选池里抹掉）。[br]
static func is_alive_hp(current_hp: int, max_hp: int) -> bool:
	if current_hp > 0:
		return true
	return max_hp <= 0


## 结果字典工厂（唯一构造处——形状变更只改这里）。
static func _result(targets: Array[int], source: int, reason: StringName) -> Dictionary:
	return {"targets": targets, "source": source, "reason": reason}
