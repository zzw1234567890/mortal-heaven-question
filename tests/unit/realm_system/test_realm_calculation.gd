extends GutTest
## Story 002 验收测试：境界压制计算 + 地图境界压制 + 稀有度权重。
##
## 覆盖 AC-001 到 AC-013（13 条 AC）。
## 测试策略：
##   - RS_SCRIPT.new() 构造 RealmSystem 实例（不调 _ready，纯计算方法无副作用）
##   - 不依赖 GSM——realm_penalty/map_effective_realm/get_rarity_weights 均为纯函数
##   - 动态分派：var rs: Node 持有，返回值显式类型注解（控制清单 2026-08-05 规则）

const RS_SCRIPT := preload("res://src/core/realm_system.gd")

var rs: Node = null


func before_each() -> void:
	rs = RS_SCRIPT.new()


func after_each() -> void:
	if rs != null:
		rs.free()
		rs = null


# ============================================================================
# AC-001：realm_penalty 方法签名 + 返回 float
# ============================================================================

func test_ac001_realm_penalty_returns_float() -> void:
	var penalty: float = rs.realm_penalty(1, 2)
	assert_eq(typeof(penalty), TYPE_FLOAT, "realm_penalty 应返回 float")
	assert_true(penalty >= 0.5 and penalty <= 1.0, "penalty 应在 [0.5, 1.0] 范围内")


# ============================================================================
# AC-002：attacker=1, defender=2 → 0.8（敌方高 1 级，-20%）
# ============================================================================

func test_ac002_realm_penalty_defender_one_level_higher() -> void:
	assert_eq(rs.realm_penalty(1, 2), 0.8, "delta=1 应返回 0.8（-20%）")


# ============================================================================
# AC-003：attacker=1, defender=3 → 0.5（敌方高 2 级，-50%）
# ============================================================================

func test_ac003_realm_penalty_defender_two_levels_higher() -> void:
	assert_eq(rs.realm_penalty(1, 3), 0.5, "delta=2 应返回 0.5（-50%）")


func test_ac003_realm_penalty_defender_three_levels_higher() -> void:
	# delta>=2 均返回 0.5
	assert_eq(rs.realm_penalty(1, 4), 0.5, "delta=3 应返回 0.5")
	assert_eq(rs.realm_penalty(1, 5), 0.5, "delta=4 应返回 0.5")
	assert_eq(rs.realm_penalty(2, 5), 0.5, "delta=3 应返回 0.5")


# ============================================================================
# AC-004：attacker=2, defender=1 → 1.0（己方高于敌方，无压制）
# ============================================================================

func test_ac004_realm_penalty_attacker_higher() -> void:
	assert_eq(rs.realm_penalty(2, 1), 1.0, "己方高应返回 1.0（无压制）")


func test_ac004_realm_penalty_attacker_much_higher() -> void:
	assert_eq(rs.realm_penalty(5, 1), 1.0, "己方高 4 级应返回 1.0")


# ============================================================================
# AC-005：attacker=3, defender=3 → 1.0（同级，无压制）
# ============================================================================

func test_ac005_realm_penalty_same_level() -> void:
	assert_eq(rs.realm_penalty(3, 3), 1.0, "同级应返回 1.0")


func test_ac005_realm_penalty_all_same_levels() -> void:
	for level: int in range(1, 6):
		assert_eq(rs.realm_penalty(level, level), 1.0, "L%d 同级应返回 1.0" % level)


# ============================================================================
# AC-006：map_effective_realm 方法签名 + 返回 Dictionary
# ============================================================================

func test_ac006_map_effective_realm_returns_dictionary() -> void:
	var result: Dictionary = rs.map_effective_realm(3, 1)
	assert_eq(typeof(result), TYPE_DICTIONARY, "应返回 Dictionary")
	assert_true(result.has("offensive_lv"), "应含 offensive_lv 键")
	assert_true(result.has("defensive_lv"), "应含 defensive_lv 键")
	assert_eq(result.size(), 2, "应含 2 个字段")


# ============================================================================
# AC-007：player=3, map_max=1 → offensive=1, defensive=3（进攻压制，防御保留）
# ============================================================================

func test_ac007_map_effective_realm_player_higher_suppressed() -> void:
	var result: Dictionary = rs.map_effective_realm(3, 1)
	assert_eq(result["offensive_lv"], 1, "offensive 应压制到 map_max=1")
	assert_eq(result["defensive_lv"], 3, "defensive 应保留玩家境界 3")


func test_ac007_map_effective_realm_player_higher_various() -> void:
	# 玩家境界 > 地图上限的多种组合
	var result1: Dictionary = rs.map_effective_realm(5, 1)
	assert_eq(result1["offensive_lv"], 1, "L5 在 map_max=1 地图 offensive 应为 1")
	assert_eq(result1["defensive_lv"], 5, "L5 在 map_max=1 地图 defensive 应为 5")
	var result2: Dictionary = rs.map_effective_realm(4, 2)
	assert_eq(result2["offensive_lv"], 2, "L4 在 map_max=2 地图 offensive 应为 2")
	assert_eq(result2["defensive_lv"], 4, "L4 在 map_max=2 地图 defensive 应为 4")


# ============================================================================
# AC-008：player=2, map_max=3 → offensive=2, defensive=2（玩家低于地图上限，无压制）
# ============================================================================

func test_ac008_map_effective_realm_player_lower_no_suppression() -> void:
	var result: Dictionary = rs.map_effective_realm(2, 3)
	assert_eq(result["offensive_lv"], 2, "offensive 应为玩家境界 2（无压制）")
	assert_eq(result["defensive_lv"], 2, "defensive 应为玩家境界 2（无压制）")


func test_ac008_map_effective_realm_equal_no_suppression() -> void:
	# 玩家境界 == 地图上限 → 无压制
	var result: Dictionary = rs.map_effective_realm(3, 3)
	assert_eq(result["offensive_lv"], 3, "玩家==地图上限 offensive 应为 3")
	assert_eq(result["defensive_lv"], 3, "玩家==地图上限 defensive 应为 3")


# ============================================================================
# AC-009：DROP_POOL_WEIGHTS 含 5 个池等级
# ============================================================================

func test_ac009_drop_pool_weights_has_five_tiers() -> void:
	var table: Dictionary = rs.DROP_POOL_WEIGHTS
	assert_eq(table.size(), 5, "DROP_POOL_WEIGHTS 应含 5 个池等级")
	for tier: int in range(1, 6):
		assert_true(table.has(tier), "应含池等级 %d" % tier)


func test_ac009_drop_pool_weights_sum_to_hundred() -> void:
	# S-1: 每个 tier 的权重总和 == 100（AC-009 edge case）
	var table: Dictionary = rs.DROP_POOL_WEIGHTS
	for tier: int in range(1, 6):
		var weights: Dictionary = table[tier]
		var sum: int = 0
		for key: StringName in weights.keys():
			sum += int(weights[key])
		assert_eq(sum, 100, "tier %d 权重总和应为 100（实际 %d）" % [tier, sum])


# ============================================================================
# AC-010：get_rarity_weights(1) → 炼气期权重
# ============================================================================

func test_ac010_get_rarity_weights_tier1() -> void:
	var w: Dictionary = rs.get_rarity_weights(1)
	assert_eq(w[&"white"], 60, "tier1 white 应为 60")
	assert_eq(w[&"blue"], 30, "tier1 blue 应为 30")
	assert_eq(w[&"purple"], 10, "tier1 purple 应为 10")
	assert_eq(w[&"gold"], 0, "tier1 gold 应为 0")
	assert_eq(w[&"darkgold"], 0, "tier1 darkgold 应为 0")


# ============================================================================
# AC-011：get_rarity_weights(3) → 金丹期权重
# ============================================================================

func test_ac011_get_rarity_weights_tier3() -> void:
	var w: Dictionary = rs.get_rarity_weights(3)
	assert_eq(w[&"white"], 15, "tier3 white 应为 15")
	assert_eq(w[&"blue"], 30, "tier3 blue 应为 30")
	assert_eq(w[&"purple"], 35, "tier3 purple 应为 35")
	assert_eq(w[&"gold"], 18, "tier3 gold 应为 18")
	assert_eq(w[&"darkgold"], 2, "tier3 darkgold 应为 2")


# ============================================================================
# AC-012：get_rarity_weights(5) → 化神期权重
# ============================================================================

func test_ac012_get_rarity_weights_tier5() -> void:
	var w: Dictionary = rs.get_rarity_weights(5)
	assert_eq(w[&"white"], 5, "tier5 white 应为 5")
	assert_eq(w[&"blue"], 15, "tier5 blue 应为 15")
	assert_eq(w[&"purple"], 25, "tier5 purple 应为 25")
	assert_eq(w[&"gold"], 35, "tier5 gold 应为 35")
	assert_eq(w[&"darkgold"], 20, "tier5 darkgold 应为 20")


func test_ac012_get_rarity_weights_all_tiers() -> void:
	# 补充：tier2 和 tier4 权重验证（const 不可变性回归保护）
	var w2: Dictionary = rs.get_rarity_weights(2)
	assert_eq(w2[&"white"], 30, "tier2 white 应为 30")
	assert_eq(w2[&"blue"], 40, "tier2 blue 应为 40")
	assert_eq(w2[&"purple"], 25, "tier2 purple 应为 25")
	assert_eq(w2[&"gold"], 5, "tier2 gold 应为 5")
	assert_eq(w2[&"darkgold"], 0, "tier2 darkgold 应为 0")

	var w4: Dictionary = rs.get_rarity_weights(4)
	assert_eq(w4[&"white"], 10, "tier4 white 应为 10")
	assert_eq(w4[&"blue"], 20, "tier4 blue 应为 20")
	assert_eq(w4[&"purple"], 30, "tier4 purple 应为 30")
	assert_eq(w4[&"gold"], 30, "tier4 gold 应为 30")
	assert_eq(w4[&"darkgold"], 10, "tier4 darkgold 应为 10")


# ============================================================================
# AC-013：无效 pool_tier → 空 Dictionary + push_warning
# ============================================================================

func test_ac013_get_rarity_weights_invalid_tier_returns_empty_and_warning() -> void:
	var w: Dictionary = rs.get_rarity_weights(6)
	assert_eq(w, {}, "无效 pool_tier=6 应返回空 Dictionary")
	assert_push_warning_count(1, "无效 pool_tier 应 push_warning 1 次")


func test_ac013_get_rarity_weights_zero_tier_returns_empty_and_warning() -> void:
	var w: Dictionary = rs.get_rarity_weights(0)
	assert_eq(w, {}, "无效 pool_tier=0 应返回空 Dictionary")
	assert_push_warning_count(1, "无效 pool_tier 应 push_warning 1 次")


func test_ac013_get_rarity_weights_negative_tier_returns_empty_and_warning() -> void:
	var w: Dictionary = rs.get_rarity_weights(-1)
	assert_eq(w, {}, "无效 pool_tier=-1 应返回空 Dictionary")
	assert_push_warning_count(1, "无效 pool_tier 应 push_warning 1 次")


# ============================================================================
# AC-009 补充：const 不可变性回归保护
# ============================================================================

func test_ac009_get_rarity_weights_returns_copy_not_reference() -> void:
	# S-M1: 修改返回值不影响内部 const DROP_POOL_WEIGHTS——消费者误修改不会污染全局权重表
	var w: Dictionary = rs.get_rarity_weights(1)
	var original_white: int = int(rs.DROP_POOL_WEIGHTS[1][&"white"])
	w[&"white"] = 999  # 消费者误修改返回值
	assert_eq(rs.DROP_POOL_WEIGHTS[1][&"white"], original_white,
		"修改 get_rarity_weights 返回值不应影响内部 const DROP_POOL_WEIGHTS（应返回副本）")
