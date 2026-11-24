
## CombatSystem 状态层（继承链第 2 段）——[b]全部 45 个实例字段[/b]住在这一层。
##
## [b]本层职责[/b]：一场战斗的全部可变态。[br]
##   · 阶段机状态（[member _phase] / [member _turn] / [member _is_active] /
##     [member _attack_queue] / 三个确认为 / [member _phase_timer_exceeded]）；[br]
##   · 运行时开关（[member _auto_advance_enabled] / [member _scene_change_enabled] /
##     [member _scene_manager_override]）；[br]
##   · 三堆牌与 RNG（[member _deck] / [member _discard_pile] / [member _hand] /
##     [member _rng] / 奖励 RNG 三件套）；[br]
##   · 本场名册与战绩（[member _battle_enemy_roster] / [member _battle_player_roster] /
##     [member _field_engaged] / [member _pending_battle_result] / [member _battle_config] /
##     [member _battle_serial] / [member _rewards_settled_for] / [member _rolled_rewards]）；[br]
##   · 16 个子模块引用（惰性创建，getter 在 [code]combat_system_access.gd[/code]）；[br]
##   · 3 个可注入回调（[member validate_targets_cb] / [member resolve_cb] /
##     [member get_card_instance_cb]）+ 卡牌实例缓存。[br]
##
## [b]为什么字段单独一段而非并入定义层[/b]：字段初始化器直接引用本链的枚举
## （[code]var _phase: int = CombatPhase.PREPARATION[/code]）——GDScript 要求标识符在[b]自身或祖先[/b]
## 段可见（探针实测：字段写在枚举[b]之前[/b]是解析期错误 "Identifier not declared"），
## 故字段段必须排在定义段[b]之后[/b]。两段合一的体量（118 + 211 行）会顶破 300 行软上限，
## 故拆成「值定义」与「状态」两段。[br]
##
## [b]哪些字段是有意留作公开接缝[/b]：三个 Callable 与 [member _scene_manager_override]
## 是测试与产品代码用 [code]cs.set(...)[/code] 打桩的入口，名字一律不动。[br]
##
## 来源: ADR-0008 §状态单一所有者 / .claude/docs/coding-standards.md §文件行数限制。

extends "res://src/feature/combat/combat_system_contract.gd"


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

## 奖励结算子模块（掷骰 / 持久化 / 发放——本轮从本类拆出）。
var _rewards: RefCounted = null

## 名册 / HP 状态表 / 战绩子模块（开战种子 + 结束定格 + 取数口 + 读档落位——本轮拆出）。
var _roster_ops: RefCounted = null

## 三堆牌子模块（抽牌 / 洗牌 / 弃牌 / 开局发牌 / 读档恢复——本轮拆出）。
var _piles: RefCounted = null

## 阶段序列件（推进 / 手动确认 / 阶段条件检查——本轮拆出）。
var _phase_sequencer: RefCounted = null

## 战斗生命周期编排模块（开战 / 终战 / 撤退 / 续战复位——本轮拆出）。
var _lifecycle: RefCounted = null

## 战斗对外副作用模块（快照 / 输入锁 / 转场 / GSM 镜像——本轮拆出）。
var _side_effects: RefCounted = null

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
