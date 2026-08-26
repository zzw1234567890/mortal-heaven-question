## BossPhaseTransition —— Boss 阶段转换内嵌 Resource。
##
## HP/回合触发 → 行为替换 + 技能解锁/移除 + 冷却重置 + 治疗。[br]
## 策划在 Inspector 中编辑，运行时只读。[br]
## [br]来源: GDD ai-system.md §7 BossPhaseTransition / ADR-0017 §关键接口 BossPhaseTransition。
class_name BossPhaseTransition
extends Resource

## HP 阈值触发器——生命值低于此比例时触发（0.5 = 50%HP）。0 = 不按 HP 触发。
@export var hp_below: float = 0.0

## 回合兜底触发器——达到此回合数后强制转阶段。0 = 不按回合触发。
@export var turn_after: int = 0

## 转换后替换的行为配置（可选——null 则不替换）。[br]
## [b]类型为 Resource[/b]——跨文件 class_name 引用在 Godot 4.6 中可能解析失败，
## 运行时由赋值路径保证类型安全（BehaviorProfile extends Resource）。
@export var behavior_override: Resource

## 解锁新技能 ID 列表（加入技能池）。[br]
## [b]声明为无类型 Array[/b]——Array[StringName] 跨文件 class_name 引用时可能解析失败（同 EnemyTemplate 模式）。
@export var skill_unlock: Array = []

## 锁定旧技能 ID 列表（从技能池移除）。[br]
## [b]声明为无类型 Array[/b]——同上。
@export var skill_remove: Array = []

## 是否重置所有技能冷却。
@export var reset_cooldowns: bool = false

## 转换时回复 HP 比例（0.1 = 回复 10%）。
@export var heal_percent: float = 0.0

## 转换动画资源 ID。
@export var animation: StringName = &""
