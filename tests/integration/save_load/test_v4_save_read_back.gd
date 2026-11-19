extends "res://tests/integration/save_load/save_round_trip_fixture.gd"
## 当前版本（v4）存档的[b]原样读回[/b]验收。[br]
## [br][b]为什么单独一个文件[/b]：老档用例（[code]test_legacy_save_migration.gd[/code]）
## 验的全是「旧档被迁移补成什么样」，而当前版本走的是迁移链的[b]空转分支[/b]
## （[code]save_schema == CURRENT_SCHEMA_VERSION[/code]，[code]DEFAULT_MIGRATIONS[/code]
## 里没有它的条目）。那条分支与迁移函数是两份不同的代码，坏法也不同：迁移函数写坏是
## 「老档读不进来」，空转分支写坏是「新档被折一遍」——后者所有老档用例仍然全绿。[br]
## [br][b]覆盖[/b]：[br]
##   1. v4 档（续战段带齐牌面 / debuff）读回来：三堆逐 ID 与顺序不丢、debuff 逐条还在；[br]
##   2. 读侧判据认得它有快照（走接管那条路，不是自然发牌）；[br]
##   3. 进度字段与探索域都原样（空转不该动任何东西）。[br]
## [br][b]为什么用真实文件[/b]：被测的是「磁盘上那份 JSON → 可玩状态」的整条路
## （[code]_atomic_read → _validate_version → _migrate_if_needed → gsm.deserialize[/code]），
## 任何一环少一步都在本文件里变红。[br]
## [br]装置见 [code]save_round_trip_fixture.gd[/code]（真 GSM + 真 SaveLoadSystem +
## 真文件，仅换存档根）。[br]
## [br]来源: ADR-0002 §JSON + 迁移链、ADR-0019 §向前兼容、本轮任务书
## 「老 v4 存档仍可读」。

## 续战载荷与两段形状的[b]读侧判据[/b]（「这份档带没带快照」）。
const PayloadScript := preload("res://src/feature/combat/battle_resume_payload.gd")
const CardsScript := preload("res://src/feature/combat/battle_resume_cards.gd")
const DebuffsScript := preload("res://src/feature/combat/battle_resume_debuffs.gd")

## 用例存档根目录——专用子目录，避免与其它套件互相清场。
const V4_ROOT: String = "user://test_v4_save_saves/"

## 续战段的进度值（都不是出厂值——重置与没存都会被抓出来）。
const TURN: int = 4
const PHASE: int = 3
const COST: int = 2
const MAX_COST: int = 5
const ORIGIN_NODE: int = 42
## 三堆牌（顺序刻意打乱——顺序错了「顺序也一致」这条断言才会红）。
const HAND_IDS: Array[int] = [9101, 9102]
const DRAW_IDS: Array[int] = [9103]
const DISCARD_IDS: Array[int] = [9104, 9105]
## 存档里挂着的一条 debuff（数值不是出厂值）。
const DEBUFF_AMOUNT: int = 3
const DEBUFF_DURATION: int = 2


## 换到本文件专用的存档根（夹具按它建目录、清目录）。
func root_path() -> String:
	return V4_ROOT


func _save_path() -> String:
	return V4_ROOT + "manual/save_1.json"


func _load_v4() -> int:
	var result: Dictionary = sls.load_game(SLS.SaveSlotType.MANUAL, 1)
	return int(result.get("result", SLS.LoadResult.DESERIALIZE_ERROR))


## 一份 v4 档的 game_state——带齐续战段的全部内容（含牌面与 debuff 两段）。[br]
## [br][b]形状照抄写侧的产出[/b]（[code]battle_resume_payload.build[/code] +
## [code]battle_resume_cards.fold[/code] + [code]battle_resume_debuffs.fold[/code]），
## 不抄一份「精简版」——精简版会被读侧的宽容处理放过去，用例就证明不了「真实 v4 档能读」。
func _v4_game_state() -> Dictionary:
	return {
		"meta": {"game_id": "v4", "seed": 7, "timestamp": 100},
		"player": {
			"realm": 2, "cultivation": 300, "max_cultivation": 1500,
			"cultivation_full": false, "is_fallen": false, "overflow_pool": 0,
			"resources": {"ling_shi": 88,
				"ling_cai": {"low": 1, "medium": 0, "high": 0, "top": 0},
				"dan_yao_sui_pian": 3},
			"identity_id": "v4_identity", "talents": ["t_a"], "talent_map": {"t_a": 2},
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
		"battle_resume": _v4_battle_section(),
	}


## v4 形态的续战段——进度 + 名册 + 三堆牌 + debuff，一段不缺。
func _v4_battle_section() -> Dictionary:
	return {
		PayloadScript.KEY_IS_ACTIVE: true,
		PayloadScript.KEY_SCENE_ID: 4,
		PayloadScript.KEY_PHASE: PHASE,
		PayloadScript.KEY_TURN: TURN,
		PayloadScript.KEY_CURRENT_COST: COST,
		PayloadScript.KEY_MAX_COST: MAX_COST,
		PayloadScript.KEY_ORIGIN_NODE_ID: ORIGIN_NODE,
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
		CardsScript.KEY_CARDS: {
			CardsScript.KEY_HAND: _card_entries(HAND_IDS),
			CardsScript.KEY_DRAW_PILE: _card_entries(DRAW_IDS),
			CardsScript.KEY_DISCARD_PILE: _card_entries(DISCARD_IDS),
		},
		DebuffsScript.KEY_DEBUFFS: [{
			DebuffsScript.KEY_TARGET_ID: 100000,
			DebuffsScript.KEY_TYPE: "atk_down",
			DebuffsScript.KEY_DURATION: DEBUFF_DURATION,
			DebuffsScript.KEY_AMOUNT: DEBUFF_AMOUNT,
			DebuffsScript.KEY_SOURCE_ID: 8801,
		}],
	}


## 一堆牌的存档条目（形状与写侧折叠的产出同一口径）。[br]
## [br][b]等级刻意不全为 1[/b]：升级与否要能被读侧区分——全 1 的话
## 「等级也一致」这条断言证明不了任何事。
func _card_entries(p_ids: Array) -> Array:
	var out: Array = []
	for idx: int in range(p_ids.size()):
		var cid: int = int(p_ids[idx])
		out.append({
			CardsScript.KEY_CARD_INSTANCE_ID: cid,
			CardsScript.KEY_TEMPLATE_ID: "card_%d" % cid,
			CardsScript.KEY_LEVEL: 1 if idx == 0 else 2,
		})
	return out


## 把 game_state 包成当前版本的存档容器写进测试槽位。
func _write_v4_save(p_game_state: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(_save_path().get_base_dir())
	var container: Dictionary = {
		"schema_version": SLS.CURRENT_SCHEMA_VERSION,
		"version": "1.0.0",
		"timestamp": "2026-01-01T00:00:00Z",
		"playtime_seconds": 600,
		"meta": {"player_name": "当前版本玩家", "realm": "筑基"},
		"game_state": p_game_state,
		"complete": true,
	}
	var file: FileAccess = FileAccess.open(_save_path(), FileAccess.WRITE)
	assert_not_null(file, "应能创建测试存档文件")
	file.store_string(JSON.stringify(container, "\t"))
	file.close()


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 当前版本原样读回
# ═══════════════════════════════════════════════════════════════════════════════

## 当前版本的档要能原样读回来——迁移链「不做事」的那一头同样要有断言。[br]
## [br][b]为什么必须钉[/b]：空转分支若被写成「也要补一遍形状」，就会往[b]已经有内容[/b]
## 的段里再折一次——症状是三堆牌变成空、debuff 归零，而所有老档用例仍然全绿。[br]
## [br][b]断言的是读侧解析口径[/b]：三堆逐 ID 相等、debuff 逐条还在——不是「读进来没报错」。
func test_v4_save_reads_back_with_cards_and_debuffs_intact() -> void:
	# Arrange
	_write_v4_save(_v4_game_state())
	# Act
	assert_eq(_load_v4(), SLS.LoadResult.SUCCESS, "当前版本的档必须读得回来")
	# Assert——读侧认得这份档有快照（走接管那条路，不是自然发牌）
	var loaded: Dictionary = gsm.battle_resume
	assert_true(PayloadScript.is_in_battle(loaded), "v4 档应判为战斗中")
	assert_true(PayloadScript.is_resumable_payload(loaded), "名册齐备的 v4 档可续战")
	assert_true(CardsScript.has_state(loaded),
			"v4 档有牌面内容——读侧必须接管三堆（判成「没有快照」会把玩家的手牌清空）")
	assert_true(DebuffsScript.has_state(loaded), "v4 档有 debuff 内容——读侧必须灌回")
	# Assert——三堆逐 ID 与顺序不丢
	assert_eq(CardsScript.ids_of(loaded, CardsScript.KEY_HAND), HAND_IDS,
			"手牌应逐 ID、逐顺序读回（顺序即抽牌顺序）")
	assert_eq(CardsScript.ids_of(loaded, CardsScript.KEY_DRAW_PILE), DRAW_IDS, "抽牌堆不丢")
	assert_eq(CardsScript.ids_of(loaded, CardsScript.KEY_DISCARD_PILE), DISCARD_IDS,
			"弃牌堆不丢（丢了等于把出过的牌还回牌堆）")


## debuff 逐条读回——只剩「有一条」而数值归零等于没存。[br]
## [br][b]为什么要分开一条[/b]：牌面与 debuff 是两段独立形状，判据也各自独立
## （[code]has_state[/code] 两处各一个）——一条断言盖不住另一条。
func test_v4_save_keeps_debuff_entries_with_values() -> void:
	# Arrange
	_write_v4_save(_v4_game_state())
	assert_eq(_load_v4(), SLS.LoadResult.SUCCESS, "前置：读档成功")
	# Act
	var entries: Array = DebuffsScript.entries_of(gsm.battle_resume)
	# Assert——条数与数值都取存档值
	assert_eq(entries.size(), 1, "debuff 应逐条读回")
	assert_eq(int(entries[0][DebuffsScript.KEY_AMOUNT]), DEBUFF_AMOUNT,
			"debuff 数值不丢（归零的减益等于没存）")
	assert_eq(int(entries[0][DebuffsScript.KEY_DURATION]), DEBUFF_DURATION,
			"剩余回合不丢（合并成总量会让两批到期的时点塌成一个）")


## 空转分支不得改动进度与探索域——它「什么都不做」正是它唯一正确的行为。[br]
## [br][b]为什么与上面两条分开[/b]：上两条盯「新段有没有被折坏」，这一条盯
## 「有没有被多写一笔」——坏法不同、红法也不同。
func test_v4_save_keeps_progress_and_exploration_untouched() -> void:
	# Arrange
	_write_v4_save(_v4_game_state())
	# Act
	assert_eq(_load_v4(), SLS.LoadResult.SUCCESS, "前置：读档成功")
	# Assert——续战段的进度逐项与盘上那份一致
	var loaded: Dictionary = gsm.battle_resume
	assert_eq(int(loaded[PayloadScript.KEY_TURN]), TURN, "回合数不受影响")
	assert_eq(int(loaded[PayloadScript.KEY_PHASE]), PHASE, "阶段不受影响")
	assert_eq(int(loaded[PayloadScript.KEY_CURRENT_COST]), COST, "当前费用不受影响")
	assert_eq(int(loaded[PayloadScript.KEY_MAX_COST]), MAX_COST, "费用上限不受影响")
	assert_eq(PayloadScript.player_ids(loaded), [8801, 8802], "阵容不受影响")
	# Assert——探索侧也原样（同一份档里两件事互不干扰）
	assert_eq(int(state_of_a().get("clear_count", 0)), 2, "通关次数不受影响")
	assert_eq(gsm.exploration.visited_nodes, [0, 101], "已访问节点不受影响")


## 读回来的档必须还能再存一次——「能读」不等于「能继续玩」。[br]
## [br][b]为什么必须有这条[/b]：读进来的形状若被折成读侧认、写侧不认的样子
## （例如把三堆折成了字符串），下一次存档会在校验那一步失败——玩家打完这一仗就丢档。
func test_v4_save_can_be_saved_again() -> void:
	# Arrange
	_write_v4_save(_v4_game_state())
	assert_eq(_load_v4(), SLS.LoadResult.SUCCESS, "前置：读档成功")
	# Act——不重新播种，直接存
	assert_eq(save_slot(), SLS.SaveResult.SUCCESS, "读回来的 v4 状态必须仍可存档")
	# Assert——落盘的是当前版本号，且再读回来三堆还在
	var read: Dictionary = sls._parse_json_file(_save_path())
	assert_eq(int((read["data"] as Dictionary).get("schema_version", -1)),
			SLS.CURRENT_SCHEMA_VERSION, "再存档写入的是当前 schema 版本")
	assert_eq(_load_v4(), SLS.LoadResult.SUCCESS, "再读仍成功")
	assert_eq(CardsScript.ids_of(gsm.battle_resume, CardsScript.KEY_HAND), HAND_IDS,
			"二次往返后三堆牌仍在（形状被折坏会在这里红）")
