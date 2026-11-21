extends RefCounted
## TribulationSettlement —— 渡劫结算子模块（从 tribulation_system.gd 拆分）。
##
## 持有对 TribulationSystem 父节点的引用，通过它访问 _get_gsm / _set_state /
## _emit_safe / _get_realm_system / _trib_type / _active_pills 等。
##
## [br]来源: ADR-0021 §_handle_tribulation_success §_handle_tribulation_failure / GDD §4-5。
## [br]Sprint 9 Story 7：从 tribulation_system.gd 拆分。

## TribulationState 枚举值（避免依赖父节点枚举）。
const _STATE_SUCCESS: int = 4
const _STATE_FAILED: int = 5
const _STATE_NOT_READY: int = 0

## TribulationType 枚举值。
const _TYPE_NORMAL: int = 0
const _TYPE_CROSS_REALM: int = 1

## 渡劫失败修为损失比例——max_cultivation × 0.15（GDD §公式 1）。
const FAILURE_PENALTY_RATIO: float = 0.15

## 连续失败保护阈值——3 次失败后解锁天劫试炼（GDD §公式 3 + §7）。
const CONSECUTIVE_FAILURE_THRESHOLD: int = 3

## 父节点引用——TribulationSystem Autoload 实例。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


## 渡劫成功结算——调用 realm_up + 重置失败计数 + 发射信号。[br]
## [br][b]流程[/b]（ADR-0021 §_handle_tribulation_success）:[br]
##   1. 记录 old_realm[br]
##   2. 调用 RealmSystem.realm_up(old_realm)[br]
##   3. GSM._set_consecutive_tribulation_failures(0)[br]
##   4. _set_state(SUCCESS)[br]
##   5. 发射 tribulation_succeeded 信号[br]
##   6. _set_state(NOT_READY)[br]
## [br][b]金卡奖励[/b]: TODO——CardSystem 未接线，后续 Sprint 补充。[br]
## [br]来源: ADR-0021 §_handle_tribulation_success + GDD §4。
func handle_success() -> void:
	var gsm: Node = _parent.call("_get_gsm")
	if gsm == null:
		return
	var old_realm: int = int(gsm.player.realm)
	# 1. 调用 RealmSystem.realm_up——编排境界升级全流程
	var realm_sys: Node = _parent.call("_get_realm_system")
	if realm_sys != null and realm_sys.has_method("realm_up"):
		realm_sys.realm_up(old_realm)
	else:
		push_warning("TribulationSystem: RealmSystem 不可用，realm_up 未调用")
	var new_realm: int = int(gsm.player.realm)
	# 2. 修为上限重算 + 溢出结算（见 _recompute_max_cultivation 的「为什么要显式调」）
	_recompute_max_cultivation(new_realm)
	# 3. 重置连续失败计数器
	gsm._set_consecutive_tribulation_failures(0)
	# 4. 金卡奖励——TODO: CardSystem 未接线
	# 5. 进入 SUCCESS 状态
	_parent.call("_set_state", _STATE_SUCCESS)
	var is_cross: bool = _parent.get("_trib_type") == _TYPE_CROSS_REALM
	# 6. 发射渡劫成功信号
	_parent.call("_emit_safe", &"tribulation_succeeded", [old_realm, new_realm, is_cross])
	# 7. 回到 NOT_READY
	_parent.call("_set_state", _STATE_NOT_READY)
	_parent.set("_trib_type", _TYPE_NORMAL)
	_parent.get("_active_pills").clear()


## 请 [code]CultivationSystem[/code] 按新境界重算修为上限（并顺带结算溢出池）。[br]
## [br][b]为什么渡劫这边要显式调一次[/b]：按设计，上限重算走
## [code]realm_changed[/code]（Cat 1）→ [code]CultivationSystem.on_realm_changed[/code]
## （GDD §6/§7）。但 GSM 的域信号只在「本帧恰好一条变更」时发射，多条时[b]只发
## [code]batch_updated[/code][/b]——而渡劫结算是典型的同帧多写入（境界 + 渡劫状态 +
## 连续失败计数），[code]realm_changed[/code] 根本到不了 [code]CultivationSystem[/code]：
## 修为上限会停在上一个境界（溢出池也不会结算）。[br]
## [br][b]幂等[/b]：[code]update_max_cultivation[/code] 值没变就不写、溢出不足一个
## 转化单位也不写——信号真到了的那条路再算一次同样无害。[br]
## [br][b]取不到就算了[/b]：系统缺失时 push_warning 并返回（境界已经升上去了，
## 不能因为重算不到就把结算判失败）。[br]
## [br]来源: GDD cultivation-system.md §6/§7、ADR-0010 §realm_up 编排器、
## GSM 帧末缓冲既有契约（[code]gsm_signal_router.gd[/code] §_flush_pending_changes）。
func _recompute_max_cultivation(p_new_realm: int) -> void:
	var cs: Node = _cultivation_system()
	if cs == null or not cs.has_method("update_max_cultivation"):
		push_warning("TribulationSystem: CultivationSystem 不可用，修为上限未重算")
		return
	cs.call("update_max_cultivation", p_new_realm)


## 获取 CultivationSystem 引用——通过 SceneTree Autoload。
func _cultivation_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/CultivationSystem")


## 渡劫失败结算——修为扣除 + 失败计数 + 发射信号 + 保护检查。[br]
## [br][b]流程[/b]（ADR-0021 §_handle_tribulation_failure + GDD §5）:[br]
##   1. 计算 penalty = floor(max_cult × FAILURE_PENALTY_RATIO)[br]
##   2. 扣除修为（兜底 ≥ 0）[br]
##   3. 失败计数 +1[br]
##   4. _set_state(FAILED)[br]
##   5. 发射 tribulation_failed 信号[br]
##   6. 连续 ≥3 次发射 tribulation_protection_unlocked[br]
##   7. _set_state(NOT_READY)[br]
## [br]来源: ADR-0021 §_handle_tribulation_failure + GDD §5 + §公式 1。
func handle_failure() -> void:
	var gsm: Node = _parent.call("_get_gsm")
	if gsm == null:
		return
	var max_cult: int = int(gsm.player.max_cultivation)
	var current: int = int(gsm.player.cultivation)
	# 1. 计算修为损失——max_cult × 0.15（GDD §公式 1）
	var penalty: int = int(floor(float(max_cult) * FAILURE_PENALTY_RATIO))
	# 2. 扣除修为——兜底不会低于 0
	var new_cult: int = maxi(current - penalty, 0)
	if new_cult != current:
		gsm.player.cultivation = new_cult
		gsm._buffer_change("player.cultivation", current, new_cult)
	# 3. 失败计数 +1
	var failures: int = int(gsm.player.get("consecutive_tribulation_failures", 0)) + 1
	gsm._set_consecutive_tribulation_failures(failures)
	# 4. 进入 FAILED 状态
	_parent.call("_set_state", _STATE_FAILED)
	# 5. 发射渡劫失败信号
	var realm_level: int = int(gsm.player.realm)
	_parent.call("_emit_safe", &"tribulation_failed", [penalty, realm_level])
	# 6. 连续失败保护
	if failures >= CONSECUTIVE_FAILURE_THRESHOLD:
		_parent.call("_emit_safe", &"tribulation_protection_unlocked", [])
	# 7. 回到 NOT_READY
	_parent.call("_set_state", _STATE_NOT_READY)
	_parent.set("_trib_type", _TYPE_NORMAL)
	_parent.get("_active_pills").clear()


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
