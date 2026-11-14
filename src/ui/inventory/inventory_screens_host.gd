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
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本宿主不持有任何玩法数据——每次
## [method open] 都让两页现读（存档在面板关闭期间可能已经变了）。[br]
## [br][b]文案本地化豁免[/b]：与 inventory_screen / character_status_screen 同源口径。
##
## 来源: ADR-0031 §1/§2、.claude/rules/ui-code.md、
## 先例 [code]settings_panel.gd[/code]（主菜单内覆盖层 + 输入锁）、
## [code]inventory_screen.gd[/code] / [code]character_status_screen.gd[/code]。

## 页签切换的合集（宿主级：背包与角色状态各自还有自己的输入处理）。[br]
## [br][b]本模块不 preload 任何模型[/b]：两个模型都是外部注入的 RefCounted
## （装配点在主菜单 / 测试装置）——宿主自己 new 一个模型等于绕开注入、
## 在无 Autoload 的环境里静默走降级分支。
const InventoryScript := preload("res://src/ui/inventory/inventory_screen.gd")
const StatusScript := preload("res://src/ui/inventory/character_status_screen.gd")

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
var input_manager: Node = null

var _tab_button: Button = null
var _tab_index: int = 0
var _pages: Array = []
var _lock_held: bool = false


func _init() -> void:
	name = "InventoryScreensHost"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false  # 挂载即隐藏（先例 SettingsPanel：靠 open() 才显示）
	_build()


func _exit_tree() -> void:
	_release_lock()


# ═══════════════════════════════════════════════════════════════════════════════
# 对外
# ═══════════════════════════════════════════════════════════════════════════════

## 打开界面（幂等：已打开时只刷新，不重复申请输入锁）。[br]
## [br]每次打开都让两页现读——关闭期间玩家可能刚打完一场（生命与收藏都变了）。
func open() -> void:
	visible = true
	_acquire_lock()
	show_page(_tab_index)

## 关闭界面——隐藏但[b]留树[/b]（复用式单例，重开不重建控件）。[br]
## [br]输入锁在这里释放：关闭是「玩家离开这一层」，锁不该留到下次打开。
func close() -> void:
	visible = false
	_release_lock()


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


## 挂一页并接上它的「返回」出口（返回 = 关闭整个界面，两页同一语义）。
func _add_page(p_page: Control, p_model: RefCounted, p_name: String) -> void:
	p_page.name = p_name
	if p_model != null and p_page.has_method(&"set_model"):
		p_page.call(&"set_model", p_model)
	p_page.visible = false
	p_page.connect(&"back_requested", close)
	add_child(p_page)
	_pages.append(p_page)


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


## 申请输入锁（幂等——重复 open 不会叠两把；[code]_lock_held[/code] 同时防
## 「同 source 重复 push」的那条 push_warning）。[br]
## [br][b]枚举值从 InputManager 自己的常量取[/b]（[code]manager.LockType.MODAL[/code]），
## 不 preload 它的脚本来抄一份——锁类型的真理来源只有一处。[br]
## [br]InputManager 缺失（剥离 Autoload 的测试环境）时静默跳过：锁是收敛 Esc
## 语义的加固，不是本界面能否工作的前提。
func _acquire_lock() -> void:
	if _lock_held:
		return
	var manager: Node = _resolve_input_manager()
	if manager == null or not manager.has_method(&"push_lock"):
		return
	var lock_type: Variant = manager.get(&"LockType")
	if lock_type == null:
		return
	manager.call(&"push_lock", lock_type.MODAL, LOCK_SOURCE)
	_lock_held = true


## 释放输入锁（未持有时为空操作；[code]_exit_tree[/code] 兜底再调一次也安全）。[br]
## [br][b]先查 [method InputManager.has_lock] 再 pop[/b]：`InputManager` 连接了
## [code]SceneTree.tree_changed[/code] 并在回调里清空整个锁栈，而本界面每次
## [method refresh] 增删行都会触发一次 [code]tree_changed[/code]——锁可能已被外部
## 清掉，此时再 pop 只会得到一条「source not found」的 push_warning 噪声。
## 查询是只读的，代价可忽略，换来日志干净。
func _release_lock() -> void:
	if not _lock_held:
		return
	_lock_held = false
	var manager: Node = _resolve_input_manager()
	if manager == null or not manager.has_method(&"pop_lock"):
		return
	if manager.has_method(&"has_lock") and not bool(manager.call(&"has_lock", LOCK_SOURCE)):
		return
	manager.call(&"pop_lock", LOCK_SOURCE)


## InputManager——注入优先，否则 Autoload 查找。
func _resolve_input_manager() -> Node:
	if input_manager != null:
		return input_manager
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath("InputManager"))
