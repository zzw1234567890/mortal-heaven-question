extends "res://tests/integration/combat_ui/full_battle_fixture.gd"
## 探索→战斗补链验收：点节点 → 开战（阵容一致）→ 结束回探索（状态未破坏）。[br]
## [br][b]与上一轮验收的差别[/b]：上一轮战斗场景在无注入时读
## [code]default_encounter.tres[/code] 兜底——「探索点哪一格都打同一批敌人」。
## 本文件走完整链路：[code]NodeInteractionPopupHost[/code] 确认 →
## [code]CombatLaunchContext[/code] 跨场景发布 → 战斗场景 [code]_ready[/code] 消费 →
## [code]setup_field[/code] / [code]battle_start[/code]。[br]
## [br][b]断言三件事[/b]：[br]
##   1. 敌方阵容 = 节点遭遇（模板 ID 与等级都来自节点，不是默认资源）；[br]
##   2. 玩家阵容 = 探索侧带进来的阵容（备战面板已预选）；[br]
##   3. 战斗结束回探索后，探索导航状态（地图 / 节点位置 / 已访问 / AP）未被破坏。[br]
## [br][b]缺上下文的路径[/b]：给可读失败并拒绝开战——不再静默兜底。[br]
## [br]本文件独占角色段：卡实例 ID 由 CardSystem 分配，不手写。

const ContextScript := preload("res://src/feature/combat/combat_launch_context.gd")
const PopupHostScript := preload("res://src/ui/exploration/node_interaction_popup_host.gd")
const ViewScript2 := preload("res://src/feature/combat/combat_result_view.gd")

## 节点遭遇：散修 ×2、等级 2（与默认遭遇的「散修 ×1、炼气」刻意区分）。
const NODE_TEMPLATES: Array[StringName] = [&"san_xiu", &"san_xiu"]
const NODE_ENEMY_LEVEL: int = 2
const NODE_REWARDS: Dictionary = {"lingshi": 9, "cultivation": 3, "cards": []}
const NODE_ID: int = 101

## 探索导航状态快照（战斗往返后逐项比对）。
var _exploration_before: Dictionary = {}
var _ai_roster_before: Array = []


## 每个用例：先起探索侧的导航状态，再走夹具的常规开战前置。[br]
## [br][b]不注入夹具自带上下文[/b]：本文件要验的正是「探索侧发布 → 战斗侧消费」
## 这条跨场景缓存路径（[member use_fixture_launch_context] = false）。
func before_each() -> void:
	use_fixture_launch_context = false
	_snapshot_exploration()
	_seed_exploration_navigation()
	ViewScript2.clear()
	ContextScript.clear()


func after_each() -> void:
	await teardown()
	ContextScript.clear()
	_restore_exploration()
	AISystem.set_enemy_roster(_ai_roster_before)


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 点节点 → 开战：敌方与玩家阵容都与节点一致
# ═══════════════════════════════════════════════════════════════════════════════

func test_node_encounter_reaches_battle_with_matching_rosters() -> void:
	# Arrange——先备好卡组/角色与独立战斗系统，暂不挂场景
	setup(false, false)
	# 探索侧确认进入战斗（真实弹窗宿主 + 真实上下文发布到跨场景缓存）
	_confirm_exploration_combat()
	var context: Dictionary = ContextScript.peek()
	assert_eq(context.get(ContextScript.KEY_TEMPLATE_IDS), NODE_TEMPLATES,
			"前置：上下文应携带节点遭遇模板")
	# Act——战斗场景挂载（_ready 取走上下文）+ 玩家确认出战
	mount_now()
	assert_eq(scene.get("launch_failure"), "", "上下文齐备时不应有失败文案")
	var deploy: Variant = _root().get("deploy_panel")
	assert_eq(deploy.call("get_selected_ids"), char_ids,
			"备战面板应按探索侧阵容预选（玩家仍可改选）")
	confirm_deploy()
	# Assert——敌方来自节点（数量 + 模板），不是默认遭遇的「散修 ×1」
	var roster: Array = cs.call("get_battle_enemy_roster")
	assert_eq(roster.size(), NODE_TEMPLATES.size(), "敌方数量与节点遭遇一致")
	for entry: Variant in roster:
		assert_eq(StringName(str(entry.get("template_id"))), &"san_xiu",
				"敌方模板与节点遭遇一致")
		# 散修 base_hp 16；玩家境界 1 < 节点等级 2 → 不缩放（仅玩家更高时缩放）
		assert_eq(int(entry.get("max_hp")), 16, "敌方 HP 来自散修模板")
	# Assert——玩家阵容 = 探索侧带进来的阵容
	assert_eq(cs.get("_battle_player_roster"), char_ids, "开战名册 = 探索侧玩家阵容")
	assert_eq(deployment_setups(), [char_ids], "setup_field 收到的正是该阵容")
	# Assert——掉落与等级进开战配置（结算时读取）
	var config: Dictionary = cs.get("_battle_config")
	assert_eq(int(config.get("rewards", {}).get("lingshi")), 9,
			"节点掉落随开战配置下发")
	assert_eq(int(config.get("enemy_level", 0)), NODE_ENEMY_LEVEL,
			"节点敌方等级随开战配置下发")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 结束回探索：导航状态未被破坏
# ═══════════════════════════════════════════════════════════════════════════════

func test_battle_end_returns_to_exploration_with_navigation_intact() -> void:
	# Arrange——先备数据，再走探索侧确认，最后挂场景
	setup(false, false)
	_confirm_exploration_combat()
	mount_now()
	confirm_deploy()
	assert_true(bool(cs.call("is_battle_active")), "前置：战斗已开始")
	var nav_before: Dictionary = _exploration_snapshot()
	assert_eq(StringName(nav_before.get("current_map")), &"qing_yun_jian_zong",
			"前置：处于探索地图中")
	# Act——撤退（走战斗系统结算 → battle_ended → 结算场景转场）
	cs.call("confirm_retreat")
	# Assert——战斗真的结束，且转场请求已发出
	assert_false(bool(cs.call("is_battle_active")), "撤退后战斗应结束")
	assert_eq(battle_events.size(), 1, "battle_ended 应发射一次")
	assert_eq(sm.requests.size(), 1, "结束应发出一次转场请求")
	assert_eq(int(sm.requests[0]["to"]), 9, "撤退应转场 DEFEAT_SCREEN（先结算再回探索）")
	# Assert——探索导航状态逐项未变（地图 / 位置 / 已访问 / AP）
	assert_eq(_exploration_snapshot(), nav_before, "战斗往返不得改写探索导航状态")
	# Assert——回到探索后仍能重建同一张图（map_states 快照仍在）
	var map_id: StringName = StringName(nav_before.get("current_map", ""))
	var states: Dictionary = GameStateManager.exploration.get("map_states", {})
	assert_true(states.has(map_id), "探索 map_states 仍保留该地图快照")
	assert_true((states[map_id] as Dictionary).has("graph"), "地图快照含 graph（可重建）")
	var es: Node = _autoload(&"ExplorationSystem")
	if es != null:
		es.call("rebuild_dag_cache", map_id, states[map_id])
		assert_eq((es.call("get_node_graph") as Dictionary).size(), 2,
				"重建后的节点图与快照一致")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 缺上下文：可读失败，不静默兜底
# ═══════════════════════════════════════════════════════════════════════════════

func test_missing_launch_context_refuses_battle_with_readable_failure() -> void:
	# Arrange——不发布任何探索上下文（直接挂场景，模拟链路断裂）
	setup(false, false)
	ContextScript.clear()
	mount_now()
	# Assert——场景挂载不崩，失败文案可读
	var failure: String = str(scene.get("launch_failure"))
	assert_string_contains(failure, "未收到探索侧开战上下文", "失败文案应说明缺什么")
	# Act——玩家仍点确认出战
	var deploy: Variant = _root().get("deploy_panel")
	for cid: int in char_ids:
		deploy.call("toggle_selection", cid)
	deploy.emit_signal("confirm_requested", char_ids)
	# Assert——拒绝开战（push_error 由 GUT 计为 1 次），不带着空敌方阵容开打
	assert_push_error_count(1, "缺上下文应 push_error 一次并拒绝开战")
	assert_false(bool(cs.call("is_battle_active")), "缺上下文不得开战")


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 探索侧确认进入战斗——真实弹窗宿主（注入玩家阵容提供者，避开 GSM 角色位）。
func _confirm_exploration_combat() -> void:
	var host: Control = PopupHostScript.new()
	add_child_autofree(host)
	host.set("player_roster_provider", Callable(func() -> Array: return char_ids))
	# 节点详情：遭遇配置挂在 nodes[node_id] 上（探索系统生成时的定档）
	host.apply_snapshot({
		"current_node": NODE_ID,
		"nodes": {NODE_ID: {
			"type": 1, "description": "山道巡守",
			"encounter": {
				"encounter_id": "shandao_patrol",
				"display_name": "山道巡守",
				"enemy_template_ids": NODE_TEMPLATES,
				"enemy_level": NODE_ENEMY_LEVEL,
				"rewards": NODE_REWARDS,
			},
		}},
	})
	host.on_combat_arrival([{"template_id": "san_xiu", "realm": 1},
			{"template_id": "san_xiu", "realm": 1}], &"combat")
	# 点确认（真实按钮路径）
	var popup: Node = host.get_node(NodePath("NodeInteractionPopup"))
	var confirm: Button = popup.get_node(NodePath("ConfirmButton")) as Button
	confirm.pressed.emit()


## 夹具里的布阵桩调用记录（本文件复用真实 DeploymentSystem——取阵位快照）。
func deployment_setups() -> Array:
	var field: Array = DeploymentSystem.get_field()
	var ids: Array = []
	for entry: Dictionary in field:
		var cid: int = int(entry.get("character_id", -1))
		if cid > 0:
			ids.append(cid)
	return [ids]


## 探索导航状态快照（战斗往返比对的四项）。
func _exploration_snapshot() -> Dictionary:
	return {
		"current_map": GameStateManager.exploration.get("current_map", &""),
		"node_position": (GameStateManager.exploration.get("node_position", {}) as Dictionary).duplicate(true),
		"visited_nodes": (GameStateManager.exploration.get("visited_nodes", []) as Array).duplicate(),
		"action_points": int(GameStateManager.exploration.get("action_points", 0)),
	}


func _snapshot_exploration() -> void:
	_exploration_before = _exploration_snapshot()
	_ai_roster_before = AISystem.get_enemy_roster().duplicate()


## 起一张活跃地图的导航状态（当前在第 1 层某战斗节点、AP 已消耗 2）。
func _seed_exploration_navigation() -> void:
	var es: Node = _autoload(&"ExplorationSystem")
	if es != null:
		es.call("clear_dag_cache")
	GameStateManager.exploration = {
		"current_map": &"qing_yun_jian_zong",
		"node_position": {"layer": 1, "idx": 0},
		"visited_nodes": [0, 101],
		"action_points": 3,
		"max_action_points": 5,
		"map_states": {&"qing_yun_jian_zong": {
			"entry_count": 1,
			"graph": {0: [101], 101: []},
			"nodes": {0: {"type": 0}, 101: {"type": 1}},
		}},
	}
	GameStateManager._pending_changes.clear()
	GameStateManager._flush_scheduled = false


func _restore_exploration() -> void:
	GameStateManager.exploration = _exploration_before.duplicate(true)
	var es: Node = _autoload(&"ExplorationSystem")
	if es != null:
		es.call("clear_dag_cache")
