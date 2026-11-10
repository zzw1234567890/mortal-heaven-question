extends GutTest
## 手牌选中态视觉集成测试（combat-ui-interaction 001）。[br]
## [br][b]背景[/b]：epic 要求「选中态在 UI 上可观测（选中抬起、非法时不可确认）」。
## 逻辑侧由 HandSelectionModel 锁定，本文件锁定[b]视觉落定[/b]——模型说「第 7 张
## 选着」时，手牌区真的把它抬起来、描边加粗、且不影响其他卡。[br]
## [br][b]本文件锁定四条语义[/b]：[br]
##   1. 选中的卡上移（抬升量 = HandCard.SELECTED_LIFT）；[br]
##   2. 选中的卡描边换成高亮色且加粗（双通道，不只靠颜色）；[br]
##   3. 取消选中 → 回到弧形基准位（不是留在抬起位）；[br]
##   4. 手牌刷新（hand_changed）后选中视觉[b]重放[/b]——否则会出「幽灵选中」。[br]
## [br]风格先例：tests/integration/combat_ui/test_hand_area.gd。

const HandAreaScript := preload("res://src/ui/combat/layout/hand_area.gd")
const HandCardScript := preload("res://src/ui/combat/layout/hand_card.gd")
const Rules := preload("res://src/ui/combat/shared/hand_arc_rules.gd")
const Selection := preload("res://src/ui/combat/shared/hand_selection_model.gd")

## 快照卡 ID 段（本文件独立——不与其它文件夹具冲突）。
const ID_BASE: int = 7900

var hand_area: Control = null


func before_each() -> void:
	hand_area = HandAreaScript.new()
	hand_area.size = Vector2(1280, 720)
	add_child_autofree(hand_area)
	hand_area.call(&"set_reduce_motion", true)  # 直跳终态——位置断言无动画干扰


## 手牌快照工厂——带 card_instance_id（选中匹配所需）。
func _cards(count: int) -> Array:
	var out: Array = []
	for i: int in range(count):
		out.append({
			"card_instance_id": ID_BASE + i,
			"name": "卡%d" % i, "cost": 1, "rarity": 1, "type": 1,
		})
	return out


## 弧形基准位（未选中的 y——直跳终态的 position.y）。
func _base_y(index: int, count: int) -> float:
	return float(Rules.hand_card_position(index, count, 1280.0, 720.0)["y"])


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 选中抬起
# ═══════════════════════════════════════════════════════════════════════════════

## 选中第 2 张 → 该卡相对基准位上移 SELECTED_LIFT，其他卡不动。
func test_selected_card_lifts_by_constant() -> void:
	# Arrange
	hand_area.call(&"apply_hand", _cards(4))
	var card: Control = hand_area.call(&"get_card", 1)
	var before_y: float = card.position.y
	# Act
	hand_area.call(&"apply_selection", ID_BASE + 1)
	# Assert
	assert_almost_eq(card.position.y, before_y - HandCardScript.SELECTED_LIFT, 0.5,
			"选中的卡上移一个抬起量")
	assert_true(bool(card.get(&"is_selected")), "卡的选中标志已落定")


## 未选中的卡保持弧形基准位（抬升只作用于选中卡）。
func test_unselected_cards_stay_at_base_position() -> void:
	# Arrange
	hand_area.call(&"apply_hand", _cards(3))
	# Act
	hand_area.call(&"apply_selection", ID_BASE + 1)
	# Assert
	var other: Control = hand_area.call(&"get_card", 0)
	assert_almost_eq(other.position.y, _base_y(0, 3), 0.5, "未选中卡仍在基准位")
	assert_false(bool(other.get(&"is_selected")), "未选中标志为 false")


## 取消选中 → 选中卡回到基准位（不是留在抬起位）。
func test_clear_selection_restores_base_position() -> void:
	# Arrange
	hand_area.call(&"apply_hand", _cards(3))
	hand_area.call(&"apply_selection", ID_BASE + 1)
	# Act
	hand_area.call(&"apply_selection", Selection.NO_CARD)
	# Assert
	var card: Control = hand_area.call(&"get_card", 1)
	assert_almost_eq(card.position.y, _base_y(1, 3), 0.5, "取消后回到弧形基准位")
	assert_false(bool(card.get(&"is_selected")), "选中标志清除")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 描边：双通道（不只靠颜色）
# ═══════════════════════════════════════════════════════════════════════════════

## 选中 → 描边色换成高亮色[b]且加粗[/b]。
## [br][b]为什么要求加粗[/b]：只换颜色对色盲玩家不可辨——位移 + 线宽 + 颜色三通道
## 里至少要有两个不依赖色觉的信号。
func test_selected_card_has_highlighted_thicker_border() -> void:
	# Arrange
	hand_area.call(&"apply_hand", _cards(2))
	var card: Control = hand_area.call(&"get_card", 0)
	var base_color: Color = card.call(&"get_border_color")
	var base_width: float = float(card.call(&"get_border_width"))
	# Act
	hand_area.call(&"apply_selection", ID_BASE)
	# Assert
	assert_ne(card.call(&"get_border_color"), base_color, "描边色变了")
	assert_eq(card.call(&"get_border_color"), HandCardScript.SELECTED_BORDER_COLOR,
			"用选中的高亮色")
	assert_true(float(card.call(&"get_border_width")) > base_width, "描边加粗了")


## 取消选中 → 描边恢复稀有度原色与原线宽。
func test_clear_selection_restores_rarity_border() -> void:
	# Arrange
	hand_area.call(&"apply_hand", _cards(2))
	var card: Control = hand_area.call(&"get_card", 0)
	var base_color: Color = card.call(&"get_border_color")
	var base_width: float = float(card.call(&"get_border_width"))
	hand_area.call(&"apply_selection", ID_BASE)
	# Act
	hand_area.call(&"apply_selection", Selection.NO_CARD)
	# Assert
	assert_eq(card.call(&"get_border_color"), base_color, "描边色恢复稀有度色")
	assert_eq(float(card.call(&"get_border_width")), base_width, "线宽恢复")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 手牌刷新后重放（防幽灵选中）
# ═══════════════════════════════════════════════════════════════════════════════

## 选中后手牌刷新（hand_changed 重建）→ 选中视觉[b]仍在[/b]。[br]
## [br][b]为什么必须[/b]：重建会新建/复用卡节点并重写全部渲染快照；若不重放选中，
## 模型仍以为「选着第 1 张」，UI 上却什么反馈都没有——玩家看不到自己选了什么。
func test_selection_survives_hand_refresh() -> void:
	# Arrange
	hand_area.call(&"apply_hand", _cards(4))
	hand_area.call(&"apply_selection", ID_BASE + 1)
	# Act——手牌变更（比如别处抽了一张）
	hand_area.call(&"on_hand_changed", _cards(5))
	# Assert
	var card: Control = hand_area.call(&"get_card", 1)
	assert_true(bool(card.get(&"is_selected")), "刷新后选中仍在")
	assert_almost_eq(card.position.y, _base_y(1, 5) - HandCardScript.SELECTED_LIFT,
			0.5, "刷新后仍抬起（且按新卡数的基准位计算）")


## 选中的卡离开手牌 → 手牌区不再有任何卡处于选中态（模型侧另有 sync_hand 自清）。
func test_selection_gone_when_card_left_hand() -> void:
	# Arrange
	hand_area.call(&"apply_hand", _cards(3))
	hand_area.call(&"apply_selection", ID_BASE + 1)
	# Act——新快照里没有 ID_BASE+1
	var remaining: Array = _cards(3)
	remaining.remove_at(1)
	hand_area.call(&"apply_hand", remaining)
	# Assert
	for i: int in range(hand_area.call(&"get_card_count")):
		var card: Control = hand_area.call(&"get_card", i)
		assert_false(bool(card.get(&"is_selected")),
				"第 %d 张不应处于选中态" % i)


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 与既有三态视觉共存（费用灰显 / 灵能预览不被选中破坏）
# ═══════════════════════════════════════════════════════════════════════════════

## 费用不足（灰显）的卡也可以被选中——[b]视觉共存[/b]：灰显 modulate 保留，
## 描边仍切高亮。选起来看详情是允许的，只是确认按不动（逻辑侧锁定）。
func test_grayed_card_can_still_be_selected_visually() -> void:
	# Arrange
	hand_area.call(&"apply_hand", _cards(2))
	hand_area.call(&"apply_affordability", [false, true])
	var card: Control = hand_area.call(&"get_card", 0)
	var grayed: Color = card.get("modulate")
	# Act
	hand_area.call(&"apply_selection", ID_BASE)
	# Assert
	assert_true(bool(card.get(&"is_selected")), "灰显卡可进入选中态")
	assert_eq(card.get("modulate"), grayed, "灰显 modulate 未被选中破坏")
	assert_eq(card.call(&"get_border_color"), HandCardScript.SELECTED_BORDER_COLOR,
			"描边仍切高亮（两套视觉互不覆盖）")


## 无 card_instance_id 的快照 → 一律按未选中渲染（无 ID 无从匹配，不误选）。
func test_cards_without_instance_id_are_never_selected() -> void:
	# Arrange——快照缺 card_instance_id
	hand_area.call(&"apply_hand", [{"name": "无ID", "cost": 1, "rarity": 1, "type": 1}])
	# Act——即便要求选中 ID_BASE
	hand_area.call(&"apply_selection", ID_BASE)
	# Assert
	assert_false(bool(hand_area.call(&"get_card", 0).get(&"is_selected")),
			"缺 ID 的卡不参与选中匹配")


## get_card_instance_ids 只收有 ID 的条目（sync_hand 的入参来源）。
func test_get_card_instance_ids_skips_entries_without_id() -> void:
	# Arrange
	var mixed: Array = _cards(2)
	mixed.append({"name": "无ID", "cost": 0, "rarity": 1, "type": 1})
	hand_area.call(&"apply_hand", mixed)
	# Act
	var ids: Array = hand_area.call(&"get_card_instance_ids")
	# Assert
	assert_eq(ids, [ID_BASE, ID_BASE + 1], "只收带 ID 的条目")
