class_name SettlementHostSignals
extends RefCounted
## SettlementHostSignals —— 结算宿主对战斗系统的信号接线（拆分自 settlement_host）。[br]
##
## [b]职责[/b]：把宿主的两个入口接到战斗系统上——[signal CombatSystem.battle_ended]
## （→ 开结算/战败面板）与 [signal CombatSystem.retreat_requested]（→ 开撤退确认），
## 并保证三件事：[br]
##   1. [b]幂等[/b]：重复 [method bind] 同一源不重复连（接两次会让一次战斗开两次面板）；[br]
##   2. [b]可换源[/b]：换到另一个战斗系统时先断开旧源，再连新源；[br]
##   3. [b]可断开[/b]：[method release] 只断本宿主连过的两个信号，不碰同一信号上的
##      其他连接者（战斗系统是共享信号源，别人也连着）。[br]
## [b]不管什么[/b]：不判定胜负、不开面板、不组装文案——两个点击入口都是调用方
## 注入的 [Callable]。[br]
## [br][b]为什么单独成文件[/b]：这一块有独立状态（[member _bound]）与独立的失败
## 模式（重复连 / 换源漏断），且是宿主里唯一需要跨对象生命周期收尾的一块
## （[code]NOTIFICATION_PREDELETE[/code]）——[code]settlement_host.gd[/code] 挤在
## 一起时超出 300 行软上限（编码标准）。[br]
## [br][b]为什么保留 [member _bound] 而不是问源自己[/b]：同一个战斗系统上可能还挂着
## 别人的连接，「谁连的」只有本件知道——换源时要断的是自己的那两个。
##
## 来源: combat-ui-layout Story 008（AC-2/AC-9）、拆分自 settlement_host（行数预算）。

## 战斗系统（battle_ended / retreat_requested 信号源——未注入为 null）。
var _source: Node = null
## 已接线信号源的战斗系统（换源时先断开旧源——防一次战斗开两次面板）。
var _bound: Node = null
## 战斗结束入口（宿主的 [code]on_battle_ended[/code]）。
var _on_battle_ended: Callable = Callable()
## 撤退请求入口（宿主的 [code]on_retreat_requested[/code]）。
var _on_retreat_requested: Callable = Callable()


## 构造——注入两个入口（宿主在 [method Node._ready] 里建，指向自己的方法）。
func _init(p_on_battle_ended: Callable, p_on_retreat_requested: Callable) -> void:
	_on_battle_ended = p_on_battle_ended
	_on_retreat_requested = p_on_retreat_requested


## 接线到战斗系统（幂等——重复 [method bind] 同一源不重复连；换源时先断旧源）。[br]
## [param p_source] 为 null 时只做换源收尾（把旧源断干净，不连新的）。
func bind(p_source: Node) -> void:
	_source = p_source
	var cs: Node = p_source
	if _bound != null and _bound != cs:
		_disconnect(_bound)
	_bound = cs
	if cs == null:
		return
	if cs.has_signal(&"battle_ended") \
			and not cs.battle_ended.is_connected(_on_battle_ended):
		cs.battle_ended.connect(_on_battle_ended)
	if cs.has_signal(&"retreat_requested") \
			and not cs.retreat_requested.is_connected(_on_retreat_requested):
		cs.retreat_requested.connect(_on_retreat_requested)


## 断开当前信号源（销毁 / 退场时调用——只断本件连过的两个信号）。[br]
## [br][b]幂等[/b]：没接过或已断开时是空操作（[code]PREDELETE[/code] 与显式退场
## 可能都走一趟）。
func release() -> void:
	if _bound != null and is_instance_valid(_bound):
		_disconnect(_bound)
	_bound = null
	_source = null


## 当前战斗系统（未注入 / 已释放为 null——测试探针）。
func source() -> Node:
	return _source


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 断开给定源上与宿主有关的两个连接（逐信号问 [method Signal.is_connected]，
## 别人的连接原样不动）。
func _disconnect(source: Node) -> void:
	if source == null or not is_instance_valid(source):
		return
	if source.has_signal(&"battle_ended") \
			and source.battle_ended.is_connected(_on_battle_ended):
		source.battle_ended.disconnect(_on_battle_ended)
	if source.has_signal(&"retreat_requested") \
			and source.retreat_requested.is_connected(_on_retreat_requested):
		source.retreat_requested.disconnect(_on_retreat_requested)
