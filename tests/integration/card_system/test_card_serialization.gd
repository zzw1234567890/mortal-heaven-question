extends GutTest
## Story 005 验收测试：实例序列化/反序列化 + reconstitute_instances。
##
## 覆盖 AC-001 到 AC-009（9 条 AC）。
## 测试策略：
##   - CS_SCRIPT.new() 构造 CardSystem 实例（不调 _ready，不走异步加载）
##   - 直接注入 fixture 模板到 cs.templates（AC-006 依赖）
##   - 构造完整 CardInstance 作为序列化输入，验证往返保真
##   - 边界值：INT_MAX、空数组、1000 元素、缺失字段、类型不匹配
##   - 动态分派：var cs: Node 持有，返回值显式类型注解（控制清单 2026-08-05 规则）

const CS_SCRIPT := preload("res://src/core/card_system/card_system.gd")
const CardTemplateClass := preload("res://src/core/card_system/card_template.gd")
const CardInstanceClass := preload("res://src/core/card_system/card_instance.gd")
const AcquiredMethodClass := preload("res://src/core/card_system/acquired_method.gd")

var cs: Node = null


func before_each() -> void:
	cs = CS_SCRIPT.new()


func after_each() -> void:
	if cs != null:
		cs.free()
		cs = null


## 构造一个完整填充的 CardInstance（9 字段均赋值）。
func _make_full_instance() -> CardInstanceClass:
	var inst: CardInstanceClass = CardInstanceClass.new()
	inst.card_instance_id = 42
	inst.template_id = &"card_s"
	inst.level = 3
	inst.inscriptions = [{"id": 1, "attr": "atk"}, {"id": 2, "attr": "def"}]
	inst.breakthrough_layers = 2
	inst.binding_target_id = &"char_x"
	inst.acquired_chapter = 5
	inst.acquired_event_id = &"evt_1"
	inst.acquired_method = AcquiredMethodClass.SHOP
	return inst


## 注入一个测试模板到 cs.templates（AC-006 依赖）。
func _inject_template(card_id: StringName) -> void:
	var tmpl: CardTemplateClass = CardTemplateClass.new()
	tmpl.card_id = card_id
	cs.templates[card_id] = tmpl


# ============================================================================
# AC-001：serialize_instance 返回含全部 9 字段的 Dictionary
# ============================================================================

func test_ac001_serialize_instance_returns_nine_fields() -> void:
	var inst: CardInstanceClass = _make_full_instance()
	var d: Dictionary = cs.serialize_instance(inst)
	assert_eq(d.size(), 9, "序列化结果应含 9 个字段")
	# 9 个键均存在
	for key: String in ["card_instance_id", "template_id", "level", "inscriptions",
			"breakthrough_layers", "binding_target_id", "acquired_chapter",
			"acquired_event_id", "acquired_method"]:
		assert_true(d.has(key), "应含字段 '%s'" % key)
	# 确认无多余键
	assert_eq(d.size(), 9, "不应有多余键")


func test_ac001_serialize_instance_field_values() -> void:
	var inst: CardInstanceClass = _make_full_instance()
	var d: Dictionary = cs.serialize_instance(inst)
	assert_eq(d["card_instance_id"], 42, "card_instance_id 应正确")
	assert_eq(d["template_id"], &"card_s", "template_id 应正确")
	assert_eq(d["level"], 3, "level 应正确")
	assert_eq(d["breakthrough_layers"], 2, "breakthrough_layers 应正确")
	assert_eq(d["binding_target_id"], &"char_x", "binding_target_id 应正确")
	assert_eq(d["acquired_chapter"], 5, "acquired_chapter 应正确")
	assert_eq(d["acquired_event_id"], &"evt_1", "acquired_event_id 应正确")
	assert_eq(d["acquired_method"], AcquiredMethodClass.SHOP, "acquired_method 应正确")
	# inscriptions 序列化为 Array
	assert_true(d["inscriptions"] is Array, "inscriptions 应为 Array")
	assert_eq(d["inscriptions"].size(), 2, "inscriptions 应有 2 个元素")


# ============================================================================
# AC-002：deserialize_instance 恢复全部 9 字段
# ============================================================================

func test_ac002_deserialize_instance_restores_all_fields() -> void:
	var inst: CardInstanceClass = _make_full_instance()
	var d: Dictionary = cs.serialize_instance(inst)
	var inst2: CardInstanceClass = cs.deserialize_instance(d)
	assert_not_null(inst2, "反序列化应返回非 null 实例")
	if inst2 == null:
		return
	assert_eq(inst2.card_instance_id, 42, "card_instance_id 应恢复")
	assert_eq(inst2.template_id, &"card_s", "template_id 应恢复")
	assert_eq(inst2.level, 3, "level 应恢复")
	assert_eq(inst2.breakthrough_layers, 2, "breakthrough_layers 应恢复")
	assert_eq(inst2.binding_target_id, &"char_x", "binding_target_id 应恢复")
	assert_eq(inst2.acquired_chapter, 5, "acquired_chapter 应恢复")
	assert_eq(inst2.acquired_event_id, &"evt_1", "acquired_event_id 应恢复")
	assert_eq(inst2.acquired_method, AcquiredMethodClass.SHOP, "acquired_method 应恢复")
	assert_eq(inst2.inscriptions.size(), 2, "inscriptions 应恢复 2 个元素")


func test_ac002_deserialize_inscriptions_deep_copy() -> void:
	# inscriptions 数组元素深拷贝——修改反序列化后的数组不影响原 Dictionary
	var inst: CardInstanceClass = _make_full_instance()
	var d: Dictionary = cs.serialize_instance(inst)
	var inst2: CardInstanceClass = cs.deserialize_instance(d)
	if inst2 == null:
		assert_true(false, "反序列化失败")
		return
	inst2.inscriptions.append({"id": 999})
	assert_eq(d["inscriptions"].size(), 2, "原 Dictionary 的 inscriptions 不应受影响（深拷贝）")


func test_ac002_deserialize_inscriptions_element_deep_copy() -> void:
	# S-H2: 元素级深拷贝——修改 inst2.inscriptions[0] 的嵌套 Dictionary 不影响 d["inscriptions"][0]
	var inst: CardInstanceClass = _make_full_instance()
	var d: Dictionary = cs.serialize_instance(inst)
	var inst2: CardInstanceClass = cs.deserialize_instance(d)
	if inst2 == null:
		assert_true(false, "反序列化失败")
		return
	assert_eq(inst2.inscriptions.size(), 2, "前置：2 个元素")
	# 修改反序列化实例的第一个元素的字段
	inst2.inscriptions[0]["id"] = 9999
	assert_eq(d["inscriptions"][0]["id"], 1, "元素级深拷贝：修改 inst2 元素不应影响原 Dictionary 元素")


func test_ac002_serialize_inscriptions_deep_copy() -> void:
	# S-H1: 序列化方向深拷贝——序列化后修改原 inst.inscriptions 不影响已序列化的 d["inscriptions"]
	var inst: CardInstanceClass = _make_full_instance()
	var d: Dictionary = cs.serialize_instance(inst)
	assert_eq(d["inscriptions"].size(), 2, "前置：序列化后 2 个元素")
	# 修改原实例的 inscriptions
	inst.inscriptions.append({"id": 999})
	assert_eq(d["inscriptions"].size(), 2, "序列化方向深拷贝：修改原 inst 不影响已序列化的 d")
	# 修改原实例的嵌套元素
	inst.inscriptions[0]["id"] = 8888
	assert_eq(d["inscriptions"][0]["id"], 1, "序列化方向元素级深拷贝：修改原 inst 元素不影响 d 元素")


# ============================================================================
# AC-003：deserialize_instance 对 template_id 执行显式 StringName() 转换
# ============================================================================

func test_ac003_deserialize_converts_template_id_to_stringname() -> void:
	# 构造 Dictionary，template_id 为 String 类型（模拟 JSON 反序列化结果）
	var d: Dictionary = {
		"card_instance_id": 1,
		"template_id": "card_s",  # String，非 StringName
		"level": 1,
		"inscriptions": [],
		"breakthrough_layers": 0,
		"binding_target_id": "",
		"acquired_chapter": 0,
		"acquired_event_id": "",
		"acquired_method": 0,
	}
	var inst: CardInstanceClass = cs.deserialize_instance(d)
	assert_not_null(inst, "反序列化应返回非 null")
	if inst == null:
		return
	assert_eq(typeof(inst.template_id), TYPE_STRING_NAME, "template_id 应为 StringName 类型")
	assert_eq(inst.template_id, &"card_s", "template_id 值应正确")


func test_ac003_deserialize_stringname_input_stays_stringname() -> void:
	# template_id 已为 StringName → 仍为 StringName
	var d: Dictionary = {
		"template_id": StringName("card_s"),
	}
	var inst: CardInstanceClass = cs.deserialize_instance(d)
	if inst == null:
		assert_true(false, "反序列化失败")
		return
	assert_eq(typeof(inst.template_id), TYPE_STRING_NAME, "StringName 输入应保持 StringName")


func test_ac003_deserialize_null_template_id_uses_default() -> void:
	# template_id 为 null → AC-007 容错为默认 &""
	var d: Dictionary = {
		"template_id": null,
	}
	var inst: CardInstanceClass = cs.deserialize_instance(d)
	if inst == null:
		assert_true(false, "反序列化失败")
		return
	assert_eq(inst.template_id, &"", "null template_id 应容错为默认 &\"\"")


func test_ac003_deserialize_binding_target_id_string_to_stringname() -> void:
	# S-M3: binding_target_id 经 JSON 往返为 String → 应转换为 StringName
	var d: Dictionary = {
		"binding_target_id": "char_x",  # String
	}
	var inst: CardInstanceClass = cs.deserialize_instance(d)
	if inst == null:
		assert_true(false, "反序列化失败")
		return
	assert_eq(typeof(inst.binding_target_id), TYPE_STRING_NAME, "binding_target_id 应为 StringName 类型")
	assert_eq(inst.binding_target_id, &"char_x", "binding_target_id 值应正确")


func test_ac003_deserialize_acquired_event_id_string_to_stringname() -> void:
	# S-M3: acquired_event_id 经 JSON 往返为 String → 应转换为 StringName
	var d: Dictionary = {
		"acquired_event_id": "evt_1",  # String
	}
	var inst: CardInstanceClass = cs.deserialize_instance(d)
	if inst == null:
		assert_true(false, "反序列化失败")
		return
	assert_eq(typeof(inst.acquired_event_id), TYPE_STRING_NAME, "acquired_event_id 应为 StringName 类型")
	assert_eq(inst.acquired_event_id, &"evt_1", "acquired_event_id 值应正确")


# ============================================================================
# AC-004：serialize → deserialize 往返保留所有字段值
# ============================================================================

func test_ac004_roundtrip_preserves_all_fields() -> void:
	var inst: CardInstanceClass = _make_full_instance()
	var d: Dictionary = cs.serialize_instance(inst)
	var inst2: CardInstanceClass = cs.deserialize_instance(d)
	if inst2 == null:
		assert_true(false, "反序列化失败")
		return
	assert_eq(inst2.card_instance_id, inst.card_instance_id, "card_instance_id 往返保真")
	assert_eq(inst2.template_id, inst.template_id, "template_id 往返保真")
	assert_eq(inst2.level, inst.level, "level 往返保真")
	assert_eq(inst2.breakthrough_layers, inst.breakthrough_layers, "breakthrough_layers 往返保真")
	assert_eq(inst2.binding_target_id, inst.binding_target_id, "binding_target_id 往返保真")
	assert_eq(inst2.acquired_chapter, inst.acquired_chapter, "acquired_chapter 往返保真")
	assert_eq(inst2.acquired_event_id, inst.acquired_event_id, "acquired_event_id 往返保真")
	assert_eq(inst2.acquired_method, inst.acquired_method, "acquired_method 往返保真")
	assert_eq(inst2.inscriptions.size(), inst.inscriptions.size(), "inscriptions 数量保真")


func test_ac004_roundtrip_boundary_values() -> void:
	# 边界值：level=0、inscriptions=空数组、breakthrough_layers=0、card_instance_id=INT_MAX
	var inst: CardInstanceClass = CardInstanceClass.new()
	inst.card_instance_id = 2147483647  # INT_MAX
	inst.template_id = &"card_boundary"
	inst.level = 0
	inst.inscriptions = []
	inst.breakthrough_layers = 0
	inst.binding_target_id = &""
	inst.acquired_chapter = 0
	inst.acquired_event_id = &""
	inst.acquired_method = 0
	var d: Dictionary = cs.serialize_instance(inst)
	var inst2: CardInstanceClass = cs.deserialize_instance(d)
	if inst2 == null:
		assert_true(false, "反序列化失败")
		return
	assert_eq(inst2.card_instance_id, 2147483647, "INT_MAX card_instance_id 往返保真")
	assert_eq(inst2.level, 0, "level=0 往返保真")
	assert_eq(inst2.inscriptions.size(), 0, "空 inscriptions 往返保真")
	assert_eq(inst2.breakthrough_layers, 0, "breakthrough_layers=0 往返保真")


func test_ac004_roundtrip_large_inscriptions() -> void:
	# inscriptions 含 1000 元素
	var inst: CardInstanceClass = CardInstanceClass.new()
	inst.template_id = &"card_large"
	inst.inscriptions = []
	for i: int in range(1000):
		inst.inscriptions.append({"id": i})
	var d: Dictionary = cs.serialize_instance(inst)
	var inst2: CardInstanceClass = cs.deserialize_instance(d)
	if inst2 == null:
		assert_true(false, "反序列化失败")
		return
	assert_eq(inst2.inscriptions.size(), 1000, "1000 元素 inscriptions 往返保真")


# ============================================================================
# AC-005：reconstitute_instances 批量反序列化
# ============================================================================

func test_ac005_reconstitute_instances_batch() -> void:
	var insts: Array = []
	for i: int in range(3):
		var inst: CardInstanceClass = CardInstanceClass.new()
		inst.card_instance_id = i + 1
		inst.template_id = StringName("card_%d" % i)
		inst.level = i + 1
		insts.append(inst)
	var dicts: Array = []
	for inst: CardInstanceClass in insts:
		dicts.append(cs.serialize_instance(inst))
	var arr: Array = cs.reconstitute_instances(dicts)
	assert_eq(arr.size(), 3, "应重构 3 个实例")
	for i: int in range(3):
		var r: CardInstanceClass = arr[i]
		assert_true(r is CardInstanceClass, "元素 %d 应为 CardInstance" % i)
		assert_eq(r.card_instance_id, i + 1, "card_instance_id 应一致")
		assert_eq(r.template_id, StringName("card_%d" % i), "template_id 应一致")
		assert_eq(r.level, i + 1, "level 应一致")


func test_ac005_reconstitute_empty_array() -> void:
	var arr: Array = cs.reconstitute_instances([])
	assert_eq(arr.size(), 0, "空数组应返回空数组（非 null）")


func test_ac005_reconstitute_single_element() -> void:
	var inst: CardInstanceClass = _make_full_instance()
	var dicts: Array = [cs.serialize_instance(inst)]
	var arr: Array = cs.reconstitute_instances(dicts)
	assert_eq(arr.size(), 1, "单元素数组应返回 1 个实例")
	var r: CardInstanceClass = arr[0]
	assert_eq(r.card_instance_id, 42, "单元素 card_instance_id 应一致")


# ============================================================================
# AC-006：反序列化后 templates.has(StringName(inst.template_id)) 返回 true
# ============================================================================

func test_ac006_deserialize_preserves_dict_lookup() -> void:
	_inject_template(&"card_s")
	var inst: CardInstanceClass = _make_full_instance()
	var d: Dictionary = cs.serialize_instance(inst)
	var inst2: CardInstanceClass = cs.deserialize_instance(d)
	if inst2 == null:
		assert_true(false, "反序列化失败")
		return
	assert_eq(typeof(inst2.template_id), TYPE_STRING_NAME, "template_id 应为 StringName")
	assert_true(cs.templates.has(StringName(inst2.template_id)),
		"反序列化后 templates.has(StringName(inst2.template_id)) 应为 true")


func test_ac006_dict_lookup_with_string_input() -> void:
	# 模拟 JSON 往返：template_id 为 String "card_s"
	_inject_template(&"card_s")
	var d: Dictionary = {
		"template_id": "card_s",  # String
	}
	var inst: CardInstanceClass = cs.deserialize_instance(d)
	if inst == null:
		assert_true(false, "反序列化失败")
		return
	# 反序列化后 inst.template_id 为 StringName，字典查找命中
	assert_true(cs.templates.has(StringName(inst.template_id)),
		"String 输入经反序列化后字典查找应命中")


# ============================================================================
# AC-007：缺失字段使用 .get(key, default) 容错
# ============================================================================

func test_ac007_missing_fields_use_defaults() -> void:
	# 仅含 card_instance_id 和 template_id 两个键（缺其余 7 字段）
	var d: Dictionary = {
		"card_instance_id": 99,
		"template_id": &"card_partial",
	}
	var inst: CardInstanceClass = cs.deserialize_instance(d)
	if inst == null:
		assert_true(false, "反序列化失败")
		return
	assert_eq(inst.card_instance_id, 99, "card_instance_id 应恢复")
	assert_eq(inst.template_id, &"card_partial", "template_id 应恢复")
	# 其余字段使用默认值（与 Story 002 一致）
	assert_eq(inst.level, 1, "level 默认 1")
	assert_eq(inst.inscriptions, [], "inscriptions 默认空数组")
	assert_eq(inst.breakthrough_layers, 0, "breakthrough_layers 默认 0")
	assert_eq(inst.binding_target_id, &"", "binding_target_id 默认 &\"\"")
	assert_eq(inst.acquired_chapter, 0, "acquired_chapter 默认 0")
	assert_eq(inst.acquired_event_id, &"", "acquired_event_id 默认 &\"\"")
	assert_eq(inst.acquired_method, 0, "acquired_method 默认 0（= AcquiredMethod.DROP）")


func test_ac007_empty_dictionary_uses_all_defaults() -> void:
	# 完全空 Dictionary → 全默认值，不崩溃
	var inst: CardInstanceClass = cs.deserialize_instance({})
	assert_not_null(inst, "空 Dictionary 应返回默认实例")
	if inst == null:
		return
	assert_eq(inst.card_instance_id, 0, "空 Dictionary card_instance_id 默认 0")
	assert_eq(inst.template_id, &"", "空 Dictionary template_id 默认 &\"\"")
	assert_eq(inst.level, 1, "空 Dictionary level 默认 1")
	assert_eq(inst.acquired_method, 0, "空 Dictionary acquired_method 默认 0")


# ============================================================================
# AC-008：未知字段忽略，不报错
# ============================================================================

func test_ac008_unknown_fields_ignored() -> void:
	var d: Dictionary = {
		"card_instance_id": 1,
		"template_id": &"card_s",
		"level": 1,
		"inscriptions": [],
		"breakthrough_layers": 0,
		"binding_target_id": &"",
		"acquired_chapter": 0,
		"acquired_event_id": &"",
		"acquired_method": 0,
		"unknown_field": 123,
		"another_unknown": "ignored",
	}
	var inst: CardInstanceClass = cs.deserialize_instance(d)
	assert_not_null(inst, "含未知字段的 Dictionary 应正常反序列化")
	if inst == null:
		return
	# 9 字段正常恢复
	assert_eq(inst.card_instance_id, 1, "card_instance_id 应恢复")
	assert_eq(inst.template_id, &"card_s", "template_id 应恢复")
	# 无 push_error（未知字段被自然忽略）
	assert_push_error_count(0, "未知字段不应触发 push_error")


# ============================================================================
# AC-009：类型不匹配字段 → push_error + 使用默认值
# ============================================================================

func test_ac009_type_mismatch_level_string_non_number() -> void:
	# level 为 String "not_a_number" → push_error + 默认值 1
	var d: Dictionary = {
		"template_id": &"card_s",
		"level": "not_a_number",
	}
	var inst: CardInstanceClass = cs.deserialize_instance(d)
	if inst == null:
		assert_true(false, "反序列化失败")
		return
	assert_push_error_count(1, "非数字 String level 应 push_error 1 次")
	assert_eq(inst.level, 1, "类型不匹配 level 应使用默认值 1")


func test_ac009_type_mismatch_level_numeric_string_converts() -> void:
	# level 为 String "3"（数字字符串）→ 隐式转换为 int 3
	var d: Dictionary = {
		"template_id": &"card_s",
		"level": "3",
	}
	var inst: CardInstanceClass = cs.deserialize_instance(d)
	if inst == null:
		assert_true(false, "反序列化失败")
		return
	assert_eq(inst.level, 3, "数字字符串 level 应转换为 int 3")
	assert_push_error_count(0, "数字字符串转换不应 push_error")


func test_ac009_type_mismatch_float_truncates() -> void:
	# level 为 float 3.7 → int() 截断为 3（JSON 数字可能为 float）
	var d: Dictionary = {
		"template_id": &"card_s",
		"level": 3.7,
	}
	var inst: CardInstanceClass = cs.deserialize_instance(d)
	if inst == null:
		assert_true(false, "反序列化失败")
		return
	assert_eq(inst.level, 3, "float level 应截断为 int 3")
	assert_push_error_count(0, "float 截断不应 push_error")


func test_ac009_type_mismatch_other_fields_use_defaults() -> void:
	# 多个 int 字段类型不匹配 → 各自 push_error + 默认值
	var d: Dictionary = {
		"template_id": &"card_s",
		"card_instance_id": true,      # bool，非 int
		"breakthrough_layers": [],     # Array，非 int
		"acquired_chapter": {},        # Dictionary，非 int
		"acquired_method": "abc",      # 非数字 String
	}
	var inst: CardInstanceClass = cs.deserialize_instance(d)
	if inst == null:
		assert_true(false, "反序列化失败")
		return
	# 4 个类型不匹配字段各自 push_error
	assert_push_error_count(4, "4 个类型不匹配字段应 push_error 4 次")
	assert_eq(inst.card_instance_id, 0, "bool card_instance_id 应使用默认 0")
	assert_eq(inst.breakthrough_layers, 0, "Array breakthrough_layers 应使用默认 0")
	assert_eq(inst.acquired_chapter, 0, "Dict acquired_chapter 应使用默认 0")
	assert_eq(inst.acquired_method, 0, "非数字 String acquired_method 应使用默认 0")
