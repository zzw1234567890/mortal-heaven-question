# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: 玩家能否在 3 分钟内完成一场卡牌战斗——打出卡牌、
#   看到效果结算并击败敌人——且架构遵循 Foundation 层设计？
# Date: 2026-07-27
##
## 角色状态管理——管理 6 个阵位的角色（前排 3 + 后排 3）。
## 生产环境中由 DeploymentSystem（ADR-0016）管理。

class_name VSDeploymentState
extends Node

signal character_deployed(slot_index: int, character_id: String)
signal character_removed(slot_index: int)
signal character_died(slot_index: int)
signal character_hp_changed(slot_index: int, old_hp: int, new_hp: int)
signal character_shield_changed(slot_index: int, old_shield: int, new_shield: int)
signal card_bound(slot_index: int, card_id: String)           ## 卡牌绑定到角色
signal card_unbound(slot_index: int, card_id: String)         ## 卡牌从角色解绑
signal bound_effect_triggered(slot_index: int, card_id: String, subtype: String, value: int)  ## 绑定效果触发

const MAX_SLOTS: int = 6
const FRONT_ROW: Array[int] = [0, 1, 2]  ## 前排阵位
const BACK_ROW: Array[int] = [3, 4, 5]   ## 后排阵位
const MAX_BOUND_CARDS: int = 2            ## 每角色最多绑定 2 张卡

## 阵位状态：每个阵位存储角色实例数据
var _slots: Array[Dictionary] = []


func _ready() -> void:
	# 初始化 6 个空阵位
	for i in range(MAX_SLOTS):
		_slots.append({
			"character_id": "",
			"current_hp": 0,
			"max_hp": 0,
			"attack": 0,
			"shield": 0,
			"is_alive": false,
			"bound_cards": [],  ## 绑定的卡牌 [{card_id, subtype, value, bind_text}]
		})


func deploy_character(slot_index: int, character_id: String, max_hp: int, attack: int) -> bool:
	## 将角色部署到指定阵位
	if slot_index < 0 or slot_index >= MAX_SLOTS:
		return false

	if _slots[slot_index].get("is_alive", false):
		return false  ## 阵位已被占用

	_slots[slot_index] = {
		"character_id": character_id,
		"current_hp": max_hp,
		"max_hp": max_hp,
		"attack": attack,
		"shield": 0,
		"is_alive": true,
		"bound_cards": [],
	}

	character_deployed.emit(slot_index, character_id)
	return true


func remove_character(slot_index: int) -> void:
	## 移除阵位上的角色
	if slot_index < 0 or slot_index >= MAX_SLOTS:
		return

	_slots[slot_index] = {
		"character_id": "",
		"current_hp": 0,
		"max_hp": 0,
		"attack": 0,
		"shield": 0,
		"is_alive": false,
		"bound_cards": [],
	}

	character_removed.emit(slot_index)


func damage_character(slot_index: int, damage: int) -> int:
	## 对指定阵位的角色造成伤害，返回实际伤害值
	## 护盾先吸收伤害
	if slot_index < 0 or slot_index >= MAX_SLOTS:
		return 0

	if not _slots[slot_index].get("is_alive", false):
		return 0

	var old_shield: int = _slots[slot_index].get("shield", 0)
	var remaining_damage: int = damage

	# 护盾先吸收
	if old_shield > 0:
		if old_shield >= remaining_damage:
			# 护盾完全吸收
			_slots[slot_index]["shield"] = old_shield - remaining_damage
			character_shield_changed.emit(slot_index, old_shield, _slots[slot_index]["shield"])
			return 0
		else:
			# 护盾部分吸收
			remaining_damage -= old_shield
			_slots[slot_index]["shield"] = 0
			character_shield_changed.emit(slot_index, old_shield, 0)

	# 剩余伤害扣 HP
	var old_hp: int = _slots[slot_index].get("current_hp", 0)
	var new_hp: int = maxi(0, old_hp - remaining_damage)
	_slots[slot_index]["current_hp"] = new_hp

	character_hp_changed.emit(slot_index, old_hp, new_hp)

	if new_hp <= 0:
		_slots[slot_index]["is_alive"] = false
		character_died.emit(slot_index)

	return damage


func heal_character(slot_index: int, amount: int) -> void:
	## 治疗指定阵位的角色
	if slot_index < 0 or slot_index >= MAX_SLOTS:
		return

	if not _slots[slot_index].get("is_alive", false):
		return

	var old_hp: int = _slots[slot_index].get("current_hp", 0)
	var max_hp: int = _slots[slot_index].get("max_hp", 0)
	var new_hp: int = mini(max_hp, old_hp + amount)
	_slots[slot_index]["current_hp"] = new_hp

	character_hp_changed.emit(slot_index, old_hp, new_hp)


func add_shield(slot_index: int, amount: int) -> void:
	## 为指定阵位的角色添加护盾
	if slot_index < 0 or slot_index >= MAX_SLOTS:
		return

	if not _slots[slot_index].get("is_alive", false):
		return

	var old_shield: int = _slots[slot_index].get("shield", 0)
	var new_shield: int = old_shield + amount
	_slots[slot_index]["shield"] = new_shield

	character_shield_changed.emit(slot_index, old_shield, new_shield)


func get_character(slot_index: int) -> Dictionary:
	## 获取指定阵位的角色数据
	if slot_index < 0 or slot_index >= MAX_SLOTS:
		return {}
	return _slots[slot_index]


func get_alive_characters() -> Array[int]:
	## 返回所有存活角色的阵位索引
	var alive: Array[int] = []
	for i in range(MAX_SLOTS):
		if _slots[i].get("is_alive", false):
			alive.append(i)
	return alive


func get_front_row_alive() -> Array[int]:
	## 返回前排存活角色的阵位索引
	var alive: Array[int] = []
	for i in FRONT_ROW:
		if _slots[i].get("is_alive", false):
			alive.append(i)
	return alive


func get_back_row_alive() -> Array[int]:
	## 返回后排存活角色的阵位索引
	var alive: Array[int] = []
	for i in BACK_ROW:
		if _slots[i].get("is_alive", false):
			alive.append(i)
	return alive


func is_all_dead() -> bool:
	## 检查是否所有角色都已死亡
	return get_alive_characters().is_empty()


func get_total_attack() -> int:
	## 获取所有存活角色的总攻击力
	var total: int = 0
	for i in get_alive_characters():
		total += _slots[i].get("attack", 0)
	return total


func get_character_name(slot_index: int) -> String:
	## 返回指定角色的显示名称（中文）。
	if slot_index < 0 or slot_index >= MAX_SLOTS:
		return "?"
	var cid: String = _slots[slot_index].get("character_id", "")
	if cid.is_empty():
		return "?"
	return VSCharacterData.CHARACTERS.get(cid, {}).get("name", "?")


func get_alive_count() -> int:
	## 获取存活角色数量
	return get_alive_characters().size()


func get_total_count() -> int:
	## 获取总角色数量（已部署的）
	var count: int = 0
	for i in range(MAX_SLOTS):
		if _slots[i].get("character_id", "") != "":
			count += 1
	return count


## === 绑定卡牌系统 =============================================================

func bind_card(slot_index: int, card_def: Dictionary) -> bool:
	## 将绑定类卡牌绑定到指定阵位角色——超过 MAX_BOUND_CARDS 上限则失败。
	if slot_index < 0 or slot_index >= MAX_SLOTS:
		return false
	if not _slots[slot_index].get("is_alive", false):
		return false

	var bound: Array = _slots[slot_index].get("bound_cards", [])
	if bound.size() >= MAX_BOUND_CARDS:
		return false

	# 存储绑定信息子集
	var bind_entry: Dictionary = {
		"card_id": card_def.get("id", card_def.get("name", "")),
		"subtype": card_def.get("subtype", ""),
		"value": card_def.get("value", 0),
		"bind_text": card_def.get("bind_text", ""),
	}
	bound.append(bind_entry)
	_slots[slot_index]["bound_cards"] = bound

	card_bound.emit(slot_index, bind_entry["card_id"])
	return true


func unbind_card(slot_index: int, card_id: String) -> bool:
	## 从角色阵位解绑指定卡牌。
	if slot_index < 0 or slot_index >= MAX_SLOTS:
		return false
	var bound: Array = _slots[slot_index].get("bound_cards", [])
	for i in range(bound.size()):
		if bound[i].get("card_id", "") == card_id:
			bound.remove_at(i)
			_slots[slot_index]["bound_cards"] = bound
			card_unbound.emit(slot_index, card_id)
			return true
	return false


func get_bound_cards(slot_index: int) -> Array:
	## 返回角色的所有绑定卡牌。
	if slot_index < 0 or slot_index >= MAX_SLOTS:
		return []
	return _slots[slot_index].get("bound_cards", []).duplicate()


func trigger_bound_effects(slot_index: int) -> void:
	## 触发该角色所有绑定卡的效果——每回合开始调用。
	## 返回触发的效果列表 [{card_id, subtype, value}], 由 battle_controller 路由执行。
	if slot_index < 0 or slot_index >= MAX_SLOTS:
		return
	if not _slots[slot_index].get("is_alive", false):
		return

	var bound: Array = _slots[slot_index].get("bound_cards", [])
	for entry in bound:
		var cid: String = entry.get("card_id", "")
		var st: String = entry.get("subtype", "")
		var val: int = entry.get("value", 0)
		# 先发信号让外部（battle_controller）执行实际效果
		bound_effect_triggered.emit(slot_index, cid, st, val)


func clear_bound_cards(slot_index: int) -> void:
	## 清空指定阵位的所有绑定卡牌（新战斗开始时调用）。
	if slot_index < 0 or slot_index >= MAX_SLOTS:
		return
	for entry in _slots[slot_index].get("bound_cards", []).duplicate():
		var cid: String = entry.get("card_id", "")
		card_unbound.emit(slot_index, cid)
	_slots[slot_index]["bound_cards"] = []
