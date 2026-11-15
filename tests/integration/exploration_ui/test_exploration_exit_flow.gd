extends "res://tests/integration/exploration_ui/exploration_exit_fixture.gd"
## 探索退出闭环 · 结算与结束原因 —— 从节点图主动结束探索。[br]
## [br][b]本文件补的断链[/b]：[code]NodeGraphScreen.back_to_map_select_requested[/code]
## 此前[b]全库无消费者[/b]（信号声明了、按钮也接了、就是没人听），
## [code]ExplorationSystem.end_exploration[/code] 也只有测试调得到。于是行动力见底
## 或想收手的玩家只能一直卡在节点图里——GDD exploration-system.md §8「退出按钮在
## 探索HUD中始终可用」与 §5「行动力归零且无法到达Boss → 立即结算」两条都无处落地。[br]
## [br][b]覆盖[/b]（交互与回退见 [code]test_exploration_exit_navigation.gd[/code]）：[br]
##   1. [b]结算真的发生[/b]——退出把 [code]collected_*[/code] 全额转入
##      [code]player.*[/code]（走既有 [code]ExplorationMapFlush[/code]，不另开通路）；[br]
##   2. [b]原因是主动退出[/b]——[code]EndReason.PLAYER_QUIT[/code]（GDD §8 明说它
##      与行动力归零结算相同、区别只在触发方式）；[br]
##   3. [b]两步确认[/b]——只按下不结算，确认才结算（GDD §AC 写的是两步）；[br]
##   4. 退出不写通关标记（§8：不获得通关奖励、地图标记为未通关）。[br]
## [br][b]装置[/b]见 [code]exploration_exit_fixture.gd[/code]（真实 Autoload + GSM 隔离）。
##
## 来源: design/gdd/exploration-system.md §5 结束条件 / §8 边界 + §AC 退回地图选择、
## ADR-0014 §决策 5 探索结束结算、ADR-0031 §2（UI 零状态所有权）。

const SystemScript := preload("res://src/feature/exploration_system.gd")


func test_exit_returns_collected_resources_to_the_player() -> void:
	# Arrange——进图并收集一点灵石
	_enter_map()
	es.call("collect_resource", &"ling_shi", COLLECTED_LING_SHI)
	var before: int = int(gsm.player.resources.get("ling_shi", 0))
	# Act——玩家确认退出
	_confirm_exit()
	# Assert——全额到账（与行动力归零结算相同，GDD §8）
	assert_eq(int(gsm.player.resources.get("ling_shi", 0)), before + COLLECTED_LING_SHI,
			"主动退出应全额保留已收集的灵石")


func test_exit_clears_navigation_state_and_dag_cache() -> void:
	# Arrange
	_enter_map()
	assert_eq(gsm.exploration.get("current_map"), MAP_ID, "前置：已在图内")
	# Act
	_confirm_exit()
	# Assert——导航状态与 DAG 缓存都清干净（ADR-0014 §决策 5）
	assert_eq(gsm.exploration.get("current_map"), &"", "current_map 应清空")
	assert_eq(gsm.exploration.get("visited_nodes"), [], "visited_nodes 应清空")
	assert_eq(gsm.exploration.get("node_position"), {"layer": 0, "idx": 0},
			"node_position 应复位到入口（下次进图从入口开始）")
	assert_eq(es.get("_dag_ready"), false, "DAG 缓存应清理")


func test_exit_does_not_mark_the_map_as_cleared() -> void:
	## GDD §8：主动退出「不获得通关奖励，地图标记为未通关」。
	# Arrange
	_enter_map()
	# Act
	_confirm_exit()
	# Assert——map_states 里没有通关标记
	var state: Dictionary = (gsm.exploration.get("map_states", {}) as Dictionary).get(MAP_ID, {})
	assert_false(bool(state.get("is_first_clear", false)),
			"主动退出不该把地图标成已通关（否则下次进来拿不到首通奖励）")


func test_exit_reason_is_player_quit() -> void:
	# Arrange
	_enter_map()
	# Act
	_confirm_exit()
	# Assert
	assert_eq(_ended_reasons.size(), 1, "退出应恰好广播一次 exploration_ended")
	assert_eq(int(_ended_reasons[0]), SystemScript.EndReason.PLAYER_QUIT,
			"结束原因应为「玩家主动退出」，不是行动力耗尽")


func test_pressing_exit_alone_does_not_settle() -> void:
	# Arrange
	_enter_map()
	# Act——只按下按钮（还没确认）
	_exit_button().pressed.emit()
	# Assert——弹窗已开、结算未发生
	assert_true(_graph().status_bar().call(&"is_confirm_open"),
			"按下应打开退出确认窗")
	assert_eq(gsm.exploration.get("current_map"), MAP_ID, "未确认前不该结算")
	assert_true(_ended_reasons.is_empty(), "未确认前不该广播探索结束")


func test_canceling_keeps_the_player_in_the_map() -> void:
	# Arrange
	_enter_map()
	_exit_button().pressed.emit()
	# Act——玩家选择继续探索
	_exit_dialog().canceled.emit()
	_exit_dialog().hide()
	# Assert——还在图里，界面也没被拆
	assert_eq(gsm.exploration.get("current_map"), MAP_ID, "取消后应留在图内")
	assert_not_null(_graph(), "取消后节点图应仍在")


func test_exit_works_at_zero_action_points() -> void:
	## §5 的「行动力归零且无法到达Boss → 立即结算」正需要这条路径走得通。
	# Arrange
	_enter_map()
	gsm.call(&"set_exploration_ap", 0, int(gsm.exploration.get("max_action_points", 5)))
	# Act
	_confirm_exit()
	# Assert
	assert_eq(gsm.exploration.get("current_map"), &"", "AP=0 时退出同样应结算")
	assert_null(scene.get("node_graph_screen"), "AP=0 时退出同样应回到地图选择")
