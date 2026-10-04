extends GutTest
## main-menu Story 001 单元测试：MainMenuLogic.has_continuable_save 纯函数。
##
## 覆盖 QA 规格 AC-1（存档存在性判定）全部场景与 edge cases：[br]
##   - 单存档槽存在 → true[br]
##   - 多槽位混合存在/不存在 → true[br]
##   - 全部不存在 → false[br]
##   - 空列表 → false[br]
##   - 空状态防御：null / 非字典条目 → 安全默认 false[br]
##
## 纯函数直调——无需场景树与 Autoload。风格先例：
## tests/unit/hud/test_cultivation_bar_state.gd（arrange/act/assert）。

const LOGIC := preload("res://src/ui/main_menu/main_menu_logic.gd")

## 槽位元数据工厂（list_slots 返回契约镜像——测试数据在测试内定义，
## 绝不使用共享可变状态）。
func _slot(slot_type: int, slot_id: int, exists: bool,
		timestamp: String = "2026-09-12T00:00:00") -> Dictionary:
	return {
		"slot_type": slot_type,
		"slot_id": slot_id,
		"exists": exists,
		"name": "测试存档",
		"timestamp": timestamp,
		"realm": "炼气期",
		"playtime": 3600,
	}


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1：存档存在性判定
# ═══════════════════════════════════════════════════════════════════════════════

func test_continue_state_single_existing_slot_returns_true() -> void:
	## AC-1 edge: 单存档槽存在 → true
	# Arrange
	var slots: Array = [_slot(0, 0, true)]
	# Act
	var result: bool = LOGIC.has_continuable_save(slots)
	# Assert
	assert_true(result, "单存档存在时应返回 true（按钮亮起）")


func test_continue_state_mixed_slots_returns_true() -> void:
	## AC-1 edge: 多槽位混合存在/不存在 → true（≥1 存在即亮起）
	# Arrange —— autosave 空 + manual_1 存在 + manual_2/3 空 + snapshot 空
	var slots: Array = [
		_slot(0, 0, false),
		_slot(1, 1, true),
		_slot(1, 2, false),
		_slot(1, 3, false),
		_slot(2, 0, false),
	]
	# Act
	var result: bool = LOGIC.has_continuable_save(slots)
	# Assert
	assert_true(result, "混合槽位中 1 个存在即应返回 true")


func test_continue_state_all_slots_missing_returns_false() -> void:
	## AC-1: 全部不存在 → false（按钮灰色不可用）
	# Arrange
	var slots: Array = [
		_slot(0, 0, false),
		_slot(1, 1, false),
		_slot(1, 2, false),
		_slot(1, 3, false),
		_slot(2, 0, false),
	]
	# Act
	var result: bool = LOGIC.has_continuable_save(slots)
	# Assert
	assert_false(result, "全部不存在应返回 false")


func test_continue_state_empty_list_returns_false() -> void:
	## AC-1: 空列表 → false（QA 规格原文）
	# Arrange
	var slots: Array = []
	# Act
	var result: bool = LOGIC.has_continuable_save(slots)
	# Assert
	assert_false(result, "空列表应返回 false")


func test_continue_state_null_list_returns_false() -> void:
	## AC-1 空状态防御: null（Autoload 缺失时 UI 层安全默认）→ false——
	## 按钮禁用是安全默认态，绝不误亮起。
	# Arrange + Act
	var result: bool = LOGIC.has_continuable_save(null)
	# Assert
	assert_false(result, "null 列表应安全默认 false")


func test_continue_state_invalid_entries_do_not_crash() -> void:
	## AC-1 空状态防御: 混入非字典条目（meta.json 损坏防御）——不崩溃，
	## 有效条目仍被识别。
	# Arrange
	var slots: Array = ["corrupted_entry", _slot(0, 0, true), 42]
	# Act
	var result: bool = LOGIC.has_continuable_save(slots)
	# Assert
	assert_true(result, "非字典条目应跳过，有效条目仍返回 true")


func test_continue_state_exists_field_defaults_false() -> void:
	## AC-1 防御: 条目缺 exists 字段 → 按 false 处理（Dictionary.get 默认值）。
	# Arrange
	var slots: Array = [{"slot_type": 0, "slot_id": 0}]
	# Act
	var result: bool = LOGIC.has_continuable_save(slots)
	# Assert
	assert_false(result, "缺 exists 字段应按 false 处理")
