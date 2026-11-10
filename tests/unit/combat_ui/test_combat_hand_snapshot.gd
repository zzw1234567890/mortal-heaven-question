extends GutTest
## 战斗手牌 → 手牌区快照（combat-ui-interaction 001 / 本轮）。[br]
## [br][b]背景[/b]：生产路径下此前无人给手牌区供牌（[code]hand_changed[/code] 无发射方），
## 真实对局的手牌永远是空的。本文件锁定三种历史条目形态的折出、目标词透传与降级。

const Snapshot := preload("res://src/ui/combat/shared/combat_hand_snapshot.gd")


## 桩卡牌系统——按实例 ID 返回模板字典。
class CardSystemStub extends RefCounted:
	var templates: Dictionary = {}

	func get_template_by_instance_id(card_instance_id: int) -> Variant:
		return templates.get(card_instance_id)


## 桩模板（Object + get）。
class TemplateStub extends RefCounted:
	var fields: Dictionary = {}

	func _init(p_fields: Dictionary) -> void:
		fields = p_fields

	func get(key: String) -> Variant:
		return fields.get(key)


## 整数条目（旧形态：手牌只存实例 ID）→ 模板字段折出。
func test_int_entry_uses_template_fields() -> void:
	# Arrange
	var card_system: CardSystemStub = CardSystemStub.new()
	card_system.templates[11] = TemplateStub.new({
		"name": "御剑术", "cost": 2, "rarity": 3, "type": 1,
		"target_type": &"single_enemy",
	})
	# Act
	var snapshot: Array = Snapshot.build([11], card_system)
	# Assert
	assert_eq(snapshot.size(), 1, "一条快照")
	assert_eq(int(snapshot[0]["card_instance_id"]), 11, "实例 ID")
	assert_eq(String(snapshot[0]["name"]), "御剑术", "卡名取自模板")
	assert_eq(int(snapshot[0]["cost"]), 2, "费用")
	assert_eq(int(snapshot[0]["rarity"]), 3, "稀有度")
	assert_eq(StringName(str(snapshot[0]["target_type"])), &"single_enemy", "目标词透传")


## 字典条目自带字段优先于模板（测试 / 内联卡）。
func test_dict_entry_prefers_own_fields() -> void:
	var snapshot: Array = Snapshot.build([{
		"card_instance_id": 12, "name": "血杀掌", "cost": 3,
		"target_type": &"multi_enemy",
	}], null)
	assert_eq(String(snapshot[0]["name"]), "血杀掌", "字典自带卡名")
	assert_eq(int(snapshot[0]["cost"]), 3, "字典自带费用")
	assert_eq(StringName(str(snapshot[0]["target_type"])), &"multi_enemy", "字典自带目标词")


## 无模板 / 无名称 → 占位名（不崩、不空串）。
func test_missing_template_falls_back_to_placeholder() -> void:
	var snapshot: Array = Snapshot.build([99], null)
	assert_eq(snapshot.size(), 1, "仍产出条目")
	assert_eq(String(snapshot[0]["name"]), "卡 #99", "占位名")
	assert_eq(StringName(str(snapshot[0]["target_type"])), &"", "目标词缺失 → 空串（未知词）")


## 无实例 ID 的条目被跳过（手牌区无法与选中比对）。
func test_entry_without_id_is_skipped() -> void:
	var snapshot: Array = Snapshot.build([{"name": "无ID"}, "not_a_card"], null)
	assert_eq(snapshot.size(), 0, "无 ID 条目全部跳过")


## 可负担性：0 费恒可出；余额不足为 false。
func test_affordability_flags() -> void:
	var snapshot: Array = [
		{"cost": 0}, {"cost": 2}, {"cost": 5},
	]
	var flags: Array = Snapshot.affordability(snapshot, 3)
	assert_eq(flags, [true, true, false], "0 费可出、2 费可出、5 费不可出")


## 目标词公开入口（交互层取卡面词用）。
func test_target_type_of_entry_and_template() -> void:
	assert_eq(Snapshot.target_type_of({"target_type": &"self"}, null), &"self",
			"条目自带优先")
	assert_eq(Snapshot.target_type_of(5, TemplateStub.new({"target_type": &"all_enemy"})),
			&"all_enemy", "回退模板")
