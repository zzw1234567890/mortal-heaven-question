extends RefCounted
## EnemyActionText —— 敌方行动播报的纯文本工具（命名 / 行文 / 去重键）。
##
## [b]职责[/b][br]
##   1. 把 [code]enemy_action_resolved[/code] 载荷折成一行中文战报；[br]
##   2. 解析敌我角色显示名（敌方读开战名册模板，我方读卡牌模板）；[br]
##   3. 生成载荷去重键（同一批播报内完全相同的载荷只播一次）。[br]
## [br][b]为什么独立成文件[/b]：这些是纯函数（无节点/无信号），可以让单元测试
## 直接断言行文，而不必搭一套战斗场景；播报组件只负责队列与输入锁。
##
## 来源: design/gdd/combat-ui-system.md §回合切换与敌方行动的可观测性、
## combat-ui-interaction 002（敌方逐条播报）。

## 状态表——敌方 ID 派生约定（与落库/建卡同源）。
const RosterState := preload("res://src/feature/combat/combat_roster_state.gd")
## 名字解析口径（兜底文案 / 名册条目与卡牌模板取名的唯一实现处——在 Feature 层，
## 战报与播报共用同一句，见 [method Seeding.resolve_name]）。
const Seeding := preload("res://src/feature/combat/combat_roster_seeding.gd")

## 行动类型（与 [code]combat_enemy_turn.gd[/code] 常量同值）。
const ACTION_SKILL: StringName = &"skill"
const ACTION_RETREAT: StringName = &"retreat"
const ACTION_NONE: StringName = &"none"

## 名称缺省文案（不让空名把一行战报变成「对『』造成…」）——转引 Feature 层口径。
const NAME_UNKNOWN: String = Seeding.NAME_UNKNOWN

## 名称解析闭包——[code]func(character_id: int) -> String[/code]。
## 生产由 [method make_name_resolver] 生成；测试可直接给桩。


## 生成播报去重键——同一批内字段完全相同的载荷视为重复。[br]
## [br][b]为什么包含 hp_after[/b]：两次不同的攻击可能数值相同，但结算后的 HP
## 不同（例如目标被治疗过）；把它们合并会吞掉一次真实的播报。
static func duplicate_key(p_payload: Dictionary) -> String:
	return "%d|%s|%d|%d|%d|%d" % [
		int(p_payload.get("enemy_id", -1)),
		str(p_payload.get("action", "")),
		int(p_payload.get("target_id", -1)),
		int(p_payload.get("damage", 0)),
		1 if bool(p_payload.get("is_kill", false)) else 0,
		int(p_payload.get("hp_after", 0)),
	]


## 载荷 → 一行中文战报。[br]
## [br][param p_target_fallen] 目标在本条行动之前已阵亡（播报层兜底）——
## 为 true 时不重复显示阵亡角色名，改记「行动落空」。
static func format_line(p_payload: Dictionary, p_name_resolver: Callable = Callable(),
		p_target_fallen: bool = false) -> String:
	var enemy_name: String = _call_name(p_name_resolver,
			int(p_payload.get("enemy_id", -1)))
	var action: StringName = StringName(str(p_payload.get("action", "")))
	if action == ACTION_RETREAT:
		return "「%s」撤退了" % enemy_name
	var target_id: int = int(p_payload.get("target_id", -1))
	if action == ACTION_NONE or target_id < 0:
		return "「%s」没有可攻击的目标" % enemy_name
	if p_target_fallen:
		return "「%s」的行动落空（目标已阵亡）" % enemy_name
	var target_name: String = _call_name(p_name_resolver, target_id)
	if not bool(p_payload.get("known", false)):
		return "「%s」攻击「%s」（目标状态未知）" % [enemy_name, target_name]
	var damage: int = int(p_payload.get("damage", 0))
	var line: String = "「%s」对「%s」造成 %d 点伤害" % [enemy_name, target_name, damage]
	if bool(p_payload.get("is_kill", false)):
		# 不重复目标名：同一行里目标已经出现过一次，再写一遍会让玩家多数一次名字。
		line += "，将其击倒"
	return line


## 生成名称解析闭包——敌方优先开战名册模板的 [code]display_name[/code]，
## 我方回退卡牌模板的 [code]display_name[/code] / [code]name[/code]，
## 最后按 ID 段给可读兜底（不返回空串）。
static func make_name_resolver(p_combat: Node, p_card_system: Node) -> Callable:
	return func(character_id: int) -> String:
		return name_of(character_id, p_combat, p_card_system)


## 角色显示名——单一入口（闭包与直接调用共用同一套回退顺序）。[br]
static func name_of(p_character_id: int, p_combat: Node,
		p_card_system: Node) -> String:
	if p_character_id < 0:
		return NAME_UNKNOWN
	var enemy_name: String = _enemy_display_name(p_character_id, p_combat)
	if enemy_name != "":
		return enemy_name
	var card_name: String = _card_display_name(p_character_id, p_card_system)
	if card_name != "":
		return card_name
	return fallback_name(p_character_id)


## 兜底名——按 ID 段区分「敌人」与「角色」（转引 [code]CombatRosterSeeding[/code]：
## 战报的逐人行走的是同一句，两处各写一遍迟早分叉成一个说「角色」一个说「敌人」）。
static func fallback_name(p_character_id: int) -> String:
	return Seeding.fallback_name(p_character_id)


## 敌方显示名——本方法只负责「从战斗系统拿本场名册并按 ID 约定反查」这一跳；
## 条目取名（[code]display_name[/code] > 模板对象 > 模板 ID）归 Feature 层
## [method CombatRosterSeeding.enemy_display_name]——战报与播报读的是同一句。
static func _enemy_display_name(p_character_id: int, p_combat: Node) -> String:
	if p_combat == null or not p_combat.has_method(&"get_battle_enemy_roster"):
		return ""
	var raw: Variant = p_combat.call(&"get_battle_enemy_roster")
	if not (raw is Array):
		return ""
	var roster: Array = raw
	for idx: int in range(roster.size()):
		var entry: Variant = roster[idx]
		if RosterState.enemy_id_of(entry, idx) != p_character_id:
			continue
		return Seeding.enemy_display_name(entry)
	return ""


## 我方显示名——卡牌模板（[code]display_name[/code] 或旧字段 name），
## 取名实现转引 [method CombatRosterSeeding.card_display_name]。
static func _card_display_name(p_character_id: int, p_card_system: Node) -> String:
	return Seeding.card_display_name(p_card_system, p_character_id)


## 调用名称闭包——闭包缺失/抛错/返回空时回退可读编号。
static func _call_name(p_resolver: Callable, p_character_id: int) -> String:
	if p_resolver.is_valid():
		var resolved: Variant = p_resolver.call(p_character_id)
		if resolved != null and str(resolved) != "":
			return str(resolved)
	return fallback_name(p_character_id)
