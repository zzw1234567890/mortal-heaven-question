extends GutTest
## combat-ui-layout Story 008 BLOCKING 集成测试：战利品 0.5s 延迟可点与面板流程。
##
## QA 规格（story QA Test Cases AC-1）：胜利面板弹出 → 0.5s 内 disabled、之后
## enabled；未选中任何项时确认按钮灰；恰 0.5s 边界固化；卡组满时卡牌选项 disabled。
## 另覆盖 AC-2 三类信号触发、AC-3 选中高亮（非确认）、AC-5 战败摘要、
## AC-6/AC-7 撤退双变体、AC-8 战前警示、AC-10 面板不自动关闭。
##
## [b]相位推进方式[/b]：0.5s 延迟以一次性 Timer 承载，测试直接
## [code]loot_delay_timer.timeout.emit()[/code] 推进到点——[b]不做真实等待[/b]
## （deterministic，无时间依赖断言）。

const HostScript := preload("res://src/ui/combat/settlement/settlement_host.gd")
const PanelScript := preload("res://src/ui/combat/settlement/settlement_panel.gd")
const RetreatScript := preload("res://src/ui/combat/settlement/retreat_dialog.gd")
const WarningScript := preload("res://src/ui/combat/settlement/tribulation_warning_dialog.gd")
const Rules := preload("res://src/ui/combat/shared/settlement_rules.gd")
const Retreat := preload("res://src/ui/combat/shared/retreat_rules.gd")
const FrameScript := preload("res://src/ui/combat/settlement/settlement_frame.gd")
const CombatSystemScript := preload("res://src/feature/combat_system.gd")
const CombatRootScene: PackedScene = preload("res://src/ui/combat/layout/CombatRoot.tscn")

## 桩卡组系统（只实现 [code]get_deck_summary()[/code]——面板不读其他 API）。
class DeckStub extends Node:
	var total: int = 5
	var limit: int = 20

	func get_deck_summary() -> Dictionary:
		return {"total": total, "limit": limit, "is_full": total >= limit}


## 桩战斗系统（承载 battle_ended / retreat_requested 两个信号——宿主接线目标）。
class CombatStub extends Node:
	signal battle_ended(result: int, rewards: Dictionary)
	signal retreat_requested()


var panel: Control = null
var host: Control = null


func before_each() -> void:
	panel = PanelScript.new()
	add_child_autofree(panel)
	panel.reduce_motion = true


func _victory_options() -> Array:
	return [
		{"kind": Rules.OPTION_KIND_CARD, "name": "青云剑诀", "rarity": "蓝",
				"school": "功法"},
		{"kind": Rules.OPTION_KIND_LINGSHI, "amount": 25},
		{"kind": Rules.OPTION_KIND_CONSUMABLE, "name": "回血丹"},
	]


## 桩战斗系统（自释放——避免孤儿节点）。
func _make_combat() -> Node:
	var stub: Node = CombatStub.new()
	add_child_autofree(stub)
	return stub


## 桩卡组系统（自释放——避免孤儿节点）。
func _make_deck(total: int = 5, limit: int = 20) -> Node:
	var deck: Node = DeckStub.new()
	deck.total = total
	deck.limit = limit
	add_child_autofree(deck)
	return deck


## 推进 0.5s 延迟窗口到点（确定性接缝——非真实等待）。
func _elapse_delay() -> void:
	panel.loot_delay_timer.timeout.emit()


# ═══════════════════════════════════════════════════════════════════════════════
# AC-2：0.5s 延迟可点（BLOCKING）
# ═══════════════════════════════════════════════════════════════════════════════

func test_loot_options_disabled_right_after_victory_panel_opens() -> void:
	# Act
	panel.show_victory(_victory_options(), 5, 20)
	# Assert: 刚弹出时不可点
	assert_false(panel.is_loot_clickable(), "弹出瞬间战利品应不可点（0.5s 延迟）")
	assert_true(panel.confirm_button.disabled, "刚弹出时确认按钮应灰")


func test_loot_options_enabled_after_delay_elapses() -> void:
	# Arrange
	panel.show_victory(_victory_options(), 5, 20)
	# Act
	_elapse_delay()
	# Assert
	assert_true(panel.is_loot_clickable(), "0.5s 后战利品应可点")
	# 未选中任何项——确认按钮仍应灰（AC-3）
	assert_true(panel.confirm_button.disabled, "未选中时确认按钮仍应灰")


func test_confirm_button_enabled_only_after_selection_and_delay() -> void:
	# Arrange: 延迟到点后选中第 0 项
	panel.show_victory(_victory_options(), 5, 20)
	_elapse_delay()
	# Act
	panel.get_cards()[0].pressed.emit(0)
	# Assert
	assert_false(panel.confirm_button.disabled, "已选中且已过延迟后确认按钮应可点")


func test_selection_before_delay_is_ignored() -> void:
	# Arrange: 延迟未到就点击（模拟误触）
	panel.show_victory(_victory_options(), 5, 20)
	# Act
	panel.get_cards()[0].pressed.emit(0)
	# Assert: 未选中、确认按钮仍灰
	assert_eq(panel.get_selected_index(), -1, "延迟窗口内的点击应被忽略（防误触）")
	assert_true(panel.confirm_button.disabled, "延迟窗口内确认按钮应保持灰")


func test_delay_boundary_constant_is_half_second() -> void:
	# 边界固化：延迟时长常量必须为 GDD 明文 0.5s
	assert_almost_eq(panel.loot_delay_timer.wait_time, 0.5, 0.0001,
			"战利品延迟窗口应为 0.5s")
	assert_almost_eq(float(Rules.LOOT_CLICK_DELAY_SEC), 0.5, 0.0001,
			"Logic 内核延迟常量应为 0.5s")


## 计时器真接线：打开后必须真的启动（一次性），关闭后必须停止。[br]
## 若 [method SettlementPanel.show_victory] 漏掉 [code]start()[/code]，
## 上面那些手工 emit 推进的用例仍会全绿——本条补上这个缺口。
func test_delay_timer_started_on_show_and_stopped_on_close() -> void:
	# Act: 打开胜利面板
	panel.show_victory(_victory_options(), 5, 20)
	# Assert: 已启动且为一次性
	assert_false(panel.loot_delay_timer.is_stopped(), "打开后面板应启动延迟计时器")
	assert_true(panel.loot_delay_timer.one_shot, "延迟计时器应为一次性（不循环）")
	# Act: 关闭
	panel.close_panel()
	# Assert: 已停止（不留悬挂计时器）
	assert_true(panel.loot_delay_timer.is_stopped(), "关闭后应停止延迟计时器")


## 到点回调只翻转可点态——不得关闭面板（AC-10 结构断言）。[br]
func test_delay_timeout_does_not_close_panel() -> void:
	panel.show_victory(_victory_options(), 5, 20)
	_elapse_delay()
	assert_true(panel.is_open(), "延迟到点后面板仍应打开")
	assert_true(panel.is_loot_clickable(), "延迟到点后战利品应可点")


## 结算面板只持有这一个 Timer（无自动关闭计时器的结构性保证）。[br]
func test_panel_holds_only_the_loot_delay_timer() -> void:
	panel.show_victory(_victory_options(), 5, 20)
	var timers: Array = []
	for child: Node in panel.get_children():
		if child is Timer:
			timers.append(child)
	assert_eq(timers.size(), 1, "结算面板只应有 loot_delay_timer 一个 Timer")
	assert_eq(timers[0], panel.loot_delay_timer, "唯一的 Timer 应是延迟计时器")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1 / AC-3：三选一网格与选中高亮
# ═══════════════════════════════════════════════════════════════════════════════

func test_victory_panel_builds_three_equal_width_cards() -> void:
	# Act
	panel.show_victory(_victory_options(), 5, 20)
	# 布局需一帧后成立（容器把等分宽度结算到卡片上）
	await get_tree().process_frame
	await get_tree().process_frame
	# Assert: 三张卡 + 内核口径格宽 > 0
	assert_eq(panel.get_cards().size(), 3, "三选一应建 3 张战利品卡")
	var cell_width: float = panel.get_loot_cell_width()
	assert_true(cell_width > 0.0, "等宽格宽应为正数")
	# Assert: 渲染层实测——三卡宽度相等且等于内核算出的格宽（GDD §边界情况
	# 「均匀网格」；断言真实 size.x，而非重算内核值自证）
	var widths: Array = []
	for card: Control in panel.get_cards():
		widths.append(card.size.x)
	assert_almost_eq(widths[0], widths[1], 0.5, "前两卡应等宽")
	assert_almost_eq(widths[1], widths[2], 0.5, "后两卡应等宽")
	assert_almost_eq(widths[0], cell_width, 0.5,
			"卡片实测宽度应等于内核 loot_grid_layout 的格宽")
	# Assert: 三卡宽 + 两列间隔 = 面板内容宽
	var content_width: float = panel.PANEL_WIDTH - FrameScript.PANEL_PADDING * 2.0
	var used: float = widths[0] + widths[1] + widths[2] + Rules.LOOT_GAP * 2.0
	assert_almost_eq(used, content_width, 1.0, "三卡与列间隔应恰好铺满内容宽")


## 垂直居中：卡片内容块在卡面内上下留白相等（AC-1 视觉口径的装配层确认）。[br]
## 内核口径已在单测固定；此处确认卡片实际把卡格高度传给了内核函数。
func test_loot_card_uses_kernel_vertical_centering() -> void:
	# Act
	panel.show_victory(_victory_options(), 5, 20)
	await get_tree().process_frame
	# Assert: 卡片高度即卡格高度（内核垂中公式的输入）
	var card: Control = panel.get_cards()[0]
	assert_almost_eq(card.size.y, Rules.LOOT_CELL_HEIGHT, 0.5,
			"卡片高度应等于内核卡格高度常量")
	var top: float = Rules.loot_card_content_top(card.size.y)
	assert_almost_eq(top * 2.0 + Rules.CARD_CONTENT_BLOCK_HEIGHT, card.size.y, 0.5,
			"内容块上下留白之和 + 块高应等于卡高（垂直居中）")


# ═══════════════════════════════════════════════════════════════════════════════
# 键盘可达（.claude/rules/ui-code.md「交互元素必须同时支持键盘与手柄」）
# ═══════════════════════════════════════════════════════════════════════════════

func test_loot_cards_are_focusable() -> void:
	# Act
	panel.show_victory(_victory_options(), 5, 20)
	# Assert: 自绘控件默认不可聚焦——必须显式开（否则键盘玩家无法选中战利品）
	for card: Control in panel.get_cards():
		assert_ne(card.focus_mode, Control.FOCUS_NONE,
				"战利品卡必须可聚焦（键盘/手柄可达）")


func test_focus_chain_forms_a_ring() -> void:
	# Arrange
	panel.show_victory(_victory_options(), 5, 20)
	var cards: Array = panel.get_cards()
	# Assert: 卡片 → 确认 → 跳过 → 首卡，首尾互指（自绘卡不会被容器自动推导邻接）
	var chain: Array = [cards[0], cards[1], cards[2],
			panel.confirm_button, panel.skip_button]
	for i: int in range(chain.size()):
		var node: Control = chain[i]
		var expected_next: Control = chain[(i + 1) % chain.size()]
		assert_eq(node.get_node_or_null(node.focus_next), expected_next,
				"第 %d 个控件的下一焦点应是链中下一个" % i)
		var expected_prev: Control = chain[(i - 1 + chain.size()) % chain.size()]
		assert_eq(node.get_node_or_null(node.focus_previous), expected_prev,
				"第 %d 个控件的上一焦点应是链中上一个" % i)


func test_victory_panel_grabs_first_card_focus() -> void:
	# Arrange / Act
	panel.show_victory(_victory_options(), 5, 20)
	await get_tree().process_frame
	# Assert: 打开时焦点落在第一张卡（键盘玩家无需鼠标即可开始操作）
	assert_true(panel.get_cards()[0].has_focus(),
			"胜利面板打开后焦点应在第一张战利品卡上")


func test_keyboard_enter_selects_focused_card_after_delay() -> void:
	# Arrange
	panel.show_victory(_victory_options(), 5, 20)
	await get_tree().process_frame
	_elapse_delay()
	# Act: 键盘 Enter（焦点路径——与鼠标同源，转发同一下标）
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	(panel.get_cards()[0] as Control).gui_input.emit(key)
	# Assert
	assert_eq(panel.get_selected_index(), 0, "键盘 Enter 应选中当前聚焦的战利品卡")


func test_keyboard_enter_ignored_before_delay() -> void:
	# Arrange: 未到 0.5s
	panel.show_victory(_victory_options(), 5, 20)
	await get_tree().process_frame
	# Act
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	(panel.get_cards()[0] as Control).gui_input.emit(key)
	# Assert: 延迟窗口内键盘同样不可越过（与鼠标口径一致）
	assert_eq(panel.get_selected_index(), -1, "延迟窗口内键盘 Enter 不应选中")


func test_defeat_panel_grabs_confirm_button_focus() -> void:
	# Act
	panel.show_defeat({"cultivation_lost": 120, "dead_names": [], "binding_card_count": 0})
	await get_tree().process_frame
	# Assert: 无卡片时焦点落到「返回探索」按钮
	assert_true(panel.confirm_button.has_focus(),
			"战败面板打开后焦点应在返回探索按钮上")


func test_clicking_loot_highlights_without_confirming() -> void:
	# Arrange
	panel.show_victory(_victory_options(), 5, 20)
	_elapse_delay()
	var confirmed: Array = []
	panel.loot_confirmed.connect(func(i: int) -> void: confirmed.append(i))
	var selected: Array = []
	panel.loot_selected.connect(func(i: int) -> void: selected.append(i))
	# Act
	panel.get_cards()[1].pressed.emit(1)
	# Assert: 只高亮选中，不确认
	assert_eq(panel.get_selected_index(), 1, "点击应选中该项")
	assert_eq(selected, [1], "应发 loot_selected")
	assert_eq(confirmed.size(), 0, "点击战利品不得直接确认（AC-3 二次确认）")
	assert_true(panel.is_open(), "选中后面板应仍打开")


func test_selection_moves_between_options() -> void:
	# Arrange
	panel.show_victory(_victory_options(), 5, 20)
	_elapse_delay()
	# Act: 先选 0 再选 2
	panel.get_cards()[0].pressed.emit(0)
	panel.get_cards()[2].pressed.emit(2)
	# Assert: 只有最后一项是已选中态
	assert_eq(panel.get_selected_index(), 2, "选中应跟随最后一次点击")
	assert_eq(panel.get_cards()[0].get_state(), Rules.OPTION_AVAILABLE,
			"前一次选中应被取消")
	assert_eq(panel.get_cards()[2].get_state(), Rules.OPTION_SELECTED,
			"最后点击项应为已选态")


func test_confirm_emits_confirmed_and_closes() -> void:
	# Arrange
	panel.show_victory(_victory_options(), 5, 20)
	_elapse_delay()
	panel.get_cards()[0].pressed.emit(0)
	var confirmed: Array = []
	panel.loot_confirmed.connect(func(i: int) -> void: confirmed.append(i))
	# Act
	panel.confirm_button.pressed.emit()
	# Assert
	assert_eq(confirmed, [0], "确认按钮应发 loot_confirmed(0)")
	assert_false(panel.is_open(), "确认后面板应关闭")


## 跳过路径：发 loot_skipped 并关闭（无二次确认归 interaction epic）。[br]
func test_skip_emits_skipped_and_closes() -> void:
	# Arrange
	panel.show_victory(_victory_options(), 5, 20)
	_elapse_delay()
	var skipped: Array = []
	panel.loot_skipped.connect(func() -> void: skipped.append(true))
	# Act
	panel.skip_button.pressed.emit()
	# Assert
	assert_eq(skipped.size(), 1, "跳过按钮应发 loot_skipped")
	assert_eq(panel.get_kind(), Rules.KIND_NONE, "跳过后面板应关闭")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-4：卡组满灰显
# ═══════════════════════════════════════════════════════════════════════════════

func test_card_option_greyed_when_deck_full() -> void:
	# Act: 卡组 20/20（满）
	panel.show_victory(_victory_options(), 20, 20)
	# Assert: 卡牌选项灰显，灵石/消耗品仍可选
	assert_eq(panel.get_cards()[0].get_state(), Rules.OPTION_DECK_FULL,
			"卡组满时卡牌选项应灰显")
	assert_false(panel.get_cards()[0].is_clickable(), "灰显卡牌不可点")
	assert_eq(panel.get_cards()[1].get_state(), Rules.OPTION_AVAILABLE,
			"灵石选项不受卡组上限约束")
	assert_eq(panel.get_cards()[2].get_state(), Rules.OPTION_AVAILABLE,
			"消耗品选项不受卡组上限约束")


func test_greyed_card_option_does_not_select() -> void:
	# Arrange: 卡组满 + 延迟到点
	panel.show_victory(_victory_options(), 20, 20)
	_elapse_delay()
	# Act: 点击灰显卡牌（卡片自身在灰显态不转发 pressed）
	panel.get_cards()[0].pressed.emit(0)
	# 面板侧同样守卫：灰显项不得被选中
	# Assert
	assert_ne(panel.get_cards()[0].get_state(), Rules.OPTION_SELECTED,
			"灰显卡牌不应进入已选中态")
	assert_eq(panel.get_selected_index(), -1, "灰显点击后选中下标应保持 -1")
	assert_true(panel.confirm_button.disabled, "灰显点击后确认按钮应仍为灰")


## 卡片自身的点击守卫：灰显态经真实 gui_input 入口点击也不转发。[br]
## 上面两条走 [code]pressed.emit()[/code] 绕过卡片层——本条覆盖
## [method LootOptionCard._on_gui_input] 的 [method LootOptionCard.is_clickable] 守卫。
func test_greyed_card_ignores_real_gui_input() -> void:
	# Arrange: 卡组满（灰显）
	panel.show_victory(_victory_options(), 20, 20)
	_elapse_delay()
	var forwarded: Array = []
	panel.get_cards()[0].pressed.connect(func(i: int) -> void: forwarded.append(i))
	# Act: 模拟左键点击（走真实输入事件）
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	panel.get_cards()[0].gui_input.emit(click)
	# Assert: 灰显卡片不转发点击
	assert_true(forwarded.is_empty(), "灰显卡牌经真实点击入口也不应转发 pressed")
	assert_eq(panel.get_cards()[0].get_state(), Rules.OPTION_DECK_FULL,
			"灰显态不应被点击改变")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-10：不自动关闭
# ═══════════════════════════════════════════════════════════════════════════════

func test_panel_stays_open_after_delay_and_time() -> void:
	# Arrange
	panel.show_victory(_victory_options(), 5, 20)
	# Act: 推进延迟 + 再等若干帧
	_elapse_delay()
	await get_tree().process_frame
	await get_tree().process_frame
	# Assert: 无自动关闭路径
	assert_true(panel.is_open(), "结算面板不得自动关闭（GDD 调优参数「无穷」）")
	assert_true(panel.visible, "面板应保持可见")


func test_close_panel_is_idempotent() -> void:
	# Arrange
	panel.show_victory(_victory_options(), 5, 20)
	# Act
	panel.close_panel()
	panel.close_panel()
	# Assert
	assert_false(panel.is_open(), "关闭后应为未打开态")
	assert_eq(panel.get_kind(), Rules.KIND_NONE, "种类应复位")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-5：战败面板
# ═══════════════════════════════════════════════════════════════════════════════

func test_defeat_panel_shows_loss_summary() -> void:
	# Act
	panel.show_defeat({
		"cultivation_lost": 30, "dead_names": ["林渊", "白芷"],
		"binding_card_count": 2,
	})
	# Assert
	assert_eq(panel.get_kind(), Rules.KIND_DEFEAT, "种类应为战败")
	assert_true(panel.defeat_lines_label.text.contains("50%"),
			"战败摘要应写明 50% 修为损失")
	assert_true(panel.defeat_lines_label.text.contains("林渊"),
			"战败摘要应列出阵亡角色")
	assert_true(panel.defeat_lines_label.text.contains("2 张"),
			"战败摘要应提示绑定卡失去")
	assert_eq(panel.confirm_button.text, Rules.TEXT_RETURN_EXPLORE,
			"战败面板按钮应为「返回探索」")
	assert_true(panel.get_cards().is_empty(), "战败面板不建战利品卡")


func test_defeat_confirm_emits_signal() -> void:
	# Arrange
	panel.show_defeat({"dead_names": ["林渊"]})
	var fired: Array = []
	panel.defeat_confirmed.connect(func() -> void: fired.append(true))
	# Act
	panel.confirm_button.pressed.emit()
	# Assert
	assert_eq(fired.size(), 1, "返回探索应发 defeat_confirmed")
	assert_false(panel.is_open(), "确认后面板应关闭")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-6/AC-7：撤退双变体
# ═══════════════════════════════════════════════════════════════════════════════

func test_retreat_dialog_normal_variant() -> void:
	var dialog: Control = RetreatScript.new()
	add_child_autofree(dialog)
	dialog.reduce_motion = true
	# Act
	dialog.open(false, 1)
	# Assert
	assert_true(dialog.is_showing(), "普通撤退弹窗应打开")
	assert_eq(dialog.title_label.text, "⚠ 确认撤退？", "普通撤退标题")
	assert_false(dialog.warning_label.visible, "普通变体不得显示渡劫警示")
	assert_true(dialog.body_label.text.contains("非绑定物品"),
			"普通变体应说明保留非绑定物品")
	assert_eq(dialog.get_border_color(), Rules.COLOR_PANEL_BORDER,
			"普通变体边框为淡墨")


func test_retreat_dialog_tribulation_variant() -> void:
	var dialog: Control = RetreatScript.new()
	add_child_autofree(dialog)
	dialog.reduce_motion = true
	# Act
	dialog.open(true, 2)
	# Assert
	assert_eq(dialog.get_border_color(), Rules.COLOR_DANGER,
			"渡劫变体边框应为朱砂红")
	assert_true(dialog.warning_label.visible, "渡劫变体应显示专属警示")
	assert_eq(dialog.warning_label.text, "畏劫而退，修为散尽", "渡劫警示文案")
	assert_true(dialog.body_label.text.contains("80%"), "渡劫变体应写明 80% 修为损失")
	assert_true(dialog.body_label.text.contains("渡劫机会"), "应写明失去渡劫机会")
	# 回读真实 StyleBox：边框色必须真的下发到外框（不只是内核算一遍）
	var style: StyleBoxFlat = dialog.frame.get_theme_stylebox("panel") as StyleBoxFlat
	assert_not_null(style, "撤退弹窗外框应有 panel StyleBox")
	assert_eq(style.border_color, Rules.COLOR_DANGER, "外框边框色应实际为朱砂红")


## 普通/渡劫来回切换——同一外框复用，边框色随之复位（不残留朱砂红）。[br]
func test_retreat_border_color_resets_between_variants() -> void:
	var dialog: Control = RetreatScript.new()
	add_child_autofree(dialog)
	dialog.reduce_motion = true
	# Act: 渡劫 → 关闭 → 普通
	dialog.open(true, 0)
	dialog.close_dialog()
	dialog.open(false, 0)
	# Assert
	var style: StyleBoxFlat = dialog.frame.get_theme_stylebox("panel") as StyleBoxFlat
	assert_not_null(style, "撤退弹窗外框应有 panel StyleBox")
	assert_eq(style.border_color, Rules.COLOR_PANEL_BORDER,
			"切回普通变体后边框应复位为淡墨")


func test_retreat_cancel_does_not_emit_confirm() -> void:
	var dialog: Control = RetreatScript.new()
	add_child_autofree(dialog)
	dialog.reduce_motion = true
	dialog.open(false)
	var confirmed: Array = []
	var cancelled: Array = []
	dialog.retreat_confirmed.connect(func() -> void: confirmed.append(true))
	dialog.retreat_cancelled.connect(func() -> void: cancelled.append(true))
	# Act: 点「继续战斗」
	dialog.cancel_button.pressed.emit()
	# Assert
	assert_eq(confirmed.size(), 0, "继续战斗不得发确认")
	assert_eq(cancelled.size(), 1, "继续战斗应发取消")
	assert_false(dialog.is_showing(), "弹窗应关闭")


func test_retreat_confirm_emits_signal() -> void:
	var dialog: Control = RetreatScript.new()
	add_child_autofree(dialog)
	dialog.reduce_motion = true
	dialog.open(true)
	var confirmed: Array = []
	dialog.retreat_confirmed.connect(func() -> void: confirmed.append(true))
	# Act
	dialog.confirm_button.pressed.emit()
	# Assert
	assert_eq(confirmed.size(), 1, "确认撤退应发 retreat_confirmed")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-8：渡劫战前警示
# ═══════════════════════════════════════════════════════════════════════════════

func test_tribulation_warning_shows_gdd_body() -> void:
	var dialog: Control = WarningScript.new()
	add_child_autofree(dialog)
	dialog.reduce_motion = true
	# Act
	dialog.open()
	# Assert
	assert_eq(dialog.get_body_text(), "天劫在前，退路将断。确认进战？",
			"战前警示正文须为 GDD 原文")
	assert_eq(dialog.confirm_button.text, "确认进战", "确认按钮文案")
	assert_eq(dialog.cancel_button.text, "返回", "返回按钮文案")


func test_tribulation_warning_confirm_marks_confirmed() -> void:
	host = HostScript.new()
	add_child_autofree(host)
	host.setup(_make_combat(), _make_deck(), true)
	# Act: 首次应弹出，确认后再问不再弹
	assert_true(host.show_pre_battle_warning(), "渡劫战未确认时应弹出警示")
	host.tribulation_warning.battle_confirmed.emit()
	assert_false(host.show_pre_battle_warning(), "确认后同场不再重复弹")


func test_non_tribulation_shows_no_pre_battle_warning() -> void:
	host = HostScript.new()
	add_child_autofree(host)
	host.setup(_make_combat(), _make_deck(), false)
	assert_false(host.show_pre_battle_warning(), "非渡劫战不应弹战前警示")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-2：宿主信号驱动（battle_ended / retreat_requested）
# ═══════════════════════════════════════════════════════════════════════════════

func test_host_opens_victory_panel_on_battle_ended_victory() -> void:
	# Arrange
	host = HostScript.new()
	add_child_autofree(host)
	var combat: Node = _make_combat()
	host.setup(combat, _make_deck(), false)
	# Act: 战斗系统发胜利信号
	combat.battle_ended.emit(CombatSystemScript.CombatResult.VICTORY,
			{"lingshi": 25, "cards": [{"name": "青云剑诀", "rarity": "蓝",
					"school": "功法"}]})
	# Assert
	assert_eq(host.settlement_panel.get_kind(), Rules.KIND_VICTORY,
			"胜利信号应打开战利品面板")
	assert_eq(host.settlement_panel.get_cards().size(), 2,
			"1 张卡 + 1 个灵石选项 = 2 张战利品卡")


func test_host_opens_defeat_panel_on_battle_ended_defeat() -> void:
	host = HostScript.new()
	add_child_autofree(host)
	var combat: Node = _make_combat()
	host.setup(combat, _make_deck(), false)
	# Act
	combat.battle_ended.emit(CombatSystemScript.CombatResult.DEFEAT, {})
	# Assert
	assert_eq(host.settlement_panel.get_kind(), Rules.KIND_DEFEAT,
			"战败信号应打开战败摘要面板")


func test_host_opens_retreat_dialog_on_retreat_requested() -> void:
	host = HostScript.new()
	add_child_autofree(host)
	var combat: Node = _make_combat()
	host.setup(combat, _make_deck(), false)
	# Act
	combat.retreat_requested.emit()
	# Assert
	assert_true(host.retreat_dialog.is_showing(), "撤退请求应打开确认弹窗")


func test_host_tribulation_retreat_uses_tribulation_variant() -> void:
	host = HostScript.new()
	add_child_autofree(host)
	var combat: Node = _make_combat()
	host.setup(combat, _make_deck(), true)
	# Act
	host.request_retreat()
	# Assert
	assert_eq(host.retreat_dialog.get_border_color(), Rules.COLOR_DANGER,
			"渡劫战撤退弹窗应为朱砂红变体")


func test_host_victory_uses_deck_summary_for_card_greyout() -> void:
	# Arrange: 卡组已满（20/20）
	host = HostScript.new()
	add_child_autofree(host)
	var deck: Node = _make_deck(20, 20)
	host.setup(_make_combat(), deck, false)
	# Act
	host.on_battle_ended(CombatSystemScript.CombatResult.VICTORY, {
		"cards": [{"name": "青云剑诀"}],
	})
	# Assert
	assert_eq(host.settlement_panel.get_cards()[0].get_state(),
			Rules.OPTION_DECK_FULL, "卡组满时卡牌选项应灰显")


## 宿主对外转发信号（面板→宿主→interaction epic 的三段链）。[br]
func test_host_forwards_panel_signals() -> void:
	# Arrange
	host = HostScript.new()
	add_child_autofree(host)
	var combat: Node = _make_combat()
	host.setup(combat, _make_deck(), false)
	combat.battle_ended.emit(CombatSystemScript.CombatResult.VICTORY,
			{"lingshi": 25, "cards": [{"name": "青云剑诀"}]})
	host.settlement_panel.loot_delay_timer.timeout.emit()
	var selected: Array = []
	var confirmed: Array = []
	var skipped: Array = []
	host.loot_selected.connect(func(i: int) -> void: selected.append(i))
	host.loot_confirmed.connect(func(i: int) -> void: confirmed.append(i))
	host.loot_skipped.connect(func() -> void: skipped.append(true))
	# Act: 选中 → 确认
	host.settlement_panel.get_cards()[0].pressed.emit(0)
	host.settlement_panel.confirm_button.pressed.emit()
	# Assert
	assert_eq(selected, [0], "宿主应转发 loot_selected")
	assert_eq(confirmed, [0], "宿主应转发 loot_confirmed")
	assert_true(skipped.is_empty(), "确认路径不应发 loot_skipped")


## 换源注入：重新 setup 到另一个战斗系统不得双开面板（旧源必须断开）。[br]
func test_host_resetup_does_not_double_open() -> void:
	# Arrange: 首次 setup 到 combat A
	host = HostScript.new()
	add_child_autofree(host)
	var combat_a: Node = _make_combat()
	var combat_b: Node = _make_combat()
	host.setup(combat_a, _make_deck(), false)
	# Act: 换源到 combat B 后由 B 触发
	host.setup(combat_b, _make_deck(), false)
	var opens: Array = []
	host.settlement_panel.loot_selected.connect(func(_i: int) -> void:
		opens.append(true))
	combat_b.battle_ended.emit(CombatSystemScript.CombatResult.VICTORY,
			{"lingshi": 5})
	# Assert: 面板打开一次（不因旧源仍挂着而重复开）
	assert_eq(host.settlement_panel.get_kind(), Rules.KIND_VICTORY,
			"新战斗系统的信号应驱动面板")
	assert_false(combat_a.battle_ended.is_connected(host.on_battle_ended),
			"换源后旧战斗系统的信号应已断开")


## 战利品为空（rewards 无 cards 且无 lingshi）——面板仍打开但不建卡。[br]
func test_host_victory_with_empty_rewards_builds_no_cards() -> void:
	host = HostScript.new()
	add_child_autofree(host)
	var combat: Node = _make_combat()
	host.setup(combat, _make_deck(), false)
	# Act
	combat.battle_ended.emit(CombatSystemScript.CombatResult.VICTORY, {})
	# Assert: 面板打开、0 张卡、确认按钮灰（无选项可确认）
	assert_eq(host.settlement_panel.get_kind(), Rules.KIND_VICTORY,
			"空奖励也应打开胜利面板")
	assert_true(host.settlement_panel.get_cards().is_empty(), "空奖励不建战利品卡")
	assert_true(host.settlement_panel.confirm_button.disabled,
			"无选项时确认按钮应保持灰")


## 宿主把本场奖励汇总行下发到面板（实得/未抽到都在面板上可见）。[br]
func test_host_passes_reward_lines_to_panel() -> void:
	# Arrange
	host = HostScript.new()
	add_child_autofree(host)
	var combat: Node = _make_combat()
	host.setup(combat, _make_deck(), false)
	# Act——胜利载荷带实得灵石与未抽到的卡
	combat.battle_ended.emit(CombatSystemScript.CombatResult.VICTORY, {
		"lingshi": 12, "cultivation": 3,
		"cards": [{"card_id": "pei_yuan_dan", "name": "培元丹",
				"rarity": "白", "school": "丹药"}],
		"cards_missed": [{"card_id": "gui_xiu_page", "name": "鬼修残页",
				"chance": 0.2}],
	})
	# Assert——面板的奖励段同时含「到手」与「未抽到」
	var text: String = host.settlement_panel.reward_lines_label.text
	assert_true(host.settlement_panel.reward_lines_label.visible,
			"有奖励时奖励段应可见")
	assert_string_contains(text, "灵石 +12", "面板展示实得灵石")
	assert_string_contains(text, "修为 +3", "面板展示修为")
	assert_string_contains(text, "获得卡牌：培元丹（白·丹药）", "面板展示到手卡牌")
	assert_string_contains(text, "未抽到：鬼修残页（20%）", "面板展示未抽到的卡")


## 战败面板不显示奖励段（损失摘要已覆盖负面信息）。[br]
func test_host_defeat_panel_hides_reward_lines() -> void:
	host = HostScript.new()
	add_child_autofree(host)
	var combat: Node = _make_combat()
	host.setup(combat, _make_deck(), false)
	# Act
	combat.battle_ended.emit(CombatSystemScript.CombatResult.VICTORY,
			{"lingshi": 5})
	assert_true(host.settlement_panel.reward_lines_label.visible,
			"前置：胜利面板显示奖励段")
	combat.battle_ended.emit(CombatSystemScript.CombatResult.DEFEAT, {})
	# Assert
	assert_eq(host.settlement_panel.get_kind(), Rules.KIND_DEFEAT, "前置：切到战败面板")
	assert_false(host.settlement_panel.reward_lines_label.visible,
			"战败面板不应残留上一场的奖励段")


## reduce_motion 在面板构建前设置也必须生效（不被子面板默认值吞掉）。[br]
func test_host_reduce_motion_survives_panel_construction() -> void:
	host = HostScript.new()
	# Act: 入树前设 reduce_motion
	host.set_reduce_motion(true)
	add_child_autofree(host)
	# Assert
	assert_true(host.settlement_panel.reduce_motion, "结算面板应继承 reduce_motion")
	assert_true(host.retreat_dialog.reduce_motion, "撤退弹窗应继承 reduce_motion")
	assert_true(host.tribulation_warning.reduce_motion, "战前警示应继承 reduce_motion")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-9：撤退按钮（CombatRoot 装配）
# ═══════════════════════════════════════════════════════════════════════════════

func test_combat_root_has_always_enabled_retreat_button() -> void:
	# Arrange
	var root: Control = CombatRootScene.instantiate()
	add_child_autofree(root)
	var button: Button = root.get_node_or_null(
			NodePath("RetreatButtonSlot/RetreatButton")) as Button
	# Assert
	assert_not_null(button, "战斗根应在撤退按钮位内装配撤退按钮")
	assert_false(button.disabled, "撤退按钮渲染态应始终可点（GDD §10）")
	assert_eq(button.text, "撤退", "撤退按钮文案")


func test_combat_root_has_hidden_settlement_host() -> void:
	var root: Control = CombatRootScene.instantiate()
	add_child_autofree(root)
	var settlement: Node = root.get_node_or_null(NodePath("SettlementHost"))
	assert_not_null(settlement, "战斗根应装配结算宿主")
	assert_false(settlement.settlement_panel.visible, "结算面板默认应隐藏")
	assert_false(settlement.retreat_dialog.visible, "撤退弹窗默认应隐藏")


func test_combat_root_retreat_button_opens_dialog() -> void:
	# Arrange
	var root: Control = CombatRootScene.instantiate()
	add_child_autofree(root)
	var button: Button = root.get_node_or_null(
			NodePath("RetreatButtonSlot/RetreatButton")) as Button
	# Act: 点击撤退按钮
	button.pressed.emit()
	# Assert
	assert_true(root.settlement_host.retreat_dialog.is_showing(),
			"点击撤退按钮应打开撤退确认弹窗")


# ═══════════════════════════════════════════════════════════════════════════════
# 不覆盖全屏（control-manifest Required）
# ═══════════════════════════════════════════════════════════════════════════════

func test_panels_do_not_cover_fullscreen() -> void:
	# Assert: 三类弹窗外框尺寸均小于 1920×1080 基准视口
	assert_true(Rules.panel_fits_within_viewport(Vector2(720, 520),
			Vector2(1920, 1080)), "战利品面板不应覆盖全屏")
	var dialog: Control = RetreatScript.new()
	add_child_autofree(dialog)
	assert_true(dialog.get_frame_size().x < 1920.0, "撤退弹窗不应覆盖全屏")
	var warning: Control = WarningScript.new()
	add_child_autofree(warning)
	assert_true(warning.get_frame_size().y < 1080.0, "战前警示不应覆盖全屏")
