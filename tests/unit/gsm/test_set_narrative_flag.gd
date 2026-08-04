extends GutTest
## Story 003 验收测试：GSM.set_narrative_flag() —— 第二层原子写入方法。
##
## 覆盖：
##   - AC-006: set_narrative_flag 写入后 batch_updated 携带 {old: null, new: value}
##   - AC-007: 更新值后 batch_updated 携带 {old: 旧值, new: 新值}
##
## [br][b]测试隔离[/b]: GSM 为 Autoload 单例——before_each/after_each 清理
## narrative.story_flags 与 _pending_changes 缓冲层，保证测试间无状态泄漏。
## [br][b]时序[/b]: set_narrative_flag 用 _buffer_change → 帧末 _flush_pending_changes
## 发射 batch_updated。测试需 await get_tree().process_frame 让 flush 执行后再断言载荷。


func before_each() -> void:
	# 清理 GSM 全局状态
	GameStateManager._pending_changes.clear()
	GameStateManager._flush_scheduled = false
	GameStateManager.narrative.story_flags.clear()


func after_each() -> void:
	GameStateManager._pending_changes.clear()
	GameStateManager._flush_scheduled = false
	GameStateManager.narrative.story_flags.clear()


# ============================================================================
# AC-006：首次写入 → batch_updated 携带 {old: null, new: value}
# ============================================================================

func test_ac006_first_write_carries_null_old_and_new_value() -> void:
	# Arrange
	watch_signals(GameStateManager)

	# Act
	GameStateManager.set_narrative_flag(&"flag_a", "value_1")
	await get_tree().process_frame

	# Assert —— batch_updated 发射且携带正确载荷
	assert_signal_emit_count(GameStateManager, "batch_updated", 1,
			"首次写入应发射 1 次 batch_updated")
	var params = get_signal_parameters(GameStateManager, "batch_updated", 0)
	assert_not_null(params, "应能取到 batch_updated 信号参数")
	var changes: Dictionary = params[0]
	assert_true(changes.has("narrative.story_flags.flag_a"),
			"batch_updated 应包含 narrative.story_flags.flag_a 路径")
	assert_eq(changes["narrative.story_flags.flag_a"]["old"], null,
			"首次写入 old 应为 null")
	assert_eq(changes["narrative.story_flags.flag_a"]["new"], "value_1",
			"首次写入 new 应为 value_1")


# ============================================================================
# AC-007：更新值 → batch_updated 携带 {old: 旧值, new: 新值}
# ============================================================================

func test_ac007_update_carries_old_and_new_values() -> void:
	# Arrange —— 先设置 flag_a = "value_1"（不监听信号）
	GameStateManager.set_narrative_flag(&"flag_a", "value_1")
	await get_tree().process_frame

	# 清空 pending 并开始监听——确保只捕获第二次写入的信号
	GameStateManager._pending_changes.clear()
	GameStateManager._flush_scheduled = false
	watch_signals(GameStateManager)

	# Act —— 更新为 "value_2"
	GameStateManager.set_narrative_flag(&"flag_a", "value_2")
	await get_tree().process_frame

	# Assert
	assert_signal_emit_count(GameStateManager, "batch_updated", 1,
			"更新值应发射 1 次 batch_updated")
	var params = get_signal_parameters(GameStateManager, "batch_updated", 0)
	assert_not_null(params, "应能取到 batch_updated 信号参数")
	var changes: Dictionary = params[0]
	assert_true(changes.has("narrative.story_flags.flag_a"),
			"batch_updated 应包含 narrative.story_flags.flag_a 路径")
	assert_eq(changes["narrative.story_flags.flag_a"]["old"], "value_1",
			"更新时 old 应为之前的值 value_1")
	assert_eq(changes["narrative.story_flags.flag_a"]["new"], "value_2",
			"更新时 new 应为新值 value_2")


# ============================================================================
# 补充：相同值去重——不发射 batch_updated
# ============================================================================

func test_duplicate_value_does_not_emit_batch_updated() -> void:
	# Arrange —— 先设置 flag_b = "initial"
	GameStateManager.set_narrative_flag(&"flag_b", "initial")
	await get_tree().process_frame

	# 清空 pending 并开始监听
	GameStateManager._pending_changes.clear()
	GameStateManager._flush_scheduled = false
	watch_signals(GameStateManager)

	# Act —— 相同值再次写入
	GameStateManager.set_narrative_flag(&"flag_b", "initial")
	await get_tree().process_frame

	# Assert —— 不发射 batch_updated
	assert_signal_not_emitted(GameStateManager, "batch_updated",
			"相同值重复写入不应发射 batch_updated")


# ============================================================================
# 补充：story_flags 写入只发射 batch_updated，不误发域信号
# qa-tester 缺口 3——防护未来新增域信号路由时误捕 narrative.story_flags.* 路径
# ============================================================================

func test_set_narrative_flag_emits_only_batch_updated_no_domain_signal() -> void:
	# Arrange
	watch_signals(GameStateManager)

	# Act
	GameStateManager.set_narrative_flag(&"sig_test", true)
	await get_tree().process_frame

	# Assert —— 应发射 batch_updated（story_flags 变更的唯一传播渠道）
	assert_signal_emitted(GameStateManager, "batch_updated",
			"story_flags 写入应发射 batch_updated")
	# Assert —— 不应误发任何域信号（_emit_domain_signal 对 narrative.* 路径无匹配分支）
	assert_signal_not_emitted(GameStateManager, "cultivation_changed",
			"story_flags 写入不应误发 cultivation_changed")
	assert_signal_not_emitted(GameStateManager, "resource_changed",
			"story_flags 写入不应误发 resource_changed")
	assert_signal_not_emitted(GameStateManager, "realm_changed",
			"story_flags 写入不应误发 realm_changed")
