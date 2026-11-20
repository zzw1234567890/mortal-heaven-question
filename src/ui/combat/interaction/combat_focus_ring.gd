class_name CombatFocusRing
extends RefCounted
## CombatFocusRing —— 焦点环的「接线几何」（CombatFocusChain 的纯函数一半）。[br]
## [br][b]职责[/b]：给一组控件设 [member Control.focus_next] /
## [member Control.focus_neighbor_left] 等邻居路径，让引擎自带的 Tab 与方向键
## 派发能走通整条链。[b]不持节点[/b]——节点每次由调用方传入，本类只算路径。[br]
## [br][b]为什么拆出来[/b]：[code]combat_focus_chain.gd[/code] 的公开 API
## （默认焦点 / 阶段驱动 / 停用释放）与「路径怎么算」是两件事；合并后单文件超出
## 300 行软上限，且几何规则可以脱离场景单测。[br]
## [br][b]三条实测约束（本类存在的理由，全部经探针验证）[/b]：[br]
##   1. 留空 [NodePath] [b]不会[/b]停住焦点——引擎退回几何自推，焦点会跳到链外
##      控件上（战斗日志折叠按钮就是被跳过去的那一个）。要停住必须[b]自指[/b]；[br]
##   2. [Button.disabled] [b]不参与[/b]焦点导航——引擎照样把焦点交给它，
##      「跳过禁用项」得由链自己保证；[br]
##   3. 相对 [NodePath] 要求同处一棵场景树——未入树时算出来的路径不可用，
##      此时一律回落到自指，不留坏路径。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：无成员变量，全部为纯函数。
##
## 来源: .claude/rules/ui-code.md（交互元素须支持键盘/鼠标/手柄）、ADR-0004 §双焦点、
## 先例 [code]settlement_panel_view.wire_focus_chain[/code]。


## 串环：每个节点按 [param p_order] 的顺序接上前后（Tab）与左右（方向键），
## 再落竖向邻居。[br]
## [br][param p_cards] 手牌卡节点（弧形顺序——也是「首/末张」的来源）。[br]
## [param p_bar] 底栏动作按钮（行囊 → 结束出牌）。[br]
## [param p_retreat] 撤退按钮（可空）。[br]
## [param p_play_ok] 手牌与底栏是否上场（出牌阶段且已启用）。[br]
## [param p_enabled] 整条链是否启用（撤退只在启用时入环）。[br]
## [param p_extra] 追加站（战斗日志入口 / 展开时的日志面板滚动区；空数组与旧行为一致）。
static func wire(p_cards: Array, p_bar: Array, p_retreat: Control,
		p_play_ok: bool, p_enabled: bool, p_extra: Array = []) -> void:
	var order: Array = ring_order(p_cards, p_bar, p_retreat, p_play_ok, p_enabled, p_extra)
	for i: int in range(order.size()):
		var node: Control = order[i]
		if not inside_tree(node) or is_stopped(node):
			pin(node)
			continue
		_set_pair(node, order[(i + 1) % order.size()],
				order[(i - 1 + order.size()) % order.size()])
		_set_sides(node, order[(i - 1 + order.size()) % order.size()],
				order[(i + 1) % order.size()])
	_verticals(p_cards, p_bar, p_retreat, p_extra)


## 环的顺序：追加站（战斗日志入口）→ 手牌（出牌阶段）→ 行囊 → 结束出牌 →
## 撤退（启用时）→ 回到追加站（成环）。[br]
## [br][b]撤退不受阶段限制[/b]：GDD §10「撤退按钮始终在战斗中可点击」，敌方行动
## 期间也是合法的撤退时机；其余控件只在自己的舞台上出现。[br]
## [br][b]可聚焦者才进环[/b]：阶段外的手牌与被隐藏的按钮不入环——不靠「引擎会跳过」
## 兜底（链外控件一旦混进来，Tab 顺序就随隐藏状态漂移，玩家的肌肉记忆跟着失效）。[br]
## [br][b]追加站排在环首而不是环尾[/b]：环尾三位（行囊 → 结束出牌 → 撤退）是
## 上一轮定下并被用例钉死的「回合动作三连」，日志入口是信息控件、不属于那一串；
## 排在环首意味着连按 Tab 走完动作三连之后才轮到读战报，同时不动那三位的相对次序。[br]
## [br][b]追加站只在链启用时入环[/b]：模态面板打开时整条链让位（日志入口也在面板底下）。
static func ring_order(p_cards: Array, p_bar: Array, p_retreat: Control,
		p_play_ok: bool, p_enabled: bool, p_extra: Array = []) -> Array:
	var order: Array = []
	if p_enabled:
		for node: Variant in p_extra:
			if inside_tree(node) and not order.has(node):
				order.append(node)
	if p_play_ok:
		order.append_array(p_cards)
		order.append_array(p_bar)
	if p_enabled and p_retreat != null:
		order.append(p_retreat)
	return order


## 把节点的 Tab 前后与四个方向邻居全部自指（「到此为止」）。[br]
## [br][b]为什么必须自指[/b]：留空 [NodePath] 会退回引擎的几何自推（见类文档约束 1）。
static func pin(p_node: Control) -> void:
	if not inside_tree(p_node):
		return
	var self_path: NodePath = p_node.get_path_to(p_node)
	p_node.focus_next = self_path
	p_node.focus_previous = self_path
	p_node.focus_neighbor_left = self_path
	p_node.focus_neighbor_right = self_path
	p_node.focus_neighbor_top = self_path
	p_node.focus_neighbor_bottom = self_path


## 清除本类设过的全部邻居路径（退场用——不留指向已释放节点的路径）。
static func clear(p_node: Control) -> void:
	if not inside_tree(p_node):
		return
	p_node.focus_next = NodePath()
	p_node.focus_previous = NodePath()
	p_node.focus_neighbor_left = NodePath()
	p_node.focus_neighbor_right = NodePath()
	p_node.focus_neighbor_top = NodePath()
	p_node.focus_neighbor_bottom = NodePath()


## 是否已入树且有效。[b]非 Control 一律为 false[/b]——邻居设置只对控件有意义。[br]
## [br][b]先验有效性再判类型[/b]：对已释放的对象做 [code]is[/code] 判断会直接报
## [code]Left operand of 'is' is a previously freed instance[/code] 并中断调用方
## （实测踩到：收拢退场时记账里留着已释放的手牌节点）。顺序不能颠倒。
static func inside_tree(p_node: Variant) -> bool:
	if not is_instance_valid(p_node):
		return false
	return p_node is Control and (p_node as Control).is_inside_tree()


## 是否被禁用（不可交互——[member BaseButton.disabled] 为真）。
static func is_stopped(p_node: Variant) -> bool:
	return p_node is BaseButton and (p_node as BaseButton).disabled


## 可否落焦点（树内 + 可见 + 未禁用 + [member Control.focus_mode] 允许）。[br]
## [br][b]为什么把 [code]focus_mode[/code] 也算进来[/b]：链会按阶段把控件设成
## [constant Control.FOCUS_NONE]（离开出牌阶段 / 弹窗打开），此时
## [method Control.grab_focus] 会被引擎拒绝并打印告警——「可落焦点」若不认这一条，
## 默认焦点与焦点还原就会把一次注定失败的落点当成成功。
static func focusable(p_node: Variant) -> bool:
	if not inside_tree(p_node):
		return false
	var control: Control = p_node
	return control.is_visible_in_tree() and not is_stopped(p_node) \
			and control.focus_mode != Control.FOCUS_NONE


## 组内首个可用控件（无则 null）。
static func first_control(p_nodes: Array) -> Control:
	for node: Variant in p_nodes:
		if inside_tree(node):
			return node as Control
	return null


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 竖向邻居（手牌 ↔ 底栏；撤退回到手牌末张；追加站接到底栏首个动作）。[br]
## [br][b]为什么手牌的上下都指行囊[/b]：手牌区在屏幕下方、底栏贴着屏幕底缘，
## 「往下走」在玩家心里就是「去底部条」；行囊是底栏里最靠左的动作按钮，也是从
## 手牌区垂直落下去最近的一个。[br]
## [br][b]为什么行囊的上方是末张手牌而不是首张[/b]：玩家从行囊往上退，落到离它
## 最近的那张（弧形排布里最右的末张）比落到整个手牌区最左边更符合空间直觉。[br]
## [br][b]追加站往下接底栏[/b]：日志入口在屏幕左上、底栏在屏幕底部——竖向通道
## 与手牌一致（玩家从日志往下走，落到回合动作上）。
static func _verticals(p_cards: Array, p_bar: Array, p_retreat: Control,
		p_extra: Array = []) -> void:
	var hub: Control = first_control(p_bar)
	var anchor: Control = p_cards[p_cards.size() - 1] if not p_cards.is_empty() else null
	for card: Variant in p_cards:
		if inside_tree(card) and not is_stopped(card):
			set_verticals(card, hub, hub)
	for button: Variant in p_bar:
		if inside_tree(button) and not is_stopped(button):
			set_verticals(button, anchor, null)
	if inside_tree(p_retreat) and not is_stopped(p_retreat):
		set_verticals(p_retreat, null, anchor)
	for node: Variant in p_extra:
		if inside_tree(node) and not is_stopped(node):
			set_verticals(node, null, hub)


## 上下邻居（[param p_up] / [param p_down] 为 null 时自指）。
static func set_verticals(p_node: Control, p_up: Control, p_down: Control) -> void:
	p_node.focus_neighbor_top = path_to(p_node, p_up)
	p_node.focus_neighbor_bottom = path_to(p_node, p_down)


## Tab 前后（相对 [NodePath]——须同处一棵场景树，未入树时跳过）。
static func _set_pair(p_node: Control, p_next: Control, p_prev: Control) -> void:
	p_node.focus_next = path_to(p_node, p_next)
	p_node.focus_previous = path_to(p_node, p_prev)


## 左右邻居（横向走链——首尾自指，不环绕）。
static func _set_sides(p_node: Control, p_left: Control, p_right: Control) -> void:
	p_node.focus_neighbor_left = path_to(p_node, p_left)
	p_node.focus_neighbor_right = path_to(p_node, p_right)


## 目标路径（null / 不在树 / 非 Control / 即自身 → 自指）。[br]
## [br][b]相对路径须同树[/b]：[method Node.get_path_to] 跨树会给出不可用的路径，
## 故未入树时直接回落到自指，不留下一个指向别处的坏路径。
static func path_to(p_node: Control, p_target: Control) -> NodePath:
	if not inside_tree(p_target) or p_target == p_node:
		return p_node.get_path_to(p_node)
	return p_node.get_path_to(p_target)
