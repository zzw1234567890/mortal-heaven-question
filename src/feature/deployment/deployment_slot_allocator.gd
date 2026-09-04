extends RefCounted
## DeploymentSlotAllocator —— 阵位分配算法子模块（从 deployment_system.gd 拆分）。
##
## 持有对 DeploymentSystem 父节点的引用，通过它访问常量和辅助方法。[br]
## [br]来源: ADR-0016 §阵位数据模型 / GDD deployment-system.md §2。[br]
## [br]Sprint 9 Story 1：从 deployment_system.gd 拆分。

## 父节点引用——DeploymentSystem Autoload 实例。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


## 阵位分配——手动布局优先，未指定角色按「前排队列填满后才填后排」分配（GDD §2 关键规则）。[br]
## [br]自动分配算法（前排配额上限，按 [constant FRONT_CAPACITY_BY_MAX_DEPLOY]）：[br]
##   - 前 N 个未指定角色放前排（N = 境界前排配额，直到配额用尽）[br]
##   - 剩余角色放后排（前排优先顺序：前1→前2→前3→后1→后2→后3）[br]
## [br][param character_ids] 上场角色 ID 列表。[br]
## [br][param layout] 手动前后排分配 [code]{char_id: is_front}[/code]。[br]
## [br][b]返回[/b]: [code]{character_id: slot_index}[/code]。
func assign_slots(character_ids: Array, layout: Dictionary) -> Dictionary:
	var assignment: Dictionary = {}
	var used: Dictionary = {}  # slot_index -> true
	var max_deploy: int = _parent.call("_query_max_deploy")
	var front_capacity_by_max: Dictionary = _parent.get("FRONT_CAPACITY_BY_MAX_DEPLOY")
	var front_slots: int = _parent.get("FRONT_SLOTS")
	var front_capacity: int = front_capacity_by_max.get(max_deploy, front_slots)
	var front_assigned: int = 0

	# 1. 手动布局优先（指定 is_front 的角色放入对应行列；计入前排配额）
	for cid in character_ids:
		if not layout.has(cid):
			continue
		var is_front: bool = layout[cid]
		var slot: int = _find_empty_in_row(is_front, used)
		if slot == -1:
			slot = _find_empty_slot(used)  # 目标行已满——回退任意空位
		assignment[cid] = slot
		used[slot] = true
		if is_front:
			front_assigned += 1

	# 2. 自动分配剩余角色——前排配额填满后转后排（后排优先顺序：后1→后2→后3）
	for cid in character_ids:
		if assignment.has(cid):
			continue
		var slot: int
		if front_assigned < front_capacity:
			slot = _find_empty_in_row(true, used)
			if slot == -1:
				slot = _find_empty_slot(used)
			front_assigned += 1
		else:
			slot = _find_empty_in_row(false, used)
			if slot == -1:
				slot = _find_empty_slot(used)
		assignment[cid] = slot
		used[slot] = true
	return assignment


## 在指定行列查找空位。[br]
## [br][param is_front] true = 前排（0,1,2）；false = 后排（3,4,5）。[br]
## [br][param used] 已占用 slot 集合。[br]
## [br][b]返回[/b]: 空位 slot_index；行列已满返回 -1。
func _find_empty_in_row(is_front: bool, used: Dictionary) -> int:
	var slots: Array = [0, 1, 2] if is_front else [3, 4, 5]
	for s in slots:
		if not used.has(s):
			return s
	return -1


## 查找任意空位（前排优先排序）。[br]
## [br][b]返回[/b]: 空位 slot_index；全部已满返回 -1。
func _find_empty_slot(used: Dictionary) -> int:
	for s in [0, 1, 2, 3, 4, 5]:
		if not used.has(s):
			return s
	return -1
