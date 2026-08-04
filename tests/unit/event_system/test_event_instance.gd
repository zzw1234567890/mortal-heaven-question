extends GutTest
## Story 002 AC-021：EventInstance 不持有 Resource 引用验证。
##
## 验证 EventInstance 仅存储 template_id: StringName 和 available_option_indices: Array[int]，
## 而非任何 Resource 引用（ADR-0003 决策 2 合规）。

const EventInstanceClass := preload("res://src/foundation/event_system/event_instance.gd")


# ============================================================================
# AC-021：EventInstance 不持有任何 Resource 引用
# ============================================================================

func test_ac021_instance_has_no_resource_references() -> void:
	# Arrange
	var instance := EventInstanceClass.new()

	# Assert: 所有字段均为值类型或基础容器类型——非 Resource
	assert_eq(typeof(instance.template_id), TYPE_STRING_NAME, "template_id 应为 StringName")
	assert_eq(typeof(instance.available_option_indices), TYPE_ARRAY, "available_option_indices 应为 Array")
	assert_eq(typeof(instance.all_options_hidden), TYPE_BOOL, "all_options_hidden 应为 bool")
	assert_eq(typeof(instance.chain_depth), TYPE_INT, "chain_depth 应为 int")
	assert_eq(typeof(instance.selected_option_index), TYPE_INT, "selected_option_index 应为 int")
	assert_eq(typeof(instance.resolved_outcomes), TYPE_ARRAY, "resolved_outcomes 应为 Array")


func test_ac021_available_option_indices_is_int_array() -> void:
	# Arrange
	var instance := EventInstanceClass.new()
	instance.available_option_indices = [0, 2, 3]

	# Assert
	assert_eq(instance.available_option_indices.size(), 3)
	for idx in instance.available_option_indices:
		assert_eq(typeof(idx), TYPE_INT, "每个选项索引应为 int")


func test_ac021_template_id_is_string_name_not_resource() -> void:
	# Arrange
	var instance := EventInstanceClass.new()
	instance.template_id = &"test_event_001"

	# Assert
	assert_eq(instance.template_id, &"test_event_001")
	assert_eq(typeof(instance.template_id), TYPE_STRING_NAME)


func test_ac021_default_values() -> void:
	# Arrange
	var instance := EventInstanceClass.new()

	# Assert
	assert_eq(instance.template_id, &"")
	assert_eq(instance.available_option_indices.size(), 0)
	assert_eq(instance.all_options_hidden, false)
	assert_eq(instance.chain_depth, 0)
	assert_eq(instance.selected_option_index, -1)
	assert_eq(instance.resolved_outcomes.size(), 0)


func test_ac021_resolved_outcomes_is_dictionary_array() -> void:
	# Arrange
	var instance := EventInstanceClass.new()
	var outcome: Dictionary = {
		"triggered": true,
		"type": 0,
		"target": "ling_shi",
		"value": 50,
		"value_str": "",
	}
	instance.resolved_outcomes = [outcome]

	# Assert
	assert_eq(instance.resolved_outcomes.size(), 1)
	assert_eq(typeof(instance.resolved_outcomes[0]), TYPE_DICTIONARY)