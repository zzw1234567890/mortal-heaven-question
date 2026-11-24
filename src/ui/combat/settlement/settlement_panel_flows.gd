## SettlementPanel 面板流程面（继承链第 2 段）——[b]两块面板的开启与战利品交互[/b]。
##
## [b]本层职责[/b]：玩家从「看到面板」到「做出选择」的那一段。[br]
##   · 胜利面板——[method show_victory]（候选数决定选择段标题与按钮文案）、0.5s 延迟窗口翻转
##     （[method _on_loot_delay_timeout]，阈值判定仍走 [SettlementRules.loot_clickable]）、
##     战利品网格重建（[method _rebuild_loot_cards]）与单选高亮
##     （[method _on_option_pressed]，AC-3：点选不立即确认）；[br]
##   · 战败面板——[method show_defeat]（损失摘要 + 确认返回，无战利品段）；[br]
##   · 网格清空（[method _clear_loot_cards]）与「已到账汇总」视图（[method show_grant_summary]：
##     选择器整体让位、只留入账清单——DEBT-CUI-008-3）。[br]
## [b]不管什么[/b]：不构造（[method _init] / [method _build] 在链尾）、不关闭
## （[method close_panel] 在链尾）、不判定（一律委托 [SettlementRules]）。[br]
## [b]为什么本层排在链尾之前[/b]：链尾的 [method _build] 要按名接线
## [method _on_loot_delay_timeout]（[code]loot_delay_timer.timeout.connect(...)[/code]），
## 被接方必须在接线方[b]本段或祖先段[/b]——祖先段用裸标识符引用不到后代段成员，
## GDScript 解析期即失败（探针验证）。[br]
##
## [b]继承链[/b]（各段守 300 行内，成员名与访问路径逐字不变）：[br]
## [code]  settlement_panel_contract.gd [/code] ← 声明面：信号 / 常量 / 实例字段[br]
## [code]  settlement_panel_flows.gd    [/code] ← 本层：面板流程面[br]
## [code]  settlement_panel.gd          [/code] ← 链尾：装配与出口面（构造 / 关闭 / 查询 / 销毁）[br]
##
## 来源: ADR-0031 §2.1、design/gdd/combat-ui-system.md §9、combat-ui-layout Story 008
## （AC-1~AC-5/AC-10）、DEBT-CUI-008-3。

extends "res://src/ui/combat/settlement/settlement_panel_contract.gd"


# ═══════════════════════════════════════════════════════════════════════════════
# 胜利面板（AC-1/AC-2/AC-3/AC-4）
# ═══════════════════════════════════════════════════════════════════════════════

## 打开胜利结算面板。[br]
## [param options]: 战利品选项列表（按实际数量排布——1 项时没有选择器，
## 标题写「这份直接带走」；≥2 项写「N 选 1」）。[br]
## [param deck_count]: 当前卡组张数（卡组满判定）。[br]
## [param deck_limit]: 当前境界卡组上限。[br]
## [param reward_lines]: 本场奖励行（空 = 隐藏该段——旧调用方照常工作）。
## 此处是该段的[b]入账前[/b]形态（前缀「本场奖励（尚未入账）：」）。
func show_victory(options: Array, deck_count: int, deck_limit: int,
		reward_lines: Array = []) -> void:
	kind = Rules.KIND_VICTORY
	loot_options = options.duplicate(true)
	selected_index = -1
	loot_ready = false
	_elapsed_sec = 0.0
	title_label.text = Rules.TEXT_VICTORY_TITLE
	# 选择段标题按实际候选数写（0 → 整段隐藏；1 → 直接带走；≥2 → N 选 1）
	pick_title_label.text = Rules.loot_pick_title(loot_options.size())
	pick_title_label.visible = not pick_title_label.text.is_empty()
	hint_label.text = Rules.victory_hint_text(false, loot_options.size())
	hint_label.visible = true
	defeat_lines_label.visible = false
	View.apply_reward_lines(reward_lines_label,
			Rules.pending_section_lines(reward_lines))
	loot_grid.visible = true
	skip_button.visible = true
	skip_button.text = Rules.TEXT_SKIP_LOOT
	confirm_button.text = Rules.confirm_button_text(loot_options.size())
	Frame.resize(frame, Vector2(PANEL_WIDTH, VICTORY_PANEL_HEIGHT))
	Frame.set_border_color(frame, Rules.COLOR_PANEL_BORDER)
	_rebuild_loot_cards(deck_count, deck_limit)
	View.apply_hint_style(hint_label, loot_ready)
	confirm_button.disabled = not Rules.confirm_button_enabled(selected_index, loot_ready)
	visible = true
	_fade.play_open(self, reduce_motion)
	# 0.5s 后战利品才可点（GDD「先看清，再选择」）
	loot_delay_timer.start()
	# 键盘焦点环（卡片 → 确认 → 跳过 闭环；自绘卡不会自动推导邻接）
	View.wire_focus_chain(_cards, confirm_button, skip_button)
	View.grab_initial_focus(_cards, confirm_button)


## 战利品到点——翻转可点态并刷新提示与确认按钮。[br]
## [br][b]阈值判定走内核[/b]：本方法只累加已过时长，是否可点由
## [method SettlementRules.loot_clickable] 裁决（0.5s 阈值不在面板内重写；
## 计时器 [code]wait_time[/code] 同样取自 [constant SettlementRules.LOOT_CLICK_DELAY_SEC]）。
func _on_loot_delay_timeout() -> void:
	_elapsed_sec += loot_delay_timer.wait_time
	loot_ready = Rules.loot_clickable(_elapsed_sec)
	if kind != Rules.KIND_VICTORY:
		return
	hint_label.text = Rules.victory_hint_text(loot_ready, loot_options.size())
	View.apply_hint_style(hint_label, loot_ready)
	confirm_button.disabled = not Rules.confirm_button_enabled(selected_index, loot_ready)


## 战利品卡片重建（每次打开重排——数量随载荷变化；布局由 View 构建）。
func _rebuild_loot_cards(deck_count: int, deck_limit: int) -> void:
	_cards = View.rebuild_loot_cards(loot_grid, loot_options,
			deck_count, deck_limit, _on_option_pressed)


## 战利品点击——只高亮选中（AC-3：非立即确认）。
func _on_option_pressed(option_index: int) -> void:
	if kind != Rules.KIND_VICTORY or not loot_ready:
		return
	if option_index < 0 or option_index >= _cards.size():
		return
	# 灰显项（卡组已满）不可选——卡片自身不转发，面板侧再守一层（防绕过）
	if not Rules.option_clickable(_cards[option_index].get_state()):
		return
	selected_index = option_index
	for i: int in range(_cards.size()):
		var card: Control = _cards[i]
		if i == option_index:
			card.set_state(Rules.OPTION_SELECTED)
		elif card.get_state() == Rules.OPTION_SELECTED:
			card.set_state(Rules.OPTION_AVAILABLE)
	confirm_button.disabled = not Rules.confirm_button_enabled(selected_index, loot_ready)
	loot_selected.emit(option_index)


# ═══════════════════════════════════════════════════════════════════════════════
# 战败面板（AC-5）
# ═══════════════════════════════════════════════════════════════════════════════

## 打开战败结算面板。[br]
## [param summary]: [code]{cultivation_lost, dead_names, binding_card_count}[/code]。
func show_defeat(summary: Dictionary) -> void:
	kind = Rules.KIND_DEFEAT
	loot_options = []
	selected_index = -1
	loot_ready = false
	_elapsed_sec = 0.0
	loot_delay_timer.stop()
	title_label.text = Rules.defeat_title()
	pick_title_label.visible = false
	hint_label.visible = false
	# 战败没有奖励段（损失摘要已覆盖负面信息，混排会削弱可读性）
	View.apply_reward_lines(reward_lines_label, [])
	loot_grid.visible = false
	_clear_loot_cards()
	defeat_lines_label.text = "\n".join(Rules.defeat_lines(summary))
	defeat_lines_label.visible = true
	confirm_button.text = Rules.TEXT_RETURN_EXPLORE
	confirm_button.disabled = false
	skip_button.visible = false
	Frame.resize(frame, Vector2(PANEL_WIDTH, DEFEAT_PANEL_HEIGHT))
	Frame.set_border_color(frame, Rules.COLOR_PANEL_BORDER)
	visible = true
	_fade.play_open(self, reduce_motion)
	View.grab_initial_focus([], confirm_button)


func _clear_loot_cards() -> void:
	_cards.clear()
	View.clear_grid(loot_grid)


## 显示「已到账汇总」视图——选择器（网格 + 选择段标题 + 跳过）整体让位，只留
## 入账清单。[br]
## [param lines] 奖励汇总行数组（["灵石 +10", "修为 +5", "获得卡牌：培元丹（白）"]）。[br]
## [br][b]入账标记由内核加[/b]（[method SettlementRules.granted_section_lines]）：
## 行的字面量是发放返回值原文，UI 只负责前置一句「已入账：」——真假由发放返回值
## 决定，不是 UI 自己编的。[br]
## [br][b]选择器必须真的消失[/b]：段标题与跳过按钮一并隐藏——留着「本次奖励：3 选 1」
## 却已无可选之物，正是真机走查里「两组奖励信息不知哪组已到手」的来源。
func show_grant_summary(lines: Array) -> void:
	loot_grid.visible = false
	_clear_loot_cards()
	skip_button.visible = false
	pick_title_label.visible = false
	selected_index = -1
	View.apply_reward_lines(reward_lines_label,
			Rules.granted_section_lines(lines))
