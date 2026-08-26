## RewardConfig —— 敌方战斗奖励配置内嵌 Resource。
##
## 策划在 Inspector 中编辑，运行时只读。[br]
## [br]来源: GDD ai-system.md §2 rewards / ADR-0017 §关键接口 RewardConfig。
class_name RewardConfig
extends Resource

## 灵石奖励下限。
@export var ling_shi_min: int = 0

## 灵石奖励上限。
@export var ling_shi_max: int = 0

## 卡牌掉落表——元素 {card_id: StringName, chance: float}。[br]
## 使用 Array[Dictionary] 而非自定义 Resource 避免过度嵌套。
@export var card_drops: Array[Dictionary] = []

## 修为奖励。
@export var cultivation_reward: int = 0
