class_name CombatOutcomeLines
extends RefCounted
## CombatOutcomeLines —— 战斗结局行文案内核（纯函数）。
##
## [b]职责[/b]：把「本场结果 + 是不是渡劫战」映射成[b]一行中文[/b]，
## 供顶部条在 [code]battle_ended[/code] 时写进战斗日志
## （[method CombatLog.append_entry]——与敌人行动播报同一入口，不另造渲染）。[br]
## [br][b]此前的问题[/b]：顶部条的 [code]_on_battle_ended[/code] 只清空日志、
## 丢掉整个结果，玩家翻开战斗日志看不到「刚才那场是不是渡劫、赢没赢」——
## 日志有开场没有结尾。[br]
## [br][b]为什么单独成一个模块[/b]：判定与措辞是纯映射（零依赖零副作用），
## 可以脱离场景逐档断言；顶部条那一侧只验「有没有落进日志、有没有清零」。
## 两件事分开测，红了能一眼看出是文案错还是接线错。[br]
## [br][b]两套语汇不许混用[/b]：渡劫战胜了写「渡劫功成」而不是「战斗胜利」——
## 玩家问的是「我这关过没过」，不是「谁把谁打没了」；反过来普通战斗
## 也绝不能出现「渡劫」字样（[br]见 [method mentions_tribulation]）。
##
## [b]纯函数[/b]（ADR-0031 Logic 内核模式）：无状态、无副作用、确定映射——单测零依赖。[br]
## [b]文案集中[/b]：本文件是渡劫结局措辞的唯一出处；普通战斗的胜利/战败标题
## [b]转引[/b] [SettlementRules]（结算面板已定的口径），不在此重写一份。
##
## @experimental
## 来源: ADR-0031、design/gdd/combat-ui-system.md §战斗日志/§9 战斗结算面板、
## .claude/rules/ui-code.md（UI 文本中文化）。

## 普通战斗胜利/战败标题的出处——结算面板先定的口径，本文件转引（同源不重写）。
const Rules := preload("res://src/ui/combat/shared/settlement_rules.gd")
## 战斗结果枚举的出处（[code]battle_ended[/code] 载荷的取值）。
const CombatScript := preload("res://src/feature/combat_system.gd")

## === 文案常量 ================================================================

## 结局行前缀——日志里与敌人行动播报（[code][1·抽牌] …[/code]）区分开，
## 也让 [method is_outcome_entry] 能把结局行认出来。
const PREFIX: String = "【战斗结束】"

## 渡劫战胜利。
const TEXT_TRIB_VICTORY: String = "渡劫功成"
## 渡劫战失败（含被打死与撤退——渡劫战中撤退同判失败，见
## [method TribulationCombat.on_battle_ended]）。
const TEXT_TRIB_FAILURE: String = "渡劫失败"
## 渡劫战中途撤退。
const TEXT_TRIB_RETREAT: String = "渡劫中断"
## 普通战斗撤退——写成句子而非光秃秃的「撤退」二字：日志行要能独立读懂，
## 也避免与撤退按钮文案（[constant RetreatRules.TEXT_RETREAT_BUTTON]）
## 变成同一份字面量抄两处。
const TEXT_RETREAT: String = "我方撤退"

## 结果未定时（[constant CombatSystem.CombatResult.NONE]）的落点文案。
const TEXT_UNKNOWN: String = "战斗结束"


# ═══════════════════════════════════════════════════════════════════════════════
# 结局行构建
# ═══════════════════════════════════════════════════════════════════════════════

## 结局日志行。[br]
## [br][b]返回恒非空[/b]：未知结果也返回一条可读的「战斗结束」行，不返回空串——
## 调用方拿到空串等于「没记」，玩家翻日志只看到一场没有结尾的战斗。[br]
## [br][param result]: [code]CombatSystem.CombatResult[/code] 取值。[br]
## [param is_tribulation]: 本场是否渡劫战（缺省 = 普通战斗）。
static func outcome_entry(result: int, is_tribulation: bool = false) -> String:
	if is_tribulation:
		return PREFIX + _tribulation_text(result)
	return PREFIX + _normal_text(result)


## 结局行是否带渡劫语汇（顶部条 / 消费方可据此判定，不必散落字符串比较）。
static func mentions_tribulation(line: String) -> bool:
	return line.contains(TEXT_TRIB_VICTORY) or line.contains(TEXT_TRIB_FAILURE) \
			or line.contains(TEXT_TRIB_RETREAT)


## 该日志条目是否为结局行（前缀判别）。
static func is_outcome_entry(entry: String) -> bool:
	return entry.begins_with(PREFIX)


# ═══════════════════════════════════════════════════════════════════════════════
# 内部：两套语汇
# ═══════════════════════════════════════════════════════════════════════════════

## 普通战斗结局措辞——胜利/战败转引结算面板的标题（[class SettlementRules]），
## 撤退与未知结果在本文件定稿。
static func _normal_text(result: int) -> String:
	match result:
		CombatScript.CombatResult.VICTORY:
			return Rules.TEXT_VICTORY_TITLE
		CombatScript.CombatResult.DEFEAT:
			return Rules.TEXT_DEFEAT_TITLE
		CombatScript.CombatResult.RETREAT:
			return TEXT_RETREAT
		_:
			return TEXT_UNKNOWN


## 渡劫战结局措辞——不再借「战斗胜利 / 战败」的措辞：渡劫战的头等事实是
## 「过没过这一关」。[br]
## [br][b]撤退单独成一档[/b]：渡劫战里撤退规则上不可用（战斗侧把非 VICTORY
## 一律判失败），但真发生时日志该如实记「自己退的」而不是「被打死的」——
## 显示层记事实，战斗域的胜负判定是另一层，两者不互相冒充。
static func _tribulation_text(result: int) -> String:
	match result:
		CombatScript.CombatResult.VICTORY:
			return TEXT_TRIB_VICTORY
		CombatScript.CombatResult.RETREAT:
			return TEXT_TRIB_RETREAT
		CombatScript.CombatResult.DEFEAT:
			return TEXT_TRIB_FAILURE
		_:
			return TEXT_UNKNOWN
