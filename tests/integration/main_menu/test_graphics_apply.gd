extends GutTest
## main-menu Story 003 集成测试：画面设置应用端到端（QA AC-3）。
##
## 覆盖 QA 规格全部场景与 edge cases：[br]
##   - max_fps 枚举映射 30/60/120/0 全覆盖（Engine.max_fps 实际生效）[br]
##   - 画质预设 → ProjectSettings 键值变更（低/中/高逐键断言，映射表数据驱动）[br]
##   - 全屏开关 → DisplayServer.window_get_mode() 可读不崩溃[br]
##   - 不支持分辨率 → 回退值生效 + fallback_used=true + 不崩溃[br]
##
## 集成范围：SettingsPanel 场景 + 真实 GraphicsTab.apply_to_engine →
## 引擎单例（Engine.max_fps / ProjectSettings / DisplayServer）。[br]
## before/after 快照还原引擎态（Engine.max_fps + 画质三键 + 窗口模式）。
## 风格先例：test_volume_bus_apply.gd（场景实例化 + 引擎单例断言）。

const SETTINGS_SCENE: PackedScene = \
		preload("res://src/ui/main_menu/SettingsPanel.tscn")
const Logic := preload("res://src/ui/main_menu/settings_graphics_logic.gd")
const Store := preload("res://src/ui/main_menu/settings_store.gd")

## 画质 ProjectSettings 键（与 GraphicsTab 同值——单一真理来源镜像）。
const PS_TEXTURE_FILTER: String = \
		"rendering/textures/canvas_textures/default_texture_filter"
const PS_MSAA_2D: String = "rendering/2d/msaa/msaa_2d"
const PS_GLOW_ENABLED: String = "rendering/environment/glow/glow_enabled"

var panel: Control = null
var store: Object = null
var _temp_path: String = ""
## 引擎态快照——after_each 还原（测试自清理）。
var _orig_max_fps: int = 0
var _orig_texture_filter: Variant = null
var _orig_msaa_2d: Variant = null
var _orig_glow_enabled: Variant = null


func before_each() -> void:
	# 引擎态快照（Engine.max_fps / 画质三键）
	_orig_max_fps = Engine.max_fps
	_orig_texture_filter = ProjectSettings.get_setting(PS_TEXTURE_FILTER, null)
	_orig_msaa_2d = ProjectSettings.get_setting(PS_MSAA_2D, null)
	_orig_glow_enabled = ProjectSettings.get_setting(PS_GLOW_ENABLED, null)
	# 临时路径 store——不污染真实 user://settings.json
	_temp_path = "user://settings_gfx_%d.json" % (Time.get_ticks_msec() \
			% 1000000 + randi() % 1000)
	var store_script: GDScript = load("res://src/ui/main_menu/settings_store.gd")
	store = store_script.new()
	store.path = _temp_path
	panel = SETTINGS_SCENE.instantiate()
	panel.animate = false
	panel.settings_store = store
	add_child(panel)


func after_each() -> void:
	if panel != null and is_instance_valid(panel):
		panel.free()
	panel = null
	store = null
	# 引擎态还原
	Engine.max_fps = _orig_max_fps
	if _orig_texture_filter != null:
		ProjectSettings.set_setting(PS_TEXTURE_FILTER, _orig_texture_filter)
	if _orig_msaa_2d != null:
		ProjectSettings.set_setting(PS_MSAA_2D, _orig_msaa_2d)
	if _orig_glow_enabled != null:
		ProjectSettings.set_setting(PS_GLOW_ENABLED, _orig_glow_enabled)
	# 窗口模式还原到窗口化（headless dummy 下 window_set_mode 可能 no-op，
	# 尽力而为——R-04 已查证调用不崩溃）
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	if not _temp_path.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_temp_path))
		_temp_path = ""


func _tab() -> GraphicsTab:
	## GraphicsTab 节点访问器（场景树路径——比私有成员引用更稳）。
	return panel.get_node("Panel/PanelVBox/TabContainer/GraphicsTab")


func _prepared_tab() -> GraphicsTab:
	## 返回已刷新分辨率下拉的 tab（headless 下回退 [1920×1080]）。
	var tab: GraphicsTab = _tab()
	tab.refresh_resolutions(Vector2i(1920, 1080))
	return tab


func _gfx(overrides: Dictionary) -> Dictionary:
	## 组装画面设置字典（默认全默认值 + 覆盖项——apply_to_engine 逐键 get）。
	var gfx: Dictionary = {
		Store.GFX_KEY_RESOLUTION_X: 1920,
		Store.GFX_KEY_RESOLUTION_Y: 1080,
		Store.GFX_KEY_FULLSCREEN: false,
		Store.GFX_KEY_MAX_FPS: Logic.FPS_DEFAULT,
		Store.GFX_KEY_QUALITY: Logic.QUALITY_DEFAULT,
		Store.GFX_KEY_REDUCE_MOTION: false,
	}
	for k: Variant in overrides.keys():
		gfx[k] = overrides[k]
	return gfx


# ═══════════════════════════════════════════════════════════════════════════════
# AC-3：max_fps 枚举映射（30/60/120/0 全覆盖）
# ═══════════════════════════════════════════════════════════════════════════════

func test_graphics_apply_max_fps_parametrized(p = use_parameters([
	[30], [60], [120], [0],
])):
	## AC-3: max_fps 枚举映射全覆盖——Engine.max_fps 实际生效。
	## p[0] = 目标 max_fps 值（30/60/120/不限→0）。
	# Arrange
	var tab: GraphicsTab = _prepared_tab()
	# Act
	tab.apply_to_engine(_gfx({Store.GFX_KEY_MAX_FPS: int(p[0])}),
			Vector2i(1920, 1080))
	# Assert
	assert_eq(Engine.max_fps, int(p[0]), "Engine.max_fps 应等于 %s" % str(p[0]))


# ═══════════════════════════════════════════════════════════════════════════════
# AC-3：画质预设 → ProjectSettings 键值变更
# ═══════════════════════════════════════════════════════════════════════════════

func test_graphics_apply_quality_preset_parametrized(p = use_parameters([
	["low"], ["medium"], ["high"],
])):
	## AC-3: 画质预设 → ProjectSettings 三键逐键生效（映射表数据驱动断言——
	## 断言「应用预设 N → 映射表逐键生效」而非硬编码值）。
	# Arrange
	var tab: GraphicsTab = _prepared_tab()
	var key: String = str(p[0])
	var preset: Dictionary = Logic.QUALITY_PRESETS[key]
	# Act
	tab.apply_to_engine(_gfx({Store.GFX_KEY_QUALITY: key}), Vector2i(1920, 1080))
	# Assert —— 映射表逐键生效（以 Logic.QUALITY_PRESETS 为期望源）
	assert_eq(int(ProjectSettings.get_setting(PS_TEXTURE_FILTER)),
			int(preset.get("texture_filter", 1)),
			"texture_filter 应匹配 %s 预设" % key)
	assert_eq(int(ProjectSettings.get_setting(PS_MSAA_2D)),
			int(preset.get("msaa_2d", 1)),
			"msaa_2d 应匹配 %s 预设" % key)
	assert_eq(bool(ProjectSettings.get_setting(PS_GLOW_ENABLED)),
			bool(preset.get("glow_enabled", false)),
			"glow_enabled 应匹配 %s 预设" % key)


# ═══════════════════════════════════════════════════════════════════════════════
# AC-3：全屏开关 → DisplayServer.window_get_mode()
# ═══════════════════════════════════════════════════════════════════════════════

func test_graphics_apply_fullscreen_window_mode_readable_no_crash() -> void:
	## AC-3: 全屏开关应用 → window_get_mode() 可读（headless 下 mode 枚举仍可读
	## ——R-04 查证）。dummy DisplayServer 可能不真实切换——断言 mode 落在
	## 合法枚举区间且不崩溃（防 window_set_mode 崩溃回归）。
	# Arrange
	var tab: GraphicsTab = _prepared_tab()
	# Act —— 应用全屏
	tab.apply_to_engine(_gfx({Store.GFX_KEY_FULLSCREEN: true}),
			Vector2i(1920, 1080))
	# Assert —— 可读 + 合法枚举 + 不崩溃
	var mode: int = DisplayServer.window_get_mode()
	assert_true(mode >= DisplayServer.WINDOW_MODE_WINDOWED \
			and mode <= DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
			"window_get_mode() 应返回合法枚举（实得 %d）" % mode)


# ═══════════════════════════════════════════════════════════════════════════════
# AC-3：不支持分辨率 → 回退值生效 + 不崩溃
# ═══════════════════════════════════════════════════════════════════════════════

func test_graphics_apply_unsupported_resolution_falls_back_no_crash() -> void:
	## AC-3 edge: 不支持分辨率 → 回退值生效 + fallback_used=true + 不崩溃。
	# Arrange
	var tab: GraphicsTab = _prepared_tab()
	# headless 下枚举空 → 回退 [1920×1080]；请求 1440×900 不在列表
	var requested: Vector2i = Vector2i(1440, 900)
	# Act
	var result: Dictionary = tab.apply_to_engine(
			_gfx({Store.GFX_KEY_RESOLUTION_X: requested.x,
					Store.GFX_KEY_RESOLUTION_Y: requested.y}),
			Vector2i(1280, 720))
	# Assert —— 回退 + 标记 + 不崩溃（到达此行即未崩溃）
	assert_true(bool(result.get("fallback_used", false)),
			"不支持分辨率应标记 fallback_used")
	assert_ne(result.get("resolved", Vector2i.ZERO), requested,
			"回退值不应是未支持请求项")
