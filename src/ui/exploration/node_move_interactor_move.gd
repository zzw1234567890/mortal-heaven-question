## NodeMoveInteractor 点击与移动面（继承链第 2 段）——[b]委托、缓冲、失败反馈、动画驱动[/b]。
##
## [b]本层职责[/b]：玩家「点一下之后发生什么」。[br]
##   · 点击命中 → [method request_move]（动画期间入缓冲，同目标去重——AC-7）；[br]
##   · 提交委托 → [method _submit_move]：[b]一律提交[/b]
##     [code]ExplorationSystem.move_to_node(current, clicked)[/code]，UI 零预判可达性
##     （control-manifest Forbidden：防 UI 与系统判定漂移）；[br]
##   · 失败反馈 → [method _play_failure_feedback]：系统 reason 经 [constant REASON_TEXTS]
##     映射文案 + 节点抖动，空文案即静默（AC-4）；[br]
##   · 动画驱动 → [method _play_move_animation] / [method _finish_move_animation]：
##     完成回调里翻转脉冲（AC-6）→ 转发暂存到达通知（B4）→ 推进缓冲队列；[br]
##   · 输入原语——[method _is_input_allowed]（锁栈，必需关卡）/ [method _hit_test]
##     （复用 renderer 公开命中）/ [method _is_reachable_node]（键盘候选判定）。
##
## [code]  node_move_interactor_move.gd  [/code] ← 本层：点击与移动面[br]
## [code]  node_move_interactor_route.gd [/code] ← 接线与转发面[br]
## [code]  node_move_interactor.gd       [/code] ← 链尾：生命周期[br]
##
## 来源: story-005-node-move-interaction.md AC-1/AC-2/AC-4/AC-6/AC-7、
## ADR-0014 §决策 3、ADR-0031 §2.1/§3、control-manifest §Presentation。

extends "res://src/ui/exploration/node_move_interactor_contract.gd"


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


## 触发暂存的到达通知（移动动画完成时）。
func _flush_pending_arrival() -> void:
	if not _pending_arrival.is_valid():
		return
	var pending: Callable = _pending_arrival
	_pending_arrival = Callable()
	pending.call()


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
