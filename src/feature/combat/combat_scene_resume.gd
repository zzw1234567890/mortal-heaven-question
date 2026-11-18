extends RefCounted
## CombatSceneResume —— 「读档回到这场战斗」的战斗侧落地（跨场景意图消费 + 重建）。[br]
## [br][b]缺在哪一步[/b]：读档把探索态恢复得很好，但 [code]battle[/code] 域是不可持久化的
## （ADR-0008 §GSM 边界），于是玩家的「战斗中存档 → 继续游戏」永远回到探索地图，
## 那场仗连同残血一起被静默丢弃。本模块补上读档侧的落地。[br]
## [br][b]与探索侧的分工[/b]：为什么会走到战斗场景归 [code]battle_resume_intent.gd[/code]
## 的发起方（读档成功那一刻判断并导航）；本模块只回答「到了战斗场景之后怎么把状态灌回去」。[br]
## [br][b]重建顺序不可换[/b]：[br]
##   1. 布阵（[code]setup_field[/code] 带存档里的阵容与前后排——不过备战面板，
##      不给 layout 会把玩家的阵型重排一遍）；[br]
##   2. 敌方名册换成存档形态（满血重开等于白存）；[br]
##   3. [code]battle_start[/code]（HP 种子由 [code]player_stats[/code] 注入——比模板
##      [code]base_hp[/code] 优先）；[br]
##   4. 阶段 / 回合 / 费用按存档落位（[code]restore_battle_state[/code]）。[br]
## [br][b]存档里不记手牌 / 牌堆 / debuff[/b]：它们要么每回合自然重建（牌堆从本局卡组
## 重发），要么是回合内的短效应——记了反而要求「逐张牌还原实例」这一整套机制，
## 与本轮「最小闭环」的取态不符。存的是[b]这一仗的进展[/b]（谁、多少血、第几回合、
## 什么阶段、还有多少费）。[br]
## [br]来源: ADR-0008 §GSM 边界、ADR-0002 §存档容器、ADR-0017 §EnemyFactory、
## [code]battle_resume_payload.gd[/code] §「能不能回到这场战斗」。

## 载荷模块（形状与解析的唯一真理来源）。
const PayloadScript := preload("res://src/feature/combat/battle_resume_payload.gd")
## 跨场景续战意图（读档侧留下、本模块取走）。
const IntentScript := preload("res://src/feature/combat/battle_resume_intent.gd")
## 敌方名册重建（存档条目 → EnemyBattleState）。
const RestoreScript := preload("res://src/feature/combat/battle_resume_restore.gd")
## 开战上下文模块（把存档里的来源折回四份输入——战斗场景的既有消费链要吃它）。
const ContextScript := preload("res://src/feature/combat/combat_launch_context.gd")

## 守卫失败文案（玩家可读——本地化 epic 后替换为 key）。
const TEXT_NO_COMBAT: String = "CombatSystem 不可用——无法续战"
const TEXT_NO_ROSTER: String = "存档里的战斗名册无法重建（模板已不存在）——无法续战"

## 本次续战的存档段（[method consume] 取走；空 = 常规开战路径）。
var _payload: Dictionary = {}


## 取走续战意图并把它折成开战上下文（[b]必须在战斗场景读上下文之前调用[/b]）。[br]
## [br][b]为什么要折上下文[/b]：战斗场景的开战链（[code]CombatSceneLaunch[/code]）只认
## [code]CombatLaunchContext[/code]——标题、掉落、模板 ID 全从那里读。续战不该再开
## 第二条链，把存档段折成同一形状即可复用既有守卫与标题口径。[br]
## [br][b]返回[/b]：是否取到了可续战的存档段。
func consume() -> bool:
	_payload = IntentScript.take()
	if _payload.is_empty():
		return false
	ContextScript.publish(PayloadScript.launch_context(_payload))
	return true


## 是否有待续战的存档段。
func has_payload() -> bool:
	return not _payload.is_empty()


## 只读副本（测试断言用）。
func payload() -> Dictionary:
	return _payload.duplicate(true)


## 重建这场战斗。[br]
## [br][param p_combat] 战斗系统（须有 [code]battle_start[/code]）。[br]
## [param p_root] 战场根（建卡用；可空）。[br]
## [param p_interaction] 出牌交互接线（重建后放行；可空）。[br]
## [param p_deps] 依赖包 [code]{ai, deployment, deck}[/code]（同开战前置那份）。[br]
## [param p_realm] 玩家当前境界（重建敌方时的缩放输入，仅用于兜底名册）。[br]
## [br][b]返回[/b]：空串 = 已重建；非空 = 拒绝原因（调用方 push_error 并展示）。
func start(p_combat: Node, p_root: Control, p_interaction: RefCounted,
		p_deps: Dictionary, p_realm: int) -> String:
	if _payload.is_empty():
		return ""  # 没有续战意图——调用方本就不该走到这里
	if p_combat == null or not p_combat.has_method(&"battle_start"):
		return TEXT_NO_COMBAT
	var deployment: Node = p_deps.get("deployment")
	var ai: Node = p_deps.get("ai")
	var roster: Array = RestoreScript.enemy_roster(_payload, ai)
	if roster.is_empty():
		return TEXT_NO_ROSTER

	var ids: Array = PayloadScript.player_ids(_payload)
	_setup_field(deployment, ids, PayloadScript.player_layout(_payload))
	_write_ai_roster(ai, roster)

	var auto_was: bool = _auto_advance_of(p_combat)
	# 关掉自动推进再开战：否则开战那一刻排下的「PREPARATION →下一阶段」会在
	# 我们落位阶段之前先跑掉一格，玩家读档回来看到的就不是存档里那个阶段了。
	p_combat.call(&"set_auto_advance", false)
	_init_deck(p_combat, p_deps.get("deck"))
	p_combat.call(&"battle_start", _config(ids, roster))
	p_combat.call(&"restore_battle_state",
			int(_payload.get(PayloadScript.KEY_TURN, 1)),
			int(_payload.get(PayloadScript.KEY_PHASE, 0)),
			int(_payload.get(PayloadScript.KEY_CURRENT_COST, 0)),
			int(_payload.get(PayloadScript.KEY_MAX_COST, 0)))
	p_combat.call(&"set_auto_advance", auto_was)
	p_combat.call(&"resume_auto_advance")

	if p_root != null:
		p_root.call(&"build_battle_roster", ids.duplicate())
	if p_interaction != null:
		p_interaction.call(&"enable")
	return ""


## 开战配置——我方阵容 / HP / 敌方名册与来源三件套全取存档值。[br]
## [br][b]为什么 [code]is_tribulation[/code] 恒 false[/b]：渡劫战没有探索来源，
## 根本不会走到这条路（[method PayloadScript.is_resumable] 已挡）。
func _config(p_ids: Array, p_roster: Array) -> Dictionary:
	var cfg: Variant = _payload.get(PayloadScript.KEY_CONFIG, {})
	var config: Dictionary = cfg if cfg is Dictionary else {}
	return {
		"character_ids": p_ids.duplicate(),
		"enemy_roster": p_roster,
		"enemy_template_ids": config.get("enemy_template_ids", []),
		"enemy_level": int(config.get("enemy_level", 0)),
		"rewards": config.get("rewards", {}),
		"layout": [],
		"is_tribulation": false,
		"player_stats": PayloadScript.player_stats(_payload),
	}


## 我方布阵——不过备战面板，直接按存档的阵容与前后排落地。[br]
## [br][b]失败不阻断[/b]：角色已被标记不可用等情形下阵位为空，战斗照常开始
## （胜负判定走既有的「信息不足则不判」口径）。
func _setup_field(p_deployment: Node, p_ids: Array, p_layout: Dictionary) -> void:
	if p_deployment == null or not p_deployment.has_method(&"setup_field"):
		push_warning("CombatSceneResume: DeploymentSystem 不可用——阵位未落地")
		return
	if not bool(p_deployment.call(&"setup_field", p_ids.duplicate(), p_layout)):
		push_warning("CombatSceneResume: 布阵失败（角色不可用或超出境界上限）——战斗继续")


## 敌方名册写回 AISystem——AI 决策读的是它（不写回则敌方回合选不出目标）。
func _write_ai_roster(p_ai: Node, p_roster: Array) -> void:
	if p_ai != null and p_ai.has_method(&"set_enemy_roster"):
		p_ai.call(&"set_enemy_roster", p_roster)


## 本局卡组写入牌堆——[code]battle_start[/code] 的开局手牌从牌堆发（同上顺序）。
func _init_deck(p_combat: Node, p_deck: Node) -> void:
	if p_deck == null or not p_deck.has_method(&"get_deck_cards"):
		return
	var raw: Variant = p_deck.call(&"get_deck_cards")
	if not (raw is Array) or (raw as Array).is_empty():
		push_warning("CombatSceneResume: 本局卡组为空——开局手牌将发出 0 张")
		return
	if p_combat.has_method(&"init_deck"):
		p_combat.call(&"init_deck", (raw as Array).duplicate())


## 战斗系统当前的自动推进开关（落位阶段前后要原样还原它）。
func _auto_advance_of(p_combat: Node) -> bool:
	var raw: Variant = p_combat.get("_auto_advance_enabled")
	return true if raw == null else bool(raw)
