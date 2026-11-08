extends RefCounted
## NodeMoveAnimator —— 节点移动交互的动画编排（exploration-ui S17-005）。[br]
##
## [b]无 class_name[/b]（headless 动态加载下不可靠——项目惯例：调用方以
## preload 脚本常量引用，S16-1/2 先例）。
##
## [b]职责[/b]：玩家标记移动 / 失败抖动 / 已访问翻转三种视觉动画的 Tween 生命周期
## 与 overlay 句柄管理。不判断业务时机（何时播动画由上层的信号/委托流决定）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：仅持有 Tween 句柄与 overlay 引用
## （瞬态视觉资源），不缓存任何游戏状态。[br]
## [br][b]reduce_motion[/b]（ADR-0031 动画偏好）：移动直跳终位、抖动/翻转跳过。[br]
## [br][b]生命周期[/b]：[method clear] 终止全部 Tween 并移除 overlay（交互组件
## 重建/退出时调用——不留残影，S17-005 审查 M4/M6）。
##
## 来源: story-005-node-move-interaction.md AC-1/AC-2/AC-6、ADR-0031 §2/§3、
## S17-005 代码审查 M4/M6/M7/H1（overlay 坐标偏移）。

## 玩家标记移动动画时长（秒/节点）——UX 规格 ~0.4s，AC 上限 0.5s。
const MOVE_ANIM_SEC: float = 0.4
## 不可达点击节点抖动时长（秒）。
const SHAKE_SEC: float = 0.3
## 抖动幅度（px）。
const SHAKE_AMPLITUDE: float = 6.0
## 已访问翻转脉冲时长（秒）——AC-6「0.2s 边框变绿+✓浮现」。
const VISITED_FLIP_SEC: float = 0.2

## Tween 宿主（交互组件——create_tween 的绑定节点）。
var _owner: Node = null
## 渲染器（overlay 挂载点 + 节点坐标源）。
var _renderer: Control = null
## 动画偏好——true 时移动直跳终位、抖动/翻转跳过。
var reduce_motion: bool = false

## 玩家标记 overlay（renderer 子节点）。
var _marker: Control = null
## 抖动/翻转 overlay（按角色复用）。
var _shake_overlay: Control = null
var _flip_overlay: Control = null
## Tween 句柄（重入 kill）。
var _move_tween: Tween = null
var _shake_tween: Tween = null
var _flip_tween: Tween = null


func _init(p_owner: Node, p_renderer: Control) -> void:
	_owner = p_owner
	_renderer = p_renderer
	if _renderer != null:
		_marker = NodeMoveOverlays.build_marker(_renderer)


## 立即把标记同步到节点（快照注入/进入地图/移动终位）。
func sync_marker_to(node_id: int) -> void:
	if _marker == null or _renderer == null:
		return
	_marker.visible = true
	NodeMoveOverlays.place_at_center(_marker, _renderer.get_node_position(node_id))


## 隐藏标记（快照无有效当前节点）。
func hide_marker() -> void:
	if _marker != null:
		_marker.visible = false


## 播放标记移动（from → to）。[br]
## [b]reduce_motion / 离树 / force_instant[/b]：直跳终位后立即回调。[br]
## [param on_finished]: 动画结束回调（缓冲推进/到达通知转发）。[br]
## [param force_instant]: 本次调用强制直跳（不改写全局偏好——快照缺失等即时场景）。
func play_move(from_node: int, to_node: int, on_finished: Callable,
		force_instant: bool = false) -> void:
	if _marker == null or _renderer == null:
		on_finished.call()
		return
	var to_pos: Vector2 = _renderer.get_node_position(to_node)
	if force_instant or reduce_motion or _owner == null or not _owner.is_inside_tree():
		NodeMoveOverlays.place_at_center(_marker, to_pos)
		_marker.visible = true
		on_finished.call()
		return
	var from_pos: Vector2 = _renderer.get_node_position(from_node)
	NodeMoveOverlays.place_at_center(_marker, from_pos)
	_marker.visible = true
	_kill(_move_tween)
	_move_tween = _owner.create_tween()
	_move_tween.tween_method(
			func(c: Vector2) -> void: NodeMoveOverlays.place_at_center(_marker, c),
			from_pos, to_pos, MOVE_ANIM_SEC) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_move_tween.tween_callback(on_finished)


## 失败抖动（reduce_motion/离树跳过——toast 由上层保留）。
func play_shake(node_id: int) -> void:
	if reduce_motion or _owner == null or not _owner.is_inside_tree() or _renderer == null:
		return
	_reset_overlay(_shake_overlay)
	_shake_overlay = _get_or_build_ring(&"ShakeOverlay")
	var overlay: Control = _shake_overlay
	var base_pos: Vector2 = _renderer.get_node_position(node_id)
	NodeMoveOverlays.place_at_center(overlay, base_pos)
	overlay.visible = true
	_kill(_shake_tween)
	_shake_tween = _owner.create_tween()
	_shake_tween.tween_method(
			func(t: float) -> void:
				NodeMoveOverlays.place_at_center(overlay,
						base_pos + Vector2(SHAKE_AMPLITUDE * sin(t * TAU * 3.0), 0.0)),
			0.0, 1.0, SHAKE_SEC)
	_shake_tween.tween_callback(func() -> void: _reset_overlay(overlay))


## 已访问翻转脉冲（AC-6——0.2s 绿环浮现后淡出）。
func play_visited_flip(node_id: int) -> void:
	if reduce_motion or _owner == null or not _owner.is_inside_tree() or _renderer == null:
		return
	_reset_overlay(_flip_overlay)
	_flip_overlay = _get_or_build_ring(&"FlipOverlay")
	var overlay: Control = _flip_overlay
	NodeMoveOverlays.place_at_center(overlay, _renderer.get_node_position(node_id))
	overlay.modulate.a = 0.0
	overlay.visible = true
	_kill(_flip_tween)
	_flip_tween = _owner.create_tween()
	_flip_tween.tween_property(overlay, "modulate:a", 1.0, VISITED_FLIP_SEC)
	_flip_tween.tween_property(overlay, "modulate:a", 0.0, VISITED_FLIP_SEC)
	_flip_tween.tween_callback(func() -> void: _reset_overlay(overlay))


## 终止全部动画并移除 overlay（组件重建/退出——不留残影）。
func clear() -> void:
	_kill(_move_tween)
	_kill(_shake_tween)
	_kill(_flip_tween)
	_move_tween = null
	_shake_tween = null
	_flip_tween = null
	for node_variant: Variant in [_marker, _shake_overlay, _flip_overlay]:
		# 非类型化遍历——已释放对象不能写入 TypedArray；
		# 且 `is` 对已释放实例会报错，必须先做有效性判定（渲染器先于本对象释放时）
		if not is_instance_valid(node_variant):
			continue
		if not (node_variant is Control):
			continue
		var node: Control = node_variant
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.free()
	_marker = null
	_shake_overlay = null
	_flip_overlay = null


## === 内部 ==================================================================

## 获取或构建环形 overlay（按名字复用——renderer 子节点）。
func _get_or_build_ring(overlay_name: StringName) -> Control:
	if _renderer == null:
		return Control.new()
	var existing: Control = _renderer.get_node_or_null(NodePath(overlay_name)) as Control
	if existing != null:
		return existing
	return NodeMoveOverlays.build_pulse_ring(_renderer, overlay_name)


## 复位 overlay 可见态（kill 前调用——审查 M4 残影）。
func _reset_overlay(overlay: Control) -> void:
	if overlay == null or not is_instance_valid(overlay):
		return
	overlay.visible = false
	overlay.modulate.a = 1.0


## kill Tween（重入保护）。
func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
