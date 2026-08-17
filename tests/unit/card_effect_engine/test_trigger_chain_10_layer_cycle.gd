extends GutTest
## Story 003 验收测试：触发链硬限制 10 层 + visited_card_ids 循环检测。
##
## 覆盖 AC-001（栈式 LIFO 深度 3）、AC-002（循环检测跳过重复触发 + DEBUG 日志）、
## AC-003（深度 10 硬限制 + 第 11 层截断 + WARN 日志格式）
## + QA Edge cases（扇出分支共享深度计数器、前 1-10 层完整结算）。
##
## 分两层测试：
##   1. [TriggerChainState] 纯状态单测——检查/记录逻辑、深度语义、WARN 消息格式。
##   2. [ResolutionStack.resolve_all] 集成——验证深度/循环检查在出栈循环中的接入点。
##
## [b]日志断言[/b]：用 GUT 的 [code]gut.p("...")[/code] 无法可靠捕获引擎日志——
## 本 Story 的日志断言聚焦 TriggerChainState 的决策返回 + build_overflow_message 格式，
## 引擎侧日志发射属 CardEffectEngine 集成层（Story 005 后）。

const ResolutionStackClass := preload("res://src/feature/card_effect_engine/resolution_stack.gd")
const TriggerChainStateClass := preload("res://src/feature/card_effect_engine/trigger_chain_state.gd")
const EffectBaseClass := preload("res://src/feature/card_effect_engine/effect_base.gd")


# === 测试辅助 =====================================================================

class RecordingEffect:
	extends EffectBase

	var log: Array = []

	func _resolve() -> void:
		log.append(source_card_instance_id)


func _make_effect(card_id: int, seq: int = 0) -> EffectBase:
	var effect := RecordingEffect.new()
	effect.source_card_instance_id = card_id
	effect.activation_sequence = seq
	return effect


# ============================================================================
# TriggerChainState 纯状态单测
# ============================================================================

func test_check_and_record_first_call_resolves() -> void:
	var state: TriggerChainState = TriggerChainStateClass.new()
	assert_eq(state.check_and_record(1), TriggerChainState.CheckResult.RESOLVE,
			"首次触发应 RESOLVE")
	assert_eq(state.current_depth, 1, "深度应从 1 开始")


func test_check_and_record_duplicate_returns_already_visited() -> void:
	var state: TriggerChainState = TriggerChainStateClass.new()
	state.check_and_record(1)
	assert_eq(state.check_and_record(1), TriggerChainState.CheckResult.ALREADY_VISITED,
			"同一 card_instance_id 重复触发应 ALREADY_VISITED")
	assert_eq(state.current_depth, 2, "循环检查也应计数 depth+1")


func test_depth_exceeded_at_eleventh_node() -> void:
	## 第 1-10 层 RESOLVE，第 11 层 DEPTH_EXCEEDED。
	var state: TriggerChainState = TriggerChainStateClass.new()
	for i in range(1, 11):
		assert_eq(state.check_and_record(i), TriggerChainState.CheckResult.RESOLVE,
				"第 %d 层应 RESOLVE" % i)
	assert_eq(state.check_and_record(11), TriggerChainState.CheckResult.DEPTH_EXCEEDED,
			"第 11 层应 DEPTH_EXCEEDED")
	assert_eq(state.current_depth, 11, "深度应达 11")


func test_overflow_message_format_matches_ac003() -> void:
	var state: TriggerChainState = TriggerChainStateClass.new()
	state.root_card_instance_id = 7
	for i in range(1, 11):
		state.check_and_record(i)
	state.check_and_record(99)  # 第 11 层截断者 K
	var msg := state.build_overflow_message()
	assert_true(msg.begins_with("[CardEffectEngine] Trigger chain depth exceeded: max=10, root_card_id=7, chain="),
			"消息前缀应匹配 AC-003 格式")
	assert_true(msg.contains("1→2→3→4→5→6→7→8→9→10→99"),
			"chain 应包含 1→2→...→10→K（截断者 99）")


func test_is_visited_tracks_recorded_ids() -> void:
	var state: TriggerChainState = TriggerChainStateClass.new()
	assert_false(state.is_visited(1), "未记录前应为 false")
	state.check_and_record(1)
	assert_true(state.is_visited(1), "记录后应为 true")


func test_reset_clears_state() -> void:
	var state: TriggerChainState = TriggerChainStateClass.new()
	state.check_and_record(1)
	state.check_and_record(2)
	state.reset()
	assert_eq(state.current_depth, 0, "reset 后深度归零")
	assert_eq(state.visited_card_ids.size(), 0, "reset 后 visited 清空")
	assert_eq(state.chain.size(), 0, "reset 后 chain 清空")


# ============================================================================
# ResolutionStack.resolve_all 集成——深度/循环检查接入点
# ============================================================================

func test_resolve_all_with_chain_state_skips_duplicate() -> void:
	## AC-002：同一 card_instance_id 在链中重复出现 → 跳过不重复触发。
	var stack: ResolutionStack = ResolutionStackClass.new()
	var a := _make_effect(1)  # 同一 card 1 出现两次
	var b := _make_effect(1)
	stack.push(a)
	stack.push(b)

	var state: TriggerChainState = TriggerChainStateClass.new()
	var log: Array = []
	var skip_count: Array = [0]
	var count := stack.resolve_all(
		func(effect: EffectBase) -> void: log.append(effect.source_card_instance_id),
		state,
		Callable(),
		func(card_id: int, chain_state: TriggerChainState) -> void: skip_count[0] += 1)

	assert_eq(count, 1, "重复触发应只结算一次")
	assert_eq(log, [1], "只记录一次 card 1")
	assert_eq(skip_count[0], 1, "循环跳过应触发一次 cycle_skip_handler（DEBUG 日志注入点）")


func test_resolve_all_depth_10_truncates_11th() -> void:
	## AC-003：第 1-10 层结算，第 11 层截断。
	var stack: ResolutionStack = ResolutionStackClass.new()
	for i in range(1, 12):  # 1..11 共 11 个效果
		stack.push(_make_effect(i))

	var state: TriggerChainState = TriggerChainStateClass.new()
	var log: Array = []
	var overflow_count: Array = [0]  # 用数组包装——GDScript lambda 按值捕获标量，数组是引用
	var count := stack.resolve_all(
		func(effect: EffectBase) -> void: log.append(effect.source_card_instance_id),
		state,
		func(chain_state: TriggerChainState) -> void: overflow_count[0] += 1)

	assert_eq(count, 10, "前 10 层结算，第 11 层截断")
	assert_eq(log.size(), 10, "log 应含 10 个已结算效果")
	assert_eq(overflow_count[0], 1, "第 11 层应触发一次 overflow_handler")


func test_resolve_all_truncation_continues_remaining_queue() -> void:
	## QA GAP-1：深度超限后 continue（非 break）——第 11 层截断后，队列中剩余效果继续被检查。
	## 12 个效果（card 1..12）：前 10 结算，第 11、12 均 DEPTH_EXCEEDED 连续截断，队列最终排空。
	var stack: ResolutionStack = ResolutionStackClass.new()
	for i in range(1, 13):  # 1..12 共 12 个效果
		stack.push(_make_effect(i))

	var state: TriggerChainState = TriggerChainStateClass.new()
	var log: Array = []
	var overflow_count: Array = [0]
	var count := stack.resolve_all(
		func(effect: EffectBase) -> void: log.append(effect.source_card_instance_id),
		state,
		func(chain_state: TriggerChainState) -> void: overflow_count[0] += 1)

	assert_eq(count, 10, "仅前 10 层结算")
	assert_eq(overflow_count[0], 2, "第 11、12 层均被截断（continue 而非 break）")
	assert_true(stack.is_empty(), "截断后队列应被排空")


func test_resolve_all_no_chain_state_no_truncation() -> void:
	## 不传 chain_state 时，所有效果都结算（向后兼容 Story 002 行为）。
	var stack: ResolutionStack = ResolutionStackClass.new()
	for i in range(1, 13):  # 12 个效果——无深度限制
		stack.push(_make_effect(i))
	var log: Array = []
	var count := stack.resolve_all(
		func(effect: EffectBase) -> void: log.append(effect.source_card_instance_id))
	assert_eq(count, 12, "无 chain_state 时全部结算")


func test_resolve_all_fanout_shares_depth_counter() -> void:
	## QA Edge：扇出分支共享深度计数器——总节点数达 11 即截断。
	## 根 A（深度 1）结算时触发 10 个扇出 B1..B10（深度 2..11）——
	## B1..B9 正常结算（深度 ≤10），B10（第 11 个节点，深度 11）截断。
	var stack: ResolutionStack = ResolutionStackClass.new()
	var root := _make_effect(1)
	stack.push(root)

	var state: TriggerChainState = TriggerChainStateClass.new()
	var resolved: Array = []
	var overflow_count: Array = [0]

	# resolver：根结算时触发 B1..B10（card 2..11 = 10 个扇出）
	var resolver := func(effect: EffectBase) -> void:
		resolved.append(effect.source_card_instance_id)
		if effect.source_card_instance_id == 1:
			for i in range(2, 12):
				stack.push(_make_effect(i))

	stack.resolve_all(resolver, state,
		func(chain_state: TriggerChainState) -> void: overflow_count[0] += 1)

	# 根(1) + B1..B9 = 10 个节点正常结算；B10（card 11）是第 11 个节点 → 深度 11 截断。
	assert_eq(resolved.size(), 10, "根 + B1..B9 = 10 个节点正常结算")
	assert_true(resolved.has(1), "根卡牌应已结算")
	assert_false(resolved.has(11), "B10（card 11）应被截断不结算")
	assert_eq(overflow_count[0], 1, "扇出第 11 个节点应触发一次截断")
