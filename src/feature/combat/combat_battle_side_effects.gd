extends RefCounted
## CombatBattleSideEffects —— 战斗对外的四组副作用（从 combat_system.gd 拆分）。[br]
## [br][b]职责边界[/b]（一组「对外说什么」，自身不持状态）：[br]
##   1. [b]战斗快照[/b]：[method create_battle_snapshot] / [method clear_battle_snapshot]
##      ——SaveLoad 的 [code]create_battle_snapshot[/code] /
##      [code]clear_battle_snapshot[/code]（AC-004 / AC-014）；[br]
##   2. [b]输入锁[/b]：[method push_animation_lock] / [method clear_animation_lock] /
##      [method sync_animation_lock]——InputManager 的 ANIMATION 锁按阶段 4/5 配对
##      （AC-005 / AC-011 / DEBT-CBT-018-11）；[br]
##   3. [b]场景转场[/b]：[method request_scene_change]——SceneManager 的
##      [code]request_scene_change[/code]（AC-015）；[br]
##   4. [b]GSM 第二层镜像[/b]：[code]_gsm_set_battle_*[/code] 四个原子落库口
##      （ADR-0008 §GSM 写入所有权、ADR-0001 §第二层原子写入）。[br]
## [br][b]所有外部依赖都走 [code]has_method[/code] 空守卫[/b]（既有口径逐字不动）：
## 测试环境常常没有 SaveLoad / InputManager / SceneManager / GSM，缺失时静默跳过或
## [code]push_warning[/code]，绝不抛错——这些副作用不该把战斗主流程带崩。[br]
## [br][b]为什么与编排分开[/b]：[code]combat_battle_lifecycle.gd[/code] 管的是
## 「按什么顺序做什么」（顺序本身就是契约），本模块管的是「每一步具体怎么对外说」。
## 两者的改动理由不同：顺序变了是设计变更，某个外部接口改名只是适配。[br]
## [br][b]门面字段的两个读取点[/b]：[method request_scene_change] 读
## [code]_scene_change_enabled[/code]（测试关转场），[code]_get_scene_manager[/code]
## 读 [code]_scene_manager_override[/code]（注入桩）——两个字段都留在门面
## （ADR-0008 §状态单一所有者）。[br]
## [br]来源: ADR-0008 §GSM 边界、ADR-0007 §_emit_signal_safe、ADR-0001 §第二层原子写入、
## GDD combat-system.md §9、tech-debt DEBT-CBT-018-3。

## 输入锁类型——[code]InputManager.LockType.ANIMATION[/code]。
const LOCK_ANIMATION: int = 1

## 输入锁归属标识——推入与清理用同一个 source（InputManager 按 source 去重）。
const LOCK_SOURCE: StringName = &"combat_system"

## 阶段常量——镜像 [enum CombatSystem.CombatPhase]（只做相等判定，不判语义）。
const PHASE_ATTACK_RESOLUTION: int = 4
const PHASE_ENEMY_TURN: int = 5

## 转场常量——[code]SceneManager.TransitionType.COMBAT_TO_EXPLORE[/code]。
const TRANSITION_COMBAT_TO_EXPLORE: int = 4

## 转场目标场景——[code]SceneManager.SceneId[/code]：胜利 → 结算屏 / 其余 → 战败屏。
const SCENE_RESULT: int = 8
const SCENE_DEFEAT: int = 9

## 结局常量——镜像 [enum CombatSystem.CombatResult.VICTORY]（只做相等判定）。
const RESULT_VICTORY: int = 1

## Autoload 查找器——本模块内的查找已收拢到它（唯一实现）。
const AutoloadAccess := preload("res://src/feature/combat/combat_autoload_access.gd")

## 父节点引用——CombatSystem Autoload 实例（读 [code]_scene_change_enabled[/code]）。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


# === 战斗快照（SaveLoad）=========================================================

## 创建战斗快照——SaveLoad.create_battle_snapshot(GSM.serialize())（AC-004）。[br]
## [br][b]桩实现[/b]——SaveLoad 不可用时静默跳过（记录错误不阻塞战斗启动）。
func create_battle_snapshot() -> void:
	var save_load: Node = _get_save_load()
	if save_load == null or not save_load.has_method("create_battle_snapshot"):
		return
	var gsm: Node = _get_gsm()
	if gsm == null:
		push_warning("CombatSystem: GSM 不可用，跳过战斗快照")
		return
	save_load.create_battle_snapshot(gsm.serialize())


## 清理战斗快照——SaveLoad.clear_battle_snapshot()（AC-014）。
func clear_battle_snapshot() -> void:
	var save_load: Node = _get_save_load()
	if save_load != null and save_load.has_method("clear_battle_snapshot"):
		save_load.clear_battle_snapshot()


# === 输入锁（InputManager）=======================================================

## 推入 ANIMATION 输入锁（AC-005）。[br]
## [br][b]只在阶段 4/5 持有[/b]（DEBT-CBT-018-11 收窄）：GDD 只要求攻击结算与
## 敌方行动这两个「玩家只看不动」的阶段拦截玩法输入；整场持锁会让出牌阶段
## （2）永远收不到点击，输入层不得不为它开一条豁免口子。[br]
## [br][b]与 [method clear_animation_lock] 严格配对[/b]：每次推入都在
## [method sync_animation_lock] 里以「当前是否在阶段 4/5」为唯一判据，
## 重复推入由 InputManager 的 source 去重兜底（不会叠加）。
func push_animation_lock() -> void:
	var im: Node = _get_input_manager()
	if im != null and im.has_method("push_lock"):
		im.push_lock(LOCK_ANIMATION, LOCK_SOURCE)


## 清理 CombatSystem 推入的输入锁（AC-011）。[br]
## [br][b]也用 [code]clear_locks[/code] 而非 pop[/b]：本方法同时服务「离开阶段 4/5」
## 与「战斗结束」两个场景，后者要求无论当前阶段如何都清干净
## （残留锁会让下一场战斗开局的输入被吞）。
func clear_animation_lock() -> void:
	var im: Node = _get_input_manager()
	if im != null and im.has_method("clear_locks"):
		im.clear_locks(LOCK_SOURCE)


## 阶段驱动的锁同步——进入阶段 4/5 推锁，其余阶段不持有。[br]
## [br][b]为什么以「当前阶段」而非「翻越了边界」判定[/b]：状态机可能因校验失败
## 原地不动，边界法会积累漂移；按当前阶段幂等地推/清，任何路径走到这里
## 都会收敛到正确状态（推入与清除各自幂等）。[br]
## [br][param p_phase] 刚进入的阶段（[method CombatSystem.advance_phase] 在簿记后调用）。
func sync_animation_lock(p_phase: int) -> void:
	if p_phase == PHASE_ATTACK_RESOLUTION or p_phase == PHASE_ENEMY_TURN:
		push_animation_lock()
	else:
		clear_animation_lock()


# === 场景转场（SceneManager）=====================================================

## 请求场景切换（AC-015）。
func request_scene_change(result: int) -> void:
	if not bool(_parent.get("_scene_change_enabled")):
		return
	var sm: Node = _parent.call("_get_scene_manager")
	if sm == null or not sm.has_method("request_scene_change"):
		return
	# VICTORY → RESULT_SCREEN(8), DEFEAT/RETREAT → DEFEAT_SCREEN(9)
	var target_scene: int = SCENE_RESULT if result == RESULT_VICTORY else SCENE_DEFEAT
	# TransitionType.COMBAT_TO_EXPLORE = 4
	sm.request_scene_change(TRANSITION_COMBAT_TO_EXPLORE, target_scene,
			TRANSITION_COMBAT_TO_EXPLORE)


# === GSM 第二层镜像 ==============================================================
# 失败回退：GSM 未注册时静默跳过——状态机逻辑不依赖 GSM 镜像，
# GSM 仅负责 Cat 1 信号传播给外部订阅者（CombatUI 等）。

## 通过 GSM 第二层方法镜像 phase 变更。
func gsm_set_battle_phase(phase: int) -> void:
	var gsm: Node = _get_gsm()
	if gsm != null and gsm.has_method("_set_battle_phase"):
		gsm._set_battle_phase(phase)


## 通过 GSM 第二层方法递增回合数。
func gsm_increment_battle_turn() -> void:
	var gsm: Node = _get_gsm()
	if gsm != null and gsm.has_method("_increment_battle_turn"):
		gsm._increment_battle_turn()


## 通过 GSM 第二层方法落位回合数——读档续战专用（[method CombatRosterOps.restore_battle_state]）。[br]
## [br][b]为什么不用 [method gsm_increment_battle_turn][/b]：那一支是「+1」，
## 而存档里的回合是绝对值（可能比 GSM 镜像的现值大好几轮，也可能一样）；
## 逐次 +1 既慢又会把中间那些轮次当成真的发生过。
func gsm_set_battle_turn(turn: int) -> void:
	var gsm: Node = _get_gsm()
	if gsm != null and gsm.has_method("_set_battle_turn"):
		gsm._set_battle_turn(turn)


## 通过 GSM 第二层方法设置战斗活跃状态。
func gsm_set_battle_active(active: bool) -> void:
	var gsm: Node = _get_gsm()
	if gsm != null and gsm.has_method("_set_battle_active"):
		gsm._set_battle_active(active)


## 通过 GSM 第二层方法写入 / 清空「进行中战斗」的存档快照。[br]
## [br][b]存档侧的写入点不在这里[/b]：抓快照要现读布阵与费用（本模块之外的持有方），
## 那是 [code]combat_resume_capture.gd[/code] 的职责；本方法只负责「战斗结束时清空」
## 这条对称出口（不清的话读档会回到一盘已经打完的棋）。
func gsm_set_battle_resume(resume: Dictionary) -> void:
	var gsm: Node = _get_gsm()
	if gsm != null and gsm.has_method("_set_battle_resume"):
		gsm._set_battle_resume(resume)


# === Autoload 取数 ==============================================================
# 三个查找与门面的同名 [code]_get_*[/code] 取的是同一份结果（都走查找器）；
# 门面保留那几个名字是给其它子模块按名字回调用的接缝。

func _get_gsm() -> Node:
	return AutoloadAccess.find(AutoloadAccess.GAME_STATE_MANAGER)


func _get_save_load() -> Node:
	return AutoloadAccess.find(AutoloadAccess.SAVE_LOAD_SYSTEM)


func _get_input_manager() -> Node:
	return AutoloadAccess.find(AutoloadAccess.INPUT_MANAGER)
