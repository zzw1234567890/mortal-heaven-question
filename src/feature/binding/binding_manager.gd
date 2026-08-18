## BindingManager —— 功法/法宝绑定系统 Autoload（#13）。
##
## Feature 层 Autoload。持有运行时绑定注册表——三个同步索引
## [member _bindings] + [member _by_character] + [member _card_to_character]。
## 采用与 ADR-0011 StatusEffectSystem 相同的 GSM 边界先例：战斗期间绑定数据
## 不经过 GSM，仅战斗结束时 [method serialize_all]（Story 004）导出快照。
##
## [b]Autoload 顺序[/b]：GSM #1 → ... → RealmSystem #11 → ProgressionSystem #12 → BindingManager #13。[br]
## [b]本 Story 范围[/b]（4-10）：BindingRecord 实例模型 + 三索引注册表 + [method _register_binding] /
## [method _unregister_binding] 原子同步 + 零分配热路径查询 [method get_binding_ids_by_character] /
## [method get_character_by_card] + 非热路径查询 [method get_bindings_by_character] + 单条查询
## [method get_binding]。[br]
## [b]不注册进 project.godot[/b]——待 CombatSystem 接线（4-22）后统一注册（4-0b 终验）。[br]
## [b]后续 story[/b]：bind/stack/overwrite 业务逻辑（4-11）、7 个 Cat 2b 信号（4-12）、
## serialize_all/deserialize_all 快照（4-13）。
##
## 来源: ADR-0013 §决策 §对象模型 §关键接口 / GDD binding-system.md §1 绑定数据结构。
extends Node
# class_name BindingManager —— 不声明：Autoload 全局单例，
# 声明 class_name 会与全局名冲突，导致 BM_SCRIPT.new() 测试实例无法解析。
# 测试以 var bm: Node 持有 + 动态分派访问（同 GSM/RealmSystem/CostSystem 先例，
# 控制清单 2026-08-05 规则）。


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
