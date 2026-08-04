## EventTemplate —— 事件模板 Resource。
##
## 存储在 [code]assets/events/[/code] 目录下作为 [code].tres[/code] 文件。
## EventSystem._ready() 时通过 ResourceLoader 批量加载到模板注册表。
## 策划在 Godot 编辑器中可通过 Inspector 可视化编辑所有字段。
##
## [b]4 层嵌套结构[/b]：
##   EventTemplate → Array[EventOption] → Array[EventCondition] + Array[EventOutcome]
##
## [b]连锁事件[/b]：[member chain_next] 指向下一个模板 ID；
## [member chain_on_option] 指定哪个选项触发连锁（-1 = 任意选项）。
##
## [b]Instance 分离[/b]：运行时 EventInstance 不持有 Resource 引用——
## 仅存储 [code]template_id: StringName[/code] + 选项索引列表。
## 与 ADR-0006（CardTemplate/CardInstance）相同的模式。
class_name EventTemplate
extends Resource


# === 模板标识 =====================================================================

@export_group("模板标识")
## 模板 ID——全局唯一。用作 [code]templates[/code] 字典的键。
## 命名约定：{event_type}_{index}，例如 [code]"ling_mai_caijue_001"[/code]。
@export var template_id: StringName = &""

## 枚举权威来源：[code]EventEnums.EventType[/code]（[code]res://src/foundation/event_system/event_enums.gd[/code]）。
## 下面 @export_enum 字符串必须与 EventEnums.EventType 保持同步（值 0-5）。
## 事件类型——6 种之一。决定此模板属于哪个事件池。
@export_enum("灵脉采掘:0", "坊市交易:1", "洞府奇遇:2", "杀人夺宝:3", "炼丹炼器:4", "斜月三星洞:5")
var event_type: int = 0


# === 显示文本 =====================================================================

@export_group("显示文本")
## 事件标题——显示在事件面板顶部。
@export var title: String = ""

## 事件描述——显示在事件面板正文区域。
## @export_multiline 使 Inspector 中可展开多行编辑。
@export_multiline var description: String = ""


# === 出现条件 =====================================================================

@export_group("出现条件")
## 最低境界要求。[code]1[/code] = 炼气, [code]2[/code] = 筑基, [code]3[/code] = 金丹, [code]4[/code] = 元婴。
## 玩家 [code]realm < min_realm[/code] 时此模板不会被 [method select_event] 选中。
@export var min_realm: int = 1

## 出现权重——用于 [method select_event] 的加权随机选择。
## [code]0[/code] = 禁用（此模板永远不会被选中）。
## 同类事件中权重越高的模板出现概率越大。
@export var weight: int = 10


# === 连锁事件 =====================================================================

@export_group("连锁事件")
## 连锁事件模板 ID。结算后如果此字段非空，自动触发指定的下一个事件。
## 空 StringName = 无连锁。
## 引用完整性：_load_templates() 验证所有 chain_next 值在注册表中存在或为空。
@export var chain_next: StringName = &""

## 触发连锁的选项索引。[code]-1[/code] = 任意选项均可触发连锁。
## [code]N (0-based)[/code] = 仅第 N 个选项触发连锁。
## 用途：部分事件只有"深挖"选项触发连锁事件——"稳妥"选项不触发。
@export var chain_on_option: int = -1


# === 隐藏奇遇 =====================================================================

@export_group("隐藏奇遇")
## 是否为隐藏奇遇。[code]true[/code] 时此模板不出现在常规事件池中——
## 仅通过特定探索节点或 chain_next 触发（斜月三星洞规则）。
@export var is_hidden: bool = false


# === 选项列表 =====================================================================

@export_group("选项")
## 事件选项列表——2~4 个选项。
## 每个 EventOption 具有各自的条件和结果。
## 玩家看到的是过滤后（满足条件的选项）的列表。
## 数组元素类型: EventOption
@export var options: Array = []
## GDScript 4.6 限制：无法使用 Array[EventOption] 跨文件类型注解——
## class_name 解析顺序与脚本编译顺序不完全一致。裸 Array 为有意偏差。