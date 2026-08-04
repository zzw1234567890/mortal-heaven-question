extends GutTest
## Story 004 AC-004, AC-010(c), AC-011(a/b)：连锁事件循环检测 + visited_ids 清空。
##
## 覆盖：
##   - AC-004: 循环场景 A→B→A，check_chain_cycle() 第三次触发返回 false + push_warning
##   - AC-010(c): 循环检测命中时 chain_ended 信号在 check_chain_cycle 内部发射
##   - AC-011(a): 循环命中时 _chain_visited_ids 清空
##   - AC-011(b): 正常链结束（get_chain_event 返回空）时 _chain_visited_ids 清空
##   - 补充: 独立链结束后新链不受残留 visited_ids 影响（无误报循环）
##
## 循环检测算法（ADR-0003 §循环检测算法 + Story 004 §1）：
##   - _chain_visited_ids.has(next_id) → push_warning + chain_ended.emit + clear + return false
##   - 否则 append(next_id) + return true
##
## 测试策略：直接操作 es._chain_visited_ids 模拟链中途状态，
## 验证 check_chain_cycle 的返回值、副作用（清空）和信号发射。

const ES_SCRIPT := preload("res://src/foundation/event_system/event_system.gd")
const EventTemplateClass := preload("res://src/foundation/event_system/event_template.gd")
const EventOptionClass := preload("res://src/foundation/event_system/event_option.gd")
const EventInstanceClass := preload("res://src/foundation/event_system/event_instance.gd")

var es: Node = null


func before_each() -> void:
	es = ES_SCRIPT.new()
	es._chain_visited_ids.clear()


func after_each() -> void:
	if es != null:
		es.free()
		es = null


func _make_instance(tmpl_id: StringName) -> EventInstance:
	## 构造一个 EventInstance，chain_depth=0（循环检测不依赖深度）。
	var inst := EventInstanceClass.new()
	inst.template_id = tmpl_id
	inst.chain_depth = 0
	inst.available_option_indices = [0]
	return inst


# ============================================================================
# AC-004：循环场景 A→B→A，check_chain_cycle() 第三次触发返回 false
# ============================================================================

func test_ac004_cycle_detection_returns_false_on_third_trigger() -> void:
	# Arrange —— 模拟 A→B→A 链：
	# 第 1 次：A → B（visited=[B]，返回 true）
	# 第 2 次：B → A（visited=[B,A]，返回 true）
	# 第 3 次：A → B（B 已在 visited 中，返回 false——循环命中）
	var inst_a := _make_instance(&"event_a")
	var inst_b := _make_instance(&"event_b")

	# Act + Assert —— 第 1 次：A→B
	var ok1: bool = es.check_chain_cycle(inst_a, &"event_b")
	assert_true(ok1, "A→B 第一次访问应返回 true（无循环）")
	assert_eq(es._chain_visited_ids.size(), 1, "visited 应含 [event_b]")

	# Act + Assert —— 第 2 次：B→A
	var ok2: bool = es.check_chain_cycle(inst_b, &"event_a")
	assert_true(ok2, "B→A 第一次访问应返回 true（无循环）")
	assert_eq(es._chain_visited_ids.size(), 2, "visited 应含 [event_b, event_a]")

	# Act + Assert —— 第 3 次：A→B（B 已在 visited，循环命中）
	var ok3: bool = es.check_chain_cycle(inst_a, &"event_b")
	assert_false(ok3, "A→B 第二次访问应返回 false（循环检测命中）")


func test_ac004_cycle_detection_first_visit_returns_true() -> void:
	# Arrange —— 首次访问任何 ID 都应返回 true
	var inst := _make_instance(&"event_root")

	# Act
	var ok: bool = es.check_chain_cycle(inst, &"event_first")

	# Assert
	assert_true(ok, "首次访问应返回 true")
	assert_eq(es._chain_visited_ids.size(), 1)
	assert_true(es._chain_visited_ids.has(&"event_first"))


# ============================================================================
# AC-004：循环检测命中时 push_warning 被调用
# ============================================================================

func test_ac004_cycle_detection_calls_push_warning() -> void:
	# Arrange —— 预填充 visited_ids，使下次访问触发循环
	var inst := _make_instance(&"event_root")
	es._chain_visited_ids.append(&"event_loop_target")

	# Act
	es.check_chain_cycle(inst, &"event_loop_target")

	# Assert —— GUT 断言 push_warning 被调用 1 次
	assert_push_warning_count(1, "循环命中应调用 push_warning 1 次")


func test_ac004_cycle_detection_warning_contains_next_id() -> void:
	# Arrange
	var inst := _make_instance(&"event_root")
	es._chain_visited_ids.append(&"event_loop_target")

	# Act
	es.check_chain_cycle(inst, &"event_loop_target")

	# Assert —— warning 文本包含循环命中的 ID（可诊断性）
	assert_push_warning("event_loop_target", "循环 warning 应包含命中的 next_id")


func test_ac004_no_cycle_does_not_push_warning() -> void:
	# Arrange —— 首次访问不触发循环，不应 push_warning
	var inst := _make_instance(&"event_root")

	# Act
	es.check_chain_cycle(inst, &"event_first")

	# Assert
	assert_push_warning_count(0, "无循环时不应 push_warning")


# ============================================================================
# AC-010(c)：循环检测命中时 chain_ended 信号在 check_chain_cycle 内部发射
# ============================================================================

func test_ac010c_cycle_hit_emits_chain_ended() -> void:
	# Arrange
	var inst := _make_instance(&"event_root")
	es._chain_visited_ids.append(&"event_loop_target")
	watch_signals(es)

	# Act
	es.check_chain_cycle(inst, &"event_loop_target")

	# Assert —— 循环命中应发射 chain_ended 信号（场景 c 归属）
	assert_signal_emitted(es, "chain_ended", "循环命中应发射 chain_ended 信号")


func test_ac010c_cycle_hit_emits_chain_ended_with_correct_payload() -> void:
	# Arrange —— chain_ended 载荷为 instance.template_id（当前事件，非 next_id）
	var inst := _make_instance(&"event_current")
	es._chain_visited_ids.append(&"event_loop_target")
	watch_signals(es)

	# Act
	es.check_chain_cycle(inst, &"event_loop_target")

	# Assert —— 载荷应为当前事件 ID（inst.template_id），而非触发循环的 next_id
	var params: Array = get_signal_parameters(es, "chain_ended", 0)
	assert_not_null(params, "应能取到 chain_ended 信号参数")
	assert_eq(params[0], &"event_current",
			"chain_ended 载荷应为当前 instance.template_id")


func test_ac010c_no_cycle_does_not_emit_chain_ended() -> void:
	# Arrange —— 首次访问无循环，不应发射 chain_ended
	var inst := _make_instance(&"event_root")
	watch_signals(es)

	# Act
	es.check_chain_cycle(inst, &"event_first")

	# Assert
	assert_signal_not_emitted(es, "chain_ended",
			"无循环时不应发射 chain_ended 信号")


# ============================================================================
# AC-011(a)：循环命中时 _chain_visited_ids 清空
# ============================================================================

func test_ac011a_cycle_hit_clears_visited_ids() -> void:
	# Arrange —— 预填充多个 ID，触发循环命中
	var inst := _make_instance(&"event_root")
	es._chain_visited_ids.append(&"event_a")
	es._chain_visited_ids.append(&"event_b")
	es._chain_visited_ids.append(&"event_c")

	# Act —— event_b 已在 visited 中，循环命中
	es.check_chain_cycle(inst, &"event_b")

	# Assert —— 循环命中后 visited 应清空
	assert_eq(es._chain_visited_ids.size(), 0,
			"循环命中应清空 _chain_visited_ids（场景 a）")


# ============================================================================
# AC-011(b)：正常链结束（get_chain_event 返回空）时 _chain_visited_ids 清空
# ============================================================================

func test_ac011b_normal_end_clears_visited_ids() -> void:
	# Arrange —— 预填充 visited_ids，然后 get_chain_event 返回空（无 chain_next）
	var opt := EventOptionClass.new()
	opt.option_id = "opt_0"
	var tmpl := EventTemplateClass.new()
	tmpl.template_id = &"event_leaf"
	tmpl.chain_next = &""  # 无连锁 → 链结束
	tmpl.options = [opt]
	es.templates[&"event_leaf"] = tmpl

	es._chain_visited_ids.append(&"event_a")
	es._chain_visited_ids.append(&"event_b")
	var inst := _make_instance(&"event_leaf")

	# Act
	es.get_chain_event(inst, 0)

	# Assert —— 正常链结束应清空 visited_ids（场景 b）
	assert_eq(es._chain_visited_ids.size(), 0,
			"正常链结束应清空 _chain_visited_ids（场景 b）")


# ============================================================================
# 补充：独立链结束后新链不受残留 visited_ids 影响（无误报循环）
# ============================================================================

func test_no_false_cycle_after_normal_chain_ends() -> void:
	# 场景：第一条链 A→B（B 无 chain_next，链结束，visited 清空）
	# 第二条独立链 A→B（应正常跳转，不因残留 visited 误报循环）
	var opt := EventOptionClass.new()
	opt.option_id = "opt_0"

	var tmpl_a := EventTemplateClass.new()
	tmpl_a.template_id = &"event_a"
	tmpl_a.chain_next = &"event_b"
	tmpl_a.options = [opt]
	es.templates[&"event_a"] = tmpl_a

	var tmpl_b := EventTemplateClass.new()
	tmpl_b.template_id = &"event_b"
	tmpl_b.chain_next = &""  # 链终点
	tmpl_b.options = [opt]
	es.templates[&"event_b"] = tmpl_b

	# 第一条链：A→B
	var inst1 := _make_instance(&"event_a")
	var next1: StringName = es.get_chain_event(inst1, 0)
	assert_eq(next1, &"event_b", "第一条链 A→B 应返回 event_b")
	var ok1: bool = es.check_chain_cycle(inst1, &"event_b")
	assert_true(ok1, "第一条链 A→B 应无循环")

	# B 无 chain_next → 链结束，visited 清空
	var inst_b := _make_instance(&"event_b")
	var next_b: StringName = es.get_chain_event(inst_b, 0)
	assert_eq(next_b, &"", "B 无 chain_next 应返回空")
	assert_eq(es._chain_visited_ids.size(), 0, "链结束应清空 visited")

	# 第二条独立链：A→B（不应误报循环）
	var inst2 := _make_instance(&"event_a")
	var next2: StringName = es.get_chain_event(inst2, 0)
	assert_eq(next2, &"event_b", "第二条链 A→B 应返回 event_b")
	var ok2: bool = es.check_chain_cycle(inst2, &"event_b")
	assert_true(ok2, "第二条独立链 A→B 不应误报循环（visited 已清空）")


func test_no_false_cycle_after_depth_truncation() -> void:
	# 场景：深度截断清空 visited 后，新链访问相同 ID 不误报循环
	var opt := EventOptionClass.new()
	opt.option_id = "opt_0"
	var tmpl := EventTemplateClass.new()
	tmpl.template_id = &"event_root"
	tmpl.chain_next = &"event_next"
	tmpl.options = [opt]
	es.templates[&"event_root"] = tmpl

	# 第一次：深度截断（depth=3），visited 清空
	var inst1 := _make_instance(&"event_root")
	inst1.chain_depth = 3
	es.get_chain_event(inst1, 0)
	assert_eq(es._chain_visited_ids.size(), 0, "深度截断应清空 visited")

	# 第二次：新链从 depth=0 开始，应正常返回 chain_next（不误报循环）
	var inst2 := _make_instance(&"event_root")
	inst2.chain_depth = 0
	var next: StringName = es.get_chain_event(inst2, 0)
	assert_eq(next, &"event_next", "深度截断后新链应正常返回 chain_next")


# ============================================================================
# 补充：check_chain_cycle 在无循环时正确累积 visited_ids
# ============================================================================

func test_check_chain_cycle_accumulates_visited_ids() -> void:
	# Arrange —— 连续多次无循环访问，visited 应累积
	var inst := _make_instance(&"event_root")

	# Act
	es.check_chain_cycle(inst, &"event_a")
	es.check_chain_cycle(inst, &"event_b")
	es.check_chain_cycle(inst, &"event_c")

	# Assert
	assert_eq(es._chain_visited_ids.size(), 3, "应累积 3 个 ID")
	assert_true(es._chain_visited_ids.has(&"event_a"))
	assert_true(es._chain_visited_ids.has(&"event_b"))
	assert_true(es._chain_visited_ids.has(&"event_c"))
