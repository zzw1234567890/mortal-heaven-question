class_name SettlementPanel
extends Control
## SettlementPanel —— 胜利/战败结算面板（combat-ui-layout Story 008）。
##
## [b]职责[/b]：两类面板的视觉框架与状态渲染。判定全部委托 [SettlementRules]（Logic
## 内核，BLOCKING 单测）；外框 [SettlementFrame] 建、控件树 [SettlementPanelView] 搭、
## 开合 [SettlementFade] 驱动——本面板只编排与转发点击。[br]
## [br][b]两段分工[/b]（DEBT-CUI-008-3）：胜利面板先给「要挑的那一份」（选择段标题按
## 实际候选数写 + 网格），确认后才换成「已入账」清单——顺序即语义。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：数据由宿主按信号载荷下发；选中态与延迟窗口
## 是瞬态交互状态（§2.1 豁免），确认前不写任何系统。[br]
## [br][b]零轮询[/b]（§3）：0.5s 延迟由一次性 [Timer] 驱动，开合为 Tween。[br]
## [br][b]不自动关闭[/b]（AC-10）：只在玩家点确认/跳过/返回时关闭；持久写入归
## interaction epic（Out of Scope）——此处只发信号。
##
## @experimental
## 来源: ADR-0031、design/gdd/combat-ui-system.md §9、
## Story 008（AC-1~AC-5/AC-10）、DEBT-CUI-008-3。

const Rules := preload("res://src/ui/combat/shared/settlement_rules.gd")
const View := preload("res://src/ui/combat/settlement/settlement_panel_view.gd")
const Frame := preload("res://src/ui/combat/settlement/settlement_frame.gd")
const Fade := preload("res://src/ui/combat/settlement/settlement_fade.gd")

## === 信号（对外出口——持久写入归 interaction epic）=========================

## 战利品被选中（高亮，非确认）。载荷为选项下标。
signal loot_selected(option_index: int)
## 确认选择战利品（二次确认生效）。载荷为选项下标。
signal loot_confirmed(option_index: int)
## 跳过全部奖励（后续「放弃所有奖励？」二次确认归 interaction epic）。
signal loot_skipped()
## 战败面板确认返回探索。
signal defeat_confirmed()
## 面板已关闭（[method close_panel] 的唯一出口）。[br]
## [br][b]为什么单开这条[/b]：关闭的触发点有四个（确认 / 跳过 / 战败返回 / 汇总视图
## 再确认），而四个业务信号各自只覆盖一部分路径——「关掉之后要做什么」若挂在业务
## 信号上，就得在四处各写一遍。焦点还原（见 [code]CombatFocusMemory[/code]）正是
## 「关掉之后」的事，故由本信号统一承载。[br]
## [br][b]与业务信号同时发[/b]：先发业务信号（上层据此推进结算），再发本信号。
signal closed()

## === 面板尺寸（px——1920×1080 基准，不覆盖全屏）=============================

const PANEL_WIDTH: float = 720.0
const VICTORY_PANEL_HEIGHT: float = 520.0
const DEFEAT_PANEL_HEIGHT: float = 320.0

## === 瞬态视觉状态（§2.1 豁免）=============================================

## 当前面板种类（[SettlementRules.KIND_*]）。
var kind: StringName = Rules.KIND_NONE
## 战利品选项快照（与 [member loot_options] 同序的卡片见 [member _cards]）。
var loot_options: Array = []
## 当前选中下标（-1 = 未选中）。
var selected_index: int = -1
## 是否已过 0.5s 延迟窗口。
var loot_ready: bool = false
## 延迟窗口已走过的秒数（阈值判定唯一入口是 [method SettlementRules.loot_clickable]
## ——本字段只承载「走了多久」，不在面板内重写 0.5s 语义）。
var _elapsed_sec: float = 0.0
## 减少动态偏好（开合动画直跳终态）。
var reduce_motion: bool = false

## === 控件（[method _build] 创建）==========================================

## 0.5s 延迟计时器（一次性——[b]测试相位推进的确定性接缝[/b]：断言前直接
## [code]loot_delay_timer.timeout.emit()[/code] 即可到点，无需真实等待）。
var loot_delay_timer: Timer = null
var title_label: Label = null
var hint_label: Label = null
## 纵向内容容器（标题/提示/网格/摘要/按钮的父级）。
var body_box: VBoxContainer = null
## 战利品网格（多行 HBox——每行 [constant SettlementRules.LOOT_COLUMNS] 张）。
var loot_grid: VBoxContainer = null
var confirm_button: Button = null
var skip_button: Button = null
## 战败摘要正文（与战利品网格互斥显示）。
var defeat_lines_label: Label = null
## 本场奖励汇总（实得 / 未抽到 / 未入库——仅胜利面板显示）。
var reward_lines_label: Label = null
## 选择段标题（「本次奖励：N 选 1」/「这份直接带走」——仅胜利面板且候选非空时显示）。
var pick_title_label: Label = null
## 外框（[SettlementFrame.build] 返回）。
var frame: Control = null

## 战利品卡片列表（与 [member loot_options] 同序）。
var _cards: Array = []
## 控件引用字典（[method SettlementPanelView.build] 返回——字号下发用）。
var _parts: Dictionary = {}
## 开合动画驱动（[SettlementFade] 实例——同一面板重开需 kill 旧 Tween）。
var _fade: SettlementFade = Fade.new()


func _init() -> void:
	name = "SettlementPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	visible = false


## 构建控件树（一次——重开只改内容不改结构）。[br]
## 结构由 [SettlementPanelView] 搭建（单文件 ≤300 行拆分）；本方法只接线与缓存引用。
func _build() -> void:
	var parts: Dictionary = View.build(self,
			Vector2(PANEL_WIDTH, VICTORY_PANEL_HEIGHT))
	_parts = parts
	frame = parts["frame"] as Control
	body_box = parts["body_box"] as VBoxContainer
	title_label = parts["title_label"] as Label
	hint_label = parts["hint_label"] as Label
	loot_grid = parts["loot_grid"] as VBoxContainer
	defeat_lines_label = parts["defeat_lines"] as Label
	reward_lines_label = parts["reward_lines"] as Label
	pick_title_label = parts["pick_title"] as Label
	confirm_button = parts["confirm_button"] as Button
	skip_button = parts["skip_button"] as Button
	loot_delay_timer = parts["loot_delay_timer"] as Timer
	confirm_button.pressed.connect(_on_confirm_pressed)
	skip_button.pressed.connect(_on_skip_pressed)
	loot_delay_timer.timeout.connect(_on_loot_delay_timeout)


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


# ═══════════════════════════════════════════════════════════════════════════════
# 关闭与查询
# ═══════════════════════════════════════════════════════════════════════════════

## 关闭面板（确认/跳过/返回——[b]唯一[/b]关闭入口，无自动关闭路径）。[br]
## [b]幂等[/b]：已关闭时再调用不重复发信号。
func close_panel() -> void:
	if kind == Rules.KIND_NONE:
		return
	loot_delay_timer.stop()
	kind = Rules.KIND_NONE
	_fade.play_close(self, reduce_motion)
	closed.emit()


## 当前面板是否打开。
func is_open() -> bool:
	return kind != Rules.KIND_NONE


## 当前面板种类（[SettlementRules.KIND_*]）。
func get_kind() -> StringName:
	return kind


## 战利品卡片列表（尺寸/状态断言用——与 [member loot_options] 同序）。
func get_cards() -> Array:
	return _cards


## 当前选中下标（-1 = 未选中）。
func get_selected_index() -> int:
	return selected_index


## 战利品当前是否可点（0.5s 延迟窗口已过）。
func is_loot_clickable() -> bool:
	return loot_ready


## 战利品卡片等宽值（口径统一在 [method SettlementPanelView.loot_cell_width]）。
func get_loot_cell_width() -> float:
	return View.loot_cell_width(PANEL_WIDTH)


## 是否处于「已到账汇总」视图（战利品网格隐藏，只显示奖励汇总行）。
func is_showing_grant_summary() -> bool:
	return kind == Rules.KIND_VICTORY and not loot_grid.visible


## 外框尺寸（「不覆盖全屏」断言用）。
func get_frame_size() -> Vector2:
	if frame == null:
		return Vector2.ZERO
	return frame.custom_minimum_size


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

func _on_confirm_pressed() -> void:
	if kind == Rules.KIND_VICTORY:
		if not Rules.confirm_button_enabled(selected_index, loot_ready):
			return
		var confirmed: int = selected_index
		close_panel()
		loot_confirmed.emit(confirmed)
	elif kind == Rules.KIND_DEFEAT:
		close_panel()
		defeat_confirmed.emit()


func _on_skip_pressed() -> void:
	if kind != Rules.KIND_VICTORY:
		return
	close_panel()
	loot_skipped.emit()



func _clear_loot_cards() -> void:
	_cards.clear()
	View.clear_grid(loot_grid)


func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		# 入树后才有真实视口高度——响应式字号在此下发（Frame.apply_font 唯一入口）
		View.apply_fonts(_parts, Frame.viewport_height(self))
	elif what == NOTIFICATION_PREDELETE:
		_fade.kill()


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
