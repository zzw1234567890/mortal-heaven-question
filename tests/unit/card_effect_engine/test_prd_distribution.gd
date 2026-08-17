extends GutTest
## Story 004 验收测试：PRD 伪随机分布引擎（5% 步进 + 怜悯保护）。
##
## 覆盖 AC-001（怜悯保护强制触发）、AC-002（100 次试验触发区间）
## + QA Edge cases（每卡独立状态、触发重置、确定性种子、C 校准、非法 p_base 拒绝）。
##
## [b]公式[/b]（game-designer 裁决 2026-08-16）：标准 PRD——起始概率 = 校准常数 C（C < p），
## 失败累加 [code]P += C[/code]，触发重置 [code]P = C[/code]，怜悯 [code]ceil(1/p)[/code] 连败强制触发。
##
## [b]确定性策略[/b]：怜悯保护用不变式断言（连续失败次数永不超过 ceil(1/p)，对任何固定种子成立）；
## 触发重置/怜悯强制用「N 次内必然触发」的确定性断言（怜悯兜底）；C 校准用数值断言。

const PRDEngineClass := preload("res://src/feature/card_effect_engine/prd_engine.gd")


# ============================================================================
# AC-001：怜悯保护强制触发——连续失败 4 次 → 第 5 次必然触发
# ============================================================================

func test_ac001_mercy_caps_consecutive_failures_at_four() -> void:
	## 怜悯保护不变式：30% 概率连续失败次数不得超过 ceil(1/0.3)=4。
	## 5000 次试验足以覆盖任意固定种子——若怜悯失效，独立/PRD 随机下必现 5+ 连败。
	var engine: RefCounted = PRDEngineClass.new()
	engine.reset_prng_seed(12345)

	var consecutive_false: int = 0
	var max_false: int = 0
	for i in range(5000):
		var hit: bool = engine.next_random(1, 0.3)
		if not hit:
			consecutive_false += 1
			max_false = maxi(max_false, consecutive_false)
		else:
			consecutive_false = 0

	assert_lte(max_false, 4, "连续失败次数不得超过 ceil(1/0.3)=4（怜悯保护）")


func test_ac001_mercy_threshold_varies_with_p_base() -> void:
	## 怜悯阈值 = ceil(1/P_base)：20% → 5。用 20% 验证阈值随标示概率变化。
	var engine: RefCounted = PRDEngineClass.new()
	engine.reset_prng_seed(99)

	var max_false: int = 0
	var streak: int = 0
	for i in range(8000):
		if engine.next_random(2, 0.2):
			streak = 0
		else:
			streak += 1
			max_false = maxi(max_false, streak)
	assert_lte(max_false, 5, "20% 概率连败封顶 ceil(1/0.2)=5")


func test_ac001_mercy_forces_trigger_within_five_tries() -> void:
	## 30% 概率 5 次内必然触发（怜悯兜底）——确定性断言，触发后状态重置。
	var engine: RefCounted = PRDEngineClass.new()
	engine.reset_prng_seed(1)
	var hit: bool = false
	for i in range(5):
		if engine.next_random(1, 0.3):
			hit = true
			break
	assert_true(hit, "30% 概率 5 次内必然触发（怜悯保护）")
	assert_eq(engine.get_p_current(1), 0.0, "触发后 P_current 重置")
	assert_eq(engine.get_failure_streak(1), 0, "触发后失败计数清零")


# ============================================================================
# AC-002：100 次试验触发次数区间 [24, 36]
# ============================================================================

func test_ac002_100_trials_30pct_in_range() -> void:
	## 同一种子 100 次 30% PRD 效果，触发次数应在 24-36（99% CI 近似）。
	var engine: RefCounted = PRDEngineClass.new()
	engine.reset_prng_seed(42)

	var triggers: int = 0
	for i in range(100):
		if engine.next_random(1, 0.3):
			triggers += 1

	assert_between(triggers, 24, 36, "100 次 30% PRD 触发次数应在 24-36")


# ============================================================================
# C 校准（game-designer 裁决）
# ============================================================================

func test_calibrated_c_less_than_p_and_approx_0_108_for_30pct() -> void:
	var engine: RefCounted = PRDEngineClass.new()
	var c30: float = engine.get_calibrated_c(0.3)
	assert_lt(c30, 0.3, "校准常数 C 应小于标示值 p")
	assert_almost_eq(c30, 0.108, 0.01, "30% 校准 C ≈ 0.108（含怜悯）")


func test_calibrated_c_varies_with_p_base() -> void:
	var engine: RefCounted = PRDEngineClass.new()
	var c20: float = engine.get_calibrated_c(0.2)
	var c30: float = engine.get_calibrated_c(0.3)
	assert_lt(c20, c30, "标示概率越高，校准 C 越大（20% < 30%）")
	assert_lt(c20, 0.2, "20% 的 C < 0.2")
	assert_lt(c30, 0.3, "30% 的 C < 0.3")


# ============================================================================
# QA Edge：确定性（同种子同操作序列 = 相同结果）
# ============================================================================

func test_deterministic_same_seed_same_sequence() -> void:
	var engine_a: RefCounted = PRDEngineClass.new()
	var engine_b: RefCounted = PRDEngineClass.new()
	engine_a.reset_prng_seed(777)
	engine_b.reset_prng_seed(777)

	var seq_a: Array = []
	var seq_b: Array = []
	for i in range(50):
		seq_a.append(engine_a.next_random(1, 0.3))
		seq_b.append(engine_b.next_random(1, 0.3))

	assert_eq(seq_a, seq_b, "同种子应产生相同结果序列")


# ============================================================================
# QA Edge：每卡独立状态
# ============================================================================

func test_per_card_independent_state() -> void:
	## 不同 card_instance_id 各自独立累计——card 1 的状态不影响 card 2。
	var engine: RefCounted = PRDEngineClass.new()
	engine.reset_prng_seed(5)

	# card 1 触发若干次（可能命中/失败，但绝不触碰 card 2 的状态）
	for i in range(100):
		engine.next_random(1, 0.3)

	# card 2 应从干净状态开始——P_current/失败计数均未初始化
	assert_eq(engine.get_p_current(2), 0.0, "card 2 未触发过，P_current 应为 0（未初始化）")
	assert_eq(engine.get_failure_streak(2), 0, "card 2 失败计数应为 0")


# ============================================================================
# 非法 p_base 拒绝
# ============================================================================

func test_invalid_p_base_rejected() -> void:
	var engine: RefCounted = PRDEngineClass.new()
	engine.reset_prng_seed(1)
	assert_false(engine.next_random(1, 0.0), "p_base=0 应返回 false")
	assert_false(engine.next_random(1, -0.5), "p_base<0 应返回 false")
	assert_false(engine.next_random(1, 1.5), "p_base>1 应返回 false")


# ============================================================================
# 重置 API
# ============================================================================

func test_reset_all_state_clears_tracking() -> void:
	var engine: RefCounted = PRDEngineClass.new()
	engine.reset_prng_seed(3)
	for i in range(20):
		engine.next_random(1, 0.3)
	engine.reset_all_state()
	assert_eq(engine.get_p_current(1), 0.0, "reset_all 后 P_current 清空")
	assert_eq(engine.get_failure_streak(1), 0, "reset_all 后失败计数清空")
