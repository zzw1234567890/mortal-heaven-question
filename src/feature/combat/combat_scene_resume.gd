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
##   4. [b]三堆牌与 debuff 接管[/b]（[code]restore_piles[/code] /
##      [code]debuff.restore[/code]）——必须在开战之后：开战会清状态表并按开局手牌
##      发一轮牌，顺序反了接管结果就被覆盖；[br]
##   5. 阶段 / 回合 / 费用按存档落位（[code]restore_battle_state[/code]）。[br]
## [br][b]为什么牌面与 debuff 也要接续[/b]：不接管的话，玩家存档时攥着的两张关键牌
## 会被洗回一副新牌（[code]battle_start[/code] 开局手牌重发），而挂在敌人身上的
## 「降攻 3 层还剩 2 回合」会随着状态表清空凭空蒸发——读回来的仗[b]人对了、牌不对、
## 数值也不对[/b]。三堆牌存的是[b]牌面本身[/b]（不是种子重放：洗牌消耗的随机数次数
## 随对局走向变化，重放必然换一副牌序），debuff 存的是[b]逐条[/b]的剩余回合
## （合并成总量会让两批到期的时点塌成一个）。[br]
## [br]来源: ADR-0008 §GSM 边界、ADR-0002 §存档容器、ADR-0017 §EnemyFactory、
## [code]battle_resume_payload.gd[/code] §「能不能回到这场战斗」、
## [code]battle_resume_cards.gd[/code] / [code]battle_resume_debuffs.gd[/code] §形状。

## 载荷模块（形状与解析的唯一真理来源）。
const PayloadScript := preload("res://src/feature/combat/battle_resume_payload.gd")
## 跨场景续战意图（读档侧留下、本模块取走）。
const IntentScript := preload("res://src/feature/combat/battle_resume_intent.gd")
## 敌方名册重建（存档条目 → EnemyBattleState）。
const RestoreScript := preload("res://src/feature/combat/battle_resume_restore.gd")
## 开战上下文模块（把存档里的来源折回四份输入——战斗场景的既有消费链要吃它）。
const ContextScript := preload("res://src/feature/combat/combat_launch_context.gd")
## 牌面快照模块（三堆的条目形状与 ID 序列解析）。
const CardsScript := preload("res://src/feature/combat/battle_resume_cards.gd")
## debuff 快照模块（逐条灌回状态表）。
const DebuffsScript := preload("res://src/feature/combat/battle_resume_debuffs.gd")

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
	# 牌面与 debuff 必须在开战[b]之后[/b]接管：battle_start 会清空状态表
	# （debuff 随之归零）并按开局手牌发一轮牌——顺序反了，接管的结果会被开战覆盖。
	_restore_cards(p_combat)
	_restore_debuffs(p_combat)
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


## 三堆牌按存档原样接管——手牌 / 抽牌堆 / 弃牌堆，顺序与内容都取存档值。[br]
## [br][b]为什么这件事必须做[/b]：不接管就只剩开战刚发的那一轮开局手牌——
## 玩家存档时攥着的牌、已经打出去垫进弃牌堆的牌，读档回来全被洗回一副新牌里。[br]
## [br][b]没有牌面快照时跳过[/b]（v3 老档 / 空段）：照空数组接管会把刚发的开局手牌
## 清成空手——那比不接管更糟（玩家读档回来无牌可出）。[br]
## [br][b]战斗系统不支持时降级[/b]：老实现没有 [code]restore_piles[/code] 时保持
## 开局手牌（战斗照常进行，缺的是「牌面接续」）。
func _restore_cards(p_combat: Node) -> void:
	if not CardsScript.has_state(_payload):
		return
	if not p_combat.has_method(&"restore_piles"):
		push_warning("CombatSceneResume: 战斗系统不支持牌面接管——手牌将按开局手牌重发")
		return
	p_combat.call(&"restore_piles",
			CardsScript.ids_of(_payload, CardsScript.KEY_HAND),
			CardsScript.ids_of(_payload, CardsScript.KEY_DRAW_PILE),
			CardsScript.ids_of(_payload, CardsScript.KEY_DISCARD_PILE))


## 回合内 debuff 逐条灌回状态表。[br]
## [br][b]为什么要灌[/b]：[code]battle_start[/code] 在种子状态表时清过一遍，
## 存档里那些「降攻 3 层还剩 2 回合」若不灌回来就凭空蒸发——玩家读档后面对的是
## 一场敌我数值与存档那一刻不同的仗。[br]
## [br][b]没有 debuff 快照时跳过[/b]：空段表示存档那一刻本来就没有 debuff
## （不是「没存」——形状归一后两者同形，读侧按「没有」处理是唯一安全的解释）。[br]
## [br][b]管理器取不到时降级[/b]：填不上 debuff 不阻断续战（战斗照常，
## 缺的是那几条减益）。
func _restore_debuffs(p_combat: Node) -> void:
	if not DebuffsScript.has_state(_payload):
		return
	var manager: Variant = _debuff_manager(p_combat)
	if manager == null:
		push_warning("CombatSceneResume: 取不到 debuff 管理器——本场 debuff 未接续")
		return
	var applied: int = DebuffsScript.restore(manager, _payload)
	var expected: int = DebuffsScript.entries_of(_payload).size()
	if applied < expected:
		push_warning("CombatSceneResume: debuff 接续不完整（%d/%d）" % [applied, expected])


## 本场 debuff 管理器——走战斗系统的状态表（与存档抓取同一取数路径）。[br]
## [br][b]为什么经 [code]get_roster_state[/code] 而不是直读[/b]：debuff 归状态表持有，
## 另开一条路径等于把「谁管 debuff」写两遍（抓取侧同一口径，见
## [code]combat_resume_capture.gd[/code]）。
func _debuff_manager(p_combat: Node) -> Variant:
	if p_combat == null or not p_combat.has_method(&"get_roster_state"):
		return null
	var state: Variant = p_combat.call(&"get_roster_state")
	if state == null or not (state is RefCounted) \
			or not (state as RefCounted).has_method(&"get_debuff_manager"):
		return null
	return (state as RefCounted).call(&"get_debuff_manager")


## 战斗系统当前的自动推进开关（落位阶段前后要原样还原它）。
func _auto_advance_of(p_combat: Node) -> bool:
	var raw: Variant = p_combat.get("_auto_advance_enabled")
	return true if raw == null else bool(raw)
