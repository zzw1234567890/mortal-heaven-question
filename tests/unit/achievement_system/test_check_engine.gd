extends GutTest
## Story 7-10 验收测试：AchievementSystem check_achievements 判定引擎。
##
## 覆盖 AC-001 到 AC-010（10 条 AC）。
## 测试策略：
##   - 注入 ProgressionSystem mock
##   - 验证事件匹配、阈值判定、extra 精确匹配、幂等
##
## 设计文档来源：GDD achievement-system.md §4 成就触发机制
## Story 来源：production/epics/achievement-system/story-002-check-engine.md

const AS := preload("res://src/feature/achievement_system.gd")

var _progression_mock: Node = null


func before_each() -> void:
	_progression_mock = Node.new()
	_progression_mock.set_script(load("res://tests/unit/achievement_system/progression_mock.gd"))
	AS._progression_override = _progression_mock
	AS.initialize()


func after_each() -> void:
	AS._progression_override = null
	if _progression_mock != null:
		_progression_mock.free()
		_progression_mock = null


# ============================================================================
# AC-001：check_achievements("elite_defeated", 1) 触发 ach_first_elite_kill
# ============================================================================

func test_check_first_elite_kill() -> void:
	# Act
	var unlocked: Array = AS.check_achievements("elite_defeated", 1)

	# Assert
	assert_true(unlocked.has("ach_first_elite_kill"), "应触发 ach_first_elite_kill")


# ============================================================================
# AC-002：check_achievements("elite_defeated", 50) 触发 ach_elite_hunter
# ============================================================================

func test_check_elite_hunter() -> void:
	# Act——50 个精英击杀达到 ach_elite_hunter threshold
	var unlocked: Array = AS.check_achievements("elite_defeated", 50)

	# Assert
	assert_true(unlocked.has("ach_first_elite_kill"), "应同时触发 ach_first_elite_kill")
	assert_true(unlocked.has("ach_elite_hunter"), "应触发 ach_elite_hunter")


# ============================================================================
# AC-003：check_achievements("realm_upgraded", 3) 触发 ach_realm_golden_core
# ============================================================================

func test_check_realm_golden_core() -> void:
	# Act
	var unlocked: Array = AS.check_achievements("realm_upgraded", 3)

	# Assert
	assert_true(unlocked.has("ach_realm_golden_core"), "应触发 ach_realm_golden_core")


# ============================================================================
# AC-004：check_achievements("elite_defeated", 5) 递增 ach_elite_hunter 进度到 5
# ============================================================================

func test_check_elite_progress_increment() -> void:
	# Act
	AS.check_achievements("elite_defeated", 5)

	# Assert——ach_elite_hunter 应有进度更新
	var found: bool = false
	for call: Dictionary in _progression_mock._progress_calls:
		if str(call["id"]) == "ach_elite_hunter":
			assert_eq(int(call["increment"]), 5, "应递增 5")
			found = true
	assert_true(found, "应调用 update_achievement_progress(ach_elite_hunter, 5)")


# ============================================================================
# AC-005：check_achievements 未匹配任何成就时无操作
# ============================================================================

func test_check_no_match_no_op() -> void:
	# Act
	var unlocked: Array = AS.check_achievements("nonexistent_event", 999)

	# Assert
	assert_eq(unlocked.size(), 0, "未匹配事件应返回空列表")
	assert_eq(_progression_mock._unlock_calls.size(), 0, "不应调用 unlock_achievement")
	assert_eq(_progression_mock._progress_calls.size(), 0, "不应调用 update_achievement_progress")


# ============================================================================
# AC-006：check_achievements("ending_unlocked", 1, "ascend") 匹配 ach_ending_ascension
# ============================================================================

func test_check_ending_ascension() -> void:
	# Act
	var unlocked: Array = AS.check_achievements("ending_unlocked", 1, "ascend")

	# Assert
	assert_true(unlocked.has("ach_ending_ascension"), "应触发 ach_ending_ascension")
	assert_false(unlocked.has("ach_ending_guardian"), "不应触发 ach_ending_guardian")


# ============================================================================
# AC-007：check_achievements("ending_unlocked", 1, "guard") 匹配 ach_ending_guardian
# ============================================================================

func test_check_ending_guardian() -> void:
	# Act
	var unlocked: Array = AS.check_achievements("ending_unlocked", 1, "guard")

	# Assert
	assert_true(unlocked.has("ach_ending_guardian"), "应触发 ach_ending_guardian")
	assert_false(unlocked.has("ach_ending_ascension"), "不应触发 ach_ending_ascension")


# ============================================================================
# AC-008：check_achievements 返回已解锁的 ach_id 列表
# ============================================================================

func test_check_returns_unlocked_list() -> void:
	# Act
	var unlocked: Array = AS.check_achievements("elite_defeated", 200)

	# Assert——应返回多个成就
	assert_true(unlocked.size() >= 2, "应至少解锁 2 个成就")
	assert_true(unlocked.has("ach_first_elite_kill"), "应包含 ach_first_elite_kill")
	assert_true(unlocked.has("ach_elite_hunter"), "应包含 ach_elite_hunter")
	assert_true(unlocked.has("ach_elite_slayer"), "应包含 ach_elite_slayer")


# ============================================================================
# AC-009：已解锁的成就不重复解锁（幂等）
# ============================================================================

func test_check_idempotent() -> void:
	# Act——第一次解锁
	var first: Array = AS.check_achievements("elite_defeated", 1)
	assert_eq(first.size(), 1, "第一次应解锁 1 个")

	# Act——第二次相同事件
	var second: Array = AS.check_achievements("elite_defeated", 1)

	# Assert——不重复解锁
	assert_eq(second.size(), 0, "第二次不应重复解锁")


# ============================================================================
# AC-010：跨局累计型成就使用 update_achievement_progress
# ============================================================================

func test_cumulative_uses_progress_update() -> void:
	# Act——elite_defeated 是累计型
	AS.check_achievements("elite_defeated", 5)

	# Assert——应调用 update_achievement_progress（非 unlock_achievement）
	assert_true(_progression_mock._progress_calls.size() > 0, "累计型应调用 update_achievement_progress")
	# ach_first_elite_kill threshold=1，5>=1 应通过 progress 自动解锁
	var first_kill_unlocked: bool = false
	for call: Dictionary in _progression_mock._progress_calls:
		if str(call["id"]) == "ach_first_elite_kill":
			first_kill_unlocked = true
	assert_true(first_kill_unlocked, "ach_first_elite_kill 应使用 update_achievement_progress")
