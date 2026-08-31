extends GutTest
## Story 003 验收测试：roll_quality / forge_artifact_stat 品质与属性。
##
## 覆盖 AC-001 到 AC-009（9 条 AC）。
## 测试策略：
##   - 直接调用 AlchemySystem 静态纯函数
##   - 验证品质掷骰确定性 + 白色不降品 + 重掷概率 + 公式数值
##
## 设计文档来源：GDD alchemy-crafting-system.md §1/§2/§3
## Story 来源：production/epics/alchemy-crafting-system/story-003-quality-and-stats.md

const AS := preload("res://src/feature/alchemy_system.gd")


# ============================================================================
# AC-001：quality_roll 确定性——相同 seed 产出相同结果
# ============================================================================

func test_quality_roll_deterministic_with_same_seed() -> void:
	# Arrange
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 42
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 42

	# Act
	var result1: int = AS.quality_roll(2, 0, 0.0, rng1)
	var result2: int = AS.quality_roll(2, 0, 0.0, rng2)

	# Assert
	assert_eq(result1, result2, "相同 seed 应产出相同结果")


# ============================================================================
# AC-002：quality_roll(rarity=1) 永不返回 DOWNGRADE
# ============================================================================

func test_quality_roll_white_rarity_never_downgrades() -> void:
	# Arrange
	var rng := RandomNumberGenerator.new()
	rng.seed = 999

	# Act——多次掷骰，白色稀有度(1)不应降品
	for _i: int in range(100):
		var outcome: int = AS.quality_roll(1, 0, 0.0, rng)
		assert_ne(outcome, AS.QualityOutcome.DOWNGRADE, "白色稀有度不应降品")


# ============================================================================
# AC-003：quality_reroll 降品概率 25%（确定性测试）
# ============================================================================

func test_quality_reroll_downgrade_probability_25_percent() -> void:
	# Arrange
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var downgrade_count: int = 0
	var total: int = 1000

	# Act
	for _i: int in range(total):
		var outcome: int = AS.quality_reroll(2, 0, 0.0, rng)
		if outcome == AS.QualityOutcome.DOWNGRADE:
			downgrade_count += 1

	# Assert——降品概率应为 25%，允许 ±7% 误差（统计波动）
	var pct: float = float(downgrade_count) / float(total)
	var pct_str: String = str(round(pct * 1000.0) / 10.0)
	assert_true(pct > 0.18 and pct < 0.32, "降品概率应接近 25%（实际 " + pct_str + "%）")


# ============================================================================
# AC-004：pill_effect(4, 1.3, 0.0) == 5
# ============================================================================

func test_pill_effect_upgrade_returns_5() -> void:
	# Act
	var result: int = AS.pill_effect(4, 1.3, 0.0)

	# Assert
	assert_eq(result, 5, "floor(4×1.3) 应为 5")


# ============================================================================
# AC-005：pill_effect(4, 0.8, 0.0) == 3
# ============================================================================

func test_pill_effect_downgrade_returns_3() -> void:
	# Act
	var result: int = AS.pill_effect(4, 0.8, 0.0)

	# Assert
	assert_eq(result, 3, "floor(4×0.8) 应为 3")


# ============================================================================
# AC-006：pill_effect(1, 0.8, 0.0) == 1（保底至少 1）
# ============================================================================

func test_pill_effect_minimum_floor_returns_1() -> void:
	# Act
	var result: int = AS.pill_effect(1, 0.8, 0.0)

	# Assert
	assert_eq(result, 1, "效果值保底至少 1")


# ============================================================================
# AC-007：forge_artifact_stat(4, 0.8) == {atk:4, def:4}
# ============================================================================

func test_forge_artifact_stat_gold_downgrade() -> void:
	# Act
	var result: Dictionary = AS.forge_artifact_stat(4, 0.8)

	# Assert
	assert_eq(int(result["atk"]), 4, "金色降品 ATK=floor(6×0.8)=4")
	assert_eq(int(result["def"]), 4, "金色降品 DEF=floor(5×0.8)=4")


# ============================================================================
# AC-008：forge_artifact_stat(5, 1.0) == {atk:10, def:8}
# ============================================================================

func test_forge_artifact_stat_dark_gold_standard() -> void:
	# Act
	var result: Dictionary = AS.forge_artifact_stat(5, 1.0)

	# Assert
	assert_eq(int(result["atk"]), 10, "暗金标准 ATK=10")
	assert_eq(int(result["def"]), 8, "暗金标准 DEF=8")


# ============================================================================
# AC-009：forge_artifact_stat(1, 0.8) == {atk:1, def:0}（白色降品保底）
# ============================================================================

func test_forge_artifact_stat_white_downgrade_floor() -> void:
	# Act
	var result: Dictionary = AS.forge_artifact_stat(1, 0.8)

	# Assert
	assert_eq(int(result["atk"]), 1, "白色降品 ATK 保底 1")
	assert_eq(int(result["def"]), 0, "白色降品 DEF=floor(1×0.8)=0")
