extends GutTest
## Story 002 AC-003~007, AC-022：事件触发与选项过滤验证。
##
## 覆盖：
##   - AC-003: trigger_event() 返回 EventInstance，available_option_indices 仅含满足条件的选项
##   - AC-004: FACTION 条件过滤——非正道玩家不可见该选项
##   - AC-005: REALM 条件过滤——境界不足时不可见
##   - AC-006: 所有选项不满足 → all_options_hidden == true
##   - AC-007: 所有选项都满足 → 所有索引可见，all_options_hidden == false
##   - AC-022: event_triggered 信号在 trigger_event() 成功后发射
##
## 测试策略：用内存 EventTemplate 构造夹具，手动填充 es.templates 字典，
## 不依赖磁盘文件。GSM 是 Autoload 全局，直接重置相关域。

const ES_SCRIPT := preload("res://src/foundation/event_system/event_system.gd")
const EventTemplateClass := preload("res://src/foundation/event_system/event_template.gd")
const EventOptionClass := preload("res://src/foundation/event_system/event_option.gd")
const EventConditionClass := preload("res://src/foundation/event_system/event_condition.gd")
const EventEnumsClass := preload("res://src/foundation/event_system/event_enums.gd")

var es: Node = null


func before_each() -> void:
	es = ES_SCRIPT.new()
	# 不调用 _ready()（避免扫描真实空目录）——手动控制 templates 字典
	# 重置 GSM 相关域到默认值
	GameStateManager.player.realm = GameStateManager.RealmLevel.QI_REFINING
	GameStateManager.player.resources = {
		"ling_shi": 0, "ling_cai": 0, "dan_yao_sui_pian": 0,
	}
	GameStateManager.narrative.story_flags = {}


func after_each() -> void:
	if es != null:
		es.free()
		es = null
	# 清理 GSM 状态
	GameStateManager.narrative.story_flags = {}
	GameStateManager.player.realm = GameStateManager.RealmLevel.QI_REFINING
	GameStateManager.player.resources = {
		"ling_shi": 0, "ling_cai": 0, "dan_yao_sui_pian": 0,
	}


func _make_unconditional_option(opt_id: String) -> EventOption:
	var opt := EventOptionClass.new()
	opt.option_id = opt_id
	opt.text = opt_id
	return opt


func _make_realm_option(opt_id: String, op: int, threshold: int) -> EventOption:
	var cond := EventConditionClass.new()
	cond.type = EventEnumsClass.ConditionType.REALM
	cond.operator = op
	cond.value_int = threshold
	var opt := EventOptionClass.new()
	opt.option_id = opt_id
	opt.text = opt_id
	opt.conditions = [cond]
	return opt


func _make_faction_option(opt_id: String, faction: String) -> EventOption:
	var cond := EventConditionClass.new()
	cond.type = EventEnumsClass.ConditionType.FACTION
	cond.value_str = faction
	var opt := EventOptionClass.new()
	opt.option_id = opt_id
	opt.text = opt_id
	opt.conditions = [cond]
	return opt


# ============================================================================
# AC-003：trigger_event() 返回 EventInstance，available_option_indices 仅含满足条件的选项
# ============================================================================

func test_ac003_trigger_event_returns_instance_with_filtered_options() -> void:
	# Arrange —— 2 个无条件选项 + 1 个 REALM GE 2 选项；玩家境界 2
	var tmpl := EventTemplateClass.new()
	tmpl.template_id = &"test_event_001"
	tmpl.options = [
		_make_unconditional_option("opt_a"),
		_make_unconditional_option("opt_b"),
		_make_realm_option("opt_c", EventEnumsClass.ConditionOperator.GE, 2),
	]
	es.templates[&"test_event_001"] = tmpl
	GameStateManager.player.realm = 2  # 满足 REALM GE 2

	# Act
	var instance := es.trigger_event(&"test_event_001")

	# Assert
	assert_not_null(instance, "trigger_event 应返回非 null 实例")
	assert_eq(instance.template_id, &"test_event_001", "instance.template_id 应正确")
	assert_eq(instance.available_option_indices.size(), 3, "3 个选项应全部可见")
	assert_true(instance.available_option_indices.has(0), "opt_a (索引0) 应可见")
	assert_true(instance.available_option_indices.has(1), "opt_b (索引1) 应可见")
	assert_true(instance.available_option_indices.has(2), "opt_c (索引2) 应可见")
	assert_false(instance.all_options_hidden, "有可见选项，all_options_hidden 应为 false")


func test_ac003_trigger_event_filters_realm_condition() -> void:
	# Arrange —— 1 个无条件 + 1 个 REALM GE 2；玩家境界 1
	var tmpl := EventTemplateClass.new()
	tmpl.template_id = &"test_event_realm_filter"
	tmpl.options = [
		_make_unconditional_option("opt_free"),
		_make_realm_option("opt_high", EventEnumsClass.ConditionOperator.GE, 2),
	]
	es.templates[&"test_event_realm_filter"] = tmpl
	GameStateManager.player.realm = 1  # 不满足 REALM GE 2

	# Act
	var instance := es.trigger_event(&"test_event_realm_filter")

	# Assert
	assert_eq(instance.available_option_indices.size(), 1, "仅 1 个选项可见")
	assert_true(instance.available_option_indices.has(0), "opt_free 应可见")
	assert_false(instance.available_option_indices.has(1), "opt_high 应被过滤")


# ============================================================================
# AC-004：FACTION 条件过滤——非正道玩家不可见
# ============================================================================

func test_ac004_faction_condition_filters_non_zhengdao() -> void:
	# Arrange —— 选项条件 FACTION == "zhengdao"；玩家是魔道
	var tmpl := EventTemplateClass.new()
	tmpl.template_id = &"test_event_faction"
	tmpl.options = [
		_make_unconditional_option("opt_open"),
		_make_faction_option("opt_zhengdao_only", "zhengdao"),
	]
	es.templates[&"test_event_faction"] = tmpl
	# EventSystem._check_faction_condition 从 narrative.story_flags["player_faction"] 读取
	GameStateManager.narrative.story_flags["player_faction"] = "modao"

	# Act
	var instance := es.trigger_event(&"test_event_faction")

	# Assert
	assert_true(instance.available_option_indices.has(0), "opt_open 应可见")
	assert_false(instance.available_option_indices.has(1),
			"非正道玩家不应看到 FACTION==zhengdao 的选项")


func test_ac004_faction_condition_matches_zhengdao() -> void:
	# Arrange —— 玩家是正道
	var tmpl := EventTemplateClass.new()
	tmpl.template_id = &"test_event_faction_match"
	tmpl.options = [
		_make_faction_option("opt_zhengdao_only", "zhengdao"),
	]
	es.templates[&"test_event_faction_match"] = tmpl
	GameStateManager.narrative.story_flags["player_faction"] = "zhengdao"

	# Act
	var instance := es.trigger_event(&"test_event_faction_match")

	# Assert
	assert_eq(instance.available_option_indices.size(), 1, "正道玩家应看到该选项")
	assert_true(instance.available_option_indices.has(0))


# ============================================================================
# AC-005：REALM 条件过滤——境界不足时不可见
# ============================================================================

func test_ac005_realm_condition_filters_low_realm() -> void:
	# Arrange —— REALM GE 2，玩家境界 1
	var tmpl := EventTemplateClass.new()
	tmpl.template_id = &"test_event_realm_gate"
	tmpl.options = [
		_make_unconditional_option("opt_open"),
		_make_realm_option("opt_high_realm", EventEnumsClass.ConditionOperator.GE, 2),
	]
	es.templates[&"test_event_realm_gate"] = tmpl
	GameStateManager.player.realm = 1

	# Act
	var instance := es.trigger_event(&"test_event_realm_gate")

	# Assert
	assert_false(instance.available_option_indices.has(1),
			"境界 1 不满足 REALM GE 2——选项应被过滤")
	assert_true(instance.available_option_indices.has(0),
			"无条件选项始终可见")


func test_ac005_realm_condition_passes_when_meeting() -> void:
	# Arrange —— REALM GE 2，玩家境界 3（金丹）
	var tmpl := EventTemplateClass.new()
	tmpl.template_id = &"test_event_realm_pass"
	tmpl.options = [
		_make_realm_option("opt_high_realm", EventEnumsClass.ConditionOperator.GE, 2),
	]
	es.templates[&"test_event_realm_pass"] = tmpl
	GameStateManager.player.realm = 3

	# Act
	var instance := es.trigger_event(&"test_event_realm_pass")

	# Assert
	assert_true(instance.available_option_indices.has(0),
			"境界 3 满足 REALM GE 2——选项应可见")


# ============================================================================
# AC-006：所有选项都不满足 → all_options_hidden == true
# ============================================================================

func test_ac006_all_options_hidden_when_none_meet_conditions() -> void:
	# Arrange —— 两个选项都有 REALM GE 5 条件；玩家境界 1
	var tmpl := EventTemplateClass.new()
	tmpl.template_id = &"test_event_all_hidden"
	tmpl.options = [
		_make_realm_option("opt_a", EventEnumsClass.ConditionOperator.GE, 5),
		_make_realm_option("opt_b", EventEnumsClass.ConditionOperator.GE, 5),
	]
	es.templates[&"test_event_all_hidden"] = tmpl
	GameStateManager.player.realm = 1

	# Act
	var instance := es.trigger_event(&"test_event_all_hidden")

	# Assert
	assert_eq(instance.available_option_indices.size(), 0, "无可见选项")
	assert_true(instance.all_options_hidden, "所有选项不满足时 all_options_hidden 应为 true")


# ============================================================================
# AC-007：所有选项都满足 → 所有索引可见，all_options_hidden == false
# ============================================================================

func test_ac007_all_options_visible_when_all_meet_conditions() -> void:
	# Arrange —— 3 个无条件选项
	var tmpl := EventTemplateClass.new()
	tmpl.template_id = &"test_event_all_visible"
	tmpl.options = [
		_make_unconditional_option("opt_a"),
		_make_unconditional_option("opt_b"),
		_make_unconditional_option("opt_c"),
	]
	es.templates[&"test_event_all_visible"] = tmpl

	# Act
	var instance := es.trigger_event(&"test_event_all_visible")

	# Assert
	assert_eq(instance.available_option_indices.size(), 3, "3 个选项应全部可见")
	assert_true(instance.available_option_indices.has(0))
	assert_true(instance.available_option_indices.has(1))
	assert_true(instance.available_option_indices.has(2))
	assert_false(instance.all_options_hidden, "有可见选项时 all_options_hidden 应为 false")


# ============================================================================
# AC-022：event_triggered 信号在 trigger_event() 成功后发射
# ============================================================================

func test_ac022_event_triggered_signal_emitted_on_success() -> void:
	# Arrange
	var tmpl := EventTemplateClass.new()
	tmpl.template_id = &"test_event_signal"
	tmpl.options = [_make_unconditional_option("opt_a")]
	es.templates[&"test_event_signal"] = tmpl
	watch_signals(es)

	# Act
	var instance := es.trigger_event(&"test_event_signal")

	# Assert
	assert_not_null(instance, "应返回有效实例")
	assert_signal_emitted(es, "event_triggered", "成功触发应发射 event_triggered 信号")


func test_ac022_event_triggered_signal_not_emitted_on_unknown_id() -> void:
	# Arrange —— 不注册任何模板
	watch_signals(es)

	# Act
	var instance := es.trigger_event(&"nonexistent_event")

	# Assert
	assert_null(instance, "未知 event_id 应返回 null")
	assert_push_error_count(1, "未知 event_id 应 push_error")
	assert_signal_not_emitted(es, "event_triggered",
			"未知 event_id 不应发射 event_triggered 信号")
