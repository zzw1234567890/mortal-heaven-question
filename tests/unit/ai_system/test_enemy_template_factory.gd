extends GutTest
## Story 001 验收测试：EnemyTemplate Resource + 内嵌 Resource 类型 +
## EnemyBattleState 运行时实例 + EnemyFactory 模板→实例创建 +
## create_enemy_roster 阵位自动分配。
##
## 覆盖 AC-001 到 AC-010（10 条 AC）。
## 测试策略：
##   - EnemyTemplate 用脚本内 EnemyTemplate.new() 构造（不依赖 .tres 文件）
##   - AISystem 用 AI_SCRIPT.new() + var ai: Node 持有
##   - 手动注入 _template_registry 以绕过 load_templates 目录扫描
##   - 阵位分配用纯逻辑断言
##
## 设计文档来源：ADR-0017 §关键接口 §EnemyTemplate Resource §EnemyBattleState
## Story 来源：production/epics/ai-system/story-001-enemy-template-factory.md

const AI_SCRIPT := preload("res://src/feature/ai_system.gd")
const EnemyTemplate := preload("res://assets/enemies/enemy_template.gd")
const BehaviorProfile := preload("res://assets/enemies/behavior_profile.gd")
const SkillEntry := preload("res://assets/enemies/skill_entry.gd")
const BossPhaseTransition := preload("res://assets/enemies/boss_phase_transition.gd")
const RewardConfig := preload("res://assets/enemies/reward_config.gd")
const EnemyBattleState := preload("res://src/feature/ai/enemy_battle_state.gd")

var ai: Node = null


func before_each() -> void:
	ai = AI_SCRIPT.new()


func after_each() -> void:
	if ai != null:
		ai.free()
		ai = null


# === 辅助：构造测试模板 ========================================================

func _make_normal_template(tid: StringName, hp: int, atk: int, def: int) -> Object:
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
	t.skill_pool = [_make_skill_entry(&"basic_attack", "基础攻击", SkillEntry.SkillType.ATTACK, 50, 1, 0, SkillEntry.TargetType.SINGLE_ENEMY)]
	t.reward_config = _make_reward_config(10, 20, 5)
	return t


func _make_elite_template(tid: StringName, hp: int, atk: int, def: int) -> Object:
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
	t.skill_pool = [_make_skill_entry(&"yuehua_zhan", "月华斩", SkillEntry.SkillType.ATTACK, 40, 1, 0, SkillEntry.TargetType.SINGLE_ENEMY)]
	t.preconfigured_bindings = [&"gongfa_xuanbing"]
	t.reward_config = _make_reward_config(30, 50, 15)
	return t


func _make_boss_template(tid: StringName, hp: int, atk: int, def: int) -> Object:
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
	t.skill_pool = [_make_skill_entry(&"duoming_zhua", "夺命爪", SkillEntry.SkillType.ATTACK, 35, 1, 0, SkillEntry.TargetType.SINGLE_ENEMY)]
	t.preconfigured_bindings = [&"gongfa_moyuan", &"fabao_hunying"]
	t.phase_transitions = [_make_phase_transition(0.5, 0)]
	t.reward_config = _make_reward_config(100, 200, 50)
	return t


func _make_behavior_profile(aggression: float, focus_fire: float, front_priority: float, retreat: float) -> Object:
	var bp := BehaviorProfile.new()
	bp.aggression = aggression
	bp.focus_fire = focus_fire
	bp.front_priority = front_priority
	bp.retreat_threshold = retreat
	return bp


func _make_skill_entry(sid: StringName, name: String, stype: int, weight: int, cost: int, cd: int, ttype: int) -> Object:
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


func _make_phase_transition(hp_below: float, turn_after: int) -> Object:
	var pt := BossPhaseTransition.new()
	pt.hp_below = hp_below
	pt.turn_after = turn_after
	pt.behavior_override = _make_behavior_profile(1.0, 0.9, 0.8, 0.0)
	pt.skill_unlock = [&"duoming_zhua_enhanced"]
	pt.skill_remove = []
	pt.reset_cooldowns = true
	pt.heal_percent = 0.1
	pt.animation = &"boss_phase_2"
	return pt


func _make_reward_config(ling_shi_min: int, ling_shi_max: int, cultivation: int) -> Object:
	var rc := RewardConfig.new()
	rc.ling_shi_min = ling_shi_min
	rc.ling_shi_max = ling_shi_max
	rc.card_drops = [{"card_id": &"card_test", "chance": 0.5}]
	rc.cultivation_reward = cultivation
	return rc


## 注入模板到注册表（绕过 load_templates 目录扫描）。
func _inject_templates(templates: Array) -> void:
	var registry: Dictionary = ai.get("_template_registry")
	registry.clear()
	for t in templates:
		registry[t.template_id] = t


# ============================================================================
# AC-001：EnemyTemplate Resource 类结构
# ============================================================================

func test_enemy_template_resource_fields() -> void:
	var t := _make_normal_template(&"test_normal", 100, 20, 10)
	assert_true(t is Resource, "EnemyTemplate 是 Resource")
	assert_eq(str(t.template_id), "test_normal", "template_id")
	assert_eq(t.display_name, "test_normal", "display_name")
	assert_eq(t.realm, 1, "realm")
	assert_false(t.is_elite, "is_elite=false")
	assert_false(t.is_boss, "is_boss=false")
	assert_eq(t.base_hp, 100, "base_hp")
	assert_eq(t.base_attack, 20, "base_attack")
	assert_eq(t.base_defense, 10, "base_defense")
	assert_eq(t.formation_limit, 0, "formation_limit=0（普通）")
	assert_false(t.front_slot, "front_slot=false")
	assert_not_null(t.behavior_profile, "behavior_profile 非空")
	assert_eq(t.skill_pool.size(), 1, "skill_pool 1 个技能")
	assert_eq(t.preconfigured_bindings.size(), 0, "普通无预配置绑定")
	assert_eq(t.preconfigured_formations.size(), 0, "普通无预配置阵法")
	assert_eq(t.phase_transitions.size(), 0, "普通无阶段转换")
	assert_not_null(t.reward_config, "reward_config 非空")


# ============================================================================
# AC-002：内嵌 Resource 类型
# ============================================================================

func test_behavior_profile_fields() -> void:
	var bp := _make_behavior_profile(0.8, 0.7, 0.6, 0.2)
	assert_true(bp is Resource, "BehaviorProfile 是 Resource")
	assert_eq(bp.aggression, 0.8, "aggression")
	assert_eq(bp.focus_fire, 0.7, "focus_fire")
	assert_eq(bp.front_priority, 0.6, "front_priority")
	assert_eq(bp.retreat_threshold, 0.2, "retreat_threshold")


func test_skill_entry_fields() -> void:
	var se := _make_skill_entry(&"yuehua_zhan", "月华斩", SkillEntry.SkillType.ATTACK, 40, 1, 0, SkillEntry.TargetType.SINGLE_ENEMY)
	assert_true(se is Resource, "SkillEntry 是 Resource")
	assert_eq(str(se.skill_id), "yuehua_zhan", "skill_id")
	assert_eq(se.display_name, "月华斩", "display_name")
	assert_eq(se.skill_type, SkillEntry.SkillType.ATTACK, "skill_type=ATTACK")
	assert_eq(se.base_weight, 40, "base_weight")
	assert_eq(se.cost, 1, "cost")
	assert_eq(se.cooldown, 0, "cooldown")
	assert_eq(se.target_type, SkillEntry.TargetType.SINGLE_ENEMY, "target_type")
	assert_eq(se.effect_template_ids.size(), 1, "effect_template_ids 1 个")


func test_boss_phase_transition_fields() -> void:
	var pt := _make_phase_transition(0.5, 0)
	assert_true(pt is Resource, "BossPhaseTransition 是 Resource")
	assert_eq(pt.hp_below, 0.5, "hp_below")
	assert_eq(pt.turn_after, 0, "turn_after=0（不按回合触发）")
	assert_not_null(pt.behavior_override, "behavior_override 非空")
	assert_eq(pt.skill_unlock.size(), 1, "skill_unlock 1 个")
	assert_eq(pt.skill_remove.size(), 0, "skill_remove 空")
	assert_true(pt.reset_cooldowns, "reset_cooldowns=true")
	assert_eq(pt.heal_percent, 0.1, "heal_percent=0.1")
	assert_eq(str(pt.animation), "boss_phase_2", "animation")


func test_reward_config_fields() -> void:
	var rc := _make_reward_config(10, 20, 5)
	assert_true(rc is Resource, "RewardConfig 是 Resource")
	assert_eq(rc.ling_shi_min, 10, "ling_shi_min")
	assert_eq(rc.ling_shi_max, 20, "ling_shi_max")
	assert_eq(rc.card_drops.size(), 1, "card_drops 1 个")
	assert_eq(rc.cultivation_reward, 5, "cultivation_reward")


# ============================================================================
# AC-003：EnemyBattleState 运行时类结构
# ============================================================================

func test_enemy_battle_state_fields() -> void:
	var state := EnemyBattleState.new()
	assert_true(state is RefCounted, "EnemyBattleState 是 RefCounted")
	assert_eq(str(state.template_id), "", "template_id 默认空")
	assert_eq(state.current_hp, 0, "current_hp 默认 0")
	assert_eq(state.max_hp, 0, "max_hp 默认 0")
	assert_eq(state.attack, 0, "attack 默认 0")
	assert_eq(state.defense, 0, "defense 默认 0")
	assert_eq(state.skill_cooldowns.size(), 0, "skill_cooldowns 默认空")
	assert_true(state.is_alive, "is_alive 默认 true")
	assert_eq(state.field_position, -1, "field_position 默认 -1")
	assert_false(state.is_front_row, "is_front_row 默认 false")
	assert_eq(state.current_phase_index, 0, "current_phase_index 默认 0")
	assert_eq(state.triggered_transitions.size(), 0, "triggered_transitions 默认空")


# ============================================================================
# AC-004：EnemyFactory 创建实例
# ============================================================================

func test_create_state_maps_template_fields() -> void:
	var t := _make_normal_template(&"test_normal", 100, 20, 10)
	var state = ai.call("create_state", t)
	assert_not_null(state, "create_state 返回非 null")
	assert_eq(str(state.template_id), "test_normal", "template_id 映射")
	assert_eq(state.max_hp, 100, "max_hp=base_hp")
	assert_eq(state.current_hp, 100, "current_hp=base_hp")
	assert_eq(state.attack, 20, "attack=base_attack")
	assert_eq(state.defense, 10, "defense=base_defense")
	assert_true(state.is_alive, "is_alive=true")
	assert_eq(state.skill_cooldowns.size(), 0, "skill_cooldowns 初始空")
	assert_eq(state.current_phase_index, 0, "current_phase_index=0")
	assert_eq(state.triggered_transitions.size(), 0, "triggered_transitions 初始空")
	assert_eq(state.field_position, -1, "field_position=-1（未分配）")


# ============================================================================
# AC-005：模板/实例分离（只读模板）
# ============================================================================

func test_template_instance_isolation() -> void:
	var t := _make_normal_template(&"test_normal", 100, 20, 10)
	var state_a = ai.call("create_state", t)
	var state_b = ai.call("create_state", t)
	# 修改实例状态
	state_a.current_hp = 50
	state_a.skill_cooldowns = {&"skill_1": 2}
	state_b.current_hp = 80
	# 模板不受影响
	assert_eq(t.base_hp, 100, "模板 base_hp 不受实例修改影响")
	assert_eq(t.skill_pool.size(), 1, "模板 skill_pool 不受实例修改影响")
	# 两实例互不污染
	assert_eq(state_a.current_hp, 50, "实例 A HP=50")
	assert_eq(state_b.current_hp, 80, "实例 B HP=80")
	assert_eq(state_a.skill_cooldowns.size(), 1, "实例 A cooldowns 1 条")
	assert_eq(state_b.skill_cooldowns.size(), 0, "实例 B cooldowns 空")


# ============================================================================
# AC-006：load_templates 加载注册表
# ============================================================================

func test_load_templates_empty_dir() -> void:
	# 无 .tres 文件时注册表为空但不崩溃
	ai.call("load_templates")
	assert_eq(ai.call("get_template_count"), 0, "空目录 → 注册表 0 个模板")


func test_load_templates_with_injected_registry() -> void:
	var t1 := _make_normal_template(&"normal_1", 50, 10, 5)
	var t2 := _make_elite_template(&"elite_1", 100, 20, 10)
	_inject_templates([t1, t2])
	assert_eq(ai.call("get_template_count"), 2, "注入 2 个模板")
	assert_true(ai.call("has_template", &"normal_1"), "has normal_1")
	assert_true(ai.call("has_template", &"elite_1"), "has elite_1")
	assert_false(ai.call("has_template", &"nonexistent"), "无 nonexistent")
	var fetched = ai.call("get_template", &"normal_1")
	assert_not_null(fetched, "get_template 返回非 null")
	assert_eq(str(fetched.template_id), "normal_1", "get_template template_id 正确")


# ============================================================================
# AC-007：create_enemy_roster 创建阵容
# ============================================================================

func test_create_enemy_roster_count_matches() -> void:
	var t1 := _make_normal_template(&"normal_1", 50, 10, 5)
	var t2 := _make_normal_template(&"normal_2", 60, 12, 8)
	var t3 := _make_normal_template(&"normal_3", 70, 15, 3)
	_inject_templates([t1, t2, t3])
	var roster = ai.call("create_enemy_roster", [&"normal_1", &"normal_2", &"normal_3"], 1)
	assert_eq(roster.size(), 3, "roster 3 个实例")
	assert_eq(str(roster[0].template_id), "normal_1", "roster[0] template_id")
	assert_eq(str(roster[1].template_id), "normal_2", "roster[1] template_id")
	assert_eq(str(roster[2].template_id), "normal_3", "roster[2] template_id")


func test_create_enemy_roster_unknown_template_skipped() -> void:
	var t1 := _make_normal_template(&"normal_1", 50, 10, 5)
	_inject_templates([t1])
	var roster = ai.call("create_enemy_roster", [&"normal_1", &"nonexistent"], 1)
	assert_eq(roster.size(), 1, "未知 template_id 跳过，roster 仅 1 个")


# ============================================================================
# AC-008：阵位自动分配（防御高→前排）
# ============================================================================

func test_assign_positions_defense_high_goes_front() -> void:
	# 3 敌人：防御 15/10/5，攻击 8/12/20
	var t1 := _make_normal_template(&"def_15", 50, 8, 15)
	var t2 := _make_normal_template(&"def_10", 50, 12, 10)
	var t3 := _make_normal_template(&"def_5", 50, 20, 5)
	_inject_templates([t1, t2, t3])
	var roster = ai.call("create_enemy_roster", [t1.template_id, t2.template_id, t3.template_id], 1)
	# 防御 15 应在前排
	var front_states: Array = []
	var back_states: Array = []
	for state in roster:
		if state.is_front_row:
			front_states.append(state)
		else:
			back_states.append(state)
	assert_eq(front_states.size(), 3, "3 人全部前排（≤3 人全前排扩展）")
	assert_eq(back_states.size(), 0, "无后排")


func test_assign_positions_front_slot_forces_front() -> void:
	# front_slot=true 的敌人强制前排，即使攻击高
	var t1 := _make_normal_template(&"high_atk", 50, 30, 2)
	t1.front_slot = true
	var t2 := _make_normal_template(&"high_def", 50, 5, 20)
	var t3 := _make_normal_template(&"mid", 50, 15, 10)
	var t4 := _make_normal_template(&"mid2", 50, 18, 8)
	_inject_templates([t1, t2, t3, t4])
	var roster = ai.call("create_enemy_roster", [t1.template_id, t2.template_id, t3.template_id, t4.template_id], 1)
	# 找到 front_slot=true 的实例
	var forced_front: Object = null
	for state in roster:
		if str(state.template_id) == "high_atk":
			forced_front = state
			break
	assert_not_null(forced_front, "找到 front_slot=true 实例")
	assert_true(forced_front.is_front_row, "front_slot=true 强制前排")


func test_assign_positions_4_enemies_split_front_back() -> void:
	# 4 敌人：防御 20/15/10/5，攻击 5/8/12/20
	var t1 := _make_normal_template(&"d20", 50, 5, 20)
	var t2 := _make_normal_template(&"d15", 50, 8, 15)
	var t3 := _make_normal_template(&"d10", 50, 12, 10)
	var t4 := _make_normal_template(&"d5", 50, 20, 5)
	_inject_templates([t1, t2, t3, t4])
	var roster = ai.call("create_enemy_roster", [t1.template_id, t2.template_id, t3.template_id, t4.template_id], 1)
	var front_count: int = 0
	var back_count: int = 0
	for state in roster:
		if state.is_front_row:
			front_count += 1
		else:
			back_count += 1
	assert_eq(front_count, 3, "前排 3 人（FRONT_CAPACITY=3）")
	assert_eq(back_count, 1, "后排 1 人")
	# 防御最低的 d5 应在后排
	for state in roster:
		if str(state.template_id) == "d5":
			assert_false(state.is_front_row, "防御最低的 d5 在后排")


# ============================================================================
# AC-009：≤2 人全部前排
# ============================================================================

func test_assign_positions_2_enemies_all_front() -> void:
	var t1 := _make_normal_template(&"e1", 50, 10, 10)
	var t2 := _make_normal_template(&"e2", 50, 20, 5)
	_inject_templates([t1, t2])
	var roster = ai.call("create_enemy_roster", [t1.template_id, t2.template_id], 1)
	assert_eq(roster.size(), 2, "roster 2 个实例")
	for state in roster:
		assert_true(state.is_front_row, "2 人全部前排")
	assert_eq(roster[0].field_position, 0, "e1 field_position=0")
	assert_eq(roster[1].field_position, 1, "e2 field_position=1")


func test_assign_positions_1_enemy_all_front() -> void:
	var t1 := _make_normal_template(&"solo", 50, 10, 10)
	_inject_templates([t1])
	var roster = ai.call("create_enemy_roster", [t1.template_id], 1)
	assert_eq(roster.size(), 1, "roster 1 个实例")
	assert_true(roster[0].is_front_row, "1 人全部前排")
	assert_eq(roster[0].field_position, 0, "field_position=0")


# ============================================================================
# AC-010：formation_limit 默认值
# ============================================================================

func test_formation_limit_normal_zero() -> void:
	var t := _make_normal_template(&"normal", 50, 10, 5)
	assert_eq(t.formation_limit, 0, "普通敌人 formation_limit=0")
	var state = ai.call("create_state", t)
	assert_eq(state.template.formation_limit, 0, "实例模板 formation_limit=0")


func test_formation_limit_elite_one() -> void:
	var t := _make_elite_template(&"elite", 100, 20, 10)
	assert_eq(t.formation_limit, 1, "精英敌人 formation_limit=1")
	var state = ai.call("create_state", t)
	assert_eq(state.template.formation_limit, 1, "实例模板 formation_limit=1")


func test_formation_limit_boss_two() -> void:
	var t := _make_boss_template(&"boss", 200, 30, 15)
	assert_eq(t.formation_limit, 2, "Boss 敌人 formation_limit=2")
	var state = ai.call("create_state", t)
	assert_eq(state.template.formation_limit, 2, "实例模板 formation_limit=2")


# ============================================================================
# 综合验证：boss 模板完整字段
# ============================================================================

func test_boss_template_full_fields() -> void:
	var t := _make_boss_template(&"moyuan", 200, 30, 15)
	assert_eq(str(t.template_id), "moyuan", "template_id")
	assert_true(t.is_boss, "is_boss=true")
	assert_eq(t.formation_limit, 2, "formation_limit=2")
	assert_true(t.front_slot, "front_slot=true（Boss 固定前排）")
	assert_eq(t.preconfigured_bindings.size(), 2, "预配置绑定 2 个")
	assert_eq(t.phase_transitions.size(), 1, "阶段转换 1 个")
	var pt = t.phase_transitions[0]
	assert_eq(pt.hp_below, 0.5, "阶段转换 hp_below=0.5")
	assert_eq(pt.skill_unlock.size(), 1, "解锁技能 1 个")
	assert_true(pt.reset_cooldowns, "重置冷却")
	assert_eq(pt.heal_percent, 0.1, "治疗 10%")
