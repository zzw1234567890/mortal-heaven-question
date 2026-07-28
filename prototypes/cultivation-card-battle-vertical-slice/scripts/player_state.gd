# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: 玩家能否在 4 分钟内无需引导完成「炼气战斗→修为满→渡劫→突破→再战」？
# Date: 2026-07-27
##
## 玩家状态容器 —— 整合境界/费用/修为三系统。
## 生产环境中由 GSM 管理——此处为垂直切片独立持有。
## 费用委托给 VSCostSystem，修为委托给 VSCultivationSystem。

class_name VSPlayerState
extends Node

## 信号 —— snake_case 过去式，遵循 ADR-0007 命名规范

signal hp_changed(old_hp: int, new_hp: int)
signal shield_changed(old_shield: int, new_shield: int)
signal player_died()
signal turn_started(turn_number: int)
signal realm_changed(old_realm: int, new_realm: int, new_name: String)

## === 子系统引用 ================================================================

var cost_system: VSCostSystem
var cultivation_system: VSCultivationSystem

## === 玩家属性（自身 HP——头部玩家） ==============================================

var max_hp: int = 50
var current_hp: int = max_hp
var shield: int = 0

## === 境界 ======================================================================

var realm_level: int = VSRealmData.RealmLevel.QI_REFINING

## === 回合状态 ==================================================================

var turn_number: int = 0


func _init() -> void:
	cost_system = VSCostSystem.new()
	cultivation_system = VSCultivationSystem.new()


func setup() -> void:
	## 初始化费用和修为系统——在节点进入场景树后调用。
	cost_system.init(realm_level)
	cultivation_system.init(realm_level)

	# 转发子系统信号
	cost_system.cost_changed.connect(_on_cost_changed)
	cultivation_system.cultivation_changed.connect(_on_cultivation_changed)
	cultivation_system.cultivation_max_changed.connect(_on_cultivation_max_changed)
	cultivation_system.breakthrough_ready.connect(_on_breakthrough_ready)


## === 伤害/治疗/护盾（玩家自身——保留兼容） =====================================

func is_alive() -> bool:
	return current_hp > 0


func take_damage(amount: int) -> int:
	if amount <= 0:
		return 0

	var actual_damage: int = amount
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


## === 费用委托方法 ==============================================================

## 每回合灵力——委托给 CostSystem。
func can_afford(cost: int) -> bool:
	return cost_system.can_afford(cost)


func spend_mana(amount: int) -> bool:
	return cost_system.spend(amount)


func get_current_mana() -> int:
	return cost_system.get_current_cost()


func get_max_mana() -> int:
	return cost_system.get_max_cost()


## === 回合管理 ==================================================================

func start_turn() -> void:
	turn_number += 1
	cost_system.reset_for_turn()
	turn_started.emit(turn_number)


## === 境界突破 ==================================================================

## 执行境界突破——更新费用上限和修为上限。
## [br]
## [b]返回:[/b] 新境界名称，突破失败返回空字符串。
func attempt_breakthrough() -> String:
	var current_level := realm_level
	var new_level: int = current_level + 1

	# 检查修为是否已满
	if not cultivation_system.is_breakthrough_ready():
		return ""

	# 过渡到新境界
	var _old_name: String = VSRealmData.get_realm_name(current_level)
	var new_name: String = VSRealmData.get_realm_name(new_level)

	if new_name == "未知境界":
		# 已是最高境界（当前切片只到筑基）
		return ""

	realm_level = new_level

	# 消费修为进度→更新子系统
	cultivation_system.consume_progress(cultivation_system.get_max_cultivation())
	cultivation_system.update_realm(new_level)
	cost_system.update_realm(new_level)

	# 结算溢出池
	var _overflow := cultivation_system.settle_overflow()

	realm_changed.emit(current_level, new_level, new_name)
	return new_name


## === 信号转发 ==================================================================

signal cost_changed(old_cost: int, new_cost: int)
signal cultivation_changed(old_amount: int, new_amount: int)
signal cultivation_max_changed(old_max: int, new_max: int)
signal breakthrough_ready()

func _on_cost_changed(old_cost: int, new_cost: int) -> void:
	cost_changed.emit(old_cost, new_cost)

func _on_cultivation_changed(old_amount: int, new_amount: int) -> void:
	cultivation_changed.emit(old_amount, new_amount)

func _on_cultivation_max_changed(old_max: int, new_max: int) -> void:
	cultivation_max_changed.emit(old_max, new_max)

func _on_breakthrough_ready() -> void:
	breakthrough_ready.emit()
