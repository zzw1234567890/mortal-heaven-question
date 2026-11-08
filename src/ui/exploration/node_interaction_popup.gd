class_name NodeInteractionPopup
extends Control
## NodeInteractionPopup —— 节点交互弹窗单体（exploration-ui Story 006）。
##
## [b]职责[/b]：渲染单类弹窗（标题 / 正文 / 渡劫警示 / 确认+取消两按钮）并
## 播放大淡入淡出动画。不含分发表判定（归 [NodeInteractionRules]）、不含
## 冻结与生命周期编排（归 [NodeInteractionPopupHost]）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：只持有展示所需文案与尺寸，
## 不缓存节点状态、不访问 Autoload；确认时不改任何游戏状态，只发
## [signal confirmed] 由宿主派发。[br]
## [br][b]零轮询[/b]（ADR-0031 §3）：无 [code]_process()[/code]——开合动画
## 为 Tween（输入驱动的纯视觉变换，豁免）。[br]
## [br][b]ESC 关闭[/b]（AC-2 Edge）：弹窗持有键盘焦点时 ESC 等效取消按钮；
## 宿主另有全局兜底（[method NodeInteractionPopupHost._unhandled_key_input]）。[br]
## [br][b]文案定位[/b]：全部文案取自 [NodeInteractionRules]（数据驱动），
## 本文件不出现业务字面量。
##
## 来源: design/gdd/exploration-ui-system.md §4/§4b、ADR-0031 §2/§3、
## exploration-ui Story 006（AC-2/AC-3/AC-6）。

## === 信号 ==================================================================

## 确认——宿主据此派发确认动作（进入战斗/开商店/用灵泉/休息/渡劫）。
signal confirmed
## 取消/关闭——等效「先等等」，玩家停留该节点（AP 不回退）。
signal cancelled

## === 常量（视觉——1920×1080 基准）=========================================

const PANEL_COLOR: Color = Color(0.10, 0.11, 0.14, 0.96)
const PANEL_BORDER: Color = Color(0.55, 0.52, 0.44)
const BUTTON_WIDTH: float = 132.0
const BUTTON_HEIGHT: float = 36.0
const TEXT_LEFT: float = 18.0
const TEXT_TOP: float = 14.0
const LINE_HEIGHT: float = 22.0
const TITLE_FONT_SIZE: int = 18
const BODY_FONT_SIZE: int = 14

## === 状态 ==================================================================

## 当前弹窗种类（[constant NodeInteractionRules.KIND_*]）。
var kind: StringName = &""
## 开合 Tween 句柄（重入 kill）。
var _tween: Tween = null
## 减少动态偏好——true 时直跳终态（ADR-0031 动画偏好）。
var reduce_motion: bool = false

## === 控件 ==================================================================

var _panel: Panel = null
var _title_label: Label = null
var _body_label: Label = null
var _warning_label: Label = null
var _confirm_button: Button = null
var _cancel_button: Button = null


func _init() -> void:
	name = "NodeInteractionPopup"
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = NodeInteractionRules.POPUP_SIZE
	_build()


## 构建控件树（一次——重开只改文案不改结构）。
func _build() -> void:
	_panel = Panel.new()
	_panel.name = "Panel"
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.position = Vector2(TEXT_LEFT, TEXT_TOP)
	_title_label.size = Vector2(size.x - TEXT_LEFT * 2.0, LINE_HEIGHT + 6.0)
	_title_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	_title_label.add_theme_color_override("font_color", NodeInteractionRules.COLOR_TITLE)
	add_child(_title_label)

	_body_label = Label.new()
	_body_label.name = "Body"
	_body_label.position = Vector2(TEXT_LEFT, TEXT_TOP + LINE_HEIGHT + 10.0)
	_body_label.size = Vector2(size.x - TEXT_LEFT * 2.0, LINE_HEIGHT * 3.0)
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
	_body_label.add_theme_color_override("font_color", NodeInteractionRules.COLOR_BODY)
	add_child(_body_label)

	_warning_label = Label.new()
	_warning_label.name = "Warning"
	_warning_label.position = Vector2(TEXT_LEFT, TEXT_TOP + LINE_HEIGHT + 10.0 + LINE_HEIGHT * 2.0)
	_warning_label.size = Vector2(size.x - TEXT_LEFT * 2.0, LINE_HEIGHT * 2.0)
	_warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warning_label.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
	# 朱砂红——渡劫 80% 警示专属（不与 Boss 50% 混用）
	_warning_label.add_theme_color_override("font_color", NodeInteractionRules.COLOR_DANGER)
	_warning_label.visible = false
	add_child(_warning_label)

	_confirm_button = Button.new()
	_confirm_button.name = "ConfirmButton"
	_confirm_button.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	_confirm_button.size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	_confirm_button.position = Vector2(size.x - BUTTON_WIDTH * 2.0 - TEXT_LEFT - 12.0,
			size.y - BUTTON_HEIGHT - TEXT_TOP)
	_confirm_button.pressed.connect(func() -> void: confirmed.emit())
	add_child(_confirm_button)

	_cancel_button = Button.new()
	_cancel_button.name = "CancelButton"
	_cancel_button.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	_cancel_button.size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	_cancel_button.position = Vector2(size.x - BUTTON_WIDTH - TEXT_LEFT,
			size.y - BUTTON_HEIGHT - TEXT_TOP)
	_cancel_button.pressed.connect(func() -> void: cancelled.emit())
	add_child(_cancel_button)

	visible = false


## 按 [param p_kind] 与载荷填充文案并打开。[br]
## [param lines]: 动态正文行（战斗敌人行 / 渡劫固定行等）；为空时用分发表固定正文。
## [param warning_lines]: 朱砂红警示行（仅渡劫台——AC-6）。
func open(p_kind: StringName, lines: Array = [], warning_lines: Array = []) -> void:
	kind = p_kind
	_title_label.text = NodeInteractionRules.title_for(kind)
	var texts: Dictionary = NodeInteractionRules.button_texts(kind)
	_confirm_button.text = str(texts["confirm"])
	_cancel_button.text = str(texts["cancel"])
	var body: Array = lines if not lines.is_empty() else NodeInteractionRules.body_lines(kind)
	_body_label.text = "\n".join(body)
	_warning_label.text = "\n".join(warning_lines)
	_warning_label.visible = not warning_lines.is_empty()
	visible = true
	_play_open()
	_cancel_button.grab_focus()


## 播放打开动画（放大淡入 0.2s；reduce_motion 直跳终态）。
func _play_open() -> void:
	_kill_tween()
	# 缩放锚点在弹窗自身左上角——pivot 居中避免从角落放大
	pivot_offset = size * 0.5
	if reduce_motion:
		modulate.a = 1.0
		scale = Vector2.ONE
		return
	modulate.a = 0.0
	scale = Vector2(NodeInteractionRules.SCALE_FROM, NodeInteractionRules.SCALE_FROM)
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, NodeInteractionRules.OPEN_SEC)
	_tween.tween_property(self, "scale", Vector2.ONE, NodeInteractionRules.OPEN_SEC)


## 播放关闭动画（缩小淡出 0.15s）后隐藏；[param on_finished] 在终态回调。
func play_close(on_finished: Callable = Callable()) -> void:
	_kill_tween()
	if reduce_motion:
		visible = false
		if on_finished.is_valid():
			on_finished.call()
		return
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", 0.0, NodeInteractionRules.CLOSE_SEC)
	_tween.tween_property(self, "scale",
			Vector2(NodeInteractionRules.SCALE_FROM, NodeInteractionRules.SCALE_FROM),
			NodeInteractionRules.CLOSE_SEC)
	_tween.chain().tween_callback(func() -> void:
		visible = false
		if on_finished.is_valid():
			on_finished.call())


## 关闭并复位（宿主换弹窗/退出时调用——不留残影）。
func reset() -> void:
	_kill_tween()
	visible = false
	modulate.a = 1.0
	scale = Vector2.ONE
	kind = NodeInteractionRules.KIND_NONE


## === 内部 ==================================================================

func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_kill_tween()
