class_name CombatFocusChainApply
extends RefCounted
## CombatFocusChainApply —— 焦点链的「落定写侧」（CombatFocusChain 的施加一半）。[br]
##
## [b]职责[/b]：把链算好的可聚焦性真正落到控件上——[method set_modes] 批量写
## [member Control.focus_mode] 并挂焦点环、[method release_if_holding] 在控件退出
## 链时把焦点交还引擎、[method clear_wiring] 退场时擦掉本链设过的邻居路径。[br]
## [b]不管什么[/b]：不算邻居路径（归 [CombatFocusRing]）、不查控件（归
## [CombatFocusChainNodes]）、不决定谁该上场——本件只回答「按这个结论，怎么改」。[br]
## [br][b]为什么单独成文件[/b]：[code]combat_focus_chain.gd[/code] 拆出查询与几何后
## 仍超 300 行软上限（编码标准）——剩下的三件事正好是「读侧已走、只剩写侧」。[br]
## [br][b]为什么写侧要单独有个家[/b]：这三件事有一个共同的、容易出错的约束——
## 引擎不会替我们搬走焦点，也不会替我们跳过禁用项；把「施加」与「决策」分开，
## 谁能改控件这件事才有单一定义处。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：无成员变量，全部为纯函数（节点由调用方传入）。
##
## 来源: .claude/rules/ui-code.md（交互元素须支持键盘/鼠标/手柄）、ADR-0004 §双焦点、
## ADR-0031 §2、combat_focus_chain.gd（拆分——行数预算）。

## 焦点环几何（复用「能不能落焦点」判据——不在这里另写一份）。
const Ring: GDScript = preload("res://src/ui/combat/interaction/combat_focus_ring.gd")
## 焦点环样式（松石青粗边——与商店 / 卡组编辑面板同一份，禁止另写一套）。
const FocusStyle: GDScript = preload("res://src/ui/exploration/shop_panel_layout.gd")


## 批量落 [member Control.focus_mode]。[br]
## [br][b]开与关写的是同一个属性[/b]：离开出牌阶段时手牌与底栏动作一起退回
## [constant Control.FOCUS_NONE]（不是只挡默认焦点——不留任何可落点）。[br]
## [br]未入树的节点跳过（邻居与焦点只对树内控件有意义）。
static func set_modes(p_nodes: Array, p_play_ok: bool) -> void:
	for node: Variant in p_nodes:
		if not Ring.inside_tree(node):
			continue
		var control: Control = node
		control.focus_mode = Control.FOCUS_ALL if p_play_ok else Control.FOCUS_NONE
		# 焦点环随焦点自动绘制（引擎只在获得焦点时画）——幂等：只覆盖同一个键
		if p_play_ok and control is Button:
			FocusStyle.apply_focus_ring(control as Button)


## 焦点是否落在给定控件上——是则释放（停用 / 离开出牌阶段时把焦点交还给引擎）。[br]
## [br][b]为什么要主动释放[/b]：焦点停在一个 [constant Control.FOCUS_NONE] 的控件上时，
## 引擎不会自动搬走它；玩家按 Tab 时又因该控件已不在链上而按几何自推乱跳。[br]
## [br][b]只释放「真的被停用」的那批[/b]：敌方回合里手牌与底栏动作退出焦点，
## 但撤退与日志入口仍可聚焦（GDD §10 撤退常驻；日志正是敌方回合最该读的东西）
## ——把整条链一起清空会让那些还亮着的控件也丢焦点。[br]
## [br][b]当前持有者由调用方现读传入[/b]：焦点不属于链的状态（ADR-0031 §2），
## 本件不缓存它。
static func release_if_holding(p_nodes: Array, p_owner: Control) -> void:
	if p_owner == null:
		return
	if p_nodes.has(p_owner):
		p_owner.release_focus()


## 当前键盘/手柄焦点持有者（未入树 / 无焦点时为 null）。[br]
## [br][b]为什么不缓存[/b]：焦点是引擎的状态（ADR-0031 §2），任何时刻现读一次
## 都比记一份靠谱——玩家的一次 Tab 就会让它失效。[br]
## [br][b]为什么在写侧[/b]：本件所有动作都以「焦点现在归谁」为前提——
## 现读与落点放在同一处，才不会有第二个地方也去问一遍。
static func current_owner() -> Control:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.gui_get_focus_owner()


## 落默认焦点。[br]
## [br][b]为什么优先手牌而不是底栏按钮[/b]：出牌阶段玩家要做的第一件事是出牌，
## 焦点落在第一张手牌上意味着「进战斗就能按回车出牌」；底栏按钮是兜底——
## 手牌为空（全打完或开局没抽到）时玩家唯一能做的是结束回合。[br]
## [br][b]返回[/b]：是否真的落到了某个控件上（无可聚焦者时为 false——如实报告，
## 不假装成功）。
static func grab_default(p_cards: Array, p_bar: Array) -> bool:
	for card: Variant in p_cards:
		if Ring.focusable(card):
			(card as Control).grab_focus()
			return true
	for button: Variant in p_bar:
		if Ring.focusable(button):
			(button as Control).grab_focus()
			return true
	return false


## 清除给到的控件的全部邻居路径（退场用——不留指向已释放节点的路径）。[br]
## [br][b]清空而不是自指[/b]：自指是「到此为止」的活链语义（[method CombatFocusRing.pin]），
## 退场要的是「当作本链没来过」——留下自指会让下一次进战斗的几何自推从这些节点起失效。
static func clear_wiring(p_nodes: Array) -> void:
	for node: Variant in p_nodes:
		if Ring.inside_tree(node):
			Ring.clear(node as Control)
