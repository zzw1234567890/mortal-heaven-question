## EventOutcome —— 事件选项结算的单个结果。
##
## 每个 EventOption 包含零到多个 EventOutcome。
## 结算时按顺序依次执行：先判定 [member chance] 概率，
## 再根据 [member use_range] 决定取精确值还是随机范围值。
## 所有 @export 字段使用 Inspector 原生类型——不出现 Variant。
##
## [b]use_range 消除歧义[/b]：[code]use_range = false[/code] 表示精确值（[member value_int]）；
## [code]use_range = true[/code] 表示随机范围（[member min_value] 到 [member max_value]）。
## 即使 [code]min_value = max_value = 0[/code] 也不引起歧义——由 [member use_range] 明确指示。
class_name EventOutcome
extends Resource


# === 结果定义 =====================================================================

## 枚举权威来源：[code]EventEnums.OutcomeType[/code]（[code]res://src/foundation/event_system/event_enums.gd[/code]）。
## 下面 @export_enum 字符串必须与 EventEnums.OutcomeType 保持同步（值 0-11，顺序不得重排）。
@export_group("结果定义")
@export_enum("添加资源:0", "添加修为:1", "添加卡牌:2", "移除卡牌:3", "治疗:4", "伤害:5", "设置标记:6", "获得天赋:7", "触发战斗:8", "推进章节:9", "恢复行动力:10", "无效果:11")
var type: int = 11

## 目标 ID——结果的承受者。
## - 添加资源：资源类型名（如 "ling_shi"、"ling_li"）
## - 添加卡牌：卡牌 template_id
## - 移除卡牌：卡牌实例 ID
## - 设置标记：story_flag 键名
## - 获得天赋：天赋 ID
## - 触发战斗：敌方阵容 ID
## - 推进章节：章节 ID
## - 治疗/伤害/添加修为/恢复行动力/无效果：忽略
@export var target: String = ""


# === 精确值 =======================================================================

@export_subgroup("精确值")
## 字符串值。
## - 设置标记：flag 值（如 "true"、"completed"）
@export var value_str: String = ""

## 整数精确值。
## - 添加资源/添加修为/治疗/伤害/恢复行动力：确定值
## - 当 [member use_range] = false 时使用此值
@export var value_int: int = 0


# === 随机范围 =====================================================================

@export_subgroup("随机范围")
## 是否使用随机范围。[code]true[/code] → 在 [member min_value]~[member max_value] 间随机。
## [code]false[/code] → 使用 [member value_int] 精确值（默认）。
@export var use_range: bool = false

## 随机范围下限（含）。仅 [member use_range] = true 时生效。
@export var min_value: int = 0

## 随机范围上限（含）。仅 [member use_range] = true 时生效。
@export var max_value: int = 0


# === 概率 =========================================================================

@export_group("概率")
## 触发概率。Inspector 中显示 0%~100% 滑块（步进 1%）。
## [code]1.0[/code] = 必定触发，[code]0.0[/code] = 永不触发（仅叙事占位）。
@export_range(0.0, 1.0, 0.01) var chance: float = 1.0