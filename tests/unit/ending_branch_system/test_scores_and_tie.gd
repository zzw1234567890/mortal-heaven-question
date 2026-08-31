extends GutTest
## Story 6-16 验收测试：_calculate_scores / _resolve_tie 评分与平局。
##
## 覆盖 AC-001 到 AC-010（10 条 AC）。
## 测试策略：
##   - 构造 EndingEvaluator 实例
##   - 使用 mock EventSystem
##   - 直接调用 _calculate_scores 和 _resolve_tie 验证中间结果
##
## 设计文档来源：GDD ending-branch-system.md §公式 1/§3
## Story 来源：production/epics/ending-branch-system/story-002-scores-and-tie.md

const EE := preload("res://src/feature/ending_evaluator.gd")

var _event_mock: Node = null


func before_each() -> void:
	_event_mock = Node.new()
	_event_mock.set_script(load("res://tests/unit/ending_branch_system/event_mock.gd"))


func after_each() -> void:
	if _event_mock != null:
		_event_mock.free()
		_event_mock = null


# ============================================================================
# AC-001：ch5=ascend (+30) + ch4=ascend_alone (+15) → ascend 得分含 45
# ============================================================================

func test_calculate_scores_ascend_ch5_and_ch4() -> void:
	# Arrange
	var evaluator: EE = EE.new()
	var path: Dictionary = {"ch5": "ascend", "ch4": "ascend_alone"}
	var run_data: Dictionary = {}

	# Act
	var scores: Dictionary = evaluator._calculate_scores(_event_mock, path, run_data)

	# Assert——ch5=ascend +30, ch4=ascend_alone +15 = 45
	assert_eq(int(scores["ascend"]), 45, "飞升线得分应含 ch5+ch4 = 45")


# ============================================================================
# AC-002：ch2=destroy_cave 给飞升线 +8，给守护线 +0
# ============================================================================

func test_calculate_scores_ch2_destroy_cave_ascend_only() -> void:
	# Arrange
	var evaluator: EE = EE.new()
	var path: Dictionary = {"ch2": "destroy_cave"}
	var run_data: Dictionary = {}

	# Act
	var scores: Dictionary = evaluator._calculate_scores(_event_mock, path, run_data)

	# Assert
	assert_eq(int(scores["ascend"]), 8, "飞升线应 +8 (destroy_cave)")
	assert_eq(int(scores["guard"]), 0, "守护线不应得分 (destroy_cave 不匹配 take_secret)")


# ============================================================================
# AC-003：ch1=accept_mo 给守护线 +8，给飞升线 +0
# ============================================================================

func test_calculate_scores_ch1_accept_mo_guard_only() -> void:
	# Arrange
	var evaluator: EE = EE.new()
	var path: Dictionary = {"ch1": "accept_mo"}
	var run_data: Dictionary = {}

	# Act
	var scores: Dictionary = evaluator._calculate_scores(_event_mock, path, run_data)

	# Assert
	assert_eq(int(scores["guard"]), 8, "守护线应 +8 (accept_mo)")
	assert_eq(int(scores["ascend"]), 0, "飞升线不应得分 (accept_mo 不匹配 reject_mo)")


# ============================================================================
# AC-004：run_data elites_killed=25 (≥20) → 飞升线 +5
# ============================================================================

func test_calculate_scores_elites_killed_ge20_ascend() -> void:
	# Arrange
	var evaluator: EE = EE.new()
	var path: Dictionary = {}
	var run_data: Dictionary = {"elites_killed": 25}

	# Act
	var scores: Dictionary = evaluator._calculate_scores(_event_mock, path, run_data)

	# Assert
	assert_eq(int(scores["ascend"]), 5, "飞升线应 +5 (elites_killed≥20)")


# ============================================================================
# AC-005：run_data elites_killed=5 (≤10) → 回归线 +8
# ============================================================================

func test_calculate_scores_elites_killed_le10_return() -> void:
	# Arrange
	var evaluator: EE = EE.new()
	var path: Dictionary = {}
	var run_data: Dictionary = {"elites_killed": 5}

	# Act
	var scores: Dictionary = evaluator._calculate_scores(_event_mock, path, run_data)

	# Assert——elites_killed≤10 +8, ch3="*" 通配 +5 = 13
	assert_eq(int(scores["return"]), 13, "回归线应 +8 (elites_killed≤10) +5 (ch3通配) = 13")


# ============================================================================
# AC-006：飞升线=50 守护线=50 平局 + ch5=ascend → 偏斜 +5 → 飞升胜出
# ============================================================================

func test_resolve_tie_ascend_wins_with_bias() -> void:
	# Arrange
	var evaluator: EE = EE.new()
	var scores: Dictionary = {"ascend": 50, "guard": 50, "return": 30}

	# Act
	var line: String = evaluator._resolve_tie(scores, "ascend")

	# Assert——偏斜后 ascend=55, guard=50 → 飞升胜出
	assert_eq(line, "ascend", "偏斜 +5 后飞升线应胜出")


# ============================================================================
# AC-007：飞升线=55 守护线=50 + ch5=guard → 偏斜后 55=55 → 优先级飞升>守护
# ============================================================================

func test_resolve_tie_priority_ascend_over_guard() -> void:
	# Arrange
	var evaluator: EE = EE.new()
	var scores: Dictionary = {"ascend": 55, "guard": 50, "return": 30}

	# Act——ch5=guard 偏斜 +5 → guard=55, ascend=55 → 平局 → 优先级 ascend
	var line: String = evaluator._resolve_tie(scores, "guard")

	# Assert
	assert_eq(line, "ascend", "平局时优先级飞升 > 守护")


# ============================================================================
# AC-008：三线同分时优先级 ascend > guard > return
# ============================================================================

func test_resolve_tie_three_way_priority() -> void:
	# Arrange
	var evaluator: EE = EE.new()
	var scores: Dictionary = {"ascend": 40, "guard": 40, "return": 40}

	# Act——无偏斜（ch5 为空）→ 三线同分 → 优先级 ascend
	var line: String = evaluator._resolve_tie(scores, "")

	# Assert
	assert_eq(line, "ascend", "三线同分时 ascend 优先")


# ============================================================================
# AC-009：flag yinyue_alive=true → 守护线 +5
# ============================================================================

func test_calculate_scores_yinyue_alive_guard() -> void:
	# Arrange
	var evaluator: EE = EE.new()
	_event_mock._flags[&"yinyue_alive"] = true
	var path: Dictionary = {}
	var run_data: Dictionary = {}

	# Act
	var scores: Dictionary = evaluator._calculate_scores(_event_mock, path, run_data)

	# Assert
	assert_eq(int(scores["guard"]), 5, "守护线应 +5 (yinyue_alive=true)")


# ============================================================================
# AC-010：ch3=neutral_mediate → 守护线 +15，飞升线 +0
# ============================================================================

func test_calculate_scores_ch3_neutral_mediate_guard() -> void:
	# Arrange
	var evaluator: EE = EE.new()
	var path: Dictionary = {"ch3": "neutral_mediate"}
	var run_data: Dictionary = {}

	# Act
	var scores: Dictionary = evaluator._calculate_scores(_event_mock, path, run_data)

	# Assert
	assert_eq(int(scores["guard"]), 15, "守护线应 +15 (neutral_mediate)")
	assert_eq(int(scores["ascend"]), 0, "飞升线不应得分")
