## BindingManager —— 功法/法宝绑定系统 Autoload（#13）。
##
## Feature 层 Autoload。持有运行时绑定注册表——三个同步索引
## [member _bindings] + [member _by_character] + [member _card_to_character]。
## 采用与 ADR-0011 StatusEffectSystem 相同的 GSM 边界先例：战斗期间绑定数据
## 不经过 GSM，仅战斗结束时 [method serialize_all]（Story 004）导出快照。
##
## [b]Autoload 顺序[/b]：GSM #1 → ... → RealmSystem #11 → ProgressionSystem #12 → BindingManager #13。[br]
## [b]本 Story 范围[/b]（4-10 + 4-11）：BindingRecord 实例模型 + 三索引注册表 + [method _register_binding] /
## [method _unregister_binding] 原子同步 + 查询 API（[method get_binding_ids_by_character] /
## [method get_character_by_card] / [method get_bindings_by_character] / [method get_binding]）+ 绑定生命周期 API
## （[method cache_slot_limits] / [method bind_card] / [method stack_card] / [method overwrite_binding] /
## [method can_bind] / [method remove_binding] / [method remove_all_bindings] / [method suspend_bindings] /
## [method restore_bindings] / [method get_accumulated_bonus] + 本命判定 [method _determine_native] +
## 叠加公式 [method _compute_effective_value]）。[br]
## [b]不注册进 project.godot[/b]——待 CombatSystem 接线（4-22）后统一注册（4-0b 终验）。[br]
## [b]后续 story[/b]：7 个 Cat 2b 信号（4-12）、serialize_all/deserialize_all 快照（4-13）。
## [b]存根接口[/b]（Story 004 / 战斗 Epic 接线，sprint §风险登记 存根策略）：效果引擎
## register/remove/suspend/restore、牌库洗回、单卡加成查询均通过可注入 [Callable] 承载——默认空操作。
##
## 来源: ADR-0013 §决策 §对象模型 §关键接口 / GDD binding-system.md §1 绑定数据结构。
extends Node
# class_name BindingManager —— 不声明：Autoload 全局单例，
# 声明 class_name 会与全局名冲突，导致 BM_SCRIPT.new() 测试实例无法解析。
# 测试以 var bm: Node 持有 + 动态分派访问（同 GSM/RealmSystem/CostSystem 先例，
# 控制清单 2026-08-05 规则）。


# === Cat 2b 生命周期信号（ADR-0013 §Cat 2b 信号，经 GSM._emit_signal_safe 路由）====
#
## 绑定成功——新卡落位（含 is_native 标志，CombatUI 据此创建图标/动画 + 本命星标）。
signal binding_applied(binding_id: int, card_instance_id: int, template_id: StringName, character_id: int, slot_type: int, is_native: bool)
## 绑定解除（reason 区分阵亡 'death' / 覆盖 'overwritten' / 移除 'removed'）。
signal binding_removed(binding_id: int, card_instance_id: int, character_id: int, reason: String)
## 覆盖完成（携带 old/new binding_id，UI 据此替换图标 + 过渡动画）。
signal binding_overwritten(old_binding_id: int, new_binding_id: int, character_id: int, slot_index: int)
## 同名叠加（携带 new_stack_count，UI 据此更新 "+1层" 文字特效 + 层数徽章）。
signal binding_stacked(binding_id: int, template_id: StringName, character_id: int, new_stack_count: int)
## 角色离场暂挂（携带 binding_ids: Array[int]，UI 据此图标灰显+半透明）。
signal binding_suspended(character_id: int, binding_ids: Array[int])
## 角色重新上场恢复（携带 binding_ids: Array[int]，UI 据此图标恢复色彩）。
signal binding_restored(character_id: int, binding_ids: Array[int])
## 本命绑定激活（CombatUI 据此点亮 ★金色星标 + Audio 金色共鸣音）。
signal native_activated(binding_id: int, template_id: StringName, character_id: int)


# === 内部数据（三个同步索引）======================================================

## 绑定主索引——[code]key=binding_id[/code] → [BindingRecord]。
var _bindings: Dictionary[int, BindingRecord] = {}

## 角色 → 绑定 ID 列表索引——[code]key=character_id[/code] → [code]Array[int][/code]。
## 零分配热路径查询 [method get_binding_ids_by_character] 直接返回已有数组引用。[br]
## [b]声明为无类型 [code]Dictionary[/code][/b]——[code]Dictionary[int, Array[int]][/code] 是
## 嵌套类型化集合，Godot 4.6 GDScript 不支持（"Nested typed collections are not supported"）。
## 值仍为 [code]Array[int][/code]，类型保证由 [method _register_binding] 的构造路径维护。
var _by_character: Dictionary = {}

## 卡牌实例 → 角色反向索引——[code]key=card_instance_id[/code] → [code]character_id[/code]。
## O(1) 反向查询 [method get_character_by_card]。
var _card_to_character: Dictionary[int, int] = {}


# === 私有方法：索引原子同步 ======================================================

## 注册绑定——同时原子更新三个索引。[br]
## 任一索引更新遗漏即视为失败（AC-004）。[br]
## [br][param record] 待注册的 BindingRecord——[code]binding_id[/code] /
## [code]card_instance_id[/code] / [code]bound_character_id[/code] 必须已填充。
func _register_binding(record: BindingRecord) -> void:
	_bindings[record.binding_id] = record
	if not _by_character.has(record.bound_character_id):
		var empty_ids: Array[int] = []
		_by_character[record.bound_character_id] = empty_ids
	_by_character[record.bound_character_id].append(record.binding_id)
	_card_to_character[record.card_instance_id] = record.bound_character_id


## 注销绑定——从三个索引同步移除。[br]
## [code]_by_character[/code] 数组移除后若为空则删除该 character_id 键（AC-004）。[br]
## [b]反查真实 character_id[/b]：优先信任 [member _card_to_character]（权威映射）反查，
## 而非 [code]record.bound_character_id[/code] 快照——调用方若在 register 后修改了 record 字段，
## 信任快照会导致 [code]_by_character[/code] 擦除静默 no-op、留下孤儿条目
## （lead-programmer C4；Story 002 接管生命周期时的防御）。[br]
## [br][param record] 待移除的 BindingRecord。
func _unregister_binding(record: BindingRecord) -> void:
	if _bindings.has(record.binding_id):
		_bindings.erase(record.binding_id)
	# 反查真实 character_id——_card_to_character 缺失时回退到 record 快照
	var character_id: int = record.bound_character_id
	if _card_to_character.has(record.card_instance_id):
		character_id = _card_to_character[record.card_instance_id]
		_card_to_character.erase(record.card_instance_id)
	if _by_character.has(character_id):
		var ids: Array[int] = _by_character[character_id]
		ids.erase(record.binding_id)
		if ids.is_empty():
			_by_character.erase(character_id)


# === 查询 API =====================================================================

## 零分配查询——返回某角色的全部绑定 ID。[br]
## 返回 [member _by_character] 中已有 [code]Array[int][/code] 的引用（不 duplicate），
## 供 CombatUI 每帧调用（AC-006）。[br]
## [b]返回内部引用[/b]——调用方必须只读，禁止修改（[code].clear()[/code] /
## [code].append()[/code] 会直接破坏三索引一致性，AC-004）。这是零分配承诺的权衡。[br]
## [br][b]返回[/b]: 绑定 ID 列表；未绑定角色返回空 [code]Array[int][/code]。
func get_binding_ids_by_character(character_id: int) -> Array[int]:
	if _by_character.has(character_id):
		return _by_character[character_id]
	var empty_ids: Array[int] = []
	return empty_ids


## 非热路径查询——返回某角色的全部 [BindingRecord]。[br]
## 每次调用分配新数组（AC-007）——CombatUI 不应每帧调用，改用
## [method get_binding_ids_by_character] + [method get_binding] 按需获取。[br]
## [br][b]返回[/b]: [code]Array[BindingRecord][/code] 新数组；未绑定角色返回空数组。
func get_bindings_by_character(character_id: int) -> Array[BindingRecord]:
	var result: Array[BindingRecord] = []
	if not _by_character.has(character_id):
		return result
	for binding_id: int in _by_character[character_id]:
		if _bindings.has(binding_id):
			result.append(_bindings[binding_id])
		# 防御性跳过：binding_id 在 _by_character 但不在 _bindings 的孤儿条目——
		# 三索引失同步时静默跳过而非崩溃（AC-004 将失同步视为失败，但查询侧不因孤儿崩溃）。
	return result


## O(1) 反向查询——某卡牌实例绑定在谁身上（AC-008）。[br]
## [br][b]返回[/b]: 绑定角色 ID；未绑定卡返回 -1。
func get_character_by_card(card_instance_id: int) -> int:
	if _card_to_character.has(card_instance_id):
		return _card_to_character[card_instance_id]
	return -1


## O(1) 单条查询——按 binding_id 获取 BindingRecord（AC-005）。[br]
## 访问处附加 [code]assert(raw is BindingRecord)[/code] 运行时守卫——先 Variant 读入，
## null 检查，再 assert，最后 cast，使 assert 成为类型化赋值之前的第一道运行时守卫。[br]
## [b]可达性说明[/b]：_bindings 为类型化 [code]Dictionary[int, BindingRecord][/code]，
## 非 null 非法类型在写入侧即被运行时拦截；唯一能存入的非法值是 null（提前返回）。
## 故 assert 对非法注入运行时不可达，实为纵深防御层——覆盖未来 deserialize 非类型化
## 写入路径（Story 004）。[br]
## [br][b]返回[/b]: 对应 BindingRecord；不存在或值为 null 时返回 null。
func get_binding(binding_id: int) -> BindingRecord:
	if not _bindings.has(binding_id):
		return null
	var raw: Variant = _bindings[binding_id]
	if raw == null:
		return null
	assert(raw is BindingRecord, "_bindings[id] 应为 BindingRecord——非法注入")
	return raw as BindingRecord


# === 常量 ========================================================================

## 本命加成乘数——[code]native_owner[/code] 匹配且本命位空闲时锁定 1.5（ADR-0013 §本命绑定判定算法）。
const NATIVE_MULTIPLIER: float = 1.5

## 默认叠加乘数——GDD 默认值 1.5（延后接 CardSystem 后由模板提供）。
const DEFAULT_STACK_MULTIPLIER: float = 1.5

## 默认绑定位上限——RealmSystem 槽位数据缺失时的保守回退（炼气基准 1，防止越界分配）。
const DEFAULT_SLOT_LIMIT: int = 1


# === 内部状态 =====================================================================

## 绑定 ID 单调递增分配器——每次注册新 BindingRecord 递增。
var _next_binding_id: int = 1

## 绑定位上限缓存——[code]{slot_type: limit}[/code]。由 [method cache_slot_limits] 在战斗开始时填充。
## 战斗期间从 RealmSystem 缓存，不运行时重查（ADR-0013 §绑定上限缓存）。
var _slot_limits: Dictionary = {}

# === 存根回调（Story 004 / 战斗 Epic 注入真实实现，sprint §风险登记 存根策略）=====

## 效果引擎 register_persistent_effect 存根——[code](card_instance_id, character_id)[/code]。默认空操作。
var effect_register_cb: Callable = Callable()

## 效果引擎 remove_effects_by_source 存根——[code](card_instance_id)[/code]。默认空操作。
var effect_remove_cb: Callable = Callable()

## 效果引擎 suspend_effects_by_source 存根——[code](character_id, card_ids)[/code]。默认空操作。
var effect_suspend_cb: Callable = Callable()

## 效果引擎 restore_effects_by_source 存根——[code](character_id, card_ids)[/code]。默认空操作。
var effect_restore_cb: Callable = Callable()

## 阵亡洗回牌库存根——[code](card_instance_id)[/code]。默认空操作。
var card_shuffle_cb: Callable = Callable()

## 覆盖旧卡进弃牌堆存根——[code](card_instance_id)[/code]。默认空操作。
var card_discard_cb: Callable = Callable()

## 卡牌实例存在性验证存根——[code](card_instance_id) -> bool[/code]。默认返回 true（假设存在）。
var card_exists_cb: Callable = Callable()

## 单卡数值加成查询存根——[code](card_instance_id, stat_name) -> float[/code]。默认返回 0.0。
var stat_bonus_cb: Callable = Callable()


# === 绑定位上限 ==================================================================

## 缓存绑定位上限——战斗开始时从 RealmSystem 查询（ADR-0013 §绑定上限缓存）。[br]
## 绝不硬编码——通过 [method RealmSystem.get_realm_property] 读取 [code]gongfa_slots[/code] /
## [code]fabao_slots[/code]。[br]
## [br][param realm_level] 境界等级（1-5）。
func cache_slot_limits(realm_level: int) -> void:
	_slot_limits[BindingRecord.BindingSlot.GONGFA] = _query_realm_slots(realm_level, &"gongfa_slots")
	_slot_limits[BindingRecord.BindingSlot.FABAO] = _query_realm_slots(realm_level, &"fabao_slots")


## 查询单类型绑定位上限——RealmSystem 缺失时回退默认值。[br]
## [br][param realm_level] 境界等级。[br]
## [br][param key] 槽位键名（gongfa_slots / fabao_slots）。[br]
## [br][b]返回[/b]: 槽位上限 int。
func _query_realm_slots(realm_level: int, key: StringName) -> int:
	var val: Variant = RealmSystem.get_realm_property(realm_level, key)
	if val == null:
		return DEFAULT_SLOT_LIMIT
	return int(val)


## 查询缓存中的槽位上限（未缓存回退默认值）。[br]
## [br][param slot_type] [enum BindingRecord.BindingSlot] 值。[br]
## [br][b]返回[/b]: 槽位上限 int。
func _get_slot_limit(slot_type: int) -> int:
	return int(_slot_limits.get(slot_type, DEFAULT_SLOT_LIMIT))


# === 绑定生命周期 API =============================================================

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


## 遍历角色所有绑定卡的数值加成累加（AC-016）——O(k)，k ≤ 6/角色。[br]
## 每张叠层实例的加成由 [member stat_bonus_cb] 提供（Story 004 接效果引擎）。[br]
## [br][param character_id] 目标角色 ID。[br]
## [br][param stat_name] 属性名（如 [code]"ATK"[/code]）。[br]
## [br][b]返回[/b]: 加成累加 float；无绑定或未注入回调返回 0.0。
func get_accumulated_bonus(character_id: int, stat_name: String) -> float:
	var total: float = 0.0
	for binding_id: int in get_binding_ids_by_character(character_id):
		if not _bindings.has(binding_id):
			continue
		var record: BindingRecord = _bindings[binding_id]
		for cid: int in record.stack_slots:
			total += _query_stat_bonus(cid, stat_name)
	return total


## 同名叠加乘法公式（AC-009）——[code]effective = base × native × stack_multiplier^(stack_count-1)[/code]，
## 结果向下取整。[br]
## [br][param base_value] 基础数值。[br]
## [br][param native_multiplier] 本命乘数（1.0 或 1.5）。[br]
## [br][param stack_multiplier] 每层叠加乘数（默认 1.5）。[br]
## [br][param stack_count] 叠加张数（≥1）。[br]
## [br][b]返回[/b]: 有效值 int（向下取整）。
func compute_effective_value(base_value: int, native_multiplier: float, stack_multiplier: float, stack_count: int) -> int:
	var mult: float = native_multiplier * pow(stack_multiplier, stack_count - 1)
	return floori(base_value * mult)


# === 内部辅助 ====================================================================

## 构造 BindingRecord——填充标识/槽位/叠层字段。[br]
## [b]card_name / card_rarity 延后[/b]：本 Story 无 CardSystem 模板查询（绑定生命周期走存根），
## 两字段保持默认空值；Story 004 接 CardSystem 后由 [method bind_card] 填充模板数据。[br]
## [br][b]返回[/b]: 新 BindingRecord（binding_id 已分配，stack_count=1，stack_slots=[card_instance_id]）。
func _make_record(card_instance_id: int, template_id: StringName, character_id: int, slot_type: int, slot_index: int) -> BindingRecord:
	var record: BindingRecord = BindingRecord.new()
	record.binding_id = _next_binding_id
	_next_binding_id += 1
	record.card_instance_id = card_instance_id
	record.card_template_id = template_id
	record.slot_type = slot_type
	record.slot_index = slot_index
	record.bound_character_id = character_id
	record.activated_turn = 0
	var slots: Array[int] = [card_instance_id]
	record.stack_slots = slots
	record.stack_count = 1
	return record


## 本命判定（AC-005）——[code]native_owner[/code] 匹配角色 card_id + 同类型本命位未占用 → 本命。[br]
## 匹配采用下划线分段边界匹配（card_id 命名 [code]{type}_{name}_{variant}[/code]，
## native_owner 匹配 name 段——两侧以下划线锚定，避免子串误匹配）。[br]
## [br][b]返回[/b]: [code]{is_native, native_multiplier}[/code]。
func _determine_native(character_id: int, native_owner: StringName, character_card_id: StringName, slot_type: int) -> Dictionary:
	if native_owner == &"":
		return {"is_native": false, "native_multiplier": 1.0}
	if not _native_matches(character_card_id, native_owner):
		return {"is_native": false, "native_multiplier": 1.0}
	if _has_native_binding(character_id, slot_type):
		return {"is_native": false, "native_multiplier": 1.0}
	return {"is_native": true, "native_multiplier": NATIVE_MULTIPLIER}


## 本命分段匹配——[code]native_owner[/code] 作为下划线分隔的完整段出现在 [code]character_card_id[/code] 中。[br]
## 两侧以下划线锚定（[code]"_" + owner + "_"[/code] in [code]"_" + card_id + "_"[/code]），
## 消除子串误匹配（如 native_owner="yuan" 不会误配 "xi_yuan"）。[br]
## [br][b]返回[/b]: true 表示匹配。
func _native_matches(character_card_id: StringName, native_owner: StringName) -> bool:
	var card_seg: String = "_" + String(character_card_id) + "_"
	var owner_seg: String = "_" + String(native_owner) + "_"
	return card_seg.contains(owner_seg)


## 检查角色某类型本命位是否已被占用。[br]
## [br][b]返回[/b]: true 表示已有 is_native 绑定。
func _has_native_binding(character_id: int, slot_type: int) -> bool:
	for binding_id: int in get_binding_ids_by_character(character_id):
		if not _bindings.has(binding_id):
			continue
		var record: BindingRecord = _bindings[binding_id]
		if record.slot_type == slot_type and record.is_native:
			return true
	return false


## 统计角色某类型的已占用槽位数（同名叠加共享一位，不计 stack_count）。[br]
## [br][b]返回[/b]: 已占用槽位数。
func _count_bound_slots(character_id: int, slot_type: int) -> int:
	var count: int = 0
	for binding_id: int in get_binding_ids_by_character(character_id):
		if _bindings.has(binding_id) and (_bindings[binding_id] as BindingRecord).slot_type == slot_type:
			count += 1
	return count


## 查找角色已绑定的同名卡（按模板 ID 判定）。[br]
## [br][b]返回[/b]: 同名 BindingRecord 或 null。
func _find_same_template_binding(character_id: int, template_id: StringName) -> BindingRecord:
	for binding_id: int in get_binding_ids_by_character(character_id):
		if _bindings.has(binding_id):
			var record: BindingRecord = _bindings[binding_id]
			if record.card_template_id == template_id:
				return record
	return null


## 查找角色某槽位上的绑定记录。[br]
## [br][b]返回[/b]: BindingRecord 或 null。
func _find_binding_at_slot(character_id: int, slot_index: int) -> BindingRecord:
	for binding_id: int in get_binding_ids_by_character(character_id):
		if _bindings.has(binding_id):
			var record: BindingRecord = _bindings[binding_id]
			if record.slot_index == slot_index:
				return record
	return null


## 查找某类型的第一个空闲槽位索引（0..limit-1）。[br]
## [br][b]返回[/b]: 空闲 slot_index；全满时 [code]push_error[/code] 并返回 -1
## （防御——调用方 [method bind_card] / [method can_bind] 已在校验后保证有空位，不应触发）。
func _find_free_slot_index(character_id: int, slot_type: int, limit: int) -> int:
	var occupied: Dictionary = {}
	for binding_id: int in get_binding_ids_by_character(character_id):
		if _bindings.has(binding_id):
			var record: BindingRecord = _bindings[binding_id]
			if record.slot_type == slot_type:
				occupied[record.slot_index] = true
	for slot_index: int in range(limit):
		if not occupied.has(slot_index):
			return slot_index
	push_error("_find_free_slot_index: 槽位已满仍被调用（character_id=%d, slot_type=%d, limit=%d）"
			% [character_id, slot_type, limit])
	return -1


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


## 调用存根回调——空 Callable 或无效 Callable 跳过。[br]
## [br][param cb] 待调用的 Callable。[br]
## [br][param args] 参数数组。
func _invoke_cb(cb: Callable, args: Array) -> void:
	if cb.is_valid():
		cb.callv(args)


## Cat 2b 信号安全发射——经 GSM._emit_signal_safe 路由（ADR-0007 信号链深度追踪）。[br]
## 非 Autoload 测试实例（BM_SCRIPT.new()）下 GSM 仍为全局 Autoload，可正常路由。[br]
## [br][param signal_name] 信号名。[br]
## [br][param args] 参数数组。
func _emit_safe(signal_name: StringName, args: Array) -> void:
	if GameStateManager != null and GameStateManager.get_script().has_method("_emit_signal_safe"):
		GameStateManager.get_script()._emit_signal_safe(self, signal_name, args)
	else:
		var call_args: Array = [signal_name]
		call_args.append_array(args)
		callv("emit_signal", call_args)


## 查询卡牌实例是否存在（存根默认 true）。[br]
## [br][b]返回[/b]: true 表示仍存在。
func _query_card_exists(card_instance_id: int) -> bool:
	if card_exists_cb.is_valid():
		return bool(card_exists_cb.call(card_instance_id))
	return true


## 查询单卡数值加成（存根默认 0.0）。[br]
## [br][b]返回[/b]: 单卡加成 float。
func _query_stat_bonus(card_instance_id: int, stat_name: String) -> float:
	if stat_bonus_cb.is_valid():
		return float(stat_bonus_cb.call(card_instance_id, stat_name))
	return 0.0


# === 序列化 / 反序列化 / 快照导出（Story 004）=================================

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
	for binding_id: int in _bindings.keys():
		var record: BindingRecord = _bindings[binding_id]
		records.append(_serialize_record(record))
	return {"bindings": records}


## 从快照恢复 BindingRecord——读档 / 战斗快照恢复（AC-003/AC-004）。[br]
## [b]尽力而为策略[/b]：逐条验证 card_instance_id（通过 [member card_exists_cb]），
## 失败跳过 + push_warning，其余正常恢复——不阻塞整体恢复。[br]
## [b]键归一[/b]：快照经 JSON round-trip 后 int-key 可能变 String——binding_id
## 统一 [code]int()[/code] 转换（同 DeploymentSystem deserialize 先例）。[br]
## [br][param data] 快照 Dictionary（[code]{"bindings": [...]}[/code]）。
func deserialize_all(data: Dictionary) -> void:
	_clear_all()
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
		if not _query_card_exists(card_instance_id):
			push_warning("BindingManager.deserialize_all: card_instance_id=%d 不存在——跳过"
				% card_instance_id)
			continue
		var record: BindingRecord = _deserialize_record(d)
		if record == null:
			continue
		_register_binding(record)
		# 叠层实例的 _card_to_character 映射——_register_binding 仅注册主实例，
		# 叠层实例需逐条补充（同 stack_card 路径的手动注册）
		for cid: int in record.stack_slots:
			if cid != record.card_instance_id:
				_card_to_character[cid] = record.bound_character_id


## 写绑定快照至 GSM battle.bindings（战斗结束导出委托，AC-002）。[br]
## GSM 不可用时静默跳过（is_instance_valid + has_method 双守卫）。[br]
## [br]来源: ADR-0013 §GSM 边界 §serialize_all。
func write_snapshot_to_gsm() -> void:
	var gsm: Node = _get_gsm()
	if gsm == null or not gsm.has_method("_set_battle_bindings"):
		return  # GSM 不可用——静默跳过
	gsm.call("_set_battle_bindings", serialize_all()["bindings"])


## 查询单条绑定的预计算乘积上下文（AC-009）。[br]
## [code]multiplier = native_multiplier × stack_multiplier^(stack_count-1)[/code]——
## CardEffectEngine 结算时查询此值，不在引擎中重复计算。[br]
## [b]stack_multiplier 延后[/b]：本 Story 无 CardSystem 模板查询（[code]cardTemplate.stack_multiplier[/code]），
## 暂用默认 1.5（GDD 默认值），Story 004 接 CardSystem 后由调用方传入或注入。[br]
## [br][param card_instance_id] 卡牌实例 ID。[br]
## [br][b]返回[/b]: [code]{native_multiplier, stack_count, multiplier}[/code]；
## 未找到返回空 Dictionary。
func get_binding_context(card_instance_id: int) -> Dictionary:
	var character_id: int = get_character_by_card(card_instance_id)
	if character_id < 0:
		return {}
	for binding_id: int in get_binding_ids_by_character(character_id):
		if not _bindings.has(binding_id):
			continue
		var record: BindingRecord = _bindings[binding_id]
		if record.stack_slots.has(card_instance_id) or record.card_instance_id == card_instance_id:
			var stack_mult: float = DEFAULT_STACK_MULTIPLIER  # 延后接 CardSystem
			var mult: float = record.native_multiplier * pow(stack_mult, record.stack_count - 1)
			return {"native_multiplier": record.native_multiplier, "stack_count": record.stack_count, "multiplier": mult}
	return {}


# === 内部辅助：序列化 / 反序列化 / GSM ==========================

## 从快照 Dictionary 重建单条 BindingRecord。[br]
## [b]键归一[/b]：int-key 统一 [code]int()[/code] 转换。[br]
## [br][b]返回[/b]: 重建的 BindingRecord；非法数据返回 null。
func _deserialize_record(d: Dictionary) -> BindingRecord:
	var record: BindingRecord = BindingRecord.new()
	record.binding_id = int(d.get("binding_id", _next_binding_id))
	if record.binding_id >= _next_binding_id:
		_next_binding_id = record.binding_id + 1
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
		var slots: Array[int] = []
		for cid: Variant in raw_slots:
			slots.append(int(cid))
		record.stack_slots = slots
	else:
		var single: Array[int] = [record.card_instance_id]
		record.stack_slots = single
	record.stack_count = int(d.get("stack_count", 1))
	return record


## 清空全部三索引（deserialize 前置清理）。
func _clear_all() -> void:
	_bindings.clear()
	_by_character.clear()
	_card_to_character.clear()
	_next_binding_id = 1


## 动态获取 GSM Autoload 节点。[br]
## 用 SceneTree.root 查找而非硬引用全局名——避免测试环境无 Autoload 时崩溃
## （同 DeploymentSystem._get_gsm 先例）。
func _get_gsm() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/GameStateManager")
