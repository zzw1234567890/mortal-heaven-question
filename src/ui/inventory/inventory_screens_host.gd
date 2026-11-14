class_name InventoryScreensHost
extends Control
## InventoryScreensHost —— 从主菜单打开的「背包 + 角色状态」双页界面（纯代码构建 UI）。[br]
## [br][b]为什么要一个宿主而不是两个按钮两个铺满层[/b]：两个界面共用同一次打开的
## 生命周期（同一次 Esc 拦截、同一次「返回主菜单」），分两个顶层铺满层会让
## 「返回」的归属变得含糊。本宿主自己带一列窄页签：[b]点页签或按 Tab 换页[/b]，
## 方向键左右仍归各页自己用（背包用它切分类）。[br]
## [br][b]与设置面板的关系[/b]：打开/关闭的形态与 [code]SettingsPanel[/code] 同源
## （主菜单 [code]add_child[/code] 一个覆盖层、[code]visible=false[/code] 起手、
## 复用式单例、[code]_exit_tree[/code] 兜底释放输入锁），但[b]不继承它[/b]：
## 设置面板是 [code]TabContainer[/code] + 逐标签控件树，与这里的两页只读面板没有
## 可复用部分，硬套继承只会让两边都变形。[br]
## [br][b]输入锁用 InputManager.push_lock[/b]（与设置面板同一把）：本宿主的面板是
## 只读的，不需要节点图那种「冻结舞台」语义；锁的作用是让 Esc 的语义在本层收敛，
## 释放走 [code]_exit_tree[/code] 兜底（防「面板被外部释放、锁留在栈上」）。[br]
## [br][b]为什么要 [method InputManager.has_lock] 再 pop[/b]：见
## [code]inventory_input_lock.gd[/code]——[code]InputManager[/code] 连接了
## [code]SceneTree.tree_changed[/code] 并在回调里清空整个锁栈，而本界面每次刷新
## 增删行都会触发一次 [code]tree_changed[/code]；「查询再弹」让日志保持干净。[br]
## [br][b]输入锁拆出去了[/b]：[code]inventory_input_lock.gd[/code] 只做
## 「申请 / 释放 / 兜底」三件事，本宿主留一句转发（拆因见文件行数上限）。[br]
## [br][b]为什么结算（用丹药）在这里而不在面板里[/b]：面板只发
## [signal InventoryScreen.item_use_requested]（「玩家确认了这一行」），由本宿主
## 交给 [code]InventoryPillUse[/code] 结算，再把系统给的文案回填给面板——与
## 商店面板（[code]ShopPanelScreen[/code] 发 [code]purchase_requested[/code]、
## [code]ShopNodePresenter[/code] 调系统）是同一处拆分：面板一旦直调系统，就会
## 长成第二处「谁改了存档」的现场（ADR-0031 §2）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本宿主不持有任何玩法数据——每次
## [method open] 都让两页现读（存档在面板关闭期间可能已经变了）。[br]
## [br][b]文案本地化豁免[/b]：与 inventory_screen / character_status_screen 同源口径。
##
## 来源: ADR-0031 §1/§2、.claude/rules/ui-code.md、
## 先例 [code]settings_panel.gd[/code]（主菜单内覆盖层 + 输入锁）、
## [code]shop_node_presenter.gd[/code]（面板发意图、宿主调系统）、
## [code]inventory_screen.gd[/code] / [code]character_status_screen.gd[/code]。

## 两页的脚本（宿主只负责挂载与接线——见上）。[br]
## [br][b]两个模型不经 preload[/b]：它们是外部注入的 RefCounted（装配点在主菜单 /
## 测试装置）——宿主自己 new 一个模型等于绕开注入、在无 Autoload 的环境里静默走降级分支。
const InventoryScript := preload("res://src/ui/inventory/inventory_screen.gd")
const StatusScript := preload("res://src/ui/inventory/character_status_screen.gd")
## 背包内使用丹药的结算层（本宿主是它在生产路径上的唯一调用方）。
const PillUseScript := preload("res://src/feature/inventory/inventory_pill_use.gd")
## 输入锁持有者（申请 / 释放 / 退场兜底——见类文档「输入锁拆出去了」）。
const InputLockScript := preload("res://src/ui/inventory/inventory_input_lock.gd")

## 锁来源标识——与设置面板同一把锁（同一时刻只该有一个全覆盖层）。
const LOCK_SOURCE: StringName = &"inventory_screens"

const TEXT_TITLE: String = "行囊与道友"
## 页签按钮文案（顺序即页序）。
const TAB_TEXTS: Array = ["背包", "角色状态"]
## 页签间的分隔文案（写进页签按钮行，说明还有别的页）。
const TEXT_TAB_HINT: String = "   （Tab 换页）"

## 依赖注入（测试可替换——null 时由各页自己去找 Autoload）。
var inventory_model: RefCounted = null
var status_model: RefCounted = null
## InputManager（写入同时转给锁持有者——该字段是既有注入口，不能悄悄失效）。[br]
## [br][b]为什么用背后字段[/b]：getter 里读同名属性在 GDScript 里会递归调自己，
## 必须落在一个私有字段上；setter 转发是必需的——生产路径在 [code]_init[/code]
## 之后才赋值，只认构造那一刻的注入会让锁永远拿不到管理器。
var input_manager: Node:
	get: return _input_manager
	set(value):
		_input_manager = value
		if _lock != null:
			_lock.call(&"set_input_manager", value)
## 丹药结算层（null 时本地 new——它自己去找 Autoload，全缺时其写入返回失败）。
var pill_use: RefCounted = null

var _tab_button: Button = null
var _tab_index: int = 0
var _pages: Array = []
## InputManager 的背后字段（见 [member input_manager]）。
var _input_manager: Node = null
## 输入锁持有者（[method _init] 创建——只做申请 / 释放 / 兜底）。
var _lock: RefCounted = null


func _init() -> void:
	name = "InventoryScreensHost"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false  # 挂载即隐藏（先例 SettingsPanel：靠 open() 才显示）
	_lock = InputLockScript.new(LOCK_SOURCE, input_manager)
	_build()


func _exit_tree() -> void:
	_lock.call(&"release")


# ═══════════════════════════════════════════════════════════════════════════════
# 对外
# ═══════════════════════════════════════════════════════════════════════════════

## 打开界面（幂等：已打开时只刷新，不重复申请输入锁）。[br]
## [br]每次打开都让两页现读——关闭期间玩家可能刚打完一场（生命与收藏都变了）。
func open() -> void:
	visible = true
	_lock.call(&"acquire")
	show_page(_tab_index)

## 关闭界面——隐藏但[b]留树[/b]（复用式单例，重开不重建控件）。[br]
## [br]输入锁在这里释放：关闭是「玩家离开这一层」，锁不该留到下次打开。
func close() -> void:
	visible = false
	_lock.call(&"release")


## 是否处于打开态（主菜单据此决定「再点一次是开还是关」）。
func is_open() -> bool:
	return visible


## 切到第 [param p_index] 页（越界夹到合法范围——不崩），并刷新该页。[br]
## [br]换页只刷新目标页：另一页在返回时刷新即可（少一次无用读取）。
func show_page(p_index: int) -> void:
	if _pages.is_empty():
		return
	_tab_index = clampi(p_index, 0, _pages.size() - 1)
	for index: int in range(_pages.size()):
		var page: Control = _pages[index]
		page.visible = index == _tab_index
		if index == _tab_index:
			_inject_model(index)
			page.call(&"refresh")
	_update_tab_text()


## 当前页下标。
func page_index() -> int:
	return _tab_index


## 页签文本（含当前页标记与换页提示）。
func tab_text() -> String:
	return _tab_button.text


## 取某一页（测试与主菜单的取数口——[code]0[/code] 背包 / [code]1[/code] 角色状态）。
func page(p_index: int) -> Control:
	if p_index < 0 or p_index >= _pages.size():
		return null
	return _pages[p_index]


## 测试用：按页签（切到下一页）。
func press_tab() -> void:
	_tab_button.emit_signal(&"pressed")


# ═══════════════════════════════════════════════════════════════════════════════
# 键盘（页签切换——Tab 与 Shift+Tab 都走同一个「下一页 / 上一页」出口）
# ═══════════════════════════════════════════════════════════════════════════════

## 输入事件——Tab 换页；其余（左右键、Esc）交给当前页自己处理。[br]
## [br][b]为什么不拦左右键[/b]：背包页要用它切分类——宿主抢走就等于把页内的
## 交互废掉。宿主的层级是「页的容器」，不该越过页去解释页内的方向语义。[br]
## [br][b]消费即拦断[/b]：Tab 在引擎里是默认的焦点切换键，本层吃掉它才能让
## 「换页」优先于「把焦点挪到下一个按钮」。Esc 由当前页处理并消费（本宿主不重复）。
func _input(p_event: InputEvent) -> void:
	if not visible:
		return
	if not p_event.is_action_pressed(&"ui_focus_next") \
			and not p_event.is_action_pressed(&"ui_focus_prev"):
		return
	_cycle_tab(1 if p_event.is_action_pressed(&"ui_focus_next") else -1)
	get_viewport().set_input_as_handled()


## 切到相邻页（环绕——只有两页）。[br]
## [br]每一页切走前刷新目标页，故「刚炼成的丹」在换页时立刻可见。
func _cycle_tab(p_delta: int) -> void:
	if _pages.is_empty():
		return
	show_page((_tab_index + p_delta + _pages.size()) % _pages.size())


## 页签被点击——切到下一页（鼠标路径与键盘路径同一出口）。
func _on_tab_pressed() -> void:
	_cycle_tab(1)


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 构建：遮罩 + 页签行 + 两页（每页自带标题与「返回」，故宿主不重复画标题）。
func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var bar := HBoxContainer.new()
	bar.name = "TabBar"
	bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	bar.offset_left = 24.0
	bar.offset_top = 16.0
	bar.offset_right = 624.0
	bar.offset_bottom = 56.0
	add_child(bar)

	_tab_button = Button.new()
	_tab_button.name = "TabButton"
	_tab_button.custom_minimum_size = Vector2(560.0, 40.0)
	_tab_button.focus_mode = Control.FOCUS_ALL
	_tab_button.pressed.connect(_on_tab_pressed)
	bar.add_child(_tab_button)
	_update_tab_text()

	_add_page(InventoryScript.new(), inventory_model, "InventoryPage")
	_add_page(StatusScript.new(), status_model, "StatusPage")


## 挂一页并接上它的「返回」出口（返回 = 关闭整个界面，两页同一语义）。[br]
## [br][b]背包页另外接上「使用条目」出口[/b]（见类文档「为什么结算在这里」）：
## 角色状态页没有这个信号，故用 [method Node.has_signal] 判一下再连——宿主不该
## 假设每一页都有同一套信号。
func _add_page(p_page: Control, p_model: RefCounted, p_name: String) -> void:
	p_page.name = p_name
	if p_model != null and p_page.has_method(&"set_model"):
		p_page.call(&"set_model", p_model)
	p_page.visible = false
	p_page.connect(&"back_requested", close)
	if p_page.has_signal(&"item_use_requested"):
		p_page.connect(&"item_use_requested", _on_item_use_requested)
	add_child(p_page)
	_pages.append(p_page)


## 背包页请求使用某一条目——交给结算层，然后把结果文案回填给面板。[br]
## [br][b]面板不参与判断[/b]：用得成用不成、为什么用不成，全是结算层给的
## [code]message[/code]；本宿主只做两件事——把句子显示出来、在真的消耗掉时刷新
## （[code]consumed[/code] 为真才刷新：无谓的刷新会把玩家的游标弹回首行）。[br]
## [br][b]先取文案再刷新[/b]：刷新会重置提示文案（模型缺失/空态都会改写它），
## 顺序反了玩家就看不到系统给的那句话。
func _on_item_use_requested(p_entry: Dictionary) -> void:
	var page: Control = page(0)
	var result: Dictionary = _resolve_pill_use().call(&"use_entry", p_entry)
	var message: String = str(result.get("message", ""))
	if bool(result.get("consumed", false)):
		page.call(&"refresh")
	page.call(&"show_message", message)


## 丹药结算层——注入优先，否则本地 new（它自己去找 Autoload）。
func _resolve_pill_use() -> RefCounted:
	if pill_use != null:
		return pill_use
	return PillUseScript.new()


## 把宿主当前持有的模型交给某一页。[br]
## [br][b]为什么每次 [method show_page] 都要再交一次[/b]：模型的赋值可能晚于建页
## ——主菜单先 [code]new[/code] 宿主、再赋 [code]inventory_model[/code] /
## [code]status_model[/code]，而建页发生在宿主的 [code]_init[/code] 里（那时字段还是
## null）。若只认建页那一刻的注入，生产路径会整页走「链路未就绪」的降级分支，
## 而测试路径因为「先赋字段后建页」恰好掩盖了这个顺序问题。每次换页补接线，
## 两条路径就都对了——且仍不缓存快照（读的永远是当前字段）。
func _inject_model(p_index: int) -> void:
	var page: Control = _pages[p_index]
	if not page.has_method(&"set_model"):
		return
	var model: RefCounted = inventory_model if p_index == 0 else status_model
	if model != null:
		page.call(&"set_model", model)


## 页签文本——当前页用方括号括起（同分类栏的双通道标记口径：文字承载状态）。
func _update_tab_text() -> void:
	var parts: Array = []
	for index: int in range(TAB_TEXTS.size()):
		var label: String = str(TAB_TEXTS[index])
		parts.append("[%s]" % label if index == _tab_index else label)
	_tab_button.text = TEXT_TITLE + "：" + "  ".join(parts) + TEXT_TAB_HINT
