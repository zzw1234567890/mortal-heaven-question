extends Node
## 备战面板取数依赖桩 —— 一次性提供 GSM / 卡牌系统 / 部署系统 / 绑定管理器
## 四个接缝，供 `DeployPanel.setup()` 与 `DeployRosterReader.read()` 消费。
##
## 用途（QL-TEST-COVERAGE 缺口 2 / 3）：验证 `setup()` 的信号订阅与
## `load_roster()` 的端到端取数成功路径——此前所有集成测试用
## `apply_roster()` 手工喂快照，绕开了生产读取链路。
##
## Story: combat-ui-layout Story 007。

## GSM 接缝：`deck.slots` = card_instance_id 数组（null 表示空位）。
var deck: Variant = {"slots": [null, null, null, null, null, null]}
## 模板表：card_instance_id → {name, base_hp, base_attack, faction_tags}。
var templates: Dictionary = {}
## 不可用（阵亡）角色 ID 列表。
var unavailable: Array = []
## 绑定表：character_id → Array[int]。
var bindings: Dictionary = {}
## `get_template_by_instance_id` 被调用次数（锁定「单次取数」不变量）。
var template_query_count: int = 0

signal character_unavailable(character_id: int)
signal character_revived(character_id: int)


## 卡牌系统接缝。
func get_template_by_instance_id(card_instance_id: int) -> Variant:
	template_query_count += 1
	return templates.get(card_instance_id)


## 部署系统接缝。
func get_unavailable_characters() -> Array:
	return unavailable.duplicate()


## 绑定管理器接缝。
func get_binding_ids_by_character(character_id: int) -> Array:
	return (bindings.get(character_id, []) as Array).duplicate()


## 让某角色阵亡（发信号 + 记入不可用列表）——驱动面板的脏通知分支。
func mark_unavailable_for_test(character_id: int) -> void:
	unavailable.append(character_id)
	character_unavailable.emit(character_id)


## 让某角色复活（发信号 + 移出不可用列表）。
func revive_for_test(character_id: int) -> void:
	unavailable.erase(character_id)
	character_revived.emit(character_id)


## 填充一组角色位与模板（简化夹具构造）。
func seed(p_ids: Array, p_templates: Dictionary) -> void:
	var slots: Array = [null, null, null, null, null, null]
	for i: int in range(mini(p_ids.size(), 6)):
		slots[i] = p_ids[i]
	deck = {"slots": slots}
	templates = p_templates.duplicate(true)
