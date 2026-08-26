## EnemyTemplate —— 敌方模板 Resource（.tres）。
##
## 策划在 Godot Inspector 中通过 @export 字段编辑敌人模板数据。[br]
## 运行时由 AISystem.EnemyFactory 创建轻量级 EnemyBattleState（RefCounted）实例。[br]
## [b]模板只读约定[/b]（ADR-0017）：运行时不得写入 EnemyTemplate 字段——
## Resource 共享引用语义导致静默数据损坏。所有可变状态在 EnemyBattleState 上。[br]
## [br]内嵌 Resource 类型定义在独立文件中：[br]
## - [BehaviorProfile]（[code]behavior_profile.gd[/code]）[br]
## - [SkillEntry]（[code]skill_entry.gd[/code]，含 SkillType/TargetType 枚举）[br]
## - [BossPhaseTransition]（[code]boss_phase_transition.gd[/code]）[br]
## - [RewardConfig]（[code]reward_config.gd[/code]）[br]
## [br]来源: ADR-0017 §关键接口 §EnemyTemplate Resource / GDD ai-system.md §2 敌方卡组构成。
class_name EnemyTemplate
extends Resource


# === 主模板字段 ==================================================================

## 唯一标识（如 &"moyuan_boss_stage1"）。
@export var template_id: StringName = &""

## 显示名称（如 "墨渊（夺舍）"）。
@export var display_name: String = ""

## 境界等级 [1, 5]。
@export var realm: int = 1

## 是否精英敌人。
@export var is_elite: bool = false

## 是否 Boss 敌人。
@export var is_boss: bool = false

## 基础生命。
@export var base_hp: int = 1

## 基础攻击。
@export var base_attack: int = 1

## 基础防御。
@export var base_defense: int = 0

## 阵营标签（部分敌人有）。
@export var faction_tags: Array[StringName] = []

## 可用阵法位（普通 0 / 精英 1 / Boss 2）。
@export var formation_limit: int = 0

## true=固定前排；false=AI 自动分配。
@export var front_slot: bool = false

## 行为配置（内嵌 Resource）。[br]
## [b]类型为 Resource[/b]——跨文件 class_name 引用在 Godot 4.6 中可能解析失败，
## 运行时由赋值路径保证类型安全（BehaviorProfile extends Resource）。
@export var behavior_profile: Resource

## 技能池。[br]
## [b]类型为 Array[/b]——Array[SkillEntry] 跨文件 class_name 在 4.6 中可能解析失败。
@export var skill_pool: Array = []

## 预配置绑定卡牌模板 ID。
@export var preconfigured_bindings: Array[StringName] = []

## 预配置阵法模板 ID。
@export var preconfigured_formations: Array[StringName] = []

## Boss 专属阶段转换列表。[br]
## [b]类型为 Array[/b]——同上，跨文件 class_name 问题。
@export var phase_transitions: Array = []

## 战斗奖励配置。[br]
## [b]类型为 Resource[/b]——同上。
@export var reward_config: Resource
