class_name SettingsGraphicsLogic
extends RefCounted
## SettingsGraphicsLogic —— 画面设置 Logic 内核（main-menu Story 003）。
##
## [b]纯函数静态类[/b]（control-manifest Presentation 必需模式——先例
## [SettingsLogic] / [MainMenuLogic]）：不 extends Node、不访问任何 Autoload、
## 不持有任何状态——全部逻辑在单次静态调用内完成。[br]
## [br][b]消费方[/b]：[GraphicsTab] 分辨率过滤、脏检测；
## [GraphicsTab.apply_to_engine] 帧率/画质映射表。
##
## @experimental
## 来源: story-003-settings-graphics.md、ADR-0031 §2.1、display-server.md R-04。

## === 数据驱动：帧率选项 =======================================================

## 帧率选项映射（标签 → [code]Engine.max_fps[/code] 实际值）。[br]
## 0 = 不限帧（Godot 语义：[code]Engine.max_fps = 0[/code] 禁用帧率限制）。
const FPS_OPTIONS: Array[Dictionary] = [
	{label = "30",  value = 30},
	{label = "60",  value = 60},
	{label = "120", value = 120},
	{label = "不限", value = 0},
]

## 帧率默认值——与 GDD 设置分类表「帧率限制 默认 60fps」一致。
const FPS_DEFAULT: int = 60

## === 数据驱动：画质预设 =======================================================

## 画质预设映射表（低/中/高 → ProjectSettings 键值组合——数据驱动，不散落逻辑判断）。[br]
## [br][b]键说明[/b]：[br]
## - [code]texture_filter[/code]: [code]rendering/textures/canvas_textures/default_texture_filter[/code]
##   （0=Nearest / 1=Linear / 5=Linear+Mipmaps+Anisotropic）[br]
## - [code]msaa_2d[/code]: [code]rendering/2d/msaa/msaa_2d[/code]
##   （0=Disabled / 1=2x / 2=4x / 3=8x）[br]
## - [code]glow_enabled[/code]: [code]rendering/environment/glow/glow_enabled[/code]
##   （bool——2D 项目下经 WorldEnvironment 生效，headless 下可读写但无视觉变化）。[br]
## [br][b]引擎风险[/b]：MSAA 2D 运行时切换在 Godot 4.6 D3D12 下可能需要 Viewport 重建
## 方可完全生效——本映射表写 ProjectSettings 作为「意图声明」，视觉验证留待手动 AC-6。
const QUALITY_PRESETS: Dictionary = {
	"low": {
		texture_filter = 0,  # Nearest（锐利但像素感）
		msaa_2d = 0,         # Disabled
		glow_enabled = false,
	},
	"medium": {
		texture_filter = 1,  # Linear（平滑默认）
		msaa_2d = 1,         # 2x
		glow_enabled = false,
	},
	"high": {
		texture_filter = 5,  # Linear + Mipmaps + Anisotropic（最佳质量）
		msaa_2d = 2,         # 4x
		glow_enabled = true,
	},
}

## 画质预设默认值——GDD「画面质量 默认 中」。
const QUALITY_DEFAULT: String = "medium"

## 画质预设键的显示顺序（下拉列表顺序——低/中/高）。
const QUALITY_ORDER: Array[String] = ["low", "medium", "high"]

## === 分辨率常量 ===============================================================

## 分辨率回退链终止值——control-manifest 基准 1920×1080（与 [constant RESOLUTION_MIN] 同源）。
const RESOLUTION_FALLBACK: Vector2i = Vector2i(1920, 1080)

## 分辨率支持下限——1280×720（control-manifest 2026-09-07 决策「不支持 720p 以下」）。
const RESOLUTION_MIN: Vector2i = Vector2i(1280, 720)

## 宽高比过滤容差——保留与主显示器一致的宽高比（±5%）。
const ASPECT_TOLERANCE: float = 0.05

## === 可用分辨率枚举（引擎绑定——依赖 DisplayServer 单例）====================

## 运行时枚举可用分辨率列表（数据驱动——不硬编码列表）。[br]
## [br][b]注意[/b]：此方法依赖 DisplayServer 引擎单例（headless 下返回空数组）——
## 非纯函数，仅供 [GraphicsTab] 组件调用，不在 Logic 单测范围。[br]
## [b]返回值[/b]：多显示器分辨率去重列表（Vector2i 升序排列）。
static func enumerate_available_resolutions() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var screen_count: int = DisplayServer.get_screen_count()
	for i: int in range(screen_count):
		var size: Vector2i = DisplayServer.screen_get_size(i)
		if size.x >= RESOLUTION_MIN.x and size.y >= RESOLUTION_MIN.y:
			if not result.has(size):
				result.append(size)
	# 升序排列（小分辨率在前——下拉列表默认选中首项为最小支持分辨率）
	result.sort_custom(_compare_resolutions)
	# 宽高比过滤：主显示器（idx 0）为基准——剔除比例不一致项
	# （Implementation Notes L52 强制要求；headless 基准 (0,0) 时跳过过滤）
	if screen_count > 0:
		result = filter_by_aspect_ratio(result, DisplayServer.screen_get_size(0),
				ASPECT_TOLERANCE)
	return result

## 分辨率排序：面积升序（小→大）。
static func _compare_resolutions(a: Vector2i, b: Vector2i) -> bool:
	return (a.x * a.y) < (b.x * b.y)

## 宽高比过滤（QA AC-1 edge case「宽高比不匹配项剔除」——Implementation Notes
## L52 强制要求）。[br]
## [br][param resolutions]: 候选分辨率列表（升序）。[br]
## [param base]: 基准分辨率（主显示器宽高比来源）。[br]
## [param tolerance]: 宽高比绝对容差——[code]|枚举项宽高比 − 基准宽高比| > tolerance[/code]
## 的项被剔除。[br]
## [b]返回[/b]: 宽高比与 base 一致（±tolerance）的子列表（保持原序）。[br]
## [br][b]纯函数[/b]：三入参值类型——同输入恒同输出（BLOCKING 单测目标）。
static func filter_by_aspect_ratio(resolutions: Array,
		base: Vector2i, tolerance: float) -> Array[Vector2i]:
	# 基准不可用（headless / 零尺寸）→ 跳过过滤（返回原列表副本）
	if base.x <= 0 or base.y <= 0:
		return resolutions.duplicate()
	var base_aspect: float = float(base.x) / float(base.y)
	var result: Array[Vector2i] = []
	for res: Variant in resolutions:
		if not (res is Vector2i):
			continue
		var size: Vector2i = res as Vector2i
		if size.x <= 0 or size.y <= 0:
			continue
		var aspect: float = float(size.x) / float(size.y)
		if absf(aspect - base_aspect) <= tolerance:
			result.append(size)
	return result

## === 分辨率过滤纯函数（BLOCKING 单测目标）===================================

## 分辨率过滤与回退（QA AC-1）。[br]
## [br][param requested]: 请求分辨率（如玩家下拉选中值）。[br]
## [param available]: 可用分辨率列表（来自 [method enumerate_available_resolutions]
## 或测试注入）。[br]
## [param previous]: 上一生效分辨率（关闭面板时的快照——回退候选）。[br]
## [b]返回[/b]: [code]{resolved: Vector2i, fallback_used: bool}[/code]。[br]
## [br][b]判定[/b]：requested in available → resolved=requested、fallback_used=false；
## requested not in available 且 previous in available → resolved=previous、
## fallback_used=true；两者皆不在 available 或 available 为空 →
## resolved=RESOLUTION_FALLBACK、fallback_used=true。[br]
## [br][b]纯函数[/b]：三入参均为值类型——同输入恒同输出（BLOCKING 单测目标）。
static func filter_resolutions(requested: Vector2i, available: Array,
		previous: Vector2i) -> Dictionary:
	# Guard: available 为空 → 终止到回退默认
	if available.is_empty():
		return {resolved = RESOLUTION_FALLBACK, fallback_used = true}
	# 快乐路径：请求项在可用列表中
	if _array_has(available, requested):
		return {resolved = requested, fallback_used = false}
	# 回退第一候选：上一生效分辨率
	if _array_has(available, previous):
		return {resolved = previous, fallback_used = true}
	# 回退第二候选（终极安全默认）：1920×1080
	return {resolved = RESOLUTION_FALLBACK, fallback_used = true}

## Vector2i 数组包含检查（GDScript [code]Array.has()[/code] 对 Vector2i 的比较语义
## 依赖于 GDScript 的 [code]==[/code] 实现——显式遍历确保值比较语义）。
static func _array_has(arr: Array, target: Vector2i) -> bool:
	for item: Variant in arr:
		if item is Vector2i and (item as Vector2i) == target:
			return true
	return false

## === 未保存变更检测（BLOCKING 单测目标）=====================================

## 待应用字典 vs 已保存字典逐键比较（QA AC-2）。[br]
## [br]类型归一：int 60 == float 60.0 视为相同（GDScript [code]Variant == Variant[/code]
## 的宽松比较——通过 [code]float()[/code] 归一完成）。[br]
## [b]返回[/b]: 任一键值不同 → true；全同（含双方均为空字典） → false。[br]
## [br][b]纯函数[/b]：无状态无 IO。
static func has_unsaved_changes(pending: Dictionary, saved: Dictionary) -> bool:
	var all_keys: Dictionary = {}
	for k: Variant in pending.keys():
		all_keys[k] = true
	for k: Variant in saved.keys():
		all_keys[k] = true
	for key: Variant in all_keys.keys():
		var p_val: Variant = pending.get(key)
		var s_val: Variant = saved.get(key)
		# 类型归一：int/float 双向 float 比较（60 == 60.0 → true）
		var pending_is_num: bool = (p_val is int) or (p_val is float)
		var saved_is_num: bool = (s_val is int) or (s_val is float)
		if pending_is_num and saved_is_num:
			if not is_equal_approx(float(p_val), float(s_val)):
				return true
		elif str(p_val) != str(s_val):
			return true
	return false