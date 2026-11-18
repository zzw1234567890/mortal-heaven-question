extends GutTest
## 续战存档里[b]牌面三堆[/b]的形状验收（[code]battle_resume_cards.gd[/code]）。[br]
## [br][b]为什么需要[/b]：牌面进存档是本轮补的断链——不记牌面，读档回来手牌会被
## [code]battle_start[/code] 重洗一遍。这层形状错了的症状是「读档回来手里是别人的牌」，
## 而那要到真机上按一遍才看得见。[br]
## [br][b]覆盖[/b]：[br]
##   1. 折叠：三堆各按原顺序落 [code]{card_instance_id, template_id, level}[/code]；[br]
##   2. [b]三种条目形态都认[/b]（int / Dictionary / [code]CardInstance[/code] 对象）；[br]
##   3. [b]JSON 安全[/b]：折出的条目必须过 [code]SaveLoadSystem._is_json_compatible[/code]
##      ——带对象或 StringName 的载荷会让整份存档被判 [code]VALIDATION_ERROR[/code]；[br]
##   4. 裸 ID 条目从收藏快照补模板与等级；[br]
##   5. 认不出 ID 的条目整个丢掉（不留「点不动的牌」）；[br]
##   6. 「有没有牌面快照」的判据（[method has_state]）与 ID 序列解析。[br]
## [br]来源: ADR-0002 §JSON 容器、ADR-0006 §模板/实例分离、本轮「牌面进存档」。

const CardsScript := preload("res://src/feature/combat/battle_resume_cards.gd")
const SLS := preload("res://src/foundation/save_load_system.gd")

## 三堆的实例 ID（顺序刻意不升序——顺序错了「顺序也一致」这条断言才会红）。
const HAND_IDS: Array[int] = [701, 705]
const DRAW_IDS: Array[int] = [702, 703, 704]
const DISCARD_IDS: Array[int] = [706]


## 一份取数包：三堆 + 收藏快照（写侧 [code]CombatResumeCapture._gather[/code] 的形状）。[br]
## [br][b]三堆混用不同形态[/b]：生产里手牌可能是对象（建卡后）、牌库是裸 ID、
## 弃牌堆是字典——三处一起覆盖，免得只测了最顺手的那一种。
func _state() -> Dictionary:
	return {
		"hand": [_instance(701, &"card_a", 1), _instance(705, &"card_b", 3)],
		"draw_pile": DRAW_IDS.duplicate(),
		"discard_pile": [{"card_instance_id": 706, "template_id": &"card_c", "level": 1}],
		"owned_cards": [
			{"card_instance_id": 702, "template_id": &"card_d", "level": 2},
			{"card_instance_id": 703, "template_id": &"card_e", "level": 1},
			{"card_instance_id": 704, "template_id": &"card_f", "level": 4},
		],
	}


## 一个真实的 [code]CardInstance[/code]（游戏代码里手牌条目的一种生产形态）。
func _instance(p_id: int, p_template: StringName, p_level: int) -> CardInstance:
	var inst: CardInstance = CardInstance.new()
	inst.card_instance_id = p_id
	inst.template_id = p_template
	inst.level = p_level
	return inst


func _pile(p_payload: Dictionary, p_key: String) -> Array:
	return CardsScript.entries_of(p_payload, p_key)


# ═══════════════════════════════════════════════════════════════════════════════
# 折叠
# ═══════════════════════════════════════════════════════════════════════════════

func test_fold_keeps_three_piles_in_order() -> void:
	var cards: Dictionary = CardsScript.fold(_state())
	assert_eq(CardsScript.ids_of({CardsScript.KEY_CARDS: cards}, CardsScript.KEY_HAND),
			HAND_IDS, "手牌顺序应与取数包一致（顺序就是抽牌顺序）")
	assert_eq(CardsScript.ids_of({CardsScript.KEY_CARDS: cards}, CardsScript.KEY_DRAW_PILE),
			DRAW_IDS, "抽牌堆顺序应与取数包一致")
	assert_eq(CardsScript.ids_of({CardsScript.KEY_CARDS: cards}, CardsScript.KEY_DISCARD_PILE),
			DISCARD_IDS, "弃牌堆顺序应与取数包一致")


func test_fold_reads_all_three_entry_forms() -> void:
	## 手牌是对象、牌库是裸 ID、弃牌堆是字典——三种形态都要吃得下。
	var cards: Dictionary = CardsScript.fold(_state())
	assert_eq(int(_pile({CardsScript.KEY_CARDS: cards}, CardsScript.KEY_HAND)[0]
			[CardsScript.KEY_CARD_INSTANCE_ID]), 701, "CardInstance 对象要认得出 ID")
	assert_eq(int(_pile({CardsScript.KEY_CARDS: cards}, CardsScript.KEY_DRAW_PILE)[0]
			[CardsScript.KEY_CARD_INSTANCE_ID]), 702, "裸 int 条目要认得出 ID")
	assert_eq(int(_pile({CardsScript.KEY_CARDS: cards}, CardsScript.KEY_DISCARD_PILE)[0]
			[CardsScript.KEY_CARD_INSTANCE_ID]), 706, "字典条目要认得出 ID")


func test_fold_fills_template_and_level_from_owned_cards() -> void:
	## 裸 ID 条目自己没有模板与等级——收藏快照是它们的来源。
	var cards: Dictionary = CardsScript.fold(_state())
	var draw: Array = _pile({CardsScript.KEY_CARDS: cards}, CardsScript.KEY_DRAW_PILE)
	assert_eq(str(draw[0][CardsScript.KEY_TEMPLATE_ID]), "card_d", "模板应取自收藏快照")
	assert_eq(int(draw[0][CardsScript.KEY_LEVEL]), 2, "等级应取自收藏快照")
	assert_eq(str(draw[2][CardsScript.KEY_TEMPLATE_ID]), "card_f", "末尾条目同样补得上")
	assert_eq(int(draw[2][CardsScript.KEY_LEVEL]), 4, "等级逐条对应（不是第一条的值）")


func test_fold_prefers_entry_own_template_over_owned() -> void:
	## 条目自带的模板是「这张牌自己说的」——收藏快照不一致时以牌面为准。
	var state: Dictionary = _state()
	state["owned_cards"] = [{"card_instance_id": 701, "template_id": &"card_wrong",
			"level": 9}]
	var cards: Dictionary = CardsScript.fold(state)
	var hand: Array = _pile({CardsScript.KEY_CARDS: cards}, CardsScript.KEY_HAND)
	assert_eq(str(hand[0][CardsScript.KEY_TEMPLATE_ID]), "card_a",
			"条目自带的模板优先（不以收藏表覆盖牌面）")
	assert_eq(int(hand[0][CardsScript.KEY_LEVEL]), 1, "条目自带的等级优先")


func test_fold_keeps_string_and_int_shapes() -> void:
	## 模板落 String、等级落 int——往返后逐项相等的前提（StringName 往返会变 String）。
	var cards: Dictionary = CardsScript.fold(_state())
	var entry: Dictionary = _pile({CardsScript.KEY_CARDS: cards}, CardsScript.KEY_HAND)[0]
	assert_eq(typeof(entry[CardsScript.KEY_TEMPLATE_ID]), TYPE_STRING,
			"模板必须是 String（StringName 过不了 JSON 兼容校验）")
	assert_eq(typeof(entry[CardsScript.KEY_CARD_INSTANCE_ID]), TYPE_INT, "实例 ID 必须是 int")
	assert_eq(typeof(entry[CardsScript.KEY_LEVEL]), TYPE_INT, "等级必须是 int")


func test_fold_output_is_json_compatible() -> void:
	## 带对象 / StringName 的载荷会让[b]整份[/b]存档被判 VALIDATION_ERROR
	## （连探索进度一起写不进去）——本轮最贵的一个坑。
	var cards: Dictionary = CardsScript.fold(_state())
	assert_true(SLS._is_json_compatible(cards),
			"折出的三堆必须只含 JSON 兼容类型（对象与 StringName 都要被折叠掉）")


func test_fold_drops_entries_with_unreadable_id() -> void:
	## 留一条 ID 认不出的会变成一张「点不动的牌」——玩家眼里那是游戏坏了。
	var state: Dictionary = _state()
	state["draw_pile"] = [702, {"template_id": &"card_x"}, "not_a_card", 703]
	var cards: Dictionary = CardsScript.fold(state)
	assert_eq(CardsScript.ids_of({CardsScript.KEY_CARDS: cards}, CardsScript.KEY_DRAW_PILE),
			[702, 703], "认不出 ID 的条目整个丢掉（不留占位）")


func test_fold_tolerates_missing_and_malformed_piles() -> void:
	var cards: Dictionary = CardsScript.fold({})
	assert_eq(cards[CardsScript.KEY_HAND], [], "缺席的手牌按空数组（形状确定，读侧不必判）")
	assert_eq(CardsScript.fold({"hand": "not_an_array"})[CardsScript.KEY_HAND], [],
			"非数组一律空——不臆造牌")


# ═══════════════════════════════════════════════════════════════════════════════
# 读侧
# ═══════════════════════════════════════════════════════════════════════════════

func test_ids_of_survives_json_round_trip() -> void:
	## 存档往返把 int 变成 float——ID 解析必须照样读得出（否则读档后牌全没了）。
	var cards: Dictionary = CardsScript.fold(_state())
	var payload: Dictionary = {CardsScript.KEY_CARDS: cards}
	var round_tripped: Variant = JSON.parse_string(JSON.stringify(payload))
	assert_eq(CardsScript.ids_of(round_tripped, CardsScript.KEY_DRAW_PILE), DRAW_IDS,
			"经 JSON 往返后 ID 序列必须原样（元素仍是 int）")


func test_entries_of_is_idempotent() -> void:
	## 同一份内容再折一遍结果不变——往返等价断言靠这条比「同一副牌」。
	var cards: Dictionary = CardsScript.fold(_state())
	var payload: Dictionary = {CardsScript.KEY_CARDS: cards}
	var again: Array = CardsScript.card_entries(
			CardsScript.entries_of(payload, CardsScript.KEY_HAND), [])
	assert_eq(again, CardsScript.entries_of(payload, CardsScript.KEY_HAND),
			"解析口径幂等（再过一遍结果相同）")


func test_has_state_requires_actual_content() -> void:
	## 判据是「有没有内容」而不是「有没有这个键」：v3 老档迁移补出的是空形状，
	## 照它去接管会把刚发的开局手牌清成空手。
	assert_false(CardsScript.has_state({}), "没有这个段 = 没有快照")
	assert_false(CardsScript.has_state({CardsScript.KEY_CARDS: {}}), "空段 = 没有快照")
	assert_false(CardsScript.has_state({CardsScript.KEY_CARDS: {
		CardsScript.KEY_HAND: [], CardsScript.KEY_DRAW_PILE: [],
		CardsScript.KEY_DISCARD_PILE: []}}), "三个空堆 = 没有快照")
	assert_true(CardsScript.has_state({CardsScript.KEY_CARDS: {
		CardsScript.KEY_HAND: [{CardsScript.KEY_CARD_INSTANCE_ID: 1}]}}),
			"任意一堆有牌即为有快照")


func test_is_upgraded_reads_level_above_one() -> void:
	assert_true(CardsScript.is_upgraded({CardsScript.KEY_LEVEL: 2}), "2 级即已升级")
	assert_false(CardsScript.is_upgraded({CardsScript.KEY_LEVEL: 1}), "1 级未升级")
	assert_false(CardsScript.is_upgraded({}), "等级未知按未升级处理（不臆造）")
	assert_false(CardsScript.is_upgraded({CardsScript.KEY_LEVEL: 0}),
			"0 = 未知（不是 1 级，也不是已升级）")


func test_card_id_of_reads_legacy_instance_id_alias() -> void:
	## [code]instance_id[/code] 是牌库侧的历史别名——漏读会让那批条目整堆丢掉。
	assert_eq(CardsScript.card_id_of({"instance_id": 88}), 88, "历史别名同样认")
	assert_eq(CardsScript.card_id_of(123), 123, "裸 int 直接就是 ID")
	assert_eq(CardsScript.card_id_of(123.0), 123, "JSON 往返后的 float 也认")
	assert_eq(CardsScript.card_id_of("nope"), CardsScript.NO_ID, "认不出给哨兵值")


func test_fold_is_stable_across_repeated_calls() -> void:
	## 同一份取数包折两次结果逐项相同——「存前与读后相等」这条断言的前提。
	var state: Dictionary = _state()
	assert_eq(CardsScript.fold(state), CardsScript.fold(state),
			"折叠应是确定映射（键序不随机）")
