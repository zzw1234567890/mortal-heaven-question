# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: 玩家能否在 4 分钟内无需引导完成「炼气战斗→修为满→渡劫→突破→再战」？
# Date: 2026-07-27
##
## 境界数据表 —— 炼气/筑基两境界的属性定义。
## 生产环境中由 RealmSystem（ADR-0010）管理——此处为垂直切片独立定义。
## 遵循 const Dictionary + 纯查询接口，与架构决策一致。

class_name VSRealmData
extends RefCounted

## === 境界枚举 ==================================================================

enum RealmLevel {
	QI_REFINING = 1,   ## 炼气期
	FOUNDATION = 2,    ## 筑基期
}

## === const 属性表（生产环境中为 RealmSystem.realm_table） =======================

const REALM_TABLE: Dictionary = {
	RealmLevel.QI_REFINING: {
		"name": "炼气期",
		"max_cultivation": 100,     ## 切片缩小——完整游戏为 1000
		"cost_per_turn": 2,         ## 每回合灵力恢复
		"max_deploy": 2,            ## 最大上场人数
		"realm_bonus_damage": 1.0,  ## 伤害基础倍率
	},
	RealmLevel.FOUNDATION: {
		"name": "筑基期",
		"max_cultivation": 200,     ## 切片缩小——完整游戏为 1500
		"cost_per_turn": 5,         ## 每回合灵力恢复
		"max_deploy": 3,            ## 最大上场人数
		"realm_bonus_damage": 1.2,  ## 伤害倍率（筑基打炼气有加成）
	},
}

## === 压制系数表（境界差 → 伤害/承伤倍率） ==========================================

## 压制规则：高境界打低境界 = 伤害加成；低境界打高境界 = 伤害衰减。
## get_suppression(attacker_realm, defender_realm) → 倍率
const SUPPRESSION_TABLE: Dictionary = {
	0: 1.0,   ## 同境界——无压制
	1: 1.3,   ## 高 1 境界（筑基 vs 炼气）——伤害 +30%
	2: 1.5,   ## 高 2 境界
	3: 1.7,
	4: 2.0,
}

## === 公共方法 ==================================================================

## 查询境界属性——O(1) 双重字典查询。
## [br][br]
## [b]示例:[/b][br]
##   [codeblock]VSRealmData.get_realm_property(RealmLevel.QI_REFINING, "cost_per_turn")  # → 2[/codeblock]
static func get_realm_property(level: int, key: String) -> Variant:
	if not REALM_TABLE.has(level):
		push_warning("VSRealmData: 境界 %d 不存在" % level)
		return null
	return REALM_TABLE[level].get(key)


## 计算境界压制倍率——attacker 对 defender 的攻击。
## [br]
## [b]返回:[/b] 伤害倍率（≥1.0 表示加成，<1.0 表示衰减）。
static func get_suppression(attacker_realm: int, defender_realm: int) -> float:
	var gap: int = attacker_realm - defender_realm
	if gap <= 0:
		## 低打高——衰减（避免除以零）
		var penalty: float = 1.0 / (1.0 + abs(gap) * 0.25)
		return penalty
	## 高打低——加成
	if SUPPRESSION_TABLE.has(gap):
		return SUPPRESSION_TABLE[gap]
	return 1.0 + gap * 0.3  ## 超范围回退公式


## 获取境界名称——方便 UI 显示。
static func get_realm_name(level: int) -> String:
	var name: Variant = get_realm_property(level, "name")
	return str(name) if name != null else "未知境界"
