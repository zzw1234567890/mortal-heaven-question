extends RefCounted
## CombatSceneBattleSetup —— 进入战斗前的开战前置（布阵 / 牌堆 / 敌方阵容）。[br]
## [br][b]职责[/b]：把 [code]CombatScene._start_battle[/code] 需要的三份输入一次备齐——[br]
##   1. [b]布阵[/b]：[code]DeploymentSystem.setup_field(character_ids)[/code]——
##      Phase 6 的「己方全灭」判据读的就是阵位，不先布阵永远判不出战败；[br]
##   2. [b]牌堆[/b]：从 [code]DeckEditingSystem.get_deck_cards()[/code] 取本局卡组
##      实例 ID——[code]battle_start[/code] 的开局手牌从牌堆发，牌堆空则一张也发不出；[br]
##   3. [b]敌方阵容[/b]：注入覆盖 > 遭遇战配置（[code]EnemyEncounter[/code]）>
##      AISystem 现有名册；生成后写回 AISystem（AI 决策读的就是它）。[br]
## [br][b]为什么独立成文件[/b]：[code]combat_scene.gd[/code] 已贴 300 行软上限，
## 且「开战前备什么数据」与「什么时候开战 / 退场」是两件事。[br]
## [br][b]降级[/b]：任一依赖缺失时对应输入为空并 push_warning，不阻断开战——
## 但空牌堆 / 空阵容意味着玩家出不了牌、敌人打不动，测试会在这里暴露断链。[br]
##
## 来源: ADR-0008 §生命周期、ADR-0016 §阵位数据模型、ADR-0017 §create_enemy_roster、
## GDD combat-system.md §2/§9、GDD ai-system.md §3。

## 默认遭遇战配置（无注入时使用）——数值与组成全部在资源里。
const DEFAULT_ENCOUNTER_PATH: String = "res://assets/enemies/encounters/default_encounter.tres"

## AISystem（敌方阵容生成与写回）。
var _ai: Node = null
## DeploymentSystem（布阵）。
var _deployment: Node = null
## DeckEditingSystem（本局卡组）。
var _deck: Node = null
## 遭遇战配置覆盖（测试 / 场景变体注入；null = 读默认资源）。
var _encounter: Resource = null
## 敌方阵容覆盖（探索系统已生成名册时的入口；空 = 走遭遇战配置）。
var _roster_override: Array = []


## 注入依赖（全部可空——缺失时对应输入退化为空）。
func setup(p_ai: Node, p_deployment: Node, p_deck: Node,
		p_encounter: Resource = null, p_roster_override: Array = []) -> void:
	_ai = p_ai
	_deployment = p_deployment
	_deck = p_deck
	_encounter = p_encounter
	_roster_override = p_roster_override.duplicate() if p_roster_override is Array else []


## 备齐开战输入。[br]
## [br][param p_character_ids] 备战面板确认的我方角色 ID 列表。[br]
## [param p_realm] 玩家当前境界（敌方难度缩放的输入）。[br]
## [param p_is_tribulation] 是否渡劫战（透传进 battle_start 配置）。[br]
## [br][b]返回[/b]: [code]{deck_ids: Array, config: Dictionary}[/code]——调用方先
## [code]init_deck(deck_ids)[/code] 再 [code]battle_start(config)[/code]。
func prepare(p_character_ids: Array, p_realm: int,
		p_is_tribulation: bool) -> Dictionary:
	_setup_field(p_character_ids)
	var deck_ids: Array = _deck_ids()
	if deck_ids.is_empty():
		push_warning("CombatSceneBattleSetup: 本局卡组为空——开局手牌将发出 0 张（无法出牌）")
	var roster: Array = _resolve_roster(p_realm)
	if roster.is_empty():
		push_warning("CombatSceneBattleSetup: 敌方阵容为空——本场无法判定胜利")
	return {
		"deck_ids": deck_ids,
		"config": {
			"character_ids": p_character_ids.duplicate(),
			"enemy_roster": roster,
			"layout": [],
			"is_tribulation": p_is_tribulation,
		},
	}


## 布阵——失败不阻断开战（无阵位时胜负判定走「信息不足则不判」）。
func _setup_field(p_character_ids: Array) -> void:
	if _deployment == null or not _deployment.has_method(&"setup_field"):
		push_warning("CombatSceneBattleSetup: DeploymentSystem 不可用——阵位未落地")
		return
	if not bool(_deployment.call(&"setup_field", p_character_ids.duplicate(), {})):
		push_warning("CombatSceneBattleSetup: 布阵失败（角色不可用或超出境界上限）——战斗继续，阵位为空")


## 本局卡组实例 ID（DeckEditingSystem 不可用时为空）。
func _deck_ids() -> Array:
	if _deck == null or not _deck.has_method(&"get_deck_cards"):
		return []
	var raw: Variant = _deck.call(&"get_deck_cards")
	return (raw as Array).duplicate() if raw is Array else []


## 敌方阵容——覆盖 > 遭遇战配置 > AISystem 现有名册；结果写回 AISystem。[br]
## [br][b]为什么写回[/b]：AI 决策读 [code]AISystem.get_enemy_roster()[/code]，
## 只把阵容塞进 battle_start config 的话，敌方回合会拿到空候选池、选不出目标。[br]
## [br][b]为什么覆盖优先于现有名册[/b]：现有名册可能是上一场留下的（敌人已阵亡），
## 直接沿用会让第二场开局就判胜利——每场必须重新生成。
func _resolve_roster(p_realm: int) -> Array:
	var roster: Array = []
	if not _roster_override.is_empty():
		roster = _roster_override.duplicate()
	else:
		var encounter: Resource = _encounter
		if encounter == null:
			encounter = _load_default_encounter()
		if encounter != null and _ai != null \
				and _ai.has_method(&"create_enemy_roster"):
			var ids: Variant = encounter.get("enemy_template_ids")
			var templates: Array = ids if ids is Array else []
			roster = _ai.call(&"create_enemy_roster", templates, p_realm)
		elif _ai != null and _ai.has_method(&"get_enemy_roster"):
			var existing: Variant = _ai.call(&"get_enemy_roster")
			roster = (existing as Array).duplicate() if existing is Array else []
	if _ai != null and _ai.has_method(&"set_enemy_roster"):
		_ai.call(&"set_enemy_roster", roster)
	return roster


## 默认遭遇战配置——资源缺失时返回 null（不臆造敌人）。
func _load_default_encounter() -> Resource:
	if not ResourceLoader.exists(DEFAULT_ENCOUNTER_PATH):
		return null
	return load(DEFAULT_ENCOUNTER_PATH) as Resource
