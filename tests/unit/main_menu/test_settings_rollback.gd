extends GutTest
## main-menu Story 002 单元测试：未保存回滚（QA AC-2）。
##
## 覆盖 QA 规格全部场景与 edge cases：[br]
##   - 已保存 80%，拖动到 30%，未应用关闭 → 总线回滚 db_from_percent(80)
##     且设置文件未被修改[br]
##   - 拖动后点应用 → 保留（文件已更新）[br]
##   - 拖动→关闭→重开 → 显示已保存值（非拖动值）[br]
##
## 集成范围：SettingsPanel 场景 + 临时路径 SettingsStore + 真实 AudioServer
## 总线（headless GUT 下总线可用——story Engine Notes；before/after 恢复
## 总线原值，测试自清理）。风格先例：test_menu_navigation.gd
## （场景实例化 + 注入 mock）。

const SETTINGS_SCENE: PackedScene = \
		preload("res://src/ui/main_menu/SettingsPanel.tscn")
const LOGIC := preload("res://src/ui/main_menu/settings_logic.gd")

## 三总线枚举 × 名称（AudioEnums 单一真源镜像——总线还原目标）。
const BUSES: Array[int] = [0, 1, 2]  # MASTER / BGM / SFX

## 临时设置文件路径（user:// 域内随机名——after_each 删除自清理）。
var _temp_path: String = ""
var panel: Control = null
var store: Object = null
## 总线原值快照——after_each 还原（快照模式，与 test_volume_bus_apply.gd
## 同源；code-review M-3/GAP-1 裁决：定值复位会跨套件污染 SFX -3dB 布局默认）。
var _orig_bus_dbs: Dictionary = {}


func before_each() -> void:
	# 总线原值快照（before 取值——测试自清理基准）
	_orig_bus_dbs = {}
	for bus: int in BUSES:
		var idx: int = AudioServer.get_bus_index(
				AudioEnums.BUS_NAMES[bus])
		if idx >= 0:
			_orig_bus_dbs[bus] = AudioServer.get_bus_volume_db(idx)
	# 临时文件路径——每次测试独立（绝无跨测试共享可变状态）
	_temp_path = "user://settings_test_%d.json" % (Time.get_ticks_msec() \
			% 1000000 + randi() % 1000)
	var store_script: GDScript = \
			load("res://src/ui/main_menu/settings_store.gd")
	store = store_script.new()
	store.path = _temp_path
	# 前置：设置文件已保存 80%（QA Given）
	store.save_volume_category({0: 80, 1: 80, 2: 80})
	# 场景实例化——animate=false（跳过滑入动画直达可交互态）
	panel = SETTINGS_SCENE.instantiate()
	panel.animate = false
	panel.settings_store = store
	add_child(panel)


func after_each() -> void:
	# 总线还原（集成测试自清理——story 裁决）：还原到测试进入时快照
	# （code-review M-3/GAP-1：不跨套件污染布局默认值——SFX 出厂 -3dB）。
	_restore_buses()
	if panel != null and is_instance_valid(panel):
		panel.free()
	panel = null
	store = null
	if not _temp_path.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_temp_path))
		_temp_path = ""


func _restore_buses() -> void:
	## 总线还原到 before_each 快照（非定值复位——见 after_each 注释）。
	for bus: int in _orig_bus_dbs.keys():
		var idx: int = AudioServer.get_bus_index(
				AudioEnums.BUS_NAMES[bus])
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, float(_orig_bus_dbs[bus]))


func _read_file_raw() -> String:
	## 原文读取设置文件（文件是否被修改的判定基准——比对原文字节）。
	var f: FileAccess = FileAccess.open(_temp_path, FileAccess.READ)
	if f == null:
		return ""
	var raw: String = f.get_as_text()
	f.close()
	return raw


# ═══════════════════════════════════════════════════════════════════════════════
# AC-2：未保存回滚
# ═══════════════════════════════════════════════════════════════════════════════

func test_rollback_unsaved_close_restores_saved_volume() -> void:
	## AC-2 主体: 已保存 80% → 拖到 30% → 未应用关闭 → 总线回滚
	## db_from_percent(80) 且文件未被修改。
	# Arrange —— 打开面板（总线对齐已保存值 80）
	panel.open()
	var file_before: String = _read_file_raw()
	# Act —— 拖动总音量滑条到 30%（value_changed 实时生效——不写文件）
	panel.master_slider.value = 30.0
	# 拖动后总线 = db_from_percent(30)（实时预览生效前置验证）
	var preview_db: float = AudioServer.get_bus_volume_db(
			AudioServer.get_bus_index(&"Master"))
	assert_almost_eq(preview_db, LOGIC.db_from_percent(30.0), 0.01,
			"前置：拖动中总线应实时预览 db_from_percent(30)")
	# 未应用直接关闭
	panel.close()
	# Assert —— 总线回滚到 db_from_percent(80)
	var after_db: float = AudioServer.get_bus_volume_db(
			AudioServer.get_bus_index(&"Master"))
	assert_almost_eq(after_db, LOGIC.db_from_percent(80.0), 0.01,
			"未保存关闭后总线应回滚到 db_from_percent(80)")
	# Assert —— 设置文件未被修改（拖动零文件写入——guardrail）
	assert_eq(_read_file_raw(), file_before,
			"未保存关闭不应修改设置文件（拖动中无文件写入）")


func test_rollback_apply_persists_sliders() -> void:
	## AC-2 edge: 拖动后点应用 → 保留（文件已更新 + 关闭后总线维持新值）。
	# Arrange
	panel.open()
	# Act —— 拖动 BGM 滑条到 30% 后应用
	panel.bgm_slider.value = 30.0
	panel._on_apply_pressed()
	panel.close()
	# Assert —— 文件已写入 30（读回验证）
	var volumes: Dictionary = store.load_volume_category()
	assert_eq(int(volumes.get(1, -1)), 30, "应用后文件 BGM 值应为 30")
	# Assert —— 关闭后总线维持 db_from_percent(30)（应用成功不回滚）
	var bgm_db: float = AudioServer.get_bus_volume_db(
			AudioServer.get_bus_index(&"BGM"))
	assert_almost_eq(bgm_db, LOGIC.db_from_percent(30.0), 0.01,
			"应用后关闭应维持新值 db_from_percent(30)")


func test_rollback_reopen_shows_saved_value() -> void:
	## AC-2 edge: 拖动→关闭→重开 → 滑条显示已保存值（非拖动值）。
	# Arrange
	panel.open()
	# Act —— 拖动 SFX 滑条到 30%，未应用关闭，重开
	panel.sfx_slider.value = 30.0
	panel.close()
	panel.open()
	# Assert —— 重开后滑条 = 已保存值 80（回滚后重读文件）
	assert_eq(panel.sfx_slider.value, 80.0,
			"重开后 SFX 滑条应显示已保存值 80（非拖动值 30）")
	# Assert —— 其余滑条同为已保存值（回滚全量对齐）
	assert_eq(panel.master_slider.value, 80.0, "Master 滑条应为已保存值 80")
	assert_eq(panel.bgm_slider.value, 80.0, "BGM 滑条应为已保存值 80")


func test_rollback_file_missing_defaults_to_hundred() -> void:
	## AC-2 防御: 设置文件不存在（首启动）→ 打开回退默认 100%（文件安全默认）。
	# Arrange —— 删除 before_each 写入的文件
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_temp_path))
	# Act
	panel.open()
	# Assert —— 三滑条均为默认 100%，总线对齐 0.0dB
	assert_eq(panel.master_slider.value, 100.0, "无文件时 Master 应默认 100")
	assert_eq(panel.bgm_slider.value, 100.0, "无文件时 BGM 应默认 100")
	assert_eq(panel.sfx_slider.value, 100.0, "无文件时 SFX 应默认 100")
	var master_db: float = AudioServer.get_bus_volume_db(
			AudioServer.get_bus_index(&"Master"))
	assert_almost_eq(master_db, LOGIC.db_from_percent(100.0), 0.01,
			"无文件时 Master 总线应默认 0.0dB")


func test_rollback_slider_drag_writes_no_file() -> void:
	## AC-2 护栏: 拖动中零文件写入（guardrail——仅实时预览到总线）。
	# Arrange
	panel.open()
	var file_before: String = _read_file_raw()
	# Act —— 连续拖动三滑条（模拟逐帧拖动）
	for v: float in [10.0, 20.0, 30.0, 40.0]:
		panel.master_slider.value = v
		panel.bgm_slider.value = v
		panel.sfx_slider.value = v
	# Assert —— 文件未变（无逐帧写入）
	assert_eq(_read_file_raw(), file_before,
			"拖动过程不应产生任何文件写入（guardrail）")


func test_rollback_apply_failure_keeps_panel_open() -> void:
	## AC-2 防御: 写入失败（路径不可写）→ 面板保持打开、总线维持当前值可重试。
	# Arrange —— 注入失效路径的 store（写入必失败——Windows 下 open() 失败
	## 走 push_error false 分支；用保留字符构造必然失败的路径）
	var bad_store: Object = load("res://src/ui/main_menu/settings_store.gd").new()
	bad_store.path = "user://nonexistent_dir_<bad>/settings.json"
	panel.settings_store = bad_store
	panel.open()
	# Act —— 拖动后应用（写入失败）
	panel.master_slider.value = 30.0
	panel._on_apply_pressed()
	# Assert —— 面板仍打开（失败不关闭不静默丢设置）
	assert_true(panel.visible, "写入失败应保持面板打开（可重试）")
	var master_db: float = AudioServer.get_bus_volume_db(
			AudioServer.get_bus_index(&"Master"))
	assert_almost_eq(master_db, LOGIC.db_from_percent(30.0), 0.01,
			"写入失败时总线维持当前预览值（不回滚不崩溃）")
