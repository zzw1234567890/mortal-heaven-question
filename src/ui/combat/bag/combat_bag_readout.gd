extends RefCounted
## CombatBagReadout —— 行囊面板的[b]读数层[/b]（从 [CombatBagScreen] 拆出）。[br]
## [br][b]为什么单独一处[/b]：面板自身近 300 行软上限，而「把渲染出来的东西读回来」
## 与「什么时候重画、按键意味着什么」是两件事。读数层只持控件句柄，不刷新、不发意图、
## 不改任何状态——它回答的全是「屏上现在是怎样的」。[br]
## [br][b]读的是控件而不是缓存[/b]：行文本一律经 [method CombatBagLayout.row_text] 从
## [Button] 现读，禁用态读 [member Button.disabled]，游标读
## [method ShopPanelNavigator.focus_index]——面板没有第二份「我以为的屏上状态」，
## 读数因此不可能与渲染分叉。[br]
## [br][b]为什么把内部取行也放在这里[/b]：[method row_at] 是上面那些读数的共同底座
## （越界返回 null）；留在面板里会让本模块反过来依赖面板。面板自己要用时经同一入口取，
## 越界口径只有一份。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：不持条目、不持游标、不持选中目标——
## 句柄全部来自面板注入。[br]
## [br][b]文案本地化豁免[/b]：本模块不产出面向玩家的句子（只转述控件的）。
##
## 来源: .claude/rules/ui-code.md（焦点可见 / 色盲可读的实证口径）、ADR-0031 §2、
## 先例 [code]combat_bag_targets.gd[/code]（同样是把一族只读结论收在一处）。

## 行文本读取（行文案的唯一来源——本模块不自己拼句子）。
const LayoutScript := preload("res://src/ui/combat/bag/combat_bag_layout.gd")

## 条目列表容器（行的宿主——行数与行内容都从这里现读）。
var item_box: VBoxContainer = null
## 提示 / 空态 / 结果文案标签。
var message_label: Label = null
## 键盘/手柄游标（焦点下标由它给）。
var navigator: RefCounted = null
## 目标选择状态机（目标栏文本与选中目标的唯一来源）。
var targets: RefCounted = null
## 当前条目行数（由面板在渲染时写入——行控件是 [method CombatBagLayout.add_entry_rows]
## 的产出，面板拿到返回值时最清楚，再数一遍子节点只是重复）。
var _entry_count: int = 0


func _init(p_item_box: VBoxContainer = null, p_message_label: Label = null,
		p_navigator: RefCounted = null, p_targets: RefCounted = null) -> void:
	item_box = p_item_box
	message_label = p_message_label
	navigator = p_navigator
	targets = p_targets


## 第 [param p_index] 行（越界或无控件时返回 null——调用方据此安全跳过）。
func row_at(p_index: int) -> Node:
	if item_box == null or p_index < 0 or p_index >= item_box.get_child_count():
		return null
	return item_box.get_child(p_index)


## 写入当前条目行数（面板渲染后调一次——本模块不自己数子节点，见成员说明）。
func set_entry_count(p_count: int) -> void:
	_entry_count = p_count


## 当前条目行数。
func entry_count() -> int:
	return _entry_count


## 全部行的文本（渲染实证——含写进行文本的禁用原因）。
func row_texts() -> Array:
	var out: Array = []
	if item_box == null:
		return out
	for child: Node in item_box.get_children():
		out.append(LayoutScript.row_text(child))
	return out


## 第 [param p_index] 行是否被禁用（不可用条目——灰显且点不到）。[br]
## [br]非 [Button] 的脏条目按禁用处理，不臆造可点性（同
## [method ShopPanelNavigator._is_disabled] 的口径）。
func is_row_disabled(p_index: int) -> bool:
	var row: Node = row_at(p_index)
	return not (row is Button) or (row as Button).disabled


## 当前是否真的持有键盘焦点（焦点可见的实证——不只读游标的内部状态）。
func is_row_focused(p_index: int) -> bool:
	var row: Node = row_at(p_index)
	return row is Button and (row as Button).has_focus()


## 第 [param p_index] 行携带的条目（没有则空字典）。
func row_entry(p_index: int) -> Dictionary:
	return LayoutScript.row_entry(row_at(p_index))


## 当前结果 / 提示 / 空态文案（标签不可见时为空串——屏上确实没有那句话）。
func message_text() -> String:
	if message_label == null or not message_label.visible:
		return ""
	return message_label.text


## 键盘/手柄游标当前所在行（-1 = 无可选行）。
func focused_index() -> int:
	return int(navigator.call(&"focus_index")) if navigator != null else -1


## 目标栏文本（「目标：角色 601  （← → 切换）」）。
func target_text() -> String:
	return str(targets.call(&"text")) if targets != null else ""


## 当前显式选定的目标 ID（全体效果为全部候选；无候选为空数组）。
func selected_target_ids() -> Array:
	if targets == null:
		return []
	var ids: Variant = targets.call(&"selected_ids")
	return ids if ids is Array else []
