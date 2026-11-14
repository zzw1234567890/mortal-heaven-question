class_name InventoryScreen
extends Control
## InventoryScreen —— 背包界面（纯代码构建 UI）。[br]
## [br][b]职责[/b]：把 [InventoryModel] 按分类取出的条目渲染成一列[b]可选中[/b]的行，
## 并把玩家的确认意图发出去（[signal item_use_requested]）；分类切换（点分类栏 /
## 方向键左右）与返回（返回按钮 / Esc）也在这里。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本面板不持有物品清单、不算数量、不写存档
## ——[method refresh] 每次都向模型现要一份；条目本身挂在行控件的元数据上
## （[code]InventoryPanelLayout.row_payload[/code]），面板不另存「下标 → 条目」副本。[br]
## [br][b]「用丹药」为什么不在这里结算[/b]：本面板[b]不发任何系统调用[/b]——确认只发
## [signal item_use_requested]，由 [InventoryScreensHost] 交给
## [code]InventoryPillUse[/code] 结算后回填文案。理由与商店面板同源
## （[code]ShopPanelScreen[/code] 只发 [code]purchase_requested[/code]，
## 由 Presenter 调系统）：面板一旦直调系统，就会长成第二处「谁改了存档」的现场。[br]
## [br][b]分类切换走左/右键[/b]（[code]ui_left[/code] / [code]ui_right[/code]）：
## 上下键归行游标，左右切分类；键鼠与手柄都绑定了这两组默认动作。[br]
## [br][b]事件层级 = _input[/b]：与 [ShopPanelScreen] 同源理由——焦点落在 [Button] 上时
## 引擎的内置焦点导航会在 GUI 阶段吃掉方向键，[code]_unhandled_key_input[/code] 收不到；
## [code]_input[/code] 排在 GUI 派发之前，是唯一能拦住的层。消费走
## [method Viewport.set_input_as_handled]，顺带挡住 [code]InputManager[/code] 的
## Esc → 暂停菜单。[br]
## [br][b]为什么不用 .tscn[/b]：与商店/采集面板同源——一次性覆盖层，条目数随存档变化。[br]
## [br][b]文案本地化豁免[/b]：与 inventory_catalog / shop_panel_screen 同源口径。
##
## 来源: design/gdd/resource-system.md §资源表、design/gdd/card-system.md §卡牌类型、
## design/gdd/alchemy-crafting-system.md §1c（丹药使用时机「战斗中或背包」）、
## ADR-0031 §2/§4、.claude/rules/ui-code.md、先例 [code]shop_panel_screen.gd[/code]。

## 玩家确认了某一行（[param p_entry] 为该行的条目——面板不解释它是什么）。
signal item_use_requested(p_entry: Dictionary)
## 玩家点了「返回」或按了取消键。
signal back_requested

## 控件树构建。
const LayoutScript := preload("res://src/ui/inventory/inventory_panel_layout.gd")
## 分类表与文案（分类名/空态/角标文本的唯一来源）。
const CatalogScript := preload("res://src/feature/inventory/inventory_catalog.gd")
## 只读取数半边。
const ModelScript := preload("res://src/feature/inventory/inventory_model.gd")
## 键盘/手柄输入翻译（左右切分类 + 上下选行 + 确认 + 取消）。
const NavigatorScript := preload("res://src/ui/inventory/paged_panel_navigator.gd")

const TEXT_TITLE: String = "🎒 背包"
const TEXT_HINT: String = "← → 切换分类，↑ ↓ 选行，回车使用，Esc 返回。"
## 模型缺失（读取层未接线 / Autoload 未就绪）时的文案——与「这一类是空的」分开：
## 前者是链路问题，后者是玩法事实，混在一句里会误导排查。
const TEXT_UNAVAILABLE: String = "行囊暂不可查——读取链路未就绪。"

var _category_button: Button = null
var _item_box: VBoxContainer = null
var _detail_box: VBoxContainer = null
var _message_label: Label = null
var _leave_button: Button = null
## 当前分类下标（越界由模型判空处理——面板不替模型兜底）。
var _category_index: int = 0
## 条目数（与控件数一致——测试断言用）。
var _entry_count: int = 0
## 键盘/手柄输入翻译（见类文档）。
var _navigator: RefCounted = null
## 只读模型（生产在装配处注入；未注入时本地 new——它自己会去找 Autoload）。
var _model: RefCounted = null


func _init() -> void:
	name = "InventoryScreen"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_layout()
	_navigator = NavigatorScript.new()
	_navigator.call(&"bind", _rows, _activate_row, _request_back, _move_category)
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
## 见常量注记）。[br]
## [br][b]游标复位[/b]：每次刷新都把游标落到首个可选行——用掉一枚丹药后该行可能消失，
## 停在旧下标上会指向别的物品。[br]
## [br][b]清空详情区[/b]：刷新换了一批控件，旧的详情文本会指着一件已经不在的东西。
func refresh() -> void:
	var model: RefCounted = _resolve_model()
	_clear_entries()
	_entry_count = 0
	_clear_detail()
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
	# 条目行按载荷渲染（条目本身即载荷——确认时面板拿回来的就是它，见 [method _activate_row]）。
	for raw: Variant in entries:
		if raw is Dictionary:
			LayoutScript.add_readout_row(_item_box, raw, "Entry%d" % _entry_count,
					_on_row_pressed)
			_entry_count += 1
	_navigator.call(&"reset")


## 回填一条结果文案（用丹药/被拒——文案由结算层给出，面板不自行措辞判断）。[br]
## [br]枚举条目的按钮把「用得成用不成」都交给系统；面板只负责把系统给的句子
## 显示出来（与 [code]ShopPanelScreen.show_message[/code] 同口径）。
func show_message(p_message: String) -> void:
	_show_message(p_message)


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
		out.append(LayoutScript.row_text(child))
	return out


## 当前结果/空态文案。
func message_text() -> String:
	return _message_label.text if _message_label.visible else ""


## 键盘/手柄游标当前所在行（-1 = 无可选行）。
func focused_index() -> int:
	return int(_navigator.call(&"focus_index"))


## 某行当前是否持有键盘焦点（焦点可见的实证——不只读游标的内部状态）。
func is_row_focused(p_index: int) -> bool:
	var row: Node = _row_at(p_index)
	return row is Button and (row as Button).has_focus()


## 测试用：点分类栏（切到下一类）。
func press_category() -> void:
	_category_button.emit_signal(&"pressed")


## 测试用：按下「返回」。
func press_back() -> void:
	if _leave_button != null:
		_leave_button.emit_signal(&"pressed")


## 测试用：确认第 [param p_index] 行（不依赖真实输入事件）。[br]
## [br][b]越界/空列表是安全的空操作[/b]：没有行可确认时什么也不发生（不崩）。
func press_row(p_index: int) -> void:
	var row: Node = _row_at(p_index)
	if row is Button:
		(row as Button).emit_signal(&"pressed")


# ═══════════════════════════════════════════════════════════════════════════════
# 键盘导航（见类文档「事件层级 = _input」）
# ═══════════════════════════════════════════════════════════════════════════════

## 输入事件——左右切分类 / 上下选行 / 回车确认 / 取消返回，其余原样放行。
func _input(p_event: InputEvent) -> void:
	if not bool(_navigator.call(&"handle_event", p_event, _category_has_focus())):
		return
	get_viewport().set_input_as_handled()


## 切到相邻分类并刷新（下标环绕——只有三个分类，走到头绕回来比卡住更好用，
## 与游标列表的「不环绕」是不同场景：那里要能观测「到到底了」，这里不必）。[br]
## [br][b]切换必重置游标[/b]：新分类的行是另一批控件（条目数也不同），游标必须回到
## 首行——否则会停在上一类的下标上（越界或指错行）。[method refresh] 里已经复位。
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


## 游标变化——把键盘焦点搬到新行（焦点环由样式的 focus 状态随焦点绘制）。
func _on_focus_changed(p_index: int) -> void:
	var row: Node = _row_at(p_index)
	if row is Button and not (row as Button).disabled:
		(row as Button).grab_focus()


## 游标确认——把该行的条目发出去（用不用得成由结算层判定，面板不预判）。[br]
## [br][b]空列表时不会被调到[/b]：游标在无行时恒为 -1，[code]ShopPanelNavigator.activate[/code]
## 已保证这一点；这里再判一次是防御式的（条目载荷缺失时也不发空意图）。
func _activate_row(p_index: int) -> void:
	var payload: Dictionary = LayoutScript.row_payload(_row_at(p_index))
	if payload.is_empty():
		return
	item_use_requested.emit(payload)


## 某一行被鼠标点击——与游标确认走同一个出口（[method _activate_row]）。[br]
## [br][b]为什么两个路径要合一[/b]：只接键盘的话，鼠标玩家点一行得到的是
## 「按钮按下去了但什么也没发生」——两个入口各写一遍逻辑更容易分叉成两种行为。
func _on_row_pressed(p_index: int) -> void:
	_activate_row(p_index)


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
	_detail_box = parts.get("detail_box")
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


## 第 [param p_index] 行（越界返回 null——调用方据此安全跳过）。
func _row_at(p_index: int) -> Node:
	if p_index < 0 or p_index >= _item_box.get_child_count():
		return null
	return _item_box.get_child(p_index)


## 模型——注入优先，否则本地 new（它自己去找 Autoload；全缺时其读取方法返回空）。
func _resolve_model() -> RefCounted:
	if _model != null:
		return _model
	return ModelScript.new()


## 分类栏是否持有键盘焦点（未挂载时为 false——不臆造）。
func _category_has_focus() -> bool:
	return _category_button != null and is_instance_valid(_category_button) \
			and _category_button.has_focus()


## 清空条目区（[code]clear_box[/code] 先摘再 free——同帧内计数即已归零，
## 「刷新后行数」的断言不会看到上一批行）。
func _clear_entries() -> void:
	LayoutScript.clear_box(_item_box)


## 收起详情区（背包本轮没有详情内容——留着这块是因为面板共用同一套布局骨架，
## 未来「查看某件法宝的说明」不必再动布局）。
func _clear_detail() -> void:
	LayoutScript.clear_box(_detail_box)


func _show_message(p_text: String) -> void:
	_message_label.text = p_text
	_message_label.visible = not p_text.strip_edges().is_empty()
