class_name KeybindLogic
extends RefCounted
## KeybindLogic —— 按键绑定 Logic 内核（main-menu Story 004）。
##
## [b]纯静态函数[/b]（control-manifest Presentation 必需模式——「冲突检测纯函数
## 单测」；先例 [SettingsLogic]）：不 extends Node、不访问 Autoload、不持有状态
## ——InputMap 读写归 [KeybindStore]，本类只做事件比较与序列化。[br]
## [br][b]同类互换规则[/b]（story Engine Notes 裁决）：键盘↔键盘、鼠标↔鼠标
## 可比较；键盘↔鼠标混绑 [b]不算冲突[/b]（布阵移动等鼠标动作的重绑定语义）。[br]
## [br][b]ESC 防御[/b]：等待输入层已拦截 ESC（取消语义——GDD 边界澄清
## 2026-09-07），纯函数层对 ESC 事件防御性返回空冲突。[br]
## [br][b]引擎 API 注记[/b]：本类仅用 [code]InputEventKey.physical_keycode /
## button_index / *_pressed[/code] 属性手动比较——不依赖
## [code]InputEvent.is_match()[/code]（其 keycode/physical 回退语义不透明），
## 避免版本行为差异；InputMap/输入事件 API 在 4.3~4.6 无变更
## （docs/engine-reference/godot/modules/input.md 无 InputMap 变更标记）。
##
## @experimental
## 来源: story-004-keybind-remapping.md、GDD main-menu-system.md 边缘情况
## 「按键绑定冲突」+ 边界澄清段。

## === 序列化类型标记 ============================================================

## 序列化字典的事件类型标记——键盘事件。
const TYPE_KEY: String = "key"
## 序列化字典的事件类型标记——鼠标按钮事件。
const TYPE_MOUSE: String = "mouse"

## === 设备类（同类替换重绑语义——QL 裁定 2026-10-18 方案 B）=====================

## 设备类标记——键盘。
const CLASS_KEY: String = "key"
## 设备类标记——鼠标。
const CLASS_MOUSE: String = "mouse"

## 判定事件设备类。[br]
## [b]返回[/b]: [code]CLASS_KEY[/code] / [code]CLASS_MOUSE[/code]；
## 不支持的事件类型（手柄等）返回空字符串。
static func device_class(event: InputEvent) -> String:
	if event is InputEventKey:
		return CLASS_KEY
	if event is InputEventMouseButton:
		return CLASS_MOUSE
	return ""

## 重绑定（同类替换、异类保留——QL 裁定 2026-10-18 方案 B）：[br]
## 从 [param action] 绑定集中移除与 [param new_event] 同设备类的全部事件，
## 再加入 [param new_event]——键盘槽替换、鼠标槽保留（跨设备双绑定如
## 「确认=Enter/左键」重绑一侧不动另一侧）。[br]
## [b]纯函数[/b]：返回新映射，不修改入参。调用方自行前置 [method has_event]
## 同类自重复判定（no-op 语义归调用层）。
static func rebind_event(bindings: Dictionary, action: StringName,
		new_event: InputEvent) -> Dictionary:
	var result: Dictionary = bindings.duplicate(true)
	var kept: Array[InputEvent] = []
	var cls: String = device_class(new_event)
	for existing: InputEvent in result.get(action, []):
		if device_class(existing) != cls:
			kept.append(existing)
	kept.append(new_event)
	result[action] = kept
	return result

## 新事件是否已存在于 [param action] 绑定集（同槽判定——同类自重复
## no-op 前置检查）。
static func has_event(bindings: Dictionary, action: StringName,
		event: InputEvent) -> bool:
	for existing: InputEvent in bindings.get(action, []):
		if events_same_slot(event, existing):
			return true
	return false

## === ESC 防御 ==================================================================

## 判定事件是否为 ESC（等待输入层拦截语义——ESC = 取消等待，不可绑定）。[br]
## [b]防御性双查[/b]：keycode 与 physical_keycode 任一命中即视为 ESC
## （project.godot 现有动作以 physical_keycode 绑定 ESC）。
static func is_escape_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		return key.keycode == KEY_ESCAPE or key.physical_keycode == KEY_ESCAPE
	return false

## === 同槽位判定（冲突比较内核）=================================================

## 归一化键码——physical 优先（布局无关），回退 keycode。[br]
## 真实输入事件两者皆可能有值；project.godot 动作只设 physical_keycode。
static func _key_code(e: InputEventKey) -> int:
	return e.physical_keycode if e.physical_keycode != 0 else e.keycode

## 键盘事件签名——键码 + 四修饰键（同签名 = 同一可绑定槽位）。
static func _key_signature(e: InputEventKey) -> Dictionary:
	return {
		"code": _key_code(e),
		"shift": e.shift_pressed,
		"ctrl": e.ctrl_pressed,
		"alt": e.alt_pressed,
		"meta": e.meta_pressed,
	}

## 鼠标按钮事件签名——按钮索引 + 四修饰键。
static func _mouse_signature(e: InputEventMouseButton) -> Dictionary:
	return {
		"button": e.button_index,
		"shift": e.shift_pressed,
		"ctrl": e.ctrl_pressed,
		"alt": e.alt_pressed,
		"meta": e.meta_pressed,
	}

## 两事件是否占用同一可绑定槽位。[br]
## [b]同类互换规则[/b]：键盘↔键盘比较键码+修饰键、鼠标↔鼠标比较按钮+修饰键；
## 跨设备（键盘↔鼠标）[b]恒 false[/b]——混绑不算冲突（story Engine Notes 裁决）。
static func events_same_slot(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return _key_signature(a as InputEventKey) \
				== _key_signature(b as InputEventKey)
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return _mouse_signature(a as InputEventMouseButton) \
				== _mouse_signature(b as InputEventMouseButton)
	return false

## === 冲突检测（BLOCKING 单测目标）==============================================

## 冲突检测——返回占用 [param new_event] 槽位的全部 action。[br]
## [br][param new_event]: 待绑定的新输入事件。[br]
## [param bindings]: 现有绑定映射 [code]{action: Array[InputEvent]}[/code]。[br]
## [param ignore_action]: 正在重绑定的目标 action——[b]自己绑自己不算冲突[/b]
## （story 裁决；对 story 给定的两参签名做的必要扩展，默认空 = 不忽略）。[br]
## [b]返回[/b]: 占用该槽位的全部 action（多 action 同绑全返回）；无占用空数组；
## ESC 事件防御性返回空（等待输入层已拦截）。[br]
## [b]纯函数[/b]：不读 InputMap、无状态、无 IO——同输入恒同输出。
static func find_conflicts(new_event: InputEvent, bindings: Dictionary,
		ignore_action: StringName = &"") -> Array[StringName]:
	if is_escape_event(new_event):
		return []
	var result: Array[StringName] = []
	for action: Variant in bindings.keys():
		var action_name: StringName = action
		if action_name == ignore_action:
			continue
		var events: Array = bindings[action]
		for existing: InputEvent in events:
			if events_same_slot(new_event, existing):
				if not result.has(action_name):
					result.append(action_name)
				break
	return result

## === 序列化（InputEvent ↔ 可 JSON 化字典）=====================================

## 单事件 → 可 JSON 化字典。[br]
## [b]返回[/b]: [code]{type, code/button, shift, ctrl, alt, meta}[/code]；
## 不支持的事件类型（手柄等——非本 story 范围）返回空字典（调用方跳过）。
static func serialize_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var data: Dictionary = _key_signature(event as InputEventKey)
		data["type"] = TYPE_KEY
		return data
	if event is InputEventMouseButton:
		var data: Dictionary = _mouse_signature(event as InputEventMouseButton)
		data["type"] = TYPE_MOUSE
		return data
	return {}

## 可 JSON 化字典 → 单事件。[br]
## [b]返回[/b]: 重构的 [InputEventKey] / [InputEventMouseButton]
## （[code]pressed=false[/code] 的干净事件——捕获事件的归一化也经此路径）；
## 类型标记未知 / 数据缺失返回 null。
static func deserialize_event(data: Dictionary) -> InputEvent:
	var type: String = str(data.get("type", ""))
	if type == TYPE_KEY:
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = int(data.get("code", 0))
		event.shift_pressed = bool(data.get("shift", false))
		event.ctrl_pressed = bool(data.get("ctrl", false))
		event.alt_pressed = bool(data.get("alt", false))
		event.meta_pressed = bool(data.get("meta", false))
		return event
	if type == TYPE_MOUSE:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = int(data.get("button", 0))
		event.shift_pressed = bool(data.get("shift", false))
		event.ctrl_pressed = bool(data.get("ctrl", false))
		event.alt_pressed = bool(data.get("alt", false))
		event.meta_pressed = bool(data.get("meta", false))
		return event
	return null

## 绑定映射序列化——[code]{action: Array[InputEvent]}[/code] →
## [code]{action: Array[可 JSON 化字典]}[/code]（不支持的事件类型跳过）。
static func serialize_bindings(bindings: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for action: Variant in bindings.keys():
		var serialized: Array = []
		for event: InputEvent in bindings[action]:
			var data: Dictionary = serialize_event(event)
			if not data.is_empty():
				serialized.append(data)
		result[action] = serialized
	return result

## 绑定映射反序列化——[code]{action: Array[字典]}[/code] →
## [code]{action: Array[InputEvent]}[/code]（非法条目跳过；action 无合法事件
## 时该 action 不出现在结果中）。
static func deserialize_bindings(data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for action: Variant in data.keys():
		var events: Array[InputEvent] = []
		if data[action] is Array:
			for entry: Variant in data[action]:
				if entry is Dictionary:
					var event: InputEvent = deserialize_event(entry)
					if event != null:
						events.append(event)
		if not events.is_empty():
			result[action] = events
	return result
