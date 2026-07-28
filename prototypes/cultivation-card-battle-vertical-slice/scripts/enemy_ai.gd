# VERTICAL SLICE - NOT FOR PRODUCTION
# Date: 2026-07-27
# D4 update: 2026-07-28 —— 敌方类型差异化行为序列 + 每格位独立行动
##
## 敌方 AI —— 管理 6 个敌方阵位 + 差异化行为序列。
## 垂直切片 D1：支持按玩家境界缩放敌方属性。
## 垂直切片 D4：每格位独立行动序列——不同类型敌人有不同的技能名称/伤害模式。

class_name VSEnemyAI
extends Node

signal enemy_slot_hp_changed(slot_index: int, old_hp: int, new_hp: int)
signal enemy_slot_died(slot_index: int)
signal enemy_is_dead()

## === 敌方角色库（基础属性——炼气期） =============================================

const ENEMY_CHARACTERS: Dictionary = {
	"stone_guard":   {"name": "石傀守卫", "max_hp": 40, "attack": 6, "type": "tank"},
	"stone_soldier": {"name": "石傀兵卒", "max_hp": 35, "attack": 5, "type": "basic"},
	"stone_captain": {"name": "石傀队长", "max_hp": 55, "attack": 8, "type": "elite"},
	"stone_shaman":  {"name": "石傀术士", "max_hp": 30, "attack": 7, "type": "cunning"},
	"stone_brute":   {"name": "石傀蛮兵", "max_hp": 50, "attack": 9, "type": "brute"},
	"stone_scout":   {"name": "石傀探哨", "max_hp": 28, "attack": 4, "type": "basic"},
}

## === 敌方差异化行为序列 ==========================================================

const SHAMAN_ACTIONS: Array[Dictionary] = [
	{"name": "咒火缠身", "damage": 4},
	{"name": "咒火缠身", "damage": 4},
	{"name": "灵火灼魂", "damage": 11},
]
const BRUTE_ACTIONS: Array[Dictionary] = [
	{"name": "蛮力冲撞", "damage": 7},
	{"name": "蛮力冲撞", "damage": 7},
	{"name": "重锤碎甲", "damage": 14},
]
const GUARD_ACTIONS: Array[Dictionary] = [
	{"name": "石拳砸击", "damage": 6},
	{"name": "石拳砸击", "damage": 6},
	{"name": "蓄力重击", "damage": 12},
]
const SCOUT_ACTIONS: Array[Dictionary] = [
	{"name": "快速刺击", "damage": 4},
	{"name": "快速刺击", "damage": 4},
	{"name": "穿刺要害", "damage": 9},
]
const CAPTAIN_ACTIONS: Array[Dictionary] = [
	{"name": "剑指苍穹", "damage": 8},
	{"name": "剑指苍穹", "damage": 8},
	{"name": "万剑归宗", "damage": 16},
]

## === 天劫敌人库（渡劫战时专用——高威胁特殊敌人） ================================

const TRIBULATION_ENEMIES: Dictionary = {
	"trib_bolt":     {"name": "天雷化身", "max_hp": 60,  "attack": 10, "description": "天道降下的雷劫，直击修士神魂"},
	"trib_fire":     {"name": "心火幻魔", "max_hp": 50,  "attack": 8,  "description": "由修士心魔催生的幻火"},
	"trib_ice":      {"name": "玄冰劫灵", "max_hp": 55,  "attack": 9,  "description": "冻结经脉的寒冰之劫"},
	"trib_shadow":   {"name": "业障阴兵", "max_hp": 70,  "attack": 12, "description": "前世业力所化的阴兵"},
	"trib_blood":    {"name": "血煞魔影", "max_hp": 65,  "attack": 11, "description": "修士精血引来的血煞"},
}
const TRIBULATION_POOL: Array[String] = ["trib_bolt", "trib_fire", "trib_ice", "trib_shadow", "trib_blood"]

## === 天劫行为序列 ================================================================

const TRIB_ACTIONS: Array[Dictionary] = [
	{"name": "天雷轰顶", "damage": 10},
	{"name": "心火灼魂", "damage": 8},
	{"name": "业力反噬", "damage": 14},
]

const ENEMY_POOL: Array[String] = ["stone_guard", "stone_soldier", "stone_captain", "stone_shaman", "stone_brute", "stone_scout"]

## === 敌方境界（当前仅用于压制计算——敌方都是炼气，玩家突破筑基后有压制） ============

var _realm_level: int = VSRealmData.RealmLevel.QI_REFINING

## === 阵位状态 ==================================================================

var _slots: Array[Dictionary] = []
var _alive_count: int = 0

## === 每格位独立行动序列 =========================================================

var _slot_sequences: Array[Array] = []  ## 每个阵位独立的行为序列
var _slot_seq_indices: Array[int] = []  ## 每个阵位当前的序列索引

## === 天劫模式 ==================================================================

var _is_tribulation: bool = false  ## 当前是否为渡劫战


func _ready() -> void:
	for _i in range(6):
		_slots.append({"character_id": "", "current_hp": 0, "max_hp": 0, "attack": 0, "is_alive": false})


## === 部署 ======================================================================

func deploy_random(count: int, player_realm: int = VSRealmData.RealmLevel.QI_REFINING) -> void:
	## 随机部署 count 个敌方角色——按玩家境界缩放属性，每种类型有独立行为序列。
	_realm_level = VSRealmData.RealmLevel.QI_REFINING  ## 敌方始终炼气（切片的敌人不升级）

	_slot_sequences.clear()
	_slot_seq_indices.clear()
	for _i2 in range(6):
		_slot_sequences.append([])
		_slot_seq_indices.append(0)

	var pool := ENEMY_POOL.duplicate()
	pool.shuffle()
	for i in range(mini(count, pool.size())):
		var char_id: String = pool[i]
		var cdata: Dictionary = ENEMY_CHARACTERS[char_id]
		var scaled_hp: int = cdata["max_hp"]
		var scaled_atk: int = cdata["attack"]

		# 如果玩家境界更高，敌人获得微弱缩放（让筑基后战斗不无聊）
		var realm_gap: int = player_realm - _realm_level
		if realm_gap > 0:
			scaled_hp = int(ceil(scaled_hp * (1.0 + realm_gap * 0.3)))
			scaled_atk = int(ceil(scaled_atk * (1.0 + realm_gap * 0.15)))

		_slots[i] = {
			"character_id": char_id,
			"current_hp": scaled_hp,
			"max_hp": scaled_hp,
			"attack": scaled_atk,
			"is_alive": true,
			"type": cdata.get("type", "basic"),
		}
		_alive_count += 1

		# 根据类型分配独立行为序列
		_slot_sequences[i] = _get_sequence_for_type(cdata.get("type", "basic"))
		_slot_seq_indices[i] = 0


func _get_sequence_for_type(etype: String) -> Array[Dictionary]:
	## 根据敌人类型返回对应的行为序列。
	match etype:
		"tank":
			return GUARD_ACTIONS
		"elite":
			return CAPTAIN_ACTIONS
		"cunning":
			return SHAMAN_ACTIONS
		"brute":
			return BRUTE_ACTIONS
		_:
			return SCOUT_ACTIONS


func reset_all() -> void:
	## 清除所有阵位——准备新一波敌人。
	for i in range(6):
		_slots[i] = {"character_id": "", "current_hp": 0, "max_hp": 0, "attack": 0, "is_alive": false, "type": "basic"}
	_alive_count = 0
	_slot_sequences.clear()
	_slot_seq_indices.clear()
	for _i in range(6):
		_slot_sequences.append([])
		_slot_seq_indices.append(0)
	_is_tribulation = false


## === 渡劫战部署 ================================================================

func deploy_tribulation(player_realm: int) -> void:
	## 部署天劫敌人——3 个天劫化身，属性按玩家境界缩放。
	_is_tribulation = true
	_realm_level = player_realm  ## 天劫与玩家同境界——无压制

	_slot_sequences.clear()
	_slot_seq_indices.clear()
	for _i3 in range(6):
		_slot_sequences.append([])
		_slot_seq_indices.append(0)

	var pool := TRIBULATION_POOL.duplicate()
	pool.shuffle()
	for i in range(3):
		var char_id: String = pool[i]
		var cdata: Dictionary = TRIBULATION_ENEMIES[char_id]
		var scaled_hp: int = cdata["max_hp"]
		var scaled_atk: int = cdata["attack"]

		# 天劫强度随境界递增
		if player_realm > VSRealmData.RealmLevel.QI_REFINING:
			var mult: float = 1.0 + (player_realm - 1) * 0.4
			scaled_hp = int(ceil(scaled_hp * mult))
			scaled_atk = int(ceil(scaled_atk * mult))

		_slots[i] = {
			"character_id": char_id,
			"current_hp": scaled_hp,
			"max_hp": scaled_hp,
			"attack": scaled_atk,
			"is_alive": true,
			"type": "tribulation",
		}
		_alive_count += 1

		# 天劫敌人各分配天劫行为序列
		_slot_sequences[i] = TRIB_ACTIONS
		_slot_seq_indices[i] = 0

	# 后排位空置
	for i in range(3, 6):
		_slots[i] = {"character_id": "", "current_hp": 0, "max_hp": 0, "attack": 0, "is_alive": false, "type": "basic"}


func is_tribulation() -> bool:
	return _is_tribulation


## === 查询方法 ==================================================================

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


func get_realm_level() -> int:
	return _realm_level


func get_slot(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= 6:
		return {}
	return _slots[slot_index]


func get_enemy_name(slot_index: int) -> String:
	## 返回敌方角色显示名称。
	if slot_index < 0 or slot_index >= 6:
		return "?"
	var cid: String = _slots[slot_index].get("character_id", "")
	if cid.is_empty():
		return "?"
	# 先查天劫库，再查普通库
	if _is_tribulation and TRIBULATION_ENEMIES.has(cid):
		return TRIBULATION_ENEMIES[cid].get("name", cid)
	var cdata: Dictionary = ENEMY_CHARACTERS.get(cid, {})
	return cdata.get("name", cid)


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


func get_all_alive() -> Array[int]:
	## 返回所有存活敌方阵位的索引——按前排优先。
	var alive: Array[int] = []
	for i in range(3):
		if _slots[i].get("is_alive", false):
			alive.append(i)
	for i in range(3, 6):
		if _slots[i].get("is_alive", false):
			alive.append(i)
	return alive


## === 战斗方法 ==================================================================

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


func get_slot_action(slot_index: int) -> Dictionary:
	## 返回指定阵位的下一个行动——使用该格位独立的行为序列。
	if slot_index < 0 or slot_index >= 6:
		return {"name": "—", "damage": 0}
	if not _slots[slot_index].get("is_alive", false):
		return {"name": "—", "damage": 0}

	var idx: int = _slot_seq_indices[slot_index]
	var seq: Array = _slot_sequences[slot_index]
	if seq.is_empty():
		return {"name": "—", "damage": 0}
	var action: Dictionary = seq[idx % seq.size()]
	_slot_seq_indices[slot_index] = (idx + 1) % seq.size()
	return action
