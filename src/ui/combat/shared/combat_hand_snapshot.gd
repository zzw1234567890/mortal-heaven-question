class_name CombatHandSnapshot
extends RefCounted
## CombatHandSnapshot —— 战斗手牌 → 手牌区渲染快照（combat-ui-interaction 001 /
## 本轮：真实对局的手牌供给）。
##
## [b]职责[/b]：把 [code]CombatSystem.get_hand()[/code] 的原始条目（实例 ID /
## 字典 / 对象三种历史形态）折成 [HandArea.apply_hand] 需要的快照，并把
## [b]卡面目标词[/b]（[code]target_type[/code]）一起带下去——交互层据此决定
## 这张卡是单体、多选、全体还是自身。[br]
## [br][b]为什么不做在 hand_area[/b]：手牌区只消费快照、不访问卡牌系统
## （ADR-0031 §2 零状态所有权）；取数在这里做一次，手牌区保持纯渲染。[br]
## [br][b]降级[/b]：卡牌系统缺失 / 模板查不到 → 用条目自带字段，再退到
## 「卡 #ID」占位；[b]不抛错[/b]——出牌链路在缺数据时仍应可用（目标词缺失按
## 未知词处理，允许玩家自由选）。
## [br][b]纯函数[/b]（ADR-0031 Logic 内核模式）：无状态、无副作用。
##
## @experimental
## 来源: ADR-0031、ADR-0006 §模板/实例分离、design/gdd/combat-ui-system.md §2 手牌区、
## production/epics/combat-ui-interaction/story-003-drag-play-flow.md。

## 卡面目标词缺失时的占位（[CombatTargetPolicy] 按未知词处理）。
const NO_TARGET_TYPE: StringName = &""


## 构建快照。[br]
## [br][param p_hand] 战斗系统手牌（条目可为 int / Dictionary / 带 get 的对象）。[br]
## [param p_card_system] 卡牌系统（可空——空时只用条目自带字段）。[br]
## [b]返回[/b]: [code]Array[Dictionary][/code]，每项
## [code]{card_instance_id, name, cost, rarity, type, target_type, affordable}[/code]。
static func build(p_hand: Array, p_card_system: Variant = null) -> Array:
	var snapshot: Array = []
	for entry: Variant in p_hand:
		var card_id: int = card_id_of(entry)
		if card_id < 0:
			continue
		var template: Variant = _template_of(p_card_system, card_id)
		snapshot.append({
			"card_instance_id": card_id,
			"name": _name_of(entry, template, card_id),
			"cost": _int_field(entry, template, "cost", 0),
			"rarity": _int_field(entry, template, "rarity", 1),
			"type": _int_field(entry, template, "type", 0),
			"target_type": target_type_of(entry, template),
			"affordable": true,
		})
	return snapshot


## 可负担性数组——与快照等长（[method HandArea.apply_affordability] 的入参）。[br]
## [param p_current_cost] 当前灵力（调用方现读 CostSystem）。[br]
## 0 费卡始终可负担（同 [code]CostSystem.can_afford[/code] 语义）。
static func affordability(p_snapshot: Array, p_current_cost: int) -> Array:
	var flags: Array = []
	for entry: Variant in p_snapshot:
		if not (entry is Dictionary):
			flags.append(true)
			continue
		var cost: int = int((entry as Dictionary).get("cost", 0))
		flags.append(cost <= 0 or p_current_cost >= cost)
	return flags


## 条目 → 卡实例 ID（三种形态统一；取不到返回 -1）。
static func card_id_of(p_entry: Variant) -> int:
	if p_entry is int:
		return p_entry
	if p_entry is Dictionary:
		return int((p_entry as Dictionary).get("card_instance_id", -1))
	if p_entry is Object and (p_entry as Object).has_method(&"get"):
		var raw: Variant = (p_entry as Object).get("card_instance_id")
		return int(raw) if raw != null else -1
	return -1


## 条目里的目标词——条目自带优先（测试 / 字典卡），其次模板。
static func target_type_of(p_entry: Variant, p_template: Variant = null) -> StringName:
	if p_entry is Dictionary:
		var raw: Variant = (p_entry as Dictionary).get("target_type")
		if raw != null and not str(raw).is_empty():
			return StringName(str(raw))
	return _card_field(p_template, "target_type", NO_TARGET_TYPE) as StringName


# === 内部 =====================================================================

## 模板查询——卡牌系统不可用 / 查不到时返回 null（降级不抛错）。
static func _template_of(p_card_system: Variant, p_card_id: int) -> Variant:
	if p_card_system == null:
		return null
	if not (p_card_system as Object).has_method(&"get_template_by_instance_id"):
		return null
	return (p_card_system as Object).call(&"get_template_by_instance_id", p_card_id)


## 条目 → 模板 → 兜底 的字段读取（字符串）。
static func _name_of(p_entry: Variant, p_template: Variant, p_card_id: int) -> String:
	if p_entry is Dictionary:
		var raw_name: Variant = (p_entry as Dictionary).get("name")
		if raw_name != null and not str(raw_name).is_empty():
			return str(raw_name)
	var from_template: Variant = _card_field(p_template, "name", "")
	if not str(from_template).is_empty():
		return str(from_template)
	return "卡 #%d" % p_card_id


## 条目 → 模板 的整数字段（条目显式键优先，缺省落模板，再落默认）。
static func _int_field(p_entry: Variant, p_template: Variant, p_key: String,
		p_default: int) -> int:
	if p_entry is Dictionary and (p_entry as Dictionary).has(p_key):
		return int((p_entry as Dictionary)[p_key])
	return int(_card_field(p_template, p_key, p_default))


## 模板字段读取（模板为空 / 无该属性时返回默认）。
static func _card_field(p_template: Variant, p_key: String, p_default: Variant) -> Variant:
	if p_template == null:
		return p_default
	var value: Variant = (p_template as Object).get(p_key)
	return p_default if value == null else value

