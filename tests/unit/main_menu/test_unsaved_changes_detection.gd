extends GutTest
## main-menu Story 003 单元测试：未保存变更检测纯函数（QA AC-2）。
##
## 覆盖 QA 规格全部场景与 edge cases：[br]
##   - 任一键不同 → true[br]
##   - 全同 → false[br]
##   - int 60 vs float 60.0（视为相同——类型归一）[br]
##   - 空字典（双方均空 → false）[br]
##   - 单键变更[br]
##   - 单侧额外键（并集比较——pending/saved 双向）[br]
##
## 纯函数直调——无场景树依赖。风格先例：test_db_from_percent.gd。

const Logic := preload("res://src/ui/main_menu/settings_graphics_logic.gd")
const Store := preload("res://src/ui/main_menu/settings_store.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-2：has_unsaved_changes 逐键比较
# ═══════════════════════════════════════════════════════════════════════════════

func test_has_unsaved_changes_all_keys_equal_returns_false() -> void:
	## AC-2: 全同 → false。
	# Arrange
	var pending: Dictionary = {
		Store.GFX_KEY_MAX_FPS: 60,
		Store.GFX_KEY_QUALITY: "medium",
	}
	var saved: Dictionary = {
		Store.GFX_KEY_MAX_FPS: 60,
		Store.GFX_KEY_QUALITY: "medium",
	}
	# Act
	var changed: bool = Logic.has_unsaved_changes(pending, saved)
	# Assert
	assert_false(changed, "全同字典应判定无变更")


func test_has_unsaved_changes_single_key_differs_returns_true() -> void:
	## AC-2 edge: 单键变更 → true。
	# Arrange
	var pending: Dictionary = {
		Store.GFX_KEY_MAX_FPS: 120,  # 变更
		Store.GFX_KEY_QUALITY: "medium",
	}
	var saved: Dictionary = {
		Store.GFX_KEY_MAX_FPS: 60,
		Store.GFX_KEY_QUALITY: "medium",
	}
	# Act
	var changed: bool = Logic.has_unsaved_changes(pending, saved)
	# Assert
	assert_true(changed, "单键变更应判定有未保存变更")


func test_has_unsaved_changes_int_float_normalized_equal() -> void:
	## AC-2 edge: int 60 vs float 60.0 → 视为相同（类型归一）。
	# Arrange
	var pending: Dictionary = {Store.GFX_KEY_MAX_FPS: 60}
	var saved: Dictionary = {Store.GFX_KEY_MAX_FPS: 60.0}
	# Act
	var changed: bool = Logic.has_unsaved_changes(pending, saved)
	# Assert
	assert_false(changed, "int 60 与 float 60.0 应视为相同（类型归一）")


func test_has_unsaved_changes_int_float_different_values_returns_true() -> void:
	## AC-2 edge 对照: 数值类型归一但值不同 → true（归一不掩盖真实差异）。
	# Arrange
	var pending: Dictionary = {Store.GFX_KEY_MAX_FPS: 120}
	var saved: Dictionary = {Store.GFX_KEY_MAX_FPS: 60.0}
	# Act
	var changed: bool = Logic.has_unsaved_changes(pending, saved)
	# Assert
	assert_true(changed, "120 vs 60.0 应判定有变更")


func test_has_unsaved_changes_both_empty_returns_false() -> void:
	## AC-2 edge: 双方均为空字典 → false。
	# Arrange
	var pending: Dictionary = {}
	var saved: Dictionary = {}
	# Act
	var changed: bool = Logic.has_unsaved_changes(pending, saved)
	# Assert
	assert_false(changed, "双方空字典应判定无变更")


func test_has_unsaved_changes_pending_extra_key_returns_true() -> void:
	## AC-2 edge: pending 多出 saved 没有的键 → true（键集合并集比较）。
	# Arrange
	var pending: Dictionary = {
		Store.GFX_KEY_MAX_FPS: 60,
		Store.GFX_KEY_REDUCE_MOTION: true,  # saved 无此键
	}
	var saved: Dictionary = {Store.GFX_KEY_MAX_FPS: 60}
	# Act
	var changed: bool = Logic.has_unsaved_changes(pending, saved)
	# Assert
	assert_true(changed, "pending 额外键应判定有变更")


func test_has_unsaved_changes_saved_extra_key_returns_true() -> void:
	## AC-2 edge: saved 多出 pending 没有的键 → true（对称并集比较）。
	# Arrange
	var pending: Dictionary = {Store.GFX_KEY_MAX_FPS: 60}
	var saved: Dictionary = {
		Store.GFX_KEY_MAX_FPS: 60,
		Store.GFX_KEY_REDUCE_MOTION: false,
	}
	# Act
	var changed: bool = Logic.has_unsaved_changes(pending, saved)
	# Assert
	assert_true(changed, "saved 额外键应判定有变更")
