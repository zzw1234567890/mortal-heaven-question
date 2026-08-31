extends GutTest
## Story 6-13 验收测试：complete_chapter + GSM narrative.* 独占写入。
##
## 覆盖 AC-001 到 AC-010（10 条 AC）。
## 测试策略：
##   - 直接调用 GSM 第二层方法 + StorySystem.complete_chapter
##   - 操作 GSM narrative 域验证写入效果
##
## 设计文档来源：GDD story-system.md §4
## Story 来源：production/epics/story-system/story-003-complete-chapter.md

var _story: Node = null
var _gsm: Node = null


func before_each() -> void:
	_story = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/StorySystem")
	_gsm = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/GameStateManager")
	if _story == null:
		fail_test("StorySystem Autoload 未注册")
		return
	if _gsm == null:
		fail_test("GSM Autoload 未注册")
		return
	# 重置状态
	_gsm.player.realm = 1
	_gsm.narrative.current_chapter = "ch1_qixuan"
	_gsm.narrative.current_chapter_progress = {
		"completed_required_events": [],
		"boss_unlocked": false,
		"boss_defeated": false,
		"ending_chosen": "",
	}
	_gsm.narrative.completed_chapters = []
	_gsm.narrative.story_flags = {}


func after_each() -> void:
	_gsm.player.realm = 1
	_gsm.narrative.current_chapter = "ch1_qixuan"
	_gsm.narrative.current_chapter_progress = {
		"completed_required_events": [],
		"boss_unlocked": false,
		"boss_defeated": false,
		"ending_chosen": "",
	}
	_gsm.narrative.completed_chapters = []
	_gsm.narrative.story_flags = {}


# ============================================================================
# AC-001：add_required_event_completion 将事件追加到 completed_required_events
# ============================================================================

func test_add_required_event_completion_appends() -> void:
	# Arrange
	_gsm.narrative.current_chapter_progress = {
		"completed_required_events": [],
		"boss_unlocked": false,
		"boss_defeated": false,
		"ending_chosen": "",
	}

	# Act
	_gsm.add_required_event_completion(&"ch1_event_1_trial")

	# Assert
	var events: Array = _gsm.narrative.current_chapter_progress["completed_required_events"]
	assert_eq(events.size(), 1, "应追加 1 个事件")
	assert_eq(str(events[0]), "ch1_event_1_trial", "事件 ID 应正确")


# ============================================================================
# AC-002：set_narrative_boss_unlocked(true) 写入 boss_unlocked=true
# ============================================================================

func test_set_narrative_boss_unlocked() -> void:
	# Arrange
	_gsm.narrative.current_chapter_progress = {
		"completed_required_events": [],
		"boss_unlocked": false,
		"boss_defeated": false,
		"ending_chosen": "",
	}

	# Act
	_gsm.set_narrative_boss_unlocked(true)

	# Assert
	assert_true(bool(_gsm.narrative.current_chapter_progress["boss_unlocked"]), "boss_unlocked 应为 true")


# ============================================================================
# AC-003：set_narrative_boss_defeated(true) 写入 boss_defeated=true
# ============================================================================

func test_set_narrative_boss_defeated() -> void:
	# Arrange
	_gsm.narrative.current_chapter_progress = {
		"completed_required_events": [],
		"boss_unlocked": false,
		"boss_defeated": false,
		"ending_chosen": "",
	}

	# Act
	_gsm.set_narrative_boss_defeated(true)

	# Assert
	assert_true(bool(_gsm.narrative.current_chapter_progress["boss_defeated"]), "boss_defeated 应为 true")


# ============================================================================
# AC-004：set_ending_chosen(branch_id) 写入 ending_chosen 字段
# ============================================================================

func test_set_ending_chosen() -> void:
	# Arrange
	_gsm.narrative.current_chapter_progress = {
		"completed_required_events": [],
		"boss_unlocked": false,
		"boss_defeated": false,
		"ending_chosen": "",
	}

	# Act
	_gsm.set_ending_chosen(&"ch1_accept_mo")

	# Assert
	assert_eq(str(_gsm.narrative.current_chapter_progress["ending_chosen"]), "ch1_accept_mo", "ending_chosen 应正确")


# ============================================================================
# AC-005：complete_chapter 后 ch1 在 completed_chapters 中
# ============================================================================

func test_complete_chapter_adds_to_completed() -> void:
	# Arrange——模拟 ch1 完成条件
	_gsm.narrative.current_chapter = "ch1_qixuan"
	_gsm.narrative.current_chapter_progress = {
		"completed_required_events": ["ch1_event_1", "ch1_event_2", "ch1_event_3", "ch1_event_4", "ch1_event_5"],
		"boss_unlocked": true,
		"boss_defeated": true,
		"ending_chosen": "ch1_accept_mo",
	}

	# Act
	var ok: bool = _story.complete_chapter(&"ch1_accept_mo")

	# Assert
	assert_true(ok, "complete_chapter 应返回 true")
	assert_true(_gsm.narrative.completed_chapters.has(&"ch1_qixuan"), "ch1 应在 completed_chapters 中")


# ============================================================================
# AC-006：complete_chapter 后 current_chapter 推进到 ch2
# ============================================================================

func test_complete_chapter_advances_to_next() -> void:
	# Arrange
	_gsm.narrative.current_chapter = "ch1_qixuan"
	_gsm.narrative.current_chapter_progress = {
		"completed_required_events": [],
		"boss_unlocked": true,
		"boss_defeated": true,
		"ending_chosen": "ch1_reject_mo",
	}

	# Act
	_story.complete_chapter(&"ch1_reject_mo")

	# Assert
	assert_eq(str(_gsm.narrative.current_chapter), "ch2_luanxinghai", "应推进到 ch2")


# ============================================================================
# AC-007：complete_chapter 后 story_flags 含结局分支 flag
# ============================================================================

func test_complete_chapter_sets_story_flags() -> void:
	# Arrange
	_gsm.narrative.current_chapter = "ch1_qixuan"
	_gsm.narrative.current_chapter_progress = {
		"completed_required_events": [],
		"boss_unlocked": true,
		"boss_defeated": true,
		"ending_chosen": "ch1_accept_mo",
	}

	# Act
	_story.complete_chapter(&"ch1_accept_mo")

	# Assert
	assert_true(_gsm.narrative.story_flags.has(&"ch1_accepted_mo_condition"), "应设置结局 flag")
	assert_true(bool(_gsm.narrative.story_flags[&"ch1_accepted_mo_condition"]), "接受墨渊时 flag 应为 true")


# ============================================================================
# AC-008：complete_chapter("ch5_ascend_immortal") 发射 game_victory
# ============================================================================

func test_complete_final_chapter_emits_game_victory() -> void:
	# Arrange
	_gsm.narrative.current_chapter = "ch5_lingjie"
	_gsm.narrative.current_chapter_progress = {
		"completed_required_events": [],
		"boss_unlocked": true,
		"boss_defeated": true,
		"ending_chosen": "ch5_ascend_immortal",
	}
	var victory_received: Dictionary = {"received": false}
	_story.game_victory.connect(func(): victory_received["received"] = true)

	# Act
	_story.complete_chapter(&"ch5_ascend_immortal")

	# Assert
	assert_true(bool(victory_received["received"]), "应发射 game_victory 信号")


# ============================================================================
# AC-009：complete_chapter 前未选择结局时返回 false
# ============================================================================

func test_complete_chapter_without_ending_returns_false() -> void:
	# Arrange
	_gsm.narrative.current_chapter = "ch1_qixuan"
	_gsm.narrative.current_chapter_progress = {
		"completed_required_events": [],
		"boss_unlocked": true,
		"boss_defeated": true,
		"ending_chosen": "",  # 未选择结局
	}

	# Act
	var ok: bool = _story.complete_chapter(&"ch1_accept_mo")

	# Assert
	assert_false(ok, "未选择结局时 complete_chapter 应返回 false")


# ============================================================================
# AC-010：complete_chapter 前未击败 BOSS 时返回 false
# ============================================================================

func test_complete_chapter_without_boss_defeated_returns_false() -> void:
	# Arrange
	_gsm.narrative.current_chapter = "ch1_qixuan"
	_gsm.narrative.current_chapter_progress = {
		"completed_required_events": [],
		"boss_unlocked": true,
		"boss_defeated": false,  # BOSS 未击败
		"ending_chosen": "ch1_accept_mo",
	}

	# Act
	var ok: bool = _story.complete_chapter(&"ch1_accept_mo")

	# Assert
	assert_false(ok, "BOSS 未击败时 complete_chapter 应返回 false")
