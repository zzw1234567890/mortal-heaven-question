## EffectEvaluation —— 单次效果评估结果（纯数据）。
##
## 由 [CardEffectEvaluator.evaluate_effect] 返回——描述一张卡牌对一个目标
## 施加的确定性效果。[code]is_overkill[/code]（伤害溢出）与 [code]is_overheal[/code]
## （治疗溢出）供 AI 判断是否浪费资源。
##
## 来源: ADR-0009 §AI 评估接口 / GDD §10。
class_name EffectEvaluation
extends RefCounted


# === 评估字段 =====================================================================

## 造成的伤害量（0 = 无伤害）。
var damage: int = 0

## 造成的治疗量（0 = 无治疗）。
var healing: int = 0

## 属性变更——[code]{stat_name: delta}[/code]（如 [code]{"ATK": 2}[/code]）。
var stat_changes: Dictionary = {}

## 施加的状态——[code]Array[StringName][/code]（状态模板 ID）。
var statuses_applied: Array[StringName] = []

## 伤害是否溢出（目标 HP < 伤害量）。
var is_overkill: bool = false

## 治疗是否溢出（目标已满血或治疗 > 缺口）。
var is_overheal: bool = false


## 便捷构造——伤害型评估。
static func damage_only(amount: int, target_hp: int) -> EffectEvaluation:
	var eval := EffectEvaluation.new()
	eval.damage = amount
	eval.is_overkill = amount > target_hp
	return eval


## 便捷构造——治疗型评估。
static func heal_only(amount: int, target_hp: int, target_max_hp: int) -> EffectEvaluation:
	var eval := EffectEvaluation.new()
	eval.healing = amount
	eval.is_overheal = target_hp + amount > target_max_hp
	return eval
