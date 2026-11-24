extends GutTest
## CombatSystem 公开面锁定守卫——拆分重构前置护栏。
##
## [b]为什么需要这条守卫[/b]：[code]src/feature/combat_system.gd[/code]（1222 行）要按职责拆成
## 继承链。拆分的唯一硬约束是「对外 API 逐位不变」——方法名、形参个数、默认参数个数[b]与值[/b]、
## 枚举取值、信号载荷个数、脚本常量、实例字段，一个都不许改。危险在于[b]编译器不会替我们发现断链[/b]：
## 产品代码、约 50 个既有测试文件、以及 16 个 RefCounted 子模块全靠动态分派访问这个面——
## [code]cs.call("advance_phase")[/code] / [code]cs.get("_phase")[/code] /
## [code]cs.set("_attack_queue", ...)[/code] / [code]CS_SCRIPT.CombatResult.VICTORY[/code] /
## [code]_parent.call("_emit_safe", ...)[/code]，名字打错或漏拆只是运行时 push_error /
## 静默返回 null，不报语法错。故先把「面」钉成反射快照，拆完复跑。
##
## [b]锁什么[/b]：
##   · 46 个公开方法 + 98 个私有方法的[形参个数 / 默认参数个数 / 默认参数值]
##   · [enum CombatPhase] 7 项 + [enum CombatResult] 4 项的取值（产品代码按名直取）
##   · 9 个 Cat 2b 信号的载荷参数个数
##   · 4 个脚本常量仍可解析且指向同一路径（子模块 preload 与外部 [code]CombatScript[/code] 引用）
##   · 45 个实例字段存在且[b]未被 static 化[/b]（两个实例互不影响）
##   · 面内不得出现未登记的方法（新增/改名都要显式更新本快照）
##   · 面仍然可调用（set_battle_active → advance_phase → 查询 一趟真行为）
##
## [b]不锁什么[/b]：函数体实现、注释、成员落在哪个文件——这些正是拆分要动的东西。
##
## 来源: .claude/docs/coding-standards.md §文件行数限制（300 行软上限）、ADR-0008 §关键接口。

const CS_SCRIPT := preload("res://src/feature/combat_system.gd")

## 公开方法快照——{方法名: [形参个数, [默认参数值...]]}。
const EXPECTED_PUBLIC: Dictionary = {
	"add_card_to_deck": [1, []], "add_card_to_discard": [1, []],
	"advance_phase": [0, []], "battle_end": [1, []],
	"battle_start": [1, []], "calculate_damage": [5, [null]],
	"confirm_attack_targets": [0, []], "confirm_end_turn": [0, []],
	"confirm_retreat": [0, []], "deal_opening_hand": [0, []],
	"discard_card": [1, []], "get_attack_queue": [0, []],
	"get_battle_config": [0, []], "get_battle_enemy_roster": [0, []],
	"get_character_hp": [1, []], "get_current_phase": [0, []],
	"get_damage_settlement": [0, []], "get_deck": [0, []],
	"get_discard_pile": [0, []], "get_hand": [0, []],
	"get_roster_state": [0, []], "get_turn_number": [0, []],
	"grant_reward_selection": [1, []], "init_deck": [1, []],
	"is_battle_active": [0, []], "is_character_alive": [1, []],
	"play_card": [3, [-1]], "play_card_detailed": [3, [-1]],
	"reset_reward_rng": [0, []], "restore_battle_state": [4, []],
	"restore_piles": [3, []], "resume_auto_advance": [0, []],
	"retreat": [0, []], "set_attack_queue": [1, []],
	"set_auto_advance": [1, []], "set_battle_active": [2, [1]],
	"set_card_instances": [1, []], "set_deck_state": [3, []],
	"set_hand": [1, []], "set_reward_rng": [1, []],
	"set_reward_rng_seed": [1, []], "set_rng_seed": [1, []],
	"set_scene_change": [1, []], "set_scene_manager": [1, []],
	"set_timer_exceeded": [0, []], "shuffle_discard_into_deck": [0, []],
}

## 私有方法快照——测试与 16 个 RefCounted 子模块经 [code].call("_xxx")[/code] /
## [code].get("_xxx")[/code] 访问，同属「面」，一并锁。
const EXPECTED_PRIVATE: Dictionary = {
	"_ready": [0, []], "_all_characters_targeted": [0, []], "_apply_victory_rewards": [1, []],
	"_build_battle_record": [1, []], "_build_field_state": [0, []], "_calculate_card_drops": [0, []],
	"_calculate_cultivation_reward": [0, []], "_calculate_draw_count": [0, []], "_calculate_lingshi_reward": [0, []],
	"_can_afford": [1, []], "_can_afford_any_card": [0, []], "_capture_battle_rosters": [1, []],
	"_check_and_process_deaths": [1, []], "_check_battle_end": [0, []], "_clear_animation_lock": [0, []],
	"_clear_battle_snapshot": [0, []], "_clear_cost_for_battle": [0, []], "_clear_rolled_rewards_from_gsm": [0, []],
	"_clear_standby_state": [0, []], "_compute_next_phase": [1, []], "_configured_rewards": [0, []],
	"_connect_death_cleanup": [0, []], "_create_battle_snapshot": [0, []], "_draw_cards": [1, []],
	"_emit_safe": [2, []], "_emit_turn_started": [0, []], "_enter_phase": [1, []],
	"_execute_ai_turn": [0, []], "_exit_phase": [1, []], "_extract_character_id": [1, []],
	"_finish_pending_battle_end": [0, []], "_get_ai_system": [0, []], "_get_attack_coverage": [0, []],
	"_get_battle_record": [0, []], "_get_battle_wiring": [0, []], "_get_card_cost": [1, []],
	"_get_card_effect_engine": [0, []], "_get_card_instance": [1, []], "_get_card_resolver": [0, []],
	"_get_card_system": [0, []], "_get_cost_system": [0, []], "_get_cultivation_system": [0, []],
	"_get_damage_calculator": [0, []], "_get_damage_settlement": [0, []], "_get_deployment_system": [0, []],
	"_get_enemy_turn": [0, []], "_get_field_characters": [0, []], "_get_gsm": [0, []],
	"_get_hp_carryover": [0, []], "_get_input_manager": [0, []], "_get_lifecycle": [0, []],
	"_get_phase_manager": [0, []], "_get_phase_sequencer": [0, []], "_get_piles": [0, []],
	"_get_realm_penalty": [2, []], "_get_realm_system": [0, []], "_get_resource_system": [0, []],
	"_get_rewards": [0, []], "_get_roster_ops": [0, []], "_get_roster_state": [0, []],
	"_get_save_load": [0, []], "_get_scene_manager": [0, []], "_get_side_effects": [0, []],
	"_get_status_effect_system": [0, []], "_gsm_increment_battle_turn": [0, []], "_gsm_set_battle_active": [1, []],
	"_gsm_set_battle_phase": [1, []], "_gsm_set_battle_resume": [1, []], "_gsm_set_battle_turn": [1, []],
	"_init_cost_for_battle": [0, []], "_is_first_player": [0, []], "_is_rewards_settled": [0, []],
	"_load_rolled_rewards": [0, []], "_mark_dead_characters_unavailable": [1, []], "_mark_rewards_settled": [0, []],
	"_note_effect_entry": [0, []], "_persist_rolled_rewards": [1, []], "_push_animation_lock": [0, []],
	"_read_cost_cap": [0, []], "_read_player_field": [0, []], "_remove_card_from_hand": [1, []],
	"_request_scene_change": [1, []], "_reset_cost_for_turn": [0, []], "_resolve_attack_queue": [0, []],
	"_resolve_effects": [2, []], "_resolve_targets": [2, []], "_schedule_auto_advance": [0, []],
	"_seed_reward_rng": [0, []], "_seed_roster_state": [1, []], "_settle_attack_damage": [1, []],
	"_settle_result": [1, []], "_spend": [1, []], "_sync_animation_lock": [1, []],
	"_tick_status_effects": [0, []], "_update_field_engaged": [1, []], "_validate_targets": [2, []],
	"_validate_transition": [2, []], "_warn_zero_hp_characters": [1, []],
}

## 信号载荷参数个数快照。
const EXPECTED_SIGNALS: Dictionary = {
	"phase_changed": 3, "battle_started": 1, "battle_ended": 2,
	"attack_resolved": 1, "character_damaged": 1, "character_died": 3,
	"retreat_requested": 0, "turn_started": 1, "enemy_action_resolved": 1,
}

## 脚本常量快照——值即契约（四个 preload 常量被子模块与外部按名引用）。
const EXPECTED_CONSTANTS: Dictionary = {
	"HpCarryoverScript": "res://src/feature/combat/combat_hp_carryover.gd", "TurnEconomy": "res://src/feature/combat/combat_turn_economy.gd",
	"RewardRoller": "res://src/feature/combat/combat_reward_roller.gd", "AutoloadAccess": "res://src/feature/combat/combat_autoload_access.gd",
}

## 实例字段快照——拆分后仍是[b]实例[/b]字段（不得因搬文件误写成 static）。
const EXPECTED_FIELDS: Array[String] = [
	"_attack_coverage", "_attack_queue", "_auto_advance_enabled",
	"_battle_config", "_battle_enemy_roster", "_battle_player_roster",
	"_battle_record", "_battle_serial", "_battle_wiring",
	"_card_instances", "_card_resolver", "_damage_calculator",
	"_damage_settlement", "_deck", "_discard_pile",
	"_enemy_turn", "_field_engaged", "_hand",
	"_hp_carryover", "_is_active", "_lifecycle",
	"_pending_battle_result", "_phase", "_phase_manager",
	"_phase_sequencer", "_phase_timer_exceeded", "_piles",
	"_player_confirmed_attack_skip", "_player_confirmed_end", "_reward_battle_count",
	"_reward_rng", "_reward_rng_explicit", "_rewards",
	"_rewards_settled_for", "_rng", "_rolled_rewards",
	"_roster_ops", "_roster_state", "_scene_change_enabled",
	"_scene_manager_override", "_side_effects", "_turn",
	"get_card_instance_cb", "resolve_cb", "validate_targets_cb",
]

var cs: Node = null


func before_each() -> void:
	cs = CS_SCRIPT.new()


func after_each() -> void:
	if cs != null:
		cs.free()
		cs = null


## 反射收集方法表——[code]name -> {args, default_args}[/code]。
func _method_table() -> Dictionary:
	var table: Dictionary = {}
	for m: Dictionary in cs.get_method_list():
		table[String(m["name"])] = m
	return table


## 逐一比对快照中的方法：存在 + 形参个数 + 默认参数个数 + 默认参数值。
func _assert_methods(snapshot: Dictionary, label: String) -> void:
	var table: Dictionary = _method_table()
	var checked: int = 0
	for method_name: String in snapshot:
		var expected: Array = snapshot[method_name]
		assert_true(table.has(method_name), "%s方法 %s 应存在（拆分后不得丢）" % [label, method_name])
		if not table.has(method_name):
			continue
		var entry: Dictionary = table[method_name]
		var args: Array = entry.get("args", [])
		var defaults: Array = entry.get("default_args", [])
		var want_defaults: Array = expected[1]
		assert_eq(args.size(), int(expected[0]),
			"%s方法 %s 形参个数应不变" % [label, method_name])
		assert_eq(defaults.size(), want_defaults.size(),
			"%s方法 %s 默认参数个数应不变" % [label, method_name])
		assert_eq(defaults, want_defaults,
			"%s方法 %s 默认参数值应逐位不变" % [label, method_name])
		checked += 1
	assert_eq(checked, snapshot.size(), "%s方法快照应全部比对到" % label)


# ============================================================================
# 1. 方法面：46 公开 + 98 私有，签名逐位不变
# ============================================================================

func test_public_methods_locked() -> void:
	assert_eq(EXPECTED_PUBLIC.size(), 46, "公开方法快照应 46 个")
	_assert_methods(EXPECTED_PUBLIC, "公开")


func test_private_methods_locked() -> void:
	assert_eq(EXPECTED_PRIVATE.size(), 98, "私有方法快照应 98 个")
	_assert_methods(EXPECTED_PRIVATE, "私有")


func test_no_untracked_script_methods() -> void:
	# 面内不得出现未登记的方法——新增/改名都要显式更新本快照。
	# 判据：get_method_list() 减去 Node 及其祖先的内建方法，再减去已登记快照。
	var builtin: Dictionary = {}
	for m: Dictionary in ClassDB.class_get_method_list(&"Node"):
		builtin[String(m["name"])] = true
	var untracked: Array[String] = []
	for m: Dictionary in cs.get_method_list():
		var method_name: String = String(m["name"])
		if builtin.has(method_name):
			continue
		if EXPECTED_PUBLIC.has(method_name) or EXPECTED_PRIVATE.has(method_name):
			continue
		if untracked.has(method_name):
			continue
		untracked.append(method_name)
	assert_eq(untracked.size(), 0, "不应出现未登记的方法：%s" % str(untracked))


# ============================================================================
# 2. 枚举面：CombatPhase 7 项 + CombatResult 4 项，取值即契约
# ============================================================================

func test_combat_phase_enum_locked() -> void:
	assert_eq(CS_SCRIPT.CombatPhase.PREPARATION, 0, "PREPARATION=0")
	assert_eq(CS_SCRIPT.CombatPhase.DRAW, 1, "DRAW=1")
	assert_eq(CS_SCRIPT.CombatPhase.PLAY, 2, "PLAY=2")
	assert_eq(CS_SCRIPT.CombatPhase.ATTACK_DECLARATION, 3, "ATTACK_DECLARATION=3")
	assert_eq(CS_SCRIPT.CombatPhase.ATTACK_RESOLUTION, 4, "ATTACK_RESOLUTION=4")
	assert_eq(CS_SCRIPT.CombatPhase.ENEMY_TURN, 5, "ENEMY_TURN=5")
	assert_eq(CS_SCRIPT.CombatPhase.END, 6, "END=6")
	assert_eq((CS_SCRIPT.CombatPhase as Dictionary).size(), 7, "CombatPhase 应恰好 7 项")


func test_combat_result_enum_locked() -> void:
	assert_eq(CS_SCRIPT.CombatResult.NONE, 0, "NONE=0")
	assert_eq(CS_SCRIPT.CombatResult.VICTORY, 1, "VICTORY=1")
	assert_eq(CS_SCRIPT.CombatResult.DEFEAT, 2, "DEFEAT=2")
	assert_eq(CS_SCRIPT.CombatResult.RETREAT, 3, "RETREAT=3")
	assert_eq((CS_SCRIPT.CombatResult as Dictionary).size(), 4, "CombatResult 应恰好 4 项")


# ============================================================================
# 3. 信号面：9 个 Cat 2b 信号，载荷个数逐位不变
# ============================================================================

func test_signals_locked() -> void:
	var table: Dictionary = {}
	for s: Dictionary in cs.get_signal_list():
		table[String(s["name"])] = s
	for signal_name: String in EXPECTED_SIGNALS:
		assert_true(table.has(signal_name), "信号 %s 应存在" % signal_name)
		if not table.has(signal_name):
			continue
		var args: Array = table[signal_name].get("args", [])
		assert_eq(args.size(), int(EXPECTED_SIGNALS[signal_name]),
			"信号 %s 载荷个数应不变" % signal_name)


# ============================================================================
# 4. 常量面：四个 preload 常量仍解析到同一路径
# ============================================================================

func test_constants_locked() -> void:
	# 逐名直取（产品代码与子模块的写法）——常量沿继承链解析。
	# [b]不用[/b] [method Script.get_script_constant_map]：它只列出[b]本文件[/b]声明的常量，
	# 拆分后返回空表（探针实测），会把「常量搬到了祖先段」误判成「常量丢了」——
	# 而沿链直取恰恰是拆分要保住的那个行为。
	assert_eq((CS_SCRIPT.HpCarryoverScript as Script).resource_path, EXPECTED_CONSTANTS["HpCarryoverScript"],
		"常量 HpCarryoverScript 应仍指向同一路径")
	assert_eq((CS_SCRIPT.TurnEconomy as Script).resource_path, EXPECTED_CONSTANTS["TurnEconomy"],
		"常量 TurnEconomy 应仍指向同一路径")
	assert_eq((CS_SCRIPT.RewardRoller as Script).resource_path, EXPECTED_CONSTANTS["RewardRoller"],
		"常量 RewardRoller 应仍指向同一路径")
	assert_eq((CS_SCRIPT.AutoloadAccess as Script).resource_path, EXPECTED_CONSTANTS["AutoloadAccess"],
		"常量 AutoloadAccess 应仍指向同一路径")
	assert_eq(EXPECTED_CONSTANTS.size(), 4, "常量快照应 4 个")
	# 实例经 Object.get 取同名常量——子模块的取用方式，也须解析
	assert_not_null(cs.get("TurnEconomy"), "实例 get(\"TurnEconomy\") 仍可解析")


# ============================================================================
# 5. 字段面：45 个实例字段在册，且仍是实例字段（未被 static 化）
# ============================================================================

func test_instance_fields_locked() -> void:
	var found: Dictionary = {}
	for p: Dictionary in cs.get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE != 0:
			found[String(p["name"])] = true
	for field_name: String in EXPECTED_FIELDS:
		assert_true(found.has(field_name), "实例字段 %s 应存在" % field_name)
	assert_eq(found.size(), EXPECTED_FIELDS.size(),
		"脚本实例字段应恰好 %d 个：%s" % [EXPECTED_FIELDS.size(), str(found.keys())])


func test_fields_not_staticized() -> void:
	# 两个实例互不影响——若拆分时把 var 误写成 static var，此处立刻变红。
	var other: Node = CS_SCRIPT.new()
	cs.set("_turn", 9)
	assert_eq(other.get("_turn"), 1, "另一实例的 _turn 不受影响")

	cs.set("_is_active", true)
	assert_false(other.get("_is_active"), "另一实例的 _is_active 不受影响")

	var mine_queue: Array = cs.get("_attack_queue")
	mine_queue.append({"attacker_id": 1})
	assert_eq((other.get("_attack_queue") as Array).size(), 0, "另一实例的 _attack_queue 不受影响")

	var mine_deck: Array = cs.get("_deck")
	mine_deck.append(777)
	assert_eq((other.get("_deck") as Array).size(), 0, "另一实例的 _deck 不受影响")

	var mine_config: Dictionary = cs.get("_battle_config")
	mine_config["probe"] = true
	assert_false((other.get("_battle_config") as Dictionary).has("probe"),
		"另一实例的 _battle_config 不受影响")

	cs.set("_scene_manager_override", cs)
	assert_null(other.get("_scene_manager_override"), "另一实例的注入覆盖不受影响")

	var cb: Callable = func() -> void: pass
	cs.set("validate_targets_cb", cb)
	assert_false(other.get("validate_targets_cb").is_valid(), "另一实例的存根回调不受影响")

	other.free()


# ============================================================================
# 6. 面仍然可调用：开战 → 推进 → 查询 一趟真行为
# ============================================================================

func test_face_still_callable_end_to_end() -> void:
	cs.call("set_auto_advance", false)
	cs.call("set_scene_change", false)
	cs.call("set_battle_active", true)
	assert_true(cs.call("is_battle_active"), "set_battle_active 仍可用")
	assert_eq(cs.call("get_current_phase"), 0, "开战落位 PREPARATION")
	assert_eq(cs.call("get_turn_number"), 1, "开战回合数为 1")

	cs.call("set_rng_seed", 42)
	cs.call("init_deck", [11, 12, 13, 14, 15])
	assert_eq((cs.call("get_deck") as Array).size(), 5, "init_deck 仍可用")
	cs.call("set_hand", [901])
	assert_eq((cs.call("get_hand") as Array).size(), 1, "set_hand 仍可用")
	cs.call("set_attack_queue", [{"attacker_id": 1, "target_id": 2}])
	assert_eq((cs.call("get_attack_queue") as Array).size(), 1, "set_attack_queue 仍可用")

	var moved: bool = cs.call("advance_phase")
	assert_true(moved, "advance_phase 仍可推进")
	assert_eq(cs.call("get_current_phase"), 1, "推进后进入 DRAW")

	cs.call("set_timer_exceeded")
	cs.call("set_battle_active", false)
	assert_false(cs.call("is_battle_active"), "关战仍可用")

	var damage: Dictionary = cs.call("calculate_damage", 100, 20, 1, 1)
	assert_true(damage.has("final_damage"), "calculate_damage 仍返回具名字典")
