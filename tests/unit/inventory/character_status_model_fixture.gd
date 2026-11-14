extends GutTest
## CharacterStatusModelFixture —— 角色状态模型单元测试的共享装置。[br]
## [br][b]装置[/b]：用内嵌桩替代 GSM / RealmSystem / CardSystem / 名册与 HP 读取器。[br]
## 名册与 HP 那两个依赖走的是 [code]DeployRosterReader[/code] 与
## [code]CombatHpCarryover[/code]——它们是[b]静态/无状态读侧[/b]，本模型通过
## [code]deck.slots[/code] + 桩模板 + 注入的 HP 表驱动它们，因而测的仍是真实
## 读取链路（不是复制一份逻辑）。[br]
## [br][b]属性断言直接对照真实 [code]RealmSystem.realm_table[/code][/b]——本轮的
## 「角色状态数值与境界配置一致」这条验收，靠的就是这份对照（模型不许加工数值）。[br]
## [br][b]原名不带 [code]test_[/code] 前缀[/b]：GUT 不把它当用例收集，只作基类
## （先例 [code]inventory_screens_fixture.gd[/code]）。
##
## 来源: 先例 [code]tests/integration/exploration_ui/shop_rest_node_fixture.gd[/code]。

const ModelScript := preload("res://src/feature/inventory/character_status_model.gd")
const RealmScript := preload("res://src/core/realm_system.gd")

## 角色位数量（[code]DeployRosterReader.CHARACTER_SLOT_COUNT[/code]）。
const CHARACTER_SLOT_COUNT: int = 6


## GSM 桩——只暴露本模型会读的两个域。
class StubGsm:
	extends Node
	var player: Variant = {}
	var deck: Variant = {"slots": [null, null, null, null, null, null]}


## CardSystem 桩——按实例 ID 反查模板（名册读取器的契约）。
class StubCardSystem:
	extends Node
	var by_instance: Dictionary = {}

	func get_template_by_instance_id(card_instance_id: int) -> Variant:
		return by_instance.get(card_instance_id, null)


## DeploymentSystem 桩——只需「谁不可用」。
class StubDeployment:
	extends Node
	var unavailable: Array = []

	func get_unavailable_characters() -> Array:
		return unavailable


## HP 账本桩——[code]CombatHpCarryover[/code] 的 [code]read_all()[/code] 契约。
class StubHp:
	extends RefCounted
	var table: Dictionary = {}

	func read_all() -> Dictionary:
		return table


var gsm: StubGsm = null
var cards: StubCardSystem = null
var deployment: StubDeployment = null
var hp: StubHp = null
var model: RefCounted = null


func before_each() -> void:
	gsm = StubGsm.new()
	cards = StubCardSystem.new()
	deployment = StubDeployment.new()
	hp = StubHp.new()
	add_child_autofree(gsm)
	add_child_autofree(cards)
	add_child_autofree(deployment)
	model = ModelScript.new(gsm, null)
	model.set_dependencies(gsm, cards, null, deployment, null)
	model.hp_carryover = hp


## 造一名角色：占位 [param p_slot]、模板名 [param p_name]、基础生命
## [param p_hp]、基础攻击 [param p_attack]。
func add_character(p_slot: int, p_instance_id: int, p_name: String,
		p_hp: int, p_attack: int) -> void:
	var slots: Array = (gsm.deck as Dictionary)["slots"]
	while slots.size() < CHARACTER_SLOT_COUNT:
		slots.append(null)
	slots[p_slot] = p_instance_id
	cards.by_instance[p_instance_id] = {
		"card_id": p_name, "name": p_name, "type": 0, "rarity": 2,
		"base_hp": p_hp, "base_attack": p_attack, "faction_tags": [],
	}
