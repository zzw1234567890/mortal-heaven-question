## DebuffConfig —— 敌方技能 Debuff 配置内嵌 Resource。
##
## 技能施加的减益效果配置——仅支持可执行类别（STAT_DOWN_ATK/DEF）。[br]
## 不可执行类别（眩晕、沉默、束缚、冰冻、中毒等）登记为技术债 DEBT-AI-001。[br]
## [br]来源: Story 敌人技能池补齐 §Debuff。
class_name DebuffConfig
extends Resource


# === 枚举 ========================================================================

## Debuff 类型——仅可执行类别。
enum DebuffType {
	STAT_DOWN_ATK = 0,  ## 降低攻击一档（持续 N 回合）
	STAT_DOWN_DEF = 1,  ## 降低防御一档（持续 N 回合）
}


# === @export 字段 =================================================================

## Debuff 类型。
@export var debuff_type: DebuffType = DebuffType.STAT_DOWN_ATK

## 持续回合数（0 = 本回合结束后生效，1 = 持续 1 回合，依此类推）。
@export var duration: int = 1

## 档位数值——降低的攻击/防御数值（当前实现为固定值，未来可扩展为百分比）。
@export var amount: int = 1
