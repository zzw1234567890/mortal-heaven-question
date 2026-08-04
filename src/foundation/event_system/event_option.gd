## EventOption —— 事件中的单个可选项。
##
## 每个 EventTemplate 包含 2~4 个 EventOption。
## 玩家选择一个选项后，依次结算其 [member outcomes] 列表。
## 部分选项可通过 [member conditions] 按玩家当前状态过滤——不满足条件的选项完全隐藏。
## 所有 @export 字段使用 Inspector 原生类型——不出现 Variant。
##
## [b]权重覆盖[/b]：[member weight_override] 为 0 时使用模板默认权重；
## 非零时覆盖该选项在加权随机中的权重。
class_name EventOption
extends Resource


# === 选项标识 =====================================================================

@export_group("选项标识")
## 选项 ID——在模板内唯一。
## 用于连锁事件的 chain_on_option 匹配和调试日志。
@export var option_id: String = ""

## 选项文本——显示在事件面板按钮上。
## @export_multiline 使 Inspector 中可展开多行编辑。
@export_multiline var text: String = ""

## 选项权重覆盖。[code]0[/code] = 无覆盖（使用模板默认权重）。
## 非零时覆盖该选项在加权随机选择中的权重。
## 用途：部分事件有"罕见结果"——权重低的选项出现概率更低。
@export var weight_override: int = 0


# === 条件过滤 =====================================================================

@export_group("条件过滤")
## 此选项的触发条件列表。[b]所有[/b]条件必须满足，选项才可见。
## 不满足任一条件的选项完全隐藏（非变灰）。
## 空数组 = 无条件限制，始终可见。
## 数组元素类型: EventCondition
## NOTE: 裸 Array 而非 Array[EventCondition]——GDScript 4.6 class_name 跨文件解析顺序限制。
@export var conditions: Array = []


# === 结果列表 =====================================================================

@export_group("结果")
## 此选项结算时执行的结果列表。[b]按顺序[/b]依次结算。
## 每个 EventOutcome 独立判定概率——多个结果可以同时触发。
## 数组元素类型: EventOutcome
## NOTE: 裸 Array 而非 Array[EventOutcome]——GDScript 4.6 class_name 跨文件解析顺序限制。
@export var outcomes: Array = []