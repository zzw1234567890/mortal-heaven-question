extends GutTest
## Story 002 AC-014~018：选项结算（resolve_option）验证。
##
## 覆盖：
##   - AC-014: chance=1.0 必定触发（100 次均 triggered=true）
##   - AC-015: chance=0.0 永不触发（100 次均 triggered=false）
##   - AC-016: chance=0.5 时 1000 次触发率在 [0.4, 0.6]
##   - AC-017: use_range=true, min=50, max=150 → 100 次结果均在 [50, 150]
##   - AC-018: use_range=false, value_int=100 → 结果严格等于 100
##
## 统计型 AC（AC-016）与"无随机种子"规则冲突。
## 采用固定 seed(42) 方案：在每个统计型测试函数开头调用 seed(42) 固定全局 RNG，
## 使结果完全可复现。这是统计性 AC 的必要例外——固定 seed 保证可复现，
## 满足测试标准"确定性"的意图。

const ES_SCRIPT := preload("res://src/foundation/event_system/event_system.gd")
const EventTemplateClass := preload("res://src/foundation/event_system/event_template.gd")
const EventOptionClass := preload("res://src/foundation/event_system/event_option.gd")
const EventOutcomeClass := preload("res://src/foundation/event_system/event_outcome.gd")
const EventInstanceClass := preload("res://src/foundation/event_system/event_instance.gd")
const EventEnumsClass := preload("res://src/foundation/event_system/event_enums.gd")

var es: Node = null


func before_each() -> void:
	es = ES_SCRIPT.new()
	# 不调 _ready()——手动填充 templates 字典


func after_each() -> void:
	if es != null:
		es.free()
		es = null


func _make_template_with_outcome(outcome: EventOutcome, tmpl_id: StringName = &"test_resolve") -> EventTemplate:
	## 构造含单选项 + 单结果的模板，注册到 es.templates。
	var opt := EventOptionClass.new()
	opt.option_id = "opt_0"
	opt.outcomes = [outcome]
	var tmpl := EventTemplateClass.new()
	tmpl.template_id = tmpl_id
	tmpl.options = [opt]
	es.templates[tmpl_id] = tmpl
	return tmpl


func _make_instance(tmpl_id: StringName = &"test_resolve") -> EventInstance:
	## 构造可用选项索引为 [0] 的 EventInstance。
	var inst := EventInstanceClass.new()
	inst.template_id = tmpl_id
	inst.available_option_indices = [0]
	return inst


# ============================================================================
# AC-014：chance=1.0 必定触发
# ============================================================================

func test_ac014_chance_one_always_triggers() -> void:
	# Arrange
	var outcome := EventOutcomeClass.new()
	outcome.type = EventEnumsClass.OutcomeType.ADD_RESOURCE
	outcome.target = "ling_shi"
	outcome.chance = 1.0
	outcome.use_range = false
	outcome.value_int = 100
	_make_template_with_outcome(outcome)

	# Act + Assert —— 100 次执行均 triggered=true
	for i: int in range(100):
		var inst := _make_instance()
		var results: Array[Dictionary] = es.resolve_option(inst, 0)
		assert_eq(results.size(), 1, "应返回 1 个结果")
		assert_true(results[0]["triggered"], "chance=1.0 应必定触发 (第 %d 次)" % i)


# ============================================================================
# AC-015：chance=0.0 永不触发
# ============================================================================

func test_ac015_chance_zero_never_triggers() -> void:
	# Arrange
	var outcome := EventOutcomeClass.new()
	outcome.type = EventEnumsClass.OutcomeType.ADD_RESOURCE
	outcome.chance = 0.0
	outcome.use_range = false
	outcome.value_int = 100
	_make_template_with_outcome(outcome)

	# Act + Assert —— 100 次执行均 triggered=false
	for i: int in range(100):
		var inst := _make_instance()
		var results: Array[Dictionary] = es.resolve_option(inst, 0)
		assert_eq(results.size(), 1)
		assert_false(results[0]["triggered"],
				"chance=0.0 应永不触发 (第 %d 次)" % i)


# ============================================================================
# AC-016：chance=0.5 时 1000 次触发率在 [0.4, 0.6]
# ============================================================================

func test_ac016_chance_half_trigger_rate_in_range() -> void:
	# 统计性 AC 的必要例外——固定 seed 保证可复现，满足测试标准"确定性"意图
	seed(42)

	# Arrange
	var outcome := EventOutcomeClass.new()
	outcome.type = EventEnumsClass.OutcomeType.ADD_RESOURCE
	outcome.chance = 0.5
	outcome.use_range = false
	outcome.value_int = 100
	_make_template_with_outcome(outcome)

	# Act —— 1000 次执行统计触发率
	var triggered_count: int = 0
	var total: int = 1000
	for i: int in range(total):
		var inst := _make_instance()
		var results: Array[Dictionary] = es.resolve_option(inst, 0)
		if results[0]["triggered"]:
			triggered_count += 1

	# Assert —— 触发率应在 [0.4, 0.6]
	var rate: float = float(triggered_count) / float(total)
	assert_true(rate >= 0.4 and rate <= 0.6,
			"chance=0.5 时触发率应在 [0.4, 0.6]，实际: %.3f (%d/%d)" % [rate, triggered_count, total])


# ============================================================================
# AC-017：use_range=true, min=50, max=150 → 结果均在 [50, 150]
# ============================================================================

func test_ac017_use_range_results_within_bounds() -> void:
	# Arrange
	var outcome := EventOutcomeClass.new()
	outcome.type = EventEnumsClass.OutcomeType.ADD_RESOURCE
	outcome.target = "ling_shi"
	outcome.chance = 1.0  # 必触发，聚焦测试范围值
	outcome.use_range = true
	outcome.min_value = 50
	outcome.max_value = 150
	_make_template_with_outcome(outcome)

	# Act + Assert —— 100 次结果均在 [50, 150]
	for i: int in range(100):
		var inst := _make_instance()
		var results: Array[Dictionary] = es.resolve_option(inst, 0)
		var value: int = results[0]["value"]
		assert_true(value >= 50 and value <= 150,
				"use_range 结果应在 [50, 150]，第 %d 次实际: %d" % [i, value])


# ============================================================================
# AC-018：use_range=false, value_int=100 → 结果严格等于 100
# ============================================================================

func test_ac018_use_range_false_returns_exact_value() -> void:
	# Arrange
	var outcome := EventOutcomeClass.new()
	outcome.type = EventEnumsClass.OutcomeType.ADD_RESOURCE
	outcome.target = "ling_shi"
	outcome.chance = 1.0
	outcome.use_range = false
	outcome.value_int = 100
	_make_template_with_outcome(outcome)

	# Act + Assert
	var inst := _make_instance()
	var results: Array[Dictionary] = es.resolve_option(inst, 0)
	assert_eq(results.size(), 1, "应返回 1 个结果")
	assert_eq(results[0]["value"], 100, "use_range=false 应返回精确 value_int=100")


func test_ac018_use_range_false_ignores_min_max() -> void:
	# Arrange —— 即使 min/max 有非零值，use_range=false 时仍用 value_int
	var outcome := EventOutcomeClass.new()
	outcome.chance = 1.0
	outcome.use_range = false
	outcome.value_int = 42
	outcome.min_value = 10
	outcome.max_value = 200
	_make_template_with_outcome(outcome)

	# Act + Assert
	var inst := _make_instance()
	var results: Array[Dictionary] = es.resolve_option(inst, 0)
	assert_eq(results[0]["value"], 42, "use_range=false 应忽略 min/max，返回 value_int=42")


# ============================================================================
# 补充：resolve_option 结果结构验证
# ============================================================================

func test_resolve_option_result_dictionary_structure() -> void:
	# Arrange
	var outcome := EventOutcomeClass.new()
	outcome.type = EventEnumsClass.OutcomeType.ADD_RESOURCE
	outcome.target = "ling_shi"
	outcome.chance = 1.0
	outcome.use_range = false
	outcome.value_int = 50
	outcome.value_str = "reward"
	_make_template_with_outcome(outcome)

	# Act
	var inst := _make_instance()
	var results: Array[Dictionary] = es.resolve_option(inst, 0)

	# Assert —— 结构包含 triggered/type/target/value/value_str
	assert_eq(results.size(), 1)
	var r: Dictionary = results[0]
	assert_true(r.has("triggered"), "结果应有 triggered 键")
	assert_true(r.has("type"), "结果应有 type 键")
	assert_true(r.has("target"), "结果应有 target 键")
	assert_true(r.has("value"), "结果应有 value 键")
	assert_true(r.has("value_str"), "结果应有 value_str 键")
	assert_eq(r["type"], EventEnumsClass.OutcomeType.ADD_RESOURCE)
	assert_eq(r["target"], "ling_shi")
	assert_eq(r["value"], 50)
	assert_eq(r["value_str"], "reward")


func test_resolve_option_sets_selected_option_index() -> void:
	# Arrange
	var outcome := EventOutcomeClass.new()
	outcome.chance = 1.0
	_make_template_with_outcome(outcome)
	var inst := _make_instance()

	# Act
	es.resolve_option(inst, 0)

	# Assert
	assert_eq(inst.selected_option_index, 0, "应设置 selected_option_index=0")
	assert_eq(inst.resolved_outcomes.size(), 1, "应填充 resolved_outcomes")


func test_resolve_option_does_not_emit_event_resolved_signal() -> void:
	## H-1 修复验证：resolve_option() 不再发射 event_resolved 信号。
	## 按 ADR-0003 §信号契约表，event_resolved 应由 apply_outcomes() 在执行完
	## GSM 写入后发射（Story 005 实现）。在 resolve_option 阶段发射会导致
	## SaveLoad 误触发自动存档、存档丢失事件结果。
	# Arrange
	var outcome := EventOutcomeClass.new()
	outcome.chance = 1.0
	_make_template_with_outcome(outcome)
	var inst := _make_instance()
	watch_signals(es)

	# Act
	es.resolve_option(inst, 0)

	# Assert
	assert_signal_not_emitted(es, "event_resolved", "resolve_option 不应发射 event_resolved（留待 apply_outcomes）")


func test_resolve_option_invalid_index_returns_empty() -> void:
	# Arrange
	var outcome := EventOutcomeClass.new()
	outcome.chance = 1.0
	_make_template_with_outcome(outcome)
	var inst := _make_instance()
	inst.available_option_indices = [0]  # 仅 0 可用

	# Act
	var results: Array[Dictionary] = es.resolve_option(inst, 5)  # 5 不在可用列表

	# Assert
	assert_eq(results.size(), 0, "无效索引应返回空数组")
	assert_push_error_count(1, "无效索引应 push_error")
