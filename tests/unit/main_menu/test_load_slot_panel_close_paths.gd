extends GutTest
## 读档槽位面板的关闭路径（真机试玩走查修复的回归用例）。[br]
## [br][b]背景[/b]：主菜单的读档面板此前只认「返回」按钮。它的
## [code]mouse_filter = STOP[/code] 把键盘事件一并吃掉，玩家按 Esc 既关不掉面板、
## 也走不到主菜单那一层（[code]MainMenu[/code] 自己不处理 Esc）——面板就此挂住
## 全屏，唯一的出路是用鼠标点「返回」。真机试玩走查在
## `load-panel` 一步上复现：面板占满屏，Esc 按下去没有任何反应。[br]
## [br][b]为什么走 [code]_input[/code] 而不是 [code]_unhandled_input[/code][/b]：
## 主菜单态下 [code]InputManager[/code] 的锁栈是空的，它那条 UI_NAV 判定会通过、
## 把 Esc 标成已处理并 [code]emit pause_requested[/code]——[code]_unhandled_input[/code]
## 那层根本收不到（主菜单没有暂停菜单接管，这一下 Esc 就此静默消失）。
## 场景节点的 [code]_input[/code] 实测早于 Autoload 的 [code]_input[/code]，
## 是本面板唯一能拿到的层（先例 [code]map_clear_panel_screen.gd[/code]）。[br]
## [br][b]为什么不用 [code]SettingsPanel[/code] 的写法[/b]：那个面板自己 push 了
## MODAL 锁，InputManager 因此放行、[code]_unhandled_input[/code] 收得到；
## 本面板没有自己的锁，故必须走在更前的一层。[br]
## [br]来源: .claude/rules/ui-code.md、ADR-0031 §1/§2、
## 先例 [code]settings_panel.gd[/code] 的关闭路径测试、
## design/gdd/main-menu-system.md（读档路径）。

const PanelScript := preload("res://src/ui/main_menu/load_slot_panel.gd")

## 承载面板的宿主尺寸（面板自身铺满——与主菜单同量级即可）。
const HOST_SIZE: Vector2 = Vector2(1280.0, 720.0)

var panel: Control = null
var _host: Control = null


func before_each() -> void:
	_host = Control.new()
	_host.size = HOST_SIZE
	add_child_autofree(_host)
	panel = PanelScript.new()
	_host.add_child(panel)
	# 面板铺满宿主——与主菜单里的真实形态一致（[code]_init[/code] 已设 FULL_RECT，
	# 此处显式再设一次以免宿主尺寸变化后锚点未生效）。
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)


func after_each() -> void:
	panel = null


## 构造一个 Esc 按键事件。
func _esc(pressed: bool = true, echo: bool = false) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = pressed
	event.echo = echo
	return event


# ═══════════════════════════════════════════════════════════════════════════════
# Esc 关闭（修复前恒红：面板完全没有键盘处理）
# ═══════════════════════════════════════════════════════════════════════════════

## 打开态按 Esc → 面板关闭 + 发出 [signal back_requested]（与「返回」同一出口）。
func test_esc_closes_open_panel_and_reports_back() -> void:
	# Arrange
	panel.open()
	var fired: Array = []
	panel.connect(&"back_requested", func() -> void: fired.append(true))
	assert_true(panel.is_open(), "前置：面板已打开")
	# Act
	panel._input(_esc())
	# Assert
	assert_false(panel.is_open(), "Esc 应关闭面板")
	assert_eq(fired.size(), 1, "Esc 应走与「返回」按钮同一个出口（back_requested）")


## 未打开时按 Esc 不产生任何副作用——隐藏着还消费 Esc 会把暂停菜单那层
## 关菜单的 Esc 吞掉（面板是复用式单例，隐藏后仍在树上收得到事件）。
func test_esc_ignored_when_panel_closed() -> void:
	# Arrange
	assert_false(panel.is_open(), "前置：面板未打开")
	var fired: Array = []
	panel.connect(&"back_requested", func() -> void: fired.append(true))
	# Act
	panel._input(_esc())
	# Assert
	assert_eq(fired.size(), 0, "未打开时 Esc 不应触发返回意图")


## echo 重复（按住不放）不重复关闭。
func test_esc_echo_repeat_does_not_reclose() -> void:
	# Arrange
	panel.open()
	# Act
	panel._input(_esc(true, true))
	# Assert
	assert_true(panel.is_open(), "echo 重复的 Esc 不应触发关闭")


## 按键释放事件（pressed=false）不触发关闭。
func test_esc_release_event_ignored() -> void:
	# Arrange
	panel.open()
	# Act
	panel._input(_esc(false))
	# Assert
	assert_true(panel.is_open(), "Esc 释放事件不应触发关闭")


## 非 Esc 按键不被关掉（面板只认这一颗键——其余原样放行给下层）。
func test_other_keys_do_not_close_panel() -> void:
	# Arrange
	panel.open()
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = true
	# Act
	panel._input(event)
	# Assert
	assert_true(panel.is_open(), "Enter 不应关闭面板")


# ═══════════════════════════════════════════════════════════════════════════════
# 真实输入：事件真的从视口走到面板上
# ═══════════════════════════════════════════════════════════════════════════════

## 用 [method Viewport.push_input] 投递真实 Esc——证明不只是「直调函数会关」，
## 而是这条链路（视口 → 场景节点 _input → 本面板）真的通。
func test_real_esc_key_event_closes_panel() -> void:
	# Arrange
	panel.open()
	assert_true(panel.is_open(), "前置：面板已打开")
	# Act
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.physical_keycode = KEY_ESCAPE
		event.pressed = pressed
		get_viewport().push_input(event, true)
	# Assert
	assert_false(panel.is_open(), "真实 Esc 事件应关掉面板")
