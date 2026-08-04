extends GutTest
## Story 005 集成验收测试：card_reward_requested 信号委托连通性。
##
## 覆盖 AC-015：
##   - 用 StubCardSystem 类连接 card_reward_requested 信号
##   - 验证 fire-and-forget 连通性 + 载荷正确
##
## [br][b]范围说明[/b]：真实 CardSystem 的 create_instance() + serialize_instance()
## + GSM.add_card_to_collection() 完整流程属 CardSystem Epic，不在本 Story 范围。
## 本测试仅验证信号委托链路的连通性——EventSystem 发射 → stub 监听器接收。

const ES_SCRIPT := preload("res://src/foundation/event_system/event_system.gd")
const EventInstanceClass := preload("res://src/foundation/event_system/event_instance.gd")
const EventEnumsClass := preload("res://src/foundation/event_system/event_enums.gd")

var es: Node = null
var stub_card_system: StubCardSystem = null


# ============================================================================
# StubCardSystem —— 模拟 CardSystem 监听 card_reward_requested 信号
# ============================================================================

## 模拟 CardSystem 的 stub——仅记录收到的信号载荷，不执行真实流程。
class StubCardSystem:
	extends RefCounted

	## 收到的 template_id 列表——用于断言验证
	var received_template_ids: Array[StringName] = []
	## 信号连接的 EventSystem 引用
	var _event_system: Node = null

	func _init(event_system: Node) -> void:
		_event_system = event_system
		# 连接 card_reward_requested 信号（fire-and-forget——EventSystem 不等待响应）
		_event_system.card_reward_requested.connect(_on_card_reward_requested)

	## 监听 EventSystem.card_reward_requested 信号
	func _on_card_reward_requested(template_id: StringName) -> void:
		received_template_ids.append(template_id)

	## 断开信号连接（清理时调用）
	func disconnect_signals() -> void:
		if _event_system != null and _event_system.card_reward_requested.is_connected(_on_card_reward_requested):
			_event_system.card_reward_requested.disconnect(_on_card_reward_requested)


func before_each() -> void:
	es = ES_SCRIPT.new()
	stub_card_system = StubCardSystem.new(es)
	_reset_gsm_state()


func after_each() -> void:
	stub_card_system.disconnect_signals()
	stub_card_system = null
	if es != null:
		es.free()
		es = null
	_reset_gsm_state()


func _reset_gsm_state() -> void:
	GameStateManager._pending_changes.clear()
	GameStateManager._flush_scheduled = false
	# 补全所有域——对齐 test_apply_outcomes.gd 的完整重置，防止跨测试状态残留
	GameStateManager.player.cultivation = 0
	GameStateManager.player.talents.clear()
	GameStateManager.collection.owned_cards.clear()
	GameStateManager.collection.total_count = 0
	GameStateManager.exploration.action_points = 0
	GameStateManager.narrative.current_chapter = ""
	GameStateManager.narrative.completed_chapters.clear()
	GameStateManager.narrative.story_flags.clear()


func _make_instance_with_outcomes(outcomes: Array[Dictionary]) -> EventInstance:
	var inst := EventInstanceClass.new()
	inst.template_id = &"test_delegation"
	inst.selected_option_index = 0
	inst.resolved_outcomes = outcomes
	return inst


func _make_triggered_outcome(type: int, target: String = "", value: int = 0,
		value_str: String = "") -> Dictionary:
	return {
		"triggered": true,
		"type": type,
		"target": target,
		"value": value,
		"value_str": value_str,
	}


# ============================================================================
# AC-015：card_reward_requested 信号被 stub 监听器接收并携带正确 template_id
# ============================================================================

func test_ac015_stub_receives_card_reward_requested() -> void:
	# Arrange
	var inst := _make_instance_with_outcomes([
		_make_triggered_outcome(EventEnumsClass.OutcomeType.ADD_CARD, "card_001"),
	])

	# Act
	es.apply_outcomes(inst)

	# Assert —— stub 监听器应收到信号
	assert_eq(stub_card_system.received_template_ids.size(), 1,
			"StubCardSystem 应收到 1 次 card_reward_requested 信号")
	assert_eq(stub_card_system.received_template_ids[0], &"card_001",
			"收到的 template_id 应为 card_001")


func test_ac015_multiple_add_card_outcomes_all_received() -> void:
	# Arrange —— 多个 ADD_CARD outcome
	var inst := _make_instance_with_outcomes([
		_make_triggered_outcome(EventEnumsClass.OutcomeType.ADD_CARD, "card_001"),
		_make_triggered_outcome(EventEnumsClass.OutcomeType.ADD_CARD, "card_002"),
		_make_triggered_outcome(EventEnumsClass.OutcomeType.ADD_CARD, "card_003"),
	])

	# Act
	es.apply_outcomes(inst)

	# Assert —— stub 监听器应收到 3 次信号，载荷顺序正确
	assert_eq(stub_card_system.received_template_ids.size(), 3,
			"3 个 ADD_CARD 应触发 3 次 card_reward_requested")
	assert_eq(stub_card_system.received_template_ids[0], &"card_001")
	assert_eq(stub_card_system.received_template_ids[1], &"card_002")
	assert_eq(stub_card_system.received_template_ids[2], &"card_003")


func test_ac015_no_add_card_outcome_does_not_trigger_stub() -> void:
	# Arrange —— 无 ADD_CARD outcome
	var inst := _make_instance_with_outcomes([
		_make_triggered_outcome(EventEnumsClass.OutcomeType.ADD_RESOURCE, "ling_shi", 100),
		_make_triggered_outcome(EventEnumsClass.OutcomeType.NOTHING),
	])

	# Act
	es.apply_outcomes(inst)

	# Assert —— stub 监听器不应收到信号
	assert_eq(stub_card_system.received_template_ids.size(), 0,
			"无 ADD_CARD 时 StubCardSystem 不应收到 card_reward_requested")
