class_name SettingsStore
extends RefCounted
## SettingsStore —— 持久设置文件读写（main-menu Story 002/003）。
##
## [b]所有权归属[/b]（ADR-0031 §2.1 状态三分类）：设置值属「持久设置」——
## 设置面板直接写设置文件 [code]user://settings.json[/code]，[b]不经 GSM[/b]
## （ADR-0001 无 settings 域）、[b]不经 SaveLoadSystem 存档链[/b]。[br]
## [br][b]形态[/b]：RefCounted 工具类（零 Autoload——ADR-0031 §1，Autoload
## 恒 25 红线）；纯同步 JSON 读写（设置文件 <1KB，无异步必要）。[br]
## [br][b]scope[/b]：音量分类（Story 002）+ 画面分类（Story 003）——
## 平铺键值 + merge 写入（QL-STORY-READY 裁决：不嵌套分类）。[br]
## 全局「恢复默认」注册机制（Story 003）：[method register_reset_handler]
## + [method reset_all_categories]。[br]
## [br][b]JSON 解析[/b]：[code]JSON.new().parse()[/code]（control-manifest
## 必需——绝不使用 [code]JSON.parse_string()[/code]）。[br]
## [br][b]写入失败处理[/b]：[code]FileAccess.store_string[/code] 返回值必须
## 检查（Godot 4.4+）；失败时 [code]push_error[/code] 并返回 false。
##
## @experimental
## 来源: ADR-0031 §2.1、story-002-settings-audio.md、story-003-settings-graphics.md。

## === 数据驱动配置 =============================================================

## 设置文件路径（ADR-0031 §2.1——主菜单系统设置面板直写）。
const SETTINGS_PATH: String = "user://settings.json"

## === 音量分类（Story 002）=====================================================

## 音量键名 → 总线枚举映射（AudioEnums.AudioBus）。
## 三滑条 → Master/BGM/SFX 一一对应（与 audio 001 总线表对齐，无 Music 总线）。
const VOLUME_KEYS: Dictionary = {
	AudioEnums.AudioBus.MASTER: "volume_master",
	AudioEnums.AudioBus.BGM: "volume_bgm",
	AudioEnums.AudioBus.SFX: "volume_sfx",
}

## 音量默认值（%——GDD 设置分类表「总音量/音乐音量/音效音量 默认 100%」）。
const VOLUME_DEFAULT: int = 100

## === 画面分类（Story 003）=====================================================

## 画面设置文件键名——平铺顶层键（QL-STORY-READY 裁决：不嵌套分类，
## 沿用 002 结构）。
const GFX_KEY_RESOLUTION_X: String = "resolution_x"
const GFX_KEY_RESOLUTION_Y: String = "resolution_y"
const GFX_KEY_FULLSCREEN: String = "fullscreen"
const GFX_KEY_MAX_FPS: String = "max_fps"
const GFX_KEY_QUALITY: String = "quality"
const GFX_KEY_REDUCE_MOTION: String = "reduce_motion"

## 画面默认值（GDD 设置分类表——分辨率/全屏/帧率/画质）。[br]
## 分辨率默认取自 control-manifest 基准 1920×1080。
const GFX_RESOLUTION_X_DEFAULT: int = 1920
const GFX_RESOLUTION_Y_DEFAULT: int = 1080
const GFX_FULLSCREEN_DEFAULT: bool = false
const GFX_MAX_FPS_DEFAULT: int = 60
const GFX_QUALITY_DEFAULT: String = "medium"
const GFX_REDUCE_MOTION_DEFAULT: bool = false

## === 实例状态 ==================================================================

## 文件路径——测试注入覆盖（默认 [constant SETTINGS_PATH]）。[br]
## 非游戏状态缓存——瞬态交互注入点（ADR-0031 §2.1 分类）。
var path: String = SETTINGS_PATH

## 全局恢复默认注册表——{分类名: Callable 重置方法}。[br]
## [method register_reset_handler] 注册；[method reset_all_categories] 遍历调用。[br]
## 各 reset 方法内部走 merge 写入（只覆写自身分类键），互不踩踏——调用顺序无关。
var _reset_handlers: Dictionary = {}

## === 音量分类 API（读/写/重置——Story 002）===================================

## 读取音量分类三键。[br]
## [b]返回[/b]: [code]{AudioBus 枚举值: int 百分比}[/code]——文件缺失/损坏/
## 单键缺失或超界时该键回退 [constant VOLUME_DEFAULT]。
func load_volume_category() -> Dictionary:
	var data: Dictionary = _read_all()
	var result: Dictionary = {}
	for bus: int in VOLUME_KEYS.keys():
		var key: String = VOLUME_KEYS[bus]
		var value: Variant = data.get(key, VOLUME_DEFAULT)
		var percent: int = VOLUME_DEFAULT
		if value is float or value is int:
			percent = clampi(int(value), 0, 100)
		result[bus] = percent
	return result

## 写入音量分类三键（merge 语义——只覆写音量键，保留其他分类键）。
func save_volume_category(volumes: Dictionary) -> bool:
	var data: Dictionary = _read_all()
	for bus: int in VOLUME_KEYS.keys():
		if volumes.has(bus):
			data[VOLUME_KEYS[bus]] = clampi(int(volumes[bus]), 0, 100)
		elif volumes.has(VOLUME_KEYS[bus]):
			data[VOLUME_KEYS[bus]] = clampi(int(volumes[VOLUME_KEYS[bus]]), 0, 100)
	return _write_all(data)

## 重置音量分类（恢复默认 100%——全局恢复默认注册项）。
func reset_volume_category() -> bool:
	return save_volume_category(load_volume_category_defaults())

## 音量分类默认值（重置目标——单一真理来源供 reset 与测试消费）。
func load_volume_category_defaults() -> Dictionary:
	var result: Dictionary = {}
	for bus: int in VOLUME_KEYS.keys():
		result[bus] = VOLUME_DEFAULT
	return result

## === 画面分类 API（读/写/重置——Story 003）===================================

## 读取画面分类六键。[br]
## [b]返回[/b]: [code]{String 键名: Variant 值}[/code]——文件缺失/损坏/
## 单键缺失时该键回退对应默认值。
func load_graphics_category() -> Dictionary:
	var data: Dictionary = _read_all()
	return {
		GFX_KEY_RESOLUTION_X: _int_or(data, GFX_KEY_RESOLUTION_X, GFX_RESOLUTION_X_DEFAULT),
		GFX_KEY_RESOLUTION_Y: _int_or(data, GFX_KEY_RESOLUTION_Y, GFX_RESOLUTION_Y_DEFAULT),
		GFX_KEY_FULLSCREEN: _bool_or(data, GFX_KEY_FULLSCREEN, GFX_FULLSCREEN_DEFAULT),
		GFX_KEY_MAX_FPS: _int_or(data, GFX_KEY_MAX_FPS, GFX_MAX_FPS_DEFAULT),
		GFX_KEY_QUALITY: _str_or(data, GFX_KEY_QUALITY, GFX_QUALITY_DEFAULT),
		GFX_KEY_REDUCE_MOTION: _bool_or(data, GFX_KEY_REDUCE_MOTION, GFX_REDUCE_MOTION_DEFAULT),
	}

## 写入画面分类六键（merge 语义——只覆写画面键，保留其他分类键）。
func save_graphics_category(graphics: Dictionary) -> bool:
	var data: Dictionary = _read_all()
	for key: String in [GFX_KEY_RESOLUTION_X, GFX_KEY_RESOLUTION_Y,
			GFX_KEY_FULLSCREEN, GFX_KEY_MAX_FPS, GFX_KEY_QUALITY,
			GFX_KEY_REDUCE_MOTION]:
		if graphics.has(key):
			data[key] = graphics[key]
	return _write_all(data)

## 重置画面分类（恢复默认值——全局恢复默认注册项）。
func reset_graphics_category() -> bool:
	return save_graphics_category(load_graphics_category_defaults())

## 画面分类默认值。
func load_graphics_category_defaults() -> Dictionary:
	return {
		GFX_KEY_RESOLUTION_X: GFX_RESOLUTION_X_DEFAULT,
		GFX_KEY_RESOLUTION_Y: GFX_RESOLUTION_Y_DEFAULT,
		GFX_KEY_FULLSCREEN: GFX_FULLSCREEN_DEFAULT,
		GFX_KEY_MAX_FPS: GFX_MAX_FPS_DEFAULT,
		GFX_KEY_QUALITY: GFX_QUALITY_DEFAULT,
		GFX_KEY_REDUCE_MOTION: GFX_REDUCE_MOTION_DEFAULT,
	}

## === 全局恢复默认注册机制（Story 003）======================================

## 注册分类重置处理器（全局「恢复默认」触发时遍历调用）。[br]
## [param name]: 分类名（诊断/日志用）。[param handler]: 无参 Callable——
## 其内部走 merge 写入，各分类互不踩踏，调用顺序无关。
func register_reset_handler(name: String, handler: Callable) -> void:
	_reset_handlers[name] = handler

## 全局恢复默认——遍历已注册分类逐个调用重置。[br]
## [b]返回[/b]: handler 数量 > 0 且全部返回 true → true；任一 handler
## 缺失或失败 → false（push_error 但不中断——剩余 handler 继续执行）。
func reset_all_categories() -> bool:
	if _reset_handlers.is_empty():
		push_warning("SettingsStore.reset_all_categories: 无注册的分类——no-op")
		return false
	var all_ok: bool = true
	for name: String in _reset_handlers.keys():
		var handler: Callable = _reset_handlers[name]
		var result: Variant = handler.call()
		if typeof(result) == TYPE_BOOL and not bool(result):
			push_error("SettingsStore: 分类 '%s' 重置失败" % name)
			all_ok = false
	return all_ok

## === 文件读写内部 ==============================================================

## 读取整个设置文件为字典。[br]
## [b]返回[/b]: 解析后的字典；文件缺失 / 解析失败 / 根非字典 → 空字典。
func _read_all() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("SettingsStore: 设置文件无法打开: %s" % path)
		return {}
	var raw: String = f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(raw) != OK:
		push_error("SettingsStore: 设置文件解析错误（路径 %s，第 %d 行）——"
				% [path, json.get_error_line()] + "按默认值处理")
		return {}
	var data: Variant = json.get_data()
	if data is Dictionary:
		return data
	push_warning("SettingsStore: 设置文件根节点非字典——按默认值处理")
	return {}

## 写入整个设置文件（merge 后的全量字典）。[br]
## [b]返回[/b]: 成功 true；失败 false（[code]store_string[/code] 返回值
## 检查——Godot 4.4+ control-manifest 约束）。
func _write_all(data: Dictionary) -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("SettingsStore: 设置文件无法写入: %s" % path)
		return false
	var ok: bool = f.store_string(
			JSON.stringify(data, "\t", false))
	f.close()
	if not ok:
		push_error("SettingsStore: 设置文件写入失败（store_string 返回 false）: %s" % path)
		return false
	return true

## === 值提取辅助 ===============================================================

## 从字典取 int——缺失/类型不匹配回退默认值。
func _int_or(data: Dictionary, key: String, default: int) -> int:
	var v: Variant = data.get(key, default)
	if v is int: return v
	if v is float: return int(v)
	return default

## 从字典取 bool——缺失/类型不匹配回退默认值。
func _bool_or(data: Dictionary, key: String, default: bool) -> bool:
	var v: Variant = data.get(key, default)
	if v is bool: return v
	return default

## 从字典取 String——缺失/类型不匹配回退默认值。
func _str_or(data: Dictionary, key: String, default: String) -> String:
	var v: Variant = data.get(key, default)
	if v is String: return v
	return default