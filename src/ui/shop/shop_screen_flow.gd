## ShopScreen 流程面（继承链第三段）——[b]刷新 / 键盘导航 / 购买 / 进出 / 上架[/b]。
##
## [b]本层职责[/b]：界面「发生什么」。[br]
##   · 刷新入口 [method refresh]——重读余额与货架、清提示行、重建行、复位游标、
##     接上模板守望；[br]
##   · 键盘 / 手柄导航（[method _input] / [method _on_focus_changed]）——走
##     [code]_input[/code] 层（排在 GUI 派发之前），是唯一能拦住引擎内置焦点导航
##     吃掉方向键的地方，顺带挡住 [code]InputManager[/code] 的 Esc → 暂停菜单；[br]
##   · 购买路径（[method _on_row_pressed] / [method _on_row_gui_input] /
##     [method _purchase]）——成功才刷新，失败也给中文原因；[br]
##   · 进出（[method _request_leave]）——经 [code]SceneManager[/code] 回主菜单
##     （ADR-0005 唯一仲裁），转场类型走 [code]GAME_TO_MENU[/code]；[br]
##   · 上架（[method _present]）、焦点兜底（[method _focus_fallback]）与模板守望接线
##     （[method _connect_templates_loaded]）。
##
## [b]环状互引都关在本段内[/b]：[method refresh] ↔ [method _connect_templates_loaded]，
## 以及 [method refresh] → [method _present] → [method _on_row_pressed] →
## [method _purchase] → [method refresh]。[b]同一段内互调自由，跨段即解析期错误[/b]
## ——这两处环就是它们同进同出的原因（见链尾段「链序不是自由选择」）。
##
## 来源: ADR-0005、ADR-0031 §2、.claude/rules/ui-code.md（双输入 + 色盲可读）、
## 先例 [code]formation_system_flow.gd[/code]。

extends "res://src/ui/shop/shop_screen_access.gd"

## 重读余额与货架、重建行、复位游标。[br]
## [br][b]重建而非就地改[/b]：买走一件后「买不起的那几行」可能变成买得起（不会，
## 只会更买不起）——但反过来余额增加时（将来售卡）就地改就漏了；重建一次的成本
## 是几行控件，换来的是「屏幕永远是当前状态的样子」。[br]
## [br][b]清空提示行[/b]：上一次的「灵石不足」与刚刚这次刷新无关，留着会让玩家
## 以为这次也被拒了。[br]
## [br][b]游标复位到首个可买行[/b]：买完一件后停在原地会让游标压在一行买不起的
## 货上（游标路径跳过禁用行，但复位那一刻的落点是明确的）。
func refresh() -> void:
	_connect_templates_loaded()
	var logic: RefCounted = _logic_
	if logic == null:
		return
	_present(int(logic.call(&"balance")), logic.call(&"rows"))
	_navigator.call(&"reset")
	_focus_fallback()


# ═══════════════════════════════════════════════════════════════════════════════
# 键盘 / 手柄导航（见类文档「事件层级 = _input」）
# ═══════════════════════════════════════════════════════════════════════════════

## 输入事件——上下选货 / 回车买入 / 取消离开，未映射的动作原样放行。[br]
## [br][b]「离开」按钮保有焦点时不吃确认键[/b]：此时 Enter 应触发那个按钮本身
## （玩家用 Tab/鼠标把焦点放过去，意图明确），游标确认让位（同商店面板口径）。[br]
## [br][b]消费即拦断[/b]：向上不再经过引擎焦点导航，也顺带挡住
## [code]InputManager[/code] 的 Esc → 暂停菜单。
func _input(p_event: InputEvent) -> void:
	if is_leave_focused() and p_event.is_action_pressed(&"ui_accept"):
		return
	if not bool(_navigator.call(&"handle_event", p_event)):
		return
	# Esc 那条路会发出回主菜单的转场（当场把本屏摘走），回到这里时本节点已不在
	# 树上——消费走空安全包装，见那边类文档。
	ConsumeScript.mark_handled(self)


## 游标变化——把键盘焦点搬到新行（焦点环由样式的 focus 状态随焦点绘制）。
func _on_focus_changed(p_index: int) -> void:
	var button: Button = _item_box.get_child(p_index) as Button
	if button != null and not button.disabled:
		button.grab_focus()


# ═══════════════════════════════════════════════════════════════════════════════
# 购买 / 进出
# ═══════════════════════════════════════════════════════════════════════════════

## 行被按下——买下并刷新。[br]
## [br][b]按下后无条件刷新[/b]：成功时余额与全列可负担态都变了；失败时刷新只是
## 让屏幕与存档保持同一个答案（比「记得在哪些分支刷新」更不容易漏）。
func _on_row_pressed(p_index: int) -> void:
	_purchase(int(_row_to_goods[p_index]))


## 点到禁用行——把拒绝原因写进提示行（见类文档「为什么买不起的行点下去仍给原因」）。[br]
## [br][b]只认左键按下[/b]：悬停 / 松开 / 右键都会送 [code]gui_input[/code]，
## 不筛会让鼠标划过一行灰货就弹一句「灵石不足」。
func _on_row_gui_input(p_event: InputEvent, p_button: Button,
		p_index: int) -> void:
	if p_button == null or not p_button.disabled:
		return
	if not (p_event is InputEventMouseButton):
		return
	var mouse: InputEventMouseButton = p_event
	if not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	_show_message(_refusal_for(int(_row_to_goods[p_index])))


## 走一次购买并把结果写进提示行（界面对结果不作判断——文案由逻辑层给出）。[br]
## [br][b]成功才刷新[/b]：失败路径不改任何状态，重建一遍行只会把游标弹回首个可买行、
## 把玩家刚点的位置弄丢。
func _purchase(p_goods_index: int) -> void:
	var logic: RefCounted = _logic_
	if logic == null:
		return
	var result: Dictionary = logic.call(&"purchase", p_goods_index)
	if bool(result.get("ok", false)):
		refresh()
	_show_message(str(result.get("reason", "")))


## 「离开」——经 [code]SceneManager[/code] 回主菜单（ADR-0005 唯一仲裁）。[br]
## [br][b]目的地固定是主菜单[/b]：坊市这一屏只从主菜单进入（探索侧商店是节点图上的
## overlay，不是这个场景），故不存在「回哪一层」的分派——写死目的地比留一个
## 永远只有一个取值的分派表更直白。[br]
## [br][b]转场类型走 GAME_TO_MENU[/b]：音频矩阵的 [code]任意 → MAIN_MENU[/code] 行
## （1.5s 淡出/淡入）由它索引；错用别的类型会把主菜单 BGM 接到游戏内过渡参数上。[br]
## [br][b]from 动态取当前场景[/b]：不写魔数（PauseMenu M-2 先例）。[br]
## [br][b]转场不可用时留在原地[/b]：把「按键失灵」变成一句看得见的回执。
func _request_leave() -> void:
	var sm: Node = SourcesScript.resolve(scene_manager, &"SceneManager")
	if sm == null or not sm.has_method(&"request_scene_change"):
		_show_message("场景管理器不可用，暂时无法离开坊市。")
		return
	var from_id: int = SceneManagerScript.SceneID.SHOP
	if sm.has_method(&"get_current_scene_id"):
		from_id = int(sm.call(&"get_current_scene_id"))
	sm.call(&"request_scene_change", from_id, SceneManagerScript.SceneID.MAIN_MENU,
			SceneManagerScript.TransitionType.GAME_TO_MENU)


# ═══════════════════════════════════════════════════════════════════════════════
# 上架 / 焦点兜底 / 模板守望
# ═══════════════════════════════════════════════════════════════════════════════

## 上架——清空旧行、按逻辑层给出的行重建、写余额与提示。[br]
## [br][b]行数口径[/b]：[method ShopLogic.rows] 已剔除模板查不到的条目，
## [member _row_to_goods] 记下「屏幕第 N 行 = 货架第几件」的对应关系。
func _present(p_balance: int, p_rows: Array) -> void:
	_balance_label.text = TEXT_BALANCE % p_balance
	_clear_items()
	_item_count = 0
	if p_rows.is_empty():
		_show_message(TEXT_EMPTY)
		return
	_show_message(TEXT_HINT)
	for raw: Variant in p_rows:
		var row: Dictionary = raw
		var button: Button = LayoutScript.add_item_row(
				_item_box, row, _item_count, _on_row_pressed)
		var row_index: int = _item_count
		button.gui_input.connect(
				func(event: InputEvent) -> void: _on_row_gui_input(event, button, row_index))
		_row_to_goods.append(int(row.get("index", row_index)))
		_item_count += 1


## 无候选行时把焦点落到「离开」——否则空货架 / 全买不起时焦点掉出本屏，
## 玩家按回车什么都不发生（Tab 也未必跳得回来）。[br]
## [br][b]提示行也换一句[/b]：此时屏幕上的唯一动作是离开，提示写成「选货」是在指路
## 到没有的东西上。
func _focus_fallback() -> void:
	if int(_navigator.call(&"focus_index")) >= 0:
		return
	if is_leave_focused():
		return
	if _leave_button != null and is_instance_valid(_leave_button):
		_leave_button.grab_focus()
		if _item_count == 0:
			_show_message(TEXT_EMPTY)
		else:
			_show_message(TEXT_LEAVE_HAS_FOCUS)
## 接上卡牌系统的「模板装载完成」信号——装载完成后自己再刷一次（见类文档
## 「模板是异步来的」）。[br]
## [br][b]挂在这里而不是 [code]_ready[/code][/b]：依赖是注入的，注入发生在进树前
## ——[code]_ready[/code] 那一刻 [member card_system] 未必已经赋好；刷新是「界面
## 开始读数据」的统一时机，接在这一处才不会漏掉后注入的场景。
func _connect_templates_loaded() -> void:
	if _watch == null:
		_watch = WatchScript.new()
	_watch.call(&"watch", SourcesScript.resolve(card_system, &"CardSystem"), refresh)
