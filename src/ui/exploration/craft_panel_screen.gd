class_name CraftPanelScreen
extends Control
## CraftPanelScreen —— 炼丹台 / 炼器台的炼制 overlay（纯代码构建 UI）。[br]
## [br][b]职责[/b]：把 [code]ExplorationCraft.entries[/code] 给出的可炼清单渲染成
## 一列可点配方，并把炼制意图发出去（[signal craft_requested] /
## [signal leave_requested]）；炼制结果文案由 [method show_message] 回填。[br]
## [br][b]两个台子共用一个面板[/b]：[code]alchemy[/code] 与 [code]forge[/code] 的
## 交互形态完全一致（一列配方 + 材料持有量 + 点一下炼），差别只在标题与行的内容
## ——由 [method present] 的 [param p_kind] 决定，不复制第二份面板。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本面板不持有配方表、不判材料够不够、
## 不写 GSM——[method present] 收到的每条目已含 [code]name / rarity_name /
## cost_text / costs / enabled / reason[/code]，面板只决定怎么显示；「真的扣料入库」
## 由 [CraftNodePresenter] 调系统 API。[br]
## [br][b]不自行计算[/b]：所需与持有量都在条目里（UI 零数值计算）。[br]
## [br][b]键盘/手柄导航[/b]（.claude/rules/ui-code.md「所有交互元素必须同时支持
## 键盘/鼠标和手柄输入」）：复用 [ShopPanelNavigator]——它的契约就是「一组
## [Button] + 确认 + 取消」，与货架/材料列无关。[br]
## [br][b]事件层级 = _input[/b]：与 [ShopPanelScreen] / [HarvestPanelScreen] 同源
## 理由——焦点落在 [Button] 上时引擎的内置焦点导航会在 GUI 阶段吃掉方向键，
## [code]_unhandled_key_input[/code] 收不到；[code]_input[/code] 排在 GUI 派发之前，
## 是唯一能拦住的层。消费走 [method Viewport.set_input_as_handled]，顺带挡住
## [code]InputManager[/code] 的 Esc → 暂停菜单。[br]
## [br][b]为什么不用 .tscn[/b]：与商店/采集面板同源理由——一次性覆盖层，
## 配方条数随配方资源变化，代码构建比维护场景文件更短。[br]
## [br][b]文案本地化豁免[/b]：与 node_interaction_rules / shop_panel_screen 同源
## 口径（项目暂无本地化系统）。
##
## 来源: design/gdd/alchemy-crafting-system.md §1a/§2a/§4 炼制位置/§边界/AC-1、
## ADR-0028 §craft_pill、ADR-0031 §2/§4、.claude/rules/ui-code.md、
## 先例 [code]harvest_panel_screen.gd[/code] / [code]shop_panel_screen.gd[/code]。

## 玩家点了第 [param p_index] 道配方。
signal craft_requested(p_index: int)
## 玩家点了「离开」或按了取消键。
signal leave_requested

## 控件树构建（尺寸/边距/焦点环与商店面板同源——只在一处定义）。
const LayoutScript := preload("res://src/ui/exploration/craft_panel_layout.gd")
## 灵材品质中文名词条来源（与采集点同一张表——本面板不自建一份）。
const TableScript := preload("res://src/feature/exploration/exploration_harvest_table.gd")
## 键盘/手柄游标（纯逻辑，不碰控件树——与商店/采集共用同一实现）。
const NavigatorScript := preload("res://src/ui/exploration/shop_panel_navigator.gd")

## 各台子的标题与提示（按 [method present] 的 [param p_kind] 取）。
const TITLES: Dictionary = {
	&"alchemy": "⚗ 炼丹台",
	&"forge": "🔨 炼器台",
}
## 空清单文案。
const TEXT_EMPTY: String = "此处炉火已冷——无方可炼。"

var _title_label: Label = null
## 顶部摘要标签（复用商店布局的余额位——这里显示灵材持有量）。
var _balance_label: Label = null
var _item_box: VBoxContainer = null
var _message_label: Label = null
var _leave_button: Button = null
## 当前展示的配方行数（测试/断言用——与控件数一致）。
var _entry_count: int = 0
## 行序对应的配方下标（行序 → index——按下标取，不按控件路径）。
var _indices: Array = []
## 键盘/手柄游标。
var _navigator: RefCounted = null


func _init() -> void:
	name = "CraftPanel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_layout()
	_navigator = NavigatorScript.new()
	_navigator.call(&"bind", _rows, _activate_row, _request_leave)
	_navigator.connect(&"focus_changed", _on_focus_changed)


# ═══════════════════════════════════════════════════════════════════════════════
# 对外
# ═══════════════════════════════════════════════════════════════════════════════

## 上架可炼清单。[br]
## [br][param p_kind] 配方种类（[code]alchemy[/code] / [code]forge[/code]）。[br]
## [param p_balance] 各品质档位灵材持有量 [code]{quality: count}[/code]
## （由系统读取后传入——面板不自己查）。[br]
## [param p_entries] 条目数组（[code]ExplorationCraft.entries[/code] 的产出）。[br]
## [br][b]空列表[/b]：显示「无方可炼」而非空白面板（可读的失败形态）。[br]
## [br][b]游标复位[/b]：每次上架都把游标落到首个可选行（炼制后重上架时旧控件
## 已被移除重建，不复位会指错行）。
func present(p_kind: StringName, p_balance: Dictionary, p_entries: Array) -> void:
	_title_label.text = str(TITLES.get(p_kind, TITLES[&"alchemy"]))
	_balance_label.text = LayoutScript.balance_text(p_balance, TableScript.QUALITY_NAMES)
	_clear_entries()
	_entry_count = 0
	_indices.clear()
	if p_entries.is_empty():
		_show_message(TEXT_EMPTY)
		_navigator.call(&"reset")
		return
	_show_message(_hint_text())
	for raw: Variant in p_entries:
		if not (raw is Dictionary):
			continue
		var entry: Dictionary = raw
		LayoutScript.add_recipe_row(_item_box, entry, _entry_count, _on_entry_pressed)
		_indices.append(int(entry.get("index", _entry_count)))
		_entry_count += 1
	_navigator.call(&"reset")


## 回填一条结果文案（炼制成功/被拒——文案由系统给出，面板不自行措辞判断）。
func show_message(p_message: String) -> void:
	_show_message(p_message)


# === 查询（测试断言用——不触及内部控件路径）==================================

## 当前配方行数。
func entry_count() -> int:
	return _entry_count


## 全部配方行的按钮文本（渲染实证）。
func entry_texts() -> Array:
	var out: Array = []
	for child: Node in _item_box.get_children():
		if child is Button:
			out.append((child as Button).text)
	return out


## 某行是否可点（等级不足 / 收藏已满 / 灵材不足为 false）。
func is_entry_enabled(p_index: int) -> bool:
	var button: Button = _item_box.get_child(p_index) as Button
	return button != null and not button.disabled


## 行序 → 配方下标（-1 = 越界）。
func recipe_index_at(p_index: int) -> int:
	if p_index < 0 or p_index >= _indices.size():
		return -1
	return int(_indices[p_index])


## 当前结果文案。
func message_text() -> String:
	return _message_label.text if _message_label.visible else ""


## 顶部灵材摘要文本。
func balance_text() -> String:
	return _balance_label.text


## 标题文本（两台子共用面板的可见证据）。
func title_text() -> String:
	return _title_label.text


## 键盘/手柄游标当前所在行（-1 = 无可选行）。
func focused_index() -> int:
	return int(_navigator.call(&"focus_index"))


## 某行当前是否持有键盘焦点（焦点可见的实证）。
func is_entry_focused(p_index: int) -> bool:
	var button: Button = _item_box.get_child(p_index) as Button
	return button != null and button.has_focus()


## 测试用：按下第 [param p_index] 行（不依赖真实输入事件）。[br]
## [b]禁用行不发意图[/b]——与真实按钮行为一致。
func press_entry(p_index: int) -> void:
	var button: Button = _item_box.get_child(p_index) as Button
	if button == null or button.disabled:
		return
	button.emit_signal(&"pressed")


## 测试用：按下「离开」。
func press_leave() -> void:
	if _leave_button != null:
		_leave_button.emit_signal(&"pressed")


# ═══════════════════════════════════════════════════════════════════════════════
# 键盘 / 手柄导航（见类文档「事件层级 = _input」）
# ═══════════════════════════════════════════════════════════════════════════════

## 输入事件——上下选行 / 确认炼制 / 取消离开，未映射的动作原样放行。[br]
## [br][b]「离开」按钮保有焦点时不吃确认键[/b]：此时 Enter 应触发那个按钮本身
## （玩家用 Tab/鼠标把焦点放过去，意图明确），游标确认让位。
func _input(p_event: InputEvent) -> void:
	if _leave_has_focus() and p_event.is_action_pressed(&"ui_accept"):
		return
	if not bool(_navigator.call(&"handle_event", p_event)):
		return
	get_viewport().set_input_as_handled()


## 游标变化——把键盘焦点搬到新行。
func _on_focus_changed(p_index: int) -> void:
	if p_index < 0 or p_index >= _item_box.get_child_count():
		return
	var button: Button = _item_box.get_child(p_index) as Button
	if button != null and not button.disabled:
		button.grab_focus()


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 构建控件树（遮罩 + 居中面板 + 标题 + 持有量 + 配方列表 + 文案 + 离开按钮）。[br]
## [br][b]引用不按控件路径查找[/b]：容器层级是构建细节，路径会随布局改动碎掉。
func _build_layout() -> void:
	var parts: Dictionary = LayoutScript.build(self, str(TITLES[&"alchemy"]))
	_title_label = parts.get("title_label")
	_balance_label = parts.get("balance_label")
	_item_box = parts.get("item_box")
	_message_label = parts.get("message_label")
	_leave_button = parts.get("leave_button")


## 行被点击——发炼制意图（禁用行的按钮不会发 [signal Button.pressed]，天然被拦）。
func _on_entry_pressed(p_index: int) -> void:
	craft_requested.emit(p_index)


## 行数组（游标的取数口——每次现取不缓存：上架会换一批控件）。
func _rows() -> Array:
	var out: Array = []
	for child: Node in _item_box.get_children():
		out.append(child)
	return out


## 游标确认——复用按钮自身的 [signal Button.pressed]（鼠标与键盘一条实现）。
func _activate_row(p_index: int) -> void:
	press_entry(p_index)


## 请求离开（「离开」按钮 / 取消键 / 手柄取消键）。
func _request_leave() -> void:
	leave_requested.emit()


## 「离开」按钮是否持有键盘焦点（未挂载时为 false——不臆造）。
func _leave_has_focus() -> bool:
	return _leave_button != null and is_instance_valid(_leave_button) \
			and _leave_button.has_focus()


## 操作提示——两个台子共用同一套键位（面板形态一致，故文案也一致）。[br]
## [br][b]键位走 ui_\* 动作[/b]：键鼠与手柄都对得上，故一行文案同时覆盖两种输入
## （.claude/rules/ui-code.md 双输入）。
func _hint_text() -> String:
	return "点击即可炼制（方向键选行，回车确认，Esc 离开）。"


func _clear_entries() -> void:
	for child: Node in _item_box.get_children():
		_item_box.remove_child(child)
		child.queue_free()


func _show_message(p_text: String) -> void:
	_message_label.text = p_text
	_message_label.visible = not p_text.strip_edges().is_empty()
