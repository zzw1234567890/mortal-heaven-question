class_name MapClearPanelScreen
extends Control
## MapClearPanelScreen —— 地图通关结算面板（Boss 战胜利后的 overlay，纯代码构建）。[br]
## [br][b]职责[/b]：把 [code]MapClearView[/code] 的结算载荷渲染成 GDD §7 的四段——
## 标题「地图通关！」/ 地图名与通关次数 / 「📦 通关奖励」/ 「⭐ 首次通关奖励」
## （金色边框，仅首通）——并把唯一出口「确认」发出去（[signal confirmed]）。[br]
## [br][b]为什么是 overlay 而不是新场景[/b]：GDD §7 说的是「Boss击败后弹出结算面板」，
## 而「回到地图选择」的出口本就摆在眼前——Boss 胜利的转场目的地是探索场景，底下的
## 地图选择界面从一开始就在。新开一个 SceneID 会多一条场景切换、多一份跨场景状态，
## 而这里只需要叠一层（同商店/打坐 overlay 先例）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：面板不读 GSM、不算奖励、不写任何状态——
## [method present] 收到的字典里所有数字都已算好并[b]已发放[/b]；「确认之后去哪儿」由
## [MapClearPresenter] 决定。「UI 零数值计算」同源：文案由
## [code]MapClearPanelRules[/code] 纯函数拼好，面板只决定怎么摆。[br]
## [br][b]键盘/手柄导航[/b]（.claude/rules/ui-code.md）：复用 [ShopPanelNavigator]。
## 游标的行数组是[b]本面板自己持有的卡牌按钮[/b]而不是 [code]item_box[/code] 的子节点
## ——布局把每个卡牌行包进了 [MarginContainer]（缩进），而游标对非 [Button] 的行一律
## 跳过，直接喂容器子节点会让卡牌在键盘路径上永远不可选。[br]
## [br][b]事件层级 = _input[/b]：与商店/打坐面板同源理由——焦点落在 [Button] 上时引擎
## 内置的焦点导航会在 GUI 阶段吃掉方向键，[code]_unhandled_key_input[/code] 收不到；
## [code]_input[/code] 排在 GUI 派发之前。消费走 [method Viewport.set_input_as_handled]，
## 顺带挡住 [code]InputManager[/code] 的 Esc → 暂停菜单。[br]
## [br][b]文案本地化豁免[/b]：与 node_interaction_rules / settlement_rules 同源口径。[br]
##
## 来源: design/gdd/exploration-ui-system.md §7 地图通关结算（含 4 条 AC）、
## design/gdd/exploration-system.md §5、ADR-0014 §决策 5、ADR-0031 §2/§4、
## .claude/rules/ui-code.md、先例 [code]meditation_panel_screen.gd[/code]。

## 玩家点了「确认」——唯一出口（面板不自己导航，由 Presenter 决定去哪儿）。
signal confirmed

## 文案内核（段与行的唯一实现）与控件树构建。
const Rules := preload("res://src/ui/exploration/map_clear_panel_rules.gd")
const LayoutScript := preload("res://src/ui/exploration/map_clear_panel_layout.gd")
## 键盘/手柄游标（纯逻辑，不碰控件树——与商店/打坐/采集/炼制共用同一实现）。
const NavigatorScript := preload("res://src/ui/exploration/shop_panel_navigator.gd")

## 结算载荷不可读时的正文（不臆造数值，给可读的失败形态）。
const TEXT_UNAVAILABLE: String = "结算数据不可读——本次通关奖励已直接入账。"

var _title_label: Label = null
var _map_label: Label = null
var _item_box: VBoxContainer = null
var _message_label: Label = null
var _confirm_button: Button = null
## 本次展示的卡牌按钮（游标的行数组——见类文档「键盘/手柄导航」）。
var _card_buttons: Array = []
## 本次展示的卡牌条目（与 [member _card_buttons] 同序，点击时取详情）。
var _card_entries: Array = []
## 段标题文本（按出现顺序——测试断言「首通行出不出现」用）与只读奖励行文本
## （灵石/修为/次数/兜底）。
var _section_titles: Array = []
var _reward_texts: Array = []
## 卡牌详情提供者 [code]func(entry: Dictionary) -> Dictionary[/code]（可空——
## 缺省只用载荷字段，不臆造描述文本）；键盘/手柄游标。
var detail_provider: Callable = Callable()
var _navigator: RefCounted = null


func _init() -> void:
	name = "MapClearPanel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_layout()
	_navigator = NavigatorScript.new()
	_navigator.call(&"bind", _rows, _activate_row, _request_confirm)
	_navigator.connect(&"focus_changed", _on_focus_changed)


# ═══════════════════════════════════════════════════════════════════════════════
# 对外
# ═══════════════════════════════════════════════════════════════════════════════

## 上架一次通关结算。[br]
## [br][param p_view] 结算载荷（[code]MapClearView[/code] 的键，缺失按 0 / 空处理）。[br]
## [br][b]空载荷不臆造[/b]：没有可展示的结算时走 [constant TEXT_UNAVAILABLE]、只留
## 「确认」按钮——玩家仍能退出去，不会卡在一个空面板里。[br]
## [br][b]重复通关没有首通行[/b]：判据是 [code]MapClearPanelRules.shows_first_section[/code]
## （读载荷的 [code]is_first_clear[/code]），GDD §7 明文要求。[br]
## [br][b]两段分开画[/b]：基础卡与首通卡各成一段——合并后玩家看不出哪张是首通彩头。
func present(p_view: Dictionary) -> void:
	_title_label.text = Rules.title()
	_clear_entries()
	if p_view == null or p_view.is_empty():
		_show_message(TEXT_UNAVAILABLE)
		_navigator.call(&"reset")
		return
	_map_label.text = Rules.map_name(p_view)
	_add_status_line(Rules.clear_count_text(p_view))
	# 「下一张去哪」——无论这一局有没有奖励都要给（重复刷图的玩家更需要它）
	_add_status_line(Rules.next_map_text(p_view), true)
	if not Rules.has_any_reward(p_view):
		_add_status_line(Rules.TEXT_NOTHING)
		_navigator.call(&"reset")
		return
	_fill_sections(p_view)
	_navigator.call(&"reset")


## 回填一条结果文案（测试/宿主用——文案由调用方给出，面板不自行措辞）。
func show_message(p_message: String) -> void:
	_show_message(p_message)


# === 查询（测试断言用——不触及内部控件路径）==================================

## 标题文本（GDD §7 首行）/ 地图名文本（标题行右侧）。
func title_text() -> String:
	return _title_label.text


func map_text() -> String:
	return _map_label.text


## 段标题列表（按出现顺序——首通行在不在，看它有没有第二项）/ 只读奖励行文本
## （次数行 / 无奖励兜底）。
func section_titles() -> Array:
	return _section_titles.duplicate()


func reward_texts() -> Array:
	return _reward_texts.duplicate()


## 卡牌行文本（基础段在前、首通段在后，与 [member _card_buttons] 同序）。
func card_texts() -> Array:
	var out: Array = []
	for button: Variant in _card_buttons:
		out.append((button as Button).text)
	return out


## 展示中的卡牌张数 / 是否展示了「⭐ 首次通关奖励」段（GDD §7：非首次不显示）。
func card_count() -> int:
	return _card_buttons.size()


func is_first_section_shown() -> bool:
	return _section_titles.has(Rules.TEXT_FIRST_SECTION)


## 第 [param p_index] 行卡牌的边框是否为金色（首通行的可视化判据）。
func is_card_gold(p_index: int) -> bool:
	if p_index < 0 or p_index >= _card_buttons.size():
		return false
	var button: Button = _card_buttons[p_index]
	var style: StyleBox = button.get_theme_stylebox(&"normal")
	return style is StyleBoxFlat \
			and (style as StyleBoxFlat).border_color == LayoutScript.FIRST_CLEAR_BORDER_COLOR


## 当前详情/提示文案（不可见时为空串）。
func message_text() -> String:
	return _message_label.text if _message_label.visible else ""


## 键盘/手柄游标当前所在行（-1 = 无可选行）。
func focused_index() -> int:
	return int(_navigator.call(&"focus_index"))


## 确认按钮文本。
func confirm_text() -> String:
	return _confirm_button.text


## 测试用：按下「确认」/ 点开第 [param p_index] 张奖励卡牌（不依赖真实输入事件）。
func press_confirm() -> void:
	if _confirm_button != null:
		_confirm_button.emit_signal(&"pressed")


func press_card(p_index: int) -> void:
	if p_index < 0 or p_index >= _card_buttons.size():
		return
	(_card_buttons[p_index] as Button).emit_signal(&"pressed")


# ═══════════════════════════════════════════════════════════════════════════════
# 键盘 / 手柄导航（见类文档「事件层级 = _input」）
# ═══════════════════════════════════════════════════════════════════════════════

## 输入事件——上下选卡 / 确认出口 / 取消出口，未映射的动作原样放行。[br]
## [br][b]「确认」按钮保有焦点时不吃确认键[/b]：此时 Enter 应触发那个按钮本身
## （玩家用 Tab/鼠标把焦点放过去，意图明确），游标确认让位。[br]
## [br][b]取消键等同确认[/b]：本面板只有一个出口（GDD §7「点击确认→返回地图选择」），
## 取消没有第二个去处，让它等同于确认比让按键无响应更不困惑。
func _input(p_event: InputEvent) -> void:
	if _confirm_has_focus() and p_event.is_action_pressed(&"ui_accept"):
		return
	if not bool(_navigator.call(&"handle_event", p_event)):
		return
	get_viewport().set_input_as_handled()


## 游标变化——把键盘焦点搬到新行（行数组就是卡牌按钮，非可点行天然不在其中）。
func _on_focus_changed(p_index: int) -> void:
	if p_index < 0 or p_index >= _card_buttons.size():
		return
	var button: Button = _card_buttons[p_index]
	if button != null and is_instance_valid(button) and not button.disabled:
		button.grab_focus()


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 构建控件树（遮罩 + 居中面板 + 标题 + 地图名 + 行列表 + 详情 + 确认）。[br]
## [br][b]引用不按控件路径查找[/b]：容器层级是构建细节，路径会随布局改动碎掉。
func _build_layout() -> void:
	var parts: Dictionary = LayoutScript.build(self, Rules.title(), &"confirmed",
			Rules.TEXT_CONFIRM)
	_title_label = parts.get("title_label")
	_map_label = parts.get("map_label")
	_item_box = parts.get("item_box")
	_message_label = parts.get("message_label")
	_confirm_button = parts.get("leave_button")


## 填充两个奖励段（基础 / 首通）——段与行的排版在 [code]MapClearPanelLayout[/code]，
## 本方法只把画好的行登记进游标（[member _card_buttons] 是游标的行数组）。
func _fill_sections(p_view: Dictionary) -> void:
	var filled: Dictionary = LayoutScript.fill_sections(_item_box, p_view, Rules,
			Callable(self, &"_on_card_pressed"))
	_section_titles = filled.get("titles", [])
	_card_buttons = filled.get("buttons", [])
	_card_entries = filled.get("entries", [])


## 追加一行只读文本并登记（次数行 / 下一张引导 / 无奖励兜底）。[br]
## [br][param p_next] true 走「下一张」样式（金色，排版归 Layout）。
func _add_status_line(p_text: String, p_next: bool = false) -> void:
	if p_text.strip_edges().is_empty():
		return
	if p_next:
		LayoutScript.add_next_line(_item_box, p_text)
	else:
		LayoutScript.add_status_line(_item_box, p_text)
	_reward_texts.append(p_text)


## 点开一张奖励卡牌——详情行取 [member detail_provider]（缺省只用载荷字段）。[br]
## [br][b]为什么详情落在提示区而不是新开弹窗[/b]：结算面板本身就是一层 overlay，
## 再叠一层弹窗会让「关掉详情」与「关掉面板」两个退出语义打架；详情是只读文本，
## 就地展开即可（GDD §7 只要求「点击奖励卡牌可查看详情」）。
func _on_card_pressed(p_index: int) -> void:
	if p_index < 0 or p_index >= _card_entries.size():
		return
	var extra: Dictionary = {}
	if detail_provider.is_valid():
		var raw: Variant = detail_provider.call(_card_entries[p_index])
		if raw is Dictionary:
			extra = raw
	var lines: Array = Rules.card_detail_lines(_card_entries[p_index], extra)
	var parts: Array = []
	for line: Variant in lines:
		parts.append(str(line))
	_show_message("\n".join(PackedStringArray(parts)))


## 请求确认（「确认」按钮 / 游标确认 / 取消键）。
func _request_confirm() -> void:
	confirmed.emit()


## 行数组（游标的取数口——[b]就是卡牌按钮[/b]，见类文档「键盘/手柄导航」）。
func _rows() -> Array:
	return _card_buttons.duplicate()


## 游标确认——复用按钮自身的 [signal Button.pressed]（鼠标与键盘一条实现）。
func _activate_row(p_index: int) -> void:
	press_card(p_index)


## 「确认」按钮是否持有键盘焦点（未挂载时为 false——不臆造）。
func _confirm_has_focus() -> bool:
	return _confirm_button != null and is_instance_valid(_confirm_button) \
			and _confirm_button.has_focus()


## 清空全部行（重复上架时先清——同时只展示一份结算）。
func _clear_entries() -> void:
	for child: Node in _item_box.get_children():
		_item_box.remove_child(child)
		child.queue_free()
	_card_buttons.clear()
	_card_entries.clear()
	_section_titles.clear()
	_reward_texts.clear()
	_show_message("")


func _show_message(p_text: String) -> void:
	_message_label.text = p_text
	_message_label.visible = not p_text.strip_edges().is_empty()
