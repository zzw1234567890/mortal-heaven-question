extends GutTest
## Story 6-15 验收测试：EndingEvaluator 纯函数工具类 + evaluate_ending。
##
## 覆盖 AC-001 到 AC-010（10 条 AC）。
## 测试策略：
##   - 构造 EndingEvaluator 实例
##   - 使用 mock EventSystem（返回预设 story_flags）
##   - 验证 evaluate() 返回的 EndingResult 字段
##
## 设计文档来源：GDD ending-branch-system.md §1/§2
## Story 来源：production/epics/ending-branch-system/story-001-ending-evaluator.md

const EE := preload("res://src/feature/ending_evaluator.gd")

var _event_mock: Node = null


func before_each() -> void:
	_event_mock = Node.new()
	_event_mock.set_script(load("res://tests/unit/ending_branch_system/event_mock.gd"))


func after_each() -> void:
	if _event_mock != null:
		_event_mock.free()
		_event_mock = null


## 构造偏向飞升线的 chapter_path + run_data
func _make_ascend_path() -> Dictionary:
	return {
		"ch1": "reject_mo",
		"ch2": "destroy_cave",
		"ch3": "defend_righteous",
		"ch4": "ascend_alone",
		"ch5": "ascend",
	}


## 构造偏向守护线的 chapter_path
func _make_guard_path() -> Dictionary:
	return {
		"ch1": "accept_mo",
		"ch2": "take_secret",
		"ch3": "neutral_mediate",
		"ch4": "ascend_with_yinyue",
		"ch5": "guard",
	}


## 构造偏向回归线的 chapter_path
func _make_return_path() -> Dictionary:
	return {
		"ch1": "reject_mo",
		"ch2": "destroy_cave",
		"ch3": "defend_righteous",
		"ch4": "ascend_alone",
		"ch5": "return",
	}


# ============================================================================
# AC-001：evaluate() 返回 ending_id 字段
# ============================================================================

func test_evaluate_returns_ending_id() -> void:
	# Arrange
	var evaluator: EE = EE.new()
	var path: Dictionary = _make_ascend_path()
	var run_data: Dictionary = {"elites_killed": 25, "unique_cards": 120}

	# Act
	var result: Dictionary = evaluator.evaluate(_event_mock, path, run_data)

	# Assert
	assert_true(result.has("ending_id"), "应返回 ending_id 字段")
	assert_true(str(result["ending_id"]).length() > 0, "ending_id 非空")


# ============================================================================
# AC-002：evaluate() 返回 ending_line 字段（ascend/guard/return）
# ============================================================================

func test_evaluate_returns_ending_line() -> void:
	# Arrange
	var evaluator: EE = EE.new()
	var path: Dictionary = _make_ascend_path()
	var run_data: Dictionary = {}

	# Act
	var result: Dictionary = evaluator.evaluate(_event_mock, path, run_data)

	# Assert
	assert_true(result.has("ending_line"), "应返回 ending_line 字段")
	var line: String = str(result["ending_line"])
	assert_true(line == "ascend" or line == "guard" or line == "return", "ending_line 应为 ascend/guard/return")


# ============================================================================
# AC-003：evaluate() 返回 variant 字段
# ============================================================================

func test_evaluate_returns_variant() -> void:
	# Arrange
	var evaluator: EE = EE.new()
	var path: Dictionary = _make_ascend_path()
	var run_data: Dictionary = {}

	# Act
	var result: Dictionary = evaluator.evaluate(_event_mock, path, run_data)

	# Assert
	assert_true(result.has("variant"), "应返回 variant 字段")
	var variant: String = str(result["variant"])
	var valid_variants: Array = ["solo", "duo", "lone", "order", "home", "sect"]
	assert_true(valid_variants.has(variant), "variant 应为有效值: " + variant)


# ============================================================================
# AC-004：evaluate() 返回 scores 字典
# ============================================================================

func test_evaluate_returns_scores() -> void:
	# Arrange
	var evaluator: EE = EE.new()
	var path: Dictionary = _make_ascend_path()
	var run_data: Dictionary = {"elites_killed": 25, "unique_cards": 120}

	# Act
	var result: Dictionary = evaluator.evaluate(_event_mock, path, run_data)

	# Assert
	assert_true(result.has("scores"), "应返回 scores 字典")
	var scores: Dictionary = result["scores"]
	assert_true(scores.has("ascend"), "scores 应含 ascend")
	assert_true(scores.has("guard"), "scores 应含 guard")
	assert_true(scores.has("return"), "scores 应含 return")


# ============================================================================
# AC-005：evaluate() 返回 epilogue 非空字符串
# ============================================================================

func test_evaluate_returns_epilogue() -> void:
	# Arrange
	var evaluator: EE = EE.new()
	var path: Dictionary = _make_ascend_path()
	var run_data: Dictionary = {}

	# Act
	var result: Dictionary = evaluator.evaluate(_event_mock, path, run_data)

	# Assert
	assert_true(result.has("epilogue"), "应返回 epilogue 字段")
	var epilogue: String = str(result["epilogue"])
	assert_true(epilogue.length() > 0, "epilogue 应为非空字符串")


# ============================================================================
# AC-006：ch5=ascend + 前4章偏向飞升 → ending_line="ascend"
# ============================================================================

func test_evaluate_ascend_path() -> void:
	# Arrange
	var evaluator: EE = EE.new()
	var path: Dictionary = _make_ascend_path()
	var run_data: Dictionary = {"elites_killed": 25, "unique_cards": 120}

	# Act
	var result: Dictionary = evaluator.evaluate(_event_mock, path, run_data)

	# Assert
	assert_eq(str(result["ending_line"]), "ascend", "飞升线应胜出")
	assert_eq(str(result["variant"]), "solo", "ch4=ascend_alone 应为 solo")
	assert_eq(str(result["ending_id"]), "ascension_solo", "ending_id 应为 ascension_solo")


# ============================================================================
# AC-007：ch5=guard + 前4章偏向守护 → ending_line="guard"
# ============================================================================

func test_evaluate_guard_path() -> void:
	# Arrange
	var evaluator: EE = EE.new()
	var path: Dictionary = _make_guard_path()
	var run_data: Dictionary = {"craft_count": 25}
	# 设置 yinyue_alive=true 以触发 order 变体
	_event_mock._flags[&"yinyue_alive"] = true

	# Act
	var result: Dictionary = evaluator.evaluate(_event_mock, path, run_data)

	# Assert
	assert_eq(str(result["ending_line"]), "guard", "守护线应胜出")


# ============================================================================
# AC-008：ch5=return + 前4章偏向回归 → ending_line="return"
# ============================================================================

func test_evaluate_return_path() -> void:
	# Arrange
	var evaluator: EE = EE.new()
	var path: Dictionary = _make_return_path()
	var run_data: Dictionary = {"elites_killed": 5, "identity": "seven_peaks_disciple", "total_reincarnations": 6}

	# Act
	var result: Dictionary = evaluator.evaluate(_event_mock, path, run_data)

	# Assert
	assert_eq(str(result["ending_line"]), "return", "回归线应胜出")


# ============================================================================
# AC-009：ENDING_TEMPLATES 包含 3 条结局线
# ============================================================================

func test_ending_templates_has_3_lines() -> void:
	assert_eq(EE.ENDING_TEMPLATES.size(), 3, "ENDING_TEMPLATES 应含 3 条结局线")
	assert_true(EE.ENDING_TEMPLATES.has("ascend"), "应含 ascend")
	assert_true(EE.ENDING_TEMPLATES.has("guard"), "应含 guard")
	assert_true(EE.ENDING_TEMPLATES.has("return"), "应含 return")


# ============================================================================
# AC-010：ENDING_TEMPLATES 每条线含 conditions + variants + epilogue_base
# ============================================================================

func test_ending_templates_structure() -> void:
	for line: String in EE.ENDING_TEMPLATES:
		var data: Dictionary = EE.ENDING_TEMPLATES[line]
		assert_true(data.has("conditions"), line + " 应含 conditions")
		assert_true(data.has("variants"), line + " 应含 variants")
		assert_true(data.has("epilogue_base"), line + " 应含 epilogue_base")
		assert_true(data.has("name"), line + " 应含 name")
