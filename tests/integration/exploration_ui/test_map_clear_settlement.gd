extends "res://tests/integration/exploration_ui/map_clear_settlement_fixture.gd"
## 地图通关结算 · 从 Boss 胜利到结算面板 —— 一张图从进图到通关的收束。[br]
## [br][b]本文件补的断链[/b]：Boss 节点战斗胜利此前只走
## [code]add_visited_node[/code]（标一格已清），结算域里的 [code]BOSS_DEFEATED[/code]
## 分支虽有实现却[b]只有单测调得到[/b]——生产路径唯一调用方是
## [code]ExplorationScene[/code]，而它发的是 [code]PLAYER_QUIT[/code]。于是
## 「打完 Boss 就算通关」既没写进 [code]map_states[/code]、也拿不到通关奖励、
## 更没有结算面板（GDD §7 四段全是空转）。[br]
## [br][b]覆盖[/b]（纯文案判据见
## [code]tests/unit/exploration_ui/test_map_clear_panel_rules.gd[/code]）：[br]
##   1. Boss 胜利 → 本图标记通关（[code]is_first_clear[/code] + [code]clear_count[/code]）；[br]
##   2. 通关奖励真的入账（灵石 / 修为 / 首通彩头卡进收藏）；[br]
##   3. 首通与重复通关分开——首通有额外奖励，重复通关不再发稀有卡；[br]
##   4. 结算面板弹出并按 GDD §7 渲染（首通行只在首通出现）；[br]
##   5. 普通/精英胜利仍只标一格已清（不误触发通关）；[br]
##   6. 面板「确认」回到地图选择（收起 overlay + 刷新列表）。[br]
## [br][b]装置[/b]见 [code]map_clear_settlement_fixture.gd[/code]（真实 Autoload + 存档隔离）。
##
## 来源: design/gdd/exploration-system.md §5 地图通关奖励 / §6 Boss节点与地图通关、
## design/gdd/exploration-ui-system.md §7 地图通关结算 + §AC、
## ADR-0014 §决策 5 探索结束结算、ADR-0031 §2。


# ═══════════════════════════════════════════════════════════════════════════════
# 1. Boss 胜利 = 本图通关（写进 map_states）
# ═══════════════════════════════════════════════════════════════════════════════

func test_boss_victory_marks_the_map_as_cleared() -> void:
	# Arrange——玩家在图里
	enter_map()
	assert_false(bool(map_state().get("is_first_clear", false)), "前置：本图尚未通关")
	# Act——打完 Boss
	run_victory(LaunchScript.COMBAT_TYPE_BOSS)
	# Assert——通关标记写进 map_states（GDD §6「Boss击败 → 地图标记为已通关」）
	assert_true(bool(map_state().get("is_first_clear", false)), "Boss 胜利应把本图标为已通关")
	assert_eq(int(map_state().get("clear_count", 0)), 1, "首通后通关次数为 1")


func test_boss_victory_clears_navigation_state() -> void:
	# Arrange
	enter_map()
	# Act
	run_victory(LaunchScript.COMBAT_TYPE_BOSS)
	# Assert——通关即结束本局探索（ADR-0014 §决策 5）
	assert_eq(gsm.exploration.get("current_map"), &"", "通关后导航状态应清空")
	assert_eq(gsm.exploration.get("visited_nodes"), [], "visited_nodes 应清空")


func test_non_boss_victory_only_marks_the_node() -> void:
	## 普通/精英战斗的胜利不该让整张白送——否则玩家打一格小兵就通关了。
	# Arrange
	enter_map()
	# Act——精英战斗胜利（开战上下文记 combat）
	run_victory(&"combat")
	# Assert——只标一格已清，不写通关标记
	assert_true((gsm.exploration.get("visited_nodes", []) as Array).has(BOSS_NODE),
			"普通战斗胜利应把该节点标为已清")
	assert_false(bool(map_state().get("is_first_clear", false)),
			"普通战斗胜利不该把地图标成已通关")
	assert_eq(gsm.exploration.get("current_map"), MAP_ID, "普通战斗不结束本局探索")


func test_boss_defeat_does_not_mark_the_map() -> void:
	# Arrange
	enter_map()
	ViewScript.publish(_defeat_view())
	LaunchScript.publish({LaunchScript.KEY_NODE_ID: BOSS_NODE,
			LaunchScript.KEY_COMBAT_TYPE: LaunchScript.COMBAT_TYPE_BOSS})
	var screen: Node = ResultScreenScript.new()
	screen.set(&"screen_id", 9)
	add_child_autofree(screen)
	# Act
	screen.call(&"_mark_battle_node_cleared_if_victory")
	# Assert——战败不算通关
	assert_false(bool(map_state().get("is_first_clear", false)),
			"Boss 战失败不该把地图标成已通关")
	assert_eq(gsm.exploration.get("current_map"), MAP_ID, "战败不该结束本局探索")


# ═══════════════════════════════════════════════════════════════════════════════
# 2/3. 通关奖励与首通差别
# ═══════════════════════════════════════════════════════════════════════════════

func test_first_clear_grants_base_and_first_rewards() -> void:
	# Arrange——余额与修为清零以隔离奖励增量
	enter_map()
	gsm.player.resources.ling_shi = 0
	gsm.player.cultivation = 0
	gsm.player.max_cultivation = 99999
	gsm.collection.owned_cards = []
	gsm.collection.total_count = 0
	# Act
	run_victory(LaunchScript.COMBAT_TYPE_BOSS)
	# Assert——基础（LOW 档 50/50）+ 首通（LOW 档 50/30）都入账
	assert_eq(ling_shi(), 100, "首通灵石 = 基础 50 + 首通额外 50（GDD §公式 5）")
	assert_eq(cultivation(), 80, "首通修为 = 基础 50 + 首通额外 30")
	assert_eq(owned_count_of(FIRST_CLEAR_CARD), 1, "首通彩头卡应进收藏")


func test_repeat_clear_grants_no_first_rewards_and_no_rare_card() -> void:
	## GDD §7：非首次通关不给稀有奖励——重复刷图能无限取卡会让首通失去意义。
	# Arrange——先把本图通关一次
	enter_map()
	run_victory(LaunchScript.COMBAT_TYPE_BOSS)
	gsm.player.resources.ling_shi = 0
	gsm.player.cultivation = 0
	gsm.player.max_cultivation = 99999
	gsm.collection.owned_cards = []
	gsm.collection.total_count = 0
	# Act——再通一次（重新进图）
	enter_map()
	run_victory(LaunchScript.COMBAT_TYPE_BOSS)
	# Assert——只有基础奖励，没有首通彩头
	assert_eq(ling_shi(), 50, "重复通关只有基础灵石（首通档位表不再生效）")
	assert_eq(cultivation(), 50, "重复通关只有基础修为")
	assert_eq(owned_count_of(FIRST_CLEAR_CARD), 0, "重复通关不再发稀有卡")
	assert_eq(int(map_state().get("clear_count", 0)), 2, "通关次数累计到 2")


func test_repeat_clear_publishes_view_without_first_section() -> void:
	## 重复通关也要有反馈（GDD §7 的「地图通关！+ 通关奖励」两段），只是没有首通行。
	# Arrange
	enter_map()
	run_victory(LaunchScript.COMBAT_TYPE_BOSS)
	ClearView.clear()
	# Act
	enter_map()
	run_victory(LaunchScript.COMBAT_TYPE_BOSS)
	# Assert
	var view: Dictionary = pending_view()
	assert_false(view.is_empty(), "重复通关同样应备好结算视图")
	assert_false(bool(view.get(ClearView.KEY_IS_FIRST_CLEAR, true)),
			"重复通关的视图应带 is_first_clear=false")
	assert_eq(int(view.get(ClearView.KEY_FIRST_LING_SHI, -1)), 0, "首通灵石为 0")


# ═══════════════════════════════════════════════════════════════════════════════
# 4/6. 结算面板
# ═══════════════════════════════════════════════════════════════════════════════

func test_panel_pops_on_return_to_exploration() -> void:
	# Act——打完 Boss 回到探索（Boss 胜利的转场目的地就是探索场景）
	run_boss_clear()
	# Assert——面板挂在薄容器上并已上架
	assert_not_null(panel(), "回到探索时应弹出地图通关结算面板")
	assert_eq(str(panel().call(&"title_text")), "地图通关！", "GDD §7 线框首行")
	assert_eq(str(panel().call(&"map_text")), "青云剑宗", "面板显示地图中文名")


func test_panel_shows_first_clear_section_with_gold_border() -> void:
	# Act
	run_boss_clear()
	# Assert——首通行在、且卡牌行是金色边框（GDD §7「金色边框高亮」）
	assert_true(bool(panel().call(&"is_first_section_shown")), "首通应显示首通奖励段")
	assert_eq(int(panel().call(&"card_count")), 1, "首通彩头卡应在面板上占一行")
	assert_true(bool(panel().call(&"is_card_gold", 0)), "首通奖励行应为金色边框")
	var texts: Array = panel().call(&"card_texts")
	assert_string_contains(str(texts[0]), "培元丹", "卡牌行含卡名")


func test_panel_hides_first_clear_section_on_repeat() -> void:
	# Arrange——先通一次
	run_boss_clear()
	assert_true(bool(panel().call(&"is_first_section_shown")), "前置：首次通关有首通行")
	scene.free()
	scene = null
	# Act——再通一次
	enter_map()
	run_victory(LaunchScript.COMBAT_TYPE_BOSS)
	scene = SceneScript.new()
	add_child_autofree(scene)
	# Assert——GDD §7：非首次通关不显示首次通关奖励行
	assert_not_null(panel(), "重复通关同样应弹面板")
	assert_false(bool(panel().call(&"is_first_section_shown")),
			"非首次通关不显示首次通关奖励行")
	assert_eq(int(panel().call(&"card_count")), 0, "重复通关面板上没有首通彩头")


func test_panel_card_click_shows_detail() -> void:
	# Arrange
	run_boss_clear()
	assert_eq(str(panel().call(&"message_text")), "", "前置：详情未展开")
	# Act——点开奖励卡牌（GDD §7「点击奖励卡牌可查看详情」）
	panel().call(&"press_card", 0)
	# Assert——详情就地展开，含模板描述与风味（详情来自 CardSystem）
	var detail: String = str(panel().call(&"message_text"))
	assert_string_contains(detail, "培元丹", "详情含卡名")
	assert_string_contains(detail, "回复3点生命", "详情含模板 description")
	assert_string_contains(detail, "培元固本", "详情含模板 flavor_text")


func test_panel_confirm_returns_to_map_select() -> void:
	# Arrange
	run_boss_clear()
	assert_true(scene.call(&"map_clear_panel_open"), "前置：面板已弹")
	# Act——玩家点「确认」（GDD §7「点击确认→返回地图选择界面」）
	panel().call(&"press_confirm")
	# Assert——overlay 收起，底下的地图选择界面还在（它从未被卸下）
	assert_false(bool(scene.call(&"map_clear_panel_open")), "确认后面板应收起")
	assert_not_null(scene.get(&"map_select_screen"), "确认后应停在地图选择界面")
	assert_null(scene.get(&"node_graph_screen"), "确认后不应进节点图")


func test_panel_is_taken_once() -> void:
	## 反复进出地图（每次转场都重挂探索场景）不该重放上一局的通关结算。
	# Arrange
	run_boss_clear()
	panel().call(&"press_confirm")
	scene.free()
	scene = null
	# Act——再挂一次探索场景（没有任何新的通关）
	scene = SceneScript.new()
	add_child_autofree(scene)
	# Assert
	assert_null(panel(), "取走即清——无新通关时不该再弹面板")


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 一份战败结算对象（Boss 战失败方向）。
func _defeat_view() -> RefCounted:
	var view: RefCounted = ViewScript.new()
	view.set("result", ViewScript.RESULT_DEFEAT)
	return view
