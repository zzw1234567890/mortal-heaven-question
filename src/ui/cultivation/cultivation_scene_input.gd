extends RefCounted
## CultivationSceneInput —— 修炼室的[b]键盘/手柄导航与焦点搬运[/b]（从
## [code]cultivation_screen.gd[/code] 拆出）。[br]
## [br][b]为什么单独一处[/b]：屏幕脚本要守在 300 行软上限内
## （.claude/docs/coding-standards.md），而「按了什么键、焦点搬到哪一行」与「这一屏
## 显示什么数字」是两件事（同 [code]shop_panel_navigator.gd[/code] 从商店面板拆出的
## 同一理由——本模块是它在「整屏场景」形态下的同伴）。[br]
## [br][b]游标本身不重造[/b]：上下移动 / 跳过禁用行 / 确认 / 取消全部复用
## [code]shop_panel_navigator.gd[/code]（它的契约就是「一组 [Button] + 确认 + 取消」，
## 与货架/材料列/洞府面板都无关）；本模块只负责[b]把游标接到控件树与输入事件上[/b]。[br]
## [br][b]为什么要「游标变化 → grab_focus」这一跳[/b]：[ShopPanelNavigator] 是纯逻辑，
## 不认识控件；键盘焦点与它的游标是两份状态，必须有人把它们对齐（否则游标动了、
## 屏幕上却看不出选中了哪一行）。[br]
## [br][b]事件层级 = [method Node._input][/b]：焦点落在 [Button] 上时引擎的内置焦点
## 导航会在 GUI 阶段先吃掉方向键，[code]_unhandled_key_input[/code] 收不到——
## [code]_input[/code] 排在 GUI 派发之前，是唯一能拦住的层。消费走
## [method Viewport.set_input_as_handled]（顺带挡住 [code]InputManager[/code] 的
## Esc → 暂停菜单）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本模块不读 GSM、不写玩法状态——只搬焦点与
## 转发意图；「确认意味着什么」由屏幕经 [method bind] 注入的 [Callable] 决定。[br]
##
## 来源: .claude/rules/ui-code.md（双输入 + 焦点可见）、ADR-0031 §2/§4、
## 、先例 [code]shop_panel_navigator.gd[/code] / [code]shop_screen.gd[/code]（同形态）。

## 键盘/手柄游标（纯逻辑，不碰控件树）。
const NavigatorScript := preload("res://src/ui/exploration/shop_panel_navigator.gd")

## 游标。
var _navigator: RefCounted = null
## 动作行容器（游标落点的取数源——只在 [method bind] 时取一次引用）。
var _item_box: VBoxContainer = null
## 「离开」按钮（确认键让位的判据与兜底焦点落点）。
var _leave_button: Button = null
## 点到禁用行的出口 [code]func(button: Button) -> void[/code]（可空）。
var _on_disabled_row: Callable = Callable()
## 是否已把禁用行的 [signal Control.gui_input] 接上（幂等守卫）。
var _rows_wired: bool = false


## 接线（屏幕构建完控件树后调用一次）。[br]
## [br][param p_parts] [code]CultivationSceneLayout.build[/code] 的返回值（本模块只取
## [code]item_box[/code] 与 [code]leave_button[/code]）。[br]
## [param p_on_activate] 游标确认 [code]func(index: int) -> void[/code]。[br]
## [param p_on_cancel] 取消（Esc / 手柄 B）[code]func() -> void[/code]。[br]
## [param p_on_disabled_row] 点到禁用行 [code]func(button: Button) -> void[/code]
## （可空——补这条路玩家才看得到「为什么不能点」）。
func bind(p_parts: Dictionary, p_on_activate: Callable, p_on_cancel: Callable,
		p_on_disabled_row: Callable = Callable()) -> void:
	_item_box = p_parts.get("item_box") as VBoxContainer
	_leave_button = p_parts.get("leave_button") as Button
	_on_disabled_row = p_on_disabled_row
	_navigator = NavigatorScript.new()
	_navigator.call(&"bind", _rows, p_on_activate, p_on_cancel)
	_navigator.connect(&"focus_changed", _on_focus_changed)
	_wire_disabled_rows()


## 处理一条输入事件。[br]
## [br][b]返回[/b]：是否应当消费（屏幕据此标记事件已处理，不再向下传播）。[br]
## [br][b]焦点在动作行之外时不吃确认键[/b]：本屏还有两个可聚焦控件住在动作行容器
## 之外——「离开」按钮与越阶渡劫勾选框。[code]_input[/code] 排在 GUI 派发[b]之前[/b]，
## 一旦在这里消费掉，事件就到不了那个控件：勾选框按回车会变成「确认当前动作行」
## （玩家想勾越阶，结果直接触发了渡劫），「离开」按钮同理。故此时让位，交给引擎
## 的 GUI 派发。[br]
## [br][b]为什么按「焦点在哪」判而不是按控件类型判[/b]：将来再往容器外放控件不用
## 回来改这一处；判据是「焦点有没有落在游标管得着的那批行上」。
func handle_event(p_event: InputEvent) -> bool:
	if _focus_outside_rows() and p_event.is_action_pressed(&"ui_accept"):
		return false
	return bool(_navigator.call(&"handle_event", p_event))


## 游标当前下标（-1 = 无落点）。
func focus_index() -> int:
	return int(_navigator.call(&"focus_index"))


## 无游标时复位到首个可用行；仍无可用行则把焦点交给「离开」。[br]
## [br][b]有游标就不动[/b]：本屏的动作行不重建（不像货架刷新会换一批控件），
## 每次刷新都复位会把玩家刚移到的「突破」拽回「打坐」。[br]
## [br][b]兜底落点必须有[/b]：两行都不可用时不留焦点，玩家按回车什么都不发生，
## 而屏幕上的唯一动作是「离开」。
func ensure_focus() -> void:
	if focus_index() >= 0:
		return
	_navigator.call(&"reset")
	if focus_index() >= 0:
		return
	if _leave_button != null and is_instance_valid(_leave_button):
		_leave_button.grab_focus()


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 游标变化——把键盘焦点搬到新行（焦点环由样式的 focus 状态随焦点绘制）。[br]
## [br][b]越界一律不动[/b]：复位路径会先发一次 [code]-1[/code]（清游标），而
## [method Node.get_child] 对负下标按「从末尾数」解释——不拦住就会去抓最后一行
## 的焦点，正是「清游标」要避免的事。
func _on_focus_changed(p_index: int) -> void:
	var button: Button = _row_at(p_index)
	if button != null and not button.disabled:
		button.grab_focus()


## 给每个动作行接上「点到禁用行」的出口（幂等——重复 [method bind] 不叠加连接）。[br]
## [br][b]为什么必须补这条路[/b]：禁用的 [Button] 不发 [signal Button.pressed]，
## 玩家点下去只会觉得「没反应」——补一条 [signal Control.gui_input] 才给得出原因
## （筛选「左键按下」由屏幕侧做，本模块只负责转发）。
func _wire_disabled_rows() -> void:
	if _rows_wired or not _on_disabled_row.is_valid():
		return
	_rows_wired = true
	for child: Node in _rows():
		var button: Button = child as Button
		if button != null:
			button.gui_input.connect(
					func(event: InputEvent) -> void: _on_disabled_row.call(event, button))


## 行数组——游标与焦点搬运共用的取数口（每次现取不缓存）。[br]
## [br][b]只交 [Button][/b]：本屏的中段信息块不在这个容器里（它是列表的兄弟），
## 故容器里的子节点天生都是动作行；仍按类型筛一道，防将来插入非按钮装饰。
func _rows() -> Array:
	if _item_box == null or not is_instance_valid(_item_box):
		return []
	var out: Array = []
	for child: Node in _item_box.get_children():
		if child is Button:
			out.append(child)
	return out


## 第 [param p_index] 行的控件（越界/负下标一律 null——见 [method _on_focus_changed]）。
func _row_at(p_index: int) -> Button:
	var rows: Array = _rows()
	if p_index < 0 or p_index >= rows.size():
		return null
	return rows[p_index] as Button


## 焦点是否落在游标管不着的控件上（见 [method handle_event]）。[br]
## [br][b]为什么看实况而不是记「离开有没有焦点」[/b]：容器外的可聚焦控件不止一个
## （离开按钮 + 越阶渡劫勾选框），每加一个都要补一条判据、且补漏了不会有任何报错
## ——只有玩家按回车时才发现「勾选框勾不上」。反过来问「焦点在不在我管的那批行上」
## 则天然覆盖将来新增的容器外控件。[br]
## [br][b]无焦点时返回 false[/b]：没有焦点就没有「让位」的对象，游标照常工作。
func _focus_outside_rows() -> bool:
	var viewport: Viewport = _viewport()
	if viewport == null:
		return false
	var owner: Control = viewport.gui_get_focus_owner()
	if owner == null:
		return false
	for row: Node in _rows():
		if row == owner:
			return false
	return true


## 本模块所属视口（未挂载时为 null——控件还没进树时没有视口可问）。[br]
## [br][b]为什么从 [member _item_box] 取而不是让屏幕传[/b]：本模块只被 [method bind]
## 喂过一个容器引用，屏幕那侧不必为「问一次焦点归属」再多传一个对象（同「只取
## item_box 与 leave_button」的取数口径）。
func _viewport() -> Viewport:
	if _item_box == null or not is_instance_valid(_item_box):
		return null
	return _item_box.get_viewport()
