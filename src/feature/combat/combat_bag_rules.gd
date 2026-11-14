extends RefCounted
## CombatBagRules —— 战斗行囊的[b]可用性判据与文案[/b]（纯数据 / 纯函数）。[br]
## [br][b]职责[/b]：给定一条行囊条目与「场上有没有可施术的人」，回答「能不能用；
## 不能用是为什么」——判据只有这一处，界面只显示句子、结算层只做二次确认。[br]
## [br][b]为什么不写进 [CombatBagEntries][/b]：那个模块是[b]取数半边[/b]（读模型 /
## 卡牌系统 / 状态表 / 费用系统），而判据本身与任何数据源无关——喂它一个条目字典
## 就能单测全部拒绝分支，不必先搭一整套 Autoload。两者分开后，清单里的每个
## 「为什么灰着」都能被独立钉死（同 [code]combat_play_result.gd[/code] 的分工）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：全静态纯函数，不 new 节点、不访问 Autoload。[br]
## [br][b]文案本地化豁免[/b]：与 inventory_catalog / combat_play_result 同源口径。
##
## 来源: design/gdd/alchemy-crafting-system.md §1c（丹药使用时机「战斗中或背包」）、
## GDD card-system.md §卡牌类型、ADR-0031 §2、先例
## [code]combat_play_result.gd[/code]（拒绝原因 + 中文文案的单点）、
## [code]inventory_catalog.gd[/code]（表 + 文案单点）。

## 效果评估层的类别枚举（判据「这是不是治疗 / 增益」的唯一来源）。
const EvaluatorScript := preload("res://src/feature/card_effect_engine/card_effect_evaluator.gd")

## 条目种类（界面据此分组；取值与 [code]combat_bag_entries.gd[/code] 的 kind 同源）。
const KIND_PILL: StringName = &"pill"
const KIND_ARTIFACT: StringName = &"artifact"

## 模板 [code]target_type[/code] 的「全体友方」取值（其余取值按单目标处理）。[br]
## 与 [code]inventory_pill_use.gd[/code] 同口径——两处各写一份必然漂移。
const TARGET_ALL_ALLIES: StringName = &"all_allies"

## 不可用原因（本模块是这些句子的唯一来源；界面只显示，不自行措辞）。
const TEXT_NO_INSTANCE: String = "行囊中已无实物"
const TEXT_NO_TEMPLATE: String = "图谱已散佚"
const TEXT_PILL_UNKNOWN: String = "效用尚未参透"
const TEXT_ARTIFACT_INERT: String = "此宝还不能直接催动"
const TEXT_NOBODY_NEEDS: String = "此刻无人需要"
const TEXT_NO_TARGET: String = "场上无人可加持"
## 灵力不足的文案与 [code]combat_play_result.message_for[/code] 同句式
## （[code]printf[/code] 两位：需要 / 当前）——出牌与用药对玩家是同一件事（都花灵力），
## 措辞不该因为入口不同而换一套。
const TEXT_NO_COST: String = "灵力不足：需要 %d 点，当前 %d 点"
## 空行囊文案（丹与宝合成一列，故不按分类各写一句——那是背包界面的口径）。
const TEXT_EMPTY: String = "行囊里空无一物——丹与宝都还没有着落。"


## 不可用原因（空串 = 可用）——判据顺序即玩家最该先知道的那一条。[br]
## [br][b]实物先于效用[/b]：连一张实例都指不到时，「效用未参透」是句废话——
## 玩家手上根本没有这枚丹。[br]
## [br][b]目标先于费用[/b]：场上无人可施时，灵力够不够都不是玩家该先解决的事
## （而且「没人需要」这句本身就在提示下一步该做什么）。[br]
## [br][param p_entry] 条目（需含 [code]kind[/code] / [code]instance_id[/code] /
## [code]effect_kind[/code] / [code]cost[/code]）。[br]
## [param p_has_template] 模板是否查得到（取数归调用方——本模块不碰卡牌系统）。[br]
## [param p_has_target] 场上是否有人可施术（[method CombatBagEntries.targets] 非空）。[br]
## [param p_affordable] 灵力是否够付（判定归费用系统——本模块只收结论）。[br]
## [param p_current_cost] 当前灵力（只为文案取数，不参与判定）。
static func reason_for(p_entry: Dictionary, p_has_template: bool, p_has_target: bool,
		p_affordable: bool, p_current_cost: int) -> String:
	if int(p_entry.get("instance_id", -1)) <= 0:
		return TEXT_NO_INSTANCE
	if not p_has_template:
		return TEXT_NO_TEMPLATE
	var kind: String = str(p_entry.get("kind", ""))
	var effect_kind: int = int(p_entry.get("effect_kind", -1))
	if kind == str(KIND_PILL):
		if effect_kind != EvaluatorScript.EffectCategory.HEAL:
			return TEXT_PILL_UNKNOWN
		if not p_has_target:
			return TEXT_NOBODY_NEEDS
	elif effect_kind != EvaluatorScript.EffectCategory.BUFF:
		return TEXT_ARTIFACT_INERT
	elif not p_has_target:
		return TEXT_NO_TARGET
	if not p_affordable:
		return TEXT_NO_COST % [int(p_entry.get("cost", 0)), p_current_cost]
	return ""


## 该条目是否可用（[method reason_for] 的空串视图——判据仍然只有一份）。
static func is_usable(p_entry: Dictionary, p_has_template: bool, p_has_target: bool,
		p_affordable: bool, p_current_cost: int) -> bool:
	return reason_for(p_entry, p_has_template, p_has_target, p_affordable,
			p_current_cost).is_empty()


## 该种类应当映射到的效果类别——丹药 = 治疗，法宝 = 增益。[br]
## [br][b]为什么收在这处[/b]：「丹药治人、法宝加身」是判据的一半（另一半在
## [method reason_for]），而结算层要在动手前再对一次同一个类别。各写一遍就会
## 出现「界面说这枚丹能用、结算层说它效果不建模」这种自相矛盾。[br]
## [br][param p_is_pill] true = 丹药，false = 法宝。
static func category_for(p_is_pill: bool) -> int:
	return EvaluatorScript.EffectCategory.HEAL if p_is_pill \
			else EvaluatorScript.EffectCategory.BUFF


## 该条目是否为「全体友方」目标词（[code]all_allies[/code]，如天罗丹）。[br]
## [br][b]未登记的取值按单目标处理[/b]——与 [code]inventory_pill_use.gd[/code]
## 同一回退口径：宁可只作用于一人，也不把一条 [code]single_ally[/code] 的丹
## 悄悄撒到全队头上。
static func is_all_allies(p_entry: Dictionary) -> bool:
	return str(p_entry.get("target_type", "")) == str(TARGET_ALL_ALLIES)


## 条目行的显示文案（名称 · 稀有度 · 效果 · 数量 [· 不可用原因]）。[br]
## [br][b]状态写进文本[/b]：不可用原因绝不能只靠灰显承载（色盲可读，同
## [code]shop_panel_layout.add_item_row[/code] 的「已售罄 / 灵石不足」口径）。[br]
## [br][b]数量恒写在行上[/b]：同名多张合并成一行，不写「×N」玩家就不知道还剩几枚。
static func row_text(p_entry: Dictionary) -> String:
	var parts: Array = [str(p_entry.get("name", ""))]
	var rarity_name: String = str(p_entry.get("rarity_name", ""))
	if not rarity_name.strip_edges().is_empty():
		parts.append(rarity_name)
	var effect: String = effect_text(p_entry)
	if not effect.is_empty():
		parts.append(effect)
	parts.append("×%d" % int(p_entry.get("count", 0)))
	var reason: String = str(p_entry.get("reason", ""))
	if not reason.is_empty():
		parts.append(reason)
	return " · ".join(parts)


## 效果短句（「回复 4 点生命」/「攻击 +3」）。[br]
## [br][b]数值取自评估层[/b]（[code]combat_bag_entries._effect_value[/code] 与
## [code]stat_changes[/code]），本模块只负责措辞——界面显示的数值与结算时用的是同一条
## 算法，故不会分叉。[br]
## [br]数值读不到（0）时返回空串：宁可少一段，也不写「回复 0 点生命」这种假信息。
static func effect_text(p_entry: Dictionary) -> String:
	var kind: int = int(p_entry.get("effect_kind", -1))
	if kind == EvaluatorScript.EffectCategory.HEAL:
		var healing: int = int(p_entry.get("effect_value", 0))
		return "回复 %d 点生命" % healing if healing > 0 else ""
	if kind == EvaluatorScript.EffectCategory.BUFF:
		return _stat_text(p_entry.get("stat_changes", {}))
	return ""


## 属性增量短句（[code]{"ATK": 3}[/code] → 「攻击 +3」）。[br]
## [br][b]键名回退键本身[/b]：评估层将来新增属性时界面会显示得朴素（「DEF +2」），
## 但不会静默吞掉一条已经生效的增益——与 [code]inventory_catalog.attribute_label[/code]
## 的未登记键口径同源。
static func _stat_text(p_changes: Variant) -> String:
	if not (p_changes is Dictionary):
		return ""
	var parts: Array = []
	for key: Variant in (p_changes as Dictionary).keys():
		var amount: int = int((p_changes as Dictionary)[key])
		if amount == 0:
			continue
		parts.append("%s %+d" % [str(STAT_LABELS.get(str(key), str(key))), amount])
	return " · ".join(parts)


## 属性中文名（键与 [code]EffectEvaluation.stat_changes[/code] 同口径）。
const STAT_LABELS: Dictionary = {"ATK": "攻击", "DEF": "防御"}


## 目标行的显示文案（角色命名管线归叙事层——此处只用 ID 兜底，不臆造名字）。[br]
## 与 [code]combat_input_layer._actor_label[/code] 同口径。
static func target_label(p_character_id: int) -> String:
	return "角色 %d" % p_character_id
