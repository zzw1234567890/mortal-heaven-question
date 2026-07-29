extends GutTest
## Story 004 验收测试：MODAL 集成场景。
##
## 覆盖 AC-018 到 AC-024。
## 验证调用方锁使用速查表中的各个场景，以及锁栈深度上限。
##
## [b]注意[/b]: 集成测试直接访问 GSM Autoload。InputManager 通过 preload 创建独立实例。

const IM := preload("res://src/foundation/input_manager.gd")

var im: Node = null


func before_each() -> void:
	# 重置 GSM 状态
	GameStateManager.set_input_locks([])
	await get_tree().process_frame
	im = IM.new()
	im._ready()


func after_each() -> void:
	im.free()
	im = null
	GameStateManager.set_input_locks([])


# ═══════════════════════════════════════════════════════════════════════════════
# 基础 MODAL push/pop 周期
# ═══════════════════════════════════════════════════════════════════════════════

func test_modal_push_pop_cycle() -> void:
	## 完整 MODAL push/pop 周期——验证栈恢复

	im.push_lock(IM.LockType.MODAL, &"settings_menu")
	assert_eq(im._lock_stack.size(), 1)

	# MODAL 期间输入被阻止
	assert_false(im.is_input_allowed(IM.ActionType.GAMEPLAY, IM.DeviceType.MOUSE),
			"MODAL 期间 gameplay 被阻止")
	assert_false(im.is_input_allowed(IM.ActionType.UI_NAV, IM.DeviceType.KEYBOARD),
			"MODAL 期间 UI_NAV 被阻止")

	# pop MODAL 恢复
	im.pop_lock(&"settings_menu")
	assert_eq(im._lock_stack.size(), 0)
	assert_true(im.is_input_allowed(IM.ActionType.GAMEPLAY, IM.DeviceType.MOUSE),
			"pop MODAL 后 gameplay 恢复")
	assert_true(im.is_input_allowed(IM.ActionType.UI_NAV, IM.DeviceType.KEYBOARD),
			"pop MODAL 后 UI_NAV 恢复")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-009 集成: TRANSITION 清除 MODAL
# ═══════════════════════════════════════════════════════════════════════════════

func test_transition_clears_modal() -> void:
	im.push_lock(IM.LockType.MODAL, &"settings_menu")
	im.push_lock(IM.LockType.TRANSITION, &"scene_manager")

	# TRANSITION 锁——所有非 ANY 阻止
	for at in [IM.ActionType.GAMEPLAY, IM.ActionType.DIALOGUE, IM.ActionType.UI_NAV]:
		for dev in [IM.DeviceType.MOUSE, IM.DeviceType.KEYBOARD]:
			assert_false(im.is_input_allowed(at, dev),
					"TRANSITION 覆盖 MODAL 后 ActionType=%d DeviceType=%d 应阻止" % [at, dev])

	# 弹出 TRANSITION——恢复到 MODAL 判定
	im.pop_lock(&"scene_manager")
	assert_false(im.is_input_allowed(IM.ActionType.GAMEPLAY, IM.DeviceType.MOUSE),
			"TRANSITION pop 后恢复到 MODAL——GAMEPLAY 仍阻止")
	assert_true(im.has_lock(&"settings_menu"),
			"MODAL 锁仍在栈中")


# ═══════════════════════════════════════════════════════════════════════════════
# 暂停菜单 ESC 在战斗锁下
# ═══════════════════════════════════════════════════════════════════════════════

func test_full_pause_menu_escape_under_combat_lock() -> void:
	# 场景：战斗动画中按 ESC 打开暂停菜单
	im.push_lock(IM.LockType.ANIMATION, &"combat_system")

	# 动画期间 UI_NAV 允许——ESC 可以通过
	assert_true(im.is_input_allowed(IM.ActionType.UI_NAV, IM.DeviceType.KEYBOARD),
			"战斗动画下 ESC(UI_NAV,KEYBOARD) 允许")

	# 打开暂停菜单——push MODAL
	im.push_lock(IM.LockType.MODAL, &"pause_menu")

	# 暂停菜单是 MODAL 拥有者——has_lock 通过
	assert_true(im.has_lock(&"pause_menu"),
			"暂停菜单是 MODAL 拥有者")

	# 非拥有者——输入被阻止
	assert_false(im.is_input_allowed(IM.ActionType.GAMEPLAY, IM.DeviceType.MOUSE),
			"暂停菜单 MODAL 下 GAMEPLAY 阻止")

	# 关闭暂停菜单
	im.pop_lock(&"pause_menu")
	# 恢复到战斗动画锁
	assert_true(im.is_input_allowed(IM.ActionType.UI_NAV, IM.DeviceType.KEYBOARD),
			"pop MODAL 后恢复到 ANIMATION——UI_NAV 允许")
	assert_false(im.is_input_allowed(IM.ActionType.GAMEPLAY, IM.DeviceType.MOUSE),
			"pop MODAL 后恢复到 ANIMATION——GAMEPLAY 阻止")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-018: 对话进行中场景
# push_lock(DIALOGUE, &"dialogue_system", ALL) → gameplay 阻止，dialogue + UI nav 允许
# ═══════════════════════════════════════════════════════════════════════════════

func test_dialogue_scenario_blocks_gameplay() -> void:
	im.push_lock(IM.LockType.DIALOGUE, &"dialogue_system")

	# GAMEPLAY 阻止
	assert_false(im.is_input_allowed(IM.ActionType.GAMEPLAY, IM.DeviceType.MOUSE),
			"对话中 GAMEPLAY+MOUSE 阻止——无法移动地图")
	assert_false(im.is_input_allowed(IM.ActionType.GAMEPLAY, IM.DeviceType.KEYBOARD),
			"对话中 GAMEPLAY+KEYBOARD 阻止——无法触发事件")

	# DIALOGUE 允许
	assert_true(im.is_input_allowed(IM.ActionType.DIALOGUE, IM.DeviceType.MOUSE),
			"对话中 DIALOGUE+MOUSE 允许——选择对话选项")
	assert_true(im.is_input_allowed(IM.ActionType.DIALOGUE, IM.DeviceType.KEYBOARD),
			"对话中 DIALOGUE+KEYBOARD 允许——键盘推进对话")

	# UI_NAV 允许
	assert_true(im.is_input_allowed(IM.ActionType.UI_NAV, IM.DeviceType.MOUSE),
			"对话中 UI_NAV+MOUSE 允许——查看卡牌 tooltip")
	assert_true(im.is_input_allowed(IM.ActionType.UI_NAV, IM.DeviceType.KEYBOARD),
			"对话中 UI_NAV+KEYBOARD 允许——浏览菜单")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-019: 战斗动画场景
# push_lock(ANIMATION, &"combat_system", ALL) → gameplay + dialogue 阻止，UI nav 允许
# ═══════════════════════════════════════════════════════════════════════════════

func test_animation_scenario_blocks_gameplay_dialogue() -> void:
	im.push_lock(IM.LockType.ANIMATION, &"combat_system")

	# GAMEPLAY 阻止
	assert_false(im.is_input_allowed(IM.ActionType.GAMEPLAY, IM.DeviceType.MOUSE),
			"战斗动画中 GAMEPLAY+MOUSE 阻止——无法拖拽卡牌")
	assert_false(im.is_input_allowed(IM.ActionType.GAMEPLAY, IM.DeviceType.KEYBOARD),
			"战斗动画中 GAMEPLAY+KEYBOARD 阻止——无法结束回合")

	# DIALOGUE 阻止
	assert_false(im.is_input_allowed(IM.ActionType.DIALOGUE, IM.DeviceType.MOUSE),
			"战斗动画中 DIALOGUE+MOUSE 阻止——动画中无法对话")
	assert_false(im.is_input_allowed(IM.ActionType.DIALOGUE, IM.DeviceType.KEYBOARD),
			"战斗动画中 DIALOGUE+KEYBOARD 阻止——动画中无法对话")

	# UI_NAV 允许
	assert_true(im.is_input_allowed(IM.ActionType.UI_NAV, IM.DeviceType.MOUSE),
			"战斗动画中 UI_NAV+MOUSE 允许——查看卡牌详情")
	assert_true(im.is_input_allowed(IM.ActionType.UI_NAV, IM.DeviceType.KEYBOARD),
			"战斗动画中 UI_NAV+KEYBOARD 允许——ESC 暂停菜单")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-020: 设置弹窗场景
# push_lock(MODAL, &"settings_menu", ALL) → 弹窗外所有输入阻止
# ═══════════════════════════════════════════════════════════════════════════════

func test_settings_modal_scenario_blocks_all_outside() -> void:
	im.push_lock(IM.LockType.MODAL, &"settings_menu")

	# 所有 action 类型被阻止
	for at in [IM.ActionType.GAMEPLAY, IM.ActionType.DIALOGUE, IM.ActionType.UI_NAV]:
		for dev in [IM.DeviceType.MOUSE, IM.DeviceType.KEYBOARD, IM.DeviceType.GAMEPAD]:
			assert_false(im.is_input_allowed(at, dev),
					"设置弹窗下 ActionType=%d DeviceType=%d 应阻止" % [at, dev])

	# 弹窗本身是拥有者——可通过 has_lock 绕行
	assert_true(im.has_lock(&"settings_menu"),
			"设置弹窗是 MODAL 拥有者——可自判处理内部输入")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-021: 战利品选择场景
# push_lock(MODAL, &"loot_screen", ALL) → 模态覆盖
# ═══════════════════════════════════════════════════════════════════════════════

func test_loot_screen_modal_scenario() -> void:
	# 战利品弹窗在战斗背景下弹出
	im.push_lock(IM.LockType.ANIMATION, &"combat_system")
	im.push_lock(IM.LockType.MODAL, &"loot_screen")
	assert_eq(im._lock_stack.size(), 2)

	# loot_screen 是 MODAL 拥有者
	assert_true(im.has_lock(&"loot_screen"),
			"战利品弹窗是 MODAL 拥有者")
	assert_true(im.has_lock(&"combat_system"),
			"战斗动画锁仍在栈中")

	# 非拥有者——所有输入阻止
	assert_false(im.is_input_allowed(IM.ActionType.GAMEPLAY, IM.DeviceType.MOUSE),
			"战利品弹窗 MODAL 下 gameplay 阻止")
	assert_false(im.is_input_allowed(IM.ActionType.UI_NAV, IM.DeviceType.KEYBOARD),
			"战利品弹窗 MODAL 下 UI_NAV 阻止")

	# 关闭战利品弹窗
	im.pop_lock(&"loot_screen")
	# 恢复到 ANIMATION 判定
	assert_false(im.is_input_allowed(IM.ActionType.GAMEPLAY, IM.DeviceType.MOUSE),
			"pop MODAL 后恢复到 ANIMATION——GAMEPLAY 阻止")
	assert_true(im.is_input_allowed(IM.ActionType.UI_NAV, IM.DeviceType.MOUSE),
			"pop MODAL 后恢复到 ANIMATION——UI_NAV 允许")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-022: 场景加载场景
# push_lock(TRANSITION, &"scene_manager", ALL) → 所有输入阻止
# ═══════════════════════════════════════════════════════════════════════════════

func test_scene_loading_scenario_blocks_all() -> void:
	im.push_lock(IM.LockType.TRANSITION, &"scene_manager")

	# 所有输入阻止
	for at in [IM.ActionType.GAMEPLAY, IM.ActionType.DIALOGUE, IM.ActionType.UI_NAV]:
		for dev in [IM.DeviceType.MOUSE, IM.DeviceType.KEYBOARD, IM.DeviceType.GAMEPAD]:
			assert_false(im.is_input_allowed(at, dev),
					"场景加载中 ActionType=%d DeviceType=%d 应阻止" % [at, dev])

	# ANY 始终允许
	assert_true(im.is_input_allowed(IM.ActionType.ANY, IM.DeviceType.MOUSE),
			"场景加载中 ANY 仍然允许——系统功能不受锁影响")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-023: 仅锁键盘保持鼠标 hover 场景
# push_lock(ANIMATION, &"combat_system", MOUSE|GAMEPAD) → 键盘输入被锁，鼠标 tooltip 仍活跃
# ═══════════════════════════════════════════════════════════════════════════════

func test_keyboard_only_keeps_mouse_hover() -> void:
	# device_mask=MOUSE|GAMEPAD(=5) → KEYBOARD 不在白名单
	# 白名单语义：MOUSE 和 GAMEPAD 在白名单中，KEYBOARD 被排除
	im.push_lock(IM.LockType.ANIMATION, &"combat_system",
			IM.DEVICE_MOUSE | IM.DEVICE_GAMEPAD)

	# 键盘被排除——所有键盘输入被拒
	assert_false(im.is_input_allowed(IM.ActionType.UI_NAV, IM.DeviceType.KEYBOARD),
			"KEYBOARD 不在白名单 → 被拒")
	assert_false(im.is_input_allowed(IM.ActionType.GAMEPLAY, IM.DeviceType.KEYBOARD),
			"KEYBOARD 不在白名单 → GAMEPLAY 被拒")

	# 鼠标在白名单中 + ANIMATION 允许 UI_NAV → tooltip 允许
	assert_true(im.is_input_allowed(IM.ActionType.UI_NAV, IM.DeviceType.MOUSE),
			"MOUSE 在白名单中 + ANIMATION 允许 UI_NAV → tooltip 正常")
	# 鼠标 GAMEPLAY 被 ANIMATION 阻止
	assert_false(im.is_input_allowed(IM.ActionType.GAMEPLAY, IM.DeviceType.MOUSE),
			"MOUSE 在白名单中 + ANIMATION 阻止 GAMEPLAY → 无法拖拽")

	# GAMEPAD 在白名单中 + ANIMATION 允许 UI_NAV
	assert_true(im.is_input_allowed(IM.ActionType.UI_NAV, IM.DeviceType.GAMEPAD),
			"GAMEPAD 在白名单中 + UI_NAV 允许")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-024: 锁栈深度在正常运行中不超过 4 层
# DIALOGUE → ANIMATION → MODAL → TRANSITION
# ═══════════════════════════════════════════════════════════════════════════════

func test_stack_depth_does_not_exceed_4() -> void:
	# 四级全栈——按严格度递增
	im.push_lock(IM.LockType.DIALOGUE, &"dialogue_system")
	im.push_lock(IM.LockType.ANIMATION, &"combat_system")
	im.push_lock(IM.LockType.MODAL, &"settings_menu")
	im.push_lock(IM.LockType.TRANSITION, &"scene_manager")

	assert_eq(im._lock_stack.size(), 4,
			"四级锁栈深度应为 4——DIALOGUE+ANIMATION+MODAL+TRANSITION")

	# TRANSITION 阻止一切
	for at in [IM.ActionType.GAMEPLAY, IM.ActionType.DIALOGUE, IM.ActionType.UI_NAV]:
		for dev in [IM.DeviceType.MOUSE, IM.DeviceType.KEYBOARD]:
			assert_false(im.is_input_allowed(at, dev),
					"四级全栈 TRANSITION 最高——ActionType=%d DeviceType=%d 应阻止" % [at, dev])

	# 逐级 pop
	im.pop_lock(&"scene_manager")
	assert_eq(im._lock_stack.size(), 3, "pop TRANSITION 后深度 3")
	im.pop_lock(&"settings_menu")
	assert_eq(im._lock_stack.size(), 2, "pop MODAL 后深度 2")
	im.pop_lock(&"combat_system")
	assert_eq(im._lock_stack.size(), 1, "pop ANIMATION 后深度 1")
	im.pop_lock(&"dialogue_system")
	assert_eq(im._lock_stack.size(), 0, "全部 pop 后深度 0")


# 验证 4 层共存时各自的 has_lock 正确
func test_stack_depth_stays_at_4_all_owners() -> void:
	im.push_lock(IM.LockType.DIALOGUE, &"a")
	im.push_lock(IM.LockType.ANIMATION, &"b")
	im.push_lock(IM.LockType.MODAL, &"c")
	im.push_lock(IM.LockType.TRANSITION, &"d")

	assert_true(im.has_lock(&"a"))
	assert_true(im.has_lock(&"b"))
	assert_true(im.has_lock(&"c"))
	assert_true(im.has_lock(&"d"))
	assert_false(im.has_lock(&"e"), "外部 source 不应 has_lock→true")


# 三层嵌套场景: DIALOGUE → ANIMATION → MODAL
func test_dialogue_then_animation_then_modal_scenario() -> void:
	# 对话进行中，触发战斗动画，又弹出确认弹窗
	im.push_lock(IM.LockType.DIALOGUE, &"dialogue")
	im.push_lock(IM.LockType.ANIMATION, &"combat")
	im.push_lock(IM.LockType.MODAL, &"confirm")

	# MODAL 阻止一切（最高锁）
	assert_false(im.is_input_allowed(IM.ActionType.GAMEPLAY, IM.DeviceType.MOUSE))
	assert_false(im.is_input_allowed(IM.ActionType.UI_NAV, IM.DeviceType.KEYBOARD))

	# 三个拥有者都可检测
	assert_true(im.has_lock(&"dialogue"))
	assert_true(im.has_lock(&"combat"))
	assert_true(im.has_lock(&"confirm"))

	# pop MODAL 恢复到 ANIMATION
	im.pop_lock(&"confirm")
	assert_false(im.is_input_allowed(IM.ActionType.DIALOGUE, IM.DeviceType.MOUSE),
			"ANIMATION 阻止 DIALOGUE")
	assert_true(im.is_input_allowed(IM.ActionType.UI_NAV, IM.DeviceType.MOUSE),
			"ANIMATION 允许 UI_NAV")

	# pop ANIMATION 恢复到 DIALOGUE
	im.pop_lock(&"combat")
	assert_true(im.is_input_allowed(IM.ActionType.DIALOGUE, IM.DeviceType.MOUSE),
			"DIALOGUE 允许 DIALOGUE")
	assert_false(im.is_input_allowed(IM.ActionType.GAMEPLAY, IM.DeviceType.MOUSE),
			"DIALOGUE 阻止 GAMEPLAY")


# 四层全栈后倒序 pop 全部
func test_full_lock_stack_dialogue_to_transition() -> void:
	im.push_lock(IM.LockType.DIALOGUE, &"sys_a")
	im.push_lock(IM.LockType.ANIMATION, &"sys_b")
	im.push_lock(IM.LockType.MODAL, &"sys_c")
	im.push_lock(IM.LockType.TRANSITION, &"sys_d")
	assert_eq(im._lock_stack.size(), 4)

	# 倒序 pop——正常流程
	im.pop_lock(&"sys_d")
	# 恢复到 MODAL 判定
	assert_false(im.is_input_allowed(IM.ActionType.GAMEPLAY, IM.DeviceType.MOUSE),
			"pop TRANSITION 后 MODAL 最高——阻止 GAMEPLAY")
	assert_true(im.has_lock(&"sys_c"), "sys_c MODAL 仍活跃")

	im.pop_lock(&"sys_c")
	assert_false(im.is_input_allowed(IM.ActionType.GAMEPLAY, IM.DeviceType.MOUSE),
			"pop MODAL 后 ANIMATION 最高——阻止 GAMEPLAY")
	assert_true(im.is_input_allowed(IM.ActionType.UI_NAV, IM.DeviceType.MOUSE),
			"pop MODAL 后 ANIMATION 最高——允许 UI_NAV")

	im.pop_lock(&"sys_b")
	assert_false(im.is_input_allowed(IM.ActionType.GAMEPLAY, IM.DeviceType.MOUSE),
			"pop ANIMATION 后 DIALOGUE 最高——阻止 GAMEPLAY")
	assert_true(im.is_input_allowed(IM.ActionType.DIALOGUE, IM.DeviceType.KEYBOARD),
			"pop ANIMATION 后 DIALOGUE 最高——允许 DIALOGUE")

	im.pop_lock(&"sys_a")
	assert_eq(im._lock_stack.size(), 0, "全部 pop 后栈为空")
	assert_true(im.is_input_allowed(IM.ActionType.GAMEPLAY, IM.DeviceType.MOUSE),
			"全部 pop 后所有输入恢复")
