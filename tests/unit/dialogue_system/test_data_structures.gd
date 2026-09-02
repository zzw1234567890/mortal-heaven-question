extends GutTest
## Story 7-12 验收测试：DialoguePlayer + DialogueDatabase 数据结构。
##
## 覆盖 AC-001 到 AC-010（10 条 AC）。
## 测试策略：
##   - 内联对话树数据（不依赖 JSON 文件加载）
##   - 验证 Database 缓存和查询、Player 播放控制
##
## 设计文档来源：GDD dialogue-system.md §1 + ADR-0027 §决策 1~3
## Story 来源：production/epics/dialogue-system/story-001-dialogue-player.md

const DB := preload("res://src/feature/dialogue/dialogue_database.gd")
const DP := preload("res://src/feature/dialogue/dialogue_player.gd")

## 测试用对话树。
func _make_test_tree() -> Dictionary:
	return {
		"id": "ch1_test",
		"title": "测试对话",
		"trigger_type": "story",
		"allow_skip": true,
		"start_node": "node_01",
		"end_action": "start_battle:test_boss",
		"nodes": {
			"node_01": {
				"speaker": "mo_yuan",
				"speaker_display": "墨渊",
				"text": "你的身体，老夫就收下了。",
				"expression": "smile",
				"next_node": "node_02",
			},
			"node_02": {
				"speaker": "lin_yuan",
				"speaker_display": "林渊",
				"text": "休想！",
				"expression": "angry",
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


# ============================================================================
# AC-001：DialogueDatabase 加载对话树并缓存到内存
# ============================================================================

func test_database_caches_tree() -> void:
	# Arrange
	var db: DB = DB.new()
	var tree: Dictionary = _make_test_tree()

	# Act
	db.register_tree("ch1_test", tree)

	# Assert——缓存命中
	assert_true(db._tree_cache.has("ch1_test"), "应缓存到内存")


# ============================================================================
# AC-002：get_tree("ch1_test") 返回对话树 Dictionary
# ============================================================================

func test_get_tree() -> void:
	# Arrange
	var db: DB = DB.new()
	db.register_tree("ch1_test", _make_test_tree())

	# Act
	var tree: Dictionary = db.get_tree("ch1_test")

	# Assert
	assert_eq(str(tree["id"]), "ch1_test", "应返回 id")
	assert_eq(str(tree["start_node"]), "node_01", "应返回 start_node")
	assert_true(tree.has("nodes"), "应包含 nodes")


# ============================================================================
# AC-003：has_tree("ch1_test") 返回 true，不存在返回 false
# ============================================================================

func test_has_tree() -> void:
	# Arrange
	var db: DB = DB.new()
	db.register_tree("ch1_test", _make_test_tree())

	# Act + Assert
	assert_true(db.has_tree("ch1_test"), "已注册应返回 true")
	assert_false(db.has_tree("nonexistent"), "未注册应返回 false")


# ============================================================================
# AC-004：DialoguePlayer start 后 _current_node_id = start_node
# ============================================================================

func test_player_start_sets_current_node() -> void:
	# Arrange
	var player: DP = DP.new()
	var tree: Dictionary = _make_test_tree()

	# Act
	player.start("ch1_test", tree)

	# Assert
	assert_eq(player._current_node_id, "node_01", "当前节点应为 start_node")


# ============================================================================
# AC-005：get_current_node() 返回当前节点 Dictionary
# ============================================================================

func test_get_current_node() -> void:
	# Arrange
	var player: DP = DP.new()
	player.start("ch1_test", _make_test_tree())

	# Act
	var node: Dictionary = player.get_current_node()

	# Assert
	assert_eq(str(node["speaker"]), "mo_yuan", "speaker 应为 mo_yuan")
	assert_eq(str(node["text"]), "你的身体，老夫就收下了。", "text 应匹配")
	assert_eq(str(node["next_node"]), "node_02", "next_node 应为 node_02")


# ============================================================================
# AC-006：DialoguePlayer 持有对话历史 _dialogue_history Array
# ============================================================================

func test_player_has_history() -> void:
	# Arrange
	var player: DP = DP.new()
	player.start("ch1_test", _make_test_tree())

	# Act + Assert
	assert_eq(player._dialogue_history.size(), 1, "start 后历史应有 1 条")
	assert_eq(str(player._dialogue_history[0]), "node_01", "第一条应为 node_01")


# ============================================================================
# AC-007：advance() 无 choices 时推进到 next_node
# ============================================================================

func test_advance_no_choices() -> void:
	# Arrange
	var player: DP = DP.new()
	player.start("ch1_test", _make_test_tree())

	# Act——node_01 无 choices，advance 推进到 node_02
	player.advance()

	# Assert
	assert_eq(player._current_node_id, "node_02", "应推进到 node_02")
	assert_eq(player._dialogue_history.size(), 2, "历史应有 2 条")


# ============================================================================
# AC-008：advance() 到 end_node 后标记 _is_finished = true
# ============================================================================

func test_advance_to_end_marks_finished() -> void:
	# Arrange
	var player: DP = DP.new()
	player.start("ch1_test", _make_test_tree())

	# Act——推进到 node_02（有 choices，不自动推进）
	player.advance()
	# 选择 resist 选项——推进到 node_03
	player.select_choice("resist")
	# node_03 无 choices，advance 推进——next_node 为空 → 结束
	player.advance()

	# Assert
	assert_true(player._is_finished, "应标记为已结束")
	assert_true(player.is_finished(), "is_finished 应返回 true")


# ============================================================================
# AC-009：DialoguePlayer 释放后状态清空（RefCounted 生命周期）
# ============================================================================

func test_player_release_clears_state() -> void:
	# Arrange
	var player: DP = DP.new()
	player.start("ch1_test", _make_test_tree())
	assert_false(player._current_node_id.is_empty(), "start 后应有当前节点")

	# Act——RefCounted 生命周期由引擎管理，此处验证状态可重置
	player.start("ch2_other", {})

	# Assert——重新 start 后状态被重置
	assert_eq(player._dialogue_history.size(), 0, "重新 start 后历史应清空（空树无 start_node）")
	assert_eq(player._is_finished, false, "重新 start 后应未结束")


# ============================================================================
# AC-010：对话树节点包含 speaker / text / next_node / choices 字段
# ============================================================================

func test_node_fields() -> void:
	# Arrange
	var player: DP = DP.new()
	player.start("ch1_test", _make_test_tree())

	# Act——node_01 有 speaker / text / next_node
	var node1: Dictionary = player.get_current_node()
	assert_true(node1.has("speaker"), "node_01 应有 speaker")
	assert_true(node1.has("text"), "node_01 应有 text")
	assert_true(node1.has("next_node"), "node_01 应有 next_node")

	# advance 到 node_02——有 choices
	player.advance()
	var node2: Dictionary = player.get_current_node()
	assert_true(node2.has("choices"), "node_02 应有 choices")
	assert_eq((node2["choices"] as Array).size(), 2, "node_02 应有 2 个选项")
