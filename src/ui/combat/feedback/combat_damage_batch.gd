class_name CombatDamageBatch
extends RefCounted
## CombatDamageBatch —— 战斗反馈的「同帧伤害合并 → 结算帧」批处理器（拆分自 feedback 编排器）。[br]
##
## [b]职责[/b]：把同一帧收到的多条伤害/治疗增量按目标合并成一条，并在帧边界
## （[method Callable.call_deferred]）调度一次结算——派发一次「该结算了」，
## 结算体本身由调用方在构造时注入。[br]
## [b]不管什么[/b]：不碰角色卡、不读源系统、不认识飘字，也不裁定结算帧里做什么
## （读终值 / 落 [code]apply_hp[/code] / 起阵亡动画都还在调用方）；
## 它只管「谁欠了一次结算、这一帧派发过没有」。[br]
## [br][b]为什么结算体是注入的[/b]：结算帧要遍历的目标与其卡节点表在调用方手里
## （卡表是编排器的公共入口 [code]register_card[/code] 的记账），搬进来会把卡表
## 一起搬走——那是另一个职责。[br]
## [br][b]瞬态视觉状态[/b]（ADR-0031 §2.1 豁免）：增量表是同一帧内的合并账，
## 结算帧即清空，不构成游戏状态的副本。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]——入队即按帧边界
## [code]call_deferred[/code] 合并派发一次。
##
## 来源: combat-ui-layout Story 003 AC-1（同帧多次伤害合并为每目标一次
## [code]apply_hp[/code]）、combat_feedback_coordinator（拆分——行数预算，
## 编码标准「单文件 ≤300 行」）。

## 待结算增量表——[code]{character_id: {delta: int, pending_death: bool}}[/code]；
## 同帧多次伤害合并（每目标一条），结算帧清空。[br]
## [br][b]借来的引用[/b]：构造时接收调用方的表（GDScript 字典是引用类型）——
## 本件就地记账，调用方照旧能读到同一份；不新建、不换表，否则「编排器摘了账、
## 批处理器还在旧表上累加」这类错位会立刻出现。
var _pending: Dictionary = {}
## 结算帧调度标志（防重复 [code]call_deferred[/code]）。
var _flush_scheduled: bool = false
## 结算帧执行体（调用方注入——形如 [code]func() -> void[/code] 的无参方法）。
var _on_flush: Callable = Callable()


## 构造——注入结算帧执行体与借入调用方的增量表。[br]
## [param p_on_flush]: 结算帧要做什么（调用方的 [code]_flush_deltas[/code]）。[br]
## [param p_pending]: 待结算增量表（同一份字典引用——调用方保留读窗口）。[br]
## [br][b]必填[/b]：没有执行体的批处理器不会派发任何东西（不假装成功——
## 生产路径由编排器在 [code]_init[/code] 里必定注入）。
func _init(p_on_flush: Callable, p_pending: Dictionary) -> void:
	_on_flush = p_on_flush
	_pending = p_pending


## 入队一条增量（同帧同目标合并；致死位只置不清）。[br]
## [br][b]增量可为负[/b]：治疗语义是负 [code]delta[/code]（种类由调用方按符号判）；
## 本件只做代数和，合并后的终值由结算帧从源系统现读。[br]
## [br][b]不判零不入队[/b]：零增量与非法目标由调用方拦在门外（本件不做业务判据）。
func enqueue(target_id: int, delta: int, is_kill: bool) -> void:
	var entry: Dictionary = _pending.get_or_add(target_id,
		{"delta": 0, "pending_death": false})
	entry["delta"] = int(entry["delta"]) + delta
	if is_kill:
		entry["pending_death"] = true
	_pending[target_id] = entry
	_schedule()


## 待结算增量表（调用方的只读别名 / 测试探针）。
func pending() -> Dictionary:
	return _pending


## 结算帧开场——复位调度位，并回报本帧待处理的角色清单。[br]
## [br][b]复位的是调度位、不是表[/b]：清表归 [method clear]（在派发体跑完之后）——
## 顺序与拆分前逐位一致，处理途中新入队的增量仍留到下一帧，不被本帧顺手清掉。
func begin_flush() -> Array:
	_flush_scheduled = false
	return _pending.keys()


## 单条增量（[method begin_flush] 回报的键——结算帧逐目标取用）。
func entry_of(character_id: int) -> Dictionary:
	return _pending[character_id]


## 结算帧收尾——清空增量表。
func clear() -> void:
	_pending.clear()


## 全灭短路——清空增量表并复位调度位（在飞的结算帧随后自然空转）。[br]
## [br][b]为什么两件一起做[/b]：战斗已结束，欠着的账不必再算（清表），
## 而调度位不复位会让下一场战斗的第一次入队不再派发。
func cancel() -> void:
	_pending.clear()
	_flush_scheduled = false


## 摘掉单个目标的待结算增量（战斗结束清理——防悬空引用）。[br]
## [br][b]只管增量[/b]：卡表与阵亡 Tween 表各有各的清理路径（三层清理分工，
## 见编排器的 [code]_finish_death[/code]）——这里不越界代劳。
func forget(character_id: int) -> void:
	_pending.erase(character_id)


## 是否已有结算帧在飞（测试探针）。
func is_scheduled() -> bool:
	return _flush_scheduled


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 结算帧调度——同帧多次入队仅调度一次（[code]call_deferred[/code] 合并）。
func _schedule() -> void:
	if _flush_scheduled:
		return
	_flush_scheduled = true
	_on_flush.call_deferred()
