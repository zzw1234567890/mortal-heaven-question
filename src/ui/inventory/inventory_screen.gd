class_name InventoryScreen
extends Control
## InventoryScreen —— 背包界面（纯代码构建 UI）。[br]
## [br][b]职责[/b]：把 [InventoryModel] 按分类取出的条目渲染成一列只读行，并处理
## 分类切换（点分类栏 / 方向键左右）与返回（返回按钮 / Esc）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本面板不持有物品清单、不算数量、不写存档
## ——[method refresh] 每次都向模型现要一份；模型缺失时显示中文空态而非崩溃。[br]
## [br][b]为什么读取层在 feature 层而不是这里[/b]：背包的内容是玩法数据（灵材四档 +
## 收藏卡实例），面板只负责「怎么显示」。这条分工与商店面板（[code]ExplorationShop[/code]
## 结算 / [code]ShopPanelScreen[/code] 显示）同源。[br]
## [br][b]分类切换走左/右键[/b]（[code]ui_left[/code] / [code]ui_right[/code]）：上下键
## 在本面板无事可做（条目是 Label，不是可选项），左右才是「切换分类」的自然映射；
## 键鼠与手柄都绑定了这两个默认动作，故一条实现覆盖两种设备。[br]
## [br][b]事件层级 = _input[/b]：与 [ShopPanelScreen] 同源理由——焦点落在 [Button] 上时
## 引擎的内置焦点导航会在 GUI 阶段吃掉方向键，[code]_unhandled_key_input[/code] 收不到；
## [code]_input[/code] 排在 GUI 派发之前，是唯一能拦住的层。消费走
## [method Viewport.set_input_as_handled]，顺带挡住 [code]InputManager[/code] 的
## Esc → 暂停菜单。[br]
## [br][b]为什么不用 .tscn[/b]：与商店/采集面板同源——一次性覆盖层，条目数随存档变化。[br]
## [br][b]文案本地化豁免[/b]：与 inventory_catalog / shop_panel_screen 同源口径
## （项目暂无本地化系统）。
##
## 来源: design/gdd/resource-system.md §资源表、design/gdd/card-system.md §卡牌类型、
## ADR-0031 §2/§4、.claude/rules/ui-code.md、先例 [code]shop_panel_screen.gd[/code]。

## 玩家点了「返回」或按了取消键。
signal back_requested

## 控件树构建。
const LayoutScript := preload("res://src/ui/inventory/inventory_panel_layout.gd")
## 分类表与文案（分类名/空态/角标文本的唯一来源）。
const CatalogScript := preload("res://src/feature/inventory/inventory_catalog.gd")
## 只读取数半边。
const ModelScript := preload("res://src/feature/inventory/inventory_model.gd")
## 键盘/手柄游标——条目是 Label 时它恒无游标，但「离开按钮持焦点时不吃确认键」
## 与方向键消费的语义仍复用它（一处实现，不做第二套）。
const NavigatorScript := preload("res://src/ui/exploration/shop_panel_navigator.gd")

const TEXT_TITLE: String = "🎒 背包"
const TEXT_HINT: String = "← → 切换分类，Esc 返回。"
## 模型缺失（读取层未接线 / Autoload 未就绪）时的文案——与「这一类是空的」分开：
## 前者是链路问题，后者是玩法事实，混在一句里会误导排查。
const TEXT_UNAVAILABLE: String = "行囊暂不可查——读取链路未就绪。"

var _category_button: Button = null
var _item_box: VBoxContainer = null
var _message_label: Label = null
var _leave_button: Button = null
## 当前分类下标（越界由模型判空处理——面板不替模型兜底）。
var _category_index: int = 0
## 条目数（与控件数一致——测试断言用）。
var _entry_count: int = 0
## 键盘/手柄游标（见类文档：Label 行不可选，故它恒无游标）。
var _navigator: RefCounted = null
## 只读模型（生产在装配处注入；未注入时本地 new——它自己会去找 Autoload）。
var _model: RefCounted = null


func _init() -> void:
	name = "InventoryScreen"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_layout()
	_navigator = NavigatorScript.new()
	_navigator.call(&"bind", _rows, _activate_row, _request_back)
	_navigator.connect(&"focus_changed", _on_focus_changed)


# ═══════════════════════════════════════════════════════════════════════════════
# 对外
# ═══════════════════════════════════════════════════════════════════════════════

## 注入只读模型（生产路径：装配处把已接好 Autoload 的模型交进来）。
func set_model(p_model: RefCounted) -> void:
	_model = p_model


## 刷新显示——每次都向模型现读（零缓存：刚炼成的丹药不该迟到一帧）。[br]
## [br][b]空态[/b]：[b]按分类各有一条文案[/b]（[code]InventoryCatalog.empty_text[/code]）
## ——「没有丹药」与「没有法宝」对玩家的下一步提示不同，不共用一句。[br]
## [br][b]模型缺失[/b]：显示 [constant TEXT_UNAVAILABLE]（与「这一类是空的」分开，
## 见常量注记）。
func refresh() -> void:
	var model: RefCounted = _resolve_model()
	_clear_entries()
	_entry_count = 0
	if model == null:
		_category_button.text = LayoutScript.TEXT_CATEGORY_PREFIX + TEXT_UNAVAILABLE
		_show_message(TEXT_UNAVAILABLE)
		_navigator.call(&"reset")
		return
	var entries: Array = model.call(&"category_entries", _category_index)
	LayoutScript.set_category_text(_category_button,
			str(model.call(&"category_bar_text", _category_index)))
	if entries.is_empty():
		_show_message(CatalogScript.empty_text(_category_index))
		_navigator.call(&"reset")
		return
	_show_message(TEXT_HINT)
	for raw: Variant in entries:
		if raw is Dictionary:
			LayoutScript.add_readout_row(_item_box, raw, "Entry%d" % _entry_count)
			_entry_count += 1
	_navigator.call(&"reset")


# === 查询（测试断言用——不触及内部控件路径）==================================

## 当前分类下标。
func category_index() -> int:
	return _category_index


## 当前分类中文名。
func category_name() -> String:
	return CatalogScript.category_name(_category_index)


## 分类栏文本（含角标与提示）。
func category_bar_text() -> String:
	return _category_button.text


## 当前条目行数。
func entry_count() -> int:
	return _entry_count


## 全部条目行的文本（渲染实证）。
func entry_texts() -> Array:
	var out: Array = []
	for child: Node in _item_box.get_children():
		if child is Label:
			out.append((child as Label).text)
	return out


## 当前结果/空态文案。
func message_text() -> String:
	return _message_label.text if _message_label.visible else ""


## 键盘/手柄游标当前所在行（本面板条目不可选，恒为 -1）。
func focused_index() -> int:
	return int(_navigator.call(&"focus_index"))


## 测试用：点分类栏（切到下一类）。
func press_category() -> void:
	_category_button.emit_signal(&"pressed")


## 测试用：按下「返回」。
func press_back() -> void:
	if _leave_button != null:
		_leave_button.emit_signal(&"pressed")


# ═══════════════════════════════════════════════════════════════════════════════
# 键盘导航（见类文档「事件层级 = _input」）
# ═══════════════════════════════════════════════════════════════════════════════

## 输入事件——左右切分类 / 取消返回，未映射的动作原样放行。[br]
## [br][b]分类栏按钮保有焦点时，左右键交给它自己[/b]：此时光标就停在这一行上，
## 玩家按方向键的意图指向它——面板不抢（同商店面板对「离开按钮持焦点时不吃确认键」
## 的处理）。[br]
## [br][b]消费即拦断[/b]：向上不再经过引擎焦点导航，向下挡住 [code]InputManager[/code]
## 的 Esc → 暂停菜单（[code]_input[/code] 按树序倒序派发，本面板先于 Autoload 收到）。
func _input(p_event: InputEvent) -> void:
	if _category_has_focus() \
			and (p_event.is_action_pressed(&"ui_left")
				or p_event.is_action_pressed(&"ui_right")):
		return
	if p_event.is_action_pressed(&"ui_left"):
		_move_category(-1)
		get_viewport().set_input_as_handled()
		return
	if p_event.is_action_pressed(&"ui_right"):
		_move_category(1)
		get_viewport().set_input_as_handled()
		return
	if not bool(_navigator.call(&"handle_event", p_event)):
		return
	get_viewport().set_input_as_handled()


## 切到相邻分类并刷新（下标环绕——只有三个分类，走到头绕回来比卡住更好用，
## 与游标列表的「不环绕」是不同场景：那里要能观测「到到底了」，这里不必）。
func _move_category(p_delta: int) -> void:
	var total: int = CatalogScript.category_count()
	if total <= 0:
		return
	_category_index = (_category_index + p_delta + total) % total
	refresh()


## 分类栏被点击——切到下一类（鼠标路径与键盘路径同一出口）。[br]
## [br][b]接线在本面板[/b]：布局把按钮原样交回（它不持有回调也不发信号），
## [method _init] 把它接到这里——鼠标点一下与按 → 键因此走同一个方法。
func _cycle_category() -> void:
	_move_category(1)


## 游标焦点变化——本面板没有可选行，故只在可行时搬运焦点（防御式，不臆造）。
func _on_focus_changed(p_index: int) -> void:
	if p_index < 0 or p_index >= _item_box.get_child_count():
		return
	var row: Node = _item_box.get_child(p_index)
	if row is Button and not (row as Button).disabled:
		(row as Button).grab_focus()


## 游标确认——无可选行时不做任何事（[ShopPanelNavigator.activate] 已保证）。
func _activate_row(_p_index: int) -> void:
	pass


## 请求返回（「返回」按钮 / Esc / 手柄取消键）。
func _request_back() -> void:
	back_requested.emit()


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 建控件树并接线。[br]
## [br][b]分类栏的接线在这里[/b]：布局把按钮原样交回（它不持回调、不发信号），
## 本面板自己接到 [method _cycle_category]——鼠标点与按 → 键因此走同一出口。
func _build_layout() -> void:
	var parts: Dictionary = LayoutScript.build(self, TEXT_TITLE)
	_leave_button = parts.get("leave_button")
	_item_box = parts.get("item_box")
	_message_label = parts.get("message_label")
	_category_button = parts.get("category_button")
	_category_button.pressed.connect(_cycle_category)
	_leave_button.text = LayoutScript.TEXT_BACK


## 行数组（游标的取数口——每次现取不缓存：刷新会换一批控件）。
func _rows() -> Array:
	var out: Array = []
	for child: Node in _item_box.get_children():
		out.append(child)
	return out


## 模型——注入优先，否则本地 new（它自己去找 Autoload；全缺时其读取方法返回空）。
func _resolve_model() -> RefCounted:
	if _model != null:
		return _model
	return ModelScript.new()


## 分类栏是否持有键盘焦点（未挂载时为 false——不臆造）。
func _category_has_focus() -> bool:
	return _category_button != null and is_instance_valid(_category_button) \
			and _category_button.has_focus()


func _clear_entries() -> void:
	for child: Node in _item_box.get_children():
		_item_box.remove_child(child)
		child.queue_free()


func _show_message(p_text: String) -> void:
	_message_label.text = p_text
	_message_label.visible = not p_text.strip_edges().is_empty()
