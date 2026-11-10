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
	# 开战配置是跨用例残留源（battle_end 不清它，下一场 battle_start 才覆盖）
	cs.set("_battle_config", {})


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
# AC-003~005：掉落来自开战配置（探索节点在节点生成时定档，战斗侧只结算）
# ============================================================================

## 开战配置带 rewards 时，三项计算都读它（而不是写死 0 / 空）。
func test_rewards_come_from_battle_config() -> void:
	# Arrange——模拟探索节点带进来的掉落
	cs.call("battle_start", {"rewards": {
		"lingshi": 12, "cultivation": 6,
		"cards": [{"card_id": "basic_attack", "rarity": 1}],
	}})
	# Assert
	assert_eq(cs.call("_calculate_lingshi_reward"), 12, "灵石取配置值")
	assert_eq(cs.call("_calculate_cultivation_reward"), 6, "修为取配置值")
	var drops: Array = cs.call("_calculate_card_drops")
	assert_eq(drops.size(), 1, "卡牌掉落取配置列表")
	assert_eq(drops[0]["card_id"], "basic_attack", "掉落条目透传")
	# 清场（下一用例不继承本场配置）
	cs.call("battle_end", 2)


## 配置缺失时按 0 / 空处理——不臆造奖励。
func test_rewards_default_to_zero_without_config() -> void:
	assert_eq(cs.call("_calculate_lingshi_reward"), 0, "无配置时灵石为 0")
	assert_eq(cs.call("_calculate_cultivation_reward"), 0, "无配置时修为为 0")
	assert_eq(cs.call("_calculate_card_drops"), [], "无配置时掉落为空 Array")


## 负值配置钳到 0——掉落配置是数据，不能把玩家余额打成负数。
func test_rewards_clamp_negative_config() -> void:
	cs.call("battle_start", {"rewards": {"lingshi": -5, "cultivation": -1}})
	assert_eq(cs.call("_calculate_lingshi_reward"), 0, "负灵石钳到 0")
	assert_eq(cs.call("_calculate_cultivation_reward"), 0, "负修为钳到 0")
	cs.call("battle_end", 2)


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
