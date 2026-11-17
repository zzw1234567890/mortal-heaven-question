extends "res://tests/integration/exploration_ui/map_clear_settlement_fixture.gd"
## 通关之后玩得下去 —— 「通关 → 回选图 → 进下一张图 / 重入本图」的闭环。[br]
## [br][b]本文件补的断链[/b]（两条，均在前几轮留下的）：[br]
##   1. [b]没有「下一张」引导[/b]——打完 Boss 回到选图界面，17 张卡里最显眼的仍是
##      刚通完那张（它亮着「已通关」），玩家的默认动作是原地重刷；[br]
##   2. [signal MapSelectScreen.reentry_requested] [b]全库无消费者[/b]——重入确认
##      弹窗上点「确认传送」既不扣费也不进图，点击看起来像失灵。[br]
## [br][b]覆盖[/b]（断言 GSM 状态与奖励口径，不只是界面可见性）：[br]
##   1. 结算面板给出「下一张：X」的引导行，且 X 就是链上的下一张；[br]
##   2. 点「确认」后选图界面[b]点亮[/b]那张卡的推荐标记（且只有它被点亮）；[br]
##   3. 进那张推荐的图 → GSM [code]current_map[/code] 换图、已访问重置为入口、
##      行动力回满（[code]enter_map[/code] 口径，不是读档续玩）；[br]
##   4. 通关下一张图 → 它自己的首通彩头入账、[code]clear_count[/code] 记 1；[br]
##   5. 重入已通关的图 → 扣掉经济公式给的传送费、进入次数递增、行动力回满；[br]
##   6. 余额不足的重入 → 不扣费、不进图，只给一条中文提示。[br]
## [br][b]装置[/b]见 [code]map_clear_settlement_fixture.gd[/code]（真实 Autoload +
## 存档隔离；[code]enter_map[/code] / [code]map_state[/code] 已参数化以支持换图）。
##
## 来源: design/gdd/exploration-system.md §1 地图重入消耗规则 / §5 地图通关奖励 / §8 解锁顺序、
## design/gdd/exploration-ui-system.md §1 地图选择界面 / §7 通关结算、
## ADR-0014 §决策 4/5、ADR-0031 §2。

## 链上的下一张（青云剑宗 → 血渊秘境，GDD §8 顺序锁）。
const NEXT_MAP: StringName = &"xue_yuan_mi_jing"
## 下一张图难度 MEDIUM 档的重入基价（[code]REENTRY_BASE_COSTS[/code]）。
const NEXT_MAP_REENTRY_FEE: int = 60
## 下一张图的首通彩头卡（MEDIUM 档）。
const NEXT_FIRST_CLEAR_CARD: StringName = &"pill_hui_chun_dan"
## 不可重入的剧情地图（探明表里唯一显式 [code]reentry_allowed=false[/code] 的一张）。
const PK_MAP: StringName = &"cang_xuan_gu_zhan_chang"
## 入口节点 ID（与 [code]ExplorationSystem.ENTRY_NODE_ID[/code] 同值）。
const ENTRY_NODE: int = 0

## 收到的通知条目 [{type, text}, ...]（重入结果文案）。
var _notices: Array = []


func before_each() -> void:
	super()
	_notices.clear()
	# 下一张图的首通彩头也要就位——否则那张卡静默不入库，用例分不出
	# 「没发」与「发了但被校验拒了」。
	PrimerScript.prime(CardSystem, NEXT_FIRST_CLEAR_CARD)
	var database: Dictionary = gsm.get("_card_template_database")
	database[str(NEXT_FIRST_CLEAR_CARD)] = database.get(str(NEXT_FIRST_CLEAR_CARD), {})
	gsm.set("_card_template_database", database)


# ═══════════════════════════════════════════════════════════════════════════════
# 1/2. 通关 → 面板给引导 → 确认后点亮下一张
# ═══════════════════════════════════════════════════════════════════════════════

func test_clear_panel_points_at_the_next_map() -> void:
	# Act——打完 Boss 回到探索（面板在此时弹）
	run_boss_clear()
	# Assert——GDD §7 面板之后的去向：写清下一张是哪张
	var texts: Array = panel().call(&"reward_texts")
	var joined: String = "\n".join(PackedStringArray(_as_strings(texts)))
	assert_string_contains(joined, "下一张", "结算面板应给出「下一张」引导行")
	assert_string_contains(joined, "血渊秘境", "引导行应点名链上的下一张")


func test_confirm_highlights_exactly_one_next_map_card() -> void:
	# Arrange——先确认面板（这一步同时刷新列表与点亮推荐）
	run_boss_clear()
	var screen: Control = scene.get("map_select_screen")
	assert_eq(StringName(str(screen.call(&"recommended_map_id"))), &"",
			"前置：确认之前没有推荐")
	# Act
	panel().call(&"press_confirm")
	# Assert——点亮的是下一张，且只有它
	assert_eq(StringName(str(screen.call(&"recommended_map_id"))), NEXT_MAP,
			"确认后应推荐血渊秘境（链上的下一张）")
	assert_true(bool(_card_of(screen, NEXT_MAP).call(&"is_recommended")),
			"推荐卡的卡面应处于推荐态")
	for raw: Variant in screen.get("card_row").get_children():
		var card: Panel = raw
		if StringName(str((card.get(&"entry") as Dictionary).get(&"map_id", ""))) == NEXT_MAP:
			continue
		assert_false(bool(card.call(&"is_recommended")),
				"不该有第二张卡被点亮（否则「推荐哪张」无从读起）")


func test_cleared_card_reports_clear_count_on_the_card() -> void:
	# Arrange——打完 Boss（本图 clear_count = 1）
	run_boss_clear()
	panel().call(&"press_confirm")
	# Act——回选图后取本图卡片的条目
	var entry: Dictionary = _entry_of(MAP_ID)
	# Assert——条目带上通关次数（卡片据此显示「⭐首次通关」而不是笼统的「已通关」）
	assert_true(bool(entry["is_cleared"]), "本图应报已通关")
	assert_eq(int(entry["clear_count"]), 1, "通关次数应为 1")
	assert_true(bool(_card_of(scene.get("map_select_screen"), MAP_ID).call(
			"is_recommended")) == false, "刚通完那张不该是推荐卡（推荐的是下一张）")


# ═══════════════════════════════════════════════════════════════════════════════
# 3/4. 进下一张图 → 它自己的首通奖励入账
# ═══════════════════════════════════════════════════════════════════════════════

func test_entering_the_highlighted_map_starts_it_from_scratch() -> void:
	# Arrange——通关青云剑宗并确认（推荐卡已点亮）
	run_boss_clear()
	panel().call(&"press_confirm")
	var screen: Control = scene.get("map_select_screen")
	gsm.exploration["visited_nodes"] = [7, 8, 9]
	# Act——点那张被推荐的卡（真实分流：未通关 + 已解锁 → ENTER）
	screen.call("_on_card_activated", _entry_of(NEXT_MAP))
	# Assert——进的是下一张图，且是新生成（不是接着上一张的残局）
	assert_eq(gsm.exploration.get("current_map"), NEXT_MAP, "应进入被推荐的下一张图")
	assert_eq(gsm.exploration.get("visited_nodes"), [ENTRY_NODE] as Array,
			"进新图应把已访问重置为入口（清掉上一张的残留路径）")
	assert_eq(gsm.exploration.get("action_points"),
			gsm.exploration.get("max_action_points"), "进新图行动力应回满（GDD §1）")
	assert_not_null(scene.get("node_graph_screen"), "应挂上节点图主界面")


func test_clearing_the_next_map_grants_its_own_first_clear_reward() -> void:
	# Arrange——先通青云剑宗并把玩家推进到血渊秘境
	run_boss_clear()
	panel().call(&"press_confirm")
	scene.get("map_select_screen").call("_on_card_activated", _entry_of(NEXT_MAP))
	gsm.player.resources.ling_shi = 0
	gsm.player.cultivation = 0
	gsm.player.max_cultivation = 99999
	gsm.collection.owned_cards = []
	gsm.collection.total_count = 0
	# Act——打掉这一张的 Boss
	run_victory(LaunchScript.COMBAT_TYPE_BOSS)
	# Assert——本图首通：通关次数记 1，首通彩头（MEDIUM 档）入账
	assert_eq(int(map_state(NEXT_MAP).get("clear_count", 0)), 1,
			"第二张图首次通关应记 1 次")
	assert_true(bool(map_state(NEXT_MAP).get("is_first_clear", false)),
			"第二张图应被标记为已通关")
	assert_eq(owned_count_of(NEXT_FIRST_CLEAR_CARD), 1,
			"第二张图的首通彩头应进收藏（推进感来自「新图有新彩头」）")


# ═══════════════════════════════════════════════════════════════════════════════
# 5/6. 重入已通关的图 —— 扣费并进图 / 余额不足则拒绝
# ═══════════════════════════════════════════════════════════════════════════════

func test_reentry_request_deducts_fee_and_restarts_the_map() -> void:
	# Arrange——先首通血渊秘境（MEDIUM 档，重入费 60），再回到探索场景
	enter_map(NEXT_MAP)
	run_victory(LaunchScript.COMBAT_TYPE_BOSS)
	ClearView.clear()
	gsm.player.resources.ling_shi = 100
	scene = SceneScript.new()
	scene.set(&"notify_cb", _capture_notice())
	add_child_autofree(scene)
	var screen: Control = scene.get("map_select_screen")
	var entry: Dictionary = _entry_of(NEXT_MAP)
	assert_true(bool(entry["is_cleared"]), "前置：本图已通关")
	assert_eq(int(entry["reentry_total"]), NEXT_MAP_REENTRY_FEE,
			"前置：条目报价应为经济公式给的 60（卡片与实扣同源）")
	# Act——走真实分流：点卡片 → 弹重入确认 → 确认传送
	screen.call("_on_card_activated", entry)
	screen.call("_on_reentry_confirmed")
	# Assert——扣了 60、进了本图、次数递增、行动力回满
	assert_eq(ling_shi(), 100 - NEXT_MAP_REENTRY_FEE,
			"重入应扣掉经济公式给的传送费")
	assert_eq(gsm.exploration.get("current_map"), NEXT_MAP, "重入后应回到本图")
	assert_eq(int(map_state(NEXT_MAP).get("entry_count", 0)), 2,
			"重入应让进入次数递增（费用随次数上涨的前提）")
	assert_eq(gsm.exploration.get("action_points"),
			gsm.exploration.get("max_action_points"), "重入后行动力应重置为上限（GDD §1）")
	assert_eq(gsm.exploration.get("visited_nodes"), [ENTRY_NODE] as Array,
			"重入应生成新节点图（已访问重置为入口）")
	assert_true(_notices_contain("重入"), "应给一条说明这是重入的提示")


func test_reentry_with_insufficient_balance_changes_nothing() -> void:
	# Arrange——已通关血渊秘境，但身上只有 10 灵石（不够 60）
	enter_map(NEXT_MAP)
	run_victory(LaunchScript.COMBAT_TYPE_BOSS)
	ClearView.clear()
	gsm.player.resources.ling_shi = 10
	scene = SceneScript.new()
	scene.set(&"notify_cb", _capture_notice())
	add_child_autofree(scene)
	var screen: Control = scene.get("map_select_screen")
	# Act——点卡片 → 弹窗（确认按钮此时应灰显）→ 直接调确认出口
	var entry: Dictionary = _entry_of(NEXT_MAP)
	screen.call("_on_card_activated", entry)
	screen.call("_on_reentry_confirmed")
	# Assert——钱没少、图没进、给了一条读得懂的拒绝提示
	assert_eq(ling_shi(), 10, "余额不足时不该扣费")
	assert_null(scene.get("node_graph_screen"), "余额不足时不该进图")
	assert_eq(gsm.exploration.get("current_map"), &"", "余额不足时不该有活跃地图")
	assert_true(_notices_contain("灵石不足"), "应提示灵石不足")


func test_reentering_a_non_reenterable_map_is_refused() -> void:
	# Arrange——苍玄古战场已通关（剧情图，reentry_allowed=false）
	enter_map(PK_MAP)
	run_victory(LaunchScript.COMBAT_TYPE_BOSS)
	ClearView.clear()
	gsm.player.resources.ling_shi = 9999
	scene = SceneScript.new()
	scene.set(&"notify_cb", _capture_notice())
	add_child_autofree(scene)
	var screen: Control = scene.get("map_select_screen")
	var entry: Dictionary = _entry_of(PK_MAP)
	assert_false(bool(entry["reentry_allowed"]), "前置：剧情图不可重入")
	# Act——点击分流应给 IGNORE（既不弹窗也不进图），强制走一次确认出口
	screen.call("_on_card_activated", entry)
	screen.call("_on_reentry_confirmed")
	# Assert——不扣费、不进图、不弹「条件不足」（它是设计而非缺陷）
	assert_eq(ling_shi(), 9999, "不可重入图不该扣费")
	assert_null(scene.get("node_graph_screen"), "不可重入图不该进图")
	assert_false(_notices_contain("重入"),
			"不可重入图不该出现「重入」提示（它连弹窗都没有）")


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 通知收集闭包（HUD 未挂载时的注入出口——与 [MapSelectNotice] 同一注入点）。
func _capture_notice() -> Callable:
	return Callable(func(type: String, text: String) -> int:
		_notices.append({"type": type, "text": text})
		return _notices.size())


## 某条通知的文案是否包含子串。
func _notices_contain(p_needle: String) -> bool:
	for raw: Variant in _notices:
		if str((raw as Dictionary).get("text", "")).contains(p_needle):
			return true
	return false


## 从系统载荷里取某张图的条目（不存在时失败）。
func _entry_of(p_map_id: StringName) -> Dictionary:
	for raw: Variant in es.call(&"get_map_list"):
		var entry: Dictionary = raw
		if entry.get(&"map_id") == p_map_id:
			return entry
	fail_test("列表里没有 %s" % p_map_id)
	return {}


## 选图界面里对应某张图的卡片（不存在时失败——不静默返回 null）。
func _card_of(p_screen: Control, p_map_id: StringName) -> Panel:
	for raw: Variant in p_screen.get("card_row").get_children():
		var card: Panel = raw
		if StringName(str((card.get(&"entry") as Dictionary).get(&"map_id", ""))) == p_map_id:
			return card
	fail_test("卡片行里没有 %s" % p_map_id)
	return null


## 把文本数组转成字符串数组（[code]join[/code] 需要 PackedStringArray）。
func _as_strings(p_values: Array) -> Array:
	var out: Array = []
	for value: Variant in p_values:
		out.append(str(value))
	return out
