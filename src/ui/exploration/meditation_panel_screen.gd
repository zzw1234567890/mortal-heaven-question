class_name MeditationPanelScreen
extends Control
## MeditationPanelScreen —— 打坐/洞府节点的突破 overlay（纯代码构建 UI）。[br]
## [br][b]职责[/b]：把 [code]ExplorationBreakthrough.status[/code] 给出的状态渲染成
## 「当前修为 / 所需修为 / 失败代价 + 一颗尝试按钮」，把尝试意图发出去
## （[signal breakthrough_requested] / [signal leave_requested]）；结果文案由
## [method show_message] 回填。[br]
## [br][b]为什么是 overlay 而不是确认框[/b]：与采集/炼制同源——到达洞府要的是
## [b]一份可反复按的面板[/b]（失败后修为还够就能再冲），不是「确认框 → 再点一次」。
## 故与 [HarvestNodePresenter] / [CraftNodePresenter] 平级，走独立通道，
## [code]meditation[/code] 也据同在 [code]node_interaction_rules.gd[/code] 的
## [code]DISPATCH_TABLE[/code] 之外。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本面板不读境界表、不算成功率、不写 GSM
## ——[method present] 收到的状态字典已含全部数字与中文文案（含按钮上的
## 「成功率 90% · 需修为 1000」），面板只决定怎么显示；「真的扣修为升境界」由
## [MeditationNodePresenter] 调系统 API。[br]
## [br][b]UI 零数值计算[/b]：文案由 Feature 层格式化（[code]action_text[/code] /
## [code]status_lines[/code]），面板只做拼接与排版。[br]
## [br][b]键盘/手柄导航[/b]（.claude/rules/ui-code.md「所有交互元素必须同时支持
## 键盘/鼠标和手柄输入」）：复用 [ShopPanelNavigator]——它的契约就是「一组
## [Button] + 确认 + 取消」，与货架/材料列无关。状态行不是 [Button]，游标天然跳过
## （纯文本不可点，键盘不会停在没有动作的行上）。[br]
## [br][b]事件层级 = _input[/b]：与 [ShopPanelScreen] / [HarvestPanelScreen] /
## [CraftPanelScreen] 同源理由——焦点落在 [Button] 上时引擎的内置焦点导航会在 GUI
## 阶段吃掉方向键，[code]_unhandled_key_input[/code] 收不到；[code]_input[/code]
## 排在 GUI 派发之前，是唯一能拦住的层。消费走 [method Viewport.set_input_as_handled]，
## 顺带挡住 [code]InputManager[/code] 的 Esc → 暂停菜单。[br]
## [br][b]文案本地化豁免[/b]：与 node_interaction_rules / shop_panel_screen 同源口径
## （项目暂无本地化系统）。[br]
##
## 来源: design/gdd/cultivation-system.md §4/§6/§边界、docs/decisions/ADR-0010、
## ADR-0031 §2/§4、.claude/rules/ui-code.md、
## 先例 [code]craft_panel_screen.gd[/code] / [code]shop_panel_screen.gd[/code]。

## 玩家点了「尝试突破」。
signal breakthrough_requested
## 玩家点了「离开」或按了取消键。
signal leave_requested

## 控件树构建（尺寸/边距/焦点环与商店面板同源——只在一处定义）。
const LayoutScript := preload("res://src/ui/exploration/meditation_panel_layout.gd")
## 键盘/手柄游标（纯逻辑，不碰控件树——与商店/采集/炼制共用同一实现）。
const NavigatorScript := preload("res://src/ui/exploration/shop_panel_navigator.gd")

## 面板标题（洞府——与节点图上的类型词条 [code]NodeIconAtlas[/code] 同字）。
const TITLE: String = "🧘 洞府"
## 状态不可读时的正文（不臆造数值，给可读的失败形态）。
const TEXT_UNAVAILABLE: String = "此处灵气紊乱——暂时无法冲关。"

var _title_label: Label = null
## 顶部摘要标签（复用商店布局的余额位——这里显示当前修为）。
var _balance_label: Label = null
var _item_box: VBoxContainer = null
var _message_label: Label = null
var _leave_button: Button = null
## 「尝试突破」按钮（不可突破时为 null——状态行位由文本承载）。
var _attempt_button: Button = null
## 状态行数（只读文本——测试断言用）。
var _line_count: int = 0
## 键盘/手柄游标。
var _navigator: RefCounted = null


func _init() -> void:
	name = "MeditationPanel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_layout()
	_navigator = NavigatorScript.new()
	_navigator.call(&"bind", _rows, _activate_row, _request_leave)
	_navigator.connect(&"focus_changed", _on_focus_changed)


# ═══════════════════════════════════════════════════════════════════════════════
# 对外
# ═══════════════════════════════════════════════════════════════════════════════

## 上架突破状态。[br]
## [br][param p_status] [code]ExplorationBreakthrough.status[/code] 的产出——
## 面板只读其中的文本与标志位，不重算任何数值。[br]
## [br][b]不可突破时仍展示代价[/b]：成功率与失败损失是玩家决策的依据，照常显示；
## 只是把「尝试」按钮置灰（[code]can_breakthrough=false[/code]）并给出原因文案。[br]
## [br][b]文案为空时不臆造[/b]：拿不到状态（缺键）走 [constant TEXT_UNAVAILABLE]。
func present(p_status: Dictionary) -> void:
	_title_label.text = TITLE
	var lines: Array = p_status.get("status_lines", [])
	if not (lines is Array) or lines.is_empty():
		_balance_label.text = ""
		_clear_entries()
		_show_message(TEXT_UNAVAILABLE)
		_navigator.call(&"reset")
		return
	_balance_label.text = str(p_status.get("realm_name", ""))
	_clear_entries()
	for raw: Variant in lines:
		if raw is String and not (raw as String).strip_edges().is_empty():
			LayoutScript.add_status_line(_item_box, raw)
			_line_count += 1
	var enabled: bool = bool(p_status.get("can_breakthrough", false))
	if enabled or not str(p_status.get("action_text", "")).is_empty():
		_attempt_button = LayoutScript.add_action_row(_item_box,
				str(p_status.get("action_text", "")), enabled,
				func() -> void: breakthrough_requested.emit())
	_show_message(str(p_status.get("message", "")))
	_navigator.call(&"reset")


## 回填一条结果文案（突破成功/失败/被拒——文案由 Feature 层给出，面板不自行措辞）。
func show_message(p_message: String) -> void:
	_show_message(p_message)


# === 查询（测试断言用——不触及内部控件路径）==================================

## 状态行数（只读文本行）。
func line_count() -> int:
	return _line_count


## 全部状态行文本。
func line_texts() -> Array:
	var out: Array = []
	for child: Node in _item_box.get_children():
		if child is Label:
			out.append((child as Label).text)
	return out


## 「尝试突破」按钮是否可点（不可突破 / 无按钮时为 false）。
func is_attempt_enabled() -> bool:
	return _attempt_button != null and is_instance_valid(_attempt_button) \
			and not _attempt_button.disabled


## 「尝试突破」按钮文本（含成功率与所需修为——UI 零数值计算的实证）。
func attempt_text() -> String:
	return _attempt_button.text if _attempt_button != null \
			and is_instance_valid(_attempt_button) else ""


## 当前结果文案（不可见时为空串）。
func message_text() -> String:
	return _message_label.text if _message_label.visible else ""


## 顶部境界名文本。
func realm_text() -> String:
	return _balance_label.text


## 标题文本。
func title_text() -> String:
	return _title_label.text


## 键盘/手柄游标当前所在行（-1 = 无可选行）。
func focused_index() -> int:
	return int(_navigator.call(&"focus_index"))


## 测试用：按下「尝试突破」（不依赖真实输入事件；禁用时与真实按钮一致地不发意图）。
func press_attempt() -> void:
	if _attempt_button != null and is_instance_valid(_attempt_button) \
			and not _attempt_button.disabled:
		_attempt_button.emit_signal(&"pressed")


## 测试用：按下「离开」。
func press_leave() -> void:
	if _leave_button != null:
		_leave_button.emit_signal(&"pressed")


# ═══════════════════════════════════════════════════════════════════════════════
# 键盘 / 手柄导航（见类文档「事件层级 = _input」）
# ═══════════════════════════════════════════════════════════════════════════════

## 输入事件——上下选行 / 确认尝试 / 取消离开，未映射的动作原样放行。[br]
## [br][b]「离开」按钮保有焦点时不吃确认键[/b]：此时 Enter 应触发那个按钮本身
## （玩家用 Tab/鼠标把焦点放过去，意图明确），游标确认让位。
func _input(p_event: InputEvent) -> void:
	if _leave_has_focus() and p_event.is_action_pressed(&"ui_accept"):
		return
	if not bool(_navigator.call(&"handle_event", p_event)):
		return
	get_viewport().set_input_as_handled()


## 游标变化——把键盘焦点搬到新行（状态行不是 [Button]，游标只会停在行动作上）。
func _on_focus_changed(p_index: int) -> void:
	if p_index < 0 or p_index >= _item_box.get_child_count():
		return
	var button: Button = _item_box.get_child(p_index) as Button
	if button != null and not button.disabled:
		button.grab_focus()


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 构建控件树（遮罩 + 居中面板 + 标题 + 状态行 + 尝试按钮 + 文案 + 离开按钮）。[br]
## [br][b]引用不按控件路径查找[/b]：容器层级是构建细节，路径会随布局改动碎掉。
func _build_layout() -> void:
	var parts: Dictionary = LayoutScript.build(self, TITLE)
	_title_label = parts.get("title_label")
	_balance_label = parts.get("balance_label")
	_item_box = parts.get("item_box")
	_message_label = parts.get("message_label")
	_leave_button = parts.get("leave_button")


## 行数组（游标的取数口——每次现取不缓存：上架会换一批控件）。
func _rows() -> Array:
	var out: Array = []
	for child: Node in _item_box.get_children():
		out.append(child)
	return out


## 游标确认——复用按钮自身的 [signal Button.pressed]（鼠标与键盘一条实现）。
func _activate_row(p_index: int) -> void:
	press_attempt()


## 请求离开（「离开」按钮 / 取消键 / 手柄取消键）。
func _request_leave() -> void:
	leave_requested.emit()


## 「离开」按钮是否持有键盘焦点（未挂载时为 false——不臆造）。
func _leave_has_focus() -> bool:
	return _leave_button != null and is_instance_valid(_leave_button) \
			and _leave_button.has_focus()


func _clear_entries() -> void:
	for child: Node in _item_box.get_children():
		_item_box.remove_child(child)
		child.queue_free()
	_attempt_button = null
	_line_count = 0


func _show_message(p_text: String) -> void:
	_message_label.text = p_text
	_message_label.visible = not p_text.strip_edges().is_empty()
