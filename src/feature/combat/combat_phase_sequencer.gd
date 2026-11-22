extends RefCounted
## CombatPhaseSequencer —— 七阶段序列的推进与玩家手动确认入口（从 combat_system.gd 拆分）。[br]
## [br][b]职责边界[/b]：[br]
##   1. [b]推进[/b]：[method advance_phase] —— ADR-0008 的核心算法，8 步顺序即契约；[br]
##   2. [b]手动确认[/b]：Phase 2「结束出牌」/ Phase 3「确认攻击声明」/ Phase 2 超时三个
##      玩家侧入口（各自先置标志再推进）；[br]
##   3. [b]阶段条件检查[/b]：[method can_afford_any_card] / [method all_characters_targeted]
##      —— 阶段转换验证矩阵读的两个条件（AC-006 / AC-007 / AC-012）。[br]
## [br][b]状态归属[/b]（ADR-0008 §状态单一所有者）：[code]_phase[/code] / [code]_turn[/code] /
## [code]_is_active[/code] / [code]_attack_queue[/code] / [code]_player_confirmed_end[/code] /
## [code]_player_confirmed_attack_skip[/code] / [code]_phase_timer_exceeded[/code] /
## [code]_pending_battle_result[/code] / [code]_hand[/code] 全部留在门面；本模块只经
## [code]_parent.get/set[/code] 读写——测试大量 [code]cs.set("_phase", ...)[/code]、
## [code]cs.get("_player_confirmed_end")[/code] 直取字段。[br]
## [br][b]8 步顺序不可更改[/b]（ADR-0008 §advance_phase 核心算法）：[br]
##   1. 非活跃守卫 → push_error + return false[br]
##   2. 计算 next 阶段（END 回绕到 PREPARATION）[br]
##   3. 校验转换 → 失败 push_warning + return false（不推进、不改字段）[br]
##   4. 退出当前阶段 → 5. 进入下一阶段 → 6. 更新 [_phase] → 7. GSM 镜像[br]
##   8. END→PREPARATION 回绕且未判定结局时回合 +1 → 信号 → 动画锁 → 结局收尾[br]
## 改动其中任何一步的次序都会让 [signal CombatSystem.phase_changed] 的载荷
## 与被截断的 7 阶段序列同时出错。[br]
## [br][b]为什么拆出来[/b]：这一组是「一次只走一格」的簿记，与出牌结算 / 名册 /
## 奖励三块互不相干；而门面里它的读者（[code]combat_card_resolver.gd[/code] 与
## [code]combat_phase_manager.gd[/code] 都按名字 [code]_parent.call("advance_phase")[/code]）
## 只依赖名字，不依赖实现位置。[br]
## [br]来源: ADR-0008 §advance_phase 核心算法 / §验证矩阵 / §Phase 6、
## ADR-0007 §_emit_signal_safe、GDD combat-system.md §1/§3、tech-debt DEBT-CBT-018-3。

## 结局常量——镜像 [enum CombatSystem.CombatResult.NONE]（未判定结局）。
const RESULT_NONE: int = 0

## 阶段常量——镜像 [enum CombatSystem.CombatPhase]（只做相等判定，不判语义）。
const PHASE_PREPARATION: int = 0
const PHASE_PLAY: int = 2
const PHASE_ATTACK_DECLARATION: int = 3
const PHASE_END: int = 6

## 父节点引用——CombatSystem Autoload 实例。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


# === 阶段推进 ====================================================================

## advance_phase —— 确定性序列推进阶段。[br]
## [br]序列（顺序不可更改，ADR-0008 §advance_phase 核心算法）：[br]
##   1. 非活跃守卫 → push_error + return false[br]
##   2. 计算 next 阶段（END 回绕到 PREPARATION）[br]
##   3. _validate_transition(from, to) → 失败 push_warning + return false[br]
##   4. _exit_phase(current) → 当前阶段清理[br]
##   5. _enter_phase(next) → 下一阶段初始化[br]
##   6. GSM._set_battle_phase(next) → GSM 第二层镜像（Cat 1）[br]
##   7. PREPARATION 回绕时 GSM._increment_battle_turn()[br]
##   8. _emit_safe("phase_changed", [old, next, turn]) → Cat 2b[br]
## [br][b]返回[/b]: true 推进成功，false 验证失败或非活跃战斗。
func advance_phase() -> bool:
	# AC-004：非活跃战斗拒绝推进
	if not bool(_parent.get("_is_active")):
		push_error("CombatSystem: advance_phase() called with no active battle")
		return false

	var current: int = int(_parent.get("_phase"))
	var next: int = _parent.call("_compute_next_phase", current)

	# AC-002/003：阶段转换验证——失败不推进
	if not bool(_parent.call("_validate_transition", current, next)):
		push_warning("CombatSystem: phase transition %d→%d rejected——preconditions not met" % [current, next])
		return false

	# AC-002：退出当前阶段
	_parent.call("_exit_phase", current)

	# AC-002：进入下一阶段
	_parent.call("_enter_phase", next)

	# 更新内部状态
	var old_phase: int = int(_parent.get("_phase"))
	_parent.set("_phase", next)

	# AC-002：GSM 第二层镜像（非直接属性赋值——ADR-0008 §GSM 写入所有权）
	_parent.call("_gsm_set_battle_phase", next)

	# AC-005：END→PREPARATION 回绕时递增回合
	# （Sprint 18：已判定结束的战斗不开启下一回合——回合数停在结束的那一回合）
	var turn_changed: bool = false
	if next == PHASE_PREPARATION and old_phase == PHASE_END \
			and int(_parent.get("_pending_battle_result")) == RESULT_NONE:
		_parent.set("_turn", int(_parent.get("_turn")) + 1)
		_parent.call("_gsm_increment_battle_turn")
		turn_changed = true

	# AC-002：Cat 2b 信号——通过 _emit_signal_safe 路由（ADR-0007）
	_parent.call("_emit_safe", &"phase_changed", [old_phase, next, int(_parent.get("_turn"))])

	# 回合切换信号（新回合的显式广播——费用与手牌已在 END 阶段重置完毕，
	# 读者拿到此信号时状态已是新回合的）
	if turn_changed:
		_parent.call("_emit_turn_started")

	# AC-005 / DEBT-CBT-018-11：动画锁按阶段 4/5 配对持有
	_parent.call("_sync_animation_lock", next)

	# Sprint 18：Phase 6 END 判定出的结局收尾（簿记 + 信号完成后才退出，
	# 保证 7 阶段序列与 phase_changed 不被 battle_end 截断——ADR-0008 §Phase 6）
	_parent.call("_finish_pending_battle_end")

	return true


# === 手动确认 API（Phase 2/3 玩家交互入口）=======================================

## 玩家确认结束出牌阶段——UI "结束回合"按钮触发。[br]
## 设置 [_player_confirmed_end] 标志后调用 [method advance_phase]。
func confirm_end_turn() -> bool:
	var phase: int = int(_parent.get("_phase"))
	if phase != PHASE_PLAY:
		push_warning("CombatSystem: confirm_end_turn() called outside PLAY phase (current=%d)" % phase)
		return false
	_parent.set("_player_confirmed_end", true)
	return advance_phase()


## 玩家确认攻击目标——UI "确认攻击"按钮触发。[br]
## 设置 [_player_confirmed_attack_skip] 标志后调用 [method advance_phase]。[br]
## [br][b]注意[/b]：此方法语义为"确认跳过/完成攻击声明"——实际目标分配属
## [code]play_card[/code] 接线。
func confirm_attack_targets() -> bool:
	var phase: int = int(_parent.get("_phase"))
	if phase != PHASE_ATTACK_DECLARATION:
		push_warning("CombatSystem: confirm_attack_targets() called outside ATTACK_DECLARATION phase (current=%d)" % phase)
		return false
	_parent.set("_player_confirmed_attack_skip", true)
	return advance_phase()


## 设置 Phase 2 超时标志——计时器到期时调用（AC-011）。
func set_timer_exceeded() -> void:
	_parent.set("_phase_timer_exceeded", true)


# === 阶段条件检查 ================================================================

## 检查手牌中是否有任何可支付费用的卡牌（AC-006 条件）。[br]
## 遍历手牌调用 CostSystem.can_afford——Sprint 8 Story 004 接线。[br]
## CostSystem 不可用时回退旧逻辑（手牌非空即 true）。
func can_afford_any_card() -> bool:
	var hand: Array = _parent.get("_hand")
	if hand.is_empty():
		return false
	var cs: Node = _parent.call("_get_cost_system")
	if cs == null or not cs.has_method("can_afford"):
		return not hand.is_empty()  # 回退
	for card in hand:
		var cost: int = int(_parent.call("_get_card_cost", card))
		if cs.can_afford(cost):
			return true
	return false


## 检查所有可攻击角色是否已分配目标（AC-007/012 空真条件）。[br]
## Sprint 8 Story 004 接线——查询 DeploymentSystem 待命角色。[br]
## 攻击队列非空时返回 false（玩家正在分配目标）。[br]
## 攻击队列空时查 DeploymentSystem：有待命角色则 false，无则 true。
func all_characters_targeted() -> bool:
	# 攻击队列非空——玩家正在分配目标，尚未全部完成
	if not (_parent.get("_attack_queue") as Array).is_empty():
		return false
	# 攻击队列空——查 DeploymentSystem 是否有待命角色
	var ds: Node = _parent.call("_get_deployment_system")
	if ds != null and ds.has_method("get_field") and ds.has_method("is_standby"):
		var field: Array = ds.get_field()
		for char_entry in field:
			var char_id: int = int(_parent.call("_extract_character_id", char_entry))
			if char_id >= 0 and ds.is_standby(char_id):
				return false  # 有待命角色未分配目标
	# 队列空且无待命角色——空真
	return true
