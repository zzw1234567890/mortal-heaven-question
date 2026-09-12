extends GutTest
## hud Story 005 集成测试：暂停菜单打开/恢复（AC-1）+ HUD 侧接收接口（AC-6）
## + 音频 Adapter 桩（AC-3）。
##
## 覆盖 QA 规格：[br]
##   - AC-1: request_pause(&"esc") 模拟 ESC 信号路径 → paused==true + 菜单可见；
##     再次触发 → paused==false + 菜单隐藏[br]
##   - AC-1 edge: 连续快速按 ESC（无状态错乱）；暂停中打开后立即关闭[br]
##   - AC-3: 打开时 adapter.suspend() 被调用；恢复时 resume() 被调用[br]
##   - AC-6: request_pause(&"combat_ui") 三路入口统一；暂停中重复调用幂等[br]
##
## 测试后清理：SceneTree.paused = false + InputManager.clear_locks()
## （泄漏 paused 状态会污染后续测试套件——story 测试要求）。
## 风格先例：tests/integration/hud/test_notification_request_interface.gd
## （HUD 实例化 + 注入模式）。

const HUD_SCENE: PackedScene = preload("res://src/ui/hud/HUD.tscn")

## mock 音频 adapter——记录 suspend/resume 调用次数（AC-3 桩阶段断言）。
class MockAudioAdapter:
	extends PauseAudioAdapter
	var suspend_calls: int = 0
	var resume_calls: int = 0

	func suspend() -> void:
		suspend_calls += 1

	func resume() -> void:
		resume_calls += 1


## mock 存档系统——save_game 恒返回 WRITE_ERROR（code-review M-4 失败路径）。
class MockSaveLoad:
	extends Node
	var save_calls: int = 0
	var last_payload: Dictionary = {}

	func save_game(_slot_type: int, _slot_id: int, data: Dictionary, _meta: Dictionary) -> int:
		save_calls += 1
		last_payload = data
		return 2 # SaveLoadSystem.SaveResult.WRITE_ERROR


## mock 场景管理器——记录 request_scene_change 调用与参数（code-review M-4）。
class MockSceneManager:
	extends Node
	var change_calls: Array = []

	func get_current_scene_id() -> int:
		return 3 # EXPLORATION——模拟暂停菜单典型调用场景

	func request_scene_change(from: int, to: int, type: int) -> bool:
		change_calls.append([from, to, type])
		return true

var hud: CanvasLayer = null
var pause_menu: Control = null
var mock_adapter: MockAudioAdapter = null


func before_each() -> void:
	hud = HUD_SCENE.instantiate()
	add_child(hud)
	pause_menu = hud.get_node_or_null("PauseOverlay/PauseMenu")
	mock_adapter = MockAudioAdapter.new()
	pause_menu.audio_adapter = mock_adapter
	pause_menu.animate = false


func after_each() -> void:
	# 清理暂停状态 + 锁栈——泄漏会污染后续测试套件（story 测试要求）
	get_tree().paused = false
	InputManager.clear_locks()
	if hud != null and is_instance_valid(hud):
		hud.free()
	hud = null
	pause_menu = null
	mock_adapter = null


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1：暂停打开与恢复
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac001_request_pause_esc_opens_menu() -> void:
	## AC-1 主体: request_pause(&"esc")（模拟 ESC 信号路径）→ paused + 菜单可见
	# Arrange —— before_each 已挂载
	# Act
	hud.request_pause(&"esc")
	# Assert
	assert_true(get_tree().paused, "ESC 路径打开后 SceneTree.paused 应为 true")
	assert_true(pause_menu.visible, "暂停菜单应可见")
	assert_true(InputManager.has_lock(&"pause_menu"),
			"打开时应 push MODAL 锁（source=pause_menu）")

func test_ac001_second_trigger_closes_menu() -> void:
	## AC-1 主体: 再触发（继续游戏路径）→ paused==false + 菜单隐藏
	# Arrange
	hud.request_pause(&"esc")
	assert_true(get_tree().paused, "前置：暂停中")
	# Act —— 继续游戏按钮路径（request_close）
	pause_menu.request_close()
	# Assert
	assert_false(get_tree().paused, "关闭后 SceneTree.paused 应为 false")
	assert_false(pause_menu.visible, "暂停菜单应隐藏")
	assert_false(InputManager.has_lock(&"pause_menu"),
			"关闭后 MODAL 锁应已 pop（锁栈配对）")

func test_ac001_rapid_esc_no_state_corruption() -> void:
	## AC-1 edge: 连续快速按 ESC——开/关/开/关循环后状态一致（无错乱）
	# Arrange
	# Act + Assert —— 4 次快速触发
	for i: int in range(4):
		if get_tree().paused:
			pause_menu.request_close()
		else:
			hud.request_pause(&"esc")
	# 循环结束（4 次：开→关→开→关）——最终态应为关闭
	assert_false(get_tree().paused, "4 次快速触发后（偶数次）应恢复运行")
	assert_false(pause_menu.visible, "菜单应隐藏")
	assert_false(InputManager.has_lock(&"pause_menu"), "锁栈应清空")

func test_ac001_open_then_immediate_close() -> void:
	## AC-1 edge: 暂停中打开后立即关闭——状态正确回退
	# Arrange
	# Act
	hud.request_pause(&"esc")
	pause_menu.request_close()
	# Assert
	assert_false(get_tree().paused, "立即关闭后应恢复运行")
	assert_false(InputManager.has_lock(&"pause_menu"), "锁应已配对释放")

func test_ac001_lock_stack_clean_after_cycle() -> void:
	## 锁栈配对断言（story 测试要求——pop 配对验证）
	# Arrange
	hud.request_pause(&"esc")
	assert_eq(InputManager.get_lock_stack().size(), 1, "前置：暂停中 1 个锁")
	# Act
	pause_menu.request_close()
	# Assert
	assert_eq(InputManager.get_lock_stack().size(), 0, "恢复后锁栈应清空")

# ═══════════════════════════════════════════════════════════════════════════════
# AC-6：HUD 侧接收接口（三路统一）
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac006_request_pause_combat_ui_opens_menu() -> void:
	## AC-6 主体: request_pause(&"combat_ui")（模拟 combat-ui 转发）→ 暂停 + 菜单可见
	# Arrange
	# Act
	hud.request_pause(&"combat_ui")
	# Assert
	assert_true(get_tree().paused, "combat_ui 转发路径应触发暂停")
	assert_true(pause_menu.visible, "菜单应可见（三路入口统一到 request_pause）")

func test_ac006_request_pause_button_path_opens_menu() -> void:
	## AC-6 补充: request_pause(&"button")（HUD 暂停按钮路径）同样触发
	# Arrange
	# Act
	hud.request_pause(&"button")
	# Assert
	assert_true(get_tree().paused, "按钮路径应触发暂停")

func test_ac006_request_pause_idempotent_while_paused() -> void:
	## AC-6 edge: 暂停状态下再次调用 request_pause——幂等（不重复开流程）
	# Arrange
	hud.request_pause(&"esc")
	var suspend_before: int = mock_adapter.suspend_calls
	var lock_depth: int = InputManager.get_lock_stack().size()
	# Act —— 暂停中重复调用（不同 source 亦幂等）
	hud.request_pause(&"combat_ui")
	# Assert
	assert_true(get_tree().paused, "幂等跳过——仍应暂停中")
	assert_true(pause_menu.visible, "幂等跳过——菜单应保持可见")
	assert_eq(InputManager.get_lock_stack().size(), lock_depth,
			"幂等跳过——锁栈深度不应增加")
	assert_eq(mock_adapter.suspend_calls, suspend_before,
			"幂等跳过——adapter.suspend 不应重复调用")
	assert_eq(mock_adapter.resume_calls, 0,
			"幂等跳过——adapter.resume 不应被调用（G-4 补强）")

func test_ac006_input_manager_signal_routes_to_pause() -> void:
	## GAP-1 裁决路径: InputManager.pause_requested 信号 → HUD 接线 → 暂停
	# Arrange —— 接线在 hud._ready（GAP-1 裁决）：instantiate + add_child 后即接线，
	# 无须调用 setup（before_each 已挂载）。
	# Act
	InputManager.pause_requested.emit()
	# Assert
	assert_true(get_tree().paused, "pause_requested 信号发射后应触发暂停")
	assert_true(pause_menu.visible, "菜单应可见（ESC 信号路径贯通）")
	# 清理——本测试经信号路径打开，关回
	pause_menu.request_close()

# ═══════════════════════════════════════════════════════════════════════════════
# AC-3：音频暂停 Adapter（桩阶段断言）
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac003_suspend_called_on_open() -> void:
	## AC-3: 打开暂停菜单 → adapter.suspend() 被调用
	# Arrange
	# Act
	hud.request_pause(&"esc")
	# Assert
	assert_eq(mock_adapter.suspend_calls, 1, "打开时应调用 adapter.suspend() 1 次")

func test_ac003_resume_called_on_close() -> void:
	## AC-3: 恢复 → adapter.resume() 被调用
	# Arrange
	hud.request_pause(&"esc")
	# Act
	pause_menu.request_close()
	# Assert
	assert_eq(mock_adapter.resume_calls, 1, "关闭时应调用 adapter.resume() 1 次")

func test_ac003_suspend_resume_call_counts_across_cycles() -> void:
	## AC-3 补充: 两轮开/关——suspend/resume 各 2 次（配对无累积偏差）
	# Arrange
	# Act
	hud.request_pause(&"esc")
	pause_menu.request_close()
	hud.request_pause(&"button")
	pause_menu.request_close()
	# Assert
	assert_eq(mock_adapter.suspend_calls, 2, "两轮打开应调用 suspend 2 次")
	assert_eq(mock_adapter.resume_calls, 2, "两轮关闭应调用 resume 2 次")

# ═══════════════════════════════════════════════════════════════════════════════
# M-4（code-review）：退出路径——存档失败/依赖缺失防御
# ═══════════════════════════════════════════════════════════════════════════════

func test_save_exit_failure_keeps_menu_open() -> void:
	## M-4: 存档失败（save_game 返回非 SUCCESS）——保持菜单打开 + 暂停 + 锁不释放
	# Arrange —— 注入恒失败的 mock save_load，打开菜单
	var mock_save: MockSaveLoad = MockSaveLoad.new()
	pause_menu.save_load = mock_save
	hud.request_pause(&"esc")
	# Act
	pause_menu._on_save_exit_pressed()
	# Assert —— 失败分支：不退出、不解除暂停、不释放锁
	assert_true(pause_menu.visible, "存档失败应保持菜单打开（不丢进度）")
	assert_true(get_tree().paused, "存档失败应保持暂停中")
	assert_true(InputManager.has_lock(&"pause_menu"),
			"存档失败 MODAL 锁不应释放")
	assert_eq(mock_save.save_calls, 1, "save_game 应被调用 1 次")

func test_save_exit_null_save_load_keeps_menu_open() -> void:
	## M-4/M-1: save_load = null——push_error + return，不静默丢档不退出
	# Arrange
	pause_menu.save_load = null
	hud.request_pause(&"esc")
	# Act
	pause_menu._on_save_exit_pressed()
	# Assert
	assert_true(pause_menu.visible, "save_load 缺失应保持菜单打开")
	assert_true(get_tree().paused, "save_load 缺失应保持暂停中")
	assert_true(InputManager.has_lock(&"pause_menu"),
			"save_load 缺失 MODAL 锁不应释放")

func test_return_to_main_menu_releases_pause_and_lock() -> void:
	## M-4: 返回主菜单——解除暂停 + pop 锁 + request_scene_change(to=MAIN_MENU)
	# Arrange —— 注入 mock scene_manager 记录转场调用
	var mock_sm: MockSceneManager = MockSceneManager.new()
	pause_menu.scene_manager = mock_sm
	hud.request_pause(&"esc")
	# Act
	pause_menu._on_return_main_menu_pressed()
	# Assert
	assert_false(get_tree().paused, "返回主菜单后应解除暂停")
	assert_false(pause_menu.visible, "返回主菜单后菜单应隐藏")
	assert_false(InputManager.has_lock(&"pause_menu"),
			"返回主菜单后 MODAL 锁应已 pop")
	assert_eq(mock_sm.change_calls.size(), 1, "request_scene_change 应被调用 1 次")
	if mock_sm.change_calls.size() == 1:
		var call: Array = mock_sm.change_calls[0]
		assert_eq(call[1], 0, "转场目标应为 MAIN_MENU（SceneID=0）")
		assert_eq(call[2], 2, "转场类型应为 GAME_TO_MENU（TransitionType=2）")

# ═══════════════════════════════════════════════════════════════════════════════
# G-3 / B-3（code-review）：request_close 守卫 + ESC 关闭链路
# ═══════════════════════════════════════════════════════════════════════════════

func test_request_close_when_not_open_is_noop() -> void:
	## G-3: 未打开时调 request_close——无副作用（不暂停、不动锁栈、不调 resume）
	# Arrange —— 菜单未打开（before_each 默认态）
	# Act
	pause_menu.request_close()
	# Assert
	assert_false(get_tree().paused, "未打开时关闭不应改变暂停状态")
	assert_eq(InputManager.get_lock_stack().size(), 0, "未打开时关闭不应动锁栈")
	assert_eq(mock_adapter.resume_calls, 0, "未打开时关闭不应调用 adapter.resume")

func test_esc_closes_menu_via_unhandled_input() -> void:
	## B-3: ESC 关闭链路——菜单打开（暂停中 InputManager 冻结）时
	## PauseMenu._unhandled_input 兜底接收 ESC 并关闭。
	# Arrange —— 打开菜单（模拟 ESC 信号路径）
	hud.request_pause(&"esc")
	assert_true(pause_menu.visible, "前置：菜单已打开")
	var esc_event: InputEventKey = InputEventKey.new()
	esc_event.keycode = KEY_ESCAPE
	esc_event.pressed = true
	esc_event.echo = false
	# Act —— 直接调用 _unhandled_input 模拟引擎派发（暂停中仅 ALWAYS 节点接收）
	pause_menu._unhandled_input(esc_event)
	# Assert
	assert_false(get_tree().paused, "ESC 兜底路径应解除暂停")
	assert_false(pause_menu.visible, "ESC 兜底路径应隐藏菜单")
	assert_false(InputManager.has_lock(&"pause_menu"),
			"ESC 兜底路径应 pop MODAL 锁")

func test_esc_echo_event_does_not_retrigger() -> void:
	## G-7/B-3 补充: echo 重复事件（按住 ESC）不应重复触发关闭——
	## 已关闭状态下再收 echo 事件必须无副作用（幂等守卫分支覆盖）。
	# Arrange —— 打开后关闭，模拟一次完整 ESC 按下
	hud.request_pause(&"esc")
	pause_menu.request_close()
	assert_false(pause_menu.visible, "前置：菜单已关闭")
	var lock_depth: int = InputManager.get_lock_stack().size()
	# Act —— echo 事件（按住产生的重复 pressed）
	var echo_event: InputEventKey = InputEventKey.new()
	echo_event.keycode = KEY_ESCAPE
	echo_event.pressed = true
	echo_event.echo = true
	pause_menu._unhandled_input(echo_event)
	# Assert —— 无副作用（不重开、不写锁、不写暂停状态）
	assert_false(pause_menu.visible, "echo 事件不应重开菜单")
	assert_false(get_tree().paused, "echo 事件不应触发暂停")
	assert_eq(InputManager.get_lock_stack().size(), lock_depth,
			"echo 事件不应 push 锁")

func test_esc_ignored_when_not_lock_owner() -> void:
	## B-3 补充: has_lock 守卫——菜单打开但锁已被其他模态替换时
	## （其他更高优先级系统 clear 后压了自己的锁），ESC 不应关闭菜单。
	# Arrange —— 打开菜单后模拟外部清理+其他模态压栈
	hud.request_pause(&"esc")
	assert_true(pause_menu.visible, "前置：菜单已打开")
	InputManager.clear_locks()
	InputManager.push_lock(InputManager.LockType.MODAL, &"other_modal")
	var paused_before: bool = get_tree().paused
	# Act —— ESC 事件到达 _unhandled_input
	var esc_event: InputEventKey = InputEventKey.new()
	esc_event.keycode = KEY_ESCAPE
	esc_event.pressed = true
	esc_event.echo = false
	pause_menu._unhandled_input(esc_event)
	# Assert —— 非锁拥有者：不关闭（保持现状，交由活跃模态处理）
	assert_true(pause_menu.visible, "非锁拥有者时 ESC 不应关闭菜单")
	assert_eq(get_tree().paused, paused_before, "非锁拥有者时不应改变暂停状态")
	# 清理——恢复测试期望的干净状态
	InputManager.clear_locks()
	get_tree().paused = false
	pause_menu.visible = false
