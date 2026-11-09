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
## [br]攻击队列格式：[code]{attacker_id, target_id, attacker_atk, target_def,
## attacker_realm, defender_realm, target_hp}[/code]，可选 [code]damage_reduction_pcts[/code]
## （防御方百分比减伤列表，DEBT-CBT-018-8；缺省 = 无减伤）。[br]
## [br]Sprint 8 Story 005：is_kill 从目标 HP 派生（final_damage >= target_hp）。[br]
## [br][b]返回[/b]（Sprint 18 / DEBT-CBT-018-1）：本次结算的攻击条目与载荷配对列表
## [code][{entry, payload}][/code]，供父节点交 [code]combat_damage_settlement.gd[/code]
## 回写 HP——本模块只算伤害不持有角色状态（与 [method calculate_damage] 的纯函数口径一致）。
func resolve_attack_queue() -> Array:
	var settled: Array = []
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
		# DEBT-CBT-018-8：防御方百分比减伤（缺省空 = 无减伤，旧队列格式不受影响）
		var reduction_pcts: Array = entry.get("damage_reduction_pcts", [])
		var dmg_result: Dictionary = calculate_damage(atk, def, atk_realm, def_realm, reduction_pcts)
		# Sprint 8 Story 005：is_kill 从目标 HP 派生
		var target_hp: int = int(entry.get("target_hp", 0))
		var is_kill: bool = target_hp > 0 and dmg_result["final_damage"] >= target_hp
		# AC-005：attack_resolved 使用具名字典格式（ADR-0007 >3 参数规则）
		# damage_reduced：本次伤害是否被百分比减伤（false = 无减伤）——
		# 由 calculate_damage 的乘算系数派生，表现层据此给飘字「减」角标
		var payload: Dictionary = {
			"attacker_id": attacker_id,
			"target_id": target_id,
			"damage": dmg_result["final_damage"],
			"is_kill": is_kill,
			"damage_reduced": float(dmg_result["damage_reduction_multiplier"]) < 1.0,
		}
		_parent.call("_emit_safe", &"attack_resolved", [payload])
		settled.append({"entry": entry, "payload": payload})
	return settled


## 计算最终伤害——`max(1, ATK - DEF) × realm_penalty`（AC-008/009）。[br]
## [br][param attacker_atk] 攻击者攻击力。[br]
## [br][param target_def] 目标防御力。[br]
## [br][param attacker_realm] 攻击者境界等级。[br]
## [br][param defender_realm] 防御者境界等级。[br]
## [br][b]返回[/b]: [code]{actual_damage, realm_penalty, final_damage, damage_reduction_multiplier}[/code]
## Dictionary（[code]damage_reduction_multiplier[/code] 为 DEBT-CBT-018-8 新增，见下）。[br]
## [br][b]方向性约定[/b]：GDD §3 规定压制仅影响玩家→敌方的伤害。本函数作为纯函数
## 不校验调用方向——方向性由调用方保证（玩家攻击时玩家为 attacker）。
## [br][param damage_reduction_pcts] 防御方各来源的百分比减伤（如 [code][10, 15][/code]）——
## GDD combat-system.md §公式：DEF 结算[b]之后[/b]乘算叠加，上限 60%（[method CardEffectEvaluator.combine_damage_reduction]）。[br]
## [br][b]重载兼容[/b]：本参数追加在末尾且默认空——既有 4 参调用点（GDD 公式 1/2 的纯函数测试）行为不变。
func calculate_damage(attacker_atk: int, target_def: int, attacker_realm: int, defender_realm: int,
		damage_reduction_pcts: Array = []) -> Dictionary:
	# AC-008：actual_damage = max(1, ATK - DEF)
	var actual_damage: int = maxi(1, attacker_atk - target_def)
	# AC-009~012：realm_penalty 来自 RealmSystem.realm_penalty
	var penalty: float = _get_realm_penalty(attacker_realm, defender_realm)
	# AC-009：final_damage = floor(actual_damage × realm_penalty)
	var final_damage: int = floori(float(actual_damage) * penalty)
	# DEBT-CBT-018-8：百分比减伤在 DEF 结算后乘算（GDD combat-system.md §公式）
	var reduction: Dictionary = CardEffectEvaluator.combine_damage_reduction(damage_reduction_pcts)
	final_damage = floori(float(final_damage) * float(reduction["multiplier"]))
	# 最低保底 1 点伤害
	final_damage = maxi(1, final_damage)
	return {
		"actual_damage": actual_damage,
		"realm_penalty": penalty,
		"final_damage": final_damage,
		"damage_reduction_multiplier": reduction["multiplier"],
	}


## 获取境界压制系数——通过 RealmSystem Autoload。[br]
## [br][b]桩实现[/b]——RealmSystem 不可用时返回 1.0（无压制）。[br]
## [br][b]方向性约定[/b]：压制仅影响玩家→敌方（GDD §3），调用方保证方向。
func _get_realm_penalty(attacker_realm: int, defender_realm: int) -> float:
	var rs = _parent.call("_get_realm_system")
	if rs != null and rs.has_method("realm_penalty"):
		return float(rs.realm_penalty(attacker_realm, defender_realm))
	return 1.0
