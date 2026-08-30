extends Node
## TribulationSystem —— 渡劫突破系统 Autoload（ADR-0021 #24）。
##
## Feature 层 Autoload。渡劫流程编排器——拥有渡劫生命周期状态机，[br]
## 委托 CombatSystem 启动渡劫战、委托 RealmSystem 境界升级、委托 GSM 修为扣除。[br]
## 本文件持有 [enum TribulationState] 枚举 + [enum TribulationType] 枚举 +[br]
## 渡劫触发/状态转换/查询接口 + 5 个 Cat 2b 信号声明。[br]
## [br][b]Story 5-10 范围[/b]：状态机骨架 + GSM 域扩展 + 触发条件检查 + 信号声明。[br]
## [br][b]Story 5-11 范围[/b]：渡劫战斗委托 CombatSystem + 雷伤纯函数 + Boss 配置查询。[br]
## [b]不注册进 project.godot[/b]——待各系统接线后统一注册。[br]
## [br]来源: ADR-0021 §关键接口 / GDD tribulation-system.md §1-7 + §状态与转换。


# === 枚举 ========================================================================

## 渡劫生命周期状态枚举——存入 GSM player.tribulation_state（ADR-0021）。
enum TribulationState {
	NOT_READY = 0,   ## 修为未满，不可渡劫
	READY = 1,        ## 修为已满，可触发渡劫（瞬态——check_tribulation_ready 返回 true 时隐含）
	PREPARING = 2,    ## 渡劫准备阶段（选择渡劫丹+调整角色）
	IN_COMBAT = 3,    ## 渡劫战中（委托 CombatSystem）
	SUCCESS = 4,      ## 突破成功（瞬时状态——结算后回到 NOT_READY）
	FAILED = 5,       ## 渡劫失败（瞬时状态——结算后回到 NOT_READY）
}

## 渡劫类型枚举——正常渡劫 vs 越阶渡劫（ADR-0021 §越阶渡劫）。
enum TribulationType {
	NORMAL = 0,       ## 正常渡劫——挑战同境界天劫 Boss
	CROSS_REALM = 1, ## 越阶渡劫——挑战高一级天劫 Boss
}


# === 常量 ========================================================================

## 渡劫丹使用总上限（GDD §边缘情况 + ADR-0021 §渡劫丹管理）。
const MAX_TRIBULATION_PILLS: int = 2

## 渡劫失败修为损失比例——max_cultivation × 0.15（GDD §公式 1）。
const FAILURE_PENALTY_RATIO: float = 0.15

## 连续失败保护阈值——3 次失败后解锁天劫试炼（GDD §公式 3 + §7）。
const CONSECUTIVE_FAILURE_THRESHOLD: int = 3


# === 信号（Cat 2b）=============================================================

## 渡劫触发——trigger_tribulation() 成功后发射。[br]
## [br][param realm_level] 当前境界等级。[br]
## [br]来源: ADR-0021 §信号分类。
signal tribulation_triggered(realm_level: int)

## 渡劫准备阶段开始——UI 就绪后发射。[br]
## [br]来源: ADR-0021 §信号分类。
signal tribulation_preparation_started()

## 渡劫成功——结算完毕后发射（realm_up + 金卡奖励 + 计数器重置之后）。[br]
## [br][param old_realm] 旧境界等级。[br]
## [br][param new_realm] 新境界等级。[br]
## [br][param is_cross_realm] 是否越阶渡劫。[br]
## [br]来源: ADR-0021 §信号分类。
signal tribulation_succeeded(old_realm: int, new_realm: int, is_cross_realm: bool)

## 渡劫失败——结算完毕后发射（修为扣除 + 失败计数更新后）。[br]
## [br][param penalty] 修为损失量。[br]
## [br][param realm_level] 当前境界等级。[br]
## [br]来源: ADR-0021 §信号分类。
signal tribulation_failed(penalty: int, realm_level: int)

## 天劫庇护解锁——连续失败计数达到阈值时发射。[br]
## [br]来源: ADR-0021 §信号分类 + GDD §7。
signal tribulation_protection_unlocked()


# === 内部状态 ====================================================================

## 当前渡劫类型——trigger_tribulation 时设置，结算后清除。
var _trib_type: int = TribulationType.NORMAL

## 激活的渡劫丹列表——准备阶段使用_tribulation_pill 添加（Story 5-12 实现）。
var _active_pills: Array = []

## 可注入 CombatSystem 引用——测试时设置，绕过 Autoload 查找（同 CombatSystem get_card_instance_cb 模式）。
var _combat_override: Node = null

## 合法状态转换白名单——_validate_state_transition 使用。
## [br]键=当前状态，值=可转换到的状态集合。
const _VALID_TRANSITIONS: Dictionary = {
	TribulationState.NOT_READY: [TribulationState.PREPARING],
	TribulationState.READY: [TribulationState.PREPARING],
	TribulationState.PREPARING: [TribulationState.IN_COMBAT, TribulationState.NOT_READY, TribulationState.READY],
	TribulationState.IN_COMBAT: [TribulationState.SUCCESS, TribulationState.FAILED],
	TribulationState.SUCCESS: [TribulationState.NOT_READY],
	TribulationState.FAILED: [TribulationState.NOT_READY, TribulationState.READY],
}


# === 渡劫触发 ====================================================================

## 检查是否可以渡劫——修为满值 + 当前不在渡劫流程中。[br]
## [br][b]返回[/b]: [code]true[/code] 可渡劫（tribulation_state == NOT_READY 且 cultivation >= max_cultivation），[code]false[/code] 不可。[br]
## [br]来源: ADR-0021 §check_tribulation_ready + GDD §1 渡劫触发条件。
func check_tribulation_ready() -> bool:
	var gsm: Node = _get_gsm()
	if gsm == null:
		push_warning("TribulationSystem.check_tribulation_ready: GSM 不可用")
		return false
	var state: int = int(gsm.player.get("tribulation_state", TribulationState.NOT_READY))
	if state != TribulationState.NOT_READY:
		return false  # 已在渡劫流程中
	var current: int = int(gsm.player.cultivation)
	var max_cult: int = int(gsm.player.max_cultivation)
	return current >= max_cult


## 触发渡劫——进入准备阶段。[br]
## [br][param trib_type] 渡劫类型（NORMAL 或 CROSS_REALM）。[br]
## [br][b]流程[/b]:[br]
##   1. check_tribulation_ready 验证[br]
##   2. 越阶渡劫验证——不能超过最高境界[br]
##   3. 写入 PREPARING 状态到 GSM[br]
##   4. 发射 tribulation_triggered 信号[br]
## [br]来源: ADR-0021 §trigger_tribulation + GDD §1-2。
func trigger_tribulation(trib_type: int = TribulationType.NORMAL) -> void:
	var gsm: Node = _get_gsm()
	if gsm == null:
		push_warning("TribulationSystem.trigger_tribulation: GSM 不可用")
		return

	if not check_tribulation_ready():
		push_warning("TribulationSystem: trigger_tribulation() called but not ready")
		return

	# 越阶渡劫验证——不能跳 2 级以上
	if trib_type == TribulationType.CROSS_REALM:
		var current_realm: int = int(gsm.player.realm)
		var next_realm: int = current_realm + 1
		# RealmSystem 的 realm_table 最大境界为 5
		if next_realm > 5:
			push_warning("TribulationSystem: cross-realm tribulation exceeds max realm")
			return

	_trib_type = trib_type

	# 进入准备阶段——通过 GSM 第二层原子写入
	_set_state(TribulationState.PREPARING)

	# 发射 Cat 2b 信号
	var realm_level: int = int(gsm.player.realm)
	_emit_safe(&"tribulation_triggered", [realm_level])


# === 状态管理 ====================================================================

## 状态转换——验证 + 写入 GSM。[br]
## [br][param new_state] 目标状态。[br]
## [br][b]流程[/b]: 验证转换合法性 → 写入 GSM player.tribulation_state。[br]
## [br][b]非法转换[/b] push_warning + return。[br]
## [br]来源: ADR-0021 §状态与转换。
func _set_state(new_state: int) -> void:
	var gsm: Node = _get_gsm()
	if gsm == null:
		push_warning("TribulationSystem._set_state: GSM 不可用")
		return

	var old_state: int = int(gsm.player.get("tribulation_state", TribulationState.NOT_READY))
	if not _validate_state_transition(old_state, new_state):
		push_warning("TribulationSystem: 非法状态转换 %d → %d" % [old_state, new_state])
		return

	gsm._set_tribulation_state(new_state)


## 验证状态转换合法性——白名单检查。[br]
## [br][param old_state] 当前状态。[br]
## [br][param new_state] 目标状态。[br]
## [br][b]返回[/b]: [code]true[/code] 合法，[code]false[/code] 非法。[br]
## [br]来源: ADR-0021 §状态与转换 + GDD §状态机表。
func _validate_state_transition(old_state: int, new_state: int) -> bool:
	if not _VALID_TRANSITIONS.has(old_state):
		return false
	var allowed: Array = _VALID_TRANSITIONS[old_state]
	return new_state in allowed


# === 查询接口 ====================================================================

## 获取渡劫状态摘要——供 UI 查询。[br]
## [br][b]返回[/b]: [code]{state, consecutive_failures, trib_type}[/code] Dictionary。[br]
## [br]来源: ADR-0021 §查询接口 + UI 查询需求。
func get_tribulation_status() -> Dictionary:
	var gsm: Node = _get_gsm()
	if gsm == null:
		return {"state": TribulationState.NOT_READY, "consecutive_failures": 0, "trib_type": TribulationType.NORMAL}
	return {
		"state": int(gsm.player.get("tribulation_state", TribulationState.NOT_READY)),
		"consecutive_failures": int(gsm.player.get("consecutive_tribulation_failures", 0)),
		"trib_type": _trib_type,
	}


# === 内部辅助 ====================================================================

## Cat 2b 信号安全发射——经 GSM._emit_signal_safe 路由（ADR-0007 信号链深度追踪）。[br]
## [br][b]GSM 不可用时回退[/b]到直接 emit_signal + push_warning 告警。[br]
## [br]来源: ADR-0021 §信号分类 / ADR-0007 §_emit_signal_safe（同 CombatSystem 模式）。
func _emit_safe(signal_name: StringName, args: Array) -> void:
	var gsm = _get_gsm()
	if gsm != null and gsm.has_method("_emit_signal_safe"):
		gsm._emit_signal_safe(self, signal_name, args)
		return
	push_warning("TribulationSystem: GSM 不可用，%s 信号绕过 _emit_signal_safe 路由" % signal_name)
	var call_args: Array = [signal_name]
	call_args.append_array(args)
	callv("emit_signal", call_args)


## 获取 GSM 引用——通过 SceneTree Autoload（同 CultivationSystem/CombatSystem 模式）。
func _get_gsm() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/GameStateManager")


# === 渡劫战斗委托（Story 5-11）==================================================

## Autoload 就绪——订阅 CombatSystem.battle_ended 信号（ADR-0021 §结算监听）。[br]
## [br][b]流程[/b]: 获取 CombatSystem 引用 → 连接 battle_ended → _on_battle_ended。[br]
## [br]来源: ADR-0021 §渡劫战启动与结算监听（同 CultivationSystem 订阅 realm_changed 模式）。
func _ready() -> void:
	var combat: Node = _get_combat_system()
	if combat == null:
		push_warning("TribulationSystem._ready: CombatSystem 不可用，battle_ended 信号未订阅")
		return
	if not combat.battle_ended.is_connected(_on_battle_ended):
		combat.battle_ended.connect(_on_battle_ended)


## 启动渡劫战斗——从 PREPARING → IN_COMBAT + 委托 CombatSystem。[br]
## [br][b]流程[/b]:[br]
##   1. 验证 PREPARING 状态[br]
##   2. _set_state(IN_COMBAT)[br]
##   3. 构建 tribulation_config[br]
##   4. 调用 CombatSystem.battle_start(config)[br]
## [br][b]注意[/b]: 不在此处 await——战斗生命周期由 CombatSystem 管理。[br]
## [br]来源: ADR-0021 §start_tribulation_combat + GDD §3 渡劫战斗规则。
func start_tribulation_combat() -> void:
	var gsm: Node = _get_gsm()
	if gsm == null:
		push_warning("TribulationSystem.start_tribulation_combat: GSM 不可用")
		return
	var state: int = int(gsm.player.get("tribulation_state", TribulationState.NOT_READY))
	if state != TribulationState.PREPARING:
		push_warning("TribulationSystem.start_tribulation_combat: 当前状态非 PREPARING（%d）" % state)
		return
	_set_state(TribulationState.IN_COMBAT)
	var config: Dictionary = _build_tribulation_config()
	var combat: Node = _get_combat_system()
	if combat == null:
		push_warning("TribulationSystem.start_tribulation_combat: CombatSystem 不可用")
		return
	combat.battle_start(config)


## 构建渡劫战斗配置——传入 is_tribulation: true 标志。[br]
## [br][b]返回[/b]: [code]{is_tribulation: true, tribulation_data: {realm_level, is_cross_realm, boss_config}}[/code] Dictionary。[br]
## [br]来源: ADR-0021 §_build_tribulation_config + §CombatSystem 扩展契约。
func _build_tribulation_config() -> Dictionary:
	var gsm: Node = _get_gsm()
	if gsm == null:
		return {}
	var realm_level: int = int(gsm.player.realm)
	var is_cross: bool = _trib_type == TribulationType.CROSS_REALM
	var boss_realm: int = realm_level + 1 if is_cross else realm_level
	var boss_config: Dictionary = get_tribulation_boss_config(boss_realm)
	return {
		"is_tribulation": true,
		"tribulation_data": {
			"realm_level": realm_level,
			"is_cross_realm": is_cross,
			"active_pills": _active_pills.duplicate(true),
			"boss_config": boss_config,
		},
	}


## 监听 CombatSystem.battle_ended——渡劫专属结算入口。[br]
## [br][param result] 战斗结果（CombatResult.VICTORY/DEFEAT/RETREAT）。[br]
## [br][param rewards] 奖励字典。[br]
## [br][b]流程[/b]: 检查 tribulation_state == IN_COMBAT → VICTORY 转 SUCCESS / DEFEAT 转 FAILED。[br]
## [br][b]非渡劫战[/b]: tribulation_state != IN_COMBAT 时忽略（普通战斗不响应）。[br]
## [br]来源: ADR-0021 §_on_battle_ended + GDD §4-5。
func _on_battle_ended(result: int, rewards: Dictionary) -> void:
	var gsm: Node = _get_gsm()
	if gsm == null:
		return
	var state: int = int(gsm.player.get("tribulation_state", TribulationState.NOT_READY))
	if state != TribulationState.IN_COMBAT:
		return  # 非渡劫战——忽略
	# CombatResult.VICTORY=0, DEFEAT=1, RETREAT=2（渡劫战中撤退不可用——仅 DEFEAT）
	if result == 0:  # CombatResult.VICTORY
		_set_state(TribulationState.SUCCESS)
	else:  # DEFEAT or RETREAT
		_set_state(TribulationState.FAILED)


# === 雷伤计算（纯函数）========================================================

## 计算雷伤层数伤害——GDD §公式 3。[br]
## [br][param turn] 当前回合数（从 1 开始）。[br]
## [br][param layers_per_turn] 每回合叠层数（1 或 2）。[br]
## [br][b]返回[/b]: 本回合雷伤 = turn × layers_per_turn（先叠后伤——第1回合末即1层）。[br]
## [br]来源: GDD §公式 3 + §边缘情况「雷伤结算时机」。
func calculate_lightning_damage(turn: int, layers_per_turn: int) -> int:
	if turn < 1:
		return 0
	if layers_per_turn < 1:
		layers_per_turn = 1
	return turn * layers_per_turn


## 获取雷伤每回合叠层数——元婴劫为 2 层/回合，其余 1 层/回合。[br]
## [br][param realm_level] 当前境界等级。[br]
## [br][b]返回[/b]: 元婴劫(realm=4)返回 2，其余返回 1。[br]
## [br]来源: GDD §3 雷伤叠加速度 + §调优参数。
func get_lightning_layers_per_turn(realm_level: int) -> int:
	# 元婴期为第 4 境界——雷伤叠加速度为 2 层/回合
	if realm_level == 4:
		return 2
	return 1


# === 天劫 Boss 配置查询 ========================================================

## 查询天劫 Boss 配置——从 RealmSystem 查询或返回桩默认值。[br]
## [br][param realm] 天劫 Boss 境界等级。[br]
## [br][b]返回[/b]: [code]{realm, hp, atk}[/code] Dictionary。[br]
## [br][b]桩阶段[/b]: 返回默认字典，后续接线 RealmSystem.get_realm_property。[br]
## [br]来源: ADR-0021 §get_tribulation_boss_config + GDD §3 天劫Boss 雷灵。
func get_tribulation_boss_config(realm: int) -> Dictionary:
	# 桩阶段——返回默认 Boss 配置
	# 后续接线：var boss_data = RealmSystem.get_realm_property(realm, &"tribulation_boss")
	return {
		"realm": realm,
		"hp": 1000 + (realm - 1) * 500,
		"atk": 50 + (realm - 1) * 20,
	}


# === CombatSystem 引用 =========================================================

## 获取 CombatSystem 引用——优先使用注入的覆盖引用，否则通过 SceneTree Autoload 查找。[br]
## [br][b]返回[/b]: CombatSystem 节点或 [code]null[/code]（未注册时）。
func _get_combat_system() -> Node:
	if _combat_override != null and is_instance_valid(_combat_override):
		return _combat_override
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/CombatSystem")
