extends RefCounted
## CombatPhaseManager —— 战斗阶段编排子模块（从 combat_system.gd 拆分）。
##
## 持有对 CombatSystem 父节点的引用，通过它访问 _phase / _turn / _is_active /
## _auto_advance_enabled / _attack_queue / _hand / _deck / _discard_pile / _rng 等
## 状态字段以及 _get_status_effect_system / _get_cost_system / _get_deployment_system /
## _get_ai_system / _get_card_cost / advance_phase 等方法。
##
## [br]来源: ADR-0008 §7 阶段状态机 §阶段转换验证矩阵 §子系统编排顺序。
## [br]Sprint 9 Story 8：从 combat_system.gd 拆分。
## [br]combat-ui-interaction Story 002：ENEMY_TURN 改走 [code]combat_enemy_turn.gd[/code]
## 真结算（此前 AI 决策完就丢弃）；抽牌/费用改由 [code]combat_turn_economy.gd[/code]
## 的数据驱动口径供数（此前恒返 2 张 + 恒按先手重置）。

## 回合经济规则（抽牌表 / 手牌上限——纯函数）。
const TurnEconomy := preload("res://src/feature/combat/combat_turn_economy.gd")

## CombatPhase 枚举值（避免依赖父节点枚举）。
const PHASE_PREPARATION: int = 0
const PHASE_DRAW: int = 1
const PHASE_PLAY: int = 2
const PHASE_ATTACK_DECLARATION: int = 3
const PHASE_ATTACK_RESOLUTION: int = 4
const PHASE_ENEMY_TURN: int = 5
const PHASE_END: int = 6

## 父节点引用——CombatSystem Autoload 实例。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


## 计算下一阶段——END(6) 回绕到 PREPARATION(0)，其余 +1。
func compute_next_phase(current: int) -> int:
	if current >= PHASE_END:
		return PHASE_PREPARATION
	return current + 1


## 阶段转换验证矩阵（ADR-0008 §验证矩阵）。[br]
## [br]无条件推进：0→1, 1→2, 4→5, 5→6, 6→0。[br]
## [br]条件推进：2→3（player_confirmed_end || timer_exceeded || hand_empty && !can_afford_any），[br]
## 3→4（all_characters_targeted || player_confirmed_skip || attack_queue.is_empty()）。
func validate_transition(from: int, _to: int) -> bool:
	match from:
		PHASE_PLAY:
			# AC-006：出牌→攻击声明
			return (_parent.get("_player_confirmed_end")
				or _parent.get("_phase_timer_exceeded")
				or (_parent.get("_hand").is_empty() and not _parent.call("_can_afford_any_card")))
		PHASE_ATTACK_DECLARATION:
			# AC-007/012：攻击声明→结算——空队列空真自动推进
			return (_parent.call("_all_characters_targeted")
				or _parent.get("_player_confirmed_attack_skip")
				or _parent.get("_attack_queue").is_empty())
		_:
			# AC-005：0→1, 1→2, 4→5, 5→6, 6→0 无条件
			return true


## 阶段入口——按固定顺序调用子系统（ADR-0008 §子系统编排顺序）。[br]
## [br]Sprint 8 Story 003：接线 StatusEffectSystem / CostSystem / DeploymentSystem。
func enter_phase(phase: int) -> void:
	match phase:
		PHASE_PREPARATION:
			# 1. 状态效果 tick
			_tick_status_effects()
			# 2. 触发"回合开始"效果（CardEffectEngine 接线属后续 Sprint）
			_schedule_auto_advance()
		PHASE_DRAW:
			# 1. 计算抽牌数量（基础 2 + 修正）
			var draw_count: int = _calculate_draw_count()
			# 2. 从牌库抽牌（AC-013 牌库抽空返还）
			_parent.call("_draw_cards", draw_count)
			# 3. 触发"抽牌时"效果（CardEffectEngine 接线属后续 Sprint）
			_schedule_auto_advance()
		PHASE_PLAY:
			# 玩家主动阶段——不自动推进，等待 confirm_end_turn() 或超时
			_parent.set("_phase_timer_exceeded", false)
		PHASE_ATTACK_DECLARATION:
			# 玩家主动阶段——不自动推进，等待 confirm_attack_targets()
			# AC-012：空队列空真——_validate_transition 已放行，但仍需手动调用 advance_phase
			pass
		PHASE_ATTACK_RESOLUTION:
			# 按速度排序依次结算
			_parent.call("_resolve_attack_queue")
			_schedule_auto_advance()
		PHASE_ENEMY_TURN:
			# AISystem.execute_turn → 逐条结算并广播（combat_enemy_turn.gd）
			_execute_ai_turn()
			_schedule_auto_advance()
		PHASE_END:
			# 1. 手牌超限弃置（GDD card-system §手牌限制：回合结束弃至 10 张）
			_enforce_hand_limit()
			# 2. CostSystem.reset_for_turn（先手/后手与首回合口径由经济模块供数）
			_reset_cost_for_turn()
			# 3. DeploymentSystem.clear_standby_state
			_clear_standby_state()
			# 4. Debuff 持续回合数递减（回合结束时 -1，归零则移除）
			_decrement_debuffs()
			# 5. 战斗结束检查（Sprint 18：真实现——敌我全灭判定，GDD §9）
			#    判定命中即停在此阶段：advance_phase 簿记后由父节点收尾 battle_end，
			#    不再调度下一回合（否则已结束的战斗会先绕回 PREPARATION）。
			if _check_battle_end():
				return
			# 6. 未结束 → 调度下一回合
			_schedule_auto_advance()


## 阶段出口——清理当前阶段状态（ADR-0008 §子系统编排顺序）。
func exit_phase(phase: int) -> void:
	match phase:
		PHASE_PLAY:
			_parent.set("_player_confirmed_end", false)
		PHASE_ATTACK_DECLARATION:
			_parent.set("_player_confirmed_attack_skip", false)
		PHASE_ATTACK_RESOLUTION:
			_parent.get("_attack_queue").clear()
		PHASE_END:
			# 清除"已行动"和"待命"标记——已由 _clear_standby_state 在 _enter_phase(END) 处理
			pass


## 自动阶段调度——call_deferred 推进（ADR-0008 §准备阶段调度模式）。[br]
## [br][b]区别于 ADR-0007 的 call_deferred 禁令[/b]：此处用于编排调度（确保每阶段至少 1 帧渲染），[br]
## 而非信号处理器内部打破信号链——ADR-0008 明确声明合法。[br]
## [br][b]测试时禁用[/b]——_auto_advance_enabled=false 时跳过，手动控制 advance_phase。
func _schedule_auto_advance() -> void:
	if not _parent.get("_auto_advance_enabled"):
		return
	if not _parent.get("_is_active"):
		return
	_parent.call_deferred("advance_phase")


## 状态效果 tick——通过 StatusEffectSystem Autoload。[br]
## 不可用时静默跳过。
func _tick_status_effects() -> void:
	var ses = _get_status_effect_system()
	if ses != null and ses.has_method("tick_all"):
		var field_chars: Array = _get_field_characters()
		ses.tick_all(field_chars, _parent.get("_turn"))


## 重置费用——通过 CostSystem Autoload。[br]
## 不可用时静默跳过。[br]
## [br][b]先手/后手由开战 config 决定[/b]（[code]combat_turn_economy.is_first_player[/code]
## 供数，缺省先手——与改造前的硬编码口径逐位一致）；[code]is_first_turn[/code]
## 取「END 时仍是第 1 回合」（费用在 END 重置，下一回合才是它的生效回合）。
func _reset_cost_for_turn() -> void:
	var cs = _get_cost_system()
	if cs != null and cs.has_method("reset_for_turn"):
		cs.reset_for_turn(_is_first_player(), int(_parent.get("_turn")) == 1)


## 手牌超限弃置——回合结束弃至上限（GDD card-system.md §手牌限制）。[br]
## [br][b]弃最旧的[/b]：从手牌头部开始弃（数组头部是先抽到的牌），
## 与「新抽的牌留在手上」的玩家预期一致；抽牌追加在尾部（同
## [code]CombatSystem._draw_cards[/code] 的 [code]append[/code]）。[br]
## [br][b]经 [code]discard_card[/code] 走既有落库路径[/b]——手牌/弃牌堆两侧同时更新，
## 不在这里手改数组（否则弃牌堆数量不对，牌库抽空返还时少一张牌）。[br]
## [br][b]返回[/b]: 实际弃置张数（未超限为 0）。
func _enforce_hand_limit() -> int:
	var hand: Array = _parent.get("_hand")
	var overflow: int = TurnEconomy.hand_overflow(hand.size())
	if overflow <= 0:
		return 0
	# 先快照要弃的 ID 再弃——discard_card 会改动手牌数组，边遍历边删会漏项。
	var victims: Array = []
	for i: int in range(mini(overflow, hand.size())):
		victims.append(_card_id_of(hand[i]))
	var discarded: int = 0
	for card_id: int in victims:
		if card_id < 0:
			continue
		_parent.call("discard_card", card_id)
		discarded += 1
	return discarded


## 清除待命状态——通过 DeploymentSystem Autoload。[br]
## 不可用时静默跳过。
func _clear_standby_state() -> void:
	var ds = _get_deployment_system()
	if ds != null and ds.has_method("clear_standby_state"):
		ds.clear_standby_state()


## Debuff 持续回合数递减——回合结束时调用一次。[br]
## [br]所有 debuff 持续回合数 -1，归零的 debuff 条目被移除。
func _decrement_debuffs() -> void:
	var roster: Variant = _parent.call("_get_roster_state")
	if roster != null and roster.has_method(&"on_turn_end_debuff"):
		roster.call(&"on_turn_end_debuff")


## 战斗结束检查——委托父节点（判定内核 + 名册快照都归 CombatSystem）。
## [br][b]返回[/b]: true 表示本场已判定结束（父节点已记录待收尾结果）。
## [br]父节点缺该方法时返回 false（守卫——不静默吞掉回合推进）。
func _check_battle_end() -> bool:
	if _parent == null or not _parent.has_method("_check_battle_end"):
		return false
	return bool(_parent.call("_check_battle_end"))


## 执行 AI 回合——决策 + 逐条结算（[code]combat_enemy_turn.gd[/code]）。[br]
## [br][b]返回[/b]: 每次行动的结算载荷列表（AISystem 不可用时为空）。
## [br][b]为什么不再直接调 [code]execute_turn[/code][/b]：那样只拿到行动指令、
## 从不落库——敌方伤害对玩家不可见（本轮修掉的断路）。
func _execute_ai_turn() -> Array:
	var module: RefCounted = _parent.call("_get_enemy_turn")
	if module == null:
		return []
	return module.call(&"run")


## 构建场上状态快照——委托敌方回合模块（键名与决策引擎的读取面对齐）。
func _build_field_state() -> Dictionary:
	var module: RefCounted = _parent.call("_get_enemy_turn")
	if module == null:
		return {"player_chars": [], "enemy_chars": [], "turn": int(_parent.get("_turn"))}
	return module.call(&"build_field_state", _get_ai_system())


## 获取场上角色列表——通过 DeploymentSystem Autoload。
func _get_field_characters() -> Array:
	var ds = _get_deployment_system()
	if ds != null and ds.has_method("get_field"):
		return ds.get_field()
	return []


## 计算抽牌数量——GDD §2 抽牌规则表（先手第 1 回合 0 / 后手第 1 回合 3 /
## 第 2 回合起「每名出战角色 1 张，保底 2 张」）。[br]
## [br][b]规则表在 [code]combat_turn_economy.gd[/code][/b]——本方法只负责
## 「在抽牌阶段问它要数字」，不在这里写条件分支（数值口径单一来源）。[br]
## [br][b]出战人数取开战名册快照[/b]：不取「当前存活人数」——那样每阵亡一人手牌就
## 少一张，先挨打的一方输出越打越低，会把一次失误放大成必败。也不回退现读阵位：
## 快照就是唯一来源（config 缺名册时 [code]capture_rosters[/code] 已写入阵位快照），
## 现读会读进上一场留下的阵容。
func _calculate_draw_count() -> int:
	return TurnEconomy.draw_count(_is_first_player(), int(_parent.get("_turn")),
			_actor_count())


## 本场出战人数——开战名册快照；无名册（桩式开战路径）返回 0 → 抽牌退回保底。
func _actor_count() -> int:
	var roster: Variant = _parent.get("_battle_player_roster")
	return (roster as Array).size() if roster is Array else 0


## 先手标志——开战 config 供数（[code]combat_turn_economy.is_first_player[/code]）。
func _is_first_player() -> bool:
	return TurnEconomy.is_first_player(_parent.get("_battle_config"))


## 手牌条目 → 卡牌实例 ID（兼容 Dictionary / 对象 / 裸整数三种既有形态）。
func _card_id_of(p_card: Variant) -> int:
	if p_card is Dictionary:
		var dict: Dictionary = p_card
		return int(dict.get("card_instance_id", dict.get("instance_id", -1)))
	if p_card is Object:
		var raw: Variant = (p_card as Object).get("card_instance_id")
		return int(raw) if raw != null else -1
	if p_card is int or p_card is float:
		return int(p_card)
	return -1


# === Autoload 查找（子模块内自用）=================================================

func _get_status_effect_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/StatusEffectSystem")


func _get_cost_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/CostSystem")


func _get_deployment_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/DeploymentSystem")


func _get_ai_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/AISystem")
