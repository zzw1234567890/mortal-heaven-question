extends RefCounted
## BindingSerializer —— 绑定序列化/反序列化/快照导出子模块（从 binding_manager.gd 拆分）。
##
## 持有对 BindingManager 父节点的引用，通过它访问 _bindings / GSM。[br]
## [br]来源: ADR-0013 §序列化 / GDD binding-system.md §快照导出。[br]
## [br]Sprint 8 Story 8-12：从 binding_manager.gd 拆分。

## 父节点引用——BindingManager Autoload 实例。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


## 序列化全部活跃绑定记录——战斗结束时导出快照（AC-001）。[br]
## 遍历 [member _bindings] 全部 BindingRecord → 序列化为 Dictionary 列表。[br]
## 含全部字段：binding_id / card_instance_id / card_template_id / card_name / card_rarity /
## slot_type / slot_index / bound_character_id / is_native / native_multiplier /
## activated_turn / is_suspended / stack_slots / stack_count。[br]
## [br][b]返回[/b]: [code]{"bindings": Array[Dictionary]}[/code]——快照根节点含 bindings 列表。
## [b]性能[/b]：化神期峰值 ~180 BindingRecord → ~36KB，battle_end 非热路径一次性执行。
## [b]card_name / card_rarity[/b]：本 Story 无 CardSystem 模板查询，两字段保持默认空值
## （延后同 Story 002 C6——战斗 Epic 接 CardSystem 后填充）。
func serialize_all() -> Dictionary:
	var records: Array = []
	var bindings: Dictionary = _parent.get("_bindings")
	for binding_id: int in bindings.keys():
		var record: BindingRecord = bindings[binding_id]
		records.append(_serialize_record(record))
	return {"bindings": records}


## 从快照恢复 BindingRecord——读档 / 战斗快照恢复（AC-003/AC-004）。[br]
## [b]尽力而为策略[/b]：逐条验证 card_instance_id（通过 [member card_exists_cb]），
## 失败跳过 + push_warning，其余正常恢复——不阻塞整体恢复。[br]
## [b]键归一[/b]：快照经 JSON round-trip 后 int-key 可能变 String——binding_id
## 统一 [code]int()[/code] 转换（同 DeploymentSystem deserialize 先例）。[br]
## [br][param data] 快照 Dictionary（[code]{"bindings": [...]}[/code]）。
func deserialize_all(data: Dictionary) -> void:
	_parent.call("_clear_all")
	var raw_bindings: Variant = data.get("bindings", [])
	if not raw_bindings is Array:
		push_warning("BindingManager.deserialize_all: 快照无 bindings 数组——跳过")
		return
	for entry: Variant in raw_bindings:
		if not entry is Dictionary:
			continue
		var d: Dictionary = entry
		var card_instance_id: int = int(d.get("card_instance_id", -1))
		if card_instance_id < 0:
			push_warning("BindingManager.deserialize_all: 条目缺 card_instance_id——跳过")
			continue
		if not _parent.call("_query_card_exists", card_instance_id):
			push_warning("BindingManager.deserialize_all: card_instance_id=%d 不存在——跳过" % card_instance_id)
			continue
		var record: BindingRecord = _deserialize_record(d)
		if record == null:
			continue
		_parent.call("_register_binding", record)
		# 叠层实例的 _card_to_character 映射——_register_binding 仅注册主实例，
		# 叠层实例需逐条补充（同 stack_card 路径的手动注册）
		var card_to_char: Dictionary = _parent.get("_card_to_character")
		for cid: int in record.stack_slots:
			if cid != record.card_instance_id:
				card_to_char[cid] = record.bound_character_id


## 写入快照到 GSM——serialize_all → GSM._set_battle_bindings。[br]
## [br][b]去重写入[/b]：GSM._set_battle_bindings 内部有去重逻辑。[br]
## [br]来源: ADR-0013 §GSM 边界 §serialize_all。
func write_snapshot_to_gsm() -> void:
	var snapshot: Dictionary = serialize_all()
	var gsm: Node = _parent.call("_get_gsm")
	if gsm != null and gsm.has_method("_set_battle_bindings"):
		gsm._set_battle_bindings(snapshot["bindings"])


## 从单条 BindingRecord 构建序列化 Dictionary。[br]
## [br][param record] 待序列化的 BindingRecord。[br]
## [br][b]返回[/b]: 含全部 14 个字段的 Dictionary。
func _serialize_record(record: BindingRecord) -> Dictionary:
	return {
		"binding_id": record.binding_id,
		"card_instance_id": record.card_instance_id,
		"card_template_id": record.card_template_id,
		"card_name": record.card_name,
		"card_rarity": record.card_rarity,
		"slot_type": record.slot_type,
		"slot_index": record.slot_index,
		"bound_character_id": record.bound_character_id,
		"is_native": record.is_native,
		"native_multiplier": record.native_multiplier,
		"activated_turn": record.activated_turn,
		"is_suspended": record.is_suspended,
		"stack_slots": record.stack_slots.duplicate(),
		"stack_count": record.stack_count,
	}


## 从快照 Dictionary 重建单条 BindingRecord。[br]
## [b]键归一[/b]：int-key 统一 [code]int()[/code] 转换。[br]
## [br][b]返回[/b]: 重建的 BindingRecord；非法数据返回 null。
func _deserialize_record(d: Dictionary) -> BindingRecord:
	var record: BindingRecord = BindingRecord.new()
	var next_id: int = _parent.get("_next_binding_id")
	record.binding_id = int(d.get("binding_id", next_id))
	if record.binding_id >= next_id:
		_parent.set("_next_binding_id", record.binding_id + 1)
	record.card_instance_id = int(d.get("card_instance_id", -1))
	if record.card_instance_id < 0:
		return null
	record.card_template_id = StringName(d.get("card_template_id", &""))
	record.card_name = str(d.get("card_name", ""))
	record.card_rarity = int(d.get("card_rarity", 0))
	record.slot_type = int(d.get("slot_type", BindingRecord.BindingSlot.GONGFA))
	record.slot_index = int(d.get("slot_index", 0))
	record.bound_character_id = int(d.get("bound_character_id", -1))
	if record.bound_character_id < 0:
		return null
	record.is_native = bool(d.get("is_native", false))
	record.native_multiplier = float(d.get("native_multiplier", 1.0))
	record.activated_turn = int(d.get("activated_turn", 0))
	record.is_suspended = bool(d.get("is_suspended", false))
	var raw_slots: Variant = d.get("stack_slots", [record.card_instance_id])
	if raw_slots is Array:
		for cid: Variant in raw_slots:
			record.stack_slots.append(int(cid))
	else:
		record.stack_slots.append(record.card_instance_id)
	record.stack_count = int(d.get("stack_count", 1))
	return record
