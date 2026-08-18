extends GutTest
## Story 002 验收测试：bind / stack / overwrite / can_bind / remove / suspend / restore / 本命判定 / 叠加公式。
##
## 覆盖 AC-001 到 AC-018（18 条 AC）。
## 测试策略：
##   - BindingManager 用动态分派 BM_SCRIPT.new() + var bm: Node 持有（Autoload 不声明 class_name）
##   - before_each 缓存槽位上限（真实 RealmSystem Autoload）
##   - 存根回调（effect_register/remove/suspend/restore + card_shuffle/discard/exists + stat_bonus）
##     通过注入 lambda 记录调用序列，断言覆盖严格顺序 + 阵亡洗回 + suspend/restore 验证
##   - 本命判定经 bind_card 注入 native_owner / character_card_id
##
## 设计文档来源：ADR-0013 §关键接口 §本命绑定判定算法 §同名叠加乘法公式 §验证标准
## Story 来源：production/epics/binding-system/story-002-bind-unbind-query-api.md

const BRClass := preload("res://src/feature/binding/binding_record.gd")
const BM_SCRIPT := preload("res://src/feature/binding/binding_manager.gd")
const BindingSlot := preload("res://src/feature/binding/binding_record.gd").BindingSlot

const GONGFA := BindingSlot.GONGFA
const FABAO := BindingSlot.FABAO

var bm: Node = null
var _effect_log: Array = []


func before_each() -> void:
	bm = BM_SCRIPT.new()
	_effect_log.clear()
	bm.call("cache_slot_limits", GameStateManager.RealmLevel.QI_REFINING)  # 炼气 1/1
	_wire_callbacks()


func after_each() -> void:
	if bm != null:
		bm.free()
		bm = null
	_effect_log.clear()


func _wire_callbacks() -> void:
	bm.set("effect_register_cb", Callable(self, "_on_effect_register"))
	bm.set("effect_remove_cb", Callable(self, "_on_effect_remove"))
	bm.set("effect_suspend_cb", Callable(self, "_on_effect_suspend"))
	bm.set("effect_restore_cb", Callable(self, "_on_effect_restore"))
	bm.set("card_shuffle_cb", Callable(self, "_on_card_shuffle"))
	bm.set("card_discard_cb", Callable(self, "_on_card_discard"))


func _on_effect_register(card_instance_id: int, character_id: int) -> void:
	_effect_log.append("register:%d" % card_instance_id)


func _on_effect_remove(card_instance_id: int) -> void:
	_effect_log.append("remove:%d" % card_instance_id)


func _on_effect_suspend(character_id: int, card_ids: Array) -> void:
	_effect_log.append("suspend:%d" % character_id)


func _on_effect_restore(character_id: int, card_ids: Array) -> void:
	_effect_log.append("restore:%d" % character_id)


func _on_card_shuffle(card_instance_id: int) -> void:
	_effect_log.append("shuffle:%d" % card_instance_id)


func _on_card_discard(card_instance_id: int) -> void:
	_effect_log.append("discard:%d" % card_instance_id)


func _set_realm(level: int) -> void:
	bm.call("cache_slot_limits", level)


# ============================================================================
# AC-001：bind_card 绑定到空位
# ============================================================================

func test_bind_card_to_empty_slot() -> void:
	var r: Dictionary = bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	assert_true(r["success"], "空位绑定成功")
	assert_eq(r["reason"], "bound", "reason 应为 bound")
	assert_gt(int(r["binding_id"]), 0, "binding_id 有效")
	assert_eq((bm.call("get_bindings_by_character", 200) as Array).size(), 1, "绑定后 1 条")
	assert_eq(int(bm.call("get_character_by_card", 100)), 200, "_card_to_character[card_id] == char_id")
	assert_eq(_effect_log, ["register:100"], "绑定成功触发效果注册")


# ============================================================================
# AC-002：bind_card 无空位拒绝（不触发覆盖）
# ============================================================================

func test_bind_card_slot_full_rejects() -> void:
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	_effect_log.clear()
	var r: Dictionary = bm.call("bind_card", 101, &"tech_other_01", 200, GONGFA)
	assert_false(r["success"], "无空位绑定失败")
	assert_eq(r["reason"], "slot_full", "reason 应为 slot_full")
	assert_eq((bm.call("get_bindings_by_character", 200) as Array).size(), 1, "不触发覆盖——仍 1 条")
	assert_eq(_effect_log.size(), 0, "不触发任何效果回调")


# ============================================================================
# AC-004：绑定位上限查询 RealmSystem（炼气 1/1，化神 3/3）
# ============================================================================

func test_slot_limits_qi_refining() -> void:
	assert_eq(int(bm.call("_get_slot_limit", GONGFA)), 1, "炼气功法位 1")
	assert_eq(int(bm.call("_get_slot_limit", FABAO)), 1, "炼气法宝位 1")


func test_slot_limits_spirit_transformation() -> void:
	_set_realm(GameStateManager.RealmLevel.SPIRIT_TRANSFORMATION)
	assert_eq(int(bm.call("_get_slot_limit", GONGFA)), 3, "化神功法位 3")
	assert_eq(int(bm.call("_get_slot_limit", FABAO)), 3, "化神法宝位 3")


# ============================================================================
# AC-005：本命判定（native_owner 匹配 + 本命位空闲 → 1.5）
# ============================================================================

func test_native_detection_match() -> void:
	var r: Dictionary = bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA, &"lin_yuan", &"char_lin_yuan_base_01")
	var rec: Variant = bm.call("get_binding", int(r["binding_id"]))
	assert_true(rec.is_native, "匹配本命位空 → is_native")
	assert_eq(rec.native_multiplier, 1.5, "native_multiplier 1.5")


func test_native_detection_no_match() -> void:
	var r: Dictionary = bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA, &"lin_yuan", &"char_xi_yin_base_01")
	var rec: Variant = bm.call("get_binding", int(r["binding_id"]))
	assert_false(rec.is_native, "不匹配 → 非本命")
	assert_eq(rec.native_multiplier, 1.0, "native_multiplier 1.0")


func test_native_detection_empty_owner() -> void:
	var r: Dictionary = bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA, &"", &"char_lin_yuan_base_01")
	var rec: Variant = bm.call("get_binding", int(r["binding_id"]))
	assert_false(rec.is_native, "native_owner 空 → 非本命")
	assert_eq(rec.native_multiplier, 1.0, "native_multiplier 1.0")


func test_native_detection_truncated_name_no_match() -> void:
	# C2 回归——截断 native_owner 不得子串误配（分段锚定 "_lin_yu_" ∉ "_char_lin_yuan_base_01_"）
	var r: Dictionary = bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA, &"lin_yu", &"char_lin_yuan_base_01")
	var rec: Variant = bm.call("get_binding", int(r["binding_id"]))
	assert_false(rec.is_native, "截断 native_owner 不误配完整名")
	assert_eq(rec.native_multiplier, 1.0, "native_multiplier 1.0")


# ============================================================================
# AC-006：本命不可逆（本命位已满 → 第二张匹配卡 ×1.0）
# ============================================================================

func test_native_slot_already_occupied() -> void:
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA, &"lin_yuan", &"char_lin_yuan_base_01")
	# 第二个功法位（炼气只有 1 个功法位——先扩到化神 3 位）
	_set_realm(GameStateManager.RealmLevel.SPIRIT_TRANSFORMATION)
	var r: Dictionary = bm.call("bind_card", 101, &"tech_other_01", 200, GONGFA, &"lin_yuan", &"char_lin_yuan_base_01")
	var rec: Variant = bm.call("get_binding", int(r["binding_id"]))
	assert_false(rec.is_native, "本命位已满 → 第二张匹配卡非本命")
	assert_eq(rec.native_multiplier, 1.0, "本命位已满 → 1.0")


func test_native_stack_preserves_native_flag() -> void:
	# AC-006 主 Then——同名叠加沿用首次绑定的 is_native/native_multiplier，不重新判定
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA, &"lin_yuan", &"char_lin_yuan_base_01")
	var r: Dictionary = bm.call("stack_card", 101, &"tech_sword_01", 200, 3)
	assert_true(r["stacked"], "同名叠加成功")
	var rec: Variant = bm.call("get_binding", 1)
	assert_true(rec.is_native, "叠加沿用首次 is_native=true")
	assert_eq(rec.native_multiplier, 1.5, "叠加沿用 native_multiplier=1.5")
	assert_eq(rec.stack_count, 2, "stack_count=2")


# ============================================================================
# AC-007：stack_card 同名叠加（共享槽位）
# ============================================================================

func test_stack_card_stacks() -> void:
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	var r: Dictionary = bm.call("stack_card", 101, &"tech_sword_01", 200, 3)
	assert_true(r["stacked"], "同名叠加成功")
	assert_eq(int(r["stack_count"]), 2, "stack_count 2")
	var rec: Variant = bm.call("get_binding", 1)
	assert_eq(rec.slot_index, 0, "slot_index 不变（共享槽位）")
	assert_eq(rec.stack_slots.size(), 2, "stack_slots 含 2 实例")
	assert_true(rec.stack_slots.has(101), "新实例在 stack_slots")
	assert_eq((bm.call("get_bindings_by_character", 200) as Array).size(), 1, "绑定位数量不增加")


# ============================================================================
# AC-008：stack_card 上限拒绝 / 无已有绑定
# ============================================================================

func test_stack_card_limit_reached() -> void:
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	bm.call("stack_card", 101, &"tech_sword_01", 200, 2)  # 上限 2，已达
	var r: Dictionary = bm.call("stack_card", 102, &"tech_sword_01", 200, 2)
	assert_false(r["stacked"], "达上限拒绝")
	assert_eq(r["reason"], "stack_limit_reached", "reason stack_limit_reached")


func test_stack_card_no_existing_binding() -> void:
	var r: Dictionary = bm.call("stack_card", 101, &"tech_sword_01", 200, 3)
	assert_false(r["stacked"], "无已有绑定拒绝")
	assert_eq(r["reason"], "no_existing_binding", "reason no_existing_binding")


# ============================================================================
# AC-009：同名叠加乘法公式
# ============================================================================

func test_effective_value_non_native() -> void:
	# base=4, native=1.0, mult=1.5 → 4/6/9/13/20
	assert_eq(bm.call("compute_effective_value", 4, 1.0, 1.5, 1), 4, "count1=4")
	assert_eq(bm.call("compute_effective_value", 4, 1.0, 1.5, 2), 6, "count2=6")
	assert_eq(bm.call("compute_effective_value", 4, 1.0, 1.5, 3), 9, "count3=9")
	assert_eq(bm.call("compute_effective_value", 4, 1.0, 1.5, 4), 13, "count4=13")
	assert_eq(bm.call("compute_effective_value", 4, 1.0, 1.5, 5), 20, "count5=20")


func test_effective_value_native() -> void:
	# base=4, native=1.5, mult=1.5 → 6/9/13/20/30
	assert_eq(bm.call("compute_effective_value", 4, 1.5, 1.5, 1), 6, "native count1=6")
	assert_eq(bm.call("compute_effective_value", 4, 1.5, 1.5, 2), 9, "native count2=9")
	assert_eq(bm.call("compute_effective_value", 4, 1.5, 1.5, 3), 13, "native count3=13")
	assert_eq(bm.call("compute_effective_value", 4, 1.5, 1.5, 4), 20, "native count4=20")
	assert_eq(bm.call("compute_effective_value", 4, 1.5, 1.5, 5), 30, "native count5=30")


func test_effective_value_count1_degrades() -> void:
	# stack_count=1 时 stack_multiplier^0 = 1.0 → base × native
	assert_eq(bm.call("compute_effective_value", 10, 1.0, 2.0, 1), 10, "count1 退化为 base×native")


func test_effective_value_high_multiplier_240() -> void:
	# AC-009 Edge case——mult=2.0 + count=5 + base=10 + native=1.5 → 240（floori）
	assert_eq(bm.call("compute_effective_value", 10, 1.5, 2.0, 5), 240, "高倍率边界 240")


# ============================================================================
# AC-010：overwrite_binding 覆盖严格顺序（remove → discard → register）
# ============================================================================

func test_overwrite_binding_strict_order() -> void:
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	_effect_log.clear()
	var r: Dictionary = bm.call("overwrite_binding", 101, &"tech_other_01", 200, 0)
	assert_true(r["success"], "覆盖成功")
	assert_eq(_effect_log, ["remove:100", "discard:100", "register:101"], "remove 先于 register，旧卡进弃牌堆")
	assert_eq((bm.call("get_bindings_by_character", 200) as Array).size(), 1, "新卡落位后仍 1 条")
	assert_eq(int(bm.call("get_character_by_card", 101)), 200, "新卡映射")


func test_overwrite_native_reclaims_native_slot() -> void:
	# ADR-0013 §本命判定算法第 4 点——旧本命卡被覆盖（进弃牌堆）后，新匹配卡重新执行本命判定
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA, &"lin_yuan", &"char_lin_yuan_base_01")
	var r: Dictionary = bm.call("overwrite_binding", 101, &"tech_other_01", 200, 0, &"lin_yuan", &"char_lin_yuan_base_01")
	assert_true(r["success"], "覆盖本命卡成功")
	var rec: Variant = bm.call("get_binding", int(r["binding_id"]))
	assert_true(rec.is_native, "新匹配卡重新占用本命位 is_native=true")
	assert_eq(rec.native_multiplier, 1.5, "native_multiplier=1.5")


# ============================================================================
# AC-011/AC-012：覆盖叠加中的一层（stack_count 递减 / 减至 0 删除）
# ============================================================================

func test_overwrite_stack_removes_one_layer() -> void:
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	bm.call("stack_card", 101, &"tech_sword_01", 200, 3)
	bm.call("stack_card", 102, &"tech_sword_01", 200, 3)
	_effect_log.clear()
	# 覆盖该槽位（炼气 1 功法位）——移除一层叠加
	var r: Dictionary = bm.call("overwrite_binding", 103, &"tech_other_01", 200, 0)
	assert_true(r["success"], "覆盖叠加一层成功")
	assert_eq(r["reason"], "overwritten_stack", "叠加覆盖 reason")
	# AC-011 回调序列——被覆盖实例 102：remove 先于 discard，且无 register（不换卡）
	assert_eq(_effect_log, ["remove:102", "discard:102"], "覆盖叠加层 remove→discard，无 register")
	var rec: Variant = bm.call("get_binding", 1)
	assert_eq(rec.stack_count, 2, "stack_count 从 3 减为 2")
	assert_eq(rec.stack_slots.size(), 2, "stack_slots 2")
	assert_false(rec.stack_slots.has(102), "被覆盖实例移出 stack_slots")
	assert_eq(int(bm.call("get_character_by_card", 102)), -1, "被覆盖实例解除卡映射")
	# 槽位不变（仍共享 slot 0）
	assert_eq(rec.slot_index, 0, "槽位不变")


func test_overwrite_stack_count_to_zero() -> void:
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	_effect_log.clear()
	# stack_count=1 覆盖 → 完全解绑（AC-012）
	var r: Dictionary = bm.call("overwrite_binding", 101, &"tech_other_01", 200, 0)
	assert_true(r["success"], "覆盖成功")
	assert_eq(r["reason"], "overwritten", "完全覆盖 reason")
	assert_eq((bm.call("get_bindings_by_character", 200) as Array).size(), 1, "旧记录删除，新记录落位")
	assert_eq(int(bm.call("get_character_by_card", 100)), -1, "旧卡解除映射")


# ============================================================================
# AC-003：can_bind 四种着色状态
# ============================================================================

func test_can_bind_slot_available() -> void:
	var r: Dictionary = bm.call("can_bind", 200, GONGFA, &"tech_sword_01", 3)
	assert_true(r["can_bind"], "有空位 → can_bind")
	assert_false(r["can_stack"], "无同名 → 非叠加")
	assert_false(r["must_overwrite"], "有空位 → 非覆盖")


func test_can_bind_can_stack() -> void:
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	var r: Dictionary = bm.call("can_bind", 200, GONGFA, &"tech_sword_01", 3)
	assert_false(r["can_bind"], "同名优先于空位判断")
	assert_true(r["can_stack"], "同名未达上限 → 绿色叠加")
	assert_eq(int(r["slot_index"]), 0, "复用已有槽位")


func test_can_bind_must_overwrite() -> void:
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	var r: Dictionary = bm.call("can_bind", 200, GONGFA, &"tech_other_01", 3)
	assert_false(r["can_bind"], "无空位")
	assert_true(r["must_overwrite"], "无空位可覆盖 → 橙色")
	assert_false(r["can_stack"], "非同名的满位")


func test_can_bind_stack_limit_reached_gray() -> void:
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	bm.call("stack_card", 101, &"tech_sword_01", 200, 2)  # 达上限 2
	var r: Dictionary = bm.call("can_bind", 200, GONGFA, &"tech_sword_01", 2)
	assert_false(r["can_bind"], "同名达上限 → 灰遮罩")
	assert_false(r["can_stack"], "达上限不可叠加")
	assert_false(r["must_overwrite"], "达上限不可覆盖")
	assert_eq(r["reason"], "stack_limit_reached", "reason stack_limit_reached")


# ============================================================================
# AC-013：remove_binding / remove_all_bindings
# ============================================================================

func test_remove_binding_single() -> void:
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	bm.call("remove_binding", 1)
	assert_eq((bm.call("get_binding_ids_by_character", 200) as Array).size(), 0, "移除后为空")
	assert_eq(int(bm.call("get_character_by_card", 100)), -1, "卡映射清除")


func test_remove_binding_clears_all_stack_mappings() -> void:
	# AC-013 多层叠加清理——remove_binding 遍历 stack_slots 清除所有叠层实例卡映射
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	bm.call("stack_card", 101, &"tech_sword_01", 200, 3)
	bm.call("stack_card", 102, &"tech_sword_01", 200, 3)
	bm.call("remove_binding", 1)
	assert_eq(int(bm.call("get_character_by_card", 100)), -1, "主实例映射清除")
	assert_eq(int(bm.call("get_character_by_card", 101)), -1, "叠层 101 映射清除")
	assert_eq(int(bm.call("get_character_by_card", 102)), -1, "叠层 102 映射清除")


func test_remove_all_bindings_returns_serialized() -> void:
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	_set_realm(GameStateManager.RealmLevel.SPIRIT_TRANSFORMATION)
	bm.call("bind_card", 101, &"tech_other_01", 200, GONGFA)
	var result: Array = bm.call("remove_all_bindings", 200)
	assert_eq(result.size(), 2, "返回 2 条序列化数据")
	assert_eq((bm.call("get_binding_ids_by_character", 200) as Array).size(), 0, "清除后为空")


# ============================================================================
# AC-014：角色阵亡洗回（含所有叠层实例）
# ============================================================================

func test_death_shuffles_all_stack_instances() -> void:
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	bm.call("stack_card", 101, &"tech_sword_01", 200, 3)
	bm.call("stack_card", 102, &"tech_sword_01", 200, 3)
	_effect_log.clear()
	var result: Array = bm.call("remove_all_bindings", 200)
	assert_eq(result.size(), 1, "1 条绑定记录")
	# 3 张叠层实例全部洗回牌库（非弃牌堆）
	assert_eq(_effect_log.count("shuffle:100"), 1, "本实例洗回")
	assert_eq(_effect_log.count("shuffle:101"), 1, "叠层 101 洗回")
	assert_eq(_effect_log.count("shuffle:102"), 1, "叠层 102 洗回")
	assert_true("remove:100" in _effect_log, "remove_effects_by_source 被调用")
	assert_eq((bm.call("get_binding_ids_by_character", 200) as Array).size(), 0, "清除所有条目")


# ============================================================================
# AC-015：suspend / restore
# ============================================================================

func test_suspend_bindings_sets_flag() -> void:
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	bm.call("suspend_bindings", 200)
	var rec: Variant = bm.call("get_binding", 1)
	assert_true(rec.is_suspended, "离场后 is_suspended=true")
	assert_true("suspend:200" in _effect_log, "效果暂挂被调用")
	# 不进弃牌堆——绑定仍在
	assert_eq((bm.call("get_bindings_by_character", 200) as Array).size(), 1, "不进弃牌堆")


func test_restore_bindings_existing_card() -> void:
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	bm.call("suspend_bindings", 200)
	bm.call("restore_bindings", 200)
	var rec: Variant = bm.call("get_binding", 1)
	assert_false(rec.is_suspended, "card 存在 → 恢复")
	assert_true("restore:200" in _effect_log, "效果恢复被调用")


func test_restore_bindings_missing_card_deletes() -> void:
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	bm.call("suspend_bindings", 200)
	# 注入 card_exists_cb 返回 false——离场期间 card 被移除
	bm.set("card_exists_cb", Callable(self, "_on_card_missing"))
	bm.call("restore_bindings", 200)
	assert_eq((bm.call("get_bindings_by_character", 200) as Array).size(), 0, "card 不存在 → 删除变空位")
	assert_eq(int(bm.call("get_character_by_card", 100)), -1, "卡映射清除")


func _on_card_missing(card_instance_id: int) -> bool:
	return false


# ============================================================================
# AC-016：get_accumulated_bonus 累加
# ============================================================================

func test_get_accumulated_bonus_accumulates() -> void:
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	bm.call("stack_card", 101, &"tech_sword_01", 200, 3)
	# 注入 stat_bonus_cb——每实例返回固定加成
	bm.set("stat_bonus_cb", Callable(self, "_on_stat_bonus"))
	var bonus: float = bm.call("get_accumulated_bonus", 200, "ATK")
	assert_eq(bonus, 4.0, "两张叠层实例加成累加 2+2=4")


func test_get_accumulated_bonus_empty() -> void:
	var bonus: float = bm.call("get_accumulated_bonus", 999, "ATK")
	assert_eq(bonus, 0.0, "无绑定 → 0.0")


func _on_stat_bonus(card_instance_id: int, stat_name: String) -> float:
	return 2.0


# ============================================================================
# AC-017：不同角色独立 stack_count
# ============================================================================

func test_independent_stack_count_between_characters() -> void:
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	bm.call("stack_card", 101, &"tech_sword_01", 200, 3)
	bm.call("stack_card", 102, &"tech_sword_01", 200, 3)
	bm.call("bind_card", 110, &"tech_sword_01", 300, GONGFA)
	bm.call("stack_card", 111, &"tech_sword_01", 300, 3)
	var rec_a: Variant = bm.call("get_binding", 1)
	var rec_b: Variant = bm.call("get_binding", 2)
	assert_eq(rec_a.stack_count, 3, "角色A stack_count=3")
	assert_eq(rec_b.stack_count, 2, "角色B stack_count=2 独立")
	# 覆盖角色A不影响角色B
	bm.call("overwrite_binding", 103, &"tech_other_01", 200, 0)
	assert_eq((bm.call("get_bindings_by_character", 300) as Array).size(), 1, "角色B 不受角色A覆盖影响")


# ============================================================================
# AC-018：card_already_bound 拒绝
# ============================================================================

func test_card_already_bound_rejects() -> void:
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	var r: Dictionary = bm.call("bind_card", 100, &"tech_sword_01", 300, GONGFA)
	assert_false(r["success"], "同一卡重复绑定拒绝")
	assert_eq(r["reason"], "card_already_bound", "reason card_already_bound")
	assert_eq((bm.call("get_bindings_by_character", 300) as Array).size(), 0, "角色B 无绑定")


func test_stack_card_already_bound_rejects() -> void:
	# C1 回归——已绑定到角色A 的卡不得经 stack_card 静默重映射到角色B
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	bm.call("bind_card", 110, &"tech_sword_01", 300, GONGFA)
	var r: Dictionary = bm.call("stack_card", 110, &"tech_sword_01", 200, 3)
	assert_false(r["stacked"], "已绑定卡不得经 stack 重映射")
	assert_eq(r["reason"], "card_already_bound", "reason card_already_bound")
	assert_eq(int(bm.call("get_character_by_card", 110)), 300, "卡 110 仍属角色B 不受影响")


func test_overwrite_binding_already_bound_rejects() -> void:
	# C1 回归——已绑定到角色B 的卡不得经 overwrite 静默重映射到角色A
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	bm.call("bind_card", 110, &"tech_other_01", 300, GONGFA)
	var r: Dictionary = bm.call("overwrite_binding", 110, &"tech_other_01", 200, 0)
	assert_false(r["success"], "已绑定卡不得经 overwrite 重映射")
	assert_eq(r["reason"], "card_already_bound", "reason card_already_bound")
	assert_eq(int(bm.call("get_character_by_card", 110)), 300, "卡 110 仍属角色B 不受影响")
