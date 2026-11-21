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
const _STATE_IN_COMBAT: int = 3

## 金卡奖励发放单点（GDD §6——普通 1 张 / 越阶 2 张，从金档池随机取）。
const RewardPoolScript := preload("res://src/feature/tribulation/tribulation_reward_pool.gd")

## TribulationType 枚举值。
const _TYPE_NORMAL: int = 0
const _TYPE_CROSS_REALM: int = 1

## 渡劫失败修为损失比例——max_cultivation × 0.15（GDD §公式 1）。
const FAILURE_PENALTY_RATIO: float = 0.15

## 连续失败保护阈值——3 次失败后解锁天劫试炼（GDD §公式 3 + §7）。
const CONSECUTIVE_FAILURE_THRESHOLD: int = 3

## 父节点引用——TribulationSystem Autoload 实例。
var _parent: Node = null

## 金卡奖励发放件——惰性初始化（[method _reward_pool]）。
var _reward_pool_instance: RefCounted = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


## 渡劫成功结算——调用 realm_up + 发金卡 + 重置失败计数 + 发射信号。[br]
## [br][b]流程[/b]（ADR-0021 §_handle_tribulation_success）:[br]
##   1. 记录 old_realm[br]
##   2. 调用 RealmSystem.realm_up(old_realm)[br]
##   3. GSM._set_consecutive_tribulation_failures(0)[br]
##   4. 发金卡奖励（普通 1 张 / 越阶 2 张——GDD §6）[br]
##   5. _set_state(SUCCESS)[br]
##   6. 发射 tribulation_succeeded 信号[br]
##   7. _set_state(NOT_READY)[br]
## [br][b]幂等[/b]：入口先判「本场是否真的在打」——[code]tribulation_state[/code] 不是
## [code]IN_COMBAT[/code] 就直接返回（判据与 [code]TribulationCombat.on_battle_ended[/code]
## 完全同一处，不另造一套序号）。同一场渡劫被结算两次（场景重入 / 重复 [code]battle_end[/code]）
## 时第二次进不来：境界不会连升两级、金卡不会连发两遍、失败计数也不会被再清一次。[br]
## [br][b]返回[/b]：本场金卡发放报告 [code]{cards, cards_failed}[/code]（两键恒在）——
## 由 [code]TribulationCombat.on_battle_ended[/code] 写进 [code]battle_ended[/code] 载荷，
## 结算屏据此写出「获得：×××（金）」。未获发（池空 / 收藏被拒）时
## [code]cards_failed[/code] 带中文原因，结算屏照实说明「未发放」。[br]
## [br]来源: ADR-0021 §_handle_tribulation_success + GDD §4/§6。
func handle_success() -> Dictionary:
	var gsm: Node = _parent.call("_get_gsm")
	if gsm == null:
		return _empty_report()
	if not _is_settling(gsm, "handle_success"):
		return _empty_report()
	var old_realm: int = int(gsm.player.realm)
	var is_cross: bool = _parent.get("_trib_type") == _TYPE_CROSS_REALM
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
	# 4. 金卡奖励——GDD §6：普通 1 张、越阶额外 +1 张，从新境界卡池的金档取
	var report: Dictionary = _reward_pool().grant(
			_card_system(), gsm, is_cross)
	# 5. 进入 SUCCESS 状态
	_parent.call("_set_state", _STATE_SUCCESS)
	# 6. 发射渡劫成功信号（载荷沿用已接受的三参签名——金卡报告走 battle_ended 载荷，
	#    不在此扩参：扩参会同时改变既有订阅者的回调签名）
	_parent.call("_emit_safe", &"tribulation_succeeded", [old_realm, new_realm, is_cross])
	# 7. 回到 NOT_READY
	_parent.call("_set_state", _STATE_NOT_READY)
	_parent.set("_trib_type", _TYPE_NORMAL)
	_parent.get("_active_pills").clear()
	return report


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


## 获取 CardSystem 引用——经父节点取（父节点支持注入覆盖，测试可换夹具注册表）。[br]
## [br][b]取不到返回 null 而不是报错[/b]：金卡池取不到要走「未发放」降级，不是崩溃点。
func _card_system() -> Node:
	if _parent == null or not _parent.has_method("_get_card_system"):
		return null
	return _parent.call("_get_card_system")


## 金卡奖励发放件（惰性初始化——不发奖的路径不构造它）。
func _reward_pool() -> RefCounted:
	if _reward_pool_instance == null:
		_reward_pool_instance = RewardPoolScript.new()
	return _reward_pool_instance


## 本场是否真的在「打渡劫」——幂等守卫（见 [method handle_success] 的「幂等」）。[br]
## [br][b]为什么直接读状态而不自己记序号[/b]：状态机本身已经是「本场在不在打」的
## 唯一事实——[code]IN_COMBAT[/code] 进出由 [code]start_tribulation_combat[/code] 与
## 结算的收尾一步配对。自记序号会多出一份可以与状态机不一致的簿记，而
## [code]TribulationCombat.on_battle_ended[/code] 已经在用同一个判据，
## 两处判据同源才不可能分叉。[br]
## [br][b]不在渡劫中一律不收尾[/b]：普通战斗撞上来的 [code]battle_ended[/code]、
## 重复结算、以及玩家从节点图直接进渡劫场景的降级路径，全都落到这里返回。
func _is_settling(gsm: Node, p_caller: String) -> bool:
	var state: int = int(gsm.player.get("tribulation_state", _STATE_NOT_READY))
	if state == _STATE_IN_COMBAT:
		return true
	push_warning("TribulationSystem.%s: 当前状态非 IN_COMBAT（%d）——本场渡劫不结算"
			% [p_caller, state])
	return false


## 空发放报告（两键恒在——消费方无需判 null）。
func _empty_report() -> Dictionary:
	return {
		RewardPoolScript.KEY_CARDS: [],
		RewardPoolScript.KEY_FAILED: [],
	}


## 渡劫失败结算——修为扣除 + 失败计数 + 发射信号 + 保护检查。[br]
## [br][b]流程[/b]（ADR-0021 §_handle_tribulation_failure + GDD §5）:[br]
##   1. 计算 penalty = floor(max_cult × FAILURE_PENALTY_RATIO)[br]
##   2. 扣除修为（兜底 ≥ 0）[br]
##   3. 失败计数 +1[br]
##   4. _set_state(FAILED)[br]
##   5. 发射 tribulation_failed 信号[br]
##   6. 连续 ≥3 次发射 tribulation_protection_unlocked[br]
##   7. _set_state(NOT_READY)[br]
## [br][b]幂等[/b]：与 [method handle_success] 同一条守卫（[method _is_settling]）
## ——同一场结算两次不会扣两遍修为、也不会把失败计数加两次。[br]
## [br]来源: ADR-0021 §_handle_tribulation_failure + GDD §5 + §公式 1。
func handle_failure() -> void:
	var gsm: Node = _parent.call("_get_gsm")
	if gsm == null:
		return
	if not _is_settling(gsm, "handle_failure"):
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
