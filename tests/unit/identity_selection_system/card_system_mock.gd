extends Node
## CardSystem mock——测试 IdentitySelectionSystem.apply_identity 时替换 CardSystem。[br]
## [br]模拟 has_template / create_instance 行为：模板注册表可注入。[br]
## [br]来源: ADR-0022 §apply_identity ② 卡牌模板有效性校验。

## 模板注册表——键=card_id (String)，值=true（模拟存在）。
var _templates: Dictionary = {}

## 下一个分配的 card_instance_id（模拟 GSM.allocate_card_id）。
var _next_id: int = 1

## CardInstance 脚本引用——create_instance 返回此类型的实例。
var _instance_script: Script = null


func _init() -> void:
	_instance_script = load("res://tests/unit/identity_selection_system/card_instance_mock.gd")


func has_template(id: StringName) -> bool:
	return _templates.has(str(id))


func create_instance(template_id: StringName) -> RefCounted:
	if not _templates.has(str(template_id)):
		return null
	var inst: RefCounted = _instance_script.new()
	inst.card_instance_id = _next_id
	inst.template_id = str(template_id)
	_next_id += 1
	return inst