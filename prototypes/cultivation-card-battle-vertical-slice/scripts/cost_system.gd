# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: 玩家能否在 4 分钟内无需引导完成「炼气战斗→修为满→渡劫→突破→再战」？
# Date: 2026-07-27
##
## 费用系统 —— 管理每回合灵力（费用）的获取、消费与恢复。
## 生产环境中由 CostSystem Autoload #7（ADR-0015）管理。
## 遵循 can_afford() → spend() → reset_for_turn() 三方法核心 API。

class_name VSCostSystem
extends RefCounted

## === 信号（生产环境中挂在 CostSystem Autoload 上——此处简化为回调） =============

signal cost_changed(old_cost: int, new_cost: int)

## === 内部状态 ==================================================================

var _current_cost: int = 0
var _max_cost: int = 0
var _temp_bonus: int = 0       ## 临时费用加成（本回合有效）
var _temp_bonus_stack: Array[int] = []


## === 初始化 ====================================================================

## 按境界设置费用上限并重置为满值。
func init(realm_level: int) -> void:
	_max_cost = VSRealmData.get_realm_property(realm_level, "cost_per_turn")
	_current_cost = _max_cost
	_temp_bonus = 0


## 根据新旧境界更新费用上限（境界突破时调用）。
## 保留当前费用值（如果新上限更高，差额需要等到下回合回复）。
func update_realm(new_level: int) -> void:
	var _old_max: int = _max_cost
	_max_cost = VSRealmData.get_realm_property(new_level, "cost_per_turn")
	# 上限提升了，当前费用不变——下回合才恢复


## === 核心 API ==================================================================

## O(1) 整数比较——检查当前灵力是否足以支付。
func can_afford(cost: int) -> bool:
	return _current_cost >= cost


## 消费灵力。返回 true 表示成功扣减，false 表示余额不足。
func spend(amount: int) -> bool:
	if amount <= 0:
		return true
	if not can_afford(amount):
		return false

	var old_cost := _current_cost
	_current_cost -= amount
	cost_changed.emit(old_cost, _current_cost)
	return true


## 每回合开始时调用——全额恢复到当前境界上限 + 临时加成。
func reset_for_turn() -> void:
	var old_cost := _current_cost
	_temp_bonus = 0
	for bonus in _temp_bonus_stack:
		_temp_bonus += bonus
	_current_cost = _max_cost + _temp_bonus
	cost_changed.emit(old_cost, _current_cost)


## 清除所有临时加成（回合结束时调用）。
func clear_temp_bonuses() -> void:
	_temp_bonus = 0
	_temp_bonus_stack.clear()


## 添加临时费用加成（丹药效果等）。
func add_temp_bonus(amount: int) -> void:
	if amount <= 0:
		return
	_temp_bonus_stack.append(amount)


## === 查询方法 ==================================================================

func get_current_cost() -> int:
	return _current_cost


func get_max_cost() -> int:
	return _max_cost


func get_temp_bonus() -> int:
	return _temp_bonus
