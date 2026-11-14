extends GutTest
## InventoryModelFixture —— 背包模型单元测试的共享装置（内嵌桩 + 造数据小工具）。[br]
## [br][b]为什么用桩而不是真实 Autoload[/b]：本模型的读法只有两种——读字典键 +
## 调 [code]get_template[/code]，分支（域缺失 / 旧档形态 / 模板查不到 / 越界分类）
## 用桩能逐个精确摆出来；真实链路的接线由
## [code]tests/integration/inventory_ui/[/code] 端到端覆盖。单元层管分支，
## 集成层管接线。[br]
## [br][b]原名不带 [code]test_[/code] 前缀[/b]：GUT 不把它当用例收集，只作基类
## （先例 [code]shop_rest_node_fixture.gd[/code] / [code]inventory_screens_fixture.gd[/code]）。
##
## 来源: 先例 [code]tests/integration/exploration_ui/shop_rest_node_fixture.gd[/code]。

const ModelScript := preload("res://src/feature/inventory/inventory_model.gd")
const Catalog := preload("res://src/feature/inventory/inventory_catalog.gd")

## 分类下标（与 [code]InventoryCatalog.CATEGORIES[/code] 的顺序一致）。
const CATEGORY_LING_CAI: int = 0
const CATEGORY_PILL: int = 1
const CATEGORY_ARTIFACT: int = 2


## GSM 桩——只需 [code]player[/code] / [code]collection[/code] 两个域。
class StubGsm:
	extends Node
	var player: Variant = {}
	var collection: Variant = {}


## CardSystem 桩——按 template_id 查模板字典。
class StubCardSystem:
	extends Node
	var templates: Dictionary = {}

	func get_template(id: StringName) -> Variant:
		return templates.get(str(id), null)


var gsm: StubGsm = null
var cards: StubCardSystem = null
var model: RefCounted = null


func before_each() -> void:
	gsm = StubGsm.new()
	cards = StubCardSystem.new()
	add_child_autofree(gsm)
	add_child_autofree(cards)
	model = ModelScript.new(gsm, cards)


## 模板桩的形状只需模型实际读到的四个键。
func _template(p_name: String, p_type: int, p_rarity: int) -> Dictionary:
	return {"card_id": p_name, "name": p_name, "type": p_type, "rarity": p_rarity}


## 摆一份灵材四档计数（走 [code]player.resources.ling_cai[/code] 的真实形状）。
func set_ling_cai(p_low: int, p_medium: int, p_high: int, p_top: int) -> void:
	gsm.player = {"resources": {"ling_cai": {
		"low": p_low, "medium": p_medium, "high": p_high, "top": p_top,
	}}}


## 摆一批收藏卡（只给模型实际读的两个键：实例 ID 与模板 ID）。[br]
## [br][b]为什么在这里造而不是让用例自己拼[/b]：拼坏了（比如漏 template_id）
## 会让用例静默走向「脏数据被跳过」的分支，断言却说不出所以然。
func set_owned(p_template_ids: Array) -> void:
	var owned: Array = []
	var instance_id: int = 1
	for template_id: String in p_template_ids:
		owned.append({"card_instance_id": instance_id, "template_id": template_id})
		instance_id += 1
	gsm.collection = {"owned_cards": owned, "total_count": owned.size()}
