## EventInstance —— 事件运行时实例。
##
## 每个由 [method EventSystem.trigger_event] 触发的事件创建一个 EventInstance。
## 根据 ADR-0003 决策 2，EventInstance [b]不持有任何 Resource 引用[/b]——
## 仅存储 [member template_id: StringName] 和选项索引列表。
## 调用方通过 [code]EventSystem.get_template(instance.template_id)[/code] 获取 Resource 数据。
##
## [b]生命周期[/b]：
##   1. trigger_event() 创建 EventInstance → 过滤条件 → 填充 available_option_indices
##   2. 玩家选择选项 → resolve_option() 结算 → 填充 resolved_outcomes
##   3. 发射 event_resolved 信号 → EventInstance 被丢弃
##
## [b]连锁事件[/b]：new_instance = EventSystem.trigger_event(template.chain_next,
## chain_depth + 1) —— 深度限制 3 层 + 循环检测（Story 004）。
class_name EventInstance
extends RefCounted


## 模板 ID——通过 [method EventSystem.get_template] 获取 Resource 数据。
var template_id: StringName = &""

## 已过滤的选项索引列表——仅包含满足所有条件的选项。
## 索引指向 [code]EventTemplate.options[index][/code]，而非持有 Resource 引用。
## ADR-0003 决策 2 合规。
var available_option_indices: Array[int] = []

## 所有选项均不满足条件时为 [code]true[/code]。
## EventSystem 应向玩家显示无选项可用的提示。
var all_options_hidden: bool = false

## 连锁深度——根事件为 0，每层连锁 +1。
## 上限 3 层——[method EventSystem.trigger_event] 在 depth >= 3 时拒绝连锁。
var chain_depth: int = 0

## 玩家选择的选项索引。[code]-1[/code] = 尚未选择。
var selected_option_index: int = -1

## 结算完成的结果列表。每个条目为 Dictionary：
##   {triggered: bool, type: int, target: String, value: int, value_str: String}
## 并非所有 Outcome 都触发——chance 判定失败的条目 triggered = false。
var resolved_outcomes: Array[Dictionary] = []