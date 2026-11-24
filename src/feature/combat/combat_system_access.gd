
## CombatSystem 查找层（继承链第 3 段）——[b]所有 Autoload 查找与子模块惰性获取[/b]住这一层。
##
## [b]本层职责[/b]：战斗域与外部世界的[b]唯一接触面[/b]。[br]
##   · 13 个 [code]_get_X_system()[/code] / [code]_get_gsm()[/code] Autoload 查找——
##     实现全部转发 [code]combat_autoload_access.gd[/code]（唯一实现，逐字不动）；[br]
##   · 16 个惰性子模块 getter（伤害计算 / 出牌结算 / 阶段管理 / 名册 / 奖励 / 三堆牌 /
##     阶段序列件 / 生命周期 / 副作用件…）——[code]null[/code] 时按需 [code]preload().new(self)[/code]；[br]
##   · 3 个取数口（[method get_roster_state] / [method get_damage_settlement] /
##     [method _extract_character_id]）——战斗域之外的表现层装配用。[br]
##
## [b]为什么这一层住在链上而非组合[/b]：产品代码与 16 个子模块按名字回调这些口
## （[code]_parent.get("_phase")[/code] 有、[code]_parent.call("_get_piles")[/code] 无）；
## 名字与签名一律不动，只换所在文件。[br]
##
## [b]本层不持状态[/b]：字段（含 [member _scene_manager_override] 这类覆盖开关）全在
## [code]combat_system_fields.gd[/code]，沿链可见。[br]
##
## 来源: ADR-0008 §架构原则、tech-debt DEBT-CBT-018-3。

extends "res://src/feature/combat/combat_system_fields.gd"


## 查找 SaveLoadSystem Autoload（薄转发——实现在 combat_autoload_access.gd）。
func _get_save_load() -> Node:
	return AutoloadAccess.find(AutoloadAccess.SAVE_LOAD_SYSTEM)


## 查找 InputManager Autoload（薄转发——实现在 combat_autoload_access.gd）。
func _get_input_manager() -> Node:
	return AutoloadAccess.find(AutoloadAccess.INPUT_MANAGER)


## 查找 SceneManager——注入覆盖优先（测试桩），否则 /root/SceneManager Autoload。[br]
## [br][b]为什么这一支不走纯查找[/b]：[code]_scene_manager_override[/code] 是门面的
## 状态字段（ADR-0008 §状态单一所有者），查找器不持状态，故「覆盖优先」这一层判据
## 只能留在门面。覆盖为空时仍走同一份查找实现。
func _get_scene_manager() -> Node:
	if _scene_manager_override != null:
		return _scene_manager_override
	return AutoloadAccess.find(AutoloadAccess.SCENE_MANAGER)


# === Autoload 查找（薄转发——实现在 combat_autoload_access.gd）====================

## 查找 CostSystem Autoload。
func _get_cost_system() -> Node:
	return AutoloadAccess.find(AutoloadAccess.COST_SYSTEM)


## 查找 RealmSystem Autoload。
func _get_realm_system() -> Node:
	return AutoloadAccess.find(AutoloadAccess.REALM_SYSTEM)


## 查找 CardEffectEngine Autoload。
func _get_card_effect_engine() -> Node:
	return AutoloadAccess.find(AutoloadAccess.CARD_EFFECT_ENGINE)


## 查找 CardSystem Autoload。
func _get_card_system() -> Node:
	return AutoloadAccess.find(AutoloadAccess.CARD_SYSTEM)


## 查找 StatusEffectSystem Autoload。
func _get_status_effect_system() -> Node:
	return AutoloadAccess.find(AutoloadAccess.STATUS_EFFECT_SYSTEM)


## 查找 DeploymentSystem Autoload。
func _get_deployment_system() -> Node:
	return AutoloadAccess.find(AutoloadAccess.DEPLOYMENT_SYSTEM)


## 查找 AISystem Autoload。
func _get_ai_system() -> Node:
	return AutoloadAccess.find(AutoloadAccess.AI_SYSTEM)


## 查找 ResourceSystem Autoload。
func _get_resource_system() -> Node:
	return AutoloadAccess.find(AutoloadAccess.RESOURCE_SYSTEM)


## 查找 CultivationSystem Autoload。
func _get_cultivation_system() -> Node:
	return AutoloadAccess.find(AutoloadAccess.CULTIVATION_SYSTEM)


## 查找 GameStateManager Autoload——返回 null 时调用方静默跳过。
func _get_gsm() -> Node:
	return AutoloadAccess.find(AutoloadAccess.GAME_STATE_MANAGER)


## 从角色条目提取 character_id——兼容 Dictionary / 对象。
func _extract_character_id(char_entry: Variant) -> int:
	if char_entry is Dictionary:
		return int(char_entry.get("character_id", char_entry.get("id", -1)))
	if char_entry is Object and char_entry.has_method("get"):
		return int(char_entry.get("character_id", -1))
	if char_entry is int:
		return char_entry
	return -1


# === 子模块获取（惰性初始化）===================================================

## 获取伤害计算子模块实例。
func _get_damage_calculator() -> RefCounted:
	if _damage_calculator == null:
		_damage_calculator = preload("res://src/feature/combat/combat_damage_calculator.gd").new(self)
	return _damage_calculator


## 获取出牌结算子模块实例。
func _get_card_resolver() -> RefCounted:
	if _card_resolver == null:
		_card_resolver = preload("res://src/feature/combat/combat_card_resolver.gd").new(self)
	return _card_resolver


## 获取阶段管理子模块实例（Sprint 9 Story 8 拆分）。
func _get_phase_manager() -> RefCounted:
	if _phase_manager == null:
		_phase_manager = preload("res://src/feature/combat/combat_phase_manager.gd").new(self)
	return _phase_manager


## 敌方回合结算模块（决策 + 落库 + 广播）——惰性创建。
func _get_enemy_turn() -> RefCounted:
	if _enemy_turn == null:
		_enemy_turn = preload("res://src/feature/combat/combat_enemy_turn.gd").new(self)
	return _enemy_turn


## 获取战斗接线子模块实例（Sprint 18——名册快照 / 费用激活 / END 判定）。
func _get_battle_wiring() -> RefCounted:
	if _battle_wiring == null:
		_battle_wiring = preload("res://src/feature/combat/combat_battle_wiring.gd").new(self)
	return _battle_wiring


## 获取敌我角色运行时状态子模块（Sprint 18 / DEBT-CBT-018-1——HP 落库）。
func _get_roster_state() -> RefCounted:
	if _roster_state == null:
		_roster_state = preload("res://src/feature/combat/combat_roster_state.gd").new()
	return _roster_state


## 获取本场战绩累积器（Sprint 18 结算回流——效果条目计数 + 结束定格）。
func _get_battle_record() -> RefCounted:
	if _battle_record == null:
		_battle_record = preload("res://src/feature/combat/combat_battle_record.gd").new()
	return _battle_record


## 获取 HP 跨战斗持久化子模块（Sprint 18 结算回流 / DEBT-CBT-018-3）。
func _get_hp_carryover() -> RefCounted:
	if _hp_carryover == null:
		_hp_carryover = HpCarryoverScript.new(self)
	return _hp_carryover


## 获取伤害落库 + 阵亡处理子模块（Sprint 18 / DEBT-CBT-018-1）。
func _get_damage_settlement() -> RefCounted:
	if _damage_settlement == null:
		_damage_settlement = preload("res://src/feature/combat/combat_damage_settlement.gd").new(self)
	return _damage_settlement


## 获取攻击队列减伤覆盖子模块（DEBT-CBT-018-8 残留——绑定卡减伤写入队列条目）。
func _get_attack_coverage() -> RefCounted:
	if _attack_coverage == null:
		_attack_coverage = preload("res://src/feature/combat/combat_attack_coverage.gd").new(self)
	return _attack_coverage


## 获取奖励结算子模块实例（掷骰 / 持久化 / 发放 / 奖励 RNG——本轮拆出）。[br]
## [br][b]为什么惰性[/b]：同其余子模块口径——未开战/未结算的战斗不该多建对象。
func _get_rewards() -> RefCounted:
	if _rewards == null:
		_rewards = preload("res://src/feature/combat/combat_rewards.gd").new(self)
	return _rewards


## 获取名册 / 战绩子模块实例（开战种子 / 取数口 / 结束定格 / 读档落位——本轮拆出）。
func _get_roster_ops() -> RefCounted:
	if _roster_ops == null:
		_roster_ops = preload("res://src/feature/combat/combat_roster_ops.gd").new(self)
	return _roster_ops


## 获取三堆牌子模块实例（抽牌 / 洗牌 / 弃牌 / 开局发牌 / 读档恢复——本轮拆出）。
func _get_piles() -> RefCounted:
	if _piles == null:
		_piles = preload("res://src/feature/combat/combat_card_piles.gd").new(self)
	return _piles


## 获取阶段序列件实例（推进 / 手动确认 / 阶段条件检查——本轮拆出）。
func _get_phase_sequencer() -> RefCounted:
	if _phase_sequencer == null:
		_phase_sequencer = preload("res://src/feature/combat/combat_phase_sequencer.gd").new(self)
	return _phase_sequencer


## 获取战斗生命周期模块实例（开战 / 终战 / 撤退 / 续战复位——本轮拆出）。
func _get_lifecycle() -> RefCounted:
	if _lifecycle == null:
		_lifecycle = preload("res://src/feature/combat/combat_battle_lifecycle.gd").new(self)
	return _lifecycle


## 获取战斗副作用模块实例（快照 / 输入锁 / 转场 / GSM 镜像——本轮拆出）。
func _get_side_effects() -> RefCounted:
	if _side_effects == null:
		_side_effects = preload("res://src/feature/combat/combat_battle_side_effects.gd").new(self)
	return _side_effects


# === 只读/落库子模块的公开取数口（战斗域之外的表现层装配用）=====================

## 敌我角色运行时状态表（HP / 存活 / 属性增益）。[br]
func get_roster_state() -> RefCounted:
	return _get_roster_state()


## 伤害落库模块（治疗 = 负伤害；唯一写 [code]current_hp[/code] 的路径）。[br]
func get_damage_settlement() -> RefCounted:
	return _get_damage_settlement()
