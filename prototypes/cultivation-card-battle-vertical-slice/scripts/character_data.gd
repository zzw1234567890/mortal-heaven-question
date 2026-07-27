# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: 玩家能否在 3 分钟内完成一场卡牌战斗——打出卡牌、
#   看到效果结算并击败敌人——且架构遵循 Foundation 层设计？
# Date: 2026-07-27
##
## 角色数据定义——6 个预设角色，涵盖不同职业和阵营。
## 生产环境中由 CardSystem 的 CharacterTemplate 管理。

class_name VSCharacterData
extends RefCounted

const CHARACTERS: Dictionary = {
	"qingyun": {
		"name": "青云剑客",
		"profession": "剑修",
		"faction": "正道",
		"max_hp": 80,
		"attack": 15,
		"description": "高攻低防的剑修，擅长单体爆发",
	},
	"xuanwu": {
		"name": "玄武盾卫",
		"profession": "盾修",
		"faction": "正道",
		"max_hp": 120,
		"attack": 8,
		"description": "高防低攻的盾修，擅长保护队友",
	},
	"yanmo": {
		"name": "炎魔使者",
		"profession": "魔修",
		"faction": "魔道",
		"max_hp": 70,
		"attack": 18,
		"description": "高攻低防的魔修，擅长群体伤害",
	},
	"lingyao": {
		"name": "灵药仙子",
		"profession": "医修",
		"faction": "正道",
		"max_hp": 60,
		"attack": 5,
		"description": "治疗型角色，擅长回复队友",
	},
	"leizun": {
		"name": "雷尊真人",
		"profession": "法修",
		"faction": "正道",
		"max_hp": 75,
		"attack": 16,
		"description": "均衡型法修，擅长远程法术",
	},
	"yinglong": {
		"name": "应龙妖修",
		"profession": "妖修",
		"faction": "妖族",
		"max_hp": 90,
		"attack": 14,
		"description": "均衡型妖修，擅长持久战",
	},
}

## 玩家初始可用角色
const STARTING_CHARACTERS: Array[String] = ["qingyun", "xuanwu", "yanmo", "lingyao", "leizun", "yinglong"]
