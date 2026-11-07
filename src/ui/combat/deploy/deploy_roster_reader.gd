class_name DeployRosterReader
extends RefCounted
## DeployRosterReader —— 备战面板角色名册读取器（combat-ui-layout Story 007）。
##
## [b]职责[/b]：把「角色位（GSM deck.slots）→ 角色卡模板 → 备战面板渲染快照」
## 的读取链路收敛到一处，供 [DeployPanel] 与手动调试宿主消费。[br]
## [br][b]数据来源[/b]（全部依赖注入，面板不直连 Autoload——ADR-0031 §2 零状态所有权）：[br]
##   - 角色位：[code]gsm.deck.slots[/code]（6 个元素，值为 card_instance_id，null = 空位）[br]
##   - 属性：[code]card_system.get_template_by_instance_id(id)[/code] → CardTemplate
##     （name / base_hp / base_attack / faction_tags）[br]
##   - 阵亡：[code]deployment_system.get_unavailable_characters()[/code][br]
##   - 绑定：[code]binding_manager.get_binding_ids_by_character(id)[/code][br]
## [br][b]输出快照字段[/b]：[code]{character_id, display_name, hp, attack,
## binding_count, faction_tags, is_dead, slot_index}[/code]。[br]
## [br][b]防御[/b]：任一依赖缺失或模板解析失败时跳过该角色位（不崩溃、不报错——
## 角色位数据尚未初始化时面板显示空名册）。
##
## @experimental
## 来源: ADR-0031、GDD card-system.md §角色位（6 个角色位）、
## deployment-system.md §2、combat-ui-layout Story 007（AC-1）。

## 角色位数量（GDD card-system.md L229「角色位：6个角色位，不计入卡组容量」）。
const CHARACTER_SLOT_COUNT: int = 6


## 读取完整名册快照。[br]
## [param gsm]: 提供 [code]deck.slots[/code] 的 GSM（或同契约 mock）。[br]
## [param card_system]: 提供 [code]get_template_by_instance_id(id)[/code]。[br]
## [param deployment_system]: 提供 [code]get_unavailable_characters()[/code]。[br]
## [param binding_manager]: 提供 [code]get_binding_ids_by_character(id)[/code]。[br]
## [br][b]返回[/b]: Array[Dictionary]——按角色位顺序，跳过空位与解析失败项。
static func read(gsm: Node, card_system: Node, deployment_system: Node,
		binding_manager: Node) -> Array:
	var roster: Array = []
	if gsm == null or card_system == null:
		return roster
	var slots: Variant = _read_slots(gsm)
	if not (slots is Array):
		return roster
	var dead_ids: Array = _read_dead_ids(deployment_system)
	for slot_index: int in range(mini((slots as Array).size(), CHARACTER_SLOT_COUNT)):
		var raw: Variant = (slots as Array)[slot_index]
		if raw == null:
			continue
		var instance_id: int = int(raw)
		if instance_id <= 0:
			continue
		var template: Variant = card_system.call("get_template_by_instance_id", instance_id)
		if template == null:
			continue
		roster.append({
			"character_id": instance_id,
			"display_name": str(template.get("name")),
			"hp": int(template.get("base_hp")),
			"attack": int(template.get("base_attack")),
			"binding_count": _read_binding_count(binding_manager, instance_id),
			"faction_tags": _read_faction_tags(template),
			"is_dead": dead_ids.has(instance_id),
			"slot_index": slot_index,
		})
	return roster


## 读取角色位数组——兼容域对象与纯字典两种承载（[code]gsm.deck[/code]）。
static func _read_slots(gsm: Node) -> Variant:
	var deck: Variant = gsm.get("deck")
	if deck == null:
		return null
	if deck is Dictionary:
		return (deck as Dictionary).get("slots", null)
	return deck.get("slots")


## 读取阵亡（不可用）角色 ID 列表——依赖缺失时返回空数组。
static func _read_dead_ids(deployment_system: Node) -> Array:
	if deployment_system == null or not deployment_system.has_method("get_unavailable_characters"):
		return []
	var ids: Variant = deployment_system.call("get_unavailable_characters")
	return ids if ids is Array else []


## 读取绑定数量——依赖缺失时返回 0（绑定概览退化为无角标）。
static func _read_binding_count(binding_manager: Node, character_id: int) -> int:
	if binding_manager == null or not binding_manager.has_method("get_binding_ids_by_character"):
		return 0
	var ids: Variant = binding_manager.call("get_binding_ids_by_character", character_id)
	return (ids as Array).size() if ids is Array else 0


## 读取阵营标签列表——模板字段缺失时返回空数组。
static func _read_faction_tags(template: Variant) -> Array:
	var tags: Variant = template.get("faction_tags")
	return (tags as Array).duplicate() if tags is Array else []
