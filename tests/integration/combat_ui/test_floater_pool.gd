extends GutTest
## combat-ui-layout Story 003 补充测试：飘字池独立规格。
##
## 覆盖：池上限 16 恒定、种类方向/颜色/文本格式、池耗尽回收最旧、
## reduce_motion 静态替代、零轮询（无 _process）。
##
## 风格先例：test_hp_batch_transition.gd。

const PoolScript: GDScript = preload("res://src/ui/combat/feedback/floater_pool.gd")

var pool: Control = null


func before_each() -> void:
	pool = PoolScript.new()
	add_child_autofree(pool)


func _wait_sec(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _wait_frames(frames: int) -> void:
	for i: int in frames:
		await get_tree().process_frame


func test_pool_precreated_exactly_16_nodes() -> void:
	# Then: 预创建 16（GDD guardrail——同帧 12+ 不产生节点风暴）
	assert_eq(pool.instance_count(), 16, "池应预创建恰好 16 个 Label")
	assert_eq(pool.get_child(0) is Label, true, "池成员应为 Label")
	assert_eq(pool.free_count(), 16, "初始应全空闲")


func test_pool_cap_never_instantiates_beyond_limit() -> void:
	# Act —— 30 个同帧请求（远超上限）
	for i: int in 30:
		pool.spawn(Vector2.ZERO, 10, PoolScript.FloaterKind.DAMAGE)
	# Then: 恒 16
	assert_eq(pool.instance_count(), 16,
		"任意同帧请求数下池实例数不应超过 16")


func test_damage_floater_red_text_with_minus() -> void:
	# Act
	pool.spawn(Vector2.ZERO, 25, PoolScript.FloaterKind.DAMAGE)
	var label: Label = pool.get_child(0) as Label
	# Then: 文本 -25 + 红色
	assert_eq(label.text, "-25", "伤害飘字文本应为 -25")
	assert_eq(label.get_theme_color("font_color"), PoolScript.DAMAGE_COLOR,
		"伤害飘字应为红色")


func test_heal_floater_green_rises() -> void:
	# Act
	pool.spawn(Vector2(50.0, 100.0), 10, PoolScript.FloaterKind.HEAL)
	var label: Label = pool.get_child(0) as Label
	var start_y: float = label.position.y
	# Then: 文本 +10 + 绿色 + 上浮（y 减小）
	assert_eq(label.text, "+10", "治疗飘字文本应为 +10")
	assert_eq(label.get_theme_color("font_color"), PoolScript.HEAL_COLOR,
		"治疗飘字应为绿色")
	await _wait_frames(10)
	assert_true(label.position.y < start_y,
		"治疗飘字应上浮（y 减小）")


func test_damage_floater_falls() -> void:
	# Act
	pool.spawn(Vector2(50.0, 100.0), 7, PoolScript.FloaterKind.DAMAGE)
	var label: Label = pool.get_child(0) as Label
	var start_y: float = label.position.y
	# Then: 下落（y 增大）
	await _wait_frames(10)
	assert_true(label.position.y > start_y,
		"伤害飘字应下落（y 增大）")


func test_pool_exhaust_recycles_oldest() -> void:
	# Arrange —— 占满 16
	for i: int in 16:
		pool.spawn(Vector2(float(i), 0.0), i + 1,
			PoolScript.FloaterKind.DAMAGE)
	var first_label: Label = pool.get_child(0) as Label
	assert_eq(first_label.text, "-1", "前置：索引 0 为最旧（值 1）")
	# Act —— 第 17 个（回收最旧——索引 0）
	pool.spawn(Vector2.ZERO, 99, PoolScript.FloaterKind.DAMAGE)
	# Then: 索引 0 被复用（文本更新为第 17 个的 -99）
	assert_eq(first_label.text, "-99",
		"池耗尽时应回收最旧飘字复用（不新建）")
	assert_eq(pool.instance_count(), 16, "实例数恒 16")


func test_floater_completes_and_returns_to_pool() -> void:
	# Act —— 单飘字 0.5s 完成（实时等待）
	pool.spawn(Vector2.ZERO, 5, PoolScript.FloaterKind.HEAL)
	assert_eq(pool.free_count(), 15, "前置：1 个占用")
	await _wait_sec(0.9)
	# Then: 回收入池（可见=false + 空闲计数恢复）
	assert_eq(pool.free_count(), 16, "完成后应回收入池")
	var label: Label = pool.get_child(0) as Label
	assert_false(label.visible, "回收后应不可见")


func test_pool_has_no_process_polling() -> void:
	# Then: 无 _process/_physics_process（ADR-0031 §3——源码检查）
	assert_false(pool.has_method("_process"), "飘字池不应有 _process")
	assert_false(pool.has_method("_physics_process"),
		"飘字池不应有 _physics_process")


func test_pool_reduce_motion_fade_only() -> void:
	# Arrange
	pool.set_reduce_motion(true)
	# Act
	pool.spawn(Vector2(100.0, 200.0), 30, PoolScript.FloaterKind.DAMAGE)
	var label: Label = pool.get_child(0) as Label
	var start_y: float = label.position.y
	await _wait_frames(15)
	# Then: 位置不变 + 透明度淡出中
	assert_almost_eq(label.position.y, start_y, 0.01,
		"reduce_motion 飘字无位移")
	assert_true(label.modulate.a < 1.0 and label.modulate.a > 0.0,
		"reduce_motion 飘字应纯淡出")
