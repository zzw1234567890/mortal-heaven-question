extends RefCounted
## BindingSlotOps —— 绑定槽位查询/创建辅助子模块（从 binding_manager.gd 拆分）。
##
## RefCounted 子模块——持有 `_parent: Node` 引用（BindingManager Autoload）。
## 包含槽位查询/创建/本命判定辅助方法。
##
## [br]来源: ADR-0013 §关键接口 / GDD binding-system.md §1 绑定数据结构。
## [br]Sprint 12 Story 2：从 binding_manager.gd 拆分。


const BindingRecord = preload("res://src/feature/binding/binding_record.gd")

var _parent: Node = null


func _init(parent: Node = null) -> void:
	_parent = parent


## 构造 BindingRecord——填充标识/槽位/叠层字段。
func make_record(card_instance_id: int, template_id: StringName, character_id: int, slot_type: int, slot_index: int) -> Object:
	var record = BindingRecord.new()
	record.binding_id = _parent.get("_next_binding_id")
	_parent.set("_next_binding_id", _parent.get("_next_binding_id") + 1)
	record.card_instance_id = card_instance_id
	record.card_template_id = template_id
	record.slot_type = slot_type
	record.slot_index = slot_index
	record.bound_character_id = character_id
	record.activated_turn = 0
	var slots: Array[int] = [card_instance_id]
	record.stack_slots = slots
	record.stack_count = 1
	return record


## 本命判定（AC-005）——native_owner 匹配角色 card_id + 同类型本命位未占用 → 本命。
func determine_native(character_id: int, native_owner: StringName, character_card_id: StringName, slot_type: int) -> Dictionary:
	if native_owner == &"":
		return {"is_native": false, "native_multiplier": 1.0}
	if not native_matches(character_card_id, native_owner):
		return {"is_native": false, "native_multiplier": 1.0}
	if has_native_binding(character_id, slot_type):
		return {"is_native": false, "native_multiplier": 1.0}
	return {"is_native": true, "native_multiplier": _parent.get("NATIVE_MULTIPLIER")}


## 本命分段匹配——native_owner 作为下划线分隔的完整段出现在 character_card_id 中。
func native_matches(character_card_id: StringName, native_owner: StringName) -> bool:
	var card_seg: String = "_" + String(character_card_id) + "_"
	var owner_seg: String = "_" + String(native_owner) + "_"
	return card_seg.contains(owner_seg)


## 检查角色某类型本命位是否已被占用。
func has_native_binding(character_id: int, slot_type: int) -> bool:
	var bindings: Dictionary = _parent.get("_bindings")
	for binding_id: int in _parent.call("get_binding_ids_by_character", character_id):
		if not bindings.has(binding_id):
			continue
		var record = bindings[binding_id]
		if record.slot_type == slot_type and record.is_native:
			return true
	return false


## 统计角色某类型的已占用槽位数。
func count_bound_slots(character_id: int, slot_type: int) -> int:
	var bindings: Dictionary = _parent.get("_bindings")
	var count: int = 0
	for binding_id: int in _parent.call("get_binding_ids_by_character", character_id):
		if bindings.has(binding_id) and bindings[binding_id].slot_type == slot_type:
			count += 1
	return count


## 查找角色已绑定的同名卡（按模板 ID 判定）。
func find_same_template_binding(character_id: int, template_id: StringName) -> Object:
	var bindings: Dictionary = _parent.get("_bindings")
	for binding_id: int in _parent.call("get_binding_ids_by_character", character_id):
		if bindings.has(binding_id):
			var record = bindings[binding_id]
			if record.card_template_id == template_id:
				return record
	return null


## 查找角色某槽位上的绑定记录。
func find_binding_at_slot(character_id: int, slot_index: int) -> Object:
	var bindings: Dictionary = _parent.get("_bindings")
	for binding_id: int in _parent.call("get_binding_ids_by_character", character_id):
		if bindings.has(binding_id):
			var record = bindings[binding_id]
			if record.slot_index == slot_index:
				return record
	return null


## 查找某类型的第一个空闲槽位索引（0..limit-1）。
func find_free_slot_index(character_id: int, slot_type: int, limit: int) -> int:
	var bindings: Dictionary = _parent.get("_bindings")
	var occupied: Dictionary = {}
	for binding_id: int in _parent.call("get_binding_ids_by_character", character_id):
		if bindings.has(binding_id):
			var record = bindings[binding_id]
			if record.slot_type == slot_type:
				occupied[record.slot_index] = true
	for slot_index: int in range(limit):
		if not occupied.has(slot_index):
			return slot_index
	push_error("find_free_slot_index: 槽位已满仍被调用（character_id=%d, slot_type=%d, limit=%d）"
			% [character_id, slot_type, limit])
	return -1
