extends GutTest
## Sprint 8 Story 8-13 验收测试：DialoguePlayer 条件评估器接线。
##
## 覆盖 8 种条件类型 + always + 未知类型，共 10 条 AC。
## 测试策略：
##   - DP.new() 创建 DialoguePlayer 实例
##   - 直接操作 GSM Autoload 设置测试状态
##   - 注入 EventSystem mock 测试 story_flag 条件
##   - 每个测试后清理 GSM 状态，保证隔离性
##
## 设计文档来源：GDD dialogue-system.md §条件判定流程
## Story 来源：production/epics/misc-wiring/story-001-dialogue-conditions.md

const DP := preload("res://src/feature/dialogue/dialogue_player.gd")
const EventMock := preload("res://tests/unit/dialogue_system/event_mock.gd")

var _event_mock: Node = null
var _saved_player: Dictionary = {}
var _saved_narrative: Dictionary = {}
var _saved_collection: Dictionary = {}
var _saved_battle: Variant = null


func before_each() -> void:
	# 保存 GSM 原始状态
	_saved_player = GameStateManager.player.duplicate(true)
	_saved_narrative = GameStateManager.narrative.duplicate(true)
	_saved_collection = GameStateManager.collection.duplicate(true)
	_saved_battle = GameStateManager.battle
	# 创建 EventSystem mock
	_event_mock = Node.new()
	_event_mock.set_script(EventMock)


func after_each() -> void:
	# 恢复 GSM 原始状态
	GameStateManager.player = _saved_player.duplicate(true)
	GameStateManager.narrative = _saved_narrative.duplicate(true)
	GameStateManager.collection = _saved_collection.duplicate(true)
	GameStateManager.battle = _saved_battle
	if _event_mock != null:
		_event_mock.free()
		_event_mock = null


# === AC-001：story_flag 条件——flag 存在且匹配时可见 ==========================

func test_story_flag_condition_match_visible() -> void:
	# Arrange
	_event_mock._flags["test_flag"] = "true"
	var tree: Dictionary = {
		"start_node": "n1",
		"nodes": {
			"n1": {"speaker": "npc", "text": "可见节点", "next_node": ""},
			"n2": {"speaker": "npc", "text": "跳过节点", "next_node": ""},
		},
		"nodes_order": ["n1", "n2"],
	}
	tree["nodes"]["n1"]["conditions"] = [{"type": "story_flag", "flag": "test_flag", "operator": "==", "value": "true"}]
	tree["nodes"]["n2"]["conditions"] = [{"type": "story_flag", "flag": "test_flag", "operator": "==", "value": "false"}]
	# Act
	var player: DP = DP.new()
	player.start_dialogue("test", tree, _event_mock)
	# Assert——n1 条件满足，应停在 n1
	assert_eq(player.get_current_node().get("text", ""), "可见节点", "story_flag 匹配时应可见")


# === AC-002：identity 条件——identity_id 匹配时可见 ===========================

func test_identity_condition_match_visible() -> void:
	# Arrange
	GameStateManager.player.identity_id = "sword_cultivator"
	var tree: Dictionary = {
		"start_node": "n1",
		"nodes": {
			"n1": {"speaker": "npc", "text": "身份匹配", "next_node": ""},
		},
	}
	tree["nodes"]["n1"]["conditions"] = [{"type": "identity", "operator": "==", "value": "sword_cultivator"}]
	# Act
	var player: DP = DP.new()
	player.start_dialogue("test", tree, _event_mock)
	# Assert
	assert_eq(player.get_current_node().get("text", ""), "身份匹配", "identity 匹配时应可见")


func test_identity_condition_mismatch_hidden() -> void:
	# Arrange
	GameStateManager.player.identity_id = "sword_cultivator"
	var tree: Dictionary = {
		"start_node": "n1",
		"nodes": {
			"n1": {"speaker": "npc", "text": "隐藏", "next_node": "n2"},
			"n2": {"speaker": "npc", "text": "显示", "next_node": ""},
		},
	}
	tree["nodes"]["n1"]["conditions"] = [{"type": "identity", "operator": "==", "value": "alchemist"}]
	# Act
	var player: DP = DP.new()
	player.start_dialogue("test", tree, _event_mock)
	# Assert——n1 不满足，跳到 n2
	assert_eq(player.get_current_node().get("text", ""), "显示", "identity 不匹配时应跳过")


# === AC-003：realm 条件——境界 >= 比较运算符 ===================================

func test_realm_condition_ge_visible() -> void:
	# Arrange
	GameStateManager.player.realm = 3
	var tree: Dictionary = {
		"start_node": "n1",
		"nodes": {
			"n1": {"speaker": "npc", "text": "境界达标", "next_node": ""},
		},
	}
	tree["nodes"]["n1"]["conditions"] = [{"type": "realm", "operator": ">=", "value": 2}]
	# Act
	var player: DP = DP.new()
	player.start_dialogue("test", tree, _event_mock)
	# Assert
	assert_eq(player.get_current_node().get("text", ""), "境界达标", "realm >= 时应可见")


func test_realm_condition_lt_hidden() -> void:
	# Arrange
	GameStateManager.player.realm = 1
	var tree: Dictionary = {
		"start_node": "n1",
		"nodes": {
			"n1": {"speaker": "npc", "text": "境界不足隐藏", "next_node": "n2"},
			"n2": {"speaker": "npc", "text": "fallback", "next_node": ""},
		},
	}
	tree["nodes"]["n1"]["conditions"] = [{"type": "realm", "operator": ">=", "value": 3}]
	# Act
	var player: DP = DP.new()
	player.start_dialogue("test", tree, _event_mock)
	# Assert
	assert_eq(player.get_current_node().get("text", ""), "fallback", "realm < 时应跳过")


# === AC-004：faction 条件——阵营匹配 ============================================

func test_faction_condition_match_visible() -> void:
	# Arrange
	GameStateManager.narrative.story_flags["player_faction"] = "zhengdao"
	var tree: Dictionary = {
		"start_node": "n1",
		"nodes": {
			"n1": {"speaker": "npc", "text": "正道对话", "next_node": ""},
		},
	}
	tree["nodes"]["n1"]["conditions"] = [{"type": "faction", "value": "zhengdao"}]
	# Act
	var player: DP = DP.new()
	player.start_dialogue("test", tree, _event_mock)
	# Assert
	assert_eq(player.get_current_node().get("text", ""), "正道对话", "faction 匹配时应可见")


func test_faction_condition_mismatch_hidden() -> void:
	# Arrange
	GameStateManager.narrative.story_flags["player_faction"] = "modao"
	var tree: Dictionary = {
		"start_node": "n1",
		"nodes": {
			"n1": {"speaker": "npc", "text": "隐藏", "next_node": "n2"},
			"n2": {"speaker": "npc", "text": "显示", "next_node": ""},
		},
	}
	tree["nodes"]["n1"]["conditions"] = [{"type": "faction", "value": "zhengdao"}]
	# Act
	var player: DP = DP.new()
	player.start_dialogue("test", tree, _event_mock)
	# Assert
	assert_eq(player.get_current_node().get("text", ""), "显示", "faction 不匹配时应跳过")


# === AC-005：card_owned 条件——拥有指定卡牌 =====================================

func test_card_owned_condition_visible() -> void:
	# Arrange
	GameStateManager.collection.owned_cards = [{"template_id": "card_fireball"}]
	var tree: Dictionary = {
		"start_node": "n1",
		"nodes": {
			"n1": {"speaker": "npc", "text": "拥有卡牌", "next_node": ""},
		},
	}
	tree["nodes"]["n1"]["conditions"] = [{"type": "card_owned", "value": "card_fireball"}]
	# Act
	var player: DP = DP.new()
	player.start_dialogue("test", tree, _event_mock)
	# Assert
	assert_eq(player.get_current_node().get("text", ""), "拥有卡牌", "card_owned 匹配时应可见")


func test_card_owned_condition_not_owned_hidden() -> void:
	# Arrange
	GameStateManager.collection.owned_cards = []
	var tree: Dictionary = {
		"start_node": "n1",
		"nodes": {
			"n1": {"speaker": "npc", "text": "隐藏", "next_node": "n2"},
			"n2": {"speaker": "npc", "text": "显示", "next_node": ""},
		},
	}
	tree["nodes"]["n1"]["conditions"] = [{"type": "card_owned", "value": "card_fireball"}]
	# Act
	var player: DP = DP.new()
	player.start_dialogue("test", tree, _event_mock)
	# Assert
	assert_eq(player.get_current_node().get("text", ""), "显示", "card_owned 不匹配时应跳过")


# === AC-006：chapter_completed 条件——已完成某章节 ==============================

func test_chapter_completed_condition_visible() -> void:
	# Arrange
	GameStateManager.narrative.completed_chapters = ["chapter_1", "chapter_2"]
	var tree: Dictionary = {
		"start_node": "n1",
		"nodes": {
			"n1": {"speaker": "npc", "text": "章节已完成", "next_node": ""},
		},
	}
	tree["nodes"]["n1"]["conditions"] = [{"type": "chapter_completed", "value": "chapter_1"}]
	# Act
	var player: DP = DP.new()
	player.start_dialogue("test", tree, _event_mock)
	# Assert
	assert_eq(player.get_current_node().get("text", ""), "章节已完成", "chapter_completed 匹配时应可见")


func test_chapter_completed_condition_not_done_hidden() -> void:
	# Arrange
	GameStateManager.narrative.completed_chapters = []
	var tree: Dictionary = {
		"start_node": "n1",
		"nodes": {
			"n1": {"speaker": "npc", "text": "隐藏", "next_node": "n2"},
			"n2": {"speaker": "npc", "text": "显示", "next_node": ""},
		},
	}
	tree["nodes"]["n1"]["conditions"] = [{"type": "chapter_completed", "value": "chapter_5"}]
	# Act
	var player: DP = DP.new()
	player.start_dialogue("test", tree, _event_mock)
	# Assert
	assert_eq(player.get_current_node().get("text", ""), "显示", "chapter_completed 不匹配时应跳过")


# === AC-007：has_item 条件——资源数量 >= 阈值 ==================================

func test_has_item_condition_visible() -> void:
	# Arrange
	GameStateManager.player.resources = {"ling_shi": 100, "ling_cai": {"low": 0, "medium": 0, "high": 0, "top": 0}, "dan_yao_sui_pian": 0}
	var tree: Dictionary = {
		"start_node": "n1",
		"nodes": {
			"n1": {"speaker": "npc", "text": "资源充足", "next_node": ""},
		},
	}
	tree["nodes"]["n1"]["conditions"] = [{"type": "has_item", "target": "ling_shi", "value": 50}]
	# Act
	var player: DP = DP.new()
	player.start_dialogue("test", tree, _event_mock)
	# Assert
	assert_eq(player.get_current_node().get("text", ""), "资源充足", "has_item >= 时应可见")


func test_has_item_condition_insufficient_hidden() -> void:
	# Arrange
	GameStateManager.player.resources = {"ling_shi": 10, "ling_cai": {"low": 0, "medium": 0, "high": 0, "top": 0}, "dan_yao_sui_pian": 0}
	var tree: Dictionary = {
		"start_node": "n1",
		"nodes": {
			"n1": {"speaker": "npc", "text": "隐藏", "next_node": "n2"},
			"n2": {"speaker": "npc", "text": "显示", "next_node": ""},
		},
	}
	tree["nodes"]["n1"]["conditions"] = [{"type": "has_item", "target": "ling_shi", "value": 50}]
	# Act
	var player: DP = DP.new()
	player.start_dialogue("test", tree, _event_mock)
	# Assert
	assert_eq(player.get_current_node().get("text", ""), "显示", "has_item < 时应跳过")


# === AC-008：combat_result 条件——上一场战斗结果 ===============================

func test_combat_result_condition_match_visible() -> void:
	# Arrange——battle 域为 null（非战斗状态），需要设置
	GameStateManager.battle = {"last_result": "win"}
	var tree: Dictionary = {
		"start_node": "n1",
		"nodes": {
			"n1": {"speaker": "npc", "text": "胜利对话", "next_node": ""},
		},
	}
	tree["nodes"]["n1"]["conditions"] = [{"type": "combat_result", "value": "win"}]
	# Act
	var player: DP = DP.new()
	player.start_dialogue("test", tree, _event_mock)
	# Assert
	assert_eq(player.get_current_node().get("text", ""), "胜利对话", "combat_result 匹配时应可见")


func test_combat_result_condition_mismatch_hidden() -> void:
	# Arrange
	GameStateManager.battle = {"last_result": "loss"}
	var tree: Dictionary = {
		"start_node": "n1",
		"nodes": {
			"n1": {"speaker": "npc", "text": "隐藏", "next_node": "n2"},
			"n2": {"speaker": "npc", "text": "显示", "next_node": ""},
		},
	}
	tree["nodes"]["n1"]["conditions"] = [{"type": "combat_result", "value": "win"}]
	# Act
	var player: DP = DP.new()
	player.start_dialogue("test", tree, _event_mock)
	# Assert
	assert_eq(player.get_current_node().get("text", ""), "显示", "combat_result 不匹配时应跳过")


# === AC-009：always 条件——始终可见 ============================================

func test_always_condition_visible() -> void:
	# Arrange
	var tree: Dictionary = {
		"start_node": "n1",
		"nodes": {
			"n1": {"speaker": "npc", "text": "始终可见", "next_node": ""},
		},
	}
	tree["nodes"]["n1"]["conditions"] = [{"type": "always"}]
	# Act
	var player: DP = DP.new()
	player.start_dialogue("test", tree, _event_mock)
	# Assert
	assert_eq(player.get_current_node().get("text", ""), "始终可见", "always 应始终可见")


# === AC-010：未知条件类型——默认可见 ===========================================

func test_unknown_condition_type_visible() -> void:
	# Arrange
	var tree: Dictionary = {
		"start_node": "n1",
		"nodes": {
			"n1": {"speaker": "npc", "text": "未知条件", "next_node": ""},
		},
	}
	tree["nodes"]["n1"]["conditions"] = [{"type": "nonexistent_type", "value": 42}]
	# Act
	var player: DP = DP.new()
	player.start_dialogue("test", tree, _event_mock)
	# Assert
	assert_eq(player.get_current_node().get("text", ""), "未知条件", "未知条件类型应默认可见")
