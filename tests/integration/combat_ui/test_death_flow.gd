extends GutTest
## combat-ui-layout Story 003 补充测试：阵亡流程（AC-4 可自动化部分）。
##
## 覆盖：character_died → 0.5s 淡出 → 移除 → 空位虚线框；
## 幂等守卫（重复阵亡信号不重播）；reduce_motion 直接移除；
## unregister 防御（未注册角色信号静默忽略）。
##
## 风格先例：test_hp_batch_transition.gd。

const CardScript: GDScript = preload("res://src/ui/combat/layout/character_status_card.gd")
const CoordinatorScript: GDScript = preload("res://src/ui/combat/feedback/combat_feedback_coordinator.gd")
const EmptyFrameScript: GDScript = preload("res://src/ui/combat/layout/empty_slot_frame.gd")
const MockSignals: GDScript = preload("res://tests/integration/combat_ui/mocks/mock_combat_signals.gd")

var mock: Node = null
var coordinator: Control = null
var card: Control = null
var container: Control = null


func before_each() -> void:
	mock = MockSignals.new()
	add_child_autofree(mock)
	coordinator = CoordinatorScript.new()
	add_child_autofree(coordinator)
	# 卡挂在独立容器下（阵亡后空位框挂同容器——位置接替断言）
	container = Control.new()
	add_child_autofree(container)
	card = CardScript.new()
	container.add_child(card)
	coordinator.setup([mock], null,
		Callable(mock, "read_hp"), false)
	coordinator.register_card(101, card)


## 等待实时秒数（headless 帧率不封顶——帧数等待对时间驱动的 Tween 不可靠）。
func _wait_sec(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func test_death_flow_animates_then_removes_and_shows_empty_frame() -> void:
	# Arrange —— 记录卡的尺寸与位置（移除后卡对象将 queue_free——先取证）
	var expected_size: Vector2 = card.size
	var expected_pos: Vector2 = card.position
	# Act —— 阵亡信号
	mock.character_died.emit(101, 0, [])
	# Then: 动画进行中（卡未移除，透明度开始下降）
	assert_true(coordinator._death_tweens.has(101), "阵亡动画应启动")
	await _wait_sec(0.2)
	assert_true(card.modulate.a < 1.0, "淡出应进行中（0.5s stub）")
	assert_true(card.get_parent() != null, "动画期间卡仍在场")
	# Act —— 等待 0.5s 动画完成（实时窗口）
	await _wait_sec(0.8)
	# Then: 卡移除 + 空位虚线框出现（同容器）
	assert_false(coordinator._cards.has(101), "卡表应已清理")
	assert_eq(container.get_child_count(), 1,
		"容器内应只剩空位框（卡已移除）")
	var frame: Control = container.get_child(0)
	assert_eq(frame.get_script(), EmptyFrameScript,
		"接替节点应为 EmptySlotFrame")
	assert_almost_eq(frame.size.x, expected_size.x, 0.5, "空位框宽应同卡宽")
	assert_almost_eq(frame.size.y, expected_size.y, 0.5, "空位框高应同卡高")
	assert_almost_eq(frame.position.x, expected_pos.x, 0.5,
		"空位框应原位接替（x）")
	assert_almost_eq(frame.position.y, expected_pos.y, 0.5,
		"空位框应原位接替（y）")


func test_death_flow_idempotent_duplicate_signal() -> void:
	# Act —— 同一角色两次阵亡信号（pending_death + 信号双路径汇合）
	mock.character_died.emit(101, 0, [])
	mock.character_died.emit(101, 0, [])
	# Then: 仅一条动画（幂等守卫）
	assert_true(coordinator._death_tweens.has(101), "首信号应启动动画")
	assert_eq(coordinator._death_tweens.size(), 1, "重复信号不应重播动画")


func test_death_flow_reduce_motion_immediate() -> void:
	# Arrange —— reduce_motion Coordinator（独立容器隔离断言）
	var rm_coordinator: Control = CoordinatorScript.new()
	add_child_autofree(rm_coordinator)
	var rm_container: Control = Control.new()
	add_child_autofree(rm_container)
	var rm_card: Control = CardScript.new()
	rm_container.add_child(rm_card)
	rm_coordinator.setup([mock], null, Callable(mock, "read_hp"), true)
	rm_coordinator.register_card(101, rm_card)
	# Act —— 阵亡信号
	rm_coordinator._on_character_died(101, 0, [])
	# Then: 直接移除（瞬时替代——无动画窗口）；容器内仅剩空位框
	assert_false(rm_coordinator._death_tweens.has(101),
		"reduce_motion 下不应有阵亡动画")
	assert_eq(rm_container.get_child_count(), 1,
		"reduce_motion 下卡应立即移除（容器内仅剩空位框）")
	assert_eq(rm_container.get_child(0).get_script(), EmptyFrameScript,
		"接替节点应为 EmptySlotFrame")


func test_death_flow_unregistered_character_ignored() -> void:
	# Act —— 未注册角色的阵亡信号（防御）
	mock.character_died.emit(999, 0, [])
	# Then: 静默忽略（无动画无崩溃）
	assert_eq(coordinator._death_tweens.size(), 0, "未注册角色不应启动动画")


func test_unregister_card_cleans_transient_state() -> void:
	# Arrange —— 制造瞬态状态
	mock.set_hp(101, 100, 100)
	mock.emit_attack(101, 10)
	assert_true(coordinator._pending_deltas.has(101), "前置：增量待结算")
	# Act
	coordinator.unregister_card(101)
	# Then: 表清理（防悬空引用）
	assert_false(coordinator._cards.has(101), "卡表应清理")
	assert_false(coordinator._pending_deltas.has(101), "增量表应清理")


# ═══════════════════════════════════════════════════════════════════════════════
# 缺口一：阵亡终态（空位框）也要带可辨识的「已阵亡」文字
# ═══════════════════════════════════════════════════════════════════════════════

## 阵亡动画结束后，接替的空位框上写有「已阵亡」——终态不是一块无来由的空白。
func test_empty_slot_after_death_carries_defeat_stamp_text() -> void:
	# Arrange
	mock.character_died.emit(101, 0, [])
	# Act —— 等动画跑完（0.5s）+ 接替
	await _wait_sec(0.8)
	# Assert
	var frame: Control = container.get_child(0)
	assert_eq(frame.get_script(), EmptyFrameScript, "前置：接替节点为 EmptySlotFrame")
	assert_eq(frame.call(&"get_defeat_text"), "已阵亡",
		"空位框应写明「已阵亡」，而不是只剩一圈虚线")


## 未阵亡的位置不出现这个文字（对照组——文字来自阵亡事实，不是空位框自带装饰）。
func test_empty_slot_without_death_has_no_stamp_text() -> void:
	# Arrange —— 直接建一个空位框（模拟「这格本来就是空的」）
	var frame: Control = EmptyFrameScript.new()
	add_child_autofree(frame)
	frame.size = Vector2(120.0, 168.0)
	# Assert —— 默认无文字（对照上面那条：文字由阵亡流程写入）
	assert_eq(frame.call(&"get_defeat_text"), "",
		"未阵亡的空位不应带阵亡文字")


## 显式清空后文字消失（空串 = 框回到「只是一格空位」的语义）。
func test_empty_slot_stamp_text_can_be_cleared() -> void:
	# Arrange
	var frame: Control = EmptyFrameScript.new()
	add_child_autofree(frame)
	frame.size = Vector2(120.0, 168.0)
	frame.call(&"set_defeat_text", "已阵亡")
	assert_eq(frame.call(&"get_defeat_text"), "已阵亡", "前置：文字已填入")
	# Act
	frame.call(&"set_defeat_text", "")
	# Assert
	assert_eq(frame.call(&"get_defeat_text"), "", "清空后文字应消失")
