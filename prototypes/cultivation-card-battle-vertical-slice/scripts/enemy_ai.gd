# VERTICAL SLICE - NOT FOR PRODUCTION
# Date: 2026-07-27
##
## 敌方 AI —— 管理 6 个敌方阵位 + 行为序列，生产环境中由 AISystem 管理。

class_name VSEnemyAI
extends Node

signal enemy_slot_hp_changed(slot_index: int, old_hp: int, new_hp: int)
signal enemy_slot_died(slot_index: int)
signal enemy_is_dead()

## 敌方角色库
const ENEMY_CHARACTERS: Dictionary = {
	"stone_guard":   {"name": "石傀守卫", "max_hp": 40, "attack": 6},
	"stone_soldier": {"name": "石傀兵卒", "max_hp": 35, "attack": 5},
	"stone_captain": {"name": "石傀队长", "max_hp": 55, "attack": 8},
	"stone_shaman":  {"name": "石傀术士", "max_hp": 30, "attack": 7},
	"stone_brute":   {"name": "石傀蛮兵", "max_hp": 50, "attack": 9},
	"stone_scout":   {"name": "石傀探哨", "max_hp": 28, "attack": 4},
}

const ENEMY_POOL: Array[String] = ["stone_guard", "stone_soldier", "stone_captain", "stone_shaman", "stone_brute", "stone_scout"]

## 6 个敌方阵位
var _slots: Array[Dictionary] = []
var _alive_count: int = 0

## 行为序列
var _action_sequence: Array[Dictionary] = [
	{"name": "石拳砸击", "damage": 6},
	{"name": "石拳砸击", "damage": 6},
	{"name": "蓄力重击", "damage": 12},
]
var _sequence_index: int = 0


func _ready() -> void:
	for _i in range(6):
		_slots.append({"character_id": "", "current_hp": 0, "max_hp": 0, "attack": 0, "is_alive": false})


func deploy_random(count: int) -> void:
	## 随机部署 count 个敌方角色
	var pool := ENEMY_POOL.duplicate()
	pool.shuffle()
	for i in range(mini(count, pool.size())):
		var char_id: String = pool[i]
		var cdata: Dictionary = ENEMY_CHARACTERS[char_id]
		_slots[i] = {
			"character_id": char_id,
			"current_hp": cdata["max_hp"],
			"max_hp": cdata["max_hp"],
			"attack": cdata["attack"],
			"is_alive": true,
		}
		_alive_count += 1


func get_total_attack() -> int:
	var total: int = 0
	for i in range(6):
		if _slots[i].get("is_alive", false):
			total += _slots[i].get("attack", 0)
	return total


func get_alive_count() -> int:
	return _alive_count


func is_all_dead() -> bool:
	return _alive_count <= 0


func get_slot(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= 6:
		return {}
	return _slots[slot_index]


func get_front_row_alive() -> Array[int]:
	var alive: Array[int] = []
	for i in range(3):
		if _slots[i].get("is_alive", false):
			alive.append(i)
	return alive


func get_back_row_alive() -> Array[int]:
	var alive: Array[int] = []
	for i in range(3, 6):
		if _slots[i].get("is_alive", false):
			alive.append(i)
	return alive


func take_damage(slot_index: int, amount: int) -> int:
	if amount <= 0:
		return 0
	if slot_index < 0 or slot_index >= 6:
		return 0
	if not _slots[slot_index].get("is_alive", false):
		return 0

	var old_hp: int = _slots[slot_index].get("current_hp", 0)
	var new_hp: int = maxi(0, old_hp - amount)
	_slots[slot_index]["current_hp"] = new_hp

	enemy_slot_hp_changed.emit(slot_index, old_hp, new_hp)

	if new_hp <= 0:
		_slots[slot_index]["is_alive"] = false
		_alive_count -= 1
		enemy_slot_died.emit(slot_index)
		if _alive_count <= 0:
			enemy_is_dead.emit()

	return amount


func get_next_action() -> Dictionary:
	var action: Dictionary = _action_sequence[_sequence_index]
	_sequence_index = (_sequence_index + 1) % _action_sequence.size()
	return action