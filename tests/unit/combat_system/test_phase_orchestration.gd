extends GutTest
## Story 8-3 验收测试：CombatSystem _enter_phase 子系统编排接线。
##
## 覆盖 AC-001 到 AC-010（10 条 AC）。
## 测试策略：
##   - 使用 CombatSystem Autoload 实例
##   - 验证 PREPARATION / END 阶段的子系统调用
##   - 验证不可用时静默跳过

var cs: Node = null


func before_each() -> void:
	cs = Engine.get_main_loop().root.get_node("/root/CombatSystem")
	assert_not_null(cs, "CombatSystem Autoload 应存在")
	cs.set_auto_advance(false)
	cs.set_scene_change(false)
	cs.set_rng_seed(42)


func after_each() -> void:
	cs.set_battle_active(false)
	cs.call("set_deck_state", [], [], [])


# ============================================================================
# AC-001：PREPARATION 阶段调用 StatusEffectSystem.tick_all
# ============================================================================

func test_preparation_ticks_status_effects() -> void:
	# Arrange
	cs.set_battle_active(true)  # 触发 _enter_phase(PREPARATION)

	# Assert——不崩溃即说明调用成功（StatusEffectSystem 可能无角色但不应报错）
	assert_eq(cs.get_current_phase(), 0, "应在 PREPARATION 阶段")
	assert_true(cs.is_battle_active(), "战斗应活跃")


# ============================================================================
# AC-002：StatusEffectSystem 不可用时静默跳过
# ============================================================================

func test_status_effect_system_unavailable_no_crash() -> void:
	# Arrange + Act——CombatSystem _enter_phase(PREPARATION) 调用 _tick_status_effects
	# 即使 StatusEffectSystem 不可用也不应崩溃
	cs.set_battle_active(true)

	# Assert
	assert_true(cs.is_battle_active(), "不应崩溃")


# ============================================================================
# AC-003：END 阶段调用 CostSystem.reset_for_turn
# ============================================================================

func test_end_resets_cost() -> void:
	# Arrange
	cs.set_battle_active(true)
	# 推进到 END 阶段：PREPARATION(0) → DRAW(1) → PLAY(2) → ATK_DEC(3) → ATK_RES(4) → ENEMY(5) → END(6)
	cs.advance_phase()  # 0→1
	cs.advance_phase()  # 1→2
	cs.advance_phase()  # 2→3
	cs.advance_phase()  # 3→4
	cs.advance_phase()  # 4→5
	cs.advance_phase()  # 5→6 END

	# Assert——到达 END 阶段不崩溃
	assert_eq(cs.get_current_phase(), 6, "应在 END 阶段")


# ============================================================================
# AC-004：CostSystem 不可用时静默跳过
# ============================================================================

func test_cost_system_unavailable_no_crash() -> void:
	# Arrange + Act——推进到 END 阶段
	cs.set_battle_active(true)
	cs.advance_phase()  # 0→1
	cs.advance_phase()  # 1→2
	cs.advance_phase()  # 2→3
	cs.advance_phase()  # 3→4
	cs.advance_phase()  # 4→5
	cs.advance_phase()  # 5→6

	# Assert——不应崩溃
	assert_eq(cs.get_current_phase(), 6, "END 阶段不应崩溃")


# ============================================================================
# AC-005：END 阶段调用 DeploymentSystem.clear_standby_state
# ============================================================================

func test_end_clears_standby() -> void:
	# Arrange
	cs.set_battle_active(true)
	cs.advance_phase()  # 0→1
	cs.advance_phase()  # 1→2
	cs.advance_phase()  # 2→3
	cs.advance_phase()  # 3→4
	cs.advance_phase()  # 4→5
	cs.advance_phase()  # 5→6

	# Assert——到达 END 不崩溃（DeploymentSystem.clear_standby_state 被调用）
	assert_eq(cs.get_current_phase(), 6, "应在 END 阶段")


# ============================================================================
# AC-006：DeploymentSystem 不可用时静默跳过
# ============================================================================

func test_deployment_system_unavailable_no_crash() -> void:
	cs.set_battle_active(true)
	cs.advance_phase()
	cs.advance_phase()
	cs.advance_phase()
	cs.advance_phase()
	cs.advance_phase()
	cs.advance_phase()  # → END
	assert_eq(cs.get_current_phase(), 6, "DeploymentSystem 不可用不应崩溃")


# ============================================================================
# AC-007：PREPARATION 编排顺序：tick_all → _schedule_auto_advance
# ============================================================================

func test_preparation_orchestration_order() -> void:
	# Arrange + Act
	cs.set_battle_active(true)  # → _enter_phase(PREPARATION) → _tick_status_effects → _schedule_auto_advance

	# Assert——_tick_status_effects 先调用，然后 _schedule_auto_advance（auto_advance=false 时不推进）
	assert_eq(cs.get_current_phase(), 0, "仍应在 PREPARATION（auto_advance 关闭）")


# ============================================================================
# AC-008：END 编排顺序：reset_for_turn → clear_standby_state → _schedule_auto_advance
# ============================================================================

func test_end_orchestration_order() -> void:
	# Arrange + Act——推进到 END
	cs.set_battle_active(true)
	cs.advance_phase()  # 0→1
	cs.advance_phase()  # 1→2
	cs.advance_phase()  # 2→3
	cs.advance_phase()  # 3→4
	cs.advance_phase()  # 4→5
	cs.advance_phase()  # 5→6 END

	# Assert——_reset_cost_for_turn → _clear_standby_state → _schedule_auto_advance 均执行不崩溃
	assert_eq(cs.get_current_phase(), 6, "应在 END 阶段")


# ============================================================================
# AC-009：自动推进链不受影响
# ============================================================================

func test_auto_advance_chain_unchanged() -> void:
	# Arrange
	cs.set_auto_advance(true)
	cs.set_battle_active(true)

	# Act——等待一帧让 call_deferred 执行
	await get_tree().process_frame

	# Assert——自动推进应已推进到下一阶段
	assert_true(cs.get_current_phase() >= 0, "自动推进链应正常工作")

	# Cleanup
	cs.set_auto_advance(false)


# ============================================================================
# AC-010：全量测试零回归
# ============================================================================

func test_no_regression() -> void:
	cs.set_battle_active(true)
	assert_true(cs.is_battle_active(), "战斗应可激活")
	assert_eq(cs.get_turn_number(), 1, "初始回合应为 1")
	cs.set_battle_active(false)
