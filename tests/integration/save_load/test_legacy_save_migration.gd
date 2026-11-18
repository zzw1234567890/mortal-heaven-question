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
##   0. v3 档（有战斗中存档段、无牌面 / debuff）→ 读档成功、判为战斗中、两个新判据
##      都为「没有快照」（读档走自然发牌那条老路）；[br]
##   1. v1 档（带探索进度、无 [code]events_shown[/code]）→ 读档成功且进度原样；[br]
##   2. 迁移补出的 [code]events_shown[/code] 为空数组（不是 null——空值会让判定炸）；[br]
##   3. 迁移不改动已有进度字段（通关次数 / 已访问 / 已采 / 灵泉次数）；[br]
##   4. 缺整域的旧档（无 collection / deck / narrative）→ 填默认值而非拒绝；[br]
##   5. 缺埋字段的旧档（player 无 character_hp / unavailable_characters）→ 填默认值；[br]
##   6. 连 schema_version 都没有的档 → 走失败路径而非被当最新版硬读；[br]
##   7. 迁移后能再存一次（存档可继续用，不是「只读的博物馆」）。[br]
## [br]来源: ADR-0002 §JSON + 迁移链、ADR-0019 §向前兼容、本轮任务书第 2/3 条、
## 「战斗中存档 → 读档回到战斗」（v2 → v3 补 [code]battle_resume[/code] 段）、
## 本轮「牌面与 debuff 进存档」（v3 → v4 补 [code]cards[/code] / [code]debuffs[/code]）。

## 续战载荷模块——本文件只用它的[b]读侧判据[/b]（「这份档在不在战斗中」）。
const PayloadScript := preload("res://src/feature/combat/battle_resume_payload.gd")
## 牌面 / debuff 两段的判据（「有没有快照」——读档侧据此决定要不要接管）。
const CardsScript := preload("res://src/feature/combat/battle_resume_cards.gd")
const DebuffsScript := preload("res://src/feature/combat/battle_resume_debuffs.gd")

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
# 2.5 老档没有战斗段：读出来「不在战斗中」，探索态一字不动（B 项的兼容半边）
# ═══════════════════════════════════════════════════════════════════════════════

## 本轮把 [code]battle_resume[/code] 段加进存档，老档里根本没有这个键。[br]
## [br][b]为什么必须钉[/b]：读档侧的导航判据是「这份档在不在战斗中」——判错一头，
## 每次继续游戏都会被送进战斗场景（而那里没有任何可续的仗）；判错另一头更隐蔽：
## 「读档时把战斗段清一遍」顺手写坏探索域，玩家丢的是整张图的进度。[br]
## [br][b]断言的是读侧口径[/b]：迁移补出来的是空段 → [method
## BattleResumePayload.is_in_battle] 为 false、[method
## BattleResumePayload.is_resumable_payload] 为 false——主菜单据此走探索那条老路。
func test_v2_save_without_battle_section_reads_as_not_in_battle() -> void:
	# Arrange——v2 形态（本轮之前的最新版）：有完整 game_state，没有 battle_resume
	var game_state: Dictionary = _v1_game_state()
	assert_false(game_state.has("battle_resume"), "前置：老档确实没有这个键")
	_write_legacy_save(2, game_state)
	# Act
	assert_eq(_load_legacy(), SLS.LoadResult.SUCCESS, "v2 老档必须读得进来")
	# Assert——迁移补出了这一段，且它表示「没有进行中的战斗」
	assert_true((gsm.get("battle_resume") as Variant) is Dictionary,
			"迁移应补出 battle_resume 段（缺域不能留 null——读侧会对它取键）")
	assert_false(PayloadScript.is_in_battle(gsm.battle_resume),
			"老档不得被判为「在战斗中」（否则继续游戏会把玩家送进战斗场景）")
	assert_false(PayloadScript.is_resumable_payload(gsm.battle_resume),
			"老档不得被判为可续战")
	assert_eq(gsm.battle_resume, {}, "补出来的是空段（不是一份凑出来的假载荷）")


## 迁移补战斗段时不得碰探索域的一个字节。[br]
## [br][b]为什么单独一条[/b]：迁移函数是「就地改 [code]game_state[/code] 字典」的
## 写法，多写一个键就可能连带把探索条目也改掉——而那种损坏只会在读档后体现为
## 「进度少了几个节点」，很难反查到迁移。
func test_v2_migration_leaves_exploration_state_untouched() -> void:
	# Arrange
	_write_legacy_save(2, _v1_game_state())
	# Act
	assert_eq(_load_legacy(), SLS.LoadResult.SUCCESS)
	# Assert——探索态逐项与盘上那份一致
	var state: Dictionary = state_of_a()
	assert_eq(int(state.get("clear_count", -1)), 2, "通关次数不受迁移影响")
	assert_eq(int(state.get("entry_count", -1)), 3, "进图次数不受迁移影响")
	assert_eq(int(state.get("collected_ling_shi", -1)), 45, "已收灵识不受迁移影响")
	assert_eq(gsm.exploration.visited_nodes, [0, 101], "已访问节点不受迁移影响")
	assert_eq(gsm.exploration.action_points, 1, "行动力不受迁移影响")
	assert_eq(str(gsm.exploration.current_map), str(MAP_A), "当前地图不受迁移影响")
	assert_eq(HarvestScript.harvested_slots(state, 203), [1], "已采槽位不受迁移影响")


# ═══════════════════════════════════════════════════════════════════════════════
# 2.6 v3 档：有战斗中存档段，但没有牌面 / debuff（本轮新增字段的兼容半边）
# ═══════════════════════════════════════════════════════════════════════════════

## v3 档的续战段只记「谁、多少血、第几回合、什么阶段、还有多少费」——没有牌面与
## debuff。[br]
## [br][b]为什么必须钉[/b]：读档侧的判据是「这一段有没有牌面快照」——判错一头，
## 玩家读档回来会面对一副被清空的手牌（照空数组接管）；判错另一头更隐蔽：
## 迁移顺手往[b]空段[/b]里塞两个形状，把「这份档不是在战斗中存的」变成一个带内容的段，
## 「继续游戏」就会把玩家送进一场根本不存在的仗。[br]
## [br][b]断言的是读侧口径[/b]：迁移补出的是空形状 → 牌面 / debuff 两个判据都为 false
## → 续战走自然发牌那条老路（与升级前逐位一致）。
func test_v3_save_with_battle_section_gets_empty_card_and_debuff_shapes() -> void:
	# Arrange——v3 形态：有正在进行的战斗段，没有本轮新增的两个键
	var game_state: Dictionary = _v1_game_state()
	game_state["battle_resume"] = _v3_battle_section()
	assert_false((game_state["battle_resume"] as Dictionary).has("cards"),
			"前置：v3 档确实没有牌面段")
	assert_false((game_state["battle_resume"] as Dictionary).has("debuffs"),
			"前置：v3 档确实没有 debuff 段")
	_write_legacy_save(3, game_state)
	# Act
	assert_eq(_load_legacy(), SLS.LoadResult.SUCCESS, "v3 档必须读得进来")
	# Assert——迁移补出了两个空形状，且这一份档仍被判为「在战斗中」
	var loaded: Dictionary = gsm.battle_resume
	assert_true(PayloadScript.is_in_battle(loaded), "有战况的 v3 档仍应判为战斗中")
	assert_true(PayloadScript.is_resumable_payload(loaded), "名册齐备的 v3 档仍可续战")
	assert_true(CardsScript.has_state(loaded) == false,
			"v3 档没有牌面内容——读侧必须走自然发牌（照空数组接管会清空手牌）")
	assert_false(DebuffsScript.has_state(loaded), "v3 档没有 debuff 内容")


## 迁移往[b]正在进行的[/b]战斗段补形状时，不得动它已有的进度字段。[br]
## [br][b]为什么单独一条[/b]：迁移是「就地改 game_state 字典」的写法，多写一个键
## 就可能连带把进度改掉——而那种损坏只会在读档后体现为「回合数回去了」。
func test_v3_migration_leaves_battle_progress_untouched() -> void:
	# Arrange
	var game_state: Dictionary = _v1_game_state()
	game_state["battle_resume"] = _v3_battle_section()
	_write_legacy_save(3, game_state)
	# Act
	assert_eq(_load_legacy(), SLS.LoadResult.SUCCESS)
	# Assert——进度逐项与盘上那份一致
	var loaded: Dictionary = gsm.battle_resume
	assert_eq(int(loaded[PayloadScript.KEY_TURN]), 4, "回合数不受迁移影响")
	assert_eq(int(loaded[PayloadScript.KEY_PHASE]), 3, "阶段不受迁移影响")
	assert_eq(int(loaded[PayloadScript.KEY_CURRENT_COST]), 2, "当前费用不受迁移影响")
	assert_eq(int(loaded[PayloadScript.KEY_MAX_COST]), 5, "费用上限不受迁移影响")
	assert_eq(PayloadScript.player_ids(loaded), [8801, 8802], "阵容不受迁移影响")


## v2 → v3 → v4 连走时，第三步不得给[b]空[/b]段补形状。[br]
## [br][b]为什么必须钉[/b]：空段的含义是「这份档不是在战斗中存的」——给它塞两个形状
## 会让主菜单的导航判据改道（把玩家送进战斗场景，而那里没有可续的仗）。
func test_v2_save_keeps_empty_battle_section_after_full_chain() -> void:
	# Arrange——v2 档（根本没有 battle_resume 键），要连走 v2→v3→v4
	var game_state: Dictionary = _v1_game_state()
	_write_legacy_save(2, game_state)
	# Act
	assert_eq(_load_legacy(), SLS.LoadResult.SUCCESS)
	# Assert——还是空段，没有被补上形状
	assert_eq(gsm.battle_resume, {}, "空段在四级迁移后仍应是空段")
	assert_false(PayloadScript.is_in_battle(gsm.battle_resume),
			"老档不得被判为「在战斗中」（否则继续游戏会被送进战斗场景）")


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


## v3 形态的续战段——有战况，没有本轮新增的牌面 / debuff 两个键。[br]
## [br][b]形状照抄 v3 的实现口径[/b]（[code]battle_resume_payload.build[/code] 当时
## 的产出），不抄一份「精简版」——精简版会被读侧的宽容处理放过去，用例就证明不了
## 「真实 v3 档能读」。
func _v3_battle_section() -> Dictionary:
	return {
		PayloadScript.KEY_IS_ACTIVE: true,
		PayloadScript.KEY_SCENE_ID: 4,
		PayloadScript.KEY_PHASE: 3,
		PayloadScript.KEY_TURN: 4,
		PayloadScript.KEY_CURRENT_COST: 2,
		PayloadScript.KEY_MAX_COST: 5,
		PayloadScript.KEY_ORIGIN_NODE_ID: 42,
		PayloadScript.KEY_ORIGIN_COMBAT_TYPE: "battle",
		PayloadScript.KEY_PLAYER_ROSTER: [
			{PayloadScript.KEY_CHARACTER_ID: 8801, PayloadScript.KEY_CURRENT_HP: 3,
				PayloadScript.KEY_MAX_HP: 12, PayloadScript.KEY_IS_ALIVE: true,
				PayloadScript.KEY_SLOT_INDEX: 0, PayloadScript.KEY_IS_FRONT: true},
			{PayloadScript.KEY_CHARACTER_ID: 8802, PayloadScript.KEY_CURRENT_HP: 5,
				PayloadScript.KEY_MAX_HP: 9, PayloadScript.KEY_IS_ALIVE: true,
				PayloadScript.KEY_SLOT_INDEX: 1, PayloadScript.KEY_IS_FRONT: true},
		],
		PayloadScript.KEY_ENEMY_ROSTER: [
			{PayloadScript.KEY_CHARACTER_ID: 100000,
				PayloadScript.KEY_TEMPLATE_ID: "san_xiu",
				PayloadScript.KEY_CURRENT_HP: 6, PayloadScript.KEY_MAX_HP: 16,
				PayloadScript.KEY_IS_ALIVE: true,
				PayloadScript.KEY_SLOT_INDEX: 0, PayloadScript.KEY_IS_FRONT: true},
		],
		PayloadScript.KEY_CONFIG: {
			"character_ids": [8801, 8802],
			"enemy_template_ids": ["san_xiu"],
			"enemy_level": 1,
			"rewards": {},
		},
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
