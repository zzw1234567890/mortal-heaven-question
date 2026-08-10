## EventSystem.ConditionChecker —— 条件判定引擎（提取自 event_system.gd）。
##
## 纯函数类——不持有状态，不依赖 EventSystem 实例。
## 所有条件判定通过 [method check_condition] 分发到 6 个私有检查器。
## 各检查器通过 [GameStateManager] Autoload 读取运行时状态。
##
## [b]提取原因[/b]：event_system.gd 570 行 → 拆分为 4 文件（Story 2-13 技术债）。
##
## 来源: ADR-0003。

extends RefCounted


## 根据条件类型和参数判定条件是否满足。[br]
## [br]通过 GSM 第一层直接读取——零开销 O(1) 字典访问。[br]
## 支持 6 种 ConditionType：[br]
##   - [code]REALM[/code] — 境界比较（按 operator: GE/EQ/LT vs value_int）[br]
##   - [code]FACTION[/code] — 阵营匹配（从 narrative.story_flags["player_faction"] 读取）[br]
##   - [code]RESOURCE[/code] — 资源数量比较（按 operator 比较 value_int）[br]
##   - [code]CARD_OWNED[/code] — 是否拥有指定卡牌（在 collection.owned_cards 中查找 value_str）[br]
##   - [code]FLAG_SET[/code] — story_flag 等于 value_str[br]
##   - [code]FLAG_NOT_SET[/code] — story_flag 不等于 value_str（含不存在）[br]
## [br][b]返回[/b]: 条件满足时 [code]true[/code]，否则 [code]false[/code]。未知 ConditionType 返回 [code]false[/code]。
func check_condition(cond: EventCondition) -> bool:
	if cond == null:
		return false

	match cond.type:
		EventEnums.ConditionType.REALM:
			return _check_realm_condition(cond)

		EventEnums.ConditionType.FACTION:
			return _check_faction_condition(cond)

		EventEnums.ConditionType.RESOURCE:
			return _check_resource_condition(cond)

		EventEnums.ConditionType.CARD_OWNED:
			return _check_card_owned_condition(cond)

		EventEnums.ConditionType.FLAG_SET:
			return _check_flag_set_condition(cond, true)

		EventEnums.ConditionType.FLAG_NOT_SET:
			return _check_flag_set_condition(cond, false)

	return false


func _check_realm_condition(cond: EventCondition) -> bool:
	var player_realm: int = GameStateManager.get_state("player.realm")
	match cond.operator:
		EventEnums.ConditionOperator.GE:
			return player_realm >= cond.value_int
		EventEnums.ConditionOperator.EQ:
			return player_realm == cond.value_int
		EventEnums.ConditionOperator.LT:
			return player_realm < cond.value_int
	return false


func _check_faction_condition(cond: EventCondition) -> bool:
	# H-2 已知偏差（待解决）：ADR-0003 §check_condition 规定 FACTION 从 GSM.player.faction 读取，
	# 但 GSM player 域无 faction 字段。当前回退：从 narrative.story_flags["player_faction"] 读取。
	# player.faction 归属不属本故事范围——待身份选择系统（ADR-0022）或后续玩家数据结构
	# story 明确归属后，更新本方法与 ADR-0003 §check_condition 契约。
	var player_faction: String = ""
	var flags: Variant = GameStateManager.get_state("narrative.story_flags")
	if flags is Dictionary and flags.has("player_faction"):
		player_faction = str(flags["player_faction"])
	return player_faction == cond.value_str


func _check_resource_condition(cond: EventCondition) -> bool:
	var resources: Dictionary = GameStateManager.get_state("player.resources")
	if resources == null:
		return false
	var amount: int = 0
	var raw: Variant = resources.get(cond.target, 0)
	# ling_cai 是嵌套字典 {low,medium,high,top}——条件判定时求四品质总和
	if raw is Dictionary:
		var lc: Dictionary = raw
		amount = int(lc.get("low", 0)) + int(lc.get("medium", 0)) + int(lc.get("high", 0)) + int(lc.get("top", 0))
	else:
		amount = int(raw)
	match cond.operator:
		EventEnums.ConditionOperator.GE:
			return amount >= cond.value_int
		EventEnums.ConditionOperator.EQ:
			return amount == cond.value_int
		EventEnums.ConditionOperator.LT:
			return amount < cond.value_int
	return false


func _check_card_owned_condition(cond: EventCondition) -> bool:
	var owned_cards: Array = GameStateManager.get_state("collection.owned_cards")
	if owned_cards == null:
		return false
	for card in owned_cards:
		if card is Dictionary and card.get("template_id", "") == cond.value_str:
			return true
	return false


func _check_flag_set_condition(cond: EventCondition, expect_set: bool) -> bool:
	var flags: Variant = GameStateManager.get_state("narrative.story_flags")
	if flags == null:
		return not expect_set
	var has_flag: bool = flags.has(cond.target)
	if not has_flag:
		return not expect_set
	var flag_value: String = str(flags[cond.target])
	if expect_set:
		return flag_value == cond.value_str
	else:
		# FLAG_NOT_SET: 键存在但值不等也算不满足
		return flag_value != cond.value_str