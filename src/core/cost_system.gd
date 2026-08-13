extends Node
# class_name CostSystem —— 不声明：Autoload 全局单例
# （控制清单 2026-08-05 规则，同 GSM/ResourceSystem/FactionSystem/CardSystem 先例）。

## CostSystem —— 费用系统 Autoload（Core 层 #7）。[br]
## 内部管理费用状态（_current_cost、_max_cost、_temp_bonus、_temp_bonus_stack），[br]
## 提供 O(1) 查询 API（can_afford 热路径）和变异 API（spend/reset_for_turn 等）。[br]
## 战斗热路径中 CardEffectEngine/CombatUI 通过直接调用查询费用，[br]
## CombatSystem 通过直接调用驱动费用生命周期。[br]
## [br][b]Autoload 顺序[/b]：GSM #1 → ... → CardSystem #6 → CostSystem #7 → StatusEffectSystem #8。[br]
## [br]来源: ADR-0015。

## 费用状态枚举——用于 UI 状态机切换显示样式。
enum CostState {
	FULL = 0,        ## 满费：_current_cost == _max_cost
	PARTIAL = 1,     ## 部分消耗：0 < _current_cost < _max_cost
	EMPTY = 2,       ## 空费：_current_cost == 0
	OVERLIMIT = 3,   ## 超限：_current_cost > _max_cost（临时丹药加成）
}


# === 信号（Cat 2b 系统信号）===================================================

## 费用变更后发射——CombatUI 监听以刷新费用栏。[br]
## [br][param current] 当前可用费用。[br]
## [br][param max_show] 境界上限（不含临时加成）。[br]
## [br][param total_max] 境界上限 + 临时加成。
signal cost_changed(current: int, max_show: int, total_max: int)


# === 内部状态 =================================================================

## 当前可用费用（含临时加成）。
var _current_cost: int = 0

## 境界费用上限（不含临时加成）——战斗初始化时缓存，战中不变。
var _max_cost: int = 0

## 临时费用加成总额——回合结束 reset_for_turn() 时清零。
var _temp_bonus: int = 0

## 临时加成来源追踪栈。[br]
## 格式：[{source_id: String, amount: int}, ...]
var _temp_bonus_stack: Array[Dictionary] = []

## 战斗活跃标志——非活跃时变异 API 拒绝写入。
var _is_active: bool = false


# === 内置虚方法 ===============================================================

func _ready() -> void:
	# 战斗准备在 init_for_battle() 中执行（由 CombatSystem 调用，此时所有 Autoload 已就绪）。
	# _ready() 为空——CostSystem（#7）在 RealmSystem（#11）之前初始化，
	# 战斗开始前不具备查询 RealmSystem 的能力，费用上限由 CombatSystem 在 battle_start() 中传入。
	pass


# === 查询 API（热路径——O(1) 整数比较/运算）=====================================

## 返回当前可用费用（含临时加成）。
func get_current_cost() -> int:
	return _current_cost


## 返回境界上限（不含临时加成）。
func get_max_cost() -> int:
	return _max_cost


## 返回总上限（境界上限 + 临时加成）。
func get_total_max() -> int:
	return _max_cost + _temp_bonus


## 检查是否可支付指定费用——O(1) 整数比较。[br]
## [br]热路径：CombatUI 每帧对每张手牌调用、CardEffectEngine 效果校验调用、AI 决策遍历。[br]
## [br][b]0 费卡牌始终可用[/b]：[param cost] <= 0 时始终返回 true。[br]
## [br][param cost] 待支付的费用。[br]
## [br][b]返回[/b]: 当前可用费用 >= cost 时为 true。
func can_afford(cost: int) -> bool:
	if cost <= 0:
		return true  # 0 费卡牌始终可用
	return _current_cost >= cost


## 返回当前费用状态——用于 UI 状态机切换显示样式。[br]
## [br][b]判定顺序[/b]：OVERLIMIT 优先于其他判定（_current_cost > _max_cost 首检查）。[br]
## [br][b]返回[/b]: [enum CostState] 枚举值。
func get_cost_state() -> CostState:
	if _current_cost > _max_cost:
		return CostState.OVERLIMIT
	if _current_cost == _max_cost:
		return CostState.FULL
	if _current_cost == 0:
		return CostState.EMPTY
	return CostState.PARTIAL


## 是否处于超限状态（临时丹药突破境界上限）。
func is_overlimit() -> bool:
	return _current_cost > _max_cost


# === 变异 API（由 CombatSystem 编排器直接调用）=================================

## 战斗初始化——由 CombatSystem.battle_start() 调用。[br]
## [br][b]防御性下限[/b]：[param max_cost] 通过 [method @GlobalScope.maxi](cost, 1) 确保至少 1 费。[br]
## [br]内部锁定 [member _max_cost]——战斗期间境界突破不改变当前战斗的费用上限。[br]
## [br][param max_cost] 从 RealmSystem.get_realm_property(player_realm, &"cost_per_turn") 查询传入。
func init_for_battle(max_cost: int) -> void:
	_max_cost = maxi(max_cost, 1)  # 防御：至少 1 费
	_current_cost = _max_cost
	_temp_bonus = 0
	_temp_bonus_stack.clear()
	_is_active = true
	_write_cost_to_gsm()
	cost_changed.emit(_current_cost, _max_cost, _max_cost + _temp_bonus)


## 扣除费用——由 CombatSystem.play_card() 调用。[br]
## [br][b]非活跃战斗[/b]：push_warning 并返回 false。[br]
## [br][b]amount <= 0[/b]：视为空操作，返回 true（与 can_afford 语义一致）。[br]
## [br][b]费用不足[/b]：push_warning 并返回 false——[_current_cost] 不变。[br]
## [br][b]扣费成功[/b]：发射 [signal cost_changed] + 写入 GSM。[br]
## [br][param amount] 扣除数量。[br]
## [br][b]返回[/b]: 扣费成功 true；非活跃/费用不足 false。
func spend(amount: int) -> bool:
	if not _is_active:
		push_warning("CostSystem: spend() called outside active battle")
		return false
	if amount <= 0:
		return true
	if _current_cost < amount:
		push_warning("CostSystem: spend(%d) failed——current_cost=%d" % [amount, _current_cost])
		return false
	_current_cost -= amount
	_write_cost_to_gsm()
	cost_changed.emit(_current_cost, _max_cost, _max_cost + _temp_bonus)
	return true


## 回合重置——由 CombatSystem Phase 6 END 调用。[br]
## [br][b]先手[/b]（is_first_player=true）：全额恢复至 _max_cost，清除临时加成。[br]
## [br][b]后手第 1 回合[/b]（is_first_player=false, is_first_turn=true）：全额恢复 + 额外 +1 费。[br]
## [br][b]后手第 2+ 回合[/b]（is_first_player=false, is_first_turn=false）：无额外 +1。[br]
## [br]后手额外 +1 不计入 _temp_bonus——回合级调整非丹药临时加成，下回合重置自然回归。[br]
## [br][param is_first_player] 是否为先手玩家。[br]
## [br][param is_first_turn] 是否为第 1 回合。
func reset_for_turn(is_first_player: bool, is_first_turn: bool) -> void:
	if not _is_active:
		return

	# 清除所有临时费用加成（回合结束自动过期——不累积）
	_temp_bonus = 0
	_temp_bonus_stack.clear()

	# 全额恢复至境界上限
	_current_cost = _max_cost

	# 后手第 1 回合额外 +1 费（GDD §2 费用恢复规则）
	if not is_first_player and is_first_turn:
		_current_cost += 1
		# 此额外 +1 不属于 temp_bonus——下回合重置时自然回归标准 _max_cost

	_write_cost_to_gsm()
	cost_changed.emit(_current_cost, _max_cost, _max_cost + _temp_bonus)


## 添加临时费用加成——由 CardEffectEngine 结算丹药效果时调用。[br]
## [br][b]可突破境界上限[/b]：同时修正 _temp_bonus 和 _current_cost——_current_cost 可超过 _max_cost。[br]
## [br][b]非活跃战斗[/b]：push_warning 并 return。[br]
## [br][b]amount <= 0[/b]：忽略（直接 return）。[br]
## [br]多丹药叠加——_temp_bonus 累加，_temp_bonus_stack 压入条目。[br]
## [br][param amount] 加成金额（低级+1/中级+2/高级+3）。[br]
## [br][param source_id] 丹药卡牌实例 ID——用于追踪来源，便于调试和 UI tooltip 显示。
func add_temp_bonus(amount: int, source_id: String) -> void:
	if not _is_active:
		push_warning("CostSystem: add_temp_bonus() called outside active battle")
		return
	if amount <= 0:
		return

	_temp_bonus += amount
	_current_cost += amount  # 临时加成同时增加可用费用
	_temp_bonus_stack.append({"source_id": source_id, "amount": amount})

	_write_cost_to_gsm()
	cost_changed.emit(_current_cost, _max_cost, _max_cost + _temp_bonus)


## 战斗结束时清理——由 CombatSystem.battle_end() 调用。[br]
## [br]全部状态归零 + _is_active = false——清理后再调用任何变异 API 应被拒绝。
func clear_for_battle_end() -> void:
	_current_cost = 0
	_max_cost = 0
	_temp_bonus = 0
	_temp_bonus_stack.clear()
	_is_active = false


# === GSM 写入委托（内部方法）==================================================

## 将当前费用状态写入 GSM battle.* 域。[br]
## [br]这是从 CombatSystem 委托的窄范围 GSM 写入权——[br]
## CostSystem 是 battle.current_cost / battle.max_cost 的专业写入者。[br]
## [br][b]双守卫模式[/b]：[br]
##   1. [method @GDScript.is_instance_valid](GameStateManager) —— GSM 不可用时静默跳过。[br]
##   2. [method Object.has_method](&"_set_battle_cost") —— 方法未实现时静默跳过（本 Story 桩模式）。[br]
## [br]Story 002 将在 GSM 中实现 _set_battle_cost 第二层方法。
func _write_cost_to_gsm() -> void:
	if not is_instance_valid(GameStateManager):
		return
	if GameStateManager.has_method(&"_set_battle_cost"):
		GameStateManager._set_battle_cost(_current_cost, _max_cost + _temp_bonus)
