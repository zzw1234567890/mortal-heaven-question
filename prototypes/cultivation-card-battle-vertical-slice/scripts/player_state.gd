# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: 玩家能否在 3 分钟内完成一场卡牌战斗——打出卡牌、
#   看到效果结算并击败敌人——且架构遵循 Foundation 层设计？
# Date: 2026-07-27
##
## 玩家状态容器。生产环境中由 GSM 管理——此处为垂直切片独立持有。
## 暴露信号供 HUD 订阅，遵循 ADR-0007 信号驱动通信模式。

class_name VSPlayerState
extends Node

## 信号 —— snake_case 过去式，遵循 ADR-0007 命名规范

signal hp_changed(old_hp: int, new_hp: int)
signal mana_changed(old_mana: int, new_mana: int)
signal shield_changed(old_shield: int, new_shield: int)
signal player_died()
signal turn_started(turn_number: int)

## 玩家属性

var max_hp: int = 50
var current_hp: int = max_hp
var max_mana: int = 5
var current_mana: int = 3
var shield: int = 0
var realm_level: int = 1  ## 炼气期

## 回合状态

var turn_number: int = 0
var mana_per_turn: int = 3  ## 每回合恢复灵力


func is_alive() -> bool:
	return current_hp > 0


func take_damage(amount: int) -> int:
	## 返回实际造成的伤害值
	if amount <= 0:
		return 0

	var actual_damage: int = amount

	# 护盾先吸收
	if shield > 0:
		if shield >= actual_damage:
			var old_shield := shield
			shield -= actual_damage
			shield_changed.emit(old_shield, shield)
			return 0
		else:
			actual_damage -= shield
			var old_shield := shield
			shield = 0
			shield_changed.emit(old_shield, 0)

	var old_hp := current_hp
	current_hp = maxi(0, current_hp - actual_damage)
	hp_changed.emit(old_hp, current_hp)

	if current_hp <= 0:
		player_died.emit()

	return actual_damage


func heal(amount: int) -> void:
	if amount <= 0:
		return
	var old_hp := current_hp
	current_hp = mini(max_hp, current_hp + amount)
	hp_changed.emit(old_hp, current_hp)


func add_shield(amount: int) -> void:
	if amount <= 0:
		return
	var old_shield := shield
	shield += amount
	shield_changed.emit(old_shield, shield)


func can_afford(cost: int) -> bool:
	return current_mana >= cost


func spend_mana(amount: int) -> bool:
	if amount <= 0 or amount > current_mana:
		return false
	var old_mana := current_mana
	current_mana -= amount
	mana_changed.emit(old_mana, current_mana)
	return true


func start_turn() -> void:
	turn_number += 1
	var old_mana := current_mana
	current_mana = mini(max_mana, current_mana + mana_per_turn)
	mana_changed.emit(old_mana, current_mana)
	turn_started.emit(turn_number)
