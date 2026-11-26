class_name NodeMoveInteractor
extends "res://src/ui/exploration/node_move_interactor_route.gd"
## NodeMoveInteractor —— 节点移动交互组件（exploration-ui Story S17-005）。
##
## [b]职责[/b]：节点图的点击/键盘移动委托、失败反馈、连续点击缓冲、到达通知转发。
## 不持有任何游戏状态（ADR-0031 §2 零状态所有权），渲染快照经
## [method apply_snapshot] 注入（map_generated 信号重建）。[br]
## [br][b]委托流[/b]（ADR-0014 §决策 3 + story B4 裁决）：点击节点 →
## [b]一律提交[/b] [code]ExplorationSystem.move_to_node(current, clicked)[/code]
## ——UI 零预判可达性（control-manifest Forbidden：防 UI 与系统判定漂移）；
## 失败 reason 由系统返回驱动 toast 文案 + 节点抖动。[br]
## [br][b]AC-7 锁定[/b]：移动动画期间新点击入 [member _click_buffer] 缓冲队列
## （同目标去重），动画完成后依序提交。[br]
## [br][b]到达通知时序[/b]（B4「先移动后弹窗」）：系统到达信号在动画进行中即到
## ——载荷暂存 [member _pending_arrival]，动画完成后统一转发（006/007 消费点）。[br]
## [br][b]职责拆分[/b]：overlay 与动画归 [NodeMoveAnimator]，键盘寻路归
## [NodeKeyboardNavigator]，悬停放大与焦点环归 [NodeGraphRenderer]（单一视觉
## 来源，ADR-0031 §4）；本组件只做交互编排。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]——gui_input/信号/未处理键输入驱动；
## Tween 为输入驱动的纯视觉变换（ADR-0031 §3 豁免）。
##
## 来源: story-005-node-move-interaction.md、ADR-0031 §2/§3/§4、
## ADR-0014 §决策 3 委托流程、control-manifest §Presentation、
## design/ux/exploration-ui.md Interaction Map / Events Fired。

## === 生命周期（宿主挂载 / 拆除 / 快照注入）===========================

## 绑定渲染器与探索系统（宿主挂载时调用）。[br]
## [b]幂等[/b]：重复调用先 [method teardown] 清理旧连接与 overlay，不产生双绑。[br]
## [param p_renderer]: 渲染器（NodeGraphRenderer）。[br]
## [param p_system]: 探索系统（测试注入 mock，生产传 Autoload）。
func setup(p_renderer: Control, p_system: Node) -> void:
	teardown()
	renderer = p_renderer
	exploration_system = p_system
	# 交互组件自身不接收鼠标——输入全部经 renderer.gui_input（不遮蔽节点命中）
	mouse_filter = MOUSE_FILTER_IGNORE
	# 键盘路径（A3）——方向键/Enter 走未处理输入
	set_process_unhandled_key_input(true)
	_animator = Animator.new(self, renderer)
	_animator.reduce_motion = _reduce_motion
	if renderer != null and not renderer.gui_input.is_connected(_on_renderer_input):
		renderer.gui_input.connect(_on_renderer_input)
	_bind_system_signals()


## 断开外部连接并清理 overlay（幂等——重复 setup / 对象释放时调用）。[br]
## [b]瞬态状态复位[/b]（终审 M1）：[member _animator.clear] 杀死 Tween 后
## 其完成回调不再触发，若不复位 [member _animating] 则后续点击永久入缓冲；
## 暂存到达通知同理不得跨重建存活。
func teardown() -> void:
	_animating = false
	_pending_arrival = Callable()
	_click_buffer.clear()
	if exploration_system != null and is_instance_valid(exploration_system):
		for entry: Array in _bound_signals:
			var signal_name: StringName = entry[0]
			var handler: Callable = entry[1]
			if exploration_system.has_signal(signal_name) \
					and exploration_system.is_connected(signal_name, handler):
				exploration_system.disconnect(signal_name, handler)
	_bound_signals.clear()
	if renderer != null and is_instance_valid(renderer) \
			and renderer.gui_input.is_connected(_on_renderer_input):
		renderer.gui_input.disconnect(_on_renderer_input)
	if _animator != null:
		_animator.clear()
		_animator = null


## 设置动画偏好（reduce_motion 直跳终位——hand_area 先例）。[br]
## [b]setup 前后均可设置[/b]：值保存在自身，setup 时下发给动画编排器。
func set_reduce_motion(value: bool) -> void:
	_reduce_motion = value
	if _animator != null:
		_animator.reduce_motion = value


## 注入渲染快照（map_generated / node_moved 重建——零状态所有权）。[br]
## [b]深拷贝[/b]：不与调用方共享引用（防 UI 原地写回污染系统侧快照，审查 M1）。
## 换图时复位键盘游标与缓冲队列（审查 L5）。
func apply_snapshot(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	_keyboard_node = -1
	_click_buffer.clear()
	_animating = false
	_sync_marker_to_current()


## 玩家标记同步到当前节点（快照注入/进入地图时）。
func _sync_marker_to_current() -> void:
	if _animator == null:
		return
	var current: int = int(_snapshot.get("current_node", -1))
	if current >= 0 and _snapshot.get("nodes", {}).has(current):
		_animator.sync_marker_to(current)
	else:
		_animator.hide_marker()


## 析构——断开外部连接并清理 overlay（组件重建不留残影，审查 M6）。
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		teardown()
