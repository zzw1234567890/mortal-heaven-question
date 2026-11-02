extends GutTest
## combat-ui-layout Story 006 单元测试：手牌弧形排位（AC-1）。
##
## QA 规格（GDD §1 公式 + AC 明文）：
##   total=0 → 空字典；total=1 → (中心, 0.86H, 0)；total=7 index 0/6 x 关于
##   中心对称且 rotation 互为相反数；中心 index y 最小、rotation≈0；
##   index=0 x ≥ 20px。
## 边界：1280 宽 + total=10 响应式卡宽（所有 x ∈ [20, W-20]）；
##   total=2 → arc=6°；rotation 单调递增。
##
## Story 类型 UI（Logic 内核）——此文件为 BLOCKING 证据。
## 风格先例：tests/unit/combat_ui/test_cost_color.gd。

const Rules := preload("res://src/ui/combat/shared/hand_arc_rules.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1：圆弧公式守卫与对称性
# ═══════════════════════════════════════════════════════════════════════════════

func test_hand_card_position_zero_cards_returns_empty() -> void:
	# Then: total=0 → 空字典（守卫：空手牌不计算位置）
	assert_eq(Rules.hand_card_position(0, 0, 1920.0, 1080.0), {},
			"total=0 应返回空字典")


func test_hand_card_position_single_card_centered_no_rotation() -> void:
	# Then: total=1 → (屏幕中心, 0.86H, 0)（单张卡无弧度）
	var pos: Dictionary = Rules.hand_card_position(0, 1, 1920.0, 1080.0)
	assert_almost_eq(pos["x"], 960.0, 0.001, "单张卡 x = 屏幕中心 960")
	assert_almost_eq(pos["y"], 1080.0 * 0.86, 0.001, "单张卡 y = 0.86H = 928.8")
	assert_almost_eq(pos["rotation"], 0.0, 0.0001, "单张卡 rotation = 0")


func test_hand_card_position_seven_cards_symmetric() -> void:
	# When: total=7，index 0 与 6
	var left: Dictionary = Rules.hand_card_position(0, 7, 1280.0, 720.0)
	var right: Dictionary = Rules.hand_card_position(6, 7, 1280.0, 720.0)
	# Then: x 关于中心对称（640），rotation 互为相反数
	assert_almost_eq(left["x"], 640.0 - (right["x"] - 640.0), 0.001,
			"index 0/6 x 应关于中心 640 对称")
	assert_almost_eq(left["rotation"], -right["rotation"], 0.0001,
			"index 0/6 rotation 应互为相反数")


func test_hand_card_position_center_rotation_zero_and_arc_shape() -> void:
	# Then: total=7 中心 index=3——rotation=0；GDD §1 半径法圆弧（y=base_y-
	#   radius×(1-cos)：中心 y = base_y 最低点，两端 y 更小向上翘——微笑弧）
	var center: Dictionary = Rules.hand_card_position(3, 7, 1280.0, 720.0)
	var edge: Dictionary = Rules.hand_card_position(0, 7, 1280.0, 720.0)
	assert_almost_eq(center["rotation"], 0.0, 0.0001, "中心卡 rotation=0")
	assert_almost_eq(center["y"], 720.0 * 0.86, 0.001, "中心卡 y = base_y = 0.86H")
	assert_true(center["y"] > edge["y"], "GDD 半径法：中心最低、两端翘起（微笑弧）")


func test_hand_card_position_edge_margin_respected() -> void:
	# Then: index=0 的 x ≥ 20px（端点边距守恒）
	var first: Dictionary = Rules.hand_card_position(0, 7, 1280.0, 720.0)
	assert_true(first["x"] >= 20.0, "index=0 x 应 ≥ 20px（左侧边距）")


# ═══════════════════════════════════════════════════════════════════════════════
# 边界情况（QA 规格 edge cases——固化决策）
# ═══════════════════════════════════════════════════════════════════════════════

func test_hand_card_position_all_cards_within_screen_at_1280_width() -> void:
	# Then: 1280 宽 + total=10 响应式卡宽——所有 x ∈ [20, W-20]
	for i: int in range(10):
		var pos: Dictionary = Rules.hand_card_position(i, 10, 1280.0, 720.0)
		assert_true(pos["x"] >= 20.0, "total=10 index %d x 应 ≥ 20（左边界）" % i)
		assert_true(pos["x"] <= 1260.0, "total=10 index %d x 应 ≤ 1260（右边界）" % i)


func test_hand_card_position_rotation_monotonic_increasing() -> void:
	# Then: rotation 随 index 单调递增（-half → +half）
	var prev: float = -INF
	for i: int in range(7):
		var rot: float = Rules.hand_card_position(i, 7, 1280.0, 720.0)["rotation"]
		assert_true(rot > prev, "rotation 应随 index 单调递增（index %d）" % i)
		prev = rot


func test_hand_card_position_two_cards_arc_six_degrees() -> void:
	# Then: total=2 → arc=6°（2×3°）——两卡 rotation 分别为 ±3° 弧度量
	var left: Dictionary = Rules.hand_card_position(0, 2, 1280.0, 720.0)
	var right: Dictionary = Rules.hand_card_position(1, 2, 1280.0, 720.0)
	assert_almost_eq(left["rotation"], -deg_to_rad(3.0), 0.0001,
			"total=2 index=0 rotation = -3°")
	assert_almost_eq(right["rotation"], deg_to_rad(3.0), 0.0001,
			"total=2 index=1 rotation = +3°")
	assert_almost_eq(left["x"] + right["x"], 1280.0, 0.001,
			"total=2 两卡 x 关于中心对称")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-4：>7 张合成语义（唯一期望锁定——相邻卡水平间距 == overlap 返回值）
# ═══════════════════════════════════════════════════════════════════════════════

func test_hand_card_position_over_seven_composition_matches_overlap() -> void:
	# Then: total ∈ {8,9,10}——相邻卡水平间距恒等于 card_overlap_offset 返回值
	for total: int in [8, 9, 10]:
		var card_width: float = minf(Rules.DEFAULT_CARD_WIDTH,
				(1280.0 - 40.0) / float(total))
		var expected: float = Rules.card_overlap_offset(total, card_width)
		for i: int in range(total - 1):
			var a: Dictionary = Rules.hand_card_position(i, total, 1280.0, 720.0)
			var b: Dictionary = Rules.hand_card_position(i + 1, total, 1280.0, 720.0)
			assert_almost_eq(b["x"] - a["x"], expected, 0.001,
					"total=%d 相邻卡 %d/%d 水平间距应 == overlap 返回值" % [total, i, i + 1])


func test_hand_card_position_over_seven_all_within_screen() -> void:
	# Then: total=8/9/10——所有卡在屏内（x ∈ [20, W-20]）
	for total: int in [8, 9, 10]:
		for i: int in range(total):
			var pos: Dictionary = Rules.hand_card_position(i, total, 1280.0, 720.0)
			assert_true(pos["x"] >= 20.0, "total=%d index %d x 应 ≥ 20" % [total, i])
			assert_true(pos["x"] <= 1260.0, "total=%d index %d x 应 ≤ 1260" % [total, i])


func test_hand_card_position_narrow_screen_responsive_card_width() -> void:
	# Then: 640 宽 + total=10——响应式卡宽收缩分支（available/total < 默认卡宽）
	#   卡宽 = 600/10 = 60 < 100，相邻间距 = overlap(10, 60) = 60×0.4 = 24
	var card_width: float = (640.0 - 40.0) / 10.0
	assert_true(card_width < Rules.DEFAULT_CARD_WIDTH,
			"前置：640 宽下响应式卡宽应收缩（60 < 100）")
	var expected: float = Rules.card_overlap_offset(10, card_width)
	for i: int in range(10):
		var pos: Dictionary = Rules.hand_card_position(i, 10, 640.0, 720.0)
		assert_true(pos["x"] >= 20.0, "640 宽 index %d x 应 ≥ 20" % i)
		assert_true(pos["x"] <= 620.0, "640 宽 index %d x 应 ≤ 620" % i)
		if i < 9:
			var next_pos: Dictionary = Rules.hand_card_position(i + 1, 10, 640.0, 720.0)
			assert_almost_eq(next_pos["x"] - pos["x"], expected, 0.001,
					"640 宽相邻卡间距应随卡宽收缩为 overlap 返回值")
