class_name NodeMoveInteractor
extends Control
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

## === 依赖 ================================================================

## InputManager 脚本常量——ActionType/DeviceType 枚举真理来源。
const InputManagerScript := preload("res://src/foundation/input_manager.gd")
## 动画编排（overlay 生命周期 + Tween）。
const Animator := preload("res://src/ui/exploration/node_move_animator.gd")
## 键盘寻路纯函数。
const Navigator := preload("res://src/ui/exploration/node_keyboard_navigator.gd")
## NodeStateLogic 脚本常量——REACHABLE 枚举（去魔数）。
const NodeStateLogicScript := preload("res://src/ui/exploration/node_state_logic.gd")

## 方向键 → 方向向量映射（A3——数据表而非 if-elif 链）。
const KEY_DIRECTIONS: Dictionary = {
	KEY_UP: Vector2i(0, -1),
	KEY_DOWN: Vector2i(0, 1),
	KEY_LEFT: Vector2i(-1, 0),
	KEY_RIGHT: Vector2i(1, 0),
}

## === 固定文案（本地化豁免——S16/S17 各 story 同源口径，待 localization epic）====

const TEXT_AP_INSUFFICIENT: String = "行动力不足"
const TEXT_UNREACHABLE: String = "路径不可达"
const TEXT_MOVE_FAILED: String = "无法移动"
## 系统 reason → toast 文案映射表（数据驱动，非 if-elif 链）。
const REASON_TEXTS: Dictionary = {
	"行动力不足": TEXT_AP_INSUFFICIENT,
	"不可达": TEXT_UNREACHABLE,
	"已访问": "",  # AC-4：已访问静默无反应
	"DAG 缓存未就绪": TEXT_MOVE_FAILED,
	"GSM 不可用": TEXT_MOVE_FAILED,
}

## === 信号（转发层——006/007 弹窗消费点）===================================

signal combat_arrival_forwarded(enemy_roster: Array, combat_type: StringName)
signal boss_arrival_forwarded(boss_data: Dictionary)
signal node_interaction_forwarded(node_id: int, interaction_type: StringName, payload: Dictionary)
## 移动失败反馈（toast 文案 + 抖动目标节点——宿主转发到通知区域）。
signal move_feedback_requested(toast_text: String, node_id: int)
## 键盘焦点变化（宿主转发到渲染器焦点环——A3）。
signal keyboard_focus_changed(node_id: int)

## === 依赖注入（测试可替换）=================================================

## 探索系统引用——move_to_node 调用方 + 信号源（测试注入 mock）。
var exploration_system: Node = null
## 渲染器引用——点击命中检测（NodeGraphRenderer 契约：hit_test_any/states/
## get_node_position）。
var renderer: Control = null

## === 瞬态交互状态（ADR-0031 §2.1——不进存档，刷新即弃）====================

## 当前渲染快照（graph/nodes/visited/current_node/ap_remaining）。
var _snapshot: Dictionary = {}
## 点击缓冲队列（AC-7）。元素为 [code][node_id, device][/code]——
## [b]保留输入设备[/b]（审查 M4）：缓冲来自键盘时锁栈须按 KEYBOARD 判定
## （ADR-0004 双焦点独立），不能一律回落 MOUSE。
var _click_buffer: Array = []
## 移动动画进行中标记（缓冲判定依据）。
var _animating: bool = false
## 键盘焦点节点（-1 = 无——A3 游标）。
var _keyboard_node: int = -1
## 动画进行中暂存的到达通知（B4「先移动后弹窗」）。
var _pending_arrival: Callable = Callable()
## 动画编排器（overlay + Tween 生命周期——preload 常量构造，无 class_name 依赖）。
var _animator: RefCounted = null
## 减少动态偏好（setup 前也可设置——宿主/测试常先设后绑）。
var _reduce_motion: bool = false
## 已连接的系统信号（[signal_name, Callable]——teardown 幂等断开）。
var _bound_signals: Array = []

## === 初始化 ================================================================

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


## node_moved 信号处理（自绑定——组件自含；宿主勿重复转发，否则双重动画 +
## 缓冲队列双重消费）。[br][b]快照更新[/b]：信号载荷为真理来源（ADR-0031 §3）。
func _on_system_node_moved(from_node: int, to_node: int, ap_remaining: int) -> void:
	_snapshot["current_node"] = to_node
	_snapshot["ap_remaining"] = ap_remaining
	var visited: Array = (_snapshot.get("visited", []) as Array).duplicate()
	if not visited.has(to_node):
		visited.append(to_node)
	_snapshot["visited"] = visited
	_play_move_animation(from_node, to_node)


## === 点击路径（零预判委托——manifest Forbidden 红线）=======================

## 渲染器输入处理——左键点击命中节点 → 提交移动（一律委托系统判定）。
func _on_renderer_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var node_id: int = _hit_test(event.position)
		if node_id >= 0:
			request_move(node_id)
			accept_event()


## 请求移动到 [param node_id]——动画期间入缓冲队列，否则立即提交系统。[br]
## [param device]: 输入设备（鼠标 vs 键盘——锁栈按设备独立判定，ADR-0004）。
func request_move(node_id: int, device: int = InputManagerScript.DeviceType.MOUSE) -> void:
	if _animating:
		# 缓冲去重——同一目标重复入队会在移动后必然「不可达」（审查 M2）
		if not _has_buffered(node_id):
			_click_buffer.append([node_id, device])
		return
	_submit_move(node_id, device)


## 缓冲队列是否已含该目标（去重判定——队列元素为 [node_id, device]）。
func _has_buffered(node_id: int) -> bool:
	for entry: Array in _click_buffer:
		if int(entry[0]) == node_id:
			return true
	return false


## 提交移动到系统（唯一委托入口——零预判，不可达也提交）。
func _submit_move(node_id: int, device: int = InputManagerScript.DeviceType.MOUSE) -> void:
	if exploration_system == null or not exploration_system.has_method(&"move_to_node"):
		return
	if not _is_input_allowed(device):
		return
	var current: int = int(_snapshot.get("current_node", -1))
	var result: Dictionary = exploration_system.move_to_node(current, node_id)
	if bool(result.get("success", false)):
		_snapshot["ap_remaining"] = int(result.get("ap_remaining", 0))
		return
	_play_failure_feedback(str(result.get("reason", "")), node_id)


## === 失败反馈（系统 reason 驱动——AC-2）===================================

## 播放失败反馈——reason 映射 toast 文案 + 节点抖动。[br]
## [b]已访问静默[/b]（AC-4）：映射为空文案时不发任何反馈。
func _play_failure_feedback(reason: String, node_id: int) -> void:
	var toast: String = str(REASON_TEXTS.get(reason, TEXT_MOVE_FAILED))
	if toast.is_empty():
		return  # 已访问——静默无反应
	if _animator != null:
		_animator.play_shake(node_id)
	move_feedback_requested.emit(toast, node_id)


## === 移动动画（AC-1——node_moved 信号驱动）================================

## 播放标记移动动画；完成后翻转脉冲（AC-6）→ 转发暂存到达通知（B4）→ 推进缓冲。
func _play_move_animation(from_node: int, to_node: int) -> void:
	_animating = true
	if _animator == null:
		_finish_move_animation(to_node)
		return
	# 无快照（宿主早退——审查 H6）：本次直跳终位不播动画（不改写全局偏好）
	_animator.play_move(from_node, to_node,
			func() -> void: _finish_move_animation(to_node), _snapshot.is_empty())


## 移动动画完成——翻转脉冲 + 到达通知转发（B4）+ 消费缓冲队列（失败也推进）。
func _finish_move_animation(to_node: int) -> void:
	_animating = false
	if _animator != null:
		_animator.sync_marker_to(to_node)
		_animator.play_visited_flip(to_node)
	_flush_pending_arrival()
	if not _click_buffer.is_empty():
		var next: Array = _click_buffer.pop_front()
		_submit_move(int(next[0]), int(next[1]))


## === 键盘路径（A3——方向键空间跳转 + Enter 确认）==========================

## 未处理键盘输入——方向键跳转 / Enter 确认（A3 接通点）。[br]
## 走 unhandled（不抢焦点控件）；锁栈判定在 [method _submit_move] 内按
## KEYBOARD 设备独立执行（ADR-0004 双焦点）。
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: int = event.keycode
	if KEY_DIRECTIONS.has(key):
		if navigate_focus(KEY_DIRECTIONS[key]) >= 0:
			accept_event()
	elif key == KEY_ENTER or key == KEY_KP_ENTER:
		if _keyboard_node >= 0:
			confirm_keyboard_selection()
			accept_event()


## 方向键空间跳转——从游标（无则当前节点）按方向找最近可达节点。[br]
## [b]返回[/b]: 新焦点节点 ID（-1 = 无候选）。焦点环由 renderer 绘制。
func navigate_focus(dir: Vector2i) -> int:
	var nodes: Dictionary = _snapshot.get("nodes", {})
	if nodes.is_empty():
		return -1
	var origin: int = _keyboard_node if _keyboard_node >= 0 \
			else int(_snapshot.get("current_node", -1))
	var target: int = Navigator.find_target(dir, origin, nodes, _is_reachable_node)
	if target >= 0:
		_keyboard_node = target
		keyboard_focus_changed.emit(target)
	return target


## Enter 确认——提交键盘游标节点移动（等效点击——设备判定用 KEYBOARD）。
func confirm_keyboard_selection() -> void:
	if _keyboard_node >= 0:
		request_move(_keyboard_node, InputManagerScript.DeviceType.KEYBOARD)


## === 系统信号转发（到达通知——006/007 消费点）==============================

## 连接系统信号（is_connected 守卫——setup 幂等，审查 H4）。[br]
## [b]到达载荷暂存[/b]：移动动画进行中 → 暂存，动画结束才转发（B4——审查 H2）。
func _bind_system_signals() -> void:
	if exploration_system == null:
		return
	_connect_if_present(&"node_moved", _on_system_node_moved)
	_connect_if_present(&"combat_node_reached", _on_combat_reached)
	_connect_if_present(&"boss_node_reached", _on_boss_reached)
	_connect_if_present(&"node_interaction_triggered", _on_node_interaction)


func _on_combat_reached(roster: Array, combat_type: StringName) -> void:
	_defer_or_forward(func() -> void: combat_arrival_forwarded.emit(roster, combat_type))


func _on_boss_reached(boss_data: Dictionary) -> void:
	_defer_or_forward(func() -> void: boss_arrival_forwarded.emit(boss_data))


func _on_node_interaction(node_id: int, interaction_type: StringName, payload: Dictionary) -> void:
	_defer_or_forward(func() -> void:
		node_interaction_forwarded.emit(node_id, interaction_type, payload))


## 动画进行中暂存，否则立即转发（B4——移动完成先于弹窗触发）。
func _defer_or_forward(forward: Callable) -> void:
	if _animating:
		_pending_arrival = forward
		return
	forward.call()


## 触发暂存的到达通知（移动动画完成时）。
func _flush_pending_arrival() -> void:
	if not _pending_arrival.is_valid():
		return
	var pending: Callable = _pending_arrival
	_pending_arrival = Callable()
	pending.call()


## 按信号名连接（信号缺失时静默跳过——mock/真实系统均兼容；重复连接守卫）。
func _connect_if_present(signal_name: StringName, handler: Callable) -> void:
	if not exploration_system.has_signal(signal_name):
		return
	if exploration_system.is_connected(signal_name, handler):
		return
	exploration_system.connect(signal_name, handler)
	_bound_signals.append([signal_name, handler])


## === 内部辅助 ================================================================

## 输入锁栈判定（control-manifest 必需——改变游戏状态的点击必须过锁栈）。[br]
## [param device]: 输入设备（键盘 Enter 与鼠标点击独立判定，ADR-0004 双焦点）。
## InputManager 缺失（headless 测试/早期启动）时失败开放。
func _is_input_allowed(device: int) -> bool:
	var im: Node = get_node_or_null("/root/InputManager")
	if im == null or not im.has_method(&"is_input_allowed"):
		return true
	return bool(im.is_input_allowed(InputManagerScript.ActionType.GAMEPLAY, device))


## 点击命中检测——复用 renderer 公开命中（含 reveal_max_layer 可见性过滤，审查 M3）。
func _hit_test(point: Vector2) -> int:
	if renderer == null:
		return -1
	if renderer.has_method(&"hit_test_any"):
		return int(renderer.hit_test_any(point))
	var nodes: Dictionary = _snapshot.get("nodes", {})
	for node_id: int in nodes.keys():
		if renderer.hit_test_node(node_id, point):
			return node_id
	return -1


## 可达判定——仅可达态（NodeStateLogic.NodeState.REACHABLE）为键盘候选。[br]
## [b]契约守卫[/b]（终审 M2）：与 [method _hit_test] 一致——renderer 未提供
## [code]states[/code] 时返回 false 而非抛错（非 NodeGraphRenderer 注入场景）。
func _is_reachable_node(node_id: int) -> bool:
	if node_id < 0 or renderer == null or not (&"states" in renderer):
		return false
	var states_variant: Variant = renderer.get(&"states")
	if not (states_variant is Dictionary):
		return false
	var states_map: Dictionary = states_variant
	return int(states_map.get(node_id, -1)) == NodeStateLogicScript.NodeState.REACHABLE


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
