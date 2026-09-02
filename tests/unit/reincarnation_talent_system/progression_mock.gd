extends Node
## ProgressionSystem mock——测试 ReincarnationTalentSystem 时替换 ProgressionSystem。[br]
## [br]模拟 register_talent / get_talent_tree_state / get_talent_points 行为。[br]
## [br]来源: ADR-0012 §talents 领域。

## 已注册的天赋定义——测试验证。
var _registered_talents: Dictionary = {}

## 模拟已解锁天赋列表。
var _unlocked: Array = []

## 模拟装备天赋列表。
var _equipped: Array = []

## 模拟可用轮回点。
var _points: int = 0

## purchase_talent 返回结果（测试设置）。
var _purchase_result: Dictionary = {"success": true, "reason": ""}

## 最后一次 purchase_talent 的 talent_id。
var _last_purchase_id: String = ""

## purchase_talent 调用计数。
var _purchase_call_count: int = 0

## set_equipped_talents 返回结果（测试设置）。
var _equip_result: Dictionary = {"success": true, "reason": ""}

## add_talent_points 调用追踪。
var _add_points_called: bool = false
var _added_amount: int = 0

## set_meta_value 调用记录。
var _meta_set_calls: Array = []

## get_meta_value 模拟数据。
var _meta_values: Dictionary = {
	"total_reincarnations": 0,
	"total_completions": 0,
	"highest_realm_ever": "",
}


func register_talent(talent_id: String, definition: Dictionary) -> void:
	_registered_talents[talent_id] = definition


func get_talent_tree_state() -> Dictionary:
	return {
		"unlocked": _unlocked.duplicate(),
		"equipped": _equipped.duplicate(),
		"points": _points,
		"slots": 5 + int(_unlocked.size() / 4),
	}


func get_talent_points() -> int:
	return _points


func purchase_talent(talent_id: String) -> Dictionary:
	_last_purchase_id = talent_id
	_purchase_call_count += 1
	return _purchase_result


func set_equipped_talents(ids: Array) -> Dictionary:
	return _equip_result


func add_talent_points(amount: int) -> void:
	_add_points_called = true
	_added_amount = amount
	_points += amount


func set_meta_value(key: String, value: Variant) -> void:
	_meta_set_calls.append({"key": key, "value": value})
	_meta_values[key] = value


func get_meta_value(key: String) -> Variant:
	return _meta_values.get(key, null)
