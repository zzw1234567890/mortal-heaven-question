extends GutTest
## combat-ui-layout Story 006 单元测试：手牌 Z 层序（AC-3）。
##
## QA 规格（GDD §2「中心卡牌优先」）：
##   中心 index 最高，向两侧递减；total 奇偶的中心定义确定且一致。
## 边界：total=1（z=0）、total=2（两卡同层 tie-break）。
##
## Story 类型 UI（Logic 内核）——此文件为 BLOCKING 证据。
## 风格先例：tests/unit/combat_ui/test_cost_color.gd。

const Rules := preload("res://src/ui/combat/shared/hand_arc_rules.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-3：Z 层序
# ═══════════════════════════════════════════════════════════════════════════════

func test_hand_card_z_index_center_highest_odd_total() -> void:
	# Then: total=7——中心 index=3 最高，向两侧递减且对称
	var center_z: int = Rules.hand_card_z_index(3, 7)
	assert_eq(center_z, 6, "total=7 中心 index=3 应为最高 z=6")
	for i: int in range(7):
		assert_true(Rules.hand_card_z_index(i, 7) <= center_z,
				"index %d z 不应超过中心 z" % i)
	# 对称：index 0 与 6、1 与 5、2 与 4 z 相等
	for i: int in range(3):
		assert_eq(Rules.hand_card_z_index(i, 7), Rules.hand_card_z_index(6 - i, 7),
				"total=7 index %d 与 %d z 应相等（对称）" % [i, 6 - i])


func test_hand_card_z_index_decreases_outward_odd() -> void:
	# Then: total=7——中心向两侧递减（单调）
	assert_eq(Rules.hand_card_z_index(3, 7), 6, "中心 z=6")
	assert_eq(Rules.hand_card_z_index(2, 7), 5, "index=2 z=5")
	assert_eq(Rules.hand_card_z_index(1, 7), 4, "index=1 z=4")
	assert_eq(Rules.hand_card_z_index(0, 7), 3, "index=0 z=3")


func test_hand_card_z_index_even_total_dual_center() -> void:
	# Then: total=8——双中心 index 3/4 同层最高（tie-break 确定且一致）
	var z3: int = Rules.hand_card_z_index(3, 8)
	var z4: int = Rules.hand_card_z_index(4, 8)
	assert_eq(z3, z4, "total=8 双中心 index 3/4 应同层（tie-break）")
	assert_eq(z3, 7, "total=8 中心层 z=7")
	# 对称：0↔7、1↔6、2↔5
	for i: int in range(3):
		assert_eq(Rules.hand_card_z_index(i, 8), Rules.hand_card_z_index(7 - i, 8),
				"total=8 index %d 与 %d z 应相等（对称）" % [i, 7 - i])


func test_hand_card_z_index_even_total_consistent_across_calls() -> void:
	# Then: 偶数中心定义确定且一致（重复调用同值）
	for _i: int in range(3):
		assert_eq(Rules.hand_card_z_index(3, 8), 7, "total=8 index=3 重复调用应一致")
		assert_eq(Rules.hand_card_z_index(4, 8), 7, "total=8 index=4 重复调用应一致")


# ═══════════════════════════════════════════════════════════════════════════════
# 边界情况（QA 规格 edge cases）
# ═══════════════════════════════════════════════════════════════════════════════

func test_hand_card_z_index_single_card_zero() -> void:
	# Then: total=1 → z=0
	assert_eq(Rules.hand_card_z_index(0, 1), 0, "total=1 应返回 z=0")


func test_hand_card_z_index_two_cards_same_layer() -> void:
	# Then: total=2 → 两卡同层（tie-break——z 均为 1）
	assert_eq(Rules.hand_card_z_index(0, 2), Rules.hand_card_z_index(1, 2),
			"total=2 两卡应同层")
	assert_eq(Rules.hand_card_z_index(0, 2), 1, "total=2 层 z=1")
