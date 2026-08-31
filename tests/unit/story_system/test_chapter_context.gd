extends GutTest
## Story 6-12 验收测试：can_enter_chapter / get_chapter_context。
##
## 覆盖 AC-001 到 AC-010（10 条 AC）。
## 测试策略：
##   - 直接调用 StorySystem 实例方法
##   - 操作 GSM narrative 域和 player.realm 验证条件校验
##
## 设计文档来源：GDD story-system.md §公式 1 / §6
## Story 来源：production/epics/story-system/story-002-chapter-context.md

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
	_gsm.narrative.current_chapter = ""
	_gsm.narrative.completed_chapters = []
	_gsm.narrative.story_flags = {}


func after_each() -> void:
	_gsm.player.realm = 1
	_gsm.narrative.current_chapter = ""
	_gsm.narrative.completed_chapters = []
	_gsm.narrative.story_flags = {}


# ============================================================================
# AC-001：can_enter_chapter("ch1") 无前置章节要求时 allowed=true
# ============================================================================

func test_can_enter_ch1_new_game_allowed() -> void:
	# Arrange——新游戏状态
	_gsm.player.realm = 1
	_gsm.narrative.completed_chapters = []

	# Act
	var result: Dictionary = _story.can_enter_chapter(&"ch1_qixuan")

	# Assert
	assert_true(bool(result["allowed"]), "ch1 无前置要求应 allowed=true")
	assert_eq(str(result["reason"]), "", "reason 应为空")


# ============================================================================
# AC-002：can_enter_chapter("ch2") 未完成 ch1 时 allowed=false
# ============================================================================

func test_can_enter_ch2_without_ch1_blocked() -> void:
	# Arrange——筑基期但未完成 ch1
	_gsm.player.realm = 2
	_gsm.narrative.completed_chapters = []

	# Act
	var result: Dictionary = _story.can_enter_chapter(&"ch2_luanxinghai")

	# Assert
	assert_false(bool(result["allowed"]), "未完成 ch1 时 ch2 应 allowed=false")
	var reason: String = str(result["reason"])
	assert_true(reason.find("青云入世") >= 0, "reason 应含前置章节名: " + reason)


# ============================================================================
# AC-003：can_enter_chapter("ch2") 完成 ch1 且境界≥2 时 allowed=true
# ============================================================================

func test_can_enter_ch2_with_ch1_completed_allowed() -> void:
	# Arrange——筑基期且已完成 ch1
	_gsm.player.realm = 2
	_gsm.narrative.completed_chapters = [&"ch1_qixuan"]

	# Act
	var result: Dictionary = _story.can_enter_chapter(&"ch2_luanxinghai")

	# Assert
	assert_true(bool(result["allowed"]), "完成 ch1 且境界≥2 时 ch2 应 allowed=true")


# ============================================================================
# AC-004：can_enter_chapter("ch3") 境界=2（金丹=3）时 allowed=false
# ============================================================================

func test_can_enter_ch3_realm_too_low_blocked() -> void:
	# Arrange——筑基期(2)，金丹期需要 3
	_gsm.player.realm = 2
	_gsm.narrative.completed_chapters = [&"ch1_qixuan", &"ch2_luanxinghai"]

	# Act
	var result: Dictionary = _story.can_enter_chapter(&"ch3_tiannan")

	# Assert
	assert_false(bool(result["allowed"]), "境界不足时 ch3 应 allowed=false")
	var reason: String = str(result["reason"])
	assert_true(reason.find("3") >= 0, "reason 应含境界要求 3: " + reason)


# ============================================================================
# AC-005：can_enter_chapter("ch1") 新游戏（无前置）且境界=1 时 allowed=true
# ============================================================================

func test_can_enter_ch1_qi_refining_allowed() -> void:
	# Arrange
	_gsm.player.realm = 1

	# Act
	var result: Dictionary = _story.can_enter_chapter(&"ch1_qixuan")

	# Assert
	assert_true(bool(result["allowed"]), "炼气期 ch1 应 allowed=true")


# ============================================================================
# AC-006：get_chapter_context("未知地图") 返回空字典
# ============================================================================

func test_get_chapter_context_unknown_map_returns_empty() -> void:
	# Act
	var result: Dictionary = _story.get_chapter_context(&"unknown_map")

	# Assert
	assert_true(result.is_empty(), "未知地图应返回空字典")


# ============================================================================
# AC-007：get_chapter_context("qing_yun_jian_zong") 返回 ch1 上下文含 required_events
# ============================================================================

func test_get_chapter_context_returns_required_events() -> void:
	# Act
	var result: Dictionary = _story.get_chapter_context(&"qing_yun_jian_zong")

	# Assert
	assert_false(result.is_empty(), "青云剑宗应返回非空上下文")
	assert_eq(str(result["chapter_id"]), "ch1_qixuan", "chapter_id 应为 ch1_qixuan")
	var events: Array = result["required_events"]
	assert_eq(events.size(), 5, "required_events 应含 5 个事件")


# ============================================================================
# AC-008：get_chapter_context 返回的 context 含 chapter_id 字段
# ============================================================================

func test_get_chapter_context_has_chapter_id() -> void:
	# Act
	var result: Dictionary = _story.get_chapter_context(&"xue_yuan_mi_jing")

	# Assert
	assert_true(result.has("chapter_id"), "context 应含 chapter_id 字段")
	assert_eq(str(result["chapter_id"]), "ch1_qixuan", "chapter_id 应为 ch1_qixuan")


# ============================================================================
# AC-009：get_chapter_context 返回的 context 含 maps 列表
# ============================================================================

func test_get_chapter_context_has_maps() -> void:
	# Act
	var result: Dictionary = _story.get_chapter_context(&"dan_xia_gu")

	# Assert
	assert_true(result.has("maps"), "context 应含 maps 列表")
	var maps: Array = result["maps"]
	assert_eq(maps.size(), 4, "ch1 maps 应含 4 个地图")


# ============================================================================
# AC-010：can_enter_chapter("无效ID") 返回 allowed=false
# ============================================================================

func test_can_enter_chapter_invalid_id_blocked() -> void:
	# Act
	var result: Dictionary = _story.can_enter_chapter(&"invalid_chapter")

	# Assert
	assert_false(bool(result["allowed"]), "无效章节 ID 应 allowed=false")
	var reason: String = str(result["reason"])
	assert_true(reason.find("未知章节") >= 0, "reason 应含未知章节提示: " + reason)
