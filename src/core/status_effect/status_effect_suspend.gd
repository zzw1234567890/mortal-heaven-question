extends RefCounted
## StatusEffectSuspend —— 状态效果暂挂/恢复子模块（从 status_effect_system.gd 拆分）。
##
## 持有对 StatusEffectSystem 父节点的引用，通过它访问 _instances / _by_target /
## _suspended / MAX_ACTIVE_STATUSES_PER_CHARACTER 常量 / _register_instance /
## _evict_lowest / get_active_count 等状态和方法。
##
## [br]来源: ADR-0011 §暂挂/恢复。
## [br]Sprint 10 Story 1：从 status_effect_system.gd 拆分。

## 父节点引用——StatusEffectSystem Autoload 实例。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


## 暂挂状态——将实例从活跃注册表迁入 _suspended，冻结倒计时。[br]
## [br][param status_id] 状态实例 ID。[br]
## [br][b]返回[/b]: 暂挂成功 true；不存在返回 false（不报错）。
func suspend_status(status_id: int) -> bool:
	var instances: Dictionary = _parent.get("_instances")
	var by_target: Dictionary = _parent.get("_by_target")
	var suspended: Dictionary = _parent.get("_suspended")
	var status: StatusInstance = instances.get(status_id, null)
	if status == null:
		return false
	# 从 _instances + _by_target 移除（不发射 status_removed——暂挂非移除）
	instances.erase(status_id)
	var ids: Array = by_target.get(status.target_id, [])
	ids.erase(status_id)
	if ids.is_empty():
		by_target.erase(status.target_id)
	# 迁入 _suspended
	suspended[status_id] = status
	return true


## 恢复暂挂状态——将实例从 _suspended 迁回活跃注册表，恢复倒计时。[br]
## [br]恢复时若目标已达 20 上限，触发驱逐（复用 _evict_lowest）。[br]
## [br][param status_id] 状态实例 ID。[br]
## [br][b]返回[/b]: 恢复成功 true；不存在返回 false（不报错）。
func restore_status(status_id: int) -> bool:
	var suspended: Dictionary = _parent.get("_suspended")
	var status: StatusInstance = suspended.get(status_id, null)
	if status == null:
		return false
	# 20 上限检查——恢复前若已满，驱逐（AC-014）
	if _parent.call("get_active_count", status.target_id) >= _parent.get("MAX_ACTIVE_STATUSES_PER_CHARACTER"):
		_parent.call("_evict_lowest", status.target_id)
	# 迁回活跃
	suspended.erase(status_id)
	_parent.call("_register_instance", status)
	return true


## 恢复目标的所有暂挂状态——按 priority 降序 + applied_turn 升序（稳定性保证）。[br]
## [br][param target_id] 目标角色实例 ID。[br]
## [br][b]来源[/b]: ADR-0011 §暂挂/恢复 §排序契约（AC-013）。
func restore_all_suspended(target_id: int) -> void:
	var suspended: Dictionary = _parent.get("_suspended")
	var suspended_ids: Array[int] = []
	for status_id: int in suspended:
		var status: StatusInstance = suspended[status_id]
		if status.target_id == target_id:
			suspended_ids.append(status_id)
	# 排序：priority 降序（大数值=高优先级先恢复）+ applied_turn 升序
	suspended_ids.sort_custom(func(a: int, b: int) -> bool:
		var sa: StatusInstance = suspended[a]
		var sb: StatusInstance = suspended[b]
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
	var suspended: Dictionary = _parent.get("_suspended")
	var result: Array[int] = []
	for status_id: int in suspended:
		var status: StatusInstance = suspended[status_id]
		if status.target_id == target_id:
			result.append(status_id)
	return result
