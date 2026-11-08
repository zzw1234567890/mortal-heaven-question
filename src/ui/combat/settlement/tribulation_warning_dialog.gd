class_name TribulationWarningDialog
extends Control
## TribulationWarningDialog —— 渡劫战前警示弹窗（combat-ui-layout Story 008）。
##
## [b]职责[/b]：进入渡劫战[b]之前[/b]（备战界面之上）弹出最后一次取舍确认——
## 「天劫在前，退路将断。确认进战？」+ 确认进战/返回按钮（GDD §10 2026-07-24
## 修订明文）。文案委托 [RetreatRules]；外框由 [SettlementFrame] 构建。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：只发按钮信号，不启动战斗、不写 GSM；
## 按钮流转归 interaction epic（Out of Scope）。[br]
## [br][b]零轮询[/b]（ADR-0031 §3）：无 [code]_process()[/code]；开合为 Tween。[br]
## [br][b]与撤退面板的区分[/b]：本弹窗在[b]进战前[/b]弹出且为朱砂红警示；
## 撤退确认在[b]战斗中[/b]弹出（普通变体淡墨 / 渡劫变体朱砂红）。
##
## @experimental
## 来源: ADR-0031、design/gdd/combat-ui-system.md §10（渡劫战前警示）/
## §边界情况（渡劫战撤退）、combat-ui-layout Story 008（AC-8）。

const Rules := preload("res://src/ui/combat/shared/settlement_rules.gd")
const Retreat := preload("res://src/ui/combat/shared/retreat_rules.gd")
const Frame := preload("res://src/ui/combat/settlement/settlement_frame.gd")
const Fade := preload("res://src/ui/combat/settlement/settlement_fade.gd")

## === 信号 =================================================================

## 确认进战（实际战斗启动归 interaction epic）。
signal battle_confirmed()
## 返回（关闭警示，停留备战界面）。
signal battle_cancelled()

## === 尺寸（px——1920×1080 基准）=============================================

const PANEL_WIDTH: float = 520.0
const PANEL_HEIGHT: float = 220.0
const TITLE_HEIGHT: float = 36.0
const BODY_HEIGHT: float = 52.0
const BUTTON_WIDTH: float = 140.0
const BUTTON_HEIGHT: float = 38.0
const TITLE_BASE_SIZE: int = 20
const BODY_BASE_SIZE: int = 16

## === 状态 =================================================================

## 减少动态偏好（开合动画直跳终态）。
var reduce_motion: bool = false
## 弹窗是否打开。
var is_open: bool = false

## === 控件 =================================================================

var title_label: Label = null
var body_label: Label = null
var confirm_button: Button = null
var cancel_button: Button = null
## 外框（[SettlementFrame] 构建）。
var frame: Control = null

## 开合动画驱动（[SettlementFade] 实例）。
var _fade: SettlementFade = Fade.new()


func _init() -> void:
	name = "TribulationWarningDialog"
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	visible = false


func _build() -> void:
	var parts: Dictionary = Frame.build(self, Vector2(PANEL_WIDTH, PANEL_HEIGHT),
			Rules.COLOR_DANGER)
	frame = parts["frame"] as Control
	var body_box: VBoxContainer = parts["body_box"] as VBoxContainer

	title_label = Label.new()
	title_label.name = "Title"
	title_label.custom_minimum_size = Vector2(0, TITLE_HEIGHT)
	title_label.text = Retreat.pre_battle_title()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 朱砂红（渡劫专属警示色）
	title_label.add_theme_color_override("font_color", Rules.COLOR_DANGER)
	body_box.add_child(title_label)

	body_label = Label.new()
	body_label.name = "Body"
	body_label.custom_minimum_size = Vector2(0, BODY_HEIGHT)
	body_label.text = Retreat.pre_battle_body()
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_color_override("font_color", Rules.COLOR_BODY)
	body_box.add_child(body_label)

	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	body_box.add_child(buttons)

	var texts: Dictionary = Retreat.pre_battle_button_texts()
	confirm_button = Button.new()
	confirm_button.name = "ConfirmButton"
	confirm_button.text = str(texts["confirm"])
	confirm_button.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	confirm_button.pressed.connect(_on_confirm_pressed)
	buttons.add_child(confirm_button)

	cancel_button = Button.new()
	cancel_button.name = "CancelButton"
	cancel_button.text = str(texts["cancel"])
	cancel_button.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	cancel_button.pressed.connect(_on_cancel_pressed)
	buttons.add_child(cancel_button)


## 打开警示弹窗（备战界面之上——[b]仅在渡劫战且未确认过时[/b]调用，
## 判定见 [method RetreatRules.should_show_pre_battle_warning]）。
func open() -> void:
	is_open = true
	visible = true
	_play_open()
	# 保守默认焦点——落在「返回」，避免误按确认进战
	cancel_button.grab_focus()


## 关闭弹窗（确认/返回共用）。
func close_dialog() -> void:
	if not is_open:
		return
	is_open = false
	_play_close()


## 弹窗是否打开。
func is_showing() -> bool:
	return is_open


## 正文文案（AC-8 断言用——GDD 明文逐字）。
func get_body_text() -> String:
	return body_label.text if body_label != null else ""


## 外框尺寸（「不覆盖全屏」断言用）。
func get_frame_size() -> Vector2:
	return frame.custom_minimum_size if frame != null else Vector2.ZERO


func _on_confirm_pressed() -> void:
	close_dialog()
	battle_confirmed.emit()


func _on_cancel_pressed() -> void:
	close_dialog()
	battle_cancelled.emit()


func _play_open() -> void:
	_fade.play_open(self, reduce_motion)


func _play_close() -> void:
	_fade.play_close(self, reduce_motion)


func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		_apply_fonts()
	elif what == NOTIFICATION_PREDELETE:
		_fade.kill()


## 响应式字号下发（[SettlementFrame.apply_font] 唯一入口——本 story 不内联字号缩放）。
func _apply_fonts() -> void:
	var h: int = Frame.viewport_height(self)
	Frame.apply_font(title_label, TITLE_BASE_SIZE, h)
	Frame.apply_font(body_label, BODY_BASE_SIZE, h)
	Frame.apply_font(confirm_button, BODY_BASE_SIZE, h)
	Frame.apply_font(cancel_button, BODY_BASE_SIZE, h)
