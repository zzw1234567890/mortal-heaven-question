## SkillEntry —— 敌方技能池条目内嵌 Resource。
##
## 技能池中的单个技能定义——AI 从技能池中按加权分数选择 1~2 个可用技能。[br]
## 策划在 Inspector 中编辑，运行时只读。[br]
## [br]来源: GDD ai-system.md §2 skill_pool / ADR-0017 §关键接口 SkillEntry。
class_name SkillEntry
extends Resource


# === 枚举 ========================================================================

## 技能类型——决定结算路径与修正系数匹配。
enum SkillType {
	ATTACK = 0,     ## 攻击——伤害类技能
	HEAL = 1,       ## 治疗——回复友方 HP
	DEFENSE = 2,    ## 防御——buff/护盾/前排维护
	FORMATION = 3,  ## 阵法——部署/覆盖阵法
	UTILITY = 4,    ## 辅助——debuff/控制/特殊
}

## 目标类型——决定目标选择逻辑分支。
enum TargetType {
	SINGLE_ENEMY = 0,  ## 单体敌方（玩家方角色）
	ALL_ENEMY = 1,     ## 全体敌方
	SELF = 2,           ## 自身
	ALLY = 3,           ## 单体友方
	ALL_ALLIES = 4,     ## 全体友方
}


# === @export 字段 =================================================================

## 技能 ID。
@export var skill_id: StringName = &""

## 显示名称。
@export var display_name: String = ""

## 技能类型。
@export var skill_type: SkillType = SkillType.ATTACK

## 基础权重 [0, 100]。
@export var base_weight: int = 50

## 费用消耗。
@export var cost: int = 1

## 冷却回合数（0 = 无冷却）。
@export var cooldown: int = 0

## 目标类型。
@export var target_type: TargetType = TargetType.SINGLE_ENEMY

## 关联的 EffectTemplate ID。
@export var effect_template_ids: Array[StringName] = []
