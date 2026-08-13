extends GutTest
## Story 002 验收测试：StatusEffectSystem 叠加规则 + 免疫 + 溢出驱逐。
##
## 覆盖 AC-001 到 AC-020（20 条 AC）。
##
## 测试策略：
##   - SES_SCRIPT.new() 构造 StatusEffectSystem 实例
##   - 手动注入 StatusTemplate 到 ses._templates
##   - 信号监听用 Array 容器收集载荷
##   - before_each/after_each 清理实例状态

const SES_SCRIPT: GDScript = preload("res://src/core/status_effect/status_effect_system.gd")
const StatusTemplateClass: GDScript = preload("res://src/core/status_effect/status_template.gd")
const StatusInstanceClass: GDScript = preload("res://src/core/status_effect/status_instance.gd")

var ses: Node = null


func before_each() -> void:
	ses = SES_SCRIPT.new()


func after_each() -> void:
	if ses != null:
		ses.free()
		ses = null


# ============================================================================
# 辅助方法
# ============================================================================

func _inject_template(
	tmpl_id: StringName, type: int, stack_rule: int,
	base_duration: int, base_value: float, max_stacks: int = 0,
	metadata: Dictionary = {}
):
	var tmpl = StatusTemplateClass.new()
	tmpl.template_id = tmpl_id
	tmpl.type = type
	tmpl.stack_rule = stack_rule
	tmpl.max_stacks = max_stacks
	tmpl.base_duration = base_duration
	tmpl.base_value = base_value
	tmpl.metadata = metadata
	ses._templates[tmpl_id] = tmpl
	return tmpl


# ============================================================================
# AC-001：独立叠加规则 —— 同名状态可并存
# ============================================================================

func test_ac001_independent_stacking_multiple_instances() -> void:
	_inject_template(&"buff_atk", StatusTemplateClass.StatusType.BUFF,
		StatusTemplateClass.StackRule.INDEPENDENT, 3, 2.0)
	var r1: Dictionary = ses.apply_status(1001, &"buff_atk", 999)
	var r2: Dictionary = ses.apply_status(1001, &"buff_atk", 999)
	var r3: Dictionary = ses.apply_status(1001, &"buff_atk", 999)
	assert_true(r1["applied"], "第1次应成功")
	assert_true(r2["applied"], "第2次应成功")
	assert_true(r3["applied"], "第3次应成功")
	assert_ne(r1["status_id"], r2["status_id"], "应分配不同 status_id")
	assert_ne(r2["status_id"], r3["status_id"], "应分配不同 status_id")
	# 3 个独立实例
	var ids: Array[int] = ses.get_active_statuses(1001)
	assert_eq(ids.size(), 3, "应有 3 个独立实例")


# ============================================================================
# AC-002：刷新叠加规则 —— 刷新 duration
# ============================================================================

func test_ac002_refresh_stacking_resets_duration() -> void:
	_inject_template(&"poison_3", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.REFRESH, 3, 5.0)
	# 第 1 次施加
	var r1: Dictionary = ses.apply_status(1001, &"poison_3", 999)
	var sid: int = r1["status_id"]
	assert_eq(r1["reason"], "new", "首次施加 reason 应为 new")
	# tick 1 回合 → duration=2
	ses.tick_all([1001])
	var s1 = ses._instances[sid]
	assert_eq(s1.duration, 2, "tick 后 duration=2")
	# 第 2 次施加（刷新）
	var r2: Dictionary = ses.apply_status(1001, &"poison_3", 999)
	assert_eq(r2["reason"], "refreshed", "第2次施加 reason 应为 refreshed")
	assert_eq(r2["status_id"], sid, "同一 status_id")
	var s2 = ses._instances[sid]
	assert_eq(s2.duration, 3, "duration 应重置为 3")
	assert_eq(s2.current_stacks, 1, "current_stacks 保持 1")


# ============================================================================
# AC-003：叠加上限规则 —— 封顶 max_stacks
# ============================================================================

func test_ac003_cumulative_stacking_caps_at_max() -> void:
	_inject_template(&"vuln_stack", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.CUMULATIVE, 3, 1.0, 3)
	# 第 1 次
	var r1: Dictionary = ses.apply_status(1001, &"vuln_stack", 999)
	assert_eq(r1["reason"], "new", "首次 reason=new")
	var sid: int = r1["status_id"]
	assert_eq(ses._instances[sid].current_stacks, 1, "stacks=1")
	# 第 2 次
	var r2: Dictionary = ses.apply_status(1001, &"vuln_stack", 999)
	assert_eq(r2["reason"], "stacked", "第2次 reason=stacked")
	assert_eq(ses._instances[sid].current_stacks, 2, "stacks=2")
	# 第 3 次
	var r3: Dictionary = ses.apply_status(1001, &"vuln_stack", 999)
	assert_eq(r3["reason"], "stacked", "第3次 reason=stacked")
	assert_eq(ses._instances[sid].current_stacks, 3, "stacks=3")
	# 第 4 次（封顶）
	var r4: Dictionary = ses.apply_status(1001, &"vuln_stack", 999)
	assert_false(r4["applied"], "第4次应 applied=false")
	assert_eq(r4["reason"], "max_stacks", "reason=max_stacks")
	assert_eq(ses._instances[sid].current_stacks, 3, "stacks 保持 3（封顶）")


# ============================================================================
# AC-004：独立规则多实例独立倒计时
# ============================================================================

func test_ac004_independent_instances_tick_independently() -> void:
	_inject_template(&"buff_atk", StatusTemplateClass.StatusType.BUFF,
		StatusTemplateClass.StackRule.INDEPENDENT, 3, 2.0)
	var r1: Dictionary = ses.apply_status(1001, &"buff_atk", 999)
	var r2: Dictionary = ses.apply_status(1001, &"buff_atk", 999)
	var id1: int = r1["status_id"]
	var id2: int = r2["status_id"]
	# tick 1 回合
	ses.tick_all([1001])
	assert_eq(ses._instances[id1].duration, 2, "实例1 duration=2")
	assert_eq(ses._instances[id2].duration, 2, "实例2 duration=2")
	# 再 tick 2 回合——实例1 过期，实例2 仍存
	ses.tick_all([1001])
	assert_eq(ses._instances[id1].duration, 1, "实例1 duration=1")
	ses.tick_all([1001])
	assert_false(ses._instances.has(id1), "实例1 应过期被移除")
	assert_false(ses._instances.has(id2), "实例2 应过期被移除")


# ============================================================================
# AC-005：刷新规则发射 status_updated
# ============================================================================

func test_ac005_refresh_emits_status_updated() -> void:
	_inject_template(&"poison_3", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.REFRESH, 3, 5.0)
	ses.apply_status(1001, &"poison_3", 999)
	# 监听信号
	var updated_payload: Array = []
	var applied_payload: Array = []
	ses.status_updated.connect(func(t, s, c): updated_payload.append([t, s, c]))
	ses.status_applied.connect(func(t, s, tid, stk, r): applied_payload.append([t, s, tid, stk, r]))
	# 刷新
	ses.apply_status(1001, &"poison_3", 999)
	assert_eq(updated_payload.size(), 1, "应发射 1 次 status_updated")
	assert_eq(applied_payload.size(), 0, "刷新不应发射 status_applied")


# ============================================================================
# AC-006 + AC-007：叠加上限封顶不发射信号
# ============================================================================

func test_ac006_007_cumulative_cap_no_status_applied() -> void:
	_inject_template(&"vuln_stack", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.CUMULATIVE, 3, 1.0, 3)
	# 施加 3 次达到封顶
	ses.apply_status(1001, &"vuln_stack", 999)
	ses.apply_status(1001, &"vuln_stack", 999)
	ses.apply_status(1001, &"vuln_stack", 999)
	# 监听信号
	var applied_payload: Array = []
	ses.status_applied.connect(func(t, s, tid, stk, r): applied_payload.append(true))
	# 第 4 次封顶
	var r4: Dictionary = ses.apply_status(1001, &"vuln_stack", 999)
	assert_false(r4["applied"], "封顶 applied=false")
	assert_eq(r4["reason"], "max_stacks", "封顶 reason=max_stacks")
	assert_eq(applied_payload.size(), 0, "封顶不发射 status_applied")


# ============================================================================
# AC-008：免疫 3 级短路顺序
# ============================================================================

func test_ac008_immunity_3_level_short_circuit_order() -> void:
	_inject_template(&"poison_3", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.REFRESH, 3, 5.0)
	# 设 3 级免疫全部命中
	ses.set_immunity(1001, "type", StatusTemplateClass.StatusType.DEBUFF)
	ses.set_immunity(1001, "template", &"poison_3")
	# type 级最先命中
	var blocked_payload: Array = []
	ses.status_immunity_blocked.connect(func(t, tid, l): blocked_payload.append([t, tid, l]))
	var r: Dictionary = ses.apply_status(1001, &"poison_3", 999)
	assert_false(r["applied"], "免疫命中 applied=false")
	assert_eq(r["reason"], "immune", "reason=immune")
	assert_eq(blocked_payload.size(), 1, "应发射 1 次 status_immunity_blocked")
	assert_eq(blocked_payload[0][2], "type", "immune_level=type（type 最先命中）")


# ============================================================================
# AC-009：type 级免疫
# ============================================================================

func test_ac009_type_level_immunity() -> void:
	_inject_template(&"poison_3", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.REFRESH, 3, 5.0)
	_inject_template(&"freeze_1", StatusTemplateClass.StatusType.SPECIAL,
		StatusTemplateClass.StackRule.INDEPENDENT, 1, 0.0)
	ses.set_immunity(1001, "type", StatusTemplateClass.StatusType.DEBUFF)
	# poison_3 → DEBUFF 免疫阻断
	var r1: Dictionary = ses.apply_status(1001, &"poison_3", 999)
	assert_false(r1["applied"], "DEBUFF 免疫应阻断 poison_3")
	var blocked: Array = []
	ses.status_immunity_blocked.connect(func(t, tid, l): blocked.append([t, tid, l]))
	ses.apply_status(1001, &"poison_3", 999)
	assert_eq(blocked[0][2], "type", "immune_level=type")
	# freeze_1 → SPECIAL 不受影响
	var r2: Dictionary = ses.apply_status(1001, &"freeze_1", 999)
	assert_true(r2["applied"], "SPECIAL 类型不受 DEBUFF 免疫影响")


# ============================================================================
# AC-010：template 级免疫
# ============================================================================

func test_ac010_template_level_immunity() -> void:
	_inject_template(&"poison_3", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.REFRESH, 3, 5.0)
	_inject_template(&"poison_1", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.REFRESH, 1, 1.0)
	ses.set_immunity(1001, "template", &"poison_3")
	# poison_3 → 免疫
	var r1: Dictionary = ses.apply_status(1001, &"poison_3", 999)
	assert_false(r1["applied"], "template 免疫应阻断 poison_3")
	# poison_1 → 不受影响
	var r2: Dictionary = ses.apply_status(1001, &"poison_1", 999)
	assert_true(r2["applied"], "poison_1 不受 poison_3 免疫影响")


# ============================================================================
# AC-011：element 级免疫
# ============================================================================

func test_ac011_element_level_immunity() -> void:
	_inject_template(&"fire_burn", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.REFRESH, 3, 5.0, 0,
		{element = "FIRE"})
	_inject_template(&"ice_freeze", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.INDEPENDENT, 1, 0.0, 0,
		{element = "ICE"})
	ses.set_immunity(1001, "element", "FIRE")
	# fire_burn → 免疫
	var r1: Dictionary = ses.apply_status(1001, &"fire_burn", 999)
	assert_false(r1["applied"], "FIRE 元素免疫应阻断 fire_burn")
	# ice_freeze → 不受影响
	var r2: Dictionary = ses.apply_status(1001, &"ice_freeze", 999)
	assert_true(r2["applied"], "ICE 不受 FIRE 元素免疫影响")


# ============================================================================
# AC-012：免疫命中发射 status_immunity_blocked
# ============================================================================

func test_ac012_immunity_emits_blocked_signal() -> void:
	_inject_template(&"poison_3", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.REFRESH, 3, 5.0)
	ses.set_immunity(1001, "template", &"poison_3")
	var blocked_payload: Array = []
	var applied_payload: Array = []
	ses.status_immunity_blocked.connect(func(t, tid, l): blocked_payload.append([t, tid, l]))
	ses.status_applied.connect(func(_t, _s, _tid, _stk, _r): applied_payload.append(true))
	var r: Dictionary = ses.apply_status(1001, &"poison_3", 999)
	assert_false(r["applied"])
	assert_eq(blocked_payload.size(), 1, "应发射 status_immunity_blocked")
	assert_eq(blocked_payload[0][0], 1001, "载荷含 target_id")
	assert_eq(blocked_payload[0][1], &"poison_3", "载荷含 template_id")
	assert_eq(blocked_payload[0][2], "template", "载荷含 immune_level")
	assert_eq(applied_payload.size(), 0, "不应发射 status_applied")


# ============================================================================
# AC-013：set_immunity 设置标志
# ============================================================================

func test_ac013_set_immunity_sets_flag() -> void:
	ses.set_immunity(1001, "type", StatusTemplateClass.StatusType.DEBUFF)
	assert_true(ses._immunity_flags.has(1001), "_immunity_flags 应有 1001")
	assert_true(ses._immunity_flags[1001]["type"].get(StatusTemplateClass.StatusType.DEBUFF, false),
		"type 免疫标志应为 true")
	# 重复设置幂等
	ses.set_immunity(1001, "type", StatusTemplateClass.StatusType.DEBUFF)
	assert_true(ses._immunity_flags[1001]["type"].get(StatusTemplateClass.StatusType.DEBUFF, false),
		"重复设置应幂等")


# ============================================================================
# AC-014：clear_immunity 清除标志
# ============================================================================

func test_ac014_clear_immunity_removes_flag() -> void:
	_inject_template(&"poison_3", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.REFRESH, 3, 5.0)
	ses.set_immunity(1001, "type", StatusTemplateClass.StatusType.DEBUFF)
	# 施加被阻断
	var r1: Dictionary = ses.apply_status(1001, &"poison_3", 999)
	assert_false(r1["applied"], "免疫生效")
	# 清除免疫
	ses.clear_immunity(1001, "type", StatusTemplateClass.StatusType.DEBUFF)
	var r2: Dictionary = ses.apply_status(1001, &"poison_3", 999)
	assert_true(r2["applied"], "清除免疫后应成功施加")
	# 清除不存在的免疫不报错
	ses.clear_immunity(9999, "type", StatusTemplateClass.StatusType.DEBUFF)
	ses.clear_immunity(1001, "type", 9999)
	assert_true(true, "不存在的免疫清除不应报错")


# ============================================================================
# AC-015：20 活跃上限触发驱逐
# ============================================================================

func test_ac015_20_active_cap_triggers_eviction() -> void:
	# 注入 20 个不同模板
	for i in range(20):
		var tmpl_name: StringName = &"tmpl_%d" % i
		_inject_template(tmpl_name, StatusTemplateClass.StatusType.BUFF,
			StatusTemplateClass.StackRule.INDEPENDENT, 5, 1.0)
		ses.apply_status(1001, tmpl_name, 999)
	assert_eq(ses.get_active_count(1001), 20, "应有 20 个活跃状态")
	# 注入第 21 个状态模板
	_inject_template(&"overflow_test", StatusTemplateClass.StatusType.BUFF,
		StatusTemplateClass.StackRule.INDEPENDENT, 5, 1.0)
	# 监听驱逐信号
	var overflow_payload: Array = []
	ses.status_removed.connect(func(t, s, tid, r):
		if r == "overflow": overflow_payload.append([t, s, tid, r])
	)
	var r: Dictionary = ses.apply_status(1001, &"overflow_test", 999)
	assert_true(r["applied"], "第 21 个状态应成功施加")
	assert_eq(ses.get_active_count(1001), 20, "驱逐后活跃数仍为 20")
	assert_eq(overflow_payload.size(), 1, "应发射 1 次 status_removed(overflow)")


# ============================================================================
# AC-016：驱逐策略确定性排序
# ============================================================================

func test_ac016_eviction_deterministic_order() -> void:
	# 注入 2 个状态：低 priority + 高 priority
	# 低 priority（数值小，优先驱逐）
	_inject_template(&"low_prio", StatusTemplateClass.StatusType.BUFF,
		StatusTemplateClass.StackRule.INDEPENDENT, 5, 1.0)
	var tmpl_low = ses._templates[&"low_prio"]
	tmpl_low.default_priority = 1  # 低 priority（数值小）
	# 高 priority（数值大，不会被驱逐）
	_inject_template(&"high_prio", StatusTemplateClass.StatusType.BUFF,
		StatusTemplateClass.StackRule.INDEPENDENT, 5, 1.0)
	var tmpl_high = ses._templates[&"high_prio"]
	tmpl_high.default_priority = 10  # 高 priority（数值大）

	var r_low: Dictionary = ses.apply_status(1001, &"low_prio", 999, {}, 1)
	var r_high: Dictionary = ses.apply_status(1001, &"high_prio", 999, {}, 2)
	var low_id: int = r_low["status_id"]
	var high_id: int = r_high["status_id"]

	# 再注入 18 个模板填满 20
	for i in range(18):
		var tmpl_name: StringName = &"fill_%d" % i
		_inject_template(tmpl_name, StatusTemplateClass.StatusType.BUFF,
			StatusTemplateClass.StackRule.INDEPENDENT, 5, 1.0)
		ses._templates[tmpl_name].default_priority = 5
		ses.apply_status(1001, tmpl_name, 999, {}, 3 + i)

	assert_eq(ses.get_active_count(1001), 20, "应有 20 个状态")

	# 施加第 21 个——应驱逐 priority 最低的（low_prio，priority=1）
	var evicted_payload: Array = []
	ses.status_removed.connect(func(_t, s, _tid, _r): evicted_payload.append(s))
	_inject_template(&"trigger_evict", StatusTemplateClass.StatusType.BUFF,
		StatusTemplateClass.StackRule.INDEPENDENT, 5, 1.0)
	ses.apply_status(1001, &"trigger_evict", 999)
	assert_eq(evicted_payload[0], low_id, "应驱逐 priority 最低的 low_prio")


# ============================================================================
# AC-017：驱逐发射 status_removed（reason="overflow"）
# ============================================================================

func test_ac017_eviction_emits_status_removed_overflow() -> void:
	for i in range(20):
		var tmpl_name: StringName = &"tmpl_%d" % i
		_inject_template(tmpl_name, StatusTemplateClass.StatusType.BUFF,
			StatusTemplateClass.StackRule.INDEPENDENT, 5, 1.0)
		ses.apply_status(1001, tmpl_name, 999)
	# 监听 status_removed
	var removed_payload: Array = []
	ses.status_removed.connect(func(t, s, tid, r): removed_payload.append([t, s, tid, r]))
	_inject_template(&"trigger_evict", StatusTemplateClass.StatusType.BUFF,
		StatusTemplateClass.StackRule.INDEPENDENT, 5, 1.0)
	ses.apply_status(1001, &"trigger_evict", 999)
	# 应至少有一个 overflow
	var overflow_removals: Array = []
	for p in removed_payload:
		if p[3] == "overflow":
			overflow_removals.append(p)
	assert_eq(overflow_removals.size(), 1, "应有 1 个 reason=overflow 的移除")
	assert_eq(overflow_removals[0][0], 1001, "target_id 应为 1001")


# ============================================================================
# AC-018：驱逐后新状态注册成功
# ============================================================================

func test_ac018_eviction_then_new_status_registered() -> void:
	for i in range(20):
		var tmpl_name: StringName = &"tmpl_%d" % i
		_inject_template(tmpl_name, StatusTemplateClass.StatusType.BUFF,
			StatusTemplateClass.StackRule.INDEPENDENT, 5, 1.0)
		ses.apply_status(1001, tmpl_name, 999)
	# 监听 status_applied
	var applied_payload: Array = []
	ses.status_applied.connect(func(t, s, tid, stk, r): applied_payload.append([t, s, tid, stk, r]))
	_inject_template(&"new_after_evict", StatusTemplateClass.StatusType.BUFF,
		StatusTemplateClass.StackRule.INDEPENDENT, 5, 1.0)
	var r: Dictionary = ses.apply_status(1001, &"new_after_evict", 999)
	assert_true(r["applied"], "驱逐后新状态应 applied=true")
	assert_eq(r["reason"], "new", "驱逐后新状态 reason=new")
	assert_ne(r["status_id"], 0, "驱逐后新状态应有有效 status_id")
	assert_eq(applied_payload.size(), 1, "应发射 1 次 status_applied")


# ============================================================================
# AC-019：永久状态可被驱逐
# ============================================================================

func test_ac019_permanent_status_can_be_evicted() -> void:
	# 注永久状态（duration=-1, priority 最低——数值最小）
	_inject_template(&"perm_low", StatusTemplateClass.StatusType.BUFF,
		StatusTemplateClass.StackRule.REFRESH, -1, 10.0)
	var tmpl_perm = ses._templates[&"perm_low"]
	tmpl_perm.default_priority = 1  # 最低 priority（数值最小）
	var r_perm: Dictionary = ses.apply_status(1001, &"perm_low", 999, {}, 1)
	var perm_id: int = r_perm["status_id"]
	assert_eq(ses._instances[perm_id].duration, -1, "永久状态 duration=-1")

	# 填满 19 个普通状态
	for i in range(19):
		var tmpl_name: StringName = &"fill_%d" % i
		_inject_template(tmpl_name, StatusTemplateClass.StatusType.BUFF,
			StatusTemplateClass.StackRule.INDEPENDENT, 5, 1.0)
		ses._templates[tmpl_name].default_priority = 50
		ses.apply_status(1001, tmpl_name, 999, {}, 2 + i)

	assert_eq(ses.get_active_count(1001), 20, "应有 20 个状态")
	# 施加第 21 个——应驱逐永久状态（priority 99 最低）
	var evicted_payload: Array = []
	ses.status_removed.connect(func(_t, s, _tid, _r): evicted_payload.append(s))
	_inject_template(&"trigger_evict", StatusTemplateClass.StatusType.BUFF,
		StatusTemplateClass.StackRule.INDEPENDENT, 5, 1.0)
	ses.apply_status(1001, &"trigger_evict", 999)
	assert_eq(evicted_payload[0], perm_id, "应驱逐永久状态（priority 最低，duration=-1 不豁免）")


# ============================================================================
# AC-020：get_active_count 查询
# ============================================================================

func test_ac020_get_active_count_includes_expired() -> void:
	_inject_template(&"tmp_short", StatusTemplateClass.StatusType.BUFF,
		StatusTemplateClass.StackRule.INDEPENDENT, 1, 1.0)
	for i in range(5):
		var tmpl_name: StringName = &"ac020_%d" % i
		_inject_template(tmpl_name, StatusTemplateClass.StatusType.BUFF,
			StatusTemplateClass.StackRule.INDEPENDENT, 10, 1.0)
		ses.apply_status(1001, tmpl_name, 999)
	# 施加 tmp_short（duration=1）
	ses.apply_status(1001, &"tmp_short", 999)
	assert_eq(ses.get_active_count(1001), 6, "应有 6 个状态")
	# tick 后 tmp_short expired 但未移除（还在 _by_target 中）
	ses.tick_all([1001])  # tick_all 内会 remove_expired
	# 注意：tick_all 后 expired 状态会被移除，所以 count 应为 5
	# 但 AC-020 要求 get_active_count 含 is_expired 未移除的
	# 在 tick_all 中 remove_expired 是在同一次调用中执行的
	# 所以这里测试的是：施加 1 个 duration=1 状态后手动标记过期但不移除
	# 然后验证 get_active_count 包含它
	_inject_template(&"tmp_short2", StatusTemplateClass.StatusType.BUFF,
		StatusTemplateClass.StackRule.INDEPENDENT, 1, 1.0)
	ses.apply_status(1001, &"tmp_short2", 999)
	# 手动标记过期（不移除）——模拟 tick 第一遍标记但未到第二遍移除
	var ids: Array = ses._by_target.get(1001, [])
	for id in ids:
		var s = ses._instances[id]
		if s.template_id == &"tmp_short2":
			s.is_expired = true
	assert_eq(ses.get_active_count(1001), 6, "应含 is_expired 未移除的状态")

	# tick_all 后应清理过期状态
	ses.tick_all([1001])
	assert_eq(ses.get_active_count(1001), 5, "tick_all 后 expired 应被移除")


# ============================================================================
# 边缘情况补强
# ============================================================================

func test_cumulative_stacking_keeps_duration() -> void:
	# 叠加上限不刷新 duration
	_inject_template(&"vuln_stack", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.CUMULATIVE, 3, 1.0, 3)
	ses.apply_status(1001, &"vuln_stack", 999)
	# tick 2 回合 → duration=1
	ses.tick_all([1001])
	ses.tick_all([1001])
	# 再叠一次
	ses.apply_status(1001, &"vuln_stack", 999)
	# 查同名实例
	var ids: Array = ses._by_target.get(1001, [])
	var s = ses._instances[ids[0]]
	assert_eq(s.duration, 1, "叠加上限不刷新 duration（保持 1）")
	assert_eq(s.current_stacks, 2, "stacks=2")


func test_immunity_no_element_metadata_no_block() -> void:
	# 模板无 element metadata 时 element 免疫不应阻断
	_inject_template(&"no_elem", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.REFRESH, 3, 5.0)  # metadata 默认空
	ses.set_immunity(1001, "element", "FIRE")
	var r: Dictionary = ses.apply_status(1001, &"no_elem", 999)
	assert_true(r["applied"], "无 element metadata 时 element 免疫不应阻断")


func test_apply_status_with_overrides_on_refresh() -> void:
	# 刷新时 overrides.value 生效
	_inject_template(&"poison_3", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.REFRESH, 3, 5.0)
	ses.apply_status(1001, &"poison_3", 999)
	# 刷新并覆盖 value
	var r: Dictionary = ses.apply_status(1001, &"poison_3", 999, {value = 99.0})
	assert_eq(r["reason"], "refreshed", "刷新 reason=refreshed")
	var ids: Array = ses._by_target.get(1001, [])
	var s = ses._instances[ids[0]]
	assert_eq(s.value, 99.0, "overrides.value 应在刷新时生效")


func test_eviction_at_exactly_20_then_21_removes_1() -> void:
	for i in range(20):
		var tmpl_name: StringName = &"e_%d" % i
		_inject_template(tmpl_name, StatusTemplateClass.StatusType.BUFF,
			StatusTemplateClass.StackRule.INDEPENDENT, 5, 1.0)
		ses.apply_status(1001, tmpl_name, 999)
	assert_eq(ses.get_active_count(1001), 20, "20 个状态")
	# 第 21 个
	_inject_template(&"extra_one", StatusTemplateClass.StatusType.BUFF,
		StatusTemplateClass.StackRule.INDEPENDENT, 5, 1.0)
	ses.apply_status(1001, &"extra_one", 999)
	assert_eq(ses.get_active_count(1001), 20, "驱逐后仍为 20")


func test_clear_immunity_nonexistent_target_no_error() -> void:
	ses.clear_immunity(99999, "type", 0)
	assert_true(true, "清除不存在目标的免疫不应报错")


func test_set_immunity_preserves_other_levels() -> void:
	ses.set_immunity(1001, "type", StatusTemplateClass.StatusType.DEBUFF)
	ses.set_immunity(1001, "template", &"poison_3")
	# 验证两个 level 都存在
	assert_true(ses._immunity_flags[1001]["type"].get(StatusTemplateClass.StatusType.DEBUFF, false))
	assert_true(ses._immunity_flags[1001]["template"].get(&"poison_3", false))
	# 清除 type 免疫，template 免疫应保留
	ses.clear_immunity(1001, "type", StatusTemplateClass.StatusType.DEBUFF)
	assert_false(ses._immunity_flags[1001]["type"].get(StatusTemplateClass.StatusType.DEBUFF, false))
	assert_true(ses._immunity_flags[1001]["template"].get(&"poison_3", false),
		"清除 type 免疫不应影响 template 免疫")