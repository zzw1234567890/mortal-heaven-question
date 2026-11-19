extends "res://tests/integration/exploration_ui/one_run_smoke_fixture.gd"
## 一周目冒烟 —— 玩家从进游戏一路打到首图 Boss。[br]
## [br][b]为什么需要本文件[/b]：既有用例各锁一段（主菜单路由、身份落地、选图、
## 节点图、战斗结算），但没有一条[b]把整条路真的走一遍[/b]——接缝上的断链
## （信号无消费者、地图 ID 被丢弃、状态没写入）恰好都在段与段之间。[br]
## [br][b]覆盖[/b]（每一步都断言「下一步真的可达」，不看信号就算过）：[br]
##   1. 主菜单「新游戏」→ 导航到身份选择；[br]
##   2. 选身份① → 确认 → 开局意图落盘（FIRST_MAP）+ 导航到探索；[br]
##   3. 进探索 → 意图被消费 → 落到首图且地图已生成；[br]
##   4. 进首图 → AP / 节点数 / 入口已访问 / DAG 快照入 map_states；[br]
##   5. 真实 [code]move_to_node[/code] 一路走到 Boss；AP 不足时的拒绝路径。[br]
## [br][b]装置[/b]见 [code]one_run_smoke_fixture.gd[/code]（真实 Autoload + 场景
## 管理器桩 + 存档隔离）。[br]
##
## 来源: design/gdd/main-menu-system.md（三条路径）、design/gdd/exploration-system.md
## §1/§4、design/gdd/exploration-ui-system.md §1、ADR-0005、ADR-0014、ADR-0031 §2。

const SM := preload("res://src/foundation/scene_manager.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 主菜单「新游戏」→ 身份选择
# ═══════════════════════════════════════════════════════════════════════════════

func test_new_game_navigates_to_identity_select() -> void:
	# Arrange
	open_main_menu()

	# Act
	press_new_game()

	# Assert——导航目标是身份选择（不是别的场景）
	assert_eq(last_nav_target(), SM.SceneID.IDENTITY_SELECT,
			"点「新游戏」应导航到身份选择场景")


func test_new_game_does_not_leave_a_stale_entry_intent() -> void:
	# Arrange——上一局的残留意图（模拟「退出到主菜单再开新游戏」）
	IntentScript.request_resume()
	open_main_menu()

	# Act
	press_new_game()

	# Assert——新游戏这条路不消费也不改写意图；更不该把 RESUME 带进新局
	assert_true(IntentScript.has_pending(), "未进探索前意图应保持原样（未被消费）")
	assert_eq(IntentScript.take_entry_mode(), IntentScript.EntryMode.RESUME,
			"主菜单「新游戏」不应改写意图——改写归身份选择侧")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 身份选择① → 确认 → 开局意图 + 导航
# ═══════════════════════════════════════════════════════════════════════════════

func test_confirm_first_identity_writes_intent_and_navigates() -> void:
	# Arrange——身份表首项（默认解锁的那个）
	var identity_id: StringName = first_identity_id()
	assert_ne(str(identity_id), "", "前置：身份表应有条目")
	open_main_menu()
	press_new_game()
	var screen: Control = open_identity_select()

	# Act——选中 + 确认（走生产处理器，含二次门禁与 apply_identity）
	var accepted: bool = confirm_identity(screen, identity_id)

	# Assert——身份真的落进 GSM（不是只发了个信号）
	assert_true(accepted, "身份 %s 应能被选中确认" % identity_id)
	assert_eq(str(gsm.player.identity_id), str(identity_id),
			"确认后身份应写入 GSM")

	# Act——叙事结束（真实路径：确认 → 叙事 → narrative_finished → 请求导航）
	_skip_narrative(screen)

	# Assert——导航到探索，且这一跳发生在身份落地之后
	assert_eq(last_nav_target(), SM.SceneID.EXPLORATION,
			"确认并看完叙事（或跳过）后应导航到探索场景")


func test_confirm_first_identity_leaves_first_map_intent() -> void:
	# Arrange
	var identity_id: StringName = first_identity_id()
	open_main_menu()
	press_new_game()
	var screen: Control = open_identity_select()

	# Act——确认后走叙事；叙事一结束即请求「新开局」导航（意图在这一步落下）
	confirm_identity(screen, identity_id)
	_skip_narrative(screen)

	# Assert——意图是「直接进第一张图」而不是「停在选图界面」
	assert_eq(IntentScript.take_entry_mode(), IntentScript.EntryMode.FIRST_MAP,
			"新开局应留下 FIRST_MAP 意图（探索场景据此自动进首图）")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 探索容器消费意图 → 首图
# ═══════════════════════════════════════════════════════════════════════════════

func test_exploration_consumes_intent_and_enters_first_map() -> void:
	# Arrange——只留意图，探索容器挂载时消费（生产时序：先发意图再转场）
	IntentScript.request_new_run()

	# Act
	open_exploration()

	# Assert——直接落在首图，且节点图已挂起来（不是停在选图界面）
	assert_eq(current_map(), first_map_id(), "新开局应直接进入探明表首图")
	assert_not_null(node_graph(), "进图后应挂载节点图界面")
	assert_false(IntentScript.has_pending(),
			"意图应已被消费（取走即清——不会让玩家进两次图）")


func test_exploration_without_intent_stays_on_map_select() -> void:
	# Arrange——无意图（从暂停菜单回来等路径）
	IntentScript.clear()

	# Act
	open_exploration()

	# Assert——停在选图界面，不自动进图
	assert_null(node_graph(), "无意图时不应自动进图（应停在选图界面）")
	assert_eq(str(current_map()), "", "无意图时不应写入 current_map")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 进首图 → 导航状态与 DAG
# ═══════════════════════════════════════════════════════════════════════════════

func test_enter_first_map_initializes_navigation_state() -> void:
	# Arrange / Act——意图消费即进图（生产时序，不再手动调一次 enter_map）
	enter_first_map()

	# Assert——AP 满格、入口已访问、节点表非空
	assert_eq(ap(), max_ap(), "进图后行动力应为满格")
	assert_true(max_ap() > 0, "进图后行动力上限应大于 0")
	assert_eq(visited(), [ENTRY_NODE], "进图后只有入口节点记为已访问")
	var nodes: Dictionary = es.get(&"_node_details")
	assert_true(nodes.size() > 1, "地图应有多个节点（含 Boss）")
	assert_true(graph().size() > 1, "地图邻接表应非空")


func test_enter_first_map_caches_dag_snapshot_for_resume() -> void:
	# Arrange / Act
	enter_first_map()

	# Assert——DAG 快照入 map_states（读档续玩靠它重建）且入口计数递增
	var state: Dictionary = map_state()
	assert_eq(int(state.get("entry_count", 0)), 1, "首次进图 entry_count 应为 1")
	assert_eq(state.get("graph", {}), graph(),
			"map_states 应缓存本次生成的邻接表（读档续玩据此重建）")
	assert_true(state.has("nodes"), "map_states 应缓存节点详情快照")


# ═══════════════════════════════════════════════════════════════════════════════
# 5. 走到 Boss：真实 move_to_node
# ═══════════════════════════════════════════════════════════════════════════════

func test_walk_real_path_to_boss_node() -> void:
	# Arrange——进图并取图结构
	enter_first_map()
	var boss_node: int = boss_node_id()
	assert_true(boss_node > 0, "前置：地图应有 Boss 节点")

	# Act——按邻接表逐跳走到 Boss（每跳都断言系统受理，不接受静默失败）
	var path: Array[int] = path_to(boss_node)
	assert_true(path.size() > 0, "应存在一条从入口到 Boss 的路径")
	var from_node: int = ENTRY_NODE
	for hop: int in path:
		var result: Dictionary = es.call(&"move_to_node", from_node, hop)
		assert_true(bool(result.get("success", false)),
				"从 %d 走到 %d 应被受理（reason=%s）"
				% [from_node, hop, result.get("reason", "")])
		from_node = hop

	# Assert——真的站在 Boss 上
	assert_true(visited().has(boss_node), "走到 Boss 后它应记为已访问")
	assert_eq(int(gsm.exploration.get("node_position", {}).get("idx", -1)),
			boss_node % 100, "导航位置应落在 Boss 节点上")


func test_move_rejected_when_action_points_insufficient() -> void:
	# Arrange——进图后把行动力清零（Boss 是豁免节点，故挑一个非豁免目标）
	enter_first_map()
	var next_node: int = first_non_exempt_hop()
	assert_true(next_node > 0, "前置：入口应有非豁免的后继节点")
	gsm.set_exploration_ap(0, max_ap())

	# Act
	var result: Dictionary = es.call(&"move_to_node", ENTRY_NODE, next_node)

	# Assert——拒绝而不是崩溃，理由是可读的中文口径，且不写任何导航状态
	assert_false(bool(result.get("success", false)), "AP 不足时移动应被拒绝")
	assert_eq(str(result.get("reason", "")), str(es.get(&"REASON_AP_SHORT")),
			"拒绝理由应为「行动力不足」")
	assert_eq(visited(), [ENTRY_NODE], "被拒绝时不应写入已访问")


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 跳过开局叙事（真实路径上的跳过入口——同玩家按任意键）。[br]
## [br][b]转发而非重写[/b]：本组三条用例文件（冒烟 / 战斗 / 通关）都要跳过它，
## 实现只有一份（[method OneRunSmokeFixture.skip_narrative]），这里只留旧名方便读。
func _skip_narrative(screen: Control) -> void:
	skip_narrative(screen)

