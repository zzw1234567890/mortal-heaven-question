## EventCondition —— 事件选项的触发条件。
##
## 通过 [enum EventEnums.ConditionType] 选择条件类型，
## 用 target + value_str/value_int 定义判定参数。
## 所有 @export 字段使用 Inspector 原生类型——不出现 Variant。
##
## [b]Inspector 用法[/b]：
## - [code]type[/code]：下拉菜单选择条件类型
## - [code]operator[/code]：仅 REALM/RESOURCE 类型使用——数值比较运算符
## - [code]target[/code]：目标键（如 "ling_shi"、"zhengdao"）
## - [code]value_str[/code]：字符串值（阵营名、卡牌 template_id、flag 键名）
## - [code]value_int[/code]：整数值（境界等级、资源数量）
class_name EventCondition
extends Resource


# === 条件定义 =====================================================================

## 枚举权威来源：[code]EventEnums.ConditionType[/code]（[code]res://src/foundation/event_system/event_enums.gd[/code]）。
## 下面 @export_enum 字符串必须与 EventEnums.ConditionType 保持同步。
@export_group("条件定义")
@export_enum("境界:0", "阵营:1", "资源:2", "持有卡牌:3", "标记已设置:4", "标记未设置:5")
var type: int = 0

## 枚举权威来源：[code]EventEnums.ConditionOperator[/code]。
## 比较运算符——仅对境界/资源类型生效。阵营/持卡/标记条件忽略此字段。
@export_enum("≥:0", "=:1", "<:2")
var operator: int = 0


# === 判定目标 =====================================================================

## 目标键——条件判定的对象。
## - 境界：忽略（使用 value_int 直接比较）
## - 阵营：忽略（与玩家阵营比较）
## - 资源：资源类型名（如 "ling_shi"、"ling_li"）
## - 持有卡牌：卡牌 template_id
## - 标记已设置/未设置：story_flag 键名
@export var target: String = ""


# === 值字段 =======================================================================

@export_group("值")
## 字符串值。
## - 阵营：阵营名（如 "zhengdao"、"modao"）
## - 持有卡牌：卡牌 template_id（与 target 相同即可）
## - 标记已设置/未设置：期望的 flag 值
@export var value_str: String = ""

## 整数值。
## - 境界：境界等级阈值（1=炼气, 2=筑基, 3=金丹, 4=元婴）
## - 资源：资源数量阈值
@export var value_int: int = 0