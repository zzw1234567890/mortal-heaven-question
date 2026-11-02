extends GutTest
## combat-ui-layout Story 006 集成测试：手牌区组件（AC-4/AC-5/AC-7/AC-8）。
##
## 覆盖：弧形定位 + Z 层序（AC-1/AC-3 消费）、灰显/灵能预览三态（AC-4）、
## 0 张空提示 + 满 10 溢出提示（AC-5）、敌方卡背区（AC-7）、抽牌入场与
## 重排动画（AC-6/AC-8）。
##
## Story 类型 UI（Logic 内核）——Logic 部分由三个单元测试文件 BLOCKING 覆盖，
## 此文件覆盖组件接线与视觉状态判定。
## 风格先例：tests/integration/combat_ui/test_cost_display.gd。

const HandAreaScript := preload("res://src/ui/combat/layout/hand_area.gd")
const MockHandSignals := preload("res://tests/integration/combat_ui/mocks/mock_hand_signals.gd")
const Rules := preload("res://src/ui/combat/shared/hand_arc_rules.gd")

var hand_area: HandArea = null


func before_each() -> void:
	hand_area = HandAreaScript.new()
	hand_area.size = Vector2(1280, 720)
	add_child_autofree(hand_area)


func _cards(n: int) -> Array:
	var cards: Array = []
	for i: int in range(n):
		cards.append({
			"name": "卡%d" % i,
			"cost": i % 3,
			"rarity": (i % 5) + 1,
			"type": i % 6,
			"affordable": true,
		})
	return cards


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1/AC-3 消费：弧形定位 + Z 层序
# ═══════════════════════════════════════════════════════════════════════════════

func test_hand_area_arc_layout_center_highest_z() -> void:
	# When: 7 张手牌
	hand_area.set_reduce_motion(true)
	hand_area.apply_hand(_cards(7))
	hand_area.apply_hand_count(0)
	# Then: 7 张卡节点存在，中心卡 z 最高
	assert_eq(hand_area.get_card_count(), 7, "应有 7 张卡节点")
	var center: HandCard = hand_area.get_card(3)
	var edge: HandCard = hand_area.get_card(0)
	assert_true(center.z_index > edge.z_index, "中心卡 z_index 应高于边缘卡")


func test_hand_area_arc_center_card_arc_shape() -> void:
	# When: 7 张手牌（reduce_motion 直跳终态）
	hand_area.set_reduce_motion(true)
	hand_area.apply_hand(_cards(7))
	hand_area.apply_hand_count(0)
	# Then: 中心卡 y = base_y（最低点），两端翘起（GDD 半径法微笑弧）；x 对称
	var center: HandCard = hand_area.get_card(3)
	var left: HandCard = hand_area.get_card(0)
	var right: HandCard = hand_area.get_card(6)
	assert_almost_eq(center.position.y, 720.0 * 0.86, 0.5, "中心卡 y = base_y = 0.86H")
	assert_true(center.position.y > left.position.y, "中心卡 y 应大于左边缘（最低点）")
	assert_almost_eq(left.position.x + right.position.x,
			hand_area.size.x - 100.0, 0.5,
			"左右边缘卡 x 应关于区中心对称（各 100 宽卡居中）")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-4：灰显 / 灵能预览三态
# ═══════════════════════════════════════════════════════════════════════════════

func test_hand_area_unaffordable_grayed_in_play_phase() -> void:
	# Arrange: 3 张手牌，第 1 张费用不足
	hand_area.set_reduce_motion(true)
	hand_area.apply_phase(2)  # 出牌阶段
	var cards: Array = _cards(3)
	cards[1]["affordable"] = false
	hand_area.apply_hand(cards)
	# Then: 灰显（modulate != WHITE）+ 费用数字红
	var grayed: HandCard = hand_area.get_card(1)
	var normal: HandCard = hand_area.get_card(0)
	assert_ne(grayed.get_current_modulate(), Color.WHITE, "费用不足卡应灰显")
	assert_eq(normal.get_current_modulate(), Color.WHITE, "费用充足卡应彩色")
	assert_ne(grayed.get_cost_color(), normal.get_cost_color(), "费用不足费用数字应异色")


func test_hand_area_psychic_preview_outside_play_phase() -> void:
	# When: 阶段 3（出牌阶段外）→ 灵能预览
	hand_area.set_reduce_motion(true)
	hand_area.apply_phase(3)
	hand_area.apply_hand(_cards(2))
	# Then: 全部卡灵能预览（🔒 可见、modulate 非白）
	var card: HandCard = hand_area.get_card(0)
	assert_true(card.is_lock_visible(), "阶段 2 外应显示 🔒 锁标记")
	assert_ne(card.get_current_modulate(), Color.WHITE, "灵能预览应降饱和")


func test_hand_area_phase_transition_flips_state() -> void:
	# When: 阶段 2 → 阶段 5（经 mock 信号路由）
	hand_area.set_reduce_motion(true)
	hand_area.apply_hand(_cards(2))
	var mock := MockHandSignals.new()
	add_child_autofree(mock)
	hand_area.bind_signals(mock)
	mock.phase_changed.emit(2, 5, 1)
	# Then: 灵能预览生效
	assert_true(hand_area.get_card(0).is_lock_visible(), "阶段切换后应进入灵能预览")


func test_hand_area_hand_changed_rebuilds_snapshot() -> void:
	# When: hand_changed 载荷驱动快照重建（生产契约——on_hand_changed 消费载荷）
	hand_area.set_reduce_motion(true)
	var mock := MockHandSignals.new()
	add_child_autofree(mock)
	hand_area.bind_signals(mock)
	mock.hand_changed.emit(_cards(4))
	# Then: 快照重建为 4 张（不再依赖手动 apply_hand）
	assert_eq(hand_area.get_card_count(), 4, "hand_changed 载荷应驱动快照重建为 4 张")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-5：0 张空提示 + 满 10 溢出提示
# ═══════════════════════════════════════════════════════════════════════════════

func test_hand_area_empty_hint_shown() -> void:
	# When: 0 张手牌
	hand_area.set_reduce_motion(true)
	hand_area.apply_hand([])
	hand_area.apply_hand_count(0)
	# Then: 空提示可见
	assert_true(hand_area.is_empty_hint_visible(), "0 张手牌应显示「无手牌」提示")


func test_hand_area_overflow_hint_shown_on_overflow() -> void:
	# When: 满 10 张 + card_overflow 信号（非 reduce_motion——提示可见 + 淡出）
	hand_area.set_reduce_motion(false)
	hand_area.apply_hand(_cards(10))
	var mock := MockHandSignals.new()
	add_child_autofree(mock)
	hand_area.bind_signals(mock)
	mock.card_overflow.emit(11)
	# Then: 溢出提示可见（2s 淡出 Tween 创建）
	assert_true(hand_area.has_overflow_hint_active(), "满 10 抽牌应显示溢出提示")


func test_hand_area_overflow_hint_skipped_in_reduce_motion() -> void:
	# When: reduce_motion 下 card_overflow——提示不残留（直跳终态隐藏）
	hand_area.set_reduce_motion(true)
	hand_area.apply_hand(_cards(10))
	var mock := MockHandSignals.new()
	add_child_autofree(mock)
	hand_area.bind_signals(mock)
	mock.card_overflow.emit(11)
	# Then: reduce_motion 不显示溢出提示（避免永久残留）
	assert_false(hand_area.has_overflow_hint_active(),
			"reduce_motion 下溢出提示不应残留")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-7：敌方手牌背面区
# ═══════════════════════════════════════════════════════════════════════════════

func test_hand_area_enemy_card_back_count() -> void:
	# When: 敌方手牌 5 张
	hand_area.apply_hand_count(5)
	# Then: 卡背区数量同步
	assert_eq(hand_area.enemy_hand_back.get_card_back_count(), 5,
			"敌方卡背区应显示 5 张卡背")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-6/AC-8：抽牌入场 + 重排动画
# ═══════════════════════════════════════════════════════════════════════════════

func test_hand_area_rearrange_tween_created() -> void:
	# When: 手牌变更（非 reduce_motion）→ 重排动画 Tween 创建
	hand_area.set_reduce_motion(false)
	hand_area.apply_hand(_cards(7))
	assert_true(hand_area.has_rearrange_active(), "手牌变更应创建重排 Tween")


func test_hand_area_draw_anim_snaps_in_reduce_motion() -> void:
	# When: reduce_motion 下抽牌入场——直跳终态（无飞入偏移残留）
	hand_area.set_reduce_motion(true)
	hand_area.apply_hand(_cards(3))
	hand_area.apply_hand_count(0)
	hand_area.on_card_drawn(99)
	# Then: 末卡位置为弧形终位（精确值——无 DRAW_START_OFFSET 偏移）
	var last: HandCard = hand_area.get_card(2)
	var target: Dictionary = Rules.hand_card_position(2, 3, 1280.0, 720.0)
	assert_almost_eq(last.position.x, target["x"] - last.size.x * 0.5, 0.5,
			"reduce_motion 抽牌末卡 x 应为弧形终位")
	assert_almost_eq(last.position.y, target["y"], 0.5,
			"reduce_motion 抽牌末卡 y 应为弧形终位（无 +90 飞入偏移）")
