extends "res://tests/integration/save_load/save_round_trip_fixture.gd"
## 旧档兼容验收：v1（无 [code]events_shown[/code]）存档读进来[b]不报错、不丢档[/b]。[br]
## [br][b]本文件补的断链[/b]：[code]CURRENT_SCHEMA_VERSION[/code] 本轮从 1 提到 2
## （[code]map_states[*].events_shown[/code] 进存档），而 v1 档里根本没有这个键。
## 迁移链 [constant SaveLoadSystem.DEFAULT_MIGRATIONS] 负责补空数组；[code]GSM[/code]
## 的默认值驱动归一负责补其余缺字段——两条都必须[b]真的跑在 load_game 路径上[/b]，
## 否则玩家一升级游戏就会看到「存档损坏」。[br]
## [br][b]为什么用真实文件而不是构造字典[/b]：被测的是「磁盘上那份旧 JSON → 可玩状态」
## 的整条路（[code]_atomic_read → _validate_version → _migrate_if_needed →
## gsm.deserialize[/code]），任何一环少一步都在本文件里变红。[br]
## [br][b]覆盖[/b]：[br]
##   1. v1 档（带探索进度、无 [code]events_shown[/code]）→ 读档成功且进度原样；[br]
##   2. 迁移补出的 [code]events_shown[/code] 为空数组（不是 null——空值会让判定炸）；[br]
##   3. 迁移不改动已有进度字段（通关次数 / 已访问 / 已采 / 灵泉次数）；[br]
##   4. 缺整域的旧档（无 collection / deck / narrative）→ 填默认值而非拒绝；[br]
##   5. 缺埋字段的旧档（player 无 character_hp / unavailable_characters）→ 填默认值；[br]
##   6. 连 schema_version 都没有的档 → 走失败路径而非被当最新版硬读；[br]
##   7. 迁移后能再存一次（存档可继续用，不是「只读的博物馆」）。[br]
## [br]来源: ADR-0002 §JSON + 迁移链、ADR-0019 §向前兼容、本轮任务书第 2/3 条。

## 用例存档根目录——专用子目录，避免与往返用例互相清场。
const LEGACY_ROOT: String = "user://test_legacy_migration_saves/"


## 换到本文件专用的存档根（夹具按它建目录、清目录）。
func root_path() -> String:
	return LEGACY_ROOT


func _load_legacy() -> int:
	var result: Dictionary = sls.load_game(SLS.SaveSlotType.MANUAL, 1)
	return int(result.get("result", SLS.LoadResult.DESERIALIZE_ERROR))


## 旧档槽位路径（与 [member sls] 的测试根一致）。
func _save_path() -> String:
	return LEGACY_ROOT + "manual/save_1.json"


# ═══════════════════════════════════════════════════════════════════════════════
# 1. v1 档：带探索进度、无 events_shown
# ═══════════════════════════════════════════════════════════════════════════════

func test_v1_save_loads_and_keeps_progress() -> void:
	# Arrange——写一份 schema_version=1 的真实存档文件
	_write_legacy_save(1, _v1_game_state())
	# Act
	assert_eq(_load_legacy(), SLS.LoadResult.SUCCESS, "v1 档必须读得进来（不能报损坏）")
	# Assert——进度原样
	var state: Dictionary = state_of_a()
	assert_true(bool(state.get("is_first_clear", false)), "v1 档的通关标记保持")
	assert_eq(ClearScript.new().clear_count_of(MAP_A, gsm), 2, "v1 档的通关次数保持")
	assert_eq(gsm.exploration.visited_nodes, [0, 101], "v1 档的已访问节点保持（元素仍是 int）")
	assert_true(gsm.exploration.visited_nodes.has(101), "已访问判定在 v1 档上同样成立")
	assert_eq(HarvestScript.harvested_slots(state, 203), [1], "v1 档的已采槽位保持")
	assert_true(HarvestScript.is_harvested(state, 203, 1), "v1 档的已采判定成立")
	assert_eq(typeof(state.get("clear_count")), TYPE_INT, "计数还原为 int")


func test_v1_save_gets_empty_events_shown_from_migration() -> void:
	# Arrange——v1 档的 map_states 里没有 events_shown
	var game_state: Dictionary = _v1_game_state()
	assert_false((game_state["exploration"]["map_states"][str(MAP_A)] as Dictionary)
			.has(ShownScript.KEY_EVENTS_SHOWN), "前置条件：v1 档确实没有这个键")
	_write_legacy_save(1, game_state)
	# Act
	assert_eq(_load_legacy(), SLS.LoadResult.SUCCESS)
	# Assert——迁移补出的是空数组（读侧的 shown_of 对非数组也宽容，但空数组才是规范形态）
	var state: Dictionary = state_of_a()
	assert_true(state.has(ShownScript.KEY_EVENTS_SHOWN), "v1 档读档后补出了 events_shown")
	assert_eq(ShownScript.shown_of(state), [], "补出的是空数组——没有凭空多出「已弹」")
	assert_false(ShownScript.is_shown(state, 101), "v1 档的节点仍视为未弹过")


func test_v1_save_migration_does_not_touch_existing_fields() -> void:
	## 迁移只该补新键——动到已有进度就是「读档把玩家的通关记录改了」。
	# Arrange
	_write_legacy_save(1, _v1_game_state())
	# Act
	assert_eq(_load_legacy(), SLS.LoadResult.SUCCESS)
	# Assert
	var state: Dictionary = state_of_a()
	assert_eq(int(state.get("entry_count", -1)), 3, "进入次数未被迁移改动")
	assert_eq(int(state.get("action_spring_uses", -1)), 1, "灵泉次数未被迁移改动")
	assert_eq(int(state.get("collected_ling_shi", -1)), 45, "已收集灵石未被迁移改动")
	assert_eq(gsm.exploration.action_points, 1, "行动力未被迁移改动")
	assert_eq(gsm.exploration.max_action_points, 5, "行动力上限未被迁移改动")
	assert_eq(gsm.player.resources.ling_shi, 88, "灵石未被迁移改动")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 更旧的档：整域 / 整字段缺失
# ═══════════════════════════════════════════════════════════════════════════════

func test_save_missing_whole_domains_fills_defaults() -> void:
	## 旧档可能整块没有 collection / deck / narrative——缺失即填默认，绝不拒绝。
	# Arrange
	var game_state: Dictionary = _v1_game_state()
	game_state.erase("collection")
	game_state.erase("deck")
	game_state.erase("narrative")
	_write_legacy_save(1, game_state)
	# Act
	assert_eq(_load_legacy(), SLS.LoadResult.SUCCESS, "缺整域不该被当成损坏")
	# Assert
	assert_eq((gsm.collection.owned_cards as Array).size(), 0, "collection 填默认空收藏")
	assert_eq((gsm.deck.slots as Array).size(), 6, "deck 填默认 6 空位")
	assert_eq(gsm.deck.current_deck, [], "deck 填默认空卡组")
	assert_eq(str(gsm.narrative.current_chapter), "", "narrative 填默认章节")


func test_save_missing_player_fields_fills_defaults() -> void:
	## 本轮新增过的字段（阵亡表 / 残血）在旧档里也不存在。
	# Arrange
	var game_state: Dictionary = _v1_game_state()
	(game_state["player"] as Dictionary).erase("unavailable_characters")
	(game_state["player"] as Dictionary).erase("character_hp")
	(game_state["player"] as Dictionary).erase("talent_map")
	_write_legacy_save(1, game_state)
	# Act
	assert_eq(_load_legacy(), SLS.LoadResult.SUCCESS, "缺字段不该被当成损坏")
	# Assert
	assert_eq((gsm.player.unavailable_characters as Dictionary).size(), 0, "阵亡表填默认空表")
	assert_eq((gsm.player.character_hp as Dictionary).size(), 0, "残血表填默认空表")
	assert_eq((gsm.player.talent_map as Dictionary).size(), 0, "天赋表填默认空表")
	assert_eq(str(gsm.player.identity_id), "legacy_identity", "旧档已有的身份保持不动")


func test_save_without_schema_version_is_rejected_not_assumed_current() -> void:
	## 连 schema_version 都没有的更老档：默认 0 起走，而 0 没有登记迁移 → MIGRATION_MISSING。
	## 这条钉住「不静默当成最新版读进来」——旧到无从迁移的档宁可报错也不乱猜。
	# Arrange
	_write_legacy_save(0, _v1_game_state())
	# Act
	var result: Dictionary = sls.load_game(SLS.SaveSlotType.MANUAL, 1)
	# Assert
	assert_eq(int(result.get("result", -1)), SLS.LoadResult.DESERIALIZE_ERROR,
			"无登记迁移的 0 版档应走失败路径（而非被当最新版硬读）")
	assert_push_error_count(1, "应有一条迁移失败的 push_error（玩家据此看到损坏提示）")
	assert_eq(gsm.exploration.map_states.size(), 0, "失败时内存状态不得被部分写入")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 迁移后仍是可存档状态
# ═══════════════════════════════════════════════════════════════════════════════

func test_migrated_save_can_be_saved_again() -> void:
	## v1 档读进来 → 直接存成 v2——旧档升级后必须能继续玩（不是只读的博物馆）。
	# Arrange
	_write_legacy_save(1, _v1_game_state())
	assert_eq(_load_legacy(), SLS.LoadResult.SUCCESS)
	# Act——不重新播种，直接存（目标槽位与旧档同一个）
	assert_eq(sls.save_game(SLS.SaveSlotType.MANUAL, 1, gsm.serialize(), {}),
			SLS.SaveResult.SUCCESS, "迁移后的内存状态必须仍可存档")
	# Assert——落盘的是当前版本号
	var read: Dictionary = sls._parse_json_file(_save_path())
	assert_eq(int((read["data"] as Dictionary).get("schema_version", -1)),
			SLS.CURRENT_SCHEMA_VERSION, "再存档写入的是当前 schema 版本")
	# Assert——再读回来进度仍在
	assert_eq(_load_legacy(), SLS.LoadResult.SUCCESS, "再读仍成功")
	var state: Dictionary = state_of_a()
	assert_eq(int(state.get("clear_count", 0)), 2, "二次往返后 v1 档的通关次数不变")
	assert_eq(ShownScript.shown_of(state), [], "二次往返后 events_shown 仍为空")
	assert_eq(gsm.exploration.visited_nodes, [0, 101], "二次往返后已访问节点不变")


# ═══════════════════════════════════════════════════════════════════════════════
# 夹具
# ═══════════════════════════════════════════════════════════════════════════════

## v1 形态的 game_state：探索进度齐全，但没有 events_shown（也没有本轮新增的
## 阵亡表 / 残血表——那两处由缺字段用例单独覆盖）。
func _v1_game_state() -> Dictionary:
	return {
		"meta": {"game_id": "legacy", "seed": 7, "timestamp": 100},
		"player": {
			"realm": 2, "cultivation": 300, "max_cultivation": 1500,
			"cultivation_full": false, "is_fallen": false, "overflow_pool": 0,
			"resources": {"ling_shi": 88,
				"ling_cai": {"low": 1, "medium": 0, "high": 0, "top": 0},
				"dan_yao_sui_pian": 3},
			"identity_id": "legacy_identity", "talents": ["t_a"], "talent_map": {"t_a": 2},
			"tribulation_state": 0, "consecutive_tribulation_failures": 0,
		},
		"collection": {"owned_cards": [], "total_count": 0},
		"deck": {"current_deck": [], "slots": [null, null, null, null, null, null],
			"change_log": [], "session_remove_count": 0, "deck_limit_modifier": 0},
		"exploration": {
			"current_map": str(MAP_A),
			"node_position": {"layer": 2, "idx": 3},
			"visited_nodes": [0, 101],
			"action_points": 1,
			"max_action_points": 5,
			"map_states": {
				str(MAP_A): {
					"is_first_clear": true,
					"clear_count": 2,
					"entry_count": 3,
					"action_spring_uses": 1,
					"collected_ling_shi": 45,
					"harvested": {"203": [1]},
					"graph": {"0": [101], "101": [], "203": []},
					"nodes": {"101": {"type": "battle"}, "203": {"type": "harvest"}},
				},
			},
		},
		"narrative": {"current_chapter": "chapter_1",
			"current_chapter_progress": {"completed_required_events": [],
				"boss_unlocked": false, "boss_defeated": false, "ending_chosen": ""},
			"completed_chapters": [], "story_flags": {}},
	}


## 把 game_state 包成存档容器写进测试槽位（[param p_schema] 控制 schema_version）。
func _write_legacy_save(p_schema: int, p_game_state: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(_save_path().get_base_dir())
	var container: Dictionary = {
		"schema_version": p_schema,
		"version": "1.0.0",
		"timestamp": "2026-01-01T00:00:00Z",
		"playtime_seconds": 600,
		"meta": {"player_name": "旧档玩家", "realm": "筑基"},
		"game_state": p_game_state,
		"complete": true,
	}
	var file: FileAccess = FileAccess.open(_save_path(), FileAccess.WRITE)
	assert_not_null(file, "应能创建测试存档文件")
	file.store_string(JSON.stringify(container, "\t"))
	file.close()
