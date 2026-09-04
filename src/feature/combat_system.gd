## CombatSystem —— 战斗系统编排器 Autoload（#9）。
##
## Feature 层 Autoload。7 阶段回合状态机 + 阶段转换验证 + 子系统编排调度。[br]
## 本文件持有 [enum CombatPhase] 枚举 + [method advance_phase] 确定性序列 +
## [method _validate_transition] 验证矩阵 + [method _enter_phase]/[method _exit_phase]
## 桩编排（子系统完整集成属 Story 002/003/004）+ [method confirm_end_turn]/
## [method confirm_attack_targets] 手动确认 API + AC-013 牌库抽空返还 +
## 5 个 Cat 2b 信号经 GSM [code]_emit_signal_safe[/code] 路由。[br]
## [br][b]本 Story 范围[/b]（4-22）：纯状态机推进逻辑 + 验证矩阵 + 自动/手动阶段调度 +
## GSM 第二层 [code]_set_battle_phase[/code]/[code]_increment_battle_turn[/code]/[code]_set_battle_active[/code] 镜像。[br]
## [b]不注册进 project.godot[/b]——待各系统接线后统一注册（4-0b 终验）。[br]
## [b]后续 story[/b]：battle_start/battle_end 生命周期（4-23）、play_card 出牌（4-24）、
## Cat 2b 信号完整声明与订阅（4-25）。[br]
## [br]来源: ADR-0008 §决策 §7 阶段状态机 §阶段转换验证矩阵 / GDD combat-system.md §1。
extends Node
# class_name CombatSystem —— 不声明：Autoload 全局单例，
# 声明 class_name 会与全局名冲突，导致 CS_SCRIPT.new() 测试实例无法解析。
# 测试以 var cs: Node 持有 + 动态分派访问（同 DeploymentSystem/FormationSystem/AISystem 先例）。


# === 枚举 ========================================================================

## 7 阶段战斗状态机——PREPARATION(0)→DRAW(1)→PLAY(2)→ATTACK_DECLARATION(3)→
## ATTACK_RESOLUTION(4)→ENEMY_TURN(5)→END(6)，END 之后回到 PREPARATION。
enum CombatPhase {
	PREPARATION = 0,         ## 准备阶段——tick 效果 + "回合开始"触发
	DRAW = 1,                ## 抽牌阶段——抽 2 张 + "抽牌时"触发
	PLAY = 2,                ## 出牌阶段——玩家主动出牌
	ATTACK_DECLARATION = 3,  ## 攻击声明——玩家分配攻击目标
	ATTACK_RESOLUTION = 4,   ## 攻击结算——按速度依次结算
	ENEMY_TURN = 5,          ## 敌方行动——AI 决策 + 结算
	END = 6,                 ## 结束阶段——"回合结束"触发 + 战斗结束检查
}

## 战斗结果枚举——Story 002 battle_end 使用。
enum CombatResult {
	NONE = 0,
	VICTORY = 1,   ## 敌方全灭
	DEFEAT = 2,    ## 己方全灭
	RETREAT = 3,   ## 玩家撤退（DEFEAT 语义）
}


# === Cat 2b 信号（ADR-0008 §信号分类，经 GSM._emit_signal_safe 路由）=============

## 阶段转换成功后发射（Cat 2b）。[br]
## 载荷: (old_phase: int, new_phase: int, turn: int)。
signal phase_changed(old_phase: int, new_phase: int, turn: int)

## 战斗开始后发射（Cat 2b）。载荷: (config: Dictionary)。[br]
## [b]完整声明与订阅属 Story 004[/b]——本 Story 仅声明占位。
signal battle_started(config: Dictionary)

## 战斗结束后发射（Cat 2b）。载荷: (result: int, rewards: Dictionary)。
signal battle_ended(result: int, rewards: Dictionary)

## 单次攻击结算完毕后发射（Cat 2b）。[br]
## 载荷: [code]{attacker_id, target_id, damage, is_kill}[/code] 具名字典（ADR-0007 >3 参数规则）。
signal attack_resolved(attack_data: Dictionary)

## 角色 HP ≤ 0 时发射（Cat 2b）。载荷: (character_id: int, side: int, binding_card_ids: Array)。
signal character_died(character_id: int, side: int, binding_card_ids: Array)

## 撤退请求——玩家调用 retreat() 时发射（Cat 2b），UI 展示确认弹窗。
signal retreat_requested()


# === 内部状态 ====================================================================

## 当前阶段——状态机唯一真源。
var _phase: int = CombatPhase.PREPARATION

## 当前回合数——从 1 开始，Phase 6→0 时递增。
var _turn: int = 1

## 战斗活跃标志——非活跃时 advance_phase 拒绝推进。
var _is_active: bool = false

## 攻击队列——Phase 3 构建，Phase 4 依次结算。
var _attack_queue: Array = []

## 玩家确认结束出牌阶段标志——Phase 2 手动推进触发。
var _player_confirmed_end: bool = false

## 玩家确认跳过攻击声明标志——Phase 3 手动推进触发。[br]
## [b]语义说明[/b]：此 flag 涵盖"确认跳过"和"确认完成目标分配"两种语义——[br]
## 方法名 confirm_attack_targets 对应"确认攻击声明阶段结束"，flag 名保留 ADR-0008 原名。
var _player_confirmed_attack_skip: bool = false

## Phase 2 超时标志——计时器到期时置真。
var _phase_timer_exceeded: bool = false

## 自动推进使能标志——测试时关闭以禁用 call_deferred 自动推进。[br]
## [b]默认 true[/b]——生产环境自动阶段通过 call_deferred 推进。[br]
## [b]测试设 false[/b]——手动控制 advance_phase 调用时机，避免 SceneTree 帧依赖。
var _auto_advance_enabled: bool = true

## 场景切换使能标志——测试时关闭以禁用 SceneManager 调用。[br]
## [b]默认 true[/b]——生产环境 battle_end 后切换场景。[br]
## [b]测试设 false[/b]——避免 SceneManager 尝试加载不存在的场景文件。
var _scene_change_enabled: bool = true

## 牌库（战斗内牌库管理——Sprint 8 接线）。
var _deck: Array = []

## 弃牌堆（战斗内牌库管理——Sprint 8 接线）。
var _discard_pile: Array = []

## 手牌（战斗内牌库管理——Sprint 8 接线）。
var _hand: Array = []

## 独立 RNG 实例（AC-013 牌库抽空随机返还）。
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

## 可注入回调——CardEffectEngine.validate_targets（Story 003 接线后替换）。[br]
## [br][b]桩实现[/b]：默认返回 true（认为目标始终合法）。
var validate_targets_cb: Callable = Callable()

## 可注入回调——CardEffectEngine.resolve（Story 003 接线后替换）。[br]
## [br][b]桩实现[/b]：默认返回空 Array（无效果结果）。
var resolve_cb: Callable = Callable()

## 可注入回调——CardSystem.get_instance（Story 003 接线后替换）。[br]
## [br][b]桩实现[/b]：默认返回 null——测试时通过 set_card_instances 注入。
var get_card_instance_cb: Callable = Callable()

## 卡牌实例缓存（测试桩——Story 003 接线 CardSystem 后移除）。
var _card_instances: Dictionary = {}

## 伤害计算子模块。
var _damage_calculator: RefCounted = null

## 出牌结算子模块。
var _card_resolver: RefCounted = null

## 阶段管理子模块——惰性初始化（Sprint 9 Story 8 拆分）。
var _phase_manager: RefCounted = null


# === 生命周期 ====================================================================

func _ready() -> void:
	# Sprint 8 Story 002：注入生产回调——CardEffectEngine + CardSystem
	# 仅对 Autoload 实例注入（CS_SCRIPT.new() 测试实例跳过）
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var autoload_cs = tree.root.get_node_or_null("/root/CombatSystem")
	if autoload_cs != self:
		return  # 测试实例——不注入
	# 注入回调——保留 Callable 字段作为测试接缝
	var cee = _get_card_effect_engine()
	if cee != null:
		if validate_targets_cb.is_null():
			validate_targets_cb = Callable(cee, "validate_targets")
		if resolve_cb.is_null():
			resolve_cb = Callable(cee, "resolve")
	var cs = _get_card_system()
	if cs != null:
		if get_card_instance_cb.is_null():
			get_card_instance_cb = Callable(cs, "get_template_by_instance_id")


## 设置战斗活跃状态——Story 002 battle_start/battle_end 调用，本 Story 测试也用于桩。[br]
## [br][param active] 活跃标志。[br]
## [br][param turn] 初始回合数（默认 1）。
func set_battle_active(active: bool, turn: int = 1) -> void:
	var was_active: bool = _is_active
	_is_active = active
	if active:
		_turn = turn
		_phase = CombatPhase.PREPARATION
		_player_confirmed_end = false
		_player_confirmed_attack_skip = false
		_phase_timer_exceeded = false
		_attack_queue.clear()
		# 启动自动推进链——_enter_phase(PREPARATION) 调用 _schedule_auto_advance
		# 同 ADR-0008 生命周期 battle_start() → advance_phase(PREPARATION) 启动模式
		if not was_active and _auto_advance_enabled:
			_enter_phase(CombatPhase.PREPARATION)


## 设置 RNG 种子（确定性测试用）。
func set_rng_seed(seed_value: int) -> void:
	_rng.seed = seed_value


## 设置自动推进使能——测试时设 false 禁用 call_deferred。
func set_auto_advance(enabled: bool) -> void:
	_auto_advance_enabled = enabled


## 设置场景切换使能——测试时设 false 禁用 SceneManager 调用。
func set_scene_change(enabled: bool) -> void:
	_scene_change_enabled = enabled


# === 战斗生命周期（Story 002）====================================================

## 战斗开始——初始化 battle.* 域 + 备战阶段 + 快照 + 输入锁 + 开始回合。[br]
## [br][param config] 战斗配置 [code]{enemy_deck_id, tribulation_level, is_tribulation}[/code]。
## [br]流程（ADR-0008 §生命周期）：[br]
##   1. 重复调用守卫——已有活跃战斗时 push_warning + return[br]
##   2. GSM._set_battle_active(true) 创建 battle 域[br]
##   3. 初始化内部状态（_phase=PREPARATION, _turn=1, _is_active=true）[br]
##   4. SaveLoad.create_battle_snapshot(GSM.serialize()) 创建快照[br]
##   5. InputManager.push_lock(ANIMATION) 推入输入锁[br]
##   6. _emit_safe("battle_started", [config]) 发射 Cat 2b 信号[br]
##   7. _enter_phase(PREPARATION) 启动第一回合
func battle_start(config: Dictionary) -> void:
	# AC-001：重复调用守卫
	if _is_active:
		push_warning("CombatSystem.battle_start: 已有活跃战斗，拒绝重复调用")
		return

	# AC-002：通过 GSM 第二层方法创建 battle 域
	_gsm_set_battle_active(true)

	# AC-001：初始化内部状态
	_is_active = true
	_phase = CombatPhase.PREPARATION
	_turn = 1
	_player_confirmed_end = false
	_player_confirmed_attack_skip = false
	_phase_timer_exceeded = false
	_attack_queue.clear()

	# AC-004：创建战斗快照
	_create_battle_snapshot()

	# AC-005：推入输入锁
	_push_animation_lock()

	# AC-003：发射 battle_started 信号（Cat 2b）
	_emit_safe(&"battle_started", [config.duplicate(true)])

	# AC-006：开始第一个回合——进入 PREPARATION 阶段
	_enter_phase(CombatPhase.PREPARATION)


## 战斗结束——防御清理 + 奖励/损失结算 + 清理 battle 域 + 场景切换。[br]
## [br][param result] 战斗结果（CombatResult.VICTORY/DEFEAT/RETREAT）。[br]
## [br]流程（ADR-0008 §生命周期）：[br]
##   1. 入口防御清理（_attack_queue.clear + _is_active=false）[br]
##   2. 按结果结算奖励/损失[br]
##   3. GSM._set_battle_active(false) 清理 battle 域[br]
##   4. _emit_safe("battle_ended", [result, rewards]) 发射 Cat 2b 信号[br]
##   5. GSM._set_battle_active(false) 清理 battle 域[br]
##   6. SceneManager.request_scene_change 切换场景
func battle_end(result: int) -> void:
	# AC-011：入口防御清理
	_attack_queue.clear()
	_is_active = false
	_clear_animation_lock()

	# 结算奖励/损失
	var rewards: Dictionary = _settle_result(result)

	# AC-014：VICTORY 清理快照
	if result == CombatResult.VICTORY:
		_clear_battle_snapshot()

	# AC-013：发射 battle_ended 信号（在清理 battle 域之前发射——ADR-0008 §信号分类表）
	# rewards Dictionary 已在 _settle_result 中构建，但消费者可能需要读取 battle 域最终状态
	_emit_safe(&"battle_ended", [result, rewards])

	# AC-012：清理 battle 域（在 battle_ended 信号发射之后）
	_gsm_set_battle_active(false)

	# AC-015：切换场景
	_request_scene_change(result)


## 撤退——确认后调用 battle_end(RETREAT)。[br]
## [br][b]无活跃战斗[/b]：直接返回，不修改状态（AC-016）。[br]
## [br][b]有活跃战斗[/b]：发射确认提示信号（AC-017），UI 展示弹窗，[br]
## 玩家确认后调用 battle_end(RETREAT)。
func retreat() -> void:
	# AC-016：无活跃战斗时直接返回
	if not _is_active:
		return
	# AC-017：发射确认提示信号（Cat 2b）——UI 展示弹窗
	_emit_safe(&"retreat_requested", [])


## 玩家确认撤退——UI 弹窗确认后调用。[br]
## [br]调用 battle_end(RETREAT) 执行 50% 保留结算。
func confirm_retreat() -> void:
	battle_end(CombatResult.RETREAT)


## 战斗结果结算——按 VICTORY/DEFEAT/RETREAT 分支。[br]
## [br]Sprint 8 Story 005 接线——通过 ResourceSystem / CultivationSystem 派生奖励。[br]
## [br][b]返回[/b]: rewards Dictionary。
func _settle_result(result: int) -> Dictionary:
	var rewards: Dictionary = {"result": result}
	match result:
		CombatResult.VICTORY:
			# 胜利奖励——灵石+修为+卡牌掉落
			rewards["lingshi"] = _calculate_lingshi_reward()
			rewards["cultivation"] = _calculate_cultivation_reward()
			rewards["cards"] = _calculate_card_drops()
			# 写入 ResourceSystem / CultivationSystem
			_apply_victory_rewards(rewards)
		CombatResult.DEFEAT, CombatResult.RETREAT:
			# 失败/撤退——保留 50% 资源
			rewards["retain_ratio"] = 0.5
	return rewards


## 计算灵石奖励——基础值由战斗配置决定（桩默认 0）。
func _calculate_lingshi_reward() -> int:
	return 0


## 计算修为奖励——基础值由战斗配置决定（桩默认 0）。
func _calculate_cultivation_reward() -> int:
	return 0


## 计算卡牌掉落——基础值由战斗配置决定（桩默认空）。
func _calculate_card_drops() -> Array:
	return []


## 应用胜利奖励——通过 ResourceSystem.add_resource / CultivationSystem.gain_cultivation。[br]
## 不可用时静默跳过。
func _apply_victory_rewards(rewards: Dictionary) -> void:
	# 灵石——通过 ResourceSystem.add_resource(&"ling_shi", amount)
	var lingshi: int = int(rewards.get("lingshi", 0))
	if lingshi > 0:
		var rs = _get_resource_system()
		if rs != null and rs.has_method("add_resource"):
			rs.add_resource(&"ling_shi", lingshi)
	# 修为——通过 CultivationSystem.gain_cultivation
	var cultivation: int = int(rewards.get("cultivation", 0))
	if cultivation > 0:
		var cs = _get_cultivation_system()
		if cs != null and cs.has_method("gain_cultivation"):
			cs.gain_cultivation(cultivation, "battle_victory")


## 创建战斗快照——SaveLoad.create_battle_snapshot(GSM.serialize())（AC-004）。[br]
## [br][b]桩实现[/b]——SaveLoad 不可用时静默跳过（记录错误不阻塞战斗启动）。
func _create_battle_snapshot() -> void:
	var save_load = _get_save_load()
	if save_load == null or not save_load.has_method("create_battle_snapshot"):
		return
	var gsm = _get_gsm()
	if gsm == null:
		push_warning("CombatSystem: GSM 不可用，跳过战斗快照")
		return
	save_load.create_battle_snapshot(gsm.serialize())


## 清理战斗快照——SaveLoad.clear_battle_snapshot()（AC-014）。
func _clear_battle_snapshot() -> void:
	var save_load = _get_save_load()
	if save_load != null and save_load.has_method("clear_battle_snapshot"):
		save_load.clear_battle_snapshot()


## 推入 ANIMATION 输入锁（AC-005）。
func _push_animation_lock() -> void:
	var im = _get_input_manager()
	if im != null and im.has_method("push_lock"):
		# LockType.ANIMATION = 1
		im.push_lock(1, &"combat_system")


## 清理 CombatSystem 推入的输入锁（AC-011）。
func _clear_animation_lock() -> void:
	var im = _get_input_manager()
	if im != null and im.has_method("clear_locks"):
		im.clear_locks(&"combat_system")


## 请求场景切换（AC-015）。
func _request_scene_change(result: int) -> void:
	if not _scene_change_enabled:
		return
	var sm = _get_scene_manager()
	if sm == null or not sm.has_method("request_scene_change"):
		return
	# VICTORY → RESULT_SCREEN(8), DEFEAT/RETREAT → DEFEAT_SCREEN(9)
	var target_scene: int = 8 if result == CombatResult.VICTORY else 9
	# TransitionType.COMBAT_TO_EXPLORE = 4
	sm.request_scene_change(4, target_scene, 4)


## 查找 SaveLoadSystem Autoload。
func _get_save_load() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/SaveLoadSystem")


## 查找 InputManager Autoload。
func _get_input_manager() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/InputManager")


## 查找 SceneManager Autoload。
func _get_scene_manager() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/SceneManager")


# === 阶段管理 ====================================================================

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
	if not _is_active:
		push_error("CombatSystem: advance_phase() called with no active battle")
		return false

	var current: int = _phase
	var next: int = _compute_next_phase(current)

	# AC-002/003：阶段转换验证——失败不推进
	if not _validate_transition(current, next):
		push_warning("CombatSystem: phase transition %d→%d rejected——preconditions not met" % [current, next])
		return false

	# AC-002：退出当前阶段
	_exit_phase(current)

	# AC-002：进入下一阶段
	_enter_phase(next)

	# 更新内部状态
	var old_phase: int = _phase
	_phase = next

	# AC-002：GSM 第二层镜像（非直接属性赋值——ADR-0008 §GSM 写入所有权）
	_gsm_set_battle_phase(next)

	# AC-005：END→PREPARATION 回绕时递增回合
	if next == CombatPhase.PREPARATION and old_phase == CombatPhase.END:
		_turn += 1
		_gsm_increment_battle_turn()

	# AC-002：Cat 2b 信号——通过 _emit_signal_safe 路由（ADR-0007）
	_emit_safe(&"phase_changed", [old_phase, next, _turn])

	return true


## 计算下一阶段——委托给 combat_phase_manager.gd 子模块（Sprint 9 Story 8 拆分）。
func _compute_next_phase(current: int) -> int:
	return _get_phase_manager().compute_next_phase(current)


## 阶段转换验证矩阵（ADR-0008 §验证矩阵）——委托给子模块。
func _validate_transition(from: int, to: int) -> bool:
	return _get_phase_manager().validate_transition(from, to)


## 阶段入口——按固定顺序调用子系统（ADR-0008 §子系统编排顺序）。委托给子模块。
func _enter_phase(phase: int) -> void:
	_get_phase_manager().enter_phase(phase)


## 阶段出口——清理当前阶段状态。委托给子模块。
func _exit_phase(phase: int) -> void:
	_get_phase_manager().exit_phase(phase)


## 自动阶段调度——委托给子模块。
func _schedule_auto_advance() -> void:
	_get_phase_manager()._schedule_auto_advance()


## 状态效果 tick——委托给子模块。
func _tick_status_effects() -> void:
	_get_phase_manager()._tick_status_effects()


## 重置费用——委托给子模块。
func _reset_cost_for_turn() -> void:
	_get_phase_manager()._reset_cost_for_turn()


## 清除待命状态——委托给子模块。
func _clear_standby_state() -> void:
	_get_phase_manager()._clear_standby_state()


## 执行 AI 回合——委托给子模块。
func _execute_ai_turn() -> void:
	_get_phase_manager()._execute_ai_turn()


## 构建场上状态快照——委托给子模块。
func _build_field_state() -> Dictionary:
	return _get_phase_manager()._build_field_state()


## 获取场上角色列表——委托给子模块。
func _get_field_characters() -> Array:
	return _get_phase_manager()._get_field_characters()


## 计算抽牌数量——委托给子模块。
func _calculate_draw_count() -> int:
	return _get_phase_manager()._calculate_draw_count()


# === 手动确认 API（Phase 2/3 玩家交互入口）========================================

## 玩家确认结束出牌阶段——UI "结束回合"按钮触发。[br]
## 设置 _player_confirmed_end 标志后调用 advance_phase()。
func confirm_end_turn() -> bool:
	if _phase != CombatPhase.PLAY:
		push_warning("CombatSystem: confirm_end_turn() called outside PLAY phase (current=%d)" % _phase)
		return false
	_player_confirmed_end = true
	return advance_phase()


## 玩家确认攻击目标——UI "确认攻击"按钮触发。[br]
## 设置 _player_confirmed_attack_skip 标志后调用 advance_phase()。[br]
## [br][b]注意[/b]：此方法语义为"确认跳过/完成攻击声明"——实际目标分配属 Story 003 play_card 接线。
func confirm_attack_targets() -> bool:
	if _phase != CombatPhase.ATTACK_DECLARATION:
		push_warning("CombatSystem: confirm_attack_targets() called outside ATTACK_DECLARATION phase (current=%d)" % _phase)
		return false
	_player_confirmed_attack_skip = true
	return advance_phase()


## 设置 Phase 2 超时标志——计时器到期时调用（AC-011）。
func set_timer_exceeded() -> void:
	_phase_timer_exceeded = true


# === 阶段条件检查 ================================================================

## 检查手牌中是否有任何可支付费用的卡牌（AC-006 条件）。[br]
## 遍历手牌调用 CostSystem.can_afford——Sprint 8 Story 004 接线。[br]
## CostSystem 不可用时回退旧逻辑（手牌非空即 true）。
func _can_afford_any_card() -> bool:
	if _hand.is_empty():
		return false
	var cs = _get_cost_system()
	if cs == null or not cs.has_method("can_afford"):
		return not _hand.is_empty()  # 回退
	for card in _hand:
		var cost: int = _get_card_cost(card)
		if cs.can_afford(cost):
			return true
	return false


## 检查所有可攻击角色是否已分配目标（AC-007/012 空真条件）。[br]
## Sprint 8 Story 004 接线——查询 DeploymentSystem 待命角色。[br]
## 攻击队列非空时返回 false（玩家正在分配目标）。[br]
## 攻击队列空时查 DeploymentSystem：有待命角色则 false，无则 true。
func _all_characters_targeted() -> bool:
	# 攻击队列非空——玩家正在分配目标，尚未全部完成
	if not _attack_queue.is_empty():
		return false
	# 攻击队列空——查 DeploymentSystem 是否有待命角色
	var ds = _get_deployment_system()
	if ds != null and ds.has_method("get_field") and ds.has_method("is_standby"):
		var field: Array = ds.get_field()
		for char_entry in field:
			var char_id: int = _extract_character_id(char_entry)
			if char_id >= 0 and ds.is_standby(char_id):
				return false  # 有待命角色未分配目标
	# 队列空且无待命角色——空真
	return true


# === 抽牌 + 牌库抽空返还（AC-013）================================================

## 从牌库抽 n 张牌到手牌——牌库抽空时从弃牌堆随机返还 1 张到牌库底部。[br]
## [br]来源: GDD §2 抽牌规则 / AC-013。
func _draw_cards(count: int) -> void:
	for i in range(count):
		if _deck.is_empty():
			# AC-013：牌库抽空 + 弃牌堆非空 → 随机返还 1 张到牌库底部
			if _discard_pile.is_empty():
				# 牌库和弃牌堆均空 → 跳过抽牌，不报错
				return
			var idx: int = _rng.randi_range(0, _discard_pile.size() - 1)
			var card = _discard_pile[idx]
			_discard_pile.remove_at(idx)
			_deck.append(card)
		if _deck.is_empty():
			return
		var drawn = _deck[0]
		_deck.remove_at(0)
		_hand.append(drawn)


## 初始化战斗牌库——接收卡组 ID 列表并洗牌。[br]
## [br][param card_ids] 卡组卡牌实例 ID 列表。[br]
## [br]洗牌使用 _rng——set_rng_seed 后确定性可复现。
func init_deck(card_ids: Array) -> void:
	_deck = card_ids.duplicate()
	_discard_pile.clear()
	_hand.clear()
	# Fisher-Yates 洗牌
	var n: int = _deck.size()
	for i in range(n - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp = _deck[i]
		_deck[i] = _deck[j]
		_deck[j] = tmp


## 弃牌——将手牌中的指定卡牌移到弃牌堆。[br]
## [br][param card_instance_id] 卡牌实例 ID。
func discard_card(card_instance_id: int) -> void:
	for i in range(_hand.size() - 1, -1, -1):
		var card = _hand[i]
		var cid: Variant = null
		if card is Dictionary:
			cid = card.get("card_instance_id", card.get("instance_id", -1))
		elif card is int:
			cid = card
		elif card != null and card.has_method("get"):
			cid = card.get("card_instance_id", -1)
		if cid == card_instance_id:
			_hand.remove_at(i)
			_discard_pile.append(card)
			return
	push_warning("CombatSystem: discard_card card_instance_id=%d not found in hand" % card_instance_id)


## 洗牌——将弃牌堆全部洗回牌库，弃牌堆清空。
func shuffle_discard_into_deck() -> void:
	while not _discard_pile.is_empty():
		var idx: int = _rng.randi_range(0, _discard_pile.size() - 1)
		var card = _discard_pile[idx]
		_discard_pile.remove_at(idx)
		_deck.append(card)


## 添加卡牌到牌库底部（绑定卡阵亡洗回——BindingManager 回调）。
func add_card_to_deck(card_instance_id: int) -> void:
	_deck.append(card_instance_id)


## 添加卡牌到弃牌堆（绑定卡覆盖进弃牌——BindingManager 回调）。
func add_card_to_discard(card_instance_id: int) -> void:
	_discard_pile.append(card_instance_id)


## 设置牌库/弃牌堆/手牌（[b]deprecated[/b]——测试注入用，生产代码使用 init_deck）。
func set_deck_state(deck: Array, discard: Array, hand: Array) -> void:
	_deck = deck.duplicate()
	_discard_pile = discard.duplicate()
	_hand = hand.duplicate()


## 设置攻击队列（测试桩注入——Story 003 接线 play_card 后替换）。
func set_attack_queue(queue: Array) -> void:
	_attack_queue = queue.duplicate()


## 返回攻击队列（测试桩——Story 003 接线后移除）。
func get_attack_queue() -> Array:
	return _attack_queue


## 返回牌库（查询 API）。
func get_deck() -> Array:
	return _deck


## 返回弃牌堆（查询 API）。
func get_discard_pile() -> Array:
	return _discard_pile


## 返回手牌（查询 API）。
func get_hand() -> Array:
	return _hand


# === 出牌结算（Story 003）=======================================================

## 玩家打出卡牌——由 CombatUI 触发（AC-001~007）。[br]
## [br][b]确定性流程[/b]（顺序不可更改，ADR-0008 §出牌结算流程）：[br]
##   1. 阶段守卫——非 PLAY 阶段 push_warning + return false[br]
##   2. 卡牌获取——_get_card_instance(card_instance_id) → null 则 return false[br]
##   3. 费用验证——CostSystem.can_afford(cost) → false 则 return false（不扣费）[br]
##   4. 目标验证——_validate_targets(card, targets) → false 则 return false（不扣费）[br]
##   5. 扣费——CostSystem.spend(cost)（直接调用——需要保证）[br]
##   6. 效果结算——_resolve_effects(card, targets) 返回结果列表[br]
##   7. 阵亡检查——_check_and_process_deaths()[br]
##   8. 自动推进判定——hand_empty && !can_afford_any → advance_phase()[br]
## [br][param card_instance_id] 卡牌实例 ID。[br]
## [br][param target_indices] 目标索引列表。[br]
## [br][b]返回[/b]: true 出牌成功，false 被拒绝。
func play_card(card_instance_id: int, target_indices: Array) -> bool:
	return _get_card_resolver().play_card(card_instance_id, target_indices)


## 获取卡牌实例——委托给 _card_resolver 子模块。
func _get_card_instance(card_instance_id: int) -> Variant:
	return _get_card_resolver()._get_card_instance(card_instance_id)


## 获取卡牌费用——委托给 _card_resolver 子模块。
func _get_card_cost(card: Variant) -> int:
	return _get_card_resolver()._get_card_cost(card)


## 费用验证——委托给 _card_resolver 子模块。
func _can_afford(cost: int) -> bool:
	return _get_card_resolver()._can_afford(cost)


## 扣费——委托给 _card_resolver 子模块。
func _spend(cost: int) -> void:
	_get_card_resolver()._spend(cost)


## 目标解析——委托给 _card_resolver 子模块。
func _resolve_targets(card: Variant, target_indices: Array) -> Array:
	return _get_card_resolver()._resolve_targets(card, target_indices)


## 目标验证——委托给 _card_resolver 子模块。
func _validate_targets(card: Variant, targets: Array) -> bool:
	return _get_card_resolver()._validate_targets(card, targets)


## 效果结算——委托给 _card_resolver 子模块。
func _resolve_effects(card: Variant, targets: Array) -> Array:
	return _get_card_resolver()._resolve_effects(card, targets)


## 阵亡检查——委托给 _card_resolver 子模块。
func _check_and_process_deaths(results: Array) -> void:
	_get_card_resolver()._check_and_process_deaths(results)


## 从手牌移除已打出的卡牌——委托给 _card_resolver 子模块。
func _remove_card_from_hand(card_instance_id: int) -> void:
	_get_card_resolver()._remove_card_from_hand(card_instance_id)


## 设置卡牌实例缓存（测试桩注入——Story 003 接线 CardSystem 后移除）。
func set_card_instances(instances: Dictionary) -> void:
	_card_instances = instances.duplicate()


## 设置手牌（测试桩注入——Story 002 接线 DeckSystem 后移除）。
func set_hand(hand: Array) -> void:
	_hand = hand.duplicate()


# === 攻击结算（AC-005 attack_resolved 信号发射）==================================

## 攻击队列结算——Phase 4 ATTACK_RESOLUTION 入口。[br]
## [br]遍历 _attack_queue，对每条攻击记录调用 calculate_damage 计算伤害，[br]
## 发射 attack_resolved 信号（Cat 2b 具名字典格式——ADR-0007）。[br]
## [br]攻击队列格式：[code]{attacker_id, target_id, attacker_atk, target_def, attacker_realm, defender_realm, target_hp}[/code][br]
## [br]Sprint 8 Story 005：is_kill 从目标 HP 派生（final_damage >= target_hp）。
func _resolve_attack_queue() -> void:
	_get_damage_calculator().resolve_attack_queue()


# === 伤害计算（AC-008~012）=======================================================

## 计算最终伤害——委托给 _damage_calculator 子模块。[br]
## [br][param attacker_atk] 攻击者攻击力。[br]
## [br][param target_def] 目标防御力。[br]
## [br][param attacker_realm] 攻击者境界等级。[br]
## [br][param defender_realm] 防御者境界等级。[br]
## [br][b]返回[/b]: [code]{actual_damage, realm_penalty, final_damage}[/code] Dictionary。
func calculate_damage(attacker_atk: int, target_def: int, attacker_realm: int, defender_realm: int) -> Dictionary:
	return _get_damage_calculator().calculate_damage(attacker_atk, target_def, attacker_realm, defender_realm)


## 获取境界压制系数——委托给 _damage_calculator 子模块。
func _get_realm_penalty(attacker_realm: int, defender_realm: int) -> float:
	return _get_damage_calculator()._get_realm_penalty(attacker_realm, defender_realm)


## 查找 CostSystem Autoload。
func _get_cost_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/CostSystem")


## 查找 RealmSystem Autoload。
func _get_realm_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/RealmSystem")


## 查找 CardEffectEngine Autoload。
func _get_card_effect_engine() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/CardEffectEngine")


## 查找 CardSystem Autoload。
func _get_card_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/CardSystem")


## 查找 StatusEffectSystem Autoload。
func _get_status_effect_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/StatusEffectSystem")


## 查找 DeploymentSystem Autoload。
func _get_deployment_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/DeploymentSystem")


## 查找 AISystem Autoload。
func _get_ai_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/AISystem")


## 查找 ResourceSystem Autoload。
func _get_resource_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/ResourceSystem")


## 查找 CultivationSystem Autoload。
func _get_cultivation_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/CultivationSystem")


## 从角色条目提取 character_id——兼容 Dictionary / 对象。
func _extract_character_id(char_entry: Variant) -> int:
	if char_entry is Dictionary:
		return int(char_entry.get("character_id", char_entry.get("id", -1)))
	if char_entry is Object and char_entry.has_method("get"):
		return int(char_entry.get("character_id", -1))
	if char_entry is int:
		return char_entry
	return -1


# === 子模块获取（惰性初始化）===================================================

## 获取伤害计算子模块实例。
func _get_damage_calculator() -> RefCounted:
	if _damage_calculator == null:
		_damage_calculator = preload("res://src/feature/combat/combat_damage_calculator.gd").new(self)
	return _damage_calculator


## 获取出牌结算子模块实例。
func _get_card_resolver() -> RefCounted:
	if _card_resolver == null:
		_card_resolver = preload("res://src/feature/combat/combat_card_resolver.gd").new(self)
	return _card_resolver


## 获取阶段管理子模块实例（Sprint 9 Story 8 拆分）。
func _get_phase_manager() -> RefCounted:
	if _phase_manager == null:
		_phase_manager = preload("res://src/feature/combat/combat_phase_manager.gd").new(self)
	return _phase_manager


# === 查询 API ===================================================================

## 返回当前阶段。
func get_current_phase() -> int:
	return _phase


## 返回当前回合数。
func get_turn_number() -> int:
	return _turn


## 返回战斗活跃状态。
func is_battle_active() -> bool:
	return _is_active


# === GSM 第二层镜像 + Cat 2b 信号路由 =============================================

## 通过 SceneTree 查找 GSM 并调用第二层方法镜像 phase 变更。[br]
## [br][b]失败回退[/b]：GSM 未注册时静默跳过——状态机逻辑不依赖 GSM 镜像，[br]
## GSM 仅负责 Cat 1 信号传播给外部订阅者（CombatUI 等）。
func _gsm_set_battle_phase(phase: int) -> void:
	var gsm = _get_gsm()
	if gsm != null and gsm.has_method("_set_battle_phase"):
		gsm._set_battle_phase(phase)


## 通过 GSM 第二层方法递增回合数。
func _gsm_increment_battle_turn() -> void:
	var gsm = _get_gsm()
	if gsm != null and gsm.has_method("_increment_battle_turn"):
		gsm._increment_battle_turn()


## 通过 GSM 第二层方法设置战斗活跃状态。
func _gsm_set_battle_active(active: bool) -> void:
	var gsm = _get_gsm()
	if gsm != null and gsm.has_method("_set_battle_active"):
		gsm._set_battle_active(active)


## 查找 GameStateManager Autoload——返回 null 时调用方静默跳过。
func _get_gsm() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/GameStateManager")


## Cat 2b 信号安全发射——经 GSM._emit_signal_safe 路由（ADR-0007 信号链深度追踪）。[br]
## [br][b]动态查找 GSM[/b]——而非直接引用 GameStateManager 全局名，[br]
## 避免测试环境无 Autoload 时 NameError（CombatSystem 测试用 CS_SCRIPT.new() 构造，[br]
## 无 Autoload 注册）。BindingManager 先例用直接引用是因为它本身是 Autoload。[br]
## [br][b]GSM 不可用时回退[/b]到直接 emit_signal + push_warning 告警——[br]
## 生产环境若 GSM 意外缺失会降级但不静默。[br]
## [br]来源: ADR-0008 §信号分类 / ADR-0007 §_emit_signal_safe。
func _emit_safe(signal_name: StringName, args: Array) -> void:
	var gsm = _get_gsm()
	if gsm != null and gsm.has_method("_emit_signal_safe"):
		gsm._emit_signal_safe(self, signal_name, args)
		return
	push_warning("CombatSystem: GSM 不可用，%s 信号绕过 _emit_signal_safe 路由" % signal_name)
	var call_args: Array = [signal_name]
	call_args.append_array(args)
	callv("emit_signal", call_args)
