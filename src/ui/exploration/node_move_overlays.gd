class_name NodeMoveOverlays
extends RefCounted
## NodeMoveOverlays —— 节点移动交互的 overlay 工厂（exploration-ui S17-005）。[br]
##
## [b]职责[/b]：构建挂在 [NodeGraphRenderer] 下的纯视觉 overlay（玩家标记 /
## 抖动环 / 翻转环），并提供「以节点中心定位」的统一坐标语义。[br]
## [br][b]坐标契约（本文件唯一真理来源）[/b]：[method place_at_center] 把控件
## 原点偏移到 [code]center - size * 0.5[/code]，使控件内部以
## [code]size * 0.5[/code] 为圆心的绘制恰好落在节点中心。renderer 的
## [method NodeGraphRenderer.get_node_position] 返回的是[b]节点中心[/b]——
## 直接把 position 设为该值会让绘制中心偏移半个自身尺寸（S17-005 审查 H1）。[br]
## [br][b]输入透明[/b]：全部 overlay 为 [code]MOUSE_FILTER_IGNORE[/code]，
## 不遮蔽 renderer 的点击/悬停命中。[br]
## [br][b]零状态[/b]：无成员状态、无 _process——纯工厂（ADR-0031 §2/§3）。
##
## 来源: story-005-node-move-interaction.md AC-1/AC-6、ADR-0031 §2/§3/§5、
## S17-005 代码审查 H1（overlay 绘制中心偏移）。

## 玩家标记半径（px）——renderer 自绘节点的玩家标记 overlay。
const MARKER_RADIUS: float = 14.0
## 玩家标记颜色——金色（renderer NODE_CURRENT_BORDER 同源）。
const MARKER_COLOR: Color = Color("#FFD700")
## 脉冲环控件边长（px）。
const RING_CONTROL_SIZE: float = 64.0
## 抖动环半径（px）。
const SHAKE_RING_RADIUS: float = 28.0
## 抖动/翻转环颜色——绿色（AC-6 已访问边框变绿同源）。
const RING_COLOR: Color = Color(0.27, 0.80, 0.40, 0.85)
## 环线宽（px）。
const RING_WIDTH: float = 3.0


## 把控件定位到节点中心（控件的绘制圆心 = 节点中心）。[br]
## [param overlay]: 待定位控件（尺寸已确定）。[param center]: 节点中心坐标
## （renderer 画布局部坐标）。
static func place_at_center(overlay: Control, center: Vector2) -> void:
	overlay.position = center - overlay.size * 0.5


## 构建玩家标记（金色实心圆，挂在 [param parent] 下）。[br]
## [b]初始隐藏[/b]：首帧到快照注入之间不出现画布原点的闪点。
static func build_marker(parent: Node) -> Control:
	var overlay: Control = Control.new()
	overlay.name = &"MoveMarker"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var diameter: float = MARKER_RADIUS * 2.0
	overlay.size = Vector2(diameter, diameter)
	overlay.draw.connect(func() -> void:
		overlay.draw_circle(Vector2(MARKER_RADIUS, MARKER_RADIUS), MARKER_RADIUS, MARKER_COLOR))
	overlay.visible = false
	parent.add_child(overlay)
	return overlay


## 构建脉冲环（绿色描边圆环，按 [param overlay_name] 复用）。[br]
## [param parent]: 挂载点（renderer）。[param overlay_name]: 节点唯一名。
static func build_pulse_ring(parent: Node, overlay_name: StringName) -> Control:
	var overlay: Control = Control.new()
	overlay.name = overlay_name
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.size = Vector2(RING_CONTROL_SIZE, RING_CONTROL_SIZE)
	var center: Vector2 = Vector2(RING_CONTROL_SIZE, RING_CONTROL_SIZE) * 0.5
	overlay.draw.connect(func() -> void:
		overlay.draw_arc(center, SHAKE_RING_RADIUS, 0.0, TAU, 24, RING_COLOR, RING_WIDTH))
	overlay.visible = false
	parent.add_child(overlay)
	return overlay
