extends GutTest
## 地图选择列表的真实数据源单元测试（本轮：get_map_list 落地 + stub 拆除）。[br]
## [br][b]覆盖[/b]：[br]
##   - 列表来自探明表 [code]ExplorationMapCatalog.MAPS[/code]（配置里有几张就出几张，
##     新增地图无需改代码）；[br]
##   - 条目契约字段齐全且口径正确（难度 0 基 → 卡片 1 基、解锁门槛取
##     [code]unlock_realm[/code]、已通关读 GSM [code]is_first_clear[/code]）；[br]
##   - 未登记地图不再从章节表漏进来（历史写法经别名归一到规范写法）；[br]
##   - 重入费用与倍率来自经济公式（首入 0、永久免费 0、非免费按档位递增）。[br]
## [br][b]为什么单独一处[/b]：既有的 [code]test_map_select_logic.gd[/code] 锁的是
## 屏幕的 Logic 内核（4 个 static 纯函数），不碰数据源；本轮改的正是数据源
## （stub → 探明表），需要自己的断言。[br]
## [br][b]隔离[/b]：GSM 的 exploration 域在 [code]before_each[/code] 快照、
## [code]after_each[/code] 原样还原——列表里的「已通关/进入次数」读的就是这里。[br]
##
## 来源: ADR-0014 §get_map_list 契约、GDD exploration-system.md §1/§8、
## design/gdd/exploration-ui-system.md §1、本轮「地图选择补齐」任务。

const MAP_LIST_SCRIPT := preload("res://src/feature/exploration/exploration_map_list.gd")
const CATALOG_SCRIPT := preload("res://src/feature/exploration/exploration_map_catalog.gd")
const ES_SCRIPT := preload("res://src/feature/exploration_system.gd")
## 重入费用用例的地图 ID 段（避开真实地图，防与其它用例互相污染）。
const TEST_MAP: StringName = &"yun_lan_cheng"
## 永久免费地图（列表条目里的 is_permanent_free 应为 true）。
const FREE_MAP: StringName = &"qing_yun_jian_zong"

var es: Node = null
var _exploration_before: Dictionary = {}
var _player_before: Dictionary = {}


func before_each() -> void:
	_exploration_before = (GameStateManager.exploration as Dictionary).duplicate(true)
	_player_before = (GameStateManager.player as Dictionary).duplicate(true)
	# 整份替换（与 test_event_economy 同口径——逐键赋值在缺键时会失败）
	GameStateManager.exploration = {
		"current_map": &"",
		"node_position": {"layer": 0, "idx": 0},
		"visited_nodes": [],
		"action_points": 0,
		"max_action_points": 0,
		"map_states": {},
	}
	GameStateManager.player.realm = 1
	GameStateManager.player.resources.ling_shi = 0
	es = ES_SCRIPT.new()


func after_each() -> void:
	GameStateManager.exploration = _exploration_before
	GameStateManager.player = _player_before
	if es != null:
		es.free()
		es = null


# ═══════════════════════════════════════════════════════════════════════════════
# 列表内容——来自探明表，不硬编码
# ═══════════════════════════════════════════════════════════════════════════════

func test_map_list_contains_every_registered_map() -> void:
	var entries: Array = es.call(&"get_map_list")
	assert_eq(entries.size(), CATALOG_SCRIPT.MAPS.size(),
			"列表条数应等于探明表登记数（%d）" % CATALOG_SCRIPT.MAPS.size())
	var ids: Array = []
	for raw: Variant in entries:
		ids.append((raw as Dictionary).get(&"map_id"))
	for map_id: Variant in CATALOG_SCRIPT.MAPS.keys():
		assert_true(ids.has(map_id), "探明表登记的 %s 应出现在列表里" % map_id)


func test_map_list_includes_previously_missing_maps() -> void:
	# 本轮补齐的 7 张此前只有 ID 没有配置的地图——它们此前根本不在任何列表里
	var ids: Array = []
	for raw: Variant in es.call(&"get_map_list"):
		ids.append((raw as Dictionary).get(&"map_id"))
	for map_id: StringName in [&"wan_gu_dian", &"sui_xing_nei_hai", &"xi_yu_bian_jing",
			&"xi_yu", &"gui_xu_tong_dao", &"gui_xu_wan_yao_gu", &"gui_xu_gu_mo_zhan_chang"]:
		assert_true(ids.has(map_id), "补齐的 %s 应进入选择列表" % map_id)


func test_map_list_follows_catalog_order() -> void:
	var ids: Array = []
	for raw: Variant in es.call(&"get_map_list"):
		ids.append((raw as Dictionary).get(&"map_id"))
	var expected: Array = CATALOG_SCRIPT.MAPS.keys()
	assert_eq(ids, expected, "列表顺序应与探明表一致（剧情顺序 = 卡片顺序）")


func test_map_list_contains_no_legacy_spelling() -> void:
	for raw: Variant in es.call(&"get_map_list"):
		var map_id: StringName = (raw as Dictionary).get(&"map_id")
		assert_false(CATALOG_SCRIPT.is_legacy_id(map_id),
				"列表不得出现历史写法 %s（应已归一到规范写法）" % map_id)


# ═══════════════════════════════════════════════════════════════════════════════
# 条目契约——字段口径
# ═══════════════════════════════════════════════════════════════════════════════

func test_entry_carries_ui_contract_fields() -> void:
	var entry: Dictionary = _entry_of(&"qing_yun_jian_zong")
	for key: String in ["map_id", "name", "difficulty", "realm_requirement",
			"is_cleared", "is_unlocked", "reentry_allowed", "reentry_base",
			"reentry_multiplier", "reentry_total", "can_reenter", "is_permanent_free"]:
		assert_true(entry.has(key), "条目应含契约字段 %s" % key)


func test_difficulty_is_one_based_for_stars() -> void:
	# 探明表 difficulty 是 0 基枚举；卡片 ⭐ 要 1 基（MapCard._difficulty_text）
	var entry: Dictionary = _entry_of(&"qing_yun_jian_zong")
	var registered: Dictionary = CATALOG_SCRIPT.MAPS[&"qing_yun_jian_zong"]
	assert_eq(int(entry["difficulty"]), int(registered["difficulty"]) + 1,
			"卡片难度应为探明表档位 +1（0 基 → 1 基）")
	assert_true(int(entry["difficulty"]) >= 1 and int(entry["difficulty"]) <= 4,
			"难度应落在 1~4（⭐ 数）")


func test_realm_requirement_comes_from_catalog_unlock_realm() -> void:
	for raw: Variant in es.call(&"get_map_list"):
		var entry: Dictionary = raw
		var registered: Dictionary = CATALOG_SCRIPT.MAPS[entry["map_id"]]
		assert_eq(int(entry["realm_requirement"]), int(registered["unlock_realm"]),
				"%s 的解锁门槛应取探明表的 unlock_realm" % entry["map_id"])


func test_unlock_state_follows_player_realm() -> void:
	GameStateManager.player.realm = 1
	var low: Array = es.call(&"get_map_list")
	GameStateManager.player.realm = 5
	var high: Array = es.call(&"get_map_list")
	assert_false(bool(_entry_in(low, &"gui_xu_fu_yun_lu")["is_unlocked"]),
			"炼气期不应解锁化神期地图")
	assert_true(bool(_entry_in(high, &"gui_xu_fu_yun_lu")["is_unlocked"]),
			"化神期应解锁化神期地图")


func test_cleared_flag_reads_gsm_map_state() -> void:
	GameStateManager.exploration.map_states = {TEST_MAP: {"is_first_clear": true}}
	assert_true(bool(_entry_of(TEST_MAP)["is_cleared"]),
			"map_states.is_first_clear 为 true 时条目应报已通关")
	GameStateManager.exploration.map_states = {}
	assert_false(bool(_entry_of(TEST_MAP)["is_cleared"]),
			"无 map_states 记录时应报未通关")


func test_cang_xuan_gu_zhan_chang_disallows_reentry() -> void:
	var entry: Dictionary = _entry_of(&"cang_xuan_gu_zhan_chang")
	assert_false(bool(entry["reentry_allowed"]),
			"苍玄古战场为剧情地图——不应允许重入（GDD §8）")


# ═══════════════════════════════════════════════════════════════════════════════
# 重入费用——来自经济公式
# ═══════════════════════════════════════════════════════════════════════════════

func test_first_entry_costs_nothing() -> void:
	var entry: Dictionary = _entry_of(TEST_MAP)
	assert_eq(int(entry["reentry_total"]), 0, "从未进入过的地图重入费为 0（首入免费）")
	assert_eq(int(entry["reentry_multiplier"]), 1, "首次倍率为 1.0")


func test_permanent_free_map_reports_free_and_cheap() -> void:
	var entry: Dictionary = _entry_of(FREE_MAP)
	assert_true(bool(entry["is_permanent_free"]), "青云剑宗应为永久免费地图")
	assert_eq(int(entry["reentry_total"]), 0, "永久免费地图重入费恒为 0")


func test_reentry_cost_grows_with_entry_count() -> void:
	GameStateManager.exploration.map_states = {TEST_MAP: {"entry_count": 1}}
	var second: Dictionary = _entry_of(TEST_MAP)
	GameStateManager.exploration.map_states = {TEST_MAP: {"entry_count": 3}}
	var fourth: Dictionary = _entry_of(TEST_MAP)
	assert_true(int(second["reentry_total"]) > 0, "第二次进入应收费")
	assert_true(int(fourth["reentry_total"]) > int(second["reentry_total"]),
			"进入次数越多费用越高（GDD §公式 10 递增）")
	assert_true(int(fourth["reentry_multiplier"]) < 3.0 \
			or int(fourth["reentry_multiplier"]) == 3,
			"倍率应被 3.0 上限夹住")


func test_can_reenter_reflects_ling_shi_balance() -> void:
	GameStateManager.exploration.map_states = {TEST_MAP: {"entry_count": 1}}
	GameStateManager.player.resources.ling_shi = 0
	var poor: Dictionary = _entry_of(TEST_MAP)
	var cost: int = int(poor["reentry_total"])
	GameStateManager.player.resources.ling_shi = cost
	var rich: Dictionary = _entry_of(TEST_MAP)
	assert_false(bool(poor["can_reenter"]), "灵石为 0 时不应可重入")
	assert_true(bool(rich["can_reenter"]), "灵石恰好够时应可重入")


# ═══════════════════════════════════════════════════════════════════════════════
# 降级——GSM 不可用时不崩溃、不臆造
# ═══════════════════════════════════════════════════════════════════════════════

func test_list_still_complete_without_gsm_state() -> void:
	# GSM 无探索状态时列表仍出全（按最保守解锁态）——不空白、不崩溃
	var entries: Array = es.call(&"get_map_list")
	assert_eq(entries.size(), CATALOG_SCRIPT.MAPS.size(),
			"GSM 状态为空时列表条数仍等于登记数")
	for raw: Variant in entries:
		assert_false(bool((raw as Dictionary)["is_cleared"]),
				"无记录的地图不应被报成已通关")


func test_list_module_is_usable_without_parent() -> void:
	# 子模块的父引用可空（防御——调用方忘记注入时返回 0/空，不崩溃）
	var orphan: RefCounted = MAP_LIST_SCRIPT.new(null)
	assert_eq(int(orphan.call(&"_reentry_total", TEST_MAP)), 0,
			"无父节点时重入费按 0 返回")
	assert_eq(float(orphan.call(&"_reentry_multiplier", TEST_MAP)), 1.0,
			"无父节点时倍率按 1.0 返回")


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 取某张地图的条目（不存在时断言失败并返回空字典）。
func _entry_of(p_map_id: StringName) -> Dictionary:
	return _entry_in(es.call(&"get_map_list"), p_map_id)


## 从列表里取某张地图的条目（不存在时失败）。
func _entry_in(p_entries: Array, p_map_id: StringName) -> Dictionary:
	for raw: Variant in p_entries:
		var entry: Dictionary = raw
		if entry.get(&"map_id") == p_map_id:
			return entry
	fail_test("列表里没有 %s" % p_map_id)
	return {}
