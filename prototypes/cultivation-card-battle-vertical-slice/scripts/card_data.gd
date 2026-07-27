# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: 玩家能否在 3 分钟内完成一场卡牌战斗——打出卡牌、
#   看到效果结算并击败敌人——且架构遵循 Foundation 层设计？
# Date: 2026-07-27
##
## 5 张测试卡牌的数据定义。生产环境中，这些数据从 CardSystem 的
## CardTemplate Resource 加载——此处为垂直切片硬编码以跳过管线。

class_name VSCardData
extends RefCounted

const CARDS: Dictionary = {
	"fireball": {
		"name": "火球术",
		"cost": 1,
		"description": "对敌方造成 8 点伤害",
		"type": "damage",
		"value": 8,
		"target": "enemy",
	},
	"slash": {
		"name": "剑斩",
		"cost": 1,
		"description": "对敌方造成 12 点伤害",
		"type": "damage",
		"value": 12,
		"target": "enemy",
	},
	"heal": {
		"name": "回春术",
		"cost": 2,
		"description": "治疗一个角色 10 点 HP",
		"type": "heal",
		"value": 10,
		"target": "ally",
	},
	"shield": {
		"name": "护体罡气",
		"cost": 2,
		"description": "为一个角色添加 6 点护盾",
		"type": "shield",
		"value": 6,
		"target": "ally",
	},
	"thunder": {
		"name": "雷霆一击",
		"cost": 3,
		"description": "对敌方造成 20 点伤害",
		"type": "damage",
		"value": 20,
		"target": "enemy",
	},
}

## 起始手牌 ID 列表——每场战斗从 5 张中随机抽 3 张
const STARTING_DECK: Array[String] = ["fireball", "slash", "heal", "shield", "thunder"]
