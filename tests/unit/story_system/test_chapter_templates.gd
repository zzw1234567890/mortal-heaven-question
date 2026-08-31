extends GutTest
## Story 6-11 验收测试：CHAPTER_TEMPLATES 5 章静态定义。
##
## 覆盖 AC-001 到 AC-010（10 条 AC）。
## 测试策略：
##   - 直接读取 StorySystem.CHAPTER_TEMPLATES const Dictionary
##   - 验证章节数量、字段完整性、关键值
##
## 设计文档来源：GDD story-system.md §2
## Story 来源：production/epics/story-system/story-001-chapter-templates.md

var _story: Node = null


func before_each() -> void:
	_story = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/StorySystem")
	if _story == null:
		fail_test("StorySystem Autoload 未注册")


# ============================================================================
# AC-001：CHAPTER_TEMPLATES 包含 5 个章节
# ============================================================================

func test_chapter_templates_contains_5_chapters() -> void:
	assert_eq(_story.CHAPTER_TEMPLATES.size(), 5, "CHAPTER_TEMPLATES 应包含 5 个章节")


# ============================================================================
# AC-002：ch1 chapter_number=1, title 正确, min_realm=1
# ============================================================================

func test_ch1_basic_fields() -> void:
	var ch1: Dictionary = _story.get_chapter_data(&"ch1_qixuan")
	assert_false(ch1.is_empty(), "ch1 不应为空")
	assert_eq(int(ch1["chapter_number"]), 1, "ch1 chapter_number 应为 1")
	assert_eq(str(ch1["title"]), "第一话：青云入世", "ch1 title 应正确")
	assert_eq(int(ch1["entry_conditions"]["min_realm"]), 1, "ch1 min_realm 应为 1")


# ============================================================================
# AC-003：ch1 required_events 含 5 个事件
# ============================================================================

func test_ch1_required_events_count() -> void:
	var ch1: Dictionary = _story.get_chapter_data(&"ch1_qixuan")
	var events: Array = ch1["required_events"]
	assert_eq(events.size(), 5, "ch1 required_events 应含 5 个事件")


# ============================================================================
# AC-004：ch1 ending_branches 含 2 个分支（接受/拒绝墨渊）
# ============================================================================

func test_ch1_ending_branches() -> void:
	var ch1: Dictionary = _story.get_chapter_data(&"ch1_qixuan")
	var branches: Array = ch1["ending_branches"]
	assert_eq(branches.size(), 2, "ch1 ending_branches 应含 2 个分支")
	assert_eq(str(branches[0]["branch_id"]), "ch1_accept_mo", "分支 A 应为接受墨渊")
	assert_eq(str(branches[1]["branch_id"]), "ch1_reject_mo", "分支 B 应为拒绝墨渊")


# ============================================================================
# AC-005：ch2 chapter_number=2, min_realm=2（筑基期）
# ============================================================================

func test_ch2_basic_fields() -> void:
	var ch2: Dictionary = _story.get_chapter_data(&"ch2_luanxinghai")
	assert_false(ch2.is_empty(), "ch2 不应为空")
	assert_eq(int(ch2["chapter_number"]), 2, "ch2 chapter_number 应为 2")
	assert_eq(int(ch2["entry_conditions"]["min_realm"]), 2, "ch2 min_realm 应为 2（筑基期）")


# ============================================================================
# AC-006：ch2 required_events 含 8 个事件（最长章节）
# ============================================================================

func test_ch2_required_events_count() -> void:
	var ch2: Dictionary = _story.get_chapter_data(&"ch2_luanxinghai")
	var events: Array = ch2["required_events"]
	assert_eq(events.size(), 8, "ch2 required_events 应含 8 个事件（最长章节）")


# ============================================================================
# AC-007：ch5 chapter_number=5, min_realm=5（化神期）
# ============================================================================

func test_ch5_basic_fields() -> void:
	var ch5: Dictionary = _story.get_chapter_data(&"ch5_lingjie")
	assert_false(ch5.is_empty(), "ch5 不应为空")
	assert_eq(int(ch5["chapter_number"]), 5, "ch5 chapter_number 应为 5")
	assert_eq(int(ch5["entry_conditions"]["min_realm"]), 5, "ch5 min_realm 应为 5（化神期）")


# ============================================================================
# AC-008：ch5 ending_branches 含 3 个分支（飞升/守护/回归）
# ============================================================================

func test_ch5_ending_branches() -> void:
	var ch5: Dictionary = _story.get_chapter_data(&"ch5_lingjie")
	var branches: Array = ch5["ending_branches"]
	assert_eq(branches.size(), 3, "ch5 ending_branches 应含 3 个分支")
	assert_eq(str(branches[0]["branch_id"]), "ch5_ascend_immortal", "分支 A 应为飞升仙界")
	assert_eq(str(branches[1]["branch_id"]), "ch5_guard_guixu", "分支 B 应为留在归墟守护")
	assert_eq(str(branches[2]["branch_id"]), "ch5_return_dongyu", "分支 C 应为回归东域")


# ============================================================================
# AC-009：每章 completion.unlock_next_chapter 指向下一章（ch5 除外，为空）
# ============================================================================

func test_completion_unlock_next_chapter_chain() -> void:
	var ids: Array = _story.get_all_chapter_ids()
	assert_eq(ids.size(), 5, "应有 5 个章节 ID")

	for i: int in range(ids.size()):
		var ch: Dictionary = _story.get_chapter_data(ids[i])
		var next: String = str(ch["completion"]["unlock_next_chapter"])
		if i < ids.size() - 1:
			var expected_next: String = str(ids[i + 1])
			assert_eq(next, expected_next, "章 " + str(ids[i]) + " 的下一章应指向 " + expected_next)
		else:
			assert_eq(next, "", "最终章 ch5 的 unlock_next_chapter 应为空")


# ============================================================================
# AC-010：GSM narrative 域默认值包含 current_chapter_progress 子字典
# ============================================================================

func test_gsm_narrative_default_has_chapter_progress() -> void:
	var gsm: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/GameStateManager")
	if gsm == null:
		fail_test("GSM Autoload 未注册")
		return

	var narrative: Dictionary = gsm.narrative
	assert_true(narrative.has("current_chapter_progress"), "narrative 域应包含 current_chapter_progress 子字典")
	var progress: Dictionary = narrative["current_chapter_progress"]
	assert_true(progress.has("completed_required_events"), "progress 应含 completed_required_events")
	assert_true(progress.has("boss_unlocked"), "progress 应含 boss_unlocked")
	assert_true(progress.has("boss_defeated"), "progress 应含 boss_defeated")
	assert_true(progress.has("ending_chosen"), "progress 应含 ending_chosen")
