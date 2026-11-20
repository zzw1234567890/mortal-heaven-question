class_name CombatFocusMemory
extends RefCounted
## CombatFocusMemory —— 弹窗开合时的键盘/手柄焦点记忆（.claude/rules/ui-code.md 双输入）。[br]
## [br][b]职责[/b]：打开覆盖面板前记下「焦点此刻在谁身上」，关闭后还给同一处。[br]
## [br][b]为什么需要显式记忆[/b]：面板一开就把焦点抢走（面板自己的默认焦点），
## 而关闭时[b]没有任何东西记得它是从哪来的[/b]——当前的兜底是「焦点为空就补默认
## 焦点」（[method CombatFocusChain.focus_default]），于是取消一次撤退确认之后，
## 玩家的焦点从「撤退按钮」跳到「第一张手牌」，而弹窗开着再关 = 焦点搬家，
## 每开一次面板就丢一次位置。手柄玩家对此最敏感：十字键按回原处得重走一遍整条链。[br]
## [br][b]失效即退回默认[/b]：记忆的控件可能已经没了（手牌重建换了节点、面板关掉时
## 该控件被隐藏或禁用了）。这一情形不假装成功——先如实判「还不了」，再落
## [member _fallback]（由焦点链注册的默认焦点，见 [method set_fallback]）。[br]
## [br][b]为什么单独成类[/b]：[code]combat_focus_chain.gd[/code] 已近 300 行软上限，
## 且「记一个控件、验它还活着、还回去」与「谁上场、Tab 怎么走」是两件事。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：持有的只是一个控件引用（表现层瞬态，
## §2.1 豁免），不含任何游戏状态。[b]零轮询[/b]：无 [code]_process()[/code]。
##
## 来源: .claude/rules/ui-code.md（键盘/手柄输入）、ADR-0004 §双焦点、ADR-0031 §2/§3、
## design/ux/hud.md（Esc 层级退出——逐层退不该丢焦点位置）。

## 焦点环几何（复用「可落焦点」判据——不另写一份）。
const Ring: GDScript = preload("res://src/ui/combat/interaction/combat_focus_ring.gd")

## 记下的控件（null = 已取走 / 从未有效记忆——见 [member _recorded]）。
var _remembered: Control = null
## 是否真的记过东西。[br]
## [br][b]为什么不能靠 [code]_remembered == null[/code] 判断[/b]：实测（探针
## [code]tools/probe_freed_ref.gd[/code]）已释放的对象引用与 null **比较相等**，
## 于是「记过、但那个控件随后被释放」会被误判成「从没记过」，
## [method restore] 直接空手而归——兜底默认焦点也就没机会落。
var _recorded: bool = false
## 还原失败时的兜底 [code]func() -> bool[/code]（焦点链注册的默认焦点——见
## [method set_fallback]）。未注册时为空 Callable，此时还原失败就只是失败。
var _fallback: Callable = Callable()


## 注册还原失败时的兜底（焦点链在 [method CombatFocusChain.bind] 里注册
## [method CombatFocusChain.focus_default]）。[br]
## [br][b]为什么是回调而不是让记忆自己找默认焦点[/b]：「默认焦点是谁」属于链
## （它知道手牌与底栏按钮），记忆只负责「还到原处」；两件事分开，记忆才能被
## 面板这类不持链的组件直接使用。
func set_fallback(p_fallback: Callable) -> void:
	_fallback = p_fallback


## 记下当前键盘/手柄焦点（打开覆盖面板前调用）。[br]
## [br][b]焦点为空时不记忆[/b]：鼠标玩家点开面板时焦点常常本来就空着，此时「记住
## 空」与「不记」等价；显式写 null 会把上一次的记忆抹掉（若面板套面板就会丢外层位置）。
func remember_current() -> void:
	var owner: Control = focus_owner()
	if owner != null:
		_remembered = owner
		_recorded = true


## 直接记下一个控件（测试与手工装配用——生产走 [method remember_current]）。
func remember(p_control: Control) -> void:
	if p_control != null:
		_remembered = p_control
		_recorded = true


## 取出记忆并把焦点还给那个控件；还不了则落兜底默认焦点。[br]
## [br][b]没记过就什么都不做[/b]：鼠标玩家点开面板时焦点常常本来就空着——此时
## 不记忆，关闭时也不该凭空把焦点塞给某个控件（那正是「关一次面板跳一次焦点」）。
## [br][b]取走即清空[/b]：一次打开配一次关闭，还过之后不该再被下一次关闭重复消费
## （否则连开两个面板时，第二个面板关掉会把焦点还到第一个面板之前的旧位置）。[br]
## [br][b]判据同链[/b]：[method CombatFocusRing.focusable]（树内 + 可见 + 未禁用 +
## [member Control.focus_mode] 非 [constant Control.FOCUS_NONE]）——被隐藏或被
## 阶段停用（敌方行动期间手牌退出焦点）的控件不算还能落点。[br]
## [br][b]返回[/b]：真的拿到焦点的控件；没记过、或原处与兜底都落不成时为 null
## （如实报告，调用方不必再补一次——兜底已经试过了）。
func restore() -> Control:
	if not _recorded:
		return null
	var target: Control = take()
	if target != null:
		target.grab_focus()
		if focus_owner() == target:
			return target
	# 原处已不可落（控件没了 / 被隐藏 / 被阶段停用）→ 落兜底默认焦点
	if _fallback.is_valid() and bool(_fallback.call()):
		return focus_owner()
	return null


## 取出记忆的控件（清空记忆）——还活着且可落焦点则返回它，否则返回 null。[br]
## [br][b]先取走再验[/b]：无论验的结果如何，记忆都算消费掉了——一次打开配一次关闭，
## 验失败时不该让下一次关闭再试一遍同一处。
func take() -> Control:
	var target: Control = _remembered
	_remembered = null
	_recorded = false
	if not is_instance_valid(target):
		return null
	return target if Ring.focusable(target) else null


## 当前记着什么（测试探针 / 未还原时为该控件，否则 null）。[br]
## [br][b]已释放的控件按 null 报[/b]：引用还在，但调用方拿到它也没用——
## 如实回报「没有可还的目标」，而不是递一个一碰就炸的句柄。
func remembered() -> Control:
	if not _recorded or not is_instance_valid(_remembered):
		return null
	return _remembered


## 清空记忆（退场用——不还原，只丢掉句柄）。
func clear() -> void:
	_remembered = null
	_recorded = false


## 当前键盘/手柄焦点持有者（未入树 / 无焦点时为 null）。
func focus_owner() -> Control:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.gui_get_focus_owner()
