extends GutTest
## main-menu Story 001 集成测试：存档损坏路径（QA 规格 AC-3）。
##
## 覆盖场景：[br]
##   - AC-3 主体: 有效存档存在且按钮亮起 + 存档文件损坏 → 点击继续 →
##     弹「存档损坏，无法读取」→ 确认 → 返回主菜单；按钮恢复可用态[br]
##   - AC-3 edge: 损坏存档 + 无其他存档——按钮仍亮起（meta 层 exists==true），
##     点击走损坏路径[br]
##   - save_corrupted 信号路径与 load_game 返回值路径双触发守卫（不重复弹窗）[br]
##
## 集成范围：MainMenu 场景 + mock SaveLoadSystem（依赖注入——AC-3 的损坏
## 注入点在 mock 的 load_game 返回值与 save_corrupted 信号）。[br]
## 风格先例：tests/integration/hud/test_pause_menu.gd（场景实例化 + 注入 mock）。

const MAIN_MENU_SCENE: PackedScene = preload("res://src/ui/main_menu/MainMenu.tscn")


## mock SaveLoadSystem——list_slots 返回可配置槽位列表；load_game 可配置
## 返回损坏结果并同步发射 save_corrupted 信号（对齐真实 SaveLoadSystem 契约：
## DESERIALIZE_ERROR 路径发信号 + 返回非 SUCCESS 字典）。
class MockSaveLoad:
	extends Node
	signal save_corrupted(slot_type: int, slot_id: int, reason: String)
	signal load_completed(success: bool)

	var slots: Array = []
	var load_result: int = 4  # LoadResult.DESERIALIZE_ERROR
	var emit_corrupted_on_load: bool = true
	var load_calls: Array = []
	## 点击瞬间存档消失场景（GAP-3）：list_calls 计数器——点击后手动清空
	## slots 模拟 meta 在判定与读取间变化。
	var list_calls: int = 0

	func list_slots() -> Array:
		list_calls += 1
		return slots

	func load_game(slot_type: int, slot_id: int) -> Dictionary:
		load_calls.append([slot_type, slot_id])
		if emit_corrupted_on_load:
			save_corrupted.emit(slot_type, slot_id, "DESERIALIZE_ERROR")
		load_completed.emit(false)
		return {"result": load_result, "data": {}}


var menu: Control = null
var mock_sl: MockSaveLoad = null


func before_each() -> void:
	menu = MAIN_MENU_SCENE.instantiate()
	menu.animate = false
	mock_sl = MockSaveLoad.new()
	menu.save_load = mock_sl
	add_child(menu)


func after_each() -> void:
	if menu != null and is_instance_valid(menu):
		menu.free()
	menu = null
	if mock_sl != null and is_instance_valid(mock_sl):
		mock_sl.free()
	mock_sl = null


func _single_corrupted_slot() -> Array:
	## 测试数据：单一存在槽位（meta 层 exists==true——文件已损坏但 meta 未感知，
	## QL-STORY-READY 2026-09-19 裁决语义）。
	return [{
		"slot_type": 0,
		"slot_id": 0,
		"exists": true,
		"name": "损坏存档",
		"timestamp": "2026-09-12T10:00:00",
		"realm": "金丹期",
		"playtime": 3600,
	}]


# ═══════════════════════════════════════════════════════════════════════════════
# AC-3：存档损坏路径
# ═══════════════════════════════════════════════════════════════════════════════

func test_corrupt_save_button_lit_before_click() -> void:
	## AC-3 前置: 有效存档存在（meta 层）→ 按钮亮起——损坏在点击后由
	## load_game 检测（损坏感知收窄裁决）。
	# Arrange
	mock_sl.slots = _single_corrupted_slot()
	# Act —— 重新进入场景刷新存档状态（before_each 挂载时 slots 为空）
	mock_sl.load_completed.emit(false)
	# Assert
	assert_false(menu.continue_button.disabled, "meta 层存在存档时按钮应亮起")


func test_corrupt_save_click_shows_dialog() -> void:
	## AC-3 主体: 点击继续（load_game 损坏 + save_corrupted 信号）→ 弹损坏提示
	# Arrange
	mock_sl.slots = _single_corrupted_slot()
	mock_sl.load_completed.emit(false)  # 触发存档状态刷新
	# Act
	menu._on_continue_pressed()
	# Assert
	assert_true(menu.corrupt_dialog.visible,
			"存档损坏应弹出「存档损坏，无法读取」对话框")
	assert_eq(menu.corrupt_dialog.dialog_text, "存档损坏，无法读取")


func test_corrupt_save_confirm_restores_button_state() -> void:
	## AC-3 主体: 确认对话框 → 返回主菜单；提示关闭后继续按钮恢复可用态
	# Arrange —— 弹出损坏对话框
	mock_sl.slots = _single_corrupted_slot()
	mock_sl.load_completed.emit(false)
	menu._on_continue_pressed()
	assert_true(menu.corrupt_dialog.visible, "前置：对话框已弹出")
	# Act —— 确认（AcceptDialog confirmed 回调路径）
	menu._on_corrupt_dialog_confirmed()
	# Assert —— meta 层存档仍在：按钮恢复可用态（重刷后依旧亮起——
	## 与 AC-3 自洽：再次点击再走损坏路径）
	assert_false(menu.continue_button.disabled,
			"确认后按钮应恢复可用态（meta 层存在性未变）")


func test_corrupt_save_only_slot_no_others_still_lit() -> void:
	## AC-3 edge: 损坏存档 + 无其他存档——按钮仍亮起（meta 层 exists==true），
	## 点击走损坏路径弹提示。
	# Arrange —— 唯一槽位即损坏存档（无其他存档）
	mock_sl.slots = _single_corrupted_slot()
	mock_sl.load_completed.emit(false)
	# Act + Assert —— 按钮亮起 + 点击弹窗（损坏路径完整）
	assert_false(menu.continue_button.disabled, "唯一损坏存档时按钮仍应亮起")
	menu._on_continue_pressed()
	assert_true(menu.corrupt_dialog.visible, "点击应走损坏路径弹提示")


func test_corrupt_save_return_value_path_only_no_signal() -> void:
	## GAP-5 修复: 双触发源分支独立验证——仅返回值失败、不发 save_corrupted
	## 信号（FILE_NOT_FOUND 类路径）→ 弹窗仍出现（返回值路径可独立工作）。
	# Arrange
	mock_sl.slots = _single_corrupted_slot()
	mock_sl.load_result = 1  # FILE_NOT_FOUND——非 SUCCESS
	mock_sl.emit_corrupted_on_load = false  # 不发信号
	mock_sl.load_completed.emit(false)
	# Act
	menu._on_continue_pressed()
	# Assert
	assert_true(menu.corrupt_dialog.visible,
			"仅返回值失败（无信号）应弹损坏对话框")


func test_corrupt_save_signal_path_only_success_return() -> void:
	## GAP-5 修复: 双触发源分支独立验证——仅 save_corrupted 信号、返回值
	## SUCCESS → 弹窗仍出现（信号路径可独立工作；重入守卫不吞首弹）。
	# Arrange
	mock_sl.slots = _single_corrupted_slot()
	mock_sl.load_result = 0  # SUCCESS
	mock_sl.emit_corrupted_on_load = true  # 信号发射
	mock_sl.load_completed.emit(false)
	# Act
	menu._on_continue_pressed()
	# Assert
	assert_true(menu.corrupt_dialog.visible,
			"仅信号路径（返回 SUCCESS）应弹损坏对话框")


func test_corrupt_save_vanish_between_click_and_load_no_dialog() -> void:
	## GAP-3 修复: 点击瞬间存档消失——disabled 判定与 load 间列表已清空 →
	## 静默重刷按钮禁用，不误弹损坏框（零状态所有权裁决的竞态防御分支）。
	# Arrange —— 按钮亮起
	mock_sl.slots = _single_corrupted_slot()
	mock_sl.load_completed.emit(false)
	assert_false(menu.continue_button.disabled, "前置：按钮亮起")
	# Act —— 模拟 meta 在判定与读取间清空（第二次 list_slots 起返回空）
	var first_list_calls: int = mock_sl.list_calls
	mock_sl.slots = []
	# _on_continue_pressed 内部：_list_slots_safe（第2次）→ 空 → 重刷返回
	menu._on_continue_pressed()
	# Assert
	assert_true(mock_sl.list_calls > first_list_calls,
			"点击后应重新读取列表（竞态防御分支真实穿越）")
	assert_false(menu.corrupt_dialog.visible,
			"存档消失应静默重刷，不误弹损坏框")
	assert_true(menu.continue_button.disabled, "重刷后按钮应变 disabled")


func test_corrupt_save_dialog_not_shown_on_success() -> void:
	## AC-3 反向守卫: load_game 成功（不损坏）→ 不弹对话框。
	# Arrange
	mock_sl.slots = _single_corrupted_slot()
	mock_sl.load_result = 0  # LoadResult.SUCCESS
	mock_sl.emit_corrupted_on_load = false
	mock_sl.load_completed.emit(false)
	# Act
	menu._on_continue_pressed()
	# Assert
	assert_false(menu.corrupt_dialog.visible, "成功读档不应弹损坏对话框")


func test_corrupt_save_load_targets_latest_slot() -> void:
	## AC-3 补充: 点击继续 → load_game 以 select_latest_save 选取的槽位调用。
	# Arrange —— manual_2 为最新
	mock_sl.slots = [
		{
			"slot_type": 1, "slot_id": 1, "exists": true,
			"name": "旧档", "timestamp": "2026-09-11T00:00:00",
			"realm": "炼气期", "playtime": 600,
		},
		{
			"slot_type": 1, "slot_id": 2, "exists": true,
			"name": "新档", "timestamp": "2026-09-12T00:00:00",
			"realm": "金丹期", "playtime": 3600,
		},
	]
	mock_sl.load_completed.emit(false)
	# Act
	menu._on_continue_pressed()
	# Assert
	assert_eq(mock_sl.load_calls.size(), 1, "load_game 应被调用 1 次")
	if mock_sl.load_calls.size() == 1:
		assert_eq(mock_sl.load_calls[0][0], 1, "应读取 MANUAL 槽（slot_type=1）")
		assert_eq(mock_sl.load_calls[0][1], 2, "应读取最新槽 manual_2（slot_id=2）")
