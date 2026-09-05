extends RefCounted
## FormationSlotOps —— 阵法部署/覆盖/条件重判子模块（从 formation_system.gd 拆分）。
##
## 持有对 FormationSystem 父节点的引用，通过它访问 _slots/_affiliations/
## _next_formation_id/_deploy_turn/_check_condition/_emit_safe 等。
##
## [br]来源: ADR-0024 §关键接口 deploy_formation §overwrite_formation §recheck_all_conditions。
## [br]Sprint 12 Story 019：从 formation_system.gd 拆分。

## SlotState 枚举值（避免依赖父节点枚举）。
const _STATE_EMPTY: int = 0
const _STATE_DEPLOYED_UNACTIVE: int = 1
const _STATE_ACTIVE: int = 2
const _STATE_DISCARDED: int = 3

## 父节点引用——FormationSystem Autoload 实例。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


## 部署阵法卡到阵法区（AC-001~004）。[br]
## slot_index=-1 时自动分配第一个空位（按 0→1→2 顺序）。[br]
## 部署后立即判定条件——满足则 ACTIVE，否则 DEPLOYED_UNACTIVE。[br]
## 阵法区满 3 个（含未激活）返回 [code]slots_full[/code]。
func deploy_formation(card_instance_id: int, template_id: StringName, slot_index: int = -1,
		requirement: Dictionary = {}, aura_scope: int = 1,
		effect_config: Dictionary = {}, max_level: int = 0, base_value: float = 0.0) -> Dictionary:
	var slots: Dictionary = _parent.get("_slots")
	var target_slot: int = slot_index if slot_index >= 0 else _parent.call("_find_empty_slot")
	if target_slot == -1:
		return {"success": false, "formation_id": -1, "slot_index": -1, "activated": false, "reason": "slots_full"}
	# 占用守卫（lead-programmer C1）——显式 slot_index 非 EMPTY 时拒绝，必须走 overwrite_formation
	if slot_index >= 0 and (slots[target_slot] as Dictionary).get("state", _STATE_EMPTY) != _STATE_EMPTY:
		return {"success": false, "formation_id": -1, "slot_index": target_slot, "activated": false, "reason": "slot_occupied"}
	var formation_id: int = _parent.get("_next_formation_id")
	_parent.set("_next_formation_id", formation_id + 1)
	var slot: Dictionary = slots[target_slot]
	slot["formation_id"] = formation_id
	slot["card_instance_id"] = card_instance_id
	slot["template_id"] = template_id
	slot["state"] = _STATE_DEPLOYED_UNACTIVE
	slot["deployed_turn"] = _parent.get("_deploy_turn")
	slot["requirement"] = requirement.duplicate(true)
	slot["aura_scope"] = aura_scope
	slot["effect_config"] = effect_config.duplicate(true)
	slot["max_level"] = max_level
	slot["base_value"] = base_value
	slot["affiliated_chars"] = []
	var activated: bool = _parent.call("_check_condition", requirement)
	if activated:
		slot["state"] = _STATE_ACTIVE
		_parent.call("_invoke_cb", _parent.get("effect_register_cb"), [card_instance_id, template_id, {"aura_scope": aura_scope}])
	_parent.call("_emit_safe", &"formation_deployed", [formation_id, target_slot, template_id, _parent.get("_deploy_turn")])
	if activated:
		_parent.call("_emit_safe", &"formation_activated", [formation_id, target_slot, template_id, "deployed"])
	var reason: String = "deployed_active" if activated else "deployed_inactive"
	return {"success": true, "formation_id": formation_id, "slot_index": target_slot, "activated": activated, "reason": reason}


## 覆盖阵法位（AC-005）——严格顺序：旧阵 DISCARDED → 清除归属 → 移除旧效果 → 新阵部署 → 判定 → 注册新效果。
func overwrite_formation(card_instance_id: int, template_id: StringName, target_slot: int,
		requirement: Dictionary = {}, aura_scope: int = 1,
		effect_config: Dictionary = {}, max_level: int = 0, base_value: float = 0.0) -> Dictionary:
	var slots: Dictionary = _parent.get("_slots")
	var old_slot: Dictionary = slots.get(target_slot, {})
	if old_slot.is_empty() or old_slot.get("state", _STATE_EMPTY) == _STATE_EMPTY:
		return {"success": false, "formation_id": -1, "slot_index": target_slot, "activated": false, "reason": "no_existing_formation"}
	var old_formation_id: int = old_slot["formation_id"]
	var old_card_instance_id: int = old_slot["card_instance_id"]
	# 1. 旧阵法 → DISCARDED（瞬态——立即被新阵覆盖）
	old_slot["state"] = _STATE_DISCARDED
	# 2. 清除旧阵法全部归属
	_parent.call("_clear_affiliations_by_formation", old_formation_id)
	# 3. CardEffectEngine.remove_effects_by_source（先移除旧效果）
	_parent.call("_invoke_cb", _parent.get("effect_remove_cb"), [old_card_instance_id])
	_parent.call("_invoke_cb", _parent.get("card_discard_cb"), [old_card_instance_id])
	# 4. 新阵法部署到该阵位
	var formation_id: int = _parent.get("_next_formation_id")
	_parent.set("_next_formation_id", formation_id + 1)
	old_slot["formation_id"] = formation_id
	old_slot["card_instance_id"] = card_instance_id
	old_slot["template_id"] = template_id
	old_slot["state"] = _STATE_DEPLOYED_UNACTIVE
	old_slot["deployed_turn"] = _parent.get("_deploy_turn")
	old_slot["requirement"] = requirement.duplicate(true)
	old_slot["aura_scope"] = aura_scope
	old_slot["effect_config"] = effect_config.duplicate(true)
	old_slot["max_level"] = max_level
	old_slot["base_value"] = base_value
	old_slot["affiliated_chars"] = []
	# 5. 立即判定条件
	var activated: bool = _parent.call("_check_condition", requirement)
	if activated:
		old_slot["state"] = _STATE_ACTIVE
		_parent.call("_invoke_cb", _parent.get("effect_register_cb"), [card_instance_id, template_id, {"aura_scope": aura_scope}])
	# 6. 发射信号
	_parent.call("_emit_safe", &"formation_overwritten", [old_formation_id, formation_id, target_slot])
	_parent.call("_emit_safe", &"formation_deployed", [formation_id, target_slot, template_id, _parent.get("_deploy_turn")])
	if activated:
		_parent.call("_emit_safe", &"formation_activated", [formation_id, target_slot, template_id, "overwrite"])
	var reason: String = "overwrite_active" if activated else "overwrite_inactive"
	return {"success": true, "formation_id": formation_id, "slot_index": target_slot, "activated": activated, "reason": reason}


## 条件重判——遍历 3 个阵法位，对每个非 EMPTY 阵法调用条件判定。[br]
## 条件变化时更新状态（DEPLOYED_UNACTIVE→ACTIVE 或 ACTIVE→DEPLOYED_UNACTIVE）。[br]
## [b]不发射信号[/b]——仅返回变更列表，由调用方批量发射
## [signal formation_condition_reevaluated]（避免信号级联/重入，ADR-0024 §风险）。[br]
## [br][b]返回[/b]: [code]Array[/code]——元素 [code]{formation_id, slot_index, old_state, new_state, reason}[/code]。
func recheck_all_conditions() -> Array:
	var slots: Dictionary = _parent.get("_slots")
	var changes: Array = []
	for i in range(_parent.get("MAX_SLOTS")):
		var slot: Dictionary = slots[i]
		var state: int = slot.get("state", _STATE_EMPTY)
		if state == _STATE_EMPTY or state == _STATE_DISCARDED:
			continue
		var requirement: Dictionary = slot.get("requirement", {})
		var now_met: bool = _parent.call("_check_condition", requirement)
		var was_active: bool = (state == _STATE_ACTIVE)
		if now_met and not was_active:
			# UNACTIVE → ACTIVE
			slot["state"] = _STATE_ACTIVE
			changes.append({"formation_id": slot["formation_id"], "slot_index": i,
				"old_state": _STATE_DEPLOYED_UNACTIVE, "new_state": _STATE_ACTIVE,
				"reason": "condition_met"})
		elif not now_met and was_active:
			# ACTIVE → UNACTIVE
			slot["state"] = _STATE_DEPLOYED_UNACTIVE
			changes.append({"formation_id": slot["formation_id"], "slot_index": i,
				"old_state": _STATE_ACTIVE, "new_state": _STATE_DEPLOYED_UNACTIVE,
				"reason": "condition_lost"})
	return changes


## DeploymentSystem 信号处理器——角色上场/阵亡/离场时触发条件重判。[br]
## 处理状态变更副作用（ACTIVE→注册 persistent effect；UNACTIVE→移除+清除归属）[br]
## 并批量发射变更信号。
func on_field_changed(_character_id: int = -1, _slot_index: int = -1, _extra: Variant = null) -> void:
	var changes: Array = recheck_all_conditions()
	var slots: Dictionary = _parent.get("_slots")
	for change: Dictionary in changes:
		var slot: Dictionary = slots[change["slot_index"]]
		var formation_id: int = change["formation_id"]
		var card_instance_id: int = slot.get("card_instance_id", -1)
		var template_id: StringName = slot.get("template_id", &"")
		if change["new_state"] == _STATE_ACTIVE:
			# UNACTIVE → ACTIVE：注册效果 + 发射 activated
			_parent.call("_invoke_cb", _parent.get("effect_register_cb"), [card_instance_id, template_id, {"aura_scope": slot.get("aura_scope", 1)}])
			_parent.call("_emit_safe", &"formation_activated", [formation_id, change["slot_index"], template_id, "recheck"])
		else:
			# ACTIVE → UNACTIVE：移除效果 + 清除归属 + 发射 deactivated
			_parent.call("_invoke_cb", _parent.get("effect_remove_cb"), [card_instance_id])
			_parent.call("_clear_affiliations_by_formation", formation_id)
			_parent.call("_emit_safe", &"formation_deactivated", [formation_id, change["slot_index"], "condition_lost"])
	if not changes.is_empty():
		_parent.call("_emit_safe", &"formation_condition_reevaluated", [changes])
