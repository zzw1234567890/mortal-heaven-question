extends Node
# class_name StatusEffectSystem —— 不声明：Autoload 全局单例，
# 声明 class_name 会与全局名冲突，导致 SES_SCRIPT.new() 测试实例无法解析。
# 测试以 var ses: Node 持有 + 动态分派访问（同 GSM/EventSystem/RealmSystem/
# ResourceSystem/CardSystem/FactionSystem 先例，控制清单 2026-08-05 规则）。

## StatusEffectSystem —— 状态效果生命周期管理 Autoload（#8）。
##
## Core 层 Autoload。持有 [_instances] + [_by_target] 内部注册表，
## 提供 [method apply_status] / [method remove_status] / [method tick_all] 等 API。
## 采用双层模型——StatusTemplate（Resource, .tres, 只读）+ StatusInstance（RefCounted, 运行时可变）。
##
## [b]Story 002 范围[/b]：叠加规则（独立/刷新/叠加上限）+ 免疫 3 级短路 + 20 上限驱逐。
##
## [b]Autoload 顺序[/b]：GSM → ... → FactionSystem → StatusEffectSystem（#8）
## （在 CardSystem/CostSystem 之后、CombatSystem 之前——ADR-0011 §Autoload 初始化）。
##
## [b]信号架构[/b]：4 个 Cat 2b 信号声明在本系统（非 GSM）——
## status_applied / status_removed / status_updated / status_immunity_blocked。
##
## 来源: ADR-0011。

# === 信号声明（Cat 2b）============================================================

## 状态成功施加到目标时发射。
signal status_applied(target_id: int, status_id: int, template_id: StringName, stacks: int, reason: String)

## 状态被移除时发射（过期/手动/溢出驱逐）。
signal status_removed(target_id: int, status_id: int, template_id: StringName, reason: String)

## 状态层数/数值/duration 变更时发射（不含每帧递减——见 tick_all）。
signal status_updated(target_id: int, status_id: int, changes: Dictionary)

## 施加被免疫阻挡时发射。
signal status_immunity_blocked(target_id: int, template_id: StringName, immune_level: String)


# === 常量 ========================================================================

## 每角色最大活跃状态数（ADR-0011 §溢出驱逐）。
const MAX_ACTIVE_STATUSES_PER_CHARACTER: int = 20

## 默认模板目录路径。
const DEFAULT_TEMPLATE_PATH: StringName = &"res://assets/statuses/"


# === 内部注册表 ===================================================================

## 所有活跃状态实例的权威注册表——key=status_id, value=StatusInstance。
var _instances: Dictionary = {}

## 角色级状态索引——key=target_id, value=Array[int]（status_id 列表）。O(1) 角色查询。
var _by_target: Dictionary = {}

## 模板注册表——key=template_id, value=StatusTemplate。由 _ready() 加载。
var _templates: Dictionary = {}

## 下一个状态实例 ID（单调递增）。
var _next_status_id: int = 1

## 免疫标志注册表——key=target_id, value={type: Dictionary, template: Dictionary, element: Dictionary}。
var _immunity_flags: Dictionary = {}

## 暂挂状态注册表——key=status_id, value=StatusInstance（Story 003）。
## 暂挂状态从 _instances/_by_target 迁出，冻结倒计时（tick_all 不递减）。
var _suspended: Dictionary = {}


# === 内置虚方法 ===================================================================

func _ready() -> void:
	_load_templates_from(DEFAULT_TEMPLATE_PATH)


# === 公共 API =====================================================================

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
	var template: StatusTemplate = get_status_template(template_id)
	if template == null:
		return {applied = false, status_id = 0, reason = "unknown_template"}

	# 阶段 1：免疫检查（3 级短路）
	var immune_result: Dictionary = _check_immunity(target_id, template)
	if immune_result.blocked:
		status_immunity_blocked.emit(target_id, template_id, immune_result.immune_level)
		return {applied = false, status_id = 0, reason = "immune"}

	# 阶段 2：同名查找 → 叠加判定
	var existing: StatusInstance = _find_existing(target_id, template_id)
	if existing != null:
		match template.stack_rule:
			StatusTemplate.StackRule.REFRESH:
				existing.duration = template.base_duration
				# overrides.value 覆盖（若有指定）
				if overrides.has("value"):
					existing.value = float(overrides["value"])
				status_updated.emit(target_id, existing.id, {duration = existing.duration, value = existing.value})
				return {applied = true, status_id = existing.id, reason = "refreshed"}

			StatusTemplate.StackRule.CUMULATIVE:
				if existing.current_stacks < template.max_stacks:
					existing.current_stacks += 1
					status_updated.emit(target_id, existing.id, {current_stacks = existing.current_stacks})
					return {applied = true, status_id = existing.id, reason = "stacked"}
				else:
					return {applied = false, status_id = existing.id, reason = "max_stacks"}

			StatusTemplate.StackRule.INDEPENDENT:
				pass  # 跳过叠加——走 NEW 路径
			_:
				pass  # 未知叠加规则——走 NEW 路径

	# 阶段 3：NEW 路径——20 上限检查
	if get_active_count(target_id) >= MAX_ACTIVE_STATUSES_PER_CHARACTER:
		_evict_lowest(target_id)

	# 阶段 4：创建新实例 + 注册
	var instance: StatusInstance = StatusInstance.new()
	instance.id = _next_status_id
	_next_status_id += 1
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

	_register_instance(instance)
	status_applied.emit(target_id, instance.id, template_id, instance.current_stacks, "new")
	return {applied = true, status_id = instance.id, reason = "new"}


## 获取目标的所有活跃 status_id 列表。[br]
## [br][b]复杂度[/b]: O(1) 字典查询 + O(n) 数组复制（n = 该角色状态数）。[br]
## [br][b]返回[/b]: [Array[int]]——status_id 列表；无状态返回空数组。
func get_active_statuses(target_id: int) -> Array[int]:
	var result: Array[int] = []
	var ids: Array = _by_target.get(target_id, [])
	for id in ids:
		result.append(id)
	return result


## 获取目标的活跃状态数（含 is_expired 未移除的）。[br]
## [br][b]返回[/b]: 活跃状态数。
func get_active_count(target_id: int) -> int:
	var ids: Array = _by_target.get(target_id, [])
	return ids.size()


## 导出所有活跃状态的快照（Array[Dictionary]）。[br]
## [br]过滤 [code]is_expired=true[/code] 的状态，仅序列化活跃实例。[br]
## 按 target_id 升序分组（同 target_id 连续排列）。[br]
## [br][b]返回[/b]: Array[Dictionary]——每个含 id/template_id/target_id/duration/applied_turn/[br]
##            value/current_stacks/source_card_instance_id/priority/is_hidden/metadata。[br]
## [br][b]来源[/b]: ADR-0011 §snapshot 导出。
func export_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var statuses: Array = []
	for status_id: int in _instances:
		var status: StatusInstance = _instances[status_id]
		if status.is_expired:
			continue  # 排除过期状态（AC-002）
		statuses.append(status)
	# 按 target_id 升序分组（AC-003）
	statuses.sort_custom(func(a: StatusInstance, b: StatusInstance) -> bool:
		return a.target_id < b.target_id
	)
	for status: StatusInstance in statuses:
		result.append(_serialize_status(status))
	return result


## 写入快照到 GSM battle 域（GSM 例外——仅快照不存活跃实例）。[br]
## [br]GSM 不可用时静默跳过（is_instance_valid + has_method 双守卫）。[br]
## [br][b]来源[/b]: ADR-0011 §GSM 例外模式。
func write_snapshot_to_gsm() -> void:
	var gsm: Node = _get_gsm()
	if gsm == null or not gsm.has_method("_set_battle_status_snapshot"):
		return  # GSM 不可用——静默跳过（AC-005）
	var snapshot: Array[Dictionary] = export_snapshot()
	gsm.call("_set_battle_status_snapshot", snapshot)


## 暂挂状态——将实例从活跃注册表迁入 _suspended，冻结倒计时。[br]
## [br][param status_id] 状态实例 ID。[br]
## [br][b]返回[/b]: 暂挂成功 true；不存在返回 false（不报错）。
func suspend_status(status_id: int) -> bool:
	var status: StatusInstance = _instances.get(status_id, null)
	if status == null:
		return false
	# 从 _instances + _by_target 移除（不发射 status_removed——暂挂非移除）
	_instances.erase(status_id)
	var ids: Array = _by_target.get(status.target_id, [])
	ids.erase(status_id)
	if ids.is_empty():
		_by_target.erase(status.target_id)
	# 迁入 _suspended
	_suspended[status_id] = status
	return true


## 恢复暂挂状态——将实例从 _suspended 迁回活跃注册表，恢复倒计时。[br]
## [br]恢复时若目标已达 20 上限，触发驱逐（复用 _evict_lowest）。[br]
## [br][param status_id] 状态实例 ID。[br]
## [br][b]返回[/b]: 恢复成功 true；不存在返回 false（不报错）。
func restore_status(status_id: int) -> bool:
	var status: StatusInstance = _suspended.get(status_id, null)
	if status == null:
		return false
	# 20 上限检查——恢复前若已满，驱逐（AC-014）
	if get_active_count(status.target_id) >= MAX_ACTIVE_STATUSES_PER_CHARACTER:
		_evict_lowest(status.target_id)
	# 迁回活跃
	_suspended.erase(status_id)
	_register_instance(status)
	return true


## 恢复目标的所有暂挂状态——按 priority 降序 + applied_turn 升序（稳定性保证）。[br]
## [br][param target_id] 目标角色实例 ID。[br]
## [br][b]来源[/b]: ADR-0011 §暂挂/恢复 §排序契约（AC-013）。
func restore_all_suspended(target_id: int) -> void:
	var suspended_ids: Array[int] = []
	for status_id: int in _suspended:
		var status: StatusInstance = _suspended[status_id]
		if status.target_id == target_id:
			suspended_ids.append(status_id)
	# 排序：priority 降序（大数值=高优先级先恢复）+ applied_turn 升序
	suspended_ids.sort_custom(func(a: int, b: int) -> bool:
		var sa: StatusInstance = _suspended[a]
		var sb: StatusInstance = _suspended[b]
		if sa.priority != sb.priority:
			return sa.priority > sb.priority  # 高 priority 先恢复
		return sa.applied_turn < sb.applied_turn  # 旧 applied_turn 先恢复
	)
	for status_id: int in suspended_ids:
		restore_status(status_id)


## 获取目标的暂挂状态列表。[br]
## [br][param target_id] 目标角色实例 ID。[br]
## [br][b]返回[/b]: Array[int]——暂挂 status_id 列表；无暂挂返回空数组。
func get_suspended_statuses(target_id: int) -> Array[int]:
	var result: Array[int] = []
	for status_id: int in _suspended:
		var status: StatusInstance = _suspended[status_id]
		if status.target_id == target_id:
			result.append(status_id)
	return result


## 导入快照重建状态（round-trip 反序列化）。[br]
## [br]跳过 is_expired=true 条目（AC-018）。[br]
## 重建 StatusInstance 并注册到 _instances/_by_target——保留原 id 若未冲突，否则分配新 id。[br]
## [br][param snapshot] Array[Dictionary]——export_snapshot 的输出格式。
func import_snapshot(snapshot: Array) -> void:
	for entry: Dictionary in snapshot:
		if entry.get("is_expired", false):
			continue  # 跳过过期条目
		var instance: StatusInstance = StatusInstance.new()
		# 保留原 id（若未冲突）——否则由注册时分配
		var original_id: int = int(entry.get("id", 0))
		if original_id != 0 and not _instances.has(original_id) and not _suspended.has(original_id):
			instance.id = original_id
			if original_id >= _next_status_id:
				_next_status_id = original_id + 1
		else:
			instance.id = _next_status_id
			_next_status_id += 1
		instance.template_id = entry.get("template_id", &"") as StringName
		instance.target_id = int(entry.get("target_id", 0))
		instance.duration = int(entry.get("duration", 0))
		instance.applied_turn = int(entry.get("applied_turn", -1))
		instance.value = float(entry.get("value", 0.0))
		instance.base_value = float(entry.get("base_value", 0.0))
		instance.current_stacks = int(entry.get("current_stacks", 1))
		instance.source_card_instance_id = int(entry.get("source_card_instance_id", 0))
		instance.priority = int(entry.get("priority", 0))
		instance.is_hidden = bool(entry.get("is_hidden", false))
		instance.is_expired = false
		instance.metadata = entry.get("metadata", {}) as Dictionary
		_register_instance(instance)


## 检查目标是否有指定模板的状态。[br]
## [br][param target_id] 目标角色实例 ID。[br]
## [param template_id] 状态模板 ID。[br]
## [br][b]返回[/b]: 存在则 true；过期状态（is_expired=true）仍返回 true 直到被移除。
func has_status(target_id: int, template_id: StringName) -> bool:
	var ids: Array = _by_target.get(target_id, [])
	for id in ids:
		var status: StatusInstance = _instances[id]
		if status.template_id == template_id:
			return true
	return false


## 移除指定状态实例。[br]
## [br][param status_id] 状态实例 ID。[br]
## [br][b]返回[/b]: 移除成功 true；不存在返回 false（不报错）。
func remove_status(status_id: int) -> bool:
	var status: StatusInstance = _instances.get(status_id, null)
	if status == null:
		return false
	_remove_instance(status_id, "manual")
	return true


## Phase 0 倒计时——由 CombatSystem 调用。[br]
## [br][b]流程[/b]:[br]
##   1. 遍历 field_characters → 查询 _by_target → duration>0 且非永久(-1) 则 -1[br]
##   2. duration==0 标记 is_expired[br]
##   3. 第二遍 remove_expired 统一移除 + 发射 status_removed(reason="expired")[br]
## [br][b]同回合判定[/b]（AC-012）：[param current_turn] >= 0 时跳过 applied_turn == current_turn 的状态。[br]
## [br][b]信号策略[/b]（AC-013）：duration 递减不发射 status_updated；仅移除时发射 status_removed。
func tick_all(field_characters: Array, current_turn: int = -1) -> void:
	# 第一遍：倒计时——不发射 status_updated
	for character in field_characters:
		var target_id: int = _extract_target_id(character)
		if target_id == 0:
			continue
		var status_ids: Array = _by_target.get(target_id, [])
		if status_ids.is_empty():
			continue
		for status_id in status_ids:
			var status: StatusInstance = _instances[status_id]
			if status.duration < 0:  # 永久状态不递减
				continue
			if current_turn >= 0 and status.applied_turn == current_turn:
				continue  # 同回合施加不倒计时（AC-012）
			if status.duration > 0:
				status.duration -= 1
				if status.duration == 0:
					status.is_expired = true
	# 第二遍：延迟移除过期状态——发射 status_removed(reason="expired")
	for character in field_characters:
		var target_id: int = _extract_target_id(character)
		if target_id == 0:
			continue
		_remove_expired_statuses(target_id)


## 只读访问器——查询模板注册表。[br]
## [br][b]返回[/b]: [StatusTemplate] 或 [code]null[/code]（template_id 不存在时）。
func get_status_template(template_id: StringName) -> StatusTemplate:
	return _templates.get(template_id, null) as StatusTemplate


## 设置免疫标志。[br]
## [br][param target_id] 目标角色实例 ID。[br]
## [param level] 免疫级别——"type"/"template"/"element"。[br]
## [param key] 免疫键值——StatusType 枚举值（type 级）/ template_id（template 级）/ element 字符串（element 级）。[br]
## [br][b]来源[/b]: ADR-0011 §免疫机制。
func set_immunity(target_id: int, level: String, key: Variant) -> void:
	if not _immunity_flags.has(target_id):
		_immunity_flags[target_id] = {type = {}, template = {}, element = {}}
	var target_flags: Dictionary = _immunity_flags[target_id]
	if level in target_flags:
		target_flags[level][key] = true


## 清除免疫标志。[br]
## [br]参数同 [method set_immunity]。清除不存在的免疫不报错（幂等）。[br]
## [br][b]来源[/b]: ADR-0011 §免疫机制。
func clear_immunity(target_id: int, level: String, key: Variant) -> void:
	if not _immunity_flags.has(target_id):
		return
	var target_flags: Dictionary = _immunity_flags[target_id]
	if level in target_flags:
		target_flags[level].erase(key)


# === 内部辅助 ====================================================================

## 注册实例——同步更新 _instances + _by_target。
func _register_instance(instance: StatusInstance) -> void:
	_instances[instance.id] = instance
	if not _by_target.has(instance.target_id):
		_by_target[instance.target_id] = []
	_by_target[instance.target_id].append(instance.id)


## 移除实例——同步更新 _instances + _by_target + 发射 status_removed。
func _remove_instance(status_id: int, reason: String) -> void:
	var status: StatusInstance = _instances.get(status_id, null)
	if status == null:
		return
	var target_id: int = status.target_id
	var template_id: StringName = status.template_id
	_instances.erase(status_id)
	var ids: Array = _by_target.get(target_id, [])
	ids.erase(status_id)
	if ids.is_empty():
		_by_target.erase(target_id)
	status_removed.emit(target_id, status_id, template_id, reason)


## 移除目标身上所有过期状态——发射 status_removed(reason="expired")。
func _remove_expired_statuses(target_id: int) -> void:
	var status_ids: Array = _by_target.get(target_id, [])
	var to_remove: Array[int] = []
	for status_id in status_ids:
		var status: StatusInstance = _instances[status_id]
		if status.is_expired:
			to_remove.append(status_id)
	for status_id in to_remove:
		_remove_instance(status_id, "expired")


## 3 级免疫短路检查——type → template → element。[br]
## [br][b]返回[/b]: [code]{blocked: bool, immune_level: String}[/code]。[br]
## 首个命中的级别立即返回；全部未命中返回 blocked=false。
func _check_immunity(target_id: int, template: StatusTemplate) -> Dictionary:
	if not _immunity_flags.has(target_id):
		return {blocked = false, immune_level = ""}

	var flags: Dictionary = _immunity_flags[target_id]

	# 级别 1：type 免疫（如 POISON/BUFF/DEBUFF/SPECIAL）
	var type_flags: Dictionary = flags.get("type", {})
	if type_flags.get(template.type, false):
		return {blocked = true, immune_level = "type"}

	# 级别 2：template 免疫（如 poison_3）
	var template_flags: Dictionary = flags.get("template", {})
	if template_flags.get(template.template_id, false):
		return {blocked = true, immune_level = "template"}

	# 级别 3：element 免疫（如 FIRE/ICE）
	var element_flags: Dictionary = flags.get("element", {})
	var element: String = template.metadata.get("element", "")
	if element != "" and element_flags.get(element, false):
		return {blocked = true, immune_level = "element"}

	return {blocked = false, immune_level = ""}


## 序列化单个状态实例为 Dictionary。[br]
## [br][b]返回[/b]: 含全部可序列化字段的 Dictionary。
func _serialize_status(status: StatusInstance) -> Dictionary:
	return {
		id = status.id,
		template_id = status.template_id,
		target_id = status.target_id,
		duration = status.duration,
		applied_turn = status.applied_turn,
		value = status.value,
		base_value = status.base_value,
		current_stacks = status.current_stacks,
		source_card_instance_id = status.source_card_instance_id,
		priority = status.priority,
		is_hidden = status.is_hidden,
		is_expired = status.is_expired,
		metadata = status.metadata,
	}


## 动态获取 GSM Autoload 节点。[br]
## 用 SceneTree.root 查找而非硬引用全局名 GSM——避免测试环境无 Autoload 时崩溃。
func _get_gsm() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/GameStateManager")


## 查找目标身上已存在的同名状态实例。[br]
## [br][b]返回[/b]: [StatusInstance] 或 [code]null[/code]（不存在）。
func _find_existing(target_id: int, template_id: StringName) -> StatusInstance:
	var ids: Array = _by_target.get(target_id, [])
	for id in ids:
		var status = _instances[id]
		if status.template_id == template_id:
			return status
	return null


## 溢出驱逐——按 priority 升序 + applied_turn 升序选首个移除。[br]
## [br]驱逐策略（ADR-0011 §活跃上限驱逐）：遍历 _by_target[target_id] →[br]
## 排序（priority ASC, applied_turn ASC）→ 移除首位 → 发射 status_removed(reason="overflow")。[br]
## [br][b]确定性[/b]：同 priority 取 applied_turn 最旧；同 applied_turn 取 priority 最低。
func _evict_lowest(target_id: int) -> void:
	var ids: Array = _by_target.get(target_id, [])
	if ids.is_empty():
		return

	# 收集所有状态以便排序
	var candidates: Array = []
	for id in ids:
		var status = _instances[id]
		candidates.append({status_id = status.id, priority = status.priority, applied_turn = status.applied_turn})

	# 排序：priority 升序（数值最小=最低优先级，优先驱逐）→ applied_turn 升序（最旧优先驱逐）
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.priority != b.priority:
			return a.priority < b.priority  # 数值小（低优先级）排前面（优先驱逐）
		return a.applied_turn < b.applied_turn  # 旧 applied_turn 排前面
	)

	var to_evict: int = candidates[0].status_id
	_remove_instance(to_evict, "overflow")


## 从角色实例对象提取 target_id——兼容 int/Dictionary/Object。
func _extract_target_id(character: Variant) -> int:
	if character is int:
		return character
	if character is Dictionary:
		if character.has("id"):
			return int(character["id"])
		if character.has("target_id"):
			return int(character["target_id"])
		if character.has("card_instance_id"):
			return int(character["card_instance_id"])
	if character is Object:
		if "id" in character:
			return int(character.id)
		if "target_id" in character:
			return int(character.target_id)
		if "card_instance_id" in character:
			return int(character.card_instance_id)
	return 0


## 从指定目录加载所有 .tres StatusTemplate 文件。[br]
## [br]目录不存在则空注册表（测试用——SES_SCRIPT.new() 不调 _ready()）。
func _load_templates_from(path: StringName) -> void:
	_templates.clear()
	var path_str: String = String(path)
	var dir := DirAccess.open(path_str)
	if dir == null:
		return  # 目录不存在——空注册表
	dir.include_hidden = false
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var full_path: String = path_str + file_name
			var res := load(full_path)
			if res is StatusTemplate:
				var tpl: StatusTemplate = res as StatusTemplate
				if tpl.template_id != &"":
					_templates[tpl.template_id] = tpl
		file_name = dir.get_next()
	dir.list_dir_end()