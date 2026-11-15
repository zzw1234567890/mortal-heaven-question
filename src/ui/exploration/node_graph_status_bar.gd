extends RefCounted
## NodeGraphStatusBar —— 节点图顶栏状态区：行动力显示 / 走投无路提示 / 退出探索。[br]
##
## [b]为什么单独一处[/b]：[code]node_graph_screen.gd[/code] 已贴 300 行软上限
## （.claude/docs/coding-standards.md），而「顶栏显示什么、退出怎么走」与
## 「收到快照怎么画节点」是两件事——后者才是屏幕的职责（同
## [code]node_graph_load_source.gd[/code] / [code]node_graph_component_assembly.gd[/code]
## 的拆分先例）。[br]
##
## [b]为什么退出要有确认[/b]：GDD exploration-system.md §AC（「点击退出探索按钮，
## WHEN 确认退出，THEN 保留已获资源，地图保持未通关，回到地图选择界面」）写的就是
## 两步。退出虽不损失已获资源（[code]EndReason.PLAYER_QUIT[/code] 与
## [code]AP_DEPLETED[/code] 结算相同），但会放弃通关奖励与首次通关奖励——误触的
## 代价是整局白跑。[br]
##
## [b]「走投无路」提示只陈述事实[/b]：行动力不足以抵达 Boss 时提示玩家，
## [b]不代替玩家做决定[/b]（GDD §8：主动退出按钮始终可用）。判定由系统的只读查询
## [code]can_still_reach_boss[/code] 作答——UI 不自行推导（本图 [code]ap_cost[/code]
## 与豁免规则都在 Feature 层）。[br]
##
## [b]输入锁（ADR-0004）[/b]：按下与确认都要过
## [code]InputManager.is_input_allowed(GAMEPLAY, MOUSE)[/code]——退出会结算并清空
## 导航状态，属于「改变游戏状态」的操作。InputManager 不可用（headless / 早期
## 启动）时放行，与 [code]MapSelectData.input_allowed[/code] /
## [code]NodeMoveInteractor._is_input_allowed[/code] 同口径。[br]
##
## [b]零状态所有权[/b]（ADR-0031 §2）：只读快照与系统的只读查询；结算
## （[code]ExplorationSystem.end_exploration[/code]）由宿主经 [param p_on_exit]
## 回调转发给 Feature 层——本模块不写任何游戏状态。[br]
##
## 来源: design/gdd/exploration-system.md §5 结束条件 / §8 边界 / AC「退回地图选择」、
## design/gdd/action-point-system.md §4 UI（行动力条）、ADR-0004、ADR-0031 §2。

## 六态分类器——[constant EXEMPT_TYPES] 的数值来源（UI 层副本，headless 可得）。
const NodeStateLogicScript := preload("res://src/ui/exploration/node_state_logic.gd")
## InputManager 枚举真理来源（ActionType / DeviceType）。
const InputManagerScript := preload("res://src/foundation/input_manager.gd")

## 行动力标签前缀——格式 [code]AP: N[/code]（GDD action-point-system.md §4
## 「显示当前行动力/上限」；出厂文案由既有集成测试按 [code]AP: N[/code] 锁定）。
const TEXT_AP_PREFIX: String = "AP"

## 退出按钮文案——GDD exploration-system.md §8「探索HUD中始终显示『退出探索』按钮」。
const TEXT_EXIT: String = "退出探索"

## 「走投无路」提示文案——两种事实分开陈述（行动力见底 / 见底前已走不到）。
const TEXT_AP_EMPTY: String = "行动力已耗尽，无法抵达 Boss"
const TEXT_AP_INSUFFICIENT: String = "行动力不足以抵达 Boss"

## AP=0 豁免节点类型（Boss/传送/灵泉）——站在这些节点上时不下「走投无路」的断语。[br]
## [br][b]为什么[/b]：三者各自都是一条出路（已在终点 / 免费跳转 / 回复全部行动力），
## 而图上的最短路只算移动开销、看不见「站在这眼泉上还能回一口血」——此时提示
## 「无法抵达 Boss」是冤枉玩家的。复用六态分类器同一份豁免集合（不另立一份）。
const EXEMPT_TYPES: Array = NodeStateLogicScript.AP_EXEMPT_TYPES


## 宿主（屏幕）——通知与 Autoload 查找的锚点。
var _host: Node = null
## 行动力标签（既有节点路径 [code]TopBar/APLabel[/code] 不变——测试按该路径读）。
var _ap_label: Label = null
## 退出按钮（[code]TopBar/ExitButton[/code]）。
var _exit_button: Button = null
## 走投无路提示标签（[code]TopBar/StatusLabel[/code]；无提示时隐藏）。
var _status_label: Label = null
## 退出确认弹窗（[code]ExitDialog[/code]；null 时按下即退出——headless 单测路径）。
var _confirm: Window = null
## 退出意图回调（宿主转发给 Feature 层；无效时只记录告警）。
var _on_exit: Callable = Callable()

## 探索系统（只读查询源）——每轮刷新前由宿主经 [method bind_system] 更新。
var _system: Node = null
## 本份快照是否出自真实系统（stub / 直调路径下不查询系统判定——见类文档）。
var _from_system: bool = false

## 输入锁判定注入（测试可替换）。无效时按 [code]/root/InputManager[/code] 查找。
var input_allowed_cb: Callable = Callable()


## 绑定控件（一次性——宿主在首次刷新前调用）。[br]
## [br][param p_host] 宿主屏幕（Autoload 查找锚点）。[br]
## [param p_ap_label] 行动力标签。[br]
## [param p_exit_button] 退出按钮（文案由本模块设为 [constant TEXT_EXIT]）。[br]
## [param p_status_label] 走投无路提示标签（可 null——无提示位时只更新行动力）。[br]
## [param p_confirm] 退出确认弹窗（可 null——按下即退出）。[br]
## [param p_on_exit] 退出意图回调（宿主转发）。
func bind(p_host: Node, p_ap_label: Label, p_exit_button: Button,
		p_status_label: Label, p_confirm: Window, p_on_exit: Callable) -> void:
	_host = p_host
	_ap_label = p_ap_label
	_exit_button = p_exit_button
	_status_label = p_status_label
	_confirm = p_confirm
	_on_exit = p_on_exit
	if _exit_button != null:
		_exit_button.text = TEXT_EXIT
		if not _exit_button.pressed.is_connected(_on_exit_pressed):
			_exit_button.pressed.connect(_on_exit_pressed)
	if _confirm != null and not _confirm.confirmed.is_connected(_on_exit_confirmed):
		_confirm.confirmed.connect(_on_exit_confirmed)


## 按节点路径绑定顶栏控件（宿主屏幕的一行装配入口）。[br]
## [br][b]为什么节点路径写在这里[/b]：顶栏有哪几个控件是本模块的事——
## 屏幕只需说「把顶栏挂上、退出时调我」。[br]
## [br][param p_host] 宿主屏幕（控件查找起点）。[br]
## [param p_on_exit] 退出意图回调。[br]
## [br][b]返回[/b]：已绑定的状态区（控件缺失的位置按 null 传入——见 [method bind]）。
static func mount(p_host: Control, p_on_exit: Callable) -> RefCounted:
	var bar: RefCounted = new()
	bar.call(&"bind", p_host,
			p_host.get_node_or_null(NodePath("TopBar/APLabel")),
			p_host.get_node_or_null(NodePath("TopBar/ExitButton")),
			p_host.get_node_or_null(NodePath("TopBar/StatusLabel")),
			p_host.get_node_or_null(NodePath("ExitDialog")),
			p_on_exit)
	return bar


## 绑定只读查询源（每轮刷新前调用——快照出处会随数据源切换而变）。[br]
## [br][param p_system] 探索系统（可 null）。[br]
## [param p_from_system] 本轮快照是否出自该系统——stub 降级与测试直调的快照
## 不在系统缓存的那张图里，拿系统的判定去问会得到与画面无关的答案。[br]
func bind_system(p_system: Node, p_from_system: bool) -> void:
	_system = p_system
	_from_system = p_from_system


## 刷新顶栏——行动力数值 + 走投无路提示。[br]
## [br][param p_snapshot] 渲染快照（[code]ap_remaining[/code] / [code]nodes[/code] /
## [code]current_node[/code]）。[br]
func refresh(p_snapshot: Dictionary) -> void:
	var ap: int = int(p_snapshot.get("ap_remaining", 0))
	if _ap_label != null:
		_ap_label.text = "%s: %d" % [TEXT_AP_PREFIX, ap]
	if _status_label == null:
		return
	var text: String = warning_text(ap, can_reach_boss(p_snapshot))
	_status_label.text = text
	_status_label.visible = not text.is_empty()


## 「走投无路」提示文案（纯函数——提示有无与措辞可单测）。[br]
## [br][param p_ap] 剩余行动力。[br]
## [param p_can_reach] 是否还走得到 Boss。[br]
## [br][b]返回[/b]：走得到时空串（无提示）；走不到时按行动力是否见底分两种陈述。[br]
static func warning_text(p_ap: int, p_can_reach: bool) -> String:
	if p_can_reach:
		return ""
	return TEXT_AP_EMPTY if p_ap <= 0 else TEXT_AP_INSUFFICIENT


## 是否还走得到 Boss——问系统，不让 UI 自己推。[br]
## [br][b]不下断语的三种情形[/b]（一律按「还走得到」处理——宁可少提示也不误报）：[br]
##   1. 快照不出自系统（stub 降级 / 测试直调）——判定与画面无关；[br]
##   2. 系统未声明该查询（早期实情 / 测试桩）——问不出答案；[br]
##   3. 当前站在 AP 豁免节点上——见 [constant EXEMPT_TYPES]。[br]
func can_reach_boss(p_snapshot: Dictionary) -> bool:
	if not _from_system or _system == null:
		return true
	if not _system.has_method(&"can_still_reach_boss"):
		return true
	if _is_on_exempt_node(p_snapshot):
		return true
	return bool(_system.call(&"can_still_reach_boss"))


## 当前节点是否为 AP 豁免类型（Boss / 传送 / 灵泉）。
func _is_on_exempt_node(p_snapshot: Dictionary) -> bool:
	var nodes: Dictionary = p_snapshot.get("nodes", {})
	var current: int = int(p_snapshot.get("current_node", -1))
	var detail: Variant = nodes.get(current, {})
	if not (detail is Dictionary):
		return false
	return EXEMPT_TYPES.has(int((detail as Dictionary).get("type", -1)))


## 退出按钮按下——过输入锁后弹确认（无确认控件时直接退出）。[br]
## [br][b]确认弹窗已打开时忽略重复点击[/b]：连点两下不该叠出两个窗口。[br]
func _on_exit_pressed() -> void:
	if not is_input_allowed() or is_confirm_open():
		return
	if _confirm == null:
		_on_exit_confirmed()
		return
	_confirm.call(&"popup_centered")


## 确认退出——转发退出意图（结算与场景编排归 Feature 层，UI 不写状态）。
func _on_exit_confirmed() -> void:
	if _on_exit.is_valid():
		_on_exit.call()
		return
	push_warning("NodeGraphStatusBar: 退出意图无消费者，探索未结算")


## 确认弹窗是否打开（测试与幂等判定用）。
func is_confirm_open() -> bool:
	return _confirm != null and _confirm.visible


## 输入锁判定——注入优先，否则查 [code]/root/InputManager[/code]（缺失时放行）。
func is_input_allowed() -> bool:
	if input_allowed_cb.is_valid():
		return bool(input_allowed_cb.call())
	var im: Node = _autoload(&"InputManager")
	if im == null or not im.has_method(&"is_input_allowed"):
		return true
	return bool(im.call(&"is_input_allowed",
			InputManagerScript.ActionType.GAMEPLAY,
			InputManagerScript.DeviceType.MOUSE))


## Autoload 动态查找——宿主未进树 / headless 测试时返回 null（调用方降级）。
func _autoload(p_node_name: StringName) -> Node:
	if _host == null:
		return null
	return _host.get_node_or_null(NodePath("/root/%s" % p_node_name))
