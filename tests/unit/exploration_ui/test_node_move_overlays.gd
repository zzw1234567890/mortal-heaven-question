extends GutTest
## exploration-ui S17-005 单元测试：overlay 坐标语义（画布坐标契约）。[br]
##
## [b]回归锁定[/b]（代码审查 H1）：renderer.get_node_position() 返回节点[b]中心[/b]，
## overlay 的绘制圆心必须落在该点上——`place_at_center` 实现
## `position = center - size * 0.5`。此前的实现直接把 position 设为节点中心，
## 导致标记/抖动环/悬停环整体偏移半个自身尺寸。
##
## 来源: story-005 AC-1/AC-6、node_move_overlays.gd、S17-005 代码审查 H1。

const Overlays := preload("res://src/ui/exploration/node_move_overlays.gd")

## 目标节点中心（取自 stub 布局——节点 101 位于 (45, 110)）。
const NODE_CENTER: Vector2 = Vector2(45.0, 110.0)


func test_place_at_center_puts_draw_center_on_node_center() -> void:
	# Arrange: 任意尺寸的 overlay
	var overlay: Control = Control.new()
	overlay.size = Vector2(64.0, 64.0)
	add_child_autofree(overlay)
	# Act
	Overlays.place_at_center(overlay, NODE_CENTER)
	# Assert: 绘制圆心（position + size * 0.5）== 节点中心
	assert_eq(overlay.position + overlay.size * 0.5, NODE_CENTER,
			"overlay 绘制圆心应落在节点中心")
	assert_eq(overlay.position, NODE_CENTER - Vector2(32.0, 32.0),
			"position 应为 中心 - 尺寸的一半")


func test_build_marker_centers_on_node_after_placement() -> void:
	# Arrange: 宿主容器（模拟 renderer）
	var host: Control = Control.new()
	add_child_autofree(host)
	# Act
	var marker: Control = Overlays.build_marker(host)
	Overlays.place_at_center(marker, NODE_CENTER)
	# Assert: 直径为 2 × 半径，圆心落在节点中心
	assert_eq(marker.size, Vector2(Overlays.MARKER_RADIUS * 2.0, Overlays.MARKER_RADIUS * 2.0),
			"标记尺寸应为半径的两倍")
	assert_eq(marker.position + marker.size * 0.5, NODE_CENTER, "标记圆心 == 节点中心")


func test_build_marker_starts_hidden() -> void:
	# Arrange / Act
	var host: Control = Control.new()
	add_child_autofree(host)
	var marker: Control = Overlays.build_marker(host)
	# Assert: 首帧不显示（避免画布原点闪点——审查 M7）
	assert_false(marker.visible, "标记初始应隐藏（快照注入后才显示）")


func test_build_marker_and_ring_ignore_mouse() -> void:
	# Arrange / Act
	var host: Control = Control.new()
	add_child_autofree(host)
	var marker: Control = Overlays.build_marker(host)
	var ring: Control = Overlays.build_pulse_ring(host, &"ShakeOverlay")
	# Assert: 不遮蔽 renderer 的点击/悬停命中
	assert_eq(marker.mouse_filter, Control.MOUSE_FILTER_IGNORE, "标记应输入透明")
	assert_eq(ring.mouse_filter, Control.MOUSE_FILTER_IGNORE, "环应输入透明")


func test_build_pulse_ring_centers_on_node_after_placement() -> void:
	# Arrange
	var host: Control = Control.new()
	add_child_autofree(host)
	# Act
	var ring: Control = Overlays.build_pulse_ring(host, &"FlipOverlay")
	Overlays.place_at_center(ring, NODE_CENTER)
	# Assert
	assert_eq(ring.position + ring.size * 0.5, NODE_CENTER,
			"脉冲环圆心 == 节点中心")
	assert_false(ring.visible, "环初始应隐藏")
