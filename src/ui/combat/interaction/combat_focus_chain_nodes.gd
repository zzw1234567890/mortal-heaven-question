class_name CombatFocusChainNodes
extends RefCounted
## CombatFocusChainNodes —— 焦点链的「成员查询」件（CombatFocusChain 的取材一半）。[br]
##
## [b]职责[/b]：从战场门面（[code]CombatLayout[/code]）把链上的控件取出并成表——
## 手牌卡（弧形顺序）、底栏动作按钮（行囊 → 结束出牌，**取包装里的内层
## [Button] 本体**）、撤退按钮、日志入口（经 [CombatFocusLogLink] 转发），
## 再加上当前战斗阶段与「链成员全套」的拼装。[br]
## [b]不管什么[/b]：不设 [member Control.focus_mode]、不算邻居路径、不落/不释放焦点、
## 不判可聚焦性——那些是链与 [CombatFocusRing] 的决策；本件只回答「场上此刻有谁」。[br]
## [br][b]为什么单独成文件[/b]：[code]combat_focus_chain.gd[/code] 的公开 API
## （默认焦点 / 阶段驱动 / 停用释放）与「控件从哪儿取」是两件事；合并后单文件超出
## 300 行软上限（同 [code]combat_focus_ring.gd[/code] /
## [code]combat_focus_sweeper.gd[/code] / [code]combat_focus_log_link.gd[/code]
## 的拆分先例）。[br]
## [br][b]桩门面安全[/b]：测试注入的门面桩可能没有某个属性，[method Object.get]
## 对不存在的属性返回 null（不报错），下面一律降级为空 / null。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：控件引用是渲染节点，阶段现读战斗系统；
## [b]零轮询[/b]：无 [code]_process()[/code]，全部由调用方在阶段信号 / 手牌重建 /
## 日志开合时现取。
##
## 来源: ADR-0031 §2、.claude/rules/ui-code.md（交互元素须支持键盘/鼠标/手柄）、
## combat_focus_chain.gd（拆分——行数预算，编码标准「单文件 ≤300 行」）。

## 战场门面（[code]CombatLayout[/code]——取手牌区 / 底栏 / 撤退按钮 / 顶栏）。
var _layout: Control = null
## 战斗系统（阶段现读）。
var _combat: Node = null
## 日志入口连接件（链在 [method CombatFocusChain.bind] 建好后交给本件）。
var _log_link: RefCounted = null


## 构造——注入门面与战斗系统。
func _init(p_layout: Control, p_combat: Node) -> void:
	_layout = p_layout
	_combat = p_combat


## 换上日志入口连接件（链重建时调用——见 [member _log_link]）。[br]
## [br][b]为什么由外部塞进来[/b]：连接件持订阅状态（退订要按同一实例），
## 归属是链；本件只是查询时借它的 [method CombatFocusLogLink.nodes]。
func set_log_link(p_log_link: RefCounted) -> void:
	_log_link = p_log_link


## 门面与战斗系统（换门面 / 退场时链会一并置空——本件跟着失效）。
func has_layout() -> bool:
	return _layout != null and is_instance_valid(_layout)


## 手牌卡节点（弧形顺序——与视觉从左到右一致）。[br]
## [br][b]为什么按方法名问而不是记句柄[/b]：手牌区每次重建都换一批卡节点
## （快照条目不带节点），每次现问才拿得到当前这批。
func hand_cards() -> Array:
	var hand: Variant = node_of(&"hand_area")
	if hand == null or not (hand as Object).has_method(&"card_nodes"):
		return []
	var raw: Variant = (hand as Object).call(&"card_nodes")
	return raw if raw is Array else []


## 底栏动作按钮（行囊 → 结束出牌——按钮本体在包装控件里，见
## [code]CombatBottombar[/code] 的组件形态）。
func bar_buttons() -> Array:
	var buttons: Array = []
	var bar: Variant = node_of(&"combat_bottombar")
	if bar == null:
		return buttons
	for property: StringName in [&"bag_button", &"end_turn_button"]:
		var button: Control = inner_button(bar, property)
		if button != null:
			buttons.append(button)
	return buttons


## 右上角撤退按钮（常驻——链上唯一不受阶段限制的控件）。
func retreat_button() -> Control:
	var raw: Variant = node_of(&"retreat_button")
	return raw as Control if raw is Control else null


## 日志可聚焦节点——折叠按钮常驻；展开时追加面板滚动区（转发连接件）。[br]
## [br][b]为什么滚动区只在展开时入环[/b]：收起态它在树里但不可见——把它接进
## 环会让 Tab 的下一站指向一个看不见的控件（焦点跳进空面板，玩家以为界面坏了）。[br]
## [br][b]为什么日志入口要进链而不是靠几何自推[/b]：它此前全库无人接线
## （[code]pressed[/code] 空挂着），上一轮因此把它的 [member Control.focus_mode]
## 收成 [constant Control.FOCUS_NONE]——Tab 不再跳过去是好事，但键盘 / 手柄玩家
## 也就再也开不了日志。本轮按钮接上了开合（[method CombatLog.toggle]），
## 于是把它放进环首：它是信息入口，与「出牌 → 结束回合 → 撤退」那条动作三连分开。[br]
## [br][b]找站与订阅归 [CombatFocusLogLink][/b]：本件不持顶栏句柄，也不认识
## 「日志组件长什么样」——那些是连接件的职责。
func log_nodes() -> Array:
	if _log_link == null:
		return []
	var nodes: Variant = _log_link.call(&"nodes")
	return nodes if nodes is Array else []


## 链上控件清单（收拢的 [code]keep[/code] 名单——按 Tab 顺序，与
## [method CombatFocusRing.ring_order] 同一来源，避免两处各拼一份）。[br]
## [br][b]含日志开合按钮[/b]：它本轮进了环，收拢就不该再把它收掉
## （否则链上有它、收拢又清它，两条规则互相打架）。
func chain_nodes() -> Array:
	var keep: Array = hand_cards()
	keep.append_array(bar_buttons())
	var retreat: Control = retreat_button()
	if retreat != null:
		keep.append(retreat)
	keep.append_array(log_nodes())
	return keep


## 当前战斗阶段（战斗系统不可用 → -1）。
func current_phase() -> int:
	if _combat == null or not is_instance_valid(_combat) \
			or not _combat.has_method(&"get_current_phase"):
		return -1
	return int(_combat.call(&"get_current_phase"))


## 门面属性 → 节点（缺失 / 未装配为 null）。
func node_of(p_property: StringName) -> Variant:
	if not has_layout():
		return null
	var raw: Variant = _layout.get(p_property)
	return raw if raw is Object and is_instance_valid(raw) else null


## 包装控件内的 [Button] 本体（包装自身是 [Control]，点击归内层按钮）。[br]
## [br][b]直接取 [code]button[/code] 属性[/b]：包装是懒建的，没有稳定节点路径。
func inner_button(p_wrapper: Variant, p_property: StringName) -> Control:
	var wrapper: Variant = (p_wrapper as Object).get(p_property)
	if wrapper == null or not is_instance_valid(wrapper):
		return null
	if wrapper is Button:
		return wrapper as Button
	var inner: Variant = (wrapper as Object).get(&"button")
	return inner as Control if inner is Control else null
