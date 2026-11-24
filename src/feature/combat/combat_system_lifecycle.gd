
## CombatSystem 生命周期层（继承链第 4 段）——[b]开战 / 终战 / 撤退 / 续战复位[/b]住这一层。
##
## [b]本层职责[/b]：本场战斗的[b]起止编排面[/b]（薄转发到既有子模块，名字与签名逐字不动）。[br]
##   · 开战 / 终战 / 撤退 / 续战复位 → [code]combat_battle_lifecycle.gd[/code]；[br]
##   · 名册快照 / 费用激活 / END 判定 / 结局收尾 → [code]combat_battle_wiring.gd[/code]；[br]
##   · HP 落库取数口 / 战绩定格 / 读档落位 → [code]combat_roster_ops.gd[/code]；[br]
##   · 奖励掷骰与发放 → [code]combat_rewards.gd[/code]；[br]
##   · 快照 / 输入锁 / 转场请求 → [code]combat_battle_side_effects.gd[/code]。[br]
##
## [b]为什么这一层是「薄转发」而链尾不是[/b]：这些名字是场景容器
## （[code]combat_scene_battle_setup.gd[/code] / [code]combat_scene_resume.gd[/code] /
## [code]combat_scene_exits.gd[/code]）、子模块（[code]combat_battle_wiring.gd[/code] /
## [code]combat_battle_lifecycle.gd[/code]）与大量既有用例按名字调用的入口，内部实现早已在
## 子模块里——本层只是把入口按职责聚拢，不改内部顺序。[br]
##
## 来源: ADR-0008 §生命周期 / GDD combat-system.md §7 战斗结束、§结算回流。

extends "res://src/feature/combat/combat_system_access.gd"


# === 战斗生命周期（Story 002）====================================================
# 编排与顺序契约在 combat_battle_lifecycle.gd（开战 / 终战 / 撤退 / 续战复位）；
# 父节点只保留同名薄转发——[code]battle_start[/code] / [code]battle_end[/code] /
# [code]retreat[/code] / [code]confirm_retreat[/code] / [code]resume_auto_advance[/code]
# 是场景容器（[code]combat_scene_battle_setup.gd[/code] /
# [code]combat_scene_resume.gd[/code] / [code]combat_scene_exits.gd[/code]）、
# 子模块回调（[code]combat_battle_wiring.gd[/code]）与大量既有用例按名字调用的入口，
# 名字、签名与内部顺序一律不动。

## 战斗开始——初始化 battle.* 域 + 费用系统 + 备战阶段 + 快照 + 输入锁 + 开始回合。（实现见 combat_battle_lifecycle.gd）[br]
func battle_start(config: Dictionary) -> void:
	_get_lifecycle().battle_start(config)


## 战斗结束——防御清理 + 奖励/损失结算 + 清理 battle 域 + 场景切换。（实现见 combat_battle_lifecycle.gd）[br]
func battle_end(result: int) -> void:
	_get_lifecycle().battle_end(result)


## 撤退——确认后调用 battle_end(RETREAT)。（实现见 combat_battle_lifecycle.gd）[br]
func retreat() -> void:
	_get_lifecycle().retreat()


## 玩家确认撤退——UI 弹窗确认后调用。（实现见 combat_battle_lifecycle.gd）[br]
func confirm_retreat() -> void:
	_get_lifecycle().confirm_retreat()


# === 战斗结束判定（Sprint 18——Phase 6 END 真实现）===============================
# 实现全部在 combat_battle_wiring.gd 子模块（名册快照 / 费用激活 / END 判定 /
# 结局收尾）；父节点只保留薄委托，供 phase_manager 与自身调用。

## 记录本场敌我名册快照——委托子模块（[method battle_start] 调用）。
func _capture_battle_rosters(config: Dictionary) -> void:
	_get_battle_wiring().capture_rosters(config)


## 费用系统激活——[code]CostSystem.init_for_battle(境界费用上限)[/code]。委托子模块。
func _init_cost_for_battle() -> void:
	_get_battle_wiring().init_cost_for_battle()


## 费用系统清理——战斗结束。委托子模块。
func _clear_cost_for_battle() -> void:
	_get_battle_wiring().clear_cost_for_battle()


## Phase 6 END 战斗结束检查——[b]返回 true 表示本场已判定结束[/b]。委托子模块。[br]
func _check_battle_end() -> bool:
	return _get_battle_wiring().check_battle_end()


## 战斗费用上限——RealmSystem 的 [code]cost_per_turn[/code]。委托子模块（测试接缝）。
func _read_cost_cap() -> int:
	return _get_battle_wiring().read_cost_cap()


## 读取 DeploymentSystem 阵位快照。委托子模块。
func _read_player_field() -> Array:
	return _get_battle_wiring().read_player_field()


## 累积「我方阵位曾有人」标志。委托子模块。
func _update_field_engaged(field: Array) -> void:
	_get_battle_wiring().update_field_engaged(field)


## Phase 6 判定的结局收尾——先清标志再 [method battle_end]（防递归）。委托子模块。
func _finish_pending_battle_end() -> void:
	_get_battle_wiring().finish_pending_battle_end()


# === HP 落库 + 阵亡清位（Sprint 18 / DEBT-CBT-018-1）===============================
# 实现全部在 combat_roster_ops.gd 子模块（开战种子 / 取数口 / 结束定格 / 读档落位）；
# 父节点只保留薄委托与两个公开取数口。[br]
# [b]注[/b]：_note_effect_entry 留在这里——它是 [code]combat_on_play_effects.gd[/code] /
# [code]combat_kill_trigger.gd[/code] 按名字回调的父节点接缝（[code]_parent.call[/code]）。

## 定格本场战绩 + 回写我方残血（Sprint 18 结算回流——必须在清表前调用）。委托子模块。（实现见 combat_roster_ops.gd）[br]
func _build_battle_record(result: int) -> Dictionary:
	return _get_roster_ops().build_battle_record(result)


## 标记阵亡角色为不可用——战斗结束时调用（GDD combat-system.md §7）。委托子模块。
func _mark_dead_characters_unavailable(entries: Array) -> void:
	_get_roster_ops().mark_dead_characters_unavailable(entries)


## 警告零 HP 角色——开战种子时调用（GDD combat-system.md §7）。委托子模块。
func _warn_zero_hp_characters(persisted: Dictionary) -> void:
	_get_roster_ops().warn_zero_hp_characters(persisted)


## 结算回流计数——子模块（[code]combat_on_play_effects.gd[/code] /
func _note_effect_entry() -> void:
	_get_battle_record().call(&"note_effect_entry", 1)

## 种子敌我 HP 状态表——我方阵位（模板 base_hp 回退）+ 敌方阵容快照。委托子模块。
func _seed_roster_state(config: Dictionary) -> void:
	_get_roster_ops().seed_roster_state(config)


## 订阅自身 character_died——阵亡清位（幂等连接）。委托子模块。（实现见 combat_roster_ops.gd）[br]
func _connect_death_cleanup() -> void:
	_get_roster_ops().connect_death_cleanup()


## 伤害落库结果读取——战斗 UI 的 hp_reader_cb 契约（[code]{current, max}[/code]）。委托子模块。（实现见 combat_roster_ops.gd）[br]
func get_character_hp(character_id: int) -> Dictionary:
	return _get_roster_ops().get_character_hp(character_id)


## 本场敌方名册快照（只读）。委托子模块。（实现见 combat_roster_ops.gd）[br]
## 看同一份数据——跨回合现读 AISystem 可能已换阵容（下一场 / 测试串场）。
func get_battle_enemy_roster() -> Array:
	return _get_roster_ops().get_battle_enemy_roster()


## 角色是否存活——出牌目标候选池的存活判定入口。委托子模块。（实现见 combat_roster_ops.gd）[br]
func is_character_alive(character_id: int) -> bool:
	return _get_roster_ops().is_character_alive(character_id)


## 本场开战配置副本（只读）。委托子模块。（实现见 combat_roster_ops.gd）[br]
func get_battle_config() -> Dictionary:
	return _get_roster_ops().get_battle_config()


## 按存档值落位本场战况——[b]读档续战专用[/b]（常规开战路径逐字不动）。委托子模块。[br]
## [br][b]为什么要这个方法[/b]：[method battle_start] 恒定从第 1 回合的
## PREPARATION 起手，而存档里的那场仗可能停在任意阶段。读档后若不落位，玩家面对的
## 是「血量和敌人都对、但回合与阶段被重置」的半场仗——费用也一并回满。[br]
## [br][b]只动内部状态与镜像，不推进阶段[/b]：阶段入口的那些副作用（抽牌 / 结算 /
## 自动推进）不能重放——玩家已经经历过一遍了。故这里直接改内部字段 + GSM 镜像，
## 再由调用方（[code]combat_scene_resume.gd[/code]）恢复自动推进。[br]
## [br][param p_turn] 存档里的回合数（≥1）。[br]
## [param p_phase] 存档里的阶段（[enum CombatPhase]；越界夹进合法区间）。[br]
## [param p_current_cost] 存档里的当前可用费用。[br]
## [param p_max_cost] 存档里的费用上限（0 = 未记录——保留 [method battle_start] 已
## 按境界算好的上限，不把费用系统打成 0 费）。[br]
## [br][b]返回[/b]：是否真的落位（未开战时 false——调用方据此报警）。
func restore_battle_state(p_turn: int, p_phase: int, p_current_cost: int,
		p_max_cost: int) -> bool:
	return _get_roster_ops().restore_battle_state(
			p_turn, p_phase, p_current_cost, p_max_cost)


## 恢复自动推进——读档落位完成后由调用方调用（把落位期间压住的调度放出来）。（实现见 combat_battle_lifecycle.gd）[br]
func resume_auto_advance() -> void:
	_get_lifecycle().resume_auto_advance()


## 战斗结果结算——按 VICTORY/DEFEAT/RETREAT 分支。转发 [CombatRewards]。（实现见 combat_rewards.gd）[br]
func _settle_result(result: int) -> Dictionary:
	return _get_rewards().settle_result(result)


## 本场是否已结算过奖励（重复 [method battle_end] 的幂等守卫）——转发 [CombatRewards]。
func _is_rewards_settled() -> bool:
	return _get_rewards().is_rewards_settled()


## 标记本场已结算——转发 [CombatRewards]。
func _mark_rewards_settled() -> void:
	_get_rewards().mark_rewards_settled()


## 持久化已掷骰奖励到 GSM battle 字段——转发 [CombatRewards]。
func _persist_rolled_rewards(p_rolled: Dictionary) -> void:
	_get_rewards().persist_rolled_rewards(p_rolled)


## 从 GSM battle 字段读取已掷骰奖励——转发 [CombatRewards]。
func _load_rolled_rewards() -> Dictionary:
	return _get_rewards().load_rolled_rewards()


## 奖励选择发放——index>=0 发灵石+修为+该张卡，index<0 只发灵石+修为。转发 [CombatRewards]。（实现见 combat_rewards.gd）[br]
func grant_reward_selection(index: int) -> Dictionary:
	return _get_rewards().grant_reward_selection(index)


## 清空 GSM battle 字段中的 rolled_rewards——转发 [CombatRewards]。
func _clear_rolled_rewards_from_gsm() -> void:
	_get_rewards().clear_rolled_rewards_from_gsm()


## 本场奖励掷骰播种——每开一场推进一步（见 [method set_reward_rng_seed]）——转发 [CombatRewards]。
func _seed_reward_rng() -> void:
	_get_rewards().seed_reward_rng()


## 计算灵石奖励——[b]由开战配置的 [code]rewards[/code] 决定[/b]（探索节点掉落）。转发 [CombatRewards]。（实现见 combat_rewards.gd）[br]
func _calculate_lingshi_reward() -> int:
	return _get_rewards().calculate_lingshi_reward()


## 计算修为奖励——同上，读开战配置 [code]rewards.cultivation[/code]——转发 [CombatRewards]。
func _calculate_cultivation_reward() -> int:
	return _get_rewards().calculate_cultivation_reward()


## 计算卡牌掉落配置——读开战配置 [code]rewards.cards[/code]（字典列表深拷贝）。转发 [CombatRewards]。（实现见 combat_rewards.gd）[br]
func _calculate_card_drops() -> Array:
	return _get_rewards().calculate_card_drops()


## 开战配置里的掉落字典（缺失/类型不符时为空——结算侧按 0/空处理）——转发 [CombatRewards]。
func _configured_rewards() -> Dictionary:
	return _get_rewards().configured_rewards()


## 应用胜利奖励——[b]保留为公开测试接缝[/b]（旧测试直调它验证资源写入）。转发 [CombatRewards]。（实现见 combat_rewards.gd）[br]
func _apply_victory_rewards(rewards: Dictionary) -> void:
	_get_rewards().apply_victory_rewards(rewards)


## 创建战斗快照——SaveLoad.create_battle_snapshot(GSM.serialize())（AC-004）。委托副作用件。
func _create_battle_snapshot() -> void:
	_get_side_effects().create_battle_snapshot()


## 清理战斗快照——SaveLoad.clear_battle_snapshot()（AC-014）。委托副作用件。
func _clear_battle_snapshot() -> void:
	_get_side_effects().clear_battle_snapshot()


## 推入 ANIMATION 输入锁（AC-005）。委托副作用件。（实现见 combat_battle_side_effects.gd）[br]
func _push_animation_lock() -> void:
	_get_side_effects().push_animation_lock()


## 清理 CombatSystem 推入的输入锁（AC-011）。委托副作用件。（实现见 combat_battle_side_effects.gd）[br]
func _clear_animation_lock() -> void:
	_get_side_effects().clear_animation_lock()


## 阶段驱动的锁同步——进入阶段 4/5 推锁，其余阶段不持有。委托副作用件。（实现见 combat_battle_side_effects.gd）[br]
func _sync_animation_lock(p_phase: int) -> void:
	_get_side_effects().sync_animation_lock(p_phase)


## 请求场景切换（AC-015）。委托副作用件。
func _request_scene_change(result: int) -> void:
	_get_side_effects().request_scene_change(result)
