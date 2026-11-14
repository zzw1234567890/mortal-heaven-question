extends RefCounted
## CombatBagLayout —— 战斗行囊面板的控件树构建（骨架复用 + 行 / 目标栏）。[br]
## [br][b]职责[/b]：搭出「遮罩 + 居中面板 + 标题 + 目标栏 + 条目列表 + 文案 + 返回」，
## 并把条目渲染成[b]可点 / 可灰显[/b]的行。[br]
## [br][b]为什么复用商店骨架[/b]：尺寸、边距、焦点环只在
## [code]shop_panel_layout.gd[/code] 定义一次（改一处四处生效）——战斗行囊与
## 商店 / 背包 / 角色状态是同一个「全屏覆盖层 + 一列可确认行」的形态，重画一遍
## 只会让两边的焦点环慢慢长歪。[br]
## [br][b]行是 [Button] 且带 [member Button.disabled][/b]：[code]ShopPanelNavigator[/code]
## 的游标判据就是 [code]disabled[/code]——用不了的条目（已用尽 / 灵力不足 / 无人可施）
## 因此[b]在键盘路径上也点不到[/b]，与鼠标点击被 [code]disabled[/code] 拦住同口径。[br]
## [br][b]状态写进文本[/b]：不可用原因由 [code]CombatBagRules.row_text[/code] 拼进按钮
## 文本（色盲可读，不只靠灰显）。[br]
## [br][b]目标栏也是 [Button][/b]：`.claude/rules/ui-code.md` 要求交互元素同时支持
## 键盘/鼠标/手柄——做成按钮后鼠标可点（点一次换下一个目标）、键盘 Tab 可聚焦、
## 方向键左右也可切（面板另外接左/右）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：只 new 节点，不持引用（[method build] 把
## 引用交回面板）。[br]
## [br][b]文案本地化豁免[/b]：与 shop_panel_layout / combat_bag_rules 同源口径。
##
## 来源: .claude/rules/ui-code.md（双输入 + 焦点可见 + 色盲可读）、ADR-0031 §2/§4、
## 先例 [code]shop_panel_layout.gd[/code] / [code]inventory_panel_layout.gd[/code]。

## 控件树样式来源（尺寸与焦点环只在那一处定义）。
const ShopLayoutScript := preload("res://src/ui/exploration/shop_panel_layout.gd")

## 面板尺寸——比商店（760×520）略高：行文案更长（带效果与原因）。
const PANEL_WIDTH: int = 760
const PANEL_HEIGHT: int = 560
## 条目行 / 目标栏高度（与商店商品行同档）。
const ROW_HEIGHT: int = ShopLayoutScript.ITEM_HEIGHT

## 目标栏文案（前缀 + 当前目标 + 操作提示——提示写进文本，屏幕阅读器可读）。
const TEXT_TARGET_PREFIX: String = "目标："
const TEXT_TARGET_HINT: String = "  （← → 切换）"
## 没有候选目标时的目标栏文本（丹药与法宝共用一句——玩家关心的是「没人可施」）。
const TEXT_TARGET_NONE: String = "无"
## 全体效果的目标描述（多目标没有「换一个」的语义，故不带切换提示）。
const TEXT_TARGET_ALL: String = "全体（%d 人）"
## 「返回」按钮文案。
const TEXT_BACK: String = "返回"

## 行条目载荷的元数据键（行自己携带条目，面板不另存「下标 → 条目」副本）。
const META_ENTRY: StringName = &"bag_entry"


## 构建面板控件树。[br]
## [br][param p_panel] 面板根节点。[br]
## [param p_title] 标题文案（由面板给出——本模块不持有面向玩家的词条）。[br]
## [br][b]返回[/b]：商店骨架的六个键 + [code]target_button[/code]——面板持有这些引用
## （不按控件路径查找）。[br]
## [br][b]「返回」转发哪个信号[/b]：显式传 [code]&"closed"[/code]——商店骨架默认
## 转发 [code]&"leave_requested"[/code]，名字对不上时 [method Object.emit_signal] 不报
## 编译错、只在运行时静默失败（按钮看着能点、点了没反应）。
static func build(p_panel: Control, p_title: String) -> Dictionary:
	var parts: Dictionary = ShopLayoutScript.build(p_panel, p_title, &"closed")
	(parts["panel"] as PanelContainer).custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)

	var target_button := Button.new()
	target_button.name = "TargetButton"
	target_button.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	target_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	target_button.focus_mode = Control.FOCUS_ALL
	ShopLayoutScript.apply_focus_ring(target_button)
	ShopLayoutScript.insert_before_list(parts, target_button)

	(parts["leave_button"] as Button).text = TEXT_BACK
	parts["target_button"] = target_button
	return parts


## 刷新目标栏文案。[br]
## [br][param p_label] 当前目标描述（角色 / 全体），[param p_all] 为真时不带切换提示。
static func set_target_text(p_target_button: Button, p_label: String,
		p_all: bool) -> void:
	var suffix: String = "" if p_all else TEXT_TARGET_HINT
	p_target_button.text = TEXT_TARGET_PREFIX + p_label + suffix


## 渲染一列条目行（可用者可选、不可用者灰显）。[br]
## [br][param p_entries] [code]CombatBagEntries.entries()[/code] 的产出。[br]
## [br][b]返回[/b]：写入的行数（面板据此更新计数，不必再数一遍子节点）。[br]
## [br][b]行文本与可用性都取自条目本身[/b]（[code]text[/code] / [code]usable[/code] 是
## [CombatBagEntries] 已经算好的结论）——本模块不重算判据，否则「界面说能用、结算层
## 说不行」会从两处判断里长出来。
static func add_entry_rows(p_item_box: VBoxContainer, p_entries: Array,
		p_on_pressed: Callable) -> int:
	var count: int = 0
	for raw: Variant in p_entries:
		if not (raw is Dictionary):
			continue
		var entry: Dictionary = raw
		var button := Button.new()
		button.name = "Entry%d" % count
		button.text = str(entry.get("text", ""))
		button.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.disabled = not bool(entry.get("usable", false))
		button.focus_mode = Control.FOCUS_ALL
		button.set_meta(META_ENTRY, entry)
		ShopLayoutScript.apply_focus_ring(button)
		button.pressed.connect(p_on_pressed.bind(count))
		p_item_box.add_child(button)
		count += 1
	return count


## 读一行的文本（[Button] 与 [Label] 都读——面板的渲染实证查询共用一条路径）。
static func row_text(p_row: Node) -> String:
	if p_row is Button:
		return (p_row as Button).text
	if p_row is Label:
		return (p_row as Label).text
	return ""


## 取某行携带的条目（没有则空字典）。
static func row_entry(p_row: Node) -> Dictionary:
	if p_row == null or not p_row.has_meta(META_ENTRY):
		return {}
	var payload: Variant = p_row.get_meta(META_ENTRY)
	return payload if payload is Dictionary else {}


## 清空一个容器（先 [method Node.remove_child] 再 [method Node.queue_free]——
## 只 [code]queue_free[/code] 的话节点要到帧末才真正离开，同一帧内
## [method Node.get_child_count] 仍数得到它，「刷新后行数」的断言会看到上一批行）。
static func clear_box(p_box: Node) -> void:
	for child: Node in p_box.get_children():
		p_box.remove_child(child)
		child.queue_free()
