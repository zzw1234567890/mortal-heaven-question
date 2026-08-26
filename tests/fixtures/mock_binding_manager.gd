class_name MockBindingManager
extends Node

## Mock BindingManager——用于 AISystem 预配置绑定注册/移除的单元测试。[br]
## 记录 bind_card / remove_all_bindings 的调用次数与参数。[br]
## [b]挂载到 SceneTree root 作为 /root/BindingManager[/b]——AI 通过 SceneTree 查找。[br]
## [br]用途：tests/unit/ai_system/test_difficulty_scaling_bindings.gd

var _bind_card_calls: Array = []
var _remove_all_calls: Array = []


func bind_card(card_instance_id: int, template_id: StringName, character_id: int, slot_type: int,
		native_owner: StringName = &"", character_card_id: StringName = &"") -> Dictionary:
	_bind_card_calls.append({
		"card_instance_id": card_instance_id,
		"template_id": template_id,
		"character_id": character_id,
		"slot_type": slot_type,
	})
	return {"success": true, "binding_id": _bind_card_calls.size(), "reason": "bound"}


func remove_all_bindings(character_id: int) -> Array:
	_remove_all_calls.append(character_id)
	return []


func get_bind_card_call_count() -> int:
	return _bind_card_calls.size()


func get_bind_card_calls() -> Array:
	return _bind_card_calls


func get_remove_all_call_count() -> int:
	return _remove_all_calls.size()


func get_remove_all_calls() -> Array:
	return _remove_all_calls


func reset() -> void:
	_bind_card_calls.clear()
	_remove_all_calls.clear()
