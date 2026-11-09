## EffectEntry —— 卡牌[b]单条效果[/b]的 Resource 数据。
##
## 一张卡可以挂多条异质效果（DEBT-CBT-018-10 第一阶段）：[br]
## 例如「血杀掌」= 造成 ATK×1.0 伤害（打出即生效）+ 击杀后回复 2 HP（条件触发）。[br]
## 多条效果由 [member CardTemplate.effects] 承载，评估器逐条评估后汇总
## （见 [code]CardEffectEvaluator.evaluate_effects[/code] / [code]CardEffectComposer[/code]）。
##
## [b]旧扁平字段继续可用[/b]：模板的 [member CardTemplate.effects] 为空时，
## [code]CardEffectComposer.effects_of[/code] 用扁平字段（[code]effect_type[/code] /
## [code]effect_value[/code] / …）经 [method from_card] 合成一条本类实例——
## 未迁移的旧卡走的是同一条评估路径，行为逐字节不变。
##
## [b]字段名与旧扁平字段的对应[/b]：[br]
##   · [member value] ←→ [code]CardTemplate.effect_value[/code]；[br]
##   · [member native_value] ←→ [code]CardTemplate.native_effect_value[/code]；[br]
##   · [member target] ←→ [code]CardTemplate.target_type[/code]。
##
## [b]触发时机[/b]（[member trigger]）：空 [constant TRIGGER_ON_PLAY] = 打出即生效；
## 非空 = 条件触发（如 [constant TRIGGER_KILL]）。条件触发的条目[b]不计入[/b]
## 干跑汇总——干跑不知道击杀是否真的会发生，计入等于臆造。
##
## 来源: DEBT-CBT-018-10 / GDD card-effect-engine.md §1 效果类型体系。
class_name EffectEntry
extends Resource


# === 触发时机常量 =================================================================

## 打出即生效——[member trigger] 取此值时效果在出牌结算中立即生效。
const TRIGGER_ON_PLAY: StringName = &""

## 击杀触发——目标被本次结算杀死后生效（如血杀掌的击杀回血）。
const TRIGGER_KILL: StringName = &"kill"


# === @export 字段 =================================================================

## 效果类型——与旧扁平 [code]effect_type[/code] 同一套词表（[code]damage[/code] /
## [code]heal[/code] / [code]damage_reduce[/code] / [code]damage_multiplier[/code] …）。
## 未知或留空一律落 [code]UNEVALUABLE[/code]，不静默当 buff。
@export var effect_type: StringName = &""

## 效果数值——单位随 [member effect_type] 变化（点数 / 百分比整数 / 倍率百分比整数），
## 与旧扁平 [code]effect_value[/code] 同口径。
@export var value: int = 0

## 本命数值——本命匹配时覆盖 [member value]（非线性加成不走 ×1.5）；0 = 未声明。
@export var native_value: int = 0

## 触发概率——0 = 未声明（必定触发），(0,1) 为概率，1 = 必定触发。
@export_range(0.0, 1.0, 0.01) var trigger_chance: float = 0.0

## 本命触发概率——本命匹配时覆盖 [member trigger_chance]；0 = 未声明。
@export_range(0.0, 1.0, 0.01) var native_trigger_chance: float = 0.0

## 持续回合数——0 = 即时（无持续）。
@export var duration_turns: int = 0

## 目标类型——与旧扁平 [code]target_type[/code] 同口径（如 [code]single_enemy[/code] / [code]self[/code]）。
@export var target: StringName = &""

## 触发时机——空 = 打出即生效（[constant TRIGGER_ON_PLAY]）；[code]kill[/code] = 击杀后触发。
@export var trigger: StringName = TRIGGER_ON_PLAY


# === 合成（旧扁平字段 → 条目）=====================================================

## 从旧扁平数据结构合成一条效果——未迁移模板的兼容通道。[br]
## [br][param card_data] CardTemplate 或 Dictionary（含 [code]effect_type[/code] /
## [code]effect_value[/code] / [code]native_effect_value[/code] / [code]trigger_chance[/code] /
## [code]native_trigger_chance[/code] / [code]duration_turns[/code] / [code]target_type[/code]）。[br]
## [br][b]不搬运 [code]trigger_condition[/code][/b]：那是法宝卡的「绑定触发条件」，
## 与效果自身的触发时机不是一回事，语义混用会造出凭空的击杀触发。[br]
## [br][b]返回[/b]: 新 [EffectEntry]（输入本就是 [EffectEntry] 时返回其副本）。
static func from_card(card_data: Variant) -> EffectEntry:
	if card_data is EffectEntry:
		return (card_data as EffectEntry).duplicate(true)
	var entry := EffectEntry.new()
	if card_data == null:
		return entry
	entry.effect_type = StringName(str(_read(card_data, "effect_type", "")))
	entry.value = int(_read(card_data, "effect_value", 0))
	entry.native_value = int(_read(card_data, "native_effect_value", 0))
	entry.trigger_chance = float(_read(card_data, "trigger_chance", 0.0))
	entry.native_trigger_chance = float(_read(card_data, "native_trigger_chance", 0.0))
	entry.duration_turns = int(_read(card_data, "duration_turns", 0))
	entry.target = StringName(str(_read(card_data, "target_type", "")))
	return entry


## 展开为评估器可读的 Dictionary（评估器内部一律走 Dictionary 读取路径）。[br]
## [br][param extra] 卡片级上下文（[code]card_id[/code] / [code]is_native[/code] /
## [code]attacker_atk[/code] 等）——[b]条目自身的键优先[/b]，上下文不覆盖它们。[br]
## [br][b]返回[/b]: 含两套数值键（[code]value[/code] 与 [code]effect_value[/code]）的字典。
func to_card_data(extra: Dictionary = {}) -> Dictionary:
	var data: Dictionary = {
		"effect_type": effect_type,
		"effect_value": value,
		"native_effect_value": native_value,
		"value": value,
		"native_value": native_value,
		"trigger_chance": trigger_chance,
		"native_trigger_chance": native_trigger_chance,
		"duration_turns": duration_turns,
		"target": target,
		"trigger": trigger,
	}
	for key: Variant in extra:
		if not data.has(key):
			data[key] = extra[key]
	return data


# === 查询 =========================================================================

## 本条是否为「打出即生效」（无触发条件）。
func is_play_triggered() -> bool:
	return trigger == TRIGGER_ON_PLAY


## 本条是否在指定触发时机下生效。
func matches_trigger(wanted: StringName) -> bool:
	return trigger == wanted


# === 内部 =========================================================================

## 读取旧扁平字段——兼容 CardTemplate（Resource 属性访问）与 Dictionary（键访问）。
static func _read(source: Variant, key: String, fallback: Variant) -> Variant:
	if source is Dictionary:
		return source.get(key, fallback)
	if source != null:
		var value: Variant = source.get(key)
		return fallback if value == null else value
	return fallback
