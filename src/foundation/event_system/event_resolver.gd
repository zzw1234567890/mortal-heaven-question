## EventSystem.EventResolver —— 选项结算 + 加权随机 + 结果执行（提取自 event_system.gd）。
##
## 引用 [member _templates]（EventSystem.templates）和 [member _condition_checker]（ConditionChecker 实例）。
## 不持有模板数据——通过构造函数注入引用。
##
## [b]提取原因[/b]：event_system.gd 570 行 → 拆分为 4 文件（Story 2-13 技术债）。
##
## 来源: ADR-0003。

extends RefCounted

var _templates: Dictionary = {}
var _condition_checker: RefCounted = null


## 初始化——注入模板注册表引用和条件检查器实例。
func init(templates: Dictionary, condition_checker: RefCounted) -> void:
	_templates = templates
	_condition_checker = condition_checker


## 检查条件列表中的 [b]所有[/b] 条件是否满足（AND 逻辑）。
## 空列表 = 始终返回 true（无条件限制）。
func _all_conditions_met(conditions: Array) -> bool:
	for cond in conditions:
		if not _condition_checker.check_condition(cond as EventCondition):
			return false
	return true


## 通过模板 ID 触发事件。[br]
## [br]遍历 [member EventTemplate.options]，对每个 EventOption 调用 [method _all_conditions_met]
## 只保留满足所有条件的选项。[br]
## [br][b]参数[/b]:[br]
##   - [param event_id]: 模板 ID[br]
##   - [param chain_depth]: 连锁深度（根事件为 0，每层连锁 +1）[br]
##   - [param event_triggered_signal]: [signal EventSystem.event_triggered] 信号引用[br]
## [br][b]返回[/b]: [EventInstance]——即使无可用选项也返回实例（检查 [member EventInstance.all_options_hidden]）。[br]
## 若 [param event_id] 不存在，返回 [code]null[/code] 并调用 [method @GlobalScope.push_error]。
func trigger_event(event_id: StringName, chain_depth: int, event_triggered_signal: Signal) -> EventInstance:
	var tmpl: EventTemplate = _templates.get(event_id, null) as EventTemplate
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

	event_triggered_signal.emit(event_id)
	return instance


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

	# 先校验模板存在性再写 selected_option_index——避免模板缺失时污染实例状态。
	var tmpl: EventTemplate = _templates.get(instance.template_id, null) as EventTemplate
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
		# clamp chance 到 [0,1]——@export_range 仅 Inspector 约束，代码设置越界值时仍需稳健。
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
	# 此处不再发射 event_resolved——按 ADR-0003 §信号契约表，
	# event_resolved 应由 apply_outcomes() 在执行完所有 GSM 写入后发射。
	# 在此发射会导致 SaveLoad 误触发自动存档，存档丢失事件结果（resolve 只算概率，未写 GSM）。
	return results


## 执行已结算的结果——通过 GSM 第二层原子方法或信号委托。[br]
## [br][b]Foundation 层原则 #3 合规[/b]：ADD_CARD → 信号委托，非直接调用 CardSystem。[br]
## [br][b]处理流程[/b]：[br]
##   - 跳过 [code]triggered=false[/code] 的 outcome（chance 判定失败项）[br]
##   - [code]ADD_RESOURCE[/code] 发射 [signal resource_add_requested][br]
##   - [code]ADD_CARD[/code] 发射 [signal card_reward_requested]（fire-and-forget）[br]
##   - [code]TRIGGER_BATTLE[/code] / [code]HEAL[/code] / [code]DAMAGE[/code] 不执行——由调用方检查 [member EventInstance.resolved_outcomes] 后自行处理[br]
##   - [code]NOTHING[/code] 不执行——仅叙事文本[br]
##   - 未知 OutcomeType 触发 [method @GlobalScope.push_warning][br]
## [br][b]信号发射[/b]：所有 outcome 处理完成后发射 [param card_reward_requested] / [param resource_add_requested] / [param event_resolved]。[br]
## [br][param instance] 已通过 [method resolve_option] 结算的 EventInstance。[br]
## [param card_reward_requested] [signal EventSystem.card_reward_requested] 信号引用。[br]
## [param resource_add_requested] [signal EventSystem.resource_add_requested] 信号引用。[br]
## [param event_resolved] [signal EventSystem.event_resolved] 信号引用。
func apply_outcomes(instance: EventInstance, card_reward_requested: Signal, resource_add_requested: Signal, event_resolved: Signal) -> void:
	for oc in instance.resolved_outcomes:
		if not oc["triggered"]:
			continue
		match oc["type"]:
			EventEnums.OutcomeType.ADD_RESOURCE:
				resource_add_requested.emit(StringName(oc["target"]), int(oc["value"]))
			EventEnums.OutcomeType.ADD_CULTIVATION:
				GameStateManager.add_cultivation(int(oc["value"]))
			EventEnums.OutcomeType.ADD_CARD:
				card_reward_requested.emit(StringName(oc["target"]))
			EventEnums.OutcomeType.REMOVE_CARD:
				GameStateManager.remove_card_from_collection(int(oc["value"]))
			EventEnums.OutcomeType.SET_FLAG:
				EventSystem.set_flag(oc["target"], oc["value_str"])
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

	event_resolved.emit(instance.template_id, instance.selected_option_index, instance.resolved_outcomes)


## 从候选事件池中按权重随机选择一个事件。[br]
## [br]自动过滤 [member EventTemplate.min_realm] > [param realm] 的模板，[br]
## 以及 [member EventTemplate.weight] == 0 的模板。[br]
## [br]使用累积分布函数 (CDF)——O(n)，n 为候选数量。[br]
## [br][b]参数[/b]:[br]
##   - [param candidates]: 候选模板 ID 列表[br]
##   - [param realm]: 当前玩家境界——用于过滤 min_realm[br]
## [br][b]返回[/b]: 选中的 template_id，或空 StringName（无合格候选时）。
func select_event(candidates: Array[StringName], realm: int) -> StringName:
	var eligible: Array[Dictionary] = []  # [{id, weight}]
	var total_weight: float = 0.0

	for id in candidates:
		var tmpl: EventTemplate = _templates.get(id, null) as EventTemplate
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

	var roll := randf_range(0.0, total_weight)
	var cumulative: float = 0.0
	for entry in eligible:
		cumulative += float(entry["weight"])
		if roll <= cumulative:
			return entry["id"]

	return eligible[-1]["id"]