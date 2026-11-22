class_name CombatFocusChain
extends RefCounted
## CombatFocusChain —— 战斗界面的键盘/手柄焦点链（.claude/rules/ui-code.md 双输入）。
##
## [b]职责[/b]：把出牌阶段玩家能用键盘/手柄操作的控件串成一条显式焦点链——
## [code]战斗日志入口 → 手牌卡[0..n-1] → 行囊 → 结束出牌 → 撤退[/code] 成环
## （日志入口是信息站，排在动作三连之前的环首），并维护三件事：[br]
##   1. [b]默认焦点[/b]：[method focus_default] 落第一张手牌（手牌为空时落第一个
##      可点按钮）——进战斗后键盘玩家不再「焦点为空、按哪都没反应」；[br]
##   2. [b]阶段驱动[/b]：手牌与底栏两按钮仅在出牌阶段（2）可聚焦——敌方行动 /
##      攻击结算 / 播报期间它们退出焦点，否则玩家能把焦点走到点不动的控件上、
##      按回车又什么都不发生。[b]日志入口与撤退不受阶段限制[/b]（GDD §10 撤退常驻；
##      日志正是敌方回合最该读的东西）；[br]
##   3. [b]禁用即停[/b]：链上被 [member BaseButton.disabled] 的控件把 Tab 前后与
##      四个方向邻居全部自指——焦点落到它便不再前移（跳过禁用项必须由链自己保证）。[br]
## [br][b]各件各有其家[/b]：「场上此刻有谁」归 [CombatFocusChainNodes]、邻居路径怎么算归
## [CombatFocusRing]、链外收拢归 [CombatFocusChainOutside]、日志入口的连接归
## [CombatFocusLogLink]、结论怎么落到控件上归 [CombatFocusChainApply]。
## 本类只管「谁上场、焦点落在哪」。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：控件引用是渲染节点，阶段现读战斗系统；
## [b]零轮询[/b]：无 [code]_process()[/code]——全部由阶段信号、手牌重建与日志开合
## 信号显式驱动。
##
## 来源: .claude/rules/ui-code.md（所有交互元素必须同时支持键盘/鼠标和手柄输入）、
## ADR-0004 §双焦点、ADR-0031 §2/§3、先例
## [code]settlement_panel_view.wire_focus_chain[/code]（结算面板焦点成环）。

## 出牌阶段号（仅此阶段手牌与底栏动作可聚焦——与 [code]CombatInputLayer.PLAY_PHASE[/code]
## 同一语义，值同源 CombatPhase.PLAY）。
const PLAY_PHASE: int = 2

## 焦点环几何（纯函数——邻居路径的唯一算法）。
const Ring := preload("res://src/ui/combat/interaction/combat_focus_ring.gd")
## 链外收拢的对外窗口（Tab 走到链尾时的兜底 + 退场还原——见类文档）。
const Outside := preload(
		"res://src/ui/combat/interaction/combat_focus_chain_outside.gd")
## 日志入口连接（找站 + 订阅开合——见类文档「日志入口」）。
const LogLink := preload(
		"res://src/ui/combat/interaction/combat_focus_log_link.gd")
## 链成员查询（控件从门面哪儿取——见类文档「场上此刻有谁」）。
const Nodes := preload(
		"res://src/ui/combat/interaction/combat_focus_chain_nodes.gd")
## 落定写侧（可聚焦性 / 释放焦点 / 擦邻居路径——见类文档「施加一半」）。
const Apply := preload(
		"res://src/ui/combat/interaction/combat_focus_chain_apply.gd")

## 豁免收拢的覆盖层子树名（转发链外窗口的单一定义——不在这里另抄一份）。[br]
## [br][b]为什么本链不持覆盖层句柄[/b]：备战 / 结算 / 行囊面板分别挂在不同层上
## （由各自的挂载模块建），焦点链只管战场四控件；豁免清单归收拢器（它才是执行方）。
const OVERLAY_NAMES: Array[String] = Outside.OVERLAY_NAMES

## 战场门面（[code]CombatLayout[/code]——取手牌区 / 底栏 / 撤退按钮）。
var _layout: Control = null
## 战斗系统（阶段现读 + [signal CombatSystem.phase_changed] 订阅）。
var _combat: Node = null
## 外部启用开关（面板打开 / 输入冻结时为 false——整条链让位）。
var _enabled: bool = true
## 链外收拢窗口（[method bind] 建——持收拢器与它的还原账）。
var _outside: RefCounted = null
## 日志入口连接件（[method bind] 建——找站 + 订阅开合）。
var _log_link: RefCounted = null
## 链成员查询（[method bind] 建——控件从门面哪儿取）。
var _nodes: RefCounted = null


## 注入门面与战斗系统并订阅（场景接线在交互层装配后调用一次）。[br]
## [br][b]重复调用防护[/b]：同源已订阅则跳过（[method Node.is_connected] 先例——
## 接两次会让一次开合触发两轮重建）。
func bind(p_layout: Control, p_combat: Node) -> void:
	_layout = p_layout
	_combat = p_combat
	_nodes = Nodes.new(p_layout, p_combat)
	_outside = Outside.new(p_layout)
	_log_link = LogLink.new(p_layout, Callable(self, &"rebuild"))
	_nodes.call(&"set_log_link", _log_link)
	_log_link.call(&"subscribe")
	if _combat != null and _combat.has_signal(&"phase_changed") \
			and not _combat.phase_changed.is_connected(_on_phase_changed):
		_combat.phase_changed.connect(_on_phase_changed)
	apply_phase(_current_phase())


## 启用 / 停用整条链（模态面板打开时停用——焦点不该走到被面板盖住的按钮上）。[br]
## [br][b]停用会释放焦点[/b]：否则焦点停留在已不可聚焦的控件上，Tab 的下一步
## 由引擎按几何自推（跳到链外的战斗日志折叠按钮，玩家再也回不来）。
func set_enabled(p_enabled: bool) -> void:
	if _enabled == p_enabled:
		return
	_enabled = p_enabled
	apply_phase(_current_phase())


## 是否启用（测试探针）。
func is_enabled() -> bool:
	return _enabled


## 阶段落定——可聚焦性 + 默认焦点一起落。[br]
## [br][param p_phase] 当前阶段（-1 = 未知，按宽松处理，同
## [code]CombatInputLayer._is_play_phase[/code] 口径）。
func apply_phase(p_phase: int) -> void:
	var play_ok: bool = _enabled and _is_play_phase(p_phase)
	var cards: Array = _hand_cards()
	var bar: Array = _bar_buttons()
	var retreat: Control = _retreat_button()
	var log_nodes: Array = _log_nodes()
	_set_modes(cards, play_ok)
	_set_modes(bar, play_ok)
	_set_modes([retreat], _enabled)
	_set_modes(log_nodes, _enabled)
	Ring.wire(cards, bar, retreat, play_ok, _enabled, log_nodes)
	sweep_outside(cards, bar, retreat)
	if not _enabled:
		# 整条链让位（模态面板打开）——焦点不该停在被盖住的控件上。
		_release_if_holding(cards + bar + [retreat] + log_nodes)
		return
	if not play_ok:
		# 只有手牌与底栏动作被停用；撤退与日志按钮此时仍可聚焦
		# （GDD §10 撤退常驻、日志是敌方回合最该读的东西），不该被一起释放。
		_release_if_holding(cards + bar)
		return
	if focus_owner() == null:
		focus_default()


## 收拢链外可聚焦控件（转发链外窗口——为什么每次阶段落定都收一次见该类文档）。[br]
## [br][b]返回[/b]：本次收掉几个（0 = 链外本就干净）。
func sweep_outside(p_cards: Array, p_bar: Array, p_retreat: Control) -> int:
	if _outside == null:
		return 0
	var keep: Array = p_cards.duplicate()
	keep.append_array(p_bar)
	if p_retreat != null:
		keep.append(p_retreat)
	keep.append_array(_log_nodes())
	return int(_outside.call(&"sweep", keep))


## 还原收拢改过的 [member Control.focus_mode]（退场用——理由见链外窗口类文档）。
func restore_outside() -> void:
	if _outside != null:
		_outside.call(&"restore")


## 链外可聚焦控件清单（纯查询——测试断言「链外已收干净」用）。
func outside_focusables() -> Array:
	if _outside == null:
		return []
	return _outside.call(&"outside_nodes", _chain_nodes())


## 手牌重建后重建环（卡节点换了一批，旧的 [NodePath] 会指向已释放的节点）。[br]
## [br][b]只在焦点为空时补默认焦点[/b]：焦点非空时不动——重建不该把玩家正在操作的
## 焦点抢走（例如刚打完一张牌，焦点应落到新的第一张而不是抖一下）。
func rebuild() -> void:
	apply_phase(_current_phase())


## 落默认焦点（转发落定写侧——为什么优先手牌而不是底栏按钮见该类文档）。[br]
## [br][b]返回[/b]：是否真的落到了某个控件上（无可聚焦者时为 false——如实报告，
## 不假装成功）。
func focus_default() -> bool:
	return bool(Apply.grab_default(_hand_cards(), _bar_buttons()))


## 链上的控件名（按 Tab 顺序——测试断言顺序稳定性用）。
func focus_order() -> Array:
	var names: Array = []
	for node: Variant in Ring.ring_order(_hand_cards(), _bar_buttons(),
			_retreat_button(), _enabled and _is_play_phase(_current_phase()), _enabled,
			_log_nodes()):
		names.append(str((node as Control).name))
	return names


## 当前键盘/手柄焦点持有者（未入树 / 无焦点时为 null——转发落定写侧的现读）。
func focus_owner() -> Control:
	return Apply.current_owner()


## 阶段信号 → 阶段落定（可聚焦性与默认焦点跟着阶段走）。[br]
## [br][b]为什么吞掉旧阶段与回合号[/b]：本链只关心「现在能不能操作」——
## 阶段间的迁移原因（攻击 / 敌方行动）不属于焦点层（ADR-0031 §2）。
func _on_phase_changed(_old_phase: int, new_phase: int, _turn: int) -> void:
	apply_phase(new_phase)


# ═══════════════════════════════════════════════════════════════════════════════
# 内部：取材（全部转发 [CombatFocusChainNodes]——链不自己找控件）
# ═══════════════════════════════════════════════════════════════════════════════

## 手牌卡节点（弧形顺序——与视觉从左到右一致）。
func _hand_cards() -> Array:
	if _nodes == null:
		return []
	var raw: Variant = _nodes.call(&"hand_cards")
	return raw if raw is Array else []


## 底栏动作按钮（行囊 → 结束出牌）。
func _bar_buttons() -> Array:
	if _nodes == null:
		return []
	var raw: Variant = _nodes.call(&"bar_buttons")
	return raw if raw is Array else []


## 右上角撤退按钮（常驻——本链唯一不受阶段限制的控件）。
func _retreat_button() -> Control:
	if _nodes == null:
		return null
	return _nodes.call(&"retreat_button") as Control


## 日志可聚焦节点（折叠按钮常驻；展开时追加面板滚动区——见类文档「日志入口」）。
func _log_nodes() -> Array:
	if _nodes == null:
		return []
	var raw: Variant = _nodes.call(&"log_nodes")
	return raw if raw is Array else []


## 当前战斗阶段（战斗系统不可用 → -1）。
func _current_phase() -> int:
	if _nodes == null:
		return -1
	return int(_nodes.call(&"current_phase"))


## 链上控件清单（收拢的 [code]keep[/code] 名单——见该类方法文档）。
func _chain_nodes() -> Array:
	if _nodes == null:
		return []
	var raw: Variant = _nodes.call(&"chain_nodes")
	return raw if raw is Array else []


## 门面是否可用（退场后 [member _nodes] 为 null——各处入口统一走这一条）。[br]
## [br][b]为什么以查询件在不在为准[/b]：[method bind] 之后门面与查询件同生同灭
## （[method unbind] 一起置空），先问查询件等于问「这一场到底接上线了没有」。
func _has_layout() -> bool:
	return _nodes != null and bool(_nodes.call(&"has_layout"))


# ═══════════════════════════════════════════════════════════════════════════════
# 内部：焦点落定
# ═══════════════════════════════════════════════════════════════════════════════

## 当前阶段是否允许聚焦手牌与底栏动作（未知按宽松——同
## [code]CombatInputLayer._is_play_phase[/code] 口径）。
func _is_play_phase(p_phase: int) -> bool:
	return p_phase < 0 or p_phase == PLAY_PHASE


## 批量落 [member Control.focus_mode]（转发落定写侧——见该类文档）。[br]
## [br][b]开与关写的是同一个属性[/b]：离开出牌阶段时手牌与底栏动作一起退回
## [constant Control.FOCUS_NONE]（不是只挡默认焦点——不留任何可落点）。
func _set_modes(p_nodes: Array, p_play_ok: bool) -> void:
	Apply.set_modes(p_nodes, p_play_ok)


## 焦点是否落在给定控件上——是则释放（转发落定写侧）。[br]
## [br][b]为什么要主动释放[/b]：焦点停在一个 [constant Control.FOCUS_NONE] 的控件上时，
## 引擎不会自动搬走它；玩家按 Tab 时又因该控件已不在链上而按几何自推乱跳。
func _release_if_holding(p_nodes: Array) -> void:
	Apply.release_if_holding(p_nodes, focus_owner())


## 清除链上全部邻居路径（退场用——不留指向已释放节点的路径）。
func clear_wiring() -> void:
	var nodes: Array = _hand_cards() + _bar_buttons() + [_retreat_button()]
	nodes.append_array(_log_nodes())
	Apply.clear_wiring(nodes)


## 退订（场景退场——信号源是常驻 Autoload / 场景节点）。[br]
## [br][b]顺序[/b]：先 [method clear_wiring]（它还要经连接件取日志站），再拆连接件
## ——反过来会把「日志站的邻居路径」留在已经不可达的控件上。[br]
## [br][b]链外窗口先还原再弃用[/b]：[method restore_outside] 要在门面还有效时跑，
## 故排在 [method CombatFocusChainOutside.release] 之前。
func unbind() -> void:
	restore_outside()
	if _outside != null:
		_outside.call(&"release")
	_outside = null
	if _combat != null and is_instance_valid(_combat) \
			and _combat.has_signal(&"phase_changed") \
			and _combat.phase_changed.is_connected(_on_phase_changed):
		_combat.phase_changed.disconnect(_on_phase_changed)
	clear_wiring()
	if _log_link != null:
		_log_link.call(&"unsubscribe")
	_log_link = null
	_nodes = null
	_layout = null
	_combat = null
