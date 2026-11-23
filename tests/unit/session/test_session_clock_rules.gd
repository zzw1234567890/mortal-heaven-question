extends GutTest
## SessionClockRules 单元测试——「已游玩时长」的判定与算术内核。[br]
## [br][b]覆盖[/b]：[br]
##   1. [method SessionClockRules.should_accumulate]：暂停中不计（GDD achievement
##      §ach_speed_run「不含暂停时间」）；[br]
##   2. [method SessionClockRules.tick]：跨帧零头凑整、负数钳制、非整 delta 不丢精度；[br]
##   3. [method SessionClockRules.format_duration]：59 / 61 / 3700 秒三档文案
##      （不足 1 分钟 / 分钟档 / 跨小时档）+ 负数钳 0；[br]
##   4. [method SessionClockRules.format_playtime]：「不到 1 分钟」不带空格、
##      「X小时Y分」带空格——空格是这条规则的一部分。[br]
## [br][b]零等待[/b]：全部为纯函数调用，不 sleep、不推进真实帧、不暂停场景树。

const Rules := preload("res://src/feature/session/session_clock_rules.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# 该不该计时
# ═══════════════════════════════════════════════════════════════════════════════

func test_should_accumulate_true_when_running() -> void:
	assert_true(Rules.should_accumulate(false), "非暂停时应收计时")


func test_should_accumulate_false_when_paused() -> void:
	# GDD achievement-system.md §ach_speed_run：playtime_seconds 不含暂停时间
	assert_false(Rules.should_accumulate(true), "暂停中不应计入时长")


# ═══════════════════════════════════════════════════════════════════════════════
# 跨帧凑整
# ═══════════════════════════════════════════════════════════════════════════════

func test_tick_sums_accum_and_delta() -> void:
	var step: Dictionary = Rules.tick(1.25, 0.5)
	assert_eq(int(step["seconds"]), 1, "1.25 + 0.5 = 1.75 → 整秒 1")
	assert_almost_eq(float(step["remainder"]), 0.75, 0.0001, "零头 0.75 留给下一帧")


func test_tick_exact_integer_has_no_remainder() -> void:
	var step: Dictionary = Rules.tick(0.5, 0.5)
	assert_eq(int(step["seconds"]), 1, "恰好凑满一秒应产出整秒")
	assert_eq(float(step["remainder"]), 0.0, "零头应清空")


func test_tick_below_one_second_yields_zero() -> void:
	var step: Dictionary = Rules.tick(0.0, 0.3)
	assert_eq(int(step["seconds"]), 0, "不足一秒不产出整秒")
	assert_eq(float(step["remainder"]), 0.3, "不足一秒的部分原样留作零头")


func test_tick_accumulates_across_many_frames_without_loss() -> void:
	# 10 次 0.25s —— 单帧都不满一秒，累计 2.5s 应产出 2 整秒
	var acc: float = 0.0
	var total: int = 0
	for i: int in range(10):
		var step: Dictionary = Rules.tick(acc, 0.25)
		acc = float(step["remainder"])
		total += int(step["seconds"])
	assert_eq(total, 2, "十次 0.25s 应凑出 2 整秒（不丢帧）")
	assert_almost_eq(acc, 0.5, 0.0001, "剩余零头 0.5s")


func test_tick_negative_inputs_clamped_to_zero() -> void:
	# 引擎给的 delta 恒为正；此钳制只为「调用方传了怪值」时不倒扣已有时长
	var step: Dictionary = Rules.tick(-5.0, -3.0)
	assert_eq(int(step["seconds"]), 0, "负入参不应倒扣时长")
	assert_eq(float(step["remainder"]), 0.0, "负入参不产生负零头")


# ═══════════════════════════════════════════════════════════════════════════════
# 展示口径：59 / 61 / 3700 秒三档
# ═══════════════════════════════════════════════════════════════════════════════

func test_format_duration_below_one_minute() -> void:
	assert_eq(Rules.format_duration(59), "不到 1 分钟", "59 秒应走「不到 1 分钟」档")


func test_format_duration_just_over_one_minute() -> void:
	assert_eq(Rules.format_duration(61), "0小时1分", "61 秒应向下取整为 0小时1分")


func test_format_duration_hours_boundary() -> void:
	assert_eq(Rules.format_duration(3700), "1小时1分", "3700 秒 = 1小时1分（60 秒余数进位到分钟）")


func test_format_duration_zero_is_sub_minute() -> void:
	# 0 秒与 59 秒对玩家是同一件事——写「0小时0分」反倒像存档没生效
	assert_eq(Rules.format_duration(0), "不到 1 分钟", "0 秒应写「不到 1 分钟」而非 0小时0分")


func test_format_duration_negative_clamped() -> void:
	assert_eq(Rules.format_duration(-100), "不到 1 分钟", "负秒数应钳 0 后走不足 1 分钟档")


func test_format_duration_floors_seconds_within_minute() -> void:
	assert_eq(Rules.format_duration(119), "0小时1分", "119 秒应向下取整到 0小时1分（不四舍五入）")


# ═══════════════════════════════════════════════════════════════════════════════
# 摘要行整句（「游玩」+ 时长——空格规则）
# ═══════════════════════════════════════════════════════════════════════════════

func test_format_playtime_sub_minute_has_no_space() -> void:
	assert_eq(Rules.format_playtime(59), "游玩不到 1 分钟",
			"不足 1 分钟时「游玩」与时长之间不带空格")


func test_format_playtime_minute_branch_has_space() -> void:
	assert_eq(Rules.format_playtime(61), "游玩 0小时1分",
			"够 1 分钟时「游玩」与时长之间带一个空格")


func test_format_playtime_matches_format_duration() -> void:
	# 两个入口必须同源：整句 = 「游玩 」+ 时长（仅差前缀与空格）
	assert_eq(Rules.format_playtime(3700), "游玩 " + Rules.format_duration(3700),
			"整句应与时长文案同源拼接")
