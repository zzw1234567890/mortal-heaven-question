extends "res://tests/integration/hud/pause_menu_battle_fixture.gd"
## 暂停菜单「战斗中存档」验收：存档那一刻把这一仗写进档，并如实告知玩家。[br]
## [br][b]补的断链[/b]：战斗中按「存档」此前只写探索进度——[code]battle[/code] 域不可
## 持久化（ADR-0008），读回来玩家站在地图上，那场仗连同残血静默消失。本文件钉住
## [b]存的那半[/b]：抓快照 → 落进 GSM → 反馈文案说实话。[br]
## [br][b]为什么要单独一份文件[/b]：断的不是「写盘成不成」而是「写进去的是不是这一仗」，
## 而 [code]test_pause_menu_save.gd[/code] 那份的替身 GSM 没有第二层写入面
## （替身不做 [code]_set_battle_resume[/code] 就只能测到写盘失败那条路）。[br]
## [br][b]覆盖[/b]：[br]
##   1. 战斗中存档 → 续战段落库，反馈说「读取此档将回到当前战斗」；[br]
##   2. 残血（敌方 / 我方）与阵型如实进档，载荷 JSON 安全且折回的上下文能过开战校验；[br]
##   3. 探索中存档不受影响（没有战斗段、反馈仍是「已存档」）；[br]
##   4. 不可续战（无探索来源 / 我方阵位读不到 / GSM 无写入面）→ 中文原因，
##      且[b]不[/b]谎称可续。[br]
## [br]装置见 [code]pause_menu_battle_fixture.gd[/code]（战斗 / 布阵 / GSM 三份替身）。[br]
## [br]注：[code]SLS[/code] / [code]SM[/code] / [code]PayloadScript[/code] /
## [code]ContextScript[/code] 与角色 ID 段由装置提供，此处不重复声明——GDScript 子类
## 重复同名成员是解析错误，整个文件会被 GUT 静默忽略。[br]
## [br]来源: ADR-0008 §GSM 边界、ADR-0031 §2、本轮「战斗中存档 → 读档回到战斗」（A / D 项）。

const SLS_JSON := preload("res://src/foundation/save_load_system.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 战斗中存档：写进去的是这一仗
# ═══════════════════════════════════════════════════════════════════════════════

func test_save_in_battle_writes_resume_section_and_tells_player() -> void:
	# Arrange
	arrange_battle()
	open_menu()
	# Act
	menu._on_save_pressed()
	# Assert——续战段真的落库了
	assert_eq(resume_gsm.resume_writes, 1, "战斗中存档应写一次续战段（GSM 第二层原子方法）")
	assert_true(PayloadScript.is_in_battle(resume_gsm.battle_resume),
			"写进去的段应带「进行中战斗」标记")
	assert_true(PayloadScript.is_resumable_payload(resume_gsm.battle_resume),
			"写进去的段应可续战（名册齐备）")
	# Assert——进度如实（取的是存档那一刻的活值，不是出厂值）
	var payload: Dictionary = resume_gsm.battle_resume
	assert_eq(int(payload[PayloadScript.KEY_TURN]), combat.turn, "回合应取存档那一刻的活值")
	assert_eq(int(payload[PayloadScript.KEY_PHASE]), combat.phase, "阶段应取存档那一刻的活值")
	assert_eq(int(payload[PayloadScript.KEY_CURRENT_COST]), CostSystem.get_current_cost(),
			"费用应取存档那一刻的活值")
	assert_eq(int(payload[PayloadScript.KEY_ORIGIN_NODE_ID]), NODE_ID, "来源节点应记住")
	assert_eq(int(payload[PayloadScript.KEY_SCENE_ID]), SM.SceneID.COMBAT,
			"存档场景应记为战斗场景")
	# Assert——反馈说实话（不说「已存档」让玩家以为读回来还在地图上）
	assert_eq(status_text(), menu.get_actions().TEXT_SAVED_IN_BATTLE,
			"战斗中的存档反馈应说明「读取此档将回到当前战斗」")
	assert_eq(sl.save_calls.size(), 1, "存档仍写一次盘（探索进度与战斗段同一份档）")


func test_saved_payload_keeps_enemy_damage_and_player_hp() -> void:
	## 残血必须存住——否则读回来的是「按模板满血重开」，等于白打。
	# Arrange
	arrange_battle()
	open_menu()
	# Act
	menu._on_save_pressed()
	# Assert——敌方残血
	var enemies: Array = PayloadScript.enemy_entries(
			resume_gsm.battle_resume[PayloadScript.KEY_ENEMY_ROSTER])
	assert_eq(enemies.size(), 1, "敌方名册应逐条进档")
	assert_eq(int(enemies[0][PayloadScript.KEY_CURRENT_HP]), ENEMY_HP,
			"敌方残血应如实进档（不是模板满血）")
	assert_eq(int(enemies[0][PayloadScript.KEY_MAX_HP]), ENEMY_MAX_HP, "上限应如实进档")
	assert_eq(str(enemies[0][PayloadScript.KEY_TEMPLATE_ID]), ENEMY_TEMPLATE,
			"模板 ID 应落 String（StringName 往返会变 String，写侧就统一）")
	# Assert——我方残血与阵容
	var stats: Dictionary = PayloadScript.player_stats(resume_gsm.battle_resume)
	assert_eq(int(stats[CHAR_A][PayloadScript.KEY_CURRENT_HP]), 4, "我方残血应如实进档")
	assert_eq(int(stats[CHAR_B][PayloadScript.KEY_MAX_HP]), 9, "我方 HP 上限应如实进档")
	assert_eq(PayloadScript.player_ids(resume_gsm.battle_resume), [CHAR_A, CHAR_B],
			"出战阵容应按阵位顺序进档")
	assert_eq(PayloadScript.player_layout(resume_gsm.battle_resume),
			{CHAR_A: true, CHAR_B: false}, "前后排应进档（读档不过备战面板）")


func test_saved_payload_is_json_safe_and_rebuilds_launch_context() -> void:
	## 载荷过不了存档类型校验，会让[b]整份[/b]存档被判 VALIDATION_ERROR ——
	## 连探索进度一起写不进去（本轮最贵的一个坑）。
	# Arrange
	arrange_battle()
	open_menu()
	# Act
	menu._on_save_pressed()
	var payload: Dictionary = resume_gsm.battle_resume
	# Assert——JSON 安全
	assert_true(SLS_JSON._is_json_compatible(payload),
			"折出的载荷必须只含 JSON 兼容类型（对象与 StringName 都要被折叠掉）")
	# Assert——折回的上下文能过开战校验（否则「读档回到战斗」进不去）
	var context: Dictionary = PayloadScript.launch_context(payload)
	assert_true(ContextScript.validate(context).is_empty(),
			"折回的上下文必须过开战校验：%s" % ContextScript.validate(context))
	assert_eq(int(context[ContextScript.KEY_ENEMY_LEVEL]), 2, "节点档位应折回")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 不在战斗中：老行为一字不动
# ═══════════════════════════════════════════════════════════════════════════════

func test_save_outside_battle_clears_resume_and_keeps_plain_message() -> void:
	# Arrange——战斗已结束（战斗系统报 inactive）
	arrange_battle()
	combat.active = false
	open_menu()
	# Act
	menu._on_save_pressed()
	# Assert——清档（写空段）而不是留下一盘打完的棋
	assert_eq(resume_gsm.battle_resume, {}, "不在战斗中时续战段应为空（清掉上一场）")
	assert_eq(status_text(), "已存档", "不在战斗中时反馈仍是朴素的「已存档」")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 不可续战：说中文，且不谎称可续（需求 D）
# ═══════════════════════════════════════════════════════════════════════════════

func test_save_without_exploration_origin_shows_chinese_reason() -> void:
	## 渡劫等没有探索来源的战斗：存档照存（探索进度是真的），但必须说清楚。
	# Arrange——战斗活跃、阵位齐备，但跨场景上下文是空的（无来源）
	arrange_battle()
	ContextScript.clear()
	open_menu()
	# Act
	menu._on_save_pressed()
	# Assert——仍然存了盘
	assert_eq(sl.save_calls.size(), 1, "不可续战也要存（探索进度与成长都在同一份档里）")
	# Assert——但没有谎称可续
	assert_eq(resume_gsm.battle_resume, {}, "不可续战时不得写下续战段")
	assert_ne(status_text(), menu.get_actions().TEXT_SAVED_IN_BATTLE,
			"不可续战时不得说「读取此档将回到当前战斗」")
	assert_true(status_text().begins_with("已存档（当前战斗无法续战："),
			"应把原因接在「已存档」之后：%s" % status_text())
	assert_true(status_text().contains("无法续玩"), "原因应为中文可读文案")


func test_save_with_crippled_roster_does_not_claim_resumable() -> void:
	## 我方阵位读不到 → 载荷判为残：写入它等于写一份读回来「不可续战」的档，
	## 而反馈却说可续——两头必须同一件事。
	# Arrange——战斗活跃、有来源，但布阵读不到（field 空）
	arrange_battle()
	deployment.field = []
	open_menu()
	# Act
	menu._on_save_pressed()
	# Assert
	assert_eq(resume_gsm.battle_resume, {}, "残载荷不得留库（读回来只会退回探索地图）")
	assert_true(status_text().contains("战斗记录不完整"),
			"应说清是记录不完整：%s" % status_text())
	assert_false(status_text().contains("将回到当前战斗"),
			"更不得同时宣称可续——那是对玩家说谎")


func test_save_without_gsm_write_surface_reports_not_written() -> void:
	## GSM 没有写入面（替身 / 降级路径）：快照等于没落库，反馈不得说「已写入」。
	# Arrange——换成没有 [code]_set_battle_resume[/code] 的基础替身
	arrange_battle()
	menu.gsm = gsm
	open_menu()
	# Act
	menu._on_save_pressed()
	# Assert
	assert_ne(status_text(), menu.get_actions().TEXT_SAVED_IN_BATTLE,
			"没落库就不得说可续（GSM 缺失时写入是无声失败）")
	assert_true(status_text().contains("未能写入"),
			"应说明战斗进度未能写入：%s" % status_text())
