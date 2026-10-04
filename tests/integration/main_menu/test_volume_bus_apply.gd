extends GutTest
## main-menu Story 002 集成测试：滑条→总线端到端（QA AC-3）。
##
## 覆盖 QA 规格全部场景与 edge cases：[br]
##   - [BGM, SFX, Master] × [0%, 50%, 100%] 参数化轮换设置对应滑条（2026-10-04
##     修订：三滑条三总线全覆盖——SFX 漏测会成为永久盲区）[br]
##   - 断言 [code]AudioServer.get_bus_volume_db(总线)[/code] ==
##     db_from_percent(输入)（容差 ±0.01dB）[br]
##   - Edge: Master 0% → -80dB；100% → 0.0dB（is_equal_approx）[br]
##
## 集成范围：SettingsPanel 场景 + 真实 AudioServer 总线（headless GUT 下
## 总线可用——story Engine Notes；before/after 恢复总线原值——测试自清理）。[br]
## 风格先例：test_menu_navigation.gd（场景实例化 + 参数化 GUT use_parameters）。

const SETTINGS_SCENE: PackedScene = \
		preload("res://src/ui/main_menu/SettingsPanel.tscn")
const LOGIC := preload("res://src/ui/main_menu/settings_logic.gd")

## dB 断言容差（QA AC-3 规格原文「容差 ±0.01dB」）。
const DB_TOLERANCE: float = 0.01

var panel: Control = null
var _orig_bus_dbs: Dictionary = {}

## 总线原值快照——after_each 恢复（集成测试自行清理恢复总线原值——story 交付要求）。
func before_each() -> void:
	_orig_bus_dbs = {}
	for bus: int in AudioEnums.BUS_NAMES.keys():
		var idx: int = AudioServer.get_bus_index(AudioEnums.BUS_NAMES[bus])
		if idx >= 0:
			_orig_bus_dbs[bus] = AudioServer.get_bus_volume_db(idx)
	# 临时路径 store——不污染真实 user://settings.json
	var store: Object = load("res://src/ui/main_menu/settings_store.gd").new()
	store.path = "user://settings_it_%d.json" % (Time.get_ticks_msec() \
			% 1000000 + randi() % 1000)
	panel = SETTINGS_SCENE.instantiate()
	panel.animate = false
	panel.settings_store = store
	add_child(panel)


func after_each() -> void:
	if panel != null and is_instance_valid(panel):
		panel.free()
	panel = null
	# 总线还原（自清理——story 裁决）
	for bus: int in _orig_bus_dbs.keys():
		var idx: int = AudioServer.get_bus_index(AudioEnums.BUS_NAMES[bus])
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, float(_orig_bus_dbs[bus]))


# ═══════════════════════════════════════════════════════════════════════════════
# AC-3：滑条→总线端到端（参数化三滑条 × 三档全覆盖）
# ═══════════════════════════════════════════════════════════════════════════════

func test_volume_bus_apply_parametrized(p = use_parameters([
	[1, 0.0], [1, 50.0], [1, 100.0],   # BGM  × 0/50/100
	[2, 0.0], [2, 50.0], [2, 100.0],   # SFX  × 0/50/100
	[0, 0.0], [0, 50.0], [0, 100.0],   # Master × 0/50/100
])):
	## AC-3: 参数化 [BGM, SFX, Master] × [0%, 50%, 100%]——设置对应滑条 →
	## AudioServer.get_bus_volume_db == db_from_percent(输入)（±0.01dB）。
	## p[0] = AudioBus 枚举（0=Master/1=BGM/2=SFX），p[1] = 滑条百分比。
	# Arrange —— 打开面板（滑条/总线对齐已保存默认值）
	panel.open()
	var slider: HSlider = _slider_for(int(p[0]))
	var bus_name: StringName = AudioEnums.BUS_NAMES[int(p[0])]
	var idx: int = AudioServer.get_bus_index(bus_name)
	assert_true(idx >= 0, "前置：总线 %s 应存在（audio 001 交付）" % bus_name)
	# Act —— 设置滑条值（value_changed → 实时 set_bus_volume_db）
	slider.value = float(p[1])
	# Assert —— 总线 dB == db_from_percent(输入)，容差 ±0.01dB
	var actual_db: float = AudioServer.get_bus_volume_db(idx)
	var expected_db: float = LOGIC.db_from_percent(float(p[1]))
	assert_almost_eq(actual_db, expected_db, DB_TOLERANCE,
			"总线 %s 在滑条 %s%% 时应为 db_from_percent=%.4f（实得 %.4f）"
			% [bus_name, str(p[1]), expected_db, actual_db])


func test_volume_bus_master_zero_is_mute_db() -> void:
	## AC-3 edge: 总音量 0% → Master 总线 -80dB（静音底值精确断言）。
	# Arrange
	panel.open()
	# Act
	panel.master_slider.value = 0.0
	# Assert
	var idx: int = AudioServer.get_bus_index(&"Master")
	var actual_db: float = AudioServer.get_bus_volume_db(idx)
	assert_almost_eq(actual_db, -80.0, DB_TOLERANCE,
			"Master 0%% 应为 -80dB（实得 %f）" % actual_db)


func test_volume_bus_master_full_is_zero_db() -> void:
	## AC-3 edge: 总音量 100% → Master 总线 0.0dB（is_equal_approx——
	## QA 规格原文要求浮点近似断言）。
	# Arrange
	panel.open()
	panel.master_slider.value = 40.0  # 先偏离 100 再回位（确认赋值路径真实生效）
	# Act
	panel.master_slider.value = 100.0
	# Assert
	var idx: int = AudioServer.get_bus_index(&"Master")
	var actual_db: float = AudioServer.get_bus_volume_db(idx)
	assert_almost_eq(actual_db, 0.0, DB_TOLERANCE,
			"Master 100%% 应为 0.0dB（实得 %f）" % actual_db)


func test_volume_bus_slider_step_is_one_percent() -> void:
	## AC-3 前置守卫: 三滑条 step=1（1% 步进——story AC + guardrail；
	## 键盘 ← → 调节粒度由此决定——HSlider 默认键控行为）。
	# Arrange
	panel.open()
	# Act + Assert
	for bus: int in [0, 1, 2]:
		var slider: HSlider = _slider_for(bus)
		assert_eq(slider.step, 1.0, "滑条 %s 的 step 应为 1（1%% 步进）"
				% AudioEnums.BUS_NAMES[bus])
		assert_eq(slider.min_value, 0.0, "滑条 %s 最小值应为 0" % AudioEnums.BUS_NAMES[bus])
		assert_eq(slider.max_value, 100.0, "滑条 %s 最大值应为 100" % AudioEnums.BUS_NAMES[bus])


func test_volume_bus_keyboard_step_changes_volume() -> void:
	## AC-3/AC-4 键盘路径: HSlider 默认键盘 ← → 行为——set_value 经
	## value_changed 同信号路径生效（键盘与鼠标共用 value_changed——
	## UX 10a「键盘 ← → 调节滑条同样实时生效」的信号级验证）。
	# Arrange
	panel.open()
	panel.master_slider.value = 50.0
	# Act —— 键盘等效：按 step 步进（HSlider 默认 → = +step）
	panel.master_slider.value += panel.master_slider.step
	# Assert —— 总线随步进变化（与鼠标拖动同 value_changed 路径）
	var idx: int = AudioServer.get_bus_index(&"Master")
	var actual_db: float = AudioServer.get_bus_volume_db(idx)
	assert_almost_eq(actual_db, LOGIC.db_from_percent(51.0), DB_TOLERANCE,
			"键盘步进 +1%% 应经同一信号路径实时生效到总线")


# ═══════════════════════════════════════════════════════════════════════════════
# 内部辅助
# ═══════════════════════════════════════════════════════════════════════════════

func _slider_for(bus: int) -> HSlider:
	## 总线枚举 → 对应滑条节点（AudioEnums.AudioBus：MASTER=0/BGM=1/SFX=2）。
	match bus:
		0: return panel.master_slider
		1: return panel.bgm_slider
		2: return panel.sfx_slider
	return null
