
## CombatSystem 定义层（继承链首段）——[b]枚举、Cat 2b 信号、脚本常量[/b]住在这一层。
##
## [b]为什么拆出这一层[/b]：[code]combat_system.gd[/code] 1222 行，超 300 行软上限
## （.claude/docs/coding-standards.md）。拆法用[b]继承链[/b]而非组合——产品代码、约 60 个既有
## 测试文件，以及 16 个 RefCounted 子模块（[code]combat_phase_manager.gd[/code] /
## [code]combat_card_resolver.gd[/code] / [code]combat_rewards.gd[/code] 等）全都直取这个面：
## 前者写 [code]cs.call("advance_phase")[/code] / [code]cs.get("_phase")[/code] /
## [code]cs.set("_attack_queue", ...)[/code] / [code]CS_SCRIPT.CombatResult.VICTORY[/code]，
## 后者经 [code]_parent.get("_phase")[/code] / [code]_parent.call("_emit_safe", ...)[/code]
## 这类动态分派回取。组合式拆分要给每个成员补一层转发器，而转发器与实体漂移是[b]静默失效[/b]
## ——[code]call / get / set[/code] 传错名字不报语法错，只 push_error 或静默返回 null。
## 守卫用例（[code]tests/unit/combat_system/test_combat_public_face_lock.gd[/code]）实测：
## 常量 / 信号 / 枚举 / 实例字段 / 方法与 [method Object.get] / [method Object.set] /
## [method Object.call] [b]都沿继承链解析[/b]，故逐字搬家即逐位等价，无需转发器。
##
## [b]继承链[/b]（各段守 300 行内，成员名与访问路径逐字不变）：[br]
## [code]  combat_system_contract.gd  [/code] ← 本层：2 枚举 / 9 信号 / 4 常量[br]
## [code]  combat_system_fields.gd    [/code] ← 状态层：45 个实例字段（阶段 / 三堆牌 / 名册 / 子模块引用）[br]
## [code]  combat_system_access.gd    [/code] ← 查找层：13 Autoload 查找 + 16 惰性子模块 getter + 3 取数口[br]
## [code]  combat_system_lifecycle.gd [/code] ← 生命周期层：开战 / 终战 / 撤退 / 续战复位 + 名册 / 奖励 / 副作用面[br]
## [code]  combat_system_phase_play.gd[/code] ← 阶段与出牌层：阶段推进 + 手动确认 + 抽牌三堆 + 出牌结算[br]
## [code]  combat_system_runtime.gd   [/code] ← 运行时接缝层：Autoload 注入 + 注入 setter + 测试开关[br]
## [code]  combat_system.gd           [/code] ← 链尾：信号出口 + GSM 镜像 + 查询 API + 攻击结算（Autoload 入口）[br]
##
## [b]本层职责[/b]：[b]值定义面[/b]——枚举取值、Cat 2b 生命周期信号的载荷形状（值即契约）、
## 四个脚本常量（子模块按名取）。[b]实例字段不住本层[/b]：它们的初始化器要引用本层枚举
## （[code]var _phase: int = CombatPhase.PREPARATION[/code]），须与枚举同段或更靠链尾；
## 而字段体量（211 行）会把本段顶破 300 行——故另起 [code]combat_system_fields.gd[/code]，紧随其后。[br]
##
## [b]信号只声明一处[/b]：重复声明会被当成两个不同信号，发了外部连不上——故 9 个 Cat 2b 信号
## 全部落在本层，由链上各段发射（探针已验证基类信号可在派生段 emit）。[br]
##
## 来源: ADR-0008 §信号分类 §7 阶段状态机 / GDD combat-system.md §1、
## .claude/docs/coding-standards.md §文件行数限制。

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

## Autoload 查找器——本类 12 个 [code]_get_X()[/code] 全部转发到它（唯一实现）。
const AutoloadAccess := preload("res://src/feature/combat/combat_autoload_access.gd")
