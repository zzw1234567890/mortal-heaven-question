extends GutTest
## 主菜单「行囊与道友」入口的接线测试。[br]
## [br][b]守什么[/b]：背包与角色状态两个界面都必须[b]从主菜单进得去、退得回来[/b]
## （本轮任务书第 3 条）。界面的内部行为由
## [code]tests/integration/inventory_ui/[/code] 覆盖，本文件只管「主菜单这一跳」：
## 按钮在、连着处理函数、点一下真的把覆盖层打开了。[br]
## [br][b]装置[/b]：与 [code]test_menu_navigation.gd[/code] 同源——真实
## [code]MainMenu.tscn[/code] + mock 的场景/存档依赖（本入口不碰这两者，
## mock 只是为了让 _ready 不误触真实 Autoload）。

const MAIN_MENU_SCENE: PackedScene = preload("res://src/ui/main_menu/MainMenu.tscn")


class MockSceneManager:
	extends Node

	func get_current_scene_id() -> int:
		return 0

	func request_scene_change(_from: int, _to: int, _type: int) -> bool:
		return true


class MockSaveLoad:
	extends Node
	signal save_corrupted(slot_type: int, slot_id: int, reason: String)
	signal load_completed(success: bool)

	func list_slots() -> Array:
		return []


var menu: Control = null
var mock_sm: MockSceneManager = null
var mock_sl: MockSaveLoad = null


func before_each() -> void:
	mock_sm = MockSceneManager.new()
	mock_sl = MockSaveLoad.new()
	menu = MAIN_MENU_SCENE.instantiate()
	menu.animate = false
	menu.scene_manager = mock_sm
	menu.save_load = mock_sl
	add_child(menu)


func after_each() -> void:
	if is_instance_valid(menu):
		menu.free()
	menu = null
	if is_instance_valid(mock_sm):
		mock_sm.free()
	mock_sm = null
	if is_instance_valid(mock_sl):
		mock_sl.free()
	mock_sl = null


func test_inventory_button_exists_with_chinese_label() -> void:
	## 入口按钮在场景里，文案是中文（玩家看得见的词条不留空）。
	# Arrange + Act + Assert
	assert_true(is_instance_valid(menu.inventory_button), "主菜单应有入口按钮节点")
	assert_eq(menu.inventory_button.text, menu.TEXT_INVENTORY,
			"按钮文案应取自脚本常量（不硬编码在场景里）")
	assert_false(menu.inventory_button.text.strip_edges().is_empty(),
			"入口文案不应为空")


func test_inventory_button_pressed_signal_is_wired() -> void:
	## 按钮的 pressed 已连到处理函数（.tscn 的 connection 声明的运行时形态）。
	# Arrange + Act + Assert
	assert_true(menu.inventory_button.pressed.is_connected(menu._on_inventory_pressed),
			"InventoryButton.pressed 应连接到 _on_inventory_pressed（场景声明）")


func test_inventory_button_is_keyboard_reachable() -> void:
	## 入口支持键盘/手柄（.claude/rules/ui-code.md 双输入）——按钮默认
	## focus_mode 就是 FOCUS_ALL，这里钉住它不被误改成 FOCUS_NONE。
	# Arrange + Act + Assert
	assert_eq(menu.inventory_button.focus_mode, Control.FOCUS_ALL,
			"入口按钮应可被键盘聚焦")


func test_pressing_inventory_button_opens_the_overlay() -> void:
	## 点一下：界面被挂进主菜单树并处于打开态——「从主菜单打开」的端到端一跳。
	# Arrange
	assert_null(menu._inventory_screens, "前置：界面尚未创建（懒加载）")
	# Act
	menu._on_inventory_pressed()
	# Assert
	assert_not_null(menu._inventory_screens, "点击后应创建界面")
	if menu._inventory_screens == null:
		return
	assert_true(is_instance_valid(menu._inventory_screens), "界面实例应有效")
	assert_eq(menu._inventory_screens.get_parent(), menu, "界面应挂在主菜单下")
	assert_true(bool(menu._inventory_screens.call(&"is_open")), "点击后界面应处于打开态")


func test_pressing_inventory_button_twice_reuses_one_overlay() -> void:
	## 连点两次只有一份界面（复用式单例——与设置面板同形态，不叠两层遮罩）。
	# Arrange
	menu._on_inventory_pressed()
	var first: Control = menu._inventory_screens
	# Act
	menu._on_inventory_pressed()
	# Assert
	assert_eq(menu._inventory_screens, first, "重复点击应复用同一实例")
	assert_true(bool(first.call(&"is_open")), "重开后仍应处于打开态")


func test_overlay_close_leaves_menu_usable() -> void:
	## 返回后界面隐藏但留树（重开不重建），主菜单的入口按钮仍可再用——「有返回」
	## 的另一半是「关得掉，且关了不坏主菜单状态」。
	# Arrange
	menu._on_inventory_pressed()
	var overlay: Control = menu._inventory_screens
	# Act
	overlay.call(&"close")
	# Assert
	assert_false(bool(overlay.call(&"is_open")), "close 后应处于关闭态")
	assert_false(overlay.visible, "关闭后应隐藏")
	assert_eq(overlay.get_parent(), menu, "关闭后应留树（复用式单例）")
	assert_true(menu.inventory_button.pressed.is_connected(menu._on_inventory_pressed),
			"关闭不得破坏入口按钮的接线")


func test_overlay_is_wired_with_the_pill_use_settlement_layer() -> void:
	## [b]回归用例[/b]：主菜单装配覆盖层时把「用丹药」的结算层也接上。[br]
	## [br][b]为什么值得单测[/b]：漏接这条依赖不会报错——背包页的确认会静默落进
	## 「谁也没接」的空档（玩家点一枚丹药什么也不发生，且日志干净）。这类
	## 「装配点漏接线」的缺陷本仓库有先例（角色状态的阵亡标记），故在这里钉住。
	# Arrange + Act
	menu._on_inventory_pressed()
	# Assert
	var overlay: Control = menu._inventory_screens
	assert_not_null(overlay, "前置：点击后应创建界面")
	if overlay == null:
		return
	assert_not_null(overlay.pill_use, "装配点应把丹药结算层交给覆盖层")
	assert_true(overlay.pill_use.has_method(&"use_entry"),
			"结算层应具备 use_entry 入口")
