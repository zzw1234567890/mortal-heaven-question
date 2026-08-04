extends GutTest
## Story 002 AC-019, AC-020：加权随机选择（select_event）验证。
##
## 覆盖：
##   - AC-019: select_event() 1000 次加权分布符合预期比例（卡方检验，α=0.05）
##   - AC-020: 过滤掉 min_realm > realm 的候选事件
##
## 统计型 AC（AC-019）与"无随机种子"规则冲突。
## 采用固定 seed(42) 方案：在每个统计型测试函数开头调用 seed(42) 固定全局 RNG，
## 使结果完全可复现。这是统计性 AC 的必要例外——固定 seed 保证可复现，
## 满足测试标准"确定性"的意图。

const ES_SCRIPT := preload("res://src/foundation/event_system/event_system.gd")
const EventTemplateClass := preload("res://src/foundation/event_system/event_template.gd")
const EventOptionClass := preload("res://src/foundation/event_system/event_option.gd")

var es: Node = null


func before_each() -> void:
	es = ES_SCRIPT.new()


func after_each() -> void:
	if es != null:
		es.free()
		es = null


func _make_template(tmpl_id: StringName, weight: int, min_realm: int = 1) -> EventTemplate:
	var tmpl := EventTemplateClass.new()
	tmpl.template_id = tmpl_id
	tmpl.weight = weight
	tmpl.min_realm = min_realm
	tmpl.options = [EventOptionClass.new()]
	es.templates[tmpl_id] = tmpl
	return tmpl


# ============================================================================
# AC-019：加权分布卡方检验
# ============================================================================

func test_ac019_weighted_distribution_matches_expected_proportion() -> void:
	# 统计性 AC 的必要例外——固定 seed 保证可复现
	seed(42)

	# Arrange —— 两个模板，权重 7:3
	_make_template(&"event_heavy", 7)
	_make_template(&"event_light", 3)
	var candidates: Array[StringName] = [&"event_heavy", &"event_light"]
	var realm: int = 1

	# Act —— 1000 次选择统计
	var total: int = 1000
	var counts: Dictionary = {&"event_heavy": 0, &"event_light": 0}
	for i: int in range(total):
		var selected: StringName = es.select_event(candidates, realm)
		counts[selected] += 1

	# Assert —— 卡方检验
	# 期望频数：heavy=700, light=300（权重 7:3）
	# chi2 = sum((observed - expected)^2 / expected)
	# df=1, α=0.05 临界值 ≈ 3.841
	var expected_heavy: float = total * 7.0 / 10.0
	var expected_light: float = total * 3.0 / 10.0
	var chi2: float = pow(float(counts[&"event_heavy"]) - expected_heavy, 2) / expected_heavy
			+ pow(float(counts[&"event_light"]) - expected_light, 2) / expected_light
	var chi2_critical: float = 3.841  # df=1, α=0.05
	assert_true(chi2 < chi2_critical,
			"卡方统计量 %.3f 应小于临界值 %.3f（heavy=%d, light=%d）"
			% [chi2, chi2_critical, counts[&"event_heavy"], counts[&"event_light"]])


func test_ac019_weighted_distribution_three_candidates() -> void:
	# 统计性 AC 的必要例外——固定 seed 保证可复现
	seed(42)

	# Arrange —— 三个模板，权重 5:3:2
	_make_template(&"event_a", 5)
	_make_template(&"event_b", 3)
	_make_template(&"event_c", 2)
	var candidates: Array[StringName] = [&"event_a", &"event_b", &"event_c"]

	# Act —— 1000 次选择统计
	var total: int = 1000
	var counts: Dictionary = {&"event_a": 0, &"event_b": 0, &"event_c": 0}
	for i: int in range(total):
		var selected: StringName = es.select_event(candidates, 1)
		counts[selected] += 1

	# Assert —— 卡方检验
	# 期望频数：a=500, b=300, c=200（权重 5:3:2）
	# df=2, α=0.05 临界值 ≈ 5.991
	var expected_a: float = total * 5.0 / 10.0
	var expected_b: float = total * 3.0 / 10.0
	var expected_c: float = total * 2.0 / 10.0
	var chi2: float = 0.0
	chi2 += pow(float(counts[&"event_a"]) - expected_a, 2) / expected_a
	chi2 += pow(float(counts[&"event_b"]) - expected_b, 2) / expected_b
	chi2 += pow(float(counts[&"event_c"]) - expected_c, 2) / expected_c
	var chi2_critical: float = 5.991  # df=2, α=0.05
	assert_true(chi2 < chi2_critical,
			"三候选卡方统计量 %.3f 应小于临界值 %.3f（a=%d, b=%d, c=%d）"
			% [chi2, chi2_critical, counts[&"event_a"], counts[&"event_b"], counts[&"event_c"]])


# ============================================================================
# AC-020：过滤 min_realm > realm 的候选事件
# ============================================================================

func test_ac020_filters_min_realm_above_player_realm() -> void:
	# Arrange —— event_high 要求 min_realm=5；玩家境界 2
	_make_template(&"event_low", 10, 1)
	_make_template(&"event_high", 10, 5)
	var candidates: Array[StringName] = [&"event_low", &"event_high"]

	# Act —— 1000 次选择，event_high 应永远不被选中
	var high_selected: bool = false
	for i: int in range(1000):
		var selected: StringName = es.select_event(candidates, 2)
		if selected == &"event_high":
			high_selected = true
			break

	# Assert
	assert_false(high_selected, "min_realm=5 的事件在 realm=2 时不应被选中")


func test_ac020_includes_min_realm_equal_to_player_realm() -> void:
	# Arrange —— min_realm 等于玩家境界时应可被选中
	# 注意：此时另一个候选被过滤，只剩 1 个 eligible——select_event 直接返回它
	_make_template(&"event_at_threshold", 10, 3)
	_make_template(&"event_too_high", 10, 5)
	var candidates: Array[StringName] = [&"event_at_threshold", &"event_too_high"]

	# Act —— 多次选择，应始终返回 event_at_threshold
	for i: int in range(100):
		var selected: StringName = es.select_event(candidates, 3)
		assert_eq(selected, &"event_at_threshold",
				"min_realm=3 在 realm=3 时应可被选中，且为唯一 eligible")


func test_ac020_all_filtered_returns_empty_stringname() -> void:
	# Arrange —— 所有候选 min_realm 都高于玩家境界
	_make_template(&"event_high_a", 10, 5)
	_make_template(&"event_high_b", 10, 6)
	var candidates: Array[StringName] = [&"event_high_a", &"event_high_b"]

	# Act
	var selected: StringName = es.select_event(candidates, 1)

	# Assert
	assert_eq(selected, &"", "无合格候选时应返回空 StringName")


# ============================================================================
# 补充：weight <= 0 过滤
# ============================================================================

func test_weight_zero_filtered_from_candidates() -> void:
	# Arrange —— weight=0 的模板应被过滤
	_make_template(&"event_disabled", 0, 1)  # weight=0
	_make_template(&"event_enabled", 10, 1)
	var candidates: Array[StringName] = [&"event_disabled", &"event_enabled"]

	# Act —— 1000 次选择，event_disabled 应永远不被选中
	var disabled_selected: bool = false
	for i: int in range(1000):
		var selected: StringName = es.select_event(candidates, 1)
		if selected == &"event_disabled":
			disabled_selected = true
			break

	# Assert
	assert_false(disabled_selected, "weight=0 的模板不应被选中")


func test_unknown_candidate_id_skipped() -> void:
	# Arrange —— 候选包含未注册的 ID，应被跳过
	_make_template(&"event_known", 10, 1)
	var candidates: Array[StringName] = [&"event_known", &"event_unknown"]

	# Act
	var selected: StringName = es.select_event(candidates, 1)

	# Assert —— 只剩 1 个 eligible，直接返回
	assert_eq(selected, &"event_known", "未注册的候选 ID 应被跳过")


func test_single_eligible_returns_directly() -> void:
	# Arrange —— 仅 1 个 eligible，select_event 应直接返回（不走加权随机）
	_make_template(&"event_only", 10, 1)
	var candidates: Array[StringName] = [&"event_only"]

	# Act
	var selected: StringName = es.select_event(candidates, 1)

	# Assert
	assert_eq(selected, &"event_only", "单 eligible 应直接返回")
