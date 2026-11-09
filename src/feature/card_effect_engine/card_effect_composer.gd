## CardEffectComposer —— 卡牌[b]多条效果[/b]的取列表与汇总（DEBT-CBT-018-10 第一阶段）。
##
## [b]本模块解决什么[/b]：`CardTemplate` 原先只有一套扁平效果字段（[code]effect_type[/code] /
## [code]effect_value[/code]），一张卡只能表达[b]一种[/b]效果。血杀掌「造成 ATK×1.0 伤害
## [i]并且[/i] 击杀后回复 2 HP」这类单调表达不出来，副效果只能写在 [code]description[/code] 里。
## 现在效果由 [member CardTemplate.effects]（[EffectEntry] 列表）承载，本模块负责
## 「取列表 → 逐条评估 → 汇总」。[br]
## [br][b]旧卡零迁移[/b]：列表为空时用扁平字段合成[b]一条[/b] [EffectEntry]
## （[method EffectEntry.from_card]），逐条评估仍走同一个
## [method CardEffectEvaluator.evaluate_effect]——旧卡行为逐字节不变
## （含 [code]UNEVALUABLE[/code] 判定与空评估）。[br]
## [br][b]汇总不造公式[/b]：[br]
##   · 伤害 / 治疗 / 属性增量 / 状态 / 加成类——按条累加（线性叠加）；[br]
##   · 百分比减伤——各条百分比收成列表后交
##     [method CardEffectEvaluator.combine_damage_reduction]（乘算 + 60% 封顶的[b]唯一实现[/b]）；[br]
##   · 伤害倍率——多条时只保留最强一条（多倍率叠乘规则 GDD 未定义，不臆造）。[br]
## [br][b]触发时机分离[/b]：默认只汇总「打出即生效」的条目。击杀类条目
## （[code]trigger="kill"[/code]）需显式指定 [param trigger] 才参与——干跑不知道击杀是否
## 真的会发生，混进打出结算的数值等于凭空多给一次治疗。[br]
## [br][b]未知类型不污染[/b]：某条落 [code]UNEVALUABLE[/code] 时其评估为空，对汇总零贡献，
## 其余条目照常生效；[method combine_detailed] 用 [code]unevaluable_count[/code] 报出来。
##
## 来源: DEBT-CBT-018-10 / GDD card-effect-engine.md §1 效果类型体系 / ADR-0009 §AI 评估接口。
class_name CardEffectComposer
extends RefCounted

## 效果条目资源类型——取列表与合成共用。
const EffectEntryScript: GDScript = preload("res://src/core/card_system/effect_entry.gd")

## 评估结果类型。
const EffectEvaluationScript: GDScript = preload("res://src/feature/card_effect_engine/effect_evaluation.gd")

## 评估器路径——用运行时 [code]load[/code] 而非 [code]preload[/code]：
## 评估器 preload 本模块，两边 preload 会构成循环依赖（Godot 解析期报错）。
const EVALUATOR_PATH: String = "res://src/feature/card_effect_engine/card_effect_evaluator.gd"

## 评估器脚本缓存——跨实例复用（[code]load[/code] 本身有引擎缓存，这里省一次查表）。
static var _evaluator_script: GDScript = null

## 评估器实例——由调用方（[CardEffectEvaluator]）注入本模块，不重复实现词表。
var _evaluator: RefCounted = null


## 构造——注入评估器（为空时惰性自建）。
func _init(evaluator: RefCounted = null) -> void:
	_evaluator = evaluator


# === 取列表 =======================================================================

## 取一张卡的效果条目列表。[br]
## [br][b]effects 非空 → 原样返回[/b]（以显式列表为准，扁平字段被忽略）；[br]
## [b]effects 为空 → 合成一条[/b]（旧卡兼容通道）。[br]
## [br][b]返回[/b]: [code]Array[EffectEntry][/code]——空模板（既无 effects 也无
## [code]effect_type[/code]）同样返回一条空条目，评估落 [code]UNEVALUABLE[/code]
## （与旧行为一致，不特殊对待）。
static func effects_of(card_data: Variant) -> Array:
	var declared: Variant = _read(card_data, "effects", null)
	if declared is Array and not (declared as Array).is_empty():
		var entries: Array = []
		for item: Variant in declared:
			entries.append(EffectEntryScript.from_card(item))
		return entries
	return [EffectEntryScript.from_card(card_data)]


# === 评估与汇总 ===================================================================

## 逐条评估并汇总。[br]
## [br][param card_data] 卡牌数据（CardTemplate 或 Dictionary）。[br]
## [br][param target_id] 目标角色 ID。[br]
## [br][param snapshot] 不可变快照。[br]
## [br][param trigger] 参与汇总的触发时机——默认 [constant EffectEntry.TRIGGER_ON_PLAY]；
## 传 [constant EffectEntry.TRIGGER_KILL] 取击杀类条目。[br]
## [br][b]返回[/b]: 汇总后的 [EffectEvaluation]（无条目参与时为空评估）。
func combine(card_data: Variant, target_id: int, snapshot: RefCounted,
		trigger: StringName = EffectEntryScript.TRIGGER_ON_PLAY) -> RefCounted:
	return combine_detailed(card_data, target_id, snapshot, trigger)["evaluation"]


## 同 [method combine]，连同明细一起返回（诊断 / 测试 / 后续触发链消费）。[br]
## [br][b]返回[/b]: [code]{evaluation, entries, unevaluable_count, skipped_count}[/code]——[br]
##   · [code]entries[/code]: 参与汇总的明细 [code][{entry, category, evaluation}][/code]；[br]
##   · [code]unevaluable_count[/code]: 其中评估不出的条数（未知 / 留空类型）；[br]
##   · [code]skipped_count[/code]: 触发时机不匹配、未参与的条数。
func combine_detailed(card_data: Variant, target_id: int, snapshot: RefCounted,
		trigger: StringName = EffectEntryScript.TRIGGER_ON_PLAY) -> Dictionary:
	var details: Array = []
	var skipped: int = 0
	var unevaluable: int = 0
	var context: Dictionary = context_of(card_data)
	for entry: Variant in effects_of(card_data):
		if not bool(entry.call("matches_trigger", trigger)):
			skipped += 1
			continue
		var data: Dictionary = entry.call("to_card_data", context)
		var category: int = _category_of(data)
		if category == _unevaluable_category():
			unevaluable += 1
		details.append({
			"entry": entry,
			"category": category,
			"evaluation": _get_evaluator().call("evaluate_effect", data, target_id, snapshot),
		})
	return {
		"evaluation": _aggregate(details, target_id, snapshot),
		"entries": details,
		"unevaluable_count": unevaluable,
		"skipped_count": skipped,
	}


## 汇总明细为单份评估。[br]
## [br][b]叠加口径[/b]见类文档——线性字段累加、减伤走 [code]combine_damage_reduction[/code]、
## 倍率取最强一条。溢出标记按汇总总量与目标快照重算（与单条同判定式，不另立规则）。[br]
## [br][b]单条减伤不走合成[/b]：只有一条减伤来源时直接沿用该条自身的
## [code]damage_reduction_pct[/code] / [code]damage_reduction_multiplier[/code]——
## 绕一圈乘算再反解会引入浮点尾差（0.1 无法精确表示），旧卡的数值必须逐位不变。
func _aggregate(details: Array, target_id: int, snapshot: RefCounted) -> RefCounted:
	var total: RefCounted = EffectEvaluationScript.new()
	var sole_reduction: RefCounted = null
	var reduction_count: int = 0
	for detail: Dictionary in details:
		var one: RefCounted = detail["evaluation"]
		total.damage += int(one.get("damage"))
		total.healing += int(one.get("healing"))
		total.damage_bonus += int(one.get("damage_bonus"))
		total.healing_bonus += int(one.get("healing_bonus"))
		total.formation_attunement += int(one.get("formation_attunement"))
		total.damage_multiplier = maxf(total.damage_multiplier, float(one.get("damage_multiplier")))
		_merge_stat_changes(total.stat_changes, one.get("stat_changes"))
		for status: Variant in one.get("statuses_applied"):
			total.statuses_applied.append(status)
		if float(one.get("damage_reduction_pct")) > 0.0:
			reduction_count += 1
			sole_reduction = one
	if reduction_count == 1:
		total.damage_reduction_pct = float(sole_reduction.get("damage_reduction_pct"))
		total.damage_reduction_multiplier = float(sole_reduction.get("damage_reduction_multiplier"))
	elif reduction_count > 1:
		# 乘算叠加 + 60% 封顶只有一处实现（GDD combat-system.md §公式）。
		var combined: Dictionary = _get_evaluator().call("combine_damage_reduction", _reduction_pcts(details))
		total.damage_reduction_multiplier = float(combined["multiplier"])
		total.damage_reduction_pct = float(combined["reduction_pct"])
	var target_hp: int = int(snapshot.call("get_hp", target_id))
	if total.damage > 0:
		total.is_overkill = total.damage > target_hp
	if total.healing > 0:
		total.is_overheal = target_hp + total.healing > int(snapshot.call("get_max_hp", target_id))
	return total


## 收集各条的减伤百分比——仅供多来源合成用（单来源见 [method _aggregate] 的短路）。
func _reduction_pcts(details: Array) -> Array:
	var pcts: Array = []
	for detail: Dictionary in details:
		var pct: float = float(detail["evaluation"].get("damage_reduction_pct"))
		if pct > 0.0:
			pcts.append(pct)
	return pcts


## 属性增量合并——同键累加（[code]{"ATK": 2}[/code] + [code]{"ATK": 1}[/code] → [code]{"ATK": 3}[/code]）。
func _merge_stat_changes(accumulated: Dictionary, incoming: Variant) -> void:
	if not (incoming is Dictionary):
		return
	for key: Variant in incoming:
		accumulated[key] = int(accumulated.get(key, 0)) + int(incoming[key])


# === 内部 =========================================================================

## 归类一条效果——委托评估器的词表（[b]不在本模块重复解析 [code]effect_type[/code][/b]）。
func _category_of(data: Dictionary) -> int:
	return int(_get_evaluator().call("category_of", data))


## [code]UNEVALUABLE[/code] 枚举值——经评估器脚本取，避免在本模块抄一份枚举序号。
func _unevaluable_category() -> int:
	return int(_script().EffectCategory.UNEVALUABLE)


## 卡片级评估上下文——逐条评估时与条目自身字段合并（条目键优先，见 [method EffectEntry.to_card_data]）。[br]
## 只搬 [code]card_id[/code] / [code]is_native[/code] / [code]attacker_atk[/code] 三个
## 与数值口径相关的键——[b]不搬扁平效果字段[/b]：条目自己已有同名字段时优先，
## 留空时才不会被旧字段顶回来（[code]to_card_data[/code] 只补缺失键）。
static func context_of(card_data: Variant) -> Dictionary:
	if card_data == null:
		return {}
	var context: Dictionary = {}
	for key: String in ["card_id", "is_native", "attacker_atk"]:
		var value: Variant = _read(card_data, key, null)
		if value != null:
			context[key] = value
	return context


## 惰性评估器——调用方未注入时自建（本模块可脱离评估器单独使用，测试便利）。
func _get_evaluator() -> RefCounted:
	if _evaluator == null:
		_evaluator = _script().new()
	return _evaluator


## 评估器脚本——首次用时 [code]load[/code]（见 [constant EVALUATOR_PATH] 的循环依赖说明）。
func _script() -> GDScript:
	if _evaluator_script == null:
		_evaluator_script = load(EVALUATOR_PATH)
	return _evaluator_script


## 读取字段——兼容 CardTemplate（Resource 属性访问）与 Dictionary（键访问）。
static func _read(source: Variant, key: String, fallback: Variant) -> Variant:
	if source is Dictionary:
		return source.get(key, fallback)
	if source != null:
		var value: Variant = source.get(key)
		return fallback if value == null else value
	return fallback
