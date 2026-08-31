extends GutTest
## Story 004 验收测试：apply_reroll 品质重掷 + 独立 RNG 实例。
##
## 覆盖 AC-001 到 AC-008（8 条 AC）。
## 测试策略：
##   - 直接调用 AlchemySystem 静态方法
##   - 验证重掷编排 + RNG 独立性 + 九转金丹阈值
##
## 设计文档来源：GDD alchemy-crafting-system.md §1b/§5
## Story 来源：production/epics/alchemy-crafting-system/story-004-reroll-and-rng.md

const AS := preload("res://src/feature/alchemy_system.gd")

var gsm: Node = null


func before_each() -> void:
	gsm = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/GameStateManager")
	if gsm != null:
		gsm.player.realm = 1


func after_each() -> void:
	if gsm != null:
		gsm.player.realm = 1


# ============================================================================
# AC-001：apply_reroll(有效配方) 返回 result=SUCCESS
# ============================================================================

func test_apply_reroll_valid_recipe_returns_success() -> void:
	# Arrange
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	# Act
	var result: Dictionary = AS.apply_reroll("hui_chun_dan", 0.0, rng, 1)

	# Assert
	assert_eq(int(result["result"]), AS.CraftResult.SUCCESS, "有效配方应返回 SUCCESS")


# ============================================================================
# AC-002：apply_reroll 返回 can_reroll=false
# ============================================================================

func test_apply_reroll_returns_can_reroll_false() -> void:
	# Arrange
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	# Act
	var result: Dictionary = AS.apply_reroll("hui_chun_dan", 0.0, rng, 1)

	# Assert
	assert_false(bool(result["can_reroll"]), "重掷后不可再次重掷")


# ============================================================================
# AC-003：apply_reroll 返回 final_roll 非 null
# ============================================================================

func test_apply_reroll_returns_final_roll_not_null() -> void:
	# Arrange
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	# Act
	var result: Dictionary = AS.apply_reroll("hui_chun_dan", 0.0, rng, 1)

	# Assert
	assert_true(result.has("final_roll"), "应包含 final_roll 字段")
	var final_roll: int = int(result["final_roll"])
	assert_true(final_roll == AS.QualityOutcome.DOWNGRADE or final_roll == AS.QualityOutcome.STANDARD or final_roll == AS.QualityOutcome.UPGRADE,
		"final_roll 应为有效 QualityOutcome")


# ============================================================================
# AC-004：apply_reroll 返回 final_rarity 在 [1,5] 范围
# ============================================================================

func test_apply_reroll_final_rarity_in_valid_range() -> void:
	# Arrange
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	# Act
	var result: Dictionary = AS.apply_reroll("ji_chu_fa_qi", 0.0, rng, 1)

	# Assert
	var final_rarity: int = int(result["final_rarity"])
	assert_true(final_rarity >= 1 and final_rarity <= 5, "final_rarity 应在 [1, 5] 范围")


# ============================================================================
# AC-005：apply_reroll(无效配方) 返回 INVALID_RECIPE
# ============================================================================

func test_apply_reroll_invalid_recipe_returns_invalid() -> void:
	# Arrange
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	# Act
	var result: Dictionary = AS.apply_reroll("invalid_recipe", 0.0, rng, 1)

	# Assert
	assert_eq(int(result["result"]), AS.CraftResult.INVALID_RECIPE, "无效配方应返回 INVALID_RECIPE")


# ============================================================================
# AC-006：quality_reroll 独立 RNG——相同 seed 产出相同结果
# ============================================================================

func test_quality_reroll_deterministic_with_same_seed() -> void:
	# Arrange
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 100
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 100

	# Act
	var result1: int = AS.quality_reroll(2, 0, 0.0, rng1)
	var result2: int = AS.quality_reroll(2, 0, 0.0, rng2)

	# Assert
	assert_eq(result1, result2, "相同 seed 应产出相同结果")


# ============================================================================
# AC-007：quality_reroll 升品概率比 quality_roll 高（+15%）
# ============================================================================

func test_quality_reroll_upgrade_chance_higher_than_roll() -> void:
	# Arrange
	var total: int = 2000
	var roll_upgrade: int = 0
	var reroll_upgrade: int = 0
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 42
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 42

	# Act
	for _i: int in range(total):
		if AS.quality_roll(2, 0, 0.0, rng1) == AS.QualityOutcome.UPGRADE:
			roll_upgrade += 1
		if AS.quality_reroll(2, 0, 0.0, rng2) == AS.QualityOutcome.UPGRADE:
			reroll_upgrade += 1

	# Assert——reroll 的升品次数应高于 roll（+15% 概率）
	assert_true(reroll_upgrade > roll_upgrade,
		"reroll 升品次数 (%d) 应高于 roll (%d)" % [reroll_upgrade, roll_upgrade])


# ============================================================================
# AC-008：jindan_cumulative_threshold(1) == 1, jindan_cumulative_threshold(3) == 6
# ============================================================================

func test_jindan_cumulative_threshold_values() -> void:
	# Act & Assert
	assert_eq(AS.jindan_cumulative_threshold(1), 1, "第 1 次需累计 1 颗")
	assert_eq(AS.jindan_cumulative_threshold(2), 3, "第 2 次需累计 3 颗")
	assert_eq(AS.jindan_cumulative_threshold(3), 6, "第 3 次需累计 6 颗")
	assert_eq(AS.jindan_cumulative_threshold(4), 10, "第 4 次需累计 10 颗")
