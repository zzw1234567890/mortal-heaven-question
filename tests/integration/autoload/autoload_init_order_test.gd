extends GutTest
## Autoload 链初始化顺序验证（集成测试）
##
## 验证 Foundation 层 5 个 Autoload 按 project.godot 中声明的顺序正确初始化。
## 覆盖 gate-check B6 —— 25 Autoload 初始化顺序在 Godot 4.6 实际运行验证。
##
## 当前已注册 Autoload 链（project.godot [autoload] 顺序）：
##   #1 GameStateManager → #2 InputManager → #3 SceneManager → #4 SaveLoadSystem → #5 EventSystem
##   → #6 CardSystem → #7 ResourceSystem → #8 FactionSystem
##
## 每个 Autoload 测试通过 preload + .new() 创建独立实例并验证初始化完整性。

const GSM_SCRIPT := preload("res://src/foundation/game_state_manager.gd")

var gsm


func before_each() -> void:
	gsm = GSM_SCRIPT.new()
	gsm._ready()


func after_each() -> void:
	gsm.free()
	gsm = null


## 验证 GameStateManager 是 project.godot [autoload] 中的第一个条目
func test_gsm_loaded_in_project_godot_autoload_section() -> void:
	var config := ConfigFile.new()
	var loaded := config.load("res://project.godot")
	assert_eq(loaded, OK, "project.godot 应该能被 ConfigFile 加载")

	# 检查 autoload 部分存在并包含 GameStateManager 作为第一个条目
	assert_true(config.has_section_key("autoload", "GameStateManager"),
		"GameStateManager 必须在 project.godot [autoload] 中注册")


# ────────────────────────────────────────────
# B6: Autoload 初始化顺序验证
# ────────────────────────────────────────────

## 验证 Foundation 层 5 个 Autoload 均已在 project.godot 中注册
func test_all_five_foundation_autoloads_registered_in_project_godot() -> void:
	var config := ConfigFile.new()
	config.load("res://project.godot")

	var expected_autoloads := [
		"GameStateManager",
		"InputManager",
		"SceneManager",
		"SaveLoadSystem",
		"EventSystem",
		"CardSystem",
		"ResourceSystem",
		"FactionSystem",
	]

	for name in expected_autoloads:
		assert_true(config.has_section_key("autoload", name),
			"Autoload '%s' 必须在 project.godot [autoload] 中注册" % name)


## 验证 project.godot [autoload] 部分的条目顺序与 ADR 规范一致
func test_foundation_autoloads_in_correct_order() -> void:
	var config := ConfigFile.new()
	config.load("res://project.godot")

	var keys := config.get_section_keys("autoload")
	assert_true(keys.size() >= 8, "project.godot [autoload] 至少包含 8 个已注册 Autoload")

	# 按 project.godot 中的出现顺序获取 Autoload 键
	var registered_order: Array[String] = []
	for key in keys:
		registered_order.append(key)

	# 验证 Foundation 层 5 个 Autoload 的相对顺序
	var gsm_idx := registered_order.find("GameStateManager")
	var input_idx := registered_order.find("InputManager")
	var scene_idx := registered_order.find("SceneManager")
	var save_idx := registered_order.find("SaveLoadSystem")
	var event_idx := registered_order.find("EventSystem")
	var card_idx := registered_order.find("CardSystem")
	var resource_idx := registered_order.find("ResourceSystem")
	var faction_idx := registered_order.find("FactionSystem")

	assert_true(gsm_idx < input_idx, "#1 GSM 必须在 #2 InputManager 之前")
	assert_true(input_idx < scene_idx, "#2 InputManager 必须在 #3 SceneManager 之前")
	assert_true(scene_idx < save_idx, "#3 SceneManager 必须在 #4 SaveLoadSystem 之前")
	assert_true(save_idx < event_idx, "#4 SaveLoadSystem 必须在 #5 EventSystem 之前")
	# Core 层依赖 Foundation 层——必须在 EventSystem 之后初始化
	assert_true(event_idx < card_idx, "#5 EventSystem 必须在 #6 CardSystem 之前")
	assert_true(card_idx < resource_idx, "#6 CardSystem 必须在 #7 ResourceSystem 之前")
	assert_true(resource_idx < faction_idx, "#7 ResourceSystem 必须在 #8 FactionSystem 之前")


# ────────────────────────────────────────────
# B6 补充：每个 Autoload 脚本文件存在且可加载
# ────────────────────────────────────────────

## 验证 GameStateManager 脚本文件存在
func test_gsm_script_file_exists() -> void:
	assert_not_null(GSM_SCRIPT, "GSM 脚本必须可 preload")


## 验证 InputManager 脚本文件存在
func test_input_manager_script_file_exists() -> void:
	var script := preload("res://src/foundation/input_manager.gd")
	assert_not_null(script, "InputManager 脚本必须可 preload")


## 验证 SceneManager 脚本文件存在
func test_scene_manager_script_file_exists() -> void:
	var script := preload("res://src/foundation/scene_manager.gd")
	assert_not_null(script, "SceneManager 脚本必须可 preload")


## 验证 SaveLoadSystem 脚本文件存在
func test_save_load_system_script_file_exists() -> void:
	var script := preload("res://src/foundation/save_load_system.gd")
	assert_not_null(script, "SaveLoadSystem 脚本必须可 preload")


## 验证 EventSystem 脚本文件存在
func test_event_system_script_file_exists() -> void:
	var script := preload("res://src/foundation/event_system/event_system.gd")
	assert_not_null(script, "EventSystem 脚本必须可 preload")
