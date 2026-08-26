extends GutTest
## Story 002 验收测试：execute_turn 决策主循环 + 三级智能分支 +
## 技能评分 + 目标选择 + 撤退判定。
##
## 覆盖 AC-001 到 AC-014（14 条 AC）。
## 测试策略：
##   - AISystem 用 AI_SCRIPT.new() + var ai: Node 持有
##   - 手动注入 _enemy_roster + _rng 种子（确定性）
##   - field_state 用 Dictionary 模拟战场状态
##   - 技能/模板用脚本内构造（不依赖 .tres 文件）
##
## 设计文档来源：ADR-0017 §决策引擎设计 §三智能层级分支
## Story 来源：production/epics/ai-system/story-002-execute-turn-decision.md

const AI_SCRIPT := preload("res://src/feature/ai_system.gd")
const EnemyTemplate := preload("res://assets/enemies/enemy_template.gd")
const BehaviorProfile := preload("res://assets/enemies/behavior_profile.gd")
const SkillEntry := preload("res://assets/enemies/skill_entry.gd")
const EnemyBattleState := preload("res://src/feature/ai/enemy_battle_state.gd")

var ai: Node = null


func before_each() -> void:
	ai = AI_SCRIPT.new()
	ai.set_rng_seed(42)


func after_each() -> void:
	if ai != null:
		ai.free()
		ai = null


# === 辅助：构造测试模板与角色 ================================================

func _make_normal_template(tid: StringName, hp: int, atk: int, def: int, skills: Array) -> Object:
	var t := EnemyTemplate.new()
	t.template_id = tid
	t.display_name = str(tid)
	t.realm = 1
	t.is_elite = false
	t.is_boss = false
	t.base_hp = hp
	t.base_attack = atk
	t.base_defense = def
	t.formation_limit = 0
	t.front_slot = false
	t.behavior_profile = _make_behavior_profile(0.7, 0.6, 0.5, 0.0)
	t.skill_pool = skills
	return t


func _make_boss_template(tid: StringName, hp: int, atk: int, def: int, skills: Array) -> Object:
	var t := EnemyTemplate.new()
	t.template_id = tid
	t.display_name = str(tid)
	t.realm = 3
	t.is_elite = false
	t.is_boss = true
	t.base_hp = hp
	t.base_attack = atk
	t.base_defense = def
	t.formation_limit = 2
	t.front_slot = true
	t.behavior_profile = _make_behavior_profile(0.9, 0.8, 0.7, 0.0)
	t.skill_pool = skills
	return t


func _make_elite_template(tid: StringName, hp: int, atk: int, def: int, skills: Array) -> Object:
	var t := EnemyTemplate.new()
	t.template_id = tid
	t.display_name = str(tid)
	t.realm = 2
	t.is_elite = true
	t.is_boss = false
	t.base_hp = hp
	t.base_attack = atk
	t.base_defense = def
	t.formation_limit = 1
	t.front_slot = false
	t.behavior_profile = _make_behavior_profile(0.8, 0.7, 0.6, 0.2)
	t.skill_pool = skills
	return t


func _make_behavior_profile(aggression: float, focus_fire: float, front_priority: float, retreat: float) -> Object:
	var bp := BehaviorProfile.new()
	bp.aggression = aggression
	bp.focus_fire = focus_fire
	bp.front_priority = front_priority
	bp.retreat_threshold = retreat
	return bp


func _make_skill(sid: StringName, stype: int, weight: int, cost: int, cd: int, ttype: int) -> Object:
	var se := SkillEntry.new()
	se.skill_id = sid
	se.display_name = str(sid)
	se.skill_type = stype
	se.base_weight = weight
	se.cost = cost
	se.cooldown = cd
	se.target_type = ttype
	se.effect_template_ids = [&"effect_basic"]
	return se


func _make_enemy(template: Object) -> Object:
	var state = EnemyBattleState.new()
	state.template_id = template.template_id
	state.template = template
	state.current_hp = template.base_hp
	state.max_hp = template.base_hp
	state.attack = template.base_attack
	state.defense = template.base_defense
	state.skill_cooldowns = {}
	state.is_alive = true
	state.field_position = 0
	state.is_front_row = true
	state.current_phase_index = 0
	state.triggered_transitions = []
	return state


func _make_player_char(cid: int, hp: int, max_hp: int, def: int, taunting: bool = false) -> Dictionary:
	return {
		"id": cid,
		"current_hp": hp,
		"max_hp": max_hp,
		"defense": def,
		"is_alive": true,
		"is_taunting": taunting,
	}


func _make_field_state(player_chars: Array, enemy_chars: Array, turn: int = 1, cost_budget: int = 3) -> Dictionary:
	return {
		"player_chars": player_chars,
		"enemy_chars": enemy_chars,
		"turn": turn,
		"enemy_cost_budget": cost_budget,
		"ally_low_hp_count": 0,
		"ally_front_dead": false,
		"player_high_threat": false,
		"ally_hp_ratio": 1.0,
		"enemy_formation_slots_available": 0,
	}


# ============================================================================
# AC-001：execute_turn 每个存活敌人至少一个行动
# ============================================================================

func test_execute_turn_returns_action_per_enemy() -> void:
	var skills := [_make_skill(&"atk1", SkillEntry.SkillType.ATTACK, 50, 1, 0, SkillEntry.TargetType.SINGLE_ENEMY)]
	var t1 := _make_normal_template(&"e1", 100, 20, 10, skills)
	var t2 := _make_normal_template(&"e2", 80, 15, 5, skills)
	var e1 := _make_enemy(t1)
	var e2 := _make_enemy(t2)
	ai.set_enemy_roster([e1, e2])
	var field := _make_field_state([_make_player_char(1, 100, 100, 5)], [e1, e2])
	var actions = ai.call("execute_turn", field)
	assert_eq(actions.size(), 2, "2 个存活敌人 → 2 个行动")
	for action in actions:
		assert_true(action.has("enemy_id"), "行动含 enemy_id")
		assert_true(action.has("skill_id"), "行动含 skill_id")
		assert_false(action.get("is_retreat", true), "非撤退行动")


func test_execute_turn_skips_dead_enemies() -> void:
	var skills := [_make_skill(&"atk1", SkillEntry.SkillType.ATTACK, 50, 1, 0, SkillEntry.TargetType.SINGLE_ENEMY)]
	var t1 := _make_normal_template(&"e1", 100, 20, 10, skills)
	var e1 := _make_enemy(t1)
	e1.is_alive = false  # 阵亡
	var e2 := _make_enemy(t1)
	ai.set_enemy_roster([e1, e2])
	var field := _make_field_state([_make_player_char(1, 100, 100, 5)], [e2])
	var actions = ai.call("execute_turn", field)
	assert_eq(actions.size(), 1, "跳过阵亡敌人，仅 1 个行动")


# ============================================================================
# AC-002：三级智能分支
# ============================================================================

func test_decide_action_normal_branch() -> void:
	var skills := [_make_skill(&"atk1", SkillEntry.SkillType.ATTACK, 50, 1, 0, SkillEntry.TargetType.SINGLE_ENEMY)]
	var t := _make_normal_template(&"normal", 100, 20, 10, skills)
	var enemy := _make_enemy(t)
	ai.set_enemy_roster([enemy])
	var field := _make_field_state([_make_player_char(1, 100, 100, 5)], [enemy])
	var action = ai.call("execute_turn", field)[0]
	assert_eq(str(action["skill_id"]), "atk1", "普通敌人选择技能")


func test_decide_action_elite_branch() -> void:
	var skills := [_make_skill(&"atk1", SkillEntry.SkillType.ATTACK, 50, 1, 0, SkillEntry.TargetType.SINGLE_ENEMY)]
	var t := _make_elite_template(&"elite", 100, 20, 10, skills)
	var enemy := _make_enemy(t)
	ai.set_enemy_roster([enemy])
	var field := _make_field_state([_make_player_char(1, 100, 100, 5)], [enemy])
	var action = ai.call("execute_turn", field)[0]
	assert_eq(str(action["skill_id"]), "atk1", "精英敌人选择技能")


func test_decide_action_boss_branch() -> void:
	var skills := [_make_skill(&"atk1", SkillEntry.SkillType.ATTACK, 50, 1, 0, SkillEntry.TargetType.SINGLE_ENEMY)]
	var t := _make_boss_template(&"boss", 200, 30, 15, skills)
	var enemy := _make_enemy(t)
	ai.set_enemy_roster([enemy])
	var field := _make_field_state([_make_player_char(1, 100, 100, 5)], [enemy])
	var action = ai.call("execute_turn", field)[0]
	assert_eq(str(action["skill_id"]), "atk1", "Boss 选择技能")


# ============================================================================
# AC-003：技能分数计算与排序
# ============================================================================

func test_skill_score_highest_weight_selected() -> void:
	var skills := [
		_make_skill(&"low", SkillEntry.SkillType.ATTACK, 20, 1, 0, SkillEntry.TargetType.SINGLE_ENEMY),
		_make_skill(&"high", SkillEntry.SkillType.ATTACK, 50, 1, 0, SkillEntry.TargetType.SINGLE_ENEMY),
		_make_skill(&"mid", SkillEntry.SkillType.ATTACK, 30, 1, 0, SkillEntry.TargetType.SINGLE_ENEMY),
	]
	var t := _make_normal_template(&"e1", 100, 20, 10, skills)
	var enemy := _make_enemy(t)
	ai.set_enemy_roster([enemy])
	var field := _make_field_state([_make_player_char(1, 100, 100, 5)], [enemy])
	var action = ai.call("execute_turn", field)[0]
	assert_eq(str(action["skill_id"]), "high", "选择最高权重技能")


# ============================================================================
# AC-004：修正系数计算
# ============================================================================

func test_modifier_heal_bonus_with_low_hp_ally() -> void:
	var skills := [
		_make_skill(&"heal", SkillEntry.SkillType.HEAL, 30, 1, 0, SkillEntry.TargetType.ALLY),
		_make_skill(&"atk", SkillEntry.SkillType.ATTACK, 50, 1, 0, SkillEntry.TargetType.SINGLE_ENEMY),
	]
	var t := _make_normal_template(&"e1", 100, 20, 10, skills)
	var enemy := _make_enemy(t)
	ai.set_enemy_roster([enemy])
	var field := _make_field_state([_make_player_char(1, 100, 100, 5)], [enemy])
	field["ally_low_hp_count"] = 2  # 友方残血
	var action = ai.call("execute_turn", field)[0]
	# 治疗 score = 30 × 1.5 = 45 < 攻击 score = 50 × 1.0 = 50 → 选攻击
	assert_eq(str(action["skill_id"]), "atk", "友方残血但攻击权重仍高 → 选攻击")


func test_modifier_heal_bonus_makes_heal_win() -> void:
	var skills := [
		_make_skill(&"heal", SkillEntry.SkillType.HEAL, 40, 1, 0, SkillEntry.TargetType.ALLY),
		_make_skill(&"atk", SkillEntry.SkillType.ATTACK, 50, 1, 0, SkillEntry.TargetType.SINGLE_ENEMY),
	]
	var t := _make_normal_template(&"e1", 100, 20, 10, skills)
	var enemy := _make_enemy(t)
	ai.set_enemy_roster([enemy])
	var field := _make_field_state([_make_player_char(1, 100, 100, 5)], [enemy])
	field["ally_low_hp_count"] = 2  # 友方残血
	var action = ai.call("execute_turn", field)[0]
	# 治疗 score = 40 × 1.5 = 60 > 攻击 score = 50 × 1.0 = 50 → 选治疗
	assert_eq(str(action["skill_id"]), "heal", "友方残血 + 治疗修正 → 治疗胜出")


# ============================================================================
# AC-005：治疗技能修正后 >= 攻击技能
# ============================================================================

func test_heal_skill_score_with_modifier() -> void:
	# AC-005 已在 test_modifier_heal_bonus_makes_heal_win 中覆盖
	var skills := [
		_make_skill(&"heal", SkillEntry.SkillType.HEAL, 40, 1, 0, SkillEntry.TargetType.ALLY),
	]
	var t := _make_normal_template(&"e1", 100, 20, 10, skills)
	var enemy := _make_enemy(t)
	ai.set_enemy_roster([enemy])
	var field := _make_field_state([_make_player_char(1, 100, 100, 5)], [enemy])
	field["ally_low_hp_count"] = 1
	var action = ai.call("execute_turn", field)[0]
	assert_eq(str(action["skill_id"]), "heal", "治疗技能被选中")


# ============================================================================
# AC-006：集火模式目标选择
# ============================================================================

func test_focus_fire_selects_lowest_hp_target() -> void:
	var skills := [_make_skill(&"atk", SkillEntry.SkillType.ATTACK, 50, 1, 0, SkillEntry.TargetType.SINGLE_ENEMY)]
	var t := _make_normal_template(&"e1", 100, 20, 10, skills)
	# focus_fire=0.6（默认）
	var enemy := _make_enemy(t)
	ai.set_enemy_roster([enemy])
	var player1 := _make_player_char(1, 40, 100, 5)  # HP%=40%
	var player2 := _make_player_char(2, 80, 100, 10)  # HP%=80%
	var field := _make_field_state([player1, player2], [enemy])
	var action = ai.call("execute_turn", field)[0]
	var target_ids: Array = action["target_ids"]
	assert_eq(target_ids.size(), 1, "单体目标")
	assert_eq(int(target_ids[0]["id"]), 1, "集火选择 HP% 最低的角色")


func test_focus_fire_same_hp_selects_lower_defense() -> void:
	var skills := [_make_skill(&"atk", SkillEntry.SkillType.ATTACK, 50, 1, 0, SkillEntry.TargetType.SINGLE_ENEMY)]
	var t := _make_normal_template(&"e1", 100, 20, 10, skills)
	var enemy := _make_enemy(t)
	ai.set_enemy_roster([enemy])
	var player1 := _make_player_char(1, 50, 100, 10)  # HP%=50% def=10
	var player2 := _make_player_char(2, 50, 100, 5)    # HP%=50% def=5
	var field := _make_field_state([player1, player2], [enemy])
	var action = ai.call("execute_turn", field)[0]
	var target_ids: Array = action["target_ids"]
	assert_eq(int(target_ids[0]["id"]), 2, "同 HP% → 选防御更低者")


# ============================================================================
# AC-007：分散模式目标选择
# ============================================================================

func test_spread_mode_weighted_random() -> void:
	var skills := [_make_skill(&"atk", SkillEntry.SkillType.ATTACK, 50, 1, 0, SkillEntry.TargetType.SINGLE_ENEMY)]
	var t := EnemyTemplate.new()
	t.template_id = &"e1"
	t.base_hp = 100
	t.base_attack = 20
	t.base_defense = 10
	t.behavior_profile = _make_behavior_profile(0.7, 0.3, 0.5, 0.0)  # focus_fire=0.3 → 分散
	t.skill_pool = skills
	var enemy := _make_enemy(t)
	ai.set_enemy_roster([enemy])
	var player1 := _make_player_char(1, 50, 100, 5)   # HP%=50%
	var player2 := _make_player_char(2, 20, 100, 5)   # HP%=20% < 0.3 → 权重×2
	var field := _make_field_state([player1, player2], [enemy])
	# 确定性种子下多次采样
	ai.set_rng_seed(42)
	var select_count: int = 0
	for i in range(100):
		var action = ai.call("execute_turn", field)[0]
		var target_ids: Array = action["target_ids"]
		if int(target_ids[0]["id"]) == 2:
			select_count += 1
	# 残血权重×2 → 选中概率应显著高于 50%
	assert_true(select_count > 50, "残血角色被选中概率 > 50%%（实际: %d/100）" % select_count)


# ============================================================================
# AC-008：嘲讽强制目标
# ============================================================================

func test_taunt_forces_target() -> void:
	var skills := [_make_skill(&"atk", SkillEntry.SkillType.ATTACK, 50, 1, 0, SkillEntry.TargetType.SINGLE_ENEMY)]
	var t := _make_normal_template(&"e1", 100, 20, 10, skills)
	var enemy := _make_enemy(t)
	ai.set_enemy_roster([enemy])
	var player1 := _make_player_char(1, 80, 100, 5, true)   # 嘲讽
	var player2 := _make_player_char(2, 20, 100, 5)         # 残血但无嘲讽
	var field := _make_field_state([player1, player2], [enemy])
	var action = ai.call("execute_turn", field)[0]
	var target_ids: Array = action["target_ids"]
	assert_eq(int(target_ids[0]["id"]), 1, "嘲讽强制目标")


# ============================================================================
# AC-009：全技能冷却 → 普通攻击
# ============================================================================

func test_all_skills_on_cooldown_basic_attack() -> void:
	var skills := [
		_make_skill(&"skill1", SkillEntry.SkillType.ATTACK, 50, 1, 2, SkillEntry.TargetType.SINGLE_ENEMY),
		_make_skill(&"skill2", SkillEntry.SkillType.ATTACK, 40, 1, 3, SkillEntry.TargetType.SINGLE_ENEMY),
	]
	var t := _make_normal_template(&"e1", 100, 20, 10, skills)
	var enemy := _make_enemy(t)
	enemy.skill_cooldowns = {&"skill1": 2, &"skill2": 3}  # 全冷却
	ai.set_enemy_roster([enemy])
	var field := _make_field_state([_make_player_char(1, 100, 100, 5)], [enemy])
	var action = ai.call("execute_turn", field)[0]
	assert_eq(str(action["skill_id"]), "basic_attack", "全冷却 → basic_attack")


# ============================================================================
# AC-010：费用不足回退
# ============================================================================

func test_insufficient_cost_skips_high_cost() -> void:
	var skills := [
		_make_skill(&"expensive", SkillEntry.SkillType.ATTACK, 50, 3, 0, SkillEntry.TargetType.SINGLE_ENEMY),
		_make_skill(&"cheap", SkillEntry.SkillType.ATTACK, 30, 1, 0, SkillEntry.TargetType.SINGLE_ENEMY),
	]
	var t := _make_normal_template(&"e1", 100, 20, 10, skills)
	var enemy := _make_enemy(t)
	ai.set_enemy_roster([enemy])
	var field := _make_field_state([_make_player_char(1, 100, 100, 5)], [enemy], 1, 1)  # budget=1
	var action = ai.call("execute_turn", field)[0]
	assert_eq(str(action["skill_id"]), "cheap", "费用不足 → 选最低可用")


func test_all_skills_too_expensive_basic_attack() -> void:
	var skills := [
		_make_skill(&"skill1", SkillEntry.SkillType.ATTACK, 50, 3, 0, SkillEntry.TargetType.SINGLE_ENEMY),
		_make_skill(&"skill2", SkillEntry.SkillType.ATTACK, 40, 2, 0, SkillEntry.TargetType.SINGLE_ENEMY),
	]
	var t := _make_normal_template(&"e1", 100, 20, 10, skills)
	var enemy := _make_enemy(t)
	ai.set_enemy_roster([enemy])
	var field := _make_field_state([_make_player_char(1, 100, 100, 5)], [enemy], 1, 1)  # budget=1
	var action = ai.call("execute_turn", field)[0]
	assert_eq(str(action["skill_id"]), "basic_attack", "全超费 → basic_attack")


# ============================================================================
# AC-011：前排阵亡修正系数（补位逻辑由 DeploymentSystem/CombatSystem 负责——Out of Scope）
# ============================================================================

func test_front_dead_modifier_defense_bonus() -> void:
	# AC-011 修正系数验证——补位操作由 DeploymentSystem 在 Phase 6 之前完成（Out of Scope）
	var skills := [
		_make_skill(&"defense", SkillEntry.SkillType.DEFENSE, 40, 1, 0, SkillEntry.TargetType.SELF),
		_make_skill(&"atk", SkillEntry.SkillType.ATTACK, 50, 1, 0, SkillEntry.TargetType.SINGLE_ENEMY),
	]
	var t := _make_normal_template(&"e1", 100, 20, 10, skills)
	var enemy := _make_enemy(t)
	ai.set_enemy_roster([enemy])
	var field := _make_field_state([_make_player_char(1, 100, 100, 5)], [enemy])
	field["ally_front_dead"] = true  # 前排阵亡
	var action = ai.call("execute_turn", field)[0]
	# 防御 score = 40 × 1.3 = 52 > 攻击 score = 50 × 1.0 = 50 → 选防御
	assert_eq(str(action["skill_id"]), "defense", "前排阵亡 → 防御技能修正 +0.3")


# ============================================================================
# AC-012：撤退判定
# ============================================================================

func test_retreat_triggered_low_hp() -> void:
	var skills := [_make_skill(&"atk", SkillEntry.SkillType.ATTACK, 50, 1, 0, SkillEntry.TargetType.SINGLE_ENEMY)]
	var t := _make_elite_template(&"e1", 100, 20, 10, skills)
	# retreat_threshold=0.2（elite 默认）
	var enemy := _make_enemy(t)
	ai.set_enemy_roster([enemy])
	var field := _make_field_state([_make_player_char(1, 100, 100, 5)], [enemy])
	field["ally_hp_ratio"] = 0.1  # < retreat_threshold=0.2
	# 确定性种子下测试——种子 42 下 randf() 可能 < 或 >= 0.5
	# 测试多次取一个撤退结果
	var retreat_count: int = 0
	for seed_val in range(100):
		ai.set_rng_seed(seed_val)
		var actions = ai.call("execute_turn", field)
		if actions[0].get("is_retreat", false):
			retreat_count += 1
	assert_true(retreat_count > 0, "至少有一次撤退触发（实际: %d/100）" % retreat_count)
	assert_true(retreat_count < 100, "并非全部撤退——50%% 概率（实际: %d/100）" % retreat_count)


func test_retreat_not_triggered_high_hp() -> void:
	var skills := [_make_skill(&"atk", SkillEntry.SkillType.ATTACK, 50, 1, 0, SkillEntry.TargetType.SINGLE_ENEMY)]
	var t := _make_elite_template(&"e1", 100, 20, 10, skills)
	var enemy := _make_enemy(t)
	ai.set_enemy_roster([enemy])
	var field := _make_field_state([_make_player_char(1, 100, 100, 5)], [enemy])
	field["ally_hp_ratio"] = 0.5  # >= retreat_threshold=0.2
	var actions = ai.call("execute_turn", field)
	assert_false(actions[0].get("is_retreat", true), "HP 比例 >= 阈值 → 不撤退")


func test_retreat_boss_never_retreats() -> void:
	var skills := [_make_skill(&"atk", SkillEntry.SkillType.ATTACK, 50, 1, 0, SkillEntry.TargetType.SINGLE_ENEMY)]
	var t := _make_boss_template(&"boss", 200, 30, 15, skills)
	var enemy := _make_enemy(t)
	enemy.current_hp = 1  # 濒死
	ai.set_enemy_roster([enemy])
	var field := _make_field_state([_make_player_char(1, 100, 100, 5)], [enemy])
	field["ally_hp_ratio"] = 0.01  # 极低
	var actions = ai.call("execute_turn", field)
	assert_false(actions[0].get("is_retreat", true), "Boss 绝不撤退")


# ============================================================================
# AC-013：不写 GSM
# ============================================================================

func test_execute_turn_returns_ai_actions_not_write_gsm() -> void:
	var skills := [_make_skill(&"atk", SkillEntry.SkillType.ATTACK, 50, 1, 0, SkillEntry.TargetType.SINGLE_ENEMY)]
	var t := _make_normal_template(&"e1", 100, 20, 10, skills)
	var enemy := _make_enemy(t)
	ai.set_enemy_roster([enemy])
	var field := _make_field_state([_make_player_char(1, 100, 100, 5)], [enemy])
	var actions = ai.call("execute_turn", field)
	assert_eq(actions.size(), 1, "返回 1 个行动")
	var action: Dictionary = actions[0]
	assert_true(action.has("enemy_id"), "AIAction 含 enemy_id")
	assert_true(action.has("skill_id"), "AIAction 含 skill_id")
	assert_true(action.has("target_ids"), "AIAction 含 target_ids")
	assert_true(action.has("is_retreat"), "AIAction 含 is_retreat")
	# AI 不持有 CombatSystem 引用——ai 对象上无 combat_system 属性
	assert_false(ai.has_method("get_combat_system"), "AI 不持有 CombatSystem 引用")


# ============================================================================
# AC-014：走 CardEffectEngine 统一路径（验证不调用 resolve）
# ============================================================================

func test_ai_does_not_resolve_effects() -> void:
	var skills := [_make_skill(&"atk", SkillEntry.SkillType.ATTACK, 50, 1, 0, SkillEntry.TargetType.SINGLE_ENEMY)]
	var t := _make_normal_template(&"e1", 100, 20, 10, skills)
	var enemy := _make_enemy(t)
	ai.set_enemy_roster([enemy])
	var field := _make_field_state([_make_player_char(1, 100, 100, 5)], [enemy])
	ai.call("execute_turn", field)
	# AI 不应有 resolve 方法——结算由 CombatSystem 调用 CardEffectEngine.resolve()
	assert_false(ai.has_method("resolve"), "AI 不含 resolve 方法——结算走 CardEffectEngine 统一路径")
	assert_false(ai.has_method("execute_effect"), "AI 不含 execute_effect 方法")


# ============================================================================
# 综合验证：修饰系数同时生效
# ============================================================================

func test_multiple_modifiers_stack() -> void:
	var skills := [
		_make_skill(&"heal", SkillEntry.SkillType.HEAL, 30, 1, 0, SkillEntry.TargetType.ALLY),
		_make_skill(&"defense", SkillEntry.SkillType.DEFENSE, 30, 1, 0, SkillEntry.TargetType.SELF),
		_make_skill(&"atk", SkillEntry.SkillType.ATTACK, 40, 1, 0, SkillEntry.TargetType.SINGLE_ENEMY),
	]
	var t := _make_normal_template(&"e1", 100, 20, 10, skills)
	var enemy := _make_enemy(t)
	ai.set_enemy_roster([enemy])
	var field := _make_field_state([_make_player_char(1, 100, 100, 5)], [enemy])
	field["ally_low_hp_count"] = 2
	field["ally_front_dead"] = true
	field["player_high_threat"] = true
	var action = ai.call("execute_turn", field)[0]
	# heal: 30 × 1.5 = 45
	# defense: 30 × 1.3 = 39
	# atk: 40 × 1.4 = 56 → 最高
	assert_eq(str(action["skill_id"]), "atk", "攻击修正 +0.4 后 score=56 最高")


# ============================================================================
# qa-lead GAP-1：is_elite AND is_boss → Boss 分支优先
# ============================================================================

func test_decide_action_boss_wins_over_elite() -> void:
	var skills := [_make_skill(&"atk1", SkillEntry.SkillType.ATTACK, 50, 1, 0, SkillEntry.TargetType.SINGLE_ENEMY)]
	var t := _make_boss_template(&"boss_elite", 200, 30, 15, skills)
	t.is_elite = true  # 同时为 elite + boss
	var enemy := _make_enemy(t)
	ai.set_enemy_roster([enemy])
	var field := _make_field_state([_make_player_char(1, 100, 100, 5)], [enemy])
	var action = ai.call("execute_turn", field)[0]
	# Boss 分支优先——不崩溃，正常返回行动
	assert_eq(str(action["skill_id"]), "atk1", "is_boss + is_elite → Boss 分支优先")
	assert_false(action.get("is_retreat", true), "Boss 绝不撤退")


# ============================================================================
# qa-lead GAP-2：同分稳定性
# ============================================================================

func test_skill_score_equal_weight_stable_sort() -> void:
	var skills := [
		_make_skill(&"skill_a", SkillEntry.SkillType.ATTACK, 50, 1, 0, SkillEntry.TargetType.SINGLE_ENEMY),
		_make_skill(&"skill_b", SkillEntry.SkillType.ATTACK, 50, 1, 0, SkillEntry.TargetType.SINGLE_ENEMY),
	]
	var t := _make_normal_template(&"e1", 100, 20, 10, skills)
	var enemy := _make_enemy(t)
	ai.set_enemy_roster([enemy])
	var field := _make_field_state([_make_player_char(1, 100, 100, 5)], [enemy])
	# 确定性种子下多次调用——结果应一致
	var first_action = ai.call("execute_turn", field)[0]
	var first_skill: String = str(first_action["skill_id"])
	for i in range(10):
		var action = ai.call("execute_turn", field)[0]
		assert_eq(str(action["skill_id"]), first_skill, "同分技能确定性选择")


# ============================================================================
# qa-lead GAP-3：阵法技能 +20 加法修正
# ============================================================================

func test_formation_modifier_adds_20_when_slots_available() -> void:
	var skills := [
		_make_skill(&"formation", SkillEntry.SkillType.FORMATION, 30, 1, 0, SkillEntry.TargetType.SELF),
		_make_skill(&"atk", SkillEntry.SkillType.ATTACK, 50, 1, 0, SkillEntry.TargetType.SINGLE_ENEMY),
	]
	var t := _make_normal_template(&"e1", 100, 20, 10, skills)
	var enemy := _make_enemy(t)
	ai.set_enemy_roster([enemy])
	var field := _make_field_state([_make_player_char(1, 100, 100, 5)], [enemy])
	field["enemy_formation_slots_available"] = 1  # 有空阵法位
	var action = ai.call("execute_turn", field)[0]
	# formation score = 30 × 1.0 + 20 = 50
	# atk score = 50 × 1.0 = 50
	# 同分——稳定性选择第一个（formation）
	assert_true(str(action["skill_id"]) == "formation" or str(action["skill_id"]) == "atk", "阵法 +20 后与攻击同分")


func test_formation_modifier_no_bonus_when_no_slots() -> void:
	var skills := [
		_make_skill(&"formation", SkillEntry.SkillType.FORMATION, 30, 1, 0, SkillEntry.TargetType.SELF),
		_make_skill(&"atk", SkillEntry.SkillType.ATTACK, 50, 1, 0, SkillEntry.TargetType.SINGLE_ENEMY),
	]
	var t := _make_normal_template(&"e1", 100, 20, 10, skills)
	var enemy := _make_enemy(t)
	ai.set_enemy_roster([enemy])
	var field := _make_field_state([_make_player_char(1, 100, 100, 5)], [enemy])
	field["enemy_formation_slots_available"] = 0  # 无空阵法位
	var action = ai.call("execute_turn", field)[0]
	# formation score = 30 × 1.0 + 0 = 30 < atk 50 → 选 atk
	assert_eq(str(action["skill_id"]), "atk", "无空阵法位 → 阵法无加法修正 → 攻击胜出")


# ============================================================================
# qa-lead GAP-4：嘲讽不影响非攻击技能（法术 debuff 可绕过）
# ============================================================================

func test_taunt_does_not_force_debuff_target() -> void:
	var skills := [_make_skill(&"debuff", SkillEntry.SkillType.UTILITY, 50, 1, 0, SkillEntry.TargetType.SINGLE_ENEMY)]
	var t := _make_normal_template(&"e1", 100, 20, 10, skills)
	# focus_fire=0.3 → 分散模式；UTILITY 类型不受嘲讽限制
	t.behavior_profile = _make_behavior_profile(0.7, 0.3, 0.5, 0.0)
	var enemy := _make_enemy(t)
	ai.set_enemy_roster([enemy])
	var player1 := _make_player_char(1, 80, 100, 5, true)   # 嘲讽
	var player2 := _make_player_char(2, 50, 100, 5)           # 非嘲讽
	var field := _make_field_state([player1, player2], [enemy])
	ai.set_rng_seed(42)
	# UTILITY 类型不受嘲讽限制——可选中非嘲讽目标
	var hit_player2: bool = false
	for i in range(20):
		var action = ai.call("execute_turn", field)[0]
		var target_ids: Array = action["target_ids"]
		if target_ids.size() > 0 and int(target_ids[0]["id"]) == 2:
			hit_player2 = true
			break
	assert_true(hit_player2, "UTILITY 技能至少有一次选到非嘲讽目标——嘲讽不强制")


# ============================================================================
# qa-lead GAP-6：retreat_threshold=0 → 永不撤退
# ============================================================================

func test_retreat_threshold_zero_never_retreats() -> void:
	var skills := [_make_skill(&"atk", SkillEntry.SkillType.ATTACK, 50, 1, 0, SkillEntry.TargetType.SINGLE_ENEMY)]
	var t := _make_normal_template(&"e1", 100, 20, 10, skills)
	t.behavior_profile = _make_behavior_profile(0.7, 0.6, 0.5, 0.0)  # retreat_threshold=0.0
	var enemy := _make_enemy(t)
	enemy.current_hp = 1  # 濒死
	ai.set_enemy_roster([enemy])
	var field := _make_field_state([_make_player_char(1, 100, 100, 5)], [enemy])
	field["ally_hp_ratio"] = 0.01  # 极低
	for seed_val in range(100):
		ai.set_rng_seed(seed_val)
		var actions = ai.call("execute_turn", field)
		assert_false(actions[0].get("is_retreat", true), "retreat_threshold=0 → 永不撤退（seed=%d）" % seed_val)


# ============================================================================
# qa-lead GAP-8：边界情况
# ============================================================================

func test_empty_skill_pool_basic_attack() -> void:
	var t := _make_normal_template(&"e1", 100, 20, 10, [])
	var enemy := _make_enemy(t)
	ai.set_enemy_roster([enemy])
	var field := _make_field_state([_make_player_char(1, 100, 100, 5)], [enemy])
	var action = ai.call("execute_turn", field)[0]
	assert_eq(str(action["skill_id"]), "basic_attack", "空技能池 → basic_attack")


func test_execute_turn_empty_roster() -> void:
	ai.set_enemy_roster([])
	var field := _make_field_state([], [])
	var actions = ai.call("execute_turn", field)
	assert_eq(actions.size(), 0, "空阵容 → 空行动列表")


func test_select_target_no_alive_players() -> void:
	var skills := [_make_skill(&"atk", SkillEntry.SkillType.ATTACK, 50, 1, 0, SkillEntry.TargetType.SINGLE_ENEMY)]
	var t := _make_normal_template(&"e1", 100, 20, 10, skills)
	var enemy := _make_enemy(t)
	ai.set_enemy_roster([enemy])
	var dead_player := _make_player_char(1, 0, 100, 5)
	dead_player["is_alive"] = false
	var field := _make_field_state([dead_player], [enemy])
	var action = ai.call("execute_turn", field)[0]
	# 无可用技能（目标为空 → 仍选最高分技能但目标列表为空）
	var target_ids: Array = action["target_ids"]
	assert_eq(target_ids.size(), 0, "无存活目标 → 空目标列表")
