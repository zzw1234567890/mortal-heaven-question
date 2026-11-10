## EnemyEncounter —— 一场遭遇战的敌方阵容配置（Resource，.tres）。[br]
## [br][b]职责[/b]：把「这场战斗由哪些敌人组成」从代码里挪到数据里——
## [code]CombatScene[/code] 开战前读它，再交 [code]AISystem.create_enemy_roster[/code]
## 生成运行时实例。[br]
## [br][b]为什么需要[/b]：战斗场景此前只带 [code]character_ids[/code] 开战，
## 敌方阵容完全依赖 AISystem 里可能为空的残留名册——真实对局里不会有敌人。[br]
## [br][b]取值来源[/b]：模板 ID 列表指向 [code]res://assets/enemies/[/code] 下的
## [code]EnemyTemplate[/code]（ADR-0017 模板/实例分离）。本类只存引用，不含数值。[br]
##
## 来源: ADR-0017 §关键接口 create_enemy_roster、GDD ai-system.md §3 敌方上阵。

class_name EnemyEncounter
extends Resource


## 遭遇战唯一标识（如 [code]&"default_san_xiu"[/code]）。
@export var encounter_id: StringName = &""

## 显示名称（战斗标题 / 探索节点预览用，可空）。
@export var display_name: String = ""

## 敌方模板 ID 列表——每个 ID 生成一个 [code]EnemyBattleState[/code]。
## [b]空数组 = 无敌人[/b]：战斗仍可开始，但胜负判定会按「信息不足不判」处理。
@export var enemy_template_ids: Array[StringName] = []
