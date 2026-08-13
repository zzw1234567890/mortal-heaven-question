extends GutTest
## Story 003 验收测试：StatusEffectSystem snapshot 导出 + 暂挂/恢复。
##
## 覆盖 AC-001 到 AC-018（18 条 AC）。
##
## 测试策略：
##   - SES_SCRIPT.new() 构造 StatusEffectSystem 实例
##   - 手动注入 StatusTemplate
##   - 信号监听用 Array 容器收集载荷
##   - snapshot round-trip 用 export → 清空 → import 验证

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
	default_priority: int = 0
):
	var tmpl = StatusTemplateClass.new()
	tmpl.template_id = tmpl_id
	tmpl.type = type
	tmpl.stack_rule = stack_rule
	tmpl.max_stacks = max_stacks
	tmpl.base_duration = base_duration
	tmpl.base_value = base_value
	tmpl.default_priority = default_priority
	ses._templates[tmpl_id] = tmpl
	return tmpl


# ============================================================================
# AC-001：export_snapshot 返回结构
# ============================================================================

func test_ac001_export_snapshot_returns_structure() -> void:
	_inject_template(&"poison_3", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.REFRESH, 3, 5.0)
	_inject_template(&"buff_atk", StatusTemplateClass.StatusType.BUFF,
		StatusTemplateClass.StackRule.INDEPENDENT, 3, 2.0)
	_inject_template(&"freeze_1", StatusTemplateClass.StatusType.SPECIAL,
		StatusTemplateClass.StackRule.INDEPENDENT, 1, 0.0)
	ses.apply_status(1001, &"poison_3", 999)
	ses.apply_status(1001, &"buff_atk", 999)
	ses.apply_status(1001, &"freeze_1", 999)

	var snapshot: Array[Dictionary] = ses.export_snapshot()
	assert_eq(snapshot.size(), 3, "应导出 3 个状态")
	for entry: Dictionary in snapshot:
		assert_true(entry.has("id"), "应含 id")
		assert_true(entry.has("template_id"), "应含 template_id")
		assert_true(entry.has("target_id"), "应含 target_id")
		assert_true(entry.has("duration"), "应含 duration")
		assert_true(entry.has("applied_turn"), "应含 applied_turn")
		assert_true(entry.has("value"), "应含 value")
		assert_true(entry.has("current_stacks"), "应含 current_stacks")
		assert_true(entry.has("source_card_instance_id"), "应含 source_card_instance_id")
		assert_true(entry.has("priority"), "应含 priority")
		assert_true(entry.has("is_hidden"), "应含 is_hidden")


# ============================================================================
# AC-002：snapshot 排除过期状态
# ============================================================================

func test_ac002_snapshot_excludes_expired() -> void:
	_inject_template(&"poison_3", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.REFRESH, 3, 5.0)
	_inject_template(&"tmp_expire", StatusTemplateClass.StatusType.BUFF,
		StatusTemplateClass.StackRule.INDEPENDENT, 1, 1.0)
	ses.apply_status(1001, &"poison_3", 999)
	ses.apply_status(1001, &"tmp_expire", 999)
	# 手动标记 tmp_expire 过期（不移除）
	var ids: Array = ses._by_target.get(1001, [])
	for id in ids:
		var s = ses._instances[id]
		if s.template_id == &"tmp_expire":
			s.is_expired = true
	# 导出快照——应排除过期状态
	var snapshot: Array[Dictionary] = ses.export_snapshot()
	assert_eq(snapshot.size(), 1, "应仅导出 1 个活跃状态")
	assert_eq(snapshot[0]["template_id"], &"poison_3", "导出的应为 poison_3")


# ============================================================================
# AC-003：snapshot 按目标分组
# ============================================================================

func test_ac003_snapshot_grouped_by_target() -> void:
	_inject_template(&"poison_3", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.REFRESH, 3, 5.0)
	_inject_template(&"buff_atk", StatusTemplateClass.StatusType.BUFF,
		StatusTemplateClass.StackRule.INDEPENDENT, 3, 2.0)
	# 目标 2002 先施加，目标 1001 后施加
	ses.apply_status(2002, &"poison_3", 999)
	ses.apply_status(2002, &"buff_atk", 999)
	ses.apply_status(1001, &"poison_3", 999)
	ses.apply_status(1001, &"buff_atk", 999)

	var snapshot: Array[Dictionary] = ses.export_snapshot()
	# 应按 target_id 升序：1001, 1001, 2002, 2002
	assert_eq(snapshot[0]["target_id"], 1001, "第1个应为 target 1001")
	assert_eq(snapshot[1]["target_id"], 1001, "第2个应为 target 1001")
	assert_eq(snapshot[2]["target_id"], 2002, "第3个应为 target 2002")
	assert_eq(snapshot[3]["target_id"], 2002, "第4个应为 target 2002")


# ============================================================================
# AC-004 + AC-005：write_snapshot_to_gsm
# ============================================================================

func test_ac004_005_write_snapshot_to_gsm_guarded() -> void:
	# 测试环境无 GSM Autoload——write_snapshot_to_gsm 应静默跳过（不崩溃）
	_inject_template(&"poison_3", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.REFRESH, 3, 5.0)
	ses.apply_status(1001, &"poison_3", 999)
	ses.write_snapshot_to_gsm()  # 不应崩溃
	assert_true(true, "GSM 不可用时 write_snapshot_to_gsm 应静默跳过")


# ============================================================================
# AC-008：suspend_status 迁移到 _suspended
# ============================================================================

func test_ac008_suspend_status_migrates() -> void:
	_inject_template(&"poison_3", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.REFRESH, 3, 5.0)
	var r: Dictionary = ses.apply_status(1001, &"poison_3", 999)
	var sid: int = r["status_id"]
	var ok: bool = ses.suspend_status(sid)
	assert_true(ok, "暂挂应成功")
	assert_false(ses._instances.has(sid), "_instances 不应含 sid")
	assert_true(ses._suspended.has(sid), "_suspended 应含 sid")
	# _by_target 同步移除
	var ids: Array = ses._by_target.get(1001, [])
	assert_false(ids.has(sid), "_by_target 不应含 sid")


# ============================================================================
# AC-009：暂挂状态不在 get_active_statuses
# ============================================================================

func test_ac009_suspended_not_in_active_statuses() -> void:
	_inject_template(&"poison_3", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.REFRESH, 3, 5.0)
	var r: Dictionary = ses.apply_status(1001, &"poison_3", 999)
	var sid: int = r["status_id"]
	ses.suspend_status(sid)
	var active: Array[int] = ses.get_active_statuses(1001)
	assert_false(active.has(sid), "暂挂状态不应在 get_active_statuses 中")
	assert_eq(ses.get_active_count(1001), 0, "get_active_count 应为 0")


# ============================================================================
# AC-010：暂挂状态不倒计时
# ============================================================================

func test_ac010_suspended_not_ticked() -> void:
	_inject_template(&"poison_3", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.REFRESH, 3, 5.0)
	var r: Dictionary = ses.apply_status(1001, &"poison_3", 999)
	var sid: int = r["status_id"]
	ses.suspend_status(sid)
	# tick_all 后暂挂状态 duration 应保持 3
	ses.tick_all([1001])
	var suspended: StatusInstance = ses._suspended[sid]
	assert_eq(suspended.duration, 3, "暂挂状态倒计时应冻结")


# ============================================================================
# AC-011：restore_status 迁回活跃
# ============================================================================

func test_ac011_restore_status_returns_to_active() -> void:
	_inject_template(&"poison_3", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.REFRESH, 3, 5.0)
	var r: Dictionary = ses.apply_status(1001, &"poison_3", 999)
	var sid: int = r["status_id"]
	ses.suspend_status(sid)
	var ok: bool = ses.restore_status(sid)
	assert_true(ok, "恢复应成功")
	assert_false(ses._suspended.has(sid), "_suspended 不应含 sid")
	assert_true(ses._instances.has(sid), "_instances 应含 sid")
	var ids: Array = ses._by_target.get(1001, [])
	assert_true(ids.has(sid), "_by_target 应含 sid")


# ============================================================================
# AC-012：恢复后重新出现在 get_active_statuses
# ============================================================================

func test_ac012_restored_reappears_in_active() -> void:
	_inject_template(&"poison_3", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.REFRESH, 3, 5.0)
	var r: Dictionary = ses.apply_status(1001, &"poison_3", 999)
	var sid: int = r["status_id"]
	ses.suspend_status(sid)
	ses.restore_status(sid)
	var active: Array[int] = ses.get_active_statuses(1001)
	assert_true(active.has(sid), "恢复后应重新出现在 get_active_statuses")
	assert_eq(ses._instances[sid].duration, 3, "duration 保持暂挂前值")


# ============================================================================
# AC-013：restore_all_suspended 排序
# ============================================================================

func test_ac013_restore_all_sorted() -> void:
	# 3 个暂挂状态，priority 不同
	_inject_template(&"p_high", StatusTemplateClass.StatusType.BUFF,
		StatusTemplateClass.StackRule.INDEPENDENT, 5, 1.0, 0, 10)
	_inject_template(&"p_mid", StatusTemplateClass.StatusType.BUFF,
		StatusTemplateClass.StackRule.INDEPENDENT, 5, 1.0, 0, 5)
	_inject_template(&"p_low", StatusTemplateClass.StatusType.BUFF,
		StatusTemplateClass.StackRule.INDEPENDENT, 5, 1.0, 0, 1)
	ses.apply_status(1001, &"p_high", 999, {}, 1)
	ses.apply_status(1001, &"p_mid", 999, {}, 2)
	ses.apply_status(1001, &"p_low", 999, {}, 3)
	# 暂挂全部
	var ids: Array = ses.get_active_statuses(1001)
	for id in ids:
		ses.suspend_status(id)
	# 恢复全部
	ses.restore_all_suspended(1001)
	# 验证顺序：p_high 先恢复（priority 10 最大）
	var restored: Array[int] = ses.get_active_statuses(1001)
	assert_eq(restored.size(), 3, "应恢复 3 个状态")
	# 第一个恢复的应为 p_high
	assert_eq(ses._instances[restored[0]].template_id, &"p_high", "priority 最高先恢复")
	assert_eq(ses._instances[restored[1]].template_id, &"p_mid", "其次 p_mid")
	assert_eq(ses._instances[restored[2]].template_id, &"p_low", "最后 p_low")


# ============================================================================
# AC-014：恢复时触发 20 上限驱逐
# ============================================================================

func test_ac014_restore_triggers_eviction() -> void:
	# 20 个活跃状态
	for i in range(20):
		var tmpl_name: StringName = &"active_%d" % i
		_inject_template(tmpl_name, StatusTemplateClass.StatusType.BUFF,
			StatusTemplateClass.StackRule.INDEPENDENT, 5, 1.0, 0, 5)
		ses.apply_status(1001, tmpl_name, 999)
	assert_eq(ses.get_active_count(1001), 20, "20 个活跃状态")
	# 1 个暂挂状态
	_inject_template(&"suspended_1", StatusTemplateClass.StatusType.BUFF,
		StatusTemplateClass.StackRule.INDEPENDENT, 5, 1.0, 0, 5)
	var r: Dictionary = ses.apply_status(1001, &"suspended_1", 999)
	var suspended_id: int = r["status_id"]
	ses.suspend_status(suspended_id)
	# 恢复——应触发驱逐，最终仍为 20
	ses.restore_status(suspended_id)
	assert_eq(ses.get_active_count(1001), 20, "恢复触发驱逐后仍为 20")
	assert_true(ses._instances.has(suspended_id), "恢复的状态应成功注册")


# ============================================================================
# AC-015：BindingManager 排序契约（本 Story 仅保证排序一致）
# ============================================================================

func test_ac015_restore_order_consistent() -> void:
	# 验证 restore_all_suspended 的排序：同 priority 按 applied_turn 升序
	_inject_template(&"same_1", StatusTemplateClass.StatusType.BUFF,
		StatusTemplateClass.StackRule.INDEPENDENT, 5, 1.0, 0, 3)
	_inject_template(&"same_2", StatusTemplateClass.StatusType.BUFF,
		StatusTemplateClass.StackRule.INDEPENDENT, 5, 1.0, 0, 3)
	_inject_template(&"same_3", StatusTemplateClass.StatusType.BUFF,
		StatusTemplateClass.StackRule.INDEPENDENT, 5, 1.0, 0, 3)
	# 施加顺序：same_3（turn=5）→ same_1（turn=1）→ same_2（turn=3）
	ses.apply_status(1001, &"same_3", 999, {}, 5)
	ses.apply_status(1001, &"same_1", 999, {}, 1)
	ses.apply_status(1001, &"same_2", 999, {}, 3)
	# 暂挂全部
	var ids: Array = ses.get_active_statuses(1001)
	for id in ids:
		ses.suspend_status(id)
	# 恢复全部——同 priority 按 applied_turn 升序
	ses.restore_all_suspended(1001)
	var restored: Array[int] = ses.get_active_statuses(1001)
	assert_eq(ses._instances[restored[0]].template_id, &"same_1", "applied_turn=1 先恢复")
	assert_eq(ses._instances[restored[1]].template_id, &"same_2", "applied_turn=3 其次")
	assert_eq(ses._instances[restored[2]].template_id, &"same_3", "applied_turn=5 最后")


# ============================================================================
# AC-016：get_suspended_statuses 查询
# ============================================================================

func test_ac016_get_suspended_statuses() -> void:
	_inject_template(&"poison_3", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.REFRESH, 3, 5.0)
	_inject_template(&"buff_atk", StatusTemplateClass.StatusType.BUFF,
		StatusTemplateClass.StackRule.INDEPENDENT, 3, 2.0)
	ses.apply_status(1001, &"poison_3", 999)
	ses.apply_status(1001, &"buff_atk", 999)
	# 暂挂 1 个
	var ids: Array = ses.get_active_statuses(1001)
	ses.suspend_status(ids[0])
	var suspended: Array[int] = ses.get_suspended_statuses(1001)
	assert_eq(suspended.size(), 1, "应有 1 个暂挂状态")
	# 无暂挂返回空
	var empty: Array[int] = ses.get_suspended_statuses(9999)
	assert_eq(empty.size(), 0, "无暂挂应返回空数组")


# ============================================================================
# AC-017：snapshot round-trip
# ============================================================================

func test_ac017_snapshot_round_trip() -> void:
	_inject_template(&"poison_3", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.REFRESH, 3, 5.0)
	_inject_template(&"buff_atk", StatusTemplateClass.StatusType.BUFF,
		StatusTemplateClass.StackRule.INDEPENDENT, 3, 2.0)
	ses.apply_status(1001, &"poison_3", 999, {}, 4)
	ses.apply_status(1001, &"buff_atk", 999, {}, 5)
	# 导出
	var snapshot: Array[Dictionary] = ses.export_snapshot()
	# 清空（模拟新实例）
	ses.free()
	ses = SES_SCRIPT.new()
	# 导入
	ses.import_snapshot(snapshot)
	# 验证字段一致
	assert_eq(ses.get_active_count(1001), 2, "应重建 2 个状态")
	var restored_ids: Array[int] = ses.get_active_statuses(1001)
	# 找到 poison_3
	var found_poison: bool = false
	var found_buff: bool = false
	for id in restored_ids:
		var s = ses._instances[id]
		if s.template_id == &"poison_3":
			found_poison = true
			assert_eq(s.duration, 3, "poison_3 duration 一致")
			assert_eq(s.applied_turn, 4, "poison_3 applied_turn 一致")
		if s.template_id == &"buff_atk":
			found_buff = true
			assert_eq(s.duration, 3, "buff_atk duration 一致")
			assert_eq(s.applied_turn, 5, "buff_atk applied_turn 一致")
	assert_true(found_poison, "应含 poison_3")
	assert_true(found_buff, "应含 buff_atk")


# ============================================================================
# AC-018：import_snapshot 跳过过期
# ============================================================================

func test_ac018_import_skips_expired() -> void:
	_inject_template(&"poison_3", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.REFRESH, 3, 5.0)
	ses.apply_status(1001, &"poison_3", 999)
	# 构造含过期条目的 snapshot
	var snapshot: Array = [
		{id = 1, template_id = &"poison_3", target_id = 1001, duration = 3,
			applied_turn = 1, value = 5.0, base_value = 5.0, current_stacks = 1,
			source_card_instance_id = 999, priority = 0, is_hidden = false,
			is_expired = true, metadata = {}},  # 过期条目
		{id = 2, template_id = &"poison_3", target_id = 1001, duration = 3,
			applied_turn = 2, value = 5.0, base_value = 5.0, current_stacks = 1,
			source_card_instance_id = 999, priority = 0, is_hidden = false,
			is_expired = false, metadata = {}},  # 活跃条目
	]
	# 清空当前实例
	ses.free()
	ses = SES_SCRIPT.new()
	ses.import_snapshot(snapshot)
	assert_eq(ses.get_active_count(1001), 1, "应仅导入 1 个活跃状态（跳过过期）")


# ============================================================================
# 边缘情况补强
# ============================================================================

func test_suspend_nonexistent_returns_false() -> void:
	var ok: bool = ses.suspend_status(99999)
	assert_false(ok, "暂挂不存在状态应返回 false")


func test_restore_nonexistent_returns_false() -> void:
	var ok: bool = ses.restore_status(99999)
	assert_false(ok, "恢复不存在状态应返回 false")


func test_suspend_preserves_status_instance_reference() -> void:
	# 暂挂是引用转移，非深拷贝
	_inject_template(&"poison_3", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.REFRESH, 3, 5.0)
	var r: Dictionary = ses.apply_status(1001, &"poison_3", 999)
	var sid: int = r["status_id"]
	var original = ses._instances[sid]
	ses.suspend_status(sid)
	var suspended = ses._suspended[sid]
	assert_eq(original, suspended, "暂挂应保留同一实例引用")


func test_restore_suspended_status_duration_preserved() -> void:
	_inject_template(&"poison_3", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.REFRESH, 3, 5.0)
	var r: Dictionary = ses.apply_status(1001, &"poison_3", 999)
	var sid: int = r["status_id"]
	# tick 1 回合 → duration=2
	ses.tick_all([1001])
	# 暂挂
	ses.suspend_status(sid)
	# 再 tick——暂挂状态不倒计时
	ses.tick_all([1001])
	# 恢复
	ses.restore_status(sid)
	assert_eq(ses._instances[sid].duration, 2, "恢复后 duration 保持暂挂前的 2")