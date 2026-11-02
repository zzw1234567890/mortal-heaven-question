extends GutTest
## combat-ui-layout Story 005 集成测试：费用显示（AC-2）。
##
## 覆盖：费用信号驱动显示、临时费用加入绿色段、同帧多次变更终值生效、
## cost_color 颜色落定、消耗动画 Tween（reduce_motion 跳过）、临时费用
## 用完淡出。
##
## Story 类型 UI（Logic 内核）——此文件为 BLOCKING 证据。
## 风格先例：tests/integration/combat_ui/test_formation_zone.gd。

const BottombarScript := preload("res://src/ui/combat/layout/combat_bottombar.gd")
const MockBottombarSignals := preload("res://tests/integration/combat_ui/mocks/mock_bottombar_signals.gd")

var bottombar: CombatBottombar = null


func before_each() -> void:
	bottombar = BottombarScript.new()
	add_child_autofree(bottombar)


# ═══════════════════════════════════════════════════════════════════════════════
# AC-2：费用信号驱动显示
# ═══════════════════════════════════════════════════════════════════════════════

func test_cost_display_updates_on_cost_state() -> void:
	# When: 费用状态 5/5 → 扣 2 → 3/5
	bottombar.apply_cost_state(5, 5, 0)
	assert_eq(bottombar.cost_bar.get_cost_text(), "5 / 5", "初始应显示 5/5")
	bottombar.apply_cost_state(3, 5, 0)
	# Then: 数字断言（动画归手动验证）
	assert_eq(bottombar.cost_bar.get_cost_text(), "3 / 5", "扣费后应显示 3/5")


func test_cost_display_temp_bonus_shows_green_segment() -> void:
	# When: 临时费用 +3（丹药）
	bottombar.apply_cost_state(3, 0, 3)
	# Then: 主数字「3 / 0」（available 含临时 / 基础上限 0）+ 绿色段「[+3临时]」
	assert_eq(bottombar.cost_bar.get_cost_text(), "3 / 0", "可用 3 / 基础上限 0")
	assert_true(bottombar.cost_bar.is_temp_visible(), "临时费用段应可见")
	assert_eq(bottombar.cost_bar.get_temp_text(), "[+3临时]", "临时数字应 +3")


func test_cost_display_color_follows_cost_color() -> void:
	# Then: 颜色经 cost_color 纯函数解析（base_max=0 守卫例）
	bottombar.apply_cost_state(0, 0, 0)
	assert_eq(bottombar.cost_bar.get_cost_color(), CombatUiRules.COST_COLOR_RED,
			"(0,0,0) 费用色应为红")
	bottombar.apply_cost_state(3, 0, 3)
	assert_eq(bottombar.cost_bar.get_cost_color(), CombatUiRules.COST_COLOR_YELLOW,
			"(3,0,3) 费用色应为黄——仅临时")


func test_cost_display_same_frame_multiple_updates_final_value_wins() -> void:
	# When: 同帧多次变更（5/5 → 2/5 → 4/5）
	bottombar.apply_cost_state(5, 5, 0)
	bottombar.apply_cost_state(2, 5, 0)
	bottombar.apply_cost_state(4, 5, 0)
	# Then: 终值生效
	assert_eq(bottombar.cost_bar.get_cost_text(), "4 / 5", "同帧多次变更终值应生效")


func test_cost_display_temp_used_up_fades() -> void:
	# When: 临时费用 +3 后用尽归零（基础费用不变）
	bottombar.apply_cost_state(3, 0, 3)
	assert_true(bottombar.cost_bar.is_temp_visible(), "前置：临时费用可见")
	bottombar.apply_cost_state(0, 0, 0)
	# Then: 临时段进入淡出（动画进行中可见——AC-4 淡出视觉）
	assert_true(bottombar.cost_bar.has_temp_fade_active(), "临时费用用完应触发淡出动画")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-3：消耗动画（reduce_motion 跳过——Tween 创建断言）
# ═══════════════════════════════════════════════════════════════════════════════

func test_cost_jump_anim_tween_created_and_reduce_motion_skips() -> void:
	# 非 reduce_motion：数字跳动 Tween 创建
	bottombar.apply_cost_state(5, 5, 0)
	bottombar.apply_cost_state(3, 5, 0)
	assert_true(bottombar.cost_bar.has_jump_anim_active(),
			"费用消耗应创建数字跳动 Tween")
	# reduce_motion：跳过动画（无 Tween）
	var rm := BottombarScript.new()
	add_child_autofree(rm)
	rm.set_reduce_motion(true)
	rm.apply_cost_state(5, 5, 0)
	rm.apply_cost_state(3, 5, 0)
	assert_false(rm.cost_bar.has_jump_anim_active(), "reduce_motion 应跳过数字跳动动画")


func test_cost_jump_scale_reset_when_not_spending() -> void:
	# 非消耗路径（费用增加/不变）不触发跳动且 scale 复位——中断跳动不残留
	bottombar.apply_cost_state(5, 5, 0)
	bottombar.apply_cost_state(3, 5, 0)  # 触发跳动
	bottombar.apply_cost_state(5, 5, 0)  # 加费——非消耗路径
	assert_eq(bottombar.cost_bar.cost_label.scale, Vector2.ONE,
			"非消耗路径应复位数字 scale 为 ONE")


func test_cost_temp_fade_reentry_keeps_visible() -> void:
	# 临时费用用完触发淡出后，同帧重新注入——旧 fade 不得把数字再隐藏
	bottombar.apply_cost_state(3, 0, 3)   # 临时 +3
	bottombar.apply_cost_state(0, 0, 0)   # 用完触发淡出
	bottombar.apply_cost_state(3, 0, 3)   # 同帧重新注入
	assert_true(bottombar.cost_bar.is_temp_visible(),
			"淡出窗口内重新注入临时费用，绿色段应保持可见")
	assert_eq(bottombar.cost_bar.temp_label.modulate.a, 1.0,
			"重新显示时 alpha 应恢复为 1.0")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-5：牌库/弃牌计数 + AC-7：结束出牌按钮
# ═══════════════════════════════════════════════════════════════════════════════

func test_deck_counter_displays_counts() -> void:
	# When: 设置牌库/弃牌计数
	bottombar.set_deck_counts(12, 3)
	# Then: 数字显示正确
	assert_eq(bottombar.deck_counter.get_deck_count(), 12, "牌库计数应 12")
	assert_eq(bottombar.deck_counter.get_discard_count(), 3, "弃牌计数应 3")
	assert_eq(bottombar.deck_counter.get_deck_text(), "≡牌库:12", "牌库文本")
	assert_eq(bottombar.deck_counter.get_discard_text(), "弃:3", "弃牌文本")


func test_deck_counter_negative_counts_clamped() -> void:
	# When: 负值防御性钳制
	bottombar.set_deck_counts(-1, -5)
	# Then: 钳制为 0
	assert_eq(bottombar.deck_counter.get_deck_count(), 0, "负牌库应钳制为 0")
	assert_eq(bottombar.deck_counter.get_discard_count(), 0, "负弃牌应钳制为 0")


func test_end_turn_button_only_visible_in_phase_2() -> void:
	# When: 依次推进阶段 0→6
	for phase: int in range(7):
		bottombar.end_turn_button.apply_phase(phase)
		# Then: 仅阶段 2 可见
		assert_eq(bottombar.end_turn_button.is_visible_in_phase(), phase == 2,
				"阶段 %d 结束出牌按钮可见性应为 %s" % [phase, str(phase == 2)])


func test_end_turn_button_always_enabled() -> void:
	# Then: 启用态常亮（player_confirmed_end 无前置条件——玩家可能想跳过攻击）
	bottombar.end_turn_button.apply_phase(2)
	assert_true(bottombar.end_turn_button.is_enabled(), "结束出牌按钮应常亮")


func test_bottombar_phase_changed_routes_to_end_turn_button() -> void:
	# Arrange —— 注入 mock 信号源
	var mock := MockBottombarSignals.new()
	add_child_autofree(mock)
	bottombar.bind_signals(mock)
	# When: phase_changed 到阶段 2（经 bottombar 路由）
	mock.phase_changed.emit(1, 2, 1)
	# Then: 结束出牌按钮可见
	assert_true(bottombar.end_turn_button.is_visible_in_phase(),
			"阶段 2 经 bottombar 路由应显示结束出牌按钮")
	# When: 阶段 2 退出
	mock.phase_changed.emit(2, 3, 1)
	# Then: 按钮隐藏
	assert_false(bottombar.end_turn_button.is_visible_in_phase(),
			"阶段 3 退出后结束出牌按钮应隐藏")


func test_bottombar_cost_changed_routes_to_cost_bar() -> void:
	# Arrange —— 注入 mock 费用信号源（AC-2 信号驱动端到端）
	var mock := MockBottombarSignals.new()
	add_child_autofree(mock)
	bottombar.bind_signals(null, mock)
	# When: cost_changed(5, 5, 5) → 满费（total_max=5, 临时=0）
	mock.cost_changed.emit(5, 5, 5)
	assert_eq(bottombar.cost_bar.get_cost_text(), "5 / 5", "满费信号应显示 5/5")
	# When: cost_changed(3, 5, 5) → 扣 2 费
	mock.cost_changed.emit(3, 5, 5)
	assert_eq(bottombar.cost_bar.get_cost_text(), "3 / 5", "扣费信号应显示 3/5")
	# When: cost_changed(3, 5, 8) → 临时 +3（total_max 8 - max_show 5 = 临时 3）
	mock.cost_changed.emit(3, 5, 8)
	assert_eq(bottombar.cost_bar.get_temp_text(), "[+3临时]",
			"total_max-max_show 应解包为临时 3")
	assert_true(bottombar.cost_bar.is_temp_visible(), "临时费用段应可见")
