extends RefCounted
## DeckEditingNavigator —— 卡组编辑两栏界面的[b]键盘/手柄游标[/b]（纯逻辑，不碰控件树）。[br]
## [br][b]职责[/b]：持有一个「当前栏 + 栏内当前行」的游标，把方向键 / 确认 / 取消翻译成
## 四件事——换栏、栏内移动、确认当前行、请求离开。[br]
## [br][b]为什么不用 [PagedPanelNavigator][/b]：那个是「分类栏 + 单列表」的形态（左右
## 是切页、页面由面板重建），而这里是[b]两栏并排、两栏各自保有自己的行[/b]——左右键
## 在玩家心里是「把注意力挪到另一栏」，不是「翻页重新加载」。行为差异具体在两点：
## 换栏后各栏的游标位置要[b]各自记住[/b]（从右栏回左栏时还停在刚才那张卡上），
## 以及换栏不该触发任何刷新（两栏的行都是同一批控件，一直在树上）。[br]
## [br][b]为什么还复用 [ShopPanelNavigator][/b]：栏内上下选行 / 确认 / 取消与商店面板
## 是同一件事（跳过禁用行、不环绕、确认复用按钮自身的 pressed），已有实现与用例；
## 本模块只加「哪一栏是活跃的」这一层，两栏各持一个该游标。[br]
## [br][b]禁用行不可选中[/b]：左栏「副本都已在卡组里」的行、右栏在卡组最低张数时的行
## 都置 [member Button.disabled]——游标据它跳过（引擎的焦点导航不会替我们跳过）。[br]
## [br][b]不环绕[/b]：走到头即停（与引擎内置焦点导航同语义）——环绕会让「已经到底了」
## 这件事不可观测。[br]
## [br][b]键位走 ui_* 动作[/b]：`.claude/rules/ui-code.md`「所有交互元素必须同时支持
## 键盘/鼠标和手柄输入」——四个默认动作在键鼠与手柄上都有绑定，故一条实现同时覆盖
## 两种设备。[br]
## [br][b]事件要喂 [method InputEvent.is_action_pressed] 的原始事件[/b]：调用方须在引擎
## GUI 派发[b]之前[/b]取到事件（见 [method DeckEditingScreen._input] 的说明——焦点在
## [Button] 上时引擎的内置焦点导航会先把方向键吃掉）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：不读卡组、不读收藏、不写任何域——它只回答
## 「这条事件是什么意思」。
##
## 来源: .claude/rules/ui-code.md（双输入 + 焦点可见）、ADR-0031 §2/§4、
## design/ux/deck-editing-ui.md（§键盘焦点顺序）、先例
## [code]paged_panel_navigator.gd[/code] / [code]shop_panel_navigator.gd[/code]。

## 游标变化（栏下标 + 栏内行下标；行下标 -1 = 该栏无可选行）。
signal focus_changed(p_column: int, p_index: int)

## 栏内游标实现（上下选行 / 确认 / 取消与商店面板同一份——见类文档）。
const RowNavigatorScript := preload("res://src/ui/exploration/shop_panel_navigator.gd")

## 左栏（收藏）下标。
const COLUMN_COLLECTION: int = 0
## 右栏（卡组）下标。
const COLUMN_DECK: int = 1

## 行提供者 [code]func(column: int) -> Array[/code]（每次现取不缓存——刷新会换控件）。
var _rows: Callable = Callable()
## 确认回调 [code]func(column: int, index: int) -> void[/code]。
var _on_activate: Callable = Callable()
## 请求离开 [code]func() -> void[/code]。
var _on_cancel: Callable = Callable()
## 两栏各自的行内游标（下标即栏下标——见 [constant COLUMN_COLLECTION]）。
var _cursors: Array = []

## 当前活跃栏下标。
var _column: int = COLUMN_COLLECTION


## 接线——注入行提供者与两个动作出口（界面构建时调用一次）。[br]
## [br][param p_on_page] 换栏回调 [code]func(column: int) -> void[/code]（界面据此把
## 键盘焦点搬到新栏的当前行）。缺省时换栏只改游标、不动焦点。
func bind(p_rows: Callable, p_on_activate: Callable, p_on_cancel: Callable,
		p_on_page: Callable = Callable()) -> void:
	_rows = p_rows
	_on_activate = p_on_activate
	_on_cancel = p_on_cancel
	_on_page = p_on_page
	_cursors = []
	for column: int in [COLUMN_COLLECTION, COLUMN_DECK]:
		var cursor: RefCounted = RowNavigatorScript.new()
		cursor.call(&"bind", _rows_for.bind(column), _activate_for.bind(column),
				_on_cancel)
		cursor.connect(&"focus_changed", _on_row_focus_changed.bind(column))
		_cursors.append(cursor)


## 换栏回调（见 [method bind]）。
var _on_page: Callable = Callable()


## 两栏重建后复位——各自落到首个可选行（无可用行时为 -1，如实报告）。[br]
## [br][b]活跃栏不变[/b]：重建是因为刚做了一次增删，玩家的注意力还在原来那一栏
## （加完一张还想再加一张）——把栏切回左边只会让人重新找位置。
func reset() -> void:
	for cursor: RefCounted in _cursors:
		cursor.call(&"reset")
	_emit_focus()


## 当前活跃栏下标（[constant COLUMN_COLLECTION] / [constant COLUMN_DECK]）。
func column() -> int:
	return _column


## 当前活跃栏内的游标下标（-1 = 该栏无可选行）。
func focus_index() -> int:
	return int(_cursor().call(&"focus_index"))


## 换到 [param p_column] 栏（越界夹到合法范围；同栏时为空操作——不重复发信号）。[br]
## [br][b]返回[/b]：换栏后的栏下标。
func set_column(p_column: int) -> int:
	var target: int = clampi(p_column, COLUMN_COLLECTION, COLUMN_DECK)
	if target == _column:
		return _column
	_column = target
	if _on_page.is_valid():
		_on_page.call(_column)
	_emit_focus()
	return _column


## 栏内移动 [param p_delta] 行（正为下、负为上）。[br]
## [br][b]返回[/b]：移动后的栏内游标下标。
func move(p_delta: int) -> int:
	return int(_cursor().call(&"move", p_delta))


## 确认当前行。[br]
## [br][b]返回[/b]：是否发起了动作（无可选行 / 当前行禁用时为 false——禁用行不发意图，
## 与鼠标点击同口径）。
func activate() -> bool:
	return bool(_cursor().call(&"activate"))


## 处理一条输入事件。[br]
## [br][b]返回[/b]：是否应当消费（消费的事件由界面标记为已处理，不再向下传播）。[br]
## [br]未映射的动作（鼠标、Tab 焦点切换、无关按键）原样放行——界面只吃这四个动作。
func handle_event(p_event: InputEvent) -> bool:
	if p_event.is_action_pressed(&"ui_left"):
		set_column(COLUMN_COLLECTION)
		return true
	if p_event.is_action_pressed(&"ui_right"):
		set_column(COLUMN_DECK)
		return true
	if p_event.is_action_pressed(&"ui_down"):
		move(1)
		return true
	if p_event.is_action_pressed(&"ui_up"):
		move(-1)
		return true
	if p_event.is_action_pressed(&"ui_accept"):
		return activate()
	if p_event.is_action_pressed(&"ui_cancel"):
		if _on_cancel.is_valid():
			_on_cancel.call()
		return true
	return false


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 当前活跃栏的游标（[method bind] 之前为空数组——取不到时给一个空壳，不崩）。[br]
## [br]空壳是惰性建的：界面在 [method bind] 之前误调（如 [code]_ready[/code] 顺序
## 反了）也只会得到 -1 而不是空指针崩溃——「游标还没接上」不该表现成进程级错误。
func _cursor() -> RefCounted:
	if _cursors.is_empty():
		var stub: RefCounted = RowNavigatorScript.new()
		_cursors = [stub, RowNavigatorScript.new()]
		_column = COLUMN_COLLECTION
	return _cursors[_column]


## 某一栏的行数组（提供者缺失时为空——组件未接线的降级路径不崩）。
func _rows_for(p_column: int) -> Array:
	if not _rows.is_valid():
		return []
	var raw: Variant = _rows.call(p_column)
	return raw if raw is Array else []


## 某一栏的确认出口（把栏下标一并交给界面——同一条回调服务两栏）。[br]
## [br][b]参数顺序是 (下标, 栏) 而不是 (栏, 下标)[/b]：栏下标经
## [method Callable.bind] 绑定，而 bind 把绑定参数接在[b]调用参数之后[/b]——行游标
## 只传一个下标，绑定的栏因此落在第二位。反过来声明会让两栏互相串（在收藏栏按确认
## 变成从卡组里删一张），且不会报任何错。
func _activate_for(p_index: int, p_column: int) -> void:
	if _on_activate.is_valid():
		_on_activate.call(p_column, p_index)


## 某一栏的游标变化——原样转发（界面只连本模块，不必知道内部有两个游标）。
func _on_row_focus_changed(p_index: int, p_column: int) -> void:
	if p_column == _column:
		focus_changed.emit(p_column, p_index)


## 发一次当前焦点（换栏 / 复位后调用——界面据此搬焦点）。
func _emit_focus() -> void:
	focus_changed.emit(_column, focus_index())
