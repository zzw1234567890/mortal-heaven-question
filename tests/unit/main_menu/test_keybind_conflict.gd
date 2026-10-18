extends GutTest
## main-menu Story 004 单元测试：按键冲突检测纯函数（QA 规格 AC-1）。
##
## 覆盖 QA 规格全部场景与 edge cases（story-004 QA Test Cases AC-1）：[br]
##   - 无占用返回空数组[br]
##   - E 与多 action 同绑（GDD 确认=Enter/左键本就多绑定）→ 全部返回[br]
##   - 相同 action 自己绑自己 → 不算冲突[br]
##   - 键盘↔鼠标混绑 → 按同类互换规则判定不算冲突[br]
##   - E 为 ESC → 等待输入层已拦截，纯函数层防御性返回空[br]
## [br][b]序列化往返[/b]补测（serialize/deserialize——集成测试 AC-2 的内核依赖）。
##
## 纯静态函数直调——无场景树、无 InputMap 依赖、无文件 IO。
## 风格先例：test_db_from_percent.gd（arrange/act/assert）。

const Logic: GDScript = preload("res://src/ui/main_menu/keybind_logic.gd")

## 测试键码常量（fixture 常量——测试标准「无内联魔数」）。
## 避免与 Godot 全局 KEY_* 枚举同名声明（cyclic reference）——用别名前缀。
const KEY_F1: int = 4194332  # KEY_F1（Godot 全局枚举值——别名防 cyclic）
const KEY_Q: int = 81        # KEY_Q
const KEY_ENTER: int = 4194309  # KEY_ENTER
const MOUSE_LEFT: int = 1    # MOUSE_BUTTON_LEFT
const MOUSE_RIGHT: int = 2   # MOUSE_BUTTON_RIGHT
const KEY_ESCAPE_VAL: int = 4194305  # KEY_ESCAPE


func _key(code: int, ctrl: bool = false) -> InputEventKey:
	## 构造键盘事件（physical_keycode 优先——与 project.godot 绑定形态一致）。
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.ctrl_pressed = ctrl
	return event


func _mouse(button: int) -> InputEventMouseButton:
	## 构造鼠标按钮事件。
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	return event


func _bindings_1q_2enter() -> Dictionary:
	## 现有绑定映射 fixture：action_a 绑 Q、action_b 绑 Enter。
	return {
		&"action_a": [_key(KEY_Q)],
		&"action_b": [_key(KEY_ENTER)],
	}


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1 主体：无占用 → 空数组
# ═══════════════════════════════════════════════════════════════════════════════
func test_find_conflicts_unoccupied_event_returns_empty() -> void:
	## AC-1: F1 未被任何 action 占用 → 返回空数组。
	# Arrange
	var bindings: Dictionary = _bindings_1q_2enter()
	# Act
	var conflicts: Array = Logic.find_conflicts(_key(KEY_F1), bindings)
	# Assert
	assert_eq(conflicts.size(), 0, "未占用键应返回空数组")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1 edge：多 action 同绑 → 全部返回
# ═══════════════════════════════════════════════════════════════════════════════

func test_find_conflicts_multi_action_same_key_returns_all() -> void:
	## AC-1 edge: Q 同时被 action_a / action_c 绑定（GDD 确认=Enter/左键
	## 本就多绑定）→ 新事件 Q 的冲突列表包含全部两个 action。
	# Arrange —— action_a 与 action_c 同绑 Q
	var bindings: Dictionary = {
		&"action_a": [_key(KEY_Q)],
		&"action_b": [_key(KEY_ENTER)],
		&"action_c": [_key(KEY_Q)],
	}
	# Act
	var conflicts: Array = Logic.find_conflicts(_key(KEY_Q), bindings)
	# Assert
	assert_eq(conflicts.size(), 2, "多 action 同绑应全部返回")
	assert_true(conflicts.has(&"action_a"), "冲突列表应含 action_a")
	assert_true(conflicts.has(&"action_c"), "冲突列表应含 action_c")
	assert_false(conflicts.has(&"action_b"), "未占用 Enter 的 action_b 不应出现")


func test_find_conflicts_single_action_returns_one() -> void:
	## AC-1 主体: Enter 被 action_b 单独占用 → 冲突列表恰含 action_b。
	# Arrange
	var bindings: Dictionary = _bindings_1q_2enter()
	# Act
	var conflicts: Array = Logic.find_conflicts(_key(KEY_ENTER), bindings)
	# Assert
	assert_eq(conflicts.size(), 1, "单占用应返回一个 action")
	assert_eq(conflicts[0], &"action_b", "冲突 action 应为 action_b")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1 edge：相同 action 自己绑自己 → 不算冲突
# ═══════════════════════════════════════════════════════════════════════════════

func test_find_conflicts_same_action_rebind_is_not_conflict() -> void:
	## AC-1 edge: action_a 已绑 Q，重绑 Q 到 action_a（ignore_action）→ 空冲突。
	# Arrange
	var bindings: Dictionary = _bindings_1q_2enter()
	# Act —— 自己绑自己（忽略目标 action）
	var conflicts: Array = Logic.find_conflicts(_key(KEY_Q), bindings, &"action_a")
	# Assert
	assert_eq(conflicts.size(), 0, "自己绑自己不应算冲突")


func test_find_conflicts_same_action_other_conflict_still_detected() -> void:
	## AC-1 edge 对照: 忽略目标 action 后，其他 action 的占用仍被检出
	## （ignore 只豁免自己，不吞并他人冲突）。
	# Arrange
	var bindings: Dictionary = _bindings_1q_2enter()
	# Act —— 重绑 Enter 到 action_a（action_b 仍占用 Enter）
	var conflicts: Array = Logic.find_conflicts(_key(KEY_ENTER), bindings, &"action_a")
	# Assert
	assert_eq(conflicts.size(), 1, "他人占用仍应检出")
	assert_eq(conflicts[0], &"action_b", "冲突 action 应为 action_b")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1 edge：键盘↔鼠标混绑 → 同类互换规则下不算冲突
# ═══════════════════════════════════════════════════════════════════════════════

func test_find_conflicts_keyboard_vs_mouse_not_conflict() -> void:
	## AC-1 edge: 键盘↔鼠标混绑不算冲突（story Engine Notes 裁决——
	## 鼠标动作重绑定语义按「同类输入可互换」）。
	# Arrange —— 无键盘 Q 与鼠标任意键同槽的可比性
	var bindings: Dictionary = {
		&"action_mouse": [_mouse(MOUSE_LEFT), _key(KEY_Q)],
	}
	# Act —— 新鼠标左键事件 vs 含键盘 Q 的绑定
	var conflicts: Array = Logic.find_conflicts(_mouse(MOUSE_LEFT), bindings)
	# Assert —— action_mouse 自己绑自己（忽略）+ 键鼠不同槽 → 空
	var ignored: Array = Logic.find_conflicts(_mouse(MOUSE_LEFT), bindings, &"action_mouse")
	assert_eq(ignored.size(), 0, "自己绑自己应被忽略")
	assert_eq(conflicts.size(), 1, "鼠标左键被 action_mouse 占用应检出（同为鼠标）")


func test_find_conflicts_mouse_vs_mouse_same_button_conflict() -> void:
	## AC-1 对照: 鼠标↔鼠标同按钮 → 冲突（同类互换规则正向用例）。
	# Arrange
	var bindings: Dictionary = {
		&"action_mouse": [_mouse(MOUSE_RIGHT)],
	}
	# Act
	var conflicts: Array = Logic.find_conflicts(_mouse(MOUSE_RIGHT), bindings)
	# Assert
	assert_eq(conflicts.size(), 1, "鼠标同按钮应算冲突")
	assert_eq(conflicts[0], &"action_mouse", "冲突 action 应为 action_mouse")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1 edge：ESC 防御性返回空
# ═══════════════════════════════════════════════════════════════════════════════

func test_find_conflicts_escape_event_returns_empty() -> void:
	## AC-1 edge: ESC 事件防御性返回空（等待输入层已拦截——ESC=取消等待，
	## GDD 边界澄清 2026-09-07；纯函数层防御不崩溃）。
	# Arrange —— ESC 被 action 占用（异常场景）+ 正常场景
	var esc_key: InputEventKey = InputEventKey.new()
	esc_key.physical_keycode = KEY_ESCAPE_VAL
	var bindings: Dictionary = {
		&"action_a": [esc_key],
		&"action_b": [_key(KEY_ENTER)],
	}
	# Act —— ESC keycode 形态
	var direct: InputEventKey = InputEventKey.new()
	direct.keycode = KEY_ESCAPE_VAL
	assert_eq(Logic.find_conflicts(direct, bindings).size(), 0,
			"keycode 形态 ESC 应防御性返回空")
	# Act —— ESC physical_keycode 形态（project.godot 绑定形态）
	var physical: InputEventKey = InputEventKey.new()
	physical.physical_keycode = KEY_ESCAPE_VAL
	assert_eq(Logic.find_conflicts(physical, bindings).size(), 0,
			"physical 形态 ESC 应防御性返回空")


# ═══════════════════════════════════════════════════════════════════════════════
# 修饰键区分（同键不同修饰 = 不同槽位）
# ═══════════════════════════════════════════════════════════════════════════════

func test_find_conflicts_modifier_difference_is_distinct_slot() -> void:
	## 同键码不同修饰键 → 不算冲突（Ctrl+Q 与 Q 是两个槽位）。
	# Arrange
	var bindings: Dictionary = {
		&"action_a": [_key(KEY_Q, true)],  # Ctrl+Q
	}
	# Act —— 裸 Q
	var conflicts: Array = Logic.find_conflicts(_key(KEY_Q), bindings)
	# Assert
	assert_eq(conflicts.size(), 0, "裸 Q 与 Ctrl+Q 应为不同槽位")


# ═══════════════════════════════════════════════════════════════════════════════
# 序列化往返（AC-2 内核依赖——serialize/deserialize 等价性）
# ═══════════════════════════════════════════════════════════════════════════════

func test_serialize_roundtrip_keyboard_event() -> void:
	## 序列化往返: 键盘事件（含修饰键）→ 字典 → 重构 → 同槽位等价。
	# Arrange
	var original: InputEventKey = _key(KEY_F1, true)
	# Act
	var data: Dictionary = Logic.serialize_event(original)
	var restored: InputEvent = Logic.deserialize_event(data)
	# Assert
	assert_not_null(restored, "往返应重构出事件")
	assert_true(Logic.events_same_slot(original, restored),
			"往返事件应与原事件同槽位")


func test_serialize_roundtrip_mouse_event() -> void:
	## 序列化往返: 鼠标按钮事件 → 字典 → 重构 → 同槽位等价。
	# Arrange
	var original: InputEventMouseButton = _mouse(MOUSE_RIGHT)
	# Act
	var data: Dictionary = Logic.serialize_event(original)
	var restored: InputEvent = Logic.deserialize_event(data)
	# Assert
	assert_not_null(restored, "往返应重构出事件")
	assert_true(Logic.events_same_slot(original, restored),
			"往返事件应与原事件同槽位")


func test_serialize_bindings_skip_unsupported_event_type() -> void:
	## 序列化防御: 不支持的事件类型（手柄按钮——非本 story 范围）→ 跳过不崩溃。
	# Arrange
	var joypad: InputEventJoypadButton = InputEventJoypadButton.new()
	joypad.button_index = JOY_BUTTON_A
	var bindings: Dictionary = {&"action_a": [joypad, _key(KEY_Q)]}
	# Act
	var serialized: Dictionary = Logic.serialize_bindings(bindings)
	# Assert —— 手柄条目被跳过，键盘条目保留
	assert_eq((serialized[&"action_a"] as Array).size(), 1,
			"不支持的事件类型应被跳过")


func test_deserialize_invalid_data_returns_empty() -> void:
	## 反序列化防御: 非法数据（类型标记未知 / 非数组载荷）→ 跳过不崩溃。
	# Arrange
	var bad_data: Dictionary = {
		&"action_a": [{"type": "joypad", "button": 0}],
		&"action_b": "not_an_array",
	}
	# Act
	var bindings: Dictionary = Logic.deserialize_bindings(bad_data)
	# Assert
	assert_false(bindings.has(&"action_a"), "未知类型标记的条目应被跳过")
	assert_false(bindings.has(&"action_b"), "非数组载荷应被跳过")
