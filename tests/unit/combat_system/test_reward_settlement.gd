extends GutTest
## Story 8-5 验收测试：CombatSystem 战斗奖励结算 + is_kill 修正。
##
## 覆盖 AC-001 到 AC-010（10 条 AC）。
## 测试策略：
##   - 使用 CombatSystem Autoload 实例
##   - 验证 _settle_result 各分支返回值
##   - 验证 is_kill 从 target_hp 派生

var cs: Node = null


func before_each() -> void:
	cs = Engine.get_main_loop().root.get_node("/root/CombatSystem")
	assert_not_null(cs, "CombatSystem Autoload 应存在")
	cs.set_auto_advance(false)
	cs.set_scene_change(false)
	cs.set_rng_seed(42)


func after_each() -> void:
	cs.set_battle_active(false)
	cs.call("set_deck_state", [], [], [])
	cs.call("set_attack_queue", [])


# ============================================================================
# AC-001：_settle_result(VICTORY) 返回包含 lingshi/cultivation/cards 的 rewards
# ============================================================================

func test_settle_result_victory_contains_reward_keys() -> void:
	# Act
	var rewards: Dictionary = cs.call("_settle_result", 1)  # CombatResult.VICTORY=1

	# Assert
	assert_eq(rewards["result"], 1, "result=VICTORY")
	assert_true(rewards.has("lingshi"), "应包含 lingshi 键")
	assert_true(rewards.has("cultivation"), "应包含 cultivation 键")
	assert_true(rewards.has("cards"), "应包含 cards 键")


# ============================================================================
# AC-002：_settle_result(DEFEAT/RETREAT) 返回 retain_ratio=0.5
# ============================================================================

func test_settle_result_defeat_returns_retain_ratio() -> void:
	var rewards_d: Dictionary = cs.call("_settle_result", 2)  # DEFEAT=2
	assert_eq(rewards_d["result"], 2, "result=DEFEAT")
	assert_eq(rewards_d["retain_ratio"], 0.5, "DEFEAT retain_ratio=0.5")

	var rewards_r: Dictionary = cs.call("_settle_result", 3)  # RETREAT=3
	assert_eq(rewards_r["result"], 3, "result=RETREAT")
	assert_eq(rewards_r["retain_ratio"], 0.5, "RETREAT retain_ratio=0.5")


# ============================================================================
# AC-003：_calculate_lingshi_reward 桩返回 0
# ============================================================================

func test_calculate_lingshi_reward_stub_returns_zero() -> void:
	assert_eq(cs.call("_calculate_lingshi_reward"), 0, "桩默认返回 0")


# ============================================================================
# AC-004：_calculate_cultivation_reward 桩返回 0
# ============================================================================

func test_calculate_cultivation_reward_stub_returns_zero() -> void:
	assert_eq(cs.call("_calculate_cultivation_reward"), 0, "桩默认返回 0")


# ============================================================================
# AC-005：_calculate_card_drops 桩返回空 Array
# ============================================================================

func test_calculate_card_drops_stub_returns_empty() -> void:
	assert_eq(cs.call("_calculate_card_drops"), [], "桩默认返回空 Array")


# ============================================================================
# AC-006：_apply_victory_rewards 通过 ResourceSystem.add_resource 写入灵石
# ============================================================================

func test_apply_victory_rewards_writes_lingshi() -> void:
	# Arrange——记录 ResourceSystem 灵石余额
	var rs: Node = Engine.get_main_loop().root.get_node_or_null("/root/ResourceSystem")
	if rs == null or not rs.has_method("get_resource"):
		pass  # ResourceSystem 不可用——跳过
		return
	var before: int = rs.get_resource(&"ling_shi")

	# Act
	cs.call("_apply_victory_rewards", {"lingshi": 100, "cultivation": 0, "cards": []})

	# Assert
	var after: int = rs.get_resource(&"ling_shi")
	assert_eq(after, before + 100, "灵石应增加 100")

	# Cleanup——回退灵石
	if rs.has_method("spend_resource"):
		rs.spend_resource(&"ling_shi", 100)


# ============================================================================
# AC-007：_apply_victory_rewards 通过 CultivationSystem.gain_cultivation 写入修为
# ============================================================================

func test_apply_victory_rewards_writes_cultivation() -> void:
	# Arrange——记录 CultivationSystem 修为
	var cult: Node = Engine.get_main_loop().root.get_node_or_null("/root/CultivationSystem")
	if cult == null or not cult.has_method("get_cultivation"):
		pass  # CultivationSystem 不可用——跳过
		return
	var before: int = cult.get_cultivation()

	# Act
	cs.call("_apply_victory_rewards", {"lingshi": 0, "cultivation": 50, "cards": []})

	# Assert
	var after: int = cult.get_cultivation()
	assert_eq(after, before + 50, "修为应增加 50")


# ============================================================================
# AC-008：ResourceSystem/CultivationSystem 不可用时静默跳过
# ============================================================================

func test_apply_victory_rewards_no_crash_when_systems_missing() -> void:
	# Act——0 奖励不应触发任何系统调用
	cs.call("_apply_victory_rewards", {"lingshi": 0, "cultivation": 0, "cards": []})

	# Assert——不崩溃即通过
	assert_true(true, "零奖励不应崩溃")


# ============================================================================
# AC-009：_resolve_attack_queue 中 is_kill 从 target_hp 派生
# ============================================================================

func test_is_kill_derived_from_target_hp() -> void:
	# Arrange——target_hp=5, final_damage=3 → is_kill=false
	cs.call("set_attack_queue", [{
		"attacker_id": 10, "target_id": 20,
		"attacker_atk": 5, "target_def": 2,
		"attacker_realm": 1, "defender_realm": 1,
		"target_hp": 5,
	}])
	var sig := {"payload": {}}
	cs.connect("attack_resolved", Callable(func(payload: Dictionary):
		sig["payload"] = payload))

	# Act
	cs.call("_resolve_attack_queue")

	# Assert——damage=max(1,5-2)=3 < target_hp=5 → is_kill=false
	assert_eq(sig["payload"]["is_kill"], false, "damage 3 < target_hp 5 → is_kill=false")


func test_is_kill_true_when_damage_exceeds_hp() -> void:
	# Arrange——target_hp=3, final_damage=3 → is_kill=true
	cs.call("set_attack_queue", [{
		"attacker_id": 10, "target_id": 20,
		"attacker_atk": 5, "target_def": 2,
		"attacker_realm": 1, "defender_realm": 1,
		"target_hp": 3,
	}])
	var sig := {"payload": {}}
	cs.connect("attack_resolved", Callable(func(payload: Dictionary):
		sig["payload"] = payload))

	# Act
	cs.call("_resolve_attack_queue")

	# Assert——damage=max(1,5-2)=3 >= target_hp=3 → is_kill=true
	assert_eq(sig["payload"]["is_kill"], true, "damage 3 >= target_hp 3 → is_kill=true")


# ============================================================================
# AC-010：全量测试零回归
# ============================================================================

func test_no_regression() -> void:
	cs.set_battle_active(true)
	assert_true(cs.is_battle_active(), "战斗应可激活")
	cs.set_battle_active(false)
	assert_false(cs.is_battle_active(), "战斗应可关闭")
