extends "res://tests/integration/inventory_ui/inventory_screens_fixture.gd"
## 回气丹（回复行动力丹药）的出厂模板 ↔ 配方 ↔ 服用 端到端。[br]
## [br][b]本文件补的断链[/b]：AP 丹药此前[b]只有 fixture 造得出来[/b]
## （[code]inventory_pill_use_fixture.add_pill(..., restore_ap)[/code]）——生产路径上
## 既没有一枚带 [code]restore_ap[/code] 的卡牌模板，也没有一条能炼出它的配方，
## 于是「玩家在探索中使用回复丹药」这条 GDD §3 的规则在真实存档里永远走不到。
## 本轮补上真实 [code].tres[/code] + 真实配方后，本文件走「炼出来 → 放进行囊 →
## 吃下去 → 行动力真的涨了」的完整链路。[br]
## [br][b]覆盖[/b]：[br]
##   1. 出厂模板口径——真实目录加载的 [code]pill_hui_qi_dan[/code] 就是 AP 类
##      （[code]restore_ap[/code] / 数值 2），配方 [code]hui_qi_dan[/code] 指向它且
##      字段符合 GDD；[br]
##   2. 炼得出来——丹炉节点真的把回气丹炼进收藏（扣料 + 入库）；[br]
##   3. 吃得到——背包里确认那枚丹，行动力真的涨（GSM 探索域），行囊少一枚；[br]
##   4. 已满不吃——行动力满时给 GDD 验收文案「行动力已满」且不消耗丹药。[br]
## [br][b]装置见 [inventory_screens_fixture.gd][/b]；炼制走真实
## [code]ExplorationCraft[/code]（与 [code]test_exploration_craft.gd[/code] 同一入口）。
## 探索域（行动力所在）由本文件自己快照还原。[br]
##
## 来源: design/gdd/action-point-system.md §3/§验收标准、本轮任务书第 1 条、
## 先例 [code]tests/integration/inventory_ui/test_inventory_item_use_flow.gd[/code]。

const CraftScript := preload("res://src/feature/exploration/exploration_craft.gd")
const ListScript := preload("res://src/feature/exploration/exploration_craft_list.gd")
const ApScript := preload("res://src/feature/inventory/inventory_pill_ap.gd")
const ES_SCRIPT := preload("res://src/feature/exploration_system.gd")

## 丹药分类下标（[code]InventoryCatalog.CATEGORIES[/code]：灵材 0 / 丹药 1 / 法宝 2）。
const CATEGORY_PILL: int = 1

## 出厂回气丹的身份（模板 ID / 配方 ID / GDD §调优参数的默认回复量）。
const AP_TEMPLATE: StringName = &"pill_hui_qi_dan"
const AP_RECIPE: String = "hui_qi_dan"
const AP_AMOUNT: int = 2
## 配方材料消耗（低级灵材 ×2）与解锁等级（炼气期即可炼）。
const AP_LOW_COST: int = 2
const AP_UNLOCK_LEVEL: int = 0

var es: Node = null
var craft: RefCounted = null
var _exploration_before: Dictionary = {}


func before_each() -> void:
	super.before_each()
	_exploration_before = (GameStateManager.exploration as Dictionary).duplicate(true)
	GameStateManager.call(&"set_exploration_ap", 0, 0)
	# 新模板要进校验库，否则炼制产出入不了收藏（GSM 按 template_id 校验）。
	assert_true(prime_templates([AP_TEMPLATE]),
			"出厂模板 %s 应能被真实 CardSystem 加载（资产/路径问题会在此暴露）" % AP_TEMPLATE)
	var database: Dictionary = GameStateManager.get("_card_template_database")
	database[str(AP_TEMPLATE)] = database.get(str(AP_TEMPLATE), {})
	GameStateManager.set("_card_template_database", database)
	es = ES_SCRIPT.new()
	craft = CraftScript.new(es)


func after_each() -> void:
	craft = null
	if es != null:
		es.free()
		es = null
	GameStateManager.exploration = _exploration_before
	super.after_each()


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 出厂口径：模板真的是 AP 类，配方指向它
# ═══════════════════════════════════════════════════════════════════════════════

func test_production_template_is_an_ap_pill() -> void:
	## 「生产上有出厂模板」这句话的证据：真实目录加载出来的这枚丹被 AP 读取侧认作
	## 回复行动力类，且数值逐字取自模板（读取侧不认识「回气丹是 2 点」）。
	# Act
	var template: Variant = CardSystem.get_template(AP_TEMPLATE)
	# Assert
	assert_not_null(template, "真实模板目录里应能查到 %s" % AP_TEMPLATE)
	assert_eq(str(template.get("name")), "回气丹", "模板名应为回气丹")
	assert_true(ApScript.is_ap_effect(str(template.get("effect_type"))),
			"效果类型 '%s' 应被判为回复行动力类" % str(template.get("effect_type")))
	assert_eq(ApScript.amount_of(template), AP_AMOUNT,
			"AP 回复量应逐字取自模板（%d）" % AP_AMOUNT)


func test_recipe_points_at_the_production_template_and_matches_gdd() -> void:
	## 配方与模板必须成对出现——配方 [code]template_id[/code] 指向一枚[b]查得到[/b]
	## 的模板，否则炼制会在扣料之后建不出卡。
	# Act
	var recipe: Dictionary = ListScript.recipe_of(ListScript.KIND_ALCHEMY, AP_RECIPE)
	# Assert
	assert_false(recipe.is_empty(), "配方表里应有 %s" % AP_RECIPE)
	assert_eq(str(recipe.get("name")), "回气丹")
	assert_eq(str(recipe.get("template_id")), str(AP_TEMPLATE), "配方应指向出厂模板")
	assert_eq(int(recipe.get("base_effect")), AP_AMOUNT,
			"配方基础效果应与模板数值一致（GDD §调优参数 丹药回复量 +2）")
	assert_eq(int(recipe.get("unlock_level")), AP_UNLOCK_LEVEL, "炼气期即可炼")
	assert_eq(int((recipe.get("materials") as Dictionary).get(1, 0)), AP_LOW_COST,
			"应消耗 %d 份低级灵材" % AP_LOW_COST)
	assert_not_null(CardSystem.get_template(AP_TEMPLATE),
			"配方指向的模板必须真的存在（否则炼制必然在扣料后失败）")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 炼得出来（丹炉节点 → 收藏）
# ═══════════════════════════════════════════════════════════════════════════════

func test_can_craft_ap_pill_at_alchemy_node() -> void:
	# Arrange——够炼一次（低级灵材 ×2）
	give_ling_cai(3, 0, 0, 0)
	# Act——炼制回气丹那道配方（行号现查，不假设配方表顺序）
	var result: Dictionary = craft.call(&"craft", ListScript.KIND_ALCHEMY,
			_ap_recipe_index())
	# Assert——灵材真的少了、丹药真的进了收藏
	assert_true(bool(result.get("success")), "材料充足时应炼成：%s" % str(result.get("message")))
	assert_eq(str(result.get("recipe_id")), AP_RECIPE, "炼的应是回气丹")
	assert_eq(low_cai(), 3 - AP_LOW_COST, "应扣掉 %d 份低级灵材" % AP_LOW_COST)
	assert_eq(_owned_count(AP_TEMPLATE), 1, "产出的回气丹应入收藏")
	assert_eq(last_owned_template(), str(AP_TEMPLATE), "入收藏的应是回气丹模板")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 吃得到（背包确认 → 行动力真的涨）
# ═══════════════════════════════════════════════════════════════════════════════

func test_crafted_ap_pill_restores_action_points_from_inventory() -> void:
	## 端到端：炼一枚 → 背包里确认它 → 行动力按模板数值上涨、行囊少一枚。
	# Arrange——炼一枚出来，行动力 2/5
	give_ling_cai(2, 0, 0, 0)
	craft.call(&"craft", ListScript.KIND_ALCHEMY, _ap_recipe_index())
	assert_eq(_owned_count(AP_TEMPLATE), 1, "前置：应已炼出一枚回气丹")
	GameStateManager.call(&"set_exploration_ap", 2, 5)
	# Act——打开背包，切到丹药分类，确认那一行
	open_page(0)
	inventory_page().call(&"press_category")
	assert_eq(int(inventory_page().call(&"entry_count")), 1, "前置：应有一行回气丹")
	inventory_page().call(&"press_row", 0)
	# Assert——存档侧（界面文案只是表象）
	assert_eq(_ap(), 2 + AP_AMOUNT, "行动力应从 2 涨到 %d" % (2 + AP_AMOUNT))
	assert_eq(_owned_count(AP_TEMPLATE), 0, "服下的那枚应从收藏移除")
	assert_eq(int(inventory_page().call(&"entry_count")), 0, "用完后该行应消失")
	assert_true(str(inventory_page().call(&"message_text")).contains("行动力"),
			"提示应说明回的是行动力：%s" % str(inventory_page().call(&"message_text")))


func test_ap_pill_clamps_to_max_and_consumes_the_pill() -> void:
	## 差 1 点却吃 +2 的丹：只回 1 点（不溢出上限），丹药照常消耗。
	# Arrange
	give_card(AP_TEMPLATE)
	GameStateManager.call(&"set_exploration_ap", 4, 5)
	# Act
	open_page(0)
	inventory_page().call(&"press_category")
	inventory_page().call(&"press_row", 0)
	# Assert
	assert_eq(_ap(), 5, "回复量应夹到上限（4 + 2 → 5）")
	assert_eq(_owned_count(AP_TEMPLATE), 0, "夹取不改变「已服下」这一事实")


func test_ap_pill_at_full_action_points_is_refused_without_consuming() -> void:
	## 行动力已满：按 GDD §验收「提示"行动力已满"」，且[b]不白吃玩家的丹[/b]。
	# Arrange
	give_card(AP_TEMPLATE)
	GameStateManager.call(&"set_exploration_ap", 5, 5)
	# Act
	open_page(0)
	inventory_page().call(&"press_category")
	inventory_page().call(&"press_row", 0)
	# Assert
	assert_eq(str(inventory_page().call(&"message_text")), ApScript.TEXT_FULL,
			"文案应为 GDD 验收项「行动力已满，无需服用此丹。」")
	assert_eq(_owned_count(AP_TEMPLATE), 1, "已满时不应消耗丹药")
	assert_eq(_ap(), 5, "行动力不应被写坏")


# ═══════════════════════════════════════════════════════════════════════════════
# 装置
# ═══════════════════════════════════════════════════════════════════════════════

## 回气丹在可炼清单里的行号（现查，不假设配方表顺序）。
func _ap_recipe_index() -> int:
	for raw: Variant in craft.call(&"entries", ListScript.KIND_ALCHEMY):
		var row: Dictionary = raw
		if str(row.get("recipe_id")) == AP_RECIPE:
			return int(row.get("index"))
	fail_test("可炼清单里没有配方 %s" % AP_RECIPE)
	return -1


## 收藏里某模板的实例数。
func _owned_count(p_template_id: StringName) -> int:
	var count: int = 0
	for raw: Variant in (GameStateManager.collection as Dictionary)["owned_cards"]:
		if raw is Dictionary and str((raw as Dictionary).get("template_id", "")) \
				== str(p_template_id):
			count += 1
	return count


## 低级灵材持有量（走真实 ResourceSystem 读口——与 [method give_ling_cai] 同一本账）。
func low_cai() -> int:
	return int(ResourceSystem.get_resource(&"ling_cai", 1))


## 收藏里最后一张卡的模板 ID（空串 = 收藏为空）。
func last_owned_template() -> String:
	var owned: Array = (GameStateManager.collection as Dictionary)["owned_cards"]
	if owned.is_empty():
		return ""
	return str((owned[owned.size() - 1] as Dictionary).get("template_id", ""))


## 当前行动力（探索域）。
func _ap() -> int:
	return int(GameStateManager.exploration.get("action_points", -1))
