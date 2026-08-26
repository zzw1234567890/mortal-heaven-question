## EnemyBattleState —— 敌方运行时战斗状态（RefCounted）。
##
## 模板/实例分离模式中的运行时层——持有所有可变状态（HP/冷却/阶段索引等）。
## 由 AISystem.create_state() 从 EnemyTemplate 创建，战斗结束后释放。
## 不在 GSM 中存储——由 AISystem 持有。[br]
## [br]来源: ADR-0017 §关键接口 EnemyBattleState / GDD ai-system.md §2 敌方卡组构成。
class_name EnemyBattleState
extends RefCounted


# === 实例标识 ====================================================================

## 模板 ID——关联 EnemyTemplate.template_id。
var template_id: StringName = &""

## 模板引用——只读，用于查询 skill_pool/behavior_profile/phase_transitions 等。[br]
## [b]绝不运行时写模板字段[/b]（ADR-0017 模板只读约定）。[br]
## [b]类型为 Resource[/b]——跨文件 class_name 引用在 Godot 4.6 中可能解析失败，
## 运行时由赋值路径保证类型安全（EnemyTemplate extends Resource）。
var template: Resource = null


# === 运行时属性 =================================================================

## 当前 HP。
var current_hp: int = 0

## 最大 HP（= base_hp，难度缩放后可能调整——Story 004 范围）。
var max_hp: int = 0

## 攻击力（= base_attack）。
var attack: int = 0

## 防御力（= base_defense）。
var defense: int = 0

## 技能冷却——{skill_id: int} → 剩余冷却回合。
var skill_cooldowns: Dictionary = {}

## 是否存活。
var is_alive: bool = true

## 场上阵位索引（0-based，前排 0-2，后排 3-5）。-1=未分配。
var field_position: int = -1

## 是否前排。
var is_front_row: bool = false

## Boss 当前阶段索引（起始 0）。
var current_phase_index: int = 0

## 已触发的阶段索引（防重复触发）。[br]
## [b]声明为无类型 Array[/b]——Array[int] 在跨文件 class_name 引用时可能解析失败。
var triggered_transitions: Array = []
