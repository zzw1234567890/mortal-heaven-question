extends "res://tests/integration/hud/pause_menu_fixture.gd"
## 暂停菜单「输入锁定与 ESC 开关配对」验收。[br]
## [br][b]为什么需要[/b]：暂停的全部意义是「下层不再吃输入」——而这条保证由三件事
## 叠起来：MODAL 锁（InputManager 层拦截）、[code]SceneTree.paused[/code]（冻结
## PAUSABLE 节点）、菜单自己开合严格配对（[code]push_lock[/code] /
## [code]pop_lock[/code] 各一次）。三者任一出偏差，症状都是「暂停了还能走位」或
## 「关了菜单输入再也不回来」（锁泄漏）。[br]
## [br][b]覆盖[/b]：[br]
##   1. 打开：MODAL 锁 +1、暂停生效、下层玩法输入被拦（UI 导航仍放行给模态拥有者）；[br]
##   2. 关闭：锁 pop 干净（栈回到 0）、暂停解除、玩法输入恢复；[br]
##   3. 配对：多轮开关后锁栈不累积（各一次，不多不少）；[br]
##   4. 幂等：暂停中重复 request_open 不重复压锁、未打开时 request_close 无副作用；[br]
##   5. ESC：打开关一次（配对），读档面板开着时第一下只收面板；[br]
##   6. 非锁拥有者时 ESC 不关菜单（其他模态接管后不应误关）；echo 事件不重复触发。[br]
## [br]装置见 [code]pause_menu_fixture.gd[/code]。[br]
##
## 来源: ADR-0031 §1.1（开合配对）、design/ux/pause-menu.md（输入锁定）、
## hud Story 005 AC-1/AC-6、code-review G-6/B-3。

const IM := preload("res://src/foundation/input_manager.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# 打开：锁 + 暂停 + 拦截
# ═══════════════════════════════════════════════════════════════════════════════

func test_open_pushes_modal_lock_and_pauses_tree() -> void:
	# Act
	open_menu()
	# Assert
	assert_true(get_tree().paused, "打开应置 SceneTree.paused = true")
	assert_true(menu.visible, "打开后菜单应可见")
	assert_true(InputManager.has_lock(&"pause_menu"), "打开应 push MODAL 锁")
	assert_eq(InputManager.get_lock_stack().size(), 1, "打开应恰好压一层锁")


func test_open_freezes_lower_gameplay_input() -> void:
	## 暂停期间探索/战斗的玩法输入必须被拦——这是「暂停」二字的全部含义。
	# Arrange —— 打开前玩法输入是放行的
	assert_true(InputManager.is_input_allowed(IM.ActionType.GAMEPLAY, IM.DeviceType.MOUSE),
			"前置：未暂停时玩法输入放行")
	# Act
	open_menu()
	# Assert
	assert_false(InputManager.is_input_allowed(IM.ActionType.GAMEPLAY, IM.DeviceType.MOUSE),
			"暂停中鼠标玩法输入应被 MODAL 锁拦下")
	assert_false(InputManager.is_input_allowed(IM.ActionType.GAMEPLAY, IM.DeviceType.KEYBOARD),
			"暂停中键盘玩法输入应被 MODAL 锁拦下")
	assert_true(InputManager.is_action_blocked(&"end_turn"),
			"内置分类映射下的玩法动作同样应被拦下")


func test_open_suspends_audio_once() -> void:
	# Act
	open_menu()
	# Assert
	assert_eq(adapter.suspend_calls, 1, "打开应调用 adapter.suspend() 一次")
	assert_eq(adapter.resume_calls, 0, "打开不应调用 adapter.resume()")


# ═══════════════════════════════════════════════════════════════════════════════
# 关闭：恢复
# ═══════════════════════════════════════════════════════════════════════════════

func test_close_pops_lock_and_resumes_tree() -> void:
	# Arrange
	open_menu()
	# Act
	menu.request_close()
	# Assert
	assert_false(get_tree().paused, "关闭应解除暂停")
	assert_false(menu.visible, "关闭后菜单应隐藏")
	assert_false(InputManager.has_lock(&"pause_menu"), "关闭应 pop MODAL 锁")
	assert_eq(InputManager.get_lock_stack().size(), 0, "关闭后锁栈应清空")


func test_close_restores_lower_gameplay_input() -> void:
	# Arrange
	open_menu()
	# Act
	menu.request_close()
	# Assert
	assert_true(InputManager.is_input_allowed(IM.ActionType.GAMEPLAY, IM.DeviceType.MOUSE),
			"关闭后鼠标玩法输入应恢复")
	assert_true(InputManager.is_input_allowed(IM.ActionType.GAMEPLAY, IM.DeviceType.KEYBOARD),
			"关闭后键盘玩法输入应恢复")
	assert_eq(adapter.resume_calls, 1, "关闭应调用 adapter.resume() 一次")


func test_lock_stack_does_not_accumulate_across_cycles() -> void:
	## push / pop 各一次——多轮开关后锁栈必须回到 0（泄漏会让输入再也回不来）。
	# Act
	for i: int in range(3):
		open_menu()
		assert_eq(InputManager.get_lock_stack().size(), 1,
				"第 %d 轮打开应恰好一层锁" % (i + 1))
		menu.request_close()
		assert_eq(InputManager.get_lock_stack().size(), 0,
				"第 %d 轮关闭应清空锁栈" % (i + 1))
	# Assert
	assert_eq(adapter.suspend_calls, 3, "三轮打开应 suspend 三次")
	assert_eq(adapter.resume_calls, 3, "三轮关闭应 resume 三次（配对无偏差）")


# ═══════════════════════════════════════════════════════════════════════════════
# 幂等
# ═══════════════════════════════════════════════════════════════════════════════

func test_open_twice_does_not_push_second_lock() -> void:
	# Arrange
	open_menu()
	# Act —— 暂停中另一路（如战斗 UI 转发）再次请求
	menu.request_open(&"combat_ui")
	# Assert
	assert_eq(InputManager.get_lock_stack().size(), 1, "重复打开不应压第二层锁")
	assert_eq(adapter.suspend_calls, 1, "重复打开不应重复 suspend")
	assert_true(get_tree().paused, "重复打开后应仍处于暂停")


func test_close_without_open_is_noop() -> void:
	# Act —— 未打开
	menu.request_close()
	# Assert
	assert_false(get_tree().paused, "未打开时关闭不应改变暂停状态")
	assert_eq(InputManager.get_lock_stack().size(), 0, "未打开时关闭不应动锁栈")
	assert_eq(adapter.resume_calls, 0, "未打开时关闭不应调用 resume")


# ═══════════════════════════════════════════════════════════════════════════════
# ESC
# ═══════════════════════════════════════════════════════════════════════════════

func test_esc_closes_menu_and_pops_lock_once() -> void:
	# Arrange
	open_menu()
	# Act
	menu._unhandled_input(esc_event())
	# Assert
	assert_false(menu.visible, "ESC 应关闭暂停菜单")
	assert_false(get_tree().paused, "ESC 应解除暂停")
	assert_eq(InputManager.get_lock_stack().size(), 0, "ESC 应 pop 锁且只 pop 一次")
	assert_eq(adapter.resume_calls, 1, "ESC 关闭应调用 resume 一次")


func test_esc_pairing_holds_across_open_close_cycles() -> void:
	## ESC 开关配对：开着按一下关、再开再按一下关——每轮各一次 push/pop。
	# Act
	for i: int in range(2):
		menu.request_open(&"esc")
		assert_eq(InputManager.get_lock_stack().size(), 1, "第 %d 轮 ESC 打开应压一层锁" % (i + 1))
		menu._unhandled_input(esc_event())
		assert_eq(InputManager.get_lock_stack().size(), 0, "第 %d 轮 ESC 关闭应清空锁栈" % (i + 1))
	# Assert
	assert_eq(adapter.suspend_calls, adapter.resume_calls,
			"suspend / resume 次数应相等（开合严格配对）")


func test_esc_echo_event_does_not_retrigger() -> void:
	## 按住 ESC 产生的 echo 事件不应重复触发（幂等守卫）。
	# Arrange
	open_menu()
	menu.request_close()
	var echo: InputEventKey = InputEventKey.new()
	echo.keycode = KEY_ESCAPE
	echo.pressed = true
	echo.echo = true
	# Act
	menu._unhandled_input(echo)
	# Assert
	assert_false(menu.visible, "echo 事件不应重开菜单")
	assert_false(get_tree().paused, "echo 事件不应触发暂停")
	assert_eq(InputManager.get_lock_stack().size(), 0, "echo 事件不应压锁")


func test_esc_ignored_when_menu_closed() -> void:
	## 菜单没开时 ESC 不该被本组件吃掉——那是下层（InputManager → 暂停菜单）的事。
	# Act
	menu._unhandled_input(esc_event())
	# Assert
	assert_false(menu.visible, "未打开时 ESC 不应打开菜单")
	assert_eq(InputManager.get_lock_stack().size(), 0, "未打开时 ESC 不应压锁")


func test_esc_ignored_when_not_lock_owner() -> void:
	## 锁被其他模态接管（更高优先级系统 clear 后压了自己的锁）时，
	## 本组件的 ESC 不应误关自己——owner-check 的实证。
	# Arrange
	open_menu()
	InputManager.clear_locks()
	InputManager.push_lock(IM.LockType.MODAL, &"other_modal")
	# Act
	menu._unhandled_input(esc_event())
	# Assert
	assert_true(menu.visible, "非锁拥有者时 ESC 不应关闭菜单")
	assert_true(get_tree().paused, "非锁拥有者时不应改变暂停状态")
	assert_true(InputManager.has_lock(&"other_modal"), "其他模态的锁应不受影响")


# ═══════════════════════════════════════════════════════════════════════════════
# 树变化后锁的归属（回归：读档面板一插进来锁就没了）
# ═══════════════════════════════════════════════════════════════════════════════

func test_modal_lock_survives_child_insertion() -> void:
	## [b]回归用例[/b]：InputManager 对 [code]tree_changed[/code] 挂了一张「场景切换
	## 时清锁」的安全网，而这张网分不清「换场景」与「同一场景里插了个子节点」。
	## 暂停菜单点「读档」必然插面板 → 锁被清 → 「暂停中屏蔽下层输入」与 ESC
	## owner-check 同时失效（玩家被卡在关不掉的菜单里）。修法是树一变就把锁认回来。
	# Arrange
	open_menu()
	assert_true(InputManager.has_lock(&"pause_menu"), "前置：打开时持有 MODAL 锁")
	# Act —— 打开读档面板（往菜单里 add_child）
	menu._on_load_pressed()
	# Assert
	assert_true(InputManager.has_lock(&"pause_menu"),
			"插入面板后仍应持有 MODAL 锁（树变不应把暂停的锁冲掉）")
	assert_eq(InputManager.get_lock_stack().size(), 1,
			"认领应恰好回到一层锁（不累积）")
	assert_false(InputManager.is_input_allowed(IM.ActionType.GAMEPLAY, IM.DeviceType.KEYBOARD),
			"面板打开期间下层玩法输入仍应被拦")


func test_esc_still_closes_menu_after_child_insertion() -> void:
	## 上一条的玩家可感知后果：锁没了以后 ESC 会被 InputManager 吃掉，
	## 走到幂等跳过分支——菜单再也关不掉。
	# Arrange
	open_menu()
	menu._on_load_pressed()
	# Act —— ESC 先收面板（分层），再按一次关菜单
	menu._unhandled_input(esc_event())
	assert_false(bool(load_panel().call(&"is_open")), "第一下 ESC 应先收面板")
	# Act
	menu._unhandled_input(esc_event())
	# Assert
	assert_false(menu.visible, "第二下 ESC 应关掉菜单（锁还在，owner-check 通过）")
	assert_false(get_tree().paused, "关闭后应恢复运行")
	assert_eq(InputManager.get_lock_stack().size(), 0, "关闭后锁栈应清空（未累积）")


func test_modal_lock_reclaim_is_idempotent() -> void:
	## 认领是「补回自己那把」而不是「再压一把」——持锁期间再来一次树变，
	## 栈深必须仍是 1（否则 ESC 要按好几次才关得掉）。
	# Arrange
	open_menu()
	# Act —— 直调回调（等价于又发生了一次树变）
	menu._on_tree_changed()
	# Assert
	assert_eq(InputManager.get_lock_stack().size(), 1, "重复认领不应叠加锁")
	assert_true(InputManager.has_lock(&"pause_menu"), "锁应仍是自己的")


func test_modal_lock_not_reclaimed_when_menu_closed() -> void:
	## 菜单关着时的树变化不该凭空压锁——否则输入再也放不开。
	# Arrange —— 未打开
	# Act
	menu._on_tree_changed()
	# Assert
	assert_eq(InputManager.get_lock_stack().size(), 0, "未打开时树变化不应压锁")


func test_modal_lock_not_reclaimed_when_other_modal_holds_it() -> void:
	## 栈非空 = 另有一个活跃模态（转场锁 / 别人的弹窗）——此时不抢锁，
	## 否则两把锁叠在一起、ESC 归属错乱。[br]
	## [br]直调回调而非 [code]add_child[/code]：[code]InputManager[/code] 的安全网在
	## 同一次树变里会先把栈清空（它不区分「换场景」与「插节点」），那之后栈必然
	## 是空的——走树变路径就测不到这个守卫了。
	# Arrange
	open_menu()
	InputManager.clear_locks(&"pause_menu")
	InputManager.push_lock(IM.LockType.MODAL, &"other_modal")
	# Act
	menu._on_tree_changed()
	# Assert
	assert_false(InputManager.has_lock(&"pause_menu"),
			"其他模态持锁时不应把锁抢回来")
	assert_eq(InputManager.get_lock_stack().size(), 1, "栈深应仍为 1（不叠加）")
	assert_true(InputManager.has_lock(&"other_modal"), "别人的锁应原样留着")
