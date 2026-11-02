extends GutTest
## combat-ui-layout Story 005 单元测试：费用显示颜色（AC-1）。
##
## QA 规格（GDD §4 公式 + AC 明文三守卫例）：
##   (3,0,3) → YELLOW（仅临时）；(0,0,0) → RED（守卫）；(5,5,0) → WHITE；
##   (3,5,0) → WHITE；(5,10,0) → YELLOW（ratio=0.5 恰黄）；(0,5,0) → RED；
##   (4,3,3) → WHITE（ratio≈0.67）。
## 边界：available 负值 → RED；temporary 负值 → 视为 0。
##
## Story 类型 UI（Logic 内核）——此文件为 BLOCKING 证据。
## 风格先例：tests/unit/combat_ui/test_hp_bar_color.gd。

const Rules := preload("res://src/ui/combat/shared/combat_ui_rules.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1：cost_color 完整覆盖（含 GDD 明文三守卫例）
# ═══════════════════════════════════════════════════════════════════════════════

func test_cost_color_base_max_zero_temp_zero_returns_red() -> void:
	# Then: base_max=0 且 temporary=0 → RED（守卫：无费用上限时费用枯竭）
	assert_eq(Rules.cost_color(0, 0, 0), Rules.COST_COLOR_RED,
			"(0,0,0) 应红（GDD AC 明文守卫）")


func test_cost_color_base_max_zero_temp_positive_returns_yellow() -> void:
	# Then: base_max=0 且 temporary>0 → YELLOW（仅临时费用，不视为充裕）
	assert_eq(Rules.cost_color(3, 0, 3), Rules.COST_COLOR_YELLOW,
			"(3,0,3) 应黄（GDD AC 明文——仅有临时费用）")
	assert_eq(Rules.cost_color(0, 0, 3), Rules.COST_COLOR_YELLOW,
			"(0,0,3) 应黄——可用为 0 但临时上限存在，不判枯竭")


func test_cost_color_full_returns_white() -> void:
	# Then: ratio > 0.5 → WHITE（充裕）
	assert_eq(Rules.cost_color(5, 5, 0), Rules.COST_COLOR_WHITE, "(5,5,0) 应白——满费")
	assert_eq(Rules.cost_color(3, 5, 0), Rules.COST_COLOR_WHITE,
			"(3,5,0) 应白——ratio=0.6 > 0.5")
	assert_eq(Rules.cost_color(4, 3, 3), Rules.COST_COLOR_WHITE,
			"(4,3,3) 应白——ratio≈0.67（AC 明文）")


func test_cost_color_mid_returns_yellow() -> void:
	# Then: 0 < ratio ≤ 0.5 → YELLOW（紧张）
	assert_eq(Rules.cost_color(5, 10, 0), Rules.COST_COLOR_YELLOW,
			"(5,10,0) 应黄——ratio=0.5 恰好黄（>0.5 才白）")
	assert_eq(Rules.cost_color(3, 8, 0), Rules.COST_COLOR_YELLOW,
			"(3,8,0) 应黄——ratio=0.375")


func test_cost_color_empty_returns_red() -> void:
	# Then: ratio = 0.0 → RED（枯竭）
	assert_eq(Rules.cost_color(0, 5, 0), Rules.COST_COLOR_RED,
			"(0,5,0) 应红（AC 明文——费用枯竭）")


func test_cost_color_temporary_bonus_included_in_total_max() -> void:
	# Then: 临时费用计入总上限（设计决策——颜色基于实际可用而非基础费用）
	assert_eq(Rules.cost_color(3, 5, 3), Rules.COST_COLOR_YELLOW,
			"(3,5,3) 应黄——total_max=8, ratio=0.375")
	assert_eq(Rules.cost_color(5, 5, 3), Rules.COST_COLOR_WHITE,
			"(5,5,3) 应白——total_max=8, ratio=0.625")


# ═══════════════════════════════════════════════════════════════════════════════
# 边界情况（QA 规格 edge cases——固化决策）
# ═══════════════════════════════════════════════════════════════════════════════

func test_cost_color_negative_available_returns_red() -> void:
	# Then: available < 0 → ratio < 0 → RED（枯竭——防御性钳制）
	assert_eq(Rules.cost_color(-1, 5, 0), Rules.COST_COLOR_RED,
			"(-1,5,0) 应红——负可用视为枯竭")


func test_cost_color_negative_temporary_treated_as_zero() -> void:
	# Then: temporary < 0 视为 0（负临时加成无意义——防御性钳制）
	assert_eq(Rules.cost_color(5, 5, -3), Rules.COST_COLOR_WHITE,
			"(5,5,-3) 应白——负临时钳制为 0 后 ratio=1.0")
	assert_eq(Rules.cost_color(3, 5, -3), Rules.COST_COLOR_WHITE,
			"(3,5,-3) 应白——钳制后 ratio=0.6")


func test_cost_color_thresholds_not_hardcoded_in_consumer() -> void:
	# Then: 阈值常量集中于 CombatUiRules（control-manifest 禁止硬编码阈值）
	assert_almost_eq(Rules.COST_WHITE_THRESHOLD, 0.5, 0.0001, "白阈值 = 0.5")
