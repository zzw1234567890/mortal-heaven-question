extends GutTest
## Story 003 验收测试：EventSystem.set_flag() —— story_flags 唯一写入入口。
##
## 覆盖：
##   - AC-001: set_flag("chapter_1", true) → story_flags["chapter_1"] == true
##   - AC-002: 两次连续相同值 → 第二次不额外触发 batch_updated（去重）
##   - AC-003: set_flag("met_boss", false) → story_flags["met_boss"] == false
##   - AC-010: set_flag 是 EventSystem 公开写入方法（方法存在 + 调用后状态变更）
##
## [br][b]测试隔离[/b]: EventSystem 为 ES_SCRIPT.new() 实例（不调 _ready，不加载模板）；
## GSM 为 Autoload 单例——before_each/after_each 清理 narrative.story_flags 与缓冲层。

const ES_SCRIPT := preload("res://src/foundation/event_system/event_system.gd")

var es: Node = null


func before_each() -> void:
	es = ES_SCRIPT.new()
	# 清理 GSM 全局状态——Autoload 单例跨测试持续存在
	GameStateManager._pending_changes.clear()
	GameStateManager._flush_scheduled = false
	GameStateManager.narrative.story_flags.clear()


func after_each() -> void:
	if es != null:
		es.free()
		es = null
	GameStateManager._pending_changes.clear()
	GameStateManager._flush_scheduled = false
	GameStateManager.narrative.story_flags.clear()


# ============================================================================
# AC-001：set_flag 写入 true
# ============================================================================

func test_ac001_set_flag_true_stores_true() -> void:
	# Act —— 数据在 _buffer_change 前已写入 story_flags，立即可读
	es.set_flag("chapter_1", true)
	# Assert
	assert_true(GameStateManager.narrative.story_flags.has("chapter_1"),
			"story_flags 应包含 chapter_1 键")
	assert_eq(GameStateManager.narrative.story_flags["chapter_1"], true,
			"chapter_1 应为 true")


# ============================================================================
# AC-002：两次连续相同值 → 第二次不额外触发 batch_updated
# 时序：set_narrative_flag 用 _buffer_change（帧末 flush）。
#   第一次 set_flag: old=null, new=true → 写入 story_flags + _buffer_change（调度帧末 flush）
#   第二次 set_flag: old=true（已写入）, value=true → old == value → return（不缓冲）
#   await 帧末 → flush 执行，batch_updated 发射 1 次（仅第一次触发缓冲）
# ============================================================================

func test_ac002_duplicate_value_emits_batch_only_once() -> void:
	# Arrange
	watch_signals(GameStateManager)

	# Act —— 两次相同值调用
	es.set_flag("chapter_1", true)
	es.set_flag("chapter_1", true)  # 相同值——set_narrative_flag 内 if old == value: return

	# await 帧末 flush 执行
	await get_tree().process_frame

	# Assert —— 仅第一次触发 _buffer_change → 帧末 batch_updated 发射 1 次
	var count: int = get_signal_emit_count(GameStateManager, "batch_updated")
	assert_eq(count, 1,
			"两次相同值 set_flag 应仅发射 1 次 batch_updated（第二次去重不缓冲），实际: %d" % count)


# ============================================================================
# AC-003：set_flag 写入 false
# ============================================================================

func test_ac003_set_flag_false_stores_false() -> void:
	# Act
	es.set_flag("met_boss", false)
	# Assert
	assert_true(GameStateManager.narrative.story_flags.has("met_boss"),
			"story_flags 应包含 met_boss 键")
	assert_eq(GameStateManager.narrative.story_flags["met_boss"], false,
			"met_boss 应为 false")


# ============================================================================
# AC-010：set_flag 是 EventSystem 公开写入方法
# ============================================================================

func test_ac010_set_flag_is_public_write_method() -> void:
	# Arrange —— 断言方法存在
	assert_true(es.has_method("set_flag"),
			"EventSystem 应有 set_flag 公开方法")

	# Act
	es.set_flag("story_milestone", "reached")

	# Assert —— 调用后状态正确变更
	assert_eq(GameStateManager.narrative.story_flags["story_milestone"], "reached",
			"set_flag 调用后 story_flags 应正确更新")


# ============================================================================
# 补充：不同值连续写入应正确更新（对比 AC-002 的去重场景）
# ============================================================================

func test_set_flag_different_values_updates_correctly() -> void:
	# Act
	es.set_flag("progress", "stage_1")
	es.set_flag("progress", "stage_2")

	# Assert —— 最终值为 stage_2
	assert_eq(GameStateManager.narrative.story_flags["progress"], "stage_2",
			"不同值连续写入应保留最后值")
