extends "res://tests/integration/exploration_ui/tribulation_entry_fixture.gd"
## 节点图渡劫入口（[code]NodeInteractionPopupHost[/code] 的渡劫台确认）端到端 ——
## 真实系统 + 真实弹窗宿主，装置见基类。[br]
## [br][b]本轮修的是什么[/b]：节点图那条路原先只做了一半——确认渡劫时直接
## [code]request_scene_change(TRIBULATION)[/code]，[b]从不调
## [code]TribulationSystem.trigger_tribulation[/code][/b]。于是渡劫场景进战时状态还在
## [code]NOT_READY[/code]，[code]start_tribulation_combat[/code] 校验不过而降级成普通
## 战斗；[code]TribulationCombat.on_battle_ended[/code] 又因状态不是
## [code]IN_COMBAT[/code] 直接 return——[b]打赢也不进境、打输也不扣修为[/b]，
## 玩家从地图进的渡劫是空打一场。本文件钉住修好之后的那条路。[br]
## [br][b]为什么是集成测试[/b]：要验的是「点下去玩家的数据与状态机真的按渡劫走」，
## 见装置文件头「真实系统不替」。[br]
## [br][b]帧末到账[/b]：境界写入的 Cat 1 信号走 GSM 帧末缓冲，「上限跟着变」必须等帧
## （同 [code]test_cultivation_tribulation_entry.gd[/code] 口径）。[br]
##
## 来源: design/gdd/tribulation-system.md §1 地图渡劫点 + §2 准备阶段、
## design/gdd/exploration-ui-system.md §4c、ADR-0021 §trigger_tribulation /
## §start_tribulation_combat / §_on_battle_ended、ADR-0031 §2、AC-6。

## 以下两个常量基类没有（其余依赖与枚举都从基类取——重复声明会编译不过）。
const LaunchScript := preload("res://src/feature/tribulation/tribulation_launch.gd")
const SettlementScript := preload("res://src/feature/tribulation/tribulation_settlement.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# 1-2：触发顺序与失败收尾
# ═══════════════════════════════════════════════════════════════════════════════

func test_node_graph_tribulation_sets_preparing_and_requests_scene_once() -> void:
	# Arrange
	sm.current_id = SceneManagerScript.SceneID.EXPLORATION
	mount_host()
	var seen: Dictionary = watch_launch_results()
	# Act
	confirm_tribulation()
	# Assert——状态机真的进了 PREPARING（渡劫场景开战时会校验它），且转场恰好一次
	assert_eq(trib_state(), TS_SCRIPT.TribulationState.PREPARING,
			"节点图确认渡劫后必须先推进状态机——否则渡劫会降级成普通战斗")
	assert_eq(tribulation_requests().size(), 1, "应恰好发出一次渡劫转场请求")
	assert_eq(int(tribulation_requests()[0]["type"]),
			SceneManagerScript.TransitionType.TRIBULATION, "转场类型应为渡劫过渡")
	assert_eq((seen["outcomes"] as Array).size(), 1, "应回报一次入口结果")
	assert_eq(StringName(str((seen["outcomes"] as Array)[0])), LaunchScript.OUTCOME_STARTED,
			"被受理时结果令牌应为 started")


func test_node_graph_tribulation_rejected_transition_rolls_state_back() -> void:
	# Arrange——导航桩拒绝转场（模拟 SceneManager 的并发守卫）
	mount_host()
	sm.accept = false
	var seen: Dictionary = watch_launch_results()
	# Act
	confirm_tribulation()
	# Assert——状态退回（不把玩家永久卡在「渡劫流程进行中」）+ 可读中文回执
	assert_eq(trib_state(), TS_SCRIPT.TribulationState.NOT_READY,
			"转场被拒后渡劫状态应退回，否则玩家再也触发不了渡劫")
	assert_eq((seen["texts"] as Array).size(), 1, "应回报一次入口结果")
	assert_eq(str((seen["texts"] as Array)[0]), LaunchScript.TEXT_DEPART_FAILED,
			"应给出共用件里那句中文回执（两个入口同源）")


# ═══════════════════════════════════════════════════════════════════════════════
# 3-4：胜负回流（本轮的核心回归断言）
# ═══════════════════════════════════════════════════════════════════════════════

func test_node_graph_tribulation_victory_advances_realm() -> void:
	# Arrange——节点图那条路触发渡劫
	mount_host()
	confirm_tribulation()
	# Act——渡劫战真的开起来（状态闸过关），然后打赢
	var combat: CombatStub = start_combat()
	assert_eq(combat.configs.size(), 1, "状态闸过关后应把渡劫配置交给战斗系统")
	assert_true(bool(combat.configs[0].get("is_tribulation", false)),
			"交给战斗系统的应是渡劫战配置")
	assert_eq(trib_state(), TS_SCRIPT.TribulationState.IN_COMBAT,
			"开战后状态机应进入 IN_COMBAT（结算据此认领这场仗）")
	TribulationSystem.call(&"_on_battle_ended", COMBAT_VICTORY, {})
	await get_tree().process_frame
	# Assert——真的进境，且修为上限按新境界重算（旧世界的 bug 在这里）
	assert_eq(realm(), 2, "从节点图进的渡劫打赢应真的进境")
	assert_eq(int(GameStateManager.player.max_cultivation),
			TableScript.required_cultivation(2), "修为上限应按新境界重算")
	assert_eq(trib_state(), TS_SCRIPT.TribulationState.NOT_READY,
			"结算完应回到 NOT_READY（可再次攒修为）")


func test_node_graph_tribulation_defeat_deducts_cultivation_only() -> void:
	# Arrange——筑基期修为满（渡劫触发的前提），从节点图触发
	_reset_player(2)
	var max_cult: int = TableScript.required_cultivation(2)
	mount_host()
	confirm_tribulation()
	start_combat()
	# Act——打输
	TribulationSystem.call(&"_on_battle_ended", COMBAT_DEFEAT, {})
	await get_tree().process_frame
	# Assert——扣 floor(max × 0.15)，境界纹丝不动
	var penalty: int = int(floor(float(max_cult) * SettlementScript.FAILURE_PENALTY_RATIO))
	assert_eq(cultivation(), max_cult - penalty,
			"失败应按 max_cultivation × %f 扣修为" % SettlementScript.FAILURE_PENALTY_RATIO)
	assert_eq(realm(), 2, "渡劫失败境界不变")
	assert_eq(trib_state(), TS_SCRIPT.TribulationState.NOT_READY, "结算完应回到 NOT_READY")


# ═══════════════════════════════════════════════════════════════════════════════
# 5-6：两条路同源；渡劫系统缺失时两边都禁用
# ═══════════════════════════════════════════════════════════════════════════════

## 修炼室那半边的转场参数与回执（走真实按钮路径）。[br]
## [br][b]返回[/b]：[code]{requests, text}[/code]——与节点图那半边逐字对比。
func _cultivation_side() -> Dictionary:
	_reset_player(1)
	sm.current_id = SceneManagerScript.SceneID.CULTIVATION
	mount_cultivation()
	screen.call(&"press_breakthrough")
	return {
		"requests": tribulation_requests().duplicate(true),
		"text": str(screen.call(&"message_text")),
	}


func test_both_entries_share_one_launch_path() -> void:
	# Arrange——修炼室半边：修为满 → 按「渡劫」
	var from_cultivation: Dictionary = _cultivation_side()
	# 退回未触发态，好让节点图半边从同一个起点再走一次
	TribulationSystem.call(&"cancel_tribulation")
	sm.requests.clear()
	# Act——节点图半边：同一起点、同样确认
	sm.current_id = SceneManagerScript.SceneID.EXPLORATION
	mount_host()
	confirm_tribulation()
	var from_node_graph: Array = tribulation_requests()
	# Assert——目标与过渡类型逐字一致（同一条顺序）；回执也取自同一处文案
	var cult_requests: Array = from_cultivation["requests"]
	assert_eq(cult_requests.size(), 1, "修炼室应按「渡劫」发出一转场")
	assert_eq(from_node_graph.size(), 1, "节点图应发出一转场")
	assert_eq(int(from_node_graph[0]["to"]), int(cult_requests[0]["to"]),
			"两个入口的目标场景必须一致")
	assert_eq(int(from_node_graph[0]["type"]), int(cult_requests[0]["type"]),
			"两个入口的过渡类型必须一致")
	assert_eq(str(from_cultivation["text"]), LaunchScript.TEXT_STARTED,
			"修炼室的回执应取自共用件（不得各写一份）")


func test_missing_tribulation_system_blocks_both_entries() -> void:
	# Arrange——一个「有对象但没方法」的桩渡劫系统
	var stub := BareTribulation.new()
	add_child_autofree(stub)
	# Act + Assert（节点图半边）——不发转场，且回执可读
	mount_host(stub)
	var seen: Dictionary = watch_launch_results()
	confirm_tribulation()
	assert_eq(tribulation_requests().size(), 0, "渡劫系统不可用时节点图不得请求转场")
	assert_eq(trib_state(), TS_SCRIPT.TribulationState.NOT_READY,
			"渡劫系统不可用时不得动状态机")
	assert_eq((seen["texts"] as Array).size(), 1, "应回报一次入口结果")
	assert_eq(str((seen["texts"] as Array)[0]), LaunchScript.TEXT_TRIBULATION_UNAVAILABLE,
			"应给出可读的中文原因")
	# Act + Assert（修炼室半边）——第二行灰着，点下去也给原因、也不转场
	sm.requests.clear()
	mount_cultivation(stub)
	assert_false(bool(screen.call(&"is_breakthrough_enabled")),
			"渡劫系统不可用时修炼室的第二行应禁用")
	screen.call(&"press_breakthrough")
	assert_eq(tribulation_requests().size(), 0, "渡劫系统不可用时修炼室不得请求转场")
	assert_eq(str(screen.call(&"message_text")), LaunchScript.TEXT_TRIBULATION_UNAVAILABLE,
			"点禁用行应给出同一句可读原因")
