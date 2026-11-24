## BindingManager 序列化层——[b]单条序列化、全量快照导出与恢复[/b]住在这一层。
##
## [b]本层职责[/b]：把绑定表在「运行时对象」与「可落盘的 Dictionary」之间来回搬——
## [method serialize_all] 导出全部 BindingRecord（战斗结束时）、
## [method deserialize_all] 从快照恢复（读档 / 战斗快照）、
## [method write_snapshot_to_gsm] 写进 GSM 的 [code]_set_battle_bindings[/code]，
## 外加 [method _serialize_record] / [method _deserialize_record] 两条单条转换。[br]
## [br][b]与子模块的分工[/b]：实现体在 [BindingSerializer]（[method _get_serializer] 惰性创建，
## 经 [code]_parent[/code] 回取三索引与 GSM），本层只留同名薄委托 + 供
## [method remove_all_bindings] 复用的单条序列化。[br]
##
## 来源: ADR-0013 §序列化 §GSM 边界 / GDD binding-system.md §快照导出。
extends "res://src/feature/binding/binding_manager_compute.gd"


## 序列化单条绑定记录（供 [method remove_all_bindings] 返回 + 未来 Story 004 serialize_all）。[br]
## [br][b]返回[/b]: BindingRecord 字段的 Dictionary 表示。
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


## 序列化全部活跃绑定记录——委托给 _serializer 子模块。
func serialize_all() -> Dictionary:
	return _get_serializer().serialize_all()


## 从快照恢复 BindingRecord——委托给 _serializer 子模块。
func deserialize_all(data: Dictionary) -> void:
	_get_serializer().deserialize_all(data)


## 写绑定快照至 GSM——委托给 _serializer 子模块。
func write_snapshot_to_gsm() -> void:
	_get_serializer().write_snapshot_to_gsm()


## 从快照 Dictionary 重建单条 BindingRecord——委托给 _serializer 子模块。
func _deserialize_record(d: Dictionary) -> BindingRecord:
	return _get_serializer()._deserialize_record(d)


## 清空全部三索引（deserialize 前置清理）。
func _clear_all() -> void:
	_bindings.clear()
	_by_character.clear()
	_card_to_character.clear()
	_next_binding_id = 1


## 惰性获取序列化子模块（Sprint 8 Story 8-12 拆分）。
func _get_serializer() -> RefCounted:
	if _serializer == null:
		_serializer = load("res://src/feature/binding/binding_serializer.gd").new(self)
	return _serializer
