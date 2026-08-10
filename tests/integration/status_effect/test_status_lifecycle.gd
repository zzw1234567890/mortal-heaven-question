extends GutTest
## Story 001 验收测试：StatusEffectSystem 状态效果生命周期。
##
## 覆盖 AC-001 到 AC-018（18 条 AC）。
##
## 测试策略：
##   - SES_SCRIPT.new() 构造 StatusEffectSystem 实例（不调 _ready()，不加载模板目录）
##   - 手动注入 StatusTemplate 到 ses._templates
##   - var result: Type = ses.method() 显式类型注解（动态分派）
##   - before_each/after_each 清理实例状态
##   - 信号监听用 Array 容器收集载荷（GDScript lambda 捕获局部变量为值语义）
##
## [b]类型注解说明[/b]：GUT headless 模式下 class_name 跨文件解析不稳定，
## 本文件使用 preload 常量（StatusTemplateClass/StatusInstanceClass）的 .new() 创建实例，
## 但不直接使用 StatusTemplate/StatusInstance 作为类型注解（可能触发解析错误）。
## 需要类型注解处使用 preload 的 GDScript 常量或移除类型注解。

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

## 注入测试用状态模板。
func _inject_template(
	tmpl_id: StringName, type: int, stack_rule: int,
	base_duration: int, base_value: float, max_stacks: int = 0
):
	var tmpl = StatusTemplateClass.new()
	tmpl.template_id = tmpl_id
	tmpl.type = type
	tmpl.stack_rule = stack_rule
	tmpl.max_stacks = max_stacks
	tmpl.base_duration = base_duration
	tmpl.base_value = base_value
	ses._templates[tmpl_id] = tmpl
	return tmpl


# ============================================================================
# AC-001：extends Node + 不声明 class_name
# ============================================================================

func test_ac001_extends_node_no_class_name() -> void:
	assert_eq(SES_SCRIPT.get_instance_base_type(), "Node",
		"StatusEffectSystem 应 extends Node")
	assert_eq(SES_SCRIPT.get_global_name(), &"",
		"StatusEffectSystem 不应声明 class_name")
	# 动态分派实例化验证
	var instance: Node = SES_SCRIPT.new()
	assert_not_null(instance, "SES_SCRIPT.new() 应返回非 null 实例")
	instance.free()


# ============================================================================
# AC-002：StatusTemplate @export 字段完整
# ============================================================================

func test_ac002_status_template_export_fields() -> void:
	var tmpl = StatusTemplateClass.new()
	# 10 个 @export 字段
	assert_true("template_id" in tmpl, "应有 template_id 字段")
	assert_true("type" in tmpl, "应有 type 字段")
	assert_true("stack_rule" in tmpl, "应有 stack_rule 字段")
	assert_true("max_stacks" in tmpl, "应有 max_stacks 字段")
	assert_true("base_duration" in tmpl, "应有 base_duration 字段")
	assert_true("base_value" in tmpl, "应有 base_value 字段")
	assert_true("icon_path" in tmpl, "应有 icon_path 字段")
	assert_true("description_tmpl" in tmpl, "应有 description_tmpl 字段")
	assert_true("default_priority" in tmpl, "应有 default_priority 字段")
	assert_true("metadata" in tmpl, "应有 metadata 字段")
	# 枚举类型验证——StatusTemplateClass.StatusType 通过 preload 常量访问
	assert_eq(tmpl.type, StatusTemplateClass.StatusType.DEBUFF, "type 默认应为 DEBUFF")
	assert_eq(tmpl.stack_rule, StatusTemplateClass.StackRule.REFRESH, "stack_rule 默认应为 REFRESH")


# ============================================================================
# AC-003：StatusInstance 运行时字段完整
# ============================================================================

func test_ac003_status_instance_fields() -> void:
	var inst = StatusInstanceClass.new()
	# 13 个字段
	assert_true("id" in inst, "应有 id 字段")
	assert_true("template_id" in inst, "应有 template_id 字段")
	assert_true("target_id" in inst, "应有 target_id 字段")
	assert_true("duration" in inst, "应有 duration 字段")
	assert_true("applied_turn" in inst, "应有 applied_turn 字段")
	assert_true("value" in inst, "应有 value 字段")
	assert_true("base_value" in inst, "应有 base_value 字段")
	assert_true("current_stacks" in inst, "应有 current_stacks 字段")
	assert_true("source_card_instance_id" in inst, "应有 source_card_instance_id 字段")
	assert_true("priority" in inst, "应有 priority 字段")
	assert_true("is_hidden" in inst, "应有 is_hidden 字段")
	assert_true("is_expired" in inst, "应有 is_expired 字段")
	assert_true("metadata" in inst, "应有 metadata 字段")
	# 默认值
	assert_eq(inst.id, 0, "id 默认 0")
	assert_eq(inst.current_stacks, 1, "current_stacks 默认 1")
	assert_false(inst.is_expired, "is_expired 默认 false")


# ============================================================================
# AC-004：内部注册表初始化
# ============================================================================

func test_ac004_internal_registries_initialized() -> void:
	assert_eq(ses._instances.size(), 0, "_instances 应为空 Dictionary")
	assert_eq(ses._by_target.size(), 0, "_by_target 应为空 Dictionary")
	assert_eq(ses._next_status_id, 1, "_next_status_id 初始应为 1")


# ============================================================================
# AC-005：apply_status 返回 ApplyResult
# ============================================================================

func test_ac005_apply_status_returns_apply_result() -> void:
	_inject_template(&"poison_3", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.REFRESH, 3, 5.0)
	var result: Dictionary = ses.apply_status(1001, &"poison_3", 999)
	assert_true(result.has("applied"), "结果应含 applied")
	assert_true(result.has("status_id"), "结果应含 status_id")
	assert_true(result.has("reason"), "结果应含 reason")
	assert_eq(typeof(result["applied"]), TYPE_BOOL, "applied 应为 bool")
	assert_eq(typeof(result["status_id"]), TYPE_INT, "status_id 应为 int")
	assert_eq(typeof(result["reason"]), TYPE_STRING, "reason 应为 String")


# ============================================================================
# AC-006：新状态施加（NEW 路径）
# ============================================================================

func test_ac006_new_status_applied() -> void:
	_inject_template(&"poison_3", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.REFRESH, 3, 5.0)
	var result: Dictionary = ses.apply_status(1001, &"poison_3", 999)
	assert_true(result["applied"], "施加应成功")
	assert_eq(result["reason"], "new", "reason 应为 new")
	var status_id: int = result["status_id"]
	var status = ses._instances[status_id]
	assert_eq(status.current_stacks, 1, "current_stacks 应为 1")
	assert_eq(status.duration, 3, "duration 应为 3")
	assert_eq(status.value, 5.0, "value 应为模板 base_value")
	assert_eq(status.target_id, 1001, "target_id 应为 1001")


# ============================================================================
# AC-007：get_active_statuses 返回 status_id 列表
# ============================================================================

func test_ac007_get_active_statuses_returns_ids() -> void:
	_inject_template(&"poison_3", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.REFRESH, 3, 5.0)
	_inject_template(&"freeze_1", StatusTemplateClass.StatusType.SPECIAL,
		StatusTemplateClass.StackRule.INDEPENDENT, 1, 0.0)
	_inject_template(&"atk_up", StatusTemplateClass.StatusType.BUFF,
		StatusTemplateClass.StackRule.CUMULATIVE, 2, 2.0)
	ses.apply_status(1001, &"poison_3", 999)
	ses.apply_status(1001, &"freeze_1", 999)
	ses.apply_status(1001, &"atk_up", 999)
	var ids: Array[int] = ses.get_active_statuses(1001)
	assert_eq(ids.size(), 3, "应有 3 个活跃状态")
	# 无状态返回空数组
	var empty_ids: Array[int] = ses.get_active_statuses(9999)
	assert_eq(empty_ids.size(), 0, "无状态应返回空数组")


# ============================================================================
# AC-008：has_status 查询
# ============================================================================

func test_ac008_has_status() -> void:
	_inject_template(&"poison_3", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.REFRESH, 3, 5.0)
	ses.apply_status(1001, &"poison_3", 999)
	assert_true(ses.has_status(1001, &"poison_3"), "应有 poison_3 状态")
	assert_false(ses.has_status(1001, &"freeze_1"), "不应有 freeze_1 状态")


# ============================================================================
# AC-009：remove_status
# ============================================================================

func test_ac009_remove_status() -> void:
	_inject_template(&"poison_3", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.REFRESH, 3, 5.0)
	var result: Dictionary = ses.apply_status(1001, &"poison_3", 999)
	var status_id: int = result["status_id"]
	# 移除存在的状态
	var ok: bool = ses.remove_status(status_id)
	assert_true(ok, "移除存在的状态应返回 true")
	assert_false(ses._instances.has(status_id), "移除后 _instances 不应再含该 id")
	var ids: Array[int] = ses.get_active_statuses(1001)
	assert_eq(ids.size(), 0, "移除后 get_active_statuses 应为空")
	# 移除不存在的状态
	var ok2: bool = ses.remove_status(99999)
	assert_false(ok2, "移除不存在的状态应返回 false")


# ============================================================================
# AC-010：tick_all 倒计时
# ============================================================================

func test_ac010_tick_all_decrements_duration() -> void:
	_inject_template(&"poison_3", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.REFRESH, 3, 5.0)
	var result: Dictionary = ses.apply_status(1001, &"poison_3", 999)
	var status_id: int = result["status_id"]
	# 1 次 tick：duration 3→2
	ses.tick_all([1001])
	var status = ses._instances[status_id]
	assert_eq(status.duration, 2, "tick 后 duration 应为 2")
	# 再 tick 2 次：duration→0，被移除
	ses.tick_all([1001])
	ses.tick_all([1001])
	assert_false(ses._instances.has(status_id), "duration 归零后应被移除")


# ============================================================================
# AC-011：永久状态不倒计时
# ============================================================================

func test_ac011_permanent_status_not_decremented() -> void:
	_inject_template(&"perm_buff", StatusTemplateClass.StatusType.BUFF,
		StatusTemplateClass.StackRule.REFRESH, -1, 10.0)
	var result: Dictionary = ses.apply_status(1001, &"perm_buff", 999)
	var status_id: int = result["status_id"]
	ses.tick_all([1001])
	var status = ses._instances[status_id]
	assert_eq(status.duration, -1, "永久状态 duration 应保持 -1")
	assert_false(status.is_expired, "永久状态不应过期")
	# 仍在活跃列表中
	var ids: Array[int] = ses.get_active_statuses(1001)
	assert_eq(ids.size(), 1, "永久状态应仍在活跃列表中")


# ============================================================================
# AC-012：同回合施加不立即倒计时
# ============================================================================

func test_ac012_same_turn_no_decrement() -> void:
	_inject_template(&"poison_3", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.REFRESH, 3, 5.0)
	# 在 turn=5 施加状态
	var result: Dictionary = ses.apply_status(1001, &"poison_3", 999, {}, 5)
	var status_id: int = result["status_id"]
	# 同回合 tick（current_turn=5）——不应倒计时
	ses.tick_all([1001], 5)
	var status = ses._instances[status_id]
	assert_eq(status.duration, 3, "同回合施加不应倒计时")
	# 下一回合 tick（current_turn=6）——应倒计时
	ses.tick_all([1001], 6)
	status = ses._instances[status_id]
	assert_eq(status.duration, 2, "下一回合应倒计时为 2")


# ============================================================================
# AC-013：倒计时不发射 status_updated
# ============================================================================

func test_ac013_tick_no_status_updated_signal() -> void:
	_inject_template(&"poison_3", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.REFRESH, 3, 5.0)
	ses.apply_status(1001, &"poison_3", 999)
	# 用 Array 容器收集信号（lambda 捕获局部变量为值语义）
	var updated_emitted: Array = []
	ses.status_updated.connect(func(_t, _s, _c): updated_emitted.append(true))
	ses.tick_all([1001])
	assert_eq(updated_emitted.size(), 0, "倒计时应不发射 status_updated")


# ============================================================================
# AC-014：过期状态延迟移除
# ============================================================================

func test_ac014_expired_status_removed_after_tick() -> void:
	_inject_template(&"poison_1", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.REFRESH, 1, 5.0)
	var result: Dictionary = ses.apply_status(1001, &"poison_1", 999)
	var status_id: int = result["status_id"]
	# 监听 status_removed
	var removed_payload: Array = []
	ses.status_removed.connect(func(t, s, tid, r): removed_payload.append([t, s, tid, r]))
	# tick 后 duration→0，is_expired=true，然后被移除
	ses.tick_all([1001])
	assert_false(ses._instances.has(status_id), "过期状态应被移除")
	assert_eq(removed_payload.size(), 1, "应发射 1 次 status_removed")
	assert_eq(removed_payload[0][3], "expired", "reason 应为 expired")


# ============================================================================
# AC-015：4 个 Cat 2b 信号声明
# ============================================================================

func test_ac015_four_signals_declared() -> void:
	var script_signals: Array = SES_SCRIPT.get_script_signal_list()
	var signal_names: Array[String] = []
	for sig in script_signals:
		signal_names.append(sig.name)
	assert_true(signal_names.has("status_applied"), "应声明 status_applied")
	assert_true(signal_names.has("status_removed"), "应声明 status_removed")
	assert_true(signal_names.has("status_updated"), "应声明 status_updated")
	assert_true(signal_names.has("status_immunity_blocked"), "应声明 status_immunity_blocked")


# ============================================================================
# AC-016：apply_status 成功发射 status_applied
# ============================================================================

func test_ac016_apply_status_emits_signal() -> void:
	_inject_template(&"poison_3", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.REFRESH, 3, 5.0)
	var payload: Array = []
	ses.status_applied.connect(func(t, s, tid, stk, r): payload.append([t, s, tid, stk, r]))
	ses.apply_status(1001, &"poison_3", 999)
	assert_eq(payload.size(), 1, "应发射 1 次 status_applied")
	assert_eq(payload[0][0], 1001, "target_id 应为 1001")
	assert_eq(payload[0][3], 1, "stacks 应为 1")
	assert_eq(payload[0][4], "new", "reason 应为 new")


# ============================================================================
# AC-017：remove_status 发射 status_removed
# ============================================================================

func test_ac017_remove_status_emits_signal() -> void:
	_inject_template(&"poison_3", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.REFRESH, 3, 5.0)
	var result: Dictionary = ses.apply_status(1001, &"poison_3", 999)
	var status_id: int = result["status_id"]
	var payload: Array = []
	ses.status_removed.connect(func(t, s, tid, r): payload.append([t, s, tid, r]))
	ses.remove_status(status_id)
	assert_eq(payload.size(), 1, "应发射 1 次 status_removed")
	assert_eq(payload[0][0], 1001, "target_id 应为 1001")
	assert_eq(payload[0][1], status_id, "status_id 应匹配")
	assert_eq(payload[0][3], "manual", "reason 应为 manual")


# ============================================================================
# AC-018：get_status_template 只读访问器
# ============================================================================

func test_ac018_get_status_template() -> void:
	var tmpl = _inject_template(&"poison_3", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.REFRESH, 3, 5.0)
	var got = ses.get_status_template(&"poison_3")
	assert_not_null(got, "已注入的模板应能查询到")
	assert_eq(got, tmpl, "应返回同一对象引用")
	var unknown = ses.get_status_template(&"nonexistent")
	assert_null(unknown, "未知 template_id 应返回 null")


# ============================================================================
# 边缘情况补强
# ============================================================================

func test_apply_status_unknown_template() -> void:
	var result: Dictionary = ses.apply_status(1001, &"unknown", 999)
	assert_false(result["applied"], "未知模板应 applied=false")
	assert_eq(result["reason"], "unknown_template", "reason 应为 unknown_template")


func test_status_id_globally_unique() -> void:
	_inject_template(&"poison_3", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.REFRESH, 3, 5.0)
	var r1: Dictionary = ses.apply_status(1001, &"poison_3", 999)
	var r2: Dictionary = ses.apply_status(1002, &"poison_3", 999)
	var id1: int = r1["status_id"]
	var id2: int = r2["status_id"]
	assert_ne(id1, id2, "不同实例的 status_id 应不同")
	assert_eq(id2, id1 + 1, "status_id 应单调递增")


func test_overrides_value_applied() -> void:
	_inject_template(&"poison_3", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.REFRESH, 3, 5.0)
	var result: Dictionary = ses.apply_status(1001, &"poison_3", 999, {value = 99.0})
	var status_id: int = result["status_id"]
	var status = ses._instances[status_id]
	assert_eq(status.value, 99.0, "overrides.value 应覆盖模板 base_value")
	assert_eq(status.base_value, 5.0, "base_value 仍为模板值")


func test_tick_all_empty_field_no_error() -> void:
	# 空场上 tick 不报错
	ses.tick_all([])
	ses.tick_all([1001])  # 无状态的角色也不报错
	assert_true(true, "空场 tick 应无错误")


func test_metadata_deep_copied() -> void:
	var tmpl = _inject_template(&"poison_3", StatusTemplateClass.StatusType.DEBUFF,
		StatusTemplateClass.StackRule.REFRESH, 3, 5.0)
	tmpl.metadata = {"damage_type": "fire"}
	var result: Dictionary = ses.apply_status(1001, &"poison_3", 999)
	var status_id: int = result["status_id"]
	var status = ses._instances[status_id]
	# 修改实例 metadata 不影响模板
	status.metadata["damage_type"] = "ice"
	assert_eq(tmpl.metadata["damage_type"], "fire", "模板 metadata 不应被实例修改影响")