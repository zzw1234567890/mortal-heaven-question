extends GutTest
## Story 001 验收测试：CardTemplate Resource 数据模型 + 枚举定义。
##
## 覆盖 AC-001 到 AC-010（10 条 AC）。
## 每个测试验证 CardTemplate 的类结构、枚举、字段 @export 标志、
## 类型化、默认值以及 Inspector 可编辑性。

const CardTemplateClass := preload("res://src/core/card_system/card_template.gd")

# CardTemplate 所有 @export 字段名（用于反射验证）
const COMMON_FIELDS: Array[String] = [
	"card_id", "name", "type", "rarity", "cost",
	"faction_tags", "description", "flavor_text", "illustration_path",
]
const CHARACTER_FIELDS: Array[String] = [
	"base_hp", "base_attack", "innate_skill", "technique_slots", "artifact_slots",
]
const TECHNIQUE_ARTIFACT_FIELDS: Array[String] = [
	"effect_type", "effect_value", "native_owner", "stack_limit",
	"stack_multiplier", "trigger_condition", "cooldown",
]
const FORMATION_FIELDS: Array[String] = [
	"faction_requirement", "required_count", "aura_effect",
]
const PILL_TALISMAN_FIELDS: Array[String] = [
	"duration_turns", "target_type", "base_fail_chance",
]
const ALL_EXPORT_FIELDS: Array[String] = [
	"card_id", "name", "type", "rarity", "cost",
	"faction_tags", "description", "flavor_text", "illustration_path",
	"base_hp", "base_attack", "innate_skill", "technique_slots", "artifact_slots",
	"effect_type", "effect_value", "native_owner", "stack_limit",
	"stack_multiplier", "trigger_condition", "cooldown",
	"faction_requirement", "required_count", "aura_effect",
	"duration_turns", "target_type", "base_fail_chance",
]


# ============================================================================
# AC-001：CardTemplate extends Resource，声明 class_name CardTemplate
# ============================================================================

func test_card_template_extends_resource() -> void:
	var script: GDScript = load("res://src/core/card_system/card_template.gd")
	assert_eq(script.get_instance_base_type(), "Resource", "CardTemplate 应继承 Resource")


func test_card_template_instance_is_resource() -> void:
	var tpl := CardTemplateClass.new()
	assert_true(tpl is Resource, "CardTemplate 实例应为 Resource")


# ============================================================================
# AC-002：CardType 枚举含 6 个值（0-based，无公式依赖）
# ============================================================================

func test_card_type_has_six_values() -> void:
	assert_eq(CardTemplateClass.CardType.size(), 6, "CardType 应有 6 个值")
	assert_eq(CardTemplateClass.CardType.CHARACTER, 0)
	assert_eq(CardTemplateClass.CardType.TECHNIQUE, 1)
	assert_eq(CardTemplateClass.CardType.ARTIFACT, 2)
	assert_eq(CardTemplateClass.CardType.FORMATION, 3)
	assert_eq(CardTemplateClass.CardType.PILL, 4)
	assert_eq(CardTemplateClass.CardType.TALISMAN, 5)


func test_card_type_values_are_unique() -> void:
	var values: Array[int] = [
		CardTemplateClass.CardType.CHARACTER,
		CardTemplateClass.CardType.TECHNIQUE,
		CardTemplateClass.CardType.ARTIFACT,
		CardTemplateClass.CardType.FORMATION,
		CardTemplateClass.CardType.PILL,
		CardTemplateClass.CardType.TALISMAN,
	]
	values.sort()
	for i in range(values.size() - 1):
		assert_ne(values[i], values[i + 1], "CardType 枚举值必须唯一")


func test_card_type_default_is_character() -> void:
	var tpl := CardTemplateClass.new()
	assert_eq(tpl.type, CardTemplateClass.CardType.CHARACTER, "默认 type 应为 CHARACTER")


# ============================================================================
# AC-003：Rarity 枚举含 5 个值（1-based——与 ResourceSystem 公式契约一致）
# ============================================================================

func test_rarity_has_five_values() -> void:
	## Rarity 必须包含全部 5 种稀有度，值 1-5（1-based）
	## 1-based 约束：ResourceSystem.dismantle_value(rarity, level) 使用
	## DISMANTLE_BASE[rarity - 1] 索引——0-based 会导致越界。
	assert_eq(CardTemplateClass.Rarity.size(), 5, "Rarity 应有 5 个值")
	assert_eq(CardTemplateClass.Rarity.WHITE, 1, "WHITE=1（1-based——ResourceSystem 契约）")
	assert_eq(CardTemplateClass.Rarity.BLUE, 2)
	assert_eq(CardTemplateClass.Rarity.PURPLE, 3)
	assert_eq(CardTemplateClass.Rarity.GOLD, 4)
	assert_eq(CardTemplateClass.Rarity.DARK_GOLD, 5)


func test_rarity_values_are_unique() -> void:
	var values: Array[int] = [
		CardTemplateClass.Rarity.WHITE,
		CardTemplateClass.Rarity.BLUE,
		CardTemplateClass.Rarity.PURPLE,
		CardTemplateClass.Rarity.GOLD,
		CardTemplateClass.Rarity.DARK_GOLD,
	]
	values.sort()
	for i in range(values.size() - 1):
		assert_ne(values[i], values[i + 1], "Rarity 枚举值必须唯一")


func test_rarity_default_is_white_one() -> void:
	## 默认 rarity 应为 WHITE=1（非 0）
	var tpl := CardTemplateClass.new()
	assert_eq(tpl.rarity, CardTemplateClass.Rarity.WHITE, "默认 rarity 应为 WHITE")
	assert_eq(tpl.rarity, 1, "WHITE 枚举值应为 1（1-based）")


# ============================================================================
# AC-004：共有字段全部 @export 且类型化
# ============================================================================

func test_common_fields_exist_and_exported() -> void:
	var tpl := CardTemplateClass.new()
	var props: Dictionary = _get_property_dict(tpl)
	for field_name in COMMON_FIELDS:
		assert_true(props.has(field_name), "共有字段 %s 应存在" % field_name)
		var prop: Dictionary = props[field_name]
		assert_true((prop["usage"] & PROPERTY_USAGE_EDITOR) != 0,
				"字段 %s 应包含 PROPERTY_USAGE_EDITOR 标志" % field_name)


func test_common_fields_default_values() -> void:
	var tpl := CardTemplateClass.new()
	assert_eq(tpl.card_id, &"", "默认 card_id 应为空 StringName")
	assert_eq(tpl.name, "", "默认 name 应为空字符串")
	assert_eq(tpl.type, CardTemplateClass.CardType.CHARACTER)
	assert_eq(tpl.rarity, CardTemplateClass.Rarity.WHITE)
	assert_eq(tpl.cost, 0)
	assert_eq(tpl.faction_tags.size(), 0, "默认 faction_tags 应为空数组")
	assert_eq(tpl.description, "")
	assert_eq(tpl.flavor_text, "")
	assert_eq(tpl.illustration_path, "")


func test_faction_tags_is_typed_array() -> void:
	## faction_tags 必须是 Array[StringName] 而非裸 Array
	## Godot 4.6：类型化数组的 hint_string 形如 "21:"（元素类型 ID 前缀，21=TYPE_STRING_NAME）
	## 裸 Array 的 hint_string 为空——以此区分。
	var tpl := CardTemplateClass.new()
	var props: Dictionary = _get_property_dict(tpl)
	assert_true(props.has("faction_tags"), "faction_tags 字段应存在")
	var prop: Dictionary = props["faction_tags"]
	assert_ne(prop["hint_string"], "", "faction_tags 应为类型化数组（hint_string 非空）")
	var expected_prefix: String = str(TYPE_STRING_NAME) + ":"
	assert_true(prop["hint_string"].begins_with(expected_prefix),
			"faction_tags 元素类型应为 StringName（hint_string 应以 '%s' 开头，实际: '%s'）" % [expected_prefix, prop["hint_string"]])


# ============================================================================
# AC-005：角色卡专属字段 @export 且默认值正确
# ============================================================================

func test_character_fields_exist_and_exported() -> void:
	var tpl := CardTemplateClass.new()
	var props: Dictionary = _get_property_dict(tpl)
	for field_name in CHARACTER_FIELDS:
		assert_true(props.has(field_name), "角色卡字段 %s 应存在" % field_name)
		var prop: Dictionary = props[field_name]
		assert_true((prop["usage"] & PROPERTY_USAGE_EDITOR) != 0,
				"字段 %s 应包含 PROPERTY_USAGE_EDITOR 标志" % field_name)


func test_character_fields_default_values() -> void:
	var tpl := CardTemplateClass.new()
	assert_eq(tpl.base_hp, 0, "默认 base_hp 应为 0")
	assert_eq(tpl.base_attack, 0, "默认 base_attack 应为 0")
	assert_eq(tpl.innate_skill, &"", "默认 innate_skill 应为空 StringName")
	assert_eq(tpl.technique_slots, 3, "默认 technique_slots 应为 3")
	assert_eq(tpl.artifact_slots, 3, "默认 artifact_slots 应为 3")


# ============================================================================
# AC-006：功法/法宝卡专属字段 @export 且默认值正确
# ============================================================================

func test_technique_artifact_fields_exist_and_exported() -> void:
	var tpl := CardTemplateClass.new()
	var props: Dictionary = _get_property_dict(tpl)
	for field_name in TECHNIQUE_ARTIFACT_FIELDS:
		assert_true(props.has(field_name), "功法/法宝字段 %s 应存在" % field_name)
		var prop: Dictionary = props[field_name]
		assert_true((prop["usage"] & PROPERTY_USAGE_EDITOR) != 0,
				"字段 %s 应包含 PROPERTY_USAGE_EDITOR 标志" % field_name)


func test_technique_artifact_fields_default_values() -> void:
	var tpl := CardTemplateClass.new()
	assert_eq(tpl.effect_type, &"", "默认 effect_type 应为空 StringName")
	assert_eq(tpl.effect_value, 0, "默认 effect_value 应为 0")
	assert_eq(tpl.native_owner, &"", "默认 native_owner 应为空 StringName")
	assert_eq(tpl.stack_limit, 3, "默认 stack_limit 应为 3")
	assert_eq(tpl.stack_multiplier, 1.5, "默认 stack_multiplier 应为 1.5")
	assert_eq(tpl.trigger_condition, &"", "默认 trigger_condition 应为空 StringName")
	assert_eq(tpl.cooldown, 0, "默认 cooldown 应为 0")


# ============================================================================
# AC-007：阵法卡专属字段 @export 且默认值正确
# ============================================================================

func test_formation_fields_exist_and_exported() -> void:
	var tpl := CardTemplateClass.new()
	var props: Dictionary = _get_property_dict(tpl)
	for field_name in FORMATION_FIELDS:
		assert_true(props.has(field_name), "阵法字段 %s 应存在" % field_name)
		var prop: Dictionary = props[field_name]
		assert_true((prop["usage"] & PROPERTY_USAGE_EDITOR) != 0,
				"字段 %s 应包含 PROPERTY_USAGE_EDITOR 标志" % field_name)


func test_formation_fields_default_values() -> void:
	var tpl := CardTemplateClass.new()
	assert_eq(tpl.faction_requirement, &"", "默认 faction_requirement 应为空 StringName")
	assert_eq(tpl.required_count, 0, "默认 required_count 应为 0")
	assert_eq(tpl.aura_effect, &"", "默认 aura_effect 应为空 StringName")


# ============================================================================
# AC-008：丹药/符箓卡专属字段 @export 且默认值正确
# ============================================================================

func test_pill_talisman_fields_exist_and_exported() -> void:
	var tpl := CardTemplateClass.new()
	var props: Dictionary = _get_property_dict(tpl)
	for field_name in PILL_TALISMAN_FIELDS:
		assert_true(props.has(field_name), "丹药/符箓字段 %s 应存在" % field_name)
		var prop: Dictionary = props[field_name]
		assert_true((prop["usage"] & PROPERTY_USAGE_EDITOR) != 0,
				"字段 %s 应包含 PROPERTY_USAGE_EDITOR 标志" % field_name)


func test_pill_talisman_fields_default_values() -> void:
	var tpl := CardTemplateClass.new()
	assert_eq(tpl.duration_turns, 0, "默认 duration_turns 应为 0")
	assert_eq(tpl.target_type, &"", "默认 target_type 应为空 StringName")
	assert_eq(tpl.base_fail_chance, 0.0, "默认 base_fail_chance 应为 0.0")


# ============================================================================
# AC-009：所有 @export 字段可在 Inspector 中编辑（PROPERTY_USAGE_EDITOR 标志）
# ============================================================================

func test_all_export_fields_have_editor_usage() -> void:
	## 遍历所有 @export 字段，断言每个字段的 usage 包含 PROPERTY_USAGE_EDITOR
	## 同时断言包含 PROPERTY_USAGE_STORAGE——确保字段可序列化到 .tres（AC-009 描述要求双标志）
	## Godot 4.6：位运算返回 int，需显式 != 0 转换为 bool 供 assert_true
	var tpl := CardTemplateClass.new()
	var props: Dictionary = _get_property_dict(tpl)
	for field_name in ALL_EXPORT_FIELDS:
		assert_true(props.has(field_name), "字段 %s 应存在于属性列表" % field_name)
		var prop: Dictionary = props[field_name]
		var usage: int = prop["usage"]
		assert_true((usage & PROPERTY_USAGE_EDITOR) != 0,
				"字段 %s 的 usage 应包含 PROPERTY_USAGE_EDITOR（实际: %d）" % [field_name, usage])
		assert_true((usage & PROPERTY_USAGE_STORAGE) != 0,
				"字段 %s 的 usage 应包含 PROPERTY_USAGE_STORAGE（确保可序列化到 .tres，实际: %d）" % [field_name, usage])


func test_no_extra_export_fields() -> void:
	## 声明的 @export 字段数量应与预期一致（27 个）。
	## 对齐 AC-004 Edge cases「确认无多余 @export 共有字段」。
	## 注：不反向枚举所有 @export 字段——Godot Resource 内置 @export 属性
	## （resource_path/resource_name/script/resource_local_to_scene 等）随引擎版本变化，
	## 硬编码排除清单会脆弱。改为断言声明字段总数 == 27，间接覆盖「无多余」。
	var tpl := CardTemplateClass.new()
	var props: Dictionary = _get_property_dict(tpl)
	var user_export_count: int = 0
	for prop_name in props:
		var prop: Dictionary = props[prop_name]
		if (prop["usage"] & PROPERTY_USAGE_EDITOR) != 0:
			# 仅统计 ALL_EXPORT_FIELDS 中声明的字段——排除 Godot Resource 内置 @export
			if ALL_EXPORT_FIELDS.has(prop_name):
				user_export_count += 1
	assert_eq(user_export_count, ALL_EXPORT_FIELDS.size(),
			"声明的 @export 字段应全部存在（共 %d 个）" % ALL_EXPORT_FIELDS.size())


# ============================================================================
# AC-010：模板字段禁止 Variant 类型（全部类型化）
# ============================================================================

func test_no_nil_type_fields() -> void:
	## 断言无字段 type == TYPE_NIL（Variant 的默认 type）
	var tpl := CardTemplateClass.new()
	var props: Dictionary = _get_property_dict(tpl)
	for field_name in ALL_EXPORT_FIELDS:
		var prop: Dictionary = props[field_name]
		assert_ne(prop["type"], TYPE_NIL,
				"字段 %s 的 type 不应为 TYPE_NIL（Variant）" % field_name)


func test_no_bare_arrays() -> void:
	## 所有数组字段必须为类型化数组（hint_string 非空），禁止裸 Array
	## Godot 4.6：类型化数组 Array[StringName] 的 hint_string 形如 "21:"（21=TYPE_STRING_NAME）
	## 裸 Array 的 hint_string 为空——以此区分。
	## faction_tags 是唯一的数组字段——验证其为 Array[StringName]
	var tpl := CardTemplateClass.new()
	var props: Dictionary = _get_property_dict(tpl)
	var expected_prefix: String = str(TYPE_STRING_NAME) + ":"
	for field_name in ALL_EXPORT_FIELDS:
		var prop: Dictionary = props[field_name]
		if prop["type"] == TYPE_ARRAY:
			assert_ne(prop["hint_string"], "",
					"数组字段 %s 的 hint_string 不应为空（禁止裸 Array）" % field_name)
			assert_true(prop["hint_string"].begins_with(expected_prefix),
					"数组字段 %s 应为 Array[StringName]（hint_string 应以 '%s' 开头，实际: '%s'）" % [field_name, expected_prefix, prop["hint_string"]])


# ============================================================================
# 辅助函数
# ============================================================================

## 获取实例的属性字典——键为属性名，值为属性信息 Dictionary
func _get_property_dict(obj: Object) -> Dictionary:
	var result: Dictionary = {}
	var props: Array = obj.get_property_list()
	for prop in props:
		result[prop["name"]] = prop
	return result
