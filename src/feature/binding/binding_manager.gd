## BindingManager —— 功法/法宝绑定系统 Autoload（#13）。[b]链尾：绑定生命周期编排面[/b]。
##
## Feature 层 Autoload。持有运行时绑定注册表——三个同步索引
## [member _bindings] + [member _by_character] + [member _card_to_character]。
## 采用与 ADR-0011 StatusEffectSystem 相同的 GSM 边界先例：战斗期间绑定数据
## 不经过 GSM，仅战斗结束时 [method serialize_all]（Story 004）导出快照。
##
## [b]Autoload 顺序[/b]：GSM #1 → ... → RealmSystem #11 → ProgressionSystem #12 → BindingManager #13。[br]
## [b]继承链[/b]（各段守 300 行内，成员名与访问路径逐字不变）：[br]
## [code]  binding_manager_contract.gd [/code] ← 定义层：7 信号 / 4 常量 / 16 实例字段 / 依赖注入[br]
## [code]  binding_manager_registry.gd [/code] ← 存取层：三索引读写 + 查询 API + 绑定位上限[br]
## [code]  binding_manager_compute.gd  [/code] ← 计算层：叠加公式 / 加成汇总 / 减伤来源 / 上下文[br]
## [code]  binding_manager_serialize.gd[/code] ← 序列化层：记录序列化 + 快照导出 / 恢复[br]
## [code]  binding_manager.gd          [/code] ← 本层：绑定生命周期编排（Autoload 入口不变）[br]
##
## [b]本层职责[/b]：[b]对外的动作入口[/b]——[method bind_card] / [method stack_card] /
## [method overwrite_binding] / [method can_bind] / [method remove_binding] /
## [method remove_all_bindings] / [method suspend_bindings] / [method restore_bindings]。
## 每个入口的责任是编排（校验 → 改三索引 → 调存根回调 → 发信号），具体存取住
## [code]binding_manager_registry.gd[/code]、数值住 [code]binding_manager_compute.gd[/code]。[br]
## [b]为什么这里不是「一行转发」的门面[/b]：继承链下同名方法已沿链解析，转发器是净增代码，
## 且转发器与被转发实体漂移正是本次拆分要消灭的失效模式。[br]
## [b]本 Story 范围[/b]（4-10 + 4-11）：BindingRecord 实例模型 + 三索引注册表 +
## [method _register_binding] / [method _unregister_binding] 原子同步 + 查询 API +
## 绑定生命周期 API + 本命判定 [method _determine_native] +
## 叠加公式 [method compute_effective_value]。[br]
## [b]不注册进 project.godot[/b]——待 CombatSystem 接线（4-22）后统一注册（4-0b 终验）。[br]
## [b]后续 story[/b]：7 个 Cat 2b 信号（4-12，已落地）、serialize_all/deserialize_all 快照（4-13，已落地）。
##
## 来源: ADR-0013 §决策 §对象模型 §关键接口 / GDD binding-system.md §1 绑定数据结构。
extends "res://src/feature/binding/binding_manager_serialize.gd"
# class_name BindingManager —— 不声明：Autoload 全局单例，
# 声明 class_name 会与全局名冲突，导致 BM_SCRIPT.new() 测试实例无法解析。
# 测试以 var bm: Node 持有 + 动态分派访问（同 GSM/RealmSystem/CostSystem 先例，
# 控制清单 2026-08-05 规则）。


## 绑定到空位——创建 BindingRecord(stack_count=1) 并注册三索引（AC-001）。[br]
## 无空位返回 [code]slot_full[/code]（不触发覆盖——覆盖走 [method overwrite_binding]）。[br]
## 同一 card_instance_id 已绑定返回 [code]card_already_bound[/code]（AC-018）。[br]
## [br][param card_instance_id] 卡牌实例 ID。[br]
## [br][param template_id] 卡牌模板 ID。[br]
## [br][param character_id] 目标角色 ID。[br]
## [br][param slot_type] [enum BindingRecord.BindingSlot] 值。[br]
## [br][param native_owner] 卡牌本命宿主（空 = 无本命资格，AC-005）。[br]
## [br][param character_card_id] 目标角色的 card_id（本命前缀匹配用）。[br]
## [br][b]返回[/b]: [code]{success, binding_id, reason}[/code]——reason: bound / slot_full / card_already_bound。
## [b]invalid_character 延后[/b]：无 Character 系统可校验角色有效性（sprint 风险登记），
## 该 reason 留待战斗 Epic 接入角色系统后由调用方前置校验（Story 004 / CombatSystem 编排）。
func bind_card(card_instance_id: int, template_id: StringName, character_id: int, slot_type: int,
		native_owner: StringName = &"", character_card_id: StringName = &"") -> Dictionary:
	if _card_to_character.has(card_instance_id):
		return {"success": false, "binding_id": -1, "reason": "card_already_bound"}
	var limit: int = _get_slot_limit(slot_type)
	if _count_bound_slots(character_id, slot_type) >= limit:
		return {"success": false, "binding_id": -1, "reason": "slot_full"}
	var slot_index: int = _find_free_slot_index(character_id, slot_type, limit)
	var record: BindingRecord = _make_record(card_instance_id, template_id, character_id, slot_type, slot_index)
	var native: Dictionary = _determine_native(character_id, native_owner, character_card_id, slot_type)
	record.is_native = native["is_native"]
	record.native_multiplier = native["native_multiplier"]
	_register_binding(record)
	_invoke_cb(effect_register_cb, [card_instance_id, template_id, character_id, get_binding_context(card_instance_id)])
	_emit_safe(&"binding_applied", [record.binding_id, card_instance_id, template_id, character_id, slot_type, record.is_native])
	if record.is_native:
		_emit_safe(&"native_activated", [record.binding_id, template_id, character_id])
	return {"success": true, "binding_id": record.binding_id, "reason": "bound"}


## 同名叠加——[code]stack_count < stack_limit[/code] 时递增、新实例加入 [member BindingRecord.stack_slots]、
## 共享槽位（slot_index 不变）（AC-007）。[br]
## 达上限返回 [code]stack_limit_reached[/code]；无已有绑定返回 [code]no_existing_binding[/code]（AC-008）。[br]
## 同一 card_instance_id 已绑定返回 [code]card_already_bound[/code]（防三索引失同步）。[br]
## [br][param card_instance_id] 新叠加副本的卡牌实例 ID。[br]
## [br][param template_id] 卡牌模板 ID（同名判定）。[br]
## [br][param character_id] 目标角色 ID。[br]
## [br][param stack_limit] 同名叠加上限（来自 cardTemplate.stack_limit）。[br]
## [br][b]返回[/b]: [code]{stacked, stack_count, reason}[/code]。
func stack_card(card_instance_id: int, template_id: StringName, character_id: int, stack_limit: int = 3) -> Dictionary:
	if _card_to_character.has(card_instance_id):
		return {"stacked": false, "stack_count": 0, "reason": "card_already_bound"}
	var existing: BindingRecord = _find_same_template_binding(character_id, template_id)
	if existing == null:
		return {"stacked": false, "stack_count": 0, "reason": "no_existing_binding"}
	if existing.stack_count >= stack_limit:
		return {"stacked": false, "stack_count": existing.stack_count, "reason": "stack_limit_reached"}
	existing.stack_count += 1
	existing.stack_slots.append(card_instance_id)
	_card_to_character[card_instance_id] = character_id
	_emit_safe(&"binding_stacked", [existing.binding_id, template_id, character_id, existing.stack_count])
	return {"stacked": true, "stack_count": existing.stack_count, "reason": "stacked"}


## 覆盖已有绑定位（AC-010）——严格顺序：旧效果移除 → 旧卡进弃牌堆 → 移除旧记录 → 新卡落位 → 新效果注册。[br]
## 覆盖叠加中的同名卡时只移除一层（AC-011）：[code]stack_count -= 1[/code]；[code]stack_count == 0[/code]
## 时删除 BindingRecord（AC-012）。[br]
## 同一 card_instance_id 已绑定返回 [code]card_already_bound[/code]（防三索引失同步）。[br]
## [br][param card_instance_id] 新卡实例 ID。[br]
## [br][param template_id] 新卡模板 ID。[br]
## [br][param character_id] 目标角色 ID。[br]
## [br][param slot_index] 被覆盖的槽位索引。[br]
## [br][param native_owner] 新卡本命宿主。[br]
## [br][param character_card_id] 目标角色 card_id。[br]
## [br][b]返回[/b]: [code]{success, binding_id, reason}[/code]。
func overwrite_binding(card_instance_id: int, template_id: StringName, character_id: int, slot_index: int,
		native_owner: StringName = &"", character_card_id: StringName = &"") -> Dictionary:
	if _card_to_character.has(card_instance_id):
		return {"success": false, "binding_id": -1, "reason": "card_already_bound"}
	var existing: BindingRecord = _find_binding_at_slot(character_id, slot_index)
	if existing == null:
		return {"success": false, "binding_id": -1, "reason": "no_existing_binding"}
	# 覆盖叠加中的同名卡——只移除一层（AC-011）
	if existing.stack_count > 1:
		var covered_cid: int = existing.stack_slots[existing.stack_slots.size() - 1]
		# 效果模型（lead-programmer C3，延后 Story 004）：当前效果注册为"每绑定一次"
		# （bind_card 调 effect_register_cb），叠加层不逐张注册——effect_remove_cb 此处按被覆盖
		# 实例逐张移除，与 stack_card 不逐张注册存在不对称。CardEffectEngine 接口落地后
		# （Story 004）统一为"每绑定持 context（stack_count 动态读取）"或"逐层注册"二选一。
		_invoke_cb(effect_remove_cb, [covered_cid])
		_card_to_character.erase(covered_cid)
		existing.stack_slots.erase(covered_cid)
		existing.stack_count -= 1
		_invoke_cb(card_discard_cb, [covered_cid])
		_emit_safe(&"binding_removed", [existing.binding_id, covered_cid, character_id, "overwritten"])
		return {"success": true, "binding_id": existing.binding_id, "reason": "overwritten_stack"}
	# stack_count == 1——完全覆盖（AC-010/AC-012）
	_invoke_cb(effect_remove_cb, [existing.card_instance_id])
	_invoke_cb(card_discard_cb, [existing.card_instance_id])
	var old_binding_id: int = existing.binding_id
	var old_card_instance_id: int = existing.card_instance_id
	_unregister_binding(existing)
	_emit_safe(&"binding_removed", [old_binding_id, old_card_instance_id, character_id, "overwritten"])
	var record: BindingRecord = _make_record(card_instance_id, template_id, character_id, existing.slot_type, slot_index)
	var native: Dictionary = _determine_native(character_id, native_owner, character_card_id, record.slot_type)
	record.is_native = native["is_native"]
	record.native_multiplier = native["native_multiplier"]
	_register_binding(record)
	_invoke_cb(effect_register_cb, [card_instance_id, template_id, character_id, get_binding_context(card_instance_id)])
	_emit_safe(&"binding_applied", [record.binding_id, card_instance_id, template_id, character_id, record.slot_type, record.is_native])
	if record.is_native:
		_emit_safe(&"native_activated", [record.binding_id, template_id, character_id])
	_emit_safe(&"binding_overwritten", [old_binding_id, record.binding_id, character_id, slot_index])
	return {"success": true, "binding_id": record.binding_id, "reason": "overwritten"}


## 绑定前预检查（AC-003）——UI 着色角色选择面板的四种状态。[br]
## 优先级：同名叠加上限（灰）> 同名未达上限（绿）> 有空位（蓝）> 无空位可覆盖（橙）。[br]
## [br][param character_id] 目标角色 ID。[br]
## [br][param slot_type] [enum BindingRecord.BindingSlot] 值。[br]
## [br][param template_id] 卡牌模板 ID（同名判定）。[br]
## [br][param stack_limit] 同名叠加上限。[br]
## [br][b]返回[/b]: [code]{can_bind, can_stack, must_overwrite, slot_index, reason}[/code]。
func can_bind(character_id: int, slot_type: int, template_id: StringName, stack_limit: int = 3) -> Dictionary:
	var same: BindingRecord = _find_same_template_binding(character_id, template_id)
	if same != null:
		if same.stack_count >= stack_limit:
			return {"can_bind": false, "can_stack": false, "must_overwrite": false, "slot_index": -1, "reason": "stack_limit_reached"}
		return {"can_bind": false, "can_stack": true, "must_overwrite": false, "slot_index": same.slot_index, "reason": "can_stack"}
	var limit: int = _get_slot_limit(slot_type)
	var used: int = _count_bound_slots(character_id, slot_type)
	if used < limit:
		return {"can_bind": true, "can_stack": false, "must_overwrite": false, "slot_index": _find_free_slot_index(character_id, slot_type, limit), "reason": "slot_available"}
	return {"can_bind": false, "can_stack": false, "must_overwrite": true, "slot_index": -1, "reason": "must_overwrite"}


## 移除单个绑定（AC-013）——从三索引清除该条目及其全部叠层实例的卡映射。[br]
## [br][param binding_id] 待移除的绑定 ID。
func remove_binding(binding_id: int) -> void:
	if not _bindings.has(binding_id):
		return
	var record: BindingRecord = _bindings[binding_id]
	var card_instance_id: int = record.card_instance_id
	var character_id: int = record.bound_character_id
	for cid: int in record.stack_slots:
		if _card_to_character.has(cid):
			_card_to_character.erase(cid)
	_invoke_cb(effect_remove_cb, [record.card_instance_id])
	_unregister_binding(record)
	_emit_safe(&"binding_removed", [binding_id, card_instance_id, character_id, "removed"])


## 移除角色全部绑定（AC-013/AC-014）——角色阵亡时清除全部条目并返回序列化数据供洗回。[br]
## 每张叠层实例独立洗回牌库（存根回调），非弃牌堆、非永久丢失。[br]
## [br][param character_id] 阵亡角色 ID。[br]
## [br][b]返回[/b]: [code]Array[Dictionary][/code]——被移除的绑定记录序列化数据。
func remove_all_bindings(character_id: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var ids: Array[int] = get_binding_ids_by_character(character_id).duplicate()
	for binding_id: int in ids:
		if not _bindings.has(binding_id):
			continue
		var record: BindingRecord = _bindings[binding_id]
		result.append(_serialize_record(record))
		for cid: int in record.stack_slots:
			_invoke_cb(effect_remove_cb, [cid])
			_invoke_cb(card_shuffle_cb, [cid])
			if _card_to_character.has(cid):
				_card_to_character.erase(cid)
		_unregister_binding(record)
		_emit_safe(&"binding_removed", [binding_id, record.card_instance_id, character_id, "death"])
	return result


## 角色离场暂挂（AC-015）——所有 BindingRecord.is_suspended = true，不进弃牌堆。[br]
## [br][param character_id] 离场角色 ID。
func suspend_bindings(character_id: int) -> void:
	var ids: Array[int] = get_binding_ids_by_character(character_id).duplicate()
	var card_ids: Array[int] = []
	for binding_id: int in ids:
		if _bindings.has(binding_id):
			(_bindings[binding_id] as BindingRecord).is_suspended = true
			card_ids.append((_bindings[binding_id] as BindingRecord).card_instance_id)
	_invoke_cb(effect_suspend_cb, [character_id, card_ids])
	_emit_safe(&"binding_suspended", [character_id, ids])


## 角色重新上场恢复（AC-015）——验证 card_instance_id 仍存在则恢复，已不存在则删除变空位（不报错）。[br]
## [b]叠层验证延后[/b]：当前仅验证主实例 [member BindingRecord.card_instance_id]；
## 叠层实例 [member BindingRecord.stack_slots] 的逐张验证延后至 Story 004
## （[code]card_exists_cb[/code] 接 CardSystem 收藏池后，restore 路径统一逐层校验）。[br]
## [br][param character_id] 重新上场角色 ID。
func restore_bindings(character_id: int) -> void:
	var ids: Array[int] = get_binding_ids_by_character(character_id).duplicate()
	var restored_ids: Array[int] = []
	var restored_card_ids: Array[int] = []
	for binding_id: int in ids:
		if not _bindings.has(binding_id):
			continue
		var record: BindingRecord = _bindings[binding_id]
		if _query_card_exists(record.card_instance_id):
			record.is_suspended = false
			restored_ids.append(binding_id)
			restored_card_ids.append(record.card_instance_id)
		else:
			for cid: int in record.stack_slots:
				if _card_to_character.has(cid):
					_card_to_character.erase(cid)
			_unregister_binding(record)
	_invoke_cb(effect_restore_cb, [character_id, restored_card_ids])
	_emit_safe(&"binding_restored", [character_id, restored_ids])
