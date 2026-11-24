
## CombatSystem 运行时接缝层（继承链第 6 段）——[b]Autoload 注入 + 注入 setter + 测试开关[/b]。
##
## [b]本层职责[/b]：把战斗域与「谁在驱动它」解耦的全部接缝聚在一处。[br]
##   · [method _ready]——Autoload 实例启动时注入生产回调（CardEffectEngine / CardSystem）；[br]
##   · 注入 setter（[method set_reward_rng] / [method set_scene_manager] /
##     [method set_auto_advance] / [method set_scene_change] / [method set_rng_seed]）；[br]
##   · 测试桩注入（[method set_battle_active] / [method set_attack_queue] /
##     [method set_card_instances] / [method set_hand] 与三堆牌桩）。[br]
##
## [b]为什么 [method _ready] 不在定义层[/b]：它调用查找层的
## [method _get_card_effect_engine] / [method _get_card_system]，而定义层是本链首段——基类
## 静态调用派生类方法是[b]解析期错误[/b]（探针实测 "Function not found in base self"）。
## [method _ready] 与注入 setter 同住「注入面」，注入口径一处可见。[br]
##
## [b]为什么本层排在阶段与出牌层之后[/b]：本层的 [method set_battle_active] 会静态回调
## [method _enter_phase]（阶段起手）与查找层的 [method _get_rewards]——被调方必须在自身或
## 祖先段。[br]
##
## 来源: ADR-0008 §生命周期 §子系统编排顺序、sprint §风险登记（存根策略）。

extends "res://src/feature/combat/combat_system_phase_play.gd"


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


## 设置[b]奖励掷骰[/b]的种子（确定性测试用）——转发 [CombatRewards]。（实现见 combat_rewards.gd）[br]
func set_reward_rng_seed(seed_value: int) -> void:
	_get_rewards().set_reward_rng_seed(seed_value)


## 注入奖励掷骰 RNG 实例（测试用——自行决定种子与推进方式）——转发 [CombatRewards]。（实现见 combat_rewards.gd）[br]
func set_reward_rng(p_rng: RandomNumberGenerator) -> void:
	_get_rewards().set_reward_rng(p_rng)


## 恢复自动播种（注入/显式种子之后的复位入口——测试隔离用）——转发 [CombatRewards]。
func reset_reward_rng() -> void:
	_get_rewards().reset_reward_rng()


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


## 设置攻击队列（测试桩注入——Story 003 接线 play_card 后替换）。
func set_attack_queue(queue: Array) -> void:
	_attack_queue = queue.duplicate()


## 返回攻击队列（测试桩——Story 003 接线后移除）。
func get_attack_queue() -> Array:
	return _attack_queue


## 设置卡牌实例缓存（测试桩注入——Story 003 接线 CardSystem 后移除）。
func set_card_instances(instances: Dictionary) -> void:
	_card_instances = instances.duplicate()


## 设置手牌（测试桩注入——Story 002 接线 DeckSystem 后移除）。
func set_hand(hand: Array) -> void:
	_hand = hand.duplicate()
