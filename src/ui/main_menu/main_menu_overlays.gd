extends RefCounted
## MainMenuOverlays —— 主菜单三块场景内覆盖层的建造、装配与开合（从 main_menu.gd 拆出）。[br]
## [br][b]职责[/b]：三块覆盖层（设置面板 / 行囊与道友 / 读档槽位面板）各建一次、关掉留树、
## 再点时复用，并把它们需要的依赖接上——设置面板接按键 store（「恢复默认」要启动时那份
## 基准）、行囊界面接两个只读模型与丹药结算层、读档面板接宿主的两个出口信号。[br]
## [b]不管什么[/b]：不导航（面板报意图，跳转仍归宿主那几条按钮路由）、不读档、
## 不判定按钮亮灭（那是 [MainMenuSaveState] 的事）。[br]
## [br][b]为什么用覆盖层而不是转场[/b]（ADR-0031 §1）：能一屏共存才用覆盖层——
## 这三块都是主菜单之上的浮层，主菜单本体结构不动；「卡组编辑」相反，整屏两栏
## 与按钮列无共存余地，故走 [code]SceneManager[/code] 转场（不归本件）。[br]
## [br][b]为什么面板句柄写回宿主[/b]：三块面板是宿主的对外可见成员
## （[code]host._settings_panel[/code] / [code]_inventory_screens[/code] /
## [code]_load_slot_panel[/code]，既有用例在读），故本件建好后写回宿主自己的属性
## ——所有权仍只有一处（宿主），本件只是建造与接线的执行方（先例
## [code]settlement_host_panels.gd[/code]）。[br]
## [br][b]为什么依赖不直连 Autoload[/b]（ADR-0031 §2）：模型与结算层要的
## [code]GameStateManager[/code] / [code]CardSystem[/code] / [code]RealmSystem[/code]
## 全部由宿主在装配时从 [code]/root[/code] 取来传给本件——面板不直连 Autoload。
## 装配点漏接这类依赖不会报错，只会让功能静默失效（先例见
## [code]test_character_status_flow[/code] 的阵亡标记用例），故显式接上比默认兜底可靠。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本件只持「建过一次」这一个事实
## （记在宿主属性上）；面板内容每次打开现读，不缓存。[b]零轮询[/b]：无 [code]_process()[/code]。
##
## 来源: ADR-0031 §1/§2、design/gdd/main-menu-system.md（设置 / 行囊 / 读档入口）、
## story-002-settings-panel.md、story-003-corrupt-dialog-split.md、
## 编码标准「单文件 ≤300 行」。

## 设置面板场景（Story 002；场景内节点模式 ADR-0031 §1）。
const SETTINGS_PANEL_SCENE: PackedScene = \
		preload("res://src/ui/main_menu/SettingsPanel.tscn")
## 「行囊与道友」界面（背包 + 角色状态双页）——主菜单的覆盖层入口。
const InventoryScreensHostScript := preload(
		"res://src/ui/inventory/inventory_screens_host.gd")
## 两页的只读模型——宿主在装配时把 Autoload 接进去（面板不直连 Autoload）。
const InventoryModelScript := preload("res://src/feature/inventory/inventory_model.gd")
const StatusModelScript := preload("res://src/feature/inventory/character_status_model.gd")
## 背包内「使用丹药」的结算层——背包页只发意图，由宿主持有它去结算。
const PillUseScript := preload("res://src/feature/inventory/inventory_pill_use.gd")
## 读档槽位选择面板（纯代码构建，与设置面板同形态）。
const LoadSlotPanelScript := preload("res://src/ui/main_menu/load_slot_panel.gd")
## 读档列表组装内核（与本面板的槽位文案口径同源）。
const Logic := preload("res://src/ui/main_menu/main_menu_logic.gd")
## 槽位读取（面板内容每次打开现读——不缓存副本）。
const SaveState := preload("res://src/ui/main_menu/main_menu_save_state.gd")


## 设置 → 打开设置面板（AC-main-menu-007）。[br]
## [br][b]首次点击实例化[/b]（顶层 CanvasItem——覆盖主菜单按钮区），重复点击复用实例；
## 关闭后 [code]visible=false[/code] 留树。[br]
## [br][param p_animate] 宿主 reduce-motion 开关，透传面板（接线点随设置面板动画
## 行为统一）。[br]
## [br][b]为什么 keybind store 要在装配时注入[/b]：面板注册的「恢复默认」要拿
## 启动时快照的默认基准（LP-CODE-REVIEW H-3——共享同一实例，不各建一份）。
static func open_settings(p_host: Control, p_animate: bool) -> void:
	if p_host == null:
		return
	var panel: SettingsPanel = p_host.get(&"_settings_panel") as SettingsPanel
	if panel == null or not is_instance_valid(panel):
		panel = SETTINGS_PANEL_SCENE.instantiate()
		panel.animate = p_animate
		var store: Object = p_host.get(&"keybind_store") as Object
		if store != null:
			panel.keybind_store = store
		p_host.add_child(panel)
		p_host.set(&"_settings_panel", panel)
	panel.open()


## 「行囊与道友」→ 打开背包 + 角色状态界面（两页签，共用一次开合）。[br]
## [br][b]模型在这里装配[/b]：面板不直连 Autoload（零状态所有权），由宿主把
## 「数据实现」接到「界面接口」上——与探索装配同一分工。面板在
## [method InventoryScreensHost.open] 时现读，故不必在此预热数据。
static func open_inventory(p_host: Control) -> void:
	if p_host == null:
		return
	var screens: Control = p_host.get(&"_inventory_screens") as Control
	if screens == null or not is_instance_valid(screens):
		screens = InventoryScreensHostScript.new()
		screens.inventory_model = InventoryModelScript.new(
				p_host.get_node_or_null(NodePath("/root/GameStateManager")),
				p_host.get_node_or_null(NodePath("/root/CardSystem")))
		screens.status_model = StatusModelScript.new(
				p_host.get_node_or_null(NodePath("/root/GameStateManager")),
				p_host.get_node_or_null(NodePath("/root/RealmSystem")))
		# 丹药结算层也在这里接线（背包页的确认 → 用丹药走它）。它自己也会去找
		# Autoload，但显式接上与其余依赖同口径——漏接不会报错，只会静默失效。
		screens.pill_use = PillUseScript.new(
				p_host.get_node_or_null(NodePath("/root/GameStateManager")),
				p_host.get_node_or_null(NodePath("/root/CardSystem")))
		p_host.add_child(screens)
		p_host.set(&"_inventory_screens", screens)
	screens.open()


## 「读档」→ 打开槽位选择面板（第三条路径）。[br]
## [br][b]每次打开都重新 populate[/b]：槽位状态可能在主菜单停留期间变了（另一个进程、
## 或刚从暂停菜单退出来），面板不缓存列表（ADR-0031 §2）。[br]
## [br][b]空列表也照开[/b]（按钮 disabled 时不可达，键盘焦点防御除外）：面板会把四格
## 全画成「（空）」——比什么都不发生更能说明「你还没有存档」。[br]
## [br][b]两个出口接回宿主[/b]：选中一格报 [code]_on_load_slot_chosen[/code]（读那一格
## 走宿主那条读档链），返回报 [code]_on_load_panel_back[/code]（重刷按钮态）。
## [br][param p_entries] 可读槽位（[code]list_slots()[/code] 过滤后的条目；不传则现读）。
static func open_load_panel(p_host: Control, p_entries: Array = []) -> void:
	if p_host == null:
		return
	var panel: Control = p_host.get(&"_load_slot_panel") as Control
	if panel == null or not is_instance_valid(panel):
		panel = LoadSlotPanelScript.new()
		panel.connect(&"slot_chosen",
				Callable(p_host, &"_on_load_slot_chosen"))
		panel.connect(&"back_requested",
				Callable(p_host, &"_on_load_panel_back"))
		p_host.add_child(panel)
		p_host.set(&"_load_slot_panel", panel)
	var entries: Array = p_entries
	if entries.is_empty():
		entries = Logic.loadable_slots(SaveState.list_slots_safe(p_host))
	panel.call(&"populate", entries)
	panel.call(&"open")
	var first: Variant = panel.call(&"first_enabled_button")
	if first is Button and (first as Button).is_inside_tree():
		(first as Button).grab_focus()
