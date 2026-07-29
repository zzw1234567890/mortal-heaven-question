extends GutTest
## Story 003 验收测试：InputManager GSM 同步、信号传播与输入分发。
##
## 覆盖 AC-001 到 AC-008 全部验收标准。
## GSM 是 Autoload——测试中直接访问全局 Autoload 实例。
## [br]
## [b]注意:[/b] InputManager 是 Autoload 无 class_name——通过 preload 获取脚本引用。
## 手动调用 _ready() 初始化（_ready 中连接 tree_changed 信号）。

const IM_SCRIPT := preload("res://src/foundation/input_manager.gd")

var im: Node = null

func before_each() -> void:
	# 确保 GSM 处于干净状态
	GameStateManager.set_input_locks([])
	await get_tree().process_frame
	im = IM_SCRIPT.new()
	im._ready()

func after_each() -> void:
	im.free()
	im = null
	GameStateManager.set_input_locks([])


# ═══════════════════════════════════════════════════════════════════════════════
# AC-001: push_lock() → _sync_to_gsm() → GSM.set_input_locks()
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac001_push_lock_syncs_to_gsm() -> void:
	## AC-001: push_lock() 调用 _sync_to_gsm() 后 GSM 中应有锁数据
	im.push_lock(IM_SCRIPT.LockType.DIALOGUE, &"dialogue_test")
	var locks: Array = GameStateManager.get_state("session.input_locks")
	assert_eq(locks.size(), 1, "push DIALOGUE 后 GSM.session.input_locks 应有 1 条记录")
	var entry: Dictionary = locks[0]
	assert_eq(entry["type"], IM_SCRIPT.LockType.DIALOGUE, "锁类型应为 DIALOGUE(0)")
	assert_eq(entry["source"], &"dialogue_test", "source 应为 'dialogue_test'")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-002: pop_lock() → _sync_to_gsm() → GSM 更新
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac002_pop_lock_syncs_to_gsm() -> void:
	## AC-002: pop_lock() 后 GSM 中锁数据应为空
	im.push_lock(IM_SCRIPT.LockType.ANIMATION, &"anim_test")
	im.pop_lock(&"anim_test")
	var locks: Array = GameStateManager.get_state("session.input_locks")
	assert_eq(locks.size(), 0, "pop 后 GSM.session.input_locks 应为空数组")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-003: clear_locks() → _sync_to_gsm() → 空数组
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac003_clear_locks_syncs_empty_array() -> void:
	## AC-003: clear_locks() 无参 → GSM 写入空数组
	im.push_lock(IM_SCRIPT.LockType.DIALOGUE, &"dialogue_test")
	im.push_lock(IM_SCRIPT.LockType.ANIMATION, &"anim_test")
	im.clear_locks()
	var locks: Array = GameStateManager.get_state("session.input_locks")
	assert_eq(locks.size(), 0, "clear_locks() 后 GSM.session.input_locks 应为空数组")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-005: 序列化格式 —— Array[Dictionary] {type, source, device_mask}
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac005_sync_format_contains_type_source_mask() -> void:
	## AC-005: _sync_to_gsm() 序列化格式：Array[Dictionary]，每元素含 type/source/device_mask
	im.push_lock(IM_SCRIPT.LockType.TRANSITION, &"scene_test",
			IM_SCRIPT.DeviceType.KEYBOARD | IM_SCRIPT.DeviceType.MOUSE)
	var locks: Array = GameStateManager.get_state("session.input_locks")
	assert_eq(locks.size(), 1, "push TRANSITION 后应有 1 条记录")

	var entry: Dictionary = locks[0]
	assert_true(entry.has("type"), "序列化条目应包含 'type' 键")
	assert_true(entry.has("source"), "序列化条目应包含 'source' 键")
	assert_true(entry.has("device_mask"), "序列化条目应包含 'device_mask' 键")
	assert_eq(entry["type"], IM_SCRIPT.LockType.TRANSITION)
	assert_eq(entry["source"], &"scene_test")
	assert_eq(entry["device_mask"], IM_SCRIPT.DeviceType.KEYBOARD | IM_SCRIPT.DeviceType.MOUSE)


func test_ac005_default_device_mask_is_all() -> void:
	## AC-005 补充：未指定 device_mask 时默认值为 DEVICE_ALL(7)
	im.push_lock(IM_SCRIPT.LockType.DIALOGUE, &"default_test")
	var locks: Array = GameStateManager.get_state("session.input_locks")
	assert_eq(locks[0]["device_mask"], IM_SCRIPT.DEVICE_ALL, "默认 device_mask 应为 DEVICE_ALL(7)")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-006: InputManager 自身不声明任何信号
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac006_no_own_signals_declared() -> void:
	## AC-006: InputManager 自身不声明任何信号——通过 GSM batch_updated 传播
	# Godot 4.6 所有 Node 子类都继承以下内置信号
	var builtins := PackedStringArray([
		"script_changed", "tree_entered", "tree_exited", "tree_exiting",
		"ready", "renamed", "child_entered_tree", "child_exiting_tree",
		"child_order_changed", "replacing_by",
		"editor_description_changed", "editor_state_changed", "property_list_changed",
	])
	var user_signals: Array[Dictionary] = []
	for sig in IM_SCRIPT.new().get_signal_list():
		if not builtins.has(sig["name"]):
			user_signals.append(sig)
	assert_eq(user_signals.size(), 0, "InputManager 不应声明任何用户自定义信号")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-007: tree_changed 触发自动清除（栈非空时）
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac007_tree_changed_clears_when_non_empty() -> void:
	## AC-007: tree_changed 回调时若栈非空 → 清除全部锁
	im.push_lock(IM_SCRIPT.LockType.DIALOGUE, &"tree_test")
	assert_eq(im._lock_stack.size(), 1, "push 后栈深度应为 1")

	# 直接调用 _on_tree_changed（模拟 SceneTree 信号）
	im._on_tree_changed()

	assert_eq(im._lock_stack.size(), 0, "tree_changed 后栈应被清空")
	var locks: Array = GameStateManager.get_state("session.input_locks")
	assert_eq(locks.size(), 0, "tree_changed 后 GSM 中锁数据也应为空")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-008: tree_changed 空栈时不写入 GSM（避免不必要的 GSM 写入）
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac008_tree_changed_no_op_when_empty() -> void:
	## AC-008: tree_changed 回调时若栈已空 → 不做任何操作（避免不必要的 GSM 写入）
	# 先 push 再 clear，确保 GSM 中已有空数组
	im.push_lock(IM_SCRIPT.LockType.DIALOGUE, &"empty_test")
	im.clear_locks()  # GSM 现在有空数组

	# 直接调用 _on_tree_changed
	im._on_tree_changed()

	var locks: Array = GameStateManager.get_state("session.input_locks")
	assert_eq(locks.size(), 0, "空栈下 tree_changed 仍应保持 GSM 为空")


# ═══════════════════════════════════════════════════════════════════════════════
# 补充测试：多次 push 后的序列化正确性
# ═══════════════════════════════════════════════════════════════════════════════

func test_multi_lock_serialization_order() -> void:
	## 多次 push 后序列化顺序与 push 顺序一致
	im.push_lock(IM_SCRIPT.LockType.DIALOGUE, &"first")
	im.push_lock(IM_SCRIPT.LockType.ANIMATION, &"second")
	im.push_lock(IM_SCRIPT.LockType.TRANSITION, &"third")

	var locks: Array = GameStateManager.get_state("session.input_locks")
	assert_eq(locks.size(), 3, "应序列化 3 条锁记录")
	assert_eq(locks[0]["source"], &"first", "第 1 条记录 source 应为 'first'")
	assert_eq(locks[1]["source"], &"second", "第 2 条记录 source 应为 'second'")
	assert_eq(locks[2]["source"], &"third", "第 3 条记录 source 应为 'third'")


func test_device_mask_preserved_through_gsm_roundtrip() -> void:
	## 设备掩码经 GSM 序列化/反序列化后应保持不变
	var mask := IM_SCRIPT.DeviceType.MOUSE | IM_SCRIPT.DeviceType.GAMEPAD  # 5
	im.push_lock(IM_SCRIPT.LockType.DIALOGUE, &"mask_test", mask)

	var locks: Array = GameStateManager.get_state("session.input_locks")
	assert_eq(locks[0]["device_mask"], mask, "device_mask 应保持 5 (MOUSE|GAMEPAD)")

	# 验证：仅锁鼠标+手柄（白名单语义——KEYBOARD 不在 mask 中则被阻止）
	# DIALOGUE 锁 → 允许 UI_NAV + DIALOGUE，阻止 GAMEPLAY
	# device_mask=MOUSE|GAMEPAD → 键盘不在白名单内 → _check_device_allowed 返回 false
	assert_false(im.is_input_allowed(IM_SCRIPT.ActionType.UI_NAV, IM_SCRIPT.DeviceType.KEYBOARD),
			"键盘不在 device_mask 中应被阻止")
	assert_false(im.is_input_allowed(IM_SCRIPT.ActionType.GAMEPLAY, IM_SCRIPT.DeviceType.MOUSE),
			"DIALOGUE 锁阻止 GAMEPLAY（鼠标在白名单中但动作被阻止）")
	assert_true(im.is_input_allowed(IM_SCRIPT.ActionType.UI_NAV, IM_SCRIPT.DeviceType.MOUSE),
			"鼠标在白名单中 + UI_NAV 被 DIALOGUE 锁允许")
