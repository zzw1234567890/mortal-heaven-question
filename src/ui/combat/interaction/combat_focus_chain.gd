class_name CombatFocusChain
extends RefCounted
## CombatFocusChain —— 战斗界面的键盘/手柄焦点链（.claude/rules/ui-code.md 双输入）。
##
## [b]职责[/b]：把出牌阶段玩家能用键盘/手柄操作的控件串成一条显式焦点链——
## [code]手牌卡[0..n-1] → 行囊 → 结束出牌 → 撤退[/code] 成环，并维护三件事：[br]
##   1. [b]默认焦点[/b]：[method focus_default] 落第一张手牌（手牌为空时落第一个
##      可点按钮）——进战斗后键盘玩家不再「焦点为空、按哪都没反应」；[br]
##   2. [b]阶段驱动[/b]：手牌与底栏两按钮仅在出牌阶段（2）可聚焦——敌方行动 /
##      攻击结算 / 播报期间整条链退出焦点（[code]FOCUS_NONE[/code] + 释放焦点），
##      否则玩家能把焦点走到点不动的控件上、按回车又什么都不发生；[br]
##   3. [b]禁用即停[/b]：链上被 [member BaseButton.disabled] 的控件把 Tab 前后与
##      四个方向邻居全部自指——焦点落到它便不再前移（实测引擎对 [code]disabled[/code]
##      的 [Button] [b]不做跳过[/b]，跳过必须由链自己保证）。[br]
## [br][b]几何归 [CombatFocusRing][/b]、[b]链外收拢归 [CombatFocusSweeper][/b]：
## 本类只管「谁上场、焦点落在哪」。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：控件引用是渲染节点，阶段现读战斗系统；
## [b]零轮询[/b]：无 [code]_process()[/code]——全部由阶段信号与手牌重建显式驱动。
##
## 来源: .claude/rules/ui-code.md（所有交互元素必须同时支持键盘/鼠标和手柄输入）、
## ADR-0004 §双焦点、ADR-0031 §2/§3、先例
## [code]settlement_panel_view.wire_focus_chain[/code]（结算面板焦点成环）。

## 出牌阶段号（仅此阶段手牌与底栏动作可聚焦——与 [code]CombatInputLayer.PLAY_PHASE[/code]
## 同一语义，值同源 CombatPhase.PLAY）。
const PLAY_PHASE: int = 2

## 焦点环几何（纯函数——邻居路径的唯一算法）。
const Ring := preload("res://src/ui/combat/interaction/combat_focus_ring.gd")
## 链外控件收拢（Tab 走到链尾时的兜底——见类文档「链外收拢」）。
const Sweeper := preload("res://src/ui/combat/interaction/combat_focus_sweeper.gd")
## 焦点环样式（松石青粗边——与商店 / 卡组编辑面板同一份，禁止另写一套）。
const FocusStyle: GDScript = preload("res://src/ui/exploration/shop_panel_layout.gd")

## 豁免收拢的覆盖层子树名（转发收拢器的单一定义——不在这里另抄一份）。[br]
## [br][b]为什么本链不持覆盖层句柄[/b]：备战 / 结算 / 行囊面板分别挂在不同层上
## （由各自的挂载模块建），焦点链只管战场四控件；豁免清单归收拢器（它才是执行方）。
const OVERLAY_NAMES: Array[String] = Sweeper.OVERLAY_NAMES

## 战场门面（[code]CombatLayout[/code]——取手牌区 / 底栏 / 撤退按钮）。
var _layout: Control = null
## 战斗系统（阶段现读 + [signal CombatSystem.phase_changed] 订阅）。
var _combat: Node = null
## 外部启用开关（面板打开 / 输入冻结时为 false——整条链让位）。
var _enabled: bool = true
## 链外收拢器（[method bind] 建——持「改过谁」的还原账）。
var _sweeper: RefCounted = null


## 注入门面与战斗系统并订阅（场景接线在交互层装配后调用一次）。[br]
## [br][b]重复调用防护[/b]：同源已订阅则跳过（[method Node.is_connected] 先例）。
func bind(p_layout: Control, p_combat: Node) -> void:
	_layout = p_layout
	_combat = p_combat
	_sweeper = Sweeper.new()
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
	_set_modes(cards, play_ok)
	_set_modes(bar, play_ok)
	_set_modes([retreat], _enabled)
	Ring.wire(cards, bar, retreat, play_ok, _enabled)
	sweep_outside(cards, bar, retreat)
	if not play_ok:
		_release_if_holding(cards, bar, retreat)
		return
	if focus_owner() == null:
		focus_default()


## 收拢链外可聚焦控件（Tab 走到链尾不再跳到战斗日志折叠按钮）。[br]
## [br][b]为什么每次阶段落定都收一次[/b]：链外控件（顶栏 / 覆盖层）的出现时机
## 不由本链决定——新面板挂上、旧节点显隐都会改变「谁可聚焦」，只在 [method bind]
## 时收一次会在那些时刻漏掉。收拢是幂等的（[CombatFocusSweeper] 逐控件记账），
## 重复调用不产生额外代价。[br]
## [br][b]返回[/b]：本次收掉几个（0 = 链外本就干净）。
func sweep_outside(p_cards: Array, p_bar: Array, p_retreat: Control) -> int:
	if _sweeper == null or not _has_layout():
		return 0
	return int(_sweeper.call(&"sweep", _layout, _chain_nodes(p_cards, p_bar, p_retreat)))


## 还原收拢改过的 [member Control.focus_mode]（退场用）。[br]
## [br][b]为什么必须还原[/b]：本链改的是别人（顶栏 / 覆盖层）的属性；不还原的话
## 下一次进战斗时那些控件仍是 [constant Control.FOCUS_NONE]，而它们本不该由本链管。
func restore_outside() -> void:
	if _sweeper != null:
		_sweeper.call(&"restore")


## 链外可聚焦控件清单（纯查询——测试断言「链外已收干净」用）。
func outside_focusables() -> Array:
	if _sweeper == null or not _has_layout():
		return []
	return _sweeper.call(&"outside_nodes", _layout,
			_chain_nodes(_hand_cards(), _bar_buttons(), _retreat_button()))


## 手牌重建后重建环（卡节点换了一批，旧的 [NodePath] 会指向已释放的节点）。[br]
## [br][b]只在焦点为空时补默认焦点[/b]：焦点非空时不动——重建不该把玩家正在操作的
## 焦点抢走（例如刚打完一张牌，焦点应落到新的第一张而不是抖一下）。
func rebuild() -> void:
	apply_phase(_current_phase())


## 落默认焦点。[br]
## [br][b]为什么优先手牌而不是底栏按钮[/b]：出牌阶段玩家要做的第一件事是出牌，
## 焦点落在第一张手牌上意味着「进战斗就能按回车出牌」；底栏按钮是兜底——
## 手牌为空（全打完或开局没抽到）时玩家唯一能做的是结束回合。[br]
## [br][b]返回[/b]：是否真的落到了某个控件上（无可聚焦者时为 false——如实报告，
## 不假装成功）。
func focus_default() -> bool:
	for card: Variant in _hand_cards():
		if Ring.focusable(card):
			(card as Control).grab_focus()
			return true
	for button: Variant in _bar_buttons():
		if Ring.focusable(button):
			(button as Control).grab_focus()
			return true
	return false


## 链上的控件名（按 Tab 顺序——测试断言顺序稳定性用）。
func focus_order() -> Array:
	var names: Array = []
	for node: Variant in Ring.ring_order(_hand_cards(), _bar_buttons(),
			_retreat_button(), _enabled and _is_play_phase(_current_phase()), _enabled):
		names.append(str((node as Control).name))
	return names


## 当前键盘/手柄焦点持有者（未入树 / 无焦点时为 null）。
func focus_owner() -> Control:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.gui_get_focus_owner()


## 阶段信号 → 阶段落定（可聚焦性与默认焦点跟着阶段走）。[br]
## [br][b]为什么吞掉旧阶段与回合号[/b]：本链只关心「现在能不能操作」——
## 阶段间的迁移原因（攻击 / 敌方行动）不属于焦点层（ADR-0031 §2）。
func _on_phase_changed(_old_phase: int, new_phase: int, _turn: int) -> void:
	apply_phase(new_phase)


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 手牌卡节点（弧形顺序——与视觉从左到右一致）。
func _hand_cards() -> Array:
	var hand: Variant = _node_of(&"hand_area")
	if hand == null or not (hand as Object).has_method(&"card_nodes"):
		return []
	var raw: Variant = (hand as Object).call(&"card_nodes")
	return raw if raw is Array else []


## 底栏动作按钮（行囊 → 结束出牌——按钮本体在包装控件里，见
## [code]CombatBottombar[/code] 的组件形态）。
func _bar_buttons() -> Array:
	var buttons: Array = []
	var bar: Variant = _node_of(&"combat_bottombar")
	if bar == null:
		return buttons
	for property: StringName in [&"bag_button", &"end_turn_button"]:
		var button: Control = _inner_button(bar, property)
		if button != null:
			buttons.append(button)
	return buttons


## 右上角撤退按钮（常驻——本链唯一不受阶段限制的控件）。
func _retreat_button() -> Control:
	var raw: Variant = _node_of(&"retreat_button")
	return raw as Control if raw is Control else null


## 门面属性 → 节点（缺失 / 未装配为 null）。
func _node_of(p_property: StringName) -> Variant:
	if not _has_layout():
		return null
	var raw: Variant = _layout.get(p_property)
	return raw if raw is Object and is_instance_valid(raw) else null


## 门面是否可用（退场后 [member _layout] 为 null——各处入口统一走这一条）。
func _has_layout() -> bool:
	return _layout != null and is_instance_valid(_layout)


## 链上控件清单（收拢的 [code]keep[/code] 名单——按 Tab 顺序，与
## [method focus_order] 同一来源，避免两处各拼一份）。
func _chain_nodes(p_cards: Array, p_bar: Array, p_retreat: Control) -> Array:
	var keep: Array = p_cards.duplicate()
	keep.append_array(p_bar)
	if p_retreat != null:
		keep.append(p_retreat)
	return keep


## 包装控件内的 [Button] 本体（包装自身是 [Control]，点击归内层按钮）。[br]
## [br][b]直接取 [code]button[/code] 属性[/b]：包装是懒建的，没有稳定节点路径。
func _inner_button(p_wrapper: Variant, p_property: StringName) -> Control:
	var wrapper: Variant = (p_wrapper as Object).get(p_property)
	if wrapper == null or not is_instance_valid(wrapper):
		return null
	if wrapper is Button:
		return wrapper as Button
	var inner: Variant = (wrapper as Object).get(&"button")
	return inner as Control if inner is Control else null


## 当前战斗阶段（战斗系统不可用 → -1）。
func _current_phase() -> int:
	if _combat == null or not is_instance_valid(_combat) \
			or not _combat.has_method(&"get_current_phase"):
		return -1
	return int(_combat.call(&"get_current_phase"))


## 当前阶段是否允许聚焦手牌与底栏动作（未知按宽松——同
## [code]CombatInputLayer._is_play_phase[/code] 口径）。
func _is_play_phase(p_phase: int) -> bool:
	return p_phase < 0 or p_phase == PLAY_PHASE


## 批量落 [member Control.focus_mode]。[br]
## [br][b]开与关写的是同一个属性[/b]：离开出牌阶段时手牌与底栏动作一起退回
## [constant Control.FOCUS_NONE]（不是只挡默认焦点——不留任何可落点）。
func _set_modes(p_nodes: Array, p_play_ok: bool) -> void:
	for node: Variant in p_nodes:
		if not Ring.inside_tree(node):
			continue
		var control: Control = node
		control.focus_mode = Control.FOCUS_ALL if p_play_ok else Control.FOCUS_NONE
		# 焦点环随焦点自动绘制（引擎只在获得焦点时画）——幂等：只覆盖同一个键
		if p_play_ok and control is Button:
			FocusStyle.apply_focus_ring(control as Button)


## 焦点是否仍在链上——是则释放（停用 / 离开出牌阶段时把焦点交还给引擎）。[br]
## [br][b]为什么要主动释放[/b]：焦点停在一个 [constant Control.FOCUS_NONE] 的控件上时，
## 引擎不会自动搬走它；玩家按 Tab 时又因该控件已不在链上而按几何自推乱跳。
func _release_if_holding(p_cards: Array, p_bar: Array, p_retreat: Control) -> void:
	var owner: Control = focus_owner()
	if owner == null:
		return
	for group: Array in [p_cards, p_bar, [p_retreat]]:
		if group.has(owner):
			owner.release_focus()
			return


## 清除链上全部邻居路径（退场用——不留指向已释放节点的路径）。
func clear_wiring() -> void:
	for node: Variant in _hand_cards() + _bar_buttons() + [_retreat_button()]:
		if Ring.inside_tree(node):
			Ring.clear(node as Control)


## 退订（场景退场——信号源是常驻 Autoload）。
func unbind() -> void:
	restore_outside()
	_sweeper = null
	if _combat != null and is_instance_valid(_combat) \
			and _combat.has_signal(&"phase_changed") \
			and _combat.phase_changed.is_connected(_on_phase_changed):
		_combat.phase_changed.disconnect(_on_phase_changed)
	clear_wiring()
	_layout = null
	_combat = null
