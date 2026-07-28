extends GutTest
## Story 004 验收测试：GSM 序列化与反序列化。
## 覆盖 AC-017~AC-019 + round-trip 往返 + deep copy 解耦。

const GSM_SCRIPT := preload("res://src/foundation/game_state_manager.gd")

var gsm


func before_each() -> void:
	gsm = GSM_SCRIPT.new()
	gsm._ready()


func after_each() -> void:
	gsm.free()
	gsm = null


# ═════════════════════════════════════════════════════════════════════════════
# AC-017：序列化排除 battle 和 session 域
# ═════════════════════════════════════════════════════════════════════════════

func test_ac017_serialize_excludes_battle() -> void:
	gsm.battle = {"round": 3}
	var data: Dictionary = gsm.serialize()
	assert_false(data.has("battle"), "battle 域不应出现在序列化输出中")


func test_ac017_serialize_excludes_session() -> void:
	gsm.session.current_scene = "battle_scene"
	var data: Dictionary = gsm.serialize()
	assert_false(data.has("session"), "session 域不应出现在序列化输出中")


func test_ac017_serialize_includes_all_persistent_domains() -> void:
	var data: Dictionary = gsm.serialize()
	assert_true(data.has("meta"), "meta 域应存在")
	assert_true(data.has("player"), "player 域应存在")
	assert_true(data.has("collection"), "collection 域应存在")
	assert_true(data.has("deck"), "deck 域应存在")
	assert_true(data.has("exploration"), "exploration 域应存在")
	assert_true(data.has("narrative"), "narrative 域应存在")
	assert_eq(data.size(), 6, "仅 6 个持久域")


func test_ac017_serialize_preserves_values() -> void:
	gsm.player.cultivation = 500
	gsm.player.realm = GSM_SCRIPT.RealmLevel.FOUNDATION
	var data: Dictionary = gsm.serialize()
	assert_eq(data.player.cultivation, 500)
	assert_eq(data.player.realm, GSM_SCRIPT.RealmLevel.FOUNDATION)


func test_ac017_serialize_deep_copy_independent() -> void:
	gsm.player.cultivation = 500
	var data: Dictionary = gsm.serialize()
	data.player.cultivation = 999
	assert_eq(gsm.player.cultivation, 500, "修改序列化结果不应影响 GSM 内存状态")


func test_ac017_nested_dict_deep_copy() -> void:
	gsm.player.resources.ling_shi = 200
	var data: Dictionary = gsm.serialize()
	data.player.resources.ling_shi = 999
	assert_eq(gsm.player.resources.ling_shi, 200, "修改嵌套字典不应影响 GSM 内存")


func test_ac017_non_battle_state_serialize_battle_absent() -> void:
	## 非战斗状态：battle 为 null，序列化后仍不应包含
	gsm.battle = null
	var data: Dictionary = gsm.serialize()
	assert_false(data.has("battle"))


# ═════════════════════════════════════════════════════════════════════════════
# AC-018：损坏数据反序列化失败——内存状态不变
# ═════════════════════════════════════════════════════════════════════════════

func test_ac018_deserialize_empty_dict_fails() -> void:
	gsm.player.cultivation = 500
	var ok: bool = gsm.deserialize({})
	assert_false(ok, "空字典应拒绝")
	assert_eq(gsm.player.cultivation, 500, "内存状态不变")


func test_ac018_deserialize_non_dict_fails() -> void:
	gsm.player.cultivation = 500
	var ok: bool = gsm.deserialize(123)
	assert_false(ok, "非字典输入应拒绝")


func test_ac018_deserialize_unknown_domain_rejected() -> void:
	gsm.player.cultivation = 500
	var data := {"player": {"cultivation": 100}, "unknown_domain": {}}
	var ok: bool = gsm.deserialize(data)
	assert_false(ok, "含未知域的存档应拒绝")


func test_ac018_deserialize_missing_player_gets_default() -> void:
	## 旧存档仅含 meta → 向前兼容，缺失域填充默认值
	gsm.player.cultivation = 500
	var data := {"meta": {}}
	var ok: bool = gsm.deserialize(data)
	assert_true(ok, "仅含 meta 的旧存档应成功（缺失域填充默认）")
	assert_eq(gsm.player.cultivation, 0, "player 应为默认值")


func test_ac018_deserialize_wrong_type_for_domain_fails() -> void:
	gsm.player.cultivation = 500
	var data := {"player": "not_a_dict"}
	var ok: bool = gsm.deserialize(data)
	assert_false(ok, "域值类型错误应拒绝")


func test_ac018_partial_corruption_fully_rejected() -> void:
	## 部分数据有效、部分损坏 → 整体拒绝
	gsm.player.cultivation = 500
	gsm.player.realm = GSM_SCRIPT.RealmLevel.QI_REFINING
	var data := {
		"player": {"cultivation": 999, "realm": GSM_SCRIPT.RealmLevel.FOUNDATION},
		"meta": {},
		"collection": "corrupted_not_dict",
	}
	var ok: bool = gsm.deserialize(data)
	assert_false(ok, "部分损坏应整体拒绝")
	assert_eq(gsm.player.cultivation, 500, "cultivation 不变")
	assert_eq(gsm.player.realm, GSM_SCRIPT.RealmLevel.QI_REFINING, "realm 不变")


# ═════════════════════════════════════════════════════════════════════════════
# AC-019：旧版本存档向前兼容——缺失字段填充默认值
# ═════════════════════════════════════════════════════════════════════════════

func test_ac019_missing_entire_domain_gets_default() -> void:
	## 旧存档缺少整个 deck 域 → 填充默认值
	var data := {
		"meta": gsm._deep_copy(gsm.meta),
		"player": gsm._deep_copy(gsm.player),
		"collection": gsm._deep_copy(gsm.collection),
		"exploration": gsm._deep_copy(gsm.exploration),
		"narrative": gsm._deep_copy(gsm.narrative),
		# deck 缺失
	}
	var ok: bool = gsm.deserialize(data)
	assert_true(ok, "缺失 deck 域应成功（填充默认）")
	assert_eq(gsm.deck.current_deck.size(), 0, "deck 应为默认值")
	assert_eq(gsm.deck.character_slots.size(), 6)


func test_ac019_missing_field_in_domain_gets_default() -> void:
	## 旧存档 player 中缺少 talents 字段 → 填充默认
	var full_data: Dictionary = gsm.serialize()
	full_data.player.erase("talents")
	var ok: bool = gsm.deserialize(full_data)
	assert_true(ok, "缺失 talents 字段应成功")
	assert_eq(gsm.player.talents.size(), 0, "talents 应为默认空数组")


func test_ac019_type_mismatch_rejected() -> void:
	## 旧存档中字段类型不兼容 → 拒绝
	var full_data: Dictionary = gsm.serialize()
	full_data.player.cultivation = "should_be_int"
	var ok: bool = gsm.deserialize(full_data)
	assert_false(ok, "类型不兼容应拒绝")


# ═════════════════════════════════════════════════════════════════════════════
# Round-trip 往返测试
# ═════════════════════════════════════════════════════════════════════════════

func test_round_trip_player_values_preserved() -> void:
	gsm.player.cultivation = 350
	gsm.player.realm = GSM_SCRIPT.RealmLevel.GOLDEN_CORE
	gsm.player.resources.ling_shi = 200
	gsm.player.identity_id = "test_identity"
	var data: Dictionary = gsm.serialize()
	var ok: bool = gsm.deserialize(data)
	assert_true(ok)
	assert_eq(gsm.player.cultivation, 350)
	assert_eq(gsm.player.realm, GSM_SCRIPT.RealmLevel.GOLDEN_CORE)
	assert_eq(gsm.player.resources.ling_shi, 200)
	assert_eq(gsm.player.identity_id, "test_identity")


func test_round_trip_nested_resources() -> void:
	gsm.player.resources.ling_shi = 100
	gsm.player.resources.ling_cai = 50
	gsm.player.resources.dan_yao_sui_pian = 25
	var data: Dictionary = gsm.serialize()
	var ok: bool = gsm.deserialize(data)
	assert_true(ok)
	assert_eq(gsm.player.resources.ling_shi, 100)
	assert_eq(gsm.player.resources.ling_cai, 50)
	assert_eq(gsm.player.resources.dan_yao_sui_pian, 25)


func test_round_trip_collection_and_deck() -> void:
	gsm.collection.owned_cards = [1, 2, 3]
	gsm.collection.total_count = 3
	gsm.deck.current_deck = [4, 5]
	gsm.deck.character_slots = [null, "char_1", null, null, null, null]
	var data: Dictionary = gsm.serialize()
	var ok: bool = gsm.deserialize(data)
	assert_true(ok)
	assert_eq(gsm.collection.owned_cards, [1, 2, 3])
	assert_eq(gsm.collection.total_count, 3)
	assert_eq(gsm.deck.current_deck, [4, 5])
	assert_eq(gsm.deck.character_slots[1], "char_1")


func test_round_trip_exploration_and_narrative() -> void:
	gsm.exploration.current_map_id = "map_01"
	gsm.exploration.node_position = 7
	gsm.exploration.action_points = 3
	gsm.narrative.current_chapter = "chapter_2"
	gsm.narrative.completed_chapters = ["chapter_1"]
	var data: Dictionary = gsm.serialize()
	var ok: bool = gsm.deserialize(data)
	assert_true(ok)
	assert_eq(gsm.exploration.current_map_id, "map_01")
	assert_eq(gsm.exploration.node_position, 7)
	assert_eq(gsm.exploration.action_points, 3)
	assert_eq(gsm.narrative.current_chapter, "chapter_2")
	assert_eq(gsm.narrative.completed_chapters, ["chapter_1"])


func test_serialize_then_modify_gsm_then_deserialize() -> void:
	## 快照-修改-恢复 场景
	gsm.player.cultivation = 500
	var snapshot: Dictionary = gsm.serialize()

	# 修改 GSM
	gsm.player.cultivation = 800
	gsm.player.resources.ling_shi = 300
	assert_eq(gsm.player.cultivation, 800)

	# 恢复快照
	var ok: bool = gsm.deserialize(snapshot)
	assert_true(ok)
	assert_eq(gsm.player.cultivation, 500)
	assert_eq(gsm.player.resources.ling_shi, 0)
