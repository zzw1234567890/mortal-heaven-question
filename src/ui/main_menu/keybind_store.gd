class_name KeybindStore
extends RefCounted
## KeybindStore —— 按键绑定持久化 + InputMap 应用（main-menu Story 004）。
##
## [b]所有权归属[/b]（ADR-0031 §2.1）：按键绑定属「持久设置」——复用
## [SettingsStore] 同一设置文件 [code]user://settings.json[/code]，merge 语义
## 只动按键域键（不并入 SettingsStore 类——其 220 行不宜再塞按键分类，
## story 建议拆分）。[br]
## [br][b]存储格式[/b]：单一顶层键 [code]keybinds[/code] 存嵌套字典
## [code]{action: [{type, code/button, 修饰键...}] }[/code]——按键域天然是
## action→多事件映射，平铺前缀 [code]keybind_<action>[/code] 需为每个 action
## 独立编解码且与「整体序列化/反序列化」的往返需求不匹配；单键存嵌套字典
## 让 merge 语义只需覆写一个键，往返读改写闭环在最简单形态。[br]
## [br][b]快照法[/b]（QL-STORY-READY 2026-09-20 裁决）：首次 [method _ready
## 快照时机] 调 [method snapshot_defaults] 保存 InputMap 当前绑定为默认；
## 恢复默认 = 回填快照——不用 [code]InputMap.load_from_project_settings()[/code]
## （会波及未列入绑定表的动作，与「动作列表从 InputMap 枚举生成」的
## Forbidden 规则冲突）。[br]
## [br][b]JSON 解析[/b]：[code]JSON.new().parse()[/code]（control-manifest 必需
## ——绝不使用 [code]JSON.parse_string()[/code]）。
##
## @experimental
## 来源: story-004-keybind-remapping.md、ADR-0031 §2.1、GDD 边界澄清
## 「恢复默认注册机制」「键位持久化加载」。

## === 数据驱动配置 =============================================================

## SettingsStore 脚本常量——文件路径单一真理来源（不复制 SETTINGS_PATH 值）。
const SettingsStoreScript := preload("res://src/ui/main_menu/settings_store.gd")
## Logic 内核——序列化/冲突检测纯函数。
const Logic := preload("res://src/ui/main_menu/keybind_logic.gd")

## 设置文件按键域顶层键（单键嵌套——类注释存储格式裁决）。
const KEY_KEYBINDS: String = "keybinds"

## 内置动作前缀——枚举时过滤 Godot 内建 UI 动作（story Forbidden：
## 动作列表从 InputMap 枚举生成，ui_ 前缀为引擎内建不暴露给玩家）。
const BUILTIN_PREFIX: String = "ui_"

## === 实例状态 ==================================================================

## 设置文件路径——测试注入覆盖（默认与 SettingsStore 同文件）。
var path: String = SettingsStoreScript.SETTINGS_PATH

## 默认绑定快照（快照法——action → Array[InputEvent]）。[br]
## [method snapshot_defaults] 首次填充；[method reset_keybind_category]
## 以此为恢复目标。
var _defaults: Dictionary = {}

## === 枚举（数据驱动——从 InputMap 生成）========================================

## 枚举玩家可重绑定动作（过滤 [code]ui_[/code] 内建前缀）。[br]
## [b]数据驱动[/b]（story Forbidden：硬编码动作列表）——project.godot [input]
## 段的动作随设置演进自动进入列表。
static func list_actions() -> Array[StringName]:
	var result: Array[StringName] = []
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with(BUILTIN_PREFIX):
			result.append(action)
	return result

## 从 InputMap 提取指定动作集的当前绑定映射。[br]
## [b]返回[/b]: [code]{action: Array[InputEvent]}[/code]。
static func collect_current(actions: Array[StringName]) -> Dictionary:
	var bindings: Dictionary = {}
	for action: StringName in actions:
		var events: Array = InputMap.action_get_events(action)
		if not events.is_empty():
			bindings[action] = events
	return bindings

## === 快照（恢复默认基准）======================================================

## 快照当前 InputMap 绑定为默认值（启动时首次调用——见 [MainMenu._ready]）。[br]
## [b]幂等[/b]：已有快照时跳过（防启动加载后再快照污染默认基准——
## 调用方应先快照后加载）。[br]
## [b]返回[/b]: 快照映射 [code]{action: Array[InputEvent]}[/code]（只读消费——
## 勿修改内部引用）。
func snapshot_defaults() -> Dictionary:
	if not _defaults.is_empty():
		return _defaults
	_defaults = collect_current(list_actions())
	return _defaults

## 默认快照只读访问（未快照时为空字典）。
func get_defaults() -> Dictionary:
	return _defaults

## === 持久化（读/写——复用 settings.json，merge 只动 keybinds 键）=============

## 从设置文件读绑定映射。[br]
## [b]返回[/b]: [code]{action: Array[InputEvent]}[/code]——文件缺失 / keybinds
## 键缺失 / 数据非法 / 无合法条目时返回空字典（调用方：空则跳过应用，
## InputMap 维持 project.godot 默认）。
func load_bindings() -> Dictionary:
	var data: Dictionary = _read_settings()
	if not data.has(KEY_KEYBINDS):
		return {}
	var raw: Variant = data[KEY_KEYBINDS]
	if raw is Dictionary:
		return Logic.deserialize_bindings(raw)
	return {}

## 写绑定映射到设置文件（merge 语义——只覆写 [code]keybinds[/code] 键，
## 保留音量/画面等其他分类键）。[br]
## [b]返回[/b]: 成功 true；失败 false（写文件错误 push_error）。
func save_bindings(bindings: Dictionary) -> bool:
	var data: Dictionary = _read_settings()
	data[KEY_KEYBINDS] = Logic.serialize_bindings(bindings)
	return _write_settings(data)

## === 应用与重置 ================================================================

## 应用绑定映射到 InputMap（[code]action_erase_events + action_add_event[/code]
## 逐 action 覆写——[code]action_set_event[/code] 在 4.6.3 不存在，R-05 spike
## 实测 [code]has_method=false[/code]，组合语义等价）。[br]
## 空绑定映射为 no-op。
static func apply_bindings(bindings: Dictionary) -> void:
	for action: Variant in bindings.keys():
		InputMap.action_erase_events(action)
		for event: InputEvent in bindings[action]:
			InputMap.action_add_event(action, event)

## 重置按键分类（全局恢复默认注册项——Story 003 注册机制消费）。[br]
## 快照法：回填 [method snapshot_defaults] 快照 + 写设置文件 + InputMap 归位
## （三合一——story AC「重置 = InputMap 恢复默认绑定 + 写设置文件 + 界面刷新」；
## 界面刷新由宿主 [SettingsPanel] 在 handler 返回后执行）。[br]
## [b]返回[/b]: 快照空（未初始化——防御）或写文件失败 → false。
func reset_keybind_category() -> bool:
	if _defaults.is_empty():
		push_warning("KeybindStore.reset_keybind_category: 默认快照未初始化——no-op")
		return false
	apply_bindings(_defaults)
	return save_bindings(_defaults)

## === 文件读写内部（与 SettingsStore 同模式——JSON.new() 解析）==================

## 读取整个设置文件为字典（文件缺失/损坏/根非字典 → 空字典）。
func _read_settings() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("KeybindStore: 设置文件无法打开: %s" % path)
		return {}
	var raw: String = f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(raw) != OK:
		push_error("KeybindStore: 设置文件解析错误（路径 %s，第 %d 行）——按默认值处理"
				% [path, json.get_error_line()])
		return {}
	var data: Variant = json.get_data()
	if data is Dictionary:
		return data
	push_warning("KeybindStore: 设置文件根节点非字典——按默认值处理")
	return {}

## 写入整个设置文件（store_string 返回值检查——Godot 4.4+ 约束）。
func _write_settings(data: Dictionary) -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("KeybindStore: 设置文件无法写入: %s" % path)
		return false
	var ok: bool = f.store_string(JSON.stringify(data, "\t", false))
	f.close()
	if not ok:
		push_error("KeybindStore: 设置文件写入失败（store_string 返回 false）: %s" % path)
		return false
	return true
