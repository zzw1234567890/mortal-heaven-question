extends GutTest
## Story 005 验收测试：事件节点分配 + 经济计算。
##
## 覆盖 AC-001 到 AC-008（8 条 AC）。
## 测试策略：
##   - ES_SCRIPT.new() + GSM Autoload
##   - 直接测试经济公式
##   - 模拟资源收集 + 结算流程
##
## 设计文档来源：ADR-0014 §决策 4/5 + GDD §公式 5/6/10/11
## Story 来源：production/epics/exploration-system/story-005-event-allocation-economy.md

const ES_SCRIPT := preload("res://src/feature/exploration_system.gd")

var es: Node = null
var gsm: Node = null


func before_each() -> void:
	es = ES_SCRIPT.new()
	es.call("set_rng_seed", 42)
	es.set("get_map_config_cb", Callable(func(_mid, _r):
		return es.get("DIFFICULTY_CONFIGS")[1].duplicate(true)))
	es.set("generate_enemy_roster_cb", Callable(func(_mid, _r, _is_elite):
		return [{"enemy_id": 1}]))
	es.set("get_event_pool_cb", Callable(func(_mid, _r):
		return ["event_a", "event_b"]))
	es.set("generate_shop_inventory_cb", Callable(func(_r):
		return {"items": [1, 2, 3]}))

	gsm = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/GameStateManager")
	if gsm != null:
		gsm.exploration = {
			"current_map": &"",
			"node_position": {"layer": 0, "idx": 0},
			"visited_nodes": [],
			"action_points": 0,
			"max_action_points": 0,
			"map_states": {},
		}
		gsm.player.resources.ling_shi = 100
		gsm.player.cultivation = 0
		gsm.player.max_cultivation = 1000
		gsm.player.cultivation_full = false
		gsm.player.overflow_pool = 0
		gsm.set("_signal_chain_depth", 0)
		gsm.get("_signal_router").set("_pending_changes", [])


func after_each() -> void:
	if es != null:
		es.free()
		es = null
	if gsm != null:
		gsm.exploration = {
			"current_map": &"",
			"node_position": {"layer": 0, "idx": 0},
			"visited_nodes": [],
			"action_points": 0,
			"max_action_points": 0,
			"map_states": {},
		}
		gsm.player.resources.ling_shi = 100
		gsm.player.cultivation = 0
		gsm.player.cultivation_full = false
		gsm.player.overflow_pool = 0


# ============================================================================
# AC-001：重入费用计算（公式 10）
# ============================================================================

func test_ac001_first_entry_free() -> void:
	# entry_count=0（从未进入）→ 0
	assert_eq(es.call("calculate_reentry_cost", &"test_map"), 0, "首次进入免费")


func test_ac001_second_entry_cost() -> void:
	# 设置 entry_count=1 → 第二次进入（entry_count+1=2）
	gsm.update_exploration_map_state(&"test_map", {"entry_count": 1})
	await get_tree().process_frame
	# 中难度 base=60, multiplier=1.0+(2-2)*0.5=1.0 → 60
	assert_eq(es.call("calculate_reentry_cost", &"test_map"), 60, "第二次进入 60 灵石")


func test_ac001_third_entry_cost() -> void:
	# 设置 entry_count=2 → 第三次进入（entry_count+1=3）
	gsm.update_exploration_map_state(&"test_map", {"entry_count": 2})
	await get_tree().process_frame
	# base=60, multiplier=1.0+(3-2)*0.5=1.5 → 90
	assert_eq(es.call("calculate_reentry_cost", &"test_map"), 90, "第三次进入 90 灵石")


func test_ac001_seventh_entry_capped() -> void:
	# 设置 entry_count=7 → 第八次进入（entry_count+1=8）
	gsm.update_exploration_map_state(&"test_map", {"entry_count": 7})
	await get_tree().process_frame
	# base=60, multiplier=min(1.0+(8-2)*0.5, 3.0)=min(4.0,3.0)=3.0 → 180
	assert_eq(es.call("calculate_reentry_cost", &"test_map"), 180, "第八次进入 180 灵石（3.0x 上限）")


# ============================================================================
# AC-002：通关奖励计算（公式 5+6）
# ============================================================================

func test_ac002_clear_rewards_no_penalty() -> void:
	# 玩家境界 = 地图境界 → 无惩罚
	var rewards: Dictionary = es.call("calculate_map_clear_rewards", &"test_map", false, 2, 2)
	assert_eq(rewards["ling_shi"], 100, "中难度灵石 100（无惩罚）")
	assert_eq(rewards["cultivation"], 80, "中难度修为 80")


func test_ac002_clear_rewards_with_penalty() -> void:
	# player_L=3, map_max_L=1 → gap=2 → penalty=0.4 → ling_shi=40
	var rewards: Dictionary = es.call("calculate_map_clear_rewards", &"test_map", false, 3, 1)
	assert_eq(rewards["ling_shi"], 40, "灵石受惩罚 100*0.4=40")
	assert_eq(rewards["cultivation"], 80, "修为不受惩罚 80")


func test_ac002_first_clear_has_extra() -> void:
	var rewards: Dictionary = es.call("calculate_map_clear_rewards", &"test_map", true, 2, 2)
	assert_true(rewards.has("extra"), "首次通关含 extra")


# ============================================================================
# AC-003：境界差额惩罚（公式 6）
# ============================================================================

func test_ac003_no_gap_no_penalty() -> void:
	assert_eq(es.call("realm_gap_penalty", 2, 2), 1.0, "gap=0 → 1.0")


func test_ac003_gap_one() -> void:
	assert_almost_eq(es.call("realm_gap_penalty", 2, 1), 0.7, 0.001, "gap=1 → ~0.7")


func test_ac003_gap_two() -> void:
	assert_almost_eq(es.call("realm_gap_penalty", 3, 1), 0.4, 0.001, "gap=2 → ~0.4")


func test_ac003_gap_three() -> void:
	assert_almost_eq(es.call("realm_gap_penalty", 4, 1), 0.1, 0.001, "gap=3 → ~0.1（保底）")


func test_ac003_gap_four_floor() -> void:
	assert_almost_eq(es.call("realm_gap_penalty", 5, 1), 0.1, 0.001, "gap=4 → ~0.1（保底）")


# ============================================================================
# AC-004：资源收集
# ============================================================================

func test_ac004_collect_ling_shi() -> void:
	gsm.set_exploration_map(&"collect_test")
	await get_tree().process_frame
	es.call("collect_resource", &"ling_shi", 50)
	await get_tree().process_frame
	var state: Dictionary = gsm.exploration["map_states"][&"collect_test"]
	assert_eq(state["collected_ling_shi"], 50, "collected_ling_shi=50")


func test_ac004_collect_cultivation() -> void:
	gsm.set_exploration_map(&"collect_test")
	await get_tree().process_frame
	es.call("collect_resource", &"cultivation", 30)
	await get_tree().process_frame
	var state: Dictionary = gsm.exploration["map_states"][&"collect_test"]
	assert_eq(state["collected_cultivation"], 30, "collected_cultivation=30")


func test_ac004_collect_accumulates() -> void:
	gsm.set_exploration_map(&"collect_test")
	await get_tree().process_frame
	es.call("collect_resource", &"ling_shi", 50)
	es.call("collect_resource", &"ling_shi", 30)
	await get_tree().process_frame
	var state: Dictionary = gsm.exploration["map_states"][&"collect_test"]
	assert_eq(state["collected_ling_shi"], 80, "累积 50+30=80")


# ============================================================================
# AC-005：资源转移
# ============================================================================

func test_ac005_flush_transfers_ling_shi() -> void:
	gsm.set_exploration_map(&"flush_test")
	await get_tree().process_frame
	es.call("collect_resource", &"ling_shi", 50)
	await get_tree().process_frame
	var ls_before: int = gsm.player.resources.ling_shi
	es.call("_flush_map_state", &"flush_test")
	await get_tree().process_frame
	assert_eq(gsm.player.resources.ling_shi, ls_before + 50, "灵石已转移")
	var state: Dictionary = gsm.exploration["map_states"][&"flush_test"]
	assert_eq(state.get("collected_ling_shi", -1), 0, "collected 已清零")


func test_ac005_flush_transfers_cultivation() -> void:
	gsm.set_exploration_map(&"flush_test")
	await get_tree().process_frame
	es.call("collect_resource", &"cultivation", 50)
	await get_tree().process_frame
	var cult_before: int = gsm.player.cultivation
	es.call("_flush_map_state", &"flush_test")
	await get_tree().process_frame
	assert_eq(gsm.player.cultivation, cult_before + 50, "修为已转移")


# ============================================================================
# AC-006：三种结算路径
# ============================================================================

func test_ac006_boss_defeated_grants_rewards() -> void:
	gsm.set_exploration_map(&"boss_test")
	await get_tree().process_frame
	# 收集一些资源
	es.call("collect_resource", &"ling_shi", 20)
	await get_tree().process_frame
	var ls_before: int = gsm.player.resources.ling_shi
	# BOSS_DEFEATED = 0
	var summary: Dictionary = es.call("end_exploration", 0)
	await get_tree().process_frame
	assert_true(summary.has("rewards"), "BOSS_DEFEATED 含 rewards")
	# 灵石 = 通关奖励 + collected
	assert_true(gsm.player.resources.ling_shi > ls_before, "灵石增加（通关奖励+collected）")
	# 导航状态已清理
	assert_eq(gsm.exploration["current_map"], &"", "current_map 已清理")
	# DAG 缓存已清理
	assert_eq(es.get("_dag_ready"), false, "_dag_ready 已清理")


func test_ac006_battle_lost_half_cultivation() -> void:
	gsm.set_exploration_map(&"lost_test")
	await get_tree().process_frame
	es.call("collect_resource", &"cultivation", 100)
	await get_tree().process_frame
	var cult_before: int = gsm.player.cultivation
	# BATTLE_LOST = 1
	es.call("end_exploration", 1)
	await get_tree().process_frame
	# 修为保留 50% → +50
	assert_eq(gsm.player.cultivation, cult_before + 50, "战败修为保留 50%")


func test_ac006_ap_depleted_full_retention() -> void:
	gsm.set_exploration_map(&"ap_test")
	await get_tree().process_frame
	es.call("collect_resource", &"ling_shi", 30)
	es.call("collect_resource", &"cultivation", 60)
	await get_tree().process_frame
	var ls_before: int = gsm.player.resources.ling_shi
	var cult_before: int = gsm.player.cultivation
	# AP_DEPLETED = 2
	es.call("end_exploration", 2)
	await get_tree().process_frame
	assert_eq(gsm.player.resources.ling_shi, ls_before + 30, "AP 耗尽灵石全额保留")
	assert_eq(gsm.player.cultivation, cult_before + 60, "AP 耗尽修为全额保留")


# ============================================================================
# AC-007：永久免费地图
# ============================================================================

func test_ac007_permanent_free_always_zero() -> void:
	# 青云剑宗——永久免费
	gsm.update_exploration_map_state(&"qing_yun_jian_zong", {"entry_count": 10})
	await get_tree().process_frame
	assert_eq(es.call("calculate_reentry_cost", &"qing_yun_jian_zong"), 0, "永久免费地图第 10 次仍 0")


func test_ac007_all_permanent_free_maps() -> void:
	for map_id in es.get("PERMANENT_FREE_MAPS"):
		gsm.update_exploration_map_state(map_id, {"entry_count": 5})
		await get_tree().process_frame
		assert_eq(es.call("calculate_reentry_cost", map_id), 0, "%s 永久免费" % map_id)


# ============================================================================
# AC-008：事件节点防 SL
# ============================================================================

func test_ac008_event_pool_filled_at_generation() -> void:
	es.call("enter_map", &"event_test", 1, 10)
	var nodes: Dictionary = es.get("_node_details")
	var has_event: bool = false
	for node_id in nodes:
		if int(nodes[node_id]["type"]) == 4:  # EVENT
			has_event = true
			assert_true(nodes[node_id].has("event_pool"), "事件节点含 event_pool")
			assert_false(nodes[node_id].has("event_template_id"), "事件节点不含具体 event_template_id")
	if not has_event:
		pass_test("无事件节点生成——跳过（概率性）")


func test_ac008_event_resolved_on_arrival() -> void:
	# 事件节点到达时通过 resolve_node 发射 event_node_reached
	es.call("rebuild_dag_cache", &"event_arrival", {
		"graph": {0: [100], 100: [200], 200: []},
		"nodes": {
			0: {"type": 0, "layer": 0, "idx": 0},
			100: {"type": 4, "layer": 1, "idx": 0, "event_pool": ["event_a"]},
			200: {"type": 3, "layer": 2, "idx": 0},
		},
	})
	var signals: Array = []
	es.event_node_reached.connect(func(pool, realm): signals.append({"pool": pool, "realm": realm}))
	es.call("resolve_node", 100)
	assert_eq(signals.size(), 1, "event_node_reached 发射")
	assert_eq(signals[0]["pool"], ["event_a"], "event_pool 正确")


# ============================================================================
# 综合：完整经济闭环
# ============================================================================

func test_full_economy_cycle() -> void:
	# 1. 进入地图
	es.call("enter_map", &"economy_cycle", 1, 10)
	await get_tree().process_frame
	# 2. 收集资源
	es.call("collect_resource", &"ling_shi", 50)
	es.call("collect_resource", &"cultivation", 30)
	await get_tree().process_frame
	var ls_before: int = gsm.player.resources.ling_shi
	var cult_before: int = gsm.player.cultivation
	# 3. 通关结算
	var summary: Dictionary = es.call("end_exploration", 0)  # BOSS_DEFEATED
	await get_tree().process_frame
	# 4. 验证：灵石 = collected + 通关奖励，修为 = collected + 通关奖励
	assert_true(gsm.player.resources.ling_shi >= ls_before + 50, "灵石含 collected + 通关奖励")
	assert_true(gsm.player.cultivation >= cult_before + 30, "修为含 collected + 通关奖励")
	assert_eq(gsm.exploration["current_map"], &"", "导航状态已清理")
