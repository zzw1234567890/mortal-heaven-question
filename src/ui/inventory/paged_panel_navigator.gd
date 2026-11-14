extends RefCounted
## PagedPanelNavigator —— 「分类栏 + 条目列表」型面板的键盘/手柄输入翻译。[br]
## [br][b]为什么单独一处[/b]：[InventoryScreen] 与 [CharacterStatusScreen] 此前各自
## 抄了一份完全相同的输入分支（左右切分类 + 上下选行 + 确认 + 取消，连
## 「分类栏按钮保有焦点时左右键让给它」的例外都一模一样）。本轮两个面板都要加
## 「条目可聚焦 + 确认生效」，各抄第二遍会让这段逻辑分叉成两份不相干的实现——
## 而它恰恰是行数已贴 300 软上限的面板里最不该再长的一段（同
## [ShopPanelNavigator] / [NodeGraphComponentAssembly] 的拆分先例）。[br]
## [br][b]职责边界[/b]：本模块只做「这条事件是什么意思」，不发意图也不碰状态——
## 选行与确认委托给 [ShopPanelNavigator]（它已是四个面板共用的游标实现），
## 切页调用由面板注入的回调。零状态所有权（ADR-0031 §2）。[br]
## [br][b]两种「左右」不打架[/b]：列表内的左右本无意义，页签的左右是玩家唯一的
## 键盘切法；唯一例外是分类栏自己持有键盘焦点时——此时光标就停在这一行上，
## 玩家按方向键的意图指向它，本模块把事件原样放行（同商店面板对「离开按钮持焦点
## 时不吃确认键」的处理）。[br]
## [br][b]键位走 ui_* 动作[/b]：`.claude/rules/ui-code.md`「所有交互元素必须同时支持
## 键盘/鼠标和手柄输入」——四个默认动作在键鼠与手柄上都有绑定，故一条实现同时
## 覆盖两种设备。[br]
## [br][b]事件要喂原始事件、且必须早于 GUI 派发[/b]：焦点落在 [Button] 上时引擎的
## 内置焦点导航会在 GUI 阶段先吃掉方向键，故面板须在 [method Control._input] 里
## 调用本模块（见各面板类文档「事件层级 = _input」）。[br]
##
## 来源: .claude/rules/ui-code.md（双输入 + 焦点可见）、
## ADR-0031 §2（零状态所有权）/ §4、先例 [code]shop_panel_navigator.gd[/code]。

## 游标变化（下标；-1 = 无游标）——转发自内部游标，面板据此把键盘焦点搬到对应行。
signal focus_changed(p_index: int)

## 共用游标实现（上下选行 / 确认 / 取消）。
const RowNavigatorScript := preload("res://src/ui/exploration/shop_panel_navigator.gd")

## 切页请求 [code]func(delta: int) -> void[/code]（面板决定「页」是分类还是小节）。
var _on_page: Callable = Callable()
## 内部游标（生命周期与面板一致——[method bind] 时接线一次）。
var _rows: RefCounted = null


## 接线——注入行提供者与三个动作出口。[br]
## [br][param p_on_page] 切页回调 [code]func(delta: int) -> void[/code]。[br]
## [br][param p_on_activate] / [param p_on_cancel] 与 [ShopPanelNavigator.bind] 同口径
## （确认选中行 / 请求离开）。[br]
## [br][param p_rows] 行数组提供者 [code]func() -> Array[/code]——每次现取不缓存
## （刷新会换一批控件）。
func bind(p_rows: Callable, p_on_activate: Callable, p_on_cancel: Callable,
		p_on_page: Callable) -> void:
	_on_page = p_on_page
	_rows = RowNavigatorScript.new()
	_rows.call(&"bind", p_rows, p_on_activate, p_on_cancel)
	_rows.connect(&"focus_changed", _on_row_focus_changed)


## 重建后复位——游标清空后落到首个可选行（无可用行时为 -1，如实报告）。[br]
## [br][b]切页也走它[/b]：新一页的行是另一批控件，游标必须回到首行——否则会停在
## 上一页的下标上（越界或指错行）。
func reset() -> void:
	if _rows != null:
		_rows.call(&"reset")


## 当前游标下标（-1 = 无）。
func focus_index() -> int:
	return int(_rows.call(&"focus_index")) if _rows != null else -1


## 处理一条输入事件。[br]
## [br][param p_page_has_focus] 分类栏按钮是否持有键盘焦点（见类文档「两种左右」）。[br]
## [br][b]返回[/b]：是否应当消费（消费的事件由面板标记为已处理，不再向下传播）。
func handle_event(p_event: InputEvent, p_page_has_focus: bool) -> bool:
	if p_event.is_action_pressed(&"ui_left") or p_event.is_action_pressed(&"ui_right"):
		if p_page_has_focus:
			return false  # 焦点在分类栏上，方向键归它自己
		if _on_page.is_valid():
			_on_page.call(-1 if p_event.is_action_pressed(&"ui_left") else 1)
		return true
	if _rows == null:
		return false
	return bool(_rows.call(&"handle_event", p_event))


## 内部游标的焦点变化——原样转发（面板只连本模块，不必知道内部游标的存在）。
func _on_row_focus_changed(p_index: int) -> void:
	focus_changed.emit(p_index)
