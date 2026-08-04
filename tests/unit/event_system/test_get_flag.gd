extends GutTest
## Story 003 验收测试：EventSystem.get_flag() —— story_flags 只读查询。
##
## 覆盖：
##   - AC-004: get_flag("non_existent", false) 返回 false（默认值）
##   - AC-005: get_flag("chapter_1", false) 对已设置的 flag 返回 true
##   - AC-011: get_flag 不发射信号——无副作用
##
## [br][b]注意[/b]: get_flag 通过 GSM 第一层 get_state 读取 narrative.story_flags，
## 属于直接属性读取（零拷贝 O(1)），不触发缓冲层、不发射信号。

const ES_SCRIPT := preload("res://src/foundation/event_system/event_system.gd")

var es: Node = null


func before_each() -> void:
	es = ES_SCRIPT.new()
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
# AC-004：get_flag 对不存在的键返回默认值
# ============================================================================

func test_ac004_get_flag_nonexistent_returns_default_false() -> void:
	# Act + Assert
	assert_eq(es.get_flag("non_existent", false), false,
			"不存在的 flag 应返回默认值 false")


func test_ac004_get_flag_nonexistent_returns_custom_default() -> void:
	# Act + Assert —— 自定义默认值
	assert_eq(es.get_flag("non_existent", "default_val"), "default_val",
			"不存在的 flag 应返回自定义默认值")


# ============================================================================
# AC-005：get_flag 对已设置的 flag 返回实际值
# ============================================================================

func test_ac005_get_flag_returns_true_after_set() -> void:
	# Arrange —— 先设置 flag
	es.set_flag("chapter_1", true)
	# Act + Assert
	assert_eq(es.get_flag("chapter_1", false), true,
			"已设置的 chapter_1=true 应返回 true")


func test_ac005_get_flag_returns_string_value_after_set() -> void:
	# Arrange
	es.set_flag("story_branch", "ending_a")
	# Act + Assert
	assert_eq(es.get_flag("story_branch", ""), "ending_a",
			"已设置的字符串 flag 应返回实际值")


# ============================================================================
# AC-011：get_flag 不发射信号
# ============================================================================

func test_ac011_get_flag_emits_no_signal() -> void:
	# Arrange
	watch_signals(GameStateManager)

	# Act —— 多次调用 get_flag
	es.get_flag("any_key", false)
	es.get_flag("another_key", "default")

	# Assert —— 不发射 batch_updated 信号
	# get_flag 是第一层直接读取，不触发 _buffer_change，无需 await
	assert_signal_not_emitted(GameStateManager, "batch_updated",
			"get_flag 不应发射 batch_updated 信号（无副作用）")
