
## CombatSystem —— 战斗系统编排器 Autoload（#9）。[b]链尾：信号出口 + 查询面 + 攻击结算[/b]。
##
## Feature 层 Autoload。7 阶段回合状态机 + 阶段转换验证 + 子系统编排调度。[br]
## [b]Autoload 路径不变[/b]：[code]project.godot[/code] 仍指
## [code]res://src/feature/combat_system.gd[/code]——本文件是链尾，注册名与既有测试的
## [code]CS_SCRIPT[/code] 常量逐字不动。[br]
##
## [b]继承链[/b]（各段守 300 行内，成员名与访问路径逐字不变）：[br]
## [code]  combat_system_contract.gd  [/code] ← 定义层：2 枚举 / 9 信号 / 4 常量[br]
## [code]  combat_system_fields.gd    [/code] ← 状态层：45 个实例字段[br]
## [code]  combat_system_access.gd    [/code] ← 查找层：13 Autoload 查找 + 16 惰性子模块 getter + 3 取数口[br]
## [code]  combat_system_lifecycle.gd [/code] ← 生命周期层：开战 / 终战 / 撤退 / 续战复位 + 名册 / 奖励 / 副作用面[br]
## [code]  combat_system_phase_play.gd[/code] ← 阶段与出牌层：阶段推进 + 手动确认 + 抽牌三堆 + 出牌结算[br]
## [code]  combat_system_runtime.gd   [/code] ← 运行时接缝层：Autoload 注入 + 注入 setter + 测试开关[br]
## [code]  combat_system.gd           [/code] ← 本层：信号出口 + GSM 镜像 + 查询 API + 攻击结算[br]
##
## [b]本层职责[/b]：[b]对外可观测面[/b]——[method _emit_safe] 经 GSM
## [code]_emit_signal_safe[/code] 路由的 Cat 2b 信号出口、GSM 第二层镜像
## （[method _gsm_set_battle_phase] / [method _gsm_increment_battle_turn] /
## [method _gsm_set_battle_turn] / [method _gsm_set_battle_active] /
## [method _gsm_set_battle_resume]）、[method get_current_phase] /
## [method get_turn_number] / [method is_battle_active] 三个查询口，以及 Phase 4 的攻击队列结算
## （[method _resolve_attack_queue] → [method _settle_attack_damage]）与
## [method calculate_damage] 减伤公式入口。[br]
##
## [b]为什么信号出口必须住本层[/b]：[method _emit_turn_started] 是回合边界的显式广播，
## 静态调用本层的 [method _emit_safe]——派生段静态调用基类方法合法，反向则是解析期错误。[br]
##
## [b]本 Story 范围[/b]（4-22）：纯状态机推进逻辑 + 验证矩阵 + 自动/手动阶段调度 +
## GSM 第二层镜像。[br]
## [b]后续 story[/b]：battle_start/battle_end 生命周期（4-23）、play_card 出牌（4-24）、
## Cat 2b 信号完整声明与订阅（4-25）。[br]
##
## 来源: ADR-0008 §决策 §7 阶段状态机 §阶段转换验证矩阵 / GDD combat-system.md §1。

extends "res://src/feature/combat/combat_system_runtime.gd"


## 发射 [signal turn_started]——回合边界的显式广播。[br]
## [br][code]is_player_turn[/code] 在 7 阶段模型下恒为 true：敌我共用同一个回合
## 序列（阶段 5 是「本回合里的敌方行动」，不是对方的独立回合）。该字段保留，
## 是为了让消费者不必理解阶段编号——将来若拆出独立的敌方回合，只改这里的取值，
## 信号形状与所有订阅方都不动。
func _emit_turn_started() -> void:
	_emit_safe(&"turn_started", [{
		"turn": _turn,
		"is_player_turn": true,
	}])


# === 攻击结算（AC-005 attack_resolved 信号发射）==================================

## 攻击队列结算——Phase 4 ATTACK_RESOLUTION 入口。[br]
## [br]遍历 _attack_queue，对每条攻击记录调用 calculate_damage 计算伤害，[br]
## 发射 attack_resolved 信号（Cat 2b 具名字典格式——ADR-0007）。[br]
## [br]攻击队列格式：[code]{attacker_id, target_id, attacker_atk, target_def, attacker_realm, defender_realm, target_hp}[/code][br]
## 可选 [code]damage_reduction_pcts[/code]（防御方百分比减伤来源，见下）。[br]
## [br]Sprint 8 Story 005：is_kill 从目标 HP 派生（final_damage >= target_hp）。[br]
## [br]Sprint 18 / DEBT-CBT-018-1：结算结果交 [code]combat_damage_settlement.gd[/code]
## 回写防御方 HP，归零者经 [signal character_died] 驱动阵亡清位。[br]
## [br]DEBT-CBT-018-8 残留：结算前先由 [code]combat_attack_coverage.gd[/code] 把各条目
## 防御方（[code]target_id[/code]）的绑定减伤来源写入 [code]damage_reduction_pcts[/code]
## ——已有显式值的条目不覆盖；取不到来源时不写该键（缺省即无减伤）。
func _resolve_attack_queue() -> void:
	# Sprint 18：结算前采样阵位「曾有人」——阵亡清位发生在结算内
	_update_field_engaged(_read_player_field())
	# DEBT-CBT-018-8 残留：Attack 阶段把防御方绑定减伤写入队列条目（显式值不覆盖）
	_get_attack_coverage().call(&"annotate_queue", _attack_queue)
	# Sprint 18 / DEBT-CBT-018-1：结算后逐条落库 HP（combat_damage_settlement.gd），
	# 归零者发射 character_died → 战斗侧清位 → Phase 6 END 判负
	var settled: Array = _get_damage_calculator().resolve_attack_queue()
	_settle_attack_damage(settled)


## 攻击结算落库——逐条把伤害写回防御方状态（委托子模块）。
func _settle_attack_damage(settled: Array) -> void:
	for pair: Variant in settled:
		if pair is Dictionary:
			_get_damage_settlement().settle_attack(pair["entry"], pair["payload"])


# === 伤害计算（AC-008~012）=======================================================

## 计算最终伤害——委托给 _damage_calculator 子模块。[br]
## [br][param attacker_atk] 攻击者攻击力。[br]
## [br][param target_def] 目标防御力。[br]
## [br][param attacker_realm] 攻击者境界等级。[br]
## [br][param defender_realm] 防御者境界等级。[br]
## [br][param damage_reduction_pcts] 防御方百分比减伤列表（DEBT-CBT-018-8，缺省无减伤）。[br]
## [br][b]返回[/b]: [code]{actual_damage, realm_penalty, final_damage, damage_reduction_multiplier}[/code] Dictionary。
func calculate_damage(attacker_atk: int, target_def: int, attacker_realm: int, defender_realm: int,
		damage_reduction_pcts: Array = []) -> Dictionary:
	return _get_damage_calculator().calculate_damage(
		attacker_atk, target_def, attacker_realm, defender_realm, damage_reduction_pcts)


## 获取境界压制系数——委托给 _damage_calculator 子模块。
func _get_realm_penalty(attacker_realm: int, defender_realm: int) -> float:
	return _get_damage_calculator()._get_realm_penalty(attacker_realm, defender_realm)


# === 查询 API ===================================================================

## 返回当前阶段。
func get_current_phase() -> int:
	return _phase


## 返回当前回合数。
func get_turn_number() -> int:
	return _turn


## 返回战斗活跃状态。
func is_battle_active() -> bool:
	return _is_active


# === GSM 第二层镜像 + Cat 2b 信号路由 =============================================
# 四个 [_gsm_set_battle_*] / [_gsm_increment_battle_turn] 镜像口与
# [code]_sync_animation_lock[/code] 同属副作用面，实现在 combat_battle_side_effects.gd；
# 父节点保留原名是因为 [code]combat_roster_ops.gd[/code] 等处按名字回调它们。

## 通过 GSM 第二层方法镜像 phase 变更。委托副作用件。
func _gsm_set_battle_phase(phase: int) -> void:
	_get_side_effects().gsm_set_battle_phase(phase)


## 通过 GSM 第二层方法递增回合数。委托副作用件。
func _gsm_increment_battle_turn() -> void:
	_get_side_effects().gsm_increment_battle_turn()


## 通过 GSM 第二层方法落位回合数——读档续战专用。委托副作用件。（实现见 combat_battle_side_effects.gd）[br]
func _gsm_set_battle_turn(turn: int) -> void:
	_get_side_effects().gsm_set_battle_turn(turn)


## 通过 GSM 第二层方法设置战斗活跃状态。委托副作用件。
func _gsm_set_battle_active(active: bool) -> void:
	_get_side_effects().gsm_set_battle_active(active)


## 通过 GSM 第二层方法写入 / 清空「进行中战斗」的存档快照。委托副作用件。（实现见 combat_battle_side_effects.gd）[br]
func _gsm_set_battle_resume(resume: Dictionary) -> void:
	_get_side_effects().gsm_set_battle_resume(resume)


## Cat 2b 信号安全发射——经 GSM._emit_signal_safe 路由（ADR-0007 信号链深度追踪）。[br]
## [br][b]动态查找 GSM[/b]——而非直接引用 GameStateManager 全局名，[br]
## 避免测试环境无 Autoload 时 NameError（CombatSystem 测试用 CS_SCRIPT.new() 构造，[br]
## 无 Autoload 注册）。BindingManager 先例用直接引用是因为它本身是 Autoload。[br]
## [br][b]GSM 不可用时回退[/b]到直接 emit_signal + push_warning 告警——[br]
## 生产环境若 GSM 意外缺失会降级但不静默。[br]
## [br]来源: ADR-0008 §信号分类 / ADR-0007 §_emit_signal_safe。
func _emit_safe(signal_name: StringName, args: Array) -> void:
	var gsm = _get_gsm()
	if gsm != null and gsm.has_method("_emit_signal_safe"):
		gsm._emit_signal_safe(self, signal_name, args)
		return
	push_warning("CombatSystem: GSM 不可用，%s 信号绕过 _emit_signal_safe 路由" % signal_name)
	var call_args: Array = [signal_name]
	call_args.append_array(args)
	callv("emit_signal", call_args)
