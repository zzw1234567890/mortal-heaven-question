extends RefCounted
## CombatEndCheck —— 战斗结束判定纯函数内核（Logic 层，无副作用）。[br]
## [br][b]职责[/b]：Phase 6 END 的「战斗结束检查」——GDD combat-system.md §9：
## 敌方全灭 → 胜利；己方全灭 → 战败。[br]
## [br][b]为什么独立成文件[/b]：判定读三份外部状态（AI 敌方阵容 / DeploymentSystem
## 阵位 / 战前我方名册），做成纯函数后可直接单测四种组合，不必把
## CombatSystem + AISystem + DeploymentSystem 三个 Autoload 拼成测试现场。[br]
## [br][b]「信息不足则不判」原则[/b]（对齐 ADR-0016 §is_game_over 的必传 roster 裁决）：
## 敌方阵容为空 / 我方名册为空 / 我方阵位从未被布置（[param field_engaged] 为 false）
## 时一律返回 NONE——宁可打不完这一局，也不能因为「读不到数据」误判胜负。[br]
## [br]来源: GDD combat-system.md §9 战斗结束规则、ADR-0008 §Phase 6、
## gate-check 2026-11-08 §B1（END 阶段检查原为桩）。

## 战斗结果——[b]直接引[/b] [enum CombatSystem.CombatResult]。[br]
## [br][b]为什么不再是镜像字面量[/b]：本模块曾自持一份 [code]NONE=0 / VICTORY=1 /
## DEFEAT=2[/code] 的镜像，理由是「子模块不反向依赖父节点枚举」。但同一份数字抄两处
## 就会漂移——渡劫侧正是栽在这种「字面量与枚举分叉」上（[code]tribulation_combat.gd[/code]
## 曾用 [code]0[/code] 判胜，打赢被判成输）。判据只有一个出处才不会再分叉。[br]
## [br][b]preload 不成环[/b]：父节点对本模块的引用是 [code]combat_battle_wiring.gd[/code]
## 的 preload，而父节点自身不被 preload 链回头引用（同 [code]combat_battle_record.gd[/code]
## 引用父枚举的先例）。
const CombatScript := preload("res://src/feature/combat_system.gd")
const RESULT_NONE: int = CombatScript.CombatResult.NONE
const RESULT_VICTORY: int = CombatScript.CombatResult.VICTORY
const RESULT_DEFEAT: int = CombatScript.CombatResult.DEFEAT

## 空位哨兵（DeploymentSystem 空位 character_id = -1）。
const EMPTY_CHARACTER_ID: int = -1


## 判定战斗是否结束。[br]
## [br][param enemy_roster] 敌方阵容（AISystem 持有——EnemyBattleState 或等效 Dictionary）。[br]
## [param player_field] 我方阵位（DeploymentSystem.get_field() 返回值）。[br]
## [param player_roster] 本场战斗上场角色 ID 列表（battle_start 的 config 名册）。[br]
## [param field_engaged] 本场战斗中我方阵位是否曾处于「有人」状态。[br]
## [br][b]返回[/b]：[constant RESULT_VICTORY] / [constant RESULT_DEFEAT] / [constant RESULT_NONE]。
static func evaluate(enemy_roster: Array, player_field: Array, player_roster: Array, field_engaged: bool) -> int:
	if _all_enemies_dead(enemy_roster):
		return RESULT_VICTORY
	if not field_engaged or player_roster.is_empty():
		return RESULT_NONE
	for entry: Variant in player_field:
		if is_occupied(entry):
			return RESULT_NONE
	return RESULT_DEFEAT


## 敌方全灭判定——空阵容不算全灭（无信息）。[br]
## [br]撤退的敌人由 AISystem 的 enemy_retreated 单独广播（GDD §9 奖励减半），
## 本判定只认「阵亡」——撤退不计入胜利，留待 interaction epic 接线后裁决。
static func _all_enemies_dead(enemy_roster: Array) -> bool:
	if enemy_roster.is_empty():
		return false
	for entry: Variant in enemy_roster:
		if is_alive(entry):
			return false
	return true


## 敌方条目存活判定——兼容 EnemyBattleState（对象）与 Dictionary 桩。[br]
## [br]判定顺序：is_alive 属性 > current_hp > 0；两者都读不到时按存活处理（不误判胜利）。
static func is_alive(entry: Variant) -> bool:
	if entry == null:
		return false
	if entry is Dictionary:
		if (entry as Dictionary).has("is_alive"):
			return bool(entry["is_alive"])
		return int((entry as Dictionary).get("current_hp", 1)) > 0
	if entry is Object:
		var obj: Object = entry as Object
		var alive: Variant = obj.get("is_alive")
		if alive != null:
			return bool(alive)
		var hp: Variant = obj.get("current_hp")
		if hp != null:
			return int(hp) > 0
	return true


## 阵位条目是否有人——以 character_id 非空位哨兵为唯一判据
## （DeploymentSystem.remove_character 会同时把 state 置 EMPTY 并写回 -1）。
static func is_occupied(entry: Variant) -> bool:
	if entry is Dictionary:
		return int((entry as Dictionary).get("character_id", EMPTY_CHARACTER_ID)) != EMPTY_CHARACTER_ID
	if entry is Object and (entry as Object).has_method("get"):
		return int((entry as Object).get("character_id")) != EMPTY_CHARACTER_ID
	return false
