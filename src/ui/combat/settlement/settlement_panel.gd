class_name SettlementPanel
extends Control
## SettlementPanel —— 胜利/战败结算面板（combat-ui-layout Story 008）。
##
## [b]职责[/b]：两类结算面板的视觉框架与状态渲染——胜利面板（战利品三选一
## 等宽网格 + 0.5s 延迟可点 + 选中高亮 + 确认/跳过按钮）与战败面板（损失摘要
## + 返回探索按钮）。判定全部委托 [SettlementRules]（Logic 内核，BLOCKING 单测）；
## 外框由 [SettlementFrame] 构建、控件树由 [SettlementPanelView] 搭建；
## 开合由 [SettlementFade] 驱动；本面板只编排与转发点击。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：数据由宿主按信号载荷下发；
## 选中态与延迟窗口是瞬态交互状态（§2.1 豁免）——确认前不写任何系统。[br]
## [br][b]零轮询[/b]（ADR-0031 §3）：0.5s 延迟由一次性 [Timer] 驱动，开合为 Tween。[br]
## [br][b]不自动关闭[/b]（AC-10 / GDD「无穷」）：只在玩家点击确认/跳过/返回时关闭。[br]
## [br][b]确认后的持久写入归 interaction epic[/b]（Out of Scope）：只发信号。
##
## @experimental
## 来源: ADR-0031、design/gdd/combat-ui-system.md §9 战斗结算面板 /
## §边界情况（均匀网格）/ §调优参数、combat-ui-layout Story 008（AC-1~AC-5/AC-10）。

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

## === 面板尺寸（px——1920×1080 基准，不覆盖全屏）=============================

const PANEL_WIDTH: float = 720.0
const VICTORY_PANEL_HEIGHT: float = 520.0
const DEFEAT_PANEL_HEIGHT: float = 320.0

## === 瞬态视觉状态（§2.1 豁免）=============================================

## 当前面板种类（[SettlementRules.KIND_*]）。
var kind: StringName = Rules.KIND_NONE
## 战利品选项快照。
var loot_options: Array = []
## 当前选中下标（-1 = 未选中）。
var selected_index: int = -1
## 是否已过 0.5s 延迟窗口。
var loot_ready: bool = false
## 延迟窗口已走过的秒数（[b]阈值判定唯一入口[/b]是
## [method SettlementRules.loot_clickable]——本字段只承载「走了多久」，
## 不在面板内重复写 0.5s 阈值语义）。
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
## [param options]: 战利品选项列表（3 项——少于/多于 3 项也按网格流式排布）。[br]
## [param deck_count]: 当前卡组张数（卡组满判定）。[br]
## [param deck_limit]: 当前境界卡组上限。[br]
## [param reward_lines]: 本场奖励行（空 = 隐藏该段——旧调用方照常工作）。
func show_victory(options: Array, deck_count: int, deck_limit: int,
		reward_lines: Array = []) -> void:
	kind = Rules.KIND_VICTORY
	loot_options = options.duplicate(true)
	selected_index = -1
	loot_ready = false
	_elapsed_sec = 0.0
	title_label.text = Rules.TEXT_VICTORY_TITLE
	hint_label.text = Rules.victory_hint_text(false, loot_options.size())
	hint_label.visible = true
	defeat_lines_label.visible = false
	View.apply_reward_lines(reward_lines_label, reward_lines)
	loot_grid.visible = true
	skip_button.visible = true
	skip_button.text = Rules.TEXT_SKIP_LOOT
	confirm_button.text = Rules.TEXT_CONFIRM_LOOT
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
