extends GutTest
## combat-ui-layout Story 007 单元测试：备战面板角色名册读取链路（AC-1）。
##
## 覆盖 QL-TEST-COVERAGE 缺口：`DeployRosterReader` 此前零自动化覆盖，而它正是
## 生产路径的取数接缝（GSM deck.slots → CardSystem 模板 → 阵亡/绑定状态）。
## 全部用例使用注入的桩节点——不触碰 Autoload、不依赖文件系统。
##
## Story 类型 UI（Logic 内核）——本文件为 Logic 内核 BLOCKING 证据之一。

const RosterReader := preload("res://src/ui/combat/deploy/deploy_roster_reader.gd")

## 桩 GSM —— 只需暴露 `deck` 属性（字典或对象两种承载）。
class MockGsm extends Node:
	var deck: Variant = null


## 桩卡牌系统 —— 模板可为 Dictionary 或 null（模拟解析失败）。
class MockCardSystem extends Node:
	var templates: Dictionary = {}

	func get_template_by_instance_id(card_instance_id: int) -> Variant:
		return templates.get(card_instance_id)


## 桩部署系统 —— 返回预设的不可用角色 ID 列表。
class MockDeployment extends Node:
	var unavailable: Array = []

	func get_unavailable_characters() -> Array:
		return unavailable.duplicate()


## 桩绑定管理器 —— 按角色 ID 返回绑定 ID 列表。
class MockBinding extends Node:
	var by_character: Dictionary = {}

	func get_binding_ids_by_character(character_id: int) -> Array:
		return (by_character.get(character_id, []) as Array).duplicate()


## 无方法桩 —— 验证「依赖缺失方法时退化」的分支。
class BareNode extends Node:
	pass


var gsm: MockGsm = null
var cards: MockCardSystem = null
var deployment: MockDeployment = null
var binding: MockBinding = null


func before_each() -> void:
	gsm = MockGsm.new()
	cards = MockCardSystem.new()
	deployment = MockDeployment.new()
	binding = MockBinding.new()
	add_child_autofree(gsm)
	add_child_autofree(cards)
	add_child_autofree(deployment)
	add_child_autofree(binding)


## 构造模板字典（模拟 CardTemplate 的可读字段）。
func _template(p_name: String, p_hp: int, p_atk: int, p_tags: Array = []) -> Dictionary:
	return {"name": p_name, "base_hp": p_hp, "base_attack": p_atk,
			"faction_tags": p_tags}


## 标准三角色名册：101 林渊（存活，2 绑定）/ 102 苏剑鸣（阵亡）/ 空位。
func _seed_standard_roster() -> void:
	gsm.deck = {"slots": [101, null, 102, null, null, null]}
	cards.templates[101] = _template("林渊", 8, 3, [&"qing_yun", &"sword"])
	cards.templates[102] = _template("苏剑鸣", 9, 4, [&"qing_yun"])
	deployment.unavailable = [102]
	binding.by_character = {101: [7, 8], 102: []}


# ═══════════════════════════════════════════════════════════════════════════════
# 依赖缺失退化（不崩溃、返回空名册）
# ═══════════════════════════════════════════════════════════════════════════════

func test_read_with_null_gsm_returns_empty_roster() -> void:
	# Act
	var roster: Array = RosterReader.read(null, cards, deployment, binding)
	# Assert
	assert_eq(roster.size(), 0, "缺少 GSM 时应退化为空名册")


func test_read_with_null_card_system_returns_empty_roster() -> void:
	# Arrange: 角色位有数据但卡牌系统缺失
	gsm.deck = {"slots": [101, null, null, null, null, null]}
	# Act
	var roster: Array = RosterReader.read(gsm, null, deployment, binding)
	# Assert
	assert_eq(roster.size(), 0, "缺少卡牌系统时应退化为空名册")


func test_read_without_deck_returns_empty_roster() -> void:
	# Arrange: GSM 无 deck 域
	gsm.deck = null
	# Act
	var roster: Array = RosterReader.read(gsm, cards, deployment, binding)
	# Assert
	assert_eq(roster.size(), 0, "GSM 无 deck 时应退化为空名册")


func test_read_with_non_array_slots_returns_empty_roster() -> void:
	# Arrange: slots 类型异常（非 Array）
	gsm.deck = {"slots": null}
	# Act
	var roster: Array = RosterReader.read(gsm, cards, deployment, binding)
	# Assert
	assert_eq(roster.size(), 0, "slots 非数组时应退化为空名册")


func test_read_without_deployment_or_binding_still_returns_roster() -> void:
	# Arrange: 两个可选依赖缺失
	gsm.deck = {"slots": [101, null, null, null, null, null]}
	cards.templates[101] = _template("林渊", 8, 3, [&"qing_yun"])
	# Act
	var roster: Array = RosterReader.read(gsm, cards, null, null)
	# Assert: 主链路可用，可选字段退化
	assert_eq(roster.size(), 1, "可选依赖缺失不应影响主链路")
	assert_false(bool(roster[0]["is_dead"]), "缺部署系统时应视为存活")
	assert_eq(int(roster[0]["binding_count"]), 0, "缺绑定管理器时角标应为 0")


func test_read_with_bare_dependency_nodes_degrades_silently() -> void:
	# Arrange: 依赖对象存在但没有所需方法（实现变更后的防御分支）
	gsm.deck = {"slots": [101, null, null, null, null, null]}
	cards.templates[101] = _template("林渊", 8, 3)
	var bare_deploy: BareNode = BareNode.new()
	var bare_binding: BareNode = BareNode.new()
	add_child_autofree(bare_deploy)
	add_child_autofree(bare_binding)
	# Act
	var roster: Array = RosterReader.read(gsm, cards, bare_deploy, bare_binding)
	# Assert
	assert_eq(roster.size(), 1, "方法缺失时不应崩溃")
	assert_eq(int(roster[0]["binding_count"]), 0, "方法缺失时绑定数退化为 0")


# ═══════════════════════════════════════════════════════════════════════════════
# 主链路：字段映射
# ═══════════════════════════════════════════════════════════════════════════════

func test_read_maps_template_fields_to_snapshot() -> void:
	# Arrange
	_seed_standard_roster()
	# Act
	var roster: Array = RosterReader.read(gsm, cards, deployment, binding)
	# Assert: 跳过空位后 2 人，字段逐项映射
	assert_eq(roster.size(), 2, "两个非空角色位应读出 2 人")
	assert_eq(int(roster[0]["character_id"]), 101, "character_id 取 card_instance_id")
	assert_eq(str(roster[0]["display_name"]), "林渊", "显示名取模板 name")
	assert_eq(int(roster[0]["hp"]), 8, "HP 取 base_hp")
	assert_eq(int(roster[0]["attack"]), 3, "ATK 取 base_attack")
	assert_eq(int(roster[0]["binding_count"]), 2, "绑定数取绑定管理器返回列表长度")
	assert_eq(roster[0]["slot_index"], 0, "slot_index 记录角色位序号")


func test_read_marks_unavailable_characters_as_dead() -> void:
	# Arrange
	_seed_standard_roster()
	# Act
	var roster: Array = RosterReader.read(gsm, cards, deployment, binding)
	# Assert: 102 在不可用列表 → is_dead=true
	assert_true(bool(roster[1]["is_dead"]), "部署系统不可用列表中的角色应标记阵亡")
	assert_eq(int(roster[1]["binding_count"]), 0, "无绑定时角标为 0")


func test_read_preserves_slot_index_of_skipped_positions() -> void:
	# Arrange: 第 4 位（索引 3）才有角色——验证空位不压缩序号
	gsm.deck = {"slots": [null, null, null, 103, null, null]}
	cards.templates[103] = _template("陆青", 7, 5)
	# Act
	var roster: Array = RosterReader.read(gsm, cards, deployment, binding)
	# Assert
	assert_eq(roster.size(), 1, "只有 1 个非空角色位")
	assert_eq(int(roster[0]["slot_index"]), 3, "slot_index 应保留原始位序")


func test_read_copies_faction_tags_not_alias() -> void:
	# Arrange
	_seed_standard_roster()
	var source_tags: Array = cards.templates[101]["faction_tags"]
	# Act
	var roster: Array = RosterReader.read(gsm, cards, deployment, binding)
	# Assert: 返回副本——面板改动不会污染模板
	source_tags.append(&"mutated")
	assert_false(roster[0]["faction_tags"].has(&"mutated"), "阵营标签应为副本而非引用")


func test_read_with_missing_faction_tags_returns_empty_array() -> void:
	# Arrange: 模板无 faction_tags 字段
	gsm.deck = {"slots": [101, null, null, null, null, null]}
	cards.templates[101] = {"name": "林渊", "base_hp": 8, "base_attack": 3}
	# Act
	var roster: Array = RosterReader.read(gsm, cards, deployment, binding)
	# Assert
	assert_eq(roster[0]["faction_tags"], [], "模板缺 faction_tags 时返回空数组")


# ═══════════════════════════════════════════════════════════════════════════════
# 边界：空位 / 非法 ID / 模板解析失败 / 角色位上限
# ═══════════════════════════════════════════════════════════════════════════════

func test_read_skips_null_slots() -> void:
	# Arrange: 全部空位
	gsm.deck = {"slots": [null, null, null, null, null, null]}
	# Act
	var roster: Array = RosterReader.read(gsm, cards, deployment, binding)
	# Assert
	assert_eq(roster.size(), 0, "全空角色位应读出空名册")


func test_read_skips_non_positive_instance_ids() -> void:
	# Arrange: 0 与负数视为空位哨兵
	gsm.deck = {"slots": [0, -5, null, null, null, null]}
	cards.templates[0] = _template("不该出现", 1, 1)
	# Act
	var roster: Array = RosterReader.read(gsm, cards, deployment, binding)
	# Assert
	assert_eq(roster.size(), 0, "非正实例 ID 应跳过（含模板存在的情况）")


func test_read_skips_slots_with_unresolvable_template() -> void:
	# Arrange: 102 无模板（卡牌系统解析失败）
	gsm.deck = {"slots": [101, 102, null, null, null, null]}
	cards.templates[101] = _template("林渊", 8, 3)
	# Act
	var roster: Array = RosterReader.read(gsm, cards, deployment, binding)
	# Assert: 解析失败者跳过，其余保留
	assert_eq(roster.size(), 1, "模板解析失败的槽位应跳过")
	assert_eq(int(roster[0]["character_id"]), 101, "保留可解析的角色")


func test_read_ignores_slots_beyond_character_slot_count() -> void:
	# Arrange: 7 个角色位（超出 GDD 的 6 位上限）
	gsm.deck = {"slots": [101, 102, 103, 104, 105, 106, 107]}
	for id: int in range(101, 108):
		cards.templates[id] = _template("角色%d" % id, 5, 2)
	# Act
	var roster: Array = RosterReader.read(gsm, cards, deployment, binding)
	# Assert: 只读前 CHARACTER_SLOT_COUNT 位
	assert_eq(roster.size(), RosterReader.CHARACTER_SLOT_COUNT,
			"超出的角色位不应读取")
	assert_eq(int(roster[roster.size() - 1]["character_id"]), 106,
			"第 6 位（索引 5）应仍是最后一个")


func test_read_supports_deck_object_carrier() -> void:
	# Arrange: deck 以对象承载（域对象形态）而非字典——槽位是脚本成员，
	# 经 Object.get("slots") 读取
	var deck_carrier := _DeckCarrier.new()
	deck_carrier.slots = [101, null, null, null, null, null]
	gsm.deck = deck_carrier
	cards.templates[101] = _template("林渊", 8, 3)
	# Act
	var roster: Array = RosterReader.read(gsm, cards, deployment, binding)
	# Assert: 两种承载都应可用
	assert_eq(roster.size(), 1, "deck 为对象承载时应同样读出名册")
	assert_eq(int(roster[0]["character_id"]), 101, "对象承载应读出同一角色")


## deck 对象承载桩——不覆写 Object.get，靠脚本成员 `slots` 暴露字段。
class _DeckCarrier extends RefCounted:
	var slots: Array = []
