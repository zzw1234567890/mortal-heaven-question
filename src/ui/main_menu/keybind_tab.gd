class_name KeybindTab
extends Control
## KeybindTab —— 设置面板「按键绑定」分类控件（main-menu Story 004）。
##
## [b]形态[/b]：[SettingsPanel] 代码实例化挂载到 KeybindsTab 节点的子 Control
## （保持 .tscn 稳定——story 允许两选一；选代码构建因为动作列表数据驱动、
## 行数随 InputMap 演进，静态 .tscn 节点会形成双源漂移）。[br]
## [br][b]即时持久化[/b]（与画面类「点应用」的差异）：按键绑定每格独立生效
## ——绑定成功即写设置文件。理由：GDD AC-016「绑定更新+弹出确认」无应用
## 按钮语义；且键位是即按即换的交互，无「未保存关闭回滚」体验需求。[br]
## [br][b]等待输入状态机[/b]：[method begin_capture] / [method
## _handle_capture_event] 分离纯逻辑入口（集成测试可驱动）——ESC=取消返回
## 列表（GDD 边界澄清 2026-09-07，等待中消费事件防冒泡关闭面板）；新键经
## [KeybindLogic.find_conflicts] 判定 → 无冲突直接绑定 / 有冲突弹「覆盖/取消」
## 确认框（AC-017）。[br]
## [br][b]音频降级[/b]：冲突警告音 AudioManager 契约（audio 14-7）未落地——
## [code]push_warning[/code] 日志占位（story AC 明文允许）。[br]
## [br][b]引擎注记[/b]：[code]InputMap.action_set_event[/code] 在 4.6.3 不存在
## （R-05 spike 实测 has_method=false）——绑定应用走 [code]action_erase_events
## + action_add_event[/code] 组合（[KeybindStore.apply_bindings]）。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]——等待输入由 [code]_unhandled_input
## [/code] 事件驱动；闪烁/0.15s 弹键名用 Tween（纯视觉变换，ADR-0031 §3 豁免）。
##
## @experimental
## 来源: story-004-keybind-remapping.md、GDD main-menu-system.md §按键绑定界面、
## R-05 spike（prototypes/r05-inputmap-api-spike）。

## === Logic / Store 脚本常量 =====================================================

const Logic := preload("res://src/ui/main_menu/keybind_logic.gd")
const StoreScript := preload("res://src/ui/main_menu/keybind_store.gd")

## === 视觉常量（GDD §视觉/音频需求表）===========================================

## 按键绑定成功——按键格弹出新按键名时长（GDD「0.15s」）。
const POPUP_DURATION: float = 0.15
## 等待输入闪烁周期（GDD「闪烁 持续」——Tween 循环视觉变换）。
const BLINK_INTERVAL: float = 0.5

## === 固定 UI 词条（本地化豁免注记——先例 SettingsPanel.TEXT_*）===================

const TEXT_WAITING: String = "等待输入..."
const TEXT_BINDING_DOT: String = "..."
const TEXT_CONFLICT_FMT: String = "该键已绑定 %s，是否覆盖？"
const TEXT_CONFLICT_SEP: String = "、"
## 动作显示名映射（仅显示文本——动作[b]列表[/b]本身数据驱动自 InputMap 枚举，
## 非硬编码列表；未知 action 回退原名）。
const ACTION_LABELS: Dictionary = {
	&"end_turn": "结束回合",
	&"pause": "暂停/菜单",
}

## === 依赖注入 ===================================================================

## 按键持久化 store（注入共享实例——与宿主面板同一 KeybindStore）。
var keybind_store: RefCounted = null
## 动画开关——false 时跳过闪烁/0.15s 弹出（测试 + reduce-motion 接线点）。
var animate: bool = true

## === 瞬态交互状态 ==============================================================

## 等待输入中的 action（空 StringName = 非等待态）。
var _capturing_action: StringName = &""
## 等待输入中的按键格 Button（闪烁 Tween 目标）。
var _capturing_button: Button = null
## 等待输入闪烁 Tween 句柄（结束/取消时 kill）。
var _blink_tween: Tween = null
## 冲突确认弹窗（复用实例——先例 SettingsPanel._confirm_dialog）。
var _confirm_dialog: ConfirmationDialog = null
## 待覆盖确认的冲突上下文——{event: InputEvent, actions: Array[StringName]}。
var _pending_conflict: Dictionary = {}
## 动作行容器（代码构建）。
var _rows_box: VBoxContainer = null
## action → 按键格 Button 映射（刷新/绑定后更新文本）。
var _action_buttons: Dictionary = {}

## === 生命周期 ===================================================================

func _ready() -> void:
	# 代码构建行容器（.tscn 保持稳定——类注释形态裁决）
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rows_box = VBoxContainer.new()
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_box.add_theme_constant_override("separation", 8)
	scroll.add_child(_rows_box)
	add_child(scroll)
	refresh_bindings()

func _exit_tree() -> void:
	_kill_blink()

## === 等待输入（事件驱动——story Guardrail：无忙等循环）=========================

## 等待输入事件入口——[code]_unhandled_input[/code] 分发（集成测试可直调）。[br]
## [b]返回[/b]: 结果字典（供测试断言）：[code]{result: "ignored"/"cancelled"/
## "bound"/"conflict", event?, actions?}[/code]；非等待态返回
## [code]{result: "ignored"}[/code]。[br]
## ESC=取消等待返回列表（消费事件——防冒泡到 [SettingsPanel] 的 ESC 关闭）；
## 键盘/鼠标按下事件（echo 重复过滤）→ 冲突检测分支。
func _handle_capture_event(event: InputEvent) -> Dictionary:
	if _capturing_action == &"":
		return {"result": "ignored"}
	if Logic.is_escape_event(event) and event.pressed and not event.echo:
		_cancel_capture()
		get_viewport().set_input_as_handled()
		return {"result": "cancelled"}
	if not event.pressed or event.echo:
		return {"result": "ignored"}
	if not (event is InputEventKey or event is InputEventMouseButton):
		return {"result": "ignored"}
	# 归一化捕获事件（清 pressed/位置等瞬态字段——序列化往返取干净事件）
	var clean: InputEvent = Logic.deserialize_event(
			Logic.serialize_event(event))
	if clean == null:
		return {"result": "ignored"}
	var conflicts: Array[StringName] = Logic.find_conflicts(
			clean, _collect_bindings(), _capturing_action)
	if conflicts.is_empty():
		_commit_binding(_capturing_action, clean)
		return {"result": "bound", "event": clean}
	_ask_overwrite(clean, conflicts)
	return {"result": "conflict", "event": clean, "actions": conflicts}

func _unhandled_input(event: InputEvent) -> void:
	_handle_capture_event(event)

## === 状态机入口（可测）=========================================================

## 进入等待输入态（点击按键格触发）。[br]
## [param action]: 目标动作；[param button]: 按键格 Button（闪烁目标）。
func begin_capture(action: StringName, button: Button) -> void:
	if _capturing_action != &"":
		_cancel_capture()  # 重入守卫——切换等待目标先复位
	_capturing_action = action
	_capturing_button = button
	button.text = TEXT_WAITING
	_play_blink(button)

## === 绑定应用（即时持久化——类注释裁决）========================================

## 提交绑定：应用 InputMap + 写设置文件 + 按键格 0.15s 弹出新键名。
func _commit_binding(action: StringName, event: InputEvent) -> void:
	var bindings: Dictionary = _collect_bindings()
	bindings[action] = [event]
	StoreScript.apply_bindings({action: [event]})
	if keybind_store != null:
		keybind_store.save_bindings(bindings)
	_end_capture()
	_show_new_key(action, event)

## 冲突覆盖分支（确认弹窗「覆盖」回调）——新 action 抢占槽位，被占用 action
## 移除该事件（GDD 边缘情况「覆盖/取消」语义）。
func _overwrite_conflicts() -> void:
	if _pending_conflict.is_empty():
		return
	var event: InputEvent = _pending_conflict.event
	var actions: Array[StringName] = _pending_conflict.actions
	var bindings: Dictionary = _collect_bindings()
	for other: StringName in actions:
		var kept: Array[InputEvent] = []
		for existing: InputEvent in bindings.get(other, []):
			if not Logic.events_same_slot(event, existing):
				kept.append(existing)
		if kept.is_empty():
			bindings.erase(other)
			InputMap.action_erase_events(other)
		else:
			bindings[other] = kept
			StoreScript.apply_bindings({other: kept})
	var action: StringName = _capturing_action
	_commit_binding(action, event)

## 取消等待——恢复按键格当前键名 + 停闪烁。
func _cancel_capture() -> void:
	var action: StringName = _capturing_action
	var button: Button = _capturing_button
	_end_capture()
	if button != null and is_instance_valid(button) and action != &"":
		button.text = _current_key_text(action)

func _end_capture() -> void:
	_kill_blink()
	_capturing_action = &""
	_capturing_button = null
	_pending_conflict = {}

## === 冲突确认弹窗（AC-017）=====================================================

func _ask_overwrite(event: InputEvent, conflicts: Array[StringName]) -> void:
	# AudioManager 契约（audio 14-7）未落地——push_warning 日志占位
	# （story AC 明文允许的降级路径）
	push_warning("KeybindTab: 按键冲突（警告音占位——AudioManager 未落地）")
	var names: Array[String] = []
	for action: StringName in conflicts:
		names.append(action_label(action))
	_pending_conflict = {"event": event, "actions": conflicts}
	if _confirm_dialog == null:
		_confirm_dialog = ConfirmationDialog.new()
		# 真实信号接线（LP-CODE-REVIEW H-2）：覆盖分支经 confirmed 信号触达；
		# 取消分支复位等待态（恢复按键格文本 + 停闪烁 + 清悬挂上下文）。
		_confirm_dialog.confirmed.connect(_overwrite_conflicts)
		_confirm_dialog.canceled.connect(_on_overwrite_cancelled)
		add_child(_confirm_dialog)
	_confirm_dialog.dialog_text = TEXT_CONFLICT_FMT % TEXT_CONFLICT_SEP.join(names)
	_confirm_dialog.popup_centered()

## 冲突弹窗「取消」——放弃覆盖，退出等待态并复位按键格（AC-017 取消分支）。
func _on_overwrite_cancelled() -> void:
	_cancel_capture()

## === 刷新 / 行构建（数据驱动——InputMap 枚举）==================================

## 重建动作行（打开面板 / 恢复默认后调用）。动作列表从
## [KeybindStore.list_actions] 枚举（story Forbidden：硬编码动作列表）。
func refresh_bindings() -> void:
	for child: Node in _rows_box.get_children():
		child.queue_free()
	_action_buttons = {}
	for action: StringName in StoreScript.list_actions():
		_rows_box.add_child(_build_row(action))

func _build_row(action: StringName) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var label: Label = Label.new()
	label.text = action_label(action)
	label.custom_minimum_size = Vector2(160, 0)
	row.add_child(label)
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(180, 36)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = _current_key_text(action)
	button.pressed.connect(_on_key_button_pressed.bind(action, button))
	row.add_child(button)
	_action_buttons[action] = button
	return row

func _on_key_button_pressed(action: StringName, button: Button) -> void:
	begin_capture(action, button)

## === 视觉（Tween 纯视觉变换——ADR-0031 §3 豁免）===============================

## 等待输入闪烁（按键格文字 alpha 往返——循环 Tween，非忙等）。
func _play_blink(button: Button) -> void:
	_kill_blink()
	if not animate:
		return
	_blink_tween = create_tween()
	_blink_tween.set_loops()
	_blink_tween.tween_property(button, "modulate:a", 0.3,
			BLINK_INTERVAL * 0.5)
	_blink_tween.tween_property(button, "modulate:a", 1.0,
			BLINK_INTERVAL * 0.5)

func _kill_blink() -> void:
	if _blink_tween != null and _blink_tween.is_valid():
		_blink_tween.kill()
	_blink_tween = null

## 绑定成功 0.15s 弹出新键名（GDD 视觉/音频需求表）。
func _show_new_key(action: StringName, event: InputEvent) -> void:
	var button: Button = _action_buttons.get(action)
	if button == null or not is_instance_valid(button):
		return
	if not animate:
		button.text = event.as_text()
		return
	button.text = TEXT_BINDING_DOT
	button.modulate.a = 1.0
	var tween: Tween = create_tween()
	tween.tween_callback(_set_key_text.bind(button,
			event.as_text())).set_delay(POPUP_DURATION)

func _set_key_text(button: Button, text: String) -> void:
	if button != null and is_instance_valid(button):
		button.text = text

## === 内部辅助 ===================================================================

## 从 InputMap 收集全部可重绑定动作的当前绑定（冲突检测载荷）。
func _collect_bindings() -> Dictionary:
	return StoreScript.collect_current(StoreScript.list_actions())

## 动作显示名（未知 action 回退原名——显示文本映射非硬编码列表）。
func action_label(action: StringName) -> String:
	return str(ACTION_LABELS.get(action, String(action)))

## 当前绑定键名文本（首事件 as_text；无绑定时显示空槽）。
func _current_key_text(action: StringName) -> String:
	var events: Array = InputMap.action_get_events(action)
	if events.is_empty():
		return "—"
	return (events[0] as InputEvent).as_text()
