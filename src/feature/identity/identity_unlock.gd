extends RefCounted
## IdentityUnlock —— 身份「能否解锁 / 能否开局」判定（静态纯函数子模块）。
##
## 从 [code]identity_selection_system.gd[/code] 拆出，只判定不写入——无状态、
## 不访问 Autoload，故可被单测直接调用（同 [code]identity_templates.gd[/code] 的拆分理由）。
##
## [br][b]解锁的两条来源[/b]：[br]
##   ① 身份表的 [code]unlock_condition.require_talent[/code]——ADR-0022 原始机制，
##      值是一个天赋 ID。[br]
##   ② 轮回天赋自身声明的 [code]identity_unlock[/code] 效果——GDD
##      reincarnation-talent-system.md §5 把效果 value 定义为「被解锁的身份 ID」。[br]
##   [b]② 不可省[/b]：只认 ① 时，天赋表里那条真正会被玩家买到的 L4 天赋
##   （[code]resource_4[/code]「苍玄行者」）与身份表里写的字面量对不上，
##   「阵道双杰」就永远锁着——界面能看到、却永远开不了局。
##
## [br][b]就绪度（readiness）[/b]：解锁 ≠ 可玩。身份卡组引用的卡牌模板若不在
## [code]assets/cards/templates/[/code] 里，[code]apply_identity[/code] 会校验失败
## 并回滚——玩家点了确认却什么也没发生。故开局前先问一句「这套卡组齐不齐」，
## 不齐就明确拦下并说明，绝不静默降级到别的身份。
##
## [br]来源: ADR-0022 §get_available_identities、GDD identity-selection-system.md §7、
## GDD reincarnation-talent-system.md §5 效果分发。

## 隐藏身份的轮回天赋效果类型（值 = 身份 ID）。
const TALENT_EFFECT_IDENTITY_UNLOCK: String = "identity_unlock"

## 阻断原因——无阻断。
const BLOCK_NONE: StringName = &""
## 阻断原因——身份 ID 不在身份表里。
const BLOCK_UNKNOWN_IDENTITY: StringName = &"unknown_identity"
## 阻断原因——未解锁（需轮回天赋）。
const BLOCK_LOCKED: StringName = &"locked"
## 阻断原因——卡组引用的卡牌模板缺失（或无法校验）。
const BLOCK_TEMPLATES_MISSING: StringName = &"templates_missing"

## 轮回天赋表——② 的数据来源（静态 const 表，不依赖 Autoload 实例）。
const _Talent := preload("res://src/feature/reincarnation_talent_system.gd")


# === 解锁判定 ===================================================================

## 判断身份的解锁条件是否已满足。[br]
## [br][param cond] 身份表的 [code]unlock_condition[/code] 字典。[br]
## [param identity_id] 身份 ID（用于 ② 的效果值比对）。[br]
## [param unlocked] 已解锁的轮回天赋 ID 列表。[br]
## [br][b]返回[/b]: 默认解锁 / ① 命中 / ② 命中 任一为真即 true。[br]
static func is_unlocked(cond: Dictionary, identity_id: StringName,
		unlocked: Array[String]) -> bool:
	if bool(cond.get("default_unlocked", true)):
		return true
	var required: String = str(cond.get("require_talent", ""))
	if not required.is_empty() and required in unlocked:
		return true
	return unlocked_by_talent_effect(identity_id, unlocked)


## 已解锁的天赋里是否有声明「解锁本身份」的——比对 [code]identity_unlock[/code]
## 效果的 value 与身份 ID。[br]
## [br][b]返回[/b]: 命中 true；身份 ID 为空（会与「效果未写 value」的天赋误匹配）
## 或天赋表无此 ID 均 false。[br]
static func unlocked_by_talent_effect(identity_id: StringName,
		unlocked: Array[String]) -> bool:
	var target: String = str(identity_id)
	if target.is_empty():
		return false
	for talent_id: String in unlocked:
		var def: Dictionary = _Talent.TALENT_TREE.get(talent_id, {})
		var effect: Dictionary = def.get("effect", {})
		if str(effect.get("type", "")) != TALENT_EFFECT_IDENTITY_UNLOCK:
			continue
		if str(effect.get("value", "")) == target:
			return true
	return false


# === 开局就绪度 =================================================================

## 身份卡组（含角色位）引用的全部 card_id——卡组在前、角色位在后，同 ID 去重。[br]
## [br][param tmpl] 身份模板字典（空字典 → 空数组）。[br]
static func referenced_card_ids(tmpl: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	var deck: Dictionary = tmpl.get("initial_deck", {})
	for entry: Dictionary in deck.get("cards", []):
		_append_unique(ids, str(entry.get("card_id", "")))
	for entry: Dictionary in deck.get("character_slots", []):
		_append_unique(ids, str(entry.get("card_id", "")))
	return ids


## 身份开局就绪度——解锁之外的第二道可玩性判定。[br]
## [br][param tmpl] 身份模板字典。[br]
## [param identity_id] 身份 ID。[br]
## [param unlocked] 已解锁的轮回天赋 ID 列表。[br]
## [param has_template] 卡牌模板存在性查询（[code]CardSystem.has_template[/code]
## 形态的 Callable）；[b]无效 Callable 视为「无法校验」→ 不就绪[/b]——
## 查不到不等于没有，宁可拦住也不能放一个注定中途失败的开局过去。[br]
## [br][b]返回[/b]: [code]{is_unlocked, is_ready, block_reason, missing_templates}[/code]；
## [code]is_ready[/code] 蕴含 [code]is_unlocked[/code]（未解锁必然不可开局）。[br]
static func readiness(tmpl: Dictionary, identity_id: StringName,
		unlocked: Array[String], has_template: Callable) -> Dictionary:
	if tmpl.is_empty():
		return _result(false, false, BLOCK_UNKNOWN_IDENTITY, [])
	if not is_unlocked(tmpl.get("unlock_condition", {}), identity_id, unlocked):
		return _result(false, false, BLOCK_LOCKED, [])
	var referenced: Array[String] = referenced_card_ids(tmpl)
	if not has_template.is_valid():
		return _result(true, false, BLOCK_TEMPLATES_MISSING, referenced)
	var missing: Array[String] = []
	for card_id: String in referenced:
		if not bool(has_template.call(StringName(card_id))):
			missing.append(card_id)
	if missing.is_empty():
		return _result(true, true, BLOCK_NONE, [])
	return _result(true, false, BLOCK_TEMPLATES_MISSING, missing)


# === 内部辅助 ===================================================================

static func _result(is_unlocked_flag: bool, is_ready: bool, reason: StringName,
		missing: Array[String]) -> Dictionary:
	return {
		"is_unlocked": is_unlocked_flag,
		"is_ready": is_ready,
		"block_reason": reason,
		"missing_templates": missing,
	}


static func _append_unique(ids: Array[String], card_id: String) -> void:
	if card_id.is_empty() or ids.has(card_id):
		return
	ids.append(card_id)
