extends GutTest
## Story 004 验收测试：难度缩放 + register_preconfigured_bindings。
##
## 覆盖 AC-001 到 AC-011（11 条 AC）。
## 测试策略：
##   - AISystem 用 AI_SCRIPT.new() + var ai: Node 持有
##   - 手动注入 _template_registry 以绕过 load_templates 目录扫描
##   - 缩放公式为纯函数——直接调用 _apply_difficulty_scaling
##   - 预配置绑定注册用 MockBindingManager 挂载到 SceneTree root——验证调用次数与参数
##
## 设计文档来源：ADR-0017 §关键接口 _apply_difficulty_scaling / register_preconfigured_bindings
## Story 来源：production/epics/ai-system/story-004-difficulty-scaling.md

const AI_SCRIPT := preload("res://src/feature/ai_system.gd")
const EnemyTemplate := preload("res://assets/enemies/enemy_template.gd")
const BehaviorProfile := preload("res://assets/enemies/behavior_profile.gd")
const SkillEntry := preload("res://assets/enemies/skill_entry.gd")
const MockBindingManager := preload("res://tests/fixtures/mock_binding_manager.gd")

var ai: Node = null
var _mock_bm: Node = null


func before_each() -> void:
	ai = AI_SCRIPT.new()
	_mock_bm = _create_mock_bm()


func after_each() -> void:
	if _mock_bm != null:
		_mock_bm.get_parent().remove_child(_mock_bm)
		_mock_bm.queue_free()
		_mock_bm = null
	if ai != null:
		ai.free()
		ai = null


## 创建 MockBindingManager 并挂载到 SceneTree root 作为 /root/BindingManager。
func _create_mock_bm() -> Node:
	var bm := MockBindingManager.new()
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(bm, false)
	bm.name = "BindingManager"
	return bm


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
	t.skill_pool = [_make_skill(&"basic_attack", "基础攻击", SkillEntry.SkillType.ATTACK, 50, 1, 0, SkillEntry.TargetType.SINGLE_ENEMY)]
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
	t.skill_pool = [_make_skill(&"yuehua_zhan", "月华斩", SkillEntry.SkillType.ATTACK, 40, 1, 0, SkillEntry.TargetType.SINGLE_ENEMY)]
	t.preconfigured_bindings = [&"gongfa_xuanbing"]
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
	t.skill_pool = [_make_skill(&"duoming_zhua", "夺命爪", SkillEntry.SkillType.ATTACK, 35, 1, 0, SkillEntry.TargetType.SINGLE_ENEMY)]
	t.preconfigured_bindings = [&"gongfa_moyuan", &"fabao_hunying"]
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


## 注入模板到注册表（绕过 load_templates 目录扫描）。
func _inject_templates(templates: Array) -> void:
	var registry: Dictionary = ai.get("_template_registry")
	registry.clear()
	for t in templates:
		registry[t.template_id] = t


# ============================================================================
# AC-001：难度缩放公式 scale = 1.0 + (player_realm - enemy_realm) × 0.3
# ============================================================================

func test_scale_formula_gap_2() -> void:
	var t := _make_normal_template(&"test", 100, 20, 10)
	# player_realm=3, enemy_realm=1, gap=2 → scale=1.0+2×0.3=1.6
	var result: Dictionary = ai.call("_apply_difficulty_scaling", t, 3)
	assert_eq(result["max_hp"], 160, "gap=2 → max_hp=160（100×1.6）")
	assert_eq(result["attack"], 32, "gap=2 → attack=32（20×1.6）")
	assert_eq(result["defense"], 16, "gap=2 → defense=16（10×1.6）")


func test_scale_formula_gap_3() -> void:
	var t := _make_normal_template(&"test", 100, 20, 10)
	# player_realm=4, enemy_realm=1, gap=3 → scale=1.0+3×0.3=1.9
	var result: Dictionary = ai.call("_apply_difficulty_scaling", t, 4)
	assert_eq(result["max_hp"], 190, "gap=3 → max_hp=190（100×1.9）")
	assert_eq(result["attack"], 38, "gap=3 → attack=38（20×1.9）")
	assert_eq(result["defense"], 19, "gap=3 → defense=19（10×1.9）")


# ============================================================================
# AC-002：缩放应用（round 取整）
# ============================================================================

func test_scaling_rounds_correctly() -> void:
	var t := _make_normal_template(&"test", 105, 21, 11)
	# player_realm=3, enemy_realm=1, gap=2 → scale=1.6
	# 105×1.6=168.0 → 168; 21×1.6=33.6 → 34; 11×1.6=17.6 → 18
	var result: Dictionary = ai.call("_apply_difficulty_scaling", t, 3)
	assert_eq(result["max_hp"], 168, "105×1.6=168.0 → round=168")
	assert_eq(result["attack"], 34, "21×1.6=33.6 → round=34")
	assert_eq(result["defense"], 18, "11×1.6=17.6 → round=18")


# ============================================================================
# AC-003：player_realm <= enemy_realm → 不缩放
# ============================================================================

func test_no_scaling_when_realm_equal() -> void:
	var t := _make_normal_template(&"test", 100, 20, 10)
	t.realm = 3
	# player_realm=3, enemy_realm=3 → 不缩放
	var result: Dictionary = ai.call("_apply_difficulty_scaling", t, 3)
	assert_eq(result["max_hp"], 100, "realm 相等 → max_hp=base")
	assert_eq(result["attack"], 20, "realm 相等 → attack=base")
	assert_eq(result["defense"], 10, "realm 相等 → defense=base")


func test_no_scaling_when_player_lower() -> void:
	var t := _make_normal_template(&"test", 100, 20, 10)
	t.realm = 3
	# player_realm=1, enemy_realm=3 → 玩家低于敌人 → 不缩放
	var result: Dictionary = ai.call("_apply_difficulty_scaling", t, 1)
	assert_eq(result["max_hp"], 100, "player < enemy → max_hp=base")
	assert_eq(result["attack"], 20, "player < enemy → attack=base")
	assert_eq(result["defense"], 10, "player < enemy → defense=base")


# ============================================================================
# AC-004：境界来源通过参数传入（由调用方从 RealmSystem 获取）
# ============================================================================

func test_player_realm_passed_as_parameter() -> void:
	# AC-004 验证缩放函数接受 player_realm 参数（由调用方从 RealmSystem 获取）
	var t := _make_normal_template(&"test", 100, 20, 10)
	# 不同 player_realm 产生不同缩放——证明参数驱动
	var r1: Dictionary = ai.call("_apply_difficulty_scaling", t, 1)
	var r3: Dictionary = ai.call("_apply_difficulty_scaling", t, 3)
	assert_eq(r1["max_hp"], 100, "player_realm=1 → 不缩放")
	assert_eq(r3["max_hp"], 160, "player_realm=3 → 缩放 1.6")


# ============================================================================
# AC-005：缩放时机在 create_enemy_roster 时（阵位分配前）
# ============================================================================

func test_scaling_applied_in_create_enemy_roster() -> void:
	var t := _make_normal_template(&"test", 100, 20, 10)
	_inject_templates([t])
	var roster = ai.call("create_enemy_roster", [&"test"], 3)
	assert_eq(roster.size(), 1, "roster 1 个实例")
	var state = roster[0]
	# player_realm=3, enemy_realm=1 → scale=1.6
	assert_eq(state.max_hp, 160, "create_enemy_roster 后 max_hp=160")
	assert_eq(state.current_hp, 160, "current_hp=max_hp=160")
	assert_eq(state.attack, 32, "attack=32")
	assert_eq(state.defense, 16, "defense=16")


func test_scaling_before_position_assignment() -> void:
	# 缩放在阵位分配前——分配基于 template.base_defense（原值），缩放值写入实例
	var t1 := _make_normal_template(&"d20", 50, 5, 20)
	var t2 := _make_normal_template(&"d5", 50, 20, 5)
	_inject_templates([t1, t2])
	var roster = ai.call("create_enemy_roster", [&"d20", &"d5"], 3)
	# 缩放后 t1.defense=32, t2.defense=8——但分配基于 template.base_defense
	var d20_state = null
	var d5_state = null
	for state in roster:
		if str(state.template_id) == "d20":
			d20_state = state
		elif str(state.template_id) == "d5":
			d5_state = state
	assert_not_null(d20_state, "找到 d20")
	assert_not_null(d5_state, "找到 d5")
	assert_true(d20_state.is_front_row, "d20 防御高 → 前排")
	assert_eq(d20_state.defense, 32, "d20 缩放后 defense=32")


# ============================================================================
# AC-006：register_preconfigured_bindings 调用 BindingManager.bind_card
# ============================================================================

func test_register_preconfigured_bindings_method_exists() -> void:
	assert_true(ai.has_method("register_preconfigured_bindings"), "register_preconfigured_bindings 方法存在")


func test_elite_register_calls_bind_card_once() -> void:
	# AC-006/008：精英 1 条预配置绑定 → bind_card 调用 1 次
	_mock_bm.call("reset")
	# 先设置 _enemy_roster 以使 register_preconfigured_bindings 能找到 enemy 索引
	var t := _make_elite_template(&"elite_1", 100, 20, 10)
	var state = ai.call("create_state", t)
	ai.call("set_enemy_roster", [state])
	ai.call("register_preconfigured_bindings", state)
	assert_eq(_mock_bm.call("get_bind_card_call_count"), 1, "精英 1 条绑定 → bind_card 调用 1 次")
	var calls = _mock_bm.call("get_bind_card_calls")
	var call: Dictionary = calls[0]
	assert_eq(str(call["template_id"]), "gongfa_xuanbing", "template_id 正确")
	assert_eq(call["slot_type"], 0, "slot_type=GONGFA")
	assert_true(call["character_id"] >= 100000, "character_id 在敌方 ID 范围（>=100000）")
	assert_true(call["card_instance_id"] > 0, "card_instance_id 为正整数")


func test_boss_register_calls_bind_card_twice() -> void:
	# AC-006/009：Boss 2 条预配置绑定 → bind_card 调用 2 次
	_mock_bm.call("reset")
	var t := _make_boss_template(&"boss_1", 200, 30, 15)
	var state = ai.call("create_state", t)
	ai.call("set_enemy_roster", [state])
	ai.call("register_preconfigured_bindings", state)
	assert_eq(_mock_bm.call("get_bind_card_call_count"), 2, "Boss 2 条绑定 → bind_card 调用 2 次")
	var calls = _mock_bm.call("get_bind_card_calls")
	assert_eq(str(calls[0]["template_id"]), "gongfa_moyuan", "第 1 个绑定 ID")
	assert_eq(str(calls[1]["template_id"]), "fabao_hunying", "第 2 个绑定 ID")
	# 两个 card_instance_id 不同（唯一性）
	assert_ne(calls[0]["card_instance_id"], calls[1]["card_instance_id"], "两个 card_instance_id 不同")
	# character_id 相同（同一敌人）
	assert_eq(calls[0]["character_id"], calls[1]["character_id"], "同一 Boss character_id 相同")


# ============================================================================
# AC-007：普通敌人无预配置绑定 → bind_card 零调用
# ============================================================================

func test_normal_enemy_empty_bindings() -> void:
	var t := _make_normal_template(&"normal", 100, 20, 10)
	assert_eq((t.preconfigured_bindings as Array).size(), 0, "普通敌人 preconfigured_bindings 为空")


func test_normal_enemy_register_zero_calls() -> void:
	# AC-007：普通敌人 preconfigured_bindings 为空 → bind_card 零调用（用 mock 验证）
	_mock_bm.call("reset")
	var t := _make_normal_template(&"normal", 100, 20, 10)
	var state = ai.call("create_state", t)
	ai.call("set_enemy_roster", [state])
	ai.call("register_preconfigured_bindings", state)
	assert_eq(_mock_bm.call("get_bind_card_call_count"), 0, "普通敌人无预配置绑定 → bind_card 零调用")


# ============================================================================
# AC-008：精英预配置绑定注册到 BindingManager
# ============================================================================

func test_elite_has_preconfigured_bindings() -> void:
	var t := _make_elite_template(&"elite_1", 100, 20, 10)
	assert_eq((t.preconfigured_bindings as Array).size(), 1, "精英 1 个预配置绑定")
	assert_eq(str(t.preconfigured_bindings[0]), "gongfa_xuanbing", "绑定 ID 正确")


# ============================================================================
# AC-009：Boss 预配置绑定注册到 BindingManager
# ============================================================================

func test_boss_has_preconfigured_bindings() -> void:
	var t := _make_boss_template(&"boss_1", 200, 30, 15)
	assert_eq((t.preconfigured_bindings as Array).size(), 2, "Boss 2 个预配置绑定")
	assert_eq(str(t.preconfigured_bindings[0]), "gongfa_moyuan", "绑定 1 ID")
	assert_eq(str(t.preconfigured_bindings[1]), "fabao_hunying", "绑定 2 ID")


# ============================================================================
# AC-010：绑定在 create_enemy_roster 时自动注册（非战斗中打出）
# ============================================================================

func test_bindings_auto_registered_in_create_enemy_roster() -> void:
	# AC-010：预配置绑定在 create_enemy_roster 时自动注册（战前），非 execute_turn 时
	_mock_bm.call("reset")
	var t := _make_elite_template(&"elite_1", 100, 20, 10)
	_inject_templates([t])
	var roster = ai.call("create_enemy_roster", [&"elite_1"], 2)
	# create_enemy_roster 内自动调用了 register_preconfigured_bindings
	assert_eq(_mock_bm.call("get_bind_card_call_count"), 1, "create_enemy_roster 后 bind_card 调用 1 次（战前注册）")
	# 绑定不消耗费用、不占出牌机会——预配置，非 AI 决策产物
	assert_eq(str(roster[0].template.preconfigured_bindings[0]), "gongfa_xuanbing", "预配置绑定 ID")


# ============================================================================
# AC-011：阵亡移除绑定——调用 BindingManager.remove_all_bindings
# ============================================================================

func test_remove_enemy_bindings_method_exists() -> void:
	assert_true(ai.has_method("remove_enemy_bindings"), "remove_enemy_bindings 方法存在")


func test_remove_enemy_bindings_calls_remove_all() -> void:
	# AC-011：阵亡移除调用 remove_all_bindings
	_mock_bm.call("reset")
	var character_id: int = 100000
	ai.call("remove_enemy_bindings", character_id)
	assert_eq(_mock_bm.call("get_remove_all_call_count"), 1, "remove_all_bindings 调用 1 次")
	var calls = _mock_bm.call("get_remove_all_calls")
	assert_eq(calls[0], character_id, "character_id 正确传入")


func test_remove_after_register_clears_bindings() -> void:
	# AC-011：先注册绑定 → 再移除 → BM 中该角色绑定被清除
	_mock_bm.call("reset")
	var t := _make_elite_template(&"elite_1", 100, 20, 10)
	var state = ai.call("create_state", t)
	ai.call("set_enemy_roster", [state])
	ai.call("register_preconfigured_bindings", state)
	assert_eq(_mock_bm.call("get_bind_card_call_count"), 1, "注册后 1 条绑定")
	# 阵亡移除
	var char_id: int = 100000  # 对应 roster_idx=0
	ai.call("remove_enemy_bindings", char_id)
	assert_eq(_mock_bm.call("get_remove_all_call_count"), 1, "移除调用 1 次")


# ============================================================================
# 综合：create_enemy_roster 全流程（缩放 + 阵位 + 绑定注册）
# ============================================================================

func test_create_enemy_roster_full_pipeline() -> void:
	var t1 := _make_normal_template(&"normal_1", 50, 10, 5)
	var t2 := _make_elite_template(&"elite_1", 100, 20, 10)
	var t3 := _make_boss_template(&"boss_1", 200, 30, 15)
	_inject_templates([t1, t2, t3])
	# player_realm=4 → t1 gap=3 scale=1.9, t2 gap=2 scale=1.6, t3 gap=1 scale=1.3
	var roster = ai.call("create_enemy_roster", [&"normal_1", &"elite_1", &"boss_1"], 4)
	assert_eq(roster.size(), 3, "roster 3 个实例")
	# 验证缩放
	var normal_state = null
	var elite_state = null
	var boss_state = null
	for state in roster:
		match str(state.template_id):
			"normal_1":
				normal_state = state
			"elite_1":
				elite_state = state
			"boss_1":
				boss_state = state
	assert_not_null(normal_state, "找到 normal_1")
	assert_not_null(elite_state, "找到 elite_1")
	assert_not_null(boss_state, "找到 boss_1")
	# normal: 50×1.9=95, 10×1.9=19, 5×1.9=9.5→10
	assert_eq(normal_state.max_hp, 95, "normal gap=3 → max_hp=95")
	assert_eq(normal_state.attack, 19, "normal gap=3 → attack=19")
	assert_eq(normal_state.defense, 10, "normal gap=3 → defense=10（round 9.5→10）")
	# elite: 100×1.6=160, 20×1.6=32, 10×1.6=16
	assert_eq(elite_state.max_hp, 160, "elite gap=2 → max_hp=160")
	assert_eq(elite_state.attack, 32, "elite gap=2 → attack=32")
	assert_eq(elite_state.defense, 16, "elite gap=2 → defense=16")
	# boss: 200×1.3=260, 30×1.3=39, 15×1.3=19.5→20
	assert_eq(boss_state.max_hp, 260, "boss gap=1 → max_hp=260")
	assert_eq(boss_state.attack, 39, "boss gap=1 → attack=39")
	assert_eq(boss_state.defense, 20, "boss gap=1 → defense=20（round 19.5→20）")
	# 3 人全部前排（≤3 人全前排扩展）
	for state in roster:
		assert_true(state.is_front_row, "3 人全部前排")
