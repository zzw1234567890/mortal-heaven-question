extends RefCounted
## PauseConfirmStep —— 「在确认框里按下某颗按钮」这一步的共享实现。[br]
## [br][b]为什么单独一处[/b]：暂停菜单的两个退出按钮本轮加了二次确认，于是「按下按钮
## 之后还要在框里按一下」成了多个用例文件（含不继承共享装置的
## [code]test_pause_menu.gd[/code]）的共同步骤。抄三份会让「确认框的控件路径」有
## 三个真理来源——路径一改就漏改一处（同 [code]pause_menu_fixture.gd[/code] 的拆因）。[br]
## [br][b]静态函数[/b]：调用方各自持有菜单引用（一个来自装置、一个来自 HUD 实例），
## 故本模块不收节点、只收参数。[br]
## [br]来源: design/ux/pause-menu.md（两个确认弹窗 / Accessibility 确认弹窗防误触）。

## 确认框内按钮行的节点路径（与 [PauseMenuConfirm._build] 的构建一致）。
const BUTTONS_PATH: String = "Panel/VBox/Buttons/"


## 在确认框里按下指定按钮。[br]
## [br][param p_menu] 暂停菜单（其 [code]get_state()[/code] 持有确认框）。[br]
## [param p_button_name] 按钮名：保存并退出走 [code]ConfirmButton[/code]；
## 返回主菜单既有「确认保存」也有「不保存」两条路（[code]LeaveButton[/code]）。[br]
## [br][b]返回[/b]：是否真的按下（框没开 / 没有该按钮时为 false——调用方据此知道
## 前一步没弹出框，而不是静默当成按过了）。
static func press(p_menu: Node, p_button_name: String) -> bool:
	if p_menu == null or not is_instance_valid(p_menu) \
			or not p_menu.has_method(&"get_state"):
		return false
	var state: Variant = p_menu.call(&"get_state")
	var dialog: Variant = state.get("_confirm")
	if dialog == null or not (dialog is Node) or not is_instance_valid(dialog):
		return false
	var button: Node = (dialog as Node).get_node_or_null(BUTTONS_PATH + p_button_name)
	if not (button is Button):
		return false
	(button as Button).pressed.emit()
	return true
