extends Control
## PauseMenuDeckView —— 战斗中暂停菜单的[b]只读卡组查看[/b]面板（纯代码构建）。[br]
## [br][b]为什么需要[/b]（design/ux/pause-menu.md §Interaction Map 战斗中特殊规则）：
## 「查看卡组」打开的界面必须是[b]只读[/b]——所有编辑按钮禁用、卡牌可查看详情但
## 不可拖拽/移动，关闭后回到暂停菜单。此前这个按钮只发一个
## [signal PauseMenu.deck_view_requested] 信号、全库零消费者，玩家点下去什么都
## 不发生。[br]
## [br][b]复用既有面板骨架而不是新造一套[/b]：遮罩 + 居中面板 + 标题 + 滚动列表 +
## 提示行 + 底栏全部走 [code]ShopPanelLayout.build[/code]（尺寸、边距、焦点环只在那
## 一处定义），行与详情走 [code]InventoryPanelLayout.add_rows[/code] /
## [code]fill_detail[/code]，键盘游标走 [code]ShopPanelNavigator[/code]——与本项目
## 已有的商店 / 背包 / 角色状态四个面板同一套控件语言。[br]
## [br][b]「只读」落在哪里[/b]：[br]
##   · 没有任何编辑入口——面板不提供拖拽、增删、装备，「返回」是唯一出口；[br]
##   · 行的确认动作只展开[b]详情文本[/b]（[method _activate_row]），不发任何系统
##     调用、不写任何状态；[br]
##   · 没有分类切换（卡组不是分类清单）——不需要分类栏，也就没有那边的翻页键。[br]
## [br][b]取数归 [DeckViewRows][/b]：牌库/手牌判定与行文案组装是纯逻辑，能在没有
## 控件树的用例里逐条断言（本文件只管骨架、焦点、键盘输入与开关配对）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：每次 [method open] 都现读卡组与牌库
## ——停留期间可能刚好打出一张牌（手牌变了，标注必须跟着变）。[br]
## [br][b]依赖注入[/b]：deck / cards / combat 三个引用由宿主透传，缺省时按
## [code]/root[/code] 找 Autoload（同 [code]InventoryModel[/code] 的回退口径）；
## 全缺时面板照常可开，只是列表为空、不带标注——不把「链路没接上」变成崩溃。[br]
## [br][b]事件层级 = _input[/b]：与背包 / 商店面板同源理由——焦点落在 [Button] 上时
## 引擎的内置焦点导航会在 GUI 阶段先吃掉方向键；[code]_input[/code] 排在 GUI 派发
## 之前，是唯一能拦住的层。消费走 [method Viewport.set_input_as_handled]，顺带挡住
## InputManager 的 Esc → 暂停菜单。[br]
## [br][b]文案本地化豁免[/b]：与 inventory_screen / shop_panel_screen 同源口径。
##
## 来源: design/ux/pause-menu.md（§Interaction Map 战斗中特殊规则 / §States &
## Variants 战斗中变体）、design/ux/deck-editing-ui.md（§多入口到达）、
## design/gdd/deck-editing-system.md §5、ADR-0031 §2/§4、.claude/rules/ui-code.md
## （双输入 + 文字即标记）、先例 [code]inventory_screen.gd[/code]。

## 玩家请求离开（「返回」按钮 / Esc / 手柄取消键）——宿主据此把焦点还回暂停菜单。
signal back_requested

## 控件树骨架、行构建与取值（三个模块各司其职，见类文档）。
const LayoutScript := preload("res://src/ui/exploration/shop_panel_layout.gd")
const RowsScript := preload("res://src/ui/hud/deck_view_rows.gd")
const NavScript := preload("res://src/ui/exploration/shop_panel_navigator.gd")
## 行与详情块的构建/填充（与背包共用同一份口径）。
const PanelLayoutScript := preload("res://src/ui/inventory/inventory_panel_layout.gd")

const TEXT_TITLE: String = "📜 卡组"
## 键盘操作提示（与背包面板同源——不靠玩家自己猜）。
const TEXT_HINT: String = "↑ ↓ 选牌，回车看详情，Esc 返回。"
## 只读声明（规格明写「所有编辑按钮禁用」，说清楚比让玩家找按钮强）。
const TEXT_READONLY: String = "只读查看——战斗中不可编辑卡组。"
## 卡组摘要（标题右侧）模板。
const TEXT_SUMMARY: String = "卡组 %d 张"
## 列表为空时的文案（链路未就绪与「卡组是空的」分开说，同背包口径）。
const TEXT_EMPTY: String = "卡组暂不可查——读取链路未就绪。"

## 依赖注入（null 时按 /root 找 Autoload——同 [code]InventoryModel[/code] 的回退口径）。
var deck_system: Node = null
var card_system: Node = null
var combat_system: Node = null

var _item_box: VBoxContainer = null
var _detail_box: VBoxContainer = null
var _message_label: Label = null
var _balance_label: Label = null
var _leave_button: Button = null
## 键盘/手柄游标（只认 [Button]，见 [ShopPanelNavigator]）。
var _navigator: RefCounted = null
## 当前行数（与控件数一致——测试断言用）。
var _entry_count: int = 0


func _init() -> void:
	name = "PauseMenuDeckView"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# STOP：面板开着时点击不该穿透到遮罩（否则点空白处会「继续游戏」）
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_layout()
	_navigator = NavScript.new()
	_navigator.call(&"bind", _rows, _activate_row, _request_back)
	_navigator.connect(&"focus_changed", _on_focus_changed)
	# 离开即收起——「返回」是唯一出口，收起归面板自己（宿主只关心焦点回锚）
	back_requested.connect(close)


# ═══════════════════════════════════════════════════════════════════════════════
# 对外
# ═══════════════════════════════════════════════════════════════════════════════

## 打开面板并刷新（每次都现读——见类文档「零状态所有权」）。[br]
## [br][b]刷新后再复位游标[/b]：行是刚建的一批控件，游标必须落到首个可选行
## （[method refresh] 里已复位）。[br]
## [br][b]返回[/b]：实际渲染出的行数（宿主/测试可直接断言）。
func open() -> int:
	visible = true
	refresh()
	return _entry_count


## 关闭面板——隐藏但[b]留树[/b]（复用式单例，重开不重建控件）。
func close() -> void:
	visible = false


## 是否处于打开态（ESC 分层与宿主开关判定用）。
func is_open() -> bool:
	return visible


## 刷新显示——现读卡组 → 组装行 → 重建列表 → 清空详情 → 游标复位。[br]
## [br][b]清空详情[/b]：刷新换了一批行控件，旧的详情文本会指着一张已经打出去的牌。
func refresh() -> void:
	PanelLayoutScript.clear_box(_item_box)
	PanelLayoutScript.clear_box(_detail_box)
	_entry_count = 0
	var deck_ids: Array = _deck_ids()
	if deck_ids.is_empty():
		_balance_label.text = ""
		_show_message(TEXT_EMPTY)
		_navigator.call(&"reset")
		return
	var built: Dictionary = RowsScript.build(deck_ids, _resolve(&"card_system", &"CardSystem"),
			_resolve(&"combat_system", &"CombatSystem"))
	var rows: Array = built.get("rows", [])
	_entry_count = PanelLayoutScript.add_rows(_item_box, rows, "Entry", _activate_row)
	_balance_label.text = TEXT_SUMMARY % int(built.get("total", 0))
	_show_message(_message_for(built))
	_navigator.call(&"reset")


# === 查询（测试断言用——不触及内部控件路径）==================================

func entry_count() -> int:
	return _entry_count


## 全部行的文本（渲染实证）。
func entry_texts() -> Array:
	var out: Array = []
	for child: Node in _item_box.get_children():
		out.append(PanelLayoutScript.row_text(child))
	return out


## 详情区的文本（未展开时为空数组）。
func detail_texts() -> Array:
	var out: Array = []
	if not _detail_box.visible:
		return out
	for child: Node in _detail_box.get_children():
		out.append(PanelLayoutScript.row_text(child))
	return out


## 提示行文案（不可见时返回空串）。
func message_text() -> String:
	return _message_label.text if _message_label.visible else ""


## 标题右侧的卡组摘要（空串 = 未取到卡组）。
func summary_text() -> String:
	return _balance_label.text


## 键盘/手柄游标当前所在行（-1 = 无可选行）。
func focused_index() -> int:
	return int(_navigator.call(&"focus_index")) if _navigator != null else -1


## 某行当前是否持有键盘焦点（焦点可见的实证）。
func is_row_focused(p_index: int) -> bool:
	var row: Node = _row_at(p_index)
	return row is Button and (row as Button).has_focus()


## 测试用：确认第 [param p_index] 行（不依赖真实输入事件；越界是安全空操作）。
func press_row(p_index: int) -> void:
	var row: Node = _row_at(p_index)
	if row is Button:
		(row as Button).emit_signal(&"pressed")


## 测试用：按下「返回」。
func press_back() -> void:
	if _leave_button != null:
		_leave_button.emit_signal(&"pressed")


# ═══════════════════════════════════════════════════════════════════════════════
# 键盘导航（见类文档「事件层级 = _input」）
# ═══════════════════════════════════════════════════════════════════════════════

## 输入事件——上下选行 / 回车看详情 / 取消返回，其余原样放行。[br]
## [br][b]只在打开时吃事件[/b]：面板隐藏着还消费 ui_cancel 会把暂停菜单的
## ESC 一起吞掉（菜单再也关不掉）。
func _input(p_event: InputEvent) -> void:
	if not visible:
		return
	if not bool(_navigator.call(&"handle_event", p_event)):
		return
	get_viewport().set_input_as_handled()


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 建控件树并接线（标题/列表/提示/底栏全部来自商店骨架，见类文档「复用」）。[br]
## [br]「返回」文案改写成退回暂停菜单（同 [code]InventoryScreen[/code] 的口径）。
func _build_layout() -> void:
	var parts: Dictionary = LayoutScript.build(self, TEXT_TITLE, &"back_requested")
	_item_box = parts.get("item_box")
	_message_label = parts.get("message_label")
	_balance_label = parts.get("balance_label")
	_leave_button = parts.get("leave_button")
	_leave_button.text = PanelLayoutScript.TEXT_BACK
	_detail_box = VBoxContainer.new()
	_detail_box.name = "DetailBox"
	_detail_box.add_theme_constant_override("separation", 4)
	_detail_box.visible = false
	LayoutScript.insert_after_list(parts, _detail_box)


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


## 游标变化——把键盘焦点搬到新行（焦点环由样式的 focus 状态随焦点绘制）。
func _on_focus_changed(p_index: int) -> void:
	var row: Node = _row_at(p_index)
	if row is Button and not (row as Button).disabled:
		(row as Button).grab_focus()


## 游标确认 / 鼠标点击 —— 展开该行的详情（[b]只读[/b]：不发系统调用、不改状态）。[br]
## [br]两个入口合一：只接键盘的话，鼠标玩家点一行只会看到按钮按下去了却什么也没
## 发生（同背包面板 [code]_on_row_pressed[/code] 的口径）。
func _activate_row(p_index: int) -> void:
	var payload: Dictionary = PanelLayoutScript.row_payload(_row_at(p_index))
	if payload.is_empty():
		return
	var detail: Variant = payload.get(RowsScript.KEY_DETAIL)
	PanelLayoutScript.fill_detail(_detail_box,
			detail if detail is Array else [str(detail)])


## 请求返回（「返回」按钮 / Esc / 手柄取消键）。
func _request_back() -> void:
	back_requested.emit()


## 卡组实例 ID 列表（[code]DeckEditingSystem.get_deck_cards[/code]；不可用时空数组）。
func _deck_ids() -> Array:
	var deck: Node = _resolve(&"deck_system", &"DeckEditingSystem")
	if deck == null or not deck.has_method(&"get_deck_cards"):
		return []
	var raw: Variant = deck.call(&"get_deck_cards")
	return (raw as Array).duplicate() if raw is Array else []


## 提示行文案——只读声明 + 张数提示 +（模板未加载时）缺失说明。
func _message_for(p_built: Dictionary) -> String:
	var hint: String = str(RowsScript.resolution_hint(
			int(p_built.get("total", 0)),
			(p_built.get("rows", []) as Array).size(),
			int(p_built.get("unresolved", 0))))
	var parts: Array = [TEXT_READONLY, TEXT_HINT]
	if not hint.is_empty():
		parts.append(hint)
	return "  ".join(parts)


## 显示一行提示（空串收起——不留一片空白占版面）。
func _show_message(p_text: String) -> void:
	_message_label.text = p_text
	_message_label.visible = not p_text.strip_edges().is_empty()


## 依赖解析——注入优先，否则按 [code]/root[/code] 找 Autoload。[br]
## [br][param p_field] 本面板上的注入字段名。[br]
## [param p_autoload] Autoload 节点名。[br]
## [br][b]返回值可能是 null[/b]：两个来源都没有时如实返回——取数侧各自降级
## （[DeckViewRows] 判空后不出行），本方法不臆造替身。
func _resolve(p_field: StringName, p_autoload: StringName) -> Node:
	var injected: Variant = get(p_field)
	if injected != null and injected is Node and is_instance_valid(injected):
		return injected
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath(String(p_autoload)))
