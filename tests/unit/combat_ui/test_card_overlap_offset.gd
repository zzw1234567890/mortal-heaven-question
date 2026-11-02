extends GutTest
## combat-ui-layout Story 006 单元测试：手牌堆叠重叠量（AC-2）。
##
## QA 规格（GDD §2 公式 + AC 明文）：
##   7 → cw+10；8 → 0.7cw；9 → 0.4cw（恰等下限）；10 → 0.4cw（下限守卫生效）。
## 边界：card_width 极小值（下限仍成立）。
##
## Story 类型 UI（Logic 内核）——此文件为 BLOCKING 证据。
## 风格先例：tests/unit/combat_ui/test_cost_color.gd。

const Rules := preload("res://src/ui/combat/shared/hand_arc_rules.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-2：重叠公式边界
# ═══════════════════════════════════════════════════════════════════════════════

func test_card_overlap_offset_seven_standard_spacing() -> void:
	# Then: 7 → cw+10（无重叠标准间距）
	assert_almost_eq(Rules.card_overlap_offset(7, 100.0), 110.0, 0.001,
			"total=7 应返回 cw+10=110")


func test_card_overlap_offset_eight_overlap_thirty_percent() -> void:
	# Then: 8 → 0.7cw（每多一张重叠 30% 卡宽）
	assert_almost_eq(Rules.card_overlap_offset(8, 100.0), 70.0, 0.001,
			"total=8 应返回 0.7cw=70")


func test_card_overlap_offset_nine_hits_min_floor_exactly() -> void:
	# Then: 9 → 0.4cw（恰等下限——100 - 100×0.3×2 = 40）
	assert_almost_eq(Rules.card_overlap_offset(9, 100.0), 40.0, 0.001,
			"total=9 应返回 0.4cw=40（恰等下限）")


func test_card_overlap_offset_ten_min_floor_guards() -> void:
	# Then: 10 → 0.4cw（下限守卫生效——原始 10 已低于下限）
	assert_almost_eq(Rules.card_overlap_offset(10, 100.0), 40.0, 0.001,
			"total=10 应返回 0.4cw=40（下限守卫生效）")


func test_card_overlap_offset_below_threshold_no_overlap() -> void:
	# Then: ≤7 全部标准间距（无重叠分支）
	assert_almost_eq(Rules.card_overlap_offset(1, 100.0), 110.0, 0.001,
			"total=1 应返回 cw+10")
	assert_almost_eq(Rules.card_overlap_offset(5, 100.0), 110.0, 0.001,
			"total=5 应返回 cw+10")


# ═══════════════════════════════════════════════════════════════════════════════
# 边界情况（QA 规格 edge cases——下限仍成立）
# ═══════════════════════════════════════════════════════════════════════════════

func test_card_overlap_offset_tiny_card_width_floor_holds() -> void:
	# Then: card_width 极小值（下限仍成立——结果 == 0.4cw）
	var tiny: float = 10.0
	assert_almost_eq(Rules.card_overlap_offset(10, tiny), tiny * 0.4, 0.001,
			"极小卡宽下结果应恰等 0.4cw（下限守卫生效）")


func test_card_overlap_offset_floor_ratio_constant() -> void:
	# Then: 下限比例常量集中定义（control-manifest 禁止硬编码阈值）
	assert_almost_eq(Rules.OVERLAP_MIN_RATIO, 0.4, 0.0001, "下限比例 = 0.4")
	assert_almost_eq(Rules.OVERLAP_RATIO, 0.3, 0.0001, "重叠比例 = 0.3")
	assert_eq(Rules.OVERLAP_THRESHOLD, 7, "堆叠阈值 = 7")
