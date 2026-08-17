## GameStateSnapshot —— AI 干跑评估的不可变快照。
##
## 承载 AI 评估所需的机制数据（角色 HP/ATK、状态、绑定乘数）的浅拷贝。
## 不含动画/UI/音效/VFX 数据（ADR-0009 L257）。
##
## [b]不可变约定[/b]：构造后字段不提供 setter——所有读取通过 getter 返回
## 深拷贝（[code]duplicate(true)[/code]），防止外部修改污染快照。
## 评估路径（[CardEffectEvaluator]）在此快照上执行纯计算，绝不修改它。
##
## [b]无 GSM 依赖[/b]：从 GSM 构建快照的接线属 CardEffectEngine Autoload 层
## （[code]create_evaluation_snapshot()[/code]），本类是纯数据容器，可独立测试。
##
## 来源: ADR-0009 §AI 评估接口 / GDD §10 AI 效果评估接口。
class_name GameStateSnapshot
extends RefCounted


# === 内部数据 =====================================================================

## 角色数据——[code]{character_id: {hp, max_hp, atk, statuses, binding_multiplier}}[/code]。
## 私有字段，仅通过 getter 深拷贝访问。
var _characters: Dictionary = {}


# === 构造 =========================================================================

## 构建快照。[br]
## [br][param characters] 角色数据字典（[code]{character_id: {hp, max_hp, atk, statuses, binding_multiplier}}[/code]）。
## 内部深拷贝一次——后续外部修改不影响快照。
func _init(characters: Dictionary = {}) -> void:
	_characters = characters.duplicate(true)


## 静态工厂——构建空快照（测试便利）。
static func build(characters: Dictionary) -> GameStateSnapshot:
	return GameStateSnapshot.new(characters)


# === 只读访问 =====================================================================

## 获取某角色的数据深拷贝。[br]
## [br][param character_id] 角色 ID。[br]
## [br][b]返回[/b]: [code]{hp, max_hp, atk, statuses, binding_multiplier}[/code] 字典深拷贝；
## 不存在返回空字典。
func get_character(character_id: int) -> Dictionary:
	if not _characters.has(character_id):
		return {}
	return _characters[character_id].duplicate(true)


## 获取某角色当前 HP（不存在返回 0）。
func get_hp(character_id: int) -> int:
	return _characters.get(character_id, {}).get("hp", 0)


## 获取某角色最大 HP（不存在返回 0）。
func get_max_hp(character_id: int) -> int:
	return _characters.get(character_id, {}).get("max_hp", 0)


## 获取某角色的预计算绑定乘数（不存在返回 1.0）。
func get_binding_multiplier(character_id: int) -> float:
	return _characters.get(character_id, {}).get("binding_multiplier", 1.0)


## 获取全部角色 ID（用于遍历评估候选）。
func get_character_ids() -> Array:
	return _characters.keys()


## 快照中角色总数。
func size() -> int:
	return _characters.size()
