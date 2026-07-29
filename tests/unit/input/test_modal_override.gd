extends GutTest
## Story 004 验收测试：MODAL 覆盖机制。
##
## 覆盖 AC-001 到 AC-009 全部验收标准。
## 每个测试通过 preload + .new() 创建独立 InputManager 实例。
##
## [b]注意:[/b] InputManager 是 Autoload 无 class_name——通过 preload 获取脚本引用。
## 手动调用 _ready() 初始化。

const IM := preload("res://src/foundation/input_manager.gd")

var im: Node = null


func before_each() -> void:
	im = IM.new()
	im._ready()


func after_each() -> void:
	im.free()
	im = null


# ═══════════════════════════════════════════════════════════════════════════════
# AC-001: MODAL 锁阻止非拥有者
# push_lock(MODAL, &"settings_menu") → is_input_allowed(GAMEPLAY, MOUSE) → false
# ═══════════════════════════════════════════════════════════════════════════════

func test_modal_blocks_non_owner() -> void:
	im.push_lock(IM.LockType.MODAL, &"settings_menu")
	assert_false(im.is_input_allowed(IM.ActionType.GAMEPLAY, IM.DeviceType.MOUSE),
			"MODAL 锁下非拥有者 GAMEPLAY+MOUSE 应返回 false")
	assert_false(im.is_input_allowed(IM.ActionType.GAMEPLAY, IM.DeviceType.KEYBOARD),
			"MODAL 锁下非拥有者 GAMEPLAY+KEYBOARD 应返回 false")
	assert_false(im.is_input_allowed(IM.ActionType.DIALOGUE, IM.DeviceType.MOUSE),
			"MODAL 锁下非拥有者 DIALOGUE+MOUSE 应返回 false")
	assert_false(im.is_input_allowed(IM.ActionType.UI_NAV, IM.DeviceType.KEYBOARD),
			"MODAL 锁下非拥有者 UI_NAV+KEYBOARD 应返回 false")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-002: MODAL 拥有者 has_lock 自检通过
# push_lock(MODAL, &"settings_menu") → has_lock(&"settings_menu") → true
# ═══════════════════════════════════════════════════════════════════════════════

func test_modal_owner_has_lock_true() -> void:
	im.push_lock(IM.LockType.MODAL, &"settings_menu")
	assert_true(im.has_lock(&"settings_menu"),
			"MODAL 拥有者 has_lock 应返回 true")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-003: MODAL 拥有者消费模式
# 调用方通过 has_lock(source) + 自行判定允许输入
# ——不在 InputManager 内部实现 MODAL 覆盖
# ═══════════════════════════════════════════════════════════════════════════════

func test_modal_owner_bypass_pattern() -> void:
	## AC-003: 弹窗拥有者消费模式——调用方通过 has_lock() + 自行判定允许输入。
	## 本测试模拟调用方代码模式：弹窗系统在处理输入时的典型流程。
	##
	##   模式: if InputManager.has_lock(&"my_source"):
	##             handle_click()   # 我是 MODAL 拥有者，自判允许
	##             return
	##         if not InputManager.is_input_allowed(…):
	##             return            # 非拥有者，遵守 InputManager 判定
	##         handle_click()

	im.push_lock(IM.LockType.MODAL, &"settings_menu")

	# 模拟弹窗系统拥有者 (source = &"settings_menu")
	var source := &"settings_menu"

	# has_lock 应返回 true
	assert_true(im.has_lock(source), "拥有者 has_lock 应返回 true")

	# Step 2: is_input_allowed 返回 false——非拥有者被阻止
	var input_blocked: bool = not im.is_input_allowed(IM.ActionType.GAMEPLAY, IM.DeviceType.MOUSE)
	assert_true(input_blocked, "is_input_allowed 对非拥有者应返回 false")

	# 非拥有者测试
	var other_source := &"other_menu"
	var other_is_owner: bool = im.has_lock(other_source)
	assert_false(other_is_owner, "非拥有者 has_lock 应返回 false")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-004: MODAL 锁 + 非拥有者 source 调用 has_lock() → false
# ═══════════════════════════════════════════════════════════════════════════════

func test_modal_non_owner_has_lock_false() -> void:
	im.push_lock(IM.LockType.MODAL, &"settings_menu")
	assert_false(im.has_lock(&"other_menu"),
			"非拥有者 source has_lock 应返回 false")
	assert_false(im.has_lock(&"loot_screen"),
			"另一个非拥有者 source has_lock 应返回 false")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-005: 空栈 has_lock → false
# ═══════════════════════════════════════════════════════════════════════════════

func test_has_lock_empty_stack_false() -> void:
	assert_false(im.has_lock(&"anything"),
			"空栈时 has_lock 应返回 false")
	assert_false(im.has_lock(&"settings_menu"),
			"空栈时 has_lock(&'settings_menu') 应返回 false")

	# push + pop 后栈为空
	im.push_lock(IM.LockType.MODAL, &"temp_modal")
	im.pop_lock(&"temp_modal")
	assert_false(im.has_lock(&"temp_modal"),
			"pop 后 has_lock 应返回 false")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-006: 多个 MODAL 锁嵌套——两个拥有者都能 has_lock→true
# ═══════════════════════════════════════════════════════════════════════════════

func test_nested_modal_both_owners_detected() -> void:
	im.push_lock(IM.LockType.MODAL, &"a")
	im.push_lock(IM.LockType.MODAL, &"b")

	assert_true(im.has_lock(&"a"),
			"嵌套 MODAL——&'a' 应 has_lock→true")
	assert_true(im.has_lock(&"b"),
			"嵌套 MODAL——&'b' 应 has_lock→true")
	assert_false(im.has_lock(&"c"),
			"外部 source &'c' 应 has_lock→false")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-007: ESC 键在 MODAL 锁下——is_input_allowed(UI_NAV, KEYBOARD) → false
# InputManager 不做特殊处理；弹窗自行通过 has_lock() 判定是否响应 ESC
# ═══════════════════════════════════════════════════════════════════════════════

func test_esc_key_blocked_under_modal() -> void:
	im.push_lock(IM.LockType.MODAL, &"pause_menu")
	assert_false(im.is_input_allowed(IM.ActionType.UI_NAV, IM.DeviceType.KEYBOARD),
			"MODAL 锁下 ESC(UI_NAV,KEYBOARD) 应返回 false——InputManager 不做特殊处理")

	# 但 MODAL 拥有者可通过 has_lock 自检决定是否响应 ESC
	assert_true(im.has_lock(&"pause_menu"),
			"pause_menu 拥有者可通过 has_lock 判定是否响应 ESC")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-008: GAMEPLAY 输入在 MODAL 锁下——is_input_allowed(GAMEPLAY, KEYBOARD) → false
# ═══════════════════════════════════════════════════════════════════════════════

func test_gameplay_input_blocked_under_modal() -> void:
	im.push_lock(IM.LockType.MODAL, &"loot_screen")
	assert_false(im.is_input_allowed(IM.ActionType.GAMEPLAY, IM.DeviceType.KEYBOARD),
			"MODAL 锁下 GAMEPLAY+KEYBOARD 应返回 false")
	assert_false(im.is_input_allowed(IM.ActionType.GAMEPLAY, IM.DeviceType.MOUSE),
			"MODAL 锁下 GAMEPLAY+MOUSE 应返回 false")
	assert_false(im.is_input_allowed(IM.ActionType.GAMEPLAY, IM.DeviceType.GAMEPAD),
			"MODAL 锁下 GAMEPLAY+GAMEPAD 应返回 false")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-009: TRANSITION 锁覆盖 MODAL 锁
# push(MODAL, &"a") + push(TRANSITION, &"scene") → ANY 仍允许，其他全部阻止
# ═══════════════════════════════════════════════════════════════════════════════

func test_transition_overrides_modal() -> void:
	im.push_lock(IM.LockType.MODAL, &"a")
	im.push_lock(IM.LockType.TRANSITION, &"scene")

	# ANY 始终允许
	assert_true(im.is_input_allowed(IM.ActionType.ANY, IM.DeviceType.MOUSE),
			"TRANSITION 覆盖 MODAL 后 ANY 仍允许")
	assert_true(im.is_input_allowed(IM.ActionType.ANY, IM.DeviceType.KEYBOARD),
			"TRANSITION 覆盖 MODAL 后 ANY+KEYBOARD 仍允许")

	# 所有其他 action 类型返回 false
	for at in [IM.ActionType.GAMEPLAY, IM.ActionType.DIALOGUE, IM.ActionType.UI_NAV]:
		for dev in [IM.DeviceType.MOUSE, IM.DeviceType.KEYBOARD, IM.DeviceType.GAMEPAD]:
			assert_false(im.is_input_allowed(at, dev),
					"TRANSITION 覆盖 MODAL 后 ActionType=%d DeviceType=%d 应返回 false" % [at, dev])

	# TRANSITION 拥有者（scene 系统）has_lock 正常
	assert_true(im.has_lock(&"scene"),
			"TRANSITION 拥有者 has_lock 应返回 true")
	# MODAL 拥有者仍可检测到自己的锁（虽然在栈中排在 TRANSITION 之下）
	assert_true(im.has_lock(&"a"),
			"MODAL 拥有者 has_lock 应返回 true（锁仍在栈中）")
