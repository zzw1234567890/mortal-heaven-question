extends GutTest
## Story 001 验收测试：InputManager 四级锁栈核心实现。
##
## 覆盖 AC-001 到 AC-014 全部验收标准。
## 每个测试通过 preload + .new() 创建独立 InputManager 实例。
##
## [b]注意:[/b] InputManager 是 Autoload 无 class_name——通过 preload 获取脚本引用。
## 手动调用 _ready() 初始化（无需加入场景树——锁栈不依赖场景上下文）。

const IM_MANAGER_SCRIPT := preload("res://src/foundation/input_manager.gd")

var im: Node = null  ## InputManager 实例——Autoload 无 class_name，通过 preload 获取脚本引用


func before_each() -> void:
	im = IM_MANAGER_SCRIPT.new()
	im._ready()


func after_each() -> void:
	im.free()
	im = null


# ═══════════════════════════════════════════════════════════════════════════════
# AC-001: LockType 枚举定义完整
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac001_locktype_enum_values() -> void:
	assert_eq(IM_MANAGER_SCRIPT.LockType.DIALOGUE, 0, "DIALOGUE 应为 0")
	assert_eq(IM_MANAGER_SCRIPT.LockType.ANIMATION, 1, "ANIMATION 应为 1")
	assert_eq(IM_MANAGER_SCRIPT.LockType.MODAL, 2, "MODAL 应为 2")
	assert_eq(IM_MANAGER_SCRIPT.LockType.TRANSITION, 3, "TRANSITION 应为 3")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-002: LockEntry 内部类字段
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac002_lockentry_fields_exist() -> void:
	var entry := IM_MANAGER_SCRIPT.LockEntry.new()
	entry.type = IM_MANAGER_SCRIPT.LockType.DIALOGUE
	entry.source = &"test_system"
	entry.device_mask = IM_MANAGER_SCRIPT.DEVICE_ALL

	assert_eq(entry.type, IM_MANAGER_SCRIPT.LockType.DIALOGUE, "type 字段应可赋值并读取")
	assert_eq(entry.source, &"test_system", "source 字段应可赋值并读取")
	assert_eq(entry.device_mask, 7, "device_mask 字段应可赋值并读取（DEVICE_ALL=7）")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-003: push_lock 增加栈深度 + 打印日志
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac003_push_lock_adds_entry() -> void:
	im.push_lock(IM_MANAGER_SCRIPT.LockType.DIALOGUE, &"dialogue_system")
	assert_eq(im._lock_stack.size(), 1, "push 后栈深度应为 1")


func test_ac003_push_lock_multiple_sources() -> void:
	im.push_lock(IM_MANAGER_SCRIPT.LockType.DIALOGUE, &"sys_a")
	im.push_lock(IM_MANAGER_SCRIPT.LockType.ANIMATION, &"sys_b")
	assert_eq(im._lock_stack.size(), 2, "push 两个不同 source 后栈深度应为 2")


func test_ac003_push_lock_stores_metadata() -> void:
	im.push_lock(IM_MANAGER_SCRIPT.LockType.ANIMATION, &"combat_system", IM_MANAGER_SCRIPT.DEVICE_MOUSE | IM_MANAGER_SCRIPT.DEVICE_KEYBOARD)
	var snapshot: Array[Dictionary] = im.get_lock_stack()
	assert_eq(snapshot.size(), 1)
	assert_eq(snapshot[0].type, IM_MANAGER_SCRIPT.LockType.ANIMATION)
	assert_eq(snapshot[0].source, &"combat_system")
	assert_eq(snapshot[0].device_mask, 3, "device_mask=MOUSE|KEYBOARD 应为 3")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-004: 同一 source 重复 push → push_warning + 跳过
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac004_duplicate_source_warns_and_skips() -> void:
	im.push_lock(IM_MANAGER_SCRIPT.LockType.DIALOGUE, &"dupe_sys")
	assert_eq(im._lock_stack.size(), 1)

	# 同一 source 再次 push——应跳过且不增加栈
	im.push_lock(IM_MANAGER_SCRIPT.LockType.ANIMATION, &"dupe_sys")
	assert_eq(im._lock_stack.size(), 1, "重复 push 不应增加栈元素")

	# 验证原有条目的类型未被覆盖
	var snapshot: Array[Dictionary] = im.get_lock_stack()
	assert_eq(snapshot[0].type, IM_MANAGER_SCRIPT.LockType.DIALOGUE,
			"重复 push 不应修改已有锁的类型")


func test_ac004_duplicate_source_with_different_type() -> void:
	im.push_lock(IM_MANAGER_SCRIPT.LockType.DIALOGUE, &"sys_a")
	im.push_lock(IM_MANAGER_SCRIPT.LockType.TRANSITION, &"sys_a")
	# 栈深度仍为 1，类型保持 DIALOGUE（首次 push 的那个）
	assert_eq(im._lock_stack.size(), 1)
	assert_eq(im._lock_stack[0].type, IM_MANAGER_SCRIPT.LockType.DIALOGUE)


# ═══════════════════════════════════════════════════════════════════════════════
# AC-005: pop_lock 从栈尾向前查找并移除
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac005_pop_lock_removes_by_source() -> void:
	im.push_lock(IM_MANAGER_SCRIPT.LockType.DIALOGUE, &"sys_a")
	assert_eq(im._lock_stack.size(), 1)
	im.pop_lock(&"sys_a")
	assert_eq(im._lock_stack.size(), 0, "pop 后栈应为空")


func test_ac005_pop_lock_then_push_again() -> void:
	im.push_lock(IM_MANAGER_SCRIPT.LockType.DIALOGUE, &"sys_a")
	im.pop_lock(&"sys_a")
	# pop 后再 push 同一 source 应正常（不触发重复检测）
	im.push_lock(IM_MANAGER_SCRIPT.LockType.ANIMATION, &"sys_a")
	assert_eq(im._lock_stack.size(), 1)
	assert_eq(im._lock_stack[0].type, IM_MANAGER_SCRIPT.LockType.ANIMATION)


# ═══════════════════════════════════════════════════════════════════════════════
# AC-006: pop_lock 不存在的 source → push_warning，栈不变
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac006_pop_nonexistent_source_warns() -> void:
	im.push_lock(IM_MANAGER_SCRIPT.LockType.DIALOGUE, &"real_sys")
	assert_eq(im._lock_stack.size(), 1)
	im.pop_lock(&"nonexistent")
	assert_eq(im._lock_stack.size(), 1, "pop 不存在的 source 后栈不应变化")
	# 原有的锁仍然存在
	assert_eq(im._lock_stack[0].source, &"real_sys")


func test_ac006_pop_on_empty_stack() -> void:
	# 空栈 pop——不应崩溃
	im.pop_lock(&"anything")
	assert_eq(im._lock_stack.size(), 0)


# ═══════════════════════════════════════════════════════════════════════════════
# AC-007: LIFO 栈序——多锁共存后按 source 移除
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac007_multi_lock_lifo_behaviour() -> void:
	im.push_lock(IM_MANAGER_SCRIPT.LockType.DIALOGUE, &"sys_a")
	im.push_lock(IM_MANAGER_SCRIPT.LockType.ANIMATION, &"sys_b")
	assert_eq(im._lock_stack.size(), 2)

	# pop sys_a——即使 sys_a 在栈底，按 LIFO 逆序查找找到并移除
	im.pop_lock(&"sys_a")
	assert_eq(im._lock_stack.size(), 1, "移除 sys_a 后栈应剩 1 个元素")
	assert_eq(im._lock_stack[0].source, &"sys_b", "剩余元素应为 sys_b")

	# pop sys_b——栈清空
	im.pop_lock(&"sys_b")
	assert_eq(im._lock_stack.size(), 0)


func test_ac007_multi_lock_three_sources_remove_middle() -> void:
	im.push_lock(IM_MANAGER_SCRIPT.LockType.DIALOGUE, &"sys_a")
	im.push_lock(IM_MANAGER_SCRIPT.LockType.ANIMATION, &"sys_b")
	im.push_lock(IM_MANAGER_SCRIPT.LockType.MODAL, &"sys_c")
	assert_eq(im._lock_stack.size(), 3)

	# 移除中间的 sys_b
	im.pop_lock(&"sys_b")
	assert_eq(im._lock_stack.size(), 2)
	assert_eq(im._lock_stack[0].source, &"sys_a")
	assert_eq(im._lock_stack[1].source, &"sys_c", "移除中间元素后顺序应保持")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-008: clear_locks 无参——栈清空
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac008_clear_locks_all() -> void:
	im.push_lock(IM_MANAGER_SCRIPT.LockType.DIALOGUE, &"sys_a")
	im.push_lock(IM_MANAGER_SCRIPT.LockType.ANIMATION, &"sys_b")
	im.push_lock(IM_MANAGER_SCRIPT.LockType.TRANSITION, &"sys_c")
	assert_eq(im._lock_stack.size(), 3)

	im.clear_locks()
	assert_eq(im._lock_stack.size(), 0, "无参 clear_locks 应清空栈")


func test_ac008_clear_locks_on_empty_stack() -> void:
	im.clear_locks()
	assert_eq(im._lock_stack.size(), 0, "空栈 clear_locks 不应崩溃")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-009: clear_locks(source) 按 source 过滤清除
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac009_clear_locks_filtered_by_source() -> void:
	im.push_lock(IM_MANAGER_SCRIPT.LockType.DIALOGUE, &"sys_a")
	im.push_lock(IM_MANAGER_SCRIPT.LockType.ANIMATION, &"sys_b")
	im.push_lock(IM_MANAGER_SCRIPT.LockType.MODAL, &"sys_a")  # 同一 source 被重复 push? 不会——AC-004 阻止了它!
	# 实际上 sys_a 重复会跳过，所以栈内只有 sys_a(DIALOGUE) + sys_b(ANIMATION)
	assert_eq(im._lock_stack.size(), 2, "此处应为 2 个元素（sys_a 的第二次 push 被跳过）")

	# 清除 sys_a
	im.clear_locks(&"sys_a")
	assert_eq(im._lock_stack.size(), 1, "清除 sys_a 后应剩 1 个")
	assert_eq(im._lock_stack[0].source, &"sys_b", "剩余应为 sys_b")


func test_ac009_clear_locks_filtered_nonexistent_source() -> void:
	im.push_lock(IM_MANAGER_SCRIPT.LockType.DIALOGUE, &"sys_a")
	im.push_lock(IM_MANAGER_SCRIPT.LockType.ANIMATION, &"sys_b")
	assert_eq(im._lock_stack.size(), 2)

	# 清除不存在的 source——栈不变
	im.clear_locks(&"nonexistent")
	assert_eq(im._lock_stack.size(), 2, "清除不存在的 source 不应影响栈")


func test_ac009_clear_locks_filtered_last_remaining() -> void:
	im.push_lock(IM_MANAGER_SCRIPT.LockType.DIALOGUE, &"only_sys")
	assert_eq(im._lock_stack.size(), 1)
	im.clear_locks(&"only_sys")
	assert_eq(im._lock_stack.size(), 0)


# ═══════════════════════════════════════════════════════════════════════════════
# AC-010: get_current_lock 返回最高 LockType；空栈返回 NO_LOCK
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac010_get_current_lock_returns_highest() -> void:
	im.push_lock(IM_MANAGER_SCRIPT.LockType.DIALOGUE, &"sys_a")
	im.push_lock(IM_MANAGER_SCRIPT.LockType.ANIMATION, &"sys_b")
	assert_eq(im.get_current_lock(), IM_MANAGER_SCRIPT.LockType.ANIMATION,
			"最高锁应为 ANIMATION (=1)")


func test_ac010_get_current_lock_single_entry() -> void:
	im.push_lock(IM_MANAGER_SCRIPT.LockType.TRANSITION, &"sys_t")
	assert_eq(im.get_current_lock(), IM_MANAGER_SCRIPT.LockType.TRANSITION,
			"单锁时应返回该锁类型")


func test_ac010_get_current_lock_empty_stack() -> void:
	assert_eq(im.get_current_lock(), IM_MANAGER_SCRIPT.NO_LOCK,
			"空栈应返回 NO_LOCK (-1)")


func test_ac010_get_current_lock_highest_not_last() -> void:
	# 最高严格度锁在栈中间而非栈尾
	im.push_lock(IM_MANAGER_SCRIPT.LockType.TRANSITION, &"sys_t")
	im.push_lock(IM_MANAGER_SCRIPT.LockType.DIALOGUE, &"sys_d")
	assert_eq(im.get_current_lock(), IM_MANAGER_SCRIPT.LockType.TRANSITION,
			"应返回 TRANSITION (=3)，虽然它在栈底")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-011: get_lock_stack 返回 Array[Dictionary] 快照
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac011_get_lock_stack_returns_snapshot() -> void:
	im.push_lock(IM_MANAGER_SCRIPT.LockType.DIALOGUE, &"sys_a", IM_MANAGER_SCRIPT.DEVICE_ALL)
	im.push_lock(IM_MANAGER_SCRIPT.LockType.ANIMATION, &"sys_b", IM_MANAGER_SCRIPT.DEVICE_MOUSE)

	var snapshot: Array[Dictionary] = im.get_lock_stack()
	assert_eq(snapshot.size(), 2)
	assert_eq(snapshot[0].type, IM_MANAGER_SCRIPT.LockType.DIALOGUE)
	assert_eq(snapshot[0].source, &"sys_a")
	assert_eq(snapshot[0].device_mask, 7)
	assert_eq(snapshot[1].type, IM_MANAGER_SCRIPT.LockType.ANIMATION)
	assert_eq(snapshot[1].source, &"sys_b")
	assert_eq(snapshot[1].device_mask, 1)


func test_ac011_get_lock_stack_empty_returns_empty_array() -> void:
	var snapshot: Array[Dictionary] = im.get_lock_stack()
	assert_eq(snapshot.size(), 0, "空栈快照应为空数组")


func test_ac011_get_lock_stack_is_independent_copy() -> void:
	im.push_lock(IM_MANAGER_SCRIPT.LockType.DIALOGUE, &"sys_a")
	var snapshot: Array[Dictionary] = im.get_lock_stack()
	snapshot.clear()  # 修改快照不应影响内部栈
	assert_eq(im._lock_stack.size(), 1, "修改快照不应影响内部 _lock_stack")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-012: has_lock(source) 查询
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac012_has_lock_true_when_present() -> void:
	im.push_lock(IM_MANAGER_SCRIPT.LockType.DIALOGUE, &"sys_a")
	assert_true(im.has_lock(&"sys_a"), "栈中存在 sys_a 时应返回 true")


func test_ac012_has_lock_false_when_not_present() -> void:
	im.push_lock(IM_MANAGER_SCRIPT.LockType.DIALOGUE, &"sys_a")
	assert_false(im.has_lock(&"sys_b"), "栈中不存在 sys_b 时应返回 false")


func test_ac012_has_lock_false_on_empty_stack() -> void:
	assert_false(im.has_lock(&"anything"), "空栈应返回 false")


func test_ac012_has_lock_after_pop_returns_false() -> void:
	im.push_lock(IM_MANAGER_SCRIPT.LockType.DIALOGUE, &"sys_a")
	im.pop_lock(&"sys_a")
	assert_false(im.has_lock(&"sys_a"), "pop 后应返回 false")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-013: _ready() 初始化 _lock_stack 为空
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac013_ready_initializes_empty_stack() -> void:
	assert_eq(im._lock_stack.size(), 0, "_ready() 后 _lock_stack 应为空")

	# 额外验证：_ready() 后所有查询 API 返回预期空栈值
	assert_eq(im.get_current_lock(), IM_MANAGER_SCRIPT.NO_LOCK)
	assert_eq(im.get_lock_stack().size(), 0)
	assert_false(im.has_lock(&"none"))


func test_ac013_ready_can_be_called_multiple_times() -> void:
	im.push_lock(IM_MANAGER_SCRIPT.LockType.DIALOGUE, &"sys_a")
	im._ready()  # 再次调用 _ready() 应重置栈
	assert_eq(im._lock_stack.size(), 0, "重复 _ready() 后栈应为空")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-014: Autoload 注册——project.godot 中 InputManager 为 #2
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac014_autoload_registered_as_number_two() -> void:
	var config := ConfigFile.new()
	var err := config.load("res://project.godot")
	assert_eq(err, OK, "project.godot 应能被 ConfigFile 加载")

	assert_true(config.has_section_key("autoload", "InputManager"),
			"InputManager 必须在 project.godot [autoload] 中注册")

	# 验证是 #2（GameStateManager 之后，SceneManager 之前）
	# ConfigFile 按写入顺序存储键——验证 autoload 节中键的相对位置
	var keys: PackedStringArray = config.get_section_keys("autoload")
	var gsm_index := -1
	var im_index  := -1
	var sm_index  := -1

	for i in range(keys.size()):
		if keys[i].begins_with("GameStateManager"):
			gsm_index = i
		elif keys[i].begins_with("InputManager"):
			im_index = i
		elif keys[i].begins_with("SceneManager"):
			sm_index = i

	assert_true(gsm_index >= 0, "GameStateManager 必须存在于 autoload 中")
	assert_true(im_index >= 0, "InputManager 必须存在于 autoload 中")
	assert_true(sm_index >= 0, "SceneManager 必须存在于 autoload 中")

	assert_true(gsm_index < im_index,
			"GameStateManager 必须在 InputManager 之前（Autoload #1 vs #2）")
	assert_true(im_index < sm_index,
			"InputManager 必须在 SceneManager 之前（Autoload #2 vs #3）")


func test_ac014_inputmanager_registered_path_matches() -> void:
	var config := ConfigFile.new()
	config.load("res://project.godot")
	# InputManager 路径应为 src/foundation/input_manager.gd
	var path: String = config.get_value("autoload", "InputManager")
	assert_string_contains(path, "input_manager.gd",
			"InputManager autoload 路径应指向 input_manager.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# 补充边界测试
# ═══════════════════════════════════════════════════════════════════════════════

func test_constants_values() -> void:
	assert_eq(IM_MANAGER_SCRIPT.NO_LOCK, -1)
	assert_eq(IM_MANAGER_SCRIPT.DEVICE_MOUSE, 1)
	assert_eq(IM_MANAGER_SCRIPT.DEVICE_KEYBOARD, 2)
	assert_eq(IM_MANAGER_SCRIPT.DEVICE_GAMEPAD, 4)
	assert_eq(IM_MANAGER_SCRIPT.DEVICE_ALL, 7)


func test_device_mask_default_is_all() -> void:
	# push_lock 默认 device_mask 应为 DEVICE_ALL (=7)
	im.push_lock(IM_MANAGER_SCRIPT.LockType.DIALOGUE, &"sys_default")
	assert_eq(im._lock_stack[0].device_mask, 7, "默认 device_mask 应为 DEVICE_ALL (7)")


func test_push_lock_then_pop_twice() -> void:
	im.push_lock(IM_MANAGER_SCRIPT.LockType.DIALOGUE, &"sys_a")
	im.pop_lock(&"sys_a")
	# 第二次 pop 同一 source——应记录警告但栈保持空
	im.pop_lock(&"sys_a")
	assert_eq(im._lock_stack.size(), 0)


func test_pop_lock_removes_only_one_entry() -> void:
	# 虽然 AC-004 阻止了同 source 重复 push，但通过直接修改内部栈
	# 来验证 pop_lock 在找到第一个匹配 source 后就停止（而非移除所有匹配项）
	im.push_lock(IM_MANAGER_SCRIPT.LockType.DIALOGUE, &"sys_a")
	im.push_lock(IM_MANAGER_SCRIPT.LockType.MODAL, &"sys_b")
	im._lock_stack.append(IM_MANAGER_SCRIPT.LockEntry.new())
	im._lock_stack[2].type = IM_MANAGER_SCRIPT.LockType.DIALOGUE
	im._lock_stack[2].source = &"sys_a"
	im._lock_stack[2].device_mask = IM_MANAGER_SCRIPT.DEVICE_ALL
	# 现在栈: [sys_a(DIALOGUE), sys_b(MODAL), sys_a(DIALOGUE)]

	im.pop_lock(&"sys_a")
	# 应从栈尾向前找到最后 push 的 sys_a（索引 2）并移除
	assert_eq(im._lock_stack.size(), 2, "应只移除最后一个匹配项")
	assert_eq(im._lock_stack[0].source, &"sys_a", "第一个 sys_a 应保留")
	assert_eq(im._lock_stack[1].source, &"sys_b", "sys_b 应保留")
