extends GutTest
## 卡牌费用解析回归（2026-11-10 完整战斗验收）。[br]
## [br][b]背景[/b]：真实对局里 [code]_get_card_instance[/code] 返回
## [code]CardTemplate[/code]（Resource），而 [code]_get_card_cost[/code] 此前只认
## Dictionary 与 [code]get_cost()[/code]——模板卡落「未知格式，按 0 处理」：
## 所有卡免费、费用校验形同虚设，且每张卡刷一条 warning。[br]
## [br][b]本文件锁定三种形态[/b]：Dictionary（测试桩）、CardTemplate（生产）、
## 带 [code]get_cost()[/code] 的对象（旧接口）。

const CS_SCRIPT := preload("res://src/feature/combat_system.gd")
const TemplateScript := preload("res://src/core/card_system/card_template.gd")

var cs: Node = null


func before_each() -> void:
	cs = CS_SCRIPT.new()


func after_each() -> void:
	if cs != null:
		cs.free()
		cs = null


## 生产形态：CardTemplate Resource 的 cost 必须被读出（不是 0）。
func test_cost_read_from_card_template_resource() -> void:
	# Arrange
	var template: Resource = TemplateScript.new()
	template.set("cost", 3)
	# Act
	var cost: int = int(cs.call("_get_card_cost", template))
	# Assert
	assert_eq(cost, 3, "CardTemplate.cost 应被读取（真实对局的节点形态）")


## 测试桩形态：Dictionary 的 cost 原样读取。
func test_cost_read_from_dictionary() -> void:
	assert_eq(int(cs.call("_get_card_cost", {"cost": 2})), 2, "字典卡读 cost 键")


## 旧接口：带 get_cost() 的对象仍然可用。
func test_cost_read_from_get_cost_object() -> void:
	assert_eq(int(cs.call("_get_card_cost", CostStub.new())), 4, "get_cost() 回退仍生效")


## 最小桩——只实现 get_cost()。
class CostStub extends RefCounted:
	func get_cost() -> int:
		return 4
