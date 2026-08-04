extends GutTest
## Story 005 集成验收测试：完整事件流 + 连锁信号连通性。
##
## 覆盖：
##   - AC-019: 完整事件流 trigger → resolve → apply_outcomes → chain → resolve → apply_outcomes → end
##   - AC-020: 选项不匹配 visited_ids 残留风险收尾（Story 004 ADVISORY #1）
##   - AC-021: chain_triggered 信号连通性（Story 004 ADVISORY #3 收尾）
##
## 测试策略：
##   - 构造两个互连的 EventTemplate（A→B 连锁）
##   - 模拟完整事件流：trigger → resolve → apply_outcomes → get_chain_event → trigger B → resolve → apply_outcomes
##   - 用 stub 监听器验证 chain_triggered 信号连通性
##   - 验证选项不匹配后新链不误报循环（AC-020）

const ES_SCRIPT := preload("res://src/foundation/event_system/event_system.gd")
const EventTemplateClass := preload("res://src/foundation/event_system/event_template.gd")
const EventOptionClass := preload("res://src/foundation/event_system/event_option.gd")
const EventOutcomeClass := preload("res://src/foundation/event_system/event_outcome.gd")
const EventInstanceClass := preload("res://src/foundation/event_system/event_instance.gd")
const EventEnumsClass := preload("res://src/foundation/event_system/event_enums.gd")

var es: Node = null
var chain_listener: ChainListener = null


# ============================================================================
# ChainListener —— stub 监听器，记录 chain_triggered 信号
# ============================================================================

class ChainListener:
	extends RefCounted
	## 收到的 (from, to) 对列表
	var received_chain_events: Array = []  # Array[Array] —— 每项 [from, to]
	var _event_system: Node = null

	func _init(event_system: Node) -> void:
		_event_system = event_system
		_event_system.chain_triggered.connect(_on_chain_triggered)

	func _on_chain_triggered(from_event: StringName, to_event: StringName) -> void:
		received_chain_events.append([from_event, to_event])

	func disconnect_signals() -> void:
		if _event_system != null and _event_system.chain_triggered.is_connected(_on_chain_triggered):
			_event_system.chain_triggered.disconnect(_on_chain_triggered)


func before_each() -> void:
	es = ES_SCRIPT.new()
	es._chain_visited_ids.clear()
	chain_listener = ChainListener.new(es)
	_reset_gsm_state()


func after_each() -> void:
	chain_listener.disconnect_signals()
	chain_listener = null
	if es != null:
		es.free()
		es = null
	_reset_gsm_state()


func _reset_gsm_state() -> void:
	GameStateManager._pending_changes.clear()
	GameStateManager._flush_scheduled = false
	GameStateManager.player.cultivation = 0
	GameStateManager.player.max_cultivation = 1000
	GameStateManager.player.resources = {
		"ling_shi": 0,
		"ling_cai": 0,
		"dan_yao_sui_pian": 0,
	}
	GameStateManager.narrative.story_flags.clear()


func _make_outcome(type: int, target: String = "", value_int: int = 0,
		value_str: String = "", chance: float = 1.0) -> EventOutcome:
	var out := EventOutcomeClass.new()
	out.type = type
	out.target = target
	out.value_int = value_int
	out.value_str = value_str
	out.chance = chance
	return out


func _make_chain_templates() -> void:
	## 构造 A→B 连锁模板对。
	## event_a：选项 0 触发连锁（chain_on_option=0），奖励灵石
	## event_b：链终点，奖励修为
	var out_a := _make_outcome(EventEnumsClass.OutcomeType.ADD_RESOURCE, "ling_shi", 100)
	var opt_a := EventOptionClass.new()
	opt_a.option_id = "opt_a"
	opt_a.outcomes = [out_a]

	var tmpl_a := EventTemplateClass.new()
	tmpl_a.template_id = &"event_a"
	tmpl_a.chain_next = &"event_b"
	tmpl_a.chain_on_option = 0  # 仅选项 0 触发连锁
	tmpl_a.options = [opt_a]
	es.templates[&"event_a"] = tmpl_a

	var out_b := _make_outcome(EventEnumsClass.OutcomeType.ADD_CULTIVATION, "", 200)
	var opt_b := EventOptionClass.new()
	opt_b.option_id = "opt_b"
	opt_b.outcomes = [out_b]

	var tmpl_b := EventTemplateClass.new()
	tmpl_b.template_id = &"event_b"
	tmpl_b.chain_next = &""  # 链终点
	tmpl_b.options = [opt_b]
	es.templates[&"event_b"] = tmpl_b


# ============================================================================
# AC-019：完整事件流 trigger → resolve → apply_outcomes → chain → resolve → apply_outcomes → end
# ============================================================================

func test_ac019_full_event_flow_executes_correctly() -> void:
	# Arrange —— 构造 A→B 连锁模板
	_make_chain_templates()
	watch_signals(es)

	# Act —— 1. 触发事件 A
	var inst_a: EventInstance = es.trigger_event(&"event_a", 0)
	assert_not_null(inst_a, "trigger_event 应返回 EventInstance")
	assert_eq(inst_a.template_id, &"event_a")

	# Act —— 2. 结算选项 0
	var results_a: Array[Dictionary] = es.resolve_option(inst_a, 0)
	assert_eq(results_a.size(), 1, "选项 0 应有 1 个 outcome")

	# Act —— 3. 执行结果
	es.apply_outcomes(inst_a)
	# Assert —— ADD_RESOURCE 应写入 GSM
	assert_eq(GameStateManager.player.resources["ling_shi"], 100,
			"事件 A 的 ADD_RESOURCE 应写入 GSM")
	# event_resolved 应发射
	assert_signal_emitted(es, "event_resolved", "事件 A 结算后应发射 event_resolved")

	# Act —— 4. 查询连锁事件
	var next_id: StringName = es.get_chain_event(inst_a, 0)
	assert_eq(next_id, &"event_b", "get_chain_event 应返回 event_b")

	# Act —— 5. 循环检测
	var ok: bool = es.check_chain_cycle(inst_a, &"event_b")
	assert_true(ok, "首次访问 event_b 不应检测到循环")

	# Act —— 6. 发射 chain_triggered 信号（调用方职责）
	es.chain_triggered.emit(&"event_a", &"event_b")

	# Act —— 7. 触发事件 B（连锁深度 +1）
	var inst_b: EventInstance = es.trigger_event(&"event_b", inst_a.chain_depth + 1)
	assert_not_null(inst_b, "连锁触发 event_b 应返回 EventInstance")

	# Act —— 8. 结算事件 B
	var results_b: Array[Dictionary] = es.resolve_option(inst_b, 0)
	assert_eq(results_b.size(), 1, "事件 B 选项 0 应有 1 个 outcome")

	# Act —— 9. 执行事件 B 结果
	es.apply_outcomes(inst_b)
	# Assert —— ADD_CULTIVATION 应写入 GSM
	assert_eq(GameStateManager.player.cultivation, 200,
			"事件 B 的 ADD_CULTIVATION 应写入 GSM")

	# Act —— 10. 查询事件 B 的连锁（应为空——链结束）
	var next_id_b: StringName = es.get_chain_event(inst_b, 0)
	assert_eq(next_id_b, &"", "事件 B 无 chain_next，链应结束")

	# Act —— 11. 发射 chain_ended（调用方职责）
	es.chain_ended.emit(inst_b.template_id)

	# Assert —— chain_triggered 信号应被 stub 监听器接收
	assert_eq(chain_listener.received_chain_events.size(), 1,
			"chain_triggered 信号应被 stub 监听器接收 1 次")
	assert_eq(chain_listener.received_chain_events[0][0], &"event_a",
			"chain_triggered from 应为 event_a")
	assert_eq(chain_listener.received_chain_events[0][1], &"event_b",
			"chain_triggered to 应为 event_b")

	# Assert —— 事件 A 和事件 B 各结算后发射一次 event_resolved，共 2 次
	assert_signal_emit_count(es, "event_resolved", 2,
			"完整事件流(A→B)应发射 event_resolved 共 2 次")


# ============================================================================
# AC-020：选项不匹配 visited_ids 残留风险收尾（Story 004 ADVISORY #1）
# ============================================================================

func test_ac020_option_mismatch_no_residual_cycle_false_positive() -> void:
	# 场景：玩家选了不触发连锁的选项后，新事件链不误报循环
	# Story 004 ADVISORY #1 修复：选项不匹配时清空 visited_ids

	# Arrange —— 构造模板：chain_on_option=0，选项 1 不触发连锁
	var out := _make_outcome(EventEnumsClass.OutcomeType.ADD_RESOURCE, "ling_shi", 50)
	var opt0 := EventOptionClass.new()
	opt0.option_id = "opt_0"
	opt0.outcomes = [out]
	var opt1 := EventOptionClass.new()
	opt1.option_id = "opt_1"
	opt1.outcomes = [out]  # 同样奖励，但选项 1 不触发连锁

	var tmpl_root := EventTemplateClass.new()
	tmpl_root.template_id = &"event_root"
	tmpl_root.chain_next = &"event_chain_target"
	tmpl_root.chain_on_option = 0  # 仅选项 0 触发连锁
	tmpl_root.options = [opt0, opt1]
	es.templates[&"event_root"] = tmpl_root

	# 构造连锁目标模板（同 ID，用于验证残留 ID 不引起误报）
	var tmpl_target := EventTemplateClass.new()
	tmpl_target.template_id = &"event_chain_target"
	tmpl_target.chain_next = &""  # 链终点
	tmpl_target.options = [opt0]
	es.templates[&"event_chain_target"] = tmpl_target

	# Act —— 玩家选了选项 1（不触发连锁）
	var inst: EventInstance = es.trigger_event(&"event_root", 0)
	var results: Array[Dictionary] = es.resolve_option(inst, 1)
	es.apply_outcomes(inst)

	# 查询连锁——选项 1 不匹配，应返回空（链结束）
	var next_id: StringName = es.get_chain_event(inst, 1)
	assert_eq(next_id, &"", "选项 1 不触发连锁，应返回空")

	# Assert —— visited_ids 应已清空（Story 004 ADVISORY #1 修复）
	assert_eq(es._chain_visited_ids.size(), 0,
			"选项不匹配后 visited_ids 应清空（场景 d）")

	# Act —— 现在触发一条全新的独立事件链，访问相同 ID
	# 模拟：新链从 event_root 开始，选选项 0（触发连锁）
	var inst2: EventInstance = es.trigger_event(&"event_root", 0)
	var next_id2: StringName = es.get_chain_event(inst2, 0)
	assert_eq(next_id2, &"event_chain_target",
			"新链选项 0 应正常返回 chain_next")

	# 循环检测——event_chain_target 不在 visited 中（已清空），不应误报
	var ok: bool = es.check_chain_cycle(inst2, &"event_chain_target")
	assert_true(ok, "新链访问 event_chain_target 不应误报循环（visited 已清空）")


# ============================================================================
# AC-021：chain_triggered 信号连通性（Story 004 ADVISORY #3 收尾）
# ============================================================================

func test_ac021_chain_triggered_signal_connectivity() -> void:
	# Arrange —— 调用方在确认连锁跳转后发射 chain_triggered 信号
	# stub 监听器验证接收
	_make_chain_templates()

	# Act —— 完整流程到连锁确认
	var inst_a: EventInstance = es.trigger_event(&"event_a", 0)
	es.resolve_option(inst_a, 0)
	es.apply_outcomes(inst_a)

	var next_id: StringName = es.get_chain_event(inst_a, 0)
	assert_eq(next_id, &"event_b")

	var ok: bool = es.check_chain_cycle(inst_a, &"event_b")
	assert_true(ok)

	# 调用方发射 chain_triggered 信号
	es.chain_triggered.emit(&"event_a", &"event_b")

	# Assert —— stub 监听器应收到信号
	assert_eq(chain_listener.received_chain_events.size(), 1,
			"chain_triggered 信号应被 stub 监听器接收")
	var received: Array = chain_listener.received_chain_events[0]
	assert_eq(received[0], &"event_a", "from_event 应为 event_a")
	assert_eq(received[1], &"event_b", "to_event 应为 event_b")


func test_ac021_chain_triggered_multiple_hops_all_received() -> void:
	# 场景：多跳连锁（A→B→C），每跳都发射 chain_triggered
	# 验证 stub 监听器接收所有跳转

	# Arrange —— 构造 A→B→C 三段连锁
	var opt := EventOptionClass.new()
	opt.option_id = "opt_0"
	opt.outcomes = []

	var tmpl_a := EventTemplateClass.new()
	tmpl_a.template_id = &"event_a"
	tmpl_a.chain_next = &"event_b"
	tmpl_a.options = [opt]
	es.templates[&"event_a"] = tmpl_a

	var tmpl_b := EventTemplateClass.new()
	tmpl_b.template_id = &"event_b"
	tmpl_b.chain_next = &"event_c"
	tmpl_b.options = [opt]
	es.templates[&"event_b"] = tmpl_b

	var tmpl_c := EventTemplateClass.new()
	tmpl_c.template_id = &"event_c"
	tmpl_c.chain_next = &""  # 终点
	tmpl_c.options = [opt]
	es.templates[&"event_c"] = tmpl_c

	# Act —— 模拟 A→B 跳转
	var inst_a: EventInstance = es.trigger_event(&"event_a", 0)
	var next_a: StringName = es.get_chain_event(inst_a, 0)
	es.check_chain_cycle(inst_a, next_a)
	es.chain_triggered.emit(&"event_a", next_a)

	# Act —— 模拟 B→C 跳转
	var inst_b: EventInstance = es.trigger_event(&"event_b", 1)
	var next_b: StringName = es.get_chain_event(inst_b, 0)
	es.check_chain_cycle(inst_b, next_b)
	es.chain_triggered.emit(&"event_b", next_b)

	# Assert —— stub 监听器应收到 2 次跳转
	assert_eq(chain_listener.received_chain_events.size(), 2,
			"两跳连锁应触发 2 次 chain_triggered")
	assert_eq(chain_listener.received_chain_events[0][0], &"event_a")
	assert_eq(chain_listener.received_chain_events[0][1], &"event_b")
	assert_eq(chain_listener.received_chain_events[1][0], &"event_b")
	assert_eq(chain_listener.received_chain_events[1][1], &"event_c")
