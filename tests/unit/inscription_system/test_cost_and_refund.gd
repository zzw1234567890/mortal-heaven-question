extends GutTest
## Story 6-10 验收测试：inscription_cost / dismantle_inscription_refund 成本与返还。
##
## 覆盖 AC-001 到 AC-010（10 条 AC）。
## 测试策略：
##   - 直接调用 InscriptionSystem 静态纯函数
##   - 验证递增成本公式 + 软上限 + 拆解返还边界
##
## 设计文档来源：GDD inscription-system.md §1/§4
## Story 来源：production/epics/inscription-system/story-003-cost-and-refund.md

const IS := preload("res://src/feature/inscription_system.gd")


# ============================================================================
# AC-001：inscription_cost(0) = 1（首次铭刻）
# ============================================================================

func test_inscription_cost_first_is_1() -> void:
	assert_eq(IS.inscription_cost(0), 1, "首次铭刻 cost 应为 1")


# ============================================================================
# AC-002：inscription_cost(1) = 2（第二次）
# ============================================================================

func test_inscription_cost_second_is_2() -> void:
	assert_eq(IS.inscription_cost(1), 2, "第二次铭刻 cost 应为 2")


# ============================================================================
# AC-003：inscription_cost(4) = 5（第五次）
# ============================================================================

func test_inscription_cost_fifth_is_5() -> void:
	assert_eq(IS.inscription_cost(4), 5, "第五次铭刻 cost 应为 5")


# ============================================================================
# AC-004：inscription_cost(5) = 5（软上限——第六次及以后固定 5）
# ============================================================================

func test_inscription_cost_sixth_capped_at_5() -> void:
	assert_eq(IS.inscription_cost(5), 5, "第六次铭刻 cost 应受软上限钳制为 5")


# ============================================================================
# AC-005：inscription_cost(100) = 5（极大值仍受软上限钳制）
# ============================================================================

func test_inscription_cost_huge_value_capped() -> void:
	assert_eq(IS.inscription_cost(100), 5, "极大值 cost 应受软上限钳制为 5")


# ============================================================================
# AC-006：dismantle_inscription_refund(0) = 0（从未铭刻不返还）
# ============================================================================

func test_refund_zero_spent_returns_zero() -> void:
	assert_eq(IS.dismantle_inscription_refund(0), 0, "从未铭刻拆解不返还")


# ============================================================================
# AC-007：dismantle_inscription_refund(1) = 1（至少返 1）
# ============================================================================

func test_refund_one_spent_returns_at_least_1() -> void:
	assert_eq(IS.dismantle_inscription_refund(1), 1, "铭刻 1 次拆解至少返 1")


# ============================================================================
# AC-008：dismantle_inscription_refund(6) = 3（floor(6×0.5)=3）
# ============================================================================

func test_refund_six_spent_returns_3() -> void:
	assert_eq(IS.dismantle_inscription_refund(6), 3, "铭刻 3 次（6 灵材）返还 floor(3) = 3")


# ============================================================================
# AC-009：dismantle_inscription_refund(3) = 1（floor(3×0.5)=1，max(1,...)）
# ============================================================================

func test_refund_three_spent_returns_1() -> void:
	assert_eq(IS.dismantle_inscription_refund(3), 1, "铭刻 2 次（3 灵材）返还 floor(1.5) = 1")


# ============================================================================
# AC-010：dismantle_inscription_refund(15) = 7（floor(15×0.5)=7）
# ============================================================================

func test_refund_fifteen_spent_returns_7() -> void:
	assert_eq(IS.dismantle_inscription_refund(15), 7, "铭刻 5 次（15 灵材）返还 floor(7.5) = 7")
