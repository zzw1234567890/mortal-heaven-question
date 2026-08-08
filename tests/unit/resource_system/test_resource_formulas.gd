extends GutTest
## Story 002 验收测试：6 资源公式纯函数。
##
## 覆盖 AC-001 到 AC-022（22 条 AC）。
## 测试策略：
##   - RS_SCRIPT.new() 构造 ResourceSystem 实例（不调 _ready，纯函数无副作用）
##   - 不依赖 GSM——6 个公式均为纯函数，不读写 player.resources
##   - 动态分派：var rs: Node 持有，返回值显式类型注解（控制清单 2026-08-05 规则）

const RS_SCRIPT: GDScript = preload("res://src/core/resource_system.gd")

## realm_gap_penalty 的保底值——用于 AC-016 范围断言（与实现 REALM_PENALTY_FLOOR 解耦）。
const REALM_PENALTY_FLOOR_EXPECTED: float = 0.1

var rs: Node = null


func before_each() -> void:
	rs = RS_SCRIPT.new()


func after_each() -> void:
	if rs != null:
		rs.free()
		rs = null


# ============================================================================
# AC-001：dismantle_value 方法签名 + 返回 int
# ============================================================================

func test_ac001_dismantle_value_returns_int() -> void:
	var val: int = rs.dismantle_value(1, 1)
	assert_eq(typeof(val), TYPE_INT, "dismantle_value 应返回 int")


# ============================================================================
# AC-002：dismantle_value(1, 1) 白卡 1 级 → 10
# ============================================================================

func test_ac002_dismantle_white_level1() -> void:
	assert_eq(rs.dismantle_value(1, 1), 10, "白卡 1 级应拆解得 10（base=10, bonus=0）")


# ============================================================================
# AC-003：dismantle_value(4, 1) 金卡 1 级 → 400
# ============================================================================

func test_ac003_dismantle_gold_level1() -> void:
	assert_eq(rs.dismantle_value(4, 1), 400, "金卡 1 级应拆解得 400（base=400, bonus=0）")


# ============================================================================
# AC-004：dismantle_value(5, 20) 暗金满级 → 3900
# ============================================================================

func test_ac004_dismantle_darkgold_level20() -> void:
	assert_eq(rs.dismantle_value(5, 20), 3900, "暗金 20 级应拆解得 3900（2000 + floor(2000×19×0.05)=1900）")


# ============================================================================
# AC-005：dismantle_value(3, 10) 紫卡 10 级 → 145
# ============================================================================

func test_ac005_dismantle_purple_level10() -> void:
	assert_eq(rs.dismantle_value(3, 10), 145, "紫卡 10 级应拆解得 145（100 + floor(100×9×0.05)=45）")


# ============================================================================
# AC-006：dismantle_crafted_value 方法签名 + 返回 int
# ============================================================================

func test_ac006_dismantle_crafted_value_returns_int() -> void:
	var val: int = rs.dismantle_crafted_value(4, 1, true)
	assert_eq(typeof(val), TYPE_INT, "dismantle_crafted_value 应返回 int")


# ============================================================================
# AC-007：dismantle_crafted_value(4, 1, true) 炼制金卡 → 200
# ============================================================================

func test_ac007_dismantle_crafted_gold() -> void:
	assert_eq(rs.dismantle_crafted_value(4, 1, true), 200, "炼制金卡应折价 50%（floor(400×0.5)=200）")


# ============================================================================
# AC-008：dismantle_crafted_value(4, 1, false) 非炼制金卡 → 400
# ============================================================================

func test_ac008_dismantle_noncrafted_gold() -> void:
	assert_eq(rs.dismantle_crafted_value(4, 1, false), 400, "非炼制金卡应等同 dismantle_value（400）")


# ============================================================================
# AC-009：sell_ling_cai_value 方法签名 + 返回 int
# ============================================================================

func test_ac009_sell_ling_cai_value_returns_int() -> void:
	var val: int = rs.sell_ling_cai_value(1, 2)
	assert_eq(typeof(val), TYPE_INT, "sell_ling_cai_value 应返回 int")


# ============================================================================
# AC-010：sell_ling_cai_value(1, 2) 低级灵材×2 → 20
# ============================================================================

func test_ac010_sell_low_quality_x2() -> void:
	assert_eq(rs.sell_ling_cai_value(1, 2), 20, "低级灵材×2 应得 20（10×2）")


# ============================================================================
# AC-011：sell_ling_cai_value(3, 1) 高级灵材×1 → 80
# ============================================================================

func test_ac011_sell_high_quality_x1() -> void:
	assert_eq(rs.sell_ling_cai_value(3, 1), 80, "高级灵材×1 应得 80")


# ============================================================================
# AC-012：sell_ling_cai_value(4, 3) 顶级灵材×3 → 600
# ============================================================================

func test_ac012_sell_top_quality_x3() -> void:
	assert_eq(rs.sell_ling_cai_value(4, 3), 600, "顶级灵材×3 应得 600（200×3）")


# ============================================================================
# AC-013：delete_card_cost 方法签名 + 返回 int
# ============================================================================

func test_ac013_delete_card_cost_returns_int() -> void:
	var val: int = rs.delete_card_cost(1)
	assert_eq(typeof(val), TYPE_INT, "delete_card_cost 应返回 int")


# ============================================================================
# AC-014：delete_card_cost(1) 首次删卡 → 50
# ============================================================================

func test_ac014_delete_first_cost() -> void:
	assert_eq(rs.delete_card_cost(1), 50, "首次删卡应花费 50")


# ============================================================================
# AC-015：delete_card_cost(5) 第 5 次删卡 → 150
# ============================================================================

func test_ac015_delete_fifth_cost() -> void:
	assert_eq(rs.delete_card_cost(5), 150, "第 5 次删卡应花费 150（50 + 25×4）")


# ============================================================================
# AC-016：realm_gap_penalty 方法签名 + 返回 float
# ============================================================================

func test_ac016_realm_gap_penalty_returns_float() -> void:
	var val: float = rs.realm_gap_penalty(3, 1)
	assert_eq(typeof(val), TYPE_FLOAT, "realm_gap_penalty 应返回 float")
	assert_true(val >= REALM_PENALTY_FLOOR_EXPECTED and val <= 1.0, "penalty 应在 [0.1, 1.0] 范围内")


# ============================================================================
# AC-017：realm_gap_penalty(3, 1) 金丹回炼气 → 0.4
# ============================================================================

func test_ac017_realm_gap_two_levels() -> void:
	assert_almost_eq(rs.realm_gap_penalty(3, 1), 0.4, 0.0001, "金丹回炼气（gap=2）应返回 0.4（1.0-0.6）")


# ============================================================================
# AC-018：realm_gap_penalty(4, 1) 元婴回炼气 → 0.1（保底）
# ============================================================================

func test_ac018_realm_gap_three_levels_floor() -> void:
	# 浮点精度：1.0-3×0.3 存在微小误差，用近似比较
	assert_almost_eq(rs.realm_gap_penalty(4, 1), 0.1, 0.0001, "元婴回炼气（gap=3）应保底 0.1")


# ============================================================================
# AC-019：realm_gap_penalty(2, 3) 玩家低于地图上限 → 1.0
# ============================================================================

func test_ac019_realm_gap_negative_no_penalty() -> void:
	assert_eq(rs.realm_gap_penalty(2, 3), 1.0, "玩家低于地图上限（gap=-1）应无惩罚（1.0）")


# ============================================================================
# AC-020：apply_ling_shi_bonus 方法签名 + 返回 int
# ============================================================================

func test_ac020_apply_ling_shi_bonus_returns_int() -> void:
	var val: int = rs.apply_ling_shi_bonus(25, true)
	assert_eq(typeof(val), TYPE_INT, "apply_ling_shi_bonus 应返回 int")


# ============================================================================
# AC-021：apply_ling_shi_bonus(25, true) 青云剑宗天赋 → 28
# ============================================================================

func test_ac021_apply_bonus_with_qingyun() -> void:
	assert_eq(rs.apply_ling_shi_bonus(25, true), 28, "青云剑宗天赋应加成 28（floor(25×1.15)=28）")


# ============================================================================
# AC-022：apply_ling_shi_bonus(25, false) 无天赋 → 25
# ============================================================================

func test_ac022_apply_bonus_without_talent() -> void:
	assert_eq(rs.apply_ling_shi_bonus(25, false), 25, "无天赋应原值返回 25")


# ============================================================================
# 边缘情况补强：无效输入守卫
# ============================================================================

func test_dismantle_value_invalid_rarity_returns_zero() -> void:
	assert_eq(rs.dismantle_value(0, 1), 0, "rarity=0 应返回 0 + push_error")
	assert_eq(rs.dismantle_value(6, 1), 0, "rarity=6 应返回 0 + push_error")


func test_dismantle_value_level_zero_no_bonus() -> void:
	# level=0 时 maxi(0, -1)=0，bonus=0，仅返回 base
	assert_eq(rs.dismantle_value(2, 0), 30, "level=0 应仅返回 base（无负 bonus）")


func test_sell_ling_cai_invalid_quality_returns_zero() -> void:
	assert_eq(rs.sell_ling_cai_value(0, 1), 0, "quality=0 应返回 0")
	assert_eq(rs.sell_ling_cai_value(5, 1), 0, "quality=5 应返回 0")


func test_sell_ling_cai_zero_quantity_returns_zero() -> void:
	assert_eq(rs.sell_ling_cai_value(2, 0), 0, "quantity=0 应返回 0")


func test_sell_ling_cai_negative_quantity_returns_zero() -> void:
	assert_eq(rs.sell_ling_cai_value(2, -1), 0, "负 quantity 应返回 0 + push_error")
	assert_eq(rs.sell_ling_cai_value(1, -100), 0, "大负数 quantity 应返回 0")
	assert_push_error_count(2, "两次负 quantity 应各 push_error 1 次")


func test_dismantle_crafted_value_invalid_rarity_returns_zero() -> void:
	# dismantle_crafted_value 委托 dismantle_value——无效 rarity 传递性返回 0
	assert_eq(rs.dismantle_crafted_value(0, 1, true), 0, "rarity=0 + is_crafted=true 应返回 0")
	assert_eq(rs.dismantle_crafted_value(6, 1, false), 0, "rarity=6 + is_crafted=false 应返回 0")


func test_realm_gap_one_level_partial_penalty() -> void:
	assert_almost_eq(rs.realm_gap_penalty(2, 1), 0.7, 0.0001, "gap=1 应返回 0.7（1.0-0.3）")


func test_delete_card_cost_invalid_count_returns_base() -> void:
	assert_eq(rs.delete_card_cost(0), 50, "delete_count=0 应返回 DELETE_BASE（50）")
	assert_eq(rs.delete_card_cost(-1), 50, "delete_count=-1 应返回 DELETE_BASE（50）")


func test_realm_gap_penalty_same_level_no_penalty() -> void:
	assert_eq(rs.realm_gap_penalty(3, 3), 1.0, "同级（gap=0）应无惩罚（1.0）")


func test_realm_gap_penalty_large_gap_floors() -> void:
	# gap=5 时 1.0-1.5=-0.5，保底 0.1
	assert_almost_eq(rs.realm_gap_penalty(6, 1), 0.1, 0.0001, "gap=5 应保底 0.1")


func test_apply_ling_shi_bonus_zero_base() -> void:
	assert_eq(rs.apply_ling_shi_bonus(0, true), 0, "base=0 加成后仍为 0")
