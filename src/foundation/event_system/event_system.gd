## EventSystem —— 事件系统 Autoload（#5）。
##
## Foundation 层第 5 个 Autoload。管理事件模板数据库、
## 运行时事件实例化、条件判定、选项结算和加权随机选择。
##
## [b]Autoload 顺序[/b]：GSM → InputManager → SceneManager → SaveLoad → EventSystem
## [b]原则 #3 合规[/b]：不直接依赖任何 Core/Feature 层系统——与 CardSystem 通过信号委托解耦。
##
## [b]模板加载[/b]：[method _load_templates] 在 [method _ready] 中同步执行，
## 从 [code]res://assets/events/[/code] 目录递归加载所有 [code].tres[/code] 文件。
##
## [b]内部委托[/b]：条件判定 → [ConditionChecker] / 连锁事件 → [ChainHandler] /
## 触发+结算+随机 → [EventResolver]（Story 2-13 技术债拆分）。
extends Node
# class_name EventSystem —— 不声明：EventSystem 是 Autoload 全局单例，
# 声明 class_name 会与全局名冲突，导致 ES_SCRIPT.new() 创建的测试实例无法解析。
# 测试以 var es: Node 持有 + 动态分派访问（Foundation Autoload 固有权衡，参考 GSM/InputManager 同模式）。


# === 信号声明 =====================================================================

## 模板加载完成后发射。[param count] 为加载成功的模板数量。
signal templates_loaded(count: int)

## 事件触发后发射。[param event_id] 为模板 ID。
signal event_triggered(event_id: StringName)

## 事件结算完成后发射。[param event_id] 为模板 ID，[param option_idx] 为选中的选项索引，
## [param outcomes] 为结算结果数组。
signal event_resolved(event_id: StringName, option_idx: int, outcomes: Array[Dictionary])

## 连锁事件触发时发射。
signal chain_triggered(from_event: StringName, to_event: StringName)

## 连锁事件链结束时发射。[param final_event_id] 为链中最后一个事件 ID。
signal chain_ended(final_event_id: StringName)

## 卡牌奖励请求——ADD_CARD 结果通过信号委托给 CardSystem（Cat 2c fire-and-forget）。[br]
## [br][b]Foundation 层原则 #3 合规[/b]：EventSystem（Foundation）不直接调用 CardSystem（Core）。[br]
## [b]消费者[/b]：CardSystem——监听后执行 [code]create_instance()[/code] + [code]serialize_instance()[/code]
## + [code]GSM.add_card_to_collection()[/code] 完整流程。[br]
## [b]信号语义[/b]：EventSystem 发射后不等待响应——如果 CardSystem 未连接，卡牌奖励静默丢失。
signal card_reward_requested(template_id: StringName)

## 资源增加请求——Foundation 层委托 Core 层 ResourceSystem。[br]
## Cat 2c 跨层委托信号（ADR-0007）——EventSystem 不直接依赖 ResourceSystem。[br]
## [br][param type] 资源类型（StringName）。[br][br][param amount] 增加数量。[br]
## [br][b]消费者[/b]：ResourceSystem 监听并执行 add_resource。
signal resource_add_requested(type: StringName, amount: int)


# === 内部助手 =====================================================================

## 连锁事件最大深度——调优参数（安全范围 1-5）。
## ADR-0003 决策 5：MAX_CHAIN_DEPTH=3 硬限制 + visited_ids 循环检测。
## 重新导出供测试与外部消费者访问（[ChainHandler] 持有同名 const，值必须一致）。
const MAX_CHAIN_DEPTH: int = 3


## 条件判定引擎（RefCounted——由本 Autoload 持有）。
var _condition_checker: RefCounted = null

## 连锁事件处理器（RefCounted——由本 Autoload 持有）。
var _chain_handler: RefCounted = null

## 事件触发器+结算器+随机选择器（RefCounted——由本 Autoload 持有）。
var _event_resolver: RefCounted = null


# === 模板注册表 ===================================================================

## 事件模板注册表——键为 [member EventTemplate.template_id: StringName]，值为 EventTemplate Resource。
var templates: Dictionary = {}

## 模板加载是否已完成。
var _templates_ready: bool = false

## 连锁事件已访问的模板 ID 集合——循环检测用。
## 声明在 EventSystem 上以保留测试白盒访问点（es._chain_visited_ids）；
## 通过引用传给 [ChainHandler]，两者共享同一份数据，无副本同步问题。
var _chain_visited_ids: Array[StringName] = []


# === 内置虚方法 ===================================================================

## _init 在 [method Object.new] 时调用——包括测试实例（ES_SCRIPT.new() 未进入场景树，[method _ready] 不执行）。
## 辅助类在此初始化，确保 check_condition / get_chain_event / resolve_option 等委托方法在测试中可用。
## templates 传引用——后续 [method _ready] 中 _load_templates 填充的条目对辅助类可见（Dictionary 是引用类型）。
func _init() -> void:
	_condition_checker = _create_condition_checker()
	_chain_handler = _create_chain_handler()
	_event_resolver = _create_event_resolver()
	_chain_handler.init(templates, _chain_visited_ids)
	_event_resolver.init(templates, _condition_checker)


func _ready() -> void:
	_load_templates()


# === 工厂方法（测试可覆盖）=========================================================

func _create_condition_checker() -> RefCounted:
	return load("res://src/foundation/event_system/condition_checker.gd").new()


func _create_chain_handler() -> RefCounted:
	return load("res://src/foundation/event_system/chain_handler.gd").new()


func _create_event_resolver() -> RefCounted:
	return load("res://src/foundation/event_system/event_resolver.gd").new()


# === 公共 API =====================================================================

## 获取模板注册表中的一个模板。[br]
## [br][b]复杂度[/b]: O(1) 字典查询。
## [br][b]返回[/b]: [EventTemplate] 或 [code]null[/code]（ID 不存在时）。
func get_template(id: StringName) -> EventTemplate:
	return templates.get(id, null)


## 检查模板是否已加载完成。
func is_ready() -> bool:
	return _templates_ready


# === story_flags 读写 API（ADR-0003 唯一写入者契约）=============================

## story_flags 唯一运行时写入入口（ADR-0003 决策 3）。[br]
## [br]任何系统（剧情/对话/效果引擎）需写入 story_flags 时必须调用此方法，
## 不可调用 GSM.set_narrative_flag() 或直接写 GSM.narrative.story_flags。[br]
## [br][b]委托写入合约[/b]:[br]
## [codeblock]
## EventSystem.set_flag(key, value)        # ← 唯一写入入口
##   └→ GSM.set_narrative_flag(key, value)  # ← GSM 第二层
##        ├→ 写入 GSM.narrative.story_flags[key]
##        └→ _buffer_change → 帧末 batch_updated（SaveLoad 监听 → 自动存档判定）
## [/codeblock]
## [br][param key] flag 键名；[param value] flag 值。[br]
## [br][b]示例[/b]: [code]EventSystem.set_flag("chapter_1", true)[/code]
func set_flag(key: String, value: Variant) -> void:
	GameStateManager.set_narrative_flag(StringName(key), value)


## story_flags 只读查询——任意系统可调用，无写入权限制。[br]
## [br]不产生副作用、不发射信号。[br]
## [br][param key] flag 键名；[param default] 键不存在时返回的默认值（默认 [code]false[/code]）。[br]
## [br][b]返回[/b]: flag 值，或 [param default]。[br]
## [br][b]示例[/b]: [code]var ch1_done: bool = EventSystem.get_flag("chapter_1", false)[/code]
func get_flag(key: String, default: Variant = false) -> Variant:
	var flags: Variant = GameStateManager.get_state("narrative.story_flags")
	if flags is Dictionary:
		return flags.get(key, default)
	return default


# === 模板加载 =====================================================================

## 从 [code]res://assets/events/[/code] 目录递归加载所有 [code].tres[/code] EventTemplate 文件。[br]
## [br]加载完成后：[br]
##   - 发射 [signal templates_loaded] 信号[br]
##   - 全量验证所有 [member EventTemplate.chain_next] 引用完整性
func _load_templates() -> void:
	templates.clear()
	var dir := DirAccess.open("res://assets/events/")
	if dir == null:
		push_error("EventSystem._load_templates: 无法打开模板目录 'res://assets/events/'")
		return
	dir.include_hidden = false
	_recursive_load(dir, "res://assets/events/")

	_templates_ready = true
	_validate_chain_references()
	templates_loaded.emit(templates.size())


## 递归遍历并加载模板文件。
func _recursive_load(dir: DirAccess, base_path: String) -> void:
	dir.include_hidden = false
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			var sub_path := base_path.path_join(file_name) + "/"
			var sub_dir := DirAccess.open(sub_path)
			if sub_dir != null:
				_recursive_load(sub_dir, sub_path)
		elif file_name.ends_with(".tres"):
			var full_path := base_path.path_join(file_name)
			_register_template(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()


## 加载单个模板文件并注册到 [member templates]。
func _register_template(path: String) -> void:
	var res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
	if not is_instance_of(res, EventTemplate):
		push_error("EventSystem._load_templates: 文件 '%s' 不是 EventTemplate 类型" % path)
		return
	var tmpl: EventTemplate = res as EventTemplate
	if tmpl.template_id == &"":
		push_error("EventSystem._load_templates: 文件 '%s' 的 template_id 为空——跳过" % path)
		return
	if templates.has(tmpl.template_id):
		push_error("EventSystem._load_templates: template_id '%s' 重复——文件 '%s' 与已注册模板冲突"
				% [tmpl.template_id, path])
		return
	templates[tmpl.template_id] = tmpl


## 验证所有 [member EventTemplate.chain_next] 引用完整性。
func _validate_chain_references() -> void:
	for id: StringName in templates.keys():
		var tmpl: EventTemplate = templates[id] as EventTemplate
		if tmpl.chain_next != &"" and not templates.has(tmpl.chain_next):
			push_error("EventSystem: 'chain_next' 引用 '%s' 不存在（来源: '%s'）" % [tmpl.chain_next, id])


# === 委托包装器 → EventResolver ===================================================

## 通过模板 ID 触发事件。[br]
## 委托给 [EventResolver.trigger_event]。[br]
## [br][b]返回[/b]: [EventInstance]——即使无可用选项也返回实例。[br]
## 若 [param event_id] 不存在，返回 [code]null[/code]。
func trigger_event(event_id: StringName, chain_depth: int = 0) -> EventInstance:
	return _event_resolver.trigger_event(event_id, chain_depth, event_triggered)


## 结算玩家选择的选项。[br]委托给 [EventResolver.resolve_option]。[br]
## [br][b]返回[/b]: [code]Array[Dictionary][/code] 结算结果。
func resolve_option(instance: EventInstance, option_index: int) -> Array[Dictionary]:
	return _event_resolver.resolve_option(instance, option_index)


## 执行已结算的结果。[br]委托给 [EventResolver.apply_outcomes]。[br]
## [br][b]副作用[/b]：通过 GSM 写入 + 信号委托 + 发射 [signal event_resolved]。
func apply_outcomes(instance: EventInstance) -> void:
	_event_resolver.apply_outcomes(instance, card_reward_requested, resource_add_requested, event_resolved)


## 从候选事件池中按权重随机选择一个事件。[br]委托给 [EventResolver.select_event]。[br]
## [br][b]返回[/b]: 选中的 template_id，或空 StringName（无合格候选时）。
func select_event(candidates: Array[StringName], realm: int) -> StringName:
	return _event_resolver.select_event(candidates, realm)


## 检查条件列表中的 [b]所有[/b] 条件是否满足（AND 逻辑）。[br]
## 委托给 [ConditionChecker.check_condition]。[br]
## 空列表 = 始终返回 true（无条件限制）。
func check_condition(cond: EventCondition) -> bool:
	return _condition_checker.check_condition(cond)


# === 委托包装器 → ChainHandler ====================================================

## 查询连锁事件跳转目标。[br]委托给 [ChainHandler.get_chain_event]。[br]
## [br][b]返回[/b]: 下一个连锁事件模板 ID，或空 StringName。
func get_chain_event(instance: EventInstance, option_index: int) -> StringName:
	return _chain_handler.get_chain_event(instance, option_index)


## 检测连锁事件链循环。[br]委托给 [ChainHandler.check_chain_cycle]。[br]
## [br][b]返回[/b]: [code]true[/code] 无循环，[code]false[/code] 循环命中。
func check_chain_cycle(instance: EventInstance, next_id: StringName) -> bool:
	return _chain_handler.check_chain_cycle(instance, next_id, chain_ended)