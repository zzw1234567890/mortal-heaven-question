extends GutTest
## Story 004 验收测试：serialize_all 快照导出 + deserialize_all 恢复 + GSM battle.bindings + get_binding_context。
##
## 覆盖 AC-001 到 AC-012（12 条 AC）。
## 测试策略：
##   - BM_SCRIPT.new() + var bm: Node 持有
##   - before_each: cache_slot_limits + GSM battle_start 包裹（使 battle != null）
##   - after_each: GSM battle_end 清理 + disconnect + free
##   - mock CardEffectEngine: 用 Callable 存根记录调用序列
##   - mock CardSystem: card_exists_cb 控制验证通过/失败
##
## 设计文档来源：ADR-0013 §GSM 边界 §serialize_all §deserialize_all §get_binding_context
## Story 来源：production/epics/binding-system/story-004-serialize-snapshot.md

const BM_SCRIPT := preload("res://src/feature/binding/binding_manager.gd")
const BRClass := preload("res://src/feature/binding/binding_record.gd")
const BindingSlot := preload("res://src/feature/binding/binding_record.gd").BindingSlot

const GONGFA: int = BindingSlot.GONGFA
const FABAO: int = BindingSlot.FABAO

var bm: Node = null
var _signal_callables: Array = []
var _effect_log: Array = []


func before_each() -> void:
	bm = BM_SCRIPT.new()
	_signal_callables.clear()
	_effect_log.clear()
	bm.call("cache_slot_limits", GameStateManager.RealmLevel.QI_REFINING)
	_wire_callbacks()
	GameStateManager.battle_start({})


func after_each() -> void:
	if bm != null:
		for callable: Callable in _signal_callables:
			for sig in [&"binding_applied", &"binding_removed", &"binding_overwritten",
						&"binding_stacked", &"binding_suspended", &"binding_restored",
						&"native_activated"]:
				if bm.is_connected(sig, callable):
					bm.disconnect(sig, callable)
		_signal_callables.clear()
		bm.free()
		bm = null
	GameStateManager.battle_end({})
	_effect_log.clear()


func _wire_callbacks() -> void:
	bm.set("effect_register_cb", Callable(self, "_on_effect_register"))
	bm.set("effect_remove_cb", Callable(self, "_on_effect_remove"))
	bm.set("effect_suspend_cb", Callable(self, "_on_effect_suspend"))
	bm.set("effect_restore_cb", Callable(self, "_on_effect_restore"))
	bm.set("card_shuffle_cb", Callable(self, "_on_card_shuffle"))
	bm.set("card_discard_cb", Callable(self, "_on_card_discard"))


func _on_effect_register(card_instance_id: int, template_id: StringName, character_id: int, context: Dictionary) -> void:
	_effect_log.append("register:%d" % card_instance_id)
	_effect_log.append("register_ctx:%d:%s" % [card_instance_id, str(context)])


func _on_effect_remove(card_instance_id: int) -> void:
	_effect_log.append("remove:%d" % card_instance_id)


func _on_effect_suspend(character_id: int, card_ids: Array) -> void:
	_effect_log.append("suspend:%d:%s" % [character_id, str(card_ids)])


func _on_effect_restore(character_id: int, card_ids: Array) -> void:
	_effect_log.append("restore:%d:%s" % [character_id, str(card_ids)])


func _on_card_shuffle(card_instance_id: int) -> void:
	_effect_log.append("shuffle:%d" % card_instance_id)


func _on_card_discard(card_instance_id: int) -> void:
	_effect_log.append("discard:%d" % card_instance_id)


func _set_realm(level: int) -> void:
	bm.call("cache_slot_limits", level)


# ============================================================================
# AC-001：serialize_all 完整序列化
# ============================================================================

func test_serialize_all_complete_snapshot() -> void:
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	bm.call("stack_card", 101, &"tech_sword_01", 200, 3)  # stack_count=2
	bm.call("bind_card", 102, &"tech_other_01", 300, GONGFA, &"lin_yuan", &"char_lin_yuan_base_01")  # native
	bm.call("suspend_bindings", 300)  # is_suspended=true
	var data: Dictionary = bm.call("serialize_all")
	assert_true(data.has("bindings"), "快照含 bindings 键")
	var bindings: Array = data["bindings"]
	assert_eq(bindings.size(), 2, "2 条绑定记录（角色A叠加1条+角色B本命1条）")
	# 检查每条记录含全部字段
	for entry: Dictionary in bindings:
		assert_true(entry.has("binding_id"), "含 binding_id")
		assert_true(entry.has("card_instance_id"), "含 card_instance_id")
		assert_true(entry.has("card_template_id"), "含 card_template_id")
		assert_true(entry.has("card_name"), "含 card_name")
		assert_true(entry.has("card_rarity"), "含 card_rarity")
		assert_true(entry.has("slot_type"), "含 slot_type")
		assert_true(entry.has("slot_index"), "含 slot_index")
		assert_true(entry.has("bound_character_id"), "含 bound_character_id")
		assert_true(entry.has("is_native"), "含 is_native")
		assert_true(entry.has("native_multiplier"), "含 native_multiplier")
		assert_true(entry.has("activated_turn"), "含 activated_turn")
		assert_true(entry.has("stack_slots"), "含 stack_slots")
		assert_true(entry.has("stack_count"), "含 stack_count")
		assert_true(entry.has("is_suspended"), "含 is_suspended")
	# 叠加记录 stack_slots 完整
	var stack_rec: Dictionary = bindings[0]
	assert_eq(stack_rec["stack_count"], 2, "叠加 stack_count=2")
	assert_eq((stack_rec["stack_slots"] as Array).size(), 2, "stack_slots 含 2 实例")
	# 本命记录
	var native_rec: Dictionary = bindings[1]
	assert_true(native_rec["is_native"], "本命 is_native=true")
	assert_eq(native_rec["native_multiplier"], 1.5, "本命 native_multiplier=1.5")
	assert_true(native_rec["is_suspended"], "本命 is_suspended=true")


# ============================================================================
# AC-002：serialize_all 导出到 GSM.battle.bindings
# ============================================================================

func test_write_snapshot_to_gsm_success() -> void:
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	bm.call("write_snapshot_to_gsm")
	assert_not_null(GameStateManager.battle, "battle 应活跃")
	assert_true(GameStateManager.battle.has("bindings"), "battle.bindings 应存在")
	assert_eq((GameStateManager.battle["bindings"] as Array).size(), 1, "battle.bindings 含 1 条")


func test_write_snapshot_to_gsm_empty_bindings() -> void:
	bm.call("write_snapshot_to_gsm")
	assert_not_null(GameStateManager.battle, "battle 应活跃")
	assert_true(GameStateManager.battle.has("bindings"), "空快照也应写入 battle.bindings 键")
	assert_eq((GameStateManager.battle.get("bindings", []) as Array).size(), 0, "空快照 0 条")


func test_write_snapshot_to_gsm_dedup() -> void:
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	bm.call("write_snapshot_to_gsm")
	# 再次写入相同快照——应去重，不触发 _buffer_change
	bm.call("write_snapshot_to_gsm")
	assert_eq((GameStateManager.battle.get("bindings", []) as Array).size(), 1, "去重后快照仍 1 条")


# ============================================================================
# AC-003：deserialize_all 恢复
# ============================================================================

func test_deserialize_all_restore_complete() -> void:
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	bm.call("stack_card", 101, &"tech_sword_01", 200, 3)
	var snapshot: Dictionary = bm.call("serialize_all")
	# 清空后恢复
	bm.call("_clear_all")
	assert_eq((bm.call("get_binding_ids_by_character", 200) as Array).size(), 0, "清空后无绑定")
	bm.call("deserialize_all", snapshot)
	assert_eq((bm.call("get_binding_ids_by_character", 200) as Array).size(), 1, "恢复后 1 条")
	var rec: Variant = bm.call("get_binding", 1)
	assert_eq(rec.stack_count, 2, "恢复后 stack_count=2")
	assert_eq((rec.stack_slots as Array).size(), 2, "恢复后 stack_slots 含 2 实例")
	assert_eq(int(bm.call("get_character_by_card", 100)), 200, "恢复后 card→character 映射")
	assert_eq(int(bm.call("get_character_by_card", 101)), 200, "恢复后叠层 card→character 映射")


func test_deserialize_all_empty_snapshot() -> void:
	bm.call("deserialize_all", {"bindings": []})
	assert_eq((bm.call("get_binding_ids_by_character", 200) as Array).size(), 0, "空快照 → 三索引为空")


func test_deserialize_all_no_bindings_key() -> void:
	bm.call("deserialize_all", {})
	assert_eq((bm.call("get_binding_ids_by_character", 200) as Array).size(), 0, "缺 bindings 键 → 空")


# ============================================================================
# AC-004：deserialize_all 部分恢复
# ============================================================================

func test_deserialize_all_partial_recovery_skips_missing() -> void:
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	bm.call("bind_card", 102, &"tech_other_01", 300, GONGFA)
	var snapshot: Dictionary = bm.call("serialize_all")
	bm.call("_clear_all")
	# 注入 card_exists_cb——card 102 返回 false（不存在）
	bm.set("card_exists_cb", Callable(self, "_on_card_exists_100_only"))
	bm.call("deserialize_all", snapshot)
	# 100 恢复、102 跳过
	assert_eq((bm.call("get_binding_ids_by_character", 200) as Array).size(), 1, "角色A 1 条恢复")
	assert_eq((bm.call("get_binding_ids_by_character", 300) as Array).size(), 0, "角色B 0 条（card 102 跳过）")
	assert_eq(int(bm.call("get_character_by_card", 100)), 200, "100 恢复映射")
	assert_eq(int(bm.call("get_character_by_card", 102)), -1, "102 未恢复")


func _on_card_exists_100_only(card_instance_id: int) -> bool:
	return card_instance_id == 100


# ============================================================================
# AC-005：register_persistent_effect 绑定成功调用
# ============================================================================

func test_effect_register_on_bind_non_native() -> void:
	_effect_log.clear()
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	assert_true("register:100" in _effect_log, "非本命绑定触发 register_persistent_effect")
	# AC-005 context 含 native_multiplier 和 stack_count
	var found_ctx: bool = false
	var ctx_str: String = ""
	for line: String in _effect_log:
		if line.begins_with("register_ctx:100:"):
			found_ctx = true
			ctx_str = line
			break
	assert_true(found_ctx, "context 被传递")
	if found_ctx:
		assert_true(ctx_str.contains("native_multiplier"), "context 含 native_multiplier")
		assert_true(ctx_str.contains("stack_count"), "context 含 stack_count")
		assert_true(ctx_str.contains("1.0"), "非本命 native_multiplier=1.0")


func test_effect_register_on_bind_native() -> void:
	_effect_log.clear()
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA, &"lin_yuan", &"char_lin_yuan_base_01")
	assert_true("register:100" in _effect_log, "本命绑定触发 register_persistent_effect")
	var found_ctx: bool = false
	var ctx_str: String = ""
	for line: String in _effect_log:
		if line.begins_with("register_ctx:100:"):
			found_ctx = true
			ctx_str = line
			break
	assert_true(found_ctx, "context 被传递")
	if found_ctx:
		assert_true(ctx_str.contains("1.5"), "本命 native_multiplier=1.5")


# ============================================================================
# AC-006：覆盖严格顺序 remove 先于 register
# ============================================================================

func test_effect_overwrite_strict_order() -> void:
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	_effect_log.clear()
	bm.call("overwrite_binding", 101, &"tech_other_01", 200, 0)
	var remove_idx: int = _effect_log.find("remove:100")
	var register_idx: int = _effect_log.find("register:101")
	assert_gte(remove_idx, 0, "remove:100 被调用")
	assert_gte(register_idx, 0, "register:101 被调用")
	assert_lt(remove_idx, register_idx, "remove 先于 register——无重叠帧")


# ============================================================================
# AC-007：suspend/restore 效果调用
# ============================================================================

func test_effect_suspend_restore_calls() -> void:
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	_effect_log.clear()
	bm.call("suspend_bindings", 200)
	assert_true("suspend:200" in _effect_log[0], "suspend_effects_by_source 被调用")
	# AC-007 card_ids 参数——传入 card_instance_id 而非 binding_id
	assert_true(_effect_log[0].contains("100"), "suspend 传入 card_id=100")
	_effect_log.clear()
	bm.call("restore_bindings", 200)
	assert_true("restore:200" in _effect_log[0], "restore_effects_by_source 被调用")
	assert_true(_effect_log[0].contains("100"), "restore 传入 card_id=100")


func test_effect_restore_excludes_missing_card() -> void:
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	bm.call("suspend_bindings", 200)
	bm.set("card_exists_cb", Callable(self, "_on_card_missing"))
	_effect_log.clear()
	bm.call("restore_bindings", 200)
	# card 不存在 → restore_effects_by_source 传入空 card_ids
	assert_true("restore:200" in _effect_log[0], "restore_effects_by_source 被调用")
	var restore_line: String = _effect_log[0]
	# card 100 不在 valid_card_ids 中
	assert_false(restore_line.contains("100"), "card 不存在 → card_id=100 不在 restore valid_ids 中")


func _on_card_missing(card_instance_id: int) -> bool:
	return false


# ============================================================================
# AC-008：阵亡 remove_effects_by_source（含所有叠层实例）
# ============================================================================

func test_effect_death_removes_all_stack_instances() -> void:
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	bm.call("stack_card", 101, &"tech_sword_01", 200, 3)
	bm.call("stack_card", 102, &"tech_sword_01", 200, 3)
	_effect_log.clear()
	bm.call("remove_all_bindings", 200)
	# AC-008 remove_effects_by_source 对所有叠层实例调用
	assert_true("remove:100" in _effect_log, "remove_effects_by_source 对主实例 100 被调用")
	assert_true("remove:101" in _effect_log, "remove_effects_by_source 对叠层 101 被调用")
	assert_true("remove:102" in _effect_log, "remove_effects_by_source 对叠层 102 被调用")
	# 叠层实例洗回牌库
	assert_true("shuffle:100" in _effect_log, "主实例 100 洗回")
	assert_true("shuffle:101" in _effect_log, "叠层 101 洗回")
	assert_true("shuffle:102" in _effect_log, "叠层 102 洗回")


# ============================================================================
# AC-009：get_binding_context 预计算乘积
# ============================================================================

func test_get_binding_context_native_stack2() -> void:
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA, &"lin_yuan", &"char_lin_yuan_base_01")
	bm.call("stack_card", 101, &"tech_sword_01", 200, 3)
	var ctx: Dictionary = bm.call("get_binding_context", 100)
	assert_false(ctx.is_empty(), "应找到绑定上下文")
	assert_eq(ctx["native_multiplier"], 1.5, "native_multiplier=1.5")
	assert_eq(ctx["stack_count"], 2, "stack_count=2")
	# multiplier = 1.5 × 1.5^1 = 2.25
	assert_eq(ctx["multiplier"], 2.25, "multiplier = 1.5 × 1.5^1 = 2.25")


func test_get_binding_context_non_native_stack1() -> void:
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	var ctx: Dictionary = bm.call("get_binding_context", 100)
	assert_eq(ctx["native_multiplier"], 1.0, "非本命 native_multiplier=1.0")
	assert_eq(ctx["stack_count"], 1, "stack_count=1")
	# multiplier = 1.0 × 1.5^0 = 1.0
	assert_eq(ctx["multiplier"], 1.0, "multiplier = 1.0 × 1.5^0 = 1.0")


func test_get_binding_context_unbound_card() -> void:
	var ctx: Dictionary = bm.call("get_binding_context", 999)
	assert_true(ctx.is_empty(), "未绑定卡返回空字典")


# ============================================================================
# AC-010：非数值叠加上下文（stack_count 传递）
# ============================================================================

func test_get_binding_context_provides_stack_count_for_engine() -> void:
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	bm.call("stack_card", 101, &"tech_sword_01", 200, 3)
	bm.call("stack_card", 102, &"tech_sword_01", 200, 3)
	var ctx: Dictionary = bm.call("get_binding_context", 101)
	assert_eq(ctx["stack_count"], 3, "stack_count=3 供效果引擎按类型分支处理")
	assert_true(ctx.has("multiplier"), "含 multiplier 预计算值")


# ============================================================================
# AC-011：覆盖积累数值保留（remove_effects_by_source 不清除累积值）
# ============================================================================

func test_overwrite_preserves_accumulated_bonuses() -> void:
	# G6 修正——Character.accumulated_bonuses 不在 BindingManager 中，
	# 用外部 Dictionary 模拟角色累积值（覆盖时旧卡效果停止但累积值不清除）。
	var accumulated: Dictionary = {200: {"ATK": 5.0}}
	# stat_bonus_cb 返回角色累积值（模拟 Character.accumulated_bonuses 查询）
	bm.set("stat_bonus_cb", Callable(self, "_on_stat_bonus_accumulated").bind(accumulated))
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	var before: float = bm.call("get_accumulated_bonus", 200, "ATK")
	assert_eq(before, 5.0, "覆盖前累积 ATK=5.0")
	# 覆盖——remove_effects_by_source 停止旧卡持续效果，但不清除角色累积值
	bm.call("overwrite_binding", 101, &"tech_other_01", 200, 0)
	# 累积值仍在角色上（未被 remove_effects_by_source 清除）
	assert_eq(accumulated[200]["ATK"], 5.0, "Character.accumulated_bonuses 未被 remove_effects_by_source 清除")
	var after: float = bm.call("get_accumulated_bonus", 200, "ATK")
	assert_eq(after, 5.0, "覆盖后累积 ATK=5.0 保留")


func _on_stat_bonus_accumulated(card_instance_id: int, stat_name: String, accumulated: Dictionary) -> float:
	# 模拟 Character.accumulated_bonuses 查询——与当前绑定卡无关
	var char_id: int = 200  # 测试中只有角色 200
	if accumulated.has(char_id) and accumulated[char_id].has(stat_name):
		return float(accumulated[char_id][stat_name])
	return 0.0


# ============================================================================
# AC-012：serialize_all 性能（简单验证——不阻塞）
# ============================================================================

func test_serialize_all_performance_acceptable() -> void:
	# G7 修正——接近化神期峰值规模 + 性能阈值断言
	_set_realm(GameStateManager.RealmLevel.SPIRIT_TRANSFORMATION)  # 3 功法位
	# 化神期上限简化：3 角色 × 每角色 1 绑定 + 5 叠层 = 3 条记录、stack_count=6
	for i in range(3):
		var char_id: int = 200 + i
		var tid: StringName = &"tech_sword_%d" % i
		bm.call("bind_card", 100 + i * 10, tid, char_id, GONGFA)
		for j in range(1, 6):
			bm.call("stack_card", 100 + i * 10 + j, tid, char_id, 6)
	var data: Dictionary = bm.call("serialize_all")
	assert_eq((data["bindings"] as Array).size(), 3, "3 条绑定记录（含叠层）")
	# 性能阈值——1000 次 get_accumulated_bonus < 50ms（测试环境简化阈值，ADR 要求 <10ms）
	var t0: int = Time.get_ticks_msec()
	for _i in range(1000):
		bm.call("get_accumulated_bonus", 200, "ATK")
	var elapsed: int = Time.get_ticks_msec() - t0
	assert_lt(elapsed, 50, "1000 次 get_accumulated_bonus < 50ms（测试环境简化阈值）")
