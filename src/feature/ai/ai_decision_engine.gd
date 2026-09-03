extends RefCounted
## AIDecisionEngine —— AI 决策引擎子模块（从 ai_system.gd 拆分）。
##
## 持有对 AISystem 父节点的引用，通过它访问 _rng / _emit_safe / 辅助方法。[br]
## [br]来源: ADR-0017 §决策 §决策引擎设计 ① / GDD ai-system.md §4/§公式。[br]
## [br]Sprint 8 Story 8-12：从 ai_system.gd 拆分。

const _SkillEntry = preload("res://assets/enemies/skill_entry.gd")

## 父节点引用——AISystem Autoload 实例。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


## Phase 6 入口——CombatSystem 在敌方行动阶段调用（AC-001）。[br]
## 对每个存活敌方角色执行决策，返回行动指令列表。[br]
## [br][param field_state] 战场状态快照——{player_chars: Array, enemy_chars: Array, turn: int}。[br]
## [br][b]返回[/b]: Array——元素为 AIAction Dictionary。[br]
## [br]来源: ADR-0017 §关键接口 execute_turn / GDD ai-system.md §4。
func execute_turn(field_state: Dictionary) -> Array:
	_parent.set("_current_turn", int(field_state.get("turn", 0)))
	var actions: Array = []
	var retreated_ids: Array = []
	for enemy in _parent.get("_enemy_roster"):
		if not _parent.call("_is_alive", enemy):
			continue
		# AC-012：撤退判定（非 Boss）
		if _check_retreat(enemy, field_state):
			retreated_ids.append(enemy)
			actions.append({"enemy_id": enemy, "skill_id": &"", "target_ids": [], "is_retreat": true})
			continue
		var action: Dictionary = _decide_action(enemy, field_state)
		actions.append(action)
	if not retreated_ids.is_empty():
		_parent.call("_emit_safe", &"enemy_retreated", [retreated_ids])
	return actions


## 三级智能分支分派（AC-002）。[br]
## Boss 优先 → 精英 → 普通。
func _decide_action(enemy, field_state: Dictionary) -> Dictionary:
	var template = enemy.template
	if template.is_boss:
		return _decide_boss_action(enemy, field_state)
	elif template.is_elite:
		return _decide_elite_action(enemy, field_state)
	else:
		return _decide_normal_action(enemy, field_state)


## 普通敌人决策——仅技能评估 + 目标选择（AC-002）。
func _decide_normal_action(enemy, field_state: Dictionary) -> Dictionary:
	var skill_result = _evaluate_skills(enemy, field_state)
	var target_ids = _select_target(enemy, skill_result, field_state)
	return {"enemy_id": enemy, "skill_id": skill_result.skill_id, "target_ids": target_ids, "is_retreat": false}


## 精英敌人决策——阵法部署检查 + 技能评估 + 目标选择（AC-002）。[br]
## _check_formation_deploy 钩子——Story 003/004 集成点，本 Story 为空桩。[br]
## 空桩确保分支结构完整，后续 Story 仅需填充钩子实现。
func _decide_elite_action(enemy, field_state: Dictionary) -> Dictionary:
	_parent.call("_check_formation_deploy", enemy, field_state)
	var skill_result = _evaluate_skills(enemy, field_state)
	var target_ids = _select_target(enemy, skill_result, field_state)
	return {"enemy_id": enemy, "skill_id": skill_result.skill_id, "target_ids": target_ids, "is_retreat": false}


## Boss 决策——阶段转换检查 + 阵法部署 + 技能评估 + 目标选择（AC-002）。[br]
## _check_phase_transition 实现——Story 003，检测 + 执行阶段转换。[br]
## 转换触发时该 Boss 本回合不产出技能行动（AC-012）。
func _decide_boss_action(enemy, field_state: Dictionary) -> Dictionary:
	var transitioned: bool = _parent.call("_check_phase_transition", enemy, field_state)
	if transitioned:
		# AC-012：阶段转换回合不进行其他行动
		return {"enemy_id": enemy, "skill_id": &"", "target_ids": [], "is_retreat": false}
	_parent.call("_check_formation_deploy", enemy, field_state)
	var skill_result = _evaluate_skills(enemy, field_state)
	var target_ids = _select_target(enemy, skill_result, field_state)
	return {"enemy_id": enemy, "skill_id": skill_result.skill_id, "target_ids": target_ids, "is_retreat": false}


## 技能评估——加权分数 + 修正系数 → 选 top 1~2 技能（AC-003~005/009/010）。[br]
## [br][b]返回[/b]: Dictionary——{skill_id: StringName, cost: int, target_type: int, skill_type: int}。[br]
## 全技能冷却/费用不足 → basic_attack 兜底。
func _evaluate_skills(enemy, field_state: Dictionary) -> Dictionary:
	var template = enemy.template
	# 优先使用实例级 runtime_skill_pool（Boss 阶段转换后修改），回退到模板
	var skill_pool: Array = enemy.runtime_skill_pool if not (enemy.runtime_skill_pool as Array).is_empty() else (template.skill_pool as Array)
	var available_budget: int = int(field_state.get("enemy_cost_budget", 3))
	var scored: Array = []
	for skill in skill_pool:
		# AC-009：冷却中 → 跳过
		if _parent.call("_is_on_cooldown", enemy, skill):
			continue
		# AC-010：费用不足 → 跳过
		if skill.cost > available_budget:
			continue
		var score: float = _calculate_skill_score(enemy, skill, field_state)
		scored.append({"skill": skill, "score": score})
	# AC-009/010：无可用技能 → basic_attack 兜底
	if scored.is_empty():
		return {"skill_id": &"basic_attack", "cost": 0, "target_type": _SkillEntry.TargetType.SINGLE_ENEMY, "skill_type": _SkillEntry.SkillType.ATTACK}
	# 按分数降序排序
	scored.sort_custom(_compare_by_score_desc)
	var best = scored[0]
	return {"skill_id": best.skill.skill_id, "cost": best.skill.cost, "target_type": best.skill.target_type, "skill_type": best.skill.skill_type}


## 计算技能分数——base_weight × modifier（AC-003/004）。
func _calculate_skill_score(enemy, skill, field_state: Dictionary) -> float:
	var base_weight: float = float(skill.base_weight)
	var modifier: float = _calculate_modifier(enemy, skill, field_state)
	var score: float = base_weight * modifier
	# 阵法部署为加法修正（+20 若阵法位空）
	if skill.skill_type == _SkillEntry.SkillType.FORMATION:
		var formation_slots_available: int = int(field_state.get("enemy_formation_slots_available", 0))
		if formation_slots_available > 0:
			score += 20.0
	return score


## 修正系数——治疗(+0.5 若友方残血) + 防御(+0.3 若前排阵亡) + 攻击(+0.4 若高威胁)（AC-004）。
func _calculate_modifier(enemy, skill, field_state: Dictionary) -> float:
	var modifier: float = 1.0
	var ally_low_hp_count: int = int(field_state.get("ally_low_hp_count", 0))
	var ally_front_dead: bool = bool(field_state.get("ally_front_dead", false))
	var player_high_threat: bool = bool(field_state.get("player_high_threat", false))
	# 治疗技能 + 残血友方 → +0.5
	if skill.skill_type == _SkillEntry.SkillType.HEAL and ally_low_hp_count > 0:
		modifier += 0.5
	# 防御技能 + 前排阵亡 → +0.3
	if skill.skill_type == _SkillEntry.SkillType.DEFENSE and ally_front_dead:
		modifier += 0.3
	# 攻击技能 + 高威胁 → +0.4
	if skill.skill_type == _SkillEntry.SkillType.ATTACK and player_high_threat:
		modifier += 0.4
	return modifier


## 目标选择——集火/分散/嘲讽 + 多目标类型（AC-006~008）。[br]
## 根据 skill_result.target_type 决定目标数量。[br]
## - SELF → 返回空（由 CombatSystem 处理自身）[br]
## - ALL_ENEMY / ALL_ALLIES → 返回全部可用目标[br]
## - SINGLE_ENEMY / ALLY → 走集火/分散/嘲讽逻辑[br]
## [br][b]嘲讽限制仅对攻击类技能生效[/b]（skill_type==ATTACK）——
## 非攻击类（UTILITY/HEAL/DEFENSE/FORMATION）可绕过嘲讽（AC-008 边缘情况）。
func _select_target(enemy, skill_result: Dictionary, field_state: Dictionary) -> Array:
	var target_type: int = int(skill_result.get("target_type", _SkillEntry.TargetType.SINGLE_ENEMY))
	# SELF → 空目标列表（CombatSystem 处理）
	if target_type == _SkillEntry.TargetType.SELF:
		return []
	var player_chars: Array = field_state.get("player_chars", [])
	var available_targets: Array = []
	for char_state in player_chars:
		if _parent.call("_is_alive", char_state):
			available_targets.append(char_state)
	# ALL_ENEMY → 全部可用目标
	if target_type == _SkillEntry.TargetType.ALL_ENEMY:
		return available_targets
	# ALL_ALLIES → 友方目标（field_state.enemy_chars 中存活者）
	if target_type == _SkillEntry.TargetType.ALL_ALLIES:
		var enemy_chars: Array = field_state.get("enemy_chars", [])
		var allies: Array = []
		for ally in enemy_chars:
			if _parent.call("_is_alive", ally):
				allies.append(ally)
		return allies
	if available_targets.is_empty():
		return []
	# AC-008：嘲讽强制目标（仅攻击类技能受嘲讽限制——非攻击可绕过）
	var skill_type: int = int(skill_result.get("skill_type", _SkillEntry.SkillType.ATTACK))
	if skill_type == _SkillEntry.SkillType.ATTACK:
		var taunting = _parent.call("_find_taunting", available_targets)
		if taunting != null:
			return [taunting]
	# AC-006：集火模式（focus_fire>0.5）→ HP% 最低
	var behavior = _parent.call("_get_behavior_profile", enemy)
	if behavior != null and behavior.focus_fire > 0.5:
		var target = _select_focus_fire_target(available_targets)
		return [target]
	# AC-007：分散模式 → 加权随机
	var target = _select_spread_target(available_targets)
	return [target]


## 集火模式——选择 HP% 最低的目标；同 HP% → 防御最低（AC-006）。
func _select_focus_fire_target(targets: Array) -> Variant:
	var best = null
	var best_hp_pct: float = 2.0  # 超出范围确保首次赋值
	for target in targets:
		var hp_pct: float = _parent.call("_get_hp_pct", target)
		if hp_pct < best_hp_pct or (hp_pct == best_hp_pct and best != null and target.defense < best.defense):
			best = target
			best_hp_pct = hp_pct
	return best


## 分散模式——加权随机，残血角色权重 ×2（AC-007）。
func _select_spread_target(targets: Array) -> Variant:
	var rng: RandomNumberGenerator = _parent.get("_rng")
	var weights: Array = []
	var total_weight: float = 0.0
	for target in targets:
		var w: float = 1.0
		if _parent.call("_get_hp_pct", target) < 0.3:
			w = 2.0
		weights.append(w)
		total_weight += w
	var roll: float = rng.randf() * total_weight
	var cumulative: float = 0.0
	for i in range(targets.size()):
		cumulative += weights[i]
		if roll <= cumulative:
			return targets[i]
	return targets[targets.size() - 1]


## 撤退判定——非 Boss + ally_hp_ratio < retreat_threshold → 50% 概率（AC-012）。
func _check_retreat(enemy, field_state: Dictionary) -> bool:
	var template = enemy.template
	if template.is_boss:
		return false
	var behavior = _parent.call("_get_behavior_profile", enemy)
	if behavior == null or behavior.retreat_threshold <= 0.0:
		return false
	var ally_hp_ratio: float = float(field_state.get("ally_hp_ratio", 1.0))
	if ally_hp_ratio >= behavior.retreat_threshold:
		return false
	var rng: RandomNumberGenerator = _parent.get("_rng")
	return rng.randf() < 0.5


## 分数降序比较器。
func _compare_by_score_desc(a, b) -> bool:
	return a.score > b.score
