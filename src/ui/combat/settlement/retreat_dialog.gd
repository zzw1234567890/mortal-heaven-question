class_name RetreatDialog
extends Control
## RetreatDialog —— 撤退确认面板（普通/渡劫双变体，combat-ui-layout Story 008）。
##
## [b]职责[/b]：撤退确认弹窗本体——标题 / 后果说明 / 渡劫专属警示 / 确认+继续战斗
## 按钮，两变体由 [param is_tribulation] 一处开关切换（标题/正文/警示/边框色）。
## 判定与文案全部委托 [RetreatRules]（Logic 内核）；外框由 [SettlementFrame] 构建。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本面板不读 GSM、不执行撤退——确认时只发
## [signal retreat_confirmed]，实际 [code]CombatSystem.confirm_retreat()[/code] 调用
## 与 [code]retreat_confirmed[/code] 持久写入归 interaction epic（Out of Scope）。[br]
## [br][b]零轮询[/b]（ADR-0031 §3）：无 [code]_process()[/code]；开合为 Tween。[br]
## [br][b]不覆盖全屏[/b]（control-manifest Required）：外框固定 560×300 居中，
## 遮罩只做视觉隔离。[br]
##
## @experimental
## 来源: ADR-0031、design/gdd/combat-ui-system.md §10 撤退确认（2026-07-24 修订）、
## combat-ui-layout Story 008（AC-6/AC-7/AC-9）。

const Rules := preload("res://src/ui/combat/shared/settlement_rules.gd")
const Retreat := preload("res://src/ui/combat/shared/retreat_rules.gd")
const Frame := preload("res://src/ui/combat/settlement/settlement_frame.gd")
const Fade := preload("res://src/ui/combat/settlement/settlement_fade.gd")

## === 信号 =================================================================

## 确认撤退（实际撤退执行归 interaction epic）。
signal retreat_confirmed()
## 继续战斗（关闭弹窗，无副作用）。
signal retreat_cancelled()
## 弹窗已关闭（[method close_dialog] 的唯一出口——与业务信号区分开）。[br]
## [br][b]为什么单开这条[/b]：关闭的触发点有三个（确认 / 继续战斗 / Esc 退层），
## 而「关掉之后要做什么」（把键盘焦点还给打开前的控件）与「玩家选了什么」无关——
## 挂在本信号上，三条路径一次覆盖。
signal dialog_closed()

## === 尺寸（px——1920×1080 基准）=============================================

const PANEL_WIDTH: float = 560.0
const PANEL_HEIGHT: float = 300.0
const TITLE_HEIGHT: float = 40.0
const BUTTON_WIDTH: float = 150.0
const BUTTON_HEIGHT: float = 38.0
const TITLE_BASE_SIZE: int = 22
const BODY_BASE_SIZE: int = 15

## === 状态 =================================================================

## 当前是否渡劫变体。
var is_tribulation: bool = false
## 减少动态偏好（开合动画直跳终态）。
var reduce_motion: bool = false
## 面板是否打开。
var is_open: bool = false

## === 控件 =================================================================

var title_label: Label = null
var body_label: Label = null
## 渡劫专属警示行（朱砂红——普通变体隐藏）。
var warning_label: Label = null
var confirm_button: Button = null
var cancel_button: Button = null
## 外框（[SettlementFrame] 构建）。
var frame: Control = null

## 开合动画驱动（[SettlementFade] 实例）。
var _fade: SettlementFade = Fade.new()


func _init() -> void:
	name = "RetreatDialog"
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	visible = false


func _build() -> void:
	var parts: Dictionary = Frame.build(self, Vector2(PANEL_WIDTH, PANEL_HEIGHT))
	frame = parts["frame"] as Control
	var body_box: VBoxContainer = parts["body_box"] as VBoxContainer

	title_label = Label.new()
	title_label.name = "Title"
	title_label.custom_minimum_size = Vector2(0, TITLE_HEIGHT)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", Rules.COLOR_TITLE)
	body_box.add_child(title_label)

	warning_label = Label.new()
	warning_label.name = "Warning"
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# 朱砂红——渡劫撤退专属（AC-7，不与普通变体混用）
	warning_label.add_theme_color_override("font_color", Rules.COLOR_DANGER)
	warning_label.visible = false
	body_box.add_child(warning_label)

	body_label = Label.new()
	body_label.name = "Body"
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL

	body_label.add_theme_color_override("font_color", Rules.COLOR_BODY)
	body_box.add_child(body_label)

	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	body_box.add_child(buttons)

	confirm_button = Button.new()
	confirm_button.name = "ConfirmButton"
	confirm_button.text = Retreat.TEXT_RETREAT_CONFIRM
	confirm_button.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	confirm_button.pressed.connect(_on_confirm_pressed)
	buttons.add_child(confirm_button)

	cancel_button = Button.new()
	cancel_button.name = "CancelButton"
	cancel_button.text = Retreat.TEXT_RETREAT_CANCEL
	cancel_button.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	cancel_button.pressed.connect(_on_cancel_pressed)
	buttons.add_child(cancel_button)


## 打开撤退确认弹窗。[br]
## [param p_is_tribulation]: 是否渡劫战（切换红框 + 80% 文案变体）。[br]
## [param binding_card_count]: 已阵亡角色的绑定卡张数（>0 时正文补具体数字）。
func open(p_is_tribulation: bool, binding_card_count: int = 0) -> void:
	is_tribulation = p_is_tribulation
	title_label.text = Retreat.retreat_title(is_tribulation)
	# 渡劫变体：标题同样走朱砂红（红框 + 红标题成套）
	title_label.add_theme_color_override("font_color",
			Rules.COLOR_DANGER if is_tribulation else Rules.COLOR_TITLE)
	var warning_lines: Array = Retreat.retreat_warning_lines(is_tribulation)
	warning_label.text = "\n".join(warning_lines)
	warning_label.visible = not warning_lines.is_empty()
	body_label.text = "\n".join(Retreat.retreat_lines(is_tribulation,
			binding_card_count))
	Frame.set_border_color(frame, Retreat.retreat_border_color(is_tribulation))
	is_open = true
	visible = true
	_play_open()
	# 默认焦点落在「继续战斗」（保守默认——避免误按确认撤退）
	cancel_button.grab_focus()


## 关闭弹窗（确认/取消共用）。
func close_dialog() -> void:
	if not is_open:
		return
	is_open = false
	_play_close()
	dialog_closed.emit()


## 面板是否打开。
func is_showing() -> bool:
	return is_open


## 当前边框色（变体断言用）。
func get_border_color() -> Color:
	return Retreat.retreat_border_color(is_tribulation)


## 外框尺寸（「不覆盖全屏」断言用）。
func get_frame_size() -> Vector2:
	return frame.custom_minimum_size if frame != null else Vector2.ZERO


func _on_confirm_pressed() -> void:
	close_dialog()
	retreat_confirmed.emit()


func _on_cancel_pressed() -> void:
	close_dialog()
	retreat_cancelled.emit()


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
	Frame.apply_font(warning_label, BODY_BASE_SIZE, h)
	Frame.apply_font(body_label, BODY_BASE_SIZE, h)
	Frame.apply_font(confirm_button, BODY_BASE_SIZE, h)
	Frame.apply_font(cancel_button, BODY_BASE_SIZE, h)
