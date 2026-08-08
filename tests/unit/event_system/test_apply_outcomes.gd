extends GutTest
## Story 005 验收测试：EventSystem.apply_outcomes() —— 结果执行器。
##
## 覆盖 AC-001~AC-018（单 outcome 执行）。
##
## 测试策略：
##   - 使用 ES_SCRIPT.new() 构造 EventSystem 实例（不调 _ready，不加载模板）
##   - GSM 为 Autoload 单例，before_each/after_each 清理状态
##   - 构造 resolved_outcomes 字典数组直接调用 apply_outcomes，跳过 resolve_option 概率逻辑
##   - ADD_CARD 用 watch_signals + assert_signal_emitted 验证信号发射 + 载荷
##   - TRIGGER_BATTLE/HEAL/DAMAGE/NOTHING 验证不产生副作用
##   - chance<1.0 未触发：构造 triggered=false 项，验证被跳过

const ES_SCRIPT := preload("res://src/foundation/event_system/event_system.gd")
const EventInstanceClass := preload("res://src/foundation/event_system/event_instance.gd")
const EventEnumsClass := preload("res://src/foundation/event_system/event_enums.gd")

var es: Node = null


func before_each() -> void:
	es = ES_SCRIPT.new()
	# 清理 GSM 全局状态——Autoload 单例跨测试持续存在
	_reset_gsm_state()
	# es 是 ES_SCRIPT.new() 实例（不调 _ready），其 resource_add_requested 信号无监听者——
	# 手动连接到 ResourceSystem Autoload 的处理方法（ADD_RESOURCE 信号委托模式）
	es.resource_add_requested.connect(ResourceSystem._on_resource_add_requested)


func after_each() -> void:
	if es != null and es.resource_add_requested.is_connected(ResourceSystem._on_resource_add_requested):
		es.resource_add_requested.disconnect(ResourceSystem._on_resource_add_requested)
	if es != null:
		es.free()
		es = null
	_reset_gsm_state()


func _reset_gsm_state() -> void:
	GameStateManager._pending_changes.clear()
	GameStateManager._flush_scheduled = false
	# 重置关键域到默认值
	GameStateManager.player.cultivation = 0
	GameStateManager.player.max_cultivation = 1000
	GameStateManager.player.cultivation_full = false
	GameStateManager.player.overflow_pool = 0
	GameStateManager.player.resources = {
		"ling_shi": 0,
		"ling_cai": {"low": 0, "medium": 0, "high": 0, "top": 0},
		"dan_yao_sui_pian": 0,
	}
	GameStateManager.player.talents.clear()
	GameStateManager.collection.owned_cards.clear()
	GameStateManager.collection.total_count = 0
	GameStateManager.exploration.action_points = 0
	GameStateManager.narrative.current_chapter = ""
	GameStateManager.narrative.completed_chapters.clear()
	GameStateManager.narrative.story_flags.clear()
	# 校验状态由 after_each 统一重置——test_ac004 不再手动清理
	GameStateManager.validation_enabled = false
	GameStateManager._card_template_database = {}


func _make_instance_with_outcomes(outcomes: Array[Dictionary]) -> EventInstance:
	## 构造一个 resolved_outcomes 已填充的 EventInstance，跳过 resolve_option。
	var inst := EventInstanceClass.new()
	inst.template_id = &"test_apply"
	inst.selected_option_index = 0
	inst.resolved_outcomes = outcomes
	return inst


func _make_triggered_outcome(type: int, target: String = "", value: int = 0,
		value_str: String = "") -> Dictionary:
	## 构造一个 triggered=true 的 outcome 字典。
	return {
		"triggered": true,
		"type": type,
		"target": target,
		"value": value,
		"value_str": value_str,
	}


func _make_untriggered_outcome(type: int) -> Dictionary:
	## 构造一个 triggered=false 的 outcome 字典（chance 判定失败）。
	return {
		"triggered": false,
		"type": type,
		"target": "",
		"value": 0,
		"value_str": "",
	}


# ============================================================================
# AC-001：ADD_RESOURCE → GSM.add_resource 被调用且值正确
# ============================================================================

func test_ac001_add_resource_writes_to_gsm() -> void:
	# Arrange
	var inst := _make_instance_with_outcomes([
		_make_triggered_outcome(EventEnumsClass.OutcomeType.ADD_RESOURCE, "ling_shi", 100),
	])

	# Act
	es.apply_outcomes(inst)

	# Assert —— GSM.player.resources.ling_shi 应增加 100
	assert_eq(GameStateManager.player.resources["ling_shi"], 100,
			"ADD_RESOURCE(ling_shi, 100) 应写入 GSM")


# ============================================================================
# AC-002：ADD_CULTIVATION → GSM.add_cultivation 被调用且值正确
# ============================================================================

func test_ac002_add_cultivation_writes_to_gsm() -> void:
	# Arrange
	var inst := _make_instance_with_outcomes([
		_make_triggered_outcome(EventEnumsClass.OutcomeType.ADD_CULTIVATION, "", 500),
	])

	# Act
	es.apply_outcomes(inst)

	# Assert —— GSM.player.cultivation 应增加 500
	assert_eq(GameStateManager.player.cultivation, 500,
			"ADD_CULTIVATION(500) 应写入 GSM")


# ============================================================================
# AC-003：ADD_CARD → card_reward_requested 信号发射且携带 template_id
# ============================================================================

func test_ac003_add_card_emits_card_reward_requested() -> void:
	# Arrange
	var inst := _make_instance_with_outcomes([
		_make_triggered_outcome(EventEnumsClass.OutcomeType.ADD_CARD, "card_001"),
	])
	watch_signals(es)

	# Act
	es.apply_outcomes(inst)

	# Assert
	assert_signal_emitted(es, "card_reward_requested",
			"ADD_CARD 应发射 card_reward_requested 信号")


func test_ac003_add_card_signal_carries_correct_template_id() -> void:
	# Arrange
	var inst := _make_instance_with_outcomes([
		_make_triggered_outcome(EventEnumsClass.OutcomeType.ADD_CARD, "card_001"),
	])
	watch_signals(es)

	# Act
	es.apply_outcomes(inst)

	# Assert —— 载荷应为 template_id = "card_001"
	var params = get_signal_parameters(es, "card_reward_requested", 0)
	assert_not_null(params, "应能取到 card_reward_requested 信号参数")
	assert_eq(params[0], &"card_001",
			"card_reward_requested 载荷应为 template_id=card_001")


# ============================================================================
# AC-004：REMOVE_CARD → GSM.remove_card_from_collection 被调用
# ============================================================================

func test_ac004_remove_card_calls_gsm_method() -> void:
	# Arrange —— 预填充一张卡牌实例
	GameStateManager.validation_enabled = true
	GameStateManager._card_template_database = {"card_test": {}}
	GameStateManager.collection.owned_cards.append({
		"card_instance_id": 42,
		"template_id": "card_test",
	})
	GameStateManager.collection.total_count = 1

	var inst := _make_instance_with_outcomes([
		_make_triggered_outcome(EventEnumsClass.OutcomeType.REMOVE_CARD, "", 42),
	])

	# Act
	es.apply_outcomes(inst)

	# Assert —— 卡牌实例 42 应被移除
	assert_eq(GameStateManager.collection.owned_cards.size(), 0,
			"REMOVE_CARD(42) 应从 collection 移除该实例")
	assert_eq(GameStateManager.collection.total_count, 0,
			"total_count 应更新为 0")
	# 清理由 after_each 统一处理（validation_enabled / _card_template_database）


func test_ac004_remove_card_nonexistent_returns_false_silently() -> void:
	# Arrange —— 空收藏，移除不存在的实例 ID
	GameStateManager.validation_enabled = true
	GameStateManager._card_template_database = {"card_test": {}}

	var inst := _make_instance_with_outcomes([
		_make_triggered_outcome(EventEnumsClass.OutcomeType.REMOVE_CARD, "", 999),
	])

	# Act —— 不应崩溃
	es.apply_outcomes(inst)

	# Assert —— 空收藏仍为空
	assert_eq(GameStateManager.collection.owned_cards.size(), 0,
			"REMOVE_CARD 不存在的实例不应崩溃")
	# 清理由 after_each 统一处理（validation_enabled / _card_template_database）


# ============================================================================
# AC-005：SET_FLAG → EventSystem.set_flag() → GSM.set_narrative_flag()
# ============================================================================

func test_ac005_set_flag_writes_via_event_system() -> void:
	# Arrange
	var inst := _make_instance_with_outcomes([
		_make_triggered_outcome(EventEnumsClass.OutcomeType.SET_FLAG, "met_boss", 0, "true"),
	])

	# Act
	es.apply_outcomes(inst)

	# Assert —— story_flags 应通过 set_flag → set_narrative_flag 写入
	assert_eq(GameStateManager.narrative.story_flags.get("met_boss", null), "true",
			"SET_FLAG(met_boss, true) 应通过 EventSystem.set_flag 写入 GSM")


# ============================================================================
# AC-006：RESTORE_AP → GSM.restore_action_points 被调用
# ============================================================================

func test_ac006_restore_ap_writes_to_gsm() -> void:
	# Arrange
	var inst := _make_instance_with_outcomes([
		_make_triggered_outcome(EventEnumsClass.OutcomeType.RESTORE_AP, "", 2),
	])

	# Act
	es.apply_outcomes(inst)

	# Assert —— exploration.action_points 应增加 2
	assert_eq(GameStateManager.exploration.action_points, 2,
			"RESTORE_AP(2) 应写入 GSM.exploration.action_points")


# ============================================================================
# AC-007：GAIN_TALENT → GSM.unlock_talent 被调用
# ============================================================================

func test_ac007_gain_talent_writes_to_gsm() -> void:
	# Arrange
	var inst := _make_instance_with_outcomes([
		_make_triggered_outcome(EventEnumsClass.OutcomeType.GAIN_TALENT, "talent_003"),
	])

	# Act
	es.apply_outcomes(inst)

	# Assert —— player.talents 应包含 talent_003
	assert_true(GameStateManager.player.talents.has(&"talent_003"),
			"GAIN_TALENT(talent_003) 应写入 GSM.player.talents")


func test_ac007_gain_talent_deduplicates() -> void:
	# Arrange —— 已拥有该天赋
	GameStateManager.player.talents.append(&"talent_003")
	var inst := _make_instance_with_outcomes([
		_make_triggered_outcome(EventEnumsClass.OutcomeType.GAIN_TALENT, "talent_003"),
	])

	# Act
	es.apply_outcomes(inst)

	# Assert —— 去重，不重复 append
	var count: int = GameStateManager.player.talents.count(&"talent_003")
	assert_eq(count, 1, "GAIN_TALENT 重复解锁应去重（仅保留 1 个）")


# ============================================================================
# AC-008：ADVANCE_CHAPTER → GSM.advance_chapter 被调用
# ============================================================================

func test_ac008_advance_chapter_writes_to_gsm() -> void:
	# Arrange
	var inst := _make_instance_with_outcomes([
		_make_triggered_outcome(EventEnumsClass.OutcomeType.ADVANCE_CHAPTER, "chapter_2"),
	])

	# Act
	es.apply_outcomes(inst)

	# Assert —— narrative.current_chapter 应为 "chapter_2"
	assert_eq(GameStateManager.narrative.current_chapter, "chapter_2",
			"ADVANCE_CHAPTER(chapter_2) 应写入 GSM.narrative.current_chapter")


func test_ac008_advance_chapter_appends_old_to_completed() -> void:
	# Arrange —— 当前有章节
	GameStateManager.narrative.current_chapter = "chapter_1"
	var inst := _make_instance_with_outcomes([
		_make_triggered_outcome(EventEnumsClass.OutcomeType.ADVANCE_CHAPTER, "chapter_2"),
	])

	# Act
	es.apply_outcomes(inst)

	# Assert —— 旧章节应 append 到 completed_chapters
	assert_eq(GameStateManager.narrative.current_chapter, "chapter_2",
			"current_chapter 应更新为 chapter_2")
	assert_true(GameStateManager.narrative.completed_chapters.has("chapter_1"),
			"旧章节 chapter_1 应 append 到 completed_chapters")


# ============================================================================
# AC-009：TRIGGER_BATTLE → 不执行任何操作
# ============================================================================

func test_ac009_trigger_battle_no_side_effects() -> void:
	# Arrange
	var cultivation_before: int = GameStateManager.player.cultivation
	var ap_before: int = GameStateManager.exploration.action_points
	var flags_before: int = GameStateManager.narrative.story_flags.size()

	var inst := _make_instance_with_outcomes([
		_make_triggered_outcome(EventEnumsClass.OutcomeType.TRIGGER_BATTLE, "enemy_001"),
	])

	# Act
	es.apply_outcomes(inst)

	# Assert —— 不产生任何副作用
	assert_eq(GameStateManager.player.cultivation, cultivation_before,
			"TRIGGER_BATTLE 不应修改 cultivation")
	assert_eq(GameStateManager.exploration.action_points, ap_before,
			"TRIGGER_BATTLE 不应修改 action_points")
	assert_eq(GameStateManager.narrative.story_flags.size(), flags_before,
			"TRIGGER_BATTLE 不应修改 story_flags")


# ============================================================================
# AC-010：HEAL / DAMAGE → 不执行任何操作
# ============================================================================

func test_ac010_heal_no_side_effects() -> void:
	# Arrange
	var cultivation_before: int = GameStateManager.player.cultivation
	var inst := _make_instance_with_outcomes([
		_make_triggered_outcome(EventEnumsClass.OutcomeType.HEAL, "", 50),
	])

	# Act
	es.apply_outcomes(inst)

	# Assert
	assert_eq(GameStateManager.player.cultivation, cultivation_before,
			"HEAL 不应修改任何 GSM 状态")


func test_ac010_damage_no_side_effects() -> void:
	# Arrange
	var cultivation_before: int = GameStateManager.player.cultivation
	var inst := _make_instance_with_outcomes([
		_make_triggered_outcome(EventEnumsClass.OutcomeType.DAMAGE, "", 30),
	])

	# Act
	es.apply_outcomes(inst)

	# Assert
	assert_eq(GameStateManager.player.cultivation, cultivation_before,
			"DAMAGE 不应修改任何 GSM 状态")


# ============================================================================
# AC-011：NOTHING → 不执行任何操作但仍计入 resolved_outcomes
# ============================================================================

func test_ac011_nothing_no_side_effects() -> void:
	# Arrange
	var cultivation_before: int = GameStateManager.player.cultivation
	var inst := _make_instance_with_outcomes([
		_make_triggered_outcome(EventEnumsClass.OutcomeType.NOTHING),
	])

	# Act
	es.apply_outcomes(inst)

	# Assert —— 不产生副作用
	assert_eq(GameStateManager.player.cultivation, cultivation_before,
			"NOTHING 不应修改任何 GSM 状态")


func test_ac011_nothing_still_counted_in_resolved_outcomes() -> void:
	# Arrange —— 多个 outcome 含 NOTHING，验证计数器
	var inst := _make_instance_with_outcomes([
		_make_triggered_outcome(EventEnumsClass.OutcomeType.ADD_RESOURCE, "ling_shi", 50),
		_make_triggered_outcome(EventEnumsClass.OutcomeType.NOTHING),
		_make_triggered_outcome(EventEnumsClass.OutcomeType.ADD_CULTIVATION, "", 100),
	])

	# Act
	es.apply_outcomes(inst)

	# Assert —— resolved_outcomes 仍包含 3 项（NOTHING 计入但不执行）
	assert_eq(inst.resolved_outcomes.size(), 3,
			"NOTHING 应仍计入 resolved_outcomes（计数器验证）")
	# ADD_RESOURCE 和 ADD_CULTIVATION 应正常执行
	assert_eq(GameStateManager.player.resources["ling_shi"], 50,
			"NOTHING 不应影响其他 outcome 执行")
	assert_eq(GameStateManager.player.cultivation, 100,
			"NOTHING 不应影响其他 outcome 执行")


# ============================================================================
# AC-012：chance<1.0 未触发的 outcome → triggered=false 项被跳过
# ============================================================================

func test_ac012_untriggered_outcome_skipped() -> void:
	# Arrange —— 一个 triggered=false 的 ADD_RESOURCE
	var inst := _make_instance_with_outcomes([
		_make_untriggered_outcome(EventEnumsClass.OutcomeType.ADD_RESOURCE),
	])

	# Act
	es.apply_outcomes(inst)

	# Assert —— 未触发的不应写入 GSM
	assert_eq(GameStateManager.player.resources["ling_shi"], 0,
			"triggered=false 的 outcome 应被跳过")


func test_ac012_mixed_triggered_untriggered_only_executes_triggered() -> void:
	# Arrange —— 混合触发/未触发
	var inst := _make_instance_with_outcomes([
		_make_triggered_outcome(EventEnumsClass.OutcomeType.ADD_RESOURCE, "ling_shi", 100),
		_make_untriggered_outcome(EventEnumsClass.OutcomeType.ADD_RESOURCE),
		_make_triggered_outcome(EventEnumsClass.OutcomeType.ADD_CULTIVATION, "", 200),
	])

	# Act
	es.apply_outcomes(inst)

	# Assert —— 仅 triggered=true 的执行
	assert_eq(GameStateManager.player.resources["ling_shi"], 100,
			"仅 triggered=true 的 ADD_RESOURCE 应执行（100，而非 200）")
	assert_eq(GameStateManager.player.cultivation, 200,
			"triggered=true 的 ADD_CULTIVATION 应执行")


# ============================================================================
# AC-013：所有 Outcome 结算完成后 event_resolved 信号发射
# ============================================================================

func test_ac013_event_resolved_emitted_after_apply() -> void:
	# Arrange
	var inst := _make_instance_with_outcomes([
		_make_triggered_outcome(EventEnumsClass.OutcomeType.ADD_RESOURCE, "ling_shi", 50),
	])
	watch_signals(es)

	# Act
	es.apply_outcomes(inst)

	# Assert
	assert_signal_emitted(es, "event_resolved",
			"apply_outcomes 完成后应发射 event_resolved 信号")


func test_ac013_event_resolved_emitted_after_all_outcomes_processed() -> void:
	# Arrange —— 多个 outcome，验证 event_resolved 在全部处理完后发射
	var inst := _make_instance_with_outcomes([
		_make_triggered_outcome(EventEnumsClass.OutcomeType.ADD_RESOURCE, "ling_shi", 50),
		_make_triggered_outcome(EventEnumsClass.OutcomeType.ADD_CULTIVATION, "", 100),
		_make_triggered_outcome(EventEnumsClass.OutcomeType.NOTHING),
	])
	watch_signals(es)

	# Act
	es.apply_outcomes(inst)

	# Assert —— event_resolved 仅发射 1 次（在所有 outcome 处理后）
	assert_signal_emit_count(es, "event_resolved", 1,
			"event_resolved 应在所有 outcome 处理完后发射 1 次")


# ============================================================================
# AC-014：event_resolved 信号携带 event_id、option_idx、outcomes 三个参数
# ============================================================================

func test_ac014_event_resolved_carries_three_params() -> void:
	# Arrange
	var inst := _make_instance_with_outcomes([
		_make_triggered_outcome(EventEnumsClass.OutcomeType.ADD_RESOURCE, "ling_shi", 50),
	])
	inst.template_id = &"test_event_001"
	inst.selected_option_index = 2
	watch_signals(es)

	# Act
	es.apply_outcomes(inst)

	# Assert —— 信号携带三个参数
	var params = get_signal_parameters(es, "event_resolved", 0)
	assert_not_null(params, "应能取到 event_resolved 信号参数")
	assert_eq(params.size(), 3, "event_resolved 应携带 3 个参数")
	assert_eq(params[0], &"test_event_001", "第 1 参数应为 event_id")
	assert_eq(params[1], 2, "第 2 参数应为 option_idx")
	assert_eq(params[2].size(), 1, "第 3 参数应为 outcomes 数组（1 项）")


# ============================================================================
# AC-016：EventSystem 不直接导入或调用 CardSystem（代码审查检查点声明）
# ============================================================================

## AC-016 代码审查检查点声明：
## ----------------------------------
## EventSystem（Foundation 层）不直接导入或调用 CardSystem（Core 层）的任何方法。
## ADD_CARD 结果通过 card_reward_requested 信号委托（ADR-0003 决策 6 / ADR-0007 Cat 2c）。
##
## 验证命令（CI 或人工执行）：
##   grep -n "CardSystem" src/foundation/event_system/event_system.gd
## 预期结果：无任何直接调用（仅文档注释中提及 CardSystem 作为信号消费者）。
##
## 此测试通过断言 apply_outcomes 中 ADD_CARD 分支仅发射信号、不调用 CardSystem 方法来间接验证。

func test_ac016_add_card_branch_only_emits_signal_no_direct_call() -> void:
	# Arrange —— ADD_CARD outcome
	var inst := _make_instance_with_outcomes([
		_make_triggered_outcome(EventEnumsClass.OutcomeType.ADD_CARD, "card_001"),
	])
	watch_signals(es)

	# Act
	es.apply_outcomes(inst)

	# Assert —— 应发射 card_reward_requested 信号（信号委托，非直接调用）
	assert_signal_emitted(es, "card_reward_requested",
			"ADD_CARD 应通过 card_reward_requested 信号委托（非直接调用 CardSystem）")
	# 代码审查检查点：event_system.gd 中无 CardSystem 直接调用
	# grep -n "CardSystem" src/foundation/event_system/event_system.gd
	# 预期：仅文档注释中提及，无代码级调用


# ============================================================================
# AC-017：GSM.add_resource 失败时 push_error 被记录
# ============================================================================

func test_ac017_add_resource_failure_records_push_error() -> void:
	# Arrange —— 使用不存在的资源类型触发 add_resource 返回 false
	# ADD_RESOURCE 走信号委托 → ResourceSystem.add_resource 对未知类型 push_error 1 次
	var inst := _make_instance_with_outcomes([
		_make_triggered_outcome(EventEnumsClass.OutcomeType.ADD_RESOURCE, "nonexistent_resource", 100),
	])

	# Act
	es.apply_outcomes(inst)

	# Assert —— ResourceSystem.add_resource 失败时 push_error 1 次（信号委托模式，EventSystem 不再直接 push_error）
	assert_push_error_count(1,
			"add_resource 失败时 ResourceSystem 应 push_error 1 次（未知资源类型）")


# ============================================================================
# AC-018：未处理的 OutcomeType 触发 push_warning
# ============================================================================

func test_ac018_unhandled_outcome_type_triggers_push_warning() -> void:
	# Arrange —— 构造 type=99（未处理的枚举值）
	var inst := _make_instance_with_outcomes([{
		"triggered": true,
		"type": 99,  # 未处理的 OutcomeType
		"target": "",
		"value": 0,
		"value_str": "",
	}])

	# Act
	es.apply_outcomes(inst)

	# Assert —— 应触发 push_warning 1 次
	assert_push_warning_count(1,
			"未处理的 OutcomeType 应触发 push_warning")


# ============================================================================
# 补充：apply_outcomes 空 resolved_outcomes 不崩溃
# ============================================================================

func test_apply_outcomes_empty_resolved_outcomes_no_crash() -> void:
	# Arrange
	var inst := _make_instance_with_outcomes([])
	watch_signals(es)

	# Act
	es.apply_outcomes(inst)

	# Assert —— 空 outcomes 仍发射 event_resolved（无 outcome 处理）
	assert_signal_emitted(es, "event_resolved",
			"空 resolved_outcomes 仍应发射 event_resolved")


# ============================================================================
# 补充：apply_outcomes 多种 outcome 混合执行
# ============================================================================

func test_apply_outcomes_multiple_mixed_outcomes_execute_correctly() -> void:
	# Arrange —— 混合 5 种不同 outcome
	var inst := _make_instance_with_outcomes([
		_make_triggered_outcome(EventEnumsClass.OutcomeType.ADD_RESOURCE, "ling_shi", 100),
		_make_triggered_outcome(EventEnumsClass.OutcomeType.ADD_CULTIVATION, "", 200),
		_make_triggered_outcome(EventEnumsClass.OutcomeType.SET_FLAG, "met_npc", 0, "true"),
		_make_triggered_outcome(EventEnumsClass.OutcomeType.RESTORE_AP, "", 3),
		_make_triggered_outcome(EventEnumsClass.OutcomeType.NOTHING),
	])

	# Act
	es.apply_outcomes(inst)

	# Assert —— 各 outcome 按预期执行
	assert_eq(GameStateManager.player.resources["ling_shi"], 100,
			"混合执行：ADD_RESOURCE 应写入")
	assert_eq(GameStateManager.player.cultivation, 200,
			"混合执行：ADD_CULTIVATION 应写入")
	assert_eq(GameStateManager.narrative.story_flags.get("met_npc", null), "true",
			"混合执行：SET_FLAG 应写入")
	assert_eq(GameStateManager.exploration.action_points, 3,
			"混合执行：RESTORE_AP 应写入")
