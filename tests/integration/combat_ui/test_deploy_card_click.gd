extends GutTest
## 备战角色卡的点选通路（真机试玩走查修复的回归用例）。[br]
## [br][b]背景[/b]：备战面板的角色卡此前只接了 [code]mouse_entered[/code] /
## [code]mouse_exited[/code]（悬停协同提示），而 [code]mouse_filter = STOP[/code]
## 把左键一并吞掉——玩家在备战阶段点角色卡[b]什么都不发生[/b]，全场唯一能点的
## 只有「确认出战」与「返回探索」。真机试玩走查在 `combat-deploy` 一步上复现：
## 面板列着 6 张卡，没有一张响应点击。[br]
## [br][b]为什么走真实输入[/b]：直调 [code]toggle_selection[/code] 绕过的正是坏掉
## 的那一段（事件能不能从视口走到卡上）。本文件用
## [code]Viewport.push_input[/code] 投递真实左键，断言终点落在面板的选中集合上。[br]
## [br][b]双输入[/b]（.claude/rules/ui-code.md）：同一张卡还要能用键盘确认
## （Tab 走到 + Enter/Space）——纯 [code]Control[/code] 的 [code]ui_accept[/code]
## 引擎不会替它翻译成点击，必须本卡自己处理。[br]
## [br]来源: .claude/rules/ui-code.md、ADR-0004 §双焦点、ADR-0031 §2、
## combat-ui-layout Story 007（备战面板 AC-3 选择态）。

const PanelScript := preload("res://src/ui/combat/deploy/deploy_panel.gd")

## 承载面板的宿主尺寸（与 [code]combat_layout_deploy_mount[/code] 的实测口径同量级
## ——太小会让卡片中心落在视口之外，投递坐标失效）。
const HOST_SIZE: Vector2 = Vector2(1280.0, 720.0)
## 面板在宿主里的偏移（同生产 [code]CombatLayoutDeployMount.OFFSET_*]）。
const OFFSET: Vector2 = Vector2(120.0, 80.0)
## 阵亡角色的 ID（名册 ID 是 [code]200 + slot_index[/code]，故第 4 位是 204）。
const DEAD_ID: int = 204

var panel: Control = null
var _host: Control = null


func before_each() -> void:
	_host = Control.new()
	_host.size = HOST_SIZE
	add_child_autofree(_host)
	panel = PanelScript.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = OFFSET.x
	panel.offset_top = OFFSET.y
	_host.add_child(panel)
	panel.apply_roster(_make_roster([DEAD_ID]), 2, 1)
	# [b]等布局落地再投递[/b]：GridContainer 排子节点是在 [code]NOTIFICATION_SORT_CHILDREN[/code]
	# 里做的，晚于 [code]add_child[/code] 那一帧。不等的话 6 张卡都还叠在原点，
	# 「点第 0 张卡」的坐标会落到[b]最后一张[/b]身上（实测选中 205 而不是 200）。
	await get_tree().process_frame
	await get_tree().process_frame


## 测试名册（6 人，其中 104 阵亡——不依赖真实系统，面板只消费快照）。
func _make_roster(dead_ids: Array) -> Array:
	var roster: Array = []
	for i: int in range(6):
		var cid: int = 200 + i
		roster.append({
			"character_id": cid,
			"display_name": "角色%d" % i,
			"hp": 10,
			"attack": 3,
			"binding_count": 0,
			"faction_tags": [],
			"is_dead": dead_ids.has(cid),
			"slot_index": i,
		})
	return roster


## 名册第 [param p_index] 张卡的控件（不存在返回 null）。
func _card(p_index: int) -> Control:
	var cards: Array = panel.get_cards()
	return cards[p_index] as Control if p_index < cards.size() else null


# ═══════════════════════════════════════════════════════════════════════════════
# 鼠标：真实左键投递
# ═══════════════════════════════════════════════════════════════════════════════

## 点第 0 张卡 → 该角色进入出战名单（这条在修复前恒红：卡把左键吞掉了）。
func test_click_on_card_selects_character() -> void:
	# Arrange
	assert_eq(panel.get_selected_ids().size(), 0, "前置：尚未选择任何角色")
	# Act
	_click(_card(0))
	# Assert
	assert_eq(panel.get_selected_ids(), [200], "点卡应把该角色选入出战名单")


## 再点一次同一张卡 → 取消选择（选中是瞬态开关，不是单向累积）。
func test_click_same_card_again_deselects() -> void:
	# Arrange
	_click(_card(0))
	assert_eq(panel.get_selected_ids(), [200], "前置：第一次点击已选中")
	# Act
	_click(_card(0))
	# Assert
	assert_eq(panel.get_selected_ids(), [], "再点一次应取消选择")


## 点不同的卡 → 两张都在名单里（上限 2 允许）。
func test_click_second_card_adds_to_selection() -> void:
	# Act
	_click(_card(0))
	_click(_card(1))
	# Assert
	assert_eq(panel.get_selected_ids(), [200, 201], "两张卡都应入选")


## 阵亡角色的卡：点得动（事件送到），但面板拒绝入选。[br]
## [br][b]为什么不断言「命中 null」[/b]：卡自己的 [code]mouse_filter = STOP[/code]
## 意味着它[b]收得到[/b]事件——拒绝的判据只能是「名单没变」，
## 与 [code]DeployPanelRules[/code] 的不可用态口径一致。
func test_click_dead_card_does_not_select() -> void:
	# Arrange
	var dead: Control = _card(4)
	assert_eq(panel.get_selection_state(204), "unavailable", "前置：204 应为不可用态")
	# Act
	_click(dead)
	# Assert
	assert_eq(panel.get_selected_ids(), [], "阵亡角色不得入选")


## 点卡之后确认按钮解除置灰——「点卡 → 点确认」这条真实路径能走通。
func test_click_card_enables_confirm_button() -> void:
	# Arrange
	assert_true(panel.confirm_button.disabled, "前置：未选人时确认按钮置灰")
	# Act
	_click(_card(0))
	_click(_card(1))
	# Assert
	assert_false(panel.confirm_button.disabled, "选满 2 人后确认按钮应可用")


# ═══════════════════════════════════════════════════════════════════════════════
# 键盘：焦点 + 确认键
# ═══════════════════════════════════════════════════════════════════════════════

## 卡片可聚焦（Tab 走得到）——纯 Control 默认 FOCUS_NONE，必须显式开启。
func test_cards_are_focusable() -> void:
	for i: int in range(6):
		var card: Control = _card(i)
		assert_eq(card.focus_mode, Control.FOCUS_ALL,
				"第 %d 张卡应可被键盘聚焦" % i)


## 焦点在某张卡上按回车 → 选中（引擎不会替纯 Control 翻译 ui_accept）。
func test_enter_on_focused_card_selects() -> void:
	# Arrange
	var card: Control = _card(1)
	card.grab_focus()
	assert_true(card.has_focus(), "前置：焦点在第 2 张卡上")
	# Act
	_press_enter()
	# Assert
	assert_eq(panel.get_selected_ids(), [201], "回车应选中焦点所在的那张卡")


## 焦点不在任何卡上时按回车，不误选（不在树内的焦点不做兜底猜测）。
func test_enter_without_focus_selects_nothing() -> void:
	# Act
	_press_enter()
	# Assert
	assert_eq(panel.get_selected_ids(), [], "没有焦点时回车不应选中任何人")


# ═══════════════════════════════════════════════════════════════════════════════
# 装置：真实输入投递
# ═══════════════════════════════════════════════════════════════════════════════

## 在控件中心投递一对真实左键事件（按下 + 抬起）。[br]
## [br][b]第二参必须为 true[/b]（[code]in_local_coords[/code]）：默认口径会把坐标
## 当屏幕坐标再乘一次拉伸逆变换，[code]canvas_items[/code] 下整体偏移
## （[code]real_input_click_driver.gd[/code] 头注释记的那个坑）。
func _click(p_control: Control) -> void:
	if p_control == null:
		assert_not_null(p_control, "目标控件不存在——前置失败")
		return
	var point: Vector2 = p_control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		get_viewport().push_input(event, true)


## 投递一对真实回车事件。
func _press_enter() -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.physical_keycode = KEY_ENTER
		event.pressed = pressed
		get_viewport().push_input(event, true)
