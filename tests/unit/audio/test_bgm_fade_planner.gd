extends GutTest
## audio-manager Story 002 单元测试：BGM 淡化纯计划器（AC-1~AC-5）。
##
## QA 规格：平行交叉淡化计划 / 渡劫顺序例外 / 中断续接 / 同 id 忽略 /
## 降低类不切曲。全部数值决策在计划器——Tween 执行层集成测试覆盖。
##
## Story 类型 Logic——此文件为 BLOCKING 证据。
## 风格先例：tests/unit/combat_ui/test_font_size_responsive.gd。

const Planner := preload("res://src/ui/audio/bgm_fade_planner.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1：平行交叉淡化计划
# ═══════════════════════════════════════════════════════════════════════════════

func test_plan_parallel_crossfade_two_commands() -> void:
	# Given: bgm_a 播放中 db=0，请求 bgm_b（fade_out 1.0 / fade_in 1.5）
	var plan: Array[Dictionary] = Planner.plan_transition(
		&"bgm_a", &"bgm_b", 0.0, Planner.SILENCE_DB, 1.0, 1.5)
	# Then: 2 条指令
	assert_eq(plan.size(), 2, "应产出 2 条指令")
	var out: Dictionary = plan[0]
	var in_cmd: Dictionary = plan[1]
	# Then: a 淡出 0→-80dB/1.0s
	assert_eq(out[Planner.K_TARGET], &"a", "第一条目标为当前播放器 a")
	assert_almost_eq(out[Planner.K_FROM_DB], 0.0, 0.001, "a 起点 0dB")
	assert_almost_eq(out[Planner.K_TO_DB], -80.0, 0.001, "a 终点 -80dB")
	assert_almost_eq(out[Planner.K_DURATION], 1.0, 0.001, "a 时长 1.0s")
	assert_false(out[Planner.K_SEQUENTIAL], "默认平行")
	# Then: b 淡入 -80→0dB/1.5s + 播放目标曲
	assert_eq(in_cmd[Planner.K_TARGET], &"b", "第二条目标为新播放器 b")
	assert_almost_eq(in_cmd[Planner.K_FROM_DB], -80.0, 0.001, "b 起点 -80dB")
	assert_almost_eq(in_cmd[Planner.K_TO_DB], 0.0, 0.001, "b 终点 0dB")
	assert_almost_eq(in_cmd[Planner.K_DURATION], 1.5, 0.001, "b 时长 1.5s")
	assert_eq(in_cmd[Planner.K_PLAY_STREAM], &"bgm_b", "b 应播放 bgm_b")


func test_plan_parallel_crossfade_equal_durations() -> void:
	# Edge: 双方时长相同（探索→战斗 0.5/0.5）
	var plan: Array[Dictionary] = Planner.plan_transition(
		&"bgm_explore", &"bgm_combat", 0.0, Planner.SILENCE_DB, 0.5, 0.5)
	assert_eq(plan.size(), 2, "应产出 2 条指令")
	assert_almost_eq(plan[0][Planner.K_DURATION], 0.5, 0.001)
	assert_almost_eq(plan[1][Planner.K_DURATION], 0.5, 0.001)


func test_plan_crossfade_custom_target_db_via_options() -> void:
	# Edge: 目标 dB 非零（如身份选择 -6dB——经 options 淡入非默认路径）。
	# 计划器 to_db 契约：切曲淡入终值 NORMAL_DB（播放器线性音量）；
	# 场景降低（-6dB）走 BUS 层（AC-5）——此处锁定切曲终值恒 0dB 播放器层，
	# 场景 dB 差异由总线承担（双播放器 volume_db 均以 0dB 为满音量基准）。
	var plan: Array[Dictionary] = Planner.plan_transition(
		&"bgm_main", &"bgm_explore", 0.0, Planner.SILENCE_DB, 1.0, 1.5)
	assert_almost_eq(plan[1][Planner.K_TO_DB], Planner.NORMAL_DB, 0.001,
		"播放器淡入终值应为 NORMAL_DB（场景 dB 由 Bus 层承担）")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-2：渡劫顺序例外
# ═══════════════════════════════════════════════════════════════════════════════

func test_plan_tribulation_sequential() -> void:
	# Given: 请求渡劫 BGM（sequential=true）
	var plan: Array[Dictionary] = Planner.plan_transition(
		&"bgm_explore", &"bgm_tribulation", 0.0, Planner.SILENCE_DB,
		0.3, 0.3, null, true)
	# Then: b 指令 sequential=true（先 a 淡出完成再 b 淡入）
	assert_eq(plan.size(), 2, "顺序式仍 2 条指令")
	assert_false(plan[0][Planner.K_SEQUENTIAL], "a 淡出无序等待")
	assert_true(plan[1][Planner.K_SEQUENTIAL],
		"渡劫 b 淡入应 sequential=true")
	assert_almost_eq(plan[0][Planner.K_DURATION], 0.3, 0.001, "a 0.3s")
	assert_almost_eq(plan[1][Planner.K_DURATION], 0.3, 0.001, "b 0.3s")


func test_plan_tribulation_exit_not_sequential() -> void:
	# Edge: 渡劫→胜利/战败出口按矩阵行非顺序（0.3/0.5 平行）
	var plan: Array[Dictionary] = Planner.plan_transition(
		&"bgm_tribulation", &"bgm_victory", 0.0, Planner.SILENCE_DB, 0.3, 0.5)
	assert_false(plan[1][Planner.K_SEQUENTIAL],
		"渡劫出口过渡应为平行（按矩阵行）")


func test_params_for_state_tribulation_sequential_flag() -> void:
	# Then: 状态参数查询——渡劫行 sequential=true，其余切曲行 false
	var trib: Dictionary = Planner.params_for_state(AudioEnums.AudioState.IN_TRIBULATION)
	assert_true(trib["sequential"], "渡劫行应 sequential=true")
	assert_almost_eq(trib["fade_out_sec"], 0.3, 0.001)
	var combat: Dictionary = Planner.params_for_state(AudioEnums.AudioState.IN_COMBAT)
	assert_false(combat["sequential"], "战斗行应平行")
	assert_almost_eq(combat["fade_out_sec"], 0.5, 0.001)
	assert_almost_eq(combat["fade_in_sec"], 0.5, 0.001)


# ═══════════════════════════════════════════════════════════════════════════════
# AC-3：中断续接（AC-BGM-10）
# ═══════════════════════════════════════════════════════════════════════════════

func test_plan_interrupt_continues_from_current_db() -> void:
	# Given: a→b 淡入进行中，b 当前 db=-35；请求 bgm_c
	# 调用侧传 b 的当前实际 dB 作为 target_from_db（中断续接）
	var plan: Array[Dictionary] = Planner.plan_transition(
		&"bgm_b", &"bgm_c", 0.0, -35.0, 0.5, 0.5)
	# Then: 新计划中目标播放器起点为 -35（非 -80）
	assert_almost_eq(plan[1][Planner.K_FROM_DB], -35.0, 0.001,
		"中断续接：b 起点应为 -35（当前实际 dB，非 -80）")
	# Then: 旧 Tween 标记 kill 由执行层负责（计划器无状态——集成测试覆盖）


func test_plan_interrupt_at_boundary_from_silence() -> void:
	# Edge: 恰在边界时刻中断（目标播放器尚未起音——当前 dB == SILENCE_DB）
	var plan: Array[Dictionary] = Planner.plan_transition(
		&"bgm_b", &"bgm_c", 0.0, Planner.SILENCE_DB, 0.5, 0.5)
	assert_almost_eq(plan[1][Planner.K_FROM_DB], Planner.SILENCE_DB, 0.001,
		"边界中断：起点 -80 等价首播路径")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-4：同 id 忽略（边缘 #12）
# ═══════════════════════════════════════════════════════════════════════════════

func test_plan_same_id_returns_empty() -> void:
	# Given: bgm_b 当前播放中；When: play_bgm("bgm_b")
	var plan: Array[Dictionary] = Planner.plan_transition(
		&"bgm_b", &"bgm_b", 0.0, Planner.SILENCE_DB)
	# Then: 计划为空，不重启
	assert_eq(plan.size(), 0, "同 id 请求应返回空计划")


func test_plan_both_empty_returns_empty() -> void:
	# Edge: 双空（无播放 + 无请求）
	var plan: Array[Dictionary] = Planner.plan_transition(
		&"", &"", 0.0, Planner.SILENCE_DB)
	assert_eq(plan.size(), 0, "双空应返回空计划")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-5：降低类不切曲
# ═══════════════════════════════════════════════════════════════════════════════

func test_plan_duck_single_bus_command() -> void:
	# Given: 探索 BGM 播放中；When: 请求降至 -10dB（商店类）
	var plan: Array[Dictionary] = Planner.plan_transition(
		&"bgm_explore", &"bgm_explore", 0.0, Planner.SILENCE_DB, 0.5, 0.5, -10.0)
	# Then: 单条 BGM Bus 指令 0→-10dB/0.5s，无播放器切换
	assert_eq(plan.size(), 1, "降低类应仅 1 条指令")
	var cmd: Dictionary = plan[0]
	assert_eq(cmd[Planner.K_TARGET], &"bus", "目标应为 BGM 总线")
	assert_almost_eq(cmd[Planner.K_FROM_DB], 0.0, 0.001, "起点 0dB")
	assert_almost_eq(cmd[Planner.K_TO_DB], -10.0, 0.001, "终点 -10dB")
	assert_almost_eq(cmd[Planner.K_DURATION], 0.5, 0.001, "时长 0.5s")
	assert_eq(cmd[Planner.K_PLAY_STREAM], &"", "不应切曲（无播放指令）")


func test_params_for_state_duck_rows() -> void:
	# Then: 状态参数查询——降低类行 duck_db 命中矩阵数值
	var shop: Dictionary = Planner.params_for_state(AudioEnums.AudioState.IN_SHOP)
	assert_almost_eq(float(shop["duck_db"]), -10.0, 0.001, "商店 -10dB")
	var identity: Dictionary = Planner.params_for_state(
		AudioEnums.AudioState.IDENTITY_SELECT)
	assert_almost_eq(float(identity["duck_db"]), -6.0, 0.001, "身份选择 -6dB")
	var cultivate: Dictionary = Planner.params_for_state(
		AudioEnums.AudioState.CULTIVATING)
	assert_almost_eq(float(cultivate["duck_db"]), -12.0, 0.001, "修为养成 -12dB")


# ═══════════════════════════════════════════════════════════════════════════════
# 仅停止（stop_bgm 语义）
# ═══════════════════════════════════════════════════════════════════════════════

func test_plan_stop_only_single_fade_out() -> void:
	# Given: 播放中；When: target_id 为空（stop_bgm）
	var plan: Array[Dictionary] = Planner.plan_transition(
		&"bgm_a", &"", 0.0, Planner.SILENCE_DB, 1.0, 1.0)
	# Then: 单条淡出 + 完成后停止
	assert_eq(plan.size(), 1, "仅停止应 1 条指令")
	assert_true(plan[0][Planner.K_STOP_AFTER], "到达静音后应停止播放")
	assert_almost_eq(plan[0][Planner.K_TO_DB], Planner.SILENCE_DB, 0.001)
