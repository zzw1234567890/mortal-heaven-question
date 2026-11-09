## CombatKillTrigger —— 击杀触发条目的结算（DEBT-CBT-018-10 执行端）。[br]
## [br][b]职责[/b]：出牌结算中某目标[b]由存活转为阵亡[/b]时，用打出卡的
## [code]trigger="kill"[/code] 条目（[EffectEntry]）结算一次——当前唯一建模的形态是
## 血杀掌的「击杀后回复 2 HP」（[code]target="self"[/code]）。[br]
## [br][b]为什么不自己写 HP[/b]：治疗在落库侧就是[b]负伤害[/b]——
## [code]combat_roster_state.apply_damage[/code] 是唯一写 [code]current_hp[/code] 的实现
## （含上限夹取与阵亡幂等），本模块经 [method CombatDamageSettlement.apply_heal]
## 复用同一条路径，不另开第二份真理来源。负伤害同时让 [code]character_damaged[/code]
## 广播负增量，表现层按既有约定飘治疗数字。[br]
## [br][b]信息不足不触发[/b]：拿不到卡牌数据（旧 [code]resolve[/code] 桩）或施法者 ID
## 缺失时不评估、不落库——不臆造治疗量，也不猜「谁打的」。[br]
## [br][b]同一次击杀只触发一次[/b]：由调用方按目标去重（阵亡转换本身已幂等，
## 两条结果项打同一目标时第二条 [code]died=false[/code]，双保险）。[br]
## [br]来源: DEBT-CBT-018-10 / GDD §②初始卡牌详情（血杀掌「击杀后回复2HP」）/
## GDD card-effect-engine.md §1 触发式效果（击杀时触发）。
extends RefCounted

## 效果条目类型——[code]TRIGGER_KILL[/code] 时机常量的唯一来源。
const EntryScript: GDScript = preload("res://src/core/card_system/effect_entry.gd")

## 效果评估器——击杀条目的汇总入口（不重复实现效果词表）。
const EvaluatorScript: GDScript = preload("res://src/feature/card_effect_engine/card_effect_evaluator.gd")

## 评估快照类型——击杀治疗的评估输入（施法者 HP 上下限）。
const SnapshotScript: GDScript = preload("res://src/feature/card_effect_engine/game_state_snapshot.gd")

## 父节点引用——CombatSystem 实例（取花名册状态与落库子模块）。
var _parent: Node = null

## 效果评估器——惰性创建（无状态，可复用）。
var _evaluator: RefCounted = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


## 结算一次击杀触发。[br]
## [br][param item] 出牌效果结果项（含 [code]card_data[/code] / [code]card_id[/code] /
## [code]caster_id[/code]）。[br]
## [param _victim_id] 被击杀的目标角色 ID（当前不参与取数，见下）。[br]
## [br][b]评估目标取施法者[/b]：击杀条目当前唯一建模的形态是指向自身的治疗，故按施法者
## 取数值（绑定倍率 / HP 上限口径落在施法者身上）。将来出现指向敌方 / 全体的击杀条目，
## 需按条目 [code]target[/code] 解析目标（[_victim_id] 保留给该扩展）。
## [br][br][b]返回[/b]: 治疗落库结果（无击杀类条目 / 信息不足时为空 Dictionary）。
func trigger(item: Dictionary, _victim_id: int) -> Dictionary:
	var card_data: Variant = card_data_of(item)
	var caster_id: int = caster_id_of(item)
	if card_data == null or caster_id < 0:
		return {}
	var evaluation: RefCounted = _get_evaluator().evaluate_effects(
		card_data, caster_id, _caster_snapshot(caster_id), EntryScript.TRIGGER_KILL)
	var healing: int = int(evaluation.get("healing"))
	if healing <= 0:
		return {}
	return _settlement().call(&"apply_heal", caster_id, healing)


## 击杀触发的卡牌数据——结果项自带 [code]card_data[/code] 优先；
## 只给模板 ID（[code]card_id[/code] / [code]template_id[/code]）时经 CardSystem 现查。
## 两者都取不到返回 [code]null[/code]（调用方跳过，不臆造）。
func card_data_of(item: Dictionary) -> Variant:
	var inline: Variant = item.get("card_data")
	if inline != null:
		return inline
	var template_id: Variant = item.get("card_id", item.get("template_id", null))
	if template_id == null or str(template_id).is_empty():
		return null
	var cs: Node = _autoload(&"CardSystem")
	if cs == null or not cs.has_method(&"get_template"):
		return null
	return cs.call(&"get_template", StringName(str(template_id)))


## 施法者角色 ID——结果项 [code]caster_id[/code] 优先，依次回退攻击队列同义的
## [code]attacker_id[/code] 与卡片数据上的 [code]caster_id[/code] / [code]attacker_id[/code]；
## 都取不到返回 -1（击杀效果不落库——不猜施法者）。
func caster_id_of(item: Dictionary) -> int:
	var direct: Variant = item.get("caster_id", item.get("attacker_id", null))
	if direct != null:
		return int(direct)
	var card_data: Variant = item.get("card_data")
	if card_data is Dictionary:
		var from_card: Variant = (card_data as Dictionary).get("caster_id",
				(card_data as Dictionary).get("attacker_id", null))
		if from_card != null:
			return int(from_card)
	return -1


## 施法者评估快照——击杀条目按施法者的 HP 上下限判断是否过量治疗。[br]
## 未知角色给 0/0（溢出标记不影响治疗数值本身）。
func _caster_snapshot(caster_id: int) -> RefCounted:
	var hp: Dictionary = _parent.call(&"_get_roster_state").call(&"get_hp", caster_id)
	return SnapshotScript.build({caster_id: {
		"hp": int(hp.get("current", 0)),
		"max_hp": int(hp.get("max", 0)),
	}})


## 落库子模块——经父节点取（与出牌结算共用同一实例，不重复建）。
func _settlement() -> RefCounted:
	return _parent.call(&"_get_damage_settlement")


## 惰性获取效果评估器。
func _get_evaluator() -> RefCounted:
	if _evaluator == null:
		_evaluator = EvaluatorScript.new()
	return _evaluator


## 以 SceneTree.root 查找 Autoload——测试环境缺该 Autoload 时返回 null（不抛错）。
func _autoload(node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath(String(node_name)))
