class_name NodeGraphViewport
extends Control
## NodeGraphViewport —— 节点图缩放平移容器（exploration-ui Story 001 stub）。
##
## [b]职责[/b]：承载 [NodeGraphRenderer] 作为内容宿主，实现画布缩放平移模式
## （UX 模式库「画布缩放平移」）：滚轮 50%-150% 平滑缩放（~0.2s）、
## 中键/背景拖拽平移、空格复位整图适配、默认初始整图适配、
## 50% 缩放隐藏节点文字标签（联动 [code]renderer.show_labels[/code]）。
##
## [br][b]变换策略[/b]（story 实现说明：Control scale/position 实测裁决）：
## renderer 为直接子 Control——缩放 = [code]renderer.scale[/code]、
## 平移 = [code]renderer.position[/code]。屏幕坐标 = world × zoom + offset。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：缩放/偏移为纯视觉变换参数，
## 不缓存游戏状态；输入驱动的过渡动画（Tween）豁免于零轮询红线
## （非 [code]_process[/code] 常驻——Tween 完成即停）。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]——所有交互经
## [code]_gui_input[/code] 输入驱动。
##
## [br]来源: ADR-0031、design/ux/interaction-patterns.md「画布缩放平移」、
## exploration-ui Story 001（AC-2 缩放平移交互）。

## === Visual 常量（模式库规格）=============================================

## 缩放下限（模式库「50%-150%」）——50% 同时是文字标签隐藏阈值。
const ZOOM_MIN: float = 0.5
## 缩放上限。
const ZOOM_MAX: float = 1.5
## 单次滚轮步进（缩放系数——指数插值基准）。
const ZOOM_STEP: float = 0.9
## 缩放平滑过渡时长（秒）——模式库「平滑过渡 ~0.2s」。
const ZOOM_TWEEN_SEC: float = 0.2
## 复位过渡时长（秒）——与缩放同源平滑。
const RESET_TWEEN_SEC: float = 0.25
## 标签隐藏缩放阈值——≤ 此值只留图标（模式库「50% 时隐藏节点文字标签」）。
const LABEL_HIDE_ZOOM: float = 0.5
## 整图适配边距（px）——四周留白。
const FIT_MARGIN: float = 60.0
## 边缘平移热区宽（px）——鼠标进入此区随 motion 平移（模式库「边缘平移」）。
const EDGE_PAN_MARGIN: float = 24.0
## 边缘平移速度基准（px/s——按 motion 事件驱动，非 _process 轮询）。
const EDGE_PAN_SPEED: float = 480.0
## 复位快捷键（模式库「空格复位」）。
const RESET_KEY: Key = KEY_SPACE

## === 状态 ====================================================================

## 内容宿主（setup 时自动创建或外部注入）。
var renderer: NodeGraphRenderer
## 当前缩放（0.5-1.5）——renderer.scale 的单一来源。
var zoom: float = 1.0
## 当前平移偏移（px，屏幕空间）——renderer.position 的单一来源。
var offset: Vector2 = Vector2.ZERO
## 平移中（拖拽按住标记——_gui_input motion 消费判定）。
var _panning: bool = false
## 缩放/复位过渡 Tween 句柄（重入时 kill 重建）。
var _tween: Tween = null
## 输入冻结（弹窗打开时置 true——模式库「模态打开冻结画布」）。
var input_frozen: bool = false:
	set(value):
		input_frozen = value
		if input_frozen and _panning:
			_panning = false


## 注入 stub DAG 并初始整图适配（透传 renderer.setup）。
func setup(graph: Dictionary, nodes: Dictionary, visited: Array = [], current_node: int = -1) -> void:
	renderer.setup(graph, nodes, visited, current_node)
	fit_to_content(true)


## 整图适配——内容包围盒缩放至视口内并居中。[br]
## [param instant]: true 立即生效（初始布局用）/ false 平滑过渡（复位用）。
func fit_to_content(instant: bool = false) -> void:
	var content: Rect2 = renderer.get_content_rect()
	if content.size == Vector2.ZERO:
		return
	var avail: Vector2 = size - Vector2(FIT_MARGIN * 2.0, FIT_MARGIN * 2.0)
	var fit_zoom: float = minf(avail.x / content.size.x, avail.y / content.size.y)
	var target_zoom: float = clampf(fit_zoom, ZOOM_MIN, ZOOM_MAX)
	var content_center: Vector2 = content.position + content.size * 0.5
	var target_offset: Vector2 = size * 0.5 - content_center * target_zoom
	_apply_transform(target_zoom, target_offset, RESET_TWEEN_SEC if not instant else 0.0)


## === 内部 ====================================================================

func _init(p_renderer: NodeGraphRenderer = null) -> void:
	renderer = p_renderer if p_renderer != null else NodeGraphRenderer.new()
	# 内容宿主覆盖全视口（clip 前提 + 绘制区域非零——Control size 0 会
	# 触发 canvas item 剔除，D3D12/Vulkan 下表现为整帧 DC 归零）
	renderer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(renderer)

func _ready() -> void:
	# 键盘复位（空格）走未处理输入——_gui_input 仅收鼠标事件
	set_process_unhandled_key_input(true)

func _gui_input(event: InputEvent) -> void:
	if input_frozen:
		accept_event()
		return
	if event is InputEventMouseButton:
		_handle_button(event)
	elif event is InputEventMouseMotion:
		if _panning:
			# 平移：拖拽增量直接进 offset（世界坐标无关——屏幕空间平移）
			_apply_transform(zoom, offset + event.relative, 0.0)
		elif not _panning:
			# 边缘平移热区（未拖拽时 motion 驱动）
			var edge: Vector2 = _edge_pan_direction(event.position)
			if edge != Vector2.ZERO:
				_apply_transform(zoom,
						offset + edge * EDGE_PAN_SPEED * (1.0 / 60.0), 0.0)

func _unhandled_key_input(event: InputEvent) -> void:
	if input_frozen:
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == RESET_KEY:
		fit_to_content()
		accept_event()  # 视图非场景树时占位——保持 _gui_input 风格一致

## 鼠标按钮：滚轮缩放（光标锚定）/ 中键 + 左键拖拽平移。
func _handle_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(event.position, 1.0 / ZOOM_STEP)
			accept_event()
		MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(event.position, ZOOM_STEP)
			accept_event()
		MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_LEFT:
			_panning = event.pressed
			accept_event()

## 光标锚定缩放：保持光标下的世界点在缩放前后屏幕位置不变。[br]
## 屏幕坐标 = world × zoom + offset ⇒
## new_offset = cursor - (cursor - old_offset) × (new_zoom / old_zoom)。
func _zoom_at(cursor: Vector2, factor: float) -> void:
	var target_zoom: float = clampf(zoom * factor, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(target_zoom, zoom):
		return
	var target_offset: Vector2 = cursor \
			- (cursor - offset) * (target_zoom / zoom)
	_apply_transform(target_zoom, target_offset, ZOOM_TWEEN_SEC)

## 应用缩放/偏移（renderer.scale/position 单一写入点）+ 标签联动。
func _apply_transform(target_zoom: float, target_offset: Vector2, tween_sec: float) -> void:
	if tween_sec <= 0.0:
		_kill_tween()
		zoom = target_zoom
		offset = target_offset
		_sync_renderer()
		return
	_kill_tween()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_method(_tween_step.bind(zoom, offset, target_zoom, target_offset),
			0.0, 1.0, tween_sec)

## Tween 步进插值（线性——0.2s 短过渡感知差异可忽略）。
func _tween_step(t: float, from_zoom: float, from_offset: Vector2,
		to_zoom: float, to_offset: Vector2) -> void:
	zoom = lerpf(from_zoom, to_zoom, t)
	offset = from_offset.lerp(to_offset, t)
	_sync_renderer()

## 写入 renderer 变换 + 50% 标签隐藏联动。
func _sync_renderer() -> void:
	renderer.scale = Vector2(zoom, zoom)
	renderer.position = offset
	renderer.show_labels = zoom > LABEL_HIDE_ZOOM
	renderer.queue_redraw()

## 边缘平移方向判定——光标进入热区返回归一化方向（可对角组合），
## 否则 Vector2.ZERO（无 [code]_process[/code]——纯 motion 事件驱动）。
func _edge_pan_direction(cursor: Vector2) -> Vector2:
	var dir := Vector2.ZERO
	if cursor.x < EDGE_PAN_MARGIN:
		dir.x = 1.0  # 左热区 → 画布右移（内容向右平移）
	elif cursor.x > size.x - EDGE_PAN_MARGIN:
		dir.x = -1.0
	if cursor.y < EDGE_PAN_MARGIN:
		dir.y = 1.0
	elif cursor.y > size.y - EDGE_PAN_MARGIN:
		dir.y = -1.0
	return dir


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
