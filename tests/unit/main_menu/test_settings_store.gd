extends GutTest
## main-menu Story 002 单元测试：SettingsStore 文件读写（code-review M-1/GAP-2/S-6 补强）。
##
## 覆盖 save/load 的防御分支与公共 API（此前测试仅经面板间接覆盖主路径）：[br]
##   - save 键名兼容分支（`volumes.has(VOLUME_KEYS[bus])`——字符串键传入）[br]
##   - load 超界钳制 / JSON 损坏回退 / 根非字典回退 / 单键缺失回退[br]
##   - merge 语义（只覆写音量三键，保留其他键）[br]
##   - reset_volume_category / load_volume_category_defaults[br]
##
## 纯 RefCounted 直调 + 临时路径注入——无场景树依赖。风格先例：
## test_db_from_percent.gd（arrange/act/assert + 常量文件注记）。

const STORE_SCRIPT: GDScript = \
		preload("res://src/ui/main_menu/settings_store.gd")

## 临时设置文件路径（user:// 域内随机名——after_each 删除自清理）。
var _temp_path: String = ""
var store: Object = null


func before_each() -> void:
	_temp_path = "user://settings_store_test_%d.json" \
			% (Time.get_ticks_msec() % 1000000 + randi() % 1000)
	store = STORE_SCRIPT.new()
	store.path = _temp_path


func after_each() -> void:
	store = null
	if not _temp_path.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_temp_path))
		_temp_path = ""


# ═══════════════════════════════════════════════════════════════════════════════
# save：键名兼容分支（M-1——防御分支必须被测试钉死）
# ═══════════════════════════════════════════════════════════════════════════════

func test_save_string_keys_writes_file() -> void:
	## M-1: 字符串键名传入（"volume_master" 等）同样落盘——键名兼容分支。
	# Act —— 以键名而非枚举传入（走 elif volumes.has(VOLUME_KEYS[bus]) 分支）
	var ok: bool = store.save_volume_category(
			{"volume_master": 50, "volume_bgm": 60, "volume_sfx": 70})
	# Assert —— 写入成功且读回一致（读回经枚举键消费——双向兼容证明）
	assert_true(ok, "字符串键名传入应写入成功")
	var volumes: Dictionary = store.load_volume_category()
	assert_eq(int(volumes.get(0, -1)), 50, "Master 应为 50（键名传入已落盘）")
	assert_eq(int(volumes.get(1, -1)), 60, "BGM 应为 60（键名传入已落盘）")
	assert_eq(int(volumes.get(2, -1)), 70, "SFX 应为 70（键名传入已落盘）")


func test_save_enum_keys_writes_file() -> void:
	## M-1 对照: 枚举键传入（面板真实调用路径——_collect_slider_values 产物）。
	# Act
	var ok: bool = store.save_volume_category({0: 80, 1: 85, 2: 90})
	# Assert
	assert_true(ok, "枚举键名传入应写入成功")
	var volumes: Dictionary = store.load_volume_category()
	assert_eq(int(volumes.get(0, -1)), 80, "Master 应为 80")
	assert_eq(int(volumes.get(1, -1)), 85, "BGM 应为 85")
	assert_eq(int(volumes.get(2, -1)), 90, "SFX 应为 90")


# ═══════════════════════════════════════════════════════════════════════════════
# save：merge 语义 + 超界钳制
# ═══════════════════════════════════════════════════════════════════════════════

func test_save_preserves_unrelated_keys() -> void:
	## merge 语义: 只覆写音量三键——Story 003/004/005 未来键原样保留。
	# Arrange —— 先以文件层写入含未来键的完整结构
	store.save_volume_category({0: 40, 1: 40, 2: 40})
	var parser := JSON.new()
	var f: FileAccess = FileAccess.open(_temp_path, FileAccess.READ)
	assert_eq(parser.parse(f.get_as_text()), OK, "前置：文件应为合法 JSON")
	f.close()
	var data: Dictionary = parser.get_data()
	data["graphics_fullscreen"] = true  # Story 003 未来键模拟
	data["locale"] = "zh_CN"  # Story 005 未来键模拟
	var wf: FileAccess = FileAccess.open(_temp_path, FileAccess.WRITE)
	assert_true(wf.store_string(JSON.stringify(data)), "前置：未来键写入")
	wf.close()
	# Act —— 只覆写音量三键
	var ok: bool = store.save_volume_category({0: 70, 1: 70, 2: 70})
	# Assert —— 音量键更新 + 未来键原样保留
	assert_true(ok, "写入应成功")
	var volumes: Dictionary = store.load_volume_category()
	assert_eq(int(volumes.get(0, -1)), 70, "Master 应更新为 70")
	var parser2 := JSON.new()
	var f2: FileAccess = FileAccess.open(_temp_path, FileAccess.READ)
	assert_eq(parser2.parse(f2.get_as_text()), OK, "前置：文件应为合法 JSON")
	f2.close()
	var after_data: Dictionary = parser2.get_data()
	assert_true(bool(after_data.get("graphics_fullscreen", false)),
			"Story 003 未来键应原样保留（merge 不踩踏）")
	assert_eq(str(after_data.get("locale", "")), "zh_CN",
			"Story 005 未来键应原样保留（merge 不踩踏）")


func test_save_clamps_out_of_range() -> void:
	## 超界钳制: 传入 150 / -20 → 落盘钳制到 [0, 100]（与 db_from_percent 同界）。
	# Act
	var ok: bool = store.save_volume_category({0: 150, 1: -20, 2: 70})
	# Assert
	assert_true(ok, "超界值写入应成功（钳制后落盘）")
	var volumes: Dictionary = store.load_volume_category()
	assert_eq(int(volumes.get(0, -1)), 100, "Master 150 应钳制到 100")
	assert_eq(int(volumes.get(1, -1)), 0, "BGM -20 应钳制到 0")
	assert_eq(int(volumes.get(2, -1)), 70, "SFX 70 应原样保留")


# ═══════════════════════════════════════════════════════════════════════════════
# load：防御分支（损坏/根非字典/单键缺失/超界钳制）
# ═══════════════════════════════════════════════════════════════════════════════

func test_load_corrupted_json_defaults_all() -> void:
	## 损坏回退: JSON 语法错误 → 三键全部回退默认 100。
	# Arrange —— 直接写入非法 JSON
	var f: FileAccess = FileAccess.open(_temp_path, FileAccess.WRITE)
	f.store_string("{not valid json!!!")
	f.close()
	# Act + Assert
	var volumes: Dictionary = store.load_volume_category()
	assert_eq(int(volumes.get(0, -1)), 100, "损坏文件 Master 应回退默认 100")
	assert_eq(int(volumes.get(1, -1)), 100, "损坏文件 BGM 应回退默认 100")
	assert_eq(int(volumes.get(2, -1)), 100, "损坏文件 SFX 应回退默认 100")


func test_load_non_dict_root_defaults_all() -> void:
	## 根非字典回退: 合法 JSON 但根为数组 → 三键全部回退默认 100。
	# Arrange
	var f: FileAccess = FileAccess.open(_temp_path, FileAccess.WRITE)
	f.store_string("[1, 2, 3]")
	f.close()
	# Act + Assert
	var volumes: Dictionary = store.load_volume_category()
	assert_eq(int(volumes.get(0, -1)), 100, "根非字典 Master 应回退默认 100")
	assert_eq(int(volumes.get(1, -1)), 100, "根非字典 BGM 应回退默认 100")
	assert_eq(int(volumes.get(2, -1)), 100, "根非字典 SFX 应回退默认 100")


func test_load_partial_keys_defaults_missing() -> void:
	## 单键缺失回退: 文件只有 volume_master → 其余两键回退默认 100。
	# Arrange
	var f: FileAccess = FileAccess.open(_temp_path, FileAccess.WRITE)
	f.store_string('{"volume_master": 30}')
	f.close()
	# Act + Assert
	var volumes: Dictionary = store.load_volume_category()
	assert_eq(int(volumes.get(0, -1)), 30, "存在的键应取文件值 30")
	assert_eq(int(volumes.get(1, -1)), 100, "缺失键 BGM 应回退默认 100")
	assert_eq(int(volumes.get(2, -1)), 100, "缺失键 SFX 应回退默认 100")


func test_load_clamps_out_of_range() -> void:
	## load 侧超界钳制: 手改文件 150/-20 → 钳制到 [0, 100]。
	# Arrange
	var f: FileAccess = FileAccess.open(_temp_path, FileAccess.WRITE)
	f.store_string('{"volume_master": 150, "volume_bgm": -20, "volume_sfx": 70}')
	f.close()
	# Act + Assert
	var volumes: Dictionary = store.load_volume_category()
	assert_eq(int(volumes.get(0, -1)), 100, "Master 150 应钳制到 100")
	assert_eq(int(volumes.get(1, -1)), 0, "BGM -20 应钳制到 0")
	assert_eq(int(volumes.get(2, -1)), 70, "SFX 70 应原样保留")


# ═══════════════════════════════════════════════════════════════════════════════
# reset 与默认值（S-6——公共 API 零覆盖补齐）
# ═══════════════════════════════════════════════════════════════════════════════

func test_reset_volume_category_restores_defaults_and_merges() -> void:
	## S-6: 写入非默认值 → reset → 三键回 100 且 merge 保留其他键。
	# Arrange —— 音量 30 + Story 003 未来键
	store.save_volume_category({0: 30, 1: 30, 2: 30})
	var f: FileAccess = FileAccess.open(_temp_path, FileAccess.READ)
	var parser := JSON.new()
	assert_eq(parser.parse(f.get_as_text()), OK, "前置：文件应为合法 JSON")
	f.close()
	var data: Dictionary = parser.get_data()
	data["graphics_fullscreen"] = true
	var wf: FileAccess = FileAccess.open(_temp_path, FileAccess.WRITE)
	assert_true(wf.store_string(JSON.stringify(data)), "前置：未来键写入")
	wf.close()
	# Act
	var ok: bool = store.reset_volume_category()
	# Assert —— 三键回默认 + 未来键保留
	assert_true(ok, "reset 写入应成功")
	var volumes: Dictionary = store.load_volume_category()
	assert_eq(int(volumes.get(0, -1)), 100, "reset 后 Master 应回默认 100")
	assert_eq(int(volumes.get(1, -1)), 100, "reset 后 BGM 应回默认 100")
	assert_eq(int(volumes.get(2, -1)), 100, "reset 后 SFX 应回默认 100")
	var parser2 := JSON.new()
	var f2: FileAccess = FileAccess.open(_temp_path, FileAccess.READ)
	assert_eq(parser2.parse(f2.get_as_text()), OK, "reset 后文件应为合法 JSON")
	f2.close()
	var after: Dictionary = parser2.get_data()
	assert_true(bool(after.get("graphics_fullscreen", false)),
			"reset 应保留非音量键（merge 语义）")


func test_load_volume_category_defaults_returns_all_hundred() -> void:
	## S-6: load_volume_category_defaults——三键全 100（Story 003 注册机制消费）。
	# Act
	var defaults: Dictionary = store.load_volume_category_defaults()
	# Assert
	assert_eq(int(defaults.get(0, -1)), 100, "默认值 Master 应为 100")
	assert_eq(int(defaults.get(1, -1)), 100, "默认值 BGM 应为 100")
	assert_eq(int(defaults.get(2, -1)), 100, "默认值 SFX 应为 100")
