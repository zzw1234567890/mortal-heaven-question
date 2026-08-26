## BehaviorProfile —— 敌方行为配置内嵌 Resource。
##
## 决定 AI 决策权重修正——攻击性、集火倾向、前排维护、撤退阈值。[br]
## 策划在 Inspector 中编辑，运行时只读。[br]
## [br]来源: GDD ai-system.md §2 behavior_profile / ADR-0017 §关键接口 BehaviorProfile。
class_name BehaviorProfile
extends Resource

## 攻击性 [0.0, 1.0]（高=优先攻击而非治疗）。
@export var aggression: float = 0.7

## 集火倾向 [0.0, 1.0]（高=优先攻击残血角色）。
@export var focus_fire: float = 0.6

## 前排维护倾向 [0.0, 1.0]。
@export var front_priority: float = 0.5

## 撤退阈值（0 = 不撤退；血量低于此比例时尝试撤退）。
@export var retreat_threshold: float = 0.0
