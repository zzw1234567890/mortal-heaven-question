extends GutTest
## 主菜单三条开局路径的接线验收：新游戏 / 继续游戏 / 读档。[br]
## [br][b]为什么需要[/b]：本轮之前「继续游戏」读档成功之后[b]没有任何导航[/b]
## ——玩家点了按钮，界面纹丝不动（只有损坏分支有后续）；也[b]没有读档入口[/b]，
## 槽位选择是隐式的（按时间戳挑最新一格，玩家只能接受）。本文件钉住三条路径
## 各自走到哪、以及无档时的中文提示。[br]
## [br][b]覆盖[/b]：[br]
##   1. 新游戏 → IDENTITY_SELECT（既有行为，防本轮改动碰坏）；[br]
##   2. 继续游戏 → 读最新档 → 发 RESUME 意图 → 转场 EXPLORATION；[br]
##   3. 读档 → 打开槽位面板（四格）→ 选中一格 → 读那一格 → 同样转场；[br]
##   4. 无档时两个按钮都置灰，并各给一句中文说明；[br]
##   5. 「成功但空载荷」不导航也不弹损坏框（文件没坏，只是没东西可续）。[br]
## [br][b]装置[/b]：真实 [code]MainMenu.tscn[/code] + mock 的场景/存档依赖
## （同 [code]test_menu_navigation.gd[/code] 口径——本组用例测的是主菜单这一跳的
## 接线，不注入真实 Autoload 的存档文件）。[br]
##
## 来源: design/gdd/main-menu-system.md（三条路径）、ADR-0005（导航唯一入口）、
## ADR-0031 §2（UI 零状态所有权）。

const MAIN_MENU_SCENE: PackedScene = preload("res://src/ui/main_menu/MainMenu.tscn")
const SM := preload("res://src/foundation/scene_manager.gd")
const SLS := preload("res://src/foundation/save_load_system.gd")
const IntentScript := preload("res://src/feature/exploration/exploration_entry_intent.gd")

## 读档列表里的第一格（自动存档）——多数用例的默认选中项。
const AUTOSAVE: int = 0
const MANUAL: int = 1


## mock 场景管理器——记录 request_scene_change 调用（先例 test_menu_navigation）。
class MockSceneManager:
	extends Node

	var change_calls: Array = []

	func get_current_scene_id() -> int:
		return SM.SceneID.MAIN_MENU

	func request_scene_change(from: int, to: int, type: int) -> bool:
		change_calls.append([from, to, type])
		return true


## mock SaveLoadSystem——[code]list_slots[/code] 可配置；[code]load_game[/code]
## 按 [member load_result] 与 [member payload] 作答，并记录每次读的槽位。
class MockSaveLoad:
	extends Node
	signal save_corrupted(slot_type: int, slot_id: int, reason: String)
	signal load_completed(success: bool)

	var slots: Array = []
	var load_result: int = 0  # LoadResult.SUCCESS
	var payload: Dictionary = {"game_state": {}}
	var load_calls: Array = []

	func list_slots() -> Array:
		return slots

	func load_game(slot_type: int, slot_id: int) -> Dictionary:
		load_calls.append([slot_type, slot_id])
		load_completed.emit(load_result == 0)
		if load_result != 0:
			save_corrupted.emit(slot_type, slot_id, "DESERIALIZE_ERROR")
			return {"result": load_result, "data": {}}
		return {"result": 0, "data": payload}


var menu: Control = null
var mock_sm: MockSceneManager = null
var mock_sl: MockSaveLoad = null


func before_each() -> void:
	IntentScript.clear()
	mock_sm = MockSceneManager.new()
	mock_sl = MockSaveLoad.new()
	menu = MAIN_MENU_SCENE.instantiate()
	menu.animate = false
	menu.scene_manager = mock_sm
	menu.save_load = mock_sl
	add_child(menu)


func after_each() -> void:
	IntentScript.clear()
	if menu != null and is_instance_valid(menu):
		menu.free()
	menu = null
	if mock_sm != null and is_instance_valid(mock_sm):
		mock_sm.free()
	mock_sm = null
	if mock_sl != null and is_instance_valid(mock_sl):
		mock_sl.free()
	mock_sl = null


## 一格「有档」的槽位元数据（list_slots 返回契约镜像）。
func _slot(slot_type: int, slot_id: int, realm: String = "炼气期",
		timestamp: String = "2026-11-16T00:00:00") -> Dictionary:
	return {
		"slot_type": slot_type, "slot_id": slot_id, "exists": true,
		"name": "测试档", "timestamp": timestamp, "realm": realm, "playtime": 3600,
	}


## 注入槽位并让 _ready 的刷新路径真的跑一遍（信号形态，不直调私有刷新）。
func _set_slots(p_slots: Array) -> void:
	mock_sl.slots = p_slots
	mock_sl.load_completed.emit(false)


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 新游戏（既有行为——本轮不得碰坏）
# ═══════════════════════════════════════════════════════════════════════════════

func test_new_game_still_targets_identity_select() -> void:
	# Act
	menu._on_new_game_pressed()
	# Assert
	assert_eq(mock_sm.change_calls.size(), 1, "新游戏应发出一次转场请求")
	if mock_sm.change_calls.size() == 1:
		assert_eq(mock_sm.change_calls[0][1], SM.SceneID.IDENTITY_SELECT,
				"新游戏的目标仍是身份选择（新开局的第一步）")
	assert_false(IntentScript.has_pending(),
			"新开局的「进第一张图」意图由身份选择侧发出，主菜单不得抢先")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 继续游戏 → 读最新档 → 转场探索（本轮闭合的断路）
# ═══════════════════════════════════════════════════════════════════════════════

func test_continue_with_save_loads_latest_and_navigates_to_exploration() -> void:
	# Arrange——自动槽（旧）与手动 2（新）都有档
	_set_slots([
		_slot(AUTOSAVE, 0, "炼气期", "2026-11-15T00:00:00"),
		_slot(MANUAL, 2, "金丹期", "2026-11-16T00:00:00"),
	])
	assert_false(menu.continue_button.disabled, "前置：有档时继续按钮应亮起")
	# Act
	menu._on_continue_pressed()
	# Assert——读的是最新那一格
	assert_eq(mock_sl.load_calls, [[MANUAL, 2]], "应读最新档（手动 2）而不是第一格")
	# Assert——真的导航了（此前这里是死路）
	assert_eq(mock_sm.change_calls.size(), 1, "读档成功后应请求转场（不再原地不动）")
	if mock_sm.change_calls.size() == 1:
		assert_eq(mock_sm.change_calls[0][1], SM.SceneID.EXPLORATION,
				"继续游戏的目标应为探索场景")
	assert_false(menu.corrupt_dialog.visible, "成功读档不应弹损坏框")


func test_continue_marks_resume_intent_so_exploration_returns_to_last_map() -> void:
	## 意图是「回到上次那张图」的一半——没有它，探索场景会停在选图界面。
	# Arrange
	_set_slots([_slot(AUTOSAVE, 0)])
	# Act
	menu._on_continue_pressed()
	# Assert——取走即清，取到的一定是 RESUME
	assert_true(IntentScript.has_pending(), "读档成功应留下一条待消费的进入意图")
	assert_eq(IntentScript.take_entry_mode(), IntentScript.EntryMode.RESUME,
			"继续游戏留下的意图应为「续玩」（回存档里那张图）")
	assert_false(IntentScript.has_pending(), "意图取走即清——不会影响下一次进入")


func test_continue_with_empty_payload_stays_in_menu_without_corrupt_dialog() -> void:
	## 「成功但空载荷」：文件没坏，只是没有可续玩的内容——不导航、也不说谎。
	# Arrange
	_set_slots([_slot(AUTOSAVE, 0)])
	mock_sl.payload = {}
	# Act
	menu._on_continue_pressed()
	# Assert
	assert_eq(mock_sm.change_calls.size(), 0, "空载荷不应导航（进去只会是一局空档）")
	assert_false(menu.corrupt_dialog.visible, "空载荷不是损坏——不得弹损坏框")
	assert_false(IntentScript.has_pending(), "未导航就不该留下待消费意图")


func test_continue_on_corrupt_save_shows_dialog_and_does_not_navigate() -> void:
	# Arrange
	_set_slots([_slot(AUTOSAVE, 0)])
	mock_sl.load_result = SLS.LoadResult.DESERIALIZE_ERROR
	# Act
	menu._on_continue_pressed()
	# Assert
	assert_true(menu.corrupt_dialog.visible, "损坏存档应弹「存档损坏，无法读取」")
	assert_eq(mock_sm.change_calls.size(), 0, "损坏时不得导航")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 读档 → 槽位面板 → 选中一格
# ═══════════════════════════════════════════════════════════════════════════════

func test_load_button_opens_panel_with_four_slots() -> void:
	# Arrange
	_set_slots([_slot(AUTOSAVE, 0)])
	# Act
	menu._on_load_pressed()
	# Assert
	assert_not_null(menu._load_slot_panel, "点击读档应创建槽位面板")
	if menu._load_slot_panel == null:
		return
	assert_true(bool(menu._load_slot_panel.call(&"is_open")), "面板应处于打开态")
	var buttons: Array = menu._load_slot_panel.call(&"slot_buttons")
	assert_eq(buttons.size(), 4, "面板应列出四格（自动存档 + 手动 1-3）")
	assert_false((buttons[0] as Button).disabled, "有档的那一格应可点")
	assert_true((buttons[1] as Button).disabled, "空的槽位应置灰（点不动）")
	assert_eq((buttons[1] as Button).tooltip_text, "该槽位没有存档",
			"置灰的槽位应说明原因（中文）")


func test_load_slot_chosen_reads_that_slot_and_navigates() -> void:
	## 读档这条路的价值就在「玩家自己挑哪一格」——必须真的读他挑的那一格。
	# Arrange——手动 1 有档且比自动槽新；玩家仍要读手动 1
	_set_slots([
		_slot(AUTOSAVE, 0, "炼气期", "2026-11-16T00:00:00"),
		_slot(MANUAL, 1, "筑基期", "2026-11-15T00:00:00"),
	])
	menu._on_load_pressed()
	# Act——点第二格（手动 1）
	var buttons: Array = menu._load_slot_panel.call(&"slot_buttons")
	(buttons[1] as Button).pressed.emit()
	# Assert
	assert_eq(mock_sl.load_calls, [[MANUAL, 1]], "应读玩家挑的那一格（手动 1）")
	assert_eq(mock_sm.change_calls.size(), 1, "读档成功后应请求转场")
	if mock_sm.change_calls.size() == 1:
		assert_eq(mock_sm.change_calls[0][1], SM.SceneID.EXPLORATION,
				"读档的目标应为探索场景")
	assert_false(bool(menu._load_slot_panel.call(&"is_open")),
			"选中后面板应自行收起（避免与转场画面叠在一起）")
	assert_eq(IntentScript.take_entry_mode(), IntentScript.EntryMode.RESUME,
			"读档与继续游戏走同一条续玩意图")


func test_load_slot_chosen_on_corrupt_slot_shows_dialog() -> void:
	# Arrange
	_set_slots([_slot(AUTOSAVE, 0)])
	mock_sl.load_result = SLS.LoadResult.CORRUPTED
	menu._on_load_pressed()
	# Act
	(menu._load_slot_panel.call(&"slot_buttons")[0] as Button).pressed.emit()
	# Assert
	assert_true(menu.corrupt_dialog.visible, "损坏槽位应弹损坏框")
	assert_eq(mock_sm.change_calls.size(), 0, "损坏时不得导航")


func test_load_panel_back_button_closes_without_loading() -> void:
	# Arrange
	_set_slots([_slot(AUTOSAVE, 0)])
	menu._on_load_pressed()
	# Act——「返回」
	menu._load_slot_panel.call(&"_on_back_pressed")
	# Assert
	assert_false(bool(menu._load_slot_panel.call(&"is_open")), "返回后面板应关闭")
	assert_eq(mock_sl.load_calls.size(), 0, "返回不得触发任何读档")
	assert_eq(mock_sm.change_calls.size(), 0, "返回不得导航")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 无档：两个按钮置灰 + 中文提示
# ═══════════════════════════════════════════════════════════════════════════════

func test_no_save_disables_both_paths_and_shows_chinese_hint() -> void:
	# Arrange——before_each 的 mock 返回空列表（无档）
	# Act + Assert
	assert_true(menu.continue_button.disabled, "无档时继续游戏应置灰")
	assert_true(menu.load_button.disabled, "无档时读档应置灰")
	assert_eq(menu.no_save_hint_label.text, menu.TEXT_NO_SAVE_CONTINUE,
			"无档时应给出一句中文说明")
	assert_false(menu.no_save_hint_label.text.strip_edges().is_empty(),
			"提示不得为空串")


func test_save_present_clears_hint_and_enables_both_paths() -> void:
	# Arrange
	_set_slots([_slot(AUTOSAVE, 0)])
	# Act + Assert
	assert_false(menu.continue_button.disabled, "有档时继续游戏应亮起")
	assert_false(menu.load_button.disabled, "有档时读档应亮起")
	assert_eq(menu.no_save_hint_label.text, "", "有档时提示应清空")


func test_snapshot_only_save_does_not_enable_load_button() -> void:
	## 只有战前快照时：继续游戏亮（存在一份档），读档灰（列表里没有它可读）。
	## 两个按钮的判据本就不同——共用一条会有一边说谎。
	# Arrange
	_set_slots([_slot(2, 0)])
	# Act + Assert
	assert_false(menu.continue_button.disabled, "存在存档时继续游戏应亮起")
	assert_true(menu.load_button.disabled,
			"只有快照槽时读档应置灰（点进去列表里没有它）")


func test_manual_only_save_enables_load_button() -> void:
	## 自动槽空、手动 1 有档——读档仍该亮着（两个判据不等价的另一半）。
	# Arrange
	_set_slots([_slot(MANUAL, 1)])
	# Act + Assert
	assert_false(menu.load_button.disabled, "手动槽有档时读档应亮起")
