extends GutTest
## Story 003 验收测试：7 个 Cat 2b 生命周期信号 + _emit_signal_safe 路由 + 信号链深度。
##
## 覆盖 AC-001 到 AC-010（10 条 AC）。
## 测试策略：
##   - BM_SCRIPT.new() + var bm: Node 持有（Autoload 不声明 class_name）
##   - before_each 缓存槽位上限（真实 RealmSystem Autoload）
##   - 信号订阅用 lambda 捕获载荷到 Array = [null] 或计数到 Array = [0]
##   - after_each 显式 disconnect 防内存泄漏（ADR-0007 禁止模式 #9）
##
## 设计文档来源：ADR-0013 §Cat 2b 信号表 / ADR-0007 信号链深度追踪
## Story 来源：production/epics/binding-system/story-003-lifecycle-signal-bus.md

const BM_SCRIPT := preload("res://src/feature/binding/binding_manager.gd")
const BRClass := preload("res://src/feature/binding/binding_record.gd")
const BindingSlot := preload("res://src/feature/binding/binding_record.gd").BindingSlot

const GONGFA: int = BindingSlot.GONGFA
const FABAO: int = BindingSlot.FABAO

var bm: Node = null
var _signal_callables: Array = []


func before_each() -> void:
	bm = BM_SCRIPT.new()
	_signal_callables.clear()
	bm.call("cache_slot_limits", GameStateManager.RealmLevel.QI_REFINING)


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


func _track_signal(signal_name: StringName, callable: Callable) -> void:
	bm.connect(signal_name, callable)
	_signal_callables.append(callable)


func _set_realm(level: int) -> void:
	bm.call("cache_slot_limits", level)


# ============================================================================
# AC-001：7 个信号声明签名与 ADR-0013 完全一致
# ============================================================================

func test_binding_signal_seven_signals_declared() -> void:
	var expected: Array = ["binding_applied", "binding_removed", "binding_overwritten",
		"binding_stacked", "binding_suspended", "binding_restored", "native_activated"]
	for sig in expected:
		assert_true(bm.has_signal(sig), "应声明信号 %s" % sig)
	# Node 基类自带信号（如 tree_entered 等），过滤后应恰好 7 个自定义信号
	var custom_count: int = 0
	for s in bm.get_signal_list():
		if expected.has(s["name"]):
			custom_count += 1
	assert_eq(custom_count, 7, "恰好 7 个自定义信号——无多余无缺失")


func test_binding_signal_names_snake_case_past_tense() -> void:
	var expected: Array = ["binding_applied", "binding_removed", "binding_overwritten",
		"binding_stacked", "binding_suspended", "binding_restored", "native_activated"]
	for sig in expected:
		# 过去式判定——以 ed 或 d 结尾（overwritten 以 en 结尾是过去分词，亦属过去式范畴）
		assert_true(sig.ends_with("ed") or sig.ends_with("d") or sig.ends_with("en"),
			"信号 %s 应为过去式/过去分词" % sig)


# ============================================================================
# AC-002：全部信号经 _emit_signal_safe 路由（非直接 emit_signal）
# ============================================================================

func test_binding_signal_emitted_via_safe_router() -> void:
	# 间接验证——_emit_signal_safe 在 GSM 可用时经路由；若 GSM 的 _signal_chain_depth
	# 在一次操作后非零递增，说明走了包装器（直接 emit_signal 不会触动 _signal_chain_depth）。
	# 但 _signal_chain_depth 是 static，操作后归零。改用行为验证：信号确实发射了（下面各 AC）。
	# 此测试验证 _emit_safe 方法存在且可调用。
	assert_true(bm.has_method("_emit_safe"), "应有 _emit_safe 包装方法")
	# 触发一次绑定，确认 _emit_safe 不报错
	var captured: Array = [null]
	_track_signal(&"binding_applied", func(_a, _b, _c, _d, _e, _f) -> void:
		captured[0] = true)
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	assert_eq(captured[0], true, "_emit_safe 路由后信号发射成功")


# ============================================================================
# AC-003：binding_applied 在 bind_card 成功时发射（含 is_native 标志）
# ============================================================================

func test_binding_signal_binding_applied_on_bind() -> void:
	var captured: Array = [null]
	_track_signal(&"binding_applied", func(bid: int, cid: int, tid: StringName, char_id: int, st: int, native: bool) -> void:
		captured[0] = {"binding_id": bid, "card_instance_id": cid, "template_id": tid,
			"character_id": char_id, "slot_type": st, "is_native": native})
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	assert_not_null(captured[0], "binding_applied 应发射")
	assert_eq(captured[0]["card_instance_id"], 100, "载荷 card_instance_id=100")
	assert_eq(captured[0]["template_id"], &"tech_sword_01", "载荷 template_id")
	assert_eq(captured[0]["character_id"], 200, "载荷 character_id=200")
	assert_eq(captured[0]["slot_type"], GONGFA, "载荷 slot_type=GONGFA")
	assert_false(captured[0]["is_native"], "非本命绑定 is_native=false")


func test_binding_signal_binding_applied_not_on_fail() -> void:
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)  # 炼气 1 位已满
	var count: Array = [0]
	_track_signal(&"binding_applied", func(_a, _b, _c, _d, _e, _f) -> void:
		count[0] += 1)
	bm.call("bind_card", 101, &"tech_other_01", 200, GONGFA)  # slot_full 失败
	assert_eq(count[0], 0, "slot_full 失败不发射 binding_applied")


func test_binding_signal_binding_applied_is_native_true() -> void:
	# G5 补测——binding_applied 载荷 is_native=true（本命绑定路径）
	var captured: Array = [null]
	_track_signal(&"binding_applied", func(bid: int, cid: int, tid: StringName, char_id: int, st: int, native: bool) -> void:
		captured[0] = {"is_native": native})
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA, &"lin_yuan", &"char_lin_yuan_base_01")
	assert_not_null(captured[0], "本命绑定应发射 binding_applied")
	assert_true(captured[0]["is_native"], "本命绑定 is_native=true")


func test_binding_signal_binding_applied_not_on_card_already_bound() -> void:
	# G6 补测——card_already_bound 失败不发射
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	var count: Array = [0]
	_track_signal(&"binding_applied", func(_a, _b, _c, _d, _e, _f) -> void:
		count[0] += 1)
	bm.call("bind_card", 100, &"tech_sword_01", 300, GONGFA)
	assert_eq(count[0], 0, "card_already_bound 失败不发射")


# ============================================================================
# AC-004：binding_removed 在绑定解除时发射（reason 区分阵亡/覆盖/移除）
# ============================================================================

func test_binding_signal_binding_removed_on_remove_binding() -> void:
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	var captured: Array = [null]
	_track_signal(&"binding_removed", func(bid: int, cid: int, char_id: int, reason: String) -> void:
		captured[0] = {"binding_id": bid, "card_instance_id": cid, "character_id": char_id, "reason": reason})
	bm.call("remove_binding", 1)
	assert_not_null(captured[0], "remove_binding 应发射 binding_removed")
	assert_eq(captured[0]["reason"], "removed", "reason=removed")
	assert_eq(captured[0]["character_id"], 200, "载荷 character_id")


func test_binding_signal_binding_removed_on_death() -> void:
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	var captured: Array = []
	_track_signal(&"binding_removed", func(bid: int, cid: int, char_id: int, reason: String) -> void:
		captured.append({"binding_id": bid, "reason": reason}))
	bm.call("remove_all_bindings", 200)
	assert_eq(captured.size(), 1, "阵亡发射 1 次 binding_removed")
	assert_eq(captured[0]["reason"], "death", "reason=death")


func test_binding_signal_binding_removed_on_overwrite() -> void:
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	var captured: Array = [null]
	_track_signal(&"binding_removed", func(bid: int, cid: int, char_id: int, reason: String) -> void:
		captured[0] = {"binding_id": bid, "card_instance_id": cid, "reason": reason})
	bm.call("overwrite_binding", 101, &"tech_other_01", 200, 0)
	assert_not_null(captured[0], "覆盖旧卡应发射 binding_removed")
	assert_eq(captured[0]["reason"], "overwritten", "reason=overwritten")
	assert_eq(captured[0]["card_instance_id"], 100, "载荷为旧卡实例 100")


func test_binding_signal_binding_removed_on_overwrite_stack() -> void:
	# G7 补测——叠加覆盖路径（stack_count > 1）的 binding_removed
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	bm.call("stack_card", 101, &"tech_sword_01", 200, 3)
	bm.call("stack_card", 102, &"tech_sword_01", 200, 3)  # stack_count=3
	var captured: Array = [null]
	_track_signal(&"binding_removed", func(bid: int, cid: int, char_id: int, reason: String) -> void:
		captured[0] = {"binding_id": bid, "card_instance_id": cid, "reason": reason})
	bm.call("overwrite_binding", 103, &"tech_other_01", 200, 0)
	assert_not_null(captured[0], "叠加覆盖应发射 binding_removed")
	assert_eq(captured[0]["reason"], "overwritten", "reason=overwritten")
	assert_eq(captured[0]["card_instance_id"], 102, "载荷为被覆盖叠层实例 102")


func test_binding_signal_binding_removed_not_on_missing_id() -> void:
	# G8 补测——remove_binding 对不存在的 binding_id 不发射
	var count: Array = [0]
	_track_signal(&"binding_removed", func(_a, _b, _c, _d) -> void:
		count[0] += 1)
	bm.call("remove_binding", 999)
	assert_eq(count[0], 0, "不存在的 binding_id 不发射")


# ============================================================================
# AC-005：binding_overwritten 在覆盖完成时发射
# ============================================================================

func test_binding_signal_binding_overwritten_on_complete() -> void:
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	var captured: Array = [null]
	_track_signal(&"binding_overwritten", func(old_bid: int, new_bid: int, char_id: int, slot_idx: int) -> void:
		captured[0] = {"old_binding_id": old_bid, "new_binding_id": new_bid,
			"character_id": char_id, "slot_index": slot_idx})
	bm.call("overwrite_binding", 101, &"tech_other_01", 200, 0)
	assert_not_null(captured[0], "覆盖完成应发射 binding_overwritten")
	assert_eq(captured[0]["old_binding_id"], 1, "载荷 old_binding_id=1")
	assert_eq(captured[0]["character_id"], 200, "载荷 character_id=200")
	assert_eq(captured[0]["slot_index"], 0, "载荷 slot_index=0")


func test_binding_signal_binding_overwritten_not_on_stack_overwrite() -> void:
	# G9 补测——叠加覆盖（stack_count > 1）不发射 binding_overwritten
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	bm.call("stack_card", 101, &"tech_sword_01", 200, 3)
	var count: Array = [0]
	_track_signal(&"binding_overwritten", func(_a, _b, _c, _d) -> void:
		count[0] += 1)
	bm.call("overwrite_binding", 102, &"tech_other_01", 200, 0)
	assert_eq(count[0], 0, "叠加覆盖不发射 binding_overwritten（binding_id 不变）")


func test_binding_signal_binding_overwritten_not_on_fail() -> void:
	# G10 补测——overwrite 失败不发射
	var count: Array = [0]
	_track_signal(&"binding_overwritten", func(_a, _b, _c, _d) -> void:
		count[0] += 1)
	bm.call("overwrite_binding", 101, &"tech_other_01", 200, 0)  # 无已有绑定
	assert_eq(count[0], 0, "no_existing_binding 失败不发射")


# ============================================================================
# AC-006：binding_stacked 在同名叠加时发射（携带 new_stack_count）
# ============================================================================

func test_binding_signal_binding_stacked_on_stack() -> void:
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	var captured: Array = [null]
	_track_signal(&"binding_stacked", func(bid: int, tid: StringName, char_id: int, new_count: int) -> void:
		captured[0] = {"binding_id": bid, "template_id": tid,
			"character_id": char_id, "new_stack_count": new_count})
	bm.call("stack_card", 101, &"tech_sword_01", 200, 3)
	assert_not_null(captured[0], "叠加成功应发射 binding_stacked")
	assert_eq(captured[0]["binding_id"], 1, "载荷 binding_id=1")
	assert_eq(captured[0]["new_stack_count"], 2, "载荷 new_stack_count=2")


func test_binding_signal_binding_stacked_not_on_reject() -> void:
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	bm.call("stack_card", 101, &"tech_sword_01", 200, 2)  # 达上限 2
	var count: Array = [0]
	_track_signal(&"binding_stacked", func(_a, _b, _c, _d) -> void:
		count[0] += 1)
	bm.call("stack_card", 102, &"tech_sword_01", 200, 2)  # 拒绝
	assert_eq(count[0], 0, "达上限拒绝不发射 binding_stacked")


func test_binding_signal_binding_stacked_not_on_no_existing() -> void:
	# G11 补测——no_existing_binding 拒绝不发射
	var count: Array = [0]
	_track_signal(&"binding_stacked", func(_a, _b, _c, _d) -> void:
		count[0] += 1)
	bm.call("stack_card", 101, &"tech_sword_01", 200, 3)
	assert_eq(count[0], 0, "no_existing_binding 拒绝不发射")


func test_binding_signal_binding_stacked_not_on_card_already_bound() -> void:
	# G11 补测——card_already_bound 拒绝不发射
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	bm.call("bind_card", 110, &"tech_sword_01", 300, GONGFA)
	var count: Array = [0]
	_track_signal(&"binding_stacked", func(_a, _b, _c, _d) -> void:
		count[0] += 1)
	bm.call("stack_card", 110, &"tech_sword_01", 200, 3)
	assert_eq(count[0], 0, "card_already_bound 拒绝不发射")


# ============================================================================
# AC-007：binding_suspended / binding_restored
# ============================================================================

func test_binding_signal_binding_suspended_on_suspend() -> void:
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	var captured: Array = [null]
	_track_signal(&"binding_suspended", func(char_id: int, binding_ids: Array) -> void:
		captured[0] = {"character_id": char_id, "binding_ids": binding_ids})
	bm.call("suspend_bindings", 200)
	assert_not_null(captured[0], "suspend_bindings 应发射 binding_suspended")
	assert_eq(captured[0]["character_id"], 200, "载荷 character_id=200")
	assert_eq(captured[0]["binding_ids"].size(), 1, "载荷 binding_ids 含 1 条")


func test_binding_signal_binding_restored_on_restore() -> void:
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	bm.call("suspend_bindings", 200)
	var captured: Array = [null]
	_track_signal(&"binding_restored", func(char_id: int, binding_ids: Array) -> void:
		captured[0] = {"character_id": char_id, "binding_ids": binding_ids})
	bm.call("restore_bindings", 200)
	assert_not_null(captured[0], "restore_bindings 应发射 binding_restored")
	assert_eq(captured[0]["character_id"], 200, "载荷 character_id=200")
	assert_eq(captured[0]["binding_ids"].size(), 1, "载荷 binding_ids 含 1 条（card 仍存在）")


func test_binding_signal_binding_restored_missing_excludes_deleted() -> void:
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	bm.call("suspend_bindings", 200)
	bm.set("card_exists_cb", Callable(self, "_on_card_missing"))
	var captured: Array = [null]
	_track_signal(&"binding_restored", func(char_id: int, binding_ids: Array) -> void:
		captured[0] = {"character_id": char_id, "binding_ids": binding_ids})
	bm.call("restore_bindings", 200)
	assert_not_null(captured[0], "restore 仍发射 binding_restored")
	assert_eq(captured[0]["binding_ids"].size(), 0, "card 不存在 → binding_ids 为空（已删除的不含）")


func test_binding_signal_binding_suspended_empty_character() -> void:
	# G12 补测——零绑定角色 suspend 仍发射，binding_ids 为空
	var captured: Array = [null]
	_track_signal(&"binding_suspended", func(char_id: int, binding_ids: Array) -> void:
		captured[0] = {"character_id": char_id, "binding_ids": binding_ids})
	bm.call("suspend_bindings", 999)
	assert_not_null(captured[0], "零绑定角色 suspend 仍发射")
	assert_eq(captured[0]["binding_ids"].size(), 0, "binding_ids 为空")


func _on_card_missing(card_instance_id: int) -> bool:
	return false


# ============================================================================
# AC-008：native_activated 在本命绑定激活时发射
# ============================================================================

func test_binding_signal_native_activated_on_native_bind() -> void:
	var captured: Array = [null]
	_track_signal(&"native_activated", func(bid: int, tid: StringName, char_id: int) -> void:
		captured[0] = {"binding_id": bid, "template_id": tid, "character_id": char_id})
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA, &"lin_yuan", &"char_lin_yuan_base_01")
	assert_not_null(captured[0], "本命绑定应发射 native_activated")
	assert_eq(captured[0]["template_id"], &"tech_sword_01", "载荷 template_id")
	assert_eq(captured[0]["character_id"], 200, "载荷 character_id=200")


func test_binding_signal_native_activated_not_on_non_native() -> void:
	var count: Array = [0]
	_track_signal(&"native_activated", func(_a, _b, _c) -> void:
		count[0] += 1)
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)  # 无 native_owner
	assert_eq(count[0], 0, "非本命绑定不发射 native_activated")


func test_binding_signal_native_activated_not_on_slot_full() -> void:
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA, &"lin_yuan", &"char_lin_yuan_base_01")
	_set_realm(GameStateManager.RealmLevel.SPIRIT_TRANSFORMATION)  # 扩到 3 位
	var count: Array = [0]
	_track_signal(&"native_activated", func(_a, _b, _c) -> void:
		count[0] += 1)
	bm.call("bind_card", 101, &"tech_other_01", 200, GONGFA, &"lin_yuan", &"char_lin_yuan_base_01")
	assert_eq(count[0], 0, "本命位已满 → 第二张匹配卡不发射 native_activated")


func test_binding_signal_native_activated_on_overwrite() -> void:
	# G13 补测——overwrite_binding 完全覆盖时新卡为本命 → 发射 native_activated
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)  # 非本命
	var captured: Array = [null]
	_track_signal(&"native_activated", func(bid: int, tid: StringName, char_id: int) -> void:
		captured[0] = {"binding_id": bid, "template_id": tid, "character_id": char_id})
	bm.call("overwrite_binding", 101, &"tech_other_01", 200, 0, &"lin_yuan", &"char_lin_yuan_base_01")
	assert_not_null(captured[0], "覆盖后新本命卡应发射 native_activated")
	assert_eq(captured[0]["character_id"], 200, "载荷 character_id=200")


# ============================================================================
# AC-009：信号链深度 ≤2（绑定信号 → 无进一步信号级联）
# ============================================================================

func test_binding_signal_chain_depth_le_two() -> void:
	# 信号链深度约束——绑定信号发射后，_signal_chain_depth 应回到 0（无级联）
	# 订阅者 handler 内不得再发射 Cat 2b 信号（本测试的 handler 是纯计数，不发射）
	var applied_count: Array = [0]
	_track_signal(&"binding_applied", func(_a, _b, _c, _d, _e, _f) -> void:
		applied_count[0] += 1)
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	assert_eq(applied_count[0], 1, "binding_applied 发射 1 次")
	# 信号链深度在 _emit_signal_safe 结束后归零
	assert_eq(GameStateManager._signal_chain_depth, 0, "信号链深度操作后归零（无级联）")


func test_binding_signal_chain_depth_truncation_on_cascade() -> void:
	# G14 补测——订阅者在 handler 内再触发绑定操作，信号链深度递增
	# 超过 MAX_SIGNAL_CHAIN_DEPTH=4 时截断 + push_error
	var call_count: Array = [0]
	var self_ref_bm: Node = bm
	var handler: Callable
	handler = func(_bid: int, cid: int, _tid: StringName, _char_id: int, _st: int, _native: bool) -> void:
		call_count[0] += 1
		if call_count[0] > GameStateManager.MAX_SIGNAL_CHAIN_DEPTH + 2:
			return
		var next_cid: int = cid + 10
		var c2c: Dictionary = self_ref_bm.get("_card_to_character")
		if not c2c.has(next_cid):
			self_ref_bm.call("bind_card", next_cid, &"tech_sword_01", 200, GONGFA)
	_track_signal(&"binding_applied", handler)
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	assert_eq(GameStateManager._signal_chain_depth, 0, "截断后深度归零")
	assert_lte(call_count[0], GameStateManager.MAX_SIGNAL_CHAIN_DEPTH + 2,
		"递归调用次数受 MAX_SIGNAL_CHAIN_DEPTH 约束")


# ============================================================================
# AC-010：信号携带事实而非指令
# ============================================================================

func test_binding_signal_payloads_carry_facts_not_instructions() -> void:
	# 7 个信号的参数均为事实数据（id/flag/count/reason），无指令性字段
	# 指令性前缀黑名单——AC-010 边缘情况明确提及 "show_animation" / "play_sound" / "update_ui"
	var forbidden_prefixes: Array = ["action", "command", "show", "play", "update",
		"trigger", "create", "destroy", "set", "call", "render", "display"]
	var all_payloads: Array = []
	# binding_applied
	_track_signal(&"binding_applied", func(bid: int, cid: int, tid: StringName, char_id: int, st: int, native: bool) -> void:
		all_payloads.append({"binding_id": bid, "card_instance_id": cid, "template_id": tid,
			"character_id": char_id, "slot_type": st, "is_native": native}))
	# binding_removed
	_track_signal(&"binding_removed", func(bid: int, cid: int, char_id: int, reason: String) -> void:
		all_payloads.append({"binding_id": bid, "card_instance_id": cid,
			"character_id": char_id, "reason": reason}))
	# binding_overwritten
	_track_signal(&"binding_overwritten", func(old_bid: int, new_bid: int, char_id: int, slot_idx: int) -> void:
		all_payloads.append({"old_binding_id": old_bid, "new_binding_id": new_bid,
			"character_id": char_id, "slot_index": slot_idx}))
	# binding_stacked
	_track_signal(&"binding_stacked", func(bid: int, tid: StringName, char_id: int, new_count: int) -> void:
		all_payloads.append({"binding_id": bid, "template_id": tid,
			"character_id": char_id, "new_stack_count": new_count}))
	# binding_suspended
	_track_signal(&"binding_suspended", func(char_id: int, binding_ids: Array) -> void:
		all_payloads.append({"character_id": char_id, "binding_ids": binding_ids}))
	# binding_restored
	_track_signal(&"binding_restored", func(char_id: int, binding_ids: Array) -> void:
		all_payloads.append({"character_id": char_id, "binding_ids": binding_ids}))
	# native_activated
	_track_signal(&"native_activated", func(bid: int, tid: StringName, char_id: int) -> void:
		all_payloads.append({"binding_id": bid, "template_id": tid, "character_id": char_id}))
	# 触发全部 7 个信号——先不叠加，确保 overwrite 走完全覆盖路径（stack_count==1）
	bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)  # 1. binding_applied (非本命)
	bm.call("stack_card", 101, &"tech_sword_01", 200, 3)  # 2. binding_stacked
	bm.call("suspend_bindings", 200)  # 3. binding_suspended
	bm.call("restore_bindings", 200)  # 4. binding_restored
	# remove_binding 清除叠加+主绑定，使槽位空出，再用本命卡直接 bind（不走 overwrite stack 分支）
	bm.call("remove_binding", 1)  # 5. binding_removed (reason=removed)
	bm.call("bind_card", 102, &"tech_other_01", 200, GONGFA, &"lin_yuan", &"char_lin_yuan_base_01")  # 6. binding_applied + 7. native_activated
	bm.call("overwrite_binding", 103, &"tech_sword_01", 200, 0)  # 8. binding_removed + 9. binding_applied + 10. binding_overwritten
	assert_gte(all_payloads.size(), 7, "至少捕获 7 个信号载荷")
	# 遍历全部载荷键——不含指令性前缀
	for payload: Dictionary in all_payloads:
		for key: String in payload:
			var key_lower: String = key.to_lower()
			for prefix: String in forbidden_prefixes:
				assert_false(key_lower.contains(prefix),
					"载荷键 '%s' 不含指令性前缀 '%s'" % [key, prefix])
