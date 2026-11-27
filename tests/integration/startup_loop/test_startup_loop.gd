extends "res://tests/integration/startup_loop/startup_loop_fixture.gd"
## 「新开局 → 进图 → 打完 Boss → 存档 → 重启后继续」主线的端到端验收。[br]
## [br][b]为什么需要[/b]：本轮之前这条线上有四处断路，各自都有单点用例，但没有一条
## 用例把它们串起来走完——[br]
##   ① 新开局落在[b]选图界面[/b]而不是第一张图（身份选择不落进入意图）；[br]
##   ②「继续游戏」读档成功后[b]没有任何导航[/b]（死路）；[br]
##   ③ 自动存档此前是[b]静默空操作[/b]（[code]SaveLoadSystem.auto_save[/code] 不存在），
##      「打完 Boss 直接退出」的玩家什么都没留下；[br]
##   ④ 读档后[b]回不到上次那张图[/b]（探索场景挂载时不查 GSM 的导航状态）。[br]
## 单点用例各自绿着，串起来却断——这正是本文件存在的理由。[br]
## [br][b]断言的层次[/b]：不只断言界面可见性——每一步都读[b]真实状态[/b]
## （GSM 的探索域 / 收藏 / 灵石 / [code]map_states[/code] 通关记录），存档走
## [b]真实文件读写[/b]（只把存档根换到专用目录），重启走「内存清空 + 静态缓存清空」
## 的真实语义。[br]
## [br][b]桩只用在 SceneManager[/b]：它是导航仲裁者，真转场会换掉测试进程的主场景；
## 桩记录 [code]request_scene_change[/code] 调用，用例据此断言「真的请求了那一跳」。[br]
##
## 来源: design/gdd/main-menu-system.md（三条路径）、exploration-system.md §5 通关、
## ADR-0002、ADR-0005、ADR-0014 §决策 5、ADR-0031 §2。

## 主线里走的那张图（探明表首项——新开局的落点）。
const MAP: StringName = &"qing_yun_jian_zong"


# ═══════════════════════════════════════════════════════════════════════════════
# 主线：一条路走完
# ═══════════════════════════════════════════════════════════════════════════════

func test_new_run_to_map_to_boss_to_save_to_restart_to_continue() -> void:
	# ── ① 新开局：身份选择确认 → 叙事跳过 → 请求进第一张图 ────────────────────
	var mode: int = start_new_run()
	assert_eq(mode, IntentScript.EntryMode.NONE,
			"新开局不应再落「直接进第一张图」的意图（2026-11-27 修）：确认身份后停在选图界面，由玩家自己点地图")
	assert_eq(sm.change_calls.size(), 1, "新开局应请求一次转场")
	assert_eq(int(sm.change_calls[0][1]), SM.SceneID.EXPLORATION,
			"新开局的目标应为探索（不再是主菜单原地不动）")
	# 玩家在选图界面点了第一张图（等价于点卡片），后面才走「进图 → Boss ⋯」主线。
	enter_first_map_by_intent()

	# ── ② 进图：薄容器消费意图，直接落到第一张图 ──────────────────────────────
	var scene: Control = enter_exploration_scene()
	assert_not_null(scene.get("node_graph_screen"),
			"新开局应直接进图（不必玩家再点一次地图卡）")
	assert_eq(gsm.exploration.get("current_map"), MAP, "落点应为探明表首项（青云剑宗）")
	assert_eq(str(gsm.player.identity_id), str(IDENTITY), "身份应已写入存档状态")

	# 玩家在图上走一步——真实消耗行动力、真实记已访问
	var stepped: int = walk_one_step()
	assert_true(stepped > 0, "前置：第一层的节点应可移动（图才走得动）")
	var ap_after_walk: int = int(gsm.exploration.get("action_points"))
	var visited_after_walk: Array = (gsm.exploration.get("visited_nodes") as Array).duplicate()
	assert_true(visited_after_walk.size() >= 2, "走过一步后应有入口 + 目标两个已访问节点")

	# ── ③ 打完 Boss：真实通关结算 ───────────────────────────────────────────
	defeat_boss()
	assert_true(bool(map_state(MAP).get("is_first_clear", false)),
			"Boss 胜利应把本图标记为已通关")
	assert_eq(int(map_state(MAP).get("clear_count", 0)), 1, "首次通关的计数应为 1")
	assert_true(owned_templates().has(str(FIRST_CLEAR_CARD)),
			"首通彩头应真的进了收藏（校验开启——不是被静默拒绝）")
	assert_true(ling_shi() > 0, "通关奖励的灵石应已入账")

	# ── ④ 存档：生产写入点是场景切换时的自动存档 ──────────────────────────────
	var saved: Variant = sls.auto_save()
	assert_eq(saved, SLS.SaveResult.SUCCESS, "已开局时自动存档应真的写盘（此前是空操作）")
	drop(scene)  # 转场会释放探索场景

	# ── ⑤ 重启：内存与跨场景静态缓存按真实重启语义清空 ────────────────────────
	simulate_restart()
	assert_eq(str(gsm.player.identity_id), "", "前置：内存状态确已清空")
	assert_eq(gsm.exploration.get("current_map"), &"", "前置：导航状态确已清空")
	assert_true(map_state(MAP).is_empty(), "前置：map_states 也随内存清空")

	# ── ⑥ 继续游戏：读最新档 → 发续玩意图 → 转场探索 ─────────────────────────
	var menu: Control = mount_main_menu()
	assert_false(menu.continue_button.disabled, "有档时「继续游戏」应亮起")
	var intent: int = press_continue(menu)
	assert_eq(sm.change_calls.size(), 2, "继续游戏应请求一次转场（此前这里是死路）")
	assert_eq(int(sm.change_calls[1][1]), SM.SceneID.EXPLORATION,
			"继续游戏的目标应为探索场景")
	assert_eq(intent, IntentScript.EntryMode.RESUME,
			"继续游戏留下的意图应为「续玩」——探索场景据此决定落到哪")

	# ── ⑦ 落地：读到的是存档里的真实状态，而不是一份空档 ──────────────────────
	assert_eq(str(gsm.player.identity_id), str(IDENTITY), "身份应从存档恢复")
	assert_eq(int(map_state(MAP).get("clear_count", 0)), 1, "通关记录应从存档恢复")
	assert_true(owned_templates().has(str(FIRST_CLEAR_CARD)), "首通彩头应从存档恢复")
	assert_true(ling_shi() > 0, "灵石余额应从存档恢复")
	assert_false((gsm.deck.current_deck as Array).is_empty(), "卡组应从存档恢复")
	# Boss 通关已清导航状态（GDD §7：通关后回到地图选择，由玩家挑下一张）——
	# 此时「没有进行中的图」，探索场景如实停在选图界面，而不是臆造一张。
	var back: Control = enter_exploration_scene()
	assert_not_null(back.get("map_select_screen"),
			"通关后没有进行中的图——应停在选图界面让玩家挑下一张")
	assert_eq(gsm.exploration.get("current_map"), &"",
			"不得凭空写入一个地图 ID")


# ═══════════════════════════════════════════════════════════════════════════════
# 未通关的档：继续游戏真的回到上次那张图
# ═══════════════════════════════════════════════════════════════════════════════

func test_continue_returns_to_in_progress_map_with_progress_intact() -> void:
	## 主线另一半：手上还有进行中的图时，「继续游戏」要回到那张图，且进度不许被抹。[br]
	## [br][b]重生成地图的典型症状[/b]：回到入口、行动力回满、已访问清空——本用例
	## 就是盯着这三样。
	# ── Arrange：开局 → 进图 → 走一步 → 存档 ────────────────────────────────
	start_new_run()
	# 玩家在选图界面点了第一张图（2026-11-27 起新开局不再自动进图）。
	enter_first_map_by_intent()
	var scene: Control = enter_exploration_scene()
	var stepped: int = walk_one_step()
	assert_true(stepped > 0, "前置：应能走一步")
	var ap_before: int = int(gsm.exploration.get("action_points"))
	var visited_before: Array = (gsm.exploration.get("visited_nodes") as Array).duplicate()
	var graph_before: Dictionary = (es.get("_node_graph") as Dictionary).duplicate(true)
	assert_ne(ap_before, 10, "前置：行动力已被消耗过（与「回满」可区分）")
	assert_eq(sls.auto_save(), SLS.SaveResult.SUCCESS, "前置：存档写盘成功")
	drop(scene)

	# ── Act：重启 → 主菜单继续游戏 → 探索场景挂载 ────────────────────────────
	simulate_restart()
	var menu: Control = mount_main_menu()
	assert_eq(press_continue(menu), IntentScript.EntryMode.RESUME, "应留下续玩意图")
	var back: Control = enter_exploration_scene()

	# ── Assert：回到了那张图，且进度原样 ────────────────────────────────────
	assert_not_null(back.get("node_graph_screen"), "读档续玩应直接回到存档里那张图")
	assert_eq(gsm.exploration.get("current_map"), MAP, "当前地图应为存档里那张图")
	assert_eq(gsm.exploration.get("visited_nodes"), visited_before,
			"已访问节点不得被重置为入口（重生成地图的典型症状）")
	assert_eq(int(gsm.exploration.get("action_points")), ap_before,
			"剩余行动力不得回满（重生成地图的典型症状）")
	var renderer: Node = (back.get("node_graph_screen") as Control).get("viewport").renderer
	assert_eq(renderer.get("graph"), graph_before,
			"节点图应渲染存档里那张 DAG，而不是重新生成的新图")


# ═══════════════════════════════════════════════════════════════════════════════
# 无档：继续游戏置灰 + 中文提示（真实存档系统口径）
# ═══════════════════════════════════════════════════════════════════════════════

func test_continue_disabled_with_chinese_hint_when_no_save_exists() -> void:
	## 空槽位目录（[code]before_each[/code] 刚清过测试存档根）——断言真实
	## [code]list_slots()[/code] 驱动的按钮态，而不是注入的 mock 返回值。
	# Act
	var menu: Control = mount_main_menu()
	# Assert
	assert_true(menu.continue_button.disabled, "无档时「继续游戏」应置灰")
	assert_true(menu.load_button.disabled, "无档时「读档」应置灰")
	assert_eq(menu.no_save_hint_label.text, menu.TEXT_NO_SAVE_CONTINUE,
			"无档时应给出一句中文说明")
	assert_false(menu.no_save_hint_label.text.strip_edges().is_empty(), "提示不得为空串")
	# 置灰态下点击不得导航（键盘焦点防御）
	press_continue(menu)
	assert_eq(sm.change_calls.size(), 0, "无档时点击不得请求转场")
	assert_false(IntentScript.has_pending(), "无档时不得留下待消费意图")
