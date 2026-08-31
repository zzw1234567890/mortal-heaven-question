extends GutTest
## Story 6-17 验收测试：_determine_variant / _generate_epilogue 变体与尾声。
##
## 覆盖 AC-001 到 AC-010（10 条 AC）。
## 测试策略：
##   - 构造 EndingEvaluator 实例
##   - 使用 mock EventSystem
##   - 直接调用 _determine_variant 和 _generate_epilogue 验证中间结果
##
## 设计文档来源：GDD ending-branch-system.md §公式 3/§7
## Story 来源：production/epics/ending-branch-system/story-003-determine-variant-epilogue.md

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
# AC-001：ch4=ascend_with_yinyue + line=ascend → variant="duo"
# ============================================================================

func test_determine_variant_ascend_with_yinyue_duo() -> void:
	# Arrange
	var evaluator: EE = EE.new()
	var path: Dictionary = {"ch4": "ascend_with_yinyue"}
	var run_data: Dictionary = {}

	# Act
	var variant: String = evaluator._determine_variant("ascend", _event_mock, path, run_data)

	# Assert
	assert_eq(variant, "duo", "ch4=ascend_with_yinyue → variant=duo（仙侣同行）")


# ============================================================================
# AC-002：ch4=ascend_alone + line=ascend → variant="solo"
# ============================================================================

func test_determine_variant_ascend_alone_solo() -> void:
	# Arrange
	var evaluator: EE = EE.new()
	var path: Dictionary = {"ch4": "ascend_alone"}
	var run_data: Dictionary = {}

	# Act
	var variant: String = evaluator._determine_variant("ascend", _event_mock, path, run_data)

	# Assert
	assert_eq(variant, "solo", "ch4=ascend_alone → variant=solo（仙道孤独）")


# ============================================================================
# AC-003：yinyue_alive=true + ch4=ascend_with_yinyue + line=guard → variant="order"
# ============================================================================

func test_determine_variant_guard_with_yinyue_order() -> void:
	# Arrange
	var evaluator: EE = EE.new()
	_event_mock._flags[&"yinyue_alive"] = true
	var path: Dictionary = {"ch4": "ascend_with_yinyue"}
	var run_data: Dictionary = {}

	# Act
	var variant: String = evaluator._determine_variant("guard", _event_mock, path, run_data)

	# Assert
	assert_eq(variant, "order", "yinyue_alive+ch4=ascend_with_yinyue+guard → variant=order（建立新秩序）")


# ============================================================================
# AC-004：yinyue_alive=false + line=guard → variant="lone"
# ============================================================================

func test_determine_variant_guard_yinyue_dead_lone() -> void:
	# Arrange
	var evaluator: EE = EE.new()
	# yinyue_alive 默认 false（不设置）
	var path: Dictionary = {"ch4": "ascend_alone"}
	var run_data: Dictionary = {}

	# Act
	var variant: String = evaluator._determine_variant("guard", _event_mock, path, run_data)

	# Assert
	assert_eq(variant, "lone", "yinyue_alive=false+guard → variant=lone（孤身守望）")


# ============================================================================
# AC-005：yinyue_alive=true + unlocked_talents≥10 + total_completions≥3 + line=return → variant="sect"
# ============================================================================

func test_determine_variant_return_full_conditions_sect() -> void:
	# Arrange
	var evaluator: EE = EE.new()
	_event_mock._flags[&"yinyue_alive"] = true
	var path: Dictionary = {}
	var run_data: Dictionary = {"unlocked_talents": 10, "total_completions": 3}

	# Act
	var variant: String = evaluator._determine_variant("return", _event_mock, path, run_data)

	# Assert
	assert_eq(variant, "sect", "yinyue_alive+talents≥10+completions≥3+return → variant=sect（开宗立派）")


# ============================================================================
# AC-006：yinyue_alive=true + unlocked_talents=5 + line=return → variant="home"
# ============================================================================

func test_determine_variant_return_insufficient_talents_home() -> void:
	# Arrange
	var evaluator: EE = EE.new()
	_event_mock._flags[&"yinyue_alive"] = true
	var path: Dictionary = {}
	var run_data: Dictionary = {"unlocked_talents": 5, "total_completions": 3}

	# Act
	var variant: String = evaluator._determine_variant("return", _event_mock, path, run_data)

	# Assert
	assert_eq(variant, "home", "yinyue_alive+talents=5 → variant=home（归隐凡间）")


# ============================================================================
# AC-007：ending_id="ascension_solo" → 尾声以飞升线基础文本开头
# ============================================================================

func test_generate_epilogue_ascension_solo_starts_with_base() -> void:
	# Arrange
	var evaluator: EE = EE.new()
	var path: Dictionary = {}

	# Act
	var epilogue: String = evaluator._generate_epilogue("ascension_solo", _event_mock, path)

	# Assert——飞升线基础文本开头
	assert_true(epilogue.begins_with("天梯尽头"), "ascension_solo 尾声应以飞升线基础文本开头")


# ============================================================================
# AC-008：ch1_accepted_mo_condition=true → 尾声含「墨渊的夺舍条件」插入段
# ============================================================================

func test_generate_epilogue_ch1_mo_condition_insertion() -> void:
	# Arrange
	var evaluator: EE = EE.new()
	_event_mock._flags[&"ch1_accepted_mo_condition"] = true
	var path: Dictionary = {}

	# Act
	var epilogue: String = evaluator._generate_epilogue("ascension_solo", _event_mock, path)

	# Assert
	assert_true(epilogue.find("墨渊的夺舍条件") >= 0, "尾声应含「墨渊的夺舍条件」插入段")


# ============================================================================
# AC-009：ch2_took_bone_secret=false → 尾声含「摧毁枯骨洞府」插入段
# ============================================================================

func test_generate_epilogue_ch2_destroy_cave_insertion() -> void:
	# Arrange
	var evaluator: EE = EE.new()
	# ch2_took_bone_secret 默认 false（不设置）
	var path: Dictionary = {}

	# Act
	var epilogue: String = evaluator._generate_epilogue("ascension_solo", _event_mock, path)

	# Assert
	assert_true(epilogue.find("摧毁枯骨洞府") >= 0, "ch2_took_bone_secret=false → 尾声应含「摧毁枯骨洞府」插入段")


# ============================================================================
# AC-010：yinyue_alive=true → 尾声含「银翎在你身旁」插入段
# ============================================================================

func test_generate_epilogue_yinyue_alive_insertion() -> void:
	# Arrange
	var evaluator: EE = EE.new()
	_event_mock._flags[&"yinyue_alive"] = true
	var path: Dictionary = {}

	# Act
	var epilogue: String = evaluator._generate_epilogue("guardian_lone", _event_mock, path)

	# Assert
	assert_true(epilogue.find("银翎在你身旁") >= 0, "yinyue_alive=true → 尾声应含「银翎在你身旁」插入段")
