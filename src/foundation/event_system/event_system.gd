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
## 预期加载 60-100 个模板，耗时 <150ms。
extends Node
# class_name EventSystem —— 不声明：EventSystem 是 Autoload 全局单例，
# 声明 class_name 会与全局名冲突，导致 ES_SCRIPT.new() 创建的测试实例无法解析。
# 测试以 var es: Node 持有 + 动态分派访问（Foundation Autoload 固有权衡，参考 GSM/InputManager 同模式）。


# === 信号声明 =====================================================================

## 模板加载完成后发射。[param count] 为加载成功的模板数量。
signal templates_loaded(count: int)

## 事件触发后发射。[param event_id] 为模板 ID。
signal event_triggered(event_id: StringName)

## 事件结算完成后发射。
## [param event_id] 为模板 ID，[param option_idx] 为选中的选项索引，
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


## 连锁事件最大深度——调优参数（安全范围 1-5）。
## ADR-0003 决策 5：MAX_CHAIN_DEPTH=3 硬限制 + visited_ids 循环检测。
const MAX_CHAIN_DEPTH: int = 3


# === 模板注册表 ===================================================================

## 事件模板注册表——键为 [member EventTemplate.template_id: StringName]，值为 EventTemplate Resource。
## NOTE: 裸 Dictionary 而非 Dictionary[StringName, EventTemplate]——GDScript 4.6 class_name 跨文件解析限制（同 EventTemplate.options）。
var templates: Dictionary = {}

## 模板加载是否已完成。
var _templates_ready: bool = false

## 连锁事件已访问的模板 ID 集合——循环检测用。
## 在链结束时清空（循环命中/正常结束/深度截断三场景），防止残留 ID 污染下一条独立事件链。
var _chain_visited_ids: Array[StringName] = []


# === 内置虚方法 ===================================================================

func _ready() -> void:
	_load_templates()


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
	# 注：GSM 是 Autoload 单例，直接通过类名访问第二层原子方法。
	# String → StringName 转换在此处完成，保证 EventSystem 接口用 String（与 ADR-0003 §关键接口一致）。
	GameStateManager.set_narrative_flag(StringName(key), value)


## story_flags 只读查询——任意系统可调用，无写入权限制。[br]
## [br]不产生副作用、不发射信号。[br]
## [br][param key] flag 键名；[param default] 键不存在时返回的默认值（默认 [code]false[/code]）。[br]
## [br][b]返回[/b]: flag 值，或 [param default]。[br]
## [br][b]示例[/b]: [code]var ch1_done: bool = EventSystem.get_flag("chapter_1", false)[/code]
func get_flag(key: String, default: Variant = false) -> Variant:
	# L-12 修复模式：get_state 返回 Variant（可能为 null），不注解为 Dictionary 以免误导。
	var flags: Variant = GameStateManager.get_state("narrative.story_flags")
	if flags is Dictionary:
		return flags.get(key, default)
	return default


# === 模板加载 =====================================================================

## 从 [code]res://assets/events/[/code] 目录递归加载所有 [code].tres[/code] EventTemplate 文件。[br]
## [br]加载完成后：[br]
##   - 发射 [signal templates_loaded] 信号[br]
##   - 全量验证所有 [member EventTemplate.chain_next] 引用完整性——不存在的引用调用 [method @GlobalScope.push_error]
func _load_templates() -> void:
	templates.clear()
	var dir := DirAccess.open("res://assets/events/")
	if dir == null:
		push_error("EventSystem._load_templates: 无法打开模板目录 'res://assets/events/'")
		return
	dir.include_hidden = false
	_recursive_load(dir, "res://assets/events/")

	_templates_ready = true
	# L-3 修复：先验证 chain_next 引用完整性，再发射 templates_loaded——
	# 消费者在回调中立即使用 chain_next 时，无效引用已被 push_error 记录。
	_validate_chain_references()
	templates_loaded.emit(templates.size())


## 递归遍历并加载模板文件。
func _recursive_load(dir: DirAccess, base_path: String) -> void:
	# L-2 修复：子目录也排除隐藏文件（.DS_Store / .godot 等）
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
## 不存在的引用调用 [method @GlobalScope.push_error]。
func _validate_chain_references() -> void:
	for id: StringName in templates.keys():
		var tmpl: EventTemplate = templates[id] as EventTemplate
		if tmpl.chain_next != &"" and not templates.has(tmpl.chain_next):
			push_error("EventSystem: 'chain_next' 引用 '%s' 不存在（来源: '%s'）" % [tmpl.chain_next, id])


# === 事件触发 =====================================================================

## 通过模板 ID 触发事件。[br]
## [br]遍历 [member EventTemplate.options]，对每个 EventOption 调用 [method _all_conditions_met]
## 只保留满足所有条件的选项。[br]
## [br][b]参数[/b]:[br]
##   - [param event_id]: 模板 ID[br]
##   - [param chain_depth]: 连锁深度（根事件为 0，每层连锁 +1）[br]
## [br][b]返回[/b]: [EventInstance]——即使无可用选项也返回实例（检查 [member EventInstance.all_options_hidden]）。[br]
## 若 [param event_id] 不存在，返回 [code]null[/code] 并调用 [method @GlobalScope.push_error]。
func trigger_event(event_id: StringName, chain_depth: int = 0) -> EventInstance:
	var tmpl: EventTemplate = templates.get(event_id, null) as EventTemplate
	if tmpl == null:
		push_error("EventSystem.trigger_event: 模板 ID '%s' 不存在" % event_id)
		return null

	var instance := EventInstance.new()
	instance.template_id = event_id
	instance.chain_depth = chain_depth

	var eligible_count := 0
	for i: int in range(tmpl.options.size()):
		var opt: EventOption = tmpl.options[i] as EventOption
		if _all_conditions_met(opt.conditions):
			instance.available_option_indices.append(i)
			eligible_count += 1

	if eligible_count == 0:
		instance.all_options_hidden = true

	event_triggered.emit(event_id)
	return instance


## 检查条件列表中的 [b]所有[/b] 条件是否满足（AND 逻辑）。
## 空列表 = 始终返回 true（无条件限制）。
func _all_conditions_met(conditions: Array) -> bool:
	for cond in conditions:
		if not check_condition(cond as EventCondition):
			return false
	return true


# === 条件判定引擎 =================================================================

## 根据条件类型和参数判定条件是否满足。[br]
## [br]通过 GSM 第一层直接读取——零开销 O(1) 字典访问。[br]
## 支持 6 种 ConditionType：[br]
##   - [code]REALM[/code] — 境界比较（按 operator: GE/EQ/LT vs value_int）[br]
##   - [code]FACTION[/code] — 阵营匹配（见 _check_faction_condition；当前从 narrative.story_flags["player_faction"] 读取，待 Story 003 明确归属）[br]
##   - [code]RESOURCE[/code] — 资源数量比较（按 operator 比较 value_int）[br]
##   - [code]CARD_OWNED[/code] — 是否拥有指定卡牌（在 collection.owned_cards 中查找 value_str ）[br]
##   - [code]FLAG_SET[/code] — story_flag 等于 value_str[br]
##   - [code]FLAG_NOT_SET[/code] — story_flag 不等于 value_str（含不存在）[br]
## [br][b]返回[/b]: 条件满足时 [code]true[/code]，否则 [code]false[/code]。未知 ConditionType 返回 [code]false[/code]。
func check_condition(cond: EventCondition) -> bool:
	if cond == null:
		return false

	match cond.type:
		EventEnums.ConditionType.REALM:
			return _check_realm_condition(cond)

		EventEnums.ConditionType.FACTION:
			return _check_faction_condition(cond)

		EventEnums.ConditionType.RESOURCE:
			return _check_resource_condition(cond)

		EventEnums.ConditionType.CARD_OWNED:
			return _check_card_owned_condition(cond)

		EventEnums.ConditionType.FLAG_SET:
			return _check_flag_set_condition(cond, true)

		EventEnums.ConditionType.FLAG_NOT_SET:
			return _check_flag_set_condition(cond, false)

	return false


func _check_realm_condition(cond: EventCondition) -> bool:
	var player_realm: int = GameStateManager.get_state("player.realm")
	match cond.operator:
		EventEnums.ConditionOperator.GE:
			return player_realm >= cond.value_int
		EventEnums.ConditionOperator.EQ:
			return player_realm == cond.value_int
		EventEnums.ConditionOperator.LT:
			return player_realm < cond.value_int
	return false


func _check_faction_condition(cond: EventCondition) -> bool:
	# H-2 已知偏差（待解决）：ADR-0003 §check_condition 规定 FACTION 从 GSM.player.faction 读取，
	# 但 GSM player 域无 faction 字段。当前回退：从 narrative.story_flags["player_faction"] 读取。
	# player.faction 归属不属本故事（story_flags 委托写入）范围——待身份选择系统（ADR-0022）或后续玩家
	# 数据结构 story 明确归属后，更新本方法与 ADR-0003 §check_condition 契约。
	# L-12 修复：get_state 返回 Variant（可能为 null），不注解为 Dictionary 以免误导。
	var player_faction: String = ""
	var flags: Variant = GameStateManager.get_state("narrative.story_flags")
	if flags is Dictionary and flags.has("player_faction"):
		player_faction = str(flags["player_faction"])
	return player_faction == cond.value_str


func _check_resource_condition(cond: EventCondition) -> bool:
	var resources: Dictionary = GameStateManager.get_state("player.resources")
	if resources == null:
		return false
	var amount: int = resources.get(cond.target, 0)
	match cond.operator:
		EventEnums.ConditionOperator.GE:
			return amount >= cond.value_int
		EventEnums.ConditionOperator.EQ:
			return amount == cond.value_int
		EventEnums.ConditionOperator.LT:
			return amount < cond.value_int
	return false


func _check_card_owned_condition(cond: EventCondition) -> bool:
	var owned_cards: Array = GameStateManager.get_state("collection.owned_cards")
	if owned_cards == null:
		return false
	for card in owned_cards:
		if card is Dictionary and card.get("template_id", "") == cond.value_str:
			return true
	return false


func _check_flag_set_condition(cond: EventCondition, expect_set: bool) -> bool:
	# L-12 修复：get_state 返回 Variant（可能为 null），不注解为 Dictionary 以免误导。
	var flags: Variant = GameStateManager.get_state("narrative.story_flags")
	if flags == null:
		return not expect_set
	var has_flag: bool = flags.has(cond.target)
	if not has_flag:
		return not expect_set
	var flag_value: String = str(flags[cond.target])
	if expect_set:
		return flag_value == cond.value_str
	else:
		# FLAG_NOT_SET: 键存在但值不等也算不满足
		return flag_value != cond.value_str


# === 选项结算 =====================================================================

## 结算玩家选择的选项。[br]
## [br]遍历选项的 [member EventOption.outcomes]，对每个 [EventOutcome] 执行：[br]
##   1. [member EventOutcome.chance] 判定——未触发则 [code]result.triggered = false[/code][br]
##   2. [member EventOutcome.use_range] 判定——[code]true[/code] 时随机范围，[code]false[/code] 取 [member EventOutcome.value_int][br]
## [br][b]参数[/b]:[br]
##   - [param instance]: 当前 EventInstance[br]
##   - [param option_index]: 玩家选中的选项索引——必须存在于 [member EventInstance.available_option_indices] 中[br]
## [br][b]返回[/b]: [code]Array[Dictionary][/code]，每个条目为 [br]
##   [code]{triggered: bool, type: int, target: String, value: int, value_str: String}[/code][br]
## 若 [param option_index] 无效，返回空数组并调用 [method @GlobalScope.push_error]。
func resolve_option(instance: EventInstance, option_index: int) -> Array[Dictionary]:
	if not instance.available_option_indices.has(option_index):
		push_error("EventSystem.resolve_option: 选项索引 %d 不在可用选项列表中" % option_index)
		return []

	# L-4 修复：先校验模板存在性再写 selected_option_index——避免模板缺失时污染实例状态。
	var tmpl: EventTemplate = get_template(instance.template_id)
	if tmpl == null:
		push_error("EventSystem.resolve_option: 无法获取模板 '%s'" % instance.template_id)
		return []

	if option_index >= tmpl.options.size():
		push_error("EventSystem.resolve_option: 选项索引 %d 超出模板选项范围" % option_index)
		return []

	instance.selected_option_index = option_index
	var opt: EventOption = tmpl.options[option_index] as EventOption
	var results: Array[Dictionary] = []

	for outcome in opt.outcomes:
		var oc: EventOutcome = outcome as EventOutcome
		# L-5 修复：clamp chance 到 [0,1]——@export_range 仅 Inspector 约束，代码设置越界值时仍需稳健。
		var chance: float = clampf(oc.chance, 0.0, 1.0)
		var triggered: bool = true
		if chance < 1.0:
			triggered = randf() < chance

		var value: int = 0
		if oc.use_range:
			value = randi_range(oc.min_value, oc.max_value)
		else:
			value = oc.value_int

		results.append({
			"triggered": triggered,
			"type": oc.type,
			"target": oc.target,
			"value": value,
			"value_str": oc.value_str,
		})

	instance.resolved_outcomes = results
	# H-1 修复：此处不再发射 event_resolved——按 ADR-0003 §信号契约表，
	# event_resolved 应由 apply_outcomes() 在执行完所有 GSM 写入后发射（Story 005 实现）。
	# 在此发射会导致 SaveLoad 误触发自动存档，存档丢失事件结果（resolve 只算概率，未写 GSM）。
	return results


# === 加权随机选择 =================================================================

## 从候选事件池中按权重随机选择一个事件。[br]
## [br]自动过滤 [member EventTemplate.min_realm] > [param realm] 的模板，[br]
## 以及 [member EventTemplate.weight] == 0 的模板。[br]
## [br]使用累积分布函数 (CDF) + 二分查找——O(n + log n)，n 为候选数量。[br]
## [br][b]参数[/b]:[br]
##   - [param candidates]: 候选模板 ID 列表[br]
##   - [param realm]: 当前玩家境界——用于过滤 min_realm[br]
## [br][b]返回[/b]: 选中的 template_id，或空 StringName（无合格候选时）。
func select_event(candidates: Array[StringName], realm: int) -> StringName:
	# 过滤并计算权重
	var eligible: Array[Dictionary] = []  # [{id, weight}]
	var total_weight: float = 0.0

	for id in candidates:
		var tmpl := get_template(id)
		if tmpl == null:
			continue
		if tmpl.weight <= 0:
			continue
		if tmpl.min_realm > realm:
			continue
		eligible.append({"id": id, "weight": tmpl.weight})
		total_weight += float(tmpl.weight)

	if eligible.is_empty():
		return &""

	if eligible.size() == 1:
		return eligible[0]["id"]

	# 加权随机选择
	var roll := randf_range(0.0, total_weight)
	var cumulative: float = 0.0
	for entry in eligible:
		cumulative += float(entry["weight"])
		if roll <= cumulative:
			return entry["id"]

	# 浮点精度回退——返回最后一个
	return eligible[-1]["id"]


# === 连锁事件 =====================================================================

## 查询当前事件结算后应跳转的下一个连锁事件模板 ID。[br]
## [br][b]查询方法（CQS——命令查询分离）[/b]：本方法不发射 [signal chain_triggered] 信号，
## 也不修改 [member _chain_visited_ids]。调用方在确认连锁跳转后自行发射 [signal chain_triggered]
## 并调用 [method check_chain_cycle] 进行循环检测。[br]
## [br][b]算法[/b]（Story 004 §1 + Story 005 ADVISORY #1 收尾）：[br]
##   1. 模板不存在或 [member EventTemplate.chain_next] == [code]&""[/code] → 返回 [code]&""[/code]（场景 a：链结束，清空 visited_ids）[br]
##   2. [member EventTemplate.chain_on_option] >= 0 且 != [param option_index] → 返回 [code]&""[/code]（场景 d：选项不匹配，清空 visited_ids）[br]
##   3. [member EventInstance.chain_depth] >= [constant MAX_CHAIN_DEPTH] → [method @GlobalScope.push_warning] + 返回 [code]&""[/code]（场景 b：深度截断，清空 visited_ids）[br]
##   4. 返回 [member EventTemplate.chain_next][br]
## [br][b]链结束清空契约[/b]：场景 (a) 无 chain_next、场景 (b) 深度截断、场景 (d) 选项不匹配
## 三条返回 [code]&""[/code] 的分支均清空 [member _chain_visited_ids]——防止残留 ID 污染下一条独立事件链。
## 场景 (c) 循环检测命中由 [method check_chain_cycle] 内部清空。[br]
## [br][param instance]: 当前 EventInstance——读取 [member EventInstance.template_id] 和 [member EventInstance.chain_depth][br]
## [param option_index]: 玩家选中的选项索引——用于 [member EventTemplate.chain_on_option] 过滤[br]
## [br][b]返回[/b]: 下一个连锁事件模板 ID，或空 StringName（无连锁 / 选项不匹配 / 深度截断）。[br]
## [br][b]示例[/b]:[codeblock]
## var next_id := EventSystem.get_chain_event(current_instance, chosen_option)
## if next_id == &amp;"":
##     EventSystem.chain_ended.emit(current_instance.template_id)
##     break
## if not EventSystem.check_chain_cycle(current_instance, next_id):
##     break
## EventSystem.chain_triggered.emit(current_instance.template_id, next_id)
## var next_inst := EventSystem.trigger_event(next_id)
## next_inst.chain_depth = current_instance.chain_depth + 1
## [/codeblock]
func get_chain_event(instance: EventInstance, option_index: int) -> StringName:
	var tmpl: EventTemplate = get_template(instance.template_id)
	# 场景 (a)：模板不存在或无 chain_next → 链结束，清空 visited_ids
	if tmpl == null or tmpl.chain_next == &"":
		_chain_visited_ids.clear()
		return &""

	# 选项过滤——仅指定选项触发连锁。选项不匹配视为链结束，
	# 清空 _chain_visited_ids（场景 d：选项不匹配——Story 004 ADVISORY #1 收尾），
	# 防止残留 ID 污染下一条独立事件链。
	if tmpl.chain_on_option >= 0 and tmpl.chain_on_option != option_index:
		_chain_visited_ids.clear()
		return &""

	# 场景 (b)：深度截断 → push_warning + 链结束，清空 visited_ids
	if instance.chain_depth >= MAX_CHAIN_DEPTH:
		push_warning("EventSystem: chain depth exceeded for '%s'" % instance.template_id)
		_chain_visited_ids.clear()
		return &""

	return tmpl.chain_next


## 检测连锁事件链中是否出现循环（A→B→A）。[br]
## [br][b]公共方法[/b]——调用方在 [method get_chain_event] 返回非空 ID 后调用此方法。[br]
## [br][b]算法[/b]（Story 004 §1 + ADR-0003 §循环检测算法）：[br]
##   1. [member _chain_visited_ids].has([param next_id]) → 循环命中：[method @GlobalScope.push_warning]
##      + 发射 [signal chain_ended]（场景 c，归属本方法）+ 清空 [member _chain_visited_ids] + 返回 [code]false[/code][br]
##   2. 否则 [member _chain_visited_ids].append([param next_id]) + 返回 [code]true[/code][br]
## [br][b]场景 (c) 归属[/b]：循环命中时 [signal chain_ended] 在本方法内部发射——
## 与场景 (a)/(b) 由调用方发射形成混合归属（Story 004 §3 方案 A）。[br]
## [br][param instance]: 当前 EventInstance——仅用于 [signal chain_ended] 载荷[br]
## [param next_id]: 即将跳转的下一个模板 ID[br]
## [br][b]返回[/b]: [code]true[/code] 无循环（可安全跳转），[code]false[/code] 循环命中（链已截断）。
func check_chain_cycle(instance: EventInstance, next_id: StringName) -> bool:
	if _chain_visited_ids.has(next_id):
		push_warning("EventSystem: chain cycle detected at '%s'" % next_id)
		chain_ended.emit(instance.template_id)
		_chain_visited_ids.clear()
		return false
	_chain_visited_ids.append(next_id)
	return true


# === 结果执行器 ===================================================================

## 执行已结算的结果——通过 GSM 第二层原子方法或信号委托。[br]
## [br][b]Foundation 层原则 #3 合规[/b]：ADD_CARD → 信号委托，非直接调用 CardSystem。[br]
## [br][b]处理流程[/b]：[br]
##   - 跳过 [code]triggered=false[/code] 的 outcome（chance 判定失败项）[br]
##   - [code]ADD_RESOURCE[/code] 检查返回值，失败时 [method @GlobalScope.push_error][br]
##   - [code]ADD_CARD[/code] 发射 [signal card_reward_requested]（fire-and-forget）[br]
##   - [code]TRIGGER_BATTLE[/code] / [code]HEAL[/code] / [code]DAMAGE[/code] 不执行——由调用方检查 [member EventInstance.resolved_outcomes] 后自行处理[br]
##   - [code]NOTHING[/code] 不执行——仅叙事文本[br]
##   - 未知 OutcomeType 触发 [method @GlobalScope.push_warning][br]
## [br][b]信号发射[/b]：所有 outcome 处理完成后发射 [signal event_resolved]，[br]
## SaveLoad 监听以判定是否触发自动存档。[br]
## [br][param instance] 已通过 [method resolve_option] 结算的 EventInstance——读取 [member EventInstance.resolved_outcomes]。
func apply_outcomes(instance: EventInstance) -> void:
	for oc in instance.resolved_outcomes:
		if not oc["triggered"]:
			continue
		match oc["type"]:
			EventEnums.OutcomeType.ADD_RESOURCE:
				# oc["target"] 为 String（Resource 名），GSM.add_resource 接受 StringName
				var ok := GameStateManager.add_resource(StringName(oc["target"]), int(oc["value"]))
				if not ok:
					push_error("EventSystem.apply_outcomes: add_resource('%s', %d) 失败" % [oc["target"], int(oc["value"])])
			EventEnums.OutcomeType.ADD_CULTIVATION:
				# add_cultivation 返回 void——不检查返回值（Story §4 文本"返回 bool"是事实错误）
				GameStateManager.add_cultivation(int(oc["value"]))
			EventEnums.OutcomeType.ADD_CARD:
				# ⚠️ 信号委托——Foundation 层不直接依赖 Core 层（ADR-0003 决策 6 / ADR-0007 Cat 2c）
				card_reward_requested.emit(StringName(oc["target"]))
			EventEnums.OutcomeType.REMOVE_CARD:
				# oc["value"] 为 card_instance_id（int）；忽略返回值（未找到时 GSM 已 push_warning）
				GameStateManager.remove_card_from_collection(int(oc["value"]))
			EventEnums.OutcomeType.SET_FLAG:
				set_flag(oc["target"], oc["value_str"])
			EventEnums.OutcomeType.RESTORE_AP:
				GameStateManager.restore_action_points(int(oc["value"]))
			EventEnums.OutcomeType.GAIN_TALENT:
				GameStateManager.unlock_talent(StringName(oc["target"]))
			EventEnums.OutcomeType.ADVANCE_CHAPTER:
				GameStateManager.advance_chapter(StringName(oc["target"]))
			EventEnums.OutcomeType.TRIGGER_BATTLE:
				pass  # 由探索系统检查 resolved_outcomes 后自行处理
			EventEnums.OutcomeType.HEAL, EventEnums.OutcomeType.DAMAGE:
				pass  # 战斗上下文中由战斗系统处理
			EventEnums.OutcomeType.NOTHING:
				pass  # 无效果——仅叙事文本
			_:
				push_warning("EventSystem: unhandled outcome type %d" % oc["type"])

	# 结算完毕后发射——SaveLoad 监听以判定自动存档
	event_resolved.emit(instance.template_id, instance.selected_option_index, instance.resolved_outcomes)