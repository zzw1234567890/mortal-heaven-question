extends GutTest
## Story 004 AC-005, AC-006：连锁事件选项过滤。
##
## 覆盖：
##   - AC-005: chain_on_option=1 时仅选项索引 1 触发连锁，选项 0 返回空
##   - AC-006: chain_on_option=-1 时任意选项均可触发连锁
##   - 补充: AC-005 正向——选项 1 返回 chain_next
##
## 测试策略：构造不同 chain_on_option 配置的模板，
## 验证 get_chain_event 在不同 option_index 下的返回值。

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


func _make_chain_template(tmpl_id: StringName, chain_next: StringName,
		chain_on_option: int) -> EventTemplate:
	## 构造一个带 chain_next + chain_on_option 的模板，含 2 个空选项。
	var opt0 := EventOptionClass.new()
	opt0.option_id = "opt_0"
	var opt1 := EventOptionClass.new()
	opt1.option_id = "opt_1"
	var tmpl := EventTemplateClass.new()
	tmpl.template_id = tmpl_id
	tmpl.chain_next = chain_next
	tmpl.chain_on_option = chain_on_option
	tmpl.options = [opt0, opt1]
	es.templates[tmpl_id] = tmpl
	return tmpl


func _make_instance(tmpl_id: StringName) -> EventInstance:
	## 构造一个 chain_depth=0 的 EventInstance。
	var inst := EventInstanceClass.new()
	inst.template_id = tmpl_id
	inst.chain_depth = 0
	inst.available_option_indices = [0, 1]
	return inst


# ============================================================================
# AC-005：chain_on_option=1 时仅选项索引 1 触发连锁，选项 0 返回空
# ============================================================================

func test_ac005_chain_on_option_1_only_option_1_triggers() -> void:
	# Arrange —— chain_on_option=1，仅选项 1 触发连锁
	_make_chain_template(&"event_root", &"event_next", 1)
	var inst := _make_instance(&"event_root")

	# Act —— 玩家选了选项 0
	var next_id: StringName = es.get_chain_event(inst, 0)

	# Assert —— 选项 0 不触发连锁
	assert_eq(next_id, &"", "chain_on_option=1 时选项 0 不应触发连锁")


func test_ac005_option_1_returns_next_id() -> void:
	# Arrange —— chain_on_option=1，选项 1 应触发连锁
	_make_chain_template(&"event_root", &"event_next", 1)
	var inst := _make_instance(&"event_root")

	# Act —— 玩家选了选项 1
	var next_id: StringName = es.get_chain_event(inst, 1)

	# Assert —— 选项 1 触发连锁，返回 chain_next
	assert_eq(next_id, &"event_next", "chain_on_option=1 时选项 1 应返回 chain_next")


func test_ac005_chain_on_option_0_only_option_0_triggers() -> void:
	# Arrange —— chain_on_option=0，仅选项 0 触发
	_make_chain_template(&"event_root", &"event_next", 0)
	var inst := _make_instance(&"event_root")

	# Act + Assert —— 选项 0 触发
	assert_eq(es.get_chain_event(inst, 0), &"event_next",
			"chain_on_option=0 时选项 0 应触发连锁")

	# Act + Assert —— 选项 1 不触发
	assert_eq(es.get_chain_event(inst, 1), &"",
			"chain_on_option=0 时选项 1 不应触发连锁")


# ============================================================================
# AC-006：chain_on_option=-1 时任意选项均可触发连锁
# ============================================================================

func test_ac006_chain_on_option_minus_1_any_option_triggers() -> void:
	# Arrange —— chain_on_option=-1（任意选项）
	_make_chain_template(&"event_root", &"event_next", -1)
	var inst := _make_instance(&"event_root")

	# Act + Assert —— 选项 0 触发
	assert_eq(es.get_chain_event(inst, 0), &"event_next",
			"chain_on_option=-1 时选项 0 应触发连锁")

	# Act + Assert —— 选项 1 也触发
	assert_eq(es.get_chain_event(inst, 1), &"event_next",
			"chain_on_option=-1 时选项 1 应触发连锁")


func test_ac006_default_chain_on_option_is_minus_1() -> void:
	# Arrange —— EventTemplate 默认 chain_on_option=-1
	var opt := EventOptionClass.new()
	opt.option_id = "opt_0"
	var tmpl := EventTemplateClass.new()
	tmpl.template_id = &"event_default"
	tmpl.chain_next = &"event_next"
	# 不显式设置 chain_on_option——使用默认值 -1
	tmpl.options = [opt]
	es.templates[&"event_default"] = tmpl
	var inst := _make_instance(&"event_default")

	# Act
	var next_id: StringName = es.get_chain_event(inst, 0)

	# Assert —— 默认 chain_on_option=-1，任意选项触发
	assert_eq(next_id, &"event_next",
			"默认 chain_on_option=-1 应允许任意选项触发连锁")


# ============================================================================
# 补充：选项过滤不触发 push_warning（非深度截断）
# ============================================================================

func test_option_filter_does_not_push_warning() -> void:
	# Arrange —— chain_on_option=1，选了选项 0（不触发连锁）
	_make_chain_template(&"event_root", &"event_next", 1)
	var inst := _make_instance(&"event_root")

	# Act
	es.get_chain_event(inst, 0)

	# Assert —— 选项不匹配是正常行为，不应 push_warning
	assert_push_warning_count(0, "选项不匹配不应 push_warning")


# ============================================================================
# 补充：选项过滤清空 _chain_visited_ids（场景 d——Story 004 ADVISORY #1 收尾）
# ============================================================================

func test_option_filter_clears_visited_ids() -> void:
	# 场景：chain_on_option=1，选了选项 0（不触发连锁）
	# Story 004 ADVISORY #1 修复：选项不匹配视为链结束，清空 visited_ids
	# 防止残留 ID 污染下一条独立事件链
	_make_chain_template(&"event_root", &"event_next", 1)
	es._chain_visited_ids.append(&"event_a")
	var inst := _make_instance(&"event_root")

	# Act
	es.get_chain_event(inst, 0)

	# Assert —— 选项不匹配是链结束场景 (d)，visited 应清空
	assert_eq(es._chain_visited_ids.size(), 0,
			"选项过滤应清空 _chain_visited_ids（场景 d——防止残留 ID 污染新链）")
