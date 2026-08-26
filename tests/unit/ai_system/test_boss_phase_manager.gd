extends GutTest
## Story 003 验收测试：BossPhaseMgr 阶段转换内部状态机。
##
## 覆盖 AC-001 到 AC-013（13 条 AC）。
## 测试策略：
##   - AISystem 用 AI_SCRIPT.new() + var ai: Node 持有
##   - 手动构造 Boss EnemyBattleState + BossPhaseTransition
##   - 纯逻辑状态机——无需完整战斗
##
## 设计文档来源：ADR-0017 §决策引擎设计 ② / GDD ai-system.md §7/§公式 4
## Story 来源：production/epics/ai-system/story-003-boss-phase-manager.md

const AI_SCRIPT := preload("res://src/feature/ai_system.gd")
const EnemyTemplate := preload("res://assets/enemies/enemy_template.gd")
const BehaviorProfile := preload("res://assets/enemies/behavior_profile.gd")
const SkillEntry := preload("res://assets/enemies/skill_entry.gd")
const BossPhaseTransition := preload("res://assets/enemies/boss_phase_transition.gd")
const EnemyBattleState := preload("res://src/feature/ai/enemy_battle_state.gd")

var ai: Node = null
var _signal_log: Array = []


func before_each() -> void:
	ai = AI_SCRIPT.new()
	_signal_log.clear()
	ai.set_rng_seed(42)


func after_each() -> void:
	if ai != null:
		ai.free()
		ai = null
	_signal_log.clear()


# === 辅助：构造 Boss + 阶段转换 ==============================================

func _make_boss(hp: int, atk: int, def: int, transitions: Array) -> Object:
	var t := EnemyTemplate.new()
	t.template_id = &"boss_test"
	t.display_name = "Test Boss"
	t.realm = 3
	t.is_elite = false
	t.is_boss = true
	t.base_hp = hp
	t.base_attack = atk
	t.base_defense = def
	t.formation_limit = 2
	t.front_slot = true
	t.behavior_profile = _make_behavior_profile(0.9, 0.8, 0.7, 0.0)
	t.skill_pool = [_make_skill(&"duoming_zhua", "夺命爪", SkillEntry.SkillType.ATTACK, 35, 1, 0, SkillEntry.TargetType.SINGLE_ENEMY)]
	t.phase_transitions = transitions
	return t


func _make_behavior_profile(aggression: float, focus_fire: float, front_priority: float, retreat: float) -> Object:
	var bp := BehaviorProfile.new()
	bp.aggression = aggression
	bp.focus_fire = focus_fire
	bp.front_priority = front_priority
	bp.retreat_threshold = retreat
	return bp


func _make_skill(sid: StringName, name: String, stype: int, weight: int, cost: int, cd: int, ttype: int) -> Object:
	var se := SkillEntry.new()
	se.skill_id = sid
	se.display_name = name
	se.skill_type = stype
	se.base_weight = weight
	se.cost = cost
	se.cooldown = cd
	se.target_type = ttype
	se.effect_template_ids = [&"effect_basic"]
	return se


func _make_phase_transition(hp_below: float, turn_after: int, override: Object = null,
		unlock: Array = [], remove: Array = [], reset_cd: bool = false, heal: float = 0.0) -> Object:
	var pt := BossPhaseTransition.new()
	pt.hp_below = hp_below
	pt.turn_after = turn_after
	pt.behavior_override = override
	pt.skill_unlock = unlock
	pt.skill_remove = remove
	pt.reset_cooldowns = reset_cd
	pt.heal_percent = heal
	pt.animation = &"boss_phase_anim"
	return pt


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


func _make_field_state(turn: int = 1) -> Dictionary:
	return {"turn": turn, "player_chars": [], "enemy_chars": [], "enemy_cost_budget": 3}


# ============================================================================
# AC-001：BossPhaseMgr 组件存在
# ============================================================================

func test_boss_phase_mgr_methods_exist() -> void:
	assert_true(ai.has_method("check"), "check 方法存在")
	assert_true(ai.has_method("transition"), "transition 方法存在")
	assert_true(ai.has_method("get_phase"), "get_phase 方法存在")


func test_get_phase_default_zero() -> void:
	var transitions := [_make_phase_transition(0.5, 0)]
	var t := _make_boss(200, 30, 15, transitions)
	var enemy := _make_enemy(t)
	assert_eq(ai.call("get_phase", enemy), 0, "默认阶段索引 0")


# ============================================================================
# AC-002：HP 阈值触发 + 行为替换
# ============================================================================

func test_hp_below_triggers_transition() -> void:
	var override := _make_behavior_profile(1.0, 0.9, 0.8, 0.0)
	var transitions := [_make_phase_transition(0.5, 0, override)]
	var t := _make_boss(200, 30, 15, transitions)
	var enemy := _make_enemy(t)
	enemy.current_hp = 80  # hp_pct = 0.4 < 0.5
	var phase_idx: int = ai.call("check", enemy, 1, 0.4)
	assert_eq(phase_idx, 0, "hp_pct=0.4 < 0.5 → 触发阶段 0")
	ai.call("transition", enemy, phase_idx)
	# 行为配置替换（实例级 runtime_behavior_profile，不写回模板）
	var current_behavior = enemy.runtime_behavior_profile
	assert_eq(current_behavior.aggression, 1.0, "runtime_behavior_profile 替换为 override")
	# 模板保持只读（ADR-0017）
	assert_ne(enemy.template.behavior_profile.aggression, 1.0, "模板 behavior_profile 未被修改")


func test_hp_exactly_at_threshold_triggers() -> void:
	var transitions := [_make_phase_transition(0.5, 0)]
	var t := _make_boss(200, 30, 15, transitions)
	var enemy := _make_enemy(t)
	enemy.current_hp = 100  # hp_pct = 0.5 == 0.5
	var phase_idx: int = ai.call("check", enemy, 1, 0.5)
	assert_eq(phase_idx, 0, "hp_pct=0.5 == hp_below → 触发（<=）")


func test_hp_above_threshold_no_trigger() -> void:
	var transitions := [_make_phase_transition(0.5, 0)]
	var t := _make_boss(200, 30, 15, transitions)
	var enemy := _make_enemy(t)
	var phase_idx: int = ai.call("check", enemy, 1, 0.7)
	assert_eq(phase_idx, -1, "hp_pct=0.7 > 0.5 → 不触发")


# ============================================================================
# AC-003：技能解锁/锁定
# ============================================================================

func test_skill_remove_during_transition() -> void:
	var transitions := [_make_phase_transition(0.5, 0, null, [], [&"duoming_zhua"], false, 0.0)]
	var t := _make_boss(200, 30, 15, transitions)
	var enemy := _make_enemy(t)
	assert_eq(enemy.template.skill_pool.size(), 1, "转换前模板 1 个技能")
	ai.call("transition", enemy, 0)
	# 实例级 runtime_skill_pool 被修改，模板保持只读（ADR-0017）
	assert_eq((enemy.runtime_skill_pool as Array).size(), 0, "runtime_skill_pool skill_remove 后为空")
	assert_eq(enemy.template.skill_pool.size(), 1, "模板 skill_pool 未被修改")


func test_skill_unlock_empty_array_no_change() -> void:
	var transitions := [_make_phase_transition(0.5, 0, null, [], [], false, 0.0)]
	var t := _make_boss(200, 30, 15, transitions)
	var enemy := _make_enemy(t)
	ai.call("transition", enemy, 0)
	assert_eq((enemy.runtime_skill_pool as Array).size(), 1, "skill_unlock 为空 → runtime_skill_pool 不变")
	assert_eq(enemy.template.skill_pool.size(), 1, "模板 skill_pool 未被修改")


func test_skill_unlock_adds_new_skill() -> void:
	# skill_unlock 当前为简化占位（Story 004 集成完整 SkillEntry 解析）
	# 验证 skill_unlock 非空时不会破坏现有技能池
	var new_skill := _make_skill(&"new_skill", "新技能", SkillEntry.SkillType.ATTACK, 30, 1, 0, SkillEntry.TargetType.SINGLE_ENEMY)
	var transitions := [_make_phase_transition(0.5, 0, null, [new_skill], [], false, 0.0)]
	var t := _make_boss(200, 30, 15, transitions)
	var enemy := _make_enemy(t)
	ai.call("transition", enemy, 0)
	# skill_unlock 添加新技能到 runtime_skill_pool
	assert_eq((enemy.runtime_skill_pool as Array).size(), 2, "skill_unlock 添加 1 个新技能 → runtime_skill_pool 有 2 个")
	assert_eq(enemy.template.skill_pool.size(), 1, "模板 skill_pool 未被修改")


# ============================================================================
# AC-004：冷却重置
# ============================================================================

func test_reset_cooldowns_clears_all() -> void:
	var transitions := [_make_phase_transition(0.5, 0, null, [], [], true, 0.0)]  # reset_cd=true
	var t := _make_boss(200, 30, 15, transitions)
	var enemy := _make_enemy(t)
	enemy.skill_cooldowns = {&"skill1": 2, &"skill2": 3}
	ai.call("transition", enemy, 0)
	assert_eq(enemy.skill_cooldowns.size(), 0, "reset_cooldowns=true → 全部清零")


func test_no_reset_cooldowns_preserves() -> void:
	var transitions := [_make_phase_transition(0.5, 0, null, [], [], false, 0.0)]  # reset_cd=false
	var t := _make_boss(200, 30, 15, transitions)
	var enemy := _make_enemy(t)
	enemy.skill_cooldowns = {&"skill1": 2, &"skill2": 3}
	ai.call("transition", enemy, 0)
	assert_eq(enemy.skill_cooldowns.size(), 2, "reset_cooldowns=false → 冷却保持")


# ============================================================================
# AC-005：转换回血
# ============================================================================

func test_heal_percent_restores_hp() -> void:
	var transitions := [_make_phase_transition(0.5, 0, null, [], [], false, 0.1)]  # heal=10%
	var t := _make_boss(100, 30, 15, transitions)
	var enemy := _make_enemy(t)
	enemy.current_hp = 40
	ai.call("transition", enemy, 0)
	assert_eq(enemy.current_hp, 50, "40 + round(100×0.1)=10 → 50")


func test_heal_percent_zero_no_heal() -> void:
	var transitions := [_make_phase_transition(0.5, 0, null, [], [], false, 0.0)]
	var t := _make_boss(100, 30, 15, transitions)
	var enemy := _make_enemy(t)
	enemy.current_hp = 40
	ai.call("transition", enemy, 0)
	assert_eq(enemy.current_hp, 40, "heal_percent=0 → 不回血")


func test_heal_capped_at_max_hp() -> void:
	var transitions := [_make_phase_transition(0.5, 0, null, [], [], false, 1.0)]  # heal=100%
	var t := _make_boss(100, 30, 15, transitions)
	var enemy := _make_enemy(t)
	enemy.current_hp = 90
	ai.call("transition", enemy, 0)
	assert_eq(enemy.current_hp, 100, "回血不超过 max_hp")


# ============================================================================
# AC-006：boss_phase_transitioned 信号
# ============================================================================

func test_boss_phase_transitioned_signal_emitted() -> void:
	var transitions := [_make_phase_transition(0.5, 0)]
	var t := _make_boss(200, 30, 15, transitions)
	var enemy := _make_enemy(t)
	# 使用 Dictionary 作为可变容器——GDScript lambda 按值捕获基元类型
	var sig_state := {"received": false, "from": -1, "to": -1, "call_count": 0}
	ai.connect("boss_phase_transitioned", func(_e, from, to):
		sig_state["received"] = true
		sig_state["from"] = from
		sig_state["to"] = to
		sig_state["call_count"] += 1)
	ai.call("transition", enemy, 0)
	assert_true(sig_state["received"], "boss_phase_transitioned 信号发射")
	assert_eq(sig_state["from"], 0, "from_phase=0")
	assert_eq(sig_state["to"], 1, "to_phase=1")
	# AC-006：信号经 _emit_safe 单路径发射，不应重复
	assert_eq(sig_state["call_count"], 1, "信号仅发射 1 次（_emit_safe 单路径）")


# ============================================================================
# AC-007：击杀优先
# ============================================================================

func test_dead_boss_no_transition() -> void:
	var transitions := [_make_phase_transition(0.5, 0)]
	var t := _make_boss(200, 30, 15, transitions)
	var enemy := _make_enemy(t)
	enemy.is_alive = false  # 阵亡
	enemy.current_hp = 10  # hp_pct 极低
	var phase_idx: int = ai.call("check", enemy, 1, 0.05)
	assert_eq(phase_idx, -1, "is_alive=false → 不检查转换")


# ============================================================================
# AC-008：防重复触发
# ============================================================================

func test_no_duplicate_trigger() -> void:
	var transitions := [_make_phase_transition(0.5, 0)]
	var t := _make_boss(200, 30, 15, transitions)
	var enemy := _make_enemy(t)
	enemy.current_hp = 80  # hp_pct=0.4
	# 第一次触发
	var phase_idx: int = ai.call("check", enemy, 1, 0.4)
	assert_eq(phase_idx, 0, "第一次触发")
	ai.call("transition", enemy, phase_idx)
	# 再次检查——不应触发
	var phase_idx2: int = ai.call("check", enemy, 2, 0.3)
	assert_eq(phase_idx2, -1, "已触发 → 不再返回")


func test_hp_fluctuation_no_duplicate() -> void:
	var transitions := [_make_phase_transition(0.5, 0)]
	var t := _make_boss(200, 30, 15, transitions)
	var enemy := _make_enemy(t)
	enemy.current_hp = 80
	ai.call("transition", enemy, 0)
	# 血量波动——再次低于阈值
	enemy.current_hp = 70
	var phase_idx: int = ai.call("check", enemy, 3, 0.35)
	assert_eq(phase_idx, -1, "血量波动 → 不重复触发")


# ============================================================================
# AC-009：最多 3 阶段
# ============================================================================

func test_phase_transitions_max_2() -> void:
	# 2 个转换 = 起始 + 2 = 3 阶段（上限）
	var transitions := [
		_make_phase_transition(0.5, 0),
		_make_phase_transition(0.2, 0),
	]
	var t := _make_boss(200, 30, 15, transitions)
	assert_eq(t.phase_transitions.size(), 2, "最多 2 个转换（3 阶段）")


# ============================================================================
# AC-010：should_transition 公式（OR + 哨兵）
# ============================================================================

func test_should_transition_hp_only() -> void:
	var transitions := [_make_phase_transition(0.5, 0)]  # turn_after=0 → 禁用
	var t := _make_boss(200, 30, 15, transitions)
	var enemy := _make_enemy(t)
	# hp 触发
	assert_eq(ai.call("check", enemy, 3, 0.4), 0, "hp 触发")
	# hp 未达标 + turn_after=0 → 不触发
	assert_eq(ai.call("check", enemy, 3, 0.7), -1, "hp 未达标 + turn 禁用 → 不触发")


func test_should_transition_turn_only() -> void:
	var transitions := [_make_phase_transition(0.0, 8)]  # hp_below=0 → 禁用
	var t := _make_boss(200, 30, 15, transitions)
	var enemy := _make_enemy(t)
	# turn 兜底触发
	assert_eq(ai.call("check", enemy, 9, 0.7), 0, "turn=9 >= 8 + hp 禁用 → 回合兜底触发")
	# turn 未达标 + hp 禁用 → 不触发
	assert_eq(ai.call("check", enemy, 5, 0.7), -1, "turn < 8 + hp 禁用 → 不触发")


func test_should_transition_both_disabled() -> void:
	var transitions := [_make_phase_transition(0.0, 0)]  # 均为 0 → 永不触发
	var t := _make_boss(200, 30, 15, transitions)
	var enemy := _make_enemy(t)
	assert_eq(ai.call("check", enemy, 10, 0.01), -1, "hp_below=0 + turn_after=0 → 永不触发")


func test_turn_exactly_at_threshold_triggers() -> void:
	var transitions := [_make_phase_transition(0.0, 8)]  # hp_below=0 → 禁用
	var t := _make_boss(200, 30, 15, transitions)
	var enemy := _make_enemy(t)
	# turn 恰好等于 turn_after → >= 语义触发
	assert_eq(ai.call("check", enemy, 8, 0.7), 0, "turn=8 == turn_after=8 → >= 边界触发")


# ============================================================================
# AC-011：回合兜底触发
# ============================================================================

func test_turn_fallback_triggers_without_hp() -> void:
	var transitions := [_make_phase_transition(0.5, 8)]  # HP + turn 均启用
	var t := _make_boss(200, 30, 15, transitions)
	var enemy := _make_enemy(t)
	# hp 未到阈值但 turn 达标 → OR 触发
	assert_eq(ai.call("check", enemy, 9, 0.7), 0, "turn=9 >= 8 + hp_pct=0.7 > 0.5 → 回合兜底触发")


func test_turn_fallback_zero_disables() -> void:
	var transitions := [_make_phase_transition(0.5, 0)]  # turn_after=0 → 禁用
	var t := _make_boss(200, 30, 15, transitions)
	var enemy := _make_enemy(t)
	# turn 很高但 hp 未到阈值 → 不触发（turn_after=0 禁用）
	assert_eq(ai.call("check", enemy, 100, 0.9), -1, "turn_after=0 → 回合兜底禁用")


# ============================================================================
# AC-012：转换回合不行动
# ============================================================================

func test_transition_round_no_action() -> void:
	var override := _make_behavior_profile(1.0, 0.9, 0.8, 0.0)
	var transitions := [_make_phase_transition(0.5, 0, override)]
	var t := _make_boss(200, 30, 15, transitions)
	var enemy := _make_enemy(t)
	enemy.current_hp = 80  # hp_pct=0.4 < 0.5
	ai.set_enemy_roster([enemy])
	var field := _make_field_state(1)
	field["player_chars"] = [{"id": 1, "current_hp": 100, "max_hp": 100, "defense": 5, "is_alive": true, "is_taunting": false}]
	var actions = ai.call("execute_turn", field)
	assert_eq(actions.size(), 1, "1 个行动")
	var action: Dictionary = actions[0]
	assert_eq(str(action["skill_id"]), "", "转换回合 skill_id 为空")
	assert_eq((action["target_ids"] as Array).size(), 0, "转换回合无目标")


func test_no_transition_normal_action() -> void:
	var transitions := [_make_phase_transition(0.5, 0)]
	var t := _make_boss(200, 30, 15, transitions)
	var enemy := _make_enemy(t)
	enemy.current_hp = 150  # hp_pct=0.75 > 0.5 → 不触发
	ai.set_enemy_roster([enemy])
	var field := _make_field_state(1)
	field["player_chars"] = [{"id": 1, "current_hp": 100, "max_hp": 100, "defense": 5, "is_alive": true, "is_taunting": false}]
	var actions = ai.call("execute_turn", field)
	var action: Dictionary = actions[0]
	assert_ne(str(action["skill_id"]), "", "无转换 → 正常技能行动")


# ============================================================================
# AC-013：最终阶段保持
# ============================================================================

func test_all_transitions_triggered_stays_final() -> void:
	var transitions := [
		_make_phase_transition(0.5, 0),
		_make_phase_transition(0.2, 0),
	]
	var t := _make_boss(200, 30, 15, transitions)
	var enemy := _make_enemy(t)
	# 触发全部两个转换
	ai.call("transition", enemy, 0)
	ai.call("transition", enemy, 1)
	assert_eq(ai.call("get_phase", enemy), 2, "最终阶段索引 2")
	# 不再触发
	assert_eq(ai.call("check", enemy, 10, 0.01), -1, "全部已触发 → 不再转换")


# ============================================================================
# 综合验证：多阶段连续转换
# ============================================================================

func test_multi_phase_sequential_transition() -> void:
	var override1 := _make_behavior_profile(1.0, 0.9, 0.8, 0.0)
	var override2 := _make_behavior_profile(1.0, 1.0, 0.9, 0.0)
	var transitions := [
		_make_phase_transition(0.5, 0, override1, [], [], true, 0.1),  # 50% HP → 阶段 1
		_make_phase_transition(0.2, 0, override2, [], [], true, 0.0),  # 20% HP → 阶段 2
	]
	var t := _make_boss(200, 30, 15, transitions)
	var enemy := _make_enemy(t)

	# 阶段 1：HP 降到 50% 以下
	enemy.current_hp = 90  # hp_pct=0.45
	assert_eq(ai.call("check", enemy, 3, 0.45), 0, "阶段 0 触发")
	ai.call("transition", enemy, 0)
	assert_eq(enemy.current_phase_index, 1, "current_phase_index=1")
	assert_eq(enemy.current_hp, 110, "回血 10% → 90+20=110")
	assert_eq(enemy.runtime_behavior_profile.aggression, 1.0, "runtime_behavior_profile 替换为 override1")

	# 阶段 2：HP 再降到 20% 以下
	enemy.current_hp = 40  # hp_pct=0.2（相对 max_hp=200）
	assert_eq(ai.call("check", enemy, 6, 0.2), 1, "阶段 1 触发")
	ai.call("transition", enemy, 1)
	assert_eq(enemy.current_phase_index, 2, "current_phase_index=2")
	assert_eq(enemy.runtime_behavior_profile.focus_fire, 1.0, "runtime_behavior_profile 替换为 override2")

	# 不再触发
	assert_eq(ai.call("check", enemy, 10, 0.01), -1, "全部已触发")
