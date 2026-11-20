extends RefCounted
## DeckEditingView —— 卡组编辑界面的[b]两栏渲染与读数[/b]（持控件句柄，不碰玩法数据）。[br]
## [br][b]为什么单独一处[/b]：界面本体要守 300 行软上限
## （.claude/docs/coding-standards.md），而「两栏怎么重建、行怎么置灰、读数怎么取回来」
## 与「游标怎么动、按下之后调谁、怎么返回」是两件事（同
## [code]deck_view_readout.gd[/code] / [code]combat_bag_readout.gd[/code] 的拆因）。[br]
## [br][b]读的是控件而不是缓存[/b]：行文本一律经
## [code]InventoryPanelLayout.row_text[/code] 从行控件现读，行数由渲染那一刻记录——
## 界面没有第二份「我以为的屏上状态」，读数因此不可能与渲染分叉。[br]
## [br][b]两栏都重建[/b]：加一张会让左栏的「卡组中 N/M 张」与右栏的行数同时变
## （删一张同理）——只刷一边会让另一边的读数停在上一帧。[br]
## [br][b]置灰在渲染时决定、不在按下时才判[/b]：左栏「副本都用尽」的行、右栏在卡组
## 低于最低张数时的整栏都置 [member Button.disabled]——游标据此跳过（引擎的焦点导航
## 不会替我们跳过），鼠标点击也被拦住，玩家看到的是「现在点不动」而不是「点了被拒」。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：不持卡组、不持游标、不写任何域——句柄全部
## 来自界面注入，每次刷新都现读系统。[br]
## [br][b]文案本地化豁免[/b]：空态与提示句集中在本文件的 [code]TEXT_*[/code]
## （项目暂无本地化系统——同 [code]deck_view_sources.gd[/code] 口径）。[br]
##
## 来源: design/ux/deck-editing-ui.md（§Layout Zones / §Component Inventory）、
## design/gdd/deck-editing-system.md §5、ADR-0031 §2、
## 先例 [code]deck_view_readout.gd[/code]（读数层）/ [code]deck_card_rows.gd[/code]
## （行构建拆层）。

## 左栏取数（收藏按模板合并——见 [DeckCollectionRows]）。
const CollectionRowsScript := preload("res://src/ui/deck_editing/deck_collection_rows.gd")
## 右栏取数（卡组逐实例——与卡组查看面板同一份实现）。
const DeckRowsScript := preload("res://src/ui/hud/deck_view_rows.gd")
## 卡面行构建（两栏的行都是卡面行）。
const CardRowsScript := preload("res://src/ui/hud/deck_card_rows.gd")
## 行载荷读取与文本读取（与背包 / 卡组查看共用同一份口径）。
const PanelLayoutScript := preload("res://src/ui/inventory/inventory_panel_layout.gd")
## 构筑规则（右栏「还能不能删」的判据——与左栏加入判定同一份实现）。
const RulesScript := preload("res://src/feature/deck/deck_build_rules.gd")
## 栏下标常量（游标与视图对「哪一栏」的编号必须一致）。
const NavScript := preload("res://src/ui/deck_editing/deck_editing_navigator.gd")

## 统计行文案（当前张数 / 上限）。
const TEXT_SUMMARY: String = "卡组 %d/%d"
## 操作提示（键盘/手柄怎么用——不靠玩家自己猜）。[br]
## [br][b]把「Esc 不保存」写进提示[/b]：两个出口语义不同（一个落盘一个不落盘），
## 不写清楚就会出现「我按了 Esc 以为存了」。
const TEXT_HINT: String = "← → 换栏，↑ ↓ 选牌，回车增删；「保存并返回」会落盘，Esc 返回不落盘。"
## 左栏空态：一张收藏都没有。
const TEXT_NO_COLLECTION: String = "收藏里还没有任何卡牌——打完一场或炼一炉丹药就有了。"
## 右栏空态：卡组是空的。
const TEXT_EMPTY_DECK: String = "卡组还是空的——从左栏挑一张加入。"

## 当前栏 / 非当前栏的标题色（[b]不是[/b]颜色单通道：栏名本身就是文字，
## 这一层只让「注意力在哪」更明显——色盲可读由文字与焦点环保证）。
const ACTIVE_COLUMN_COLOR: Color = Color(1.0, 1.0, 1.0)
const INACTIVE_COLUMN_COLOR: Color = Color(0.62, 0.62, 0.66)

var summary_label: Label = null
var message_label: Label = null
var left_box: VBoxContainer = null
var right_box: VBoxContainer = null
var left_empty: Label = null
var right_empty: Label = null
var left_title: Label = null
var right_title: Label = null
var save_button: Button = null

## 两栏当前渲染出的行数（行控件由 [DeckCardRows] 建，数目在渲染那一刻记录）。
var _left_count: int = 0
var _right_count: int = 0


## 构造——从 [code]DeckEditingLayout.build[/code] 的产出取句柄（见那边类文档）。
func _init(p_parts: Dictionary = {}) -> void:
	summary_label = p_parts.get("summary_label")
	message_label = p_parts.get("message_label")
	left_box = p_parts.get("left_box")
	right_box = p_parts.get("right_box")
	left_empty = p_parts.get("left_empty")
	right_empty = p_parts.get("right_empty")
	left_title = p_parts.get("left_title")
	right_title = p_parts.get("right_title")
	save_button = p_parts.get("save_button")


# ═══════════════════════════════════════════════════════════════════════════════
# 渲染
# ═══════════════════════════════════════════════════════════════════════════════

## 重读两栏并重建。[br]
## [br][param p_on_left_pressed] / [param p_on_right_pressed] 行被按下的回调
## [code]func(index: int) -> void[/code]（键盘游标与鼠标点击两条路径共用同一个出口）。[br]
## [br][b]清空提示行[/b]：上一次的「同名已达上限」与刚刚这次操作无关，留着会让玩家
## 以为这次也被拒了。
func rebuild(p_gsm: Variant, p_cards: Variant, p_deck_ids: Array, p_limit: int,
		p_on_left_pressed: Callable, p_on_right_pressed: Callable) -> void:
	PanelLayoutScript.clear_box(left_box)
	PanelLayoutScript.clear_box(right_box)
	# [b]clear_box 会把 box 连同隐藏[/b]（它服务于「空栏不占版面」的场景）——重建完
	# 必须显式打开，否则这一栏画了出来却是隐形的：截图上只剩列表底色与栏标题，
	# 行控件一个都不出现，而 [method count_of] 照样报出正确的行数（读数与渲染分叉）。
	left_box.visible = true
	right_box.visible = true
	_left_count = 0
	_right_count = 0
	summary_label.text = TEXT_SUMMARY % [p_deck_ids.size(), p_limit]
	_show_message(TEXT_HINT)
	_build_collection(p_gsm, p_cards, p_deck_ids, p_on_left_pressed)
	_build_deck(p_cards, p_deck_ids, p_on_right_pressed)
	_show_empty(left_empty, _left_count == 0, TEXT_NO_COLLECTION)
	_show_empty(right_empty, _right_count == 0, TEXT_EMPTY_DECK)


## 某栏是否空着（测试与界面共用——空态提示的开关判据只有这一处）。
func is_column_empty(p_column: int) -> bool:
	return count_of(p_column) == 0


## 某栏的行数。
func count_of(p_column: int) -> int:
	return _left_count if p_column == NavScript.COLUMN_COLLECTION else _right_count


## 当前栏的标题加亮（另一栏压暗）。[br]
## [br][b]为什么除了焦点环还要这个[/b]：焦点环画在[b]行[/b]上，而当前栏可能一行可选的
## 都没有（空收藏 / 卡组满且不可删）——那时焦点无处可落，玩家看不出自己现在在哪一栏。
func highlight_column(p_column: int) -> void:
	if left_title == null or right_title == null:
		return
	left_title.modulate = ACTIVE_COLUMN_COLOR if p_column == NavScript.COLUMN_COLLECTION \
			else INACTIVE_COLUMN_COLOR
	right_title.modulate = ACTIVE_COLUMN_COLOR if p_column == NavScript.COLUMN_DECK \
			else INACTIVE_COLUMN_COLOR


## 显示一行提示（空串收起——不留一片空白占版面）。
func show_message(p_text: String) -> void:
	_show_message(p_text)


# ═══════════════════════════════════════════════════════════════════════════════
# 读数（测试断言用——不触及内部控件路径）
# ═══════════════════════════════════════════════════════════════════════════════

## 某一栏的全部行控件（游标的取数口与读数口——每次现取不缓存：刷新会换一批控件）。
func rows_of(p_column: int) -> Array:
	var box: VBoxContainer = left_box if p_column == NavScript.COLUMN_COLLECTION else right_box
	var out: Array = []
	for child: Node in box.get_children():
		out.append(child)
	return out


## 第 [param p_column] 栏的第 [param p_index] 行（越界返回 null——调用方据此安全跳过）。
func row_at(p_column: int, p_index: int) -> Node:
	var rows: Array = rows_of(p_column)
	if p_index < 0 or p_index >= rows.size():
		return null
	return rows[p_index] as Node


## 某一栏全部行的文本（渲染实证——卡面行读它的 [member Button.text]）。
func texts_of(p_column: int) -> Array:
	var out: Array = []
	for child: Node in rows_of(p_column):
		out.append(PanelLayoutScript.row_text(child))
	return out


## 某一栏某行的载荷（界面把它交给动作层——行上写着什么就按什么办事）。
func payload_at(p_column: int, p_index: int) -> Dictionary:
	return PanelLayoutScript.row_payload(row_at(p_column, p_index))


## 某行当前是否持有键盘焦点（焦点可见的实证——不只读游标的内部状态）。
func is_row_focused(p_column: int, p_index: int) -> bool:
	var row: Node = row_at(p_column, p_index)
	return row is Button and (row as Button).has_focus()


## 统计行文案（「卡组 N/上限」）。
func summary_text() -> String:
	return summary_label.text if summary_label != null else ""


## 提示行文案（不可见时返回空串）。
func message_text() -> String:
	return message_label.text if message_label != null and message_label.visible else ""


## 某一栏的空态提示是否可见（空的时候才说——不空时说「还没有卡」是在说谎）。
func empty_hint_visible(p_column: int) -> bool:
	var label: Label = left_empty if p_column == NavScript.COLUMN_COLLECTION else right_empty
	return label != null and label.visible


## 某一栏的空态提示文案（隐藏时返回空串——「没提示」与「提示是空的」是两回事）。
func empty_hint_text(p_column: int) -> String:
	var label: Label = left_empty if p_column == NavScript.COLUMN_COLLECTION else right_empty
	if label == null or not label.visible:
		return ""
	return label.text


## 按下一行（鼠标点击与游标确认共用这一个出口——只接一边等于给另一种输入设备的
## 玩家一个点了没反应的按钮）。[br]
## [br][b]禁用行不发意图[/b]（与真实按钮一致）。[br]
## [br][b]返回[/b]：是否真的发出了意图。
func press_row(p_column: int, p_index: int) -> bool:
	var row: Node = row_at(p_column, p_index)
	if not (row is Button) or (row as Button).disabled:
		return false
	(row as Button).emit_signal(&"pressed")
	return true


## 某行的按钮是否置灰（越界 / 非按钮行返回 false——不臆造可点性）。
func is_row_disabled(p_column: int, p_index: int) -> bool:
	var row: Node = row_at(p_column, p_index)
	return row is Button and (row as Button).disabled


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 重建左栏（收藏：按模板合并，标注「卡组中 N/M 张」）。
func _build_collection(p_gsm: Variant, p_cards: Variant, p_deck_ids: Array,
		p_on_pressed: Callable) -> void:
	var built: Dictionary = CollectionRowsScript.build(p_gsm, p_cards, p_deck_ids)
	_left_count = CardRowsScript.add_rows(left_box, built.get("rows", []),
			"Collection", p_on_pressed)
	_disable_unavailable(left_box, CollectionRowsScript.KEY_AVAILABLE, false)
	var hint: String = CollectionRowsScript.resolution_hint(int(built.get("unresolved", 0)))
	if not hint.strip_edges().is_empty():
		_show_message("%s  %s" % [TEXT_HINT, hint])


## 重建右栏（卡组：逐实例，按顺序列出）。[br]
## [br][b]卡组低于最低张数时整栏置灰[/b]：剩下的每一张都删不得，逐行置灰比按下才拒绝
## 更早地告诉玩家「到这里为止了」。
func _build_deck(p_cards: Variant, p_deck_ids: Array, p_on_pressed: Callable) -> void:
	var built: Dictionary = DeckRowsScript.build(p_deck_ids, p_cards, null)
	_right_count = CardRowsScript.add_rows(right_box, built.get("rows", []),
			"DeckEntry", p_on_pressed)
	var removable: bool = bool(RulesScript.evaluate_remove(p_deck_ids.size(), 1)["allowed"])
	if not removable:
		_disable_unavailable(right_box, "", true)


## 把某栏里「不可操作」的行按钮置灰。[br]
## [br][param p_payload_key] 载荷里判定可操作性的键（[param p_all] 为真时不看它）。[br]
## [br][param p_all] 整栏置灰（右栏低于最低张数时——见 [method _build_deck]）。[br]
## [br][b]没有载荷的行（模板未加载的降级文本行）一律置灰[/b]：点了也说不清是哪一张。
func _disable_unavailable(p_box: VBoxContainer, p_payload_key: String, p_all: bool) -> void:
	for child: Node in p_box.get_children():
		if not (child is Button):
			continue
		var button: Button = child
		if p_all:
			button.disabled = true
			continue
		var payload: Dictionary = PanelLayoutScript.row_payload(button)
		if payload.is_empty():
			button.disabled = true
			continue
		var available: Variant = payload.get(p_payload_key)
		button.disabled = available is Array and (available as Array).is_empty()


## 空态提示的开关（空的时候才说——不空时说「还没有卡」是在说谎）。
func _show_empty(p_label: Label, p_empty: bool, p_text: String) -> void:
	if p_label == null:
		return
	p_label.text = p_text
	p_label.visible = p_empty


## 显示一行提示（空串收起——不留一片空白占版面）。
func _show_message(p_text: String) -> void:
	if message_label == null:
		return
	message_label.text = p_text
	message_label.visible = not p_text.strip_edges().is_empty()
