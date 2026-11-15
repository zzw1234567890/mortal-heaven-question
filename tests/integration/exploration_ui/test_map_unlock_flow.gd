extends GutTest
## 未解锁地图卡的中文提示 —— 点击不进场、说明缺什么。[br]
## [br][b]本轮补的断链[/b]：未解锁卡点击此前是 [code]pass[/code]——不进图、
## 也不给任何反馈，玩家只能逐张试出「为什么点不动」（卡片上只有 🔒 与悬停
## tooltip，触屏 / 手柄路径连悬停都没有）。本文件锁三件事：[br]
##   1. 点击未解锁卡不发出进入意图，改弹一条中文条件提示；[br]
##   2. 提示文案点名缺的那条（「需筑基期」/「需通关苍玄古战场」），与灰显判据同源；[br]
##   3. 已解锁卡点击照旧进场、且不弹条件提示（对照路径，防「提示把正常路径也吞掉」）。[br]
## [br][b]为什么直调 [code]_on_card_activated[/code][/b]：卡片点击 → 屏幕分流这条
## 链路的分支点是它；点真实 [code]MapCard[/code] 的 [code]gui_input[/code] 只是
## 多绕一层输入事件（那条链由 [code]test_map_select_logic.gd[/code] 锁的纯函数覆盖）。[br]
## [br][b]隔离[/b]：GSM 的 exploration / player 两域在 [code]before_each[/code]
## 快照、[code]after_each[/code] 原样还原——列表载荷读的就是这里。[br]
##
## 来源: design/gdd/exploration-ui-system.md §1（未解锁灰显 + 标明所需境界）、
## design/gdd/exploration-system.md §8、ADR-0031 §2、hud Story 004 通知接口。

const ScreenScene: PackedScene = preload("res://src/ui/exploration/map_select_screen.tscn")
const BootstrapScript := preload("res://src/feature/exploration/exploration_bootstrap.gd")
const NoticeScript := preload("res://src/ui/exploration/map_select_notice.gd")
const CatalogScript := preload("res://src/feature/exploration/exploration_map_catalog.gd")

## 开局可进的图（GDD §8）。
const START_MAP: StringName = &"qing_yun_jian_zong"
## 炼气链上的第二张（首通青云剑宗前应为锁定态）。
const CHAINED_MAP: StringName = &"xue_yuan_mi_jing"
## 剧情锁样例（筑基期 + 需先通关苍玄古战场）。
const STORY_MAP: StringName = &"sui_xing_wai_huan"
const STORY_PREREQ: StringName = &"cang_xuan_gu_zhan_chang"

var es: Node = null
var gsm: Node = null
var screen: Control = null
var _exploration_before: Dictionary = {}
var _player_before: Dictionary = {}
## 收到的通知条目 [{type, text}, ...]。
var _notices: Array = []
## 收到的进入意图（地图 ID 数组）。
var _entered: Array = []


func before_each() -> void:
	gsm = get_node_or_null(NodePath("/root/GameStateManager"))
	es = get_node_or_null(NodePath("/root/ExplorationSystem"))
	assert_not_null(es, "本文件需要真实 ExplorationSystem Autoload")
	_exploration_before = (gsm.exploration as Dictionary).duplicate(true)
	_player_before = (gsm.player as Dictionary).duplicate(true)
	BootstrapScript.mount(es, get_node_or_null(NodePath("/root/AISystem")))
	_notices.clear()
	_entered.clear()
	_reset_gsm()
	_mount_screen()


func after_each() -> void:
	if screen != null and is_instance_valid(screen):
		screen.free()
	screen = null
	gsm.exploration = _exploration_before
	gsm.player = _player_before
	if es != null and es.has_method(&"clear_dag_cache"):
		es.call("clear_dag_cache")


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 点击未解锁卡 —— 不进图 + 中文条件提示
# ═══════════════════════════════════════════════════════════════════════════════

func test_click_locked_card_does_not_enter_map() -> void:
	# Arrange——炼气期、无通关记录（血渊秘境锁着：需先通关青云剑宗）
	var entry: Dictionary = _entry_of(CHAINED_MAP)
	assert_false(bool(entry["is_unlocked"]), "前置：血渊秘境此时应为锁定态")
	# Act——点这张卡
	screen.call("_on_card_activated", entry)
	# Assert——不进图（意图未发出）
	assert_eq(_entered, [], "未解锁卡点击不应发出进入意图")


func test_click_locked_card_reports_missing_condition() -> void:
	# Arrange
	var entry: Dictionary = _entry_of(CHAINED_MAP)
	# Act
	screen.call("_on_card_activated", entry)
	# Assert——弹一条提示，点名缺的那条（前置地图的中文名）
	assert_eq(_notices.size(), 1, "未解锁卡点击应给一条提示")
	assert_string_contains(str(_notices[0]["text"]), "需通关青云剑宗",
			"提示应写明缺的前置条件")


func test_click_locked_story_card_names_both_missing_conditions() -> void:
	# Arrange——炼气期（门槛筑基）+ 苍玄古战场未通关：两条都缺
	GameStateManager.player.realm = 1
	var entry: Dictionary = _entry_of(STORY_MAP)
	assert_false(bool(entry["is_unlocked"]), "前置：碎星外环此时应为锁定态")
	# Act
	screen.call("_on_card_activated", entry)
	# Assert——两条并排，玩家一眼看出还差什么
	assert_eq(_notices.size(), 1, "应给一条提示")
	var text: String = str(_notices[0]["text"])
	assert_string_contains(text, "需筑基期", "提示应含境界条件")
	assert_string_contains(text, "需通关苍玄古战场", "提示应含前置条件")


func test_click_realm_locked_card_reports_realm_in_chinese() -> void:
	# Arrange——炼气玩家看金丹图（无前置，只差境界）
	var entry: Dictionary = _entry_of(&"wan_gu_dian")
	assert_false(bool(entry["is_unlocked"]), "前置：万古殿需金丹期，此时应锁着")
	# Act
	screen.call("_on_card_activated", entry)
	# Assert——念的是境界名而不是数字
	assert_eq(_notices.size(), 1, "应给一条提示")
	assert_eq(str(_notices[0]["text"]), "需金丹期",
			"境界不足的提示应给中文境界名")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 解锁后自动可进（读档后重算，不依赖一次性写入）
# ═══════════════════════════════════════════════════════════════════════════════

func test_unlocked_after_prerequisite_clear_without_any_write() -> void:
	# Arrange——本局首通青云剑宗（只写 GSM 的通关态，不写任何「解锁标记」）
	GameStateManager.exploration.map_states = {START_MAP: {"is_first_clear": true}}
	# Act——重取列表载荷（模拟读档后 / 回探索时的重算）
	var entry: Dictionary = _entry_of(CHAINED_MAP)
	# Assert——自动解锁，点击直接进场
	assert_true(bool(entry["is_unlocked"]), "首通前置后应自动解锁（无需写入解锁态）")
	assert_eq(str(entry["locked_hint"]), "", "已解锁条目不带条件文案")
	screen.call("_on_card_activated", entry)
	assert_eq(_entered, [CHAINED_MAP] as Array, "已解锁卡点击应发出进入意图")
	assert_eq(_notices, [], "已解锁卡点击不应弹条件提示")


func test_story_map_unlocks_after_prerequisite_clear_at_sufficient_realm() -> void:
	# Arrange——筑基期 + 苍玄古战场已通关
	GameStateManager.player.realm = 2
	GameStateManager.exploration.map_states = {STORY_PREREQ: {"is_first_clear": true}}
	# Act
	var entry: Dictionary = _entry_of(STORY_MAP)
	# Assert——两项条件齐了即开，且进场意图带对地图 ID
	assert_true(bool(entry["is_unlocked"]), "境界与前置齐备后碎星外环应解锁")
	screen.call("_on_card_activated", entry)
	assert_eq(_entered, [STORY_MAP] as Array, "解锁后点击应进入该图")


func test_realm_alone_does_not_unlock_story_map() -> void:
	# Arrange——化神期（远超门槛）但苍玄古战场未通关
	GameStateManager.player.realm = 5
	# Act
	var entry: Dictionary = _entry_of(STORY_MAP)
	# Assert——剧情锁与境界是「与」关系
	assert_false(bool(entry["is_unlocked"]), "仅境界达标不足以解锁剧情锁地图")
	screen.call("_on_card_activated", entry)
	assert_eq(_entered, [], "仍不应进场")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 已通关不可重入的卡不误报（IGNORE 的另一半语义）
# ═══════════════════════════════════════════════════════════════════════════════

func test_click_cleared_non_reenterable_card_says_nothing() -> void:
	# Arrange——苍玄古战场已通关（reentry_allowed=false —— 剧情图，设计如此）
	GameStateManager.player.realm = 2
	GameStateManager.exploration.map_states = {STORY_PREREQ: {"is_first_clear": true}}
	var entry: Dictionary = _entry_of(STORY_PREREQ)
	assert_true(bool(entry["is_unlocked"]), "前置：该卡应为已解锁态")
	assert_false(bool(entry["reentry_allowed"]), "前置：剧情图不可重入")
	# Act
	screen.call("_on_card_activated", entry)
	# Assert——不进图，也不弹「条件不足」（它不是缺陷，是设计）
	assert_eq(_entered, [], "不可重入卡不应进场")
	assert_eq(_notices, [], "不可重入不应被说成「条件不足」")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 降级 —— 无通知出口 / 纯函数边界
# ═══════════════════════════════════════════════════════════════════════════════

func test_locked_click_without_sink_is_silent() -> void:
	# Arrange——撤掉注入出口，且 headless 下没有常驻 HUD
	screen.set("notify_cb", Callable())
	assert_false(NoticeScript.notification_sink(screen).is_valid(),
			"前置：本环境应无可用通知出口")
	var entry: Dictionary = _entry_of(CHAINED_MAP)
	# Act——不应崩溃
	screen.call("_on_card_activated", entry)
	# Assert——仍然不进图（提示缺失不改变「点不动」的事实）
	assert_eq(_entered, [], "无出口时也不应进场")


func test_hint_text_is_empty_for_unlocked_entry() -> void:
	# Arrange——已解锁条目（占位用的最小字典）
	var entry: Dictionary = {"map_id": START_MAP, "is_unlocked": true,
			"locked_hint": "需筑基期"}
	# Act / Assert——已解锁不给条件文案（即便载荷里塞了）
	assert_eq(NoticeScript.locked_hint_text(entry), "", "已解锁条目不应有条件文案")


func test_hint_text_falls_back_to_digit_form_for_legacy_payload() -> void:
	# Arrange——旧载荷：只有 realm_requirement，没有 locked_hint
	var entry: Dictionary = {"map_id": &"legacy", "is_unlocked": false,
			"realm_requirement": 3}
	# Act / Assert——回退数字形式（与卡片此前的 tooltip 口径一致）
	assert_eq(NoticeScript.locked_hint_text(entry), "需3境界",
			"缺 locked_hint 时应回退数字形式")


func test_hint_text_defaults_to_unlocked_for_missing_field() -> void:
	# Arrange——缺 is_unlocked 字段（安全默认不锁定，与 should_show_lock 同口径）
	var entry: Dictionary = {"map_id": &"unknown"}
	# Act / Assert
	assert_false(NoticeScript.is_locked(entry), "缺字段应安全默认不锁定")
	assert_eq(NoticeScript.locked_hint_text(entry), "", "缺字段不应给条件文案")


func test_notify_locked_returns_empty_for_unlocked_entry() -> void:
	# Arrange——对已解锁条目调提示出口
	var entry: Dictionary = {"map_id": START_MAP, "is_unlocked": true}
	# Act
	var shown: String = NoticeScript.notify_locked(screen, entry)
	# Assert——静默（不给玩家一条莫名其妙的提示）
	assert_eq(shown, "", "已解锁条目不提示")
	assert_eq(_notices, [], "不应发出任何通知")


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 挂载地图选择界面并注入通知入口 + 进入意图收集（不依赖真实 HUD）。
func _mount_screen() -> void:
	screen = ScreenScene.instantiate()
	screen.set("exploration_system", es)
	screen.set("animate", false)
	screen.set("notify_cb", Callable(func(type: String, text: String) -> int:
		_notices.append({"type": type, "text": text})
		return _notices.size()))
	screen.enter_map_requested.connect(func(map_id: StringName) -> void:
		_entered.append(map_id))
	add_child_autofree(screen)


## 从系统载荷里取某张图的条目（不存在时失败）。
func _entry_of(p_map_id: StringName) -> Dictionary:
	for raw: Variant in es.call(&"get_map_list"):
		var entry: Dictionary = raw
		if entry.get(&"map_id") == p_map_id:
			return entry
	fail_test("列表里没有 %s" % p_map_id)
	return {}


## 重置 GSM 探索域与玩家境界（列表载荷读这两处）。
func _reset_gsm() -> void:
	gsm.exploration = {
		"current_map": &"",
		"node_position": {"layer": 0, "idx": 0},
		"visited_nodes": [],
		"action_points": 0,
		"max_action_points": 0,
		"map_states": {},
	}
	gsm.player.realm = 1
	gsm.set("_signal_chain_depth", 0)
	var router: Variant = gsm.get("_signal_router")
	if router != null:
		router.set("_pending_changes", [])
