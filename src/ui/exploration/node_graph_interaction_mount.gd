extends RefCounted
## NodeGraphInteractionMount —— 节点图交互组件的挂载与信号接线（从 NodeGraphScreen 拆出）。[br]
## [br][b]为什么单独一处[/b]：屏幕脚本已超 300 行软上限，而「挂哪些组件、怎么接线」
## 与「收到快照怎么画」是两件事——后者才是屏幕的职责。[br]
## [br][b]组件[/b]：[NodeMoveInteractor]（点击/键盘移动、失败反馈）、
## [NodeTutorialOverlay]（首次进入 3 步教程）、[NodeInteractionPopupHost]
## （节点交互弹窗）。[br]
## [br][b]转发方向[/b]：组件的到达通知经屏幕传入的 [param p_forward] 回调转发
## （审查 H3——后续 story 只连屏幕公开信号，不依赖私有成员），同时进弹窗宿主；
## 事件节点显式排除（EventSystem 事件面板接管，防双面板）。[br]
## [br][b]不持有游戏状态[/b]：本模块只建节点与连信号，状态全部在快照里
## （ADR-0031 §2）。[br]
## [br]来源: story-005-node-move-interaction.md、story-006-node-interaction-popups.md、
## ADR-0031 §2/§4。

## NodeMoveInteractor 脚本常量（class_name 在 headless 动态加载下不可靠）。
const NodeMoveInteractorScript := preload("res://src/ui/exploration/node_move_interactor.gd")
## NodeTutorialOverlay 脚本常量。
const NodeTutorialOverlayScript := preload("res://src/ui/exploration/node_tutorial_overlay.gd")
## NodeInteractionPopupHost 脚本常量。
const NodeInteractionPopupHostScript := preload(
		"res://src/ui/exploration/node_interaction_popup_host.gd")

## 转发回调键——屏幕侧提供，本模块只负责把组件信号接过去。
const KEY_MOVE_FEEDBACK: StringName = &"move_feedback"
const KEY_KEYBOARD_FOCUS: StringName = &"keyboard_focus"
const KEY_COMBAT_ARRIVAL: StringName = &"combat_arrival"
const KEY_BOSS_ARRIVAL: StringName = &"boss_arrival"
const KEY_NODE_INTERACTION: StringName = &"node_interaction"

## 交互组件（点击委托/失败反馈/移动动画/键盘路径）。
var interactor: Control = null
## 教程覆盖组件（首次进入 3 步提示）。
var tutorial: Control = null
## 节点交互弹窗宿主（分发表路由/节点图冻结/背景模糊）。
var popup_host: Control = null


## 挂载三个组件并完成接线。[br]
## [br][param p_host] 屏幕（组件挂载宿主）。[br]
## [param p_renderer] 节点图渲染器。[br]
## [param p_viewport] 缩放平移容器（弹窗冻结用）。[br]
## [param p_system] 探索系统（移动命令/到达信号源，可空）。[br]
## [param p_reduce_motion] 减少动态偏好。[br]
## [param p_forward] 转发回调表（见 [constant KEY_MOVE_FEEDBACK] 等键）。[br]
## [param p_scene_manager] 场景管理器（开战转场，可空）。[br]
## [param p_realm_system] 境界系统（渡劫判定，可空）。[br]
func mount(p_host: Control, p_renderer: Control, p_viewport: Control, p_system: Node,
		p_reduce_motion: bool, p_forward: Dictionary, p_scene_manager: Node = null,
		p_realm_system: Node = null) -> void:
	_mount_interactor(p_host, p_renderer, p_system, p_reduce_motion, p_forward)
	tutorial = NodeTutorialOverlayScript.new()
	tutorial.name = "NodeTutorialOverlay"
	p_host.add_child(tutorial)
	_mount_popup_host(p_host, p_renderer, p_viewport, p_system,
			p_reduce_motion, p_scene_manager, p_realm_system)


## 挂载移动交互组件——绑定 renderer 与探索系统（依赖注入，测试可先注入 mock）。[br]
## [b]到达通知转发[/b]（审查 H3）：经 [param p_forward] 交给屏幕，屏幕再发公开信号。
func _mount_interactor(p_host: Control, p_renderer: Control, p_system: Node,
		p_reduce_motion: bool, p_forward: Dictionary) -> void:
	interactor = NodeMoveInteractorScript.new()
	interactor.name = "NodeMoveInteractor"
	p_host.add_child(interactor)
	interactor.setup(p_renderer, p_system)
	interactor.set_reduce_motion(p_reduce_motion)
	interactor.move_feedback_requested.connect(
			_forward(p_forward, KEY_MOVE_FEEDBACK))
	interactor.keyboard_focus_changed.connect(
			_forward(p_forward, KEY_KEYBOARD_FOCUS))
	interactor.combat_arrival_forwarded.connect(
			_forward(p_forward, KEY_COMBAT_ARRIVAL))
	interactor.boss_arrival_forwarded.connect(
			_forward(p_forward, KEY_BOSS_ARRIVAL))
	interactor.node_interaction_forwarded.connect(
			_forward(p_forward, KEY_NODE_INTERACTION))


## 挂载节点交互弹窗宿主（S17-006）——消费交互组件的到达信号派发弹窗。[br]
## [b]事件节点显式排除[/b]（AC-9）：不连 [code]event_node_reached[/code]。[br]
func _mount_popup_host(p_host: Control, p_renderer: Control, p_viewport: Control,
		p_system: Node, p_reduce_motion: bool, p_scene_manager: Node,
		p_realm_system: Node) -> void:
	popup_host = NodeInteractionPopupHostScript.new()
	popup_host.name = "NodeInteractionPopupHost"
	p_host.add_child(popup_host)
	popup_host.setup(p_renderer, p_viewport, p_system, p_scene_manager, p_realm_system)
	popup_host.set_reduce_motion(p_reduce_motion)
	# 交互节点到达（商店/灵泉/回复/渡劫台——战斗/精英走 combat_node_reached）
	interactor.node_interaction_forwarded.connect(
			func(nid: int, itype: StringName, payload: Dictionary) -> void:
				popup_host.on_node_interaction(nid, itype, payload))
	# 战斗/精英到达（B4 先移动后弹窗——载荷由交互组件在动画后转发）
	interactor.combat_arrival_forwarded.connect(
			func(roster: Array, ctype: StringName) -> void:
				popup_host.on_combat_arrival(roster, ctype))
	# 弹窗期间冻结键盘路径（鼠标/缩放平移由宿主经视口 input_frozen 冻结）
	popup_host.popup_opened.connect(func(_nid: int, _kind: StringName) -> void:
		if interactor != null:
			interactor.set_process_unhandled_key_input(false))
	# 关闭弹窗时回到节点图焦点（键盘路径恢复）
	popup_host.popup_closed.connect(func(_nid: int, _kind: StringName) -> void:
		if interactor != null:
			interactor.set_process_unhandled_key_input(true))


## 取转发回调——未注入时返回空 Callable（组件信号接了空回调不报错，
## 降级环境不因缺回调崩溃）。
func _forward(p_forward: Dictionary, p_key: StringName) -> Callable:
	var cb: Variant = p_forward.get(p_key)
	return cb if cb is Callable else Callable()
