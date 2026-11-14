extends GutTest
## 炼丹台/炼器台结算 —— 扣料入库、拒绝不改状态、重复炼制计数、配方清单一致性。[br]
## [br][b]覆盖[/b]：[br]
##   · 炼成后灵材[b]真的扣掉[/b]、产出的卡[b]真的进收藏[/b]（经
##     [code]AlchemySystem.craft_pill[/code] → [code]CardSystem.create_instance[/code]
##     → [code]GameStateManager.add_card_to_collection[/code] 这条既有通路，
##     与商店/战斗奖励同一本账）；[br]
##   · 灵材不足 / 收藏已满 / 行号越界 / 境界不足的拒绝路径都[b]不改任何状态[/b]；[br]
##   · 连续炼制两次计数正确（收藏 +2、灵材按两次扣）；[br]
##   · 可炼清单与 [code]AlchemyRecipes[/code] 这份配方资源逐条一致（不硬编码配方）。[br]
## [br][b]装置[/b]：真实 GSM + 真实 ResourceSystem + 真实 CardSystem（Autoload），
## 卡牌模板经 [CardTemplatePrimer] 同步就位；用例前后快照还原 player / collection /
## deck 与校验库（同 [code]shop_rest_node_fixture[/code] 口径）。[br]
## [br]公式侧（品质掷骰）见 [code]test_quality_and_stats.gd[/code]；
## 端到端（面板点击）见 [code]test_craft_node_flow.gd[/code]。
##
## 来源: design/gdd/alchemy-crafting-system.md §1a/§2a/§4/§边界/AC-1/AC-13、
## ADR-0028 §craft_pill、ADR-0019 §关键接口。

const CraftScript := preload("res://src/feature/exploration/exploration_craft.gd")
const ListScript := preload("res://src/feature/exploration/exploration_craft_list.gd")
const RecipeScript := preload("res://src/feature/alchemy/alchemy_recipes.gd")
const ES_SCRIPT := preload("res://src/feature/exploration_system.gd")
## 卡牌模板就位助手（异步加载的同步推进——与商店/采集用例共用）。
const PrimerScript := preload("res://tests/integration/exploration_ui/card_template_primer.gd")

## 炼气期（炼制等级 0）就能炼的两道配方——炼丹与炼器各一。
const PILL_ID: String = "hui_chun_dan"
const PILL_TEMPLATE: String = "pill_hui_chun_dan"
const PILL_LOW_COST: int = 2
const ARTIFACT_ID: String = "ji_chu_fa_qi"
const ARTIFACT_TEMPLATE: String = "artifact_ji_chu_fa_qi"
const ARTIFACT_LOW_COST: int = 3
## 筑基期才解锁的配方（用于「境界不足」的禁用断言）。
const LOCKED_PILL_ID: String = "yu_ling_dan"

## 配方资源里的全部模板 ID（GSM 校验库需要它们才让写入）。
const ALL_TEMPLATES: Array = [
	"pill_hui_chun_dan", "pill_yu_ling_dan", "pill_tian_luo_dan",
	"pill_jiu_zhuan_jin_dan", "artifact_ji_chu_fa_qi", "artifact_zhong_pin_fa_qi",
	"artifact_shang_pin_fa_qi", "artifact_tong_tian_ling_bao",
]

var es: Node = null
var service: RefCounted = null
var _player_before: Dictionary = {}
var _collection_before: Dictionary = {}
var _deck_before: Dictionary = {}
var _db_before: Dictionary = {}
var _validation_before: bool = false
var _next_id_before: int = 1


func before_each() -> void:
	_player_before = (GameStateManager.player as Dictionary).duplicate(true)
	_collection_before = (GameStateManager.collection as Dictionary).duplicate(true)
	_deck_before = (GameStateManager.deck as Dictionary).duplicate(true)
	_db_before = (GameStateManager.get("_card_template_database") as Dictionary).duplicate(true)
	_validation_before = bool(GameStateManager.validation_enabled)
	_next_id_before = int(GameStateManager.get("_next_card_instance_id"))
	_prepare_card_validation()
	GameStateManager.player.realm = 1  # 炼气期 → 炼制等级 0
	_set_materials({1: 0, 2: 0, 3: 0, 4: 0})
	GameStateManager.collection.owned_cards = []
	GameStateManager.collection.total_count = 0
	es = ES_SCRIPT.new()
	service = CraftScript.new(es)


func after_each() -> void:
	service = null
	GameStateManager.player = _player_before
	GameStateManager.collection = _collection_before
	GameStateManager.deck = _deck_before
	GameStateManager.set("_card_template_database", _db_before)
	GameStateManager.validation_enabled = _validation_before
	GameStateManager.set("_next_card_instance_id", _next_id_before)
	if es != null:
		es.free()
		es = null


# ═══════════════════════════════════════════════════════════════════════════════
# 炼成（扣料 + 入库）
# ═══════════════════════════════════════════════════════════════════════════════

func test_craft_pill_deducts_materials_and_stores_card() -> void:
	# Arrange——够炼一次回春丹（下品 ×2）
	_set_materials({1: 5})
	# Act
	var result: Dictionary = service.call(&"craft", ListScript.KIND_ALCHEMY,
			_first_index(ListScript.KIND_ALCHEMY))
	# Assert——灵材真的少了两份，产物真的进了收藏
	assert_true(bool(result.get("success")), "材料充足时应炼成")
	assert_eq(str(result.get("recipe_id")), PILL_ID, "炼的应是清单首条配方")
	assert_eq(_low(), 5 - PILL_LOW_COST, "应扣掉配方要求的 %d 份下品灵材" % PILL_LOW_COST)
	assert_eq(_collection_count(), 1, "产出的丹药应入收藏")
	assert_eq(_last_owned_template(), PILL_TEMPLATE, "入收藏的应是配方对应的模板")
	assert_true(str(result.get("message")).begins_with("炼成"), "提示应为中文炼成文案")


func test_craft_artifact_deducts_materials_and_stores_card() -> void:
	# Arrange——够炼一次基础法器（下品 ×3）
	_set_materials({1: 4})
	# Act
	var result: Dictionary = service.call(&"craft", ListScript.KIND_FORGE,
			_index_of(ListScript.KIND_FORGE, ARTIFACT_ID))
	# Assert
	assert_true(bool(result.get("success")), "炼器台也应能炼出基础法器")
	assert_eq(_low(), 4 - ARTIFACT_LOW_COST, "应扣掉炼器配方要求的下品灵材")
	assert_eq(_last_owned_template(), ARTIFACT_TEMPLATE, "产出的法宝应入收藏")


func test_craft_twice_keeps_counts_correct() -> void:
	# Arrange——够炼两次（下品 ×4）
	_set_materials({1: 4})
	var idx: int = _first_index(ListScript.KIND_ALCHEMY)
	# Act——连炼两次
	var first: Dictionary = service.call(&"craft", ListScript.KIND_ALCHEMY, idx)
	var second: Dictionary = service.call(&"craft", ListScript.KIND_ALCHEMY, idx)
	# Assert——两次都成，收藏 +2，灵材按两次扣（不是一次）
	assert_true(bool(first.get("success")) and bool(second.get("success")),
			"材料够时应能连炼两次")
	assert_eq(_collection_count(), 2, "两次炼制应产出两张卡")
	assert_eq(_low(), 4 - PILL_LOW_COST * 2, "灵材应按两次扣减")
	assert_ne(int(first.get("card_instance_id")), int(second.get("card_instance_id")),
			"两次炼制应是两个不同的卡牌实例")


# ═══════════════════════════════════════════════════════════════════════════════
# 拒绝路径（全部不改状态）
# ═══════════════════════════════════════════════════════════════════════════════

func test_craft_insufficient_materials_rejected_without_state_change() -> void:
	# Arrange——只有 1 份下品（回春丹要 2）
	_set_materials({1: 1})
	# Act
	var result: Dictionary = service.call(&"craft", ListScript.KIND_ALCHEMY,
			_first_index(ListScript.KIND_ALCHEMY))
	# Assert——拒绝且灵材与收藏都不动
	assert_false(bool(result.get("success")), "灵材不足时应拒绝")
	assert_eq(_low(), 1, "被拒的炼制不得扣灵材")
	assert_eq(_collection_count(), 0, "被拒的炼制不得产出卡")
	assert_true(str(result.get("message")).contains("灵材不足"),
			"提示应为中文「灵材不足」并带上缺口")


func test_craft_collection_full_rejected_without_state_change() -> void:
	# Arrange——灵材够，但收藏池已满
	_set_materials({1: 5})
	GameStateManager.collection.total_count = CraftScript.COLLECTION_CAP
	# Act
	var result: Dictionary = service.call(&"craft", ListScript.KIND_ALCHEMY,
			_first_index(ListScript.KIND_ALCHEMY))
	# Assert
	assert_false(bool(result.get("success")), "收藏已满时应拒绝")
	assert_eq(str(result.get("message")), ListScript.TEXT_FULL, "提示应为「收藏已满」")
	assert_eq(_low(), 5, "被拒的炼制不得扣灵材")
	assert_eq(_collection_count(), CraftScript.COLLECTION_CAP, "收藏张数不得变化")


func test_craft_out_of_range_index_rejected_without_state_change() -> void:
	_set_materials({1: 5})
	# Act——行号越界
	var result: Dictionary = service.call(&"craft", ListScript.KIND_ALCHEMY, 99)
	# Assert
	assert_false(bool(result.get("success")), "越界行号应被拒")
	assert_eq(_low(), 5, "越界行号不得扣灵材")
	assert_eq(_collection_count(), 0, "越界行号不得产出卡")


func test_locked_recipe_is_disabled_with_realm_reason() -> void:
	# Arrange——炼气期（等级 0），玉灵丹要筑基（解锁等级 1）
	_set_materials({1: 9, 2: 9})
	var entries: Array = service.call(&"entries", ListScript.KIND_ALCHEMY)
	# Act
	var row: Dictionary = _entry_of(entries, LOCKED_PILL_ID)
	# Assert——禁用 + 中文原因指向所需境界
	assert_false(bool(row.get("enabled")), "境界不足的配方应禁用")
	assert_true(str(row.get("reason")).contains("筑基"),
			"禁用原因应写明所需境界（实得「%s」）" % str(row.get("reason")))
	# 且直接调结算层也被拒
	var result: Dictionary = service.call(&"craft", ListScript.KIND_ALCHEMY,
			int(row.get("index")))
	assert_false(bool(result.get("success")), "结算层也不得放行未解锁配方")
	assert_eq(_low(), 9, "被拒的炼制不得扣灵材")


# ═══════════════════════════════════════════════════════════════════════════════
# 配方清单 ↔ 配方资源一致性（不硬编码配方）
# ═══════════════════════════════════════════════════════════════════════════════

func test_entries_match_recipe_resources() -> void:
	_set_materials({1: 9, 2: 9, 3: 9, 4: 9})
	for kind: StringName in [ListScript.KIND_ALCHEMY, ListScript.KIND_FORGE]:
		var entries: Array = service.call(&"entries", kind)
		var recipes: Array = ListScript.recipes_of(kind)
		assert_eq(entries.size(), recipes.size(),
				"%s 清单条数应等于配方资源条数" % kind)
		for i: int in recipes.size():
			var recipe: Dictionary = recipes[i]
			var row: Dictionary = entries[i]
			assert_eq(str(row.get("recipe_id")), str(recipe.get("recipe_id")),
					"行序应与配方表一致")
			assert_eq(str(row.get("name")), str(recipe.get("name")), "名称应取自配方资源")
			assert_eq(int(row.get("rarity")), int(recipe.get("rarity")), "稀有度应取自配方资源")
			assert_eq((row.get("costs") as Array).size(),
					(recipe.get("materials") as Dictionary).size(),
					"每档材料需求应逐条对应配方资源")


func test_entries_carry_held_counts_from_resource_system() -> void:
	# Arrange——下品 7，其它为 0
	_set_materials({1: 7})
	var entries: Array = service.call(&"entries", ListScript.KIND_ALCHEMY)
	var row: Dictionary = _entry_of(entries, PILL_ID)
	# Assert——行里的「持 N」来自真实持有量，不是配方表的静态值
	var first: Dictionary = (row.get("costs") as Array)[0]
	assert_eq(int(first.get("need")), PILL_LOW_COST, "所需数量取自配方资源")
	assert_eq(int(first.get("held")), 7, "持有数量取自 ResourceSystem 实况")
	assert_true(str(row.get("cost_text")).contains("持 7"), "行文案应把持有量写出来")


func test_unknown_kind_yields_no_recipes() -> void:
	_set_materials({1: 9})
	assert_eq((service.call(&"entries", &"nope") as Array).size(), 0,
			"未知种类不得臆造配方")
	assert_eq((ListScript.recipes_of(&"nope") as Array).size(), 0,
			"配方资源查询对未知种类返回空")


# ═══════════════════════════════════════════════════════════════════════════════
# 装置
# ═══════════════════════════════════════════════════════════════════════════════

## 备好卡牌校验——真实模板注册表 + GSM 校验开启（同 [code]test_battle_reward_grant[/code] 口径）。
func _prepare_card_validation() -> void:
	PrimerScript.prime(CardSystem, StringName(PILL_TEMPLATE))
	var database: Dictionary = GameStateManager.get("_card_template_database")
	for tid: String in ALL_TEMPLATES:
		database[tid] = database.get(tid, {})
	GameStateManager.set("_card_template_database", database)
	GameStateManager.validation_enabled = true


## 各品质档位的灵材持有量（按 GSM 的 key 名写入——与 ResourceSystem 同一本账）。
func _set_materials(p_counts: Dictionary) -> void:
	GameStateManager.player.resources.ling_cai = {
		"low": int(p_counts.get(1, 0)),
		"medium": int(p_counts.get(2, 0)),
		"high": int(p_counts.get(3, 0)),
		"top": int(p_counts.get(4, 0)),
	}


## 某配方在清单里的行号（不假设配方表顺序）。
func _index_of(p_kind: StringName, p_recipe_id: String) -> int:
	var entries: Array = service.call(&"entries", p_kind)
	for raw: Variant in entries:
		if str((raw as Dictionary).get("recipe_id")) == p_recipe_id:
			return int((raw as Dictionary).get("index"))
	return -1


## 清单首行行号。
func _first_index(p_kind: StringName) -> int:
	var entries: Array = service.call(&"entries", p_kind)
	return int((entries[0] as Dictionary).get("index")) if not entries.is_empty() else -1


## 按 recipe_id 取清单条目（找不到时失败并返回空字典）。
func _entry_of(p_entries: Array, p_recipe_id: String) -> Dictionary:
	for raw: Variant in p_entries:
		if str((raw as Dictionary).get("recipe_id")) == p_recipe_id:
			return raw
	fail_test("清单里没有配方 %s" % p_recipe_id)
	return {}


func _low() -> int:
	return int(ResourceSystem.get_resource(&"ling_cai", 1))


func _collection_count() -> int:
	return int(GameStateManager.collection.total_count)


## 收藏里最后一张卡的模板 ID（空串 = 收藏为空）。
func _last_owned_template() -> String:
	var owned: Array = GameStateManager.collection.owned_cards
	if owned.is_empty():
		return ""
	return str((owned[owned.size() - 1] as Dictionary).get("template_id", ""))
