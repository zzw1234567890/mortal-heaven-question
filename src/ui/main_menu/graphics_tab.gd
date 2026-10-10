class_name GraphicsTab
extends VBoxContainer
## GraphicsTab —— 设置面板「画面」分类控件（main-menu Story 003）。
##
## [b]形态[/b]：SettingsPanel 的场景内子组件（挂载于 GraphicsTab 节点，
## ADR-0031 §1 场景内节点——零新增 Autoload），把画面分类控件从
## [SettingsPanel] 拆出（settings_panel.gd 贴 300 软限——与 story-002 记账项
## main_menu.gd 拆分同思路）。[br]
## [br][b]画面类统一「点应用」生效[/b]（QL-STORY-READY 2026-09-19 裁决——
## 区别于音量的实时生效）：控件仅收集待应用值，[method apply_to_engine]
## 点应用时统一写引擎；未保存关闭由 [SettingsPanel] 回滚控件。[br]
## [br][b]引擎绑定[/b]（display-server.md R-04 实测结论）：分辨率枚举
## [code]DisplayServer.get_screen_count() + screen_get_size(idx)[/code]（禁用
## 不存在的 [code]screen_get_resolutions()[/code]）；全屏切换
## [code]window_set_mode()[/code]（禁用 [code]window_set_fullscreen()[/code]）；
## 帧率 [code]Engine.max_fps[/code]（0=不限）。[br]
## [br][b]数据驱动[/b]：fps/画质映射表在 [SettingsGraphicsLogic] 常量表；
## 分辨率运行时枚举 + 宽高比过滤——不硬编码列表。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]。
##
## @experimental
## 来源: story-003-settings-graphics.md、ADR-0031 §2.1、display-server.md R-04。

## === Logic 内核（preload——class_name 动态加载不可靠，先例 MainMenu）===========

const Logic := preload("res://src/ui/main_menu/settings_graphics_logic.gd")
## SettingsStore 脚本常量——GFX_KEY_* 单一真理来源（防键名字面量漂移）。
const Store := preload("res://src/ui/main_menu/settings_store.gd")

## === ProjectSettings 键路径（数据驱动——画质预设写入目标）======================

## 纹理过滤键（0=Nearest / 1=Linear / 5=Linear+Mipmaps+Anisotropic）。
const PS_TEXTURE_FILTER: String = \
		"rendering/textures/canvas_textures/default_texture_filter"
## MSAA 2D 键（0=Disabled / 1=2x / 2=4x / 3=8x）。
const PS_MSAA_2D: String = "rendering/2d/msaa/msaa_2d"
## Glow 开关键（bool——2D 项目经 WorldEnvironment 生效，headless 可读写）。
const PS_GLOW_ENABLED: String = "rendering/environment/glow/glow_enabled"

## === 固定 UI 词条（本地化豁免注记——先例 MainMenu.TEXT_*）=====================

const TEXT_RESOLUTION: String = "分辨率"
const TEXT_FULLSCREEN: String = "全屏"
const TEXT_MAX_FPS: String = "帧率限制"
const TEXT_QUALITY: String = "画面质量"
const TEXT_REDUCE_MOTION: String = "减少动态效果"
const TEXT_FULLSCREEN_OFF: String = "窗口化"
const TEXT_FULLSCREEN_ON: String = "全屏"
const TEXT_QUALITY_LABELS: Array[String] = ["低", "中", "高"]

## === 瞬态交互状态（ADR-0031 §2.1——纯 UI 本地，刷新即弃）=====================

## 运行时枚举的可用分辨率列表（open 时刷新；headless 回退 [1920×1080]）。
var _available_resolutions: Array[Vector2i] = []

## === 节点引用 ==================================================================

@onready var _resolution_option: OptionButton = $ResolutionRow/ResolutionOption
@onready var _fullscreen_option: OptionButton = $FullscreenRow/FullscreenOption
@onready var _max_fps_option: OptionButton = $MaxFpsRow/MaxFpsOption
@onready var _quality_option: OptionButton = $QualityRow/QualityOption
@onready var _reduce_motion_check: CheckBox = $ReduceMotionRow/ReduceMotionCheck

## === 生命周期 ==================================================================

func _ready() -> void:
	_apply_texts()
	_populate_fps_options()
	_populate_quality_options()
	_populate_fullscreen_options()

## === 控件填充（静态选项——fps/画质/全屏在 _ready 一次填充）====================

func _apply_texts() -> void:
	$ResolutionRow/ResolutionLabel.text = TEXT_RESOLUTION
	$FullscreenRow/FullscreenLabel.text = TEXT_FULLSCREEN
	$MaxFpsRow/MaxFpsLabel.text = TEXT_MAX_FPS
	$QualityRow/QualityLabel.text = TEXT_QUALITY
	$ReduceMotionRow/ReduceMotionLabel.text = TEXT_REDUCE_MOTION

func _populate_fps_options() -> void:
	_max_fps_option.clear()
	for opt: Dictionary in Logic.FPS_OPTIONS:
		_max_fps_option.add_item(str(opt["label"]))

func _populate_quality_options() -> void:
	_quality_option.clear()
	for label: String in TEXT_QUALITY_LABELS:
		_quality_option.add_item(label)

func _populate_fullscreen_options() -> void:
	_fullscreen_option.clear()
	_fullscreen_option.add_item(TEXT_FULLSCREEN_OFF)
	_fullscreen_option.add_item(TEXT_FULLSCREEN_ON)

## === 公开 API（SettingsPanel 消费）============================================

## 刷新分辨率下拉 + 返回实际选中（previous 不在可用列表时走回退链）。[br]
## [br][param previous]: 上一生效分辨率（打开时的已保存值——回退候选）。[br]
## [b]返回[/b]: 实际选中的分辨率（[code]filter_resolutions[/code] 的 resolved
## ——供宿主对齐脏检测快照基线）。[br]
## headless 下枚举为空 → 注入回退默认 [1920×1080] 保证下拉至少一项。
func refresh_resolutions(previous: Vector2i) -> Vector2i:
	_available_resolutions = Logic.enumerate_available_resolutions()
	if _available_resolutions.is_empty():
		_available_resolutions = [Logic.RESOLUTION_FALLBACK]
	_resolution_option.clear()
	for res: Vector2i in _available_resolutions:
		_resolution_option.add_item("%d×%d" % [res.x, res.y])
	var resolved: Vector2i = Logic.filter_resolutions(
			previous, _available_resolutions, previous)["resolved"]
	_select_resolution(resolved)
	return resolved

## 用设置字典回填全部控件（打开对齐 / 关闭回滚 / 恢复默认共用）。
func set_values(gfx: Dictionary) -> void:
	var res := Vector2i(
			int(gfx.get(Store.GFX_KEY_RESOLUTION_X, 1920)),
			int(gfx.get(Store.GFX_KEY_RESOLUTION_Y, 1080)))
	_select_resolution(res)
	_fullscreen_option.select(1 if bool(gfx.get(Store.GFX_KEY_FULLSCREEN, false)) else 0)
	_max_fps_option.select(_fps_index(int(gfx.get(Store.GFX_KEY_MAX_FPS, Logic.FPS_DEFAULT))))
	_quality_option.select(_quality_index(str(gfx.get(Store.GFX_KEY_QUALITY, Logic.QUALITY_DEFAULT))))
	_reduce_motion_check.button_pressed = bool(gfx.get(Store.GFX_KEY_REDUCE_MOTION, false))

## 收集控件当前值为设置字典（待应用 / 脏检测载荷）。
func collect() -> Dictionary:
	var res: Vector2i = _selected_resolution()
	return {
		Store.GFX_KEY_RESOLUTION_X: res.x,
		Store.GFX_KEY_RESOLUTION_Y: res.y,
		Store.GFX_KEY_FULLSCREEN: _fullscreen_option.selected == 1,
		Store.GFX_KEY_MAX_FPS: int(Logic.FPS_OPTIONS[_max_fps_option.selected]["value"]),
		Store.GFX_KEY_QUALITY: Logic.QUALITY_ORDER[_quality_option.selected],
		Store.GFX_KEY_REDUCE_MOTION: _reduce_motion_check.button_pressed,
	}

## 画面设置统一应用到引擎（点应用时调用——AC-main-menu-009~011 + 减少动效）。[br]
## [br][param gfx]: 待应用设置字典。[br]
## [param previous]: 上一生效分辨率（分辨率回退候选）。[br]
## [b]返回[/b]: [code]{resolved: Vector2i, fallback_used: bool}[/code]——
## [code]fallback_used=true[/code] 时宿主弹「该分辨率不支持，已恢复」提示。
func apply_to_engine(gfx: Dictionary, previous: Vector2i) -> Dictionary:
	var res_result: Dictionary = _apply_resolution(gfx, previous)
	_apply_fullscreen(bool(gfx.get(Store.GFX_KEY_FULLSCREEN, false)))
	_apply_max_fps(int(gfx.get(Store.GFX_KEY_MAX_FPS, Logic.FPS_DEFAULT)))
	_apply_quality(str(gfx.get(Store.GFX_KEY_QUALITY, Logic.QUALITY_DEFAULT)))
	return res_result

## 可用分辨率列表访问器（宿主脏检测/回退提示用）。
func get_available_resolutions() -> Array[Vector2i]:
	return _available_resolutions

## === 引擎应用内部 ==============================================================

## 分辨率应用——经 filter_resolutions 回退链（AC-main-menu-009）。[br]
## 窗口化下设置窗口尺寸；全屏下尺寸由模式决定（不重复设置避免扰动）。
func _apply_resolution(gfx: Dictionary, previous: Vector2i) -> Dictionary:
	var requested := Vector2i(
			int(gfx.get(Store.GFX_KEY_RESOLUTION_X, 1920)),
			int(gfx.get(Store.GFX_KEY_RESOLUTION_Y, 1080)))
	var result: Dictionary = Logic.filter_resolutions(
			requested, _available_resolutions, previous)
	var resolved: Vector2i = result["resolved"]
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_size(resolved)
	return result

## 全屏/窗口切换（AC-main-menu-010——window_set_mode，R-04 已查证）。
func _apply_fullscreen(fullscreen: bool) -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

## 帧率限制应用（AC-main-menu-011——Engine.max_fps，0=不限）。
func _apply_max_fps(max_fps: int) -> void:
	Engine.max_fps = max_fps

## 画质预设应用（AC-main-menu-012——ProjectSettings 写入「意图声明」）。[br]
## [b]引擎风险[/b]：MSAA 2D 运行时切换在 4.6 D3D12 下可能需 Viewport 重建方完全
## 生效——本方法写 ProjectSettings 作为意图声明，视觉验证留待手动 AC-6。
func _apply_quality(quality: String) -> void:
	var preset: Dictionary = Logic.QUALITY_PRESETS.get(quality,
			Logic.QUALITY_PRESETS[Logic.QUALITY_DEFAULT])
	ProjectSettings.set_setting(PS_TEXTURE_FILTER, int(preset.get("texture_filter", 1)))
	ProjectSettings.set_setting(PS_MSAA_2D, int(preset.get("msaa_2d", 1)))
	ProjectSettings.set_setting(PS_GLOW_ENABLED, bool(preset.get("glow_enabled", false)))

## === 内部辅助 ==================================================================

## 当前下拉选中的分辨率。
func _selected_resolution() -> Vector2i:
	var idx: int = _resolution_option.selected
	if idx >= 0 and idx < _available_resolutions.size():
		return _available_resolutions[idx]
	return Logic.RESOLUTION_FALLBACK

## 按值选中分辨率（值不在列表 → 选回退默认）。
func _select_resolution(res: Vector2i) -> void:
	var idx: int = _available_resolutions.find(res)
	_resolution_option.select(idx if idx >= 0 else 0)

## 帧率值 → 下拉索引（默认 60 = 索引 1）。
func _fps_index(value: int) -> int:
	for i: int in range(Logic.FPS_OPTIONS.size()):
		if int(Logic.FPS_OPTIONS[i]["value"]) == value:
			return i
	return 1

## 画质键 → 下拉索引（默认 medium = 索引 1）。
func _quality_index(key: String) -> int:
	var idx: int = Logic.QUALITY_ORDER.find(key)
	return idx if idx >= 0 else 1
