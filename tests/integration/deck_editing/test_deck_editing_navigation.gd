extends "res://tests/integration/deck_editing/deck_editing_fixture.gd"
## 卡组编辑界面 —— 键盘导航与出口用例（双输入 + 转场唯一入口）。[br]
## [br][b]守什么[/b]：[br]
##   1. 方向键换栏 / 选牌，回车增删——键盘（与手柄同一套动作）能走完全流程；[br]
##   2. 焦点落在真实行控件上（焦点可见的实证，不只看游标内部状态）；[br]
##   3. Esc 返回、不保存；「保存并返回」写盘并回到打开它的地方（经 SceneManager）；[br]
##   4. 主菜单的入口按钮存在、接线正确、点一下发出的是 DECK_EDITING 的转场请求。[br]
## [br][b]为什么单独一个文件[/b]：上一个文件覆盖的是「数据对不对」，这里覆盖的是
## 「按键有没有用」——两类断言各有各的装置前置（这里必须造输入事件），合在一起会
## 让两边都不好读（同 [code]test_shop_panel_navigation.gd[/code] 与商店流程用例的拆法）。[br]
##
## 来源: .claude/rules/ui-code.md（双输入 + 焦点可见）、ADR-0005（转场唯一仲裁）、
## ADR-0031 §1（场景内 overlay vs 场景切换）、design/ux/deck-editing-ui.md §Interaction Map。

const MainMenuScene: PackedScene = preload("res://src/ui/main_menu/MainMenu.tscn")


# ═══════════════════════════════════════════════════════════════════════════════
# 键盘导航
# ═══════════════════════════════════════════════════════════════════════════════

func test_arrow_keys_switch_columns() -> void:
	## → 切到卡组栏、← 切回收藏栏（栏下标随之改变）。
	# Arrange
	seed_collection()
	seed_deck()
	mount_screen()
	assert_eq(screen.active_column(), NavScript.COLUMN_COLLECTION, "前置：默认在收藏栏")
	# Act
	screen._input(action_event(&"ui_right"))
	# Assert
	assert_eq(screen.active_column(), NavScript.COLUMN_DECK, "→ 应切到卡组栏")
	# Act
	screen._input(action_event(&"ui_left"))
	assert_eq(screen.active_column(), NavScript.COLUMN_COLLECTION, "← 应切回收藏栏")


func test_arrow_keys_move_the_cursor_and_skip_disabled_rows() -> void:
	## ↓ 下移游标，且[b]跳过置灰的行[/b]。[br]
	## [br][b]为什么不断「恰好 +1」[/b]：装置里 2 件法宝都在卡组中，那一行的副本已用尽
	## （置灰）——游标必须跳过它落到下一个可操作的行，而不是停在一个按不动的行上。
	## 断「严格 +1」会把「跳过禁用行」这条正确行为判成失败。
	# Arrange
	seed_collection()
	seed_deck()
	mount_screen()
	var start: int = screen.focused_index()
	assert_gte(start, 0, "前置：收藏栏应有一行可选")
	assert_false(screen.get(&"_view").is_row_disabled(NavScript.COLUMN_COLLECTION, start),
			"前置：起始行应是可操作的行")
	# Act
	screen._input(action_event(&"ui_down"))
	# Assert
	var moved: int = screen.focused_index()
	assert_gt(moved, start, "↓ 应把游标往下移")
	assert_false(screen.get(&"_view").is_row_disabled(NavScript.COLUMN_COLLECTION, moved),
			"移动后落在的行不应是置灰的行（游标跳过不可操作项）")


func test_focused_row_actually_holds_keyboard_focus() -> void:
	## 焦点落在真实的行控件上——焦点环画在 [member Control.has_focus] 上，
	## 只改游标下标而没搬焦点的话，玩家看不见自己选的是哪一行。
	# Arrange
	seed_collection()
	seed_deck()
	mount_screen()
	# Act
	screen._input(action_event(&"ui_down"))
	# Assert
	assert_true(screen.is_row_focused(NavScript.COLUMN_COLLECTION, screen.focused_index()),
			"游标所在的行应持有键盘焦点")


func test_accept_key_adds_the_focused_card() -> void:
	## 回车 = 确认当前行：收藏栏的回车把那一张加进卡组（键盘走完整条增删链路）。
	# Arrange
	seed_collection()
	seed_deck()
	mount_screen()
	var index: int = collection_index_of(TALISMAN_ID)
	assert_ne(index, -1, "前置：收藏里应有符箓那一行")
	screen.select_column(NavScript.COLUMN_COLLECTION)
	while screen.focused_index() < index:
		screen._input(action_event(&"ui_down"))
	assert_eq(screen.focused_index(), index, "前置：游标应停在符箓那一行")
	var before: int = deck_ids().size()
	# Act
	screen._input(action_event(&"ui_accept"))
	# Assert
	assert_eq(deck_ids().size(), before + 1, "回车应把当前行加进卡组")


func test_cancel_key_returns_without_saving() -> void:
	## Esc = 返回且[b]不落盘[/b]：改过的卡组留在 GSM 内存里，但盘上那份没动。[br]
	## [br][b]为什么这条值得单测[/b]：两个出口语义相反（保存 / 不保存），
	## 混淆会让「我改错了想原样退出去」变成「改错了也照样存」。
	# Arrange
	seed_collection()
	seed_deck()
	mount_screen(SceneManagerScript.SceneID.MAIN_MENU)
	var index: int = collection_index_of(TALISMAN_ID)
	add_card_at(index)
	screen.refresh()
	var changed: Array = deck_ids()
	assert_eq(changed.size(), 7, "前置：内存里已改过")
	# Act
	screen._input(action_event(&"ui_cancel"))
	# Assert
	assert_eq(sm.requests.size(), 1, "Esc 应发出一次返回请求")
	assert_eq(int(last_request().get("to", -1)), SceneManagerScript.SceneID.MAIN_MENU,
			"应回到打开它的地方（这里是主菜单）")
	assert_eq(deck_ids(), changed, "Esc 不保存——内存里的改动不受影响")
	# 盘上那份没有被写过（自动存档槽位在本次用例里从未落盘）
	assert_false(FileAccess.file_exists(TEST_ROOT + "autosave/save.json"),
			"Esc 路径不应写盘")


# ═══════════════════════════════════════════════════════════════════════════════
# 出口：保存并返回
# ═══════════════════════════════════════════════════════════════════════════════

func test_save_exit_returns_to_the_scene_that_opened_it() -> void:
	## 「保存并返回」把玩家送回打开它的地方（来路由 [DeckEditingEntry] 记）。
	# Arrange
	seed_collection()
	seed_deck()
	mount_screen(SceneManagerScript.SceneID.MAIN_MENU)
	sm.current_id = SceneManagerScript.SceneID.DECK_EDITING
	# Act
	screen.press_save_exit()
	# Assert
	assert_eq(sm.requests.size(), 1, "应发出一次转场请求")
	assert_eq(int(last_request().get("from", -1)), SceneManagerScript.SceneID.DECK_EDITING,
			"from 应取当前场景 ID")
	assert_eq(int(last_request().get("to", -1)), SceneManagerScript.SceneID.MAIN_MENU,
			"应回到打开它的主菜单")
	assert_eq(int(last_request().get("type", -1)),
			SceneManagerScript.TransitionType.GAME_TO_MENU,
			"回主菜单应走 GAME_TO_MENU（音频过渡矩阵按它索引）")


func test_save_exit_from_exploration_goes_back_to_exploration() -> void:
	## 从探索进来的（将来会有的入口）：返回目标应是探索，转场类型随之改。
	# Arrange
	seed_collection()
	seed_deck()
	mount_screen(SceneManagerScript.SceneID.EXPLORATION)
	sm.current_id = SceneManagerScript.SceneID.DECK_EDITING
	# Act
	screen.press_save_exit()
	# Assert
	assert_eq(int(last_request().get("to", -1)), SceneManagerScript.SceneID.EXPLORATION,
			"应从哪来回哪去")
	assert_eq(int(last_request().get("type", -1)),
			SceneManagerScript.TransitionType.COMBAT_TO_EXPLORE,
			"回探索应走 COMBAT_TO_EXPLORE")


func test_origin_is_one_shot_so_the_next_entry_starts_clean() -> void:
	## 来路是一次性的：取走即清，下一次没记过时回落到探索
	## （不残留上一次的来路——否则第二次打开会莫名其妙回错地方）。
	# Arrange
	EntryScript.request_edit(SceneManagerScript.SceneID.MAIN_MENU)
	# Act
	var first: int = EntryScript.take_origin()
	var second: int = EntryScript.take_origin()
	# Assert
	assert_eq(first, SceneManagerScript.SceneID.MAIN_MENU, "第一次应取到记下的来路")
	assert_eq(second, SceneManagerScript.SceneID.EXPLORATION,
			"第二次应回落探索（来路已被取走）")


func test_save_exit_still_leaves_when_the_save_reports_nothing_to_save() -> void:
	## 保存回执是「还没开局」时也照走：卡组已经改在 GSM 里了，卡在这一屏只会更困惑。
	# Arrange
	seed_collection()
	seed_deck()
	GameStateManager.player.identity_id = ""
	mount_screen(SceneManagerScript.SceneID.MAIN_MENU)
	sm.current_id = SceneManagerScript.SceneID.DECK_EDITING
	# Act
	screen.press_save_exit()
	# Assert
	assert_eq(sm.requests.size(), 1, "保存失败也应照常返回（不留玩家在这一屏）")


# ═══════════════════════════════════════════════════════════════════════════════
# 主菜单入口
# ═══════════════════════════════════════════════════════════════════════════════

## 主菜单桩：场景管理 + 存档读写都不触真实 Autoload（本入口不碰它们，
## 桩只是为了让 [code]_ready[/code] 不误触）。
class MainMenuSaveStub extends Node:
	signal save_corrupted(slot_type: int, slot_id: int, reason: String)
	signal load_completed(success: bool)

	func list_slots() -> Array:
		return []


var menu: Control = null
var _menu_sl: MainMenuSaveStub = null


func _mount_main_menu() -> Control:
	_menu_sl = MainMenuSaveStub.new()
	add_child_autofree(_menu_sl)
	sm.requests.clear()
	menu = MainMenuScene.instantiate()
	menu.animate = false
	menu.scene_manager = sm
	menu.save_load = _menu_sl
	add_child_autofree(menu)
	return menu


func test_main_menu_has_a_deck_edit_entry_button() -> void:
	## 入口按钮在场景里、文案是中文、可被键盘聚焦（与既有按钮同一套焦点链）。
	# Arrange + Act
	_mount_main_menu()
	# Assert
	assert_true(is_instance_valid(menu.deck_edit_button), "主菜单应有「卡组编辑」按钮")
	assert_eq(menu.deck_edit_button.text, menu.TEXT_DECK_EDIT,
			"按钮文案应取自脚本常量（不硬编码在场景里）")
	assert_eq(menu.deck_edit_button.focus_mode, Control.FOCUS_ALL,
			"入口按钮应可被键盘聚焦")


func test_main_menu_deck_edit_button_is_wired() -> void:
	## .tscn 的 connection 声明在运行时确实连上了处理函数。
	# Arrange + Act
	_mount_main_menu()
	# Assert
	assert_true(menu.deck_edit_button.pressed.is_connected(menu._on_deck_edit_pressed),
			"DeckEditButton.pressed 应连接到 _on_deck_edit_pressed（场景声明）")


func test_pressing_main_menu_entry_requests_the_deck_editing_scene() -> void:
	## 点一下：发出一次 DECK_EDITING 的转场请求（经 SceneManager 桩记录），
	## 并把来路记成主菜单（编辑屏据此回得来）。
	# Arrange
	_mount_main_menu()
	sm.current_id = SceneManagerScript.SceneID.MAIN_MENU
	# Act
	menu._on_deck_edit_pressed()
	# Assert
	assert_eq(sm.requests.size(), 1, "应发出一次转场请求")
	assert_eq(int(last_request().get("from", -1)), SceneManagerScript.SceneID.MAIN_MENU,
			"from 应取当前场景 ID")
	assert_eq(int(last_request().get("to", -1)), SceneManagerScript.SceneID.DECK_EDITING,
			"目标应是卡组编辑场景")
	assert_eq(int(last_request().get("type", -1)),
			SceneManagerScript.TransitionType.MENU_TO_GAME,
			"主菜单进游戏界面应走 MENU_TO_GAME")
	assert_eq(EntryScript.take_origin(), SceneManagerScript.SceneID.MAIN_MENU,
			"来路应记成主菜单（编辑屏「保存并返回」据此回得来）")


func test_main_menu_entry_is_reachable_in_the_focus_chain() -> void:
	## 焦点链：入口与既有主按钮同容器（同一套样式），且可聚焦——
	## 键盘 Tab 走得到它（.claude/rules/ui-code.md：所有交互元素双输入）。[br]
	## [br][b]为什么不断 focus_neighbor_top[/b]：.tscn 里没有显式声明邻居，
	## 引擎按容器内的树序自动串——断一个恒为空串的字段等于在断言「没写」这件事，
	## 而真正要守的是「它在同一条链上、且真的能拿到焦点」。
	# Arrange + Act
	_mount_main_menu()
	# Assert
	assert_eq(menu.deck_edit_button.get_parent(), menu.get_node("LayoutAnchor/ButtonBox"),
			"入口应挂在与其他主按钮同一个容器里（同一套样式与焦点链）")
	assert_eq(menu.deck_edit_button.focus_mode, Control.FOCUS_ALL,
			"入口应可被键盘聚焦")
	assert_eq(menu.deck_edit_button.get_index(),
			menu.settings_button.get_index() + 1,
			"入口应紧跟在「设置」之后（焦点链顺序与视觉顺序一致）")


func after_each() -> void:
	# [b]必须 await[/b]：基类的收尾里有等一帧（等 [code]queue_free[/code] 的行控件
	# 真正释放）。不 await 的话基类会在第一个 await 处停住，后面的状态还原与目录清理
	# 全部不会执行——症状是本文件的用例污染后续用例，且行控件被报成 orphan。
	await super.after_each()
	if menu != null and is_instance_valid(menu):
		menu = null
	_menu_sl = null
