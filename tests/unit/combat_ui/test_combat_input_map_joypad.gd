extends GutTest
## 战斗键盘/手柄输入映射核对（[code]project.godot[/code] → [code][input][/code]）。[br]
## [br][b]背景[/b]：上一轮把底栏焦点链、Esc 逐层退都接通了，但都是拿真实按键投递测的
## ——[b]测的是键盘[/b]。[code]ui_accept[/code] / [code]ui_cancel[/code] 在
## [code]project.godot[/code] 里被重写成「只有键盘事件」时，手柄 A / B 就静默失效：
## 焦点链再完整，手柄玩家也按不动任何一个按钮。而这类缺失不会让任何一条用例变红
## ——引擎的默认 InputMap 只在项目没有覆盖该动作时生效，一旦覆盖就整条替换。[br]
## [br][b]为什么是断言「至少 1 个 JOY 事件」而不是「等于某个具体绑定」[/b]：
## 键位是设计决定，会变；「手柄能不能用」是能力，不该退。断言具体键位会把
## 无关的键位调整变成测试失败，反过来诱导人去改测试而不是改代码。[br]
## [br]本文件只读 InputMap——不加载场景、不投递输入。

## 需要手柄绑定的四个方向动作 + 两个确认动作（见 .claude/rules/ui-code.md）。
const REQUIRED_ACTIONS: Array[String] = [
	&"ui_accept", &"ui_cancel",
	&"ui_left", &"ui_right", &"ui_up", &"ui_down",
]
## 必须有键盘绑定的动作（键盘是主要输入——手柄补充不许把键盘挤掉）。
const KEYBOARD_ACTIONS: Array[String] = [
	&"ui_accept", &"ui_cancel",
	&"ui_left", &"ui_right", &"ui_up", &"ui_down",
]


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 六个动作都存在
# ═══════════════════════════════════════════════════════════════════════════════

## 六个动作在 [method InputMap.has_action] 里成立（没被改名 / 删掉）。[br]
## [br][b]为什么单列这条[/b]：下面几条都假定动作存在；动作一旦改名，
## 那些断言会以「找不到动作」的形式一起红，排查时看不出根因。
func test_all_required_actions_exist() -> void:
	for action: String in REQUIRED_ACTIONS:
		assert_true(InputMap.has_action(action), "动作 %s 应存在" % action)


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 每个动作都至少有一个手柄事件
# ═══════════════════════════════════════════════════════════════════════════════

## 六个动作各自至少 1 个手柄事件（[InputEventJoypadButton] 或
## [InputEventJoypadMotion]）。[br]
## [br][b]为什么这是本文件的核心[/b]：缺手柄绑定时焦点链本身毫无破绽——键盘全绿，
## 手柄玩家却连「确认」都按不出来。这是唯一能在 CI 里挡住该回归的地方。
func test_every_action_has_joypad_binding() -> void:
	for action: String in REQUIRED_ACTIONS:
		assert_gt(_joy_events_of(action).size(), 0,
				"动作 %s 应至少有一个手柄事件（按钮或摇杆）" % action)


## [code]ui_accept[/code] 的有手柄事件——手柄 A 键要能确认。[br]
## [br][b]为什么单独点名[/b]：它是唯一一条「手柄按不出来就整个战斗玩不下去」的动作。
func test_ui_accept_has_joypad_binding() -> void:
	assert_gt(_joy_events_of(&"ui_accept").size(), 0, "ui_accept 应有手柄绑定")


## [code]ui_cancel[/code] 有手柄事件——手柄 B 键要能逐层退出。
func test_ui_cancel_has_joypad_binding() -> void:
	assert_gt(_joy_events_of(&"ui_cancel").size(), 0, "ui_cancel 应有手柄绑定")


## 四个方向动作各至少 1 个手柄事件（十字键或左摇杆）。[br]
## [br][b]为什么方向单独一组[/b]：焦点链的「走位」全靠方向键；确认能按、走不动
## 等于链只有一格。
func test_direction_actions_have_joypad_binding() -> void:
	for action: String in [&"ui_left", &"ui_right", &"ui_up", &"ui_down"]:
		assert_gt(_joy_events_of(action).size(), 0,
				"方向动作 %s 应至少有一个手柄事件" % action)


## 方向动作同时有按钮与摇杆两路——十字键坏了还有摇杆。[br]
## [br][b]为什么不断言「两者都有」[/b]：引擎默认可能只给其一。这里断言的是
## 「每个方向动作的键盘事件恰好一条」——方向键一旦被重复绑定（同一物理键既作
## keycode 又作 physical_keycode），按住方向键会一次触发两遍焦点移动，
## 手感上表现为「一格变两格」。
func test_direction_actions_have_single_keyboard_event() -> void:
	for action: String in [&"ui_left", &"ui_right", &"ui_up", &"ui_down"]:
		assert_eq(_key_events_of(action).size(), 1,
				"方向动作 %s 应只有一条键盘事件（重复绑定会让焦点一次跳两格）" % action)


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 键盘绑定没被手柄挤掉
# ═══════════════════════════════════════════════════════════════════════════════

## 六个动作各自仍有至少 1 个键盘事件。[br]
## [br][b]为什么必须有这条[/b]：给 [code]project.godot[/code] 的 [code]ui_accept[/code]
## 加手柄绑定时，最省事的错法是重写整条动作——把原本的键盘事件一起丢掉。
## 实测发生过（见 [code]combat_focus_chain.gd[/code] 的文档注释）。
## 键盘是主输入（[code].claude/docs/technical-preferences.md[/code]），不能退。
func test_keyboard_bindings_survive_joypad_addition() -> void:
	for action: String in KEYBOARD_ACTIONS:
		assert_gt(_key_events_of(action).size(), 0,
				"动作 %s 应至少保留一个键盘事件" % action)


## [code]ui_accept[/code] 上回车与空格都还在（两个都被玩家熟知）。[br]
## [br][b]为什么点名这两个[/b]：它们是最容易被「顺手删掉」的——回车与空格
## 都能确认，删一个不会立刻显形，但用惯了空格的人会突然按不动。
func test_ui_accept_keeps_enter_and_space() -> void:
	var codes: Array = []
	for event: InputEvent in _key_events_of(&"ui_accept"):
		codes.append((event as InputEventKey).keycode)
	assert_true(codes.has(KEY_ENTER), "ui_accept 应保留回车")
	assert_true(codes.has(KEY_SPACE), "ui_accept 应保留空格")


## [code]ui_cancel[/code] 上 Esc 还在（Esc 逐层退靠它）。
func test_ui_cancel_keeps_escape() -> void:
	var codes: Array = []
	for event: InputEvent in _key_events_of(&"ui_cancel"):
		codes.append((event as InputEventKey).keycode)
	assert_true(codes.has(KEY_ESCAPE), "ui_cancel 应保留 Esc")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 不新增自定义动作名
# ═══════════════════════════════════════════════════════════════════════════════

## 战斗相关的新增动作名没有出现（[code]project.godot[/code] 里自定义的只有
## [code]end_turn[/code] / [code]pause[/code] 两个存量）。[br]
## [br][b]为什么这条要有[/b]：手柄绑定最容易被写成「新加一个 gamepad_accept」，
## 于是全库出现两套语义相同的动作名，后续谁接谁不接全凭记忆。
## 用户口径是「不要新增自定义动作名，除非 GDD 明确要求」。
func test_no_custom_gamepad_action_names() -> void:
	var forbidden: Array[String] = [
		&"gamepad_accept", &"gamepad_cancel", &"pad_accept", &"pad_cancel",
		&"joypad_accept", &"joypad_cancel", &"gamepad_confirm",
	]
	for action: String in forbidden:
		assert_false(InputMap.has_action(action),
				"不该新增自定义手柄动作名 %s（用 ui_* 标准动作）" % action)


# ═══════════════════════════════════════════════════════════════════════════════
# 工具
# ═══════════════════════════════════════════════════════════════════════════════

## [param p_action] 上的手柄事件（按钮 + 摇杆）。
func _joy_events_of(p_action: String) -> Array:
	var found: Array = []
	for event: InputEvent in InputMap.action_get_events(p_action):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			found.append(event)
	return found


## [param p_action] 上的键盘事件。
func _key_events_of(p_action: String) -> Array:
	var found: Array = []
	for event: InputEvent in InputMap.action_get_events(p_action):
		if event is InputEventKey:
			found.append(event)
	return found
