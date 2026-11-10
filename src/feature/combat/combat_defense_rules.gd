extends RefCounted
## CombatDefenseRules —— 固定值防御（DEF）的纯结算规则。
##
## [b]职责[/b]：只做伤害链里的「固定值减免」一步，供敌方行动结算与测试复用。
## 公式：[code]结果 = max(0, 原始伤害 − max(0, 防御))[/code]。[br]
## [br][b]为什么下限是 0 而不是 1[/b]：本路径用于「敌方 → 我方」的行动结算，
## 产品口径允许高防角色完全免伤；攻击声明路径（[code]combat_damage_calculator.gd[/code]）
## 保留 GDD 原有的 [code]max(1, ATK − DEF)[/code] 保底，两条路径的下限不同是有意为之
## （见 GDD combat-system.md §公式「玩家防御字段」）。[br]
## [br][b]与百分比减伤的顺序[/b]：固定值 DEF 先结算，百分比减伤后乘算——
## [code]max(0, 原始 − DEF) × (1 − pct%)[/code]，与 GDD §公式的
## 「DEF 结算之后乘算」一致。本模块只负责第一步，百分比乘算由攻击声明链路负责。[br]
## [br]来源: GDD combat-system.md §公式/§边缘情况、combat-ui-interaction 002 后续
## （玩家 defense 字段建模）。

## 伤害下限——允许完全免伤。
const MIN_DAMAGE: int = 0


## 应用固定值防御——负防御按 0 处理（不反向增伤）。[br]
## [param p_raw_damage] 防御前的原始伤害（技能威力或攻击力）。[br]
## [param p_defense] 目标防御值（默认 0）。[br]
static func apply_flat(p_raw_damage: int, p_defense: int) -> int:
	return maxi(p_raw_damage - maxi(p_defense, 0), MIN_DAMAGE)
