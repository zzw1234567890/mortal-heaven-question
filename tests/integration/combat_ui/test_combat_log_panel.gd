extends "res://tests/integration/combat_ui/full_battle_fixture.gd"
## 战斗日志面板的真实用例（开合入口 + 内容 + 焦点 + 不遮操作）。[br]
## [br][b]背景[/b]：顶部条的日志折叠按钮（[code]CombatTopBar/CombatLog/CollapseLabel[/code]）
## 的 [code]pressed[/code] 信号**全库无人接线**——点下去什么都不会发生；上一轮因此把它的
## [code]focus_mode[/code] 收成 [code]FOCUS_NONE[/code]（Tab 不再跳过去，但键盘也开不了）。[br]
## [br][b]本文件锁定八条语义[/b]：[br]
##   1. 点一下展开、再点一下收起（鼠标真实事件投递）；[br]
##   2. 键盘在按钮上按回车同样能开合（双输入）；[br]
##   3. 面板里能看到本场已经发生的战报（复用播报组件的文本，不新造第二套）；[br]
##   4. 没有战报时显示空态文案，不报错；[br]
##   5. 战报随时间增长（第二批敌方行动后条目数增加）；[br]
##   6. 展开后焦点仍在折叠按钮，且 Tab 能进面板再出来；[br]
##   7. 展开面板不是全屏遮罩（宽度受限，右侧战场仍可点）；[br]
##   8. 阶段推进到出牌阶段时自动收起（AC-2）且按钮文案复位。[br]
## [br][b]真实场景真实事件[/b]：走 [code]combat_scene.tscn[/code] +
## [code]Viewport.push_input[/code] 投递的鼠标 / 键盘事件——直调
## [code]button.pressed.emit()[/code] 会绕开「事件能不能走到按钮」这一环，
## 而本轮修的恰恰是那一环。

## 真实输入驱动（[code]Viewport.push_input[/code]——引擎每帧对真实事件做的事）。
const RealInputDriverScript := preload(
		"res://tests/integration/combat_ui/real_input_click_driver.gd")

## 阶段号（与 [code]CombatPhase[/code] 同源）。
const PHASE_PLAY: int = 2
const PHASE_ENEMY: int = 5

## 空态文案（与 [code]CombatLog.EMPTY_TEXT[/code] 同源——从组件读，不另写一份）。
const LogScript := preload("res://src/ui/combat/layout/combat_log.gd")

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
# 1. 开合入口（鼠标 + 键盘两条路）
# ═══════════════════════════════════════════════════════════════════════════════

## 真实鼠标点一下折叠按钮 → 面板可见；再点一下 → 收起。[br]
## [br][b]为什么这条是核心[/b]：该按钮的 [code]pressed[/code] 此前全库无人接线，
## 「点一下有反应」正是本轮要建立的事实。
func test_mouse_click_toggles_log_panel() -> void:
	# Arrange
	var log: Variant = _log()
	var button: Control = _collapse_button()
	assert_false(bool(log.call("is_expanded")), "前置：日志默认折叠")
	assert_true(button.is_visible_in_tree(), "前置：折叠按钮应可见")
	# Act——第一次点击
	driver.call(&"click_control", button)
	# Assert——展开
	assert_true(bool(log.call("is_expanded")), "点一下应展开日志面板——诊断：%s"
			% driver.call(&"diagnose"))
	assert_true((log.get("expand_panel") as Control).visible, "展开面板应可见")
	# Act——第二次点击
	driver.call(&"click_control", button)
	# Assert——收起
	assert_false(bool(log.call("is_expanded")), "再点一下应收起日志面板")
	assert_false((log.get("expand_panel") as Control).visible, "收起后展开面板应隐藏")


## 按钮文案随状态变化（折叠态「战斗日志」↔ 展开态「收起日志」）。[br]
## [br][b]为什么用文字而不是图标[/b]：图标含义要玩家猜；文案直接写清「再按一次会收起来」。
func test_button_label_follows_panel_state() -> void:
	# Arrange
	var button: Button = _collapse_button()
	assert_eq(button.text, LogScript.LABEL_TEXT, "前置：折叠态文案")
	# Act
	driver.call(&"click_control", button)
	# Assert
	assert_eq(button.text, LogScript.LABEL_TEXT_EXPANDED, "展开后应写「收起日志」")
	# Act
	driver.call(&"click_control", button)
	# Assert
	assert_eq(button.text, LogScript.LABEL_TEXT, "收起后应写回「战斗日志」")


## 键盘在按钮上按回车同样能开合（手柄 A 走的是同一条 [code]ui_accept[/code]）。[br]
## [br][b]为什么必须有这条[/b]：[code].claude/rules/ui-code.md[/code] 要求所有交互元素
## 同时支持键盘 / 鼠标与手柄——只接鼠标等于把键盘玩家挡在日志外。
func test_keyboard_accept_toggles_log_panel() -> void:
	# Arrange
	var log: Variant = _log()
	var button: Control = _collapse_button()
	button.grab_focus()
	assert_eq(get_viewport().gui_get_focus_owner(), button, "前置：焦点在折叠按钮上")
	# Act
	_push_key(KEY_ENTER)
	# Assert
	assert_true(bool(log.call("is_expanded")), "回车应展开日志面板")
	# Act
	_push_key(KEY_SPACE)
	# Assert
	assert_false(bool(log.call("is_expanded")), "空格应收起日志面板")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 面板内容：本场战报 + 空态
# ═══════════════════════════════════════════════════════════════════════════════

## 打完一个回合（敌方行动已结算）再展开 → 面板里有本场的战报条目。[br]
## [br][b]数据来源[/b]：[code]enemy_action_resolved[/code] →
## [code]EnemyActionBroadcast[/code] → [code]CombatLog.append_entry[/code]
## （生产接线在 [code]CombatLayout.setup_feedback[/code]）——本用例验的正是这条链
## 在真实场景里通着，而不是「面板能不能显示手灌进去的假文本」。
func test_panel_shows_entries_from_this_battle() -> void:
	# Arrange——跑一个完整回合（结束出牌 → 敌方行动结算）
	finish_turn()
	await _wait_seconds(0.6)
	# Act
	driver.call(&"click_control", _collapse_button())
	# Assert
	var entries: Array = _log().call("get_entries")
	assert_gt(entries.size(), 0, "面板里应有本场战斗的战报条目（实际 0 条——"
			+ "日志接线断了或是本回合没有敌方行动）")
	assert_false(str(entries[0]).strip_edges().is_empty(), "条目文本不该是空串")
	assert_true(not _log_text().contains(LogScript.EMPTY_TEXT),
			"有条目时不该再显示空态文案")


## 本场还没有任何战报时展开 → 显示空态文案，不报错、不留空白面板。[br]
## [br][b]为什么这条要有[/b]：开局立刻点开日志就是这个状态；一片空白会让玩家
## 以为界面坏了（与「点了没反应」同类的失败形态）。
func test_empty_panel_shows_placeholder_text() -> void:
	# Arrange——出牌阶段刚进，敌方行动尚未发生
	assert_eq(int(cs.call("get_current_phase")), PHASE_PLAY, "前置：出牌阶段")
	assert_eq((_log().call("get_entries") as Array).size(), 0, "前置：还没有战报")
	# Act
	driver.call(&"click_control", _collapse_button())
	# Assert
	assert_true(bool(_log().call("is_expanded")), "面板应已展开")
	assert_true(_log_text().contains(LogScript.EMPTY_TEXT),
			"没有战报时应显示空态文案（实际正文：「%s」）" % _log_text())


## 战报随时间增长：第二个回合的敌方行动让条目数增加。[br]
## [br][b]为什么不在同一批里数[/b]：播报批内去重（相同载荷只播一次）——
## 同一批里数条数会被去重掩盖「新行动没进日志」。
func test_entries_grow_after_second_enemy_batch() -> void:
	# Arrange——第一个回合
	finish_turn()
	await _wait_seconds(0.6)
	var first: int = (_log().call("get_entries") as Array).size()
	assert_gt(first, 0, "前置：第一个回合应已产生战报")
	# Act——第二个回合的敌方行动
	finish_turn()
	await _wait_seconds(0.6)
	# Assert
	var after: int = (_log().call("get_entries") as Array).size()
	assert_gt(after, first, "第二个回合后条目数应增加（%d → %d）" % [first, after])


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 焦点：开合不夺焦点、面板进得去也出得来
# ═══════════════════════════════════════════════════════════════════════════════

## 展开后焦点仍留在折叠按钮上（开合不抢焦点）。[br]
## [br][b]为什么这条重要[/b]：面板展开若把焦点抛给别处，键盘玩家下一次按回车
## 会落在意料之外的地方；开关一次丢一次位置正是上一轮修掉的老毛病。
func test_focus_stays_on_collapse_button_after_toggle() -> void:
	# Arrange
	var button: Control = _collapse_button()
	button.grab_focus()
	# Act
	_push_key(KEY_ENTER)
	# Assert
	assert_true(bool(_log().call("is_expanded")), "前置：已展开")
	assert_eq(get_viewport().gui_get_focus_owner(), button,
			"展开后焦点应仍在折叠按钮上")


## 展开后 Tab 能进入面板（滚动区），再 Tab 回到链上（进得去也出得来）。[br]
## [br][b]为什么面板里要有个聚焦站[/b]：日志比一屏长时键盘玩家得能翻看——
## 面板里没有可聚焦元素的话，展开等于只有鼠标能用。[br]
## [br][b]环序[/b]：折叠按钮 → 面板滚动区 → 手牌… → 底栏三按钮 → 回到折叠按钮
## （日志入口是环首，见 [code]CombatFocusRing.ring_order[/code]）。
func test_tab_enters_panel_and_leaves() -> void:
	# Arrange——展开并把焦点放回折叠按钮（环首）
	var button: Control = _collapse_button()
	driver.call(&"click_control", button)
	button.grab_focus()
	var scroll: Control = _log().get("scroll") as Control
	assert_true(scroll.is_visible_in_tree(), "前置：面板滚动区应可见")
	# Act——Tab 进面板
	_push_key(KEY_TAB)
	# Assert——焦点落在面板里
	assert_eq(get_viewport().gui_get_focus_owner(), scroll,
			"Tab 应从折叠按钮进入面板滚动区")
	# Act——再 Tab 出来（回到环上的第一张手牌）
	_push_key(KEY_TAB)
	# Assert
	var owner: Control = get_viewport().gui_get_focus_owner()
	assert_ne(owner, scroll, "再按一次 Tab 应离开面板")
	assert_true(_hand_cards().has(owner), "离开面板后应回到链上的手牌")
	# Act——反向 Tab（Shift+Tab）从手牌退回面板，再退回收折叠按钮
	_push_key(KEY_TAB, true)
	assert_eq(get_viewport().gui_get_focus_owner(), scroll,
			"反向 Tab 应从手牌回到面板滚动区（面板与链双向可达）")
	_push_key(KEY_TAB, true)
	# Assert
	assert_eq(get_viewport().gui_get_focus_owner(), button,
			"再反向 Tab 应回到折叠按钮（环闭合）")


## 收起面板时焦点若在面板里，应被拉回折叠按钮（不留悬空焦点）。[br]
## [br][b]为什么这条要有[/b]：阶段 2 会自动收起（AC-2），而键盘玩家此时可能正
## 停在面板的滚动区上——控件一隐藏，焦点就悬在一个看不见的地方。
func test_collapsing_panel_pulls_focus_back_to_button() -> void:
	# Arrange——展开并把焦点放进面板
	var button: Control = _collapse_button()
	driver.call(&"click_control", button)
	var scroll: Control = _log().get("scroll") as Control
	scroll.grab_focus()
	assert_eq(get_viewport().gui_get_focus_owner(), scroll, "前置：焦点在面板里")
	# Act——按回车收起（焦点在滚动区上，不在按钮上，故用组件入口）
	_log().call("collapse")
	# Assert
	assert_false(bool(_log().call("is_expanded")), "面板应已收起")
	assert_eq(get_viewport().gui_get_focus_owner(), button,
			"收起后焦点应回到折叠按钮（而不是悬在隐藏的滚动区上）")


## 折叠按钮可聚焦且在焦点链上（不再被收拢器收掉）。[br]
## [br][b]本轮语义变更[/b]：上一轮它是「链外唯一漏网者」被收成
## [code]FOCUS_NONE[/code]；本轮它接上了开合并进链，收拢器也不该再动它。
func test_collapse_button_is_focusable_and_on_chain() -> void:
	# Arrange
	var button: Control = _collapse_button()
	# Act / Assert
	assert_eq(button.focus_mode, Control.FOCUS_ALL,
			"折叠按钮应可聚焦（它是日志入口，键盘玩家唯一的门）")
	assert_true(_chain().call("focus_order").has(button.name),
			"折叠按钮应在焦点链上（链序：%s）"
			% str(_chain().call("focus_order")))
	assert_false(_chain().call("outside_focusables").has(button),
			"已在链上的控件不该同时出现在链外清单里")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 面板不遮操作 + 阶段自动收起
# ═══════════════════════════════════════════════════════════════════════════════

## 展开面板不是全屏遮罩：宽度受限、右侧战场的「结束出牌」仍可点。[br]
## [br][b]为什么这条必须有[/b]：面板铺满屏宽就成了盖住一切的遮罩——玩家展开日志后
## 连出牌都做不了；GDD 只要求「覆盖在手牌区上方」，不是全屏。
func test_expanded_panel_does_not_block_play_actions() -> void:
	# Arrange
	driver.call(&"click_control", _collapse_button())
	assert_true(bool(_log().call("is_expanded")), "前置：面板已展开")
	var panel: Control = _log().get("expand_panel") as Control
	var viewport_w: float = get_viewport().get_visible_rect().size.x
	# Assert——宽度受限（不是全屏遮罩）
	assert_lt(panel.size.x, viewport_w,
			"展开面板宽度应小于屏宽（实际 %.0f / 屏宽 %.0f）" % [panel.size.x, viewport_w])
	# Act——面板开着点「结束出牌」（底栏靠右，不在面板覆盖范围内）
	assert_eq(int(cs.call("get_current_phase")), PHASE_PLAY, "前置：出牌阶段")
	driver.call(&"click", driver.call(&"end_turn_button_pos"))
	# Assert——阶段真的推进了（面板没吃掉这一点）
	assert_eq(int(cs.call("get_current_phase")), 3,
			"日志面板展开时点「结束出牌」仍应推进阶段——诊断：%s"
			% driver.call(&"diagnose"))


## 回到出牌阶段（2）时日志自动收起，且按钮文案复位（AC-2）。[br]
## [br][b]AC 的原话是「阶段 2 进入时自动收起[/b]」——只收阶段 2，不收别的阶段：
## 敌方行动期间玩家正该读战报，那时把面板收掉等于把信息从眼前夺走。[br]
## [br][b]为什么在真实场景里再验一遍[/b]：[code]apply_phase(2)[/code] 的单元用例
## 直调组件；这一条验的是「阶段信号经顶部条路由到日志」这条生产接线还在。
func test_entering_play_phase_autocollapses_and_resets_label() -> void:
	# Arrange——展开日志，再推进到敌方行动阶段
	var log: Variant = _log()
	driver.call(&"click_control", _collapse_button())
	assert_true(bool(log.call("is_expanded")), "前置：日志已展开")
	assert_true(_advance_to(PHASE_ENEMY), "前置：应能推进到敌方行动阶段（5）")
	# Assert——敌方回合不收（那时正该读战报）
	assert_true(bool(log.call("is_expanded")), "敌方行动阶段不该收掉日志（那是读战报的时机）")
	# Act——回到出牌阶段
	assert_true(_advance_to(PHASE_PLAY), "前置：应能回到出牌阶段（2）")
	# Assert
	assert_false(bool(log.call("is_expanded")), "进入出牌阶段时日志应自动收起（AC-2）")
	assert_eq(_collapse_button().text, LogScript.LABEL_TEXT,
			"收起后按钮文案应复位为「战斗日志」")


# ═══════════════════════════════════════════════════════════════════════════════
# 工具
# ═══════════════════════════════════════════════════════════════════════════════

## 投递一条真实按键（按下 + 抬起成对——引擎对合成事件同样做 UI 动作派发）。[br]
## [param p_shift] 为真时带 Shift（Tab 反向）。
func _push_key(p_code: Key, p_shift: bool = false) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = p_code
		event.physical_keycode = p_code
		event.pressed = pressed
		event.shift_pressed = p_shift
		tree.root.push_input(event, true)


## 等待若干秒（真实计时器路径——播报条间隔 350ms，等待须长于它）。
func _wait_seconds(p_seconds: float) -> void:
	await get_tree().create_timer(p_seconds).timeout


## 战斗日志组件（顶部条持有）。
func _log() -> Variant:
	var bar: Variant = _root().get("combat_topbar")
	assert_not_null(bar, "前置：战场根应持有顶部条")
	var log: Variant = (bar as Object).get("combat_log")
	assert_not_null(log, "前置：顶部条应持有战斗日志组件")
	return log


## 折叠按钮（日志入口——真实节点，不用路径猜）。
func _collapse_button() -> Button:
	var button: Variant = _log().call("collapse_button")
	assert_not_null(button, "前置：日志组件应持有折叠按钮")
	return button as Button


## 日志正文（RichTextLabel 文本）。
func _log_text() -> String:
	var rich: Variant = _log().get("log_rich")
	return (rich as RichTextLabel).text if rich != null else ""


## 焦点链实例（场景接线持有）。
func _chain() -> Variant:
	var wiring: Variant = scene.get("interaction_wiring")
	assert_not_null(wiring, "前置：场景应持有出牌交互接线")
	var chain: Variant = wiring.get("focus_chain")
	assert_not_null(chain, "前置：交互接线应已建焦点链")
	return chain


func _hand_cards() -> Array:
	var hand: Variant = _root().get("hand_area")
	return hand.call("card_nodes") as Array


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
