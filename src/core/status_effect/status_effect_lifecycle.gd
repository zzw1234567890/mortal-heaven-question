extends RefCounted
## StatusEffectLifecycle —— 状态施加管线子模块（从 status_effect_system.gd 拆分）。
##
## 持有对 StatusEffectSystem 父节点的引用，通过它访问 _instances/_by_target/
## _next_status_id 注册表与 _check_immunity/get_active_count 方法，
## 信号仍由父节点发射（信号声明在 StatusEffectSystem 上，Cat 2b）。
##
## [br]来源: ADR-0011 §叠加规则 §20 上限驱逐。
## [br]Sprint 12 Story 016：从 status_effect_system.gd 拆分。

const _StatusInstance = preload("res://src/core/status_effect/status_instance.gd")
const _StatusTemplate = preload("res://src/core/status_effect/status_template.gd")

## 父节点引用——StatusEffectSystem Autoload 实例。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


## 施加状态到目标——完整管线。[br]
## [br][b]管线[/b]：[br]
##   1. 加载模板（失败 → reason="unknown_template"）[br]
##   2. 免疫检查 3 级短路（type → template → element）→ 命中返回 reason="immune"[br]
##   3. 同名查找 → 叠加判定：[br]
##      - 独立 → 跳过叠加，走 NEW 路径[br]
##      - 刷新 → 刷新 duration + 发射 status_updated[br]
##      - 叠加上限 → current_stacks+1（封顶返回 reason="max_stacks"）[br]
##   4. NEW 路径 → 20 上限检查 → 溢出驱逐 → 注册 → 发射 status_applied[br]
## [br][param target_id] 目标角色实例 ID。[br]
## [param template_id] 状态模板 ID。[br]
## [param source_card_instance_id] 来源卡牌实例 ID（追溯用）。[br]
## [param overrides] 覆盖字段（支持 [code]"value"[/code]）。[br]
## [param current_turn] 当前回合数（用于同回合不倒计时判定，-1 不追踪）。[br]
## [br][b]返回[/b]: [Dictionary]——[code]{applied: bool, status_id: int, reason: String}[/code]。
func apply_status(
	target_id: int,
	template_id: StringName,
	source_card_instance_id: int,
	overrides: Dictionary = {},
	current_turn: int = -1
) -> Dictionary:
	var template: StatusTemplate = _parent.get_status_template(template_id)
	if template == null:
		return {applied = false, status_id = 0, reason = "unknown_template"}

	# 阶段 1：免疫检查（3 级短路）
	var immune_result: Dictionary = _parent.call("_check_immunity", target_id, template)
	if immune_result.blocked:
		_parent.get("status_immunity_blocked").emit(target_id, template_id, immune_result.immune_level)
		return {applied = false, status_id = 0, reason = "immune"}

	# 阶段 2：同名查找 → 叠加判定
	var existing: StatusInstance = find_existing(target_id, template_id)
	if existing != null:
		match template.stack_rule:
			_StatusTemplate.StackRule.REFRESH:
				existing.duration = template.base_duration
				# overrides.value 覆盖（若有指定）
				if overrides.has("value"):
					existing.value = float(overrides["value"])
				_parent.get("status_updated").emit(target_id, existing.id, {duration = existing.duration, value = existing.value})
				return {applied = true, status_id = existing.id, reason = "refreshed"}

			_StatusTemplate.StackRule.CUMULATIVE:
				if existing.current_stacks < template.max_stacks:
					existing.current_stacks += 1
					_parent.get("status_updated").emit(target_id, existing.id, {current_stacks = existing.current_stacks})
					return {applied = true, status_id = existing.id, reason = "stacked"}
				else:
					return {applied = false, status_id = existing.id, reason = "max_stacks"}

			_StatusTemplate.StackRule.INDEPENDENT:
				pass  # 跳过叠加——走 NEW 路径
			_:
				pass  # 未知叠加规则——走 NEW 路径

	# 阶段 3：NEW 路径——20 上限检查
	if _parent.call("get_active_count", target_id) >= _parent.get("MAX_ACTIVE_STATUSES_PER_CHARACTER"):
		evict_lowest(target_id)

	# 阶段 4：创建新实例 + 注册
	var instance: StatusInstance = _StatusInstance.new()
	instance.id = _parent.get("_next_status_id")
	_parent.set("_next_status_id", instance.id + 1)
	instance.template_id = template_id
	instance.target_id = target_id
	instance.duration = template.base_duration
	instance.applied_turn = current_turn
	instance.base_value = template.base_value
	instance.value = float(overrides.get("value", template.base_value))
	instance.current_stacks = 1
	instance.source_card_instance_id = source_card_instance_id
	instance.priority = template.default_priority
	instance.is_hidden = false
	instance.is_expired = false
	instance.metadata = template.metadata.duplicate(true)

	_parent.call("_register_instance", instance)
	_parent.get("status_applied").emit(target_id, instance.id, template_id, instance.current_stacks, "new")
	return {applied = true, status_id = instance.id, reason = "new"}


## 查找目标身上已存在的同名状态实例。[br]
## [br][b]返回[/b]: [StatusInstance] 或 [code]null[/code]（不存在）。
func find_existing(target_id: int, template_id: StringName) -> StatusInstance:
	var instances: Dictionary = _parent.get("_instances")
	var ids: Array = _parent.get("_by_target").get(target_id, [])
	for id in ids:
		var status = instances[id]
		if status.template_id == template_id:
			return status
	return null


## 溢出驱逐——按 priority 升序 + applied_turn 升序选首个移除。[br]
## [br]驱逐策略（ADR-0011 §活跃上限驱逐）：遍历 _by_target[target_id] →[br]
## 排序（priority ASC, applied_turn ASC）→ 移除首位 → 发射 status_removed(reason="overflow")。[br]
## [br][b]确定性[/b]：同 priority 取 applied_turn 最旧；同 applied_turn 取 priority 最低。
func evict_lowest(target_id: int) -> void:
	var instances: Dictionary = _parent.get("_instances")
	var ids: Array = _parent.get("_by_target").get(target_id, [])
	if ids.is_empty():
		return

	# 收集所有状态以便排序
	var candidates: Array = []
	for id in ids:
		var status = instances[id]
		candidates.append({status_id = status.id, priority = status.priority, applied_turn = status.applied_turn})

	# 排序：priority 升序（数值最小=最低优先级，优先驱逐）→ applied_turn 升序（最旧优先驱逐）
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.priority != b.priority:
			return a.priority < b.priority  # 数值小（低优先级）排前面（优先驱逐）
		return a.applied_turn < b.applied_turn  # 旧 applied_turn 排前面
	)

	var to_evict: int = candidates[0].status_id
	_parent.call("_remove_instance", to_evict, "overflow")
