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
## 载荷: [code]{attacker_id, target_id, damage, is_kill, damage_reduced}[/code]
## 具名字典（ADR-0007 >3 参数规则）。[br]
## [br][code]damage[/code] 为[b]减伤后[/b]的最终伤害（[method calculate_damage] 的
## [code]final_damage[/code]）；[code]damage_reduced[/code] 表示该值是否已乘过
## 百分比减伤系数（false = 无减伤来源），供表现层给飘字「减」角标。
signal attack_resolved(attack_data: Dictionary)

## 伤害/治疗落库后广播（Cat 2b）——攻击结算与出牌效果两条来源共用。[br]
## 载荷: [code]{character_id, side, damage, is_kill, damage_reduced}[/code] 具名字典
## （ADR-0007 >3 参数规则；[code]damage[/code] 为本次增量，负值 = 治疗）。[br]
## [br][b]damage 是实际扣血[/b]：落库后的增量（攻击结算为减伤后的
## [code]final_damage[/code]），表现层飘字直接用它——玩家看到的数字与 HP 条
## 实际减少量一致，不是减伤前的原始伤害。[br]
## [br][b]与 attack_resolved 的分工[/b]：[code]attack_resolved[/code] 只覆盖
## Phase 4 的攻击队列（攻击动画/命中音效的消费者）；出牌效果造成的伤害不经过它。
## 本信号是「某角色刚受到多少伤害」的统一通知，UI 血条/飘字据此渲染。[br]
## [br][b]不携带 HP 终值[/b]（ADR-0008 §信号合规：CombatSystem 不自设 HP 数据信号）：
## 消费者持 [code]get_character_hp()[/code] 读取契约，需要终值时自行现读——
## HP 所有权始终在战斗侧，UI 不复制。[br]
## [br][b]不广播未知角色[/b]：没有可信 HP（未种子 / 模板缺失）时不发射，
## 与 [code]combat_end_check.gd[/code] 的「信息不足则不判」同源。
signal character_damaged(damage_data: Dictionary)

## 角色 HP ≤ 0 时发射（Cat 2b）。载荷: (character_id: int, side: int, binding_card_ids: Array)。
signal character_died(character_id: int, side: int, binding_card_ids: Array)

## 撤退请求——玩家调用 retreat() 时发射（Cat 2b），UI 展示确认弹窗。
signal retreat_requested()

## 新回合开始——[b]回合切换的显式信号[/b]（Cat 2b）。[br]
## 载荷: [code]{turn: int, is_player_turn: bool}[/code] 具名字典（ADR-0007 >3 参数规则）。[br]
## [br][b]为什么与 phase_changed 并存[/b]：[code]phase_changed[/code] 是「阶段推进」
## 的通用事件，每回合发 7 次；「回合切换」是玩家心智里的另一个层级（手牌与费用刚重置、
## 轮到我/对方行动）。UI 侧要靠 7 次阶段信号里筛 [code]new_phase == PREPARATION[/code]
## 才能知道回合换了——那是把编排细节漏进表现层。本信号在回合边界发一次，
## 消费者（回合横幅 / 手牌刷新 / 音效）不必再理解阶段编号。[br]
## [br][b]发射时机[/b]：[method advance_phase] 中 [code]END→PREPARATION[/code] 回绕、
## 回合号递增[b]并且[/b]费用与手牌已重置之后（读者拿到信号时状态已是新回合的）。
signal turn_started(turn_data: Dictionary)

## 敌方单次行动结算完毕——敌方回合的可观测结果（Cat 2b）。[br]
## 载荷: [code]{enemy_id, action, target_id, damage, is_kill, known, hp_after}[/code]
## 具名字典。[br]
## [br][code]action[/code] 取 [code]combat_enemy_turn.gd[/code] 的常量
## （[code]skill[/code] / [code]retreat[/code] / [code]none[/code]）；
## [code]known=false[/code] 表示目标读不到可信 HP、本次未落库
## （同 [code]character_damaged[/code] 的不臆造口径）。[br]
## [br][b]为什么要有[/b]：敌方回合此前是「黑盒一跳」——[code]execute_turn()[/code]
## 的行动被丢弃，玩家看不到敌人打了谁、掉多少血。本信号是战报与表现层的唯一入口。
signal enemy_action_resolved(action_data: Dictionary)


# === 子模块类型常量（Sprint 18 结算回流）=========================================

## HP 跨战斗持久化子模块——[constant WRITE_UNAVAILABLE] 与回写口径的单一来源。
const HpCarryoverScript := preload("res://src/feature/combat/combat_hp_carryover.gd")

## 回合经济规则（开局手牌 / 抽牌表——纯函数，与阶段侧同一份口径）。
const TurnEconomy := preload("res://src/feature/combat/combat_turn_economy.gd")

## 战斗奖励的掷骰与发放（灵石区间 / 卡牌概率——全场唯一实现）。
const RewardRoller := preload("res://src/feature/combat/combat_reward_roller.gd")


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

## SceneManager 覆盖（null = 按 /root 查找 Autoload）。[br]
## [br][b]为什么需要注入[/b]：结算转场的目标场景是战斗结果的一部分，测试要断言
## 「胜利 → RESULT_SCREEN / 失败 → DEFEAT_SCREEN」；用真实 SceneManager 会触发
## 异步加载与自动存档（测试环境无有效场景树），故提供同形状注入点。
var _scene_manager_override: Node = null

## 牌库（战斗内牌库管理——Sprint 8 接线）。
var _deck: Array = []

## 弃牌堆（战斗内牌库管理——Sprint 8 接线）。
var _discard_pile: Array = []

## 手牌（战斗内牌库管理——Sprint 8 接线）。
var _hand: Array = []

## 独立 RNG 实例（AC-013 牌库抽空随机返还）。
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

## 奖励掷骰 RNG——[b]与牌库 _rng 分开[/b]：抽牌/弃牌洗牌消耗的随机数次数随对局
## 走向变化，与它共用一条流会让「同一掉落配置的结算结果」不可复现。[br]
## [br]种子口径见 [method set_reward_rng_seed]；测试可注入固定种子实例。
var _reward_rng: RandomNumberGenerator = RandomNumberGenerator.new()

## 是否已由调用方显式播种/注入奖励 RNG（true 时 [method battle_start] 不自动播种）。
var _reward_rng_explicit: bool = false

## 本进程已开战场数——自动播种的偏移量（见 [method set_reward_rng_seed]）。
var _reward_battle_count: int = 0

## 本进程的开战序号——每 [method battle_start] 递增（0 = 从未开过战）。[br]
## [br][b]为什么不用布尔开关[/b]：同一个 CombatSystem 会连续打多场，布尔要在
## [code]battle_start[/code] 重置，而「重置」本身又是一处可漏写的状态；用单调序号
## 做键，换场自然失效、同场重复调用自然命中。
var _battle_serial: int = 0

## 已结算过奖励的开战序号——重复 [method battle_end] 幂等守卫。[br]
## [br]与 [member _battle_serial] 相等即「本场已结算」；序号单调递增，
## 因此不需要在开战时刻意清零。
var _rewards_settled_for: int = 0

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

## 敌方回合结算模块（决策 + 落库 + 广播）——惰性创建（combat-ui-interaction 002）。
var _enemy_turn: RefCounted = null

## 战斗开始/结束接线子模块（Sprint 18 补链——名册快照 / 费用激活 / END 判定）。
var _battle_wiring: RefCounted = null

## 本场敌我角色运行时状态（HP / 存活）——伤害结算的唯一落库目标（Sprint 18 / DEBT-CBT-018-1）。
var _roster_state: RefCounted = null

## 伤害落库 + 阵亡处理子模块（攻击结算 / 出牌效果结算共用）。
var _damage_settlement: RefCounted = null

## 本场战绩累积器（Sprint 18 结算回流——效果条目计数，结束定格）。
var _battle_record: RefCounted = null

## HP 跨战斗持久化子模块（Sprint 18 结算回流 / DEBT-CBT-018-3）。
var _hp_carryover: RefCounted = null

## 本场已掷骰但未发放的奖励（胜利后暂存，等待 UI 选择）。
var _rolled_rewards: Dictionary = {}

## 攻击队列减伤覆盖子模块（DEBT-CBT-018-8 残留——Attack 阶段写入防御方减伤来源）。
var _attack_coverage: RefCounted = null

## 本场战斗的敌方阵容快照（battle_start 时从 AISystem 取；用于胜负判定）。[br]
## [br][b]为什么快照而非现读[/b]：现读 AISystem 的阵容会读进上一场战斗的残留
## （测试串场即误判胜利）；快照空 = 本场无敌方数据 → 永远不判胜利。
var _battle_enemy_roster: Array = []

## 本场战斗上场名册（battle_start 的 config.character_ids；无则取阵位快照）。
var _battle_player_roster: Array = []

## 我方阵位「曾有人」标志——只有战斗期间见过占用阵位，才允许判战败。[br]
## [br]防止「DeploymentSystem 从未被布置」被读成「己方全灭」。
var _field_engaged: bool = false

## Phase 6 END 判定出的战斗结果（[constant CombatResult.NONE] = 未结束）。[br]
## [br][b]为何延后执行[/b]：判定发生在 _enter_phase(END) 内部，此时 advance_phase
## 的阶段簿记（_phase / GSM 镜像 / phase_changed 信号）尚未完成——若立即
## battle_end() 会把已结束的战斗再写一次阶段。改为「END 入口判定 + advance_phase
## 簿记后收尾」，保证 7 阶段序列完整走完再退出（ADR-0008 §Phase 6）。
var _pending_battle_result: int = CombatResult.NONE

## 本场开战 config 快照——回合经济规则的输入（先手/后手由
## [code]is_first_player[/code] 决定抽牌数与首回合费用）。[br]
## [br][b]为什么留快照而非现读[/b]：battle_start 之后调用方可以改自己那份字典，
## 而「本场谁是先手」在一场战斗内不可变；现读会让同一场里前后两次抽牌
## 按不同先后手口径算。
var _battle_config: Dictionary = {}


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
	# END 判定结果只在单场战斗内有意义——桩式开关一并清掉（防上一场的结局
	# 被下一场 advance_phase 的收尾逻辑捡起来误执行）
	_pending_battle_result = CombatResult.NONE
	if active:
		# 本场我方名册同样只在单场内有意义——桩式开关没有名册可快照，清空后
		# 抽牌退回保底张数（否则会读进上一场/别的用例留下的阵容，抽牌数漂移）
		_battle_player_roster = []
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


## 设置[b]奖励掷骰[/b]的种子（确定性测试用）。[br]
## [br][b]与 [method set_rng_seed] 分开[/b]：洗牌流的消耗次数随对局走向变化，
## 共用一条流会让「固定种子 → 固定掉落」不成立。[br]
## [br][b]调用后本场及后续各场都不再自动播种[/b]（显式种子优先）；调用
## [method set_reward_rng] 注入实例同样视为显式。[br]
## [br][b]生产自动播种口径[/b]（[method battle_start]）：[br]
##   [code]reward_seed = GSM.meta.seed + 本进程已开战场数[/code]——同一存档的
##   第一场、第二场……结果各自可复现，且不会两场共用同一串随机数；
##   GSM / meta.seed 缺失时用 [code]本进程已开战场数[/code] 起步（仍可复现，
##   只是不再跨存档对齐）。[br]
## [br][b]一次胜利会消耗的随机数[/b]：灵石区间掷 1 次 [code]randi_range[/code]
## （仅当配置了 [code]lingshi_min/max[/code]）；随后每张 [code]0 < chance < 1[/code]
## 的卡牌掷 1 次 [code]randf()[/code]，顺序与配置数组一致（[code]chance >= 1[/code] /
## [code]<= 0[/code] 与缺 [code]chance[/code] 的条目都不消耗）。
func set_reward_rng_seed(seed_value: int) -> void:
	_reward_rng.seed = seed_value
	_reward_rng_explicit = true


## 注入奖励掷骰 RNG 实例（测试用——自行决定种子与推进方式）。[br]
## [br]注入后 [method battle_start] 不再自动播种，直到 [method reset_reward_rng]。
func set_reward_rng(p_rng: RandomNumberGenerator) -> void:
	_reward_rng = p_rng if p_rng != null else RandomNumberGenerator.new()
	_reward_rng_explicit = p_rng != null


## 恢复自动播种（注入/显式种子之后的复位入口——测试隔离用）。
func reset_reward_rng() -> void:
	_reward_rng = RandomNumberGenerator.new()
	_reward_rng_explicit = false
	_reward_battle_count = 0


## 设置自动推进使能——测试时设 false 禁用 call_deferred。
func set_auto_advance(enabled: bool) -> void:
	_auto_advance_enabled = enabled


## 设置场景切换使能——测试时设 false 禁用 SceneManager 调用。
func set_scene_change(enabled: bool) -> void:
	_scene_change_enabled = enabled


## 注入 SceneManager 覆盖（null = 恢复按 /root 查找 Autoload）。[br]
## [br][param p_manager] 需实现 [code]request_scene_change(from, to, type)[/code]。
func set_scene_manager(p_manager: Node) -> void:
	_scene_manager_override = p_manager


# === 战斗生命周期（Story 002）====================================================

## 战斗开始——初始化 battle.* 域 + 费用系统 + 备战阶段 + 快照 + 输入锁 + 开始回合。[br]
## [br][param config] 战斗配置 [code]{character_ids, enemy_roster, is_tribulation}[/code]。
## [br]流程（ADR-0008 §生命周期）：[br]
##   1. 重复调用守卫——已有活跃战斗时 push_warning + return[br]
##   2. GSM._set_battle_active(true) 创建 battle 域[br]
##   3. 初始化内部状态（_phase=PREPARATION, _turn=1, _is_active=true）[br]
##   4. 记录本场敌我名册快照（END 阶段胜负判定用）[br]
##   5. [b]CostSystem.init_for_battle(境界费用上限)[/b]——费用系统激活[br]
##   6. SaveLoad.create_battle_snapshot(GSM.serialize()) 创建快照[br]
##   7. InputManager.push_lock(ANIMATION) 推入输入锁[br]
##   8. _emit_safe("battle_started", [config]) 发射 Cat 2b 信号[br]
##   9. _enter_phase(PREPARATION) 启动第一回合
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
	_pending_battle_result = CombatResult.NONE

	# Sprint 18：记录本场名册快照（END 阶段胜负判定的输入之一）
	_capture_battle_rosters(config)

	# Sprint 18（结算回流）：本场战绩计数归零
	_get_battle_record().call(&"reset")

	# 回合经济规则输入快照（先手/后手——开战定格，见成员文档）
	_battle_config = config.duplicate(true)
	# 本场身份 + 奖励 RNG（序号递增即「换场」，同场的重复结算据此识别）
	_battle_serial += 1
	_seed_reward_rng()

	# Sprint 18 / DEBT-CBT-018-1：种子敌我 HP 状态 + 订阅自身 character_died（阵亡清位）
	_seed_roster_state(config)
	_connect_death_cleanup()

	# Sprint 18：费用系统激活——境界费用上限由 RealmSystem 现读，战斗中锁定
	_init_cost_for_battle()

	# AC-004：创建战斗快照
	_create_battle_snapshot()

	# GDD §2 开局手牌（先手 4 / 后手 5）——「先手第 1 回合不抽牌」的前提。
	# 牌堆尚未就绪（调用方未 init_deck）时发 0 张，不报错：本场的抽牌阶段
	# 会照常走牌堆为空的分支（GDD §边缘情况「抽空牌库」）。[br]
	# [b]读档续战走的是同一条[/b]：那一路的发牌结果会被随后的
	# [method restore_piles] 原样换掉（顺序上接管在最后）；存档里没有牌面快照时
	# （v3 老档）发出来的这几张正是玩家读到的手牌——老档因此不必另开一条路。
	deal_opening_hand()

	# AC-005 / DEBT-CBT-018-11：动画锁不再整场持有——改由阶段 4/5 的
	# 进/出配对推弹（见 _sync_animation_lock）。开战瞬间不在阶段 4/5，
	# 故此处不推锁。

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
##   6. SceneManager.request_scene_change 切换场景[br]
## [br][b]Sprint 18 结算回流[/b]：结束瞬间定格本场战绩（胜负 / 回合数 / 双方剩余 HP /
## 触发条目数）并入 [code]rewards["record"][/code]，同时把我方残血回写
## [code]player.character_hp[/code]（[code]combat_hp_carryover.gd[/code]）。[br]
## 两者都必须在 [code]_get_roster_state().clear()[/code] [b]之前[/b]取数。
func battle_end(result: int) -> void:
	# AC-011：入口防御清理
	_attack_queue.clear()
	_is_active = false
	_pending_battle_result = CombatResult.NONE
	_clear_animation_lock()

	# Sprint 18：费用系统清理（未开始/已清理时自身为幂等 no-op）
	_clear_cost_for_battle()

	# Sprint 18（结算回流）：先定格本场战绩 + 回写我方残血，再清空 HP 状态表——
	# 两者都以状态表为唯一取数来源，清表后读到的只会是空数组。
	var record: Dictionary = _build_battle_record(result)

	# Sprint 18 / DEBT-CBT-018-1：本场 HP 状态表退场（下一场重新种子）
	_get_roster_state().call(&"clear")

	# 结算奖励/损失
	var rewards: Dictionary = _settle_result(result)
	# 战绩随载荷下发（键为新增，旧消费者忽略即可）——battle_ended 的展示端据此渲染
	rewards["record"] = record

	# AC-014：VICTORY 清理快照
	if result == CombatResult.VICTORY:
		_clear_battle_snapshot()

	# AC-013：发射 battle_ended 信号（在清理 battle 域之前发射——ADR-0008 §信号分类表）
	# rewards Dictionary 已在 _settle_result 中构建，但消费者可能需要读取 battle 域最终状态
	_emit_safe(&"battle_ended", [result, rewards])

	# AC-012：清理 battle 域（在 battle_ended 信号发射之后）
	_gsm_set_battle_active(false)

	# 「回到这场战斗」的快照随战斗结束作废——否则读档会回到一盘已经打完的棋
	_gsm_set_battle_resume({})

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


# === 战斗结束判定（Sprint 18——Phase 6 END 真实现）===============================
# 实现全部在 combat_battle_wiring.gd 子模块（名册快照 / 费用激活 / END 判定 /
# 结局收尾）；父节点只保留薄委托，供 phase_manager 与自身调用。

## 记录本场敌我名册快照——委托子模块（[method battle_start] 调用）。
func _capture_battle_rosters(config: Dictionary) -> void:
	_get_battle_wiring().capture_rosters(config)


## 费用系统激活——[code]CostSystem.init_for_battle(境界费用上限)[/code]。委托子模块。
func _init_cost_for_battle() -> void:
	_get_battle_wiring().init_cost_for_battle()


## 费用系统清理——战斗结束。委托子模块。
func _clear_cost_for_battle() -> void:
	_get_battle_wiring().clear_cost_for_battle()


## Phase 6 END 战斗结束检查——[b]返回 true 表示本场已判定结束[/b]。委托子模块。[br]
## [br]只记录 [member _pending_battle_result]，由 [method advance_phase] 在阶段簿记
## 与信号完成后收尾（ADR-0008 §Phase 6 顺序）。
func _check_battle_end() -> bool:
	return _get_battle_wiring().check_battle_end()


## 战斗费用上限——RealmSystem 的 [code]cost_per_turn[/code]。委托子模块（测试接缝）。
func _read_cost_cap() -> int:
	return _get_battle_wiring().read_cost_cap()


## 读取 DeploymentSystem 阵位快照。委托子模块。
func _read_player_field() -> Array:
	return _get_battle_wiring().read_player_field()


## 累积「我方阵位曾有人」标志。委托子模块。
func _update_field_engaged(field: Array) -> void:
	_get_battle_wiring().update_field_engaged(field)


## Phase 6 判定的结局收尾——先清标志再 [method battle_end]（防递归）。委托子模块。
func _finish_pending_battle_end() -> void:
	_get_battle_wiring().finish_pending_battle_end()


# === HP 落库 + 阵亡清位（Sprint 18 / DEBT-CBT-018-1）===============================

## 定格本场战绩 + 回写我方残血（Sprint 18 结算回流——必须在清表前调用）。[br]
## [br]取数：HP 状态表全量快照（[method CombatRosterState.snapshot_all]）——
##   1. 交战绩累积器定格 [code]{result, outcome, turn_count, effect_entries, player, enemy}[/code]；[br]
##   2. 交 [code]combat_hp_carryover.gd[/code] 把 [code]side == 我方 且 known[/code]
##      的条目写进 [code]player.character_hp[/code]；[br]
##   3. 阵亡角色标记不可用（DeploymentSystem.mark_unavailable）。[br]
## [br][b]回写失败要可见[/b]：持久化没写成意味着「带伤进下一场」断链——
## [code]push_error[/code]（不是 warning：这是功能失效，而 warning 在 Godot 里不打断
## 测试与 CI）。战斗结算本身照常进行，调用方不需要处理返回值。
## [br][b]返回值[/b]：只给 [method CombatSystem.battle_end] 收进 [code]rewards["record"]`[/code]，
## 不参与任何分支（回写成败都不改变本场结局）。
func _build_battle_record(result: int) -> Dictionary:
	var entries: Array = _get_roster_state().call(&"snapshot_all")
	var written: int = int(_get_hp_carryover().call(&"write_back", entries))
	if written == HpCarryoverScript.WRITE_UNAVAILABLE:
		push_error("CombatSystem: 我方 HP 回写失败（无 GSM 入口）——"
				+ "本场残血未持久化，下一场将按模板满血开局")
	_mark_dead_characters_unavailable(entries)
	return _get_battle_record().call(&"build", result, _turn, entries)


## 标记阵亡角色为不可用——战斗结束时调用（GDD combat-system.md §7）。[br]
## [br][b]调用时机[/b]：HP 回写之后，状态表清空之前（entries 尚可用）。[br]
## [br][b]判定规则[/b]：只标记我方（side == 0）且 current_hp == 0 的角色。[br]
## [br][b]责任边界[/b]：只负责调用 DeploymentSystem.mark_unavailable，
## 是否复活由 DeploymentSystem / 事件系统处理（ADR-0016）。
func _mark_dead_characters_unavailable(entries: Array) -> void:
	var ds: Node = _get_deployment_system()
	if ds == null or not ds.has_method(&"mark_unavailable"):
		return
	for raw: Variant in entries:
		if not (raw is Dictionary):
			continue
		var entry: Dictionary = raw
		if int(entry.get("side", 1)) != 0:
			continue  # 跳过敌方
		if int(entry.get("current_hp", 1)) != 0:
			continue  # 跳过存活角色
		var character_id: int = int(entry.get("character_id", -1))
		if character_id < 0:
			continue
		ds.call(&"mark_unavailable", character_id, {
			"death_turn": _turn,
			"death_battle_id": str(_battle_serial),
		})


## 警告零 HP 角色——开战种子时调用（GDD combat-system.md §7）。[br]
## [br][b]判定规则[/b]：读回 [code]current_hp == 0[/code] 时警告，提示角色处于阵亡状态。
## [br][b]警告等级[/b]：warning 而非 error——战斗照常进行（角色上场后 HP 为 0，
## 需由 DeploymentSystem 的不可用列表拦截）。
func _warn_zero_hp_characters(persisted: Dictionary) -> void:
	for character_id: Variant in persisted.keys():
		var entry: Dictionary = persisted[character_id]
		if not (entry is Dictionary):
			continue
		if int(entry.get("current_hp", 1)) == 0:
			push_warning("CombatSystem: 角色 %d 上场时 HP 为 0（阵亡状态）——如需请先通过复活机制恢复" % int(character_id))


## 结算回流计数——子模块（[code]combat_on_play_effects.gd[/code] /
## [code]combat_kill_trigger.gd[/code]）每结算一条效果条目调用一次。
func _note_effect_entry() -> void:
	_get_battle_record().call(&"note_effect_entry", 1)

## 种子敌我 HP 状态表——我方阵位（模板 base_hp 回退）+ 敌方阵容快照。[br]
## [br][param config] 可带 [code]player_stats: {character_id: {current_hp, max_hp}}[/code]
## 覆盖模板值（interaction epic 的 battle_start 扩展契约；缺省走模板）。[br]
## [br][b]Sprint 18 结算回流[/b]：显式 [code]player_stats[/code] 缺省时，由
## [code]combat_hp_carryover.gd[/code] 补上上一场的残血（[code]player.character_hp[/code]）——
## 「带伤进入下一场」据此成立；持久层没有该角色时仍回退模板 [code]base_hp[/code]（满血）。[br]
## [br][b]阵亡角色警告[/b]：读回 [code]current_hp == 0[/code] 时警告，角色后续由
## DeploymentSystem.mark_unavailable 处理不可用逻辑。
func _seed_roster_state(config: Dictionary) -> void:
	var stats: Variant = config.get("player_stats", {})
	var explicit: Dictionary = stats if stats is Dictionary else {}
	var persisted: Dictionary = _get_hp_carryover().call(&"seed_stats", _read_player_field(), explicit)
	_warn_zero_hp_characters(persisted)
	_get_roster_state().call(&"seed", _read_player_field(), persisted,
			_battle_enemy_roster, _get_card_system())


## 订阅自身 character_died——阵亡清位（幂等连接）。委托子模块。[br]
## [br][b]为什么在战斗侧订阅自己的信号[/b]：character_died 是「谁死了」的事实广播，
## 而「把阵位清空」是战斗编排的处置职责（ADR-0008 §架构原则 #2 信号不承载逻辑）。
## CombatUI / BindingManager / DeploymentSystem 是同一信号的另外三类消费者。
func _connect_death_cleanup() -> void:
	_get_damage_settlement().connect_death_cleanup()


## 伤害落库结果读取——战斗 UI 的 hp_reader_cb 契约（[code]{current, max}[/code]）。[br]
## [br]未知角色返回 0/0（UI 侧 apply_hp 已有 max=0 除零守卫）。
func get_character_hp(character_id: int) -> Dictionary:
	return _get_roster_state().call(&"get_hp", character_id)


## 本场敌方名册快照（只读）。[br]
## [br][b]为什么暴露快照而非 AISystem 现读[/b]：战斗 UI 建敌方角色卡要跟 END 判定
## 看同一份数据——跨回合现读 AISystem 可能已换阵容（下一场 / 测试串场）。
func get_battle_enemy_roster() -> Array:
	return _battle_enemy_roster


## 角色是否存活——出牌目标候选池的存活判定入口。[br]
## [br][b]为什么 UI 要问这里而不是自己比 HP[/b]：存活的真理来源是战斗状态表
## （[code]is_alive[/code] 在落库时与 HP 一同写入，[code]known=false[/code] 的角色
## 另有「不据 HP 判死」的既有裁决）。UI 自己拿 [code]current_hp == 0[/code] 去推，
## 会在「读不到 HP」时把活着的敌人从候选池里抹掉。[br]
## [br][b]未知角色返回 true[/b]（同 [method CombatRosterState.is_alive] 口径）——
## 不因缺数据把角色判死。
func is_character_alive(character_id: int) -> bool:
	return bool(_get_roster_state().call(&"is_alive", character_id))


## 本场开战配置副本（只读）。[br]
## [br][b]为什么暴露副本而不是现读调用方[/b]：开战配置在 [method battle_start] 时定格
## （[member _battle_config]），存档快照要存的正是「这场仗开打时的那份」——
## 现读探索侧只会拿到节点当前状态，玩家中途换图后两者就不再是同一场仗。[br]
## [br][b]返回[/b]：配置深拷贝；未开战时为空字典。
func get_battle_config() -> Dictionary:
	return _battle_config.duplicate(true)


## 按存档值落位本场战况——[b]读档续战专用[/b]（常规开战路径逐字不动）。[br]
## [br][b]为什么要这个方法[/b]：[method battle_start] 恒定从第 1 回合的
## PREPARATION 起手，而存档里的那场仗可能停在任意阶段。读档后若不落位，玩家面对的
## 是「血量和敌人都对、但回合与阶段被重置」的半场仗——费用也一并回满。[br]
## [br][b]只动内部状态与镜像，不推进阶段[/b]：阶段入口的那些副作用（抽牌 / 结算 /
## 自动推进）不能重放——玩家已经经历过一遍了。故这里直接改内部字段 + GSM 镜像，
## 再由调用方（[code]combat_scene_resume.gd[/code]）恢复自动推进。[br]
## [br][param p_turn] 存档里的回合数（≥1）。[br]
## [param p_phase] 存档里的阶段（[enum CombatPhase]；越界夹进合法区间）。[br]
## [param p_current_cost] 存档里的当前可用费用。[br]
## [param p_max_cost] 存档里的费用上限（0 = 未记录——保留 [method battle_start] 已
## 按境界算好的上限，不把费用系统打成 0 费）。[br]
## [br][b]返回[/b]：是否真的落位（未开战时 false——调用方据此报警）。
func restore_battle_state(p_turn: int, p_phase: int, p_current_cost: int,
		p_max_cost: int) -> bool:
	if not _is_active:
		push_error("CombatSystem.restore_battle_state: 没有活跃战斗，拒绝落位")
		return false
	_turn = maxi(p_turn, 1)
	_phase = clampi(p_phase, CombatPhase.PREPARATION, CombatPhase.END)
	_gsm_set_battle_turn(_turn)
	_gsm_set_battle_phase(_phase)
	if p_max_cost > 0:
		var cost_system: Node = _get_cost_system()
		if cost_system != null and cost_system.has_method(&"restore_for_battle"):
			cost_system.call(&"restore_for_battle", p_current_cost, p_max_cost)
	return true


## 恢复自动推进——读档落位完成后由调用方调用（把落位期间压住的调度放出来）。[br]
## [br][b]为什么是由调用方显式恢复而不是本方法内部开关[/b]：落位顺序是
## 「关自动 → battle_start → restore_battle_state → 开自动」，中间那步必须有自动
## 推进关着，而这个顺序的编排归场景侧重建设置（[code]combat_scene_resume.gd[/code]）；
## 本方法只补上「开自动之后把下一格排上」这半句——[method set_auto_advance] 只改
## 字段不排调度，缺了它，玩家读档回来会停在一个永不推进的阶段里。[br]
## [br][b]玩家主动阶段不排下一格[/b]（[method CombatPhaseManager.is_player_driven]）：
## 落位直接改 [code]_phase[/code]、不重放阶段入口，若照旧排一格，玩家在攻击声明阶段
## 存的档会被当场推走（[code]_attack_queue[/code] 刚清空 → 3→4 空真放行），一路滑到
## 下一回合的出牌阶段——「本回合还能出几张牌」于是与存档那一刻不等。停在玩家阶段等
## 玩家自己点，读档前后可出牌数才是同一个数。
func resume_auto_advance() -> void:
	if not _is_active:
		return
	if _get_phase_manager().call(&"is_player_driven", _phase):
		return
	_schedule_auto_advance()


## 战斗结果结算——按 VICTORY/DEFEAT/RETREAT 分支。[br]
## [br]Sprint 8 Story 005 接线——通过 ResourceSystem / CultivationSystem 派生奖励。[br]
## [br][b]胜利时[/b]：只掷骰不发放，结果存 _rolled_rewards 并持久化到 GSM battle 字段；[br]
## [b]失败/撤退时[/b]：不发奖、不掷骰，只带 retain_ratio。[br]
## [br][b]返回[/b]: rewards Dictionary。
func _settle_result(result: int) -> Dictionary:
	var rewards: Dictionary = {"result": result}
	if result != CombatResult.VICTORY:
		# 失败/撤退——保留 50% 资源（不发奖、不掷骰）
		rewards["retain_ratio"] = 0.5
		return rewards
	# 幂等守卫：同一场重复调用不再掷骰、不再发放
	if _is_rewards_settled():
		rewards["grant_skipped"] = true
		return rewards
	_mark_rewards_settled()
	# 胜利时只掷骰不发放
	var rolled: Dictionary = RewardRoller.roll(_configured_rewards(), _reward_rng)
	# 未命中条目也要带展示名/稀有度——结算界面要说明「没抽到什么」
	RewardRoller.enrich(rolled.get("cards_missed", []), _get_card_system())
	# 存入内部状态
	_rolled_rewards = rolled.duplicate(true)
	# 持久化到 GSM battle 字段
	_persist_rolled_rewards(rolled)
	# 返回掷骰结果（不含发放标记，因为还没发放）
	rewards.merge(rolled, true)
	return rewards


## 本场是否已结算过奖励（重复 [method battle_end] 的幂等守卫）。[br]
## [br][b]没开过战不参与守卫[/b]：序号为 0 说明没有「场」的概念（测试桩、
## 直接调 [method battle_end] 的旧用例），重复调用照常走结算——此时掉落本身也是空的。[br]
## [br][b]已结束的场次直接调 [method _settle_result] 也算重复[/b]：`_battle_config`
## 在战斗结束后不清（旧口径），比对序号正是为了不让「上一场的配置」被再发一次。
func _is_rewards_settled() -> bool:
	return _battle_serial != 0 and _rewards_settled_for == _battle_serial


## 标记本场已结算——记下当前开战序号；下一场 [method battle_start] 递增后自然失效。
func _mark_rewards_settled() -> void:
	_rewards_settled_for = _battle_serial


## 持久化已掷骰奖励到 GSM battle 字段——供 UI 选择时读取。
func _persist_rolled_rewards(p_rolled: Dictionary) -> void:
	var gsm: Node = _get_gsm()
	if gsm == null or not gsm.has_method(&"set"):
		push_warning("CombatSystem: GSM 不可用，奖励掷骰结果无法持久化")
		return
	if gsm.battle == null:
		gsm.battle = {}
	var battle: Dictionary = gsm.battle
	battle["rolled_rewards"] = p_rolled.duplicate(true)
	gsm.set("battle", battle)


## 从 GSM battle 字段读取已掷骰奖励——供 grant_reward_selection 使用。
func _load_rolled_rewards() -> Dictionary:
	var gsm: Node = _get_gsm()
	if gsm == null or gsm.battle == null:
		return {}
	var battle: Dictionary = gsm.battle
	return battle.get("rolled_rewards", {})


## 奖励选择发放——index>=0 发灵石+修为+该张卡，index<0 只发灵石+修为。[br]
## [br]发放后清空 _rolled_rewards（重复调用返回 no_rolled_rewards 且不重复发奖）。[br]
## [br][param index] 卡牌索引（>=0 选择该卡，<0 跳过卡牌）。[br]
## [br][b]返回[/b]: [code]{no_rolled_rewards, lingshi_granted, cultivation_granted,
## cards, cards_failed}[/code]——no_rolled_rewards=true 表示已发放或无掷骰结果。
func grant_reward_selection(index: int) -> Dictionary:
	var result: Dictionary = {"no_rolled_rewards": true}
	# 幂等守卫：已清空或无掷骰结果
	if _rolled_rewards.is_empty():
		var loaded: Dictionary = _load_rolled_rewards()
		if loaded.is_empty():
			return result
		_rolled_rewards = loaded.duplicate(true)
	if _rolled_rewards.is_empty():
		return result

	# 准备发放内容——灵石和修为始终发放，卡牌按 index 选择
	var to_grant: Dictionary = _rolled_rewards.duplicate(true)
	var cards: Array = to_grant.get("cards", [])
	var selected_cards: Array = []

	if index >= 0 and index < cards.size():
		# 选择指定卡牌
		selected_cards.append(cards[index])
	else:
		# 跳过卡牌
		selected_cards = []

	to_grant["cards"] = selected_cards

	# 发放
	var granted: Dictionary = RewardRoller.apply(to_grant, _get_resource_system(),
			_get_cultivation_system(), _get_card_system(), _get_gsm())

	# 清空掷骰结果（幂等）
	_rolled_rewards.clear()
	_clear_rolled_rewards_from_gsm()

	# 返回发放结果
	result["no_rolled_rewards"] = false
	result["lingshi_granted"] = bool(granted.get("lingshi_granted", true))
	result["cultivation_granted"] = bool(granted.get("cultivation_granted", true))
	result["cards"] = granted.get("cards", [])
	result["cards_failed"] = granted.get("cards_failed", [])
	return result


## 清空 GSM battle 字段中的 rolled_rewards——发放后调用。
func _clear_rolled_rewards_from_gsm() -> void:
	var gsm: Node = _get_gsm()
	if gsm == null or gsm.battle == null:
		return
	var battle: Dictionary = gsm.battle
	battle.erase("rolled_rewards")
	gsm.set("battle", battle)


## 本场奖励掷骰播种——每开一场推进一步（见 [method set_reward_rng_seed]）。[br]
## [br][b]显式种子/注入实例优先[/b]：测试设过种子后不被开战覆盖，
## 否则「固定种子」的口径在第二场就断了。
func _seed_reward_rng() -> void:
	_reward_battle_count += 1
	if _reward_rng_explicit:
		return
	_reward_rng.seed = _reward_seed_base() + _reward_battle_count


## 自动播种基数——[code]GSM.meta.seed[/code]（缺失/类型不符时为 0）。[br]
## [br][b]为什么要全局种子参与[/b]：不同存档（不同轮次）应得到不同掉落；
## 同一存档内按开战场数递增，保证各场互不相同且可复现。
func _reward_seed_base() -> int:
	var gsm: Node = _get_gsm()
	if gsm == null:
		return 0
	var meta: Variant = gsm.get("meta")
	if not (meta is Dictionary):
		return 0
	return int((meta as Dictionary).get("seed", 0))


## 计算灵石奖励——[b]由开战配置的 [code]rewards[/code] 决定[/b]（探索节点掉落）。[br]
## [br][b]为什么读配置而不是现算[/b]：掉落属于「哪一格打哪一批人、给什么」的
## 探索侧数据（[code]combat_launch_context.gd[/code] 在节点生成时定档）；战斗系统
## 只负责结算，不重复一套掉落表。配置缺失时为 0（不臆造奖励）。[br]
## [br][b]这是预览值[/b]：配置了区间时返回区间中值；实得值见 [method _settle_result]
## 掷骰后的 [code]rewards.lingshi[/code]（两者在结算面板上都有展示口径）。[br]
## [br][b]为什么区间也要兜底[/b]：探索侧经 [code]EncounterFields[/code] 写出的配置
## 同时带中值与区间，但手写配置可能只给区间——只读 [code]lingshi[/code] 会让预览恒为 0，
## 与实得对不上。
func _calculate_lingshi_reward() -> int:
	var rewards: Dictionary = _configured_rewards()
	if rewards.has("lingshi"):
		return maxi(int(rewards.get("lingshi", 0)), 0)
	if rewards.has("lingshi_min") or rewards.has("lingshi_max"):
		var lo: int = maxi(int(rewards.get("lingshi_min", 0)), 0)
		var hi: int = maxi(int(rewards.get("lingshi_max", 0)), 0)
		return int(round((float(lo) + float(hi)) * 0.5))
	return 0


## 计算修为奖励——同上，读开战配置 [code]rewards.cultivation[/code]。
func _calculate_cultivation_reward() -> int:
	return maxi(_configured_rewards().get("cultivation", 0), 0)


## 计算卡牌掉落配置——读开战配置 [code]rewards.cards[/code]（字典列表深拷贝）。[br]
## [br][b]返回的是配置清单，不是实得[/b]：每项 [code]{card_id, chance}[/code]
## 是否到手由 [method _settle_result] 的掷骰决定。
func _calculate_card_drops() -> Array:
	var raw: Variant = _configured_rewards().get("cards", [])
	if not (raw is Array):
		return []
	return (raw as Array).duplicate(true)


## 开战配置里的掉落字典（缺失/类型不符时为空——结算侧按 0/空处理）。
func _configured_rewards() -> Dictionary:
	var raw: Variant = _battle_config.get("rewards", {})
	return raw if raw is Dictionary else {}


## 应用胜利奖励——[b]保留为公开测试接缝[/b]（旧测试直调它验证资源写入）。[br]
## [br][b]生产路径不再走这里[/b]：结算改由 [constant RewardRoller] 统一掷骰 + 发放
## （灵石/修为/卡牌三者在同一处），本方法只做「金额已知时发一笔」的兼容入口。
func _apply_victory_rewards(rewards: Dictionary) -> void:
	var lingshi: int = int(rewards.get("lingshi", 0))
	if lingshi > 0:
		var rs = _get_resource_system()
		if rs != null and rs.has_method("add_resource"):
			rs.add_resource(&"ling_shi", lingshi)
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
## [br][b]只在阶段 4/5 持有[/b]（DEBT-CBT-018-11 收窄）：GDD 只要求攻击结算与
## 敌方行动这两个「玩家只看不动」的阶段拦截玩法输入；整场持锁会让出牌阶段
## （2）永远收不到点击，输入层不得不为它开一条豁免口子。[br]
## [br][b]与 [method _clear_animation_lock] 严格配对[/b]：每次推入都在
## [method _sync_animation_lock] 里以「当前是否在阶段 4/5」为唯一判据，
## 重复推入由 InputManager 的 source 去重兜底（不会叠加）。
func _push_animation_lock() -> void:
	var im = _get_input_manager()
	if im != null and im.has_method("push_lock"):
		# LockType.ANIMATION = 1
		im.push_lock(1, &"combat_system")


## 清理 CombatSystem 推入的输入锁（AC-011）。
## [br][b]也用 [code]clear_locks[/code] 而非 pop[/b]：本方法同时服务「离开阶段 4/5」
## 与「战斗结束」两个场景，后者要求无论当前阶段如何都清干净
## （残留锁会让下一场战斗开局的输入被吞）。
func _clear_animation_lock() -> void:
	var im = _get_input_manager()
	if im != null and im.has_method("clear_locks"):
		im.clear_locks(&"combat_system")


## 阶段驱动的锁同步——进入阶段 4/5 推锁，其余阶段不持有。[br]
## [br][b]为什么以「当前阶段」而非「翻越了边界」判定[/b]：状态机可能因校验失败
## 原地不动，边界法会积累漂移；按当前阶段幂等地推/清，任何路径走到这里
## 都会收敛到正确状态（推入与清除各自幂等）。[br]
## [br][param p_phase] 刚进入的阶段（[method advance_phase] 在簿记后调用）。
func _sync_animation_lock(p_phase: int) -> void:
	if p_phase == CombatPhase.ATTACK_RESOLUTION or p_phase == CombatPhase.ENEMY_TURN:
		_push_animation_lock()
	else:
		_clear_animation_lock()


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


## 查找 SceneManager——注入覆盖优先，否则 /root/SceneManager Autoload。
func _get_scene_manager() -> Node:
	if _scene_manager_override != null:
		return _scene_manager_override
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
	# （Sprint 18：已判定结束的战斗不开启下一回合——回合数停在结束的那一回合）
	var turn_changed: bool = false
	if next == CombatPhase.PREPARATION and old_phase == CombatPhase.END \
			and _pending_battle_result == CombatResult.NONE:
		_turn += 1
		_gsm_increment_battle_turn()
		turn_changed = true

	# AC-002：Cat 2b 信号——通过 _emit_signal_safe 路由（ADR-0007）
	_emit_safe(&"phase_changed", [old_phase, next, _turn])

	# 回合切换信号（新回合的显式广播——费用与手牌已在 END 阶段重置完毕，
	# 读者拿到此信号时状态已是新回合的）
	if turn_changed:
		_emit_turn_started()

	# AC-005 / DEBT-CBT-018-11：动画锁按阶段 4/5 配对持有
	_sync_animation_lock(next)

	# Sprint 18：Phase 6 END 判定出的结局收尾（簿记 + 信号完成后才退出，
	# 保证 7 阶段序列与 phase_changed 不被 battle_end 截断——ADR-0008 §Phase 6）
	_finish_pending_battle_end()

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


## 发射 [signal turn_started]——回合边界的显式广播。[br]
## [br][code]is_player_turn[/code] 在 7 阶段模型下恒为 true：敌我共用同一个回合
## 序列（阶段 5 是「本回合里的敌方行动」，不是对方的独立回合）。该字段保留，
## 是为了让消费者不必理解阶段编号——将来若拆出独立的敌方回合，只改这里的取值，
## 信号形状与所有订阅方都不动。
func _emit_turn_started() -> void:
	_emit_safe(&"turn_started", [{
		"turn": _turn,
		"is_player_turn": true,
	}])


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


## 发开局手牌——GDD §2「开局手牌：先手 4 张，后手 5 张」。<br>
## [br][b]为什么需要显式发牌[/b]：GDD 抽牌表里「先手第 1 回合不抽牌」的前提是
## 玩家手里[b]已经有[/b]开局手牌。此前该前提没有兑现——第 1 回合不抽牌就等于空手开局
## （无牌可出），所以旧实现用「恒抽 2 张」绕过。本方法把开局手牌补上，
## 抽牌表才能按 GDD 原样执行。<br>
## [br][b]与 [method init_deck] 的分工[/b]：init_deck 只负责「洗牌 + 清手牌」
## （既有 Story 001 契约，不改），发牌是它的下一步——单独成方法让
## 「牌堆就绪」与「发牌」可以分别测试，也让 battle_start 能在牌堆为空时安全跳过。<br>
## [br][b]牌堆不足时发多少算多少[/b]：不从弃牌堆返还（那会让开局凭空多出牌），
## 有多少发多少——不足是牌组配置问题，应由组牌侧暴露。<br>
## [br][b]返回[/b]: 实际发出的张数（牌堆为空时为 0）。
func deal_opening_hand() -> int:
	var count: int = TurnEconomy.opening_hand_size(_is_first_player())
	# 沿用既有抽牌路径（含牌库抽空返还与手牌追加语义）——不另开一条发牌实现，
	# 否则「开局手牌」与「回合抽牌」的手牌顺序语义会分家。
	var before: int = _hand.size()
	_draw_cards(count)
	return _hand.size() - before


## 先手标志——开战 config 供数（回合经济规则的输入）。
func _is_first_player() -> bool:
	return TurnEconomy.is_first_player(_battle_config)


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


## 按存档快照原样恢复三堆牌——读档续战专用（顺序与内容都取存档值）。[br]
## [br][b]与 [method init_deck] 的分工[/b]：[code]init_deck[/code] 是「开一场新仗」——
## 拿本局卡组洗一遍再清空手牌；本方法是「接着打」——牌面已经在存档里了，
## 洗牌会把它洗没（玩家攥着的那两张关键牌、已经垫进弃牌堆的那几张，全都会变）。[br]
## [br][b]不洗牌、不发牌[/b]：顺序就是抽牌顺序（[method _draw_cards] 取
## [code]_deck[0][/code]），动了顺序等于换了一副牌；开局手牌也已经在 [code]hand[/code] 里，
## 再发一次等于凭空多几张。[br]
## [br][b]参数顺序与 [method set_deck_state] 不同[/b]（那里是牌库 / 弃牌堆 / 手牌）：
## 本方法的调用方（读档重建）按「手上 / 待抽 / 已弃」的自然顺序给，且带名字的类型
## 让写错的调用点在编译期就红。[br]
## [br][param p_hand] 存档里的手牌（实例 ID 列表，顺序即存档顺序）。[br]
## [param p_draw_pile] 存档里的抽牌堆。[br]
## [param p_discard_pile] 存档里的弃牌堆。
func restore_piles(p_hand: Array, p_draw_pile: Array, p_discard_pile: Array) -> void:
	_hand = p_hand.duplicate()
	_deck = p_draw_pile.duplicate()
	_discard_pile = p_discard_pile.duplicate()


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
##   6b. 打出即生效效果——倍率伤害（ATK × 倍率）并入同一批落库、
##      target=self 的治疗在伤害落库后落施法者（DEBT-CBT-018-10 执行端）[br]
##   7. 阵亡检查——_check_and_process_deaths()（击杀触发条目在此结算治疗）[br]
##   8. 自动推进判定——hand_empty && !can_afford_any → advance_phase()[br]
## [br][param card_instance_id] 卡牌实例 ID。[br]
## [br][param target_indices] 目标索引列表。[br]
## [br][param caster_id] 施法者角色 ID（可选）——[code]trigger="kill"[/code] 条目的治疗落点；
## 缺省 -1 时由子模块从结果项 / 卡牌数据取，仍取不到则击杀条目不结算
## （信息不足不臆造——见 [code]combat_damage_settlement.gd[/code]）。[br]
## [br][b]返回[/b]: true 出牌成功，false 被拒绝。
func play_card(card_instance_id: int, target_indices: Array, caster_id: int = -1) -> bool:
	return _get_card_resolver().play_card(card_instance_id, target_indices, caster_id)


## 同 [method play_card]，但返回带拒绝原因与中文提示文本的结果字典。[br]
## [br][b]为什么保留 bool 版本[/b]：AI / 既有调用方只关心成败，改签名会波及一片；
## 两条入口共用同一份结算实现（[code]CombatCardResolver.play_card_detailed[/code]），
## 不会漂移。UI 出牌链路走本方法，以便费用不足时给出提示而不是静默失败。[br]
## [br][b]返回[/b]: [code]{ok, reason, message, context}[/code]——
## [code]reason[/code] 取 [code]CombatPlayResult[/code] 的常量。
func play_card_detailed(card_instance_id: int, target_indices: Array,
		caster_id: int = -1) -> Dictionary:
	return _get_card_resolver().play_card_detailed(
			card_instance_id, target_indices, caster_id)


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
## 可选 [code]damage_reduction_pcts[/code]（防御方百分比减伤来源，见下）。[br]
## [br]Sprint 8 Story 005：is_kill 从目标 HP 派生（final_damage >= target_hp）。[br]
## [br]Sprint 18 / DEBT-CBT-018-1：结算结果交 [code]combat_damage_settlement.gd[/code]
## 回写防御方 HP，归零者经 [signal character_died] 驱动阵亡清位。[br]
## [br]DEBT-CBT-018-8 残留：结算前先由 [code]combat_attack_coverage.gd[/code] 把各条目
## 防御方（[code]target_id[/code]）的绑定减伤来源写入 [code]damage_reduction_pcts[/code]
## ——已有显式值的条目不覆盖；取不到来源时不写该键（缺省即无减伤）。
func _resolve_attack_queue() -> void:
	# Sprint 18：结算前采样阵位「曾有人」——阵亡清位发生在结算内
	_update_field_engaged(_read_player_field())
	# DEBT-CBT-018-8 残留：Attack 阶段把防御方绑定减伤写入队列条目（显式值不覆盖）
	_get_attack_coverage().call(&"annotate_queue", _attack_queue)
	# Sprint 18 / DEBT-CBT-018-1：结算后逐条落库 HP（combat_damage_settlement.gd），
	# 归零者发射 character_died → 战斗侧清位 → Phase 6 END 判负
	var settled: Array = _get_damage_calculator().resolve_attack_queue()
	_settle_attack_damage(settled)


## 攻击结算落库——逐条把伤害写回防御方状态（委托子模块）。
func _settle_attack_damage(settled: Array) -> void:
	for pair: Variant in settled:
		if pair is Dictionary:
			_get_damage_settlement().settle_attack(pair["entry"], pair["payload"])


# === 伤害计算（AC-008~012）=======================================================

## 计算最终伤害——委托给 _damage_calculator 子模块。[br]
## [br][param attacker_atk] 攻击者攻击力。[br]
## [br][param target_def] 目标防御力。[br]
## [br][param attacker_realm] 攻击者境界等级。[br]
## [br][param defender_realm] 防御者境界等级。[br]
## [br][param damage_reduction_pcts] 防御方百分比减伤列表（DEBT-CBT-018-8，缺省无减伤）。[br]
## [br][b]返回[/b]: [code]{actual_damage, realm_penalty, final_damage, damage_reduction_multiplier}[/code] Dictionary。
func calculate_damage(attacker_atk: int, target_def: int, attacker_realm: int, defender_realm: int,
		damage_reduction_pcts: Array = []) -> Dictionary:
	return _get_damage_calculator().calculate_damage(
		attacker_atk, target_def, attacker_realm, defender_realm, damage_reduction_pcts)


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


## 敌方回合结算模块（决策 + 落库 + 广播）——惰性创建。
func _get_enemy_turn() -> RefCounted:
	if _enemy_turn == null:
		_enemy_turn = preload("res://src/feature/combat/combat_enemy_turn.gd").new(self)
	return _enemy_turn


## 获取战斗接线子模块实例（Sprint 18——名册快照 / 费用激活 / END 判定）。
func _get_battle_wiring() -> RefCounted:
	if _battle_wiring == null:
		_battle_wiring = preload("res://src/feature/combat/combat_battle_wiring.gd").new(self)
	return _battle_wiring


## 获取敌我角色运行时状态子模块（Sprint 18 / DEBT-CBT-018-1——HP 落库）。
func _get_roster_state() -> RefCounted:
	if _roster_state == null:
		_roster_state = preload("res://src/feature/combat/combat_roster_state.gd").new()
	return _roster_state


## 获取本场战绩累积器（Sprint 18 结算回流——效果条目计数 + 结束定格）。
func _get_battle_record() -> RefCounted:
	if _battle_record == null:
		_battle_record = preload("res://src/feature/combat/combat_battle_record.gd").new()
	return _battle_record


## 获取 HP 跨战斗持久化子模块（Sprint 18 结算回流 / DEBT-CBT-018-3）。
func _get_hp_carryover() -> RefCounted:
	if _hp_carryover == null:
		_hp_carryover = HpCarryoverScript.new(self)
	return _hp_carryover


## 获取伤害落库 + 阵亡处理子模块（Sprint 18 / DEBT-CBT-018-1）。
func _get_damage_settlement() -> RefCounted:
	if _damage_settlement == null:
		_damage_settlement = preload("res://src/feature/combat/combat_damage_settlement.gd").new(self)
	return _damage_settlement


## 获取攻击队列减伤覆盖子模块（DEBT-CBT-018-8 残留——绑定卡减伤写入队列条目）。
func _get_attack_coverage() -> RefCounted:
	if _attack_coverage == null:
		_attack_coverage = preload("res://src/feature/combat/combat_attack_coverage.gd").new(self)
	return _attack_coverage


# === 只读/落库子模块的公开取数口（战斗域之外的表现层装配用）=====================

## 敌我角色运行时状态表（HP / 存活 / 属性增益）。[br]
## [br][b]为什么公开一层薄转发[/b]：[code]_get_roster_state()[/code] 是子模块之间的
## 私有约定（它们持有父引用，直接 call 下划线方法）。战斗域[b]之外[/b]的装配侧
## （战斗场景挂载 → 行囊结算）没有那条父子关系，让它去 call 下划线方法等于把私有
## 约定当成公开 API；转一道手后，改动子模块内部只需同步这一个出口。[br]
## [br]返回 [RefCounted]（[code]combat_roster_state.gd[/code]）——调用方按鸭子类型
## 取用（[code]snapshot_all[/code] / [code]apply_bonus[/code] / [code]get_hp[/code]）。
func get_roster_state() -> RefCounted:
	return _get_roster_state()


## 伤害落库模块（治疗 = 负伤害；唯一写 [code]current_hp[/code] 的路径）。[br]
## 公开理由同 [method get_roster_state]；调用方按鸭子类型取用（[code]apply_heal[/code]）。
func get_damage_settlement() -> RefCounted:
	return _get_damage_settlement()


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


## 通过 GSM 第二层方法落位回合数——读档续战专用（[method restore_battle_state]）。[br]
## [br][b]为什么不用 [method _gsm_increment_battle_turn][/b]：那一支是「+1」，
## 而存档里的回合是绝对值（可能比 GSM 镜像的现值大好几轮，也可能一样）；
## 逐次 +1 既慢又会把中间那些轮次当成真的发生过。
func _gsm_set_battle_turn(turn: int) -> void:
	var gsm = _get_gsm()
	if gsm != null and gsm.has_method("_set_battle_turn"):
		gsm._set_battle_turn(turn)


## 通过 GSM 第二层方法设置战斗活跃状态。
func _gsm_set_battle_active(active: bool) -> void:
	var gsm = _get_gsm()
	if gsm != null and gsm.has_method("_set_battle_active"):
		gsm._set_battle_active(active)


## 通过 GSM 第二层方法写入 / 清空「进行中战斗」的存档快照。[br]
## [br][b]存档侧的写入点不在这里[/b]：抓快照要现读布阵与费用（本类之外的持有方），
## 那是 [code]combat_resume_capture.gd[/code] 的职责；本方法只负责「战斗结束时清空」
## 这条对称出口（不清的话读档会回到一盘已经打完的棋）。
func _gsm_set_battle_resume(resume: Dictionary) -> void:
	var gsm = _get_gsm()
	if gsm != null and gsm.has_method("_set_battle_resume"):
		gsm._set_battle_resume(resume)


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
