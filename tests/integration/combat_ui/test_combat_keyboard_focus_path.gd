extends "res://tests/integration/combat_ui/full_battle_fixture.gd"
## 战斗界面键盘/手柄焦点路径的真实用例（.claude/rules/ui-code.md 双输入）。[br]
## [br][b]背景[/b]：战斗底栏（结束出牌 / 行囊 / 撤退）此前只有鼠标可用——[code]Button[/code]
## 没进焦点链、没有 [code]focus_neighbor[/code]、也没有默认焦点，玩家用键盘进战斗后
## 完全没法出牌或结束回合。[br]
## [br][b]走真实场景与真实事件[/b]：场景是 [code]combat_scene.tscn[/code]，按键经
## [code]Viewport.push_input[/code] 投递（引擎每帧对真实事件做的事），不是直调
## [code]grab_focus[/code] 之后自说自话——否则「Tab 到底能不能走通」这条根本没被测到。[br]
## [br][b]不改既有鼠标用例[/b]：本文件只新增；[code]test_bottombar_and_retreat_real_input.gd[/code]
## 的 9 例必须仍绿（焦点链不夺鼠标路径）。

## 真实输入驱动（[code]Viewport.push_input[/code]——引擎每帧对真实事件做的事）。
const RealInputDriverScript := preload(
		"res://tests/integration/combat_ui/real_input_click_driver.gd")

## 阶段号（与 [code]CombatPhase[/code] 同源）。
const PHASE_PLAY: int = 2
const PHASE_ENEMY: int = 5

## 真实鼠标驱动（鼠标路径不被焦点链影响的用例用它）。
var driver: RefCounted = null


func before_all() -> void:
	for _i: int in range(300):
		if CardSystem.get_template(&"basic_attack") != null \
				and CardSystem.get_template(&"lin_yuan") != null:
			break
		await get_tree().process_frame
	AISystem.load_templates()


func before_each() -> void:
	setup(false)
	confirm_deploy()
	assert_true(drive_to_play(), "前置：应能推进到出牌阶段")
	driver = RealInputDriverScript.new()
	driver.call(&"setup", Callable(self, "_root"))


func after_each() -> void:
	driver = null
	await teardown()


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 出牌阶段的默认焦点
# ═══════════════════════════════════════════════════════════════════════════════

## 出牌阶段默认焦点非空，且落在一张可见可点的手牌上。[br]
## [br][b]为什么断言是手牌而不是「随便哪个控件」[/b]：GDD 的一个回合就是出牌阶段，
## 玩家进来要做的第一件事是出牌——焦点落手牌意味着「进战斗就能按回车出牌」。
func test_play_phase_default_focus_is_first_hand_card() -> void:
	# Act
	var cards: Array = _hand_cards()
	# Assert
	assert_gt(cards.size(), 0, "前置：出牌阶段手牌非空")
	var owner: Control = get_viewport().gui_get_focus_owner()
	assert_not_null(owner, "出牌阶段应已有默认焦点（此前为空——键盘玩家按哪都没反应）")
	assert_eq(owner, cards[0], "默认焦点应落第一张手牌")
	assert_true(owner.is_visible_in_tree(), "默认焦点控件应可见")
	assert_eq(owner.focus_mode, Control.FOCUS_ALL, "默认焦点控件应可再次被聚焦")


## 手牌打空后默认焦点退到底栏按钮（兜底——此时玩家唯一能做的是结束回合）。[br]
## [br][b]为什么这条要有[/b]：默认焦点只认手牌的话，手牌空的那一刻焦点链就没有落点了。
func test_default_focus_falls_back_when_hand_empty() -> void:
	# Arrange——把手牌清空（模拟全打完），再重建焦点链
	cs.call("set_hand", [])
	_root().call("interaction").call("hand_snapshot")
	var hand: Variant = _root().get("hand_area")
	hand.call("apply_hand", [])
	assert_eq(hand.call("card_nodes").size(), 0, "前置：手牌区应已无卡节点")
	get_viewport().gui_release_focus()
	# Act
	_chain().call("rebuild")
	# Assert
	var owner: Control = get_viewport().gui_get_focus_owner()
	assert_not_null(owner, "手牌为空时默认焦点应退到底栏按钮")
	assert_eq(owner, _bag_button(), "兜底焦点应是行囊按钮（底栏首个动作）")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. Tab 依次经过底栏三个按钮
# ═══════════════════════════════════════════════════════════════════════════════

## Tab 从末张手牌出发，依次经过「行囊 → 结束出牌 → 撤退」，顺序稳定。[br]
## [br][b]为什么按这个顺序[/b]：链序是「手牌 → 行囊 → 结束出牌 → 撤退」——
## 底栏从左到右（行囊在左、结束出牌靠右）、撤退在右上角殿后。
func test_tab_visits_three_bottom_buttons_in_order() -> void:
	# Arrange——焦点落在末张手牌（Tab 的下一站就是底栏首个动作）
	var cards: Array = _hand_cards()
	var last: Control = cards[cards.size() - 1]
	last.grab_focus()
	assert_eq(get_viewport().gui_get_focus_owner(), last, "前置：焦点在末张手牌")
	# Act + Assert——三站依次到位
	var stops: Array = []
	_push_key(KEY_TAB)
	stops.append(get_viewport().gui_get_focus_owner())
	_push_key(KEY_TAB)
	stops.append(get_viewport().gui_get_focus_owner())
	_push_key(KEY_TAB)
	stops.append(get_viewport().gui_get_focus_owner())
	assert_eq(stops, [_bag_button(), _end_turn_button(), _retreat_button()],
			"Tab 应依次经过行囊 → 结束出牌 → 撤退")


## 链序本身稳定（不随手牌重建漂移——玩家的肌肉记忆据此）。[br]
## [br][b]与上一条分工[/b]：上一条验「按键真的走通」，这一条验「链的构成」。
func test_focus_order_is_stable_across_rebuilds() -> void:
	# Arrange
	var before: Array = _chain().call("focus_order")
	# Act——手牌重建后链要跟着重建（卡节点换了一批）
	_chain().call("rebuild")
	var after: Array = _chain().call("focus_order")
	# Assert
	assert_eq(before, after, "重建前后链序应一致")
	assert_eq(before.slice(before.size() - 3, before.size()),
			["BagButton", "EndTurnButton", "RetreatButton"],
			"链尾三位应是底栏三按钮且顺序固定")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 方向键：手牌 → 行囊
# ═══════════════════════════════════════════════════════════════════════════════

## 末张手牌按「下」应走到行囊按钮（手牌区 → 底栏的竖向通道）。[br]
## [br][b]为什么是末张而不是首张[/b]：行囊在底栏最左、手牌弧线最右是末张，
## 但从手牌区「往下」在玩家心里就是「去底部条」——两张都接向行囊。
func test_down_from_last_hand_card_reaches_bag_button() -> void:
	# Arrange
	var cards: Array = _hand_cards()
	var last: Control = cards[cards.size() - 1]
	last.grab_focus()
	# Act
	_push_key(KEY_DOWN)
	# Assert
	assert_eq(get_viewport().gui_get_focus_owner(), _bag_button(),
			"末张手牌按下应走到行囊按钮")


## 行囊按钮按「上」应回到末张手牌（竖向通道是双向的，不是单行道）。
func test_up_from_bag_button_returns_to_last_hand_card() -> void:
	# Arrange
	var cards: Array = _hand_cards()
	var last: Control = cards[cards.size() - 1]
	_bag_button().grab_focus()
	# Act
	_push_key(KEY_UP)
	# Assert
	assert_eq(get_viewport().gui_get_focus_owner(), last,
			"行囊按上应回到末张手牌")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 敌方回合按回车不出牌
# ═══════════════════════════════════════════════════════════════════════════════

## 敌方行动阶段（5）焦点链整条退出，玩家连可聚焦的手牌都没有。[br]
## [br][b]这是「按回车不会出牌」的第一道保障[/b]：焦点不在卡上，按键根本到不了卡。
func test_enemy_turn_takes_focus_chain_offline() -> void:
	# Arrange——出牌阶段先确认手牌是可聚焦的
	assert_eq(_hand_cards()[0].focus_mode, Control.FOCUS_ALL, "前置：出牌阶段手牌可聚焦")
	# Act
	assert_true(_advance_to(PHASE_ENEMY), "前置：应能推进到敌方行动阶段（5）")
	# Assert——[b]重新取节点[/b]：每次刷新手牌会换一批卡节点（快照条目不带 node），
	# 停在阶段切换前抓到的那份引用上验的是已退场的旧节点。
	var cards: Array = _hand_cards()
	assert_gt(cards.size(), 0, "前置：敌方行动阶段手牌仍在手里")
	for card: Control in cards:
		assert_eq(card.focus_mode, Control.FOCUS_NONE,
				"敌方行动阶段手牌应退出焦点（否则玩家能把焦点走到点不动的卡上）")
	assert_eq(_bag_button().focus_mode, Control.FOCUS_NONE,
			"敌方行动阶段行囊应退出焦点")
	assert_eq(_end_turn_button().focus_mode, Control.FOCUS_NONE,
			"敌方行动阶段结束出牌应退出焦点")
	assert_true(_retreat_button().focus_mode == Control.FOCUS_ALL,
			"撤退应仍可聚焦（GDD §10：撤退按钮始终在战斗中可点击）")


## 敌方回合里就算把一次「卡被确认」送到接线层，也不会真的出牌。[br]
## [br][b]为什么这条必须有[/b]：焦点退出是表现层的一道闸，第二道闸在接线层——
## 两道任一失效都会让玩家在敌方回合出牌，直接改变战斗结果。[br]
## [br][b]触发方式[/b]：发 [signal HandCard.activated]（卡的
## [code]_gui_input[/code] 收到回车时做的正是这一件事）。
func test_card_activation_during_enemy_turn_plays_nothing() -> void:
	# Arrange
	var card: Control = _hand_cards()[0]
	var hand_before: int = int(cs.call("get_hand").size())
	var cost_before: int = CostSystem.get_current_cost()
	assert_true(_advance_to(PHASE_ENEMY), "前置：应能推进到敌方行动阶段（5）")
	# Act——把「这张卡被确认了」直接送到接线层
	card.emit_signal(&"activated", card.get("card_instance_id"))
	# Assert
	assert_eq(int(cs.call("get_hand").size()), hand_before, "敌方回合不应打出任何卡")
	assert_eq(CostSystem.get_current_cost(), cost_before, "敌方回合不应扣灵力")


## 敌方回合投递真实回车键：焦点不在卡上，什么都不会发生。
func test_enter_key_during_enemy_turn_does_nothing() -> void:
	# Arrange
	var hand_before: int = int(cs.call("get_hand").size())
	assert_true(_advance_to(PHASE_ENEMY), "前置：应能推进到敌方行动阶段（5）")
	# Act
	_push_key(KEY_ENTER)
	_push_key(KEY_SPACE)
	# Assert
	assert_eq(int(cs.call("get_hand").size()), hand_before, "敌方回合按回车/空格不出牌")


# ═══════════════════════════════════════════════════════════════════════════════
# 5. 焦点在禁用按钮上不再前移
# ═══════════════════════════════════════════════════════════════════════════════

## 焦点落到被禁用的按钮上时，Tab 不再把它带向下一站。[br]
## [br][b]为什么必须自己保证[/b]：实测引擎对 [code]disabled[/code] 的 [code]Button[/code]
## [b]不做跳过[/b]——[method Control.find_next_valid_focus] 照样选中它；
## 不把四个方向与 Tab 前后自指，焦点就会从禁用按钮跳到链外的控件（战斗日志折叠按钮）。
func test_tab_does_not_advance_from_disabled_button() -> void:
	# Arrange——禁用行囊按钮后重建链（链按当前禁用态重设邻居）
	var bag: Button = _bag_button()
	bag.disabled = true
	_chain().call("rebuild")
	bag.grab_focus()
	assert_eq(get_viewport().gui_get_focus_owner(), bag, "前置：焦点应能落在禁用按钮上")
	# Act
	_push_key(KEY_TAB)
	# Assert
	assert_eq(get_viewport().gui_get_focus_owner(), bag,
			"禁用按钮上的 Tab 不应继续前移")
	_push_key(KEY_DOWN)
	assert_eq(get_viewport().gui_get_focus_owner(), bag,
			"禁用按钮上的方向键同样不应前移")


# ═══════════════════════════════════════════════════════════════════════════════
# 6. 键盘路径不影响鼠标路径
# ═══════════════════════════════════════════════════════════════════════════════

## 焦点链开着的时候，鼠标点「结束出牌」照样推进阶段。[br]
## [br][b]为什么新增这条而不是只跑既有文件[/b]：既有鼠标用例跑的是「没有焦点时」
## 的路径；本用例把「焦点正握在别处」这个状态也覆盖上——焦点链一旦抢事件，
## 症状就是鼠标点不动。
func test_mouse_click_still_works_while_focus_chain_active() -> void:
	# Arrange
	_hand_cards()[0].grab_focus()
	assert_eq(int(cs.call("get_current_phase")), PHASE_PLAY, "前置：出牌阶段")
	# Act——真实鼠标点击
	driver.call(&"click", driver.call(&"end_turn_button_pos"))
	# Assert
	assert_eq(int(cs.call("get_current_phase")), 3,
			"焦点在别处时鼠标点「结束出牌」仍应推进阶段——诊断：%s"
			% driver.call(&"diagnose"))


## 焦点停在手牌上时按回车 = 选中该卡（与鼠标点一下同一形状）。[br]
## [br][b]为什么复用 [code]click_card[/code] 语义[/b]：第一次选中、同一张再按一次
## 确认——不新造一套键盘专属的出牌语义。
func test_enter_on_focused_card_selects_it() -> void:
	# Arrange
	var card: Control = _hand_cards()[0]
	var card_id: int = int(card.get("card_instance_id"))
	card.grab_focus()
	var layout: Variant = _root()
	var controller: Variant = layout.call("interaction").call("play_controller")
	assert_eq(int(controller.call("get_selected_card_id")), -1, "前置：未选中任何卡")
	# Act
	_push_key(KEY_ENTER)
	# Assert
	assert_eq(int(controller.call("get_selected_card_id")), card_id,
			"回车应选中焦点所在的那张卡（与鼠标点一下同义）")


# ═══════════════════════════════════════════════════════════════════════════════
# 工具
# ═══════════════════════════════════════════════════════════════════════════════

## 投递一条真实按键（按下 + 抬起成对——引擎对合成事件同样做 UI 动作派发）。
func _push_key(p_code: Key) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var down := InputEventKey.new()
	down.keycode = p_code
	down.physical_keycode = p_code
	down.pressed = true
	tree.root.push_input(down, true)
	var up := InputEventKey.new()
	up.keycode = p_code
	up.physical_keycode = p_code
	up.pressed = false
	tree.root.push_input(up, true)


## 焦点链实例（场景接线持有——测试据此断言链的构成与重建）。
func _chain() -> Variant:
	var wiring: Variant = scene.get("interaction_wiring")
	assert_not_null(wiring, "前置：场景应持有出牌交互接线")
	var chain: Variant = wiring.get("focus_chain")
	assert_not_null(chain, "前置：交互接线应已建焦点链")
	return chain


func _hand_cards() -> Array:
	var hand: Variant = _root().get("hand_area")
	return hand.call("card_nodes") as Array


func _bag_button() -> Button:
	return _bar().get("bag_button").get("button") as Button


func _end_turn_button() -> Button:
	return _bar().get("end_turn_button").get("button") as Button


func _retreat_button() -> Button:
	return _root().get("retreat_button") as Button


func _bar() -> Variant:
	return _root().get("combat_bottombar")


## 推进到指定阶段（走生产路径的阶段推进；战斗中途结束则返回 false）。
func _advance_to(p_phase: int) -> bool:
	for _i: int in range(16):
		if int(cs.call("get_current_phase")) == p_phase:
			return true
		if not bool(cs.call("is_battle_active")):
			return false
		if int(cs.call("get_current_phase")) == PHASE_PLAY:
			press_end_turn_button()
			continue
		if int(cs.call("get_current_phase")) == 3:
			cs.call("confirm_attack_targets")
			continue
		_advance_with_confirm()
	return int(cs.call("get_current_phase")) == p_phase
