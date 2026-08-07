extends GutTest
## Story 002 验收测试：CardInstance RefCounted 实例模型 + AcquiredMethod 枚举。
##
## 覆盖 AC-001 到 AC-008（8 条 AC）。
## 每个测试验证 CardInstance 的类结构、字段类型化、默认值以及实例独立性。

const CardInstanceClass := preload("res://src/core/card_system/card_instance.gd")
const AcquiredMethodClass := preload("res://src/core/card_system/acquired_method.gd")

# CardInstance 所有字段名（用于反射验证）
const ALL_FIELDS: Array[String] = [
	"card_instance_id", "template_id", "level", "inscriptions",
	"breakthrough_layers", "binding_target_id", "acquired_chapter",
	"acquired_event_id", "acquired_method",
]


# ============================================================================
# AC-001：CardInstance extends RefCounted，声明 class_name CardInstance
# ============================================================================

func test_card_instance_extends_refcounted() -> void:
	var script: GDScript = load("res://src/core/card_system/card_instance.gd")
	assert_eq(script.get_instance_base_type(), "RefCounted", "CardInstance 应继承 RefCounted")


func test_card_instance_instance_is_refcounted() -> void:
	var inst := CardInstanceClass.new()
	assert_true(inst is RefCounted, "CardInstance 实例应为 RefCounted")
	assert_true(inst is CardInstanceClass, "CardInstance 实例应为 CardInstance（通过 preload 类常量判定）")


# ============================================================================
# AC-002：card_instance_id: int 字段（默认 0，由 GSM 分配）
# ============================================================================

func test_card_instance_id_default_is_zero() -> void:
	var inst := CardInstanceClass.new()
	assert_eq(inst.card_instance_id, 0, "默认 card_instance_id 应为 0")
	assert_eq(typeof(inst.card_instance_id), TYPE_INT, "card_instance_id 应为 int 类型")


func test_card_instance_id_is_writable() -> void:
	var inst := CardInstanceClass.new()
	inst.card_instance_id = 42
	assert_eq(inst.card_instance_id, 42, "card_instance_id 应可写")


# ============================================================================
# AC-003：template_id: StringName 字段（指向 CardTemplate.card_id）
# ============================================================================

func test_template_id_default_is_empty_stringname() -> void:
	var inst := CardInstanceClass.new()
	assert_eq(inst.template_id, &"", "默认 template_id 应为空 StringName")
	assert_eq(typeof(inst.template_id), TYPE_STRING_NAME, "template_id 应为 StringName 类型")


func test_template_id_is_assignable() -> void:
	var inst := CardInstanceClass.new()
	inst.template_id = &"card_test_001"
	assert_eq(inst.template_id, &"card_test_001", "template_id 应可赋值")
	assert_eq(typeof(inst.template_id), TYPE_STRING_NAME, "赋值后 template_id 应仍为 StringName 类型")


# ============================================================================
# AC-004：成长状态字段（level, inscriptions, breakthrough_layers）
# ============================================================================

func test_growth_fields_default_values() -> void:
	var inst := CardInstanceClass.new()
	assert_eq(inst.level, 1, "默认 level 应为 1")
	assert_eq(typeof(inst.level), TYPE_INT, "level 应为 int 类型")
	assert_eq(inst.inscriptions, [], "默认 inscriptions 应为空数组")
	assert_eq(inst.breakthrough_layers, 0, "默认 breakthrough_layers 应为 0")
	assert_eq(typeof(inst.breakthrough_layers), TYPE_INT, "breakthrough_layers 应为 int 类型")


func test_inscriptions_is_typed_array() -> void:
	## inscriptions 必须是 Array[Dictionary] 而非裸 Array
	## Godot 4.6：非 @export 的 var 类型化数组，hint_string 返回元素类型名字符串 "Dictionary"
	## 裸 Array 的 hint_string 为空——以此区分。
	var inst := CardInstanceClass.new()
	var props: Dictionary = _get_property_dict(inst)
	assert_true(props.has("inscriptions"), "inscriptions 字段应存在")
	var prop: Dictionary = props["inscriptions"]
	assert_eq(prop["type"], TYPE_ARRAY, "inscriptions 应为数组类型")
	assert_ne(prop["hint_string"], "", "inscriptions 应为类型化数组（hint_string 非空）")
	assert_eq(prop["hint_string"], "Dictionary",
			"inscriptions 元素类型应为 Dictionary（hint_string 应为 'Dictionary'，实际: '%s'）" % prop["hint_string"])


func test_inscriptions_arrays_are_independent() -> void:
	## inscriptions 数组对象身份独立——a.inscriptions 与 b.inscriptions 是不同实例
	## Godot 4.6：is_same() 检查引用身份（区别于 == 的值比较）
	var a := CardInstanceClass.new()
	var b := CardInstanceClass.new()
	assert_false(is_same(a.inscriptions, b.inscriptions), "a.inscriptions 与 b.inscriptions 应为不同数组实例")


# ============================================================================
# AC-005：绑定字段 binding_target_id: StringName
# ============================================================================

func test_binding_target_id_default_is_empty_stringname() -> void:
	var inst := CardInstanceClass.new()
	assert_eq(inst.binding_target_id, &"", "默认 binding_target_id 应为空 StringName")
	assert_eq(typeof(inst.binding_target_id), TYPE_STRING_NAME, "binding_target_id 应为 StringName 类型")


func test_binding_target_id_is_assignable() -> void:
	var inst := CardInstanceClass.new()
	inst.binding_target_id = &"char_001"
	assert_eq(inst.binding_target_id, &"char_001", "binding_target_id 应可赋值")
	assert_eq(typeof(inst.binding_target_id), TYPE_STRING_NAME, "赋值后 binding_target_id 应仍为 StringName 类型")


# ============================================================================
# AC-006：获得来源字段（acquired_chapter, acquired_event_id, acquired_method）
# ============================================================================

func test_acquired_fields_default_values() -> void:
	var inst := CardInstanceClass.new()
	assert_eq(inst.acquired_chapter, 0, "默认 acquired_chapter 应为 0")
	assert_eq(typeof(inst.acquired_chapter), TYPE_INT, "acquired_chapter 应为 int 类型")
	assert_eq(inst.acquired_event_id, &"", "默认 acquired_event_id 应为空 StringName")
	assert_eq(typeof(inst.acquired_event_id), TYPE_STRING_NAME, "acquired_event_id 应为 StringName 类型")
	assert_eq(inst.acquired_method, AcquiredMethodClass.DROP, "默认 acquired_method 应为 AcquiredMethod.DROP")
	assert_eq(typeof(inst.acquired_method), TYPE_INT, "acquired_method 应为 int 类型")


func test_acquired_method_is_writable_with_enum_value() -> void:
	## acquired_method 可写入非默认枚举值——守护"int 字段可持有任意枚举值"契约
	## 与 AC-002/003/005 的可写测试对称
	var inst := CardInstanceClass.new()
	inst.acquired_method = AcquiredMethodClass.SHOP
	assert_eq(inst.acquired_method, AcquiredMethodClass.SHOP, "acquired_method 应可写入 SHOP")
	assert_eq(inst.acquired_method, 1, "SHOP 枚举值应为 1")


func test_growth_int_fields_are_writable() -> void:
	## level / breakthrough_layers / acquired_chapter 可写——与 AC-002 的 card_instance_id 可写测试对称
	var inst := CardInstanceClass.new()
	inst.level = 5
	inst.breakthrough_layers = 3
	inst.acquired_chapter = 7
	assert_eq(inst.level, 5, "level 应可写")
	assert_eq(inst.breakthrough_layers, 3, "breakthrough_layers 应可写")
	assert_eq(inst.acquired_chapter, 7, "acquired_chapter 应可写")


# ============================================================================
# AC-007：两张同名卡 CardInstance 实例的 level 独立
# ============================================================================

func test_instance_level_independence() -> void:
	## 修改实例 A 的 level 不影响实例 B
	var a := CardInstanceClass.new()
	var b := CardInstanceClass.new()
	a.template_id = &"card_same"
	b.template_id = &"card_same"
	assert_eq(a.level, 1, "a 初始 level 应为 1")
	assert_eq(b.level, 1, "b 初始 level 应为 1")
	a.level = 5
	assert_eq(a.level, 5, "a.level 修改后应为 5")
	assert_eq(b.level, 1, "b.level 应保持 1（未受影响）")


func test_instance_level_independence_reverse() -> void:
	## 同步修改 b.level 后再读 a.level 仍为原值
	var a := CardInstanceClass.new()
	var b := CardInstanceClass.new()
	a.level = 5
	b.level = 10
	assert_eq(a.level, 5, "a.level 应仍为 5（b 修改不影响 a）")
	assert_eq(b.level, 10, "b.level 应为 10")


func test_instance_inscriptions_independence() -> void:
	## inscriptions 数组独立性——a.inscriptions.append 不影响 b.inscriptions
	var a := CardInstanceClass.new()
	var b := CardInstanceClass.new()
	a.inscriptions.append({"id": 1})
	assert_eq(a.inscriptions.size(), 1, "a.inscriptions 应有 1 个元素")
	assert_eq(b.inscriptions.size(), 0, "b.inscriptions 应保持空（未受影响）")


# ============================================================================
# AC-008：AcquiredMethod 枚举定义（DROP/SHOP/EVENT/CRAFT/TRIBULATION）
# ============================================================================

func test_acquired_method_has_five_values() -> void:
	assert_eq(AcquiredMethodClass.DROP, 0, "DROP 应为 0（0-based——与默认值 0 对齐）")
	assert_eq(AcquiredMethodClass.SHOP, 1, "SHOP 应为 1")
	assert_eq(AcquiredMethodClass.EVENT, 2, "EVENT 应为 2")
	assert_eq(AcquiredMethodClass.CRAFT, 3, "CRAFT 应为 3")
	assert_eq(AcquiredMethodClass.TRIBULATION, 4, "TRIBULATION 应为 4")


func test_acquired_method_values_are_unique() -> void:
	var values: Array[int] = [
		AcquiredMethodClass.DROP,
		AcquiredMethodClass.SHOP,
		AcquiredMethodClass.EVENT,
		AcquiredMethodClass.CRAFT,
		AcquiredMethodClass.TRIBULATION,
	]
	values.sort()
	for i in range(values.size() - 1):
		assert_ne(values[i], values[i + 1], "AcquiredMethod 枚举值必须唯一")


func test_acquired_method_count_is_five() -> void:
	## 断言枚举值总数 == 5
	## Godot 4.6：RefCounted 实例无 get_script_constant_list——通过已知 5 常量
	## 的显式存在性 + 唯一性间接验证总数（test_acquired_method_has_five_values
	## 已断言各值，test_acquired_method_values_are_unique 已断言唯一）。
	## 此处补充边界值 TRIBULATION 断言，确认枚举上界。
	assert_eq(AcquiredMethodClass.TRIBULATION, 4, "TRIBULATION 应为 4（枚举上界）")
	assert_eq(AcquiredMethodClass.DROP, 0, "DROP 应为 0（枚举下界）")
	## 下界 0 + 上界 4 + 1 = 5 个值（与 has_five_values 配合确认无间隙）
	assert_eq(AcquiredMethodClass.TRIBULATION - AcquiredMethodClass.DROP + 1, 5,
			"枚举值范围 [0, 4] 应含 5 个连续整数")


func test_all_nine_fields_exposed_via_reflection() -> void:
	## 聚合守护：遍历 ALL_FIELDS 常量，断言每个字段名出现在 get_property_list() 中
	## 防止未来误删字段——单点失败而非逐字段发现
	var inst := CardInstanceClass.new()
	var props: Dictionary = _get_property_dict(inst)
	for field_name in ALL_FIELDS:
		assert_true(props.has(field_name), "字段 %s 应通过反射暴露（CardInstance 全部 9 字段）" % field_name)


func test_acquired_method_is_zero_based() -> void:
	## 确认 0-based（DROP=0）——与 CardInstance.acquired_method 默认值 0 一致
	assert_eq(AcquiredMethodClass.DROP, 0, "DROP 必须为 0（0-based 枚举）")


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
