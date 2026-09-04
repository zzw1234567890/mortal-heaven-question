extends RefCounted
## StatusEffectSnapshot —— 状态效果快照导出/导入/序列化子模块（从 status_effect_system.gd 拆分）。
##
## 持有对 StatusEffectSystem 父节点的引用，通过它访问 _instances / _suspended /
## _next_status_id / _register_instance 等状态和辅助方法。
##
## [br]来源: ADR-0011 §snapshot 导出/导入。
## [br]Sprint 10 Story 1：从 status_effect_system.gd 拆分。

## 父节点引用——StatusEffectSystem Autoload 实例。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


## 导出所有活跃状态的快照（Array[Dictionary]）。[br]
## [br]过滤 [code]is_expired=true[/code] 的状态，仅序列化活跃实例。[br]
## 按 target_id 升序分组（同 target_id 连续排列）。[br]
## [br][b]返回[/b]: Array[Dictionary]——每个含 id/template_id/target_id/duration/applied_turn/[br]
##            value/current_stacks/source_card_instance_id/priority/is_hidden/metadata。[br]
## [br][b]来源[/b]: ADR-0011 §snapshot 导出。
func export_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var statuses: Array = []
	var instances: Dictionary = _parent.get("_instances")
	for status_id: int in instances:
		var status: StatusInstance = instances[status_id]
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


## 导入快照重建状态（round-trip 反序列化）。[br]
## [br]跳过 is_expired=true 条目（AC-018）。[br]
## 重建 StatusInstance 并注册到 _instances/_by_target——保留原 id 若未冲突，否则分配新 id。[br]
## [br][param snapshot] Array[Dictionary]——export_snapshot 的输出格式。
func import_snapshot(snapshot: Array) -> void:
	var instances: Dictionary = _parent.get("_instances")
	var suspended: Dictionary = _parent.get("_suspended")
	for entry: Dictionary in snapshot:
		if entry.get("is_expired", false):
			continue  # 跳过过期条目
		var instance: StatusInstance = StatusInstance.new()
		# 保留原 id（若未冲突）——否则由注册时分配
		var original_id: int = int(entry.get("id", 0))
		if original_id != 0 and not instances.has(original_id) and not suspended.has(original_id):
			instance.id = original_id
			if original_id >= _parent.get("_next_status_id"):
				_parent.set("_next_status_id", original_id + 1)
		else:
			instance.id = _parent.get("_next_status_id")
			_parent.set("_next_status_id", _parent.get("_next_status_id") + 1)
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
		_parent.call("_register_instance", instance)


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


## 动态获取 GSM Autoload 节点（同 FormationSerializer 先例）。
func _get_gsm() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/GameStateManager")
