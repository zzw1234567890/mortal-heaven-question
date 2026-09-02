extends GutTest
## Story 7-8 验收测试：settle_run 轮回结算。
##
## 覆盖 AC-001 到 AC-010（10 条 AC）。
## 测试策略：
##   - 注入 ProgressionSystem mock
##   - 验证轮回点计算公式和结算编排
##
## 设计文档来源：GDD reincarnation-talent-system.md §1/§2
## Story 来源：production/epics/reincarnation-talent-system/story-003-settle-run.md

const RTS := preload("res://src/feature/reincarnation_talent_system.gd")

var _progression_mock: Node = null


func before_each() -> void:
	_progression_mock = Node.new()
	_progression_mock.set_script(load("res://tests/unit/reincarnation_talent_system/progression_mock.gd"))
	RTS._progression_override = _progression_mock


func after_each() -> void:
	RTS._progression_override = null
	if _progression_mock != null:
		_progression_mock.free()
		_progression_mock = null


# ============================================================================
# AC-001：炼气死亡(1) → 境界²×2=2 + 保底 max(3,2) = 3
# ============================================================================

func test_calculate_points_qi_death_minimum() -> void:
	# Arrange
	var run_data: Dictionary = {
		"realm_reached": 1,
		"result": "death",
		"elites_killed": 0,
		"bosses_killed": 0,
		"unique_cards_collected": 0,
		"alchemy_count": 0,
		"forge_count": 0,
	}

	# Act
	var points: int = RTS.calculate_reincarnation_points(run_data, [])

	# Assert——1²×2=2 + 保底 max(3,2)=3
	assert_eq(points, 3, "炼气死亡保底应为 3")


# ============================================================================
# AC-002：筑基通关(2) → 8 + 通关10
# ============================================================================

func test_calculate_points_foundation_victory() -> void:
	# Arrange
	var run_data: Dictionary = {
		"realm_reached": 2,
		"result": "victory",
		"elites_killed": 3,
		"bosses_killed": 1,
		"unique_cards_collected": 10,
		"alchemy_count": 5,
		"forge_count": 0,
	}

	# Act
	var points: int = RTS.calculate_reincarnation_points(run_data, [])

	# Assert——2²×2=8 + 通关10 + 精英 min(3,6)×1=3 + Boss min(1,3)×2=2 + 收集 min(1,5)×1=1 + 炼制 min(1,5)×1=1 = 25
	assert_eq(points, 25, "筑基通关应得 25 点")


# ============================================================================
# AC-003：化神通关(5) → 50 + 10
# ============================================================================

func test_calculate_points_deity_victory() -> void:
	# Arrange
	var run_data: Dictionary = {
		"realm_reached": 5,
		"result": "victory",
		"elites_killed": 20,
		"bosses_killed": 10,
		"unique_cards_collected": 50,
		"alchemy_count": 25,
		"forge_count": 25,
	}

	# Act
	var points: int = RTS.calculate_reincarnation_points(run_data, [])

	# Assert——5²×2=50 + 通关10 + 精英 min(20,20)×1=20 + Boss min(10,10)×2=20 + 收集 min(5,5)×1=5 + 炼制 min(10,5)×1=5 = 110
	assert_eq(points, 110, "化神完美通关应得 110 点")


# ============================================================================
# AC-004：死亡保底 → 至少 3 点
# ============================================================================

func test_calculate_points_death_minimum_3() -> void:
	# Arrange——即使境界很低
	var run_data: Dictionary = {
		"realm_reached": 1,
		"result": "death",
		"elites_killed": 0,
		"bosses_killed": 0,
		"unique_cards_collected": 0,
		"alchemy_count": 0,
		"forge_count": 0,
	}

	# Act
	var points: int = RTS.calculate_reincarnation_points(run_data, [])

	# Assert
	assert_true(points >= 3, "死亡时至少 3 点轮回点")


# ============================================================================
# AC-005：超脱轮回（reincarnation_4 已解锁）→ points × 1.2
# ============================================================================

func test_calculate_points_transcend_bonus() -> void:
	# Arrange
	var run_data: Dictionary = {
		"realm_reached": 3,
		"result": "victory",
		"elites_killed": 5,
		"bosses_killed": 2,
		"unique_cards_collected": 0,
		"alchemy_count": 0,
		"forge_count": 0,
	}
	# 基础 = 3²×2=18 + 通关10 + 精英 min(5,10)×1=5 + Boss min(2,5)×2=4 = 37
	# 超脱轮回 × 1.2 = round(44.4) = 44
	var unlocked: Array = ["reincarnation_4"]

	# Act
	var points: int = RTS.calculate_reincarnation_points(run_data, unlocked)

	# Assert
	assert_eq(points, 44, "超脱轮回加成 × 1.2 后应为 44（round(37×1.2)=round(44.4)=44）")


# ============================================================================
# AC-006：settle_run 返回结算摘要
# ============================================================================

func test_settle_run_returns_summary() -> void:
	# Arrange
	var run_data: Dictionary = {
		"realm_reached": 2,
		"result": "victory",
		"elites_killed": 3,
		"bosses_killed": 1,
		"unique_cards_collected": 10,
		"alchemy_count": 5,
		"forge_count": 0,
	}
	_progression_mock._points = 0

	# Act
	var summary: Dictionary = RTS.settle_run(run_data, "金丹")

	# Assert
	assert_true(summary.has("points_earned"), "应返回 points_earned")
	assert_true(summary.has("realm_reached"), "应返回 realm_reached")
	assert_true(summary.has("result"), "应返回 result")
	assert_eq(int(summary["realm_reached"]), 2, "realm_reached 应为 2")
	assert_eq(str(summary["result"]), "victory", "result 应为 victory")


# ============================================================================
# AC-007：settle_run 调用 ProgressionSystem.add_talent_points
# ============================================================================

func test_settle_run_calls_add_talent_points() -> void:
	# Arrange
	var run_data: Dictionary = {
		"realm_reached": 2,
		"result": "victory",
		"elites_killed": 0,
		"bosses_killed": 0,
		"unique_cards_collected": 0,
		"alchemy_count": 0,
		"forge_count": 0,
	}
	_progression_mock._add_points_called = false
	_progression_mock._added_amount = 0

	# Act
	RTS.settle_run(run_data, "筑基")

	# Assert
	assert_true(_progression_mock._add_points_called, "应调用 add_talent_points")
	assert_eq(_progression_mock._added_amount, 18, "应添加 18 点（8+10=18）")


# ============================================================================
# AC-008：settle_run 递增 total_reincarnations
# ============================================================================

func test_settle_run_increments_reincarnations() -> void:
	# Arrange
	var run_data: Dictionary = {
		"realm_reached": 1,
	"result": "death",
		"elites_killed": 0,
		"bosses_killed": 0,
		"unique_cards_collected": 0,
		"alchemy_count": 0,
		"forge_count": 0,
	}
	_progression_mock._meta_set_calls = []

	# Act
	RTS.settle_run(run_data, "炼气")

	# Assert——应调用 set_meta_value("total_reincarnations", ...)
	var found: bool = false
	for call: Dictionary in _progression_mock._meta_set_calls:
		if str(call["key"]) == "total_reincarnations":
			found = true
	assert_true(found, "应递增 total_reincarnations")


# ============================================================================
# AC-009：settle_run 通关时递增 total_completions
# ============================================================================

func test_settle_run_victory_increments_completions() -> void:
	# Arrange
	var run_data: Dictionary = {
		"realm_reached": 5,
		"result": "victory",
		"elites_killed": 0,
		"bosses_killed": 0,
		"unique_cards_collected": 0,
		"alchemy_count": 0,
		"forge_count": 0,
	}
	_progression_mock._meta_set_calls = []

	# Act
	RTS.settle_run(run_data, "化神")

	# Assert——通关时应调用 set_meta_value("total_completions", ...)
	var found: bool = false
	for call: Dictionary in _progression_mock._meta_set_calls:
		if str(call["key"]) == "total_completions":
			found = true
	assert_true(found, "通关时应递增 total_completions")


# ============================================================================
# AC-010：settle_run 通关时设置 highest_realm_ever
# ============================================================================

func test_settle_run_victory_sets_highest_realm() -> void:
	# Arrange
	var run_data: Dictionary = {
		"realm_reached": 5,
		"result": "victory",
		"elites_killed": 0,
		"bosses_killed": 0,
		"unique_cards_collected": 0,
		"alchemy_count": 0,
		"forge_count": 0,
	}
	_progression_mock._meta_set_calls = []

	# Act
	RTS.settle_run(run_data, "化神")

	# Assert——应调用 set_meta_value("highest_realm_ever", "化神")
	var found: bool = false
	for call: Dictionary in _progression_mock._meta_set_calls:
		if str(call["key"]) == "highest_realm_ever":
			found = true
	assert_true(found, "应设置 highest_realm_ever")
