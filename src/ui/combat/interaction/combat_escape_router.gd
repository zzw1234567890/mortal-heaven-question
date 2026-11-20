extends Node
## CombatEscapeRouter —— 战斗内 Esc「退一层」路由（.claude/rules/ui-code.md 双输入）。[br]
## [br][b]职责[/b]：把 Esc 按「从最上面一层往下退」的次序解析——[br]
##   1. 撤退确认弹窗开着 → 关它（等价于点「继续战斗」，不撤退）；[br]
##   2. 渡劫战前警示开着 → 关它（等价于点取消）；[br]
##   3. 手里已选中一张卡 → 取消选中（[code]CombatPlayFlow.cancel[/code] 的文档
##      一直写着「点空白 / 右键 / ESC：取消选中」，此前 ESC 这一条从未接线）；[br]
##   4. [b]以上都没有 → 什么都不做，事件原样放行[/b]。[br]
## [br][b]为什么不消费最后一档[/b]：没有可退的层时 Esc 该归暂停菜单
## （[code]InputManager._input[/code] → [code]pause_requested[/code]）——本节点只
## 在真的退掉了一层时 [method Viewport.set_input_as_handled]，不打乱既有暂停语义。[br]
## [br][b]为什么走 [method Node._input] 而不是 [method Node._unhandled_input][/b]：
## 焦点落在 [Button] 上时引擎的内置焦点导航会在 GUI 阶段先吃掉按键；[code]_input[/code]
## 排在 GUI 派发之前，是唯一能稳定拦住的层（先例：[code]combat_bag_screen.gd[/code]）。[br]
## [br][b]行囊面板不在这里管[/b]：它自己接 [code]_input[/code] 并消费 Esc（导航器
## 的 [code]ui_cancel[/code] → [code]closed[/code] → 宿主 [code]close[/code]，
## 顺带解冻出牌输入）——重复接管会让关闭路径有两条。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：弹窗开合与选中态全部现读，本节点不缓存。
##
## 来源: design/ux/hud.md（Esc 层级退出）、ADR-0004、combat-ui-interaction、
## 先例 [code]combat_bag_screen.gd[/code] 的「事件层级 = _input」。

## 战场门面（[code]CombatLayout[/code]——取结算宿主与交互层）。
var _layout: Control = null


## 注入门面（场景接线在交互层装配后调用一次）。
func bind(p_layout: Control) -> void:
	_layout = p_layout
	name = "CombatEscapeRouter"


## 退出路由（按层退——退掉一层即消费事件）。[br]
## [br][b]返回[/b]：是否退掉了一层（测试探针；false = 事件已放行给暂停菜单）。
func route() -> bool:
	if _bag_open():
		return false
	if _close_retreat_dialog():
		return true
	if _close_tribulation_warning():
		return true
	if _cancel_selection():
		return true
	return false


## 输入事件——只吃 Esc 按下（[code]echo[/code] 重复事件不吃：按住不该连退多层）。
func _input(p_event: InputEvent) -> void:
	if _layout == null or not is_instance_valid(_layout):
		return
	if not (p_event is InputEventKey):
		return
	var key: InputEventKey = p_event
	if key.keycode != KEY_ESCAPE or not key.pressed or key.echo:
		return
	if not is_inside_tree():
		return
	if not get_viewport().is_input_handled() and route():
		get_viewport().set_input_as_handled()


# ═══════════════════════════════════════════════════════════════════════════════
# 内部：逐层退
# ═══════════════════════════════════════════════════════════════════════════════

## 撤退确认弹窗 → 走「继续战斗」那条生产出口（发出
## [signal RetreatDialog.retreat_cancelled]，不做持久写入）。[br]
## [br][b]为什么发按钮的 pressed 而不是直调 [code]close_dialog[/code][/b]：
## 直调只关面板不发信号，上层（结算宿主 → 场景容器）就收不到「玩家放弃撤退」
## ——同一件事留两条路径，迟早只走通一条。
func _close_retreat_dialog() -> bool:
	var dialog: Variant = _panel(&"retreat_dialog")
	if dialog == null or not bool(dialog.call(&"is_showing")):
		return false
	var cancel: Variant = (dialog as Object).get(&"cancel_button")
	if cancel is Button:
		(cancel as Button).emit_signal(&"pressed")
		return true
	return false


## 渡劫战前警示 → 关它（等价于点取消）。[br]
## [br][b]为什么这一层允许 Esc 退[/b]：它是「要不要打这一场」的确认，玩家退掉
## 等于「先不打」，与撤退确认同性质；而战利品选择不退（选完才往下走，
## 退掉会让战斗停在半路）。
func _close_tribulation_warning() -> bool:
	var dialog: Variant = _panel(&"tribulation_warning")
	if dialog == null or not bool(dialog.call(&"is_showing")):
		return false
	var cancel: Variant = (dialog as Object).get(&"cancel_button")
	if cancel is Button:
		(cancel as Button).emit_signal(&"pressed")
		return true
	return false


## 已选中的手牌 → 取消选中（[code]CombatPlayFlow.cancel[/code]——幂等，未选中时为空操作）。
func _cancel_selection() -> bool:
	var flow: Variant = _flow()
	if flow == null:
		return false
	var controller: Variant = flow.call(&"get_controller")
	if controller == null:
		return false
	if int(controller.call(&"get_selected_card_id")) < 0:
		return false
	flow.call(&"cancel")
	return true


## 结算宿主上的某个子面板（宿主 / 面板缺失为 null）。
func _panel(p_property: StringName) -> Variant:
	if _layout == null:
		return null
	var host: Variant = _layout.get(&"settlement_host")
	if host == null or not is_instance_valid(host):
		return null
	var panel: Variant = (host as Object).get(p_property)
	return panel if panel != null and is_instance_valid(panel) else null


## 出牌手势语义实例（交互层未装配为 null）。
func _flow() -> Variant:
	if _layout == null:
		return null
	var interaction: Variant = _layout.call(&"interaction")
	if interaction == null or not (interaction as Object).has_method(&"get_input_layer"):
		return null
	var input: Variant = interaction.call(&"get_input_layer")
	if input == null or not (input as Object).has_method(&"get_flow"):
		return null
	return input.call(&"get_flow")


## 行囊面板是否开着。[br]
## [br][b]为什么它排在最前面[/b]：行囊自己就接 [code]_input[/code] 并消费 Esc
## （关面板 + 解冻出牌输入）。本节点若也判一次，同一次 Esc 会被两层各退一步
## ——「关行囊」与「取消选中」一起发生，玩家看到的是一次按键两个后果。[br]
## [br][b]按节点名找而不是按属性[/b]：行囊面板挂在战场根上（[code]CombatBagHost[/code]
## 挂载），交互接线不持它的句柄；名字由该组件自己钉住（[code]CombatBagScreen[/code]）。
func _bag_open() -> bool:
	if _layout == null:
		return false
	var panel: Node = _layout.find_child("CombatBagScreen", true, false)
	if panel == null or not (panel is Control):
		return false
	return (panel as Control).visible
