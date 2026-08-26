## FormationSystem —— 阵法系统 Autoload（#23）。
##
## Feature 层 Autoload。采用内部条件状态机管理阵法位数据——
## 阵法位状态、激活/未激活判定、角色归属关系均在内部 Dictionary 中管理，
## 战斗期间不经过 GSM（ADR-0024 GSM 例外先例，同 ADR-0011/0013/0016）。
##
## [b]本 Story 范围[/b]（4-14）：SlotState/AuraScope 枚举 + 阵位数据模型 +
## deploy_formation / overwrite_formation / set_character_affilation /
## clear_character_affilation + 查询 API + 5 个 Cat 2b 信号。[br]
## [b]不注册进 project.godot[/b]——待各系统实现完毕后统一注册（4-0b 终验）。[br]
## [b]后续 story[/b]：recheck_all_conditions 实时重判（4-15）、
## get_aura_bonus O(1) 查询（4-16）、serialize_all 快照（4-17）。
## [b]存根接口[/b]：条件判定走 FactionSystem.check_condition 或可注入
## condition_check_cb；效果引擎 register/remove 通过 Callable 承载——默认空操作。
##
## 来源: ADR-0024 §决策 §对象模型 §阵法状态机 §关键接口 / GDD formation-system.md。
extends Node
# class_name FormationSystem —— 不声明：Autoload 全局单例，
# 声明 class_name 会与全局名冲突，导致 FS_SCRIPT.new() 测试实例无法解析。
# 测试以 var fs: Node 持有 + 动态分派访问（同 DeploymentSystem/BindingManager 先例）。


# === 枚举 ======================================================================

enum SlotState { EMPTY, DEPLOYED_UNACTIVE, ACTIVE, DISCARDED }
enum AuraScope { GLOBAL, AFFILIATED_CHARACTERS, SAME_FACTION, FORMATION_TRIGGER }


# === Cat 2b 信号（ADR-0024 §Cat 2b 信号，经 _emit_signal_safe 路由）===============

## 阵法部署到阵法位（无论是否激活）。
signal formation_deployed(formation_id: int, slot_index: int, template_id: StringName, deployed_turn: int)
## 阵法条件满足→激活。
signal formation_activated(formation_id: int, slot_index: int, template_id: StringName, trigger_reason: String)
## 阵法条件不满足→失效。
signal formation_deactivated(formation_id: int, slot_index: int, reason: String)
## 覆盖完成（携带 old/new formation_id，UI 据此替换图标 + 过渡动画）。
signal formation_overwritten(old_formation_id: int, new_formation_id: int, slot_index: int)
## 玩家手动指定角色归属。
signal character_affiliated(character_id: int, formation_id: int)
## 条件重判完成批量通知（携带变更列表）。
signal formation_condition_reevaluated(changes: Array)


# === 常量 ======================================================================

const MAX_SLOTS: int = 3


# === 内部数据 ==================================================================

## 阵法位——slot_index(0-2) → 阵法 Dictionary。[br]
## [b]声明为无类型 Dictionary[/b]——Dictionary[int, Dictionary] 是嵌套类型化集合，
## Godot 4.6 GDScript 不支持。值仍为 Dictionary，类型保证由构造路径维护。
var _slots: Dictionary = {}

## 角色归属——character_id → formation_id（每角色最多 1 个）。
var _affiliations: Dictionary[int, int] = {}

## 下一阵法 ID（单调递增）。
var _next_formation_id: int = 1

## 当前回合（由调用方设置，默认 0）。
var _deploy_turn: int = 0

## 延迟归属队列（ADR-0024 §风险——敌方回合时序安全）。[br]
## 敌方回合条件重判中新阵法激活需归属选择时压入此队列，[br]
## 己方回合 Phase 1 DRAW 由 CombatSystem 弹出（本 Story 仅实现数据结构 + 压入存根）。
var _pending_affiliations: Array[Dictionary] = []


# === 可注入存根（同 BindingManager 先例——默认空操作/安全回退）===================

## 阵法激活条件判定存根——(requirement: Dictionary) -> bool。默认走 FactionSystem.check_condition。
var condition_check_cb: Callable = Callable()

## 效果引擎 register_persistent_effect 存根——(card_instance_id, template_id, scope_context)。默认空操作。
var effect_register_cb: Callable = Callable()

## 效果引擎 remove_effects_by_source 存根——(card_instance_id)。默认空操作。
var effect_remove_cb: Callable = Callable()

## 阵法覆盖时旧卡进弃牌堆存根——(card_instance_id)。默认空操作。
var card_discard_cb: Callable = Callable()

## 阵营人数查询存根——(tag_id: StringName) -> int。默认走 FactionSystem.count_on_field。
var count_on_field_cb: Callable = Callable()

## 固定属性加成查询存根——(formation_id: int, stat_name: String) -> float。[br]
## 用于固定阵法（非梯度）的属性增益查询——默认从 slot.effect_config 读取。
var fixed_bonus_cb: Callable = Callable()

## 角色存在性验证存根——(character_id: int) -> bool。默认返回 true（假设存在）。
var character_exists_cb: Callable = Callable()


# === 初始化 ====================================================================

func _init() -> void:
	_reset_slots()


func _reset_slots() -> void:
	_slots.clear()
	for i in range(MAX_SLOTS):
		_slots[i] = _make_empty_slot()


func _make_empty_slot() -> Dictionary:
	return {
		"formation_id": -1,
		"card_instance_id": -1,
		"template_id": &"",
		"state": SlotState.EMPTY,
		"deployed_turn": -1,
		"requirement": {},
		"aura_scope": AuraScope.AFFILIATED_CHARACTERS,
		"effect_config": {},
		"max_level": 0,
		"base_value": 0.0,
		"affiliated_chars": [],
	}


func set_deploy_turn(turn: int) -> void:
	_deploy_turn = turn


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
	var target_slot: int = slot_index if slot_index >= 0 else _find_empty_slot()
	if target_slot == -1:
		return {"success": false, "formation_id": -1, "slot_index": -1, "activated": false, "reason": "slots_full"}
	# 占用守卫（lead-programmer C1）——显式 slot_index 非 EMPTY 时拒绝，必须走 overwrite_formation
	if slot_index >= 0 and _slots[target_slot].get("state", SlotState.EMPTY) != SlotState.EMPTY:
		return {"success": false, "formation_id": -1, "slot_index": target_slot, "activated": false, "reason": "slot_occupied"}
	var formation_id: int = _next_formation_id
	_next_formation_id += 1
	var slot: Dictionary = _slots[target_slot]
	slot["formation_id"] = formation_id
	slot["card_instance_id"] = card_instance_id
	slot["template_id"] = template_id
	slot["state"] = SlotState.DEPLOYED_UNACTIVE
	slot["deployed_turn"] = _deploy_turn
	slot["requirement"] = requirement.duplicate(true)
	slot["aura_scope"] = aura_scope
	slot["effect_config"] = effect_config.duplicate(true)
	slot["max_level"] = max_level
	slot["base_value"] = base_value
	slot["affiliated_chars"] = []
	var activated: bool = _check_condition(requirement)
	if activated:
		slot["state"] = SlotState.ACTIVE
		_invoke_cb(effect_register_cb, [card_instance_id, template_id, {"aura_scope": aura_scope}])
	_emit_safe(&"formation_deployed", [formation_id, target_slot, template_id, _deploy_turn])
	if activated:
		_emit_safe(&"formation_activated", [formation_id, target_slot, template_id, "deployed"])
	var reason: String = "deployed_active" if activated else "deployed_inactive"
	return {"success": true, "formation_id": formation_id, "slot_index": target_slot, "activated": activated, "reason": reason}


## 覆盖阵法位（AC-005）——严格顺序：旧阵 DISCARDED → 清除归属 → 移除旧效果 → 新阵部署 → 判定 → 注册新效果。[br]
## [br][param target_slot] 被覆盖的阵位索引。[br]
## [br][b]返回[/b]: [code]{success, formation_id, slot_index, activated, reason}[/code]。
func overwrite_formation(card_instance_id: int, template_id: StringName, target_slot: int,
		requirement: Dictionary = {}, aura_scope: int = AuraScope.AFFILIATED_CHARACTERS,
		effect_config: Dictionary = {}, max_level: int = 0, base_value: float = 0.0) -> Dictionary:
	var old_slot: Dictionary = _slots.get(target_slot, {})
	if old_slot.is_empty() or old_slot.get("state", SlotState.EMPTY) == SlotState.EMPTY:
		return {"success": false, "formation_id": -1, "slot_index": target_slot, "activated": false, "reason": "no_existing_formation"}
	var old_formation_id: int = old_slot["formation_id"]
	var old_card_instance_id: int = old_slot["card_instance_id"]
	# 1. 旧阵法 → DISCARDED（瞬态——立即被新阵覆盖）
	old_slot["state"] = SlotState.DISCARDED
	# 2. 清除旧阵法全部归属
	_clear_affiliations_by_formation(old_formation_id)
	# 3. CardEffectEngine.remove_effects_by_source（先移除旧效果）
	_invoke_cb(effect_remove_cb, [old_card_instance_id])
	_invoke_cb(card_discard_cb, [old_card_instance_id])
	# 4. 新阵法部署到该阵位
	var formation_id: int = _next_formation_id
	_next_formation_id += 1
	old_slot["formation_id"] = formation_id
	old_slot["card_instance_id"] = card_instance_id
	old_slot["template_id"] = template_id
	old_slot["state"] = SlotState.DEPLOYED_UNACTIVE
	old_slot["deployed_turn"] = _deploy_turn
	old_slot["requirement"] = requirement.duplicate(true)
	old_slot["aura_scope"] = aura_scope
	old_slot["effect_config"] = effect_config.duplicate(true)
	old_slot["max_level"] = max_level
	old_slot["base_value"] = base_value
	old_slot["affiliated_chars"] = []
	# 5. 立即判定条件
	var activated: bool = _check_condition(requirement)
	if activated:
		old_slot["state"] = SlotState.ACTIVE
		_invoke_cb(effect_register_cb, [card_instance_id, template_id, {"aura_scope": aura_scope}])
	# 6. 发射信号
	_emit_safe(&"formation_overwritten", [old_formation_id, formation_id, target_slot])
	_emit_safe(&"formation_deployed", [formation_id, target_slot, template_id, _deploy_turn])
	if activated:
		_emit_safe(&"formation_activated", [formation_id, target_slot, template_id, "overwrite"])
	var reason: String = "overwrite_active" if activated else "overwrite_inactive"
	return {"success": true, "formation_id": formation_id, "slot_index": target_slot, "activated": activated, "reason": reason}


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


## 动态获取 FactionSystem Autoload 节点。
func _get_faction_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/FactionSystem")


## Cat 2b 信号安全发射——经 GSM._emit_signal_safe 路由（ADR-0007 信号链深度追踪）。
func _emit_safe(signal_name: StringName, args: Array) -> void:
	if GameStateManager != null and GameStateManager.get_script().has_method("_emit_signal_safe"):
		GameStateManager.get_script()._emit_signal_safe(self, signal_name, args)
	else:
		var call_args: Array = [signal_name]
		call_args.append_array(args)
		callv("emit_signal", call_args)


## 调用可注入存根——无效 Callable 静默跳过。
func _invoke_cb(cb: Callable, args: Array) -> void:
	if cb.is_valid():
		cb.callv(args)


## 清空全部阵位和归属（测试辅助 + Story 004 clear_all_formations 基础）。[br]
## [b]注意[/b]：本方法重置 [member _next_formation_id] 为 1——便于测试断言。[br]
## Story 004 公共 [code]clear_all_formations()[/code] 须按 ADR-0024 §验证标准保留 [member _next_formation_id]。
func _clear_all() -> void:
	_reset_slots()
	_affiliations.clear()
	_next_formation_id = 1
	_deploy_turn = 0


# === 条件实时重判（Story 002）=================================================

## 条件重判——遍历 3 个阵法位，对每个非 EMPTY 阵法调用条件判定。[br]
## 条件变化时更新状态（DEPLOYED_UNACTIVE→ACTIVE 或 ACTIVE→DEPLOYED_UNACTIVE）。[br]
## [b]不发射信号[/b]——仅返回变更列表，由调用方 [method _on_field_changed] 批量发射
## [signal formation_condition_reevaluated]（避免信号级联/重入，ADR-0024 §风险）。[br]
## [br][b]返回[/b]: [code]Array[/code]——元素 [code]{formation_id, slot_index, old_state, new_state, reason}[/code]。
func recheck_all_conditions() -> Array:
	var changes: Array = []
	for i in range(MAX_SLOTS):
		var slot: Dictionary = _slots[i]
		var state: int = slot.get("state", SlotState.EMPTY)
		if state == SlotState.EMPTY or state == SlotState.DISCARDED:
			continue
		var requirement: Dictionary = slot.get("requirement", {})
		var now_met: bool = _check_condition(requirement)
		var was_active: bool = (state == SlotState.ACTIVE)
		if now_met and not was_active:
			# UNACTIVE → ACTIVE
			slot["state"] = SlotState.ACTIVE
			changes.append({"formation_id": slot["formation_id"], "slot_index": i,
				"old_state": SlotState.DEPLOYED_UNACTIVE, "new_state": SlotState.ACTIVE,
				"reason": "condition_met"})
		elif not now_met and was_active:
			# ACTIVE → UNACTIVE
			slot["state"] = SlotState.DEPLOYED_UNACTIVE
			changes.append({"formation_id": slot["formation_id"], "slot_index": i,
				"old_state": SlotState.ACTIVE, "new_state": SlotState.DEPLOYED_UNACTIVE,
				"reason": "condition_lost"})
	return changes


## DeploymentSystem 信号处理器——角色上场/阵亡/离场时触发条件重判。[br]
## [br]流程（ADR-0024 §信号处理器）：[br]
##   1. 调用 [method recheck_all_conditions] 获取变更列表[br]
##   2. 逐个处理状态变更的副作用（ACTIVE→注册 persistent effect；UNACTIVE→移除+清除归属）[br]
##   3. 若变更非空 → 批量发射 [signal formation_condition_reevaluated]
func _on_field_changed(_character_id: int = -1, _slot_index: int = -1, _extra: Variant = null) -> void:
	var changes: Array = recheck_all_conditions()
	for change: Dictionary in changes:
		var slot: Dictionary = _slots[change["slot_index"]]
		var formation_id: int = change["formation_id"]
		var card_instance_id: int = slot.get("card_instance_id", -1)
		var template_id: StringName = slot.get("template_id", &"")
		if change["new_state"] == SlotState.ACTIVE:
			# UNACTIVE → ACTIVE：注册效果 + 发射 activated
			_invoke_cb(effect_register_cb, [card_instance_id, template_id, {"aura_scope": slot.get("aura_scope", AuraScope.AFFILIATED_CHARACTERS)}])
			_emit_safe(&"formation_activated", [formation_id, change["slot_index"], template_id, "recheck"])
		else:
			# ACTIVE → UNACTIVE：移除效果 + 清除归属 + 发射 deactivated
			_invoke_cb(effect_remove_cb, [card_instance_id])
			_clear_affiliations_by_formation(formation_id)
			_emit_safe(&"formation_deactivated", [formation_id, change["slot_index"], "condition_lost"])
	if not changes.is_empty():
		_emit_safe(&"formation_condition_reevaluated", [changes])


# === 光环查询（Story 003）====================================================

## 战斗热路径 O(1) 查询——计算角色从归属阵法获得的总光环加成（AC-001/002）。[br]
## 梯度阵法实时计算当前场上同阵营人数 → 确定效果等级 → 返回梯度值。[br]
## 固定阵法从 [code]effect_config[stat_name][/code] 读取。[br]
## [br][param character_id] 角色 ID。[br]
## [br][param stat_name] 属性名（如 "hp"/"def"/"atk"）。[br]
## [br][b]返回[/b]: [code]{total_bonus: float, breakdown: Array}[/code]——未归属/非 ACTIVE 返回 0。[br]
## [br]来源: ADR-0024 §关键接口 §梯度阵法动态效果计算。
func get_aura_bonus(character_id: int, stat_name: String) -> Dictionary:
	if not _affiliations.has(character_id):
		return {"total_bonus": 0.0, "breakdown": []}
	var formation_id: int = _affiliations[character_id]
	if not is_formation_active(formation_id):
		return {"total_bonus": 0.0, "breakdown": []}
	var slot: Dictionary = _get_slot_by_formation(formation_id)
	if slot.is_empty():
		return {"total_bonus": 0.0, "breakdown": []}
	var aura_scope: int = slot.get("aura_scope", AuraScope.AFFILIATED_CHARACTERS)
	var bonus: float = 0.0
	var breakdown: Array = []
	# 梯度阵法——requirement 含 tag_id + max_level > 0 时走梯度计算
	var requirement: Dictionary = slot.get("requirement", {})
	var max_level: int = int(slot.get("max_level", 0))
	if max_level > 0 and requirement.has("tag_id"):
		bonus = _calculate_gradient_aura(formation_id, stat_name)
	else:
		# 固定阵法——从 effect_config 读取
		bonus = _get_fixed_bonus(slot, stat_name)
	if bonus != 0.0:
		breakdown.append({
			"formation_id": formation_id,
			"template_id": slot.get("template_id", &""),
			"aura_scope": aura_scope,
			"bonus": bonus,
			"stat": stat_name,
		})
	return {"total_bonus": bonus, "breakdown": breakdown}


## 梯度阵法光环加成——实时计算当前场上同阵营人数（AC-003~007）。[br]
## [b]公式[/b]: [code]effect_value = base_value × min(count_on_field(tag_id) - 1, max_level)[/code][br]
## 门槛 ≥2 人——不足返回 0.0。[br]
## [br][param formation_id] 阵法 ID。[br]
## [br][param stat_name] 属性名（固定阵法 effect_config 的 key，梯度阵法不区分 stat）。[br]
## [br][b]返回[/b]: 梯度效果值 float。[br]
## [br]来源: ADR-0024 §梯度阵法动态效果计算。
func _calculate_gradient_aura(formation_id: int, _stat_name: String) -> float:
	var slot: Dictionary = _get_slot_by_formation(formation_id)
	if slot.is_empty():
		return 0.0
	var requirement: Dictionary = slot.get("requirement", {})
	var tag_id: StringName = requirement.get("tag_id", &"")
	if tag_id.is_empty():
		return 0.0
	var count_on_field: int = _query_count_on_field(tag_id)
	if count_on_field < 2:
		return 0.0
	var max_level: int = int(slot.get("max_level", 0))
	if max_level <= 0:
		return 0.0
	var effect_level: int = mini(count_on_field - 1, max_level)
	var base_value: float = float(slot.get("base_value", 0.0))
	return base_value * float(effect_level)


## 固定阵法属性增益——从 effect_config 读取指定 stat 的加成值。[br]
## [br][param slot] 阵法位 Dictionary。[br]
## [br][param stat_name] 属性名。[br]
## [br][b]返回[/b]: 加成值 float（无配置返回 0.0）。
func _get_fixed_bonus(slot: Dictionary, stat_name: String) -> float:
	if fixed_bonus_cb.is_valid():
		return float(fixed_bonus_cb.call(slot.get("formation_id", -1), stat_name))
	var effect_config: Dictionary = slot.get("effect_config", {})
	return float(effect_config.get(stat_name, 0.0))


## 查询场上某阵营角色数——优先 count_on_field_cb，否则走 FactionSystem。[br]
## [br][param tag_id] 阵营标签 ID。[br]
## [br][b]返回[/b]: 场上该阵营角色数 int。
func _query_count_on_field(tag_id: StringName) -> int:
	if count_on_field_cb.is_valid():
		return int(count_on_field_cb.call(tag_id))
	var fs: Node = _get_faction_system()
	if fs != null and fs.has_method("count_on_field"):
		return int(fs.call("count_on_field", tag_id))
	return 0


# === 序列化 / 反序列化 / 快照导出（Story 004）=================================

## 序列化全部阵位数据 + 归属关系——战斗结束时导出快照（AC-001）。[br]
## [br][b]返回[/b]: [code]{slots: Array, affiliations: Dictionary, next_formation_id: int}[/code]——
## slots 为 3 阵位序列化列表（StringName→String 转换确保 JSON 可序列化）。[br]
## [br]来源: ADR-0024 §GSM 边界 §serialize_all。
func serialize_all() -> Dictionary:
	var slots_data: Array = []
	for i in range(MAX_SLOTS):
		slots_data.append(_serialize_slot(_slots[i]))
	var aff_data: Dictionary = {}
	for char_id: int in _affiliations.keys():
		aff_data[char_id] = _affiliations[char_id]
	return {
		"slots": slots_data,
		"affiliations": aff_data,
		"next_formation_id": _next_formation_id,
	}


## 序列化单个阵位——StringName→String 确保 JSON 可序列化（ADR-0002 存档规范）。
func _serialize_slot(slot: Dictionary) -> Dictionary:
	return {
		"formation_id": slot.get("formation_id", -1),
		"card_instance_id": slot.get("card_instance_id", -1),
		"template_id": str(slot.get("template_id", &"")),
		"state": slot.get("state", SlotState.EMPTY),
		"deployed_turn": slot.get("deployed_turn", -1),
		"requirement": (slot.get("requirement", {}) as Dictionary).duplicate(true),
		"aura_scope": slot.get("aura_scope", AuraScope.AFFILIATED_CHARACTERS),
		"effect_config": (slot.get("effect_config", {}) as Dictionary).duplicate(true),
		"max_level": slot.get("max_level", 0),
		"base_value": slot.get("base_value", 0.0),
		"affiliated_chars": (slot.get("affiliated_chars", []) as Array).duplicate(true),
	}


## 从快照恢复阵位状态 + 归属关系（AC-003/004）。[br]
## 逐条验证 affiliations 中的 character_id——验证失败跳过 + push_warning（不阻塞阵法自身状态恢复）。[br]
## [br][param data] 快照 Dictionary（含 slots/affiliations/next_formation_id）。
func deserialize_all(data: Dictionary) -> void:
	_reset_slots()
	_affiliations.clear()
	var slots_data: Array = data.get("slots", [])
	for i in range(mini(slots_data.size(), MAX_SLOTS)):
		_slots[i] = _deserialize_slot(slots_data[i])
	var aff_data: Dictionary = data.get("affiliations", {})
	for key: Variant in aff_data.keys():
		var char_id: int = int(key)
		var formation_id: int = int(aff_data[key])
		if _validate_character_exists(char_id):
			_affiliations[char_id] = formation_id
		else:
			push_warning("FormationSystem.deserialize_all: character_id=%d 不存在，跳过归属关系" % char_id)
	# 重建 affiliated_chars 派生索引——以 _affiliations 为唯一真理来源（lead-programmer C1 / qa-lead GAP-001）
	for i in range(MAX_SLOTS):
		_slots[i]["affiliated_chars"] = []
	for char_id: int in _affiliations.keys():
		var slot: Dictionary = _get_slot_by_formation(_affiliations[char_id])
		if not slot.is_empty() and slot.has("affiliated_chars"):
			(slot["affiliated_chars"] as Array).append(char_id)
	_next_formation_id = int(data.get("next_formation_id", 1))


## 反序列化单个阵位——键归一（int/String key 均接受，JSON round-trip 安全）。[br]
## 对嵌套集合字段做类型守卫——快照损坏时回退默认值（lead-programmer C3）。
func _deserialize_slot(slot_data: Dictionary) -> Dictionary:
	var slot: Dictionary = _make_empty_slot()
	slot["formation_id"] = int(slot_data.get("formation_id", -1))
	slot["card_instance_id"] = int(slot_data.get("card_instance_id", -1))
	slot["template_id"] = StringName(str(slot_data.get("template_id", "")))
	slot["state"] = int(slot_data.get("state", SlotState.EMPTY))
	slot["deployed_turn"] = int(slot_data.get("deployed_turn", -1))
	var req: Variant = slot_data.get("requirement", {})
	slot["requirement"] = (req as Dictionary).duplicate(true) if req is Dictionary else {}
	slot["aura_scope"] = int(slot_data.get("aura_scope", AuraScope.AFFILIATED_CHARACTERS))
	var ec: Variant = slot_data.get("effect_config", {})
	slot["effect_config"] = (ec as Dictionary).duplicate(true) if ec is Dictionary else {}
	slot["max_level"] = int(slot_data.get("max_level", 0))
	slot["base_value"] = float(slot_data.get("base_value", 0.0))
	var ac: Variant = slot_data.get("affiliated_chars", [])
	slot["affiliated_chars"] = (ac as Array).duplicate(true) if ac is Array else []
	return slot


## 验证角色是否存在——优先 character_exists_cb，否则默认 true。[br]
## [br][param character_id] 角色 ID。[br]
## [br][b]返回[/b]: true 表示存在。
func _validate_character_exists(character_id: int) -> bool:
	if character_exists_cb.is_valid():
		return bool(character_exists_cb.call(character_id))
	return true


## 写阵法快照至 GSM battle.formation_snapshot（战斗结束导出委托）。[br]
## [br]GSM 不可用时静默跳过（is_instance_valid + has_method 双守卫）。[br]
## [br]来源: ADR-0024 §GSM 边界 §serialize_all。
func write_snapshot_to_gsm() -> void:
	var gsm: Node = _get_gsm()
	if gsm == null or not gsm.has_method("_set_battle_formation_snapshot"):
		return  # GSM 不可用——静默跳过
	gsm.call("_set_battle_formation_snapshot", serialize_all())


## 动态获取 GSM Autoload 节点（同 DeploymentSystem 先例）。
func _get_gsm() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/GameStateManager")


## 清空全部阵位和归属——战斗结束清理（AC-005）。[br]
## [b]注意[/b]：[member _next_formation_id] 保留（ADR-0024 §验证标准——不重置，避免 ID 冲突）。[br]
## 同时清理 [member _pending_affiliations] 延迟队列（lead-programmer C2——跨战斗遗留防护）。
func clear_all_formations() -> void:
	_reset_slots()
	_affiliations.clear()
	_pending_affiliations.clear()
	_deploy_turn = 0
