extends GutTest
## ShopRestNodeFixture —— 商店 / 回复节点端到端用例的共享夹具。[br]
## [br][b]为什么单独一处[/b]：两类节点的用例共用同一套装置——真实
## [code]node_graph_screen.tscn[/code] 场景、真实 Autoload（ResourceSystem /
## CardSystem / GSM）、独占角色 ID 段（7701+）的存档还原。把这些留在用例文件里
## 会让文件超出 300 行软上限，而「怎么搭台子」与「断言什么」是两件事
## （同 [code]full_battle_fixture.gd[/code] 先例）。[br]
## [br][b]用法[/b]：子类 [code]extends "res://…/shop_rest_node_fixture.gd"[/code]，
## 直接写 [code]test_*[/code] 方法即可；[code]before_each[/code] /
## [code]after_each[/code] 由本夹具提供，子类若要扩展需先 [code]super()[/code]。[br]
## [br][b]文件前缀[/b]：本文件不以 [code]test_[/code] 开头——GUT 按前缀收集，
## 因此它只作为基类被继承，不会被当作用例文件单独执行。[br]
## [br][b]隔离与还原[/b]：GSM 的 player / collection / 校验模板库在
## [code]before_each[/code] 快照、[code]after_each[/code] 原样还原
## （同 [code]test_battle_reward_grant.gd[/code] 先例），避免污染后续用例。[br]
##
## 来源: GDD exploration-system.md §公式 7 / §8 边界、exploration-ui-system.md §4c、
## ADR-0031 §2。

const NodeGraphScreenScene: PackedScene = preload(
		"res://src/ui/exploration/node_graph_screen.tscn")
const ES_SCRIPT := preload("res://src/feature/exploration_system.gd")
const Rules := preload("res://src/ui/exploration/node_interaction_rules.gd")
## 卡牌模板就位助手（异步加载的同步推进）。
const PrimerScript := preload("res://tests/integration/exploration_ui/card_template_primer.gd")

const SHOP_NODE: int = 201
const REST_NODE: int = 303
## 货架用的真实出厂模板（稀有度 1 → 价格 10）。
const CARD_ID: StringName = &"pei_yuan_dan"
const CARD_PRICE: int = 10
## 回复点用例的角色 ID 与血量（1/10 与 1/10，合计缺口 18 → 回复 9）。
const CHAR_A: int = 7701
const CHAR_B: int = 7702
const CHAR_MAX_HP: int = 10
const CHAR_START_HP: int = 1
const EXPECTED_HEAL: int = 9

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
	_reset_hp()
	es = ES_SCRIPT.new()
	screen = NodeGraphScreenScene.instantiate()
	screen.animate = false
	screen.reduce_motion_override = true
	screen.exploration_system = es
	add_child_autofree(screen)
	screen._on_map_generated(&"qing_yun_jian_zong", {"nodes": {}, "graph": {}})


func after_each() -> void:
	if screen != null and is_instance_valid(screen):
		# 面板还开着时先关掉——否则节点图冻结跨用例留着
		var presenter: Variant = screen.shop_presenter()
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

## 到达交互节点——经交互组件的转发信号（生产路径的同一发射点）。
func _reach(p_node_id: int, p_type: StringName, p_payload: Dictionary) -> void:
	var interactor: Node = screen.get_node(NodePath("NodeMoveInteractor"))
	interactor.emit_signal(&"node_interaction_forwarded", p_node_id, p_type, p_payload)
	assert_eq(_popup_host().call(&"get_open_kind"), Rules.popup_kind_for(p_type),
			"到达 %s 节点应打开对应确认弹窗" % p_type)


## 点确认框的「确认」。
func _confirm() -> void:
	_popup_host().get_node(NodePath(
			"NodeInteractionPopup/ConfirmButton")).pressed.emit()


func _popup_host() -> Node:
	return screen.get_node(NodePath("NodeInteractionPopupHost"))


## 屏幕下的节点图渲染器与视口（冻结断言读它们的状态）。
func _renderer() -> Node:
	return screen.get("viewport").renderer


func _viewport() -> Node:
	return screen.get("viewport")


## 屏幕下的移动交互组件（键盘走位开关的持有者）。
func _interactor() -> Node:
	return screen.get_node(NodePath("NodeMoveInteractor"))


## 商店/回复接线组件（屏幕公开入口）。
func _presenter() -> Variant:
	return screen.shop_presenter()


## 当前商店面板（未打开时断言会失败——面板是「确认之后」的可见证据）。
func _panel() -> Variant:
	return _presenter().call(&"panel")


## 一份货架载荷（价格/库存显式给定——不依赖生成器的定价表）。
func _shop_payload(p_price: int, p_stock: int) -> Dictionary:
	return {"inventory": {"items": [{
		"card_id": str(CARD_ID), "rarity": 1, "price": p_price, "stock": p_stock,
	}], "generated_for_realm": 1}}


# ═══════════════════════════════════════════════════════════════════════════════
# 存档读写（断言的就是「玩家数据变了」）
# ═══════════════════════════════════════════════════════════════════════════════

func _ling_shi() -> int:
	return int(GameStateManager.player.resources.ling_shi)


func _set_ling_shi(p_value: int) -> void:
	GameStateManager.player.resources.ling_shi = p_value


func _collection_count() -> int:
	return int(GameStateManager.collection.total_count)


## 收藏里最后一张卡的模板 ID（空串 = 收藏为空）。
func _last_owned_template() -> String:
	var owned: Array = GameStateManager.collection.owned_cards
	if owned.is_empty():
		return ""
	return str((owned[owned.size() - 1] as Dictionary).get("template_id", ""))


func _hp_of(p_character_id: int) -> int:
	var table: Dictionary = GameStateManager.player.character_hp
	return int((table.get(str(p_character_id), {}) as Dictionary).get("current_hp", -1))


func _set_hp(p_character_id: int, p_current: int) -> void:
	GameStateManager.call(&"_set_player_character_hp", p_character_id,
			{"current_hp": p_current, "max_hp": CHAR_MAX_HP})


func _reset_hp() -> void:
	GameStateManager.player.character_hp = {}
	for char_id: int in [CHAR_A, CHAR_B]:
		_set_hp(char_id, CHAR_START_HP)


## 提示里的回复量（从「回复 N 点生命」里取 N；无该句式返回 0）。
func _hinted_amount() -> int:
	var text: String = str(_presenter().call(&"last_hint"))
	var marker: String = "回复 "
	var start: int = text.find(marker)
	if start < 0:
		return 0
	var rest: String = text.substr(start + marker.length())
	var digits: String = ""
	for i: int in range(rest.length()):
		if not rest[i].is_valid_int():
			break
		digits += rest[i]
	return digits.to_int() if not digits.is_empty() else 0


# ═══════════════════════════════════════════════════════════════════════════════
# 卡牌模板就位
# ═══════════════════════════════════════════════════════════════════════════════

## 备好卡牌校验——真实模板注册表 + GSM 校验开启（同 test_battle_reward_grant 口径）。
## [br]模板就位的驱动逻辑见 [CardTemplatePrimer]（多个用例文件共用，避免各写一遍）。
func _prepare_card_validation() -> void:
	PrimerScript.prime(CardSystem, CARD_ID)
	var database: Dictionary = GameStateManager.get("_card_template_database")
	database[str(CARD_ID)] = database.get(str(CARD_ID), {})
	GameStateManager.set("_card_template_database", database)
	GameStateManager.validation_enabled = true
