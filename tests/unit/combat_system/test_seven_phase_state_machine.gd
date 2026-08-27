extends GutTest
## Story 001 验收测试：7 阶段回合状态机（advance_phase 确定性推进 + 阶段转换校验）。
##
## 覆盖 AC-001 到 AC-013（13 条 AC）。
## 测试策略：
##   - CS_SCRIPT.new() 构造 CombatSystem 实例（不调 _ready）
##   - set_auto_advance(false) 禁用 call_deferred 自动推进——手动控制 advance_phase
##   - set_battle_active(true) 设置战斗活跃——进入 PREPARATION(0) 阶段
##   - 动态分派：var cs: Node 持有，返回值显式类型注解
##   - 信号捕获用 Dictionary 可变容器（同 4-20 先例——lambda 按值捕获基元类型）
##
## 设计文档来源：ADR-0008 §验证标准 §advance_phase 核心算法 §阶段转换验证矩阵
## Story 来源：production/epics/combat-system/story-001-seven-phase-state-machine.md

const CS_SCRIPT := preload("res://src/feature/combat_system.gd")

var cs: Node = null


func before_each() -> void:
	cs = CS_SCRIPT.new()
	cs.call("set_auto_advance", false)
	cs.call("set_scene_change", false)
	cs.call("set_battle_active", true)
	cs.call("set_rng_seed", 42)


func after_each() -> void:
	if cs != null:
		cs.free()
		cs = null


## 信号捕获容器——用 Dictionary 绕过 lambda 按值捕获基元类型的问题（同 4-20 先例）。
func _capture_phase_changed() -> Dictionary:
	var state := {"received": false, "old": -1, "new": -1, "turn": -1, "count": 0}
	cs.connect("phase_changed", func(old_p: int, new_p: int, turn: int):
		state["received"] = true
		state["old"] = old_p
		state["new"] = new_p
		state["turn"] = turn
		state["count"] += 1)
	return state


# ============================================================================
# AC-001：CombatPhase 枚举 7 阶段取值
# ============================================================================

func test_ac001_combat_phase_enum_values() -> void:
	assert_eq(CS_SCRIPT.CombatPhase.PREPARATION, 0, "PREPARATION=0")
	assert_eq(CS_SCRIPT.CombatPhase.DRAW, 1, "DRAW=1")
	assert_eq(CS_SCRIPT.CombatPhase.PLAY, 2, "PLAY=2")
	assert_eq(CS_SCRIPT.CombatPhase.ATTACK_DECLARATION, 3, "ATTACK_DECLARATION=3")
	assert_eq(CS_SCRIPT.CombatPhase.ATTACK_RESOLUTION, 4, "ATTACK_RESOLUTION=4")
	assert_eq(CS_SCRIPT.CombatPhase.ENEMY_TURN, 5, "ENEMY_TURN=5")
	assert_eq(CS_SCRIPT.CombatPhase.END, 6, "END=6")


func test_ac001_end_wraps_to_preparation() -> void:
	# END(6) + 1 回绕到 PREPARATION(0)
	cs.call("set_battle_active", false)  # 先关闭
	cs.call("set_battle_active", true)
	# 手动推进到 END
	for i in range(6):
		assert_true(cs.call("advance_phase"), "推进到下一阶段")
	assert_eq(cs.call("get_current_phase"), CS_SCRIPT.CombatPhase.END, "当前为 END(6)")
	# END → PREPARATION
	assert_true(cs.call("advance_phase"), "END→PREPARATION 推进")
	assert_eq(cs.call("get_current_phase"), CS_SCRIPT.CombatPhase.PREPARATION, "回绕到 PREPARATION(0)")


# ============================================================================
# AC-002：advance_phase 确定性序列
# ============================================================================

func test_ac002_advance_phase_emits_phase_changed() -> void:
	var sig := _capture_phase_changed()
	# 当前 PREPARATION(0) → DRAW(1)
	var ok: bool = cs.call("advance_phase")
	assert_true(ok, "advance_phase 返回 true")
	assert_true(sig["received"], "phase_changed 信号已发射")
	assert_eq(sig["old"], 0, "old_phase=PREPARATION(0)")
	assert_eq(sig["new"], 1, "new_phase=DRAW(1)")
	assert_eq(sig["count"], 1, "信号发射 1 次")


func test_ac002_advance_phase_updates_internal_phase() -> void:
	assert_eq(cs.call("get_current_phase"), 0, "初始 PREPARATION(0)")
	cs.call("advance_phase")
	assert_eq(cs.call("get_current_phase"), 1, "推进后 DRAW(1)")


# ============================================================================
# AC-003：验证失败返回 false 不推进
# ============================================================================

func test_ac003_validation_failure_returns_false() -> void:
	# 推进到 PLAY(2)
	cs.call("advance_phase")  # 0→1
	cs.call("advance_phase")  # 1→2
	assert_eq(cs.call("get_current_phase"), 2, "当前 PLAY(2)")
	# 未确认结束、未超时、手牌非空 → _validate_transition 返回 false
	# 注入手牌使 hand 非空
	cs.call("set_deck_state", [1, 2, 3], [], [10, 20])  # hand=[10,20]
	var ok: bool = cs.call("advance_phase")
	assert_false(ok, "PLAY→ATK_DEC 未确认时返回 false")
	assert_eq(cs.call("get_current_phase"), 2, "阶段仍为 PLAY(2)")


func test_ac003_validation_failure_no_signal() -> void:
	cs.call("advance_phase")  # 0→1
	cs.call("advance_phase")  # 1→2
	cs.call("set_deck_state", [1, 2, 3], [], [10, 20])  # hand 非空
	var sig := _capture_phase_changed()
	var ok: bool = cs.call("advance_phase")
	assert_false(ok, "推进失败")
	assert_false(sig["received"], "失败时不发射 phase_changed")
	assert_eq(sig["count"], 0, "信号未发射")


# ============================================================================
# AC-004：非活跃战斗 advance_phase 报错
# ============================================================================

func test_ac004_inactive_battle_returns_false() -> void:
	cs.call("set_battle_active", false)
	var ok: bool = cs.call("advance_phase")
	assert_false(ok, "非活跃战斗 advance_phase 返回 false")


func test_ac004_inactive_battle_no_phase_change() -> void:
	cs.call("set_battle_active", false)
	var phase_before: int = cs.call("get_current_phase")
	cs.call("advance_phase")
	assert_eq(cs.call("get_current_phase"), phase_before, "非活跃时阶段不变")


# ============================================================================
# AC-005：无条件自动推进阶段
# ============================================================================

func test_ac005_preparation_to_draw() -> void:
	assert_true(cs.call("advance_phase"), "0→1 推进成功")
	assert_eq(cs.call("get_current_phase"), 1, "当前 DRAW(1)")


func test_ac005_draw_to_play() -> void:
	cs.call("advance_phase")  # 0→1
	assert_true(cs.call("advance_phase"), "1→2 推进成功")
	assert_eq(cs.call("get_current_phase"), 2, "当前 PLAY(2)")


func test_ac005_attack_resolution_to_enemy_turn() -> void:
	# 推进到 PLAY(2)，确认结束跳到 ATK_DEC(3)，空队列跳到 ATK_RES(4)
	cs.call("advance_phase")  # 0→1
	cs.call("advance_phase")  # 1→2
	cs.call("confirm_end_turn")  # 2→3（空队列自动放行）
	cs.call("advance_phase")  # 3→4（空队列空真）
	assert_eq(cs.call("get_current_phase"), 4, "当前 ATK_RES(4)")
	assert_true(cs.call("advance_phase"), "4→5 推进成功")
	assert_eq(cs.call("get_current_phase"), 5, "当前 ENEMY_TURN(5)")


func test_ac005_enemy_turn_to_end() -> void:
	cs.call("advance_phase")  # 0→1
	cs.call("advance_phase")  # 1→2
	cs.call("confirm_end_turn")  # 2→3
	cs.call("advance_phase")  # 3→4
	cs.call("advance_phase")  # 4→5
	assert_true(cs.call("advance_phase"), "5→6 推进成功")
	assert_eq(cs.call("get_current_phase"), 6, "当前 END(6)")


func test_ac005_end_to_preparation_increments_turn() -> void:
	cs.call("advance_phase")  # 0→1
	cs.call("advance_phase")  # 1→2
	cs.call("confirm_end_turn")  # 2→3
	cs.call("advance_phase")  # 3→4
	cs.call("advance_phase")  # 4→5
	cs.call("advance_phase")  # 5→6
	var turn_before: int = cs.call("get_turn_number")
	assert_eq(turn_before, 1, "第 1 回合")
	assert_true(cs.call("advance_phase"), "6→0 推进成功")
	assert_eq(cs.call("get_current_phase"), 0, "当前 PREPARATION(0)")
	assert_eq(cs.call("get_turn_number"), 2, "回合递增为 2")


# ============================================================================
# AC-006：PLAY→ATTACK_DECLARATION 推进条件
# ============================================================================

func test_ac006_play_to_attack_via_confirm_end() -> void:
	cs.call("advance_phase")  # 0→1
	cs.call("advance_phase")  # 1→2
	assert_eq(cs.call("get_current_phase"), 2, "当前 PLAY(2)")
	var ok: bool = cs.call("confirm_end_turn")
	assert_true(ok, "confirm_end_turn 推进成功")
	assert_eq(cs.call("get_current_phase"), 3, "当前 ATTACK_DECLARATION(3)")


func test_ac006_play_to_attack_via_timer_exceeded() -> void:
	cs.call("advance_phase")  # 0→1
	cs.call("advance_phase")  # 1→2
	cs.call("set_timer_exceeded")
	var ok: bool = cs.call("advance_phase")
	assert_true(ok, "timer_exceeded 推进成功")
	assert_eq(cs.call("get_current_phase"), 3, "当前 ATTACK_DECLARATION(3)")


func test_ac006_play_to_attack_via_empty_hand_and_cannot_afford() -> void:
	cs.call("advance_phase")  # 0→1
	cs.call("advance_phase")  # 1→2
	# 手牌为空 + _can_afford_any_card 返回 false（空手牌时 false）
	cs.call("set_deck_state", [], [], [])  # hand=[]
	var ok: bool = cs.call("advance_phase")
	assert_true(ok, "空手牌+不可支付 推进成功")
	assert_eq(cs.call("get_current_phase"), 3, "当前 ATTACK_DECLARATION(3)")


func test_ac006_play_rejected_when_all_conditions_fail() -> void:
	cs.call("advance_phase")  # 0→1
	cs.call("advance_phase")  # 1→2
	# 手牌非空、未确认、未超时
	cs.call("set_deck_state", [1, 2, 3], [], [10, 20])  # hand=[10,20]
	var ok: bool = cs.call("advance_phase")
	assert_false(ok, "三条件均不满足时返回 false")
	assert_eq(cs.call("get_current_phase"), 2, "阶段仍为 PLAY(2)")


# ============================================================================
# AC-007：ATTACK_DECLARATION→ATTACK_RESOLUTION 推进条件
# ============================================================================

func test_ac007_attack_dec_to_resolution_via_empty_queue() -> void:
	cs.call("advance_phase")  # 0→1
	cs.call("advance_phase")  # 1→2
	cs.call("confirm_end_turn")  # 2→3
	# 攻击队列为空（_all_characters_targeted 空真）
	var ok: bool = cs.call("advance_phase")
	assert_true(ok, "空队列推进成功")
	assert_eq(cs.call("get_current_phase"), 4, "当前 ATTACK_RESOLUTION(4)")


func test_ac007_attack_dec_to_resolution_via_confirm_skip() -> void:
	cs.call("advance_phase")  # 0→1
	cs.call("advance_phase")  # 1→2
	cs.call("confirm_end_turn")  # 2→3
	# 注入非空攻击队列使 _all_characters_targeted 返回 false
	cs.call("set_attack_queue", [{"attacker": 1, "target": 2}])
	var ok: bool = cs.call("confirm_attack_targets")
	assert_true(ok, "confirm_attack_targets 推进成功")
	assert_eq(cs.call("get_current_phase"), 4, "当前 ATTACK_RESOLUTION(4)")


# ============================================================================
# AC-008：自动阶段 call_deferred 推进
# ============================================================================

func test_ac008_auto_advance_deferred() -> void:
	# 重置战斗状态——before_each 以 auto_advance=false 初始化，此处切换
	cs.call("set_battle_active", false)
	cs.call("set_auto_advance", true)
	cs.call("set_battle_active", true)  # was_active=false + auto_advance=true → _enter_phase(PREPARATION) → call_deferred(advance_phase)
	# 等待 2 帧——call_deferred 在帧末执行
	# 帧 1 末：advance_phase 0→1 DRAW → _enter_phase(DRAW) → call_deferred(advance_phase)
	# 帧 2 末：advance_phase 1→2 PLAY → _enter_phase(PLAY) → 手动阶段不推进
	await get_tree().process_frame
	await get_tree().process_frame
	var phase: int = cs.call("get_current_phase")
	assert_true(phase >= CS_SCRIPT.CombatPhase.PLAY, "自动推进至少到 PLAY(2)，实际=%d" % phase)


func test_ac008_auto_advance_disabled_when_inactive() -> void:
	cs.call("set_auto_advance", true)
	cs.call("set_battle_active", false)
	# _schedule_auto_advance 在 _is_active=false 时不调度
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(cs.call("get_current_phase"), CS_SCRIPT.CombatPhase.PREPARATION, "非活跃时阶段不变")


# ============================================================================
# AC-009：手动阶段等待输入
# ============================================================================

func test_ac009_play_phase_waits_for_input() -> void:
	cs.call("advance_phase")  # 0→1
	cs.call("advance_phase")  # 1→2
	# PLAY(2) 是手动阶段——不自动推进
	cs.call("set_deck_state", [1, 2, 3], [], [10, 20])  # hand 非空
	# 模拟等待几帧
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(cs.call("get_current_phase"), 2, "PLAY 阶段不自动推进")


func test_ac009_attack_declaration_waits_for_input() -> void:
	cs.call("advance_phase")  # 0→1
	cs.call("advance_phase")  # 1→2
	cs.call("confirm_end_turn")  # 2→3
	# 注入非空攻击队列使 _all_characters_targeted 返回 false
	cs.call("set_attack_queue", [{"attacker": 1, "target": 2}])
	# ATTACK_DECLARATION(3) 是手动阶段——不自动推进
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(cs.call("get_current_phase"), 3, "ATK_DEC 阶段不自动推进")


# ============================================================================
# AC-010：完整 1 回合流程
# ============================================================================

func test_ac010_full_round_flow() -> void:
	# Phase 0→1
	assert_true(cs.call("advance_phase"), "0→1")
	assert_eq(cs.call("get_current_phase"), 1, "DRAW(1)")
	# Phase 1→2
	assert_true(cs.call("advance_phase"), "1→2")
	assert_eq(cs.call("get_current_phase"), 2, "PLAY(2)")
	# Phase 2→3（手动确认）
	assert_true(cs.call("confirm_end_turn"), "2→3")
	assert_eq(cs.call("get_current_phase"), 3, "ATK_DEC(3)")
	# Phase 3→4（空队列自动放行）
	assert_true(cs.call("advance_phase"), "3→4")
	assert_eq(cs.call("get_current_phase"), 4, "ATK_RES(4)")
	# Phase 4→5
	assert_true(cs.call("advance_phase"), "4→5")
	assert_eq(cs.call("get_current_phase"), 5, "ENEMY_TURN(5)")
	# Phase 5→6
	assert_true(cs.call("advance_phase"), "5→6")
	assert_eq(cs.call("get_current_phase"), 6, "END(6)")
	# Phase 6→0 + turn 递增
	assert_eq(cs.call("get_turn_number"), 1, "第 1 回合")
	assert_true(cs.call("advance_phase"), "6→0")
	assert_eq(cs.call("get_current_phase"), 0, "PREPARATION(0)")
	assert_eq(cs.call("get_turn_number"), 2, "第 2 回合")


# ============================================================================
# AC-011：Phase 2 超时推进
# ============================================================================

func test_ac011_phase2_timeout_advances() -> void:
	cs.call("advance_phase")  # 0→1
	cs.call("advance_phase")  # 1→2
	cs.call("set_timer_exceeded")
	assert_true(cs.call("advance_phase"), "超时后推进成功")
	assert_eq(cs.call("get_current_phase"), 3, "ATK_DEC(3)")


# ============================================================================
# AC-012：Phase 3 空攻击队列自动跳过
# ============================================================================

func test_ac012_empty_attack_queue_auto_advances() -> void:
	cs.call("advance_phase")  # 0→1
	cs.call("advance_phase")  # 1→2
	cs.call("confirm_end_turn")  # 2→3
	# 攻击队列为空（首回合所有角色待命）
	assert_true(cs.call("advance_phase"), "空队列自动推进")
	assert_eq(cs.call("get_current_phase"), 4, "ATK_RES(4)")


func test_ac012_first_round_attack_skipped() -> void:
	# 模拟首回合：所有角色待命 → 无可攻击角色 → 空队列
	cs.call("advance_phase")  # 0→1
	cs.call("advance_phase")  # 1→2
	cs.call("confirm_end_turn")  # 2→3
	# 不注入攻击队列 → _attack_queue 为空 → _all_characters_targeted() 返回 true
	assert_true(cs.call("advance_phase"), "首回合 ATK_DEC 自动跳过")
	assert_eq(cs.call("get_current_phase"), 4, "直接进入 ATK_RES(4)")


# ============================================================================
# AC-013：牌库抽空返还
# ============================================================================

func test_ac013_empty_deck_returns_from_discard() -> void:
	# 牌库空 + 弃牌堆非空 → 随机返还 1 张到牌库底部 → 抽牌
	cs.call("set_deck_state", [], [101, 102, 103], [])  # deck=[], discard=[101,102,103]
	cs.call("_draw_cards", 1)
	# 抽牌后手牌应有 1 张（从弃牌堆返还的）
	var hand: Array = cs.call("get_hand")
	assert_eq(hand.size(), 1, "抽 1 张后手牌 1 张")
	# 牌库应空（返还 1 张后立即抽出）
	var deck: Array = cs.call("get_deck")
	assert_eq(deck.size(), 0, "牌库仍为空（返还后立即抽出）")
	# 弃牌堆应少 1 张
	var discard: Array = cs.call("get_discard_pile")
	assert_eq(discard.size(), 2, "弃牌堆减少 1 张")


func test_ac013_empty_deck_and_empty_discard_skips_draw() -> void:
	cs.call("set_deck_state", [], [], [])  # deck=[], discard=[]
	cs.call("_draw_cards", 3)  # 尝试抽 3 张
	var hand: Array = cs.call("get_hand")
	assert_eq(hand.size(), 0, "牌库+弃牌堆均空 → 跳过抽牌")
	var deck: Array = cs.call("get_deck")
	assert_eq(deck.size(), 0, "牌库仍为空")


func test_ac013_discard_card_goes_to_deck_bottom() -> void:
	# 返还的牌应到牌库底部——抽取从顶部
	cs.call("set_deck_state", [], [201, 202], [])
	cs.call("_draw_cards", 1)
	var hand: Array = cs.call("get_hand")
	assert_eq(hand.size(), 1, "抽 1 张")
	# 返还后牌库应有 1 张（在底部），但立即从顶部抽出
	# 所以牌库为空，弃牌堆少 1
	assert_true(hand[0] == 201 or hand[0] == 202, "抽到的是弃牌堆中的牌")


# ============================================================================
# 综合：完整 2 回合流程 + 信号验证
# ============================================================================

func test_full_two_rounds_with_signal_verification() -> void:
	var sig := _capture_phase_changed()
	# 第 1 回合
	cs.call("advance_phase")  # 0→1 DRAW
	assert_eq(sig["new"], 1, "→DRAW")
	cs.call("advance_phase")  # 1→2 PLAY
	assert_eq(sig["new"], 2, "→PLAY")
	cs.call("confirm_end_turn")  # 2→3 ATK_DEC
	assert_eq(sig["new"], 3, "→ATK_DEC")
	cs.call("advance_phase")  # 3→4 ATK_RES
	assert_eq(sig["new"], 4, "→ATK_RES")
	cs.call("advance_phase")  # 4→5 ENEMY
	assert_eq(sig["new"], 5, "→ENEMY")
	cs.call("advance_phase")  # 5→6 END
	assert_eq(sig["new"], 6, "→END")
	cs.call("advance_phase")  # 6→0 PREP（turn=2）
	assert_eq(sig["new"], 0, "→PREPARATION")
	assert_eq(sig["turn"], 2, "第 2 回合")
	# 第 2 回合
	cs.call("advance_phase")  # 0→1
	cs.call("advance_phase")  # 1→2
	cs.call("confirm_end_turn")  # 2→3
	cs.call("advance_phase")  # 3→4
	cs.call("advance_phase")  # 4→5
	cs.call("advance_phase")  # 5→6
	cs.call("advance_phase")  # 6→0（turn=3）
	assert_eq(cs.call("get_turn_number"), 3, "第 3 回合")
	assert_eq(sig["count"], 14, "2 回合共 14 次 phase_changed")


# ============================================================================
# QA MAJOR-1：_exit_phase 副作用——flag 重置验证
# ============================================================================

func test_exit_phase_play_resets_confirm_flag() -> void:
	# 验证 _exit_phase(PLAY) 重置 _player_confirmed_end=false
	cs.call("advance_phase")  # 0→1
	cs.call("advance_phase")  # 1→2
	cs.call("confirm_end_turn")  # 2→3，_exit_phase(PLAY) 应重置 flag
	# 推进到第 2 回合的 PLAY 阶段
	cs.call("advance_phase")  # 3→4
	cs.call("advance_phase")  # 4→5
	cs.call("advance_phase")  # 5→6
	cs.call("advance_phase")  # 6→0
	cs.call("advance_phase")  # 0→1
	cs.call("advance_phase")  # 1→2 → PLAY(2)
	# 注入非空手牌使条件不满足
	cs.call("set_deck_state", [1, 2, 3], [], [10, 20])
	# 如果 flag 未重置，advance_phase 会因 _player_confirmed_end=true 而放行
	var ok: bool = cs.call("advance_phase")
	assert_false(ok, "第 2 回合 PLAY flag 已重置——未确认时拒绝推进")
	assert_eq(cs.call("get_current_phase"), 2, "仍为 PLAY(2)")


func test_exit_phase_attack_dec_resets_skip_flag() -> void:
	# 验证 _exit_phase(ATTACK_DECLARATION) 重置 _player_confirmed_attack_skip=false
	cs.call("advance_phase")  # 0→1
	cs.call("advance_phase")  # 1→2
	cs.call("confirm_end_turn")  # 2→3
	# 注入非空队列使 _all_characters_targeted 返回 false
	cs.call("set_attack_queue", [{"attacker": 1, "target": 2}])
	cs.call("confirm_attack_targets")  # 3→4，_exit_phase(ATK_DEC) 应重置 flag
	# 推进到第 2 回合的 ATK_DEC
	cs.call("advance_phase")  # 4→5
	cs.call("advance_phase")  # 5→6
	cs.call("advance_phase")  # 6→0
	cs.call("advance_phase")  # 0→1
	cs.call("advance_phase")  # 1→2
	cs.call("confirm_end_turn")  # 2→3
	# 注入非空队列
	cs.call("set_attack_queue", [{"attacker": 1, "target": 2}])
	# 如果 skip flag 未重置，advance_phase 会因 _player_confirmed_attack_skip=true 而放行
	var ok: bool = cs.call("advance_phase")
	assert_false(ok, "第 2 回合 ATK_DEC skip flag 已重置——未确认时拒绝推进")
	assert_eq(cs.call("get_current_phase"), 3, "仍为 ATK_DEC(3)")


func test_exit_phase_attack_resolution_clears_queue() -> void:
	# 验证 _exit_phase(ATTACK_RESOLUTION) 清空 _attack_queue
	cs.call("advance_phase")  # 0→1
	cs.call("advance_phase")  # 1→2
	cs.call("confirm_end_turn")  # 2→3
	cs.call("set_attack_queue", [{"attacker": 1, "target": 2}])
	cs.call("confirm_attack_targets")  # 3→4
	# 推进 4→5 时 _exit_phase(ATK_RES) 清空 queue
	cs.call("advance_phase")  # 4→5
	var queue: Array = cs.call("get_attack_queue")
	assert_eq(queue.size(), 0, "_exit_phase(ATK_RES) 清空攻击队列")


# ============================================================================
# QA MAJOR-3：AC-008 帧间隔精确断言
# ============================================================================

func test_ac008_one_frame_per_auto_phase() -> void:
	cs.call("set_battle_active", false)
	cs.call("set_auto_advance", true)
	cs.call("set_battle_active", true)  # 启动自动推进链
	# 关键语义 1：自动推进是延迟的——set_battle_active 后立即检查仍为 PREPARATION(0)
	assert_eq(cs.call("get_current_phase"), 0, "set_battle_active 后立即检查仍为 PREPARATION(0)——未同帧推进")
	# 等待帧——call_deferred 执行后自动阶段链式推进到 PLAY(2) 手动阶段停止
	await get_tree().process_frame
	var phase: int = cs.call("get_current_phase")
	assert_true(phase >= CS_SCRIPT.CombatPhase.PLAY, "帧后自动推进至少到 PLAY(2)，实际=%d" % phase)
	# 关键语义 2：PLAY(2) 是手动阶段——不自动推进
	await get_tree().process_frame
	assert_eq(cs.call("get_current_phase"), phase, "PLAY 手动阶段不自动推进——阶段不变")


# ============================================================================
# QA MAJOR-4：AC-013 多次抽牌+多次返还
# ============================================================================

func test_ac013_multiple_draws_with_multiple_returns() -> void:
	# 牌库 1 张 + 弃牌堆 2 张，抽 3 张
	cs.call("set_deck_state", [1], [101, 102], [])
	cs.call("_draw_cards", 3)
	var hand: Array = cs.call("get_hand")
	assert_eq(hand.size(), 3, "抽 3 张")
	var deck: Array = cs.call("get_deck")
	assert_eq(deck.size(), 0, "牌库耗尽")
	var discard: Array = cs.call("get_discard_pile")
	assert_eq(discard.size(), 0, "弃牌堆全部返还")


func test_ac013_draw_when_both_empty_after_return() -> void:
	# 牌库 0 张 + 弃牌堆 1 张，抽 2 张
	cs.call("set_deck_state", [], [201], [])
	cs.call("_draw_cards", 2)
	var hand: Array = cs.call("get_hand")
	assert_eq(hand.size(), 1, "第 1 次返还后抽出，第 2 次跳过")


# ============================================================================
# QA MAJOR-5：_enter_phase(DRAW) 抽牌集成验证
# ============================================================================

func test_enter_phase_draw_triggers_draw_cards() -> void:
	cs.call("set_deck_state", [1, 2, 3, 4, 5], [], [])
	cs.call("advance_phase")  # 0→1 DRAW，_enter_phase(DRAW) 应抽 2 张
	var hand: Array = cs.call("get_hand")
	assert_eq(hand.size(), 2, "进入 DRAW 阶段后自动抽 2 张")
	var deck: Array = cs.call("get_deck")
	assert_eq(deck.size(), 3, "牌库减少 2 张")


# ============================================================================
# QA MINOR-1：phase_changed 信号 turn 参数验证
# ============================================================================

func test_phase_changed_signal_includes_turn() -> void:
	var sig := _capture_phase_changed()
	cs.call("advance_phase")  # 0→1，turn=1
	assert_eq(sig["turn"], 1, "turn=1（第 1 回合内）")


# ============================================================================
# QA MINOR-2：confirm 方法阶段守卫
# ============================================================================

func test_confirm_end_turn_rejected_outside_play() -> void:
	# 当前 PREPARATION(0)，调用 confirm_end_turn 应失败
	var ok: bool = cs.call("confirm_end_turn")
	assert_false(ok, "非 PLAY 阶段 confirm_end_turn 返回 false")
	assert_eq(cs.call("get_current_phase"), 0, "阶段不变")


func test_confirm_attack_targets_rejected_outside_attack_dec() -> void:
	cs.call("advance_phase")  # 0→1
	cs.call("advance_phase")  # 1→2
	var ok: bool = cs.call("confirm_attack_targets")
	assert_false(ok, "非 ATK_DEC 阶段 confirm_attack_targets 返回 false")
	assert_eq(cs.call("get_current_phase"), 2, "阶段不变")
