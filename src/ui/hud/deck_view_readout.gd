extends RefCounted
## DeckViewReadout —— 卡组查看面板的[b]读数层[/b]（从 [PauseMenuDeckView] 拆出）。[br]
## [br][b]为什么单独一处[/b]：面板要守 300 行软上限（.claude/docs/coding-standards.md），
## 而「把渲染出来的东西读回来」与「什么时候刷新、按键意味着什么」是两件事
## （同 [code]combat_bag_readout.gd[/code] 先例）。读数层只持控件句柄，不刷新、
## 不发意图、不改任何状态——它回答的全是「屏上现在是怎样的」。[br]
## [br][b]读的是控件而不是缓存[/b]：行文本一律经
## [code]InventoryPanelLayout.row_text[/code] 从行控件现读（卡面行与纯文本行都认），
## 焦点读 [code]ShopPanelNavigator.focus_index[/code]——面板没有第二份「我以为的屏上
## 状态」，读数因此不可能与渲染分叉。[br]
## [br][b]行数也不自己数[/b]：由面板在渲染后写入（[method set_entry_count]）——
## 行控件是 [method DeckCardRows.add_rows] 的产出，拿到返回值时最清楚。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：不持卡组、不持游标、不持卡牌模板——
## 句柄全部来自面板注入。[br]
## [br][b]文案本地化豁免[/b]：本模块不产出面向玩家的句子（只转述控件的）。
##
## 来源: .claude/rules/ui-code.md（焦点可见 / 色盲可读的实证口径）、ADR-0031 §2、
## 先例 [code]combat_bag_readout.gd[/code]。

## 行文本与载荷读取的单一来源（卡面行与纯文本行都经它）。
const PanelLayoutScript := preload("res://src/ui/inventory/inventory_panel_layout.gd")

## 条目列表容器（行的宿主——行数与行内容都从这里现读）。
var item_box: VBoxContainer = null
## 详情区容器（未展开时 [member Control.visible] 为假）。
var detail_box: VBoxContainer = null
## 提示 / 空态文案标签。
var message_label: Label = null
## 标题右侧的卡组摘要标签。
var summary_label: Label = null
## 「返回」按钮（按下即离开面板）。
var leave_button: Button = null
## 键盘/手柄游标（焦点下标由它给）。
var navigator: RefCounted = null
## 当前行数（由面板在渲染时写入——本模块不自己数子节点，见类文档）。
var _entry_count: int = 0


func _init(p_item_box: VBoxContainer = null, p_detail_box: VBoxContainer = null,
		p_message_label: Label = null, p_summary_label: Label = null,
		p_leave_button: Button = null, p_navigator: RefCounted = null) -> void:
	item_box = p_item_box
	detail_box = p_detail_box
	message_label = p_message_label
	summary_label = p_summary_label
	leave_button = p_leave_button
	navigator = p_navigator


# ═══════════════════════════════════════════════════════════════════════════════
# 写入（面板渲染时调）
# ═══════════════════════════════════════════════════════════════════════════════

## 写入当前行数（面板渲染后调一次——见类文档）。
func set_entry_count(p_count: int) -> void:
	_entry_count = p_count


# ═══════════════════════════════════════════════════════════════════════════════
# 读出（面板与测试共用——不触及内部控件路径）
# ═══════════════════════════════════════════════════════════════════════════════

## 第 [param p_index] 行（越界或无控件时返回 null——调用方据此安全跳过）。
func row_at(p_index: int) -> Node:
	if item_box == null or p_index < 0 or p_index >= item_box.get_child_count():
		return null
	return item_box.get_child(p_index)


## 行的宿主容器（测试往空列表里塞行数据时用——不靠控件路径字符串定位，
## 那一层的层数是构建细节，多数/少数一层就会拿到别的节点）。
func rows_parent() -> VBoxContainer:
	return item_box


## 当前行数。
func entry_count() -> int:
	return _entry_count


## 全部行的文本（渲染实证——卡面行的文本是它的三行卡面文案）。
func entry_texts() -> Array:
	var out: Array = []
	if item_box == null:
		return out
	for child: Node in item_box.get_children():
		out.append(PanelLayoutScript.row_text(child))
	return out


## 详情区的文本（未展开时为空数组）。
func detail_texts() -> Array:
	var out: Array = []
	if detail_box == null or not detail_box.visible:
		return out
	for child: Node in detail_box.get_children():
		out.append(PanelLayoutScript.row_text(child))
	return out


## 提示行文案（不可见时返回空串）。
func message_text() -> String:
	if message_label == null or not message_label.visible:
		return ""
	return message_label.text


## 标题右侧的卡组摘要（空串 = 未取到卡组）。
func summary_text() -> String:
	return summary_label.text if summary_label != null else ""


## 键盘/手柄游标当前所在行（-1 = 无可选行）。
func focused_index() -> int:
	return int(navigator.call(&"focus_index")) if navigator != null else -1


## 某行当前是否持有键盘焦点（焦点可见的实证）。
func is_row_focused(p_index: int) -> bool:
	var row: Node = row_at(p_index)
	return row is Button and (row as Button).has_focus()


## 测试用：确认第 [param p_index] 行（不依赖真实输入事件；越界是安全空操作）。[br]
## [br][b]走真实信号[/b]：与玩家按回车/点击走同一条 [signal Button.pressed]——
## 直调面板的处理函数会绕过「这一行到底接没接上」这件事。
func press_row(p_index: int) -> void:
	var row: Node = row_at(p_index)
	if row is Button:
		(row as Button).emit_signal(&"pressed")


## 测试用：按下「返回」。
func press_back() -> void:
	if leave_button != null:
		leave_button.emit_signal(&"pressed")
