## DeploymentSystem 数据层（继承链第 4 段）——[b]阵位查询 API + 内部数据原语[/b]。
##
## [b]本层职责[/b]：[br]
##   · 5 个查询口（[method get_field] / [method get_character_slot] /
##     [method get_front_count] / [method get_empty_slots] / [method can_deploy]）——
##     表现层（[code]combat_actor_reader[/code] / [code]pause_menu[/code] / 备战面板）与
##     战斗域各子模块按名调用；[br]
##   · 7 个内部原语（[method _reset_field] / [method _assign_slots] / [method _is_front] /
##     [method _state_to_string] / [method _state_from_string] / [method _query_max_deploy]）——
##     其中 4 个被 3 个 RefCounted 子模块经 [code]_parent.call("_state_to_string")[/code] /
##     [code]_parent.get("SLOT_COUNT")[/code] 回取，同属公开面；[br]
##   · [method _query_max_deploy] 是境界上场上限的唯一取数口——不自行维护境界→人数映射
##     （L+1 公式在 RealmSystem 中，ADR-0016）。[br]
##
## [b]为什么原语与查询同段[/b]：[method can_deploy] 调 [method _query_max_deploy]、
## [method _reset_field] 调 [method _is_front]——同段互调不受链序约束；
## 而 [method setup_field]（下一段）要调这里的三个原语，故本段必须在战斗操作层[b]之前[/b]。[br]
##
## 来源: ADR-0016 §关键接口 §境界阵位分布 / GDD deployment-system.md §2、
## .claude/docs/coding-standards.md §文件行数限制。

extends "res://src/feature/deployment/deployment_system_access.gd"

# === 查询 API =====================================================================

## 返回当前阵位分布（按 slot_index 升序）。[br]
## [br][b]返回[/b]: [code]Array[Dictionary][/code]——每项含
## [code]{slot_index, character_id, is_front, state, deploy_turn}[/code]；
## 空位为 [code]character_id=-1[/code] + [code]state=EMPTY[/code] + [code]deploy_turn=-1[/code]。
func get_field() -> Array:
	var result: Array = []
	for i in range(SLOT_COUNT):
		var entry: Dictionary = _field[i]
		result.append({
			"slot_index": i,
			"character_id": entry["character_id"],
			"is_front": entry["is_front"],
			"state": entry["state"],
			"deploy_turn": entry["deploy_turn"],
		})
	return result


## 查询角色所在 slot_index（O(n)，n≤6）。[br]
## [br][param character_id] 角色 ID。[br]
## [br][b]返回[/b]: slot_index；未上场返回 -1。[br]
## [br][b]哨兵守卫[/b]：-1 是空位的内部 character_id 哨兵值——传入 -1 直接返回 -1，
## 避免「查询不存在角色」误命中空位（QA 覆盖审查缺口 #3）。
func get_character_slot(character_id: int) -> int:
	if character_id == -1:
		return -1
	for slot in range(SLOT_COUNT):
		if _field[slot]["character_id"] == character_id:
			return slot
	return -1


## 前排角色计数。[br]
## [br][param alive_only] true = 仅存活（排除 DEAD）；false = 占用计数（含阵亡）。均排除空位。[br]
## [br][b]返回[/b]: 前排角色数。
func get_front_count(alive_only: bool = true) -> int:
	var count: int = 0
	for slot in range(FRONT_SLOTS):
		var entry: Dictionary = _field[slot]
		if entry["character_id"] == -1:
			continue
		if alive_only and entry["state"] == FieldState.DEAD:
			continue
		count += 1
	return count


## 返回空阵位 slot_index 列表——前排优先排序（0,1,2,3,4,5）。[br]
## [br][b]返回[/b]: [code]Array[int][/code]。
func get_empty_slots() -> Array:
	var empty: Array = []
	for slot in [0, 1, 2, 3, 4, 5]:
		if _field[slot]["character_id"] == -1:
			empty.append(slot)
	return empty


## 出战前检查。[br]
## [br][b]返回[/b]: [code]{can_deploy: bool, empty_slots: int, max_deploy: int, reason: String}[/code]。
func can_deploy() -> Dictionary:
	var empty_slots: int = get_empty_slots().size()
	var max_deploy: int = _query_max_deploy()
	var deployed: int = SLOT_COUNT - empty_slots
	var can: bool = empty_slots > 0 and deployed < max_deploy
	var reason: String = "可以补位" if can else ("场上已满" if empty_slots == 0 else "已达上场人数上限")
	return {
		"can_deploy": can,
		"empty_slots": empty_slots,
		"max_deploy": max_deploy,
		"reason": reason,
	}

# === 内部 =========================================================================

## 重置 6 个阵位为空位（前排 is_front=true）。
func _reset_field() -> void:
	_field.clear()
	for i in range(SLOT_COUNT):
		_field[i] = {
			"character_id": -1,
			"is_front": _is_front(i),
			"deploy_turn": -1,
			"state": FieldState.EMPTY,
		}


## 阵位分配——委托给 _slot_allocator 子模块。
func _assign_slots(character_ids: Array, layout: Dictionary) -> Dictionary:
	return _get_slot_allocator().assign_slots(character_ids, layout)


## slot_index 前后排判定——slot_index ∈ [0,2] 为前排。
func _is_front(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < FRONT_SLOTS


## FieldState 枚举 → String 名映射（序列化用——可读性 + 前向兼容）。[br]
## [br][b]未知状态[/b]：回退 "EMPTY"。
func _state_to_string(state: FieldState) -> String:
	match state:
		FieldState.STANDBY:
			return "STANDBY"
		FieldState.READY:
			return "READY"
		FieldState.ACTED:
			return "ACTED"
		FieldState.DEAD:
			return "DEAD"
		_:
			return "EMPTY"


## String 名 → FieldState 枚举映射（反序列化用）。[br]
## [br][b]未知/缺失[/b]：回退 [constant FieldState.EMPTY]。
func _state_from_string(state_name: String) -> FieldState:
	match state_name:
		"STANDBY":
			return FieldState.STANDBY
		"READY":
			return FieldState.READY
		"ACTED":
			return FieldState.ACTED
		"DEAD":
			return FieldState.DEAD
		_:
			return FieldState.EMPTY


## 查询当前境界的上场人数上限。[br]
## [br]通过 [method RealmSystem.get_current_property] 读取 GSM.player.realm——不自行维护境界→人数映射
## （L+1 公式在 RealmSystem 中，ADR-0016）。[br]
## [br][b]返回[/b]: max_deploy；GSM/realm 无效返回 0。
func _query_max_deploy() -> int:
	var val: Variant = RealmSystem.get_current_property(&"max_deploy")
	if val == null:
		return 0
	return int(val)
