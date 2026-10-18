extends GutTest
## main-menu Story 004 集成测试：绑定应用与持久化往返（QA 规格 AC-2 + AC-4）。
##
## 覆盖 QA 规格全部场景与 edge cases（story-004 QA Test Cases）：[br]
##   - AC-2 主体: F1→测试动作 保存 → 重置 InputMap → 从文件加载 → 事件 == F1[br]
##   - AC-2 edge: 多键多 action 同时保存加载[br]
##   - AC-2 edge: 恢复默认后 InputMap == 初始定义（快照法）[br]
##   - AC-4: 自定义后全局恢复默认 → 注册表遍历含 keybinds + InputMap 归位
##     快照 + 设置文件已写回默认[br]
##   - UI 状态机: begin_capture / _handle_capture_event 分离入口——ESC 取消
##     返回列表、无冲突直接绑定、冲突弹确认（覆盖/取消两分支）
##
## 集成范围：KeybindStore（临时 user:// 路径注入）+ 真实 InputMap + KeybindTab
## 控件 + SettingsPanel 注册机制。测试动作用 [code]InputMap.add_action[/code]
## 临时注册（[code]test_kb_*[/code] 前缀）避免污染真实动作——after_each 清理。
## 风格先例：test_graphics_apply.gd（场景实例化 + 引擎态快照还原）。

const Logic: GDScript = preload("res://src/ui/main_menu/keybind_logic.gd")
const StoreScript: GDScript = preload("res://src/ui/main_menu/keybind_store.gd")
const TabScript: GDScript = preload("res://src/ui/main_menu/keybind_tab.gd")
const SettingsStoreScript: GDScript = \
		preload("res://src/ui/main_menu/settings_store.gd")

## 测试键码（fixture 常量——Godot 全局枚举值，别名防 cyclic reference）。
const KEY_F1: int = 4194332
const KEY_Q: int = 81
const MOUSE_RIGHT: int = 2

## 临时动作名（test_kb_ 前缀——清理时按前缀扫描兜底）。
const ACTION_A: StringName = &"test_kb_a"
const ACTION_B: StringName = &"test_kb_b"

var _temp_path: String = ""
var store: Object = null
var tab: Control = null
## 临时动作清理表——before_each 注册、after_each 反注册。
var _temp_actions: Array[StringName] = []


func before_each() -> void:
	_temp_path = "user://keybind_test_%d.json" % (Time.get_ticks_msec() \
			% 1000000 + randi() % 1000)
	store = StoreScript.new()
	store.path = _temp_path
	# 临时动作注册（绑 Q 作默认——快照基准）
	_add_temp_action(ACTION_A, KEY_Q)
	_add_temp_action(ACTION_B, MOUSE_RIGHT)
	tab = TabScript.new()
	tab.animate = false
	tab.keybind_store = store
	add_child_autofree(tab)


func after_each() -> void:
	# 临时动作清理（含前缀兜底扫描——防测试中途失败遗留）
	for action: StringName in _temp_actions:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
			InputMap.erase_action(action)
	_temp_actions = []
	for action: StringName in InputMap.get_actions():
		if String(action).begins_with("test_kb_"):
			InputMap.erase_action(action)
	if tab != null and is_instance_valid(tab):
		tab.free()
	tab = null
	store = null
	if not _temp_path.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_temp_path))
		_temp_path = ""


func _add_temp_action(action: StringName, key_code: int) -> void:
	## 注册临时动作并绑默认键（模拟 project.godot 动作——键盘/鼠标按键值域：
	## ≤32 为鼠标按钮索引，其余为键码）。
	InputMap.add_action(action)
	if key_code <= 32:  # MOUSE_BUTTON_* 枚举值域（1=左 2=右 3=中）
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = key_code
		InputMap.action_add_event(action, event)
	else:
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = key_code
		InputMap.action_add_event(action, event)
	_temp_actions.append(action)


func _f1_key() -> InputEventKey:
	## F1 事件构造（AC-2 Given：绑定 F1）。
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = KEY_F1
	event.pressed = true
	return event


func _pressed_event(code: int) -> InputEventKey:
	## 按下态键盘事件（capture 事件驱动用）。
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event


func _current_codes(action: StringName) -> Array:
	## 动作当前全部绑定键码（physical 优先——与序列化形态一致）。
	var codes: Array = []
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key: InputEventKey = event as InputEventKey
			codes.append(key.physical_keycode \
					if key.physical_keycode != 0 else key.keycode)
		elif event is InputEventMouseButton:
			codes.append((event as InputEventMouseButton).button_index)
	return codes


# ═══════════════════════════════════════════════════════════════════════════════
# AC-2 主体：单键往返（保存 → 重置 → 加载 → 事件 == F1）
# ═══════════════════════════════════════════════════════════════════════════════

func test_roundtrip_single_binding_survives_inputmap_reset() -> void:
	## AC-2: F1→test_kb_a 保存 → InputMap 重置（erase_events）→ 从文件加载
	## 应用 → 该 action 事件 == F1（重启不失效的文件侧证明）。
	# Arrange —— F1 绑 test_kb_a + 快照默认 + 保存
	var f1: InputEventKey = _f1_key()
	var bindings: Dictionary = {ACTION_A: [f1]}
	assert_true(store.save_bindings(bindings), "前置：保存应成功")
	# Act —— 重置 InputMap（模拟重启——project.godot 默认丢失自定义）
	InputMap.action_erase_events(ACTION_A)
	assert_eq(InputMap.action_get_events(ACTION_A).size(), 0,
			"前置：重置后动作无事件")
	var loaded: Dictionary = store.load_bindings()
	StoreScript.apply_bindings(loaded)
	# Assert —— 事件 == F1
	assert_eq(loaded.size(), 1, "加载应含一个 action")
	assert_eq(_current_codes(ACTION_A), [KEY_F1], "加载后事件应为 F1")


func test_roundtrip_load_empty_file_keeps_inputmap_default() -> void:
	## AC-2 防御: 文件无 keybinds 键（首启动）→ 空绑定 → 不应用
	## （InputMap 维持默认——MainMenu._load_keybinds 的空跳过分支）。
	# Act
	var loaded: Dictionary = store.load_bindings()
	# Assert
	assert_true(loaded.is_empty(), "无 keybinds 键应返回空绑定")
	# InputMap 维持默认（Q 仍在）
	assert_eq(_current_codes(ACTION_A), [KEY_Q], "空加载不应扰动 InputMap")


func test_roundtrip_preserves_other_categories_in_file() -> void:
	## merge 语义: 写按键域只覆写 keybinds 键——音量/画面键原样保留。
	# Arrange —— 先写音量键（模拟 Story 002 已落盘数据）
	var settings_store: Object = SettingsStoreScript.new()
	settings_store.path = _temp_path
	settings_store.save_volume_category({0: 55, 1: 55, 2: 55})
	# Act —— 写按键域
	assert_true(store.save_bindings({ACTION_A: [_f1_key()]}), "保存应成功")
	# Assert —— 音量键保留
	var volumes: Dictionary = settings_store.load_volume_category()
	assert_eq(int(volumes.get(0, -1)), 55, "Master 音量键应被保留（merge）")
	var loaded: Dictionary = store.load_bindings()
	StoreScript.apply_bindings(loaded)
	assert_eq(_current_codes(ACTION_A), [KEY_F1], "按键域值应可加载应用")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-2 edge：多键多 action 同时保存加载
# ═══════════════════════════════════════════════════════════════════════════════

func test_roundtrip_multi_action_multi_event() -> void:
	## AC-2 edge: 两 action 各自绑定（test_kb_a→F1 键盘、test_kb_b→右键鼠标）
	## 同时保存 → 重置 → 加载 → 各自归位（键鼠混合载荷）。
	# Arrange
	var f1: InputEventKey = _f1_key()
	var right: InputEventMouseButton = InputEventMouseButton.new()
	right.button_index = MOUSE_RIGHT
	assert_true(store.save_bindings(
			{ACTION_A: [f1], ACTION_B: [right]}), "保存应成功")
	# Act —— 重置 + 加载
	InputMap.action_erase_events(ACTION_A)
	InputMap.action_erase_events(ACTION_B)
	StoreScript.apply_bindings(store.load_bindings())
	# Assert —— 各自归位（键鼠混合）
	assert_eq(_current_codes(ACTION_A), [KEY_F1], "test_kb_a 应为 F1")
	assert_eq(_current_codes(ACTION_B), [MOUSE_RIGHT], "test_kb_b 应为右键")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-2 edge：恢复默认（快照法）
# ═══════════════════════════════════════════════════════════════════════════════

func test_reset_keybind_category_restores_snapshot() -> void:
	## AC-2 edge: 快照法——快照初始绑定（test_kb_a→Q）→ 自定义为 F1 →
	## reset → InputMap 归位 Q + 设置文件写回默认。
	# Arrange —— 快照（Q / 右键）
	store.snapshot_defaults()
	# 自定义为 F1 并保存
	StoreScript.apply_bindings({ACTION_A: [_f1_key()]})
	store.save_bindings({ACTION_A: [_f1_key()]})
	assert_eq(_current_codes(ACTION_A), [KEY_F1], "前置：自定义 F1 已生效")
	# Act —— 恢复默认
	assert_true(store.reset_keybind_category(), "reset 应成功")
	# Assert —— InputMap 归位快照
	assert_eq(_current_codes(ACTION_A), [KEY_Q], "reset 后应归位快照 Q")
	# Assert —— 设置文件也写回默认（重启加载的也是默认）
	StoreScript.apply_bindings(store.load_bindings())
	assert_eq(_current_codes(ACTION_A), [KEY_Q], "reset 后文件值应为默认 Q")


func test_reset_keybind_category_without_snapshot_returns_false() -> void:
	## 防御: 快照未初始化（未调 snapshot_defaults）→ reset 返回 false no-op
	## （不崩溃——注册机制遍历容错）。
	# Act
	var ok: bool = store.reset_keybind_category()
	# Assert
	assert_false(ok, "无快照 reset 应返回 false")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-4：注册机制集成（SettingsPanel 注册 + 全局恢复默认）
# ═══════════════════════════════════════════════════════════════════════════════

func test_reset_all_includes_keybind_category_and_restores_inputmap() -> void:
	## AC-4: 已自定义按键（F1→test_kb_a）且按键分类已注册 → 全局恢复默认 →
	## InputMap 归位快照 + 注册表遍历含 keybinds。
	# Arrange —— SettingsPanel 场景（_ready 注册三分类）+ 快照 + 自定义
	var panel_store: Object = SettingsStoreScript.new()
	panel_store.path = _temp_path
	var panel: Control = load(
			"res://src/ui/main_menu/SettingsPanel.tscn").instantiate()
	panel.animate = false
	panel.settings_store = panel_store
	add_child_autofree(panel)  # _ready 在此刻执行——_setup_keybind_tab 装配
	# 面板的 keybind store 与本测试 store 共路径（读写同一临时文件）
	var panel_keybind_store: Object = panel._get_keybind_store()
	panel_keybind_store.path = _temp_path
	# 快照基准：test_kb_a→Q（本测试 before_each 注册的默认）
	panel_keybind_store.snapshot_defaults()
	# 自定义 F1 + 保存
	StoreScript.apply_bindings({ACTION_A: [_f1_key()]})
	panel_keybind_store.save_bindings({ACTION_A: [_f1_key()]})
	assert_eq(_current_codes(ACTION_A), [KEY_F1], "前置：自定义 F1 已生效")
	# Act —— 全局恢复默认（注册表遍历）
	var ok: bool = panel_store.reset_all_categories()
	# Assert —— reset 成功 + InputMap 归位快照
	assert_true(ok, "全局恢复默认应成功")
	assert_eq(_current_codes(ACTION_A), [KEY_Q], "reset_all 后应归位快照 Q")
	# Assert —— 注册表遍历含 keybinds（AC-4 字面要求）
	var handler_names: Array = panel_store._reset_handlers.keys()
	assert_true(handler_names.has("keybinds"), "注册表应含 keybinds 分类")


func test_reset_all_product_path_without_manual_snapshot() -> void:
	## H-3 回归: 产品路径「恢复默认」走真实快照来源——MainMenu 注入已快照
	## store 到面板，不手动调 snapshot_defaults（此前缺陷：面板本地 new 的
	## store 无快照 → reset 必 no-op 失败，被测试手动快照遮住）。
	# Arrange —— MainMenu 场景 + 注入临时路径的共享 keybind store（_ready
	# 的 _load_keybinds 在注入实例上快照——不读真实 user://settings.json）
	var menu: Control = load(
			"res://src/ui/main_menu/MainMenu.tscn").instantiate()
	menu.animate = false
	var shared_kb: Object = StoreScript.new()
	shared_kb.path = _temp_path
	menu.keybind_store = shared_kb
	add_child_autofree(menu)  # _ready 执行（keybind_store 非空 → 共享实例快照）
	# 打开设置面板（产品路径注入共享 store——H-3 修复接线）
	menu._on_settings_pressed()
	var panel: Control = menu._settings_panel
	assert_not_null(panel, "前置：设置面板已实例化")
	var panel_kb: Object = panel._get_keybind_store()
	assert_eq(panel_kb, shared_kb, "面板应共享 MainMenu 的已快照 store（H-3）")
	# 自定义 F1 + 保存
	StoreScript.apply_bindings({ACTION_A: [_f1_key()]})
	panel_kb.save_bindings({ACTION_A: [_f1_key()]})
	assert_eq(_current_codes(ACTION_A), [KEY_F1], "前置：自定义 F1 已生效")
	# Act —— 全局恢复默认（面板注册表——不手动 snapshot_defaults）
	var ok: bool = panel._get_store().reset_all_categories()
	# Assert —— InputMap 归位快照 Q（产品路径快照来源生效）
	assert_true(ok, "产品路径全局恢复默认应成功")
	assert_eq(_current_codes(ACTION_A), [KEY_Q], "reset_all 后应归位快照 Q")


func test_keybind_tab_visible_under_keybinds_tab() -> void:
	## H-1 回归: KeybindTab 挂 KeybindsTab（VBoxContainer）直接子级——产品路径
	## 按键绑定页内容可见（此前缺陷：挂隐藏占位 Label 之下整树不可见）。
	# Arrange —— 面板场景（_ready 装配 KeybindTab）
	var panel_store: Object = SettingsStoreScript.new()
	panel_store.path = _temp_path
	var panel: Control = load(
			"res://src/ui/main_menu/SettingsPanel.tscn").instantiate()
	panel.animate = false
	panel.settings_store = panel_store
	add_child_autofree(panel)
	panel.visible = true  # 打开面板（产品路径可见性前提）
	# Act —— 切到按键绑定页 + 定位 KeybindTab（TabContainer 仅当前页可见）
	var tab_container: TabContainer = panel.get_node(
			"Panel/PanelVBox/TabContainer")
	tab_container.current_tab = 2  # KeybindsTab（0=音频 1=画面 2=按键 3=语言）
	# TabContainer 页可见性经一帧传播（headless 同——deferred 侧更新）
	await get_tree().process_frame
	var keybinds_tab: VBoxContainer = tab_container.get_node("KeybindsTab")
	var keybind_tab_child: Control = null
	for child: Node in keybinds_tab.get_children():
		if child is KeybindTab:
			keybind_tab_child = child
			break
	# Assert —— 挂载点正确 + 祖先链无 visible=false（headless 下根窗口不可见，
	# is_visible_in_tree 恒 false——改查 CanvasItem.visible 属性链）
	assert_not_null(keybind_tab_child, "KeybindTab 应挂 KeybindsTab 节点下")
	assert_true(keybind_tab_child.visible,
			"KeybindTab 自身 visible 应为 true")
	var ancestor: Node = keybind_tab_child.get_parent()
	while ancestor is CanvasItem:
		var anc: CanvasItem = ancestor as CanvasItem
		assert_true(anc.visible,
				"祖先 %s 不应隐藏（H-1：不挂隐藏占位 Label 之下）" % anc.name)
		ancestor = anc.get_parent()


func test_conflict_dialog_real_signal_paths() -> void:
	## H-2 回归: 冲突确认弹窗的真实信号接线——confirmed → 覆盖生效；
	## canceled → 取消分支复位等待态（此前缺陷：两信号均未连接，覆盖分支
	## 在真实 UI 不可达）。
	# Arrange —— 制造冲突上下文（Q 被 test_kb_a 占用，重绑到 test_kb_b）
	var button: Button = Button.new()
	add_child_autofree(button)
	tab.begin_capture(ACTION_B, button)
	var result: Dictionary = tab._handle_capture_event(_pressed_event(KEY_Q))
	assert_eq(str(result.get("result")), "conflict", "前置：冲突分支")
	var dialog: ConfirmationDialog = tab._confirm_dialog
	assert_not_null(dialog, "前置：确认弹窗已创建")
	# Act ① —— canceled 信号（真实接线路径）
	dialog.canceled.emit()
	# Assert ① —— 等待态复位：闪烁停 + 冲突上下文清 + 按键格恢复键名
	assert_eq(str(tab._capturing_action), &"", "取消后应退出等待态")
	assert_true(tab._pending_conflict.is_empty(), "取消后冲突上下文应清空")
	assert_eq(_current_codes(ACTION_A), [KEY_Q],
			"取消后 InputMap 不变（占用者保留 Q）")
	assert_eq(_current_codes(ACTION_B), [MOUSE_RIGHT],
			"取消后目标 action 维持原绑定")
	# Act ② —— 重新制造冲突，confirmed 信号（真实接线路径）
	tab.begin_capture(ACTION_B, button)
	assert_eq(str(tab._handle_capture_event(_pressed_event(KEY_Q))
			.get("result")), "conflict", "前置②：再次进入冲突分支")
	dialog.confirmed.emit()
	# Assert ② —— 覆盖生效：新 action 抢占 Q、被占用 action 移除 Q
	# （方案 B：ACTION_B 默认含鼠标右键——键盘槽换 Q、鼠标槽保留）
	var codes_after: Array = _current_codes(ACTION_B)
	assert_true(codes_after.has(KEY_Q),
			"confirmed 后新 action 键盘槽应占 Q（真实信号路径）")
	assert_true(codes_after.has(MOUSE_RIGHT),
			"confirmed 后鼠标槽右键应保留（方案 B）")
	assert_eq(_current_codes(ACTION_A), [],
			"confirmed 后被占用 action 应移除 Q")


# ═══════════════════════════════════════════════════════════════════════════════
# UI 状态机（等待输入——可测入口分离）
# ═══════════════════════════════════════════════════════════════════════════════

func test_capture_esc_cancels_waiting() -> void:
	## UI: 等待输入中按 ESC → 取消等待（result=cancelled）+ 按键格恢复键名
	## + InputMap 不变。
	# Arrange —— 进入等待输入
	var button: Button = Button.new()
	add_child_autofree(button)
	tab.begin_capture(ACTION_A, button)
	assert_eq(button.text, "等待输入...", "前置：等待输入态文案")
	# Act —— ESC 按下
	var esc: InputEventKey = InputEventKey.new()
	esc.physical_keycode = 4194305  # KEY_ESCAPE
	esc.pressed = true
	var result: Dictionary = tab._handle_capture_event(esc)
	# Assert
	assert_eq(str(result.get("result")), "cancelled", "ESC 应取消等待")
	assert_true(button.text.begins_with("Q"), "取消后按键格应恢复当前键名（Q 形态）")
	assert_eq(_current_codes(ACTION_A), [KEY_Q], "取消不应改动 InputMap")


func test_capture_new_key_unoccupied_binds_immediately() -> void:
	## UI: 等待输入中按 F1（无占用）→ 直接绑定（result=bound）+ 即时写文件
	## + InputMap 生效。
	# Arrange
	var button: Button = Button.new()
	add_child_autofree(button)
	tab.begin_capture(ACTION_A, button)
	# Act —— F1 按下
	var result: Dictionary = tab._handle_capture_event(_f1_key())
	# Assert —— 绑定 + 即时持久化（文件侧可加载回 F1）
	assert_eq(str(result.get("result")), "bound", "无占用键应直接绑定")
	assert_eq(_current_codes(ACTION_A), [KEY_F1], "InputMap 应即时生效 F1")
	var loaded: Dictionary = store.load_bindings()
	var restored: Array = []
	for event: InputEvent in loaded.get(ACTION_A, []):
		restored.append(Logic.serialize_event(event))
	assert_eq(str(restored[0].get("code", "")), str(KEY_F1),
			"绑定成功即写文件（即时持久化）")


func test_capture_conflicting_key_returns_conflict() -> void:
	## UI: 等待输入中按已被占用的键（Q 被 test_kb_a 占用，重绑到 test_kb_b）
	## → 冲突分支（result=conflict + actions 含占用者）+ 弹确认框。
	# Arrange —— 快照后 test_kb_b 重绑 Q（Q 当前被 test_kb_a 占用）
	var button: Button = Button.new()
	add_child_autofree(button)
	tab.begin_capture(ACTION_B, button)
	# Act —— Q 按下（test_kb_a 占用中）
	var result: Dictionary = tab._handle_capture_event(_pressed_event(KEY_Q))
	# Assert
	assert_eq(str(result.get("result")), "conflict", "占用键应走冲突分支")
	var actions: Array = result.get("actions", [])
	assert_true(actions.has(ACTION_A), "冲突列表应含占用者 test_kb_a")
	# InputMap 未变（等待覆盖确认）
	assert_eq(_current_codes(ACTION_A), [KEY_Q], "冲突未确认前 InputMap 不变")


func test_capture_conflict_overwrite_takes_slot() -> void:
	## UI: 冲突确认「覆盖」→ 新 action 抢占槽位、被占用 action 移除该事件。
	# Arrange —— 制造冲突上下文
	var button: Button = Button.new()
	add_child_autofree(button)
	tab.begin_capture(ACTION_B, button)
	var result: Dictionary = tab._handle_capture_event(_pressed_event(KEY_Q))
	assert_eq(str(result.get("result")), "conflict", "前置：冲突分支")
	# Act —— 模拟用户点「覆盖」（确认回调直调——headless 无真实弹窗交互）
	tab._overwrite_conflicts()
	# Assert —— test_kb_b 键盘槽抢占 Q（方案 B：默认右键鼠标槽保留）、
	# test_kb_a 失去 Q
	var codes_b: Array = _current_codes(ACTION_B)
	assert_true(codes_b.has(KEY_Q), "覆盖后新 action 键盘槽应占 Q")
	assert_true(codes_b.has(MOUSE_RIGHT), "覆盖后鼠标槽右键应保留（方案 B）")
	assert_eq(_current_codes(ACTION_A), [], "被占用 action 应移除 Q")


func test_capture_escape_release_and_echo_ignored() -> void:
	## UI 防御: 等待输入中非按下事件（释放/echo）不触发任何分支。
	# Arrange
	var button: Button = Button.new()
	add_child_autofree(button)
	tab.begin_capture(ACTION_A, button)
	# Act —— 释放态 F1
	var release: InputEventKey = _f1_key()
	release.pressed = false
	assert_eq(str(tab._handle_capture_event(release).get("result")), "ignored",
			"释放事件应被忽略")
	# Act —— echo 重复 Q
	var echo_event: InputEventKey = _pressed_event(KEY_Q)
	echo_event.echo = true
	assert_eq(str(tab._handle_capture_event(echo_event).get("result")),
			"ignored", "echo 重复事件应被忽略")
	# Assert —— 仍在等待态
	assert_eq(button.text, "等待输入...", "忽略后应保持等待输入态")


# ═══════════════════════════════════════════════════════════════════════════════
# 多绑定同类替换语义（QL 裁定 2026-10-18 方案 B）
# ═══════════════════════════════════════════════════════════════════════════════

func test_rebind_same_device_class_keeps_other_device() -> void:
	## 方案 B: 跨设备双绑定 action（键盘+鼠标）重绑键盘侧 → 键盘槽替换、
	## 鼠标槽保留（重绑「确认」到 Q → Enter→Q、左键不动）。
	# Arrange —— test_kb_a 改为跨设备双绑定（Q + 右键）
	var mouse: InputEventMouseButton = InputEventMouseButton.new()
	mouse.button_index = MOUSE_RIGHT
	StoreScript.apply_bindings({ACTION_A: [_pressed_event(KEY_Q), mouse]})
	var button: Button = Button.new()
	add_child_autofree(button)
	# Act —— 重绑键盘 F1（无冲突）
	tab.begin_capture(ACTION_A, button)
	var result: Dictionary = tab._handle_capture_event(_f1_key())
	# Assert —— 键盘槽 Q→F1、鼠标右键保留
	assert_eq(str(result.get("result")), "bound", "应成功绑定")
	var codes: Array = _current_codes(ACTION_A)
	assert_true(codes.has(KEY_F1), "键盘槽应为 F1")
	assert_true(codes.has(MOUSE_RIGHT), "鼠标槽右键应保留（同类替换异类保留）")
	assert_false(codes.has(KEY_Q), "旧键盘 Q 应被替换")


func test_rebind_same_device_class_noop_on_duplicate() -> void:
	## 方案 B 自重复: 重绑 Q 到已绑 Q 的 action → no-op（绑定集不变）。
	# Arrange —— ACTION_A 当前绑 Q
	var before: Array = _current_codes(ACTION_A)
	var button: Button = Button.new()
	add_child_autofree(button)
	tab.begin_capture(ACTION_A, button)
	# Act —— 按 Q（自己已占——find_conflicts 忽略自己 → no-op 提交路径）
	var result: Dictionary = tab._handle_capture_event(_pressed_event(KEY_Q))
	# Assert —— 绑定集不变 + 退出等待态
	assert_eq(str(result.get("result")), "bound", "自重复走绑定路径（无冲突）")
	assert_eq(_current_codes(ACTION_A), before, "自重复应 no-op——绑定集不变")
	assert_eq(str(tab._capturing_action), &"", "no-op 后应退出等待态")
	# M-A 回归：no-op 路径按键格文本恢复（原 _end_capture 不恢复文本——卡死
	# 「等待输入...」）+ modulate 复位（闪烁中途取消无半透明残留）
	assert_true(button.text.begins_with("Q"), "no-op 后按键格应恢复当前键名（M-A）")
	assert_eq(button.modulate.a, 1.0, "no-op 后按键格应无半透明残留（M-A）")


func test_rebind_pure_mouse_action_rejects_keyboard() -> void:
	## 方案 B 准入: 纯鼠标 action（默认绑定集仅鼠标类）收键盘输入 →
	## 提示 + 保持等待态、绑定集不变（继续等待）。
	# Arrange —— 快照记录默认（ACTION_B=右键——纯鼠标）+ tab 挂同 store
	store.snapshot_defaults()
	var button: Button = Button.new()
	add_child_autofree(button)
	tab.begin_capture(ACTION_B, button)
	# Act —— 按 F1（键盘——不在允许设备类）
	var result: Dictionary = tab._handle_capture_event(_f1_key())
	# Assert —— 拒绝 + 仍在等待态
	assert_eq(str(result.get("result")), "ignored",
			"纯鼠标 action 收键盘应被拒绝（设备类准入）")
	assert_eq(str(result.get("reason", "")), "device_class", "拒绝原因应为设备类")
	assert_eq(button.text, "等待输入...", "拒绝后应保持等待输入态")
	assert_eq(_current_codes(ACTION_B), [MOUSE_RIGHT], "绑定集应不变")
	# Act ② —— 按鼠标中键（同属鼠标类——允许）
	var middle: InputEventMouseButton = InputEventMouseButton.new()
	middle.button_index = 3  # MOUSE_BUTTON_MIDDLE
	middle.pressed = true
	var result2: Dictionary = tab._handle_capture_event(middle)
	# Assert ② —— 鼠标类可绑
	assert_eq(str(result2.get("result")), "bound", "鼠标类输入应可绑纯鼠标 action")


func test_conflict_overwrite_keeps_target_other_device_binding() -> void:
	## 方案 B × 冲突覆盖组合: 重绑「确认」类跨设备 action 到 Q（Q 被他人占）
	## → 覆盖后他人移除 Q、目标 action 键盘槽换 Q、鼠标槽保留。
	# Arrange —— ACTION_A 跨设备双绑定（Q + 右键），Q 冲突方 ACTION_B 也占 Q
	var mouse: InputEventMouseButton = InputEventMouseButton.new()
	mouse.button_index = MOUSE_RIGHT
	StoreScript.apply_bindings({ACTION_A: [_pressed_event(KEY_Q), mouse]})
	StoreScript.apply_bindings({ACTION_B: [_pressed_event(KEY_Q)]})
	var button: Button = Button.new()
	add_child_autofree(button)
	tab.begin_capture(ACTION_A, button)
	# Act —— 重绑 F1？不——直接重绑 Q 已被 ACTION_B 占用 → 冲突 → 覆盖
	assert_eq(str(tab._handle_capture_event(_pressed_event(KEY_Q))
			.get("result")), "conflict", "前置：Q 冲突 ACTION_B")
	tab._overwrite_conflicts()
	# Assert —— ACTION_B 移除 Q（空则清空）；ACTION_A 键盘槽 F1→Q、右键保留
	assert_eq(_current_codes(ACTION_B), [], "被占用 action 应移除 Q")
	var codes: Array = _current_codes(ACTION_A)
	assert_true(codes.has(KEY_Q), "覆盖后键盘槽应为 Q")
	assert_true(codes.has(MOUSE_RIGHT), "覆盖后鼠标槽右键应保留（方案 B）")
