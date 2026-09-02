extends GutTest
## Story 7-13 验收测试：start_dialogue / select_option / advance 播放编排。
##
## 覆盖 AC-001 到 AC-010（10 条 AC）。
## 测试策略：
##   - 内联对话树数据
##   - 注入 EventSystem mock
##   - 验证信号发射、条件可见性、outcomes 委托
##
## 设计文档来源：GDD dialogue-system.md §3/§4 + ADR-0027 §决策 4
## Story 来源：production/epics/dialogue-system/story-002-playback-orchestration.md

const DP := preload("res://src/feature/dialogue/dialogue_player.gd")

var _event_mock: Node = null


func before_each() -> void:
	_event_mock = Node.new()
	_event_mock.set_script(load("res://tests/unit/dialogue_system/event_mock.gd"))


func after_each() -> void:
	if _event_mock != null:
		_event_mock.free()
		_event_mock = null


## 带条件分支的测试对话树。
func _make_conditional_tree() -> Dictionary:
	return {
		"id": "ch1_cond",
		"title": "条件测试",
		"start_node": "node_01",
		"allow_skip": true,
		"end_action": "start_battle:test_boss",
		"nodes": {
			"node_01": {
				"speaker": "narrator",
				"speaker_display": "旁白",
				"text": "故事开始……",
				"next_node": "node_02",
			},
			"node_02": {
				"speaker": "lin_yuan",
				"speaker_display": "林渊",
				"text": "我该怎么做？",
				"choices": [
					{
						"id": "resist",
						"text": "拼死抵抗",
						"outcomes": [{"type": "set_flag", "target": "ch1_resisted_mo", "value": "true"}],
						"next_node": "node_03",
					},
					{
						"id": "accept",
						"text": "接受条件",
						"outcomes": [{"type": "set_flag", "target": "ch1_accepted_mo", "value": "true"}],
						"next_node": "node_03",
					},
				],
			},
			"node_03": {
				"speaker": "narrator",
				"speaker_display": "旁白",
				"text": "战斗即将开始……",
				"next_node": "",
			},
		},
	}


## 带 always 条件的树。
func _make_always_tree() -> Dictionary:
	return {
		"id": "always_test",
		"start_node": "node_a",
		"allow_skip": true,
		"end_action": "",
		"nodes": {
			"node_a": {
				"speaker": "narrator",
				"text": "always 可见",
				"conditions": [{"type": "always"}],
				"next_node": "node_b",
			},
			"node_b": {
				"speaker": "narrator",
				"text": "结束",
				"next_node": "",
			},
		},
	}


# ============================================================================
# AC-001：start_dialogue 后发射 dialogue_started(tree_id) 信号
# ============================================================================

func test_start_emits_signal() -> void:
	# Arrange
	var player: DP = DP.new()
	var received: Dictionary = {"id": "", "received": false}
	player.dialogue_started.connect(func(tree_id: String): received["id"] = tree_id; received["received"] = true)

	# Act
	player.start_dialogue("ch1_cond", _make_conditional_tree(), _event_mock)

	# Assert
	assert_true(received["received"], "应发射 dialogue_started 信号")
	assert_eq(str(received["id"]), "ch1_cond", "信号参数应为 ch1_cond")


# ============================================================================
# AC-002：select_option("resist") 返回 outcomes 列表
# ============================================================================

func test_select_option_returns_outcomes() -> void:
	# Arrange
	var player: DP = DP.new()
	player.start_dialogue("ch1_cond", _make_conditional_tree(), _event_mock)
	player.advance()  # node_01 → node_02

	# Act
	var outcomes: Array = player.select_option("resist")

	# Assert
	assert_eq(outcomes.size(), 1, "应返回 1 个 outcome")
	assert_eq(str(outcomes[0]["type"]), "set_flag", "outcome type 应为 set_flag")
	assert_eq(str(outcomes[0]["target"]), "ch1_resisted_mo", "target 应为 ch1_resisted_mo")


# ============================================================================
# AC-003：select_option 后推进到选项的 next_node
# ============================================================================

func test_select_option_advances() -> void:
	# Arrange
	var player: DP = DP.new()
	player.start_dialogue("ch1_cond", _make_conditional_tree(), _event_mock)
	player.advance()  # node_01 → node_02

	# Act
	player.select_option("accept")

	# Assert
	assert_eq(player._current_node_id, "node_03", "应推进到 node_03")


# ============================================================================
# AC-004：条件可见性——story_flag=true 的节点可见
# ============================================================================

func test_condition_visible_flag_true() -> void:
	# Arrange
	var player: DP = DP.new()
	_event_mock._flags[&"test_flag"] = true
	var tree: Dictionary = {
		"id": "cond_test",
		"start_node": "node_a",
		"nodes": {
			"node_a": {
				"speaker": "narrator",
				"text": "可见节点",
				"conditions": [{"type": "story_flag", "flag": "test_flag", "operator": "==", "value": "true"}],
				"next_node": "",
			},
		},
	}

	# Act
	player.start_dialogue("cond_test", tree, _event_mock)
	var node: Dictionary = player.get_current_node()

	# Assert——flag=true → 节点可见
	assert_eq(str(node["text"]), "可见节点", "flag=true 的节点应可见")


# ============================================================================
# AC-005：选项条件不满足时返回 {visible: false, reason: ...}
# ============================================================================

func test_choice_condition_not_met() -> void:
	# Arrange
	var player: DP = DP.new()
	var tree: Dictionary = {
		"id": "choice_cond",
		"start_node": "node_a",
		"nodes": {
			"node_a": {
				"speaker": "narrator",
				"text": "选择",
				"choices": [
					{
						"id": "locked_choice",
						"text": "锁定选项",
						"conditions": [{"type": "story_flag", "flag": "missing_flag", "operator": "==", "value": "true"}],
						"next_node": "",
					},
				],
			},
		},
	}

	# Act
	player.start_dialogue("choice_cond", tree, _event_mock)
	var choices: Array = player.get_visible_choices()

	# Assert——locked_choice 条件不满足
	assert_eq(choices.size(), 1, "应有 1 个选项")
	assert_false(bool(choices[0].get("visible", true)), "锁定选项应 visible=false")


# ============================================================================
# AC-006：advance 到无 next_node 的节点发射 dialogue_finished 信号
# ============================================================================

func test_finished_emits_signal() -> void:
	# Arrange
	var player: DP = DP.new()
	var received: Dictionary = {"received": false}
	player.dialogue_finished.connect(func(): received["received"] = true)
	player.start_dialogue("ch1_cond", _make_conditional_tree(), _event_mock)

	# Act——推进到 node_02，选择选项到 node_03，再 advance 到结束
	player.advance()  # node_01 → node_02
	player.select_option("resist")  # → node_03
	player.advance()  # node_03 无 next_node → 结束

	# Assert
	assert_true(received["received"], "应发射 dialogue_finished 信号")


# ============================================================================
# AC-007：allow_skip=true 时 skip() 直接跳到 end_action
# ============================================================================

func test_skip_jumps_to_end() -> void:
	# Arrange
	var player: DP = DP.new()
	player.start_dialogue("ch1_cond", _make_conditional_tree(), _event_mock)

	# Act
	player.skip()

	# Assert
	assert_true(player.is_finished(), "skip 后应标记为结束")


# ============================================================================
# AC-008：select_option 的 outcomes 中 set_flag 委托 EventSystem.set_flag
# ============================================================================

func test_outcomes_delegate_to_event_system() -> void:
	# Arrange
	var player: DP = DP.new()
	player.start_dialogue("ch1_cond", _make_conditional_tree(), _event_mock)
	player.advance()  # node_01 → node_02
	_event_mock._set_flag_calls.clear()

	# Act
	player.select_option("resist")

	# Assert——应委托 EventSystem.set_flag
	assert_eq(_event_mock._set_flag_calls.size(), 1, "应调用 set_flag 一次")
	assert_eq(str(_event_mock._set_flag_calls[0]["flag"]), "ch1_resisted_mo", "flag 应为 ch1_resisted_mo")


# ============================================================================
# AC-009：对话结束后 get_end_action() 返回 end_action 字符串
# ============================================================================

func test_get_end_action() -> void:
	# Arrange
	var player: DP = DP.new()
	player.start_dialogue("ch1_cond", _make_conditional_tree(), _event_mock)

	# Act
	var action: String = player.get_end_action()

	# Assert
	assert_eq(action, "start_battle:test_boss", "end_action 应为 start_battle:test_boss")


# ============================================================================
# AC-010：条件 always=true 的节点始终可见
# ============================================================================

func test_always_condition_visible() -> void:
	# Arrange
	var player: DP = DP.new()
	player.start_dialogue("always_test", _make_always_tree(), _event_mock)

	# Act
	var node: Dictionary = player.get_current_node()

	# Assert——always 条件节点始终可见
	assert_eq(str(node["text"]), "always 可见", "always 条件节点应始终可见")
