extends Control
## PauseMenuConfirm —— 暂停菜单的二次确认弹窗（GAP-5 无障碍要求）。[br]
## [br][b]为什么需要[/b]：「保存并退出」与「返回主菜单」都是[b]不可逆[/b]动作
## （前者结束本次会话、后者丢掉未保存的进度）。无障碍检查表要求两者均需二次确认
## ——为认知障碍 / 手滑玩家提供容错（design/ux/pause-menu.md §Accessibility
## 「确认弹窗防误触」）。[br]
## [br][b]ESC 可取消 + 焦点默认落在「取消」上[/b]：这是本条要求的核心——误开的弹窗
## 必须能用一个键退出去，且[b]回车不会直接执行危险动作[/b]（默认焦点在保守一侧，
## 同 [RetreatDialog] 的「默认焦点落在继续战斗」先例）。[br]
## [br][b]纯代码构建[/b]：与 [LoadSlotPanel] 同源口径——自建遮罩 + 自建面板，
## 不用 [AcceptDialog]（它的内容区归引擎排布，与自定义控件争位置）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本模块不存档、不转场、不读 GSM
## ——按下的按钮只经 [signal outcome_chosen] 报出去，动作归 [PauseMenu] 那条链。[br]
## [br][b]文案本地化豁免[/b]：与 [PauseMenuActions] 各 [code]TEXT_*[/code] 同源口径
## （项目暂无本地化系统）。[br]
##
## 来源: design/ux/pause-menu.md（§保存并退出确认弹窗 / §返回主菜单确认弹窗 /
## §Accessibility 确认弹窗防误触）、ADR-0031 §1/§2、.claude/rules/ui-code.md。

## 确认类型（弹窗标题与正文按此切换）。
const TYPE_SAVE_AND_EXIT: int = 0
const TYPE_RETURN_TO_MENU: int = 1

## 结果取值——确认 / 离开 / 取消（取消按钮与 ESC 同值）。
const OUTCOME_SAVE_EXIT: int = 0
const OUTCOME_LEAVE: int = 1
const OUTCOME_CANCEL: int = 2

const TEXT_TITLE_SAVE_EXIT: String = "保存并退出？"
const TEXT_TITLE_RETURN: String = "⚠ 返回主菜单？"
const TEXT_BODY_SAVE_EXIT: String = "当前进度将被保存。\n下次可通过「继续游戏」恢复。"
const TEXT_BODY_RETURN: String = "未保存的进度将丢失。"
## 战斗中的额外提示（UX 规格 §返回主菜单确认弹窗）。
const TEXT_COMBAT_WARNING: String = "当前战斗进度将丢失——视为战败。"
const TEXT_CONFIRM_SAVE_EXIT: String = "确认保存"
const TEXT_LEAVE: String = "不保存"
## 「不保存」的实际语义是「不以存档成功为前提直接离开」——自动存档仍会顺手存一次底
## （design/ux/pause-menu.md §退出点表）。按钮文案取规格原文。
const TEXT_LEAVE_TOOLTIP: String = "直接返回主菜单（会顺手存一次底）"
const TEXT_CANCEL: String = "取消"

## 面板尺寸（与暂停面板同宽——视觉上是同一列东西叠了一层）。
const PANEL_SIZE: Vector2 = Vector2(360, 180)
const BUTTON_SIZE: Vector2 = Vector2(150, 40)

## 玩家按下某个结果按钮。[br]
## [param outcome] 取值见 [constant OUTCOME_SAVE_EXIT] / [constant OUTCOME_LEAVE] /
## [constant OUTCOME_CANCEL]（取消按钮与 ESC 走同一条路——宿主只需处理一种取消）。
signal outcome_chosen(outcome: int)

## 当前确认类型（[constant TYPE_SAVE_AND_EXIT] / [constant TYPE_RETURN_TO_MENU]）。
var _type: int = TYPE_SAVE_AND_EXIT
## 弹窗是否打开。
var _is_open: bool = false

var _title_label: Label = null
var _body_label: Label = null
var _warning_label: Label = null
var _confirm_button: Button = null
var _leave_button: Button = null
var _cancel_button: Button = null
## 面板内的竖列容器（[method _build] 末尾才有值——[method _make_label] 靠它挂标签）。
var _box: VBoxContainer = null


func _init() -> void:
	name = "PauseMenuConfirm"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# STOP：弹窗开着时点击不该穿透到遮罩（否则点空白处会「继续游戏」）
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


## 打开弹窗。[br]
## [br][param p_type] 确认类型。[br]
## [param p_is_combat] 是否战斗中（「返回主菜单」补一句战败提示）。[br]
## [br][b]焦点默认落在「取消」[/b]：回车不会直接执行危险动作（无障碍要求）。
func open(p_type: int, p_is_combat: bool = false) -> void:
	_type = p_type
	_title_label.text = TEXT_TITLE_SAVE_EXIT if p_type == TYPE_SAVE_AND_EXIT \
			else TEXT_TITLE_RETURN
	_body_label.text = TEXT_BODY_SAVE_EXIT if p_type == TYPE_SAVE_AND_EXIT \
			else TEXT_BODY_RETURN
	# 战斗提示只在「返回主菜单」变体出现（保存并退出在战斗中被隐藏——不出现即可）
	_warning_label.text = TEXT_COMBAT_WARNING
	_warning_label.visible = p_type == TYPE_RETURN_TO_MENU and p_is_combat
	# 「不保存」只在返回主菜单变体出现；保存并退出只有确认 / 取消两键
	_leave_button.visible = p_type == TYPE_RETURN_TO_MENU
	_is_open = true
	visible = true
	_cancel_button.grab_focus()


## 关闭弹窗（确认 / 离开 / 取消三条路共用）。
func close() -> void:
	_is_open = false
	visible = false


## 是否处于打开态。
func is_open() -> bool:
	return _is_open


## 当前确认类型（宿主与测试查询用）。
func confirm_type() -> int:
	return _type


## 「取消」按钮——ESC 亦然（宿主在 [code]_unhandled_input[/code] 里调本方法）。[br]
## [br][b]为什么要一个具名入口[/b]：ESC 走的是输入层、按钮走的是信号层，两条来源
## 必须汇到同一个出口，否则「ESC 取消」与「点取消」会各自演化出不同语义。
func cancel() -> void:
	if not _is_open:
		return
	close()
	outcome_chosen.emit(OUTCOME_CANCEL)


# ═══════════════════════════════════════════════════════════════════════════════
# 构建
# ═══════════════════════════════════════════════════════════════════════════════

## 构建：遮罩 + 居中面板（标题 + 正文 + 提示 + 按钮行）。[br]
## [br][b]遮罩独立于暂停菜单的模糊层[/b]：弹窗要在菜单之上再压一层暗度，
## 否则按钮行与下面的菜单按钮看起来是同一层（层级读不出来）。
func _build() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := Panel.new()
	panel.name = "Panel"
	# 居中固定尺寸：锚点全在中心，四条偏移对称展开（不用 size + 预设双重定位，
	# 那两套口径会互相覆盖，最终尺寸取决于谁后写）
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -PANEL_SIZE.x / 2.0
	panel.offset_top = -PANEL_SIZE.y / 2.0
	panel.offset_right = PANEL_SIZE.x / 2.0
	panel.offset_bottom = PANEL_SIZE.y / 2.0
	add_child(panel)

	var box := VBoxContainer.new()
	box.name = "VBox"
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 16.0
	box.offset_top = 12.0
	box.offset_right = -16.0
	box.offset_bottom = -12.0
	box.add_theme_constant_override(&"separation", 6)
	panel.add_child(box)
	_box = box

	_title_label = _make_label("TitleLabel", 18)
	_body_label = _make_label("BodyLabel", 14)
	_warning_label = _make_label("WarningLabel", 13)
	# 朱砂红——与「返回主菜单」危险按钮同一编码（不靠颜色单独传达，另有 ⚠ 与文案）
	_warning_label.add_theme_color_override(&"font_color", Color("#B3424A"))
	_warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override(&"separation", 8)
	box.add_child(buttons)

	# 按钮顺序刻意是「危险 → 次危险 → 取消」：取消在最右，与焦点默认同侧
	_confirm_button = _make_button("ConfirmButton", TEXT_CONFIRM_SAVE_EXIT)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	buttons.add_child(_confirm_button)

	_leave_button = _make_button("LeaveButton", TEXT_LEAVE)
	_leave_button.tooltip_text = TEXT_LEAVE_TOOLTIP
	_leave_button.pressed.connect(_on_leave_pressed)
	buttons.add_child(_leave_button)

	_cancel_button = _make_button("CancelButton", TEXT_CANCEL)
	_cancel_button.pressed.connect(cancel)
	buttons.add_child(_cancel_button)


func _make_label(p_name: String, p_font_size: int) -> Label:
	var label := Label.new()
	label.name = p_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", p_font_size)
	_box.add_child(label)
	return label


func _make_button(p_name: String, p_text: String) -> Button:
	var button := Button.new()
	button.name = p_name
	button.text = p_text
	button.custom_minimum_size = BUTTON_SIZE
	button.focus_mode = Control.FOCUS_ALL
	return button


func _on_confirm_pressed() -> void:
	close()
	outcome_chosen.emit(OUTCOME_SAVE_EXIT)


func _on_leave_pressed() -> void:
	close()
	outcome_chosen.emit(OUTCOME_LEAVE)
