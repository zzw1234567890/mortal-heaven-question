# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: 玩家能否在 4 分钟内无需引导完成「炼气战斗→修为满→渡劫→突破→再战」？
# Date: 2026-07-27
# D3 update: 2026-07-28 —— 新增绑定类卡牌
# D4 update: 2026-07-28 —— 新增 4 张卡牌（前排/AOE/灵力回复），共 13 张
##
## 卡牌数据定义。生产环境中这些数据从 CardSystem 的 CardTemplate Resource 加载。
## 垂直切片硬编码 13 张卡牌（8 即时 + 4 绑定 + 1 灵力）。

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
	## === 绑定类卡牌（D3 新增——绑定到角色阵位，每回合自动触发） ====================
	"wood_art": {
		"name": "青木长生功",
		"cost": 2,
		"description": "绑定：每回合回复角色 5 点 HP",
		"type": "binding",
		"subtype": "regen",
		"value": 5,
		"target": "ally",
		"bind_text": "每回合回复 %d HP",
	},
	"flame_bind": {
		"name": "烈焰附体诀",
		"cost": 2,
		"description": "绑定：每回合对敌方造成 6 点伤害",
		"type": "binding",
		"subtype": "burn",
		"value": 6,
		"target": "ally",
		"bind_text": "每回合灼烧敌方 %d 点",
	},
	"iron_skin": {
		"name": "金刚不坏功",
		"cost": 3,
		"description": "绑定：每回合获得 4 点护盾",
		"type": "binding",
		"subtype": "barrier",
		"value": 4,
		"target": "ally",
		"bind_text": "每回合获得 %d 护盾",
	},
	"thunder_rage": {
		"name": "雷霆怒意",
		"cost": 3,
		"description": "绑定：每回合对敌方造成 8 点伤害",
		"type": "binding",
		"subtype": "aoe_burn",
		"value": 8,
		"target": "ally",
		"bind_text": "每回合雷击敌方 %d 点",
	},
	## === D4 新增卡牌 =============================================================
	"frontline_slash": {
		"name": "破空斩",
		"cost": 3,
		"description": "对前排敌方造成 22 点伤害",
		"type": "damage",
		"value": 22,
		"target": "enemy_front",
	},
	"earth_crack": {
		"name": "地裂术",
		"cost": 2,
		"description": "对前排敌方造成 15 点伤害",
		"type": "damage",
		"value": 15,
		"target": "enemy_front",
	},
	"fire_storm": {
		"name": "烈焰风暴",
		"cost": 4,
		"description": "对所有敌方造成 12 点伤害",
		"type": "damage",
		"value": 12,
		"target": "enemy_all",
	},
	"mana_gather": {
		"name": "灵气汇聚",
		"cost": 1,
		"description": "回复 6 点灵力",
		"type": "mana",
		"value": 6,
		"target": "self",
	},
}

## 起始手牌 ID 列表——每场战斗从 13 张中随机抽 3 张
const STARTING_DECK: Array[String] = [
	"fireball", "slash", "heal", "shield", "thunder",
	"wood_art", "flame_bind", "iron_skin", "thunder_rage",
	"frontline_slash", "earth_crack", "fire_storm", "mana_gather",
]
