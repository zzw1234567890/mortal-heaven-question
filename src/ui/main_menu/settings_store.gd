class_name SettingsStore
extends RefCounted
## SettingsStore —— 持久设置文件读写（main-menu Story 002）。
##
## [b]所有权归属[/b]（ADR-0031 §2.1 状态三分类）：设置值属「持久设置」——
## 设置面板直接写设置文件 [code]user://settings.json[/code]，[b]不经 GSM[/b]
## （ADR-0001 无 settings 域）、[b]不经 SaveLoadSystem 存档链[/b]。[br]
## [br][b]形态[/b]：RefCounted 工具类（零 Autoload——ADR-0031 §1，Autoload
## 恒 25 红线）；纯同步 JSON 读写（设置文件 <1KB，无异步必要）。[br]
## [br][b]scope[/b]：本 story 只实现 [b]音量分类[/b]三键
## （[code]volume_master / volume_bgm / volume_sfx[/code]，0~100 整数）；
## 文件整体格式（分类嵌套/schema_version）与全局「恢复默认」注册机制由
## Story 003 统一定义——本类保持平铺键值结构 + 只覆写音量键（merge 写入，
## 保留文件中已有的其他键），接口留扩展性（见 [method reset_volume_category]
## 注释的分类注册占位）。[br]
## [br][b]JSON 解析[/b]：[code]JSON.new().parse()[/code]（control-manifest
## 必需——绝不使用 [code]JSON.parse_string()[/code]）。[br]
## [br][b]写入失败处理[/b]：[code]FileAccess.store_string[/code] 返回值必须
## 检查（Godot 4.4+）；失败时 [code]push_error[/code] 并返回 false——
## 调用方（SettingsPanel）保持总线当前值不回滚（设置面板仍打开，玩家可重试）。[br]
## [br][b]消费方[/b]：[SettingsPanel]（打开读 / 应用写 / 关闭回滚读）、
## audio 005（启动加载音量真值——[method load_volume_category] +
## [SettingsLogic.db_from_percent] 覆盖总线默认 dB）。
##
## @experimental
## 来源: ADR-0031 §2.1、story-002-settings-audio.md、story-003（格式统一裁决
## ——本类为音量分类先行实现）。

## === 数据驱动配置 =============================================================

## 设置文件路径（ADR-0031 §2.1——主菜单系统设置面板直写；Story 003 定义
## 完整格式后路径不变）。
const SETTINGS_PATH: String = "user://settings.json"

## 音量键名 → 总线枚举映射（AudioEnums.AudioBus）。[br]
## 三滑条 → Master/BGM/SFX 一一对应（QL-STORY-READY 2026-09-19 裁决——
## 与 audio 001 总线表对齐，无 Music 总线）。
const VOLUME_KEYS: Dictionary = {
	AudioEnums.AudioBus.MASTER: "volume_master",
	AudioEnums.AudioBus.BGM: "volume_bgm",
	AudioEnums.AudioBus.SFX: "volume_sfx",
}

## 音量默认值（%——GDD 设置分类表「总音量/音乐音量/音效音量 默认 100%」；[br]
## 「设置文件默认 100%=0dB 覆盖 bus_layout 默认 SFX -3dB」——QL-STORY-READY
## 2026-09-19 启动真值裁决）。
const VOLUME_DEFAULT: int = 100

## === 实例状态 ==================================================================

## 文件路径——测试注入覆盖（默认 [constant SETTINGS_PATH]）。[br]
## 非游戏状态缓存——瞬态交互注入点（ADR-0031 §2.1 分类）。
var path: String = SETTINGS_PATH

## === 音量分类 API（读/写/重置）===============================================

## 读取音量分类三键。[br]
## [br][b]返回[/b]: [code]{AudioBus 枚举值: int 百分比}[/code]——文件缺失/损坏/
## 单键缺失或超界时该键回退 [constant VOLUME_DEFAULT]（100%——安全默认：
## 首次启动无文件场景，总线维持默认 dB 感知）。[br]
## 超界值钳制到 [0, 100]（与 [SettingsLogic.db_from_percent] 同界——
## 手改文件防御）。
func load_volume_category() -> Dictionary:
	var data: Dictionary = _read_all()
	var result: Dictionary = {}
	for bus: int in VOLUME_KEYS.keys():
		var key: String = VOLUME_KEYS[bus]
		var value: Variant = data.get(key, VOLUME_DEFAULT)
		var percent: int = VOLUME_DEFAULT
		if value is float or value is int:
			# JSON 数字解析为 float——int 化后钳界（float→int 向零取整）
			percent = clampi(int(value), 0, 100)
		result[bus] = percent
	return result

## 写入音量分类三键。[br]
## [br][param volumes]: [code]{AudioBus 枚举值: int 百分比}[/code]
## （通常为 [method load_volume_category] 返回结构的修改版）。[br]
## [b]返回[/b]: 写入成功 true；文件打开失败/存储失败 false（详见类注释）。[br]
## [br][b]merge 语义[/b]：只覆写音量三键，文件中已有其他键（Story 003/004/005
## 落地后的画面/按键/语言键）原样保留——分类间互不踩踏。
func save_volume_category(volumes: Dictionary) -> bool:
	var data: Dictionary = _read_all()
	for bus: int in VOLUME_KEYS.keys():
		if volumes.has(bus):
			data[VOLUME_KEYS[bus]] = clampi(int(volumes[bus]), 0, 100)
		elif volumes.has(VOLUME_KEYS[bus]):
			# 兼容键名传入（防御——测试/调用方直接以键名字典传入）
			data[VOLUME_KEYS[bus]] = clampi(int(volumes[VOLUME_KEYS[bus]]), 0, 100)
	return _write_all(data)

## 重置音量分类（恢复默认 100%）。[br]
## [br]Story 003 全局「恢复默认」注册机制落地后，本方法即音量分类的注册实现
## （分类注册表项：[code]{name: "audio", reset: SettingsStore.reset_volume_category}[/code]
## ——接口签名不变，届时由注册表调用）。[br]
## [b]返回[/b]: 写入成功与否（同 [method save_volume_category]）。
func reset_volume_category() -> bool:
	return save_volume_category(load_volume_category_defaults())

## 音量分类默认值（重置目标——单一真理来源供 reset 与测试消费）。
func load_volume_category_defaults() -> Dictionary:
	var result: Dictionary = {}
	for bus: int in VOLUME_KEYS.keys():
		result[bus] = VOLUME_DEFAULT
	return result

## === 文件读写内部 ==============================================================

## 读取整个设置文件为字典。[br]
## [br][b]返回[/b]: 解析后的字典；文件缺失 / 解析失败 / 根非字典 → 空字典
## （调用方以 [code]Dictionary.get(key, 默认)[/code] 消费——缺失即默认值语义）。
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
## [br][b]返回[/b]: 成功 true；失败 false（[code]store_string[/code] 返回值
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
