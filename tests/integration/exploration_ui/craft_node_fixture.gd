extends GutTest
## CraftNodeFixture —— 炼丹台 / 炼器台端到端用例的共享夹具。[br]
## [br][b]为什么单独一处[/b]：用例文件要守在 300 行软上限内
## （.claude/docs/coding-standards.md），而「怎么搭台子」与「断言什么」是两件事
## （同 [code]shop_rest_node_fixture.gd[/code] 先例）。[br]
## [br][b]用法[/b]：子类 [code]extends "res://…/craft_node_fixture.gd"[/code]，
## 直接写 [code]test_*[/code] 方法即可；[code]before_each[/code] /
## [code]after_each[/code] 由本夹具提供，子类若要扩展需先 [code]super()[/code]。[br]
## [br][b]文件前缀[/b]：本文件不以 [code]test_[/code] 开头——GUT 按前缀收集，
## 因此它只作为基类被继承，不会被当作用例文件单独执行。[br]
## [br][b]装置[/b]：真实 [code]node_graph_screen.tscn[/code] + 真实 Autoload
## （ResourceSystem / CardSystem / GSM）；用例前后快照还原 player / collection /
## 校验库（同 [code]test_battle_reward_grant.gd[/code] 口径）。[br]
##
## 来源: design/gdd/alchemy-crafting-system.md §1a/§2a/§4/§边界、
## design/gdd/exploration-ui-system.md §4c（overlay 先例）、ADR-0031 §2。

const NodeGraphScreenScene: PackedScene = preload(
		"res://src/ui/exploration/node_graph_screen.tscn")
const ES_SCRIPT := preload("res://src/feature/exploration_system.gd")
const ListScript := preload("res://src/feature/exploration/exploration_craft_list.gd")
## 卡牌模板就位助手（异步加载的同步推进——与商店/采集用例共用）。
const PrimerScript := preload("res://tests/integration/exploration_ui/card_template_primer.gd")

## 炼丹台与炼器台节点 ID（[code]layer * 100 + idx[/code] 编码，任意非入口值即可）。
const ALCHEMY_NODE: int = 210
const FORGE_NODE: int = 211
## 用例地图 ID。
const MAP_ID: StringName = &"qing_yun_jian_zong"

## 炼气期（炼制等级 0）就能炼的两道配方——炼丹与炼器各一。
const PILL_ID: String = "hui_chun_dan"
const PILL_TEMPLATE: String = "pill_hui_chun_dan"
const PILL_LOW_COST: int = 2
const ARTIFACT_ID: String = "ji_chu_fa_qi"
const ARTIFACT_TEMPLATE: String = "artifact_ji_chu_fa_qi"

## 配方资源里的全部模板 ID（GSM 校验库需要它们才让写入）。
const ALL_TEMPLATES: Array = [
	"pill_hui_chun_dan", "pill_yu_ling_dan", "pill_tian_luo_dan",
	"pill_jiu_zhuan_jin_dan", "artifact_ji_chu_fa_qi", "artifact_zhong_pin_fa_qi",
	"artifact_shang_pin_fa_qi", "artifact_tong_tian_ling_bao",
]

var es: Node = null
var screen: Control = null
var _player_before: Dictionary = {}
var _collection_before: Dictionary = {}
var _db_before: Dictionary = {}
var _validation_before: bool = false


func before_each() -> void:
	_player_before = (GameStateManager.player as Dictionary).duplicate(true)
	_collection_before = (GameStateManager.collection as Dictionary).duplicate(true)
	_db_before = (GameStateManager.get("_card_template_database") as Dictionary).duplicate(true)
	_validation_before = bool(GameStateManager.validation_enabled)
	_prepare_card_validation()
	GameStateManager.player.realm = 1  # 炼气期 → 炼制等级 0
	set_materials({1: 0, 2: 0, 3: 0, 4: 0})
	GameStateManager.collection.owned_cards = []
	GameStateManager.collection.total_count = 0

	es = ES_SCRIPT.new()
	es.set("_dag_ready", true)
	es.set("_node_details", {
		ALCHEMY_NODE: {"type": 11, "layer": 2, "idx": 0, "label": "炼丹台"},
		FORGE_NODE: {"type": 12, "layer": 2, "idx": 1, "label": "炼器台"},
	})
	screen = NodeGraphScreenScene.instantiate()
	screen.animate = false
	screen.reduce_motion_override = true
	screen.exploration_system = es
	add_child_autofree(screen)
	screen._on_map_generated(MAP_ID, {"nodes": {}, "graph": {}})


func after_each() -> void:
	if screen != null and is_instance_valid(screen):
		# 面板还开着时先关掉——否则节点图冻结跨用例留着
		var presenter: Variant = screen.craft_presenter()
		if presenter != null:
			presenter.call(&"close_panel")
	GameStateManager.player = _player_before
	GameStateManager.collection = _collection_before
	GameStateManager.set("_card_template_database", _db_before)
	GameStateManager.validation_enabled = _validation_before
	if es != null:
		es.free()
		es = null
	screen = null


# ═══════════════════════════════════════════════════════════════════════════════
# 装置
# ═══════════════════════════════════════════════════════════════════════════════

## 到达炼制节点——经交互组件的转发信号（生产路径的同一发射点）。
func reach(p_node_id: int, p_kind: StringName) -> void:
	var interactor: Node = screen.get_node(NodePath("NodeMoveInteractor"))
	interactor.emit_signal(&"node_interaction_forwarded", p_node_id, p_kind,
			{"entries": es.call(&"craft_entries", p_kind)})


## 某配方在面板里的行序（不假设配方表顺序）。
func row_of(p_panel: Variant, p_recipe_id: String) -> int:
	var count: int = int(p_panel.call(&"entry_count"))
	for row: int in count:
		if int(p_panel.call(&"recipe_index_at", row)) == index_in_entries(p_recipe_id):
			return row
	fail_test("面板里没有配方 %s" % p_recipe_id)
	return -1


## 配方在清单里的下标（面板行序 → 配方下标）。
func index_in_entries(p_recipe_id: String) -> int:
	for kind: StringName in [ListScript.KIND_ALCHEMY, ListScript.KIND_FORGE]:
		var entries: Array = es.call(&"craft_entries", kind)
		for raw: Variant in entries:
			var row: Dictionary = raw
			if str(row.get("recipe_id")) == p_recipe_id:
				return int(row.get("index"))
	return -1


## 面板里某行的渲染文本。
func row_text(p_panel: Variant, p_row: int) -> String:
	return str((p_panel.call(&"entry_texts") as Array)[p_row])


## 炼制面板接线组件（屏幕公开入口）。
func presenter() -> Variant:
	return screen.craft_presenter()


## 当前炼制面板（未打开时返回 null）。
func panel() -> Variant:
	var p: Variant = presenter()
	return p.call(&"panel") if p != null else null


func popup_host() -> Node:
	return screen.get_node(NodePath("NodeInteractionPopupHost"))


# ═══════════════════════════════════════════════════════════════════════════════
# 存档读写（断言的就是「玩家数据变了」）
# ═══════════════════════════════════════════════════════════════════════════════

## 各品质档位的灵材持有量（按 GSM 的 key 名写入——与 ResourceSystem 同一本账）。
func set_materials(p_counts: Dictionary) -> void:
	GameStateManager.player.resources.ling_cai = {
		"low": int(p_counts.get(1, 0)),
		"medium": int(p_counts.get(2, 0)),
		"high": int(p_counts.get(3, 0)),
		"top": int(p_counts.get(4, 0)),
	}


func low_cai() -> int:
	return int(ResourceSystem.get_resource(&"ling_cai", 1))


func collection_count() -> int:
	return int(GameStateManager.collection.total_count)


## 收藏里最后一张卡的模板 ID（空串 = 收藏为空）。
func last_owned_template() -> String:
	var owned: Array = GameStateManager.collection.owned_cards
	if owned.is_empty():
		return ""
	return str((owned[owned.size() - 1] as Dictionary).get("template_id", ""))


# ═══════════════════════════════════════════════════════════════════════════════
# 卡牌模板就位
# ═══════════════════════════════════════════════════════════════════════════════

## 备好卡牌校验——真实模板注册表 + GSM 校验开启（同 [code]test_battle_reward_grant[/code] 口径）。
## [br]模板就位的驱动逻辑见 [CardTemplatePrimer]（多个用例文件共用，避免各写一遍）。
func _prepare_card_validation() -> void:
	PrimerScript.prime(CardSystem, StringName(PILL_TEMPLATE))
	var database: Dictionary = GameStateManager.get("_card_template_database")
	for tid: String in ALL_TEMPLATES:
		database[tid] = database.get(tid, {})
	GameStateManager.set("_card_template_database", database)
	GameStateManager.validation_enabled = true
