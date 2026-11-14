extends RefCounted
## CombatStatBonus —— 战斗内属性增益的运行时存储（战斗内直用法宝的落点）。[br]
## [br][b]为什么与 [CombatDebuffManager] 分开而不是合并[/b]：那个模块的公开契约
## （[code]apply[/code] / [code]get_atk_with_debuff[/code] / [code]on_turn_end[/code]）
## 已被 debuff 集成测试逐条锁定，且它的语义是「降低」——[code]apply[/code] 对
## [code]amount <= 0[/code] 直接拒绝。把增益塞进去，要么改那条判据（既有测试红），
## 要么让正负号承担两种含义（调用方再也说不清「-3」是降 3 还是加 -3）。两条都是把
## 一个已经稳定的模块拖进不确定态——故对称地另起一个小模块，读侧在
## [CombatRosterState] 叠加。[br]
## [br][b]不随回合递减[/b]（本模块不提供 [code]on_turn_end[/code]）：战斗内直用法宝
## 的口径是「本场有效」——它是消耗掉一次性的实物换来的，若按回合过期，玩家在
## 回合末用掉的法宝会当场归零。需要按回合计时的增益是另一套模型
## （[code]StatusEffectSystem[/code]），不在本轮的裁定范围内。[br]
## [br][b]零状态所有权边界[/b]：本模块只持修正值，不读 HP、不判存活、不写存档；
## 「谁能被加」由结算层裁定（见 [code]combat_bag_use.gd[/code]）。[br]
##
## 来源: GDD card-system.md §卡牌类型（法宝）、GDD combat-system.md §2（战斗内属性）、
## 先例 [code]combat_debuff_manager.gd[/code]。

## 属性键——与 [code]EffectEvaluation.stat_changes[/code] 同口径（大写，单一真理来源）。
const STAT_ATK: String = "ATK"
const STAT_DEF: String = "DEF"

## 状态表——[code]{character_id: {stat: total}}[/code]（同角色同属性累加）。
var _bonuses: Dictionary = {}


## 清空全部增益——开战重种子与战斗结束共用。
func clear() -> void:
	_bonuses.clear()


## 施加一次增益。[br]
## [br][param p_amount] 增益点数——[code]<= 0[/code] 视为无效不记录（不臆造零增益条目，
## 否则 [method has_any] 会把「什么都没加」报成有增益）。[br]
## [b]返回[/b]：是否真的记了一笔。
func apply(p_target_id: int, p_stat: String, p_amount: int) -> bool:
	if p_target_id < 0 or p_amount <= 0:
		return false
	if not _bonuses.has(p_target_id):
		_bonuses[p_target_id] = {}
	var row: Dictionary = _bonuses[p_target_id]
	row[p_stat] = int(row.get(p_stat, 0)) + p_amount
	return true


## 读某角色某属性的增益总量（无记录返回 0）。
func get_bonus(p_target_id: int, p_stat: String) -> int:
	if not _bonuses.has(p_target_id):
		return 0
	return int((_bonuses[p_target_id] as Dictionary).get(p_stat, 0))


## 该角色是否吃到过任何增益（测试断言 / UI 展示用）。
func has_any(p_target_id: int) -> bool:
	return not (_bonuses.get(p_target_id, {}) as Dictionary).is_empty()


## 全表快照（调试与断言用——深拷贝，调用方改不到内部状态）。
func snapshot() -> Dictionary:
	return _bonuses.duplicate(true)
