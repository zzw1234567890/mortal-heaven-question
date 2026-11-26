## ShopScreen 接缝与访问面（继承链第二段）——[b]读数口 / 测试用按下 / 控件取值原语[/b]。
##
## [b]本层职责[/b]：界面「能被问什么」与「怎么被问」。[br]
##   · 读数口（[method item_count] / [method item_texts] / [method is_item_enabled] /
##     [method message_text] / [method balance_text] / [method focused_index] /
##     [method is_item_focused] / [method is_leave_focused]）——集成用例按名调用，
##     一律[b]不触及内部控件路径[/b]；[br]
##   · 测试用按下（[method press_item] / [method press_leave]）——不依赖真实输入
##     事件；[b]禁用行同样走「点下去给原因」那条路[/b]，与真实鼠标点击同一段代码
##     （真实点击由 [signal Control.gui_input] 送进流程段的 [method _on_row_gui_input]）；[br]
##   · 拒绝原因 [method _refusal_for]——一次「不改变状态」的拒绝：复用购买路径的
##     校验（判断与措辞只有 [method ShopLogic.purchase] 一处来源）；[br]
##   · 控件取值原语（[method _rows_of] / [method _activate_row] / [method _clear_items] /
##     [method _show_message]）——游标段与流程段共用的最小动作；[br]
##   · 环境拆除（[method _exit_tree]）——离屏时拆掉模板守望：卡牌系统是 Autoload、
##     活得比界面久，不拆的话守望对象就白拿着一个指向已释放界面的 [Callable]。
##
## [b]本层为什么排在流程段之前[/b]：[method press_item] 要调 [method _refusal_for] 与
## [method _show_message]，[method _activate_row] 要调 [method press_item]，而流程段的
## [method _present] / [method _on_row_gui_input] 反过来要调这几个——把这一组
## 「无内部依赖的取值口与原语」整体前移，链序才自洽（GDScript 解析期只认本段或祖先段）。
##
## 来源: ADR-0031 §1/§2、.claude/rules/ui-code.md（双输入）、
## 先例 [code]formation_system_access.gd[/code]。

extends "res://src/ui/shop/shop_screen_contract.gd"

## 离屏时拆掉模板守望（信号持有的是守望对象，不拆会在界面释放后仍被卡牌系统引用）。[br]
## [br][b]卡牌系统是 Autoload、活得比界面久[/b]：装载完成时它照样会发信号——
## 不拆的话守望对象就白拿着一个指向已释放界面的 [Callable]。
func _exit_tree() -> void:
	if _watch != null:
		_watch.call(&"release")
		_watch = null


# ═══════════════════════════════════════════════════════════════════════════════
# 读数口与测试用按下（不触及内部控件路径）
# ═══════════════════════════════════════════════════════════════════════════════

## 当前货架行数。
func item_count() -> int:
	return _item_count


## 全部货架行的按钮文本（渲染实证——含价格与「灵石不足」标记）。
func item_texts() -> Array:
	var out: Array = []
	for child: Node in _item_box.get_children():
		if child is Button:
			out.append((child as Button).text)
	return out


## 某行是否可买（买不起的行 [code]disabled[/code]——与探索侧商店同口径）。
func is_item_enabled(p_index: int) -> bool:
	var button: Button = _item_box.get_child(p_index) as Button
	return button != null and not button.disabled


## 当前提示行文案（不可见时返回空串）。
func message_text() -> String:
	return _message_label.text if _message_label.visible else ""


## 余额行文案（「灵石：N」）。
func balance_text() -> String:
	return _balance_label.text


## 键盘/手柄游标当前所在行（-1 = 无可选行，此时焦点在「离开」上）。
func focused_index() -> int:
	return int(_navigator.call(&"focus_index"))


## 某行当前是否持有键盘焦点（焦点可见的实证）。
func is_item_focused(p_index: int) -> bool:
	var button: Button = _item_box.get_child(p_index) as Button
	return button != null and button.has_focus()


## 「离开」按钮是否持有键盘焦点（空货架 / 全买不起时的落点）。
func is_leave_focused() -> bool:
	return _leave_button != null and is_instance_valid(_leave_button) \
			and _leave_button.has_focus()


## 测试用：按下第 [param p_index] 行（不依赖真实输入事件）。[br]
## [b]禁用行同样走「点下去给原因」那条路[/b]——与真实鼠标点击同一条代码
## （真实点击由 [signal Control.gui_input] 送进来，见 [method _on_row_gui_input]）。
func press_item(p_index: int) -> void:
	var button: Button = _item_box.get_child(p_index) as Button
	if button == null:
		return
	if button.disabled:
		_show_message(_refusal_for(int(_row_to_goods[p_index])))
		return
	button.emit_signal(&"pressed")


## 测试用：按下「离开」。
func press_leave() -> void:
	if _leave_button != null:
		_leave_button.emit_signal(&"pressed")
## 一次「不改变状态」的拒绝原因——复用购买路径的校验（校验全在动手之前，
## 禁用的行必然过不了其中一道，故这里得到的就是玩家该看到的那句话）。[br]
## [br][b]为什么调 purchase 而不是自己判一遍[/b]：判断与措辞只有一处来源；
## 自己再写一遍「余额 < 价格 → 灵石不足」就是第二份真理，且数字格式会漂移。
func _refusal_for(p_goods_index: int) -> String:
	var logic: RefCounted = _logic_
	if logic == null:
		return ""
	var result: Dictionary = logic.call(&"purchase", p_goods_index)
	return str(result.get("reason", ""))


# ═══════════════════════════════════════════════════════════════════════════════
# 控件取值原语（游标取数口 / 行清理 / 提示行写入）
# ═══════════════════════════════════════════════════════════════════════════════

## 清空货架行（含 [member _row_to_goods] 的对应关系——它与行同生共死）。
func _clear_items() -> void:
	_row_to_goods.clear()
	for child: Node in _item_box.get_children():
		_item_box.remove_child(child)
		child.queue_free()


## 当前行控件数组（游标的取数口——每次现取不缓存：刷新会换一批控件）。
func _rows_of() -> Array:
	var out: Array = []
	for child: Node in _item_box.get_children():
		out.append(child)
	return out


## 游标确认——复用按钮自身的 [signal Button.pressed]（鼠标与键盘一条实现）。
func _activate_row(p_index: int) -> void:
	press_item(p_index)
func _show_message(p_text: String) -> void:
	_message_label.text = p_text
	_message_label.visible = not p_text.strip_edges().is_empty()
