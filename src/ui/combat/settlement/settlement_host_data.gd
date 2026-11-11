class_name SettlementHostData
extends RefCounted
## SettlementHostData —— 结算宿主的数据快照与载荷构建工具（拆分自 settlement_host）。[br]
##
## [b]职责[/b]：卡组张数/上限读取、战利品选项映射、战败摘要构建——
## 纯函数逻辑，不持有宿主状态，不接线信号。[br]
## [br][b]拆分理由[/b]：settlement_host.gd 超 300 行软上限（编码标准），
## 数据逻辑与宿主编排解耦。

const Rules := preload("res://src/ui/combat/shared/settlement_rules.gd")


## 卡组张数/上限（[code]get_deck_summary()[/code] 现读；缺失时 0/0）。[br]
## [br][b]返回[/b]: [code]{count, limit}[/code]。
static func deck_counts(deck_system: Node) -> Dictionary:
	if deck_system == null or not deck_system.has_method(&"get_deck_summary"):
		return {"count": 0, "limit": 0}
	var summary: Dictionary = deck_system.call(&"get_deck_summary") as Dictionary
	if summary == null:
		return {"count": 0, "limit": 0}
	return {
		"count": int(summary.get("total", 0)),
		"limit": int(summary.get("limit", 0)),
	}


## 胜利面板的战利品选项（GDD §9「卡牌正面 / 消耗品」）。[br]
## [br][b]不做战利品生成逻辑[/b]（Out of Scope）：只把战斗系统已给出的
## [code]cards[/code] / [code]consumables[/code] 映射成选项；灵石是全局奖励，
## 始终发放，不列入三选一选项。不足 3 项时按实际数量展示（不伪造填充项）。[br]
## [br][b]上游缺口[/b]：`CombatSystem._settle_result()` 暂不产出 `consumables`——
## 映射已就位，战斗系统补字段后无需改 UI（DEBT-CUI-008-3）。
static func victory_options(rewards: Dictionary) -> Array:
	var options: Array = map_entries(rewards.get("cards", []), Rules.OPTION_KIND_CARD)
	options.append_array(map_entries(rewards.get("consumables", []),
			Rules.OPTION_KIND_CONSUMABLE))
	return options


## 把一类奖励列表映射成战利品选项（字典深拷贝后补 kind；字符串退化为只带 name）。[br]
## [param entries]: 奖励列表（字典或字符串）。[br]
## [param kind]: [constant SettlementRules.OPTION_KIND_*] 取值。
static func map_entries(entries: Variant, kind: String) -> Array:
	var result: Array = []
	if not (entries is Array):
		return result
	for item: Variant in entries:
		if item is Dictionary:
			var entry: Dictionary = (item as Dictionary).duplicate(true)
			entry["kind"] = kind
			result.append(entry)
		elif item is String or item is StringName:
			result.append({"kind": kind, "name": str(item)})
	return result


## 战败损失摘要（AC-5）——阵亡名单与绑定卡张数由注入/载荷提供。[br]
## [br][b]数据源优先级[/b]：[param rewards] 载荷字段 > [param dead_names] /
## [param binding_card_count] 注入的上下文 > 0/空（[b]不自行推算阵亡名单[/b]——
## 角色状态归战斗系统）。
static func defeat_summary(rewards: Dictionary, dead_names: Array = [],
		binding_card_count: int = 0) -> Dictionary:
	var source: Variant = rewards.get("dead_names", dead_names)
	var final_dead: Array = []
	if source is Array:
		final_dead = (source as Array).duplicate()
	var final_binding: int = int(rewards.get("binding_card_count", binding_card_count))
	return {
		"cultivation_lost": int(rewards.get("cultivation_lost", 0)),
		"dead_names": final_dead,
		"binding_card_count": final_binding,
	}
