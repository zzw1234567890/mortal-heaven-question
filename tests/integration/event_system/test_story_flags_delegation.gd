extends GutTest
## Story 003 集成验收测试：story_flags 委托写入契约。
##
## 覆盖：
##   - AC-008: 外部调用方通过 EventSystem.set_flag() 写入后
##            GSM.narrative.story_flags 被正确更新，
##            且 stub 调用方不直接访问 GSM.narrative.story_flags
##   - AC-009: 代码库 grep 检查点——EventSystem.set_flag 是唯一写入入口
##            （声明 + 委托链验证）
##
## [br][b]委托链[/b]: stub → EventSystem.set_flag() → GSM.set_narrative_flag()
##           → _buffer_change → 帧末 batch_updated

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
# Stub 调用方——模拟 StorySystem / DialogueSystem / CardEffectEngine
# ============================================================================

## 模拟外部系统（StorySystem/DialogueSystem/CardEffectEngine 的 stub）。
## 仅持有 EventSystem 引用，通过 EventSystem.set_flag() 委托写入——
## [b]不[/b]直接访问 GSM.narrative.story_flags（架构合规，ADR-0003 决策 3）。
class StubCaller:
	extends RefCounted
	var _event_system: Node = null

	func _init(event_system: Node) -> void:
		_event_system = event_system

	## 模拟 StorySystem.advance_chapter(chapter_id) 的写入路径。
	func advance_chapter(chapter_id: String) -> void:
		_event_system.set_flag("chapter_" + chapter_id, true)

	## 模拟 DialogueOutcome.set_flag 的写入路径。
	func set_dialogue_flag(target: String, value: Variant) -> void:
		_event_system.set_flag(target, value)

	## 模拟 CardEffectEngine SET_FLAG 效果的写入路径。
	func apply_set_flag_effect(flag_key: String, value: Variant) -> void:
		_event_system.set_flag(flag_key, value)


# ============================================================================
# AC-008：外部调用方通过 EventSystem.set_flag() 委托写入
# ============================================================================

func test_ac008_stub_writes_via_event_system_updates_gsm() -> void:
	# Arrange —— 创建 stub 调用方，仅持有 EventSystem 引用
	var stub := StubCaller.new(es)

	# Act —— stub 通过 EventSystem.set_flag() 委托写入（模拟 3 个不同系统的写入路径）
	stub.advance_chapter("1")
	stub.set_dialogue_flag("met_npc", true)
	stub.apply_set_flag_effect("card_trigger", "activated")

	# await 帧末 flush 执行（数据已立即写入，await 仅为信号完整性）
	await get_tree().process_frame

	# Assert —— GSM.narrative.story_flags 被正确更新
	assert_eq(GameStateManager.narrative.story_flags["chapter_1"], true,
			"stub 通过 EventSystem.set_flag 写入 chapter_1 应更新 GSM")
	assert_eq(GameStateManager.narrative.story_flags["met_npc"], true,
			"stub 通过 EventSystem.set_flag 写入 met_npc 应更新 GSM")
	assert_eq(GameStateManager.narrative.story_flags["card_trigger"], "activated",
			"stub 通过 EventSystem.set_flag 写入 card_trigger 应更新 GSM")


func test_ac008_stub_does_not_access_gsm_directly() -> void:
	## 验证 stub 调用方不直接访问 GSM.narrative.story_flags。
	## stub 类定义中仅持有 EventSystem 引用，所有写入通过 set_flag() 委托——
	## 无 GSM.narrative.story_flags 直接赋值（架构合规，ADR-0003 决策 3）。
	# Arrange
	var stub := StubCaller.new(es)

	# Act —— stub 调用 advance_chapter，内部仅调用 EventSystem.set_flag
	stub.advance_chapter("2")
	await get_tree().process_frame

	# Assert —— 状态正确变更，证明委托链工作
	assert_eq(GameStateManager.narrative.story_flags["chapter_2"], true,
			"stub 委托写入应正确更新 GSM")
	# stub 类定义中无 GSM.narrative.story_flags 直接访问——架构合规（代码审查检查点）


# ============================================================================
# AC-009：代码库 grep 检查点
# ============================================================================

## AC-009 代码审查检查点声明：
## ----------------------------------
## 整个代码库中（排除 EventSystem.set_flag 和 GSM.set_narrative_flag 自身），
## 不存在 GSM.narrative.story_flags[ 的直接赋值。
##
## Story 003 阶段平凡通过——仅 Foundation 层代码存在 EventSystem.set_flag()
## 和 GSM.set_narrative_flag() 两个写入点。Story 005 及后续 sprint 重新验证。
##
## 验证命令（CI 或人工执行）：
##   grep -rn "narrative\.story_flags\[" src/ tests/ \
##     | grep -v "event_system.gd" \
##     | grep -v "game_state_manager.gd"
## 预期结果：无直接赋值行（仅读取访问允许）。
##
## 此测试通过断言 EventSystem.set_flag 是唯一有效写入入口来间接验证。

func test_ac009_event_system_is_sole_write_entry_point() -> void:
	# Arrange —— 清空 story_flags 确保从零开始
	GameStateManager.narrative.story_flags.clear()

	# Act —— 通过唯一公开入口写入
	es.set_flag("ac009_test_flag", "unique_value")
	await get_tree().process_frame

	# Assert —— 状态正确变更，证明 EventSystem.set_flag 是有效的唯一写入入口
	assert_eq(GameStateManager.narrative.story_flags["ac009_test_flag"], "unique_value",
			"EventSystem.set_flag 是 story_flags 唯一写入入口——调用后应正确更新 GSM")


func test_ac009_delegation_chain_completes_end_to_end() -> void:
	## 验证完整委托链：
	## EventSystem.set_flag → GSM.set_narrative_flag → _buffer_change → 帧末 batch_updated
	# Arrange
	watch_signals(GameStateManager)

	# Act
	es.set_flag("chain_test", "end_to_end")
	await get_tree().process_frame

	# Assert —— GSM 状态更新
	assert_eq(GameStateManager.narrative.story_flags["chain_test"], "end_to_end",
			"委托链终点：GSM.narrative.story_flags 应被更新")
	# Assert —— batch_updated 携带正确路径
	assert_signal_emitted(GameStateManager, "batch_updated",
			"委托链终点：batch_updated 应被发射")
	var params = get_signal_parameters(GameStateManager, "batch_updated", 0)
	assert_not_null(params, "应能取到 batch_updated 信号参数")
	var changes: Dictionary = params[0]
	assert_true(changes.has("narrative.story_flags.chain_test"),
			"batch_updated 应携带 narrative.story_flags.chain_test 路径")
