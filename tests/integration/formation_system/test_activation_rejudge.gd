extends GutTest
## Story 002 验收测试：激活条件实时重判（订阅 deployment 信号）。
##
## 覆盖 AC-001 到 AC-005（5 条 AC）。
## 测试策略：
##   - FormationSystem 用动态分派 FS_SCRIPT.new() + var fs: Node 持有
##   - before_each 重置 + 注入 condition_check_cb 存根（可动态切换条件满足/不满足）
##   - 直接调用 recheck_all_conditions() 验证返回值
##   - 直接调用 _on_field_changed() 模拟 DeploymentSystem 信号触发
##   - mock effect register/remove 验证副作用
##
## 设计文档来源：ADR-0024 §关键接口 §阵法条件判定管线 §风险（信号重入）
## Story 来源：production/epics/formation-system/story-002-activation-rejudge.md

const FS_SCRIPT := preload("res://src/feature/formation_system.gd")

const REQ_3_ZHENGDAO: Dictionary = {"tag_id": &"zhengdao", "min_count": 3}
const REQ_CHAR_200: Dictionary = {"character_id": 200}

var fs: Node = null
var _effect_log: Array = []
var _signal_log: Array = []
var _signal_callables: Array = []
var _activated_reasons: Array = []
var _deactivated_reasons: Array = []
var _reevaluated_changes: Array = []
var _condition_result: bool = true


func before_each() -> void:
	fs = FS_SCRIPT.new()
	_effect_log.clear()
	_signal_log.clear()
	_signal_callables.clear()
	_activated_reasons.clear()
	_deactivated_reasons.clear()
	_reevaluated_changes.clear()
	_condition_result = true
	_wire_callbacks()


func after_each() -> void:
	if fs != null:
		for callable: Callable in _signal_callables:
			for sig in [&"formation_deployed", &"formation_activated", &"formation_deactivated",
						&"formation_overwritten", &"character_affiliated",
						&"formation_condition_reevaluated"]:
				if fs.is_connected(sig, callable):
					fs.disconnect(sig, callable)
		_signal_callables.clear()
		fs.free()
		fs = null
	_effect_log.clear()


func _wire_callbacks() -> void:
	fs.set("condition_check_cb", Callable(self, "_on_check_condition"))
	fs.set("effect_register_cb", Callable(self, "_on_effect_register"))
	fs.set("effect_remove_cb", Callable(self, "_on_effect_remove"))
	fs.set("card_discard_cb", Callable(self, "_on_card_discard"))
	_connect_signals()


func _connect_signals() -> void:
	var sigs: Array = [{"name": &"formation_deployed", "callable": Callable(self, "_on_formation_deployed")},
		{"name": &"formation_activated", "callable": Callable(self, "_on_formation_activated")},
		{"name": &"formation_deactivated", "callable": Callable(self, "_on_formation_deactivated")},
		{"name": &"formation_overwritten", "callable": Callable(self, "_on_formation_overwritten")},
		{"name": &"character_affiliated", "callable": Callable(self, "_on_character_affiliated")},
		{"name": &"formation_condition_reevaluated", "callable": Callable(self, "_on_condition_reevaluated")}]
	for entry in sigs:
		fs.connect(entry["name"], entry["callable"])
		_signal_callables.append(entry["callable"])


func _on_formation_deployed(_f: int, _s: int, _t: StringName, _d: int) -> void:
	_signal_log.append("formation_deployed")


func _on_formation_activated(_f: int, _s: int, _t: StringName, r: String) -> void:
	_signal_log.append("formation_activated")
	_activated_reasons.append(r)


func _on_formation_deactivated(_f: int, _s: int, r: String) -> void:
	_signal_log.append("formation_deactivated")
	_deactivated_reasons.append(r)


func _on_formation_overwritten(_o: int, _n: int, _s: int) -> void:
	_signal_log.append("formation_overwritten")


func _on_character_affiliated(_c: int, _f: int) -> void:
	_signal_log.append("character_affiliated")


func _on_condition_reevaluated(changes: Array) -> void:
	_signal_log.append("formation_condition_reevaluated")
	_reevaluated_changes = changes


func _on_check_condition(_requirement: Dictionary) -> bool:
	return _condition_result


func _on_effect_register(card_instance_id: int, _template_id: StringName, _scope_context: Dictionary) -> void:
	_effect_log.append("register:%d" % card_instance_id)


func _on_effect_remove(card_instance_id: int) -> void:
	_effect_log.append("remove:%d" % card_instance_id)


func _on_card_discard(card_instance_id: int) -> void:
	_effect_log.append("discard:%d" % card_instance_id)


func _set_condition(result: bool) -> void:
	_condition_result = result


# ============================================================================
# AC-001：角色上场补足条件 → 阵法激活
# ============================================================================

func test_recheck_unactive_to_active() -> void:
	_set_condition(false)
	fs.call("deploy_formation", 100, &"f1", 0, REQ_3_ZHENGDAO)
	assert_eq(fs.call("get_slot_states")[0]["state"], FS_SCRIPT.SlotState.DEPLOYED_UNACTIVE, "初始 UNACTIVE")
	# 条件变为满足
	_set_condition(true)
	var changes: Array = fs.call("recheck_all_conditions")
	assert_eq(changes.size(), 1, "返回 1 条变更")
	assert_eq(changes[0]["old_state"], FS_SCRIPT.SlotState.DEPLOYED_UNACTIVE, "old_state = DEPLOYED_UNACTIVE")
	assert_eq(changes[0]["new_state"], FS_SCRIPT.SlotState.ACTIVE, "new_state = ACTIVE")
	assert_eq(changes[0]["reason"], "condition_met", "reason = condition_met")
	assert_eq(fs.call("get_slot_states")[0]["state"], FS_SCRIPT.SlotState.ACTIVE, "阵法已变 ACTIVE")


func test_on_field_changed_activates_and_emits() -> void:
	_set_condition(false)
	fs.call("deploy_formation", 100, &"f1", 0, REQ_3_ZHENGDAO)
	_effect_log.clear()
	_signal_log.clear()
	_activated_reasons.clear()
	_reevaluated_changes.clear()
	_set_condition(true)
	fs.call("_on_field_changed", 201, 0, true)
	assert_true("register:100" in _effect_log, "激活 → effect_register 被调用")
	assert_true("formation_activated" in _signal_log, "发射 formation_activated")
	assert_true("formation_condition_reevaluated" in _signal_log, "批量发射 formation_condition_reevaluated")
	# GAP-002：trigger_reason 断言
	assert_eq(_activated_reasons.size(), 1, "1 个 activated reason")
	assert_eq(_activated_reasons[0], "recheck", "trigger_reason = recheck")
	# GAP-004：changes 载荷验证
	assert_eq(_reevaluated_changes.size(), 1, "changes 载荷含 1 条变更")
	assert_eq(_reevaluated_changes[0]["new_state"], FS_SCRIPT.SlotState.ACTIVE, "载荷 new_state = ACTIVE")


func test_on_field_changed_no_change_no_signal() -> void:
	_set_condition(true)
	fs.call("deploy_formation", 100, &"f1", 0, REQ_3_ZHENGDAO)
	_signal_log.clear()
	fs.call("_on_field_changed", 201, 1, true)
	assert_false("formation_condition_reevaluated" in _signal_log, "无变更 → 不发射 formation_condition_reevaluated")
	assert_false("formation_activated" in _signal_log, "无变更 → 不发射 formation_activated")


# ============================================================================
# AC-002：阵眼角色阵亡 → 阵法失效
# ============================================================================

func test_recheck_active_to_unactive_character_removed() -> void:
	_set_condition(true)
	fs.call("deploy_formation", 100, &"f1", 0, REQ_CHAR_200)
	assert_eq(fs.call("get_slot_states")[0]["state"], FS_SCRIPT.SlotState.ACTIVE, "初始 ACTIVE")
	_set_condition(false)
	var changes: Array = fs.call("recheck_all_conditions")
	assert_eq(changes.size(), 1, "返回 1 条变更")
	assert_eq(changes[0]["old_state"], FS_SCRIPT.SlotState.ACTIVE, "old_state = ACTIVE")
	assert_eq(changes[0]["new_state"], FS_SCRIPT.SlotState.DEPLOYED_UNACTIVE, "new_state = DEPLOYED_UNACTIVE")
	assert_eq(changes[0]["reason"], "condition_lost", "reason = condition_lost")
	assert_eq(fs.call("get_slot_states")[0]["state"], FS_SCRIPT.SlotState.DEPLOYED_UNACTIVE, "阵法已变 UNACTIVE")


func test_on_field_changed_deactivates_and_clears_affiliations() -> void:
	_set_condition(true)
	fs.call("deploy_formation", 100, &"f1", 0, REQ_3_ZHENGDAO)
	fs.call("set_character_affilation", 200, 1)
	_effect_log.clear()
	_signal_log.clear()
	_deactivated_reasons.clear()
	_set_condition(false)
	fs.call("_on_field_changed", 200, 0, "death")
	assert_true("remove:100" in _effect_log, "失效 → effect_remove 被调用")
	assert_true("formation_deactivated" in _signal_log, "发射 formation_deactivated")
	assert_eq(int(fs.call("get_character_affilation", 200)), -1, "阵法失效 → 归属自动清除")
	assert_true("formation_condition_reevaluated" in _signal_log, "批量发射 formation_condition_reevaluated")
	# GAP-002：deactivated reason 断言
	assert_eq(_deactivated_reasons.size(), 1, "1 个 deactivated reason")
	assert_eq(_deactivated_reasons[0], "condition_lost", "reason = condition_lost")


# ============================================================================
# AC-002 edge：阵亡角色不满足条件时不触发失效
# ============================================================================

func test_recheck_no_change_when_condition_still_met() -> void:
	_set_condition(true)
	fs.call("deploy_formation", 100, &"f1", 0, REQ_3_ZHENGDAO)
	var changes: Array = fs.call("recheck_all_conditions")
	assert_eq(changes.size(), 0, "条件仍满足 → 无变更")


# ============================================================================
# AC-003：阵营人数下降 → 阵法失效
# ============================================================================

func test_recheck_count_drop_deactivates() -> void:
	_set_condition(true)
	fs.call("deploy_formation", 100, &"f1", 0, REQ_3_ZHENGDAO)
	fs.call("set_character_affilation", 200, 1)
	fs.call("set_character_affilation", 201, 1)
	_set_condition(false)
	# recheck_all_conditions 只返回变更+更新状态，不处理副作用
	var changes: Array = fs.call("recheck_all_conditions")
	assert_eq(changes.size(), 1, "条件不满足 → 1 条变更")
	assert_eq(changes[0]["new_state"], FS_SCRIPT.SlotState.DEPLOYED_UNACTIVE, "new_state = DEPLOYED_UNACTIVE")
	# 副作用（归属清除）由 _on_field_changed 处理——recheck 本身不清除
	assert_eq(int(fs.call("get_character_affilation", 200)), 1, "recheck 不处理副作用 → 归属仍在")
	# 重新激活再走 _on_field_changed 验证完整副作用
	_set_condition(true)
	fs.call("recheck_all_conditions")  # 状态回到 ACTIVE
	fs.call("set_character_affilation", 200, 1)
	fs.call("set_character_affilation", 201, 1)
	fs.call("set_character_affilation", 202, 1)
	_set_condition(false)
	fs.call("_on_field_changed")
	assert_eq(int(fs.call("get_character_affilation", 200)), -1, "角色 200 归属清除")
	assert_eq(int(fs.call("get_character_affilation", 201)), -1, "角色 201 归属清除")
	assert_eq(int(fs.call("get_character_affilation", 202)), -1, "角色 202 归属清除")
	# lead-programmer C1：affiliated_chars 数组同步清理
	var state: Dictionary = fs.call("get_formation_state", 1)
	assert_eq(int(state["affiliated_count"]), 0, "失效后 affiliated_count=0（数组同步清理）")


# ============================================================================
# AC-003 edge：从 3 降到 2 但门槛为 2 时不应失效
# ============================================================================

func test_recheck_threshold_2_still_met() -> void:
	var req_2: Dictionary = {"tag_id": &"zhengdao", "min_count": 2}
	_set_condition(true)
	fs.call("deploy_formation", 100, &"f1", 0, req_2)
	_set_condition(true)
	var changes: Array = fs.call("recheck_all_conditions")
	assert_eq(changes.size(), 0, "门槛 2 仍满足 → 无变更")


# ============================================================================
# AC-004：阵眼复活重新上场 → 重新激活
# ============================================================================

func test_recheck_revive_reactivates() -> void:
	_set_condition(true)
	fs.call("deploy_formation", 100, &"f1", 0, REQ_CHAR_200)
	# 阵眼阵亡 → 失效
	_set_condition(false)
	fs.call("recheck_all_conditions")
	assert_eq(fs.call("get_slot_states")[0]["state"], FS_SCRIPT.SlotState.DEPLOYED_UNACTIVE, "阵亡后 UNACTIVE")
	# 阵位保留
	assert_ne(fs.call("get_slot_states")[0]["state"], FS_SCRIPT.SlotState.EMPTY, "阵位保留非 EMPTY")
	# 阵眼复活重新上场
	_set_condition(true)
	var changes: Array = fs.call("recheck_all_conditions")
	assert_eq(changes.size(), 1, "复活 → 1 条变更")
	assert_eq(changes[0]["new_state"], FS_SCRIPT.SlotState.ACTIVE, "重新 ACTIVE")
	assert_eq(fs.call("get_slot_states")[0]["state"], FS_SCRIPT.SlotState.ACTIVE, "阵法已重新激活")


func test_on_field_changed_revive_reactivates_and_registers() -> void:
	_set_condition(true)
	fs.call("deploy_formation", 100, &"f1", 0, REQ_CHAR_200)
	_set_condition(false)
	fs.call("_on_field_changed")
	_effect_log.clear()
	_signal_log.clear()
	_set_condition(true)
	fs.call("_on_field_changed", 200, 0, true)
	assert_true("register:100" in _effect_log, "重新激活 → effect_register 被调用")
	assert_true("formation_activated" in _signal_log, "发射 formation_activated")


# ============================================================================
# AC-005：recheck_all_conditions 不直接发射信号
# ============================================================================

func test_recheck_does_not_emit_signals() -> void:
	_set_condition(false)
	fs.call("deploy_formation", 100, &"f1", 0, REQ_3_ZHENGDAO)
	_signal_log.clear()
	_set_condition(true)
	var _changes: Array = fs.call("recheck_all_conditions")
	assert_false("formation_condition_reevaluated" in _signal_log, "recheck 不直接发射 formation_condition_reevaluated")
	assert_false("formation_activated" in _signal_log, "recheck 不直接发射 formation_activated")
	assert_false("formation_deactivated" in _signal_log, "recheck 不直接发射 formation_deactivated")


func test_recheck_empty_changes_no_signal() -> void:
	_set_condition(true)
	fs.call("deploy_formation", 100, &"f1", 0, REQ_3_ZHENGDAO)
	_signal_log.clear()
	fs.call("_on_field_changed")
	assert_false("formation_condition_reevaluated" in _signal_log, "空变更 → 不发射 formation_condition_reevaluated")


# ============================================================================
# 多阵法同时重判
# ============================================================================

func test_recheck_multiple_formations() -> void:
	_set_condition(true)
	fs.call("deploy_formation", 100, &"f1", 0, REQ_3_ZHENGDAO)
	fs.call("deploy_formation", 101, &"f2", 1, REQ_3_ZHENGDAO)
	_set_condition(false)
	var changes: Array = fs.call("recheck_all_conditions")
	assert_eq(changes.size(), 2, "2 个阵法同时失效")
	assert_eq(changes[0]["slot_index"], 0, "变更 1 为 slot 0")
	assert_eq(changes[1]["slot_index"], 1, "变更 2 为 slot 1")


func test_recheck_skips_empty_and_keeps_unactive() -> void:
	_set_condition(true)
	fs.call("deploy_formation", 100, &"f1", 0, REQ_3_ZHENGDAO)
	_set_condition(false)
	fs.call("deploy_formation", 101, &"f2", 1, REQ_3_ZHENGDAO)  # slot 1 UNACTIVE
	# slot 2 EMPTY
	var changes: Array = fs.call("recheck_all_conditions")
	assert_eq(changes.size(), 1, "仅 slot 0 变更（slot 1 保持 UNACTIVE，slot 2 EMPTY 跳过）")


# ============================================================================
# GAP-003：性能断言（ADR-0024 §验证标准 recheck ×1000 <20ms）
# ============================================================================

func test_recheck_performance_under_20ms() -> void:
	_set_condition(true)
	fs.call("deploy_formation", 100, &"f1", 0, REQ_3_ZHENGDAO)
	fs.call("deploy_formation", 101, &"f2", 1, REQ_3_ZHENGDAO)
	fs.call("deploy_formation", 102, &"f3", 2, REQ_3_ZHENGDAO)
	var start: int = Time.get_ticks_usec()
	for _i in range(1000):
		fs.call("recheck_all_conditions")
	var elapsed_ms: float = (Time.get_ticks_usec() - start) / 1000.0
	assert_lt(elapsed_ms, 20.0, "recheck ×1000 应 <20ms，实际 %.2fms" % elapsed_ms)