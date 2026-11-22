extends RefCounted
## CombatBattleLifecycle —— 战斗的开战 / 终战 / 撤退编排 + 续战复位（从 combat_system.gd 拆分）。[br]
## [br][b]职责边界[/b]：[br]
##   1. [b]开战[/b]：[method battle_start] —— battle 域就位、内部状态归零、名册与 HP 种子、
##      费用激活、快照、开局手牌、[signal CombatSystem.battle_started]、进入 PREPARATION；[br]
##   2. [b]终战[/b]：[method battle_end] —— 防御清理、战绩定格、HP 状态表退场、奖励结算、
##      [signal CombatSystem.battle_ended]、清 battle 域、作废续战快照、转场；[br]
##   3. [b]撤退[/b]：[method retreat] / [method confirm_retreat] —— 两段式确认（AC-016/017）；[br]
##   4. [b]续战复位[/b]：[method resume_auto_advance] —— 读档落位后把自动推进放出来。[br]
## [br][b]副作用不在本模块[/b]：快照 / 输入锁 / 转场 / GSM 镜像四组「对外说什么」
## 收在 [code]combat_battle_side_effects.gd[/code]；本模块只管「按什么顺序做」，
## 每一步都经门面的同名方法转发过去（[code]_parent.call("_create_battle_snapshot")[/code]
## 等）——顺序是这里的契约，接口适配是那里的契约。[br]
## [br][b]状态归属[/b]（ADR-0008 §状态单一所有者）：[code]_is_active[/code] / [code]_phase[/code] /
## [code]_turn[/code] / [code]_attack_queue[/code] / [code]_pending_battle_result[/code] /
## [code]_battle_config[/code] / [code]_battle_serial[/code] / [code]_player_confirmed_*[/code]
## 等字段[b]全部留在门面[/b]；本模块只经 [code]_parent.get/set[/code] 读写——测试大量
## [code]cs.set("_battle_config", ...)[/code]、[code]cs.get("_is_active")[/code] 直取字段，
## 字段搬走这些路径全断。[br]
## [br][b]顺序不可更改[/b]（ADR-0008 §生命周期）：两条主序列是
## 「GSM 建域 → 内部状态 → 名册 → 战绩归零 → 配置定格 → 奖励 RNG → HP 种子 →
## 费用激活 → 快照 → 开局发牌 → [code]battle_started[/code] → 进 PREPARATION」与
## 「防御清理 → 费用清理 → 战绩定格 → HP 表退场 → 奖励结算 → 快照清理 →
## [code]battle_ended[/code] → 清 battle 域 → 作废续战快照 → 转场」。
## 尤其：[code]battle_ended[/code] [b]必须在清 battle 域之前[/b]发射；
## [code]record[/code] 与 HP 回写必须在 HP 状态表清空[b]之前[/b]取数。[br]
## [br][b]为什么拆出来[/b]：这两个方法是全工程被「按名字」调用最多的入口
## （场景容器 4 处 / 子模块回调 / 测试夹具），此前与状态字段、阶段序列混在同一张
## 1794 行的文件里；拆出后门面只留同名薄转发，签名与顺序逐字不动。[br]
## [br]来源: ADR-0008 §生命周期 / §Phase 6、ADR-0007 §_emit_signal_safe、
## ADR-0001 §第二层原子写入、GDD combat-system.md §1/§9、tech-debt DEBT-CBT-018-3。

## 结局常量——镜像 [enum CombatSystem.CombatResult]（同
## [code]combat_phase_manager.gd[/code] 的 [code]PHASE_*[/code] 先例）。
const RESULT_NONE: int = 0
const RESULT_VICTORY: int = 1
const RESULT_RETREAT: int = 3

## 阶段常量——镜像 [enum CombatSystem.CombatPhase]。
const PHASE_PREPARATION: int = 0

## 父节点引用——CombatSystem Autoload 实例。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


# === 开战 ========================================================================

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
	if bool(_parent.get("_is_active")):
		push_warning("CombatSystem.battle_start: 已有活跃战斗，拒绝重复调用")
		return

	# AC-002：通过 GSM 第二层方法创建 battle 域
	_parent.call("_gsm_set_battle_active", true)

	# AC-001：初始化内部状态
	_parent.set("_is_active", true)
	_parent.set("_phase", PHASE_PREPARATION)
	_parent.set("_turn", 1)
	_parent.set("_player_confirmed_end", false)
	_parent.set("_player_confirmed_attack_skip", false)
	_parent.set("_phase_timer_exceeded", false)
	(_parent.get("_attack_queue") as Array).clear()
	_parent.set("_pending_battle_result", RESULT_NONE)

	# Sprint 18：记录本场名册快照（END 阶段胜负判定的输入之一）
	_parent.call("_capture_battle_rosters", config)

	# Sprint 18（结算回流）：本场战绩计数归零
	_parent.call("_get_battle_record").call(&"reset")

	# 回合经济规则输入快照（先手/后手——开战定格，见 CombatSystem 成员文档）
	_parent.set("_battle_config", config.duplicate(true))
	# 本场身份 + 奖励 RNG（序号递增即「换场」，同场的重复结算据此识别）
	_parent.set("_battle_serial", int(_parent.get("_battle_serial")) + 1)
	_parent.call("_seed_reward_rng")

	# Sprint 18 / DEBT-CBT-018-1：种子敌我 HP 状态 + 订阅自身 character_died（阵亡清位）
	_parent.call("_seed_roster_state", config)
	_parent.call("_connect_death_cleanup")

	# Sprint 18：费用系统激活——境界费用上限由 RealmSystem 现读，战斗中锁定
	_parent.call("_init_cost_for_battle")

	# AC-004：创建战斗快照
	_parent.call("_create_battle_snapshot")

	# GDD §2 开局手牌（先手 4 / 后手 5）——「先手第 1 回合不抽牌」的前提。
	# 牌堆尚未就绪（调用方未 init_deck）时发 0 张，不报错：本场的抽牌阶段
	# 会照常走牌堆为空的分支（GDD §边缘情况「抽空牌库」）。[br]
	# [b]读档续战走的是同一条[/b]：那一路的发牌结果会被随后的
	# [method CombatSystem.restore_piles] 原样换掉（顺序上接管在最后）；存档里
	# 没有牌面快照时（v3 老档）发出来的这几张正是玩家读到的手牌——老档因此
	# 不必另开一条路。
	_parent.call("deal_opening_hand")

	# AC-005 / DEBT-CBT-018-11：动画锁不再整场持有——改由阶段 4/5 的
	# 进/出配对推弹（见 [method CombatBattleSideEffects.sync_animation_lock]）。
	# 开战瞬间不在阶段 4/5，故此处不推锁。

	# AC-003：发射 battle_started 信号（Cat 2b）
	_parent.call("_emit_safe", &"battle_started", [config.duplicate(true)])

	# AC-006：开始第一个回合——进入 PREPARATION 阶段
	_parent.call("_enter_phase", PHASE_PREPARATION)


# === 终战 ========================================================================

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
	(_parent.get("_attack_queue") as Array).clear()
	_parent.set("_is_active", false)
	_parent.set("_pending_battle_result", RESULT_NONE)
	_parent.call("_clear_animation_lock")

	# Sprint 18：费用系统清理（未开始/已清理时自身为幂等 no-op）
	_parent.call("_clear_cost_for_battle")

	# Sprint 18（结算回流）：先定格本场战绩 + 回写我方残血，再清空 HP 状态表——
	# 两者都以状态表为唯一取数来源，清表后读到的只会是空数组。
	var record: Dictionary = _parent.call("_build_battle_record", result)

	# Sprint 18 / DEBT-CBT-018-1：本场 HP 状态表退场（下一场重新种子）
	_parent.call("_get_roster_state").call(&"clear")

	# 结算奖励/损失
	var rewards: Dictionary = _parent.call("_settle_result", result)
	# 战绩随载荷下发（键为新增，旧消费者忽略即可）——battle_ended 的展示端据此渲染
	rewards["record"] = record

	# AC-014：VICTORY 清理快照
	if result == RESULT_VICTORY:
		_parent.call("_clear_battle_snapshot")

	# AC-013：发射 battle_ended 信号（在清理 battle 域之前发射——ADR-0008 §信号分类表）
	# rewards Dictionary 已在 _settle_result 中构建，但消费者可能需要读取 battle 域最终状态
	_parent.call("_emit_safe", &"battle_ended", [result, rewards])

	# AC-012：清理 battle 域（在 battle_ended 信号发射之后）
	_parent.call("_gsm_set_battle_active", false)

	# 「回到这场战斗」的快照随战斗结束作废——否则读档会回到一盘已经打完的棋
	_parent.call("_gsm_set_battle_resume", {})

	# AC-015：切换场景
	_parent.call("_request_scene_change", result)


# === 撤退 ========================================================================

## 撤退——确认后调用 battle_end(RETREAT)。[br]
## [br][b]无活跃战斗[/b]：直接返回，不修改状态（AC-016）。[br]
## [br][b]有活跃战斗[/b]：发射确认提示信号（AC-017），UI 展示弹窗，[br]
## 玩家确认后调用 battle_end(RETREAT)。
func retreat() -> void:
	# AC-016：无活跃战斗时直接返回
	if not bool(_parent.get("_is_active")):
		return
	# AC-017：发射确认提示信号（Cat 2b）——UI 展示弹窗
	_parent.call("_emit_safe", &"retreat_requested", [])


## 玩家确认撤退——UI 弹窗确认后调用。[br]
## [br]调用 battle_end(RETREAT) 执行 50% 保留结算。
func confirm_retreat() -> void:
	battle_end(RESULT_RETREAT)


# === 续战复位 ====================================================================

## 恢复自动推进——读档落位完成后由调用方调用（把落位期间压住的调度放出来）。[br]
## [br][b]为什么是由调用方显式恢复而不是本方法内部开关[/b]：落位顺序是
## 「关自动 → battle_start → restore_battle_state → 开自动」，中间那步必须有自动
## 推进关着，而这个顺序的编排归场景侧重建设置（[code]combat_scene_resume.gd[/code]）；
## 本方法只补上「开自动之后把下一格排上」这半句——[method CombatSystem.set_auto_advance]
## 只改字段不排调度，缺了它，玩家读档回来会停在一个永不推进的阶段里。[br]
## [br][b]玩家主动阶段不排下一格[/b]（[method CombatPhaseManager.is_player_driven]）：
## 落位直接改 [code]_phase[/code]、不重放阶段入口，若照旧排一格，玩家在攻击声明阶段
## 存的档会被当场推走（[code]_attack_queue[/code] 刚清空 → 3→4 空真放行），一路滑到
## 下一回合的出牌阶段——「本回合还能出几张牌」于是与存档那一刻不等。停在玩家阶段等
## 玩家自己点，读档前后可出牌数才是同一个数。
func resume_auto_advance() -> void:
	if not bool(_parent.get("_is_active")):
		return
	if bool(_parent.call("_get_phase_manager").call(&"is_player_driven",
			int(_parent.get("_phase")))):
		return
	_parent.call("_schedule_auto_advance")
