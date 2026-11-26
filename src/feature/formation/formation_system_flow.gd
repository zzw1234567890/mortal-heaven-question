## FormationSystem 流程面（继承链第 3 段）——[b]部署与覆盖 / 归属管理 / 查询 API / 内部原语[/b]。
##
## [b]本层职责[/b]：阵位状态机的本体与它的读写入口。[br]
##   · 部署与覆盖——[method deploy_formation] / [method overwrite_formation]
##     （实现体在 [code]formation_slot_ops.gd[/code]，Sprint 12 Story 019 切出）；[br]
##   · 归属管理——[method set_character_affilation] / [method clear_character_affilation]
##     （[b]注意方法名里的 [code]affilation[/code] 是既有拼写[/b]——产品代码、三个子模块
##     与四个既有测试文件都按这个名字符串调用，逐字不动）；[br]
##   · 查询 API——[method get_formation_state] / [method get_active_formations] /
##     [method get_slot_states] / [method get_character_affilation] /
##     [method is_formation_active] / [method can_deploy]（UI 与战斗域按名读）；[br]
##   · 内部原语——[method _check_condition] / [method _clear_affiliations_by_formation] /
##     [method _get_slot_by_formation] / [method _get_slot_index_by_formation] /
##     [method _find_empty_slot]，三个子模块经 [code]_parent.call[/code] 回取。
## [b]为什么本层排在接缝段之后[/b]：[method deploy_formation] 要调 [method _get_slot_ops]，
## [method _check_condition] 要调 [method _get_faction_system]，
## [method set_character_affilation] 要发信号（[method _emit_safe]）——被调方全在祖先段。
## 本段 [method deploy_formation] 的默认参数值 [code]AuraScope.AFFILIATED_CHARACTERS[/code]
## 是[b]解析期求值[/b]，只能引用本段或祖先段常量，故枚举随声明落链首。[br]
## [b]不管什么[/b]：不建子模块（祖先段）、不转发出口（链尾）、不碰快照与清理（链尾）。
##
## [b]继承链[/b]（各段守 300 行内，成员名与访问路径逐字不变）：[br]
## [code]  formation_system_contract.gd [/code] ← 声明面：2 枚举 / 6 信号 / 1 标量常量 / 15 实例字段[br]
## [code]  formation_system_access.gd   [/code] ← 接缝与访问面：默认状态构造 / 三个惰性子模块获取器 / 信号发射包装 / 两个 Autoload 获取器[br]
## [code]  formation_system_flow.gd     [/code] ← 流程面：部署与覆盖 / 归属管理 / 查询 API / 内部原语[br]
## [code]  formation_system.gd          [/code] ← 链尾：条件重判与光环委托 / 序列化三出口 / 战斗结束清理[br]
##
## 来源: ADR-0024 §关键接口 §阵法状态机 §覆盖流程 §角色归属管理、
## GDD formation-system.md §部署 §归属 §查询。

extends "res://src/feature/formation/formation_system_access.gd"


# === 部署 API ==================================================================

## 部署阵法卡到阵法区（AC-001~004）。[br]
## slot_index=-1 时自动分配第一个空位（按 0→1→2 顺序）。[br]
## 部署后立即判定条件——满足则 ACTIVE，否则 DEPLOYED_UNACTIVE。[br]
## 阵法区满 3 个（含未激活）返回 [code]slots_full[/code]。[br]
## [br][param card_instance_id] 阵法卡实例 ID。[br]
## [br][param template_id] 阵法模板 ID。[br]
## [br][param slot_index] 指定阵位（-1 自动分配）。[br]
## [br][param requirement] 激活条件 [code]{tag_id, min_count}[/code]。[br]
## [br][param aura_scope] 光环作用域。[br]
## [br][b]返回[/b]: [code]{success, formation_id, slot_index, activated, reason}[/code]。
func deploy_formation(card_instance_id: int, template_id: StringName, slot_index: int = -1,
		requirement: Dictionary = {}, aura_scope: int = AuraScope.AFFILIATED_CHARACTERS,
		effect_config: Dictionary = {}, max_level: int = 0, base_value: float = 0.0) -> Dictionary:
	return _get_slot_ops().deploy_formation(card_instance_id, template_id, slot_index, requirement, aura_scope, effect_config, max_level, base_value)


## 覆盖阵法位（AC-005）——严格顺序：旧阵 DISCARDED → 清除归属 → 移除旧效果 → 新阵部署 → 判定 → 注册新效果。[br]
## [br][param target_slot] 被覆盖的阵位索引。[br]
## [br][b]返回[/b]: [code]{success, formation_id, slot_index, activated, reason}[/code]。
func overwrite_formation(card_instance_id: int, template_id: StringName, target_slot: int,
		requirement: Dictionary = {}, aura_scope: int = AuraScope.AFFILIATED_CHARACTERS,
		effect_config: Dictionary = {}, max_level: int = 0, base_value: float = 0.0) -> Dictionary:
	return _get_slot_ops().overwrite_formation(card_instance_id, template_id, target_slot, requirement, aura_scope, effect_config, max_level, base_value)


# === 归属管理 ==================================================================

## 玩家手动指定角色归属阵法（AC-007）。[br]
## 仅当角色当前无归属 + 阵法为 ACTIVE → 返回 true。[br]
## 角色已有归属 → 返回 false（需先清除）；阵法非 ACTIVE → 返回 false。[br]
## [b]延后[/b]：ADR-0024 §关键接口指定"角色满足条件"第三检查项——
## 角色是否在场/阵营匹配依赖 DeploymentSystem/FactionSystem 集成，
## 延后至 Story 002（recheck_all_conditions 订阅 deployment 信号时）或集成测试。
func set_character_affilation(character_id: int, formation_id: int) -> bool:
	if _affiliations.has(character_id):
		return false
	if not is_formation_active(formation_id):
		return false
	var slot: Dictionary = _get_slot_by_formation(formation_id)
	if slot.is_empty():
		return false
	_affiliations[character_id] = formation_id
	(slot["affiliated_chars"] as Array).append(character_id)
	_emit_safe(&"character_affiliated", [character_id, formation_id])
	return true


## 清除角色归属（AC-008）——阵法失效/覆盖时自动调用。[br]
## [br][param character_id] 角色 ID。
func clear_character_affilation(character_id: int) -> void:
	if not _affiliations.has(character_id):
		return
	var formation_id: int = _affiliations[character_id]
	_affiliations.erase(character_id)
	var slot: Dictionary = _get_slot_by_formation(formation_id)
	if not slot.is_empty() and slot.has("affiliated_chars"):
		(slot["affiliated_chars"] as Array).erase(character_id)


# === 查询 API ==================================================================

## O(1) 查询单阵法完整状态。[br]
## [br][b]返回[/b]: [code]{slot_index, template_id, state, deployed_turn, requirement, affiliated_count, is_active}[/code]。
func get_formation_state(formation_id: int) -> Dictionary:
	var slot: Dictionary = _get_slot_by_formation(formation_id)
	if slot.is_empty():
		return {}
	return {
		"slot_index": _get_slot_index_by_formation(formation_id),
		"template_id": slot.get("template_id", &""),
		"state": slot.get("state", SlotState.EMPTY),
		"deployed_turn": slot.get("deployed_turn", -1),
		"requirement": slot.get("requirement", {}),
		"affiliated_count": (slot.get("affiliated_chars", []) as Array).size(),
		"is_active": slot.get("state", SlotState.EMPTY) == SlotState.ACTIVE,
	}


## 返回所有 ACTIVE 阵法摘要列表。
func get_active_formations() -> Array:
	var result: Array = []
	for i in range(MAX_SLOTS):
		var slot: Dictionary = _slots[i]
		if slot.get("state", SlotState.EMPTY) == SlotState.ACTIVE:
			result.append({
				"formation_id": slot["formation_id"],
				"slot_index": i,
				"template_id": slot["template_id"],
				"affiliated_count": (slot.get("affiliated_chars", []) as Array).size(),
			})
	return result


## 返回 3 个阵法位完整状态。
func get_slot_states() -> Array:
	var result: Array = []
	for i in range(MAX_SLOTS):
		var slot: Dictionary = _slots[i]
		result.append({
			"slot_index": i,
			"formation_id": slot.get("formation_id", -1),
			"template_id": slot.get("template_id", &""),
			"state": slot.get("state", SlotState.EMPTY),
			"deployed_turn": slot.get("deployed_turn", -1),
			"is_active": slot.get("state", SlotState.EMPTY) == SlotState.ACTIVE,
			"affiliated_count": (slot.get("affiliated_chars", []) as Array).size(),
		})
	return result


## O(1) 查询角色归属的阵法 ID——未归属返回 -1。
func get_character_affilation(character_id: int) -> int:
	return int(_affiliations.get(character_id, -1))


## O(1) 查询阵法是否处于 ACTIVE 状态。
func is_formation_active(formation_id: int) -> bool:
	var slot: Dictionary = _get_slot_by_formation(formation_id)
	if slot.is_empty():
		return false
	return slot.get("state", SlotState.EMPTY) == SlotState.ACTIVE


## 阵法部署前检查。[br]
## [br][b]返回[/b]: [code]{can_deploy, empty_slots, reason}[/code]。
func can_deploy() -> Dictionary:
	var empty: int = 0
	for i in range(MAX_SLOTS):
		if _slots[i].get("state", SlotState.EMPTY) == SlotState.EMPTY:
			empty += 1
	return {"can_deploy": empty > 0, "empty_slots": empty, "reason": "ok" if empty > 0 else "slots_full"}


# === 内部方法 ==================================================================

## 条件判定——优先 condition_check_cb，否则走 FactionSystem.check_condition。[br]
## 无 requirement → 自动激活（无条件阵法）。[br]
## FactionSystem 不可用 → 返回 false（安全回退）。
func _check_condition(requirement: Dictionary) -> bool:
	if requirement.is_empty():
		return true
	if condition_check_cb.is_valid():
		return bool(condition_check_cb.call(requirement))
	var fs: Node = _get_faction_system()
	if fs != null and fs.has_method("check_condition"):
		return bool(fs.call("check_condition", requirement))
	return false


## 清除指向指定阵法的全部归属记录 + 同步清理 slot.affiliated_chars 数组（lead-programmer C1）。
func _clear_affiliations_by_formation(formation_id: int) -> void:
	var to_remove: Array[int] = []
	for char_id: int in _affiliations.keys():
		if _affiliations[char_id] == formation_id:
			to_remove.append(char_id)
	for char_id: int in to_remove:
		_affiliations.erase(char_id)
	var slot: Dictionary = _get_slot_by_formation(formation_id)
	if not slot.is_empty() and slot.has("affiliated_chars"):
		(slot["affiliated_chars"] as Array).clear()


## 按 formation_id 查找阵法位 Dictionary。
func _get_slot_by_formation(formation_id: int) -> Dictionary:
	for i in range(MAX_SLOTS):
		var slot: Dictionary = _slots[i]
		if slot.get("formation_id", -1) == formation_id:
			return slot
	return {}


## 按 formation_id 查找阵位索引。
func _get_slot_index_by_formation(formation_id: int) -> int:
	for i in range(MAX_SLOTS):
		if _slots[i].get("formation_id", -1) == formation_id:
			return i
	return -1


## 查找第一个空位（按 0→1→2 顺序）。
func _find_empty_slot() -> int:
	for i in range(MAX_SLOTS):
		if _slots[i].get("state", SlotState.EMPTY) == SlotState.EMPTY:
			return i
	return -1
