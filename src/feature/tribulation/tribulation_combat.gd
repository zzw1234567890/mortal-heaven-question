extends RefCounted
## TribulationCombat —— 渡劫战斗委托子模块（从 tribulation_system.gd 拆分）。
##
## 持有对 TribulationSystem 父节点的引用，通过它访问 _get_gsm / _set_state /
## _trib_type / _active_pills / get_tribulation_boss_config 等。
##
## [br]来源: ADR-0021 §start_tribulation_combat §_on_battle_ended / GDD §3-4。
## [br]Sprint 12 Story 017：从 tribulation_system.gd 拆分。

## TribulationState 枚举值（避免依赖父节点枚举）。
const _STATE_NOT_READY: int = 0
const _STATE_PREPARING: int = 2
const _STATE_IN_COMBAT: int = 3

## TribulationType 枚举值。
const _TYPE_NORMAL: int = 0
const _TYPE_CROSS_REALM: int = 1

## 金卡报告载荷键的出处（不在此写字符串字面量）。
const RewardPoolScript := preload("res://src/feature/tribulation/tribulation_reward_pool.gd")

## 天劫 Boss 名册的组装件（模板表 + 运行时名册——见 ADR-0032）。
const BossRosterScript := preload("res://src/feature/tribulation/tribulation_boss_roster.gd")

## [enum CombatSystem.CombatResult] 的出处——胜负判据的唯一真理来源。[br]
## [br][b]为什么不镜像枚举值[/b]：本模块此前按「胜利=0」判胜，而
## [code]combat_system.gd[/code] 的枚举是 [code]VICTORY = 1 / DEFEAT = 2 /
## RETREAT = 3[/code]——[code]battle_ended[/code] 发的正是真实值，于是
## [b]打赢也走失败结算[/b]（境界不升、修为被扣、金卡不发），且渡劫永不进境。
## 判据改为直接引用枚举本身，字面量再也无法与枚举分叉。[br]
## [br][b]preload 不成环[/b]：[code]combat_system.gd[/code] 及其子模块不反向
## preload 渡劫侧（同 [code]settlement_rules.gd[/code] 引用本枚举的先例）。
const CombatScript := preload("res://src/feature/combat_system.gd")

## 父节点引用——TribulationSystem Autoload 实例。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


## 启动渡劫战斗——从 PREPARING → IN_COMBAT + 委托 CombatSystem。[br]
## [br][b]流程[/b]:[br]
##   1. 验证 PREPARING 状态[br]
##   2. _set_state(IN_COMBAT)[br]
##   3. 构建 tribulation_config[br]
##   4. 调用 CombatSystem.battle_start(config)[br]
## [br][b]注意[/b]: 不在此处 await——战斗生命周期由 CombatSystem 管理。[br]
## [br]来源: ADR-0021 §start_tribulation_combat + GDD §3 渡劫战斗规则。
func start_tribulation_combat() -> void:
	var gsm: Node = _parent.call("_get_gsm")
	if gsm == null:
		push_warning("TribulationSystem.start_tribulation_combat: GSM 不可用")
		return
	var state: int = int(gsm.player.get("tribulation_state", _STATE_NOT_READY))
	if state != _STATE_PREPARING:
		push_warning("TribulationSystem.start_tribulation_combat: 当前状态非 PREPARING（%d）" % state)
		return
	_parent.call("_set_state", _STATE_IN_COMBAT)
	var config: Dictionary = build_tribulation_config()
	var combat: Node = _parent.call("_get_combat_system")
	if combat == null:
		push_warning("TribulationSystem.start_tribulation_combat: CombatSystem 不可用")
		return
	combat.battle_start(config)


## 构建渡劫战斗配置——传入 is_tribulation: true 标志 + 天劫 Boss 名册。[br]
## [br][b]返回[/b]: [code]{is_tribulation: true, enemy_roster, tribulation_data: {realm_level, is_cross_realm, boss_config}}[/code] Dictionary。[br]
## [br][b]为什么名册要放在顶层 [code]enemy_roster[/code][/b]：那是
## [code]CombatSystem.battle_start[/code] 认的键（[code]combat_battle_wiring.gd
## §capture_rosters[/code]）——放错层，胜负判定拿到空名册，
## [code]CombatEndCheck._all_enemies_dead[/code] 对空名册返回 false，
## 于是把敌人打光也判不出胜负（DEBT-TRB-001 的形态）。[br]
## [br][b]名册是运行时对象而非 id[/b]：由 [code]TribulationBossRoster.build[/code]
## 现建（模板 → [code]EnemyBattleState[/code] + 阵位 + 写回 AISystem），
## 与探索侧 [code]combat_scene_battle_setup.gd §_resolve_roster[/code] 的产物形状一致。[br]
## [br][b]不备名册的后果与降级[/b]：雷灵模板缺失时 [code]build[/code] 返回空数组，
## 本函数照常开战（不阻断）——但名册为空即判不出胜负，故 [code]boss_config[/code] 里
## 的 [code]enemy_roster[/code] 也为空，可据此诊断。[br]
## [br]来源: ADR-0021 §_build_tribulation_config + §CombatSystem 扩展契约、ADR-0032。
func build_tribulation_config() -> Dictionary:
	var gsm: Node = _parent.call("_get_gsm")
	if gsm == null:
		return {}
	var realm_level: int = int(gsm.player.realm)
	var is_cross: bool = _parent.get("_trib_type") == _TYPE_CROSS_REALM
	var boss_realm: int = realm_level + 1 if is_cross else realm_level
	var boss_config: Dictionary = _parent.call("get_tribulation_boss_config", boss_realm)
	var active_pills: Array = _parent.get("_active_pills")
	# 天劫 Boss 运行时名册——现建并写回 AISystem（AI 决策读的就是它）。
	# 取不到 AISystem 时为空数组：不阻断开战，但这一场判不出胜负（见方法文档）。
	var ai: Node = _parent.call("_get_ai_system")
	var roster: Array = BossRosterScript.build(ai, boss_realm)
	if roster.is_empty():
		push_warning("TribulationCombat: 天劫 Boss 名册为空（境界 %d）——"
				+ "本场无法判定胜利，请检查 assets/enemies/tribulation/ 下的雷灵模板"
				% boss_realm)
	return {
		"is_tribulation": true,
		"enemy_roster": roster,
		"tribulation_data": {
			"realm_level": realm_level,
			"is_cross_realm": is_cross,
			"active_pills": active_pills.duplicate(true),
			"boss_config": boss_config,
		},
	}


## 监听 CombatSystem.battle_ended——渡劫专属结算入口。[br]
## [br][param result] 战斗结果（CombatResult.VICTORY/DEFEAT/RETREAT）。[br]
## [br][param rewards] 奖励字典（[b]本方法会往里写渡劫金卡报告[/b]——见下）。[br]
## [b]流程[/b]: 检查 tribulation_state == IN_COMBAT → VICTORY 调用 _handle_success / DEFEAT 调用 _handle_failure。[br]
## [br][b]非渡劫战[/b]: tribulation_state != IN_COMBAT 时忽略（普通战斗不响应）。[br]
## [br][b]同一条判据兼作幂等守卫[/b]：结算是「本场在不在打」这一事实的消费方——
## [code]TribulationSettlement.handle_success[/code] 最后一步把状态推回
## [code]NOT_READY[/code]，故同一场被结算两次时第二次直接走这里的 return：
## 境界不会连升两级、金卡不会连发两遍、修为不会连扣两次。[b]不另造序号[/b]
## （[code]CombatSystem._battle_serial[/code] 那套是战斗域自己的掷骰守卫，
## 渡劫这层用状态机本身的事实即可）。[br]
## [br][b]为什么把金卡报告写回 [code]rewards[/code] 而不是另发信号[/b]：
## [code]battle_ended[/code] 的载荷就是本场战果的唯一载体——结算面板
## （[code]SettlementHost[/code]）与结算屏（[code]CombatResultView[/code]）都从它取数。
## 另发一条信号会让这两处各多一次订阅与断线，还引入「谁先到」的时序问题。[br]
## [br][b]写入时机依赖连接顺序[/b]：[code]TribulationSystem[/code] 在 Autoload
## [code]_ready[/code] 里订阅（[code]tribulation_system.gd[/code] §_ready），早于任何
## 战斗场景装配的订阅者（如 [code]combat_result_bridge.gd[/code]）——故本方法在
## 折叠载荷之前就把键写好了。这一条是契约，改动订阅时机需同步复核。[br]
## [br]来源: ADR-0021 §_on_battle_ended + GDD §4-5/§6。
func on_battle_ended(result: int, rewards: Dictionary) -> void:
	var gsm: Node = _parent.call("_get_gsm")
	if gsm == null:
		return
	var state: int = int(gsm.player.get("tribulation_state", _STATE_NOT_READY))
	if state != _STATE_IN_COMBAT:
		return  # 非渡劫战 / 本场已结算过——忽略
	# 胜负判据引 [enum CombatSystem.CombatResult] 本身（VICTORY=1 / DEFEAT=2 /
	# RETREAT=3）——[code]battle_ended[/code] 发的就是这个枚举的真实取值。
	# 渡劫战中撤退不可用，故非 VICTORY 一律走失败（DEFEAT 与 RETREAT 同路）。
	if result == CombatScript.CombatResult.VICTORY:
		var report: Dictionary = _parent.call("_handle_tribulation_success")
		_attach_reward_report(rewards, report)
	else:  # DEFEAT or RETREAT
		_parent.call("_handle_tribulation_failure")


## 把金卡发放报告写进 [code]battle_ended[/code] 载荷（键名取自
## [code]tribulation_reward_pool.gd[/code]——唯一出处，消费方都引它）。[br]
## [br][b]失败不发卡也不写键[/b]：没有奖励就没有这一段，结算界面自然「不建那一行」。[br]
## [br][b]载荷为空时静默跳过[/b]：没有可写的载荷就没有这一段（载荷被换掉 / 调用方只
## 传字面量空字典的路径不该在这里崩）。
func _attach_reward_report(rewards: Dictionary, report: Dictionary) -> void:
	if rewards == null or report == null or report.is_empty():
		return
	rewards[RewardPoolScript.KEY_PAYLOAD] = report.duplicate(true)
