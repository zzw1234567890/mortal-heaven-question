extends GutTest
## main-menu Story 002 单元测试：SettingsLogic.db_from_percent 纯函数（QA AC-1）。
##
## 覆盖 QA 规格全部场景与 edge cases：[br]
##   - 0 → -80.0；负值 → -80.0[br]
##   - 100 → 0.0（is_equal_approx）[br]
##   - 50 → ≈-6.02dB；1 → 非 -80 的有限负值[br]
##   - 超界（101/-1）钳制后按边界值处理[br]
##   - 浮点步进值[br]
##
## 纯函数直调——无需场景树与 Autoload。风格先例：
## tests/unit/main_menu/test_continue_button_state.gd（arrange/act/assert）。

const LOGIC := preload("res://src/ui/main_menu/settings_logic.gd")

## linear_to_db(0.5) 的理论值（20 * log10(0.5)）——以引擎同名公式复核
## （先自算再断言，杜绝「实现与期望同源同错」的同义反复）。
const DB_AT_50_THEORY: float = -6.020599913279624

## 引擎参照实现——与被测函数同一公式但独立编写（防实现侧笔误被期望值掩盖）。
static func _reference_db(percent: float) -> float:
	if percent <= 0.0:
		return -80.0
	return linear_to_db(percent / 100.0)


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1：音量转换公式
# ═══════════════════════════════════════════════════════════════════════════════

func test_db_from_percent_zero_returns_mute_db() -> void:
	## AC-1: 0 → -80.0（GDD 公式「0% = -80dB 静音」）
	# Arrange + Act
	var result: float = LOGIC.db_from_percent(0.0)
	# Assert
	assert_eq(result, -80.0, "0% 应精确返回 -80.0（静音底值）")


func test_db_from_percent_negative_returns_mute_db() -> void:
	## AC-1: 负值 → -80.0（钳制到 0 后走静音分支）
	# Arrange + Act
	var result: float = LOGIC.db_from_percent(-1.0)
	# Assert
	assert_eq(result, -80.0, "-1% 应钳制到 0 并返回 -80.0")


func test_db_from_percent_full_returns_zero() -> void:
	## AC-1: 100 → 0.0（is_equal_approx——QA 规格原文要求浮点近似断言）
	# Arrange + Act
	var result: float = LOGIC.db_from_percent(100.0)
	# Assert
	assert_almost_eq(result, 0.0, 0.0001, "100% 应近似 0.0dB（linear_to_db(1.0)）")


func test_db_from_percent_half_returns_linear_db() -> void:
	## AC-1: 50 → ≈-6.02dB（20·log10(0.5)）
	# Arrange + Act
	var result: float = LOGIC.db_from_percent(50.0)
	# Assert —— 容差 0.01dB（QA AC-3 同界）
	assert_almost_eq(result, DB_AT_50_THEORY, 0.01,
			"50%% 应近似 %.4fdB（linear_to_db(0.5)）" % DB_AT_50_THEORY)


func test_db_from_percent_one_returns_finite_negative() -> void:
	## AC-1: 1 → 非 -80 的有限负值（1% ≠ 静音——公式连续性守卫）
	# Arrange + Act
	var result: float = LOGIC.db_from_percent(1.0)
	# Assert
	assert_ne(result, -80.0, "1% 不应等于静音底值 -80.0")
	assert_true(is_finite(result), "1% 应返回有限值（无 inf/nan）")
	assert_true(result < 0.0, "1% 应为负 dB（linear_to_db(0.01) ≈ -40dB）")


func test_db_from_percent_over_range_clamps_to_full() -> void:
	## AC-1: 超界 101 → 钳制到 100 → 0.0dB（QL-STORY-READY 钳制裁决）
	# Arrange + Act
	var result: float = LOGIC.db_from_percent(101.0)
	# Assert
	assert_almost_eq(result, 0.0, 0.0001, "101% 应钳制到 100% 并返回 0.0dB")


func test_db_from_percent_under_range_clamps_to_mute() -> void:
	## AC-1: 超界 -1 → 钳制到 0 → -80.0dB（与负值路径同界复核）
	# Arrange + Act
	var result: float = LOGIC.db_from_percent(-1.0)
	# Assert
	assert_eq(result, -80.0, "-1% 应钳制到 0% 并返回 -80.0")


func test_db_from_percent_float_step_matches_engine_reference() -> void:
	## AC-1 edge: 浮点步进值——滑条 step=1 产生的 0~100 浮点序列逐点与
	## 引擎参照实现一致（公式保真扫描）。
	# Arrange + Act + Assert
	for i: int in range(0, 101):
		var percent: float = float(i)
		var result: float = LOGIC.db_from_percent(percent)
		var expected: float = _reference_db(percent)
		assert_almost_eq(result, expected, 0.0001,
				"percent=%d 应与引擎参照公式一致（got %f / want %f）"
				% [i, result, expected])


func test_db_from_percent_fractional_step_matches_engine_reference() -> void:
	## AC-1 edge: 浮点步进值——非整百格（如 33.5/67.25）与引擎参照一致
	## （测试隔离规则例外声明：边界值本身即测试点，允许内联魔数）。
	# Arrange
	var percents: Array[float] = [0.5, 33.5, 67.25, 99.5]
	# Act + Assert
	for percent: float in percents:
		var result: float = LOGIC.db_from_percent(percent)
		var expected: float = _reference_db(percent)
		assert_almost_eq(result, expected, 0.0001,
				"percent=%s 应与引擎参照公式一致（got %f / want %f）"
				% [str(percent), result, expected])
