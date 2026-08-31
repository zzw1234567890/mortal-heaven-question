extends Node
## CardSystem mock——测试 AlchemySystem 炼制编排时替换 CardSystem。[br]
## [br]模拟 create_instance 行为：返回带 card_instance_id 的实例。[br]
## [br]来源: ADR-0028 §craft_pill ⑤ 生成卡牌实例。

## 下一个分配的 card_instance_id。
var _next_id: int = 1

## CardInstance 脚本引用。
var _instance_script: Script = null


func _init() -> void:
	_instance_script = load("res://tests/unit/alchemy_system/card_instance_mock.gd")


func create_instance(template_id: StringName) -> RefCounted:
	var inst: RefCounted = _instance_script.new()
	inst.card_instance_id = _next_id
	inst.template_id = str(template_id)
	_next_id += 1
	return inst


func has_template(id: StringName) -> bool:
	return true