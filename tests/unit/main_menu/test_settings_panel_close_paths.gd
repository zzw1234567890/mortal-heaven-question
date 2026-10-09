extends GutTest
## main-menu Story 002 单元测试：面板关闭路径（code-review GAP-3/GAP-4 补强）。
##
## 覆盖三条关闭链中此前仅按钮路径有覆盖的缺口：[br]
##   - ESC 关闭（_unhandled_input 兜底分支——含 has_lock 自判）[br]
##   - open() 幂等（二次调用跳过——总线不重复对齐）[br]
##   - _exit_tree 兜底锁释放（面板打开态直接 free——防泄漏锁回归）[br]
##   - ESC 未按下/echo 重复不关闭（防御分支钉死）[br]
##
## 集成范围：SettingsPanel 场景 + InputManager Autoload（真实锁栈——headless
## GUT 下 Autoload 可用）+ 临时路径 store。总线快照还原（同
## test_settings_rollback.gd 模式——code-review M-3 裁决统一惯例）。

const SETTINGS_SCENE: PackedScene = \
		preload("res://src/ui/main_menu/SettingsPanel.tscn")
const LOGIC := preload("res://src/ui/main_menu/settings_logic.gd")

## 面板 LOCK_SOURCE（settings_panel.gd 同值——锁栈断言用）。
const LOCK_SOURCE: StringName = &"settings_panel"

## 三总线枚举（AudioEnums 单一真源镜像）。
const BUSES: Array[int] = [0, 1, 2]

var _temp_path: String = ""
var panel: Control = null
var store: Object = null
## 总线原值快照——after_each 还原（快照模式惯例）。
var _orig_bus_dbs: Dictionary = {}


func before_each() -> void:
	# 总线原值快照
	_orig_bus_dbs = {}
	for bus: int in BUSES:
		var idx: int = AudioServer.get_bus_index(
				AudioEnums.BUS_NAMES[bus])
		if idx >= 0:
			_orig_bus_dbs[bus] = AudioServer.get_bus_volume_db(idx)
	_temp_path = "user://settings_close_test_%d.json" \
			% (Time.get_ticks_msec() % 1000000 + randi() % 1000)
	var store_script: GDScript = \
			load("res://src/ui/main_menu/settings_store.gd")
	store = store_script.new()
	store.path = _temp_path
	store.save_volume_category({0: 80, 1: 80, 2: 80})
	panel = SETTINGS_SCENE.instantiate()
	panel.animate = false
	panel.settings_store = store
	add_child(panel)


func after_each() -> void:
	# 兜底：面板可能已被测试内 free——仅清理仍存活的实例
	if panel != null and is_instance_valid(panel):
		if panel.visible:
			panel.close()
			# close() 同步路径已释放锁（animate=false 直达 _finish_close）
		panel.free()
	panel = null
	store = null
	# 总线还原到快照
	for bus: int in _orig_bus_dbs.keys():
		var idx: int = AudioServer.get_bus_index(
				AudioEnums.BUS_NAMES[bus])
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, float(_orig_bus_dbs[bus]))
	if not _temp_path.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_temp_path))
		_temp_path = ""


func _make_esc_event(pressed: bool, echo: bool = false) -> InputEventKey:
	## 构造 ESC 按键事件（_unhandled_input 直调——GUT 下无需真实窗口焦点）。
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = pressed
	event.echo = echo
	return event


func _lock_stack_holds_settings() -> bool:
	## 面板锁是否在 InputManager 栈中（has_lock 直查——真实锁栈非 mock）。
	return InputManager.has_lock(LOCK_SOURCE)


# ═══════════════════════════════════════════════════════════════════════════════
# GAP-3：ESC 关闭路径
# ═══════════════════════════════════════════════════════════════════════════════

func test_esc_closes_panel_when_open_and_unlocks() -> void:
	## GAP-3: 打开态按 ESC → 面板关闭 + 锁释放 + 总线回滚已保存值。
	# Arrange —— 打开并拖动（制造脏状态：滑条 30，已保存 80）
	panel.open()
	panel.master_slider.value = 30.0
	assert_true(_lock_stack_holds_settings(), "前置：打开后面板应在锁栈中")
	# Act —— ESC 按下
	panel._unhandled_input(_make_esc_event(true))
	# Assert —— 面板已关闭 + 锁已释放
	assert_false(panel.visible, "ESC 应关闭面板")
	assert_false(_lock_stack_holds_settings(), "ESC 关闭后锁应已释放")
	# Assert —— 总线回滚到已保存值 80（ESC 与关闭按钮同回滚语义）
	var master_db: float = AudioServer.get_bus_volume_db(
			AudioServer.get_bus_index(&"Master"))
	assert_almost_eq(master_db, LOGIC.db_from_percent(80.0), 0.01,
			"ESC 关闭应回滚总线到已保存值 db_from_percent(80)")


func test_esc_ignored_when_panel_closed() -> void:
	## GAP-3 防御: 面板未打开时 ESC 事件不触发任何关闭逻辑（visible 守卫）。
	# Arrange —— 面板从未打开
	assert_false(panel.visible)
	# Act
	panel._unhandled_input(_make_esc_event(true))
	# Assert —— 无异常 + 面板保持关闭
	assert_false(panel.visible, "未打开面板 ESC 应为 no-op")


func test_esc_echo_repeat_does_not_reclose() -> void:
	## GAP-3 防御: event.echo 按住重复不触发（echo 过滤——与 InputManager
	## 路径 B 的 G-7 修复对称）。
	# Arrange —— 打开
	panel.open()
	# Act —— echo 重复事件（按住 ESC 不放产生的重复）
	panel._unhandled_input(_make_esc_event(true, true))
	# Assert —— 面板仍打开（echo 被过滤）
	assert_true(panel.visible, "echo 重复 ESC 不应触发关闭")


func test_esc_release_event_ignored() -> void:
	## GAP-3 防御: 按键释放事件（pressed=false）不触发关闭。
	# Arrange —— 打开
	panel.open()
	# Act —— 释放事件
	panel._unhandled_input(_make_esc_event(false))
	# Assert —— 面板仍打开
	assert_true(panel.visible, "ESC 释放事件不应触发关闭")


# ═══════════════════════════════════════════════════════════════════════════════
# GAP-4：open() 幂等 + _exit_tree 兜底
# ═══════════════════════════════════════════════════════════════════════════════

func test_open_twice_is_idempotent_keeps_lock_single() -> void:
	## GAP-4: 二次 open() 幂等跳过——锁栈不重复入（has_lock 布尔不变，
	## 但 push_lock 不应叠加；以总线上下文无副作用 + 面板状态稳定断言）。
	# Arrange —— 打开后拖动到 30（制造脏状态）
	panel.open()
	panel.master_slider.value = 30.0
	# Act —— 二次 open（幂等跳过——不重读文件不重置滑条）
	panel.open()
	# Assert —— 滑条保持拖动值 30（幂等跳过未重置为已保存值 80）
	assert_eq(panel.master_slider.value, 30.0,
			"二次 open 应幂等跳过（滑条不被重置）")
	assert_true(panel.visible, "面板应保持打开")
	assert_true(_lock_stack_holds_settings(), "锁应仍在栈中（幂等无副作用）")
	# GAP-C1 补强（QL-TEST-COVERAGE ADVISORY）：钉死幂等路径的警告侧输出——
	# 二次 open 应 push_warning 1 次（行为已验证，此处补诊断输出回归守卫）。
	assert_push_warning_count(1, "二次 open 应 push_warning 1 次")


func test_exit_tree_open_state_releases_lock() -> void:
	## GAP-4: 面板打开态直接 free（模拟场景切换中途销毁）→ _exit_tree
	## 兜底释放锁——锁栈无泄漏。
	# Arrange —— 打开（持有锁）
	panel.open()
	assert_true(_lock_stack_holds_settings(), "前置：打开后锁在栈中")
	# Act —— 打开态直接 free（不经 close——_exit_tree 兜底路径）
	panel.free()
	panel = null  # 防 after_each 二次 free
	# Assert —— 锁已被 _exit_tree 兜底释放
	assert_false(_lock_stack_holds_settings(),
			"_exit_tree 应兜底释放锁（防泄漏锁回归）")
