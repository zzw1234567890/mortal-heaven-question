class_name CombatBagScreen
extends Control
## CombatBagScreen —— 战斗内「行囊」面板（纯代码构建 UI）。[br]
## [br][b]职责[/b]：把 [code]CombatBagEntries[/code] 取来的丹药与法宝渲染成一列
## [b]可确认[/b]的行，并让玩家[b]显式选定目标[/b]；确认后只发
## [signal entry_use_requested]（发意图，不调系统）。[br]
## [br][b]「用丹药」为什么不在这里结算[/b]：与背包面板同源理由——面板一旦直调系统，
## 就会长成第二处「谁改了存档」的现场（ADR-0031 §2）。由
## [code]combat_bag_host.gd[/code] 交给 [code]CombatBagUse[/code] 结算后回填文案。[br]
## [br][b]不可用的行灰显且点不到[/b]：[code]usable[/code] 为假的行 [code]disabled[/code]
## 置真——鼠标点击被引擎拦住、游标也跳过它（[code]ShopPanelNavigator[/code] 的判据
## 正是 [code]disabled[/code]）。原因句已经写进行文本（色盲可读）。[br]
## [br][b]两块状态各自成模块[/b]：候选池与「当前选中谁」在
## [code]combat_bag_targets.gd[/code]；「屏上现在是怎样的」这族只读结论在
## [code]combat_bag_readout.gd[/code]。本面板只剩「什么时候重画、按键意味着什么」。[br]
## [br][b]事件层级 = _input[/b]：与 [InventoryScreen] 同源理由——焦点落在 [Button] 上时
## 引擎的内置焦点导航会在 GUI 阶段吃掉方向键，[code]_unhandled_key_input[/code] 收不到；
## [code]_input[/code] 排在 GUI 派发之前，是唯一能拦住的层。消费走
## [method Viewport.set_input_as_handled]，顺带挡住 [code]InputManager[/code] 的
## Esc → 暂停菜单（行囊开着时按 Esc 该关行囊，不是弹暂停）。[br]
## [br][b]打开/关闭由宿主驱动[/b]：本面板不自己决定何时出现——[method open] /
## [method close] 由 [code]combat_bag_host.gd[/code] 调，以便同一时刻冻结出牌输入。[br]
## [br][b]为什么不用 .tscn[/b]：与背包/商店同源——覆盖层一次性，条目数随存档变化。[br]
## [br][b]文案本地化豁免[/b]：与 combat_bag_rules / inventory_screen 同源口径。
##
## 来源: design/gdd/alchemy-crafting-system.md §1c（丹药使用时机「战斗中或背包」）、
## ADR-0031 §2/§4、.claude/rules/ui-code.md、先例 [code]inventory_screen.gd[/code]。

## 玩家确认了某一行。[br]
## [br][param p_entry] 该行的条目（面板不解释它是什么）。[br]
## [param p_target_ids] 玩家显式选定的目标 ID（全体效果为全部候选；无候选为空数组）。
signal entry_use_requested(p_entry: Dictionary, p_target_ids: Array)
## 玩家点了「返回」或按了取消键。
signal closed

## 控件树构建。
const LayoutScript := preload("res://src/ui/combat/bag/combat_bag_layout.gd")
## 判据与文案（空态 / 目标标签的唯一来源）。
const RulesScript := preload("res://src/feature/combat/combat_bag_rules.gd")
## 键盘/手柄输入翻译（上下选行 + 确认 + 取消；左右交给目标选择模块）。
const NavigatorScript := preload("res://src/ui/exploration/shop_panel_navigator.gd")
## 目标选择状态机（候选池 / 下标 / 全体判定）。
const TargetsScript := preload("res://src/ui/combat/bag/combat_bag_targets.gd")
## 读数层（行数 / 行文本 / 禁用态 / 游标 / 目标栏的只读结论）。
const ReadoutScript := preload("res://src/ui/combat/bag/combat_bag_readout.gd")

const TEXT_TITLE: String = "行囊"
const TEXT_HINT: String = "↑ ↓ 选行，← → 换目标，回车使用，Esc 关闭。"
## 条目来源缺失（读取链路未接线）时的文案——与「行囊是空的」分开：前者是链路问题，
## 后者是玩法事实，混在一句里会误导排查（同 [code]InventoryScreen.TEXT_UNAVAILABLE[/code]）。
const TEXT_UNAVAILABLE: String = "行囊暂不可查——读取链路未就绪。"

## 条目来源（注入——生产由宿主接上 [code]CombatBagEntries[/code]）。
var entries_source: RefCounted = null
## 目标选择（本面板自建，随布局交回的目标栏按钮构造）。
var targets: RefCounted = null
## 读数层（测试与调试的查询出口——见类文档「两块状态各自成模块」）。
var readout: RefCounted = null

var _item_box: VBoxContainer = null
var _message_label: Label = null
var _leave_button: Button = null
## 键盘/手柄游标（上下选行 / 确认 / 取消）。
var _navigator: RefCounted = null


func _init() -> void:
	name = "CombatBagScreen"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_layout()
	_navigator = NavigatorScript.new()
	_navigator.call(&"bind", _rows, _activate_row, _request_close)
	_navigator.connect(&"focus_changed", _on_focus_changed)
	readout = ReadoutScript.new(_item_box, _message_label, _navigator, targets)
	visible = false  # 挂载即隐藏（由宿主 open() 才显示）


# ═══════════════════════════════════════════════════════════════════════════════
# 对外
# ═══════════════════════════════════════════════════════════════════════════════

## 注入条目来源（生产路径：宿主把已接好依赖的 [code]CombatBagEntries[/code] 交进来）。[br]
## [br][b]同时转给目标选择模块[/b]：候选池由它现问来源（见
## [method CombatBagTargets.sync]），面板不代它缓存一份。
func set_entries_source(p_source: RefCounted) -> void:
	entries_source = p_source
	if targets != null:
		targets.call(&"set_entries_source", p_source)


## 打开面板并刷新（每次打开都现读——关闭期间玩家可能刚打完一场）。[br]
## [br][b]游标复位到首个可选行[/b]：上次用掉的那一条可能已不存在。
func open() -> void:
	visible = true
	refresh()


## 关闭面板（隐藏但留树——复用式，重开不重建控件）。
func close() -> void:
	visible = false


## 是否处于打开态（宿主据此决定「再点一次是开还是关」）。
func is_open() -> bool:
	return visible


## 刷新显示——每次都向条目来源现读（零缓存：刚炼成的丹不该迟到一帧）。[br]
## [br][b]空态[/b]：无条目时显示 [constant CombatBagRules.TEXT_EMPTY]（本面板不自行
## 措辞——空态的句子归判据模块，那是它唯一的来源）。[br]
## [br][b]游标复位[/b]：刷新会换一批控件，停在旧下标上会指向别的条目。[br]
## [br][b]目标栏跟着行再算一次[/b]：候选池依赖「当前游标那一行是丹还是宝」，
## 刷新后行可能整批换过，沿用旧候选池会把丹药施到一个满血的人身上。
func refresh() -> void:
	var source: RefCounted = entries_source
	LayoutScript.clear_box(_item_box)
	readout.call(&"set_entry_count", 0)
	if source == null:
		_show_message(TEXT_UNAVAILABLE)
		_reset_cursor()
		return
	var rows: Array = source.call(&"entries")
	if rows.is_empty():
		_show_message(RulesScript.TEXT_EMPTY)
		_reset_cursor()
		return
	_show_message(TEXT_HINT)
	readout.call(&"set_entry_count",
			LayoutScript.add_entry_rows(_item_box, rows, _on_row_pressed))
	_navigator.call(&"reset")
	# 游标落到 -1 时 [method ShopPanelNavigator._set_focus] 同值不发信号（幂等），
	# 候选池不会经 [method _on_focus_changed] 归零——这里补上那一次。游标有效时
	# 焦点搬运已经带过一次 sync，再调只是白问一次来源。
	if focused_index() < 0:
		_sync_targets()


## 回填一条结果文案（用得成用不成都由结算层给句子——面板不自行措辞判断）。[br]
## [br]与 [method refresh] 分开调：刷新会把提示改写成操作提示，宿主必须先刷新再现文案
## （顺序反了玩家就看不到系统给的那句话）。
func show_message(p_message: String) -> void:
	_show_message(p_message)


# === 查询（测试断言用——不触及内部控件路径）==================================
# 结论全部来自读数层：面板不另存一份「我以为的屏上状态」（见类文档）。

## 当前条目行数。
func entry_count() -> int:
	return int(readout.call(&"entry_count"))


## 全部条目行的文本（渲染实证——含禁用原因）。
func entry_texts() -> Array:
	return readout.call(&"row_texts")


## 第 [param p_index] 行是否被禁用（不可用条目 —— 灰显且点不到）。
func is_row_disabled(p_index: int) -> bool:
	return bool(readout.call(&"is_row_disabled", p_index))


## 当前结果/提示/空态文案。
func message_text() -> String:
	return str(readout.call(&"message_text"))


## 键盘/手柄游标当前所在行（-1 = 无可选行）。
func focused_index() -> int:
	return int(readout.call(&"focused_index"))


## 某行当前是否持有键盘焦点（焦点可见的实证——不只读游标的内部状态）。
func is_row_focused(p_index: int) -> bool:
	return bool(readout.call(&"is_row_focused", p_index))


## 目标栏文本（「目标：角色 601  （← → 切换）」）。
func target_text() -> String:
	return str(readout.call(&"target_text"))


## 当前显式选定的目标 ID（全体效果为全部候选；无候选为空数组）。
func selected_target_ids() -> Array:
	return readout.call(&"selected_target_ids")


# === 测试与鼠标入口 ===========================================================

## 测试用：确认第 [param p_index] 行（不依赖真实输入事件；越界是安全空操作）。
func press_row(p_index: int) -> void:
	var row: Node = _row_at(p_index)
	if row is Button:
		(row as Button).emit_signal(&"pressed")


## 测试用：点目标栏（切到下一个目标）。
func press_target() -> void:
	targets.call(&"press")


## 测试用：按下「返回」。
func press_back() -> void:
	_leave_button.emit_signal(&"pressed")


# ═══════════════════════════════════════════════════════════════════════════════
# 键盘导航（见类文档「事件层级 = _input」）
# ═══════════════════════════════════════════════════════════════════════════════

## 输入事件——左右切目标 / 上下选行 / 回车确认 / 取消关闭，其余原样放行。
func _input(p_event: InputEvent) -> void:
	if not visible:
		return
	if bool(targets.call(&"handle_sideways", p_event)):
		get_viewport().set_input_as_handled()
		return
	if not bool(_navigator.call(&"handle_event", p_event)):
		return
	get_viewport().set_input_as_handled()


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 建控件树并接线（目标栏的接线在这里——布局把按钮原样交回，本面板自己接）。[br]
## [br][b]目标选择模块在这里构造[/b]：它需要一个真实的 [Button]（焦点查询走它），
## 而按钮是 [method LayoutScript.build] 的产出——先建树再建状态机，顺序不能反。[br]
## [br][b]「返回」按钮不在这里接[/b]：构建时已经把 [code]&"closed"[/code] 交给骨架
## （[method CombatBagLayout.build] 的第三参），骨架的「返回」直接转发该信号——
## 再连一次 [method _request_close] 会让 [signal closed] 发两次（宿主开关两次）。
func _build_layout() -> void:
	var parts: Dictionary = LayoutScript.build(self, TEXT_TITLE)
	_leave_button = parts.get("leave_button")
	_item_box = parts.get("item_box")
	_message_label = parts.get("message_label")
	targets = TargetsScript.new(parts.get("target_button"), entries_source)
	(parts.get("target_button") as Button).pressed.connect(
			Callable(targets, &"cycle").bind(1))


## 行数组（游标取数口——每次现取不缓存：刷新会换一批控件）。
func _rows() -> Array:
	var out: Array = []
	for child: Node in _item_box.get_children():
		out.append(child)
	return out


## 第 [param p_index] 行（越界返回 null——调用方据此安全跳过）。
func _row_at(p_index: int) -> Node:
	return readout.call(&"row_at", p_index)


## 无行可站时的收尾（空态与链路缺失共用）：候选池清空 + 游标复位。
func _reset_cursor() -> void:
	targets.call(&"sync", {})
	_navigator.call(&"reset")


## 游标变化——把键盘焦点搬到新行，并同步目标候选池（目标栏跟着当前行走）。
func _on_focus_changed(p_index: int) -> void:
	var row: Node = _row_at(p_index)
	if row is Button and not (row as Button).disabled:
		(row as Button).grab_focus()
	_sync_targets()


## 按当前游标行的条目重算候选池（见 [method CombatBagTargets.sync]）。
func _sync_targets() -> void:
	targets.call(&"sync", readout.call(&"row_entry", focused_index()))


## 游标确认——把该行的条目与显式选定的目标一起发出去（用不用得成由结算层判定）。[br]
## [br][b]无可用行时不会被调到[/b]：游标在无行时恒为 -1，[code]ShopPanelNavigator[/code]
## 已保证这一点（禁用行同样不发意图）。
func _activate_row(p_index: int) -> void:
	var entry: Dictionary = readout.call(&"row_entry", p_index)
	if entry.is_empty():
		return
	entry_use_requested.emit(entry, selected_target_ids())


## 鼠标点击某行——与游标确认走同一个出口（两个入口各写一遍更容易分叉成两种行为）。
func _on_row_pressed(p_index: int) -> void:
	_activate_row(p_index)


## 请求关闭（「返回」按钮 / Esc / 手柄取消键）。
func _request_close() -> void:
	closed.emit()


func _show_message(p_text: String) -> void:
	_message_label.text = p_text
	_message_label.visible = not p_text.strip_edges().is_empty()
