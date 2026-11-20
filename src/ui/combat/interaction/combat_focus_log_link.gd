extends RefCounted
## CombatFocusLogLink —— 战斗日志入口与焦点链之间的连接件（combat-ui-layout Story 004）。
##
## [b]职责[/b]（两件，且只有两件）：[br]
##   1. [b]找入口[/b]：[method nodes] 报出「日志此刻有哪些可聚焦的站」——折叠按钮常驻；
##      面板展开时追加其滚动区；[br]
##   2. [b]订阅开合[/b]：日志的 [code]expand_changed[/code] 直连调用方给的 [Callable]，
##      让链在面板开合的下一拍重建。[br]
## [br][b]为什么单独成文件[/b]：[code]combat_focus_chain.gd[/code] 加上日志站后越过
## 300 行软上限，而「顶栏里那个日志组件怎么找、它的开合怎么订阅」是一块能整体搬走的
## 职责（同 [code]combat_focus_sweeper.gd[/code] / [code]combat_focus_ring.gd[/code]
## 的先例）——链只管「谁上场、焦点落在哪」。[br]
## [br][b]为什么要订阅[/b]：开合只发生在折叠按钮的 [code]pressed[/code] 上
## （[method CombatLog.toggle]），链若不跟着重建，玩家展开日志后按 Tab 会直接跳过
## 刚出现的滚动区；而阶段切换不一定紧跟着发生，链就停在旧环上。[br]
## [br][b]为什么滚动区只在展开时入环[/b]：收起态它在树里但不可见——接进环会让 Tab
## 的下一站指向一个看不见的控件（焦点跳进空面板，玩家以为界面坏了）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：控件引用是渲染节点，开合态现读日志组件；
## [b]零轮询[/b]：无 [code]_process()[/code]，全部由开合信号显式驱动。[br]
## [br][b]桩门面安全[/b]：测试注入的顶部条桩可能没有 [code]combat_log[/code] 属性，
## [method Object.get] 对不存在的属性返回 null（不报错），下面照常降级为空清单。
##
## 来源: ADR-0031 §2、.claude/rules/ui-code.md（双输入）、先例
## [code]combat_focus_sweeper.gd[/code]（链外收拢的独立模块）。

## 焦点环几何（复用「能不能落焦点」判据——不在这里另写一份）。
const Ring: GDScript = preload("res://src/ui/combat/interaction/combat_focus_ring.gd")

## 战场门面（[code]CombatLayout[/code]——经它取顶栏）。
var _layout: Control = null
## 开合变化的接收方（链的 [method CombatFocusChain.rebuild]）。
var _on_changed: Callable = Callable()
## 已订阅开合信号的日志组件（幂等——重复 [method bind] 不重复接）。
var _source: Object = null


## 构造——传入战场门面与开合变化的接收方。
func _init(p_layout: Control, p_on_changed: Callable) -> void:
	_layout = p_layout
	_on_changed = p_on_changed


## 订阅日志开合（幂等：同源已订阅则跳过）。[br]
## [br][b]重复调用防护[/b]：[method Node.is_connected] 先例——[method CombatFocusChain.bind]
## 可能被反复调用（场景重挂），接两次会让一次开合触发两轮重建。
func subscribe() -> void:
	var log: Variant = _log_node()
	if log == null or log == _source:
		return
	if (log as Object).has_signal(&"expand_changed"):
		if not (log as Object).is_connected(&"expand_changed", _on_expand_changed):
			(log as Object).connect(&"expand_changed", _on_expand_changed)
	_source = log


## 退订（场景退场——信号源是常驻场景节点，不摘会在下一场战斗里对着已释放的链开火）。
func unsubscribe() -> void:
	if _source != null and is_instance_valid(_source) \
			and (_source as Object).has_signal(&"expand_changed") \
			and (_source as Object).is_connected(&"expand_changed",
					_on_expand_changed):
		(_source as Object).disconnect(&"expand_changed", _on_expand_changed)
	_source = null


## 日志此刻可聚焦的站（按环序）。[br]
## [br][b]返回[/b]：折叠按钮（常驻——只要它在树里）+ 面板滚动区（仅在展开时）。
func nodes() -> Array:
	var result: Array = []
	var log: Variant = _log_node()
	if log == null or not (log as Object).has_method(&"collapse_button"):
		return result
	var button: Variant = (log as Object).call(&"collapse_button")
	if Ring.inside_tree(button):
		result.append(button)
	var panel: Variant = (log as Object).get(&"expand_panel")
	# 先验存活再判类型：对已释放实例做 `is` 判断会报错并**中断调用**（上一轮实测）。
	if panel == null or not is_instance_valid(panel) or not panel is Control \
			or not (panel as Control).visible:
		return result
	var scroll: Variant = (log as Object).get(&"scroll")
	if Ring.inside_tree(scroll):
		result.append(scroll)
	return result


## 开合信号是否已接上（测试断言接线状态用）。
func is_subscribed() -> bool:
	if _source == null or not is_instance_valid(_source):
		return false
	return (_source as Object).is_connected(&"expand_changed", _on_expand_changed)


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 开合信号 → 接收方（信号带 [code]expanded: bool[/code] 载荷，接收方
## [method CombatFocusChain.rebuild] 不收参数——链不关心展没展，只关心「环变了」，
## 故在这里吞掉载荷，不 [method Callable.bind] 转发）。
func _on_expand_changed(_expanded: bool) -> void:
	if _on_changed.is_valid():
		_on_changed.call()


## 战斗日志组件（顶部条持有——缺顶栏 / 缺组件时为 null）。[br]
## [br][b]为什么按名找而不是记句柄[/b]：顶栏由 [code]CombatTopBar[/code] 自己建日志，
## 本连接件不持它——名字是它钉住的稳定契约（同
## [code]CombatFocusSweeper.OVERLAY_NAMES[/code] 口径）。
func _log_node() -> Variant:
	if _layout == null or not is_instance_valid(_layout):
		return null
	var bar: Variant = _layout.get(&"combat_topbar")
	if bar == null or not is_instance_valid(bar):
		return null
	var log: Variant = (bar as Object).get(&"combat_log")
	return log if log is Object and is_instance_valid(log) else null
