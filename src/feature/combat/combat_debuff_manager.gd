extends RefCounted
## CombatDebuffManager —— Debuff 状态管理模块（降攻/降防）。[br]
## [br][b]职责[/b]：[br]
##   1. 施加 debuff（目标 + 类型 + 持续回合数 + 档位数值）[br]
##   2. 回合结束时递减持续回合数，归零时移除 debuff[br]
##   3. 计算目标当前受 debuff 影响后的 ATK/DEF[br]
##   4. 同一目标重复施加 debuff 按层数叠加，不超过上限[br]
## [br][b]作用顺序[/b]（GDD combat-system.md §公式）：[br]
##   debuff 修正 → 防御减免 → 减伤比例[br]
##   即：ATK 受降攻 debuff 调整后，再算防御减免。[br]
## [br][b]层数上限[/b]：降攻/降防各 5 层（超出则新施加无效）。[br]
## [br]来源: Story debuff 真正作用到战斗数值上。

## 层数上限——同类型 debuff 最多叠加 5 层。
const MAX_STACKS: int = 5

## Debuff 类型——与 DebuffConfig 同源。
const TYPE_ATK: int = 0  ## 降低攻击
const TYPE_DEF: int = 1  ## 降低防御

## 类型 → 状态表键名（[b]唯一真理来源[/b]：状态的键、[method type_of_key] 的反查、
## 存档侧折叠都读它——各写一遍必然有一处漂移，而漂移的症状是「debuff 存了但读不回」）。
## [br][b]未知键[/b]：不在本表内的返回 [constant NO_TYPE]。
const NO_TYPE: int = -1
const TYPE_KEYS: Dictionary = {
	TYPE_ATK: "atk_down",
	TYPE_DEF: "def_down",
}

## 状态表——[code]{character_id: {type: [ {stacks, duration, amount, source_id} ]}}[/code]。[br]
## 每个角色每种 debuff 类型维护一个列表，每条记录代表一次施加的 debuff。[br]
## [br]字段说明：[br]
## - [code]stacks[/code]：本次施加的层数（固定 1 层，单次技能只加 1 层）[br]
## - [code]duration[/code]：剩余回合数（0 = 本回合结束后生效，N = 持续 N 回合）[br]
## - [code]amount[/code]：每层降低的数值（档位数值）[br]
## - [code]source_id[/code]：施加者角色 ID（用于反向追踪/日志，结算不依赖）
var _states: Dictionary = {}


## 清空全部状态——开战/战斗结束共用。
func clear() -> void:
	_states.clear()


## 施加 debuff——目标收到 debuff。[br]
## [br][param p_target_id] 目标角色 ID。[br]
## [param p_type] DebuffType（TYPE_ATK / TYPE_DEF）。[br]
## [param p_duration] 持续回合数（0 = 本回合结束后生效）。[br]
## [param p_amount] 每层降低的数值（DebuffConfig.amount）。[br]
## [param p_source_id] 施加者角色 ID（可选）。[br]
## [b]返回[/b]：是否成功施加（层数已满则失败）。
func apply(p_target_id: int, p_type: int, p_duration: int, p_amount: int,
		p_source_id: int = -1) -> bool:
	if p_target_id < 0 or p_amount <= 0:
		return false
	if not _states.has(p_target_id):
		_states[p_target_id] = {}
	var char_states: Dictionary = _states[p_target_id]
	var type_key: String = _type_key(p_type)
	if not char_states.has(type_key):
		char_states[type_key] = []
	var entries: Array = char_states[type_key]
	# 检查层数上限
	if entries.size() >= MAX_STACKS:
		return false
	# 添加新条目
	entries.append({
		"stacks": 1,
		"duration": p_duration,
		"amount": p_amount,
		"source_id": p_source_id,
	})
	return true


## 回合结束递减——调用一次，所有 debuff 持续回合数 -1。[br]
## [br]归零的 debuff 条目会被移除。[br]
## [b]返回[/b]：被移除的 debuff 数量（用于日志/统计）。
func on_turn_end() -> int:
	var removed: int = 0
	for char_id: Variant in _states.keys():
		var char_states: Dictionary = _states[char_id]
		for type_key: Variant in char_states.keys():
			var entries: Array = char_states[type_key]
			var new_entries: Array = []
			for entry: Variant in entries:
				if entry is Dictionary:
					var entry_dict: Dictionary = entry
					var dur: int = int(entry_dict.get("duration", 0))
					if dur > 0:
						entry_dict["duration"] = dur - 1
						new_entries.append(entry_dict)
					else:
						removed += 1
			if new_entries.is_empty():
				char_states.erase(type_key)
			else:
				char_states[type_key] = new_entries
		if char_states.is_empty():
			_states.erase(char_id)
	return removed


## 计算目标受 debuff 影响后的 ATK——原始 ATK 减去降攻 debuff 总量。[br]
## [br][param p_target_id] 目标角色 ID。[br]
## [param p_base_atk] 原始攻击力（未被 debuff 影响）。[br]
## [b]返回[/b]：调整后的攻击力（最低 0）。
func get_atk_with_debuff(p_target_id: int, p_base_atk: int) -> int:
	var total_reduction: int = _total_reduction(p_target_id, TYPE_ATK)
	return maxi(p_base_atk - total_reduction, 0)


## 计算目标受 debuff 影响后的 DEF——原始 DEF 减去降防 debuff 总量。[br]
## [br][param p_target_id] 目标角色 ID。[br]
## [param p_base_def] 原始防御力（未被 debuff 影响）。[br]
## [b]返回[/b]：调整后的防御力（最低 0）。
func get_def_with_debuff(p_target_id: int, p_base_def: int) -> int:
	var total_reduction: int = _total_reduction(p_target_id, TYPE_DEF)
	return maxi(p_base_def - total_reduction, 0)


## 查询目标当前层数——用于 UI 显示 / 断言。[br]
## [br][param p_target_id] 目标角色 ID。[br]
## [param p_type] DebuffType。[br]
## [b]返回[/b]：当前层数（0 = 无此 debuff）。
func get_stacks(p_target_id: int, p_type: int) -> int:
	if not _states.has(p_target_id):
		return 0
	var char_states: Dictionary = _states[p_target_id]
	var type_key: String = _type_key(p_type)
	if not char_states.has(type_key):
		return 0
	var entries: Array = char_states[type_key]
	return entries.size()


## 查询目标当前剩余回合数（最早到期的那条）。[br]
## [br][param p_target_id] 目标角色 ID。[br]
## [param p_type] DebuffType。[br]
## [b]返回[/b]：剩余回合数（-1 = 无此 debuff）。
func get_duration(p_target_id: int, p_type: int) -> int:
	if not _states.has(p_target_id):
		return -1
	var char_states: Dictionary = _states[p_target_id]
	var type_key: String = _type_key(p_type)
	if not char_states.has(type_key):
		return -1
	var entries: Array = char_states[type_key]
	if entries.is_empty():
		return -1
	# 返回最早到期的剩余回合数
	var min_dur: int = -1
	for entry: Variant in entries:
		if entry is Dictionary:
			var dur: int = int(entry.get("duration", -1))
			if min_dur < 0 or dur < min_dur:
				min_dur = dur
	return min_dur


## 快照全部状态——用于测试断言。[br]
## [b]返回[/b]：[code]{character_id: {type: [ {stacks, duration, amount, source_id} ]}}[/code]。
func snapshot() -> Dictionary:
	return _states.duplicate(true)


## DebuffType → 字典键名（见 [constant TYPE_KEYS] 的「唯一真理来源」注记）。
static func key_of_type(p_type: int) -> String:
	return str(TYPE_KEYS.get(p_type, "unknown"))


## 字典键名 → DebuffType（[method key_of_type] 的反查；认不出的给 [constant NO_TYPE]）。[br]
## [br][b]为什么要有反查[/b]：存档侧拿到的是一份快照，只有键名没有枚举；
## 让那边自己维护一张「键名 → 类型」表等于把本表抄第二遍。
static func type_of_key(p_key: String) -> int:
	for known_type: Variant in TYPE_KEYS.keys():
		if str(TYPE_KEYS[known_type]) == p_key:
			return int(known_type)
	return NO_TYPE


# === 内部 ====================================================================

## 计算指定类型的总降低量——层数 × 每层数值。[br]
func _total_reduction(p_target_id: int, p_type: int) -> int:
	if not _states.has(p_target_id):
		return 0
	var char_states: Dictionary = _states[p_target_id]
	var type_key: String = _type_key(p_type)
	if not char_states.has(type_key):
		return 0
	var entries: Array = char_states[type_key]
	var total: int = 0
	for entry: Variant in entries:
		if entry is Dictionary:
			var entry_dict: Dictionary = entry
			var stacks: int = int(entry_dict.get("stacks", 0))
			var amount: int = int(entry_dict.get("amount", 0))
			total += stacks * amount
	return total


## DebuffType → 字典键名（转发 [method key_of_type]——本方法原先是实现处，
## 改由 [constant TYPE_KEYS] 供数后只留这层转发，调用点一字未改）。
func _type_key(p_type: int) -> String:
	return key_of_type(p_type)
