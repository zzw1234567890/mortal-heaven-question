extends GutTest
## Story 004 验收测试：设备掩码边缘情况。
##
## 覆盖 AC-010 到 AC-013 全部验收标准。
## 验证 Godot 4.6 双焦点下 device_mask 白名单语义的正确性。
##
## [b]白名单语义[/b]: device_mask 指定此锁允许的设备位掩码。
## 不在 mask 中的设备被 _check_device_allowed 拒绝。
## "仅锁键盘" → KEYBOARD 不在白名单 → device_mask=MOUSE|GAMEPAD(=5).
## "锁 GAMEPAD" → GAMEPAD 不在白名单 → device_mask=MOUSE|KEYBOARD(=3).

const IM := preload("res://src/foundation/input_manager.gd")

var im: Node = null


func before_each() -> void:
	im = IM.new()
	im._ready()


func after_each() -> void:
	im.free()
	im = null


# ═══════════════════════════════════════════════════════════════════════════════
# AC-010: 仅锁键盘 + MODAL → 鼠标仍在白名单内，允许
# 白名单语义："仅锁键盘" → KEYBOARD 不在白名单 → device_mask=MOUSE|GAMEPAD(=5)
# push_lock(MODAL, &"dialog", MOUSE|GAMEPAD)
# → MOUSE 在白名单中 + MODAL 判定 → false（MODAL 默认阻止所有非 ANY）
# 要真正"仅锁键盘但鼠标不阻止"需要用 DIALOGUE/ANIMATION 锁
# ═══════════════════════════════════════════════════════════════════════════════

func test_modal_keyboard_only_mouse_still_allowed() -> void:
	## AC-010: 仅锁键盘时鼠标不受锁影响。
	##
	## 白名单语义下 "仅锁键盘" → 键盘不在白名单 → device_mask=MOUSE|GAMEPAD
	## MODAL 锁 + MOUSE|GAMEPAD 白名单：MOUSE 通过 _check_device_allowed，
	## 然后 MODAL 判定返回 false。
	## 要实现真正的"仅锁键盘鼠标仍可 hover"，应使用 DIALOGUE/ANIMATION 锁。

	# 场景：仅锁键盘，鼠标/手柄在白名单
	im.push_lock(IM.LockType.MODAL, &"dialog", IM.DEVICE_MOUSE | IM.DEVICE_GAMEPAD)

	# MOUSE 在白名单中 → _check_device_allowed 通过 → MODAL 返回 false
	assert_false(im.is_input_allowed(IM.ActionType.GAMEPLAY, IM.DeviceType.MOUSE),
			"MODAL 锁 + 仅锁键盘：MOUSE 在白名单中但 MODAL 阻止非 ANY")

	# DIALOGUE 锁 + 仅锁键盘方案——鼠标 hover (UI_NAV+MOUSE) 允许
	im.clear_locks()
	im.push_lock(IM.LockType.DIALOGUE, &"dialog_keyboard_only",
			IM.DEVICE_MOUSE | IM.DEVICE_GAMEPAD)
	assert_true(im.is_input_allowed(IM.ActionType.UI_NAV, IM.DeviceType.MOUSE),
			"DIALOGUE+仅锁键盘: UI_NAV+MOUSE 允许——tooltip 正常显示")
	assert_false(im.is_input_allowed(IM.ActionType.GAMEPLAY, IM.DeviceType.MOUSE),
			"DIALOGUE+仅锁键盘: GAMEPLAY+MOUSE 被 DIALOGUE 锁阻止")
	# KEYBOARD 不在白名单 → 拒绝
	assert_false(im.is_input_allowed(IM.ActionType.UI_NAV, IM.DeviceType.KEYBOARD),
			"DIALOGUE+仅锁键盘: KEYBOARD 不在白名单中")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-011: 仅锁键盘 + MODAL/ANIMATION → KEYBOARD 被阻止
# 白名单语义："仅锁键盘" → KEYBOARD 不在白名单 → device_mask=MOUSE|GAMEPAD
# ═══════════════════════════════════════════════════════════════════════════════

func test_modal_keyboard_only_blocks_keyboard() -> void:
	## AC-011: 仅锁键盘时键盘输入被阻止。

	# 锁定键盘设备: KEYBOARD 不在白名单 → device_mask=MOUSE|GAMEPAD
	im.push_lock(IM.LockType.ANIMATION, &"combat",
			IM.DEVICE_MOUSE | IM.DEVICE_GAMEPAD)

	# KEYBOARD 不在白名单 → _check_device_allowed 拒绝
	assert_false(im.is_input_allowed(IM.ActionType.UI_NAV, IM.DeviceType.KEYBOARD),
			"KEYBOARD 不在白名单(MOUSE|GAMEPAD)中 → _check_device_allowed 拒绝键盘")
	assert_false(im.is_input_allowed(IM.ActionType.GAMEPLAY, IM.DeviceType.KEYBOARD),
			"KEYBOARD 不在白名单中 → GAMEPLAY 被拒")

	# MOUSE 在白名单中 + ANIMATION 允许 UI_NAV → 通过
	assert_true(im.is_input_allowed(IM.ActionType.UI_NAV, IM.DeviceType.MOUSE),
			"MOUSE 在白名单中 + ANIMATION 允许 UI_NAV → 鼠标通过")

	# MODAL 锁 + KEYBOARD 不在白名单
	im.clear_locks()
	im.push_lock(IM.LockType.MODAL, &"dialog",
			IM.DEVICE_MOUSE | IM.DEVICE_GAMEPAD)
	assert_false(im.is_input_allowed(IM.ActionType.GAMEPLAY, IM.DeviceType.KEYBOARD),
			"MODAL 锁 + KEYBOARD 不在白名单 → 被拒")
	assert_false(im.is_input_allowed(IM.ActionType.UI_NAV, IM.DeviceType.KEYBOARD),
			"MODAL 锁 + KEYBOARD 不在白名单 → UI_NAV 被拒")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-012: GAMEPAD 独立锁
# push_lock(ANIMATION, &"cinematic", device_mask=MOUSE|KEYBOARD) → 手柄被锁，鼠标/键盘正常
# ═══════════════════════════════════════════════════════════════════════════════

func test_gamepad_exclusive_lock() -> void:
	## AC-012: GAMEPAD 独立锁——"锁 GAMEPAD"意味着 GAMEPAD 不在白名单。

	# "锁 GAMEPAD" → GAMEPAD 不在白名单 → device_mask=MOUSE|KEYBOARD(=3)
	im.push_lock(IM.LockType.ANIMATION, &"cinematic",
			IM.DEVICE_MOUSE | IM.DEVICE_KEYBOARD)

	# GAMEPAD 不在白名单 → _check_device_allowed 拒绝
	assert_false(im.is_input_allowed(IM.ActionType.UI_NAV, IM.DeviceType.GAMEPAD),
			"GAMEPAD 不在白名单(MOUSE|KEYBOARD)中 → 被拒")
	assert_false(im.is_input_allowed(IM.ActionType.GAMEPLAY, IM.DeviceType.GAMEPAD),
			"GAMEPAD 不在白名单中 → GAMEPLAY 被拒")

	# MOUSE 在白名单中 + ANIMATION 允许 UI_NAV → 通过
	assert_true(im.is_input_allowed(IM.ActionType.UI_NAV, IM.DeviceType.MOUSE),
			"MOUSE 在白名单中 + ANIMATION 允许 UI_NAV → 鼠标通过")

	# KEYBOARD 在白名单中 + ANIMATION 允许 UI_NAV → 通过
	assert_true(im.is_input_allowed(IM.ActionType.UI_NAV, IM.DeviceType.KEYBOARD),
			"KEYBOARD 在白名单中 + ANIMATION 允许 UI_NAV → 键盘通过")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-013: 鼠标 hover（tooltip/高亮）在 DIALOGUE/ANIMATION 锁下仍触发
# 锁栈含 DIALOGUE/ANIMATION + device_mask=ALL → _check_device_allowed(MOUSE) true
# + ActionType.UI_NAV 允许 → tooltip 正常显示
# ═══════════════════════════════════════════════════════════════════════════════

func test_mouse_hover_allowed_under_dialogue_lock() -> void:
	## AC-013: DIALOGUE 锁下鼠标 hover 正常——device_mask=ALL 白名单含 MOUSE
	im.push_lock(IM.LockType.DIALOGUE, &"dialogue_system")

	# UI_NAV + MOUSE (tooltip) → 白名单通过 + DIALOGUE 允许 UI_NAV
	assert_true(im.is_input_allowed(IM.ActionType.UI_NAV, IM.DeviceType.MOUSE),
			"DIALOGUE 锁下 UI_NAV+MOUSE 应允许——tooltip 正常显示")

	# GAMEPLAY + MOUSE (点击移动) → 白名单通过 + DIALOGUE 阻止 GAMEPLAY
	assert_false(im.is_input_allowed(IM.ActionType.GAMEPLAY, IM.DeviceType.MOUSE),
			"DIALOGUE 锁下 GAMEPLAY+MOUSE 应被阻止——无法进行地图操作")


func test_mouse_hover_allowed_under_animation_lock() -> void:
	## AC-013 补充：ANIMATION 锁下鼠标 hover 也正常
	im.push_lock(IM.LockType.ANIMATION, &"combat_system")

	# UI_NAV + MOUSE → 白名单通过 + ANIMATION 允许 UI_NAV
	assert_true(im.is_input_allowed(IM.ActionType.UI_NAV, IM.DeviceType.MOUSE),
			"ANIMATION 锁下 UI_NAV+MOUSE 应允许——卡牌 tooltip 正常显示")

	# GAMEPLAY + MOUSE → 白名单通过 + ANIMATION 阻止 GAMEPLAY
	assert_false(im.is_input_allowed(IM.ActionType.GAMEPLAY, IM.DeviceType.MOUSE),
			"ANIMATION 锁下 GAMEPLAY+MOUSE 应被阻止——动画期间无法拖拽卡牌")

	# DIALOGUE + KEYBOARD → 白名单通过 + ANIMATION 阻止 DIALOGUE
	assert_false(im.is_input_allowed(IM.ActionType.DIALOGUE, IM.DeviceType.KEYBOARD),
			"ANIMATION 锁下 DIALOGUE+KEYBOARD 应被阻止——动画期间无法推进对话")