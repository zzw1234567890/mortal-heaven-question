extends "res://tests/integration/exploration_ui/shop_rest_node_fixture.gd"
## 商店面板的键盘/手柄导航 —— 真实输入事件走完整链路。[br]
## [br][b]为什么另起一个文件[/b]：装置与商店/回复用例同源（真实场景 + 真实
## Autoload + 存档还原），但断言对象是面板的[b]输入面[/b]（方向键 / 确认 / 取消、
## 焦点可见），与「点了之后钱货两讫」是两件事——分开两份文件各自离 300 行软上限
## 更远（同 [code]shop_rest_node_fixture.gd[/code] 拆出的理由）。[br]
## [br][b]事件层级[/b]：面板吃的是 [code]_input[/code]（实测焦点在 [Button] 上时
## 引擎的内置焦点导航在 GUI 阶段就吃掉方向键，[code]_unhandled_key_input[/code]
## 收不到）——测试直调 [method Control._input] 复现引擎的同一次派发
## （同 [code]test_node_move_interaction.gd[/code] 直调 [code]_gui_input[/code]
## 的先例）。[br]
##
## 来源: .claude/rules/ui-code.md（所有交互元素必须同时支持键盘/鼠标和手柄输入）、
## GDD exploration-ui-system.md §4c、ADR-0031 §2/§4、本轮「商店面板键盘导航」任务。

## 两件商品的货架（同一张卡、各一件库存——买走第一件即可观察售罄）。
const TWO_ITEM_STOCK: int = 1


## 两件商品的货架载荷。
func _two_item_payload() -> Dictionary:
	return {"inventory": {"items": [
		{"card_id": str(CARD_ID), "rarity": 1, "price": CARD_PRICE,
			"stock": TWO_ITEM_STOCK},
		{"card_id": str(CARD_ID), "rarity": 1, "price": CARD_PRICE,
			"stock": TWO_ITEM_STOCK},
	], "generated_for_rarity": 1}}


## 造一条按键事件（[param p_code] 为主键盘键码）。
func _key(p_code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = p_code
	event.pressed = true
	event.echo = false
	return event


## 打开两件商品的商店（返回面板；已断言上架成功）。
func _open_two_item_shop() -> Variant:
	_set_ling_shi(CARD_PRICE * 2)
	_reach(SHOP_NODE, &"shop", _two_item_payload())
	_confirm()
	var panel: Variant = _panel()
	assert_not_null(panel, "前置：商店面板应已上架")
	assert_eq(int(panel.call(&"item_count")), 2, "前置：货架应有两件商品")
	return panel


# ═══════════════════════════════════════════════════════════════════════════════
# 上下选行 + 焦点可见
# ═══════════════════════════════════════════════════════════════════════════════

func test_shop_panel_reset_focuses_first_buyable_row() -> void:
	# Arrange + Act——上架两件商品
	var panel: Variant = _open_two_item_shop()
	# Assert——游标落在首行，且[b]真的是键盘焦点[/b]（焦点可见的实证）
	assert_eq(int(panel.call(&"focused_index")), 0, "上架后游标应落在首行")
	assert_true(bool(panel.call(&"is_item_focused", 0)),
			"首行应真的持有键盘焦点（焦点环随焦点绘制）")
	assert_false(bool(panel.call(&"is_item_focused", 1)), "未选中的行不应持有焦点")


func test_shop_panel_down_key_moves_cursor_and_focus() -> void:
	# Arrange
	var panel: Variant = _open_two_item_shop()
	# Act——↓
	panel.call(&"_input", _key(KEY_DOWN))
	# Assert——游标与键盘焦点一起搬过去（不出现「游标走了焦点没走」）
	assert_eq(int(panel.call(&"focused_index")), 1, "↓ 应把游标移到第 2 行")
	assert_true(bool(panel.call(&"is_item_focused", 1)), "第 2 行应取得键盘焦点")
	assert_false(bool(panel.call(&"is_item_focused", 0)), "第 1 行应失去键盘焦点")


func test_shop_panel_up_key_returns_to_first_row() -> void:
	# Arrange
	var panel: Variant = _open_two_item_shop()
	panel.call(&"_input", _key(KEY_DOWN))
	# Act——↑
	panel.call(&"_input", _key(KEY_UP))
	# Assert
	assert_eq(int(panel.call(&"focused_index")), 0, "↑ 应把游标移回第 1 行")
	assert_true(bool(panel.call(&"is_item_focused", 0)), "第 1 行应重新取得键盘焦点")


# ═══════════════════════════════════════════════════════════════════════════════
# 确认购买
# ═══════════════════════════════════════════════════════════════════════════════

func test_shop_panel_enter_key_buys_focused_row() -> void:
	# Arrange——两件商品，余额刚好买两件
	var panel: Variant = _open_two_item_shop()
	var cards_before: int = _collection_count()
	# Act——↓ 选第 2 行 → 回车确认
	panel.call(&"_input", _key(KEY_DOWN))
	panel.call(&"_input", _key(KEY_ENTER))
	# Assert——买的是[b]游标那一行[/b]（不是永远的首行）
	assert_eq(_ling_shi(), CARD_PRICE, "确认后应扣掉一件的钱")
	assert_eq(_collection_count(), cards_before + 1, "确认后卡牌应进收藏")
	assert_false(bool(panel.call(&"is_item_enabled", 1)), "被买走的那行应变售罄")
	assert_true(bool(panel.call(&"is_item_enabled", 0)), "未被买的那行应仍可买")


func test_shop_panel_cursor_relocates_after_purchase_removes_row() -> void:
	# Arrange——买走第 1 行（该行随即售罄）
	var panel: Variant = _open_two_item_shop()
	panel.call(&"_input", _key(KEY_ENTER))
	# Assert——重上架把游标复位到「当前首个可买行」，不停在售罄行上
	assert_false(bool(panel.call(&"is_item_enabled", 0)), "前置：第 1 行已售罄")
	assert_eq(int(panel.call(&"focused_index")), 1, "重上架后游标应落到首个可买行")
	assert_true(bool(panel.call(&"is_item_focused", 1)), "第 2 行应取得键盘焦点")


func test_shop_panel_enter_on_sold_out_shelf_buys_nothing() -> void:
	# Arrange——两件商品只买得起一件
	_set_ling_shi(CARD_PRICE + 1)
	_reach(SHOP_NODE, &"shop", _two_item_payload())
	_confirm()
	var panel: Variant = _panel()
	# Act——买走一件（余额随即不足）
	panel.call(&"_input", _key(KEY_ENTER))
	var money_after: int = _ling_shi()
	var cards_after: int = _collection_count()
	# Assert——剩下的行买不起 → 确认被拒且一分钱不动
	assert_false(bool(panel.call(&"is_item_enabled", 1)), "前置：剩余行应标为买不起")
	panel.call(&"_input", _key(KEY_ENTER))
	assert_eq(_ling_shi(), money_after, "买不起时确认不得扣钱")
	assert_eq(_collection_count(), cards_after, "买不起时确认不得发卡")


# ═══════════════════════════════════════════════════════════════════════════════
# 取消关闭
# ═══════════════════════════════════════════════════════════════════════════════

func test_shop_panel_escape_key_closes_panel_and_unfreezes() -> void:
	# Arrange
	var panel: Variant = _open_two_item_shop()
	assert_true(bool(_presenter().call(&"is_node_graph_frozen")), "前置：面板期间已冻结")
	# Act——Esc
	panel.call(&"_input", _key(KEY_ESCAPE))
	# Assert——面板关闭且节点图完全解冻（与点「离开」同一出口）
	assert_false(bool(_presenter().call(&"is_panel_open")), "Esc 应关闭商店面板")
	assert_false(bool(_presenter().call(&"is_node_graph_frozen")), "关闭后应解冻节点图")
	assert_false(bool(_viewport().get(&"input_frozen")), "关闭后应解冻视口")
	assert_true(_interactor().is_processing_unhandled_key_input(), "关闭后键盘走位应恢复")


func test_shop_panel_input_does_not_leak_pause_request() -> void:
	# Arrange——面板已开（InputManager 的 Esc → 暂停菜单必须被拦住）
	var panel: Variant = _open_two_item_shop()
	var pauses: Array = []
	InputManager.pause_requested.connect(func() -> void: pauses.append(1))
	InputManager.clear_locks()
	# Act——Esc 打到面板上
	var esc: InputEventKey = _key(KEY_ESCAPE)
	panel.call(&"_input", esc)
	# Assert——面板消费了事件（不再向下传播到 InputManager 的 Esc 拦截点）
	assert_true(get_viewport().is_input_handled(), "面板应把 Esc 标记为已处理")
	assert_eq(pauses, [], "商店开着时 Esc 不应触发暂停菜单")
