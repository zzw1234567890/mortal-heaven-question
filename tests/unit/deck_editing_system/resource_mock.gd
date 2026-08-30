extends Node
## ResourceSystem mock——测试 DeckEditingSystem 时替换 ResourceSystem。[br]
## [br]模拟 add_resource/spend_resource/can_spend + dismantle_value/delete_card_cost。[br]
## [br]来源: ADR-0023 §公式委托边界 测试桩。

var _ling_shi: int = 0

const DISMANTLE_BASE: PackedInt32Array = [10, 30, 100, 400, 2000]
const DELETE_BASE: int = 50
const DELETE_INCREMENT: int = 25


func add_resource(type: StringName, amount: int, quality: int = -1) -> bool:
	if type == &"ling_shi":
		_ling_shi += amount
		return true
	return false


func spend_resource(type: StringName, amount: int, quality: int = -1) -> bool:
	if type == &"ling_shi":
		if _ling_shi < amount:
			return false
		_ling_shi -= amount
		return true
	return false


func can_spend(type: StringName, amount: int, quality: int = -1) -> bool:
	if type == &"ling_shi":
		return _ling_shi >= amount
	return false


func dismantle_value(rarity: int, level: int) -> int:
	if rarity < 1 or rarity > 5:
		return 0
	var base: int = DISMANTLE_BASE[rarity - 1]
	var bonus: int = floori(base * maxi(0, level - 1) * 0.05)
	return base + bonus


func delete_card_cost(delete_count: int) -> int:
	if delete_count < 1:
		return DELETE_BASE
	return DELETE_BASE + DELETE_INCREMENT * (delete_count - 1)