## EventSystem.ChainHandler —— 连锁事件管理（提取自 event_system.gd）。
##
## 管理深度限制、循环检测和链结束逻辑。
## 不持有模板数据或 visited_ids——通过 init() 注入引用（共享 EventSystem.templates 与
## EventSystem._chain_visited_ids，避免副本同步问题，并保留测试白盒访问点 es._chain_visited_ids）。
##
## [b]提取原因[/b]：event_system.gd 570 行 → 拆分为 4 文件（Story 2-13 技术债）。
##
## 来源: ADR-0003 §连锁事件 + 循环检测。

extends RefCounted

## 连锁事件最大深度——调优参数（安全范围 1-5）。
## ADR-0003 决策 5：MAX_CHAIN_DEPTH=3 硬限制 + visited_ids 循环检测。
const MAX_CHAIN_DEPTH: int = 3

var _templates: Dictionary = {}

## visited_ids 引用——指向 EventSystem._chain_visited_ids（Array 是引用类型，修改同步可见）。
var _visited_ids: Array[StringName] = []


## 初始化——注入模板注册表引用和 visited_ids 引用（共享 EventSystem 状态）。
func init(templates: Dictionary, visited_ids: Array[StringName]) -> void:
	_templates = templates
	_visited_ids = visited_ids


## 查询当前事件结算后应跳转的下一个连锁事件模板 ID。[br]
## [br][b]查询方法（CQS——命令查询分离）[/b]：本方法不发射 [signal chain_triggered] 信号，
## 也不追加 visited_ids（但链结束分支 a/b/d 会 clear，见下）。调用方在确认连锁跳转后
## 自行发射 [signal chain_triggered] 并调用 [method check_chain_cycle] 进行循环检测。[br]
## [br][b]算法[/b]：[br]
##   1. 模板不存在或 [member EventTemplate.chain_next] == [code]&""[/code] → 返回 [code]&""[/code]（场景 a）[br]
##   2. [member EventTemplate.chain_on_option] >= 0 且 != [param option_index] → 返回 [code]&""[/code]（场景 d）[br]
##   3. [member EventInstance.chain_depth] >= [constant MAX_CHAIN_DEPTH] → [method @GlobalScope.push_warning] + 返回 [code]&""[/code]（场景 b）[br]
##   4. 返回 [member EventTemplate.chain_next][br]
## [br][b]链结束清空契约[/b]：场景 (a) 无 chain_next、场景 (b) 深度截断、场景 (d) 选项不匹配
## 三条返回 [code]&""[/code] 的分支均清空 visited_ids。[br]
## [br][param instance]: 当前 EventInstance[br]
## [param option_index]: 玩家选中的选项索引[br]
## [br][b]返回[/b]: 下一个连锁事件模板 ID，或空 StringName。
func get_chain_event(instance: EventInstance, option_index: int) -> StringName:
	var tmpl: EventTemplate = _templates.get(instance.template_id, null) as EventTemplate
	# 场景 (a)：模板不存在或无 chain_next → 链结束，清空 visited_ids
	if tmpl == null or tmpl.chain_next == &"":
		_visited_ids.clear()
		return &""

	# 选项过滤——仅指定选项触发连锁。选项不匹配视为链结束，清空 visited_ids（场景 d）。
	if tmpl.chain_on_option >= 0 and tmpl.chain_on_option != option_index:
		_visited_ids.clear()
		return &""

	# 场景 (b)：深度截断 → push_warning + 链结束，清空 visited_ids
	if instance.chain_depth >= MAX_CHAIN_DEPTH:
		push_warning("EventSystem: chain depth exceeded for '%s'" % instance.template_id)
		_visited_ids.clear()
		return &""

	return tmpl.chain_next


## 检测连锁事件链中是否出现循环（A→B→A）。[br]
## [br][b]算法[/b]：[br]
##   1. visited_ids.has([param next_id]) → 循环命中：[method @GlobalScope.push_warning]
##      + 发射 [param chain_ended] + 清空 visited_ids + 返回 [code]false[/code][br]
##   2. 否则 visited_ids.append([param next_id]) + 返回 [code]true[/code][br]
## [br][param instance]: 当前 EventInstance——仅用于 [param chain_ended] 载荷[br]
## [param next_id]: 即将跳转的下一个模板 ID[br]
## [param chain_ended]: [signal EventSystem.chain_ended] 信号引用[br]
## [br][b]返回[/b]: [code]true[/code] 无循环（可安全跳转），[code]false[/code] 循环命中（链已截断）。
func check_chain_cycle(instance: EventInstance, next_id: StringName, chain_ended: Signal) -> bool:
	if _visited_ids.has(next_id):
		push_warning("EventSystem: chain cycle detected at '%s'" % next_id)
		chain_ended.emit(instance.template_id)
		_visited_ids.clear()
		return false
	_visited_ids.append(next_id)
	return true