extends RefCounted
## FormationSerializer —— 阵法序列化/反序列化/快照导出子模块（从 formation_system.gd 拆分）。
##
## 持有对 FormationSystem 父节点的引用，通过它访问 _slots / _affiliations /
## _next_formation_id / MAX_SLOTS / SlotState 枚举 / _make_empty_slot /
## _reset_slots / _get_slot_by_formation 等状态和辅助方法。
##
## [br]来源: ADR-0024 §GSM 边界 §serialize_all / GDD formation-system.md §快照导出。
## [br]Sprint 9 Story 3：从 formation_system.gd 拆分。

## 父节点引用——FormationSystem Autoload 实例。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


## 序列化全部阵位数据 + 归属关系——战斗结束时导出快照（AC-001）。[br]
## [br][b]返回[/b]: [code]{slots: Array, affiliations: Dictionary, next_formation_id: int}[/code]——
## slots 为 3 阵位序列化列表（StringName→String 转换确保 JSON 可序列化）。[br]
## [br]来源: ADR-0024 §GSM 边界 §serialize_all。
func serialize_all() -> Dictionary:
	var max_slots: int = _parent.get("MAX_SLOTS")
	var slots: Dictionary = _parent.get("_slots")
	var slots_data: Array = []
	for i in range(max_slots):
		slots_data.append(_serialize_slot(slots[i]))
	var affiliations: Dictionary = _parent.get("_affiliations")
	var aff_data: Dictionary = {}
	for char_id: int in affiliations.keys():
		aff_data[char_id] = affiliations[char_id]
	return {
		"slots": slots_data,
		"affiliations": aff_data,
		"next_formation_id": _parent.get("_next_formation_id"),
	}


## 序列化单个阵位——StringName→String 确保 JSON 可序列化（ADR-0002 存档规范）。
func _serialize_slot(slot: Dictionary) -> Dictionary:
	return {
		"formation_id": slot.get("formation_id", -1),
		"card_instance_id": slot.get("card_instance_id", -1),
		"template_id": str(slot.get("template_id", &"")),
		"state": slot.get("state", 0),  # SlotState.EMPTY = 0
		"deployed_turn": slot.get("deployed_turn", -1),
		"requirement": (slot.get("requirement", {}) as Dictionary).duplicate(true),
		"aura_scope": slot.get("aura_scope", 1),  # AuraScope.AFFILIATED_CHARACTERS = 1
		"effect_config": (slot.get("effect_config", {}) as Dictionary).duplicate(true),
		"max_level": slot.get("max_level", 0),
		"base_value": slot.get("base_value", 0.0),
		"affiliated_chars": (slot.get("affiliated_chars", []) as Array).duplicate(true),
	}


## 从快照恢复阵位状态 + 归属关系（AC-003/004）。[br]
## 逐条验证 affiliations 中的 character_id——验证失败跳过 + push_warning（不阻塞阵法自身状态恢复）。[br]
## [br][param data] 快照 Dictionary（含 slots/affiliations/next_formation_id）。
func deserialize_all(data: Dictionary) -> void:
	_parent.call("_reset_slots")
	var affiliations: Dictionary = _parent.get("_affiliations")
	affiliations.clear()
	var max_slots: int = _parent.get("MAX_SLOTS")
	var slots: Dictionary = _parent.get("_slots")
	var slots_data: Array = data.get("slots", [])
	for i in range(mini(slots_data.size(), max_slots)):
		slots[i] = _deserialize_slot(slots_data[i])
	var aff_data: Dictionary = data.get("affiliations", {})
	for key: Variant in aff_data.keys():
		var char_id: int = int(key)
		var formation_id: int = int(aff_data[key])
		if _validate_character_exists(char_id):
			affiliations[char_id] = formation_id
		else:
			push_warning("FormationSystem.deserialize_all: character_id=%d 不存在，跳过归属关系" % char_id)
	# 重建 affiliated_chars 派生索引——以 _affiliations 为唯一真理来源（lead-programmer C1 / qa-lead GAP-001）
	for i in range(max_slots):
		slots[i]["affiliated_chars"] = []
	for char_id: int in affiliations.keys():
		var slot: Dictionary = _parent.call("_get_slot_by_formation", affiliations[char_id])
		if not slot.is_empty() and slot.has("affiliated_chars"):
			(slot["affiliated_chars"] as Array).append(char_id)
	_parent.set("_next_formation_id", int(data.get("next_formation_id", 1)))


## 反序列化单个阵位——键归一（int/String key 均接受，JSON round-trip 安全）。[br]
## 对嵌套集合字段做类型守卫——快照损坏时回退默认值（lead-programmer C3）。
func _deserialize_slot(slot_data: Dictionary) -> Dictionary:
	var slot: Dictionary = _parent.call("_make_empty_slot")
	slot["formation_id"] = int(slot_data.get("formation_id", -1))
	slot["card_instance_id"] = int(slot_data.get("card_instance_id", -1))
	slot["template_id"] = StringName(str(slot_data.get("template_id", "")))
	slot["state"] = int(slot_data.get("state", 0))  # SlotState.EMPTY = 0
	slot["deployed_turn"] = int(slot_data.get("deployed_turn", -1))
	var req: Variant = slot_data.get("requirement", {})
	slot["requirement"] = (req as Dictionary).duplicate(true) if req is Dictionary else {}
	slot["aura_scope"] = int(slot_data.get("aura_scope", 1))  # AuraScope.AFFILIATED_CHARACTERS = 1
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
	var cb: Callable = _parent.get("character_exists_cb")
	if cb.is_valid():
		return bool(cb.call(character_id))
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
