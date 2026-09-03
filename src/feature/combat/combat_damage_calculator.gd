## CombatDamageCalculator —— 伤害计算 + 攻击结算子模块（RefCounted）。
##
## 从 combat_system.gd 提取的伤害计算 + 攻击队列结算逻辑。[br]
## 持有父节点 CombatSystem 引用，通过它访问 _attack_queue / RealmSystem / _emit_safe。[br]
## [br]来源: ADR-0008 §攻击结算 / GDD combat-system.md §3。[br]
## [br]Sprint 8 Story 8-10：从 combat_system.gd 拆分。
extends RefCounted


## 父节点引用——CombatSystem Autoload 实例。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


## 攻击队列结算——Phase 4 ATTACK_RESOLUTION 入口。[br]
## [br]遍历 _attack_queue，对每条攻击记录调用 calculate_damage 计算伤害，[br]
## 发射 attack_resolved 信号（Cat 2b 具名字典格式——ADR-0007）。[br]
## [br]攻击队列格式：[code]{attacker_id, target_id, attacker_atk, target_def, attacker_realm, defender_realm, target_hp}[/code][br]
## [br]Sprint 8 Story 005：is_kill 从目标 HP 派生（final_damage >= target_hp）。
func resolve_attack_queue() -> void:
	var queue: Array = _parent.get("_attack_queue")
	for entry in queue:
		if not (entry is Dictionary):
			continue
		var attacker_id: int = int(entry.get("attacker_id", -1))
		var target_id: int = int(entry.get("target_id", -1))
		if attacker_id < 0 or target_id < 0:
			push_warning("CombatSystem: _resolve_attack_queue skipping entry with invalid id")
			continue
		var atk: int = int(entry.get("attacker_atk", 0))
		var def: int = int(entry.get("target_def", 0))
		var atk_realm: int = int(entry.get("attacker_realm", 1))
		var def_realm: int = int(entry.get("defender_realm", 1))
		var dmg_result: Dictionary = calculate_damage(atk, def, atk_realm, def_realm)
		# Sprint 8 Story 005：is_kill 从目标 HP 派生
		var target_hp: int = int(entry.get("target_hp", 0))
		var is_kill: bool = target_hp > 0 and dmg_result["final_damage"] >= target_hp
		# AC-005：attack_resolved 使用具名字典格式（ADR-0007 >3 参数规则）
		var payload: Dictionary = {
			"attacker_id": attacker_id,
			"target_id": target_id,
			"damage": dmg_result["final_damage"],
			"is_kill": is_kill,
		}
		_parent.call("_emit_safe", &"attack_resolved", [payload])


## 计算最终伤害——`max(1, ATK - DEF) × realm_penalty`（AC-008/009）。[br]
## [br][param attacker_atk] 攻击者攻击力。[br]
## [br][param target_def] 目标防御力。[br]
## [br][param attacker_realm] 攻击者境界等级。[br]
## [br][param defender_realm] 防御者境界等级。[br]
## [br][b]返回[/b]: [code]{actual_damage, realm_penalty, final_damage}[/code] Dictionary。[br]
## [br][b]方向性约定[/b]：GDD §3 规定压制仅影响玩家→敌方的伤害。本函数作为纯函数
## 不校验调用方向——方向性由调用方保证（玩家攻击时玩家为 attacker）。
func calculate_damage(attacker_atk: int, target_def: int, attacker_realm: int, defender_realm: int) -> Dictionary:
	# AC-008：actual_damage = max(1, ATK - DEF)
	var actual_damage: int = maxi(1, attacker_atk - target_def)
	# AC-009~012：realm_penalty 来自 RealmSystem.realm_penalty
	var penalty: float = _get_realm_penalty(attacker_realm, defender_realm)
	# AC-009：final_damage = floor(actual_damage × realm_penalty)
	var final_damage: int = floori(float(actual_damage) * penalty)
	# 最低保底 1 点伤害
	final_damage = maxi(1, final_damage)
	return {
		"actual_damage": actual_damage,
		"realm_penalty": penalty,
		"final_damage": final_damage,
	}


## 获取境界压制系数——通过 RealmSystem Autoload。[br]
## [br][b]桩实现[/b]——RealmSystem 不可用时返回 1.0（无压制）。[br]
## [br][b]方向性约定[/b]：压制仅影响玩家→敌方（GDD §3），调用方保证方向。
func _get_realm_penalty(attacker_realm: int, defender_realm: int) -> float:
	var rs = _parent.call("_get_realm_system")
	if rs != null and rs.has_method("realm_penalty"):
		return float(rs.realm_penalty(attacker_realm, defender_realm))
	return 1.0
