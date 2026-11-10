extends RefCounted
## CombatBattleRecord —— 本场战绩累积器 + 定格（Sprint 18 结算回流）。[br]
## [br][b]职责[/b]：战斗期间累计「打了多少效果条目」，战斗结束时把
## 胜负 / 回合数 / 双方剩余 HP / 效果条目数定格成一个纯数据 Dictionary，
## 交 [method CombatSystem.battle_end] 并入 [signal CombatSystem.battle_ended] 的载荷。[br]
## [br][b]为什么独立成文件[/b]：计数是战斗期间累积、结束瞬间定格的独立关注点；
## 放父节点会让 1100+ 行的聚合体再长一截，且计数口径需要单测锁死
## （同 [code]combat_end_check.gd[/code] / [code]combat_roster_state.gd[/code] 先例）。[br]
## [br][b]计数口径[/b]（[member effect_entries]）：[b]进入执行端的效果条目数[/b]——[br]
##   · 出牌「打出即生效」：[method CombatOnPlayEffects.collect] 中每条匹配
##     [code]TRIGGER_ON_PLAY[/code] 的条目计一条（含尚未建模的增益/控制/抽牌——
##     它们同样是「被触发」的条目，只是没有执行端）；[br]
##   · 击杀触发：[method CombatKillTrigger.trigger] 中每条匹配 [code]TRIGGER_KILL[/code]
##     的条目计一条（仅在击杀事实成立、卡牌与施法者都取得到时）。[br]
## [br][b]不计入[/b]：Phase 4 攻击队列的普通攻击（那不是卡效果条目）、
## 被拒绝的出牌（阶段/费用/目标校验不过的卡不产生任何条目）。[br]
## [br][b]双方剩余 HP[/b]：取自 [method CombatRosterState.snapshot_all]
## （本场状态表）——故必须在 [code]battle_end[/code] 清空状态表[b]之前[/b]定格。[br]
## [br][b]信息不足不臆造[/b]（同 [code]combat_end_check.gd[/code]）：HP 数据不可信
## （[code]known=false[/code]）的条目照实进 [code]roster[/code] 并计入
## [code]unknown_count[/code]，但[b]不参与[/b] [code]remaining_hp[/code] 求和——
## 读不到数据时宁可少算，也不拿 0 冒充「满血阵亡」。[br]
## [br]来源: production/session-state/active.md（Sprint 18 结算回流）、
## ADR-0008 §生命周期 §信号分类、GDD combat-system.md §9。

## 阵营常量——镜像 [code]combat_roster_state.gd[/code]（0 己方 / 1 敌方）。
const SIDE_PLAYER: int = 0
const SIDE_ENEMY: int = 1

## 结局文本标记（稳定 token——中文文案归 UI，本模块只给数据）。
const OUTCOME_NONE: String = "none"
const OUTCOME_VICTORY: String = "victory"
const OUTCOME_DEFEAT: String = "defeat"
const OUTCOME_RETREAT: String = "retreat"

## 结局枚举值 → token（镜像 CombatSystem.CombatResult：0 无 / 1 胜 / 2 败 / 3 撤退）。
const OUTCOME_BY_RESULT: Dictionary = {
	0: OUTCOME_NONE,
	1: OUTCOME_VICTORY,
	2: OUTCOME_DEFEAT,
	3: OUTCOME_RETREAT,
}

## 本场「进入执行端的效果条目数」。
var _effect_entries: int = 0


## 开战重置——每场一份，battle_start 调用。
func reset() -> void:
	_effect_entries = 0


## 累计触发的效果条目数（负值忽略——计数只增不减）。
func note_effect_entry(count: int = 1) -> void:
	_effect_entries += maxi(count, 0)


## 当前累计的触发条目数（只读）。
func effect_entry_count() -> int:
	return _effect_entries


## 定格本场战绩。[br]
## [br][param result] [code]CombatSystem.CombatResult[/code] 取值。[br]
## [param turn] 结束时的回合数（[code]CombatSystem._turn[/code]）。[br]
## [param entries] [method CombatRosterState.snapshot_all] 的产出（须在状态表清空前取）。[br]
## [br][b]返回[/b]：纯数据 Dictionary——[code]{result, outcome, turn_count,
## effect_entries, player, enemy}[/code]，其中 [code]player[/code] / [code]enemy[/code]
## 各为 [code]{count, alive_count, remaining_hp, unknown_count, roster} [/code]。[br]
## [br][b]不含中文文案[/b]：结算对象的展示职责在 UI 侧（[code]CombatResultView[/code]）。
func build(result: int, turn: int, entries: Array) -> Dictionary:
	var player: Dictionary = _fold_side(entries, SIDE_PLAYER)
	var enemy: Dictionary = _fold_side(entries, SIDE_ENEMY)
	return {
		"result": result,
		"outcome": OUTCOME_BY_RESULT.get(result, OUTCOME_NONE),
		"turn_count": maxi(turn, 0),
		"effect_entries": _effect_entries,
		"player": player,
		"enemy": enemy,
	}


## 单侧汇总——活人数 / 剩余 HP 总和 / 未知条目数 / 逐条明细（按 character_id 升序）。
func _fold_side(entries: Array, side: int) -> Dictionary:
	var roster: Array = []
	var alive_count: int = 0
	var remaining_hp: int = 0
	var unknown_count: int = 0
	for raw: Variant in entries:
		if not (raw is Dictionary):
			continue
		var entry: Dictionary = raw
		if int(entry.get("side", SIDE_PLAYER)) != side:
			continue
		var known: bool = bool(entry.get("known", false))
		var is_alive: bool = bool(entry.get("is_alive", true))
		if known:
			remaining_hp += maxi(int(entry.get("current_hp", 0)), 0)
			if is_alive:
				alive_count += 1
		else:
			unknown_count += 1
		roster.append({
			"character_id": int(entry.get("character_id", -1)),
			"current_hp": int(entry.get("current_hp", 0)),
			"max_hp": int(entry.get("max_hp", 0)),
			"is_alive": is_alive,
			"known": known,
		})
	roster.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["character_id"]) < int(b["character_id"]))
	return {
		"count": roster.size(),
		"alive_count": alive_count,
		"remaining_hp": remaining_hp,
		"unknown_count": unknown_count,
		"roster": roster,
	}
