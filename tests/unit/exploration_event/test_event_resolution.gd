extends GutTest
## 事件结算验收——ExplorationEventSystem.resolve_option 的真实落库。
##
## 走真实 Autoload（GameStateManager / ResourceSystem / CultivationSystem /
## CardSystem），断言状态变化而不是调用次数：灵石余量、修为、收藏数、角色 HP。
## 另测区间掷骰的确定性、0 数额跳过、未知事件与越界、缺依赖时的降级文案。

const EventSystemScript := preload("res://src/feature/exploration_event_system.gd")

const KIND_LING_SHI: int = 0
const KIND_CULTIVATION: int = 1
const KIND_HP: int = 2
const KIND_CARD: int = 3
const TEST_CHARACTER_ID: int = 9901
const CARD_ID: String = "pei_yuan_dan"

var _system: RefCounted = null
var _gsm: Node = null


func before_each() -> void:
	_system = EventSystemScript.new()
	_system.call(&"load_events")
	_gsm = get_node_or_null(NodePath("/root/GameStateManager"))


func _deps() -> Dictionary:
	return {
		"gsm": _gsm,
		"resource_system": get_node_or_null(NodePath("/root/ResourceSystem")),
		"cultivation_system": get_node_or_null(NodePath("/root/CultivationSystem")),
		"card_system": get_node_or_null(NodePath("/root/CardSystem")),
	}


# === 基础 =====================================================================

func test_autoloads_are_available() -> void:
	assert_not_null(_gsm, "GameStateManager 应存在")
	assert_not_null(get_node_or_null(NodePath("/root/ResourceSystem")))
	assert_not_null(get_node_or_null(NodePath("/root/CardSystem")))


func test_unknown_event_fails_gracefully() -> void:
	var result: Dictionary = _system.call(&"resolve_option", "no_such_event", 0, _deps())
	assert_false(bool(result.get("ok")))
	assert_string_contains(str(result.get("result_text")), "事件不存在")


func test_option_index_out_of_range_fails() -> void:
	var event_id: String = _first_event_id()
	var result: Dictionary = _system.call(&"resolve_option", event_id, 99, _deps())
	assert_false(bool(result.get("ok")))
	assert_string_contains(str(result.get("result_text")), "越界")


# === 真实事件：每条选项都能结算不报错 ==========================================

func test_every_option_resolves_without_error() -> void:
	var ids: Array = _system.call(&"event_ids")
	assert_gt(ids.size(), 0)
	for raw: Variant in ids:
		var event_id: String = str(raw)
		var def: Variant = _system.call(&"get_event", event_id)
		var options: Array = def.get(&"options")
		for i in range(options.size()):
			var result: Dictionary = _system.call(&"resolve_option",
					event_id, i, _deps())
			assert_true(bool(result.get("ok")),
					"选项应能结算：%s#%d" % [event_id, i])
			assert_false(str(result.get("result_text")).is_empty(),
					"应带回结果文案：%s#%d" % [event_id, i])


# === 四类效果（用临时事件资源，落在内存里） ====================================

func test_ling_shi_effect_increases_resource() -> void:
	var before: int = _read_ling_shi()
	var result: Dictionary = _resolve(tmp_event([_effect(KIND_LING_SHI, 12)]))
	assert_true(bool(result.get("ok")))
	assert_eq(_read_ling_shi(), before + 12, "灵石应 +12")
	assert_string_contains(str(result.get("lines")), "灵石 +12")


func test_cultivation_effect_increases_cultivation() -> void:
	var before: int = _read_cultivation()
	var result: Dictionary = _resolve(tmp_event([_effect(KIND_CULTIVATION, 5)]))
	assert_true(bool(result.get("ok")))
	assert_eq(_read_cultivation(), before + 5, "修为应 +5")
	assert_string_contains(str(result.get("lines")), "修为 +5")


func test_card_effect_grants_to_collection() -> void:
	# CardSystem 的模板是 _process 里异步装载的——等几帧再断言。
	for _i in range(5):
		await get_tree().process_frame
	_ensure_card_validation()
	var before: int = _collection_count()
	var result: Dictionary = _resolve(
			tmp_event([_effect(KIND_CARD, 0, CARD_ID)]))
	assert_true(bool(result.get("ok")))
	assert_false((result.get("lines") as Array).is_empty(),
			"卡片效果应产生一条明细")
	assert_false(str((result.get("lines") as Array)[0]).contains("未能发放"),
			"模板应可解析：%s" % str(result.get("lines")))
	assert_eq(_collection_count(), before + 1, "收藏应多一张卡")
	assert_string_contains(str(result.get("lines")), "获得卡牌")


## 卡片入库要求 GSM 校验开启且模板在库里——别的用例可能先开启了窄库，
## 这里补齐本用例需要的模板，避免测试顺序影响结果。
func _ensure_card_validation() -> void:
	var card_system: Node = get_node_or_null(NodePath("/root/CardSystem"))
	if card_system == null:
		return
	var template: Variant = card_system.call(&"get_template", StringName(CARD_ID))
	if template == null:
		return
	var db: Dictionary = _gsm.get(&"_card_template_database")
	db[CARD_ID] = template
	if not bool(_gsm.get(&"validation_enabled")):
		_gsm.call(&"enable_validation", db)


func test_hp_effect_clamps_damage_at_zero() -> void:
	_seed_hp(TEST_CHARACTER_ID, 10, 30)
	var result: Dictionary = _resolve(
			tmp_event([_effect(KIND_HP, -9999, "", TEST_CHARACTER_ID)]))
	assert_true(bool(result.get("ok")))
	assert_eq(_read_hp(TEST_CHARACTER_ID), 0, "伤害不应把 HP 打到负数")


func test_hp_effect_heals_up_to_max() -> void:
	_seed_hp(TEST_CHARACTER_ID, 10, 30)
	_resolve(tmp_event([_effect(KIND_HP, 999, "", TEST_CHARACTER_ID)]))
	assert_eq(_read_hp(TEST_CHARACTER_ID), 30, "回复不应超过上限")


# === 掷骰 =====================================================================

func test_range_effect_is_deterministic_with_seeded_rng() -> void:
	var event: Dictionary = tmp_event([_effect(KIND_LING_SHI, 0, "", 0, [5, 9])])
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 20261112
	var before: int = _read_ling_shi()
	_resolve(event, rng_a)
	var delta_a: int = _read_ling_shi() - before
	assert_between(delta_a, 5, 9, "区间掷骰应落在 [5, 9]")
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 20261112
	var before_b: int = _read_ling_shi()
	_resolve(event, rng_b)
	assert_eq(_read_ling_shi() - before_b, delta_a, "同种子应得同结果")


func test_range_effect_without_rng_uses_midpoint() -> void:
	var before: int = _read_ling_shi()
	_resolve(tmp_event([_effect(KIND_LING_SHI, 0, "", 0, [4, 10])]), null)
	assert_eq(_read_ling_shi() - before, 7, "无 rng 时取区间中值")


# === 降级 =====================================================================

func test_missing_resource_system_reports_not_granted() -> void:
	var deps: Dictionary = _deps()
	deps["resource_system"] = null
	var result: Dictionary = _system.call(&"resolve_option",
			_register(tmp_event([_effect(KIND_LING_SHI, 3)])), 0, deps)
	assert_string_contains(str(result.get("lines")), "未能发放")


func test_zero_amount_effect_produces_no_line() -> void:
	var result: Dictionary = _resolve(tmp_event([_effect(KIND_LING_SHI, 0)]))
	assert_eq(int(result.get("applied")), 0, "0 数额不应产生明细")
	assert_eq((result.get("lines") as Array).size(), 0)


# === 辅助 =====================================================================

var _tmp_counter: int = 0


## 造一个单选项临时事件并写入注册表（结算只认注册表里的 id）。
func tmp_event(p_effects: Array) -> Dictionary:
	var option := EventDefOption.new()
	option.text = "试试"
	option.result_text = "结果文案"
	option.effects = p_effects
	var def := EventDef.new()
	_tmp_counter += 1
	def.event_id = "tmp_event_%d" % _tmp_counter
	def.title = "临时事件"
	def.body = "临时正文"
	def.options = [option]
	_register({"def": def, "option": option})
	return {"def": def, "option": option}


func _register(p_built: Dictionary) -> String:
	var def: EventDef = p_built["def"]
	var table: Dictionary = _system.get(&"_registry")
	table[def.event_id] = def
	return def.event_id


func _resolve(p_built: Dictionary, p_rng: RandomNumberGenerator = null) -> Dictionary:
	var event_id: String = _register(p_built)
	return _system.call(&"resolve_option", event_id, 0, _deps(), p_rng)


func _effect(p_kind: int, p_amount: int, p_card_id: String = "",
		p_character_id: int = 0, p_range: Array = []) -> EventDefEffect:
	var effect := EventDefEffect.new()
	effect.kind = p_kind
	effect.amount = p_amount
	effect.card_id = p_card_id
	effect.character_id = p_character_id
	if p_range.size() == 2:
		effect.use_range = true
		effect.min_amount = int(p_range[0])
		effect.max_amount = int(p_range[1])
	return effect


func _first_event_id() -> String:
	var ids: Array = _system.call(&"event_ids")
	ids.sort()
	return String(ids[0]) if not ids.is_empty() else ""


func _read_ling_shi() -> int:
	return int(_gsm.call(&"get_state", "player.resources.ling_shi"))


func _read_cultivation() -> int:
	return int(_gsm.call(&"get_state", "player.cultivation"))


func _collection_count() -> int:
	var owned: Variant = _gsm.call(&"get_state", "collection.owned_cards")
	return (owned as Array).size() if owned is Array else 0


func _seed_hp(p_character_id: int, p_current: int, p_max: int) -> void:
	_gsm.call(&"_set_player_character_hp", p_character_id,
			{"current_hp": p_current, "max_hp": p_max})


func _read_hp(p_character_id: int) -> int:
	var table: Variant = _gsm.call(&"get_state", "player.character_hp")
	if not (table is Dictionary):
		return -1
	var hp_table: Dictionary = table
	# GSM 写入口统一用字符串键（str(character_id)）。
	var entry: Variant = hp_table.get(str(p_character_id))
	if entry == null:
		entry = hp_table.get(p_character_id)
	if not (entry is Dictionary):
		return -1
	return int((entry as Dictionary).get("current_hp", -1))
