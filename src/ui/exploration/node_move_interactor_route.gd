## NodeMoveInteractor 接线与转发面（继承链第 3 段）——[b]系统信号转发 + 键盘寻路[/b]。
##
## [b]本层职责[/b]：把外部事件接进来、把内部事件送出去。[br]
##   · 系统信号——[method _bind_system_signals] 按名连接四个信号（缺失时静默跳过，
##     mock/真实系统均兼容；[code]is_connected[/code] 守卫保 setup 幂等，审查 H4）；[br]
##   · [method _on_system_node_moved]——快照更新以信号载荷为真理来源（ADR-0031 §3）；
##   · 到达通知 [method _on_combat_reached] / [method _on_boss_reached] /
##     [method _on_node_interaction]——统一走 [method _defer_or_forward]：
##     [b]动画进行中暂存，动画结束才转发[/b]（B4「先移动后弹窗」，审查 H2）；[br]
##   · 键盘路径（A3）——[method _unhandled_key_input] 走 unhandled 层（不抢焦点控件，
##     锁栈判定仍按 KEYBOARD 设备在 [method _submit_move] 内独立执行，ADR-0004 双焦点）、
##     [method navigate_focus]（方向键空间跳转，焦点环由 renderer 绘制）、
##     [method confirm_keyboard_selection]（Enter 等效点击）。
##
## [b]键盘信号也在此段[/b]：[method _unhandled_key_input] 与 [method navigate_focus]
## 互相调用，且前者要用前一段的 [method _is_reachable_node]——本段在它之后。
##
## [code]  node_move_interactor_route.gd [/code] ← 本层：接线与转发面[br]
## [code]  node_move_interactor.gd       [/code] ← 链尾：生命周期[br]
##
## 来源: story-005-node-move-interaction.md AC-1/AC-3、ADR-0014 §决策 3 委托流程、
## ADR-0004 双焦点、ADR-0031 §3、S17-005 审查 H2/H4。

extends "res://src/ui/exploration/node_move_interactor_move.gd"


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


## 按信号名连接（信号缺失时静默跳过——mock/真实系统均兼容；重复连接守卫）。
func _connect_if_present(signal_name: StringName, handler: Callable) -> void:
	if not exploration_system.has_signal(signal_name):
		return
	if exploration_system.is_connected(signal_name, handler):
		return
	exploration_system.connect(signal_name, handler)
	_bound_signals.append([signal_name, handler])


## === 内部辅助 ================================================================
