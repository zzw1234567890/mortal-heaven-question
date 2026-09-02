extends GutTest
## Story 7-2 验收测试：ProgressionSystem achievements 领域 API。
##
## 覆盖 AC-001 到 AC-010（10 条 AC）。
## 测试策略：
##   - 直接实例化 ProgressionSystem
##   - 注册成就定义后测试 unlock/get/update_progress
##
## 设计文档来源：ADR-0012 §关键接口（achievements 领域）
## Story 来源：production/epics/progression-system/story-002-achievements-api.md

const PS := preload("res://src/meta/progression_system.gd")

var _save_load_mock: Node = null


func before_each() -> void:
	_save_load_mock = Node.new()
	_save_load_mock.set_script(load("res://tests/unit/progression_system/save_load_mock.gd"))


func after_each() -> void:
	if _save_load_mock != null:
		_save_load_mock.free()
		_save_load_mock = null


func _make_ps() -> Node:
	var ps: Node = PS.new()
	ps._save_load_override = _save_load_mock
	ps.initialize({})
	return ps


func _register_test_achievements(ps: Node) -> void:
	ps.register_achievement("ach_test", {"name": "测试成就", "category": "combat", "tier": "bronze", "target": 0})
	ps.register_achievement("ach_cumulative", {"name": "累计成就", "category": "collection", "tier": "silver", "target": 10})
	ps.register_achievement("ach_no_progress", {"name": "无进度成就", "category": "narrative", "tier": "gold", "target": 0})


# ============================================================================
# AC-001：unlock_achievement("ach_test") → {success: true}，写入 unlocked_at
# ============================================================================

func test_unlock_achievement_success() -> void:
	# Arrange
	var ps: Node = _make_ps()
	_register_test_achievements(ps)

	# Act
	var result: Dictionary = ps.unlock_achievement("ach_test")

	# Assert
	assert_true(result["success"], "解锁应返回 success: true")
	var ach: Dictionary = ps._achievements["ach_test"]
	assert_true(ach.has("unlocked_at"), "应写入 unlocked_at")
	assert_true(str(ach["unlocked_at"]).length() > 0, "unlocked_at 应为非空时间戳")

	# Cleanup
	ps.free()


# ============================================================================
# AC-002：unlock_achievement 重复解锁 → {success: false, reason: "already_unlocked"}
# ============================================================================

func test_unlock_achievement_already_unlocked() -> void:
	# Arrange
	var ps: Node = _make_ps()
	_register_test_achievements(ps)
	ps.unlock_achievement("ach_test")

	# Act
	var result: Dictionary = ps.unlock_achievement("ach_test")

	# Assert
	assert_false(result["success"], "重复解锁应返回 success: false")
	assert_eq(str(result["reason"]), "already_unlocked", "reason 应为 already_unlocked")

	# Cleanup
	ps.free()


# ============================================================================
# AC-003：get_achievement("ach_test") 返回 {id, unlocked, unlocked_at}
# ============================================================================

func test_get_achievement_returns_state() -> void:
	# Arrange
	var ps: Node = _make_ps()
	_register_test_achievements(ps)
	ps.unlock_achievement("ach_test")

	# Act
	var ach: Dictionary = ps.get_achievement("ach_test")

	# Assert
	assert_eq(str(ach["id"]), "ach_test", "应返回 id")
	assert_true(bool(ach["unlocked"]), "应返回 unlocked: true")
	assert_true(ach.has("unlocked_at"), "应包含 unlocked_at")

	# Cleanup
	ps.free()


# ============================================================================
# AC-004：get_achievements() 返回全部成就数组，已解锁按 unlocked_at DESC 排序
# ============================================================================

func test_get_achievements_sorted_by_unlocked_at_desc() -> void:
	# Arrange
	var ps: Node = _make_ps()
	_register_test_achievements(ps)
	ps.unlock_achievement("ach_no_progress")
	ps.unlock_achievement("ach_test")

	# Act
	var list: Array = ps.get_achievements()

	# Assert
	assert_eq(list.size(), 3, "应返回全部 3 个成就")
	# 已解锁的排在前面
	assert_eq(str(list[0]["id"]), "ach_test", "最新解锁的应排第一")
	assert_eq(str(list[1]["id"]), "ach_no_progress", "较早解锁的排第二")
	assert_eq(str(list[2]["id"]), "ach_cumulative", "未解锁的排最后")

	# Cleanup
	ps.free()


# ============================================================================
# AC-005：get_achievements("combat") 按 category 过滤
# ============================================================================

func test_get_achievements_filter_by_category() -> void:
	# Arrange
	var ps: Node = _make_ps()
	_register_test_achievements(ps)

	# Act
	var list: Array = ps.get_achievements("combat")

	# Assert
	assert_eq(list.size(), 1, "combat 类应只有 1 个")
	assert_eq(str(list[0]["id"]), "ach_test", "应为 ach_test")

	# Cleanup
	ps.free()


# ============================================================================
# AC-006：update_achievement_progress("ach_cumulative", 5) 递增进度 current=5
# ============================================================================

func test_update_achievement_progress_increments() -> void:
	# Arrange
	var ps: Node = _make_ps()
	_register_test_achievements(ps)

	# Act
	ps.update_achievement_progress("ach_cumulative", 5)

	# Assert
	var ach: Dictionary = ps._achievements["ach_cumulative"]
	assert_eq(int(ach["progress"]["current"]), 5, "进度 current 应为 5")
	assert_eq(int(ach["progress"]["target"]), 10, "进度 target 应为 10")
	assert_false(bool(ach["unlocked"]), "未达到 target 不应解锁")

	# Cleanup
	ps.free()


# ============================================================================
# AC-007：update_achievement_progress 达到 target 时自动调用 unlock_achievement
# ============================================================================

func test_update_achievement_progress_auto_unlock_at_target() -> void:
	# Arrange
	var ps: Node = _make_ps()
	_register_test_achievements(ps)

	# Act——先加 5，再加 5 = 10 = target
	ps.update_achievement_progress("ach_cumulative", 5)
	ps.update_achievement_progress("ach_cumulative", 5)

	# Assert
	var ach: Dictionary = ps._achievements["ach_cumulative"]
	assert_eq(int(ach["progress"]["current"]), 10, "进度应为 10")
	assert_true(bool(ach["unlocked"]), "达到 target 应自动解锁")
	assert_true(ach.has("unlocked_at"), "应有 unlocked_at")

	# Cleanup
	ps.free()


# ============================================================================
# AC-008：unlock_achievement 后 _dirty = true
# ============================================================================

func test_unlock_achievement_sets_dirty() -> void:
	# Arrange
	var ps: Node = _make_ps()
	_register_test_achievements(ps)
	assert_false(ps.has_unsaved_changes(), "初始应为 false")

	# Act
	ps.unlock_achievement("ach_test")

	# Assert
	assert_true(ps.has_unsaved_changes(), "解锁后 _dirty 应为 true")

	# Cleanup
	ps.free()


# ============================================================================
# AC-009：unlock_achievement 发射 achievement_unlocked(ach_id) 信号
# ============================================================================

func test_unlock_achievement_emits_signal() -> void:
	# Arrange
	var ps: Node = _make_ps()
	_register_test_achievements(ps)
	var received: Dictionary = {"id": "", "received": false}
	ps.achievement_unlocked.connect(func(ach_id: String): received["id"] = ach_id; received["received"] = true)

	# Act
	ps.unlock_achievement("ach_test")

	# Assert
	assert_true(received["received"], "应发射 achievement_unlocked 信号")
	assert_eq(str(received["id"]), "ach_test", "信号参数应为 ach_test")

	# Cleanup
	ps.free()


# ============================================================================
# AC-010：unlock_achievement("unknown") → {success: false, reason: "unknown_id"}
# ============================================================================

func test_unlock_achievement_unknown_id() -> void:
	# Arrange
	var ps: Node = _make_ps()
	_register_test_achievements(ps)

	# Act
	var result: Dictionary = ps.unlock_achievement("ach_nonexistent")

	# Assert
	assert_false(result["success"], "未知 ID 应返回 success: false")
	assert_eq(str(result["reason"]), "unknown_id", "reason 应为 unknown_id")

	# Cleanup
	ps.free()
