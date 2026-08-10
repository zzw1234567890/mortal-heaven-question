extends Node
# class_name StatusEffectSystem —— 不声明：Autoload 全局单例，
# 声明 class_name 会与全局名冲突，导致 SES_SCRIPT.new() 测试实例无法解析。
# 测试以 var ses: Node 持有 + 动态分派访问（同 GSM/EventSystem/RealmSystem/
# ResourceSystem/CardSystem/FactionSystem 先例，控制清单 2026-08-05 规则）。

## StatusEffectSystem —— 状态效果生命周期管理 Autoload（#8）。
##
## Core 层 Autoload。持有 [_instances] + [_by_target] 内部注册表，
## 提供 [method apply_status] / [method remove_status] / [method tick_all] 等 API。
## 采用双层模型——StatusTemplate（Resource, .tres, 只读）+ StatusInstance（RefCounted, 运行时可变）。
##
## [b]Story 001 范围[/b]：仅实现基础 NEW 路径（施加/移除/倒计时/过期）。
## 叠加规则（刷新/叠加上限）、免疫检查、溢出驱逐属 Story 002。
##
## [b]Autoload 顺序[/b]：GSM → ... → FactionSystem → StatusEffectSystem（#8）
## （在 CardSystem/CostSystem 之后、CombatSystem 之前——ADR-0011 §Autoload 初始化）。
## 注：CostSystem(#7) 尚未注册，当前暂接在 FactionSystem 之后；后续 CostSystem story 会调整顺序。
##
## [b]信号架构[/b]：4 个 Cat 2b 信号声明在本系统（非 GSM）——
## status_applied / status_removed / status_updated / status_immunity_blocked。
##
## 来源: ADR-0011。

# === 信号声明（Cat 2b）============================================================

## 状态成功施加到目标时发射。
signal status_applied(target_id: int, status_id: int, template_id: StringName, stacks: int, reason: String)

## 状态被移除时发射（过期/手动/溢出驱逐）。
signal status_removed(target_id: int, status_id: int, template_id: StringName, reason: String)

## 状态层数/数值/duration 变更时发射（不含每帧递减——见 tick_all）。
signal status_updated(target_id: int, status_id: int, changes: Dictionary)

## 施加被免疫阻挡时发射。
signal status_immunity_blocked(target_id: int, template_id: StringName, immune_level: String)


# === 常量 ========================================================================

## 每角色最大活跃状态数（ADR-0011 §溢出驱逐，Story 002 实现）。
const MAX_ACTIVE_STATUSES_PER_CHARACTER: int = 20

## 默认模板目录路径。
const DEFAULT_TEMPLATE_PATH: StringName = &"res://assets/statuses/"


# === 内部注册表 ===================================================================

## 所有活跃状态实例的权威注册表——key=status_id, value=StatusInstance。
var _instances: Dictionary = {}

## 角色级状态索引——key=target_id, value=Array[int]（status_id 列表）。O(1) 角色查询。
var _by_target: Dictionary = {}

## 模板注册表——key=template_id, value=StatusTemplate。由 _ready() 加载。
var _templates: Dictionary = {}

## 下一个状态实例 ID（单调递增）。
var _next_status_id: int = 1

## 免疫标志注册表——key=target_id, value={type: {}, template: {}, element: {}}（Story 002）。
var _immunity_flags: Dictionary = {}


# === 内置虚方法 ===================================================================

func _ready() -> void:
	_load_templates_from(DEFAULT_TEMPLATE_PATH)


# === 公共 API =====================================================================

## 施加状态到目标——Story 001 仅实现 NEW 路径。[br]
## [br][b]管线[/b]（Story 001）：加载模板 → 创建 StatusInstance → 注册 → 发射 status_applied。[br]
## 叠加/免疫/溢出属 Story 002。[br]
## [br][param target_id] 目标角色实例 ID。[br]
## [param template_id] 状态模板 ID。[br]
## [param source_card_instance_id] 来源卡牌实例 ID（追溯用）。[br]
## [param overrides] 覆盖字段（支持 [code]"value"[/code]）。[br]
## [param current_turn] 当前回合数（用于同回合不倒计时判定，-1 不追踪）。[br]
## [br][b]返回[/b]: [Dictionary]——[code]{applied: bool, status_id: int, reason: String}[/code]。
func apply_status(
	target_id: int,
	template_id: StringName,
	source_card_instance_id: int,
	overrides: Dictionary = {},
	current_turn: int = -1
) -> Dictionary:
	var template: StatusTemplate = get_status_template(template_id)
	if template == null:
		return {applied = false, status_id = 0, reason = "unknown_template"}

	# Story 001 仅实现 NEW 路径——叠加/免疫/溢出属 Story 002
	var instance: StatusInstance = StatusInstance.new()
	instance.id = _next_status_id
	_next_status_id += 1
	instance.template_id = template_id
	instance.target_id = target_id
	instance.duration = template.base_duration
	instance.applied_turn = current_turn
	instance.base_value = template.base_value
	instance.value = float(overrides.get("value", template.base_value))
	instance.current_stacks = 1
	instance.source_card_instance_id = source_card_instance_id
	instance.priority = template.default_priority
	instance.is_hidden = false
	instance.is_expired = false
	instance.metadata = template.metadata.duplicate(true)

	_register_instance(instance)
	status_applied.emit(target_id, instance.id, template_id, instance.current_stacks, "new")
	return {applied = true, status_id = instance.id, reason = "new"}


## 获取目标的所有活跃 status_id 列表。[br]
## [br][b]复杂度[/b]: O(1) 字典查询 + O(n) 数组复制（n = 该角色状态数）。[br]
## [br][b]返回[/b]: [Array[int]]——status_id 列表；无状态返回空数组。
func get_active_statuses(target_id: int) -> Array[int]:
	var result: Array[int] = []
	var ids: Array = _by_target.get(target_id, [])
	for id in ids:
		result.append(id)
	return result


## 检查目标是否有指定模板的状态。[br]
## [br][param target_id] 目标角色实例 ID。[br]
## [param template_id] 状态模板 ID。[br]
## [br][b]返回[/b]: 存在则 true；过期状态（is_expired=true）仍返回 true 直到被移除。
func has_status(target_id: int, template_id: StringName) -> bool:
	var ids: Array = _by_target.get(target_id, [])
	for id in ids:
		var status: StatusInstance = _instances[id]
		if status.template_id == template_id:
			return true
	return false


## 移除指定状态实例。[br]
## [br][param status_id] 状态实例 ID。[br]
## [br][b]返回[/b]: 移除成功 true；不存在返回 false（不报错）。
func remove_status(status_id: int) -> bool:
	var status: StatusInstance = _instances.get(status_id, null)
	if status == null:
		return false
	_remove_instance(status_id, "manual")
	return true


## Phase 0 倒计时——由 CombatSystem 调用。[br]
## [br][b]流程[/b]:[br]
##   1. 遍历 field_characters → 查询 _by_target → duration>0 且非永久(-1) 则 -1[br]
##   2. duration==0 标记 is_expired[br]
##   3. 第二遍 remove_expired 统一移除 + 发射 status_removed(reason="expired")[br]
## [br][b]同回合判定[/b]（AC-012）：[param current_turn] >= 0 时跳过 applied_turn == current_turn 的状态。[br]
## [br][b]信号策略[/b]（AC-013）：duration 递减不发射 status_updated；仅移除时发射 status_removed。
func tick_all(field_characters: Array, current_turn: int = -1) -> void:
	# 第一遍：倒计时——不发射 status_updated
	for character in field_characters:
		var target_id: int = _extract_target_id(character)
		if target_id == 0:
			continue
		var status_ids: Array = _by_target.get(target_id, [])
		if status_ids.is_empty():
			continue
		for status_id in status_ids:
			var status: StatusInstance = _instances[status_id]
			if status.duration < 0:  # 永久状态不递减
				continue
			if current_turn >= 0 and status.applied_turn == current_turn:
				continue  # 同回合施加不倒计时（AC-012）
			if status.duration > 0:
				status.duration -= 1
				if status.duration == 0:
					status.is_expired = true
	# 第二遍：延迟移除过期状态——发射 status_removed(reason="expired")
	for character in field_characters:
		var target_id: int = _extract_target_id(character)
		if target_id == 0:
			continue
		_remove_expired_statuses(target_id)


## 只读访问器——查询模板注册表。[br]
## [br][b]返回[/b]: [StatusTemplate] 或 [code]null[/code]（template_id 不存在时）。
func get_status_template(template_id: StringName) -> StatusTemplate:
	return _templates.get(template_id, null) as StatusTemplate


# === 内部辅助 ====================================================================

## 注册实例——同步更新 _instances + _by_target。
func _register_instance(instance: StatusInstance) -> void:
	_instances[instance.id] = instance
	if not _by_target.has(instance.target_id):
		_by_target[instance.target_id] = []
	_by_target[instance.target_id].append(instance.id)


## 移除实例——同步更新 _instances + _by_target + 发射 status_removed。
func _remove_instance(status_id: int, reason: String) -> void:
	var status: StatusInstance = _instances.get(status_id, null)
	if status == null:
		return
	var target_id: int = status.target_id
	var template_id: StringName = status.template_id
	_instances.erase(status_id)
	var ids: Array = _by_target.get(target_id, [])
	ids.erase(status_id)
	if ids.is_empty():
		_by_target.erase(target_id)
	status_removed.emit(target_id, status_id, template_id, reason)


## 移除目标身上所有过期状态——发射 status_removed(reason="expired")。
func _remove_expired_statuses(target_id: int) -> void:
	var status_ids: Array = _by_target.get(target_id, [])
	var to_remove: Array[int] = []
	for status_id in status_ids:
		var status: StatusInstance = _instances[status_id]
		if status.is_expired:
			to_remove.append(status_id)
	for status_id in to_remove:
		_remove_instance(status_id, "expired")


## 从角色实例对象提取 target_id——兼容 int/Dictionary/Object。
func _extract_target_id(character: Variant) -> int:
	if character is int:
		return character
	if character is Dictionary:
		if character.has("id"):
			return int(character["id"])
		if character.has("target_id"):
			return int(character["target_id"])
		if character.has("card_instance_id"):
			return int(character["card_instance_id"])
	if character is Object:
		if "id" in character:
			return int(character.id)
		if "target_id" in character:
			return int(character.target_id)
		if "card_instance_id" in character:
			return int(character.card_instance_id)
	return 0


## 从指定目录加载所有 .tres StatusTemplate 文件。[br]
## [br]目录不存在则空注册表（测试用——SES_SCRIPT.new() 不调 _ready()）。
func _load_templates_from(path: StringName) -> void:
	_templates.clear()
	var path_str: String = String(path)
	var dir := DirAccess.open(path_str)
	if dir == null:
		return  # 目录不存在——空注册表
	dir.include_hidden = false
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var full_path: String = path_str + file_name
			var res := load(full_path)
			if res is StatusTemplate:
				var tpl: StatusTemplate = res as StatusTemplate
				if tpl.template_id != &"":
					_templates[tpl.template_id] = tpl
		file_name = dir.get_next()
	dir.list_dir_end()
