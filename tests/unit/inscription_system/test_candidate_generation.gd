extends GutTest
## Story 6-8 验收测试：generate_candidates 候选属性生成。
##
## 覆盖 AC-001 到 AC-010（10 条 AC）。
## 测试策略：
##   - 直接调用 InscriptionSystem 静态方法
##   - 使用 get_candidate_weights 验证中间权重变换
##   - 使用 generate_candidates 验证最终输出
##
## 设计文档来源：GDD inscription-system.md §2-3
## Story 来源：production/epics/inscription-system/story-001-candidate-generation.md

const IS := preload("res://src/feature/inscription_system.gd")


# ============================================================================
# AC-001：SUBSTAT_WEIGHTS 包含 11 种副属性
# ============================================================================

func test_substat_weights_contains_11_entries() -> void:
	# Act
	var count: int = IS.SUBSTAT_WEIGHTS.size()

	# Assert
	assert_eq(count, 11, "SUBSTAT_WEIGHTS 应包含 11 种副属性")


# ============================================================================
# AC-002：generate_candidates(realm=1) 不含 T4 属性
# ============================================================================

func test_generate_candidates_realm1_excludes_t4() -> void:
	# Arrange
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var t4_keys: Array = ["cost-1", "regen+1", "armor_break", "mana_extract"]

	# Act
	var weights: Dictionary = IS.get_candidate_weights([], 1, -1, IS.Direction.NONE)

	# Assert——T4 属性应全部被移除
	for key: String in t4_keys:
		assert_false(weights.has(key), "炼气期应移除 T4 属性: " + key)


# ============================================================================
# AC-003：generate_candidates(realm=2) 含全部 4 个 T4 属性，bonus=4
# ============================================================================

func test_generate_candidates_realm2_includes_all_t4_with_bonus() -> void:
	# Arrange
	var t4_base: Dictionary = {
		"cost-1": 4,
		"regen+1": 3,
		"armor_break": 3,
		"mana_extract": 2,
	}
	var expected_bonus: int = 4  # floori(2 * 2) = 4

	# Act
	var weights: Dictionary = IS.get_candidate_weights([], 2, -1, IS.Direction.NONE)

	# Assert——4 个 T4 属性均存在且加了 bonus=4
	for key: String in t4_base:
		assert_true(weights.has(key), "筑基期应包含 T4 属性: " + key)
		var expected: int = int(t4_base[key]) + expected_bonus
		assert_eq(int(weights[key]), expected,
			"T4 属性 " + key + " 应为基础权重 " + str(t4_base[key]) + " + bonus 4 = " + str(expected))


# ============================================================================
# AC-004：direction=ATTACK 时 atk+1=33, crit+3=22, crit_dmg+5=18
# ============================================================================

func test_direction_attack_weights() -> void:
	# Act
	var weights: Dictionary = IS.get_candidate_weights([], 1, -1, IS.Direction.ATTACK)

	# Assert——floori(base * 1.5)
	assert_eq(int(weights["atk+1"]), 33, "atk+1 应为 floori(22 * 1.5) = 33")
	assert_eq(int(weights["crit+3"]), 22, "crit+3 应为 floori(15 * 1.5) = 22")
	assert_eq(int(weights["crit_dmg+5"]), 18, "crit_dmg+5 应为 floori(12 * 1.5) = 18")


# ============================================================================
# AC-005：direction=DEFENSE, realm=1 时 def+1=27, hp+2=15
# ============================================================================

func test_direction_defense_realm1_weights() -> void:
	# Act
	var weights: Dictionary = IS.get_candidate_weights([], 1, -1, IS.Direction.DEFENSE)

	# Assert——floori(base * 1.5)
	assert_eq(int(weights["def+1"]), 27, "def+1 应为 floori(18 * 1.5) = 27")
	assert_eq(int(weights["hp+2"]), 15, "hp+2 应为 floori(10 * 1.5) = 15")


# ============================================================================
# AC-006：已有 atk+1 时权重减半为 11，def+1 不受影响
# ============================================================================

func test_existing_atk_halved_def_unaffected() -> void:
	# Arrange——existing 包含 atk+1
	var existing: Array = [{"type": "atk+1"}]

	# Act
	var weights: Dictionary = IS.get_candidate_weights(existing, 1, -1, IS.Direction.NONE)

	# Assert——atk+1 基础 22，减半 = floori(22 * 0.5) = 11
	assert_eq(int(weights["atk+1"]), 11, "已有 atk+1 时权重应减半为 11")
	assert_eq(int(weights["def+1"]), 18, "def+1 不受已有 atk+1 影响，保持基础值 18")


# ============================================================================
# AC-007：三叠同属性时权重保底为 1
# ============================================================================

func test_triple_duplicate_weight_floor_1() -> void:
	# Arrange——3 个相同属性 weakness（基础权重 6）
	var existing: Array = [
		{"type": "weakness"},
		{"type": "weakness"},
		{"type": "weakness"},
	]

	# Act
	var weights: Dictionary = IS.get_candidate_weights(existing, 1, -1, IS.Direction.NONE)

	# Assert——6 → 3 → 1 → maxi(1, floori(1 * 0.5)) = maxi(1, 0) = 1
	assert_true(weights.has("weakness"), "weakness 应在权重表中")
	assert_eq(int(weights["weakness"]), 1, "三叠后权重保底为 1")


# ============================================================================
# AC-008：已有 cost-1 时完全移除（不减半）
# ============================================================================

func test_existing_cost1_removed_not_halved() -> void:
	# Arrange——existing 包含 cost-1，realm=2 使 T4 可见
	var existing: Array = [{"type": "cost-1"}]

	# Act
	var weights: Dictionary = IS.get_candidate_weights(existing, 2, -1, IS.Direction.NONE)

	# Assert——cost-1 应被完全移除，不在权重表中
	assert_false(weights.has("cost-1"), "已有 cost-1 时应完全移除，不减半")


# ============================================================================
# AC-009：generate_candidates 返回恰好 3 个互不相同的候选
# ============================================================================

func test_generate_candidates_returns_3_unique() -> void:
	# Arrange
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	# Act
	var candidates: Array = IS.generate_candidates([], 2, -1, IS.Direction.NONE, rng)

	# Assert
	assert_eq(candidates.size(), 3, "应返回恰好 3 个候选")
	# 验证互不相同
	var seen: Dictionary = {}
	for c: String in candidates:
		assert_false(seen.has(c), "候选不应重复: " + c)
		seen[c] = true


# ============================================================================
# AC-010：direction=NONE 时所有权重保持基础值
# ============================================================================

func test_direction_none_keeps_base_weights() -> void:
	# Act
	var weights: Dictionary = IS.get_candidate_weights([], 1, -1, IS.Direction.NONE)

	# Assert——T1-T3 属性保持基础值（T4 在 realm=1 被移除）
	assert_eq(int(weights["atk+1"]), 22, "NONE 方向 atk+1 保持基础 22")
	assert_eq(int(weights["def+1"]), 18, "NONE 方向 def+1 保持基础 18")
	assert_eq(int(weights["crit+3"]), 15, "NONE 方向 crit+3 保持基础 15")
	assert_eq(int(weights["crit_dmg+5"]), 12, "NONE 方向 crit_dmg+5 保持基础 12")
	assert_eq(int(weights["hp+2"]), 10, "NONE 方向 hp+2 保持基础 10")
	assert_eq(int(weights["lifesteal+2"]), 8, "NONE 方向 lifesteal+2 保持基础 8")
	assert_eq(int(weights["weakness"]), 6, "NONE 方向 weakness 保持基础 6")
