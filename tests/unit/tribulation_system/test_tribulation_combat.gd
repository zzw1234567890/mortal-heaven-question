extends GutTest
## Story 002 验收测试：渡劫战斗委托 CombatSystem + 天雷 debuff。
##
## 覆盖 AC-001 到 AC-008（8 条 AC）。
## 测试策略：
##   - 使用 GSM Autoload + TribulationSystem 实例 + CombatSystem 实例
##   - 手动连接 battle_ended 信号
##   - 验证战斗委托 + 配置构建 + 雷伤纯函数 + Boss 配置查询
##
## 设计文档来源：GDD tribulation-system.md §3 渡劫战斗规则 + §公式 3
## Story 来源：production/epics/tribulation-system/story-002-tribulation-combat-lightning.md

const TS_SCRIPT := preload("res://src/feature/tribulation_system.gd")
const CS_SCRIPT := preload("res://src/feature/combat_system.gd")

var ts: Node = null
var cs: Node = null
var gsm: Node = null
var _battle_started_configs: Array = []
var _battle_ended_results: Array = []


func before_each() -> void:
	ts = TS_SCRIPT.new()
	cs = CS_SCRIPT.new()
	cs.call("set_auto_advance", false)
	cs.call("set_scene_change", false)
	ts.set("_combat_override", cs)  # 注入 CombatSystem 引用
	gsm = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/GameStateManager")
	if gsm == null:
		fail_test("GSM Autoload 未注册")
		return
	gsm.player.cultivation = 0
	gsm.player.max_cultivation = 1000
	gsm.player.cultivation_full = false
	gsm.player.realm = 1
	gsm.player.tribulation_state = 0
	gsm.player.consecutive_tribulation_failures = 0
	gsm.set("_signal_chain_depth", 0)
	gsm.get("_signal_router").set("_pending_changes", [])
	_battle_started_configs.clear()
	_battle_ended_results.clear()
	cs.battle_started.connect(_on_battle_started)
	cs.battle_ended.connect(_on_battle_ended)


func after_each() -> void:
	if cs != null:
		if cs.battle_started.is_connected(_on_battle_started):
			cs.battle_started.disconnect(_on_battle_started)
		if cs.battle_ended.is_connected(_on_battle_ended):
			cs.battle_ended.disconnect(_on_battle_ended)
		cs.free()
		cs = null
	if ts != null:
		ts.free()
		ts = null
	if gsm != null:
		gsm.player.cultivation = 0
		gsm.player.max_cultivation = 1000
		gsm.player.cultivation_full = false
		gsm.player.realm = 1
		gsm.player.tribulation_state = 0
		gsm.player.consecutive_tribulation_failures = 0
	_battle_started_configs.clear()
	_battle_ended_results.clear()


func _on_battle_started(config: Dictionary) -> void:
	_battle_started_configs.append(config.duplicate(true))


func _on_battle_ended(result: int, rewards: Dictionary) -> void:
	_battle_ended_results.append({"result": result, "rewards": rewards.duplicate(true)})


func _flush() -> void:
	await get_tree().process_frame


func _setup_preparing() -> void:
	gsm.player.cultivation = 1000
	gsm.player.max_cultivation = 1000
	ts.call("trigger_tribulation", TS_SCRIPT.TribulationType.NORMAL)


# ============================================================================
# AC-001：start_tribulation_combat 进入 IN_COMBAT + 调用 battle_start
# ============================================================================

func test_ac001_start_combat_enters_in_combat() -> void:
	_setup_preparing()
	await _flush()
	ts.call("start_tribulation_combat")
	await _flush()
	assert_eq(gsm.player.tribulation_state, TS_SCRIPT.TribulationState.IN_COMBAT, "start 后进入 IN_COMBAT")


func test_ac001_start_combat_calls_battle_start() -> void:
	_setup_preparing()
	await _flush()
	ts.call("start_tribulation_combat")
	await _flush()
	assert_eq(_battle_started_configs.size(), 1, "battle_start 被调用 1 次")


func test_ac001_start_combat_not_preparing_rejected() -> void:
	# NOT_READY 状态——不可启动
	ts.call("start_tribulation_combat")
	await _flush()
	assert_eq(gsm.player.tribulation_state, TS_SCRIPT.TribulationState.NOT_READY, "非 PREPARING 被拒绝")
	assert_eq(_battle_started_configs.size(), 0, "battle_start 未被调用")


# ============================================================================
# AC-002：_build_tribulation_config 返回正确结构
# ============================================================================

func test_ac002_config_structure() -> void:
	_setup_preparing()
	await _flush()
	ts.call("start_tribulation_combat")
	await _flush()
	assert_true(_battle_started_configs.size() > 0, "有配置")
	var config: Dictionary = _battle_started_configs[0]
	assert_true(config.has("is_tribulation"), "含 is_tribulation")
	assert_eq(config["is_tribulation"], true, "is_tribulation=true")
	assert_true(config.has("tribulation_data"), "含 tribulation_data")
	var trib_data: Dictionary = config["tribulation_data"]
	assert_true(trib_data.has("realm_level"), "含 realm_level")
	assert_true(trib_data.has("is_cross_realm"), "含 is_cross_realm")
	assert_true(trib_data.has("boss_config"), "含 boss_config")


func test_ac002_config_realm_level() -> void:
	gsm.player.cultivation = 1000
	gsm.player.max_cultivation = 1000
	gsm.player.realm = 2
	ts.call("trigger_tribulation", TS_SCRIPT.TribulationType.NORMAL)
	await _flush()
	ts.call("start_tribulation_combat")
	await _flush()
	var config: Dictionary = _battle_started_configs[0]
	var trib_data: Dictionary = config["tribulation_data"]
	assert_eq(trib_data["realm_level"], 2, "realm_level=2")
	assert_eq(trib_data["is_cross_realm"], false, "is_cross_realm=false")


# ============================================================================
# AC-003：_on_battle_ended 在 IN_COMBAT 时响应，其他状态忽略
# ============================================================================

func test_ac003_battle_ended_victory_transitions_success() -> void:
	_setup_preparing()
	await _flush()
	ts.call("start_tribulation_combat")
	await _flush()
	# 模拟 CombatSystem 发射 battle_ended(VICTORY=0)
	# Story 5-12 后 _on_battle_ended 调用 _handle_tribulation_success
	# 最终回到 NOT_READY（完整结算行为在 test_pill_and_settlement.gd 验证）
	ts.call("_on_battle_ended", 0, {})
	await _flush()
	assert_ne(gsm.player.tribulation_state, TS_SCRIPT.TribulationState.IN_COMBAT, "VICTORY 后离开 IN_COMBAT")
	assert_eq(gsm.player.tribulation_state, TS_SCRIPT.TribulationState.NOT_READY, "VICTORY 最终回到 NOT_READY")


func test_ac003_battle_ended_defeat_transitions_failed() -> void:
	_setup_preparing()
	await _flush()
	ts.call("start_tribulation_combat")
	await _flush()
	# 模拟 CombatSystem 发射 battle_ended(DEFEAT=1)
	# Story 5-12 后 _on_battle_ended 调用 _handle_tribulation_failure
	# 最终回到 NOT_READY（完整结算行为在 test_pill_and_settlement.gd 验证）
	ts.call("_on_battle_ended", 1, {})
	await _flush()
	assert_ne(gsm.player.tribulation_state, TS_SCRIPT.TribulationState.IN_COMBAT, "DEFEAT 后离开 IN_COMBAT")
	assert_eq(gsm.player.tribulation_state, TS_SCRIPT.TribulationState.NOT_READY, "DEFEAT 最终回到 NOT_READY")


func test_ac003_battle_ended_ignored_when_not_in_combat() -> void:
	# NOT_READY 状态——忽略
	ts.call("_on_battle_ended", 0, {})
	await _flush()
	assert_eq(gsm.player.tribulation_state, TS_SCRIPT.TribulationState.NOT_READY, "非 IN_COMBAT 时忽略")


# ============================================================================
# AC-004：calculate_lightning_damage 纯函数
# ============================================================================

func test_ac004_lightning_damage_turn_1() -> void:
	assert_eq(ts.call("calculate_lightning_damage", 1, 1), 1, "第1回合 = 1×1 = 1")


func test_ac004_lightning_damage_turn_3() -> void:
	assert_eq(ts.call("calculate_lightning_damage", 3, 1), 3, "第3回合 = 3×1 = 3")


func test_ac004_lightning_damage_yuan_ying_turn_5() -> void:
	# 元婴劫 2层/回合，第5回合 = 5×2 = 10
	assert_eq(ts.call("calculate_lightning_damage", 5, 2), 10, "第5回合元婴劫 = 5×2 = 10")


func test_ac004_lightning_damage_invalid_turn() -> void:
	assert_eq(ts.call("calculate_lightning_damage", 0, 1), 0, "turn=0 返回 0")
	assert_eq(ts.call("calculate_lightning_damage", -1, 1), 0, "turn=-1 返回 0")


# ============================================================================
# AC-005：get_lightning_layers_per_turn 元婴=2，其余=1
# ============================================================================

func test_ac005_layers_yuan_ying() -> void:
	assert_eq(ts.call("get_lightning_layers_per_turn", 4), 2, "元婴劫(realm=4) 2层/回合")


func test_ac005_layers_other_realms() -> void:
	assert_eq(ts.call("get_lightning_layers_per_turn", 1), 1, "炼气(realm=1) 1层/回合")
	assert_eq(ts.call("get_lightning_layers_per_turn", 2), 1, "筑基(realm=2) 1层/回合")
	assert_eq(ts.call("get_lightning_layers_per_turn", 3), 1, "金丹(realm=3) 1层/回合")
	assert_eq(ts.call("get_lightning_layers_per_turn", 5), 1, "化神(realm=5) 1层/回合")


# ============================================================================
# AC-006：get_tribulation_boss_config 返回非空字典
# ============================================================================

func test_ac006_boss_config_structure() -> void:
	var boss: Dictionary = ts.call("get_tribulation_boss_config", 1)
	assert_false(boss.is_empty(), "非空字典")
	assert_true(boss.has("realm"), "含 realm")
	assert_true(boss.has("hp"), "含 hp")
	assert_true(boss.has("atk"), "含 atk")


func test_ac006_boss_config_scales_with_realm() -> void:
	var boss_1: Dictionary = ts.call("get_tribulation_boss_config", 1)
	var boss_2: Dictionary = ts.call("get_tribulation_boss_config", 2)
	assert_gt(int(boss_2["hp"]), int(boss_1["hp"]), "realm=2 HP > realm=1 HP")
	assert_gt(int(boss_2["atk"]), int(boss_1["atk"]), "realm=2 ATK > realm=1 ATK")


# ============================================================================
# AC-007：越阶渡劫时 Boss 境界 = 玩家境界 + 1
# ============================================================================

func test_ac007_cross_realm_boss_realm() -> void:
	gsm.player.cultivation = 1000
	gsm.player.max_cultivation = 1000
	gsm.player.realm = 2
	ts.call("trigger_tribulation", TS_SCRIPT.TribulationType.CROSS_REALM)
	await _flush()
	ts.call("start_tribulation_combat")
	await _flush()
	var config: Dictionary = _battle_started_configs[0]
	var trib_data: Dictionary = config["tribulation_data"]
	assert_eq(trib_data["is_cross_realm"], true, "is_cross_realm=true")
	var boss_config: Dictionary = trib_data["boss_config"]
	assert_eq(int(boss_config["realm"]), 3, "越阶 Boss 境界 = 2+1 = 3")


func test_ac007_normal_realm_boss_same() -> void:
	gsm.player.cultivation = 1000
	gsm.player.max_cultivation = 1000
	gsm.player.realm = 3
	ts.call("trigger_tribulation", TS_SCRIPT.TribulationType.NORMAL)
	await _flush()
	ts.call("start_tribulation_combat")
	await _flush()
	var config: Dictionary = _battle_started_configs[0]
	var trib_data: Dictionary = config["tribulation_data"]
	assert_eq(trib_data["is_cross_realm"], false, "is_cross_realm=false")
	var boss_config: Dictionary = trib_data["boss_config"]
	assert_eq(int(boss_config["realm"]), 3, "正常 Boss 境界 = 3（同级）")


# ============================================================================
# AC-008：战斗结束时状态转换 IN_COMBAT → SUCCESS/FAILED
# ============================================================================

func test_ac008_victory_to_success() -> void:
	_setup_preparing()
	await _flush()
	ts.call("start_tribulation_combat")
	await _flush()
	assert_eq(gsm.player.tribulation_state, TS_SCRIPT.TribulationState.IN_COMBAT, "战斗中")
	# Story 5-12 后 _on_battle_ended 调用 _handle_tribulation_success
	# 最终回到 NOT_READY（完整结算在 test_pill_and_settlement.gd 验证）
	ts.call("_on_battle_ended", 0, {})  # VICTORY
	await _flush()
	assert_eq(gsm.player.tribulation_state, TS_SCRIPT.TribulationState.NOT_READY, "VICTORY 最终回到 NOT_READY")


func test_ac008_defeat_to_failed() -> void:
	_setup_preparing()
	await _flush()
	ts.call("start_tribulation_combat")
	await _flush()
	ts.call("_on_battle_ended", 1, {})  # DEFEAT
	await _flush()
	assert_eq(gsm.player.tribulation_state, TS_SCRIPT.TribulationState.NOT_READY, "DEFEAT 最终回到 NOT_READY")


func test_ac008_retreat_to_failed() -> void:
	_setup_preparing()
	await _flush()
	ts.call("start_tribulation_combat")
	await _flush()
	ts.call("_on_battle_ended", 2, {})  # RETREAT
	await _flush()
	assert_eq(gsm.player.tribulation_state, TS_SCRIPT.TribulationState.NOT_READY, "RETREAT 最终回到 NOT_READY")
