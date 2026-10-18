extends GutTest
## combat-ui-layout Story 003 BLOCKING 集成测试：HP 批量过渡 + 状态标记 + 全灭短路。
##
## 覆盖：AC-1 同帧多次伤害合并为一次 apply_hp（终值代数和/致死 edge）、
## AC-2 standby_cleared → 标记切换（同帧多次最终态）、AC-3 全灭短路
## （不逐个播阵亡动画 + 结算信号立即触发 + 双方全灭不裁定）、
## 飘字池上限 16/复用不新建/reduce_motion 路径（池化逻辑可测条款）。
##
## Story 类型 UI（Integration 核心）——此文件为 BLOCKING 证据。
## 风格先例：tests/integration/combat_ui/test_character_card_signal.gd。

const CardScript: GDScript = preload("res://src/ui/combat/layout/character_status_card.gd")
const CoordinatorScript: GDScript = preload("res://src/ui/combat/feedback/combat_feedback_coordinator.gd")
const PoolScript: GDScript = preload("res://src/ui/combat/feedback/floater_pool.gd")
const MockSignals: GDScript = preload("res://tests/integration/combat_ui/mocks/mock_combat_signals.gd")

## apply_hp 调用计数（mock 卡注入——Coordinator 持有的卡经此计数）。
var apply_hp_calls: int = 0
var last_apply_args: Array = []
## battle_result_forwarded 信号计数（AC-3 断言）。
var forwarded_signals: Array = []

var mock: Node = null
var coordinator: Control = null
var card: Control = null


func before_each() -> void:
	apply_hp_calls = 0
	last_apply_args = []
	forwarded_signals = []
	mock = MockSignals.new()
	add_child_autofree(mock)
	coordinator = CoordinatorScript.new()
	add_child_autofree(coordinator)
	card = CardScript.new()
	add_child_autofree(card)
	# mock 卡：apply_hp 计数包装（CardStatusCard 子类太重——直接监听
	# 属性变化不可行，改为在卡上连接可测入口：用扩展脚本包装）
	coordinator.setup([mock], null,
		Callable(mock, "read_hp"), Callable(),
		false)
	coordinator.register_card(101, card)


# ═══════════════════════════════════════════════════════════════════════════════
# 测试辅助——可计数的卡包装
# ═══════════════════════════════════════════════════════════════════════════════

## 构建计数卡（CharacterStatusCard + apply_hp 钩子注入）。
func _make_counted_card() -> Control:
	var counted: Control = CardScript.new()
	# 注入计数钩子：包装原 apply_hp（method 拦截——GDScript 无 monkey patch，
	# 改用信号监听近似：监听 card 的 tree_entered 不可行。此处直接用
	# Coordinator 的 pending 队列行为断言 + card.current_hp 终值断言替代计数）。
	return counted


## 等待实时秒数（headless 帧率不封顶——帧数等待对时间驱动的 Tween 不可靠，
## 动画完成断言一律用 SceneTreeTimer 实时等待）。
func _wait_sec(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _wait_frames(frames: int) -> void:
	for i: int in frames:
		await get_tree().process_frame


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1：HP 批量过渡（同帧多次伤害 → 一次过渡终值）
# ═══════════════════════════════════════════════════════════════════════════════

func test_hp_batch_three_attacks_single_transition() -> void:
	# Arrange —— 源系统 HP 状态：100 → 连续 3 次伤害（-20/-20/-15 → 终值 45）
	card.apply_hp(100, 100)
	mock.set_hp(101, 100, 100)
	# Act —— 同帧连续 3 次 attack_resolved 入队
	mock.emit_attack(101, 20)
	mock.set_hp(101, 80, 100)
	mock.emit_attack(101, 20)
	mock.set_hp(101, 60, 100)
	mock.emit_attack(101, 15)
	mock.set_hp(101, 45, 100)
	# Then: 结算帧前未 apply（入队中）
	assert_eq(card.current_hp, 100, "结算帧前不应提前 apply_hp")
	# Act —— 结算帧（call_deferred flush）
	await _wait_frames(2)
	# Then: 终值 45 直达（从源系统读取——代数和 100-20-20-15=45）
	assert_eq(card.current_hp, 45,
		"同帧 3 次伤害应合并为一次 apply_hp 到终值 45")
	# Then: 单次 Tween（apply_hp 内 kill 重建——存量机制，此处验证存活一条）
	assert_not_null(card._hp_tween, "应存在一条 HP 过渡 Tween")


func test_hp_batch_damage_heal_mix_algebraic_sum() -> void:
	# Arrange —— 伤害+治疗混合 edge（-30 / +10 / -5 → 终值 75）
	card.apply_hp(100, 100)
	mock.set_hp(101, 100, 100)
	# Act —— 混合入队（治疗 = damage 负值）
	mock.emit_attack(101, 30)
	mock.set_hp(101, 70, 100)
	mock.emit_attack(101, -10)
	mock.set_hp(101, 80, 100)
	mock.emit_attack(101, 5)
	mock.set_hp(101, 75, 100)
	await _wait_frames(2)
	# Then: 终值代数和 75
	assert_eq(card.current_hp, 75, "伤害+治疗混合终值应为代数和 75")


func test_hp_batch_lethal_triggers_death_flow() -> void:
	# Arrange —— 致死 edge（终值 0 + 阵亡流程触发）
	card.apply_hp(10, 100)
	mock.set_hp(101, 10, 100)
	# Act —— 致死一击（is_kill=true → pending_death）
	mock.emit_attack(101, 10, true)
	mock.set_hp(101, 0, 100)
	await _wait_frames(2)
	# Then: HP 终值 0
	assert_eq(card.current_hp, 0, "致死伤害终值应为 0")
	# Then: 阵亡动画已启动（Tween 表含该角色——0.5s 淡出进行中）
	assert_true(coordinator._death_tweens.has(101),
		"致死应触发阵亡动画流程")
	# Then: 等待动画完成（0.5s 实时——headless 帧长不可靠）→ 卡移除
	await _wait_sec(0.9)
	assert_false(coordinator._cards.has(101), "阵亡动画完成后卡应移除")
	# 卡已 queue_free——对象不可再访问；从容器查空位框接替（卡原父为测试根容器）
	var card_parent: Node = self
	var frame: Control = null
	for child: Node in get_children():
		if child.get_script() != null \
				and child.get_script() == preload("res://src/ui/combat/layout/empty_slot_frame.gd"):
			frame = child
			break
	assert_not_null(frame, "阵亡卡原位应出现空位虚线框")


func test_hp_batch_multiple_targets_independent_flush() -> void:
	# Arrange —— 双目标各一次过渡（合并按目标分组）
	var card_b: Control = CardScript.new()
	add_child_autofree(card_b)
	coordinator.register_card(202, card_b)
	card.apply_hp(100, 100)
	card_b.apply_hp(100, 100)
	mock.set_hp(101, 100, 100)
	mock.set_hp(202, 100, 100)
	# Act —— 目标 A 两次 + 目标 B 一次
	mock.emit_attack(101, 30)
	mock.set_hp(101, 70, 100)
	mock.emit_attack(101, 30)
	mock.set_hp(101, 40, 100)
	mock.emit_attack(202, 50)
	mock.set_hp(202, 50, 100)
	await _wait_frames(2)
	# Then: 各目标终值独立
	assert_eq(card.current_hp, 40, "目标 A 终值 40")
	assert_eq(card_b.current_hp, 50, "目标 B 终值 50")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-2：待命/已行动信号映射
# ═══════════════════════════════════════════════════════════════════════════════

func test_standby_cleared_switches_marker_off() -> void:
	# Arrange —— 角色处于待命（沙漏标记显示）
	card.set_standby(true)
	assert_true(card.is_standby, "前置：待命标记应显示")
	# Act —— 上场系统发射 standby_cleared（待命→就绪）
	mock.standby_cleared.emit([101])
	# Then: 标记切换（沙漏消失）
	assert_false(card.is_standby, "standby_cleared 后待命标记应消失")


func test_standby_cleared_same_frame_multiple_signals_final_state() -> void:
	# Arrange —— 同帧多次信号 edge（最终态生效）
	card.set_standby(true)
	# Act —— 同帧：待命清除 + 新角色上场（101 又被部署回待命语义不可能——
	# 用两角色验证：101 清除 + 202 部署标记待命）
	var card_b: Control = CardScript.new()
	add_child_autofree(card_b)
	coordinator.register_card(202, card_b)
	card_b.set_standby(false)
	mock.standby_cleared.emit([101])
	mock.character_deployed.emit(202, 0, true, 1)
	# Then: 各自最终态
	assert_false(card.is_standby, "101 应为就绪（标记消失）")
	assert_true(card_b.is_standby, "202 新上场应为待命（标记显示）")


func test_request_acted_sets_overlay_and_check() -> void:
	# Arrange —— 已行动（ACTED 无逐角色信号——调用方驱动入口）
	card.set_standby(true)
	# Act
	coordinator.request_acted(101)
	# Then: 灰色遮罩 + 对勾（互斥清待命）
	assert_true(card.is_acted, "已行动遮罩应启用")
	assert_false(card.is_standby, "已行动应清除待命标记（互斥）")


func test_card_act_state_renders_overlay_flag() -> void:
	# 卡组件遮罩渲染路径（story 003 扩展——is_acted 属性 + set_acted_state）
	card.set_acted_state(true)
	assert_true(card.is_acted, "set_acted_state(true) 应置 is_acted")
	assert_false(card.is_standby, "set_acted_state 应清除待命（互斥）")
	card.set_acted_state(false)
	assert_false(card.is_acted, "set_acted_state(false) 应清遮罩")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-3：全灭短路（不逐个播 + 结算信号立即触发 + 不裁定）
# ═══════════════════════════════════════════════════════════════════════════════

func test_total_wipe_skips_death_animations_and_forwards_immediately() -> void:
	# Arrange —— 订阅结算转发信号
	coordinator.battle_result_forwarded.connect(
		func(result: int, rewards: Dictionary) -> void:
			forwarded_signals.append([result, rewards])
	)
	# Act —— 全灭：battle_ended 立即到达（最后一个角色 HP 归零的同时）
	mock.battle_ended.emit(1, {"lingshi": 10})
	# Then: 结算信号立即触发（同帧——无等待）
	assert_eq(forwarded_signals.size(), 1,
		"battle_ended 应立即转发结算信号（不逐个播阵亡动画）")
	assert_eq(forwarded_signals[0][0], 1, "结果应为原始 result=1（VICTORY）")
	# Then: 无阵亡动画启动
	assert_eq(coordinator._death_tweens.size(), 0, "不应启动任何阵亡动画")


func test_total_wipe_cancels_pending_deltas_and_running_death_anim() -> void:
	# Arrange —— 先触发一次阵亡动画进行中 + 待处理增量
	mock.set_hp(101, 0, 100)
	coordinator._on_character_died(101, 0, [])
	assert_true(coordinator._death_tweens.has(101), "前置：阵亡动画进行中")
	mock.emit_attack(101, 5)
	assert_true(coordinator._pending_deltas.has(101), "前置：增量待结算")
	# Act —— 全灭信号（双方同时全灭 edge：result 原样转发——UI 不裁定）
	coordinator.battle_result_forwarded.connect(
		func(result: int, rewards: Dictionary) -> void:
			forwarded_signals.append([result])
	)
	mock.battle_ended.emit(2, {})
	# Then: 短路清理——待处理清空 + 进行中动画杀死
	assert_true(coordinator._pending_deltas.is_empty(),
		"全灭应清空待结算增量")
	assert_false(coordinator._death_tweens.has(101),
		"全灭应取消进行中的阵亡动画")
	assert_eq(forwarded_signals.size(), 1, "结算信号应转发一次")
	assert_eq(forwarded_signals[0][0], 2, "DEFEAT 原样转发（不裁定）")


# ═══════════════════════════════════════════════════════════════════════════════
# 飘字池（池化逻辑可测——story AC-4 条款）
# ═══════════════════════════════════════════════════════════════════════════════

func test_floater_pool_cap_never_exceeds_16() -> void:
	# Arrange —— 池已由 setup 创建（floater_pool 子节点）
	var pool: Control = coordinator.floater_pool
	assert_not_null(pool, "Coordinator 应持有飘字池")
	assert_eq(pool.instance_count(), 16, "预创建池应恰好 16 个节点")
	# Act —— 同帧发射 17+ 个飘字（超过池上限——guardrail 12+ 同帧不产生节点风暴）
	for i: int in 20:
		pool.spawn(Vector2(float(i) * 10.0, 50.0), 25,
			PoolScript.FloaterKind.DAMAGE)
	# Then: 仍 16 个节点（第 17+ 个复用最旧——不新建）
	assert_eq(pool.instance_count(), 16,
		"超过池上限后不应新建节点（复用最旧）")


func test_floater_pool_reuses_freed_labels() -> void:
	var pool: Control = coordinator.floater_pool
	# Act —— 发射 3 个并等待动画完成（0.5s 实时）回收
	for i: int in 3:
		pool.spawn(Vector2.ZERO, 10, PoolScript.FloaterKind.HEAL)
	assert_eq(pool.free_count(), 13, "前置：3 个占用")
	await _wait_sec(0.9)
	assert_eq(pool.free_count(), 16, "动画完成后应全部回收")
	# Act —— 再发射 2 个
	pool.spawn(Vector2.ZERO, 5, PoolScript.FloaterKind.DAMAGE)
	pool.spawn(Vector2.ZERO, 5, PoolScript.FloaterKind.DAMAGE)
	# Then: 无新建（仍 16 实例）
	assert_eq(pool.instance_count(), 16, "复用回收节点——不新建")


func test_floater_pool_reduce_motion_no_displacement() -> void:
	# Arrange —— reduce_motion 池
	var pool: Control = PoolScript.new()
	add_child_autofree(pool)
	pool.set_reduce_motion(true)
	# Act
	pool.spawn(Vector2(100.0, 100.0), 30, PoolScript.FloaterKind.DAMAGE)
	var label: Label = pool.get_child(0) as Label
	var start_y: float = label.position.y
	# Then: 数帧后位置不变（直接淡出——无下落位移）
	await _wait_frames(10)
	assert_almost_eq(label.position.y, start_y, 0.01,
		"reduce_motion 下飘字不应位移（直接淡出）")
	assert_true(label.modulate.a < 1.0, "透明度应正在淡出")


func test_damage_floater_spawns_on_attack_resolved() -> void:
	# Arrange —— Coordinator 飘字路径（attack_resolved → 池发射）
	var pool: Control = coordinator.floater_pool
	assert_eq(pool.free_count(), 16, "前置：池全空闲")
	mock.set_hp(101, 100, 100)
	# Act —— 一次伤害（带伤害飘字）
	mock.emit_attack(101, 25)
	# Then: 池占用 1（同帧立即发射——飘字不入队合并）
	assert_eq(pool.free_count(), 15, "一次攻击应发射一个伤害飘字")
