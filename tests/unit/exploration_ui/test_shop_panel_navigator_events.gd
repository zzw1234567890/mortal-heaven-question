extends "res://tests/unit/exploration_ui/shop_navigator_fixture.gd"
## 商店面板游标的输入事件翻译与焦点信号。[br]
## [br][b]Story 类型[/b]：Logic（纯游标逻辑——行数组 + 三个动作出口注入，无场景依赖）。
## 复位 / 移动 / 确认见 [code]test_shop_panel_navigator.gd[/code]；面板级完整链路见
## [code]test_shop_panel_navigation.gd[/code]。[br]
## [br]装置（真实 Button 行、注入出口、计数器）见
## [code]shop_navigator_fixture.gd[/code]。[br]
##
## 来源: .claude/rules/ui-code.md（双输入）、ADR-0031 §2/§4（零状态所有权 + 双焦点）、
## GDD exploration-ui-system.md §4c、shop_panel_navigator.gd。


## 造一条按键事件（[param p_code] 为主键盘键码）。
func _key(p_code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = p_code
	event.pressed = true
	return event


# ═══════════════════════════════════════════════════════════════════════════════
# 输入事件翻译
# ═══════════════════════════════════════════════════════════════════════════════

func test_handle_event_down_moves_and_consumes() -> void:
	# Arrange
	_rows_of("xx")
	nav.call(&"reset")
	# Act
	var consumed: bool = bool(nav.call(&"handle_event", _key(KEY_DOWN)))
	# Assert
	assert_true(consumed, "方向键应被消费（不再向下传播到引擎焦点导航）")
	assert_eq(int(nav.call(&"focus_index")), 1, "↓ 应下移游标")


func test_handle_event_up_moves_and_consumes() -> void:
	# Arrange
	_rows_of("xx")
	nav.call(&"reset")
	nav.call(&"move", 1)
	# Act
	var consumed: bool = bool(nav.call(&"handle_event", _key(KEY_UP)))
	# Assert
	assert_true(consumed, "方向键应被消费")
	assert_eq(int(nav.call(&"focus_index")), 0, "↑ 应上移游标")


func test_handle_event_accept_buys_cursor_row() -> void:
	# Arrange
	_rows_of("xx")
	nav.call(&"reset")
	# Act
	var consumed: bool = bool(nav.call(&"handle_event", _key(KEY_ENTER)))
	# Assert
	assert_true(consumed, "确认键应被消费")
	assert_eq(_activated, [0], "确认应买下游标所在行")


func test_handle_event_cancel_requests_leave() -> void:
	# Arrange
	_rows_of("xx")
	nav.call(&"reset")
	# Act
	var consumed: bool = bool(nav.call(&"handle_event", _key(KEY_ESCAPE)))
	# Assert
	assert_true(consumed, "取消键应被消费")
	assert_eq(_cancelled, 1, "取消应请求离开商店")


func test_handle_event_unmapped_key_passes_through() -> void:
	# Arrange
	_rows_of("xx")
	nav.call(&"reset")
	# Act
	var consumed: bool = bool(nav.call(&"handle_event", _key(KEY_F5)))
	# Assert——只吃这四个动作，其余原样放行
	assert_false(consumed, "无关按键不应被消费")
	assert_eq(int(nav.call(&"focus_index")), 0, "无关按键不应移动游标")


func test_handle_event_mouse_click_passes_through() -> void:
	# Arrange
	_rows_of("xx")
	nav.call(&"reset")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	# Act
	var consumed: bool = bool(nav.call(&"handle_event", click))
	# Assert——鼠标点击走按钮自身的 pressed，不经游标
	assert_false(consumed, "鼠标点击不应被游标消费")
	assert_eq(_activated, [], "鼠标点击不由游标发起购买")


# ═══════════════════════════════════════════════════════════════════════════════
# 焦点信号
# ═══════════════════════════════════════════════════════════════════════════════

func test_focus_changed_emitted_once_per_actual_move() -> void:
	# Arrange——记录每次焦点变化
	_rows_of("xx")
	var seen: Array = []
	nav.connect(&"focus_changed", func(i: int) -> void: seen.append(i))
	# Act——复位 + 下移 + 在末行重复下移（后者无位移）
	nav.call(&"reset")
	nav.call(&"move", 1)
	nav.call(&"move", 1)
	# Assert——无位移不发信号（焦点搬运是幂等的，重复发只会白刷）
	assert_eq(seen, [0, 1], "只在游标真的换行时才发焦点变化")


func test_focus_changed_not_emitted_when_no_rows() -> void:
	# Arrange
	_rows = []
	var seen: Array = []
	nav.connect(&"focus_changed", func(i: int) -> void: seen.append(i))
	# Act
	nav.call(&"reset")
	# Assert——-1 → -1 无变化
	assert_eq(seen, [], "空货架复位不应发焦点变化（游标始终缺席）")
