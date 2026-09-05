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


## 构建渡劫战斗配置——传入 is_tribulation: true 标志。[br]
## [br][b]返回[/b]: [code]{is_tribulation: true, tribulation_data: {realm_level, is_cross_realm, boss_config}}[/code] Dictionary。[br]
## [br]来源: ADR-0021 §_build_tribulation_config + §CombatSystem 扩展契约。
func build_tribulation_config() -> Dictionary:
	var gsm: Node = _parent.call("_get_gsm")
	if gsm == null:
		return {}
	var realm_level: int = int(gsm.player.realm)
	var is_cross: bool = _parent.get("_trib_type") == _TYPE_CROSS_REALM
	var boss_realm: int = realm_level + 1 if is_cross else realm_level
	var boss_config: Dictionary = _parent.call("get_tribulation_boss_config", boss_realm)
	var active_pills: Array = _parent.get("_active_pills")
	return {
		"is_tribulation": true,
		"tribulation_data": {
			"realm_level": realm_level,
			"is_cross_realm": is_cross,
			"active_pills": active_pills.duplicate(true),
			"boss_config": boss_config,
		},
	}


## 监听 CombatSystem.battle_ended——渡劫专属结算入口。[br]
## [br][param result] 战斗结果（CombatResult.VICTORY/DEFEAT/RETREAT）。[br]
## [br][param rewards] 奖励字典。[br]
## [br][b]流程[/b]: 检查 tribulation_state == IN_COMBAT → VICTORY 调用 _handle_success / DEFEAT 调用 _handle_failure。[br]
## [br][b]非渡劫战[/b]: tribulation_state != IN_COMBAT 时忽略（普通战斗不响应）。[br]
## [br]来源: ADR-0021 §_on_battle_ended + GDD §4-5。
func on_battle_ended(result: int, _rewards: Dictionary) -> void:
	var gsm: Node = _parent.call("_get_gsm")
	if gsm == null:
		return
	var state: int = int(gsm.player.get("tribulation_state", _STATE_NOT_READY))
	if state != _STATE_IN_COMBAT:
		return  # 非渡劫战——忽略
	# CombatResult.VICTORY=0, DEFEAT=1, RETREAT=2（渡劫战中撤退不可用——仅 DEFEAT）
	if result == 0:  # CombatResult.VICTORY
		_parent.call("_handle_tribulation_success")
	else:  # DEFEAT or RETREAT
		_parent.call("_handle_tribulation_failure")
