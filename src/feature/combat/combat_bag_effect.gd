extends RefCounted
## CombatBagEffect —— 行囊条目的[b]落效果半边[/b]（「已裁定可用」之后发生什么）。[br]
## [br][b]职责[/b]：把一条已经过校验的条目落到战场上——[br]
##   1. [method evaluate]：经 [code]CardEffectEvaluator.evaluate_effects[/code] 现算类别 /
##      治疗量 / 属性增量（与界面显示、与结算层用的是同一次算法，本模块不认识
##      「回春丹是 4 点」这种事实）；[br]
##   2. [method apply]：丹药逐人治疗、法宝逐人加属性；[br]
##   3. [method success_text]：把结果说成一句中文。[br]
## [br][b]为什么与 [CombatBagUse] 分家[/b]：那个模块管「能不能用」（六道门 + 扣实物 +
## 扣灵力），依赖存档 / 费用 / 候选池；本模块只管「用下去发生什么」，只依赖战斗状态表与
## 伤害落库。两者合在一处会越过 300 行软上限（coding-standards），而分开后
## 「回血落在谁头上、加成记了几笔」能脱离存档与费用单独钉死。[br]
## [br][b]写入走既有设施[/b]：HP 只经 [method CombatDamageSettlement.apply_heal]
## （负伤害落库 + 上限夹取 + 广播实际增量），攻防只经
## [method CombatRosterState.apply_bonus]——本模块不碰 [code]current_hp[/code]，
## 也不自建第二条写属性的路径。[br]
## [br][b]文案本地化豁免[/b]：与 combat_play_result / combat_bag_rules 同源口径。
##
## 来源: design/gdd/alchemy-crafting-system.md §1c（丹药使用时机「战斗中或背包」）、
## GDD card-system.md §卡牌类型、ADR-0008 §Phase 4、ADR-0031 §2、先例
## [code]combat_on_play_effects.gd[/code]（出牌效果的落库半边）。

## 评估层（效果类别与点数的唯一来源）· 快照 · 判据文案 · 属性键。
const EvaluatorScript := preload("res://src/feature/card_effect_engine/card_effect_evaluator.gd")
const SnapshotScript := preload("res://src/feature/card_effect_engine/game_state_snapshot.gd")
const RulesScript := preload("res://src/feature/combat/combat_bag_rules.gd")

## 伤害落库模块（治疗落库的唯一入口）——由装配处从战斗系统现取。
var settlement: RefCounted = null
## 战斗状态表（属性增益的落点）——同上。
var roster: RefCounted = null


## 构造——依赖可后置注入（[method set_dependencies]）。
func _init(p_settlement: RefCounted = null, p_roster: RefCounted = null) -> void:
	settlement = p_settlement
	roster = p_roster


## 后置注入（生产路径：战斗系统与状态表就绪后再接上）。
func set_dependencies(p_settlement: RefCounted, p_roster: RefCounted) -> void:
	settlement = p_settlement
	roster = p_roster


# ═══════════════════════════════════════════════════════════════════════════════
# 对外
# ═══════════════════════════════════════════════════════════════════════════════

## 效果评估——类别 / 治疗量 / 属性增量（一次算齐，见 [CombatBagEntries._evaluation]）。[br]
## [br][b]返回[/b]：[code]{kind, value, changes}[/code]；模板缺失时全为「不可评估 / 0」。
func evaluate(p_template: Variant) -> Dictionary:
	if p_template == null:
		return {"kind": EvaluatorScript.EffectCategory.UNEVALUABLE, "value": 0, "changes": {}}
	var evaluator: RefCounted = EvaluatorScript.new()
	var outcome: RefCounted = evaluator.call(&"evaluate_effects", p_template, 0,
			SnapshotScript.new({}))
	return {
		"kind": int(evaluator.call(&"category_of", p_template)),
		"value": maxi(int(outcome.get("healing")), 0),
		"changes": outcome.get("stat_changes"),
	}


## 落效果——丹药逐人治疗（返回实际回血总量），法宝逐人加属性（返回 0）。[br]
## [br][b]返回 -1 表示法宝一笔都没加上[/b]（目标不在状态表内 / 增量为 0）——调用方据此
## 报失败，而不是拿一个 0 冒充满意。
func apply(p_targets: Array, p_category: int, p_effect: Dictionary) -> int:
	if p_category == EvaluatorScript.EffectCategory.HEAL:
		return _apply_heal(p_targets, int(p_effect.get("value", 0)))
	return _apply_buff(p_targets, p_effect.get("changes", {}))


## 成功文案——「回春丹已服下 · 回复 4 点生命」/「基础法器已祭出 · 攻击 +3」。[br]
## [br]回复量为 0（服药时已满血——理论不可达，候选池已滤掉无缺口者）时不说「回复 0 点」。
func success_text(p_entry: Dictionary, p_kind: String, p_effect: Dictionary,
		p_applied: int) -> String:
	var name: String = str(p_entry.get("name", ""))
	if p_kind == str(RulesScript.KIND_PILL):
		if p_applied <= 0:
			return "%s已服下" % name
		return "%s已服下 · 回复 %d 点生命" % [name, p_applied]
	return "%s已祭出 · %s" % [name, RulesScript.effect_text({
		"effect_kind": EvaluatorScript.EffectCategory.BUFF,
		"stat_changes": p_effect.get("changes", {}),
	})]


# ═══════════════════════════════════════════════════════════════════════════════
# 内部：两种效果
# ═══════════════════════════════════════════════════════════════════════════════

## 逐人治疗——经 [method CombatDamageSettlement.apply_heal] 落库（上限夹取与
## [code]character_damaged[/code] 广播都在那一层），返回实际回血总量。[br]
## [br][b]为什么累加落库结果的 damage[/b]：那是「夹取前后 HP 差」的取负（满血治疗为 0），
## 故申请 8 点但只回 3 点时这里返回 3——与表现层飘出的数字一致，不虚报。[br]
## [br][b]落库模块缺失时返回 0[/b]（没落库就没回血——不谎报一个没发生的数字）。
func _apply_heal(p_targets: Array, p_heal: int) -> int:
	if p_heal <= 0:
		return 0
	var mod: RefCounted = settlement
	if mod == null:
		return 0
	var total: int = 0
	for raw: Variant in p_targets:
		var outcome: Dictionary = mod.call(&"apply_heal", int(raw), p_heal)
		if bool(outcome.get("known", false)):
			total += -int(outcome.get("damage", 0))
	return total


## 逐人加属性——经 [method CombatRosterState.apply_bonus] 记一笔（本场有效）。[br]
## [br][b]返回 -1 = 一笔都没记上[/b]（目标未知 / 增量非正）；只要有一笔记上就返回 0
## ——部分成功不谎报成功，但也确实发生了效果，故不报失败。
func _apply_buff(p_targets: Array, p_changes: Variant) -> int:
	if not (p_changes is Dictionary) or (p_changes as Dictionary).is_empty():
		return -1
	var state: RefCounted = roster
	if state == null:
		return -1
	var landed: bool = false
	for raw: Variant in p_targets:
		var character_id: int = int(raw)
		for stat: Variant in (p_changes as Dictionary).keys():
			var amount: int = int((p_changes as Dictionary)[stat])
			if bool(state.call(&"apply_bonus", character_id, str(stat), amount)):
				landed = true
	return 0 if landed else -1
