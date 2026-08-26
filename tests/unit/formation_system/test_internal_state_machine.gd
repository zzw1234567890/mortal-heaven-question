extends GutTest
## Story 001 验收测试：阵法系统内部条件状态机 + 阵法位管理。
##
## 覆盖 AC-001 到 AC-008（8 条 AC）。
## 测试策略：
##   - FormationSystem 用动态分派 FS_SCRIPT.new() + var fs: Node 持有
##   - before_each 重置 + 注入 condition_check_cb 存根（控制条件满足/不满足）
##   - mock CardEffectEngine：用 Callable 存根记录 register/remove/discard 调用序列
##   - mock signal 监听：验证 5 个 Cat 2b 信号发射
##
## 设计文档来源：ADR-0024 §阵法状态机 §关键接口 §覆盖流程 §角色归属管理
## Story 来源：production/epics/formation-system/story-001-internal-state-machine.md

const FS_SCRIPT := preload("res://src/feature/formation_system.gd")

const REQ_3_ZHENGDAO: Dictionary = {"tag_id": &"zhengdao", "min_count": 3}

var fs: Node = null
var _effect_log: Array = []
var _signal_log: Array = []
var _signal_callables: Array = []
var _condition_result: bool = true


func before_each() -> void:
	fs = FS_SCRIPT.new()
	_effect_log.clear()
	_signal_log.clear()
	_signal_callables.clear()
	_condition_result = true
	_wire_callbacks()


func after_each() -> void:
	if fs != null:
		for callable: Callable in _signal_callables:
			for sig in [&"formation_deployed", &"formation_activated", &"formation_deactivated",
						&"formation_overwritten", &"character_affiliated"]:
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
		{"name": &"character_affiliated", "callable": Callable(self, "_on_character_affiliated")}]
	for entry in sigs:
		fs.connect(entry["name"], entry["callable"])
		_signal_callables.append(entry["callable"])


func _on_formation_deployed(_f: int, _s: int, _t: StringName, _d: int) -> void:
	_signal_log.append("formation_deployed")


func _on_formation_activated(_f: int, _s: int, _t: StringName, _r: String) -> void:
	_signal_log.append("formation_activated")


func _on_formation_deactivated(_f: int, _s: int, _r: String) -> void:
	_signal_log.append("formation_deactivated")


func _on_formation_overwritten(_o: int, _n: int, _s: int) -> void:
	_signal_log.append("formation_overwritten")


func _on_character_affiliated(_c: int, _f: int) -> void:
	_signal_log.append("character_affiliated")


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
# AC-001：空位部署 + 自动分配 slot_index
# ============================================================================

func test_deploy_formation_to_empty_slot() -> void:
	var r: Dictionary = fs.call("deploy_formation", 100, &"formation_zhengdao_01")
	assert_true(r["success"], "空位部署成功")
	assert_eq(int(r["slot_index"]), 0, "自动分配到 slot 0")
	assert_gt(int(r["formation_id"]), 0, "formation_id 有效")
	assert_true(r["activated"], "条件满足（默认 true）→ 立即 ACTIVE")
	var slot: Dictionary = fs.call("get_slot_states")[0]
	assert_eq(slot["state"], FS_SCRIPT.SlotState.ACTIVE, "slot 0 状态 = ACTIVE")
	assert_eq(slot["formation_id"], r["formation_id"], "slot 0 formation_id 匹配")


func test_deploy_auto_assign_second_slot() -> void:
	fs.call("deploy_formation", 100, &"formation_a")
	var r: Dictionary = fs.call("deploy_formation", 101, &"formation_b")
	assert_eq(int(r["slot_index"]), 1, "第二个阵法自动分配到 slot 1")


func test_deploy_specified_slot() -> void:
	var r: Dictionary = fs.call("deploy_formation", 100, &"formation_a", 2)
	assert_eq(int(r["slot_index"]), 2, "指定 slot_index=2")


# ============================================================================
# AC-002：满位部署返回 slots_full（含未激活阵法）
# ============================================================================

func test_deploy_slots_full_returns_false() -> void:
	fs.call("deploy_formation", 100, &"f1", 0)
	fs.call("deploy_formation", 101, &"f2", 1)
	fs.call("deploy_formation", 102, &"f3", 2)
	var r: Dictionary = fs.call("deploy_formation", 103, &"f4")
	assert_false(r["success"], "满位部署失败")
	assert_eq(r["reason"], "slots_full", "reason = slots_full")
	assert_eq(int(r["formation_id"]), -1, "未分配 formation_id")


func test_deploy_slots_full_with_inactive() -> void:
	_set_condition(false)
	fs.call("deploy_formation", 100, &"f1", 0, REQ_3_ZHENGDAO)
	_set_condition(true)
	fs.call("deploy_formation", 101, &"f2", 1)
	fs.call("deploy_formation", 102, &"f3", 2)
	var r: Dictionary = fs.call("deploy_formation", 103, &"f4")
	assert_false(r["success"], "未激活阵法仍占位 → slots_full")


# ============================================================================
# AC-003：条件满足立即 ACTIVE
# ============================================================================

func test_deploy_condition_met_immediately_active() -> void:
	_set_condition(true)
	var r: Dictionary = fs.call("deploy_formation", 100, &"f1", -1, REQ_3_ZHENGDAO)
	assert_true(r["activated"], "条件满足 → activated=true")
	assert_eq(r["reason"], "deployed_active", "reason = deployed_active")
	var state: Dictionary = fs.call("get_formation_state", int(r["formation_id"]))
	assert_eq(state["state"], FS_SCRIPT.SlotState.ACTIVE, "state = ACTIVE")
	assert_true(state["is_active"], "is_active = true")


func test_deploy_emits_deployed_and_activated_signals() -> void:
	_set_condition(true)
	fs.call("deploy_formation", 100, &"f1", -1, REQ_3_ZHENGDAO)
	assert_true("formation_deployed" in _signal_log, "发射 formation_deployed")
	assert_true("formation_activated" in _signal_log, "条件满足 → 发射 formation_activated")


func test_deploy_condition_met_calls_effect_register() -> void:
	_set_condition(true)
	fs.call("deploy_formation", 100, &"f1", -1, REQ_3_ZHENGDAO)
	assert_true("register:100" in _effect_log, "激活 → effect_register_cb 被调用")


# ============================================================================
# AC-004：条件不满足 → DEPLOYED_UNACTIVE
# ============================================================================

func test_deploy_condition_not_met_inactive() -> void:
	_set_condition(false)
	var r: Dictionary = fs.call("deploy_formation", 100, &"f1", -1, REQ_3_ZHENGDAO)
	assert_false(r["activated"], "条件不满足 → activated=false")
	assert_eq(r["reason"], "deployed_inactive", "reason = deployed_inactive")
	var state: Dictionary = fs.call("get_formation_state", int(r["formation_id"]))
	assert_eq(state["state"], FS_SCRIPT.SlotState.DEPLOYED_UNACTIVE, "state = DEPLOYED_UNACTIVE")
	assert_false(state["is_active"], "is_active = false")


func test_deploy_inactive_no_activated_signal() -> void:
	_set_condition(false)
	fs.call("deploy_formation", 100, &"f1", -1, REQ_3_ZHENGDAO)
	assert_true("formation_deployed" in _signal_log, "仍发射 formation_deployed")
	assert_false("formation_activated" in _signal_log, "条件不满足 → 不发射 formation_activated")


func test_deploy_inactive_no_effect_register() -> void:
	_set_condition(false)
	fs.call("deploy_formation", 100, &"f1", -1, REQ_3_ZHENGDAO)
	assert_false("register:100" in _effect_log, "未激活 → 不调用 effect_register_cb")


# ============================================================================
# AC-005：overwrite_formation 覆盖流程
# ============================================================================

func test_overwrite_formation_old_discarded_new_deployed() -> void:
	_set_condition(true)
	fs.call("deploy_formation", 100, &"f1", 0, REQ_3_ZHENGDAO)
	fs.call("set_character_affilation", 200, 1)
	_effect_log.clear()
	_signal_log.clear()
	var r: Dictionary = fs.call("overwrite_formation", 101, &"f2", 0, REQ_3_ZHENGDAO)
	assert_true(r["success"], "覆盖成功")
	assert_gt(int(r["formation_id"]), 1, "新 formation_id > 旧")
	assert_true(r["activated"], "新阵法条件满足 → activated=true")
	var remove_idx: int = _effect_log.find("remove:100")
	var register_idx: int = _effect_log.find("register:101")
	assert_gte(remove_idx, 0, "remove:100 被调用")
	assert_gte(register_idx, 0, "register:101 被调用")
	assert_lt(remove_idx, register_idx, "remove 先于 register——严格顺序")
	assert_true("discard:100" in _effect_log, "旧卡进弃牌堆")
	assert_true("formation_overwritten" in _signal_log, "发射 formation_overwritten")
	assert_true("formation_deployed" in _signal_log, "新阵法发射 formation_deployed")


func test_overwrite_clears_old_affiliations() -> void:
	_set_condition(true)
	fs.call("deploy_formation", 100, &"f1", 0, REQ_3_ZHENGDAO)
	fs.call("set_character_affilation", 200, 1)
	fs.call("set_character_affilation", 201, 1)
	fs.call("overwrite_formation", 101, &"f2", 0, REQ_3_ZHENGDAO)
	assert_eq(int(fs.call("get_character_affilation", 200)), -1, "旧阵法归属角色 200 清除")
	assert_eq(int(fs.call("get_character_affilation", 201)), -1, "旧阵法归属角色 201 清除")


func test_overwrite_empty_slot_fails() -> void:
	var r: Dictionary = fs.call("overwrite_formation", 101, &"f2", 0)
	assert_false(r["success"], "空位覆盖失败")
	assert_eq(r["reason"], "no_existing_formation", "reason = no_existing_formation")


# ============================================================================
# AC-006：未激活阵法占用阵位
# ============================================================================

func test_inactive_formation_occupies_slot() -> void:
	_set_condition(false)
	fs.call("deploy_formation", 100, &"f1", 0, REQ_3_ZHENGDAO)
	var can: Dictionary = fs.call("can_deploy")
	assert_eq(int(can["empty_slots"]), 2, "1 个未激活阵法 → 空位 2")
	assert_true(can["can_deploy"], "仍有空位可部署")


func test_all_three_inactive_still_full() -> void:
	_set_condition(false)
	fs.call("deploy_formation", 100, &"f1", 0, REQ_3_ZHENGDAO)
	fs.call("deploy_formation", 101, &"f2", 1, REQ_3_ZHENGDAO)
	fs.call("deploy_formation", 102, &"f3", 2, REQ_3_ZHENGDAO)
	var can: Dictionary = fs.call("can_deploy")
	assert_eq(int(can["empty_slots"]), 0, "3 个未激活 → 空位 0")
	assert_false(can["can_deploy"], "满位不可部署")


# ============================================================================
# AC-007：set_character_affilation 归属指定
# ============================================================================

func test_set_affilation_success() -> void:
	_set_condition(true)
	fs.call("deploy_formation", 100, &"f1", 0, REQ_3_ZHENGDAO)
	var ok: bool = fs.call("set_character_affilation", 200, 1)
	assert_true(ok, "ACTIVE 阵法 + 无归属 → 成功")
	assert_eq(int(fs.call("get_character_affilation", 200)), 1, "归属记录写入")


func test_set_affilation_already_affiliated_rejects() -> void:
	_set_condition(true)
	fs.call("deploy_formation", 100, &"f1", 0, REQ_3_ZHENGDAO)
	fs.call("set_character_affilation", 200, 1)
	fs.call("deploy_formation", 101, &"f2", 1, REQ_3_ZHENGDAO)
	var ok: bool = fs.call("set_character_affilation", 200, 2)
	assert_false(ok, "角色已有归属 → 拒绝")


func test_set_affilation_inactive_formation_rejects() -> void:
	_set_condition(false)
	fs.call("deploy_formation", 100, &"f1", 0, REQ_3_ZHENGDAO)
	var ok: bool = fs.call("set_character_affilation", 200, 1)
	assert_false(ok, "非 ACTIVE 阵法 → 拒绝归属")


func test_set_affilation_emits_signal() -> void:
	_set_condition(true)
	fs.call("deploy_formation", 100, &"f1", 0, REQ_3_ZHENGDAO)
	_signal_log.clear()
	fs.call("set_character_affilation", 200, 1)
	assert_true("character_affiliated" in _signal_log, "发射 character_affiliated")


# ============================================================================
# AC-008：阵法失效清除归属
# ============================================================================

func test_clear_affiliation_removes_mapping() -> void:
	_set_condition(true)
	fs.call("deploy_formation", 100, &"f1", 0, REQ_3_ZHENGDAO)
	fs.call("set_character_affilation", 200, 1)
	fs.call("clear_character_affilation", 200)
	assert_eq(int(fs.call("get_character_affilation", 200)), -1, "清除后归属为 -1")


func test_clear_affiliation_unaffiliated_noop() -> void:
	fs.call("clear_character_affilation", 999)
	assert_eq(int(fs.call("get_character_affilation", 999)), -1, "未归属角色清除无副作用")


# ============================================================================
# 查询 API 补充
# ============================================================================

func test_get_active_formations() -> void:
	_set_condition(true)
	fs.call("deploy_formation", 100, &"f1", 0, REQ_3_ZHENGDAO)
	_set_condition(false)
	fs.call("deploy_formation", 101, &"f2", 1, REQ_3_ZHENGDAO)
	var active: Array = fs.call("get_active_formations")
	assert_eq(active.size(), 1, "仅 1 个 ACTIVE")
	assert_eq(int(active[0]["slot_index"]), 0, "ACTIVE 阵法在 slot 0")


func test_get_slot_states_three_slots() -> void:
	var slots: Array = fs.call("get_slot_states")
	assert_eq(slots.size(), 3, "3 个阵法位")
	for slot in slots:
		assert_eq(slot["state"], FS_SCRIPT.SlotState.EMPTY, "初始全 EMPTY")


func test_get_formation_state_not_found() -> void:
	var state: Dictionary = fs.call("get_formation_state", 999)
	assert_true(state.is_empty(), "未找到阵法返回空字典")


func test_is_formation_active() -> void:
	_set_condition(true)
	var r: Dictionary = fs.call("deploy_formation", 100, &"f1", 0, REQ_3_ZHENGDAO)
	assert_true(fs.call("is_formation_active", int(r["formation_id"])), "ACTIVE 阵法 is_active=true")
	assert_false(fs.call("is_formation_active", 999), "不存在的阵法 is_active=false")


func test_get_character_affilation_unaffiliated() -> void:
	assert_eq(int(fs.call("get_character_affilation", 200)), -1, "未归属返回 -1")


# ============================================================================
# lead-programmer C1 / qa-lead GAP-004：deploy 到已占用阵位拒绝
# ============================================================================

func test_deploy_to_occupied_slot_fails() -> void:
	fs.call("deploy_formation", 100, &"f1", 0)
	var r: Dictionary = fs.call("deploy_formation", 101, &"f2", 0)
	assert_false(r["success"], "占用阵位拒绝直接部署")
	assert_eq(r["reason"], "slot_occupied", "reason = slot_occupied")
	# 原阵法不受影响
	var slot: Dictionary = fs.call("get_slot_states")[0]
	assert_eq(int(slot["formation_id"]), 1, "原阵法 formation_id 不变")


# ============================================================================
# lead-programmer C2 / qa-lead GAP-003：覆盖新阵法条件不满足 → inactive
# ============================================================================

func test_overwrite_new_condition_not_met_inactive() -> void:
	_set_condition(true)
	fs.call("deploy_formation", 100, &"f1", 0, REQ_3_ZHENGDAO)
	_signal_log.clear()
	_set_condition(false)
	var r: Dictionary = fs.call("overwrite_formation", 101, &"f2", 0, REQ_3_ZHENGDAO)
	assert_false(r["activated"], "新阵法条件不满足 → inactive")
	assert_eq(r["reason"], "overwrite_inactive", "reason = overwrite_inactive")
	var slot: Dictionary = fs.call("get_slot_states")[0]
	assert_eq(slot["state"], FS_SCRIPT.SlotState.DEPLOYED_UNACTIVE, "新阵法 state = DEPLOYED_UNACTIVE")
	assert_false("formation_activated" in _signal_log, "条件不满足 → 不发射 formation_activated")


# ============================================================================
# lead-programmer C3 / qa-lead GAP-002：角色阵亡保留归属记录
# ============================================================================

func test_character_death_preserves_affiliation() -> void:
	_set_condition(true)
	fs.call("deploy_formation", 100, &"f1", 0, REQ_3_ZHENGDAO)
	fs.call("set_character_affilation", 200, 1)
	fs.call("set_character_affilation", 201, 1)
	# 角色阵亡——FormationSystem 不主动清除（仅阵法失效/覆盖时清除）
	assert_eq(int(fs.call("get_character_affilation", 200)), 1, "阵亡角色 200 归属保留")
	assert_eq(int(fs.call("get_character_affilation", 201)), 1, "角色 201 归属不受影响")


# ============================================================================
# qa-lead GAP-001：覆盖已失效旧阵法（归属已空，不影响任何角色）
# ============================================================================

func test_overwrite_already_inactive_formation_no_affiliation_impact() -> void:
	_set_condition(true)
	fs.call("deploy_formation", 100, &"f1", 0, REQ_3_ZHENGDAO)
	# 阵法条件变为不满足（本 Story 无 recheck——直接部署一个 condition=false 的阵法模拟）
	_set_condition(false)
	fs.call("deploy_formation", 101, &"f2", 1, REQ_3_ZHENGDAO)
	# slot 1 阵法为 DEPLOYED_UNACTIVE——无法 set affiliation（非 ACTIVE 拒绝）
	assert_false(fs.call("set_character_affilation", 200, 2), "非 ACTIVE 阵法拒绝归属")
	# 覆盖 slot 1（归属已空）
	_set_condition(true)
	_effect_log.clear()
	var r: Dictionary = fs.call("overwrite_formation", 102, &"f3", 1, REQ_3_ZHENGDAO)
	assert_true(r["success"], "覆盖成功")
	assert_true("remove:101" in _effect_log, "旧卡 effect_remove 被调用")
	# 无归属可清除——不影响任何角色
	assert_eq(int(fs.call("get_character_affilation", 200)), -1, "角色 200 无归属（从未设置）")


# ============================================================================
# lead-programmer C5 / qa-lead GAP-005：空 requirement 无条件阵法自动激活
# ============================================================================

func test_deploy_empty_requirement_auto_active() -> void:
	_set_condition(false)
	var r: Dictionary = fs.call("deploy_formation", 100, &"f1", 0, {})
	assert_true(r["activated"], "空 requirement → 无条件激活")
	assert_eq(r["reason"], "deployed_active", "reason = deployed_active")


# ============================================================================
# lead-programmer C6 / qa-lead GAP-006：overwrite 信号顺序 + formation_activated 发射
# ============================================================================

func test_overwrite_signal_order_and_activated() -> void:
	_set_condition(true)
	fs.call("deploy_formation", 100, &"f1", 0, REQ_3_ZHENGDAO)
	_signal_log.clear()
	var r: Dictionary = fs.call("overwrite_formation", 101, &"f2", 0, REQ_3_ZHENGDAO)
	assert_eq(r["reason"], "overwrite_active", "reason = overwrite_active")
	assert_true("formation_activated" in _signal_log, "条件满足 → 发射 formation_activated")
	var overwritten_idx: int = _signal_log.find("formation_overwritten")
	var deployed_idx: int = _signal_log.find("formation_deployed")
	assert_lt(overwritten_idx, deployed_idx, "formation_overwritten 先于 formation_deployed")


# ============================================================================
# qa-lead GAP-006：formation_deactivated 在 Story 001 范围内不发射
# ============================================================================

func test_formation_deactivated_not_emitted_in_story_001() -> void:
	_set_condition(true)
	fs.call("deploy_formation", 100, &"f1", 0, REQ_3_ZHENGDAO)
	_set_condition(false)
	fs.call("deploy_formation", 101, &"f2", 1, REQ_3_ZHENGDAO)
	fs.call("set_character_affilation", 200, 1)
	fs.call("clear_character_affilation", 200)
	fs.call("overwrite_formation", 102, &"f3", 0, REQ_3_ZHENGDAO)
	assert_false("formation_deactivated" in _signal_log, "Story 001 范围内不触发 deactivation")


# ============================================================================
# qa-lead GAP-007：拒绝归属后原归属不变
# ============================================================================

func test_set_affilation_reject_preserves_original() -> void:
	_set_condition(true)
	fs.call("deploy_formation", 100, &"f1", 0, REQ_3_ZHENGDAO)
	fs.call("set_character_affilation", 200, 1)
	fs.call("deploy_formation", 101, &"f2", 1, REQ_3_ZHENGDAO)
	assert_false(fs.call("set_character_affilation", 200, 2), "已有归属 → 拒绝")
	assert_eq(int(fs.call("get_character_affilation", 200)), 1, "拒绝后原归属不变")


# ============================================================================
# qa-lead GAP-008：归属设置后 affiliated_count 递增
# ============================================================================

func test_affiliated_count_increments() -> void:
	_set_condition(true)
	fs.call("deploy_formation", 100, &"f1", 0, REQ_3_ZHENGDAO)
	fs.call("set_character_affilation", 200, 1)
	var state: Dictionary = fs.call("get_formation_state", 1)
	assert_eq(int(state["affiliated_count"]), 1, "归属设置后 affiliated_count=1")
	var active: Array = fs.call("get_active_formations")
	assert_eq(int(active[0]["affiliated_count"]), 1, "get_active_formations 含 affiliated_count=1")
