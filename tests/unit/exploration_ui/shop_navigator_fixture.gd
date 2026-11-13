extends GutTest
## ShopNavigatorFixture —— 商店游标单测的共享夹具。[br]
## [br][b]为什么单独一处[/b]：游标的用例分布在两份文件（核心移动 / 输入事件翻译），
## 装置完全相同——真实 [Button] 行 + 三个注入出口 + 计数器。留在任一份用例文件里
## 都会让它越过 300 行软上限，而「怎么搭台子」与「断言什么」是两件事
## （同 [code]shop_rest_node_fixture.gd[/code]、[code]full_battle_fixture.gd[/code]
## 先例）。[br]
## [br][b]用法[/b]：子类 [code]extends "res://…/shop_navigator_fixture.gd"[/code]，
## 直接写 [code]test_*[/code] 方法；[code]before_each[/code] 由本夹具提供，子类若要
## 扩展需先 [code]super()[/code]。[br]
## [br][b]文件前缀[/b]：本文件不以 [code]test_[/code] 开头——GUT 按前缀收集，
## 因此它只作为基类被继承，不会被当作用例文件单独执行。[br]
## [br][b]为什么用真实 [Button][/b]：游标的「跳过禁用行」判据就是
## [member Button.disabled]（实测 [method Control.grab_focus] 对禁用按钮仍生效，
## 故引擎不会代劳），桩对象复现不了这条判据。[br]
##
## 来源: .claude/rules/ui-code.md（双输入）、ADR-0031 §2/§4（零状态所有权 + 双焦点）、
## GDD exploration-ui-system.md §4c、shop_panel_navigator.gd。

const Navigator := preload("res://src/ui/exploration/shop_panel_navigator.gd")

## 当前行数组（游标的取数口——每次现取，与生产同口径）。
var _rows: Array = []
## 确认所触发的下标记录。
var _activated: Array = []
## 取消（请求离开）的触发次数。
var _cancelled: int = 0
## 被测游标（每个用例新建）。
var nav: RefCounted = null


func before_each() -> void:
	_rows = []
	_activated = []
	_cancelled = 0
	nav = Navigator.new()
	nav.call(&"bind", _row_provider, _on_activate, _on_cancel)


func _row_provider() -> Array:
	return _rows


func _on_activate(p_index: int) -> void:
	_activated.append(p_index)


func _on_cancel() -> void:
	_cancelled += 1


## 造一行商品（[param p_disabled] 为 true 即售罄/灵石不足）。
func _row(p_disabled: bool) -> Button:
	var button := Button.new()
	button.disabled = p_disabled
	add_child_autofree(button)
	return button


## 造 [param p_pattern] 描述的行列（"x" = 可选，"o" = 禁用）。
func _rows_of(p_pattern: String) -> Array:
	var out: Array = []
	for i: int in range(p_pattern.length()):
		out.append(_row(p_pattern[i] == "o"))
	_rows = out
	return out
