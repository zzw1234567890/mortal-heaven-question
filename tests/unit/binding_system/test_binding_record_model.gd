extends GutTest
## Story 001 验收测试：BindingRecord RefCounted 实例模型 + BindingManager 内部注册表。
##
## 覆盖 AC-001 到 AC-008（8 条 AC）。
## 测试策略：
##   - BindingRecord 通过 preload 类常量构造（class_name 的 RefCounted）
##   - BindingManager 用动态分派 BM_SCRIPT.new() + var bm: Node 持有（Autoload 不声明 class_name，
##     同 GSM/RealmSystem/CostSystem 先例）
##   - 三索引同步：_register_binding / _unregister_binding 原子更新三索引
##   - 零分配热路径：get_binding_ids_by_character 返回已有数组引用（已绑定路径）
##   - assert 守卫：get_binding 访问处运行时 is BindingRecord 检查（纵深防御层）
##
## 设计文档来源：ADR-0013 §对象模型 §关键接口 §验证标准
## Story 来源：production/epics/binding-system/story-001-refcounted-model.md

const BRClass := preload("res://src/feature/binding/binding_record.gd")
const BM_SCRIPT := preload("res://src/feature/binding/binding_manager.gd")

const BindingSlot := preload("res://src/feature/binding/binding_record.gd").BindingSlot

var bm: Node = null


func before_each() -> void:
	bm = BM_SCRIPT.new()


func after_each() -> void:
	if bm != null:
		bm.free()
		bm = null


func _make_record(binding_id: int, card_instance_id: int, character_id: int) -> Variant:
	var r = BRClass.new()
	r.binding_id = binding_id
	r.card_instance_id = card_instance_id
	r.bound_character_id = character_id
	return r


# ============================================================================
# AC-001：BindingRecord 为 RefCounted（非 Resource、非 Dictionary）
# ============================================================================

func test_binding_record_extends_refcounted() -> void:
	var script: GDScript = load("res://src/feature/binding/binding_record.gd")
	assert_eq(script.get_instance_base_type(), "RefCounted", "BindingRecord 应继承 RefCounted")


func test_binding_record_instance_is_refcounted() -> void:
	var r = BRClass.new()
	assert_true(r is RefCounted, "BindingRecord 实例应为 RefCounted")
	assert_false(r is Resource, "BindingRecord 不应为 Resource")
	assert_false(r is Dictionary, "BindingRecord 不应为 Dictionary")


# ============================================================================
# AC-002：BindingRecord 字段完整（14 字段，类型匹配）
# ============================================================================

func test_binding_record_all_fields_types() -> void:
	var r = BRClass.new()
	# 逐字段赋值并读回，断言类型匹配声明
	r.binding_id = 1
	r.card_instance_id = 100
	r.card_template_id = &"tech_sword_01"
	r.card_name = "青云剑诀"
	r.card_rarity = 4
	r.slot_type = BindingSlot.FABAO
	r.slot_index = 2
	r.bound_character_id = 200
	r.is_native = true
	r.native_multiplier = 1.5
	r.activated_turn = 3
	r.is_suspended = true
	var slots: Array[int] = [100, 101]
	r.stack_slots = slots
	r.stack_count = 2

	assert_eq(typeof(r.binding_id), TYPE_INT, "binding_id int")
	assert_eq(typeof(r.card_instance_id), TYPE_INT, "card_instance_id int")
	assert_eq(typeof(r.card_template_id), TYPE_STRING_NAME, "card_template_id StringName")
	assert_eq(typeof(r.card_name), TYPE_STRING, "card_name String")
	assert_eq(typeof(r.card_rarity), TYPE_INT, "card_rarity int")
	assert_eq(r.slot_type, BindingSlot.FABAO, "slot_type BindingSlot")
	assert_eq(typeof(r.slot_index), TYPE_INT, "slot_index int")
	assert_eq(typeof(r.bound_character_id), TYPE_INT, "bound_character_id int")
	assert_eq(typeof(r.is_native), TYPE_BOOL, "is_native bool")
	assert_eq(typeof(r.native_multiplier), TYPE_FLOAT, "native_multiplier float")
	assert_eq(typeof(r.activated_turn), TYPE_INT, "activated_turn int")
	assert_eq(typeof(r.is_suspended), TYPE_BOOL, "is_suspended bool")
	assert_eq(typeof(r.stack_slots), TYPE_ARRAY, "stack_slots Array")
	assert_eq(typeof(r.stack_count), TYPE_INT, "stack_count int")


func test_binding_record_field_defaults() -> void:
	var r = BRClass.new()
	assert_eq(r.card_rarity, 0, "card_rarity 默认 0")
	assert_eq(r.slot_type, BindingSlot.GONGFA, "slot_type 默认 GONGFA")
	assert_eq(r.native_multiplier, 1.0, "native_multiplier 默认 1.0")
	assert_eq(r.stack_count, 1, "stack_count 默认 1（≥1）")
	assert_eq(r.stack_slots.size(), 0, "stack_slots 默认空")
	assert_false(r.is_native, "is_native 默认 false")
	assert_false(r.is_suspended, "is_suspended 默认 false")


func test_binding_record_stack_slots_first_is_self() -> void:
	var r = BRClass.new()
	r.card_instance_id = 100
	var slots: Array[int] = [100]
	r.stack_slots = slots
	assert_eq(r.stack_slots[0], 100, "stack_slots[0] 应为自身 card_instance_id")


# ============================================================================
# AC-003：三索引结构存在且初始为空
# ============================================================================

func test_binding_manager_three_indexes_exist_and_empty() -> void:
	assert_true(bm.get("_bindings") is Dictionary, "_bindings 存在")
	assert_true(bm.get("_by_character") is Dictionary, "_by_character 存在")
	assert_true(bm.get("_card_to_character") is Dictionary, "_card_to_character 存在")
	assert_eq((bm.get("_bindings") as Dictionary).size(), 0, "_bindings 初始为空")
	assert_eq((bm.get("_by_character") as Dictionary).size(), 0, "_by_character 初始为空")
	assert_eq((bm.get("_card_to_character") as Dictionary).size(), 0, "_card_to_character 初始为空")


# ============================================================================
# AC-004：三索引原子同步
# ============================================================================

func test_binding_manager_register_updates_three_indexes() -> void:
	var r = _make_record(1, 100, 200)
	bm.call("_register_binding", r)

	var bindings: Dictionary = bm.get("_bindings")
	var by_character: Dictionary = bm.get("_by_character")
	var card_to_character: Dictionary = bm.get("_card_to_character")

	assert_true(bindings.has(1), "_bindings[id] 存在")
	assert_true(by_character.has(200), "_by_character[char_id] 存在")
	assert_true(by_character[200].has(1), "_by_character[char_id] 含 binding_id")
	assert_eq(card_to_character[100], 200, "_card_to_character[card_id] == char_id")


func test_binding_manager_unregister_removes_three_indexes() -> void:
	var r = _make_record(1, 100, 200)
	bm.call("_register_binding", r)
	bm.call("_unregister_binding", r)

	var bindings: Dictionary = bm.get("_bindings")
	var by_character: Dictionary = bm.get("_by_character")
	var card_to_character: Dictionary = bm.get("_card_to_character")

	assert_false(bindings.has(1), "unregister 后 _bindings 移除")
	assert_false(card_to_character.has(100), "unregister 后 _card_to_character 移除")
	assert_false(by_character.has(200), "unregister 唯一一条后 _by_character 删除该 character_id 键")


func test_binding_manager_register_three_then_unregister_all_clears_key() -> void:
	for i in range(3):
		var r = _make_record(i + 1, 100 + i, 200)
		bm.call("_register_binding", r)

	var by_character: Dictionary = bm.get("_by_character")
	assert_eq(by_character[200].size(), 3, "连续 register 3 条后 _by_character[char_id].size() == 3")

	# 逐个注销前两条——character_id 键应保留
	bm.call("_unregister_binding", _make_record(1, 100, 200))
	assert_true(by_character.has(200), "注销非最后一条后 character_id 键保留")
	bm.call("_unregister_binding", _make_record(2, 101, 200))
	assert_true(by_character.has(200), "注销后仍有剩余条目，键保留")

	# 注销最后一条——character_id 键删除
	bm.call("_unregister_binding", _make_record(3, 102, 200))
	assert_false(by_character.has(200), "注销最后一条后 _by_character 删除该 character_id 键")


func test_binding_manager_unregister_idempotent() -> void:
	# 对从未注册的 record 调用 _unregister_binding——应不崩溃且三索引保持空
	bm.call("_unregister_binding", _make_record(999, 999, 999))
	var bindings: Dictionary = bm.get("_bindings")
	var by_character: Dictionary = bm.get("_by_character")
	var card_to_character: Dictionary = bm.get("_card_to_character")
	assert_eq(bindings.size(), 0, "未注册 unregister 后 _bindings 保持空")
	assert_eq(by_character.size(), 0, "未注册 unregister 后 _by_character 保持空")
	assert_eq(card_to_character.size(), 0, "未注册 unregister 后 _card_to_character 保持空")


# ============================================================================
# AC-005：assert 守卫（get_binding 访问处运行时 is BindingRecord 检查）
# ============================================================================

func test_binding_manager_get_binding_returns_record() -> void:
	var r = _make_record(1, 100, 200)
	bm.call("_register_binding", r)
	var got: Variant = bm.call("get_binding", 1)
	assert_true(got is BRClass, "get_binding 返回 BindingRecord")
	# 正常 BindingRecord 值通过 assert 守卫不触发——返回正确值（AC-005 edge case）
	assert_eq((got as Variant).binding_id, 1, "正常值通过 assert 且字段正确")


func test_binding_manager_get_binding_missing_null() -> void:
	var got: Variant = bm.call("get_binding", 999)
	assert_null(got, "不存在的 binding_id 返回 null")


func test_binding_manager_get_binding_null_injection_graceful() -> void:
	# null 值注入：null 是唯一能绕过类型化 Dictionary 编译期拦截的非 BindingRecord 值。
	# get_binding 对 null 值优雅返回 null（不触发 assert、不崩溃）。
	# 非 null 非法类型（String/int/Dictionary）在 _bindings[id] = x 赋值时就被
	# 类型化 Dictionary 运行时拦截，根本无法存入——assert 守卫因此对非法注入运行时不可达，
	# 实为纵深防御层（防未来 deserialize 非类型化写入路径）。
	var bindings: Dictionary = bm.get("_bindings")
	bindings[42] = null
	var got: Variant = bm.call("get_binding", 42)
	assert_null(got, "注入 null 值时优雅返回 null（不触发断言、不崩溃）")


# ============================================================================
# AC-006：零分配热路径查询（已绑定路径返回已有数组引用）
# ============================================================================

func test_binding_manager_get_ids_returns_same_reference() -> void:
	for i in range(3):
		var r = _make_record(i + 1, 100 + i, 200)
		bm.call("_register_binding", r)

	var ids1: Array[int] = bm.call("get_binding_ids_by_character", 200)
	var ids2: Array[int] = bm.call("get_binding_ids_by_character", 200)

	assert_eq(ids1.size(), 3, "返回 3 个 binding_id")
	assert_true(is_same(ids1, ids2), "已绑定路径两次返回同一引用（不构造新数组）")


func test_binding_manager_get_ids_empty_allocates_new() -> void:
	var ids1: Array[int] = bm.call("get_binding_ids_by_character", 999)
	var ids2: Array[int] = bm.call("get_binding_ids_by_character", 999)
	assert_eq(ids1.size(), 0, "未绑定角色返回空数组")
	assert_eq(ids2.size(), 0, "第二次同样返回空数组")
	# 未绑定路径每次分配新空数组（非热路径边界——CombatUI 不应对未绑定角色每帧调用）
	assert_false(is_same(ids1, ids2), "未绑定路径每次分配新空数组（不共享可变状态）")


# ============================================================================
# AC-007：非热路径分配查询（每次分配新数组）
# ============================================================================

func test_binding_manager_get_bindings_returns_new_array() -> void:
	for i in range(3):
		var r = _make_record(i + 1, 100 + i, 200)
		bm.call("_register_binding", r)

	var records1: Array = bm.call("get_bindings_by_character", 200)
	var records2: Array = bm.call("get_bindings_by_character", 200)

	assert_eq(records1.size(), 3, "返回 3 条 BindingRecord")
	assert_eq(records2.size(), 3, "第二次同样返回 3 条")
	assert_false(is_same(records1, records2), "每次调用返回新数组实例（不共享可变状态）")
	for rec in records1:
		assert_true(rec is BRClass, "元素均为 BindingRecord 类型")


func test_binding_manager_get_bindings_empty() -> void:
	var records: Array = bm.call("get_bindings_by_character", 999)
	assert_eq(records.size(), 0, "未绑定角色返回空数组")


# ============================================================================
# AC-008：O(1) 反向查询
# ============================================================================

func test_binding_manager_get_character_by_card_returns() -> void:
	var r = _make_record(1, 100, 200)
	bm.call("_register_binding", r)
	var character_id: int = bm.call("get_character_by_card", 100)
	assert_eq(character_id, 200, "card_instance_id → character_id 正确")


func test_binding_manager_get_character_by_card_unbound() -> void:
	var character_id: int = bm.call("get_character_by_card", 999)
	assert_eq(character_id, -1, "未绑定 card_instance_id 返回 -1")
