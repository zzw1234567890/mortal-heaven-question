class_name CombatFocusSweeper
extends RefCounted
## CombatFocusSweeper —— 把「焦点链之外」的可聚焦控件收出焦点（CombatFocusChain 的收尾一半）。[br]
## [br][b]职责[/b]：链只管自己那一串（手牌 → 行囊 → 结束出牌 → 撤退），但引擎的
## Tab 派发在链走到头时[b]不会停下[/b]——它会退回几何自推，把焦点交给链外的控件。
## 实测（探针 [code]tools/probe_combat_focusable.gd[/code]）战场里链外可见可聚焦者
## 只有顶部条的[b]战斗日志折叠按钮[/b]：玩家在底栏按一次 Tab 就会跳到屏幕左上角，
## 且那个按钮的 [signal BaseButton.pressed] 全库无人接线——跳过去之后按回车
## 什么也不会发生（比跳走更糟：玩家以为界面坏了）。[br]
## [br][b]为什么是「收掉」而不是「纳入链」[/b]：日志折叠按钮是顶栏信息控件，
## 不是回合动作；把它塞进「出牌 → 结束回合」这条动作链会让两件事混淆。而且它
## 连点击行为都还没接（interaction epic 未落），纳入链只会把「按了没反应」
## 从链外搬到链上。[br]
## [br][b]豁免覆盖层子树[/b]：备战 / 结算 / 行囊面板自有焦点链（那些面板打开时
## 该由它们管焦点）。收拢一律跳过这些子树——否则面板一开就被抹平，玩家在
## 面板里连按钮都按不动。[br]
## [br][b]只收「可见」的[/b]：收拢按 [method Control.is_visible_in_tree] 过滤，
## 隐藏着的覆盖层按钮本就不该落焦点、也不必改（[member Control.focus_mode]
## 留着，面板打开时照常生效）。[br]
## [br][b]可逆[/b]：原 [member Control.focus_mode] 逐控件记账，[method restore]
## 原样还回去——本类改的是别人的属性，退场时必须不留痕迹。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：持有的是「我改过谁、改前是什么」这张
## 还原账（表现层的临时改写记录），不含任何游戏状态。
##
## 来源: .claude/rules/ui-code.md（键盘/手柄输入）、ADR-0031 §2、ADR-0004 §双焦点。

## 焦点环几何（复用「可落焦点」判据——不另写一份）。
const Ring: GDScript = preload("res://src/ui/combat/interaction/combat_focus_ring.gd")

## 豁免收拢的覆盖层子树名（备战 / 结算 / 行囊——它们打开时自管焦点）。[br]
## [br][b]为什么按名字找而不是按属性[/b]：三者分别由备战挂载、结算挂载、行囊宿主
## 建在战场根的不同层上，收拢方不持它们的句柄；名字由各自组件自己钉住。
const OVERLAY_NAMES: Array[String] = ["DeployPanel", "SettlementHost", "CombatBagScreen"]


## 被本类改过 [member Control.focus_mode] 的控件 → 改前的值。
var _restore: Dictionary = {}


## 收拢一次：把 [param p_root] 子树里可见、可聚焦、且不在 [param p_keep] 上、
## 也不属于豁免覆盖层子树的控件的 [member Control.focus_mode] 置为
## [constant Control.FOCUS_NONE]。[br]
## [br][param p_keep] 链上控件（手牌 / 底栏 / 撤退——它们归链管）。[br]
## [br][b]返回[/b]：本次收掉了几个（0 = 链外已无可见可聚焦者，如实报告）。[br]
## [br][b]幂等[/b]：已收过的控件不会覆盖记账（否则第二次收拢会把
## [constant Control.FOCUS_NONE] 当成「改前值」记下来，还原就把控件永久锁死）。
func sweep(p_root: Control, p_keep: Array) -> int:
	if p_root == null or not is_instance_valid(p_root):
		return 0
	var count: int = 0
	for node: Variant in outside_nodes(p_root, p_keep):
		var control: Control = node
		if not _restore.has(control):
			_restore[control] = control.focus_mode
		control.focus_mode = Control.FOCUS_NONE
		count += 1
	return count


## 链外可聚焦控件清单（纯查询——不落任何改动，测试与调试用）。[br]
## [br][b]判据[/b]：树内 + 可见 + [member Control.focus_mode] 非 NONE +
## 不是链上控件 + 不在豁免覆盖层里。[br]
## [br][b]禁用（[member BaseButton.disabled]）也算[/b]：引擎对禁用 [Button] 的焦点
## 导航不跳过（见 [method CombatFocusRing.pin] 的说明），留着它等于留一个焦点陷阱
## ——这一点与 [method CombatFocusRing.focusable] 的口径不同，那边问的是「值不值得
## 主动把默认焦点放上去」（禁用当然不值得），这边问的是「Tab 会不会走到」。
func outside_nodes(p_root: Control, p_keep: Array) -> Array:
	var found: Array = []
	_walk(p_root, p_keep, _overlay_roots(p_root), found)
	return found


## 把改过的 [member Control.focus_mode] 全部还原（退场 / 重建链时调用）。[br]
## [br][b]已释放的控件跳过[/b]：控件随场景销毁后，改回去只会打到已释放对象上。
## 判据必须先 [method @GlobalScope.is_instance_valid] 再 [code]is[/code]——
## 对已释放对象做 [code]is[/code] 判断，引擎会直接报
## [code]Left operand of 'is' is a previously freed instance[/code] 并中断本次还原
## （记账清不掉，下一次还原还会再撞一次）。
func restore() -> void:
	for node: Variant in _restore.keys():
		if not is_instance_valid(node):
			continue
		if node is Control:
			(node as Control).focus_mode = int(_restore[node])
	_restore.clear()


## 已记账的控件数（未还原时——测试探针）。
func tracked_count() -> int:
	return _restore.size()


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 豁免收拢的覆盖层子树根（按名现找——见 [constant OVERLAY_NAMES]）。
func _overlay_roots(p_root: Control) -> Array:
	var roots: Array = []
	for overlay_name: String in OVERLAY_NAMES:
		var node: Node = p_root.find_child(overlay_name, true, false)
		if node is Control:
			roots.append(node as Control)
	return roots

## 深度优先遍历：命中即收，命中豁免子树即整棵跳过（不往面板里走）。
func _walk(p_node: Node, p_keep: Array, p_exempt: Array, p_found: Array) -> void:
	if p_node is Control:
		var control: Control = p_node
		if p_exempt.has(control):
			return
		if not p_keep.has(control) and _is_outside_focusable(control):
			p_found.append(control)
	for child: Node in p_node.get_children():
		_walk(child, p_keep, p_exempt, p_found)


## 是否值得收（可见 + [member Control.focus_mode] 非 NONE / 非 ACCESSIBILITY）。[br]
## [br][b]为什么不直接复用 [method CombatFocusRing.focusable][/b]：那一条问的是
## 「能不能把焦点放上去」（禁用即否），而收拢面对的是「Tab 会不会走到」——
## 禁用按钮正是最该收的（引擎不跳过它）。故判据故意更宽：只要可见且
## [member Control.focus_mode] 允许焦点，就收。[br]
## [br][b]为什么放过 [constant Control.FOCUS_ACCESSIBILITY][/b]：
## [code]RichTextLabel[/code] 之类默认是这个值（实测 = 3），读屏未启用时引擎拒绝
## 把焦点交给它、Tab 也不会走到它——收掉属于改别人的可访问性配置，代价大于收益。
func _is_outside_focusable(p_control: Control) -> bool:
	if not Ring.inside_tree(p_control):
		return false
	if p_control.focus_mode == Control.FOCUS_ACCESSIBILITY:
		return false
	return p_control.is_visible_in_tree() and p_control.focus_mode != Control.FOCUS_NONE
