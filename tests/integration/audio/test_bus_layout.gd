extends GutTest
## audio Story 001 集成测试：总线布局加载、PersistentLayer 挂载、静默模式。
##
## 覆盖 QA 规格：[br]
##   - AC-1: 9 条总线按名称存在、默认 dB 与 GDD 表一致、Limiter 参数正确[br]
##   - AC-2: AudioManager 节点池挂入 PersistentLayer、PROCESS_MODE_ALWAYS、
##     转场后存活[br]
##   - AC-3: 不可用 adapter 注入 → 11 个 API no-op 不崩溃、日志记录一次[br]
##
## 总线布局经 project.godot [audio] buses/default_bus_layout 自动加载——
## 集成测试运行时 AudioServer 按名称可查即验证该路径（story Engine Notes）。[br]
## 风格先例：tests/integration/hud/test_hud_scene_visibility.gd
## （真实 Autoload 下的挂载断言 + assert_push_warning_count）。

const SM_SCRIPT := preload("res://src/foundation/scene_manager.gd")
const AM_SCRIPT := preload("res://src/ui/audio/audio_manager.gd")
const ADAPTER_SCRIPT := preload("res://src/ui/audio/audio_server_adapter.gd")
const MockFactory := preload("res://tests/integration/scene_manager/mocks/mock_factory.gd")

## GDD 音量规格表默认 dB（期望值——数据真源在 .tres 资产，此处为断言镜像）。
const EXPECTED_DB: Dictionary = {
	&"Master": 0.0,
	&"BGM": 0.0,
	&"SFX": -3.0,
	&"UI": -8.0,
	&"Ambient": -10.0,
	&"Voice": -1.0,
}

## dB 断言容差（浮点资源序列化精度余量）。
const DB_TOLERANCE: float = 0.01

## 全部 9 条总线名称（6 主总线 + 3 SFX 子总线）。
const ALL_BUS_NAMES: Array[StringName] = [
	&"Master", &"BGM", &"SFX", &"UI", &"Ambient", &"Voice",
	&"Combat SFX", &"Card SFX", &"Explore SFX",
]

var sm: Node = null
var _mock_gsm: Node = null
var _mock_im: Node = null
var _mock_sl: Node = null


func before_each() -> void:
	sm = SM_SCRIPT.new()
	sm._ready()
	sm._test_mode = true
	_mock_gsm = MockFactory.build_gsm()
	_mock_im = MockFactory.build_im()
	_mock_sl = MockFactory.build_sl()
	sm.set_dependencies(_mock_gsm, _mock_im, _mock_sl)
	add_child_autofree(sm)


func after_each() -> void:
	# sm 为 SM_SCRIPT.new() 独立实例（非 Autoload 原身）——显式释放其
	# 持有的 AudioManager 节点池（挂在其 PersistentLayer 子树，级联释放）。
	if sm != null and is_instance_valid(sm):
		sm.free()
	sm = null
	_free_mocks()


## 释放 setup 期构造的三个 mock（孤儿计数归零——hud 测试同款先例）。
func _free_mocks() -> void:
	for m: Node in [_mock_gsm, _mock_im, _mock_sl]:
		if m != null and is_instance_valid(m):
			m.free()
	_mock_gsm = null
	_mock_im = null
	_mock_sl = null


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1：总线结构存在性（按名称断言）
# ═══════════════════════════════════════════════════════════════════════════════

func test_bus_layout_all_nine_buses_exist_by_name() -> void:
	## AC-1: 6 主总线 + 3 SFX 子总线按名称全部存在（索引 != -1）
	# Arrange —— project.godot 自动加载 default_bus_layout.tres
	# Act + Assert
	for bus_name: StringName in ALL_BUS_NAMES:
		var idx: int = AudioServer.get_bus_index(bus_name)
		assert_ne(idx, -1, "总线 '%s' 应存在（get_bus_index != -1）" % bus_name)


func test_bus_layout_default_volumes_match_gdd_table() -> void:
	## AC-1: 6 主总线默认 dB 与 GDD 音量规格表一致（容差 0.01）
	# Arrange + Act + Assert
	for bus_name: StringName in EXPECTED_DB:
		var idx: int = AudioServer.get_bus_index(bus_name)
		assert_ne(idx, -1, "总线 '%s' 应存在" % bus_name)
		if idx == -1:
			continue
		var actual_db: float = AudioServer.get_bus_volume_db(idx)
		assert_almost_eq(actual_db, EXPECTED_DB[bus_name], DB_TOLERANCE,
				"总线 '%s' 默认 dB 应为 %s（实际 %s）" % [bus_name,
				str(EXPECTED_DB[bus_name]), str(actual_db)])


func test_bus_layout_sfx_child_buses_send_to_sfx() -> void:
	## AC-1: 3 SFX 子总线 send 指向 SFX（结构正确性——子总线路由）
	# Arrange + Act + Assert
	for child_name: StringName in [&"Combat SFX", &"Card SFX", &"Explore SFX"]:
		var idx: int = AudioServer.get_bus_index(child_name)
		assert_ne(idx, -1, "子总线 '%s' 应存在" % child_name)
		if idx == -1:
			continue
		assert_eq(AudioServer.get_bus_send(idx), &"SFX",
				"子总线 '%s' 的 send 应指向 SFX" % child_name)


func test_bus_layout_no_duplicate_bus_names() -> void:
	## AC-1 edge: 无重名总线——遍历计数各名称出现次数恰为 1
	# Arrange
	var name_counts: Dictionary = {}
	# Act
	for i: int in AudioServer.bus_count:
		var bus_name: StringName = AudioServer.get_bus_name(i)
		name_counts[bus_name] = name_counts.get(bus_name, 0) + 1
	# Assert
	for bus_name: StringName in ALL_BUS_NAMES:
		assert_eq(name_counts.get(bus_name, 0), 1,
				"总线 '%s' 应恰好出现 1 次（无重名）" % bus_name)


func _find_limiter_ceiling_db(bus_name: StringName) -> float:
	## 辅助——遍历指定总线效果器找 AudioEffectLimiter，返回其 ceiling_db。[br]
	## 未找到时返回 NAN（调用方断言非 NAN）。
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return NAN
	var effect_count: int = AudioServer.get_bus_effect_count(idx)
	for e: int in effect_count:
		var effect: AudioEffect = AudioServer.get_bus_effect(idx, e)
		if effect is AudioEffectLimiter:
			return effect.ceiling_db
	return NAN


func test_bus_layout_master_limiter_ceiling_minus_0_5_db() -> void:
	## AC-1: Master Limiter 存在且 ceiling -0.5dB（防削波——GDD L86）
	# Arrange + Act
	var ceiling: float = _find_limiter_ceiling_db(&"Master")
	# Assert
	assert_false(is_nan(ceiling), "Master 总线应存在 AudioEffectLimiter")
	if not is_nan(ceiling):
		assert_almost_eq(ceiling, -0.5, DB_TOLERANCE,
				"Master Limiter ceiling 应为 -0.5dB（实际 %s）" % str(ceiling))


func test_bus_layout_sfx_limiter_ceiling_minus_1_db() -> void:
	## AC-1: SFX Limiter 存在且 ceiling -1dB（12 SFX 叠加保护——GDD L86）
	# Arrange + Act
	var ceiling: float = _find_limiter_ceiling_db(&"SFX")
	# Assert
	assert_false(is_nan(ceiling), "SFX 总线应存在 AudioEffectLimiter")
	if not is_nan(ceiling):
		assert_almost_eq(ceiling, -1.0, DB_TOLERANCE,
				"SFX Limiter ceiling 应为 -1dB（实际 %s）" % str(ceiling))


func test_bus_layout_ambient_has_reverb_effect() -> void:
	## AC-1: Ambient 总线带 Reverb 效果（可选要求——建议挂上，参数保守默认）
	# Arrange + Act
	var idx: int = AudioServer.get_bus_index(&"Ambient")
	assert_ne(idx, -1, "Ambient 总线应存在")
	var found: bool = false
	if idx >= 0:
		for e: int in AudioServer.get_bus_effect_count(idx):
			if AudioServer.get_bus_effect(idx, e) is AudioEffectReverb:
				found = true
	# Assert
	assert_true(found, "Ambient 总线应存在 AudioEffectReverb 效果器")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-2：PersistentLayer 挂载（ADR-0031 §1.2）
# ═══════════════════════════════════════════════════════════════════════════════

func _audio_manager_of(sm_node: Node) -> RefCounted:
	## 辅助——获取 sm 的 AudioManager（未创建时触发创建）。
	return sm_node.get_audio_manager()


func test_audio_manager_startup_creates_bgm_players_under_persistent_layer() -> void:
	## AC-2: AudioManager 启动实例化 → BGM 双播放器挂入 PersistentLayer
	# Arrange —— before_each 的 sm._ready() 已触发 _get_audio_manager()
	# Act
	var am: RefCounted = _audio_manager_of(sm)
	var layer: Node = sm.get_node_or_null(^"PersistentLayer")
	# Assert
	assert_not_null(layer, "PersistentLayer 应存在")
	assert_not_null(am, "AudioManager 实例应存在")
	var players: Array = am.get_bgm_players()
	assert_eq(players.size(), 2, "节点池应含 2 个 BGM 播放器（bgm_player_a/b）")
	for p: AudioStreamPlayer in players:
		assert_eq(p.get_parent(), layer,
				"BGM 播放器 '%s' 应挂在 PersistentLayer 下" % p.name)
	assert_ne(layer.get_node_or_null(^"bgm_player_a"), null,
			"bgm_player_a 应存在于 PersistentLayer")
	assert_ne(layer.get_node_or_null(^"bgm_player_b"), null,
			"bgm_player_b 应存在于 PersistentLayer")


func test_audio_manager_bgm_players_process_mode_always() -> void:
	## AC-2: 节点池 process_mode == PROCESS_MODE_ALWAYS（ADR-0031 §1.2
	## 音频节点池要求——暂停中不被 SceneTree.paused 冻结）
	# Arrange
	var am: RefCounted = _audio_manager_of(sm)
	# Act + Assert
	for p: AudioStreamPlayer in am.get_bgm_players():
		assert_eq(p.process_mode, Node.PROCESS_MODE_ALWAYS,
				"BGM 播放器 '%s' 的 process_mode 应为 PROCESS_MODE_ALWAYS" % p.name)


func test_audio_manager_bgm_players_bus_routing() -> void:
	## AC-2: BGM 播放器路由到 BGM 总线（按名称——AudioServer 实际解析）
	# Arrange
	var am: RefCounted = _audio_manager_of(sm)
	# Act + Assert
	for p: AudioStreamPlayer in am.get_bgm_players():
		var bus_idx: int = AudioServer.get_bus_index(p.bus)
		assert_ne(bus_idx, -1, "BGM 播放器 bus '%s' 应在 AudioServer 中存在" % p.bus)
		assert_eq(p.bus, &"BGM", "BGM 播放器 bus 应为 \"BGM\"（按名称路由）")


func test_audio_manager_node_pool_survives_scene_transition() -> void:
	## AC-2 edge: 模拟场景切换后节点池仍存在（不随场景卸载）。[br]
	## [b]覆盖边界[/b]：test_mode 下 Phase 3-5 被跳过（scene_manager.gd
	## [code]if not _test_mode: _execute_transition()[/code]）——本测试只验证
	## [b]请求管线接受转场后节点池不变[/b]；真实 [code]change_scene_to_file[/code]
	## 卸载路径由 [method test_audio_manager_node_pool_survives_real_transition]
	## 覆盖（hud epic 同款双测试先例——test_hud_scene_visibility.gd）。[br]
	## PersistentLayer 挂为 SceneManager 子节点，Autoload 子树不经
	## current_scene 释放（先例：test_hud_scene_visibility.gd 转场存活测试）。
	# Arrange —— 节点池已挂载；记录引用
	var player_a: AudioStreamPlayer = \
			sm.get_node_or_null(^"PersistentLayer/bgm_player_a")
	assert_not_null(player_a, "前置：bgm_player_a 已挂载")
	# Act —— 经完整转场请求管线（MAIN_MENU → EXPLORATION）
	var ok: bool = sm.request_scene_change(
			SM_SCRIPT.SceneID.MAIN_MENU, SM_SCRIPT.SceneID.EXPLORATION,
			SM_SCRIPT.TransitionType.MENU_TO_GAME)
	# Assert
	assert_true(ok, "转场请求应被接受")
	assert_true(is_instance_valid(player_a), "转场后 bgm_player_a 仍存活")
	assert_eq(player_a.get_parent(), sm.get_node_or_null(^"PersistentLayer"),
			"转场后 bgm_player_a 仍挂在 PersistentLayer 下")


func test_audio_manager_node_pool_survives_real_transition() -> void:
	## AC-2 edge（code-review B-1 修复）：真实 change_scene_to_file 转场存活。[br]
	## test_mode 会跳过 Phase 3 的 change_scene_to_file——本测试关闭 test_mode，
	## 以真实存在的 loading_screen.tscn 为目标执行完整异步管线，验证节点池
	## 不随 current_scene 卸载（ADR-0031 §1.2 挂载契约的引擎行为本身）。[br]
	## 先例：test_hud_scene_visibility.gd 的
	## test_persistent_layer_survives_real_change_scene_to_file。
	# Arrange —— 独立实例（不复用 before_each 的 test_mode sm）
	var real_sm: Node = SM_SCRIPT.new()
	real_sm._ready()
	real_sm._test_mode = false
	var local_gsm: Node = MockFactory.build_gsm()
	var local_im: Node = MockFactory.build_im()
	var local_sl: Node = MockFactory.build_sl()
	real_sm.set_dependencies(local_gsm, local_im, local_sl)
	add_child_autofree(real_sm)
	var player_a: AudioStreamPlayer = \
			real_sm.get_node_or_null(^"PersistentLayer/bgm_player_a")
	assert_not_null(player_a, "前置：bgm_player_a 已挂载")
	# Act —— 真实转场（MAIN_MENU → LOADING 场景，目标 .tscn 确认存在）
	var ok: bool = real_sm.request_scene_change(
			SM_SCRIPT.SceneID.MAIN_MENU, SM_SCRIPT.SceneID.LOADING,
			SM_SCRIPT.TransitionType.MENU_TO_GAME)
	assert_true(ok, "真实转场请求应被接受")
	# Phase 3 await tree_changed + 场景实例化需要数帧完成——轮询至转场结束或超时
	var waited: int = 0
	while real_sm.is_transitioning() and waited < 60:
		await get_tree().process_frame
		waited += 1
	# Assert
	assert_false(real_sm.is_transitioning(),
			"转场应在帧预算内完成（等待 %d 帧）" % waited)
	assert_true(is_instance_valid(player_a), "真实转场后 bgm_player_a 仍存活")
	assert_eq(player_a.get_parent(),
			real_sm.get_node_or_null(^"PersistentLayer"),
			"真实转场后 bgm_player_a 仍挂在 PersistentLayer 下")
	# 清理——mock 不在 sm 子树内，须显式释放（hud 先例同款）
	local_gsm.free()
	local_im.free()
	local_sl.free()


func test_audio_manager_refcounted_not_node() -> void:
	## AC（story 规格）：AudioManager 为 RefCounted 控制类——自身非节点
	## （节点池挂 PersistentLayer，控制类由 SceneManager 持有引用）
	# Arrange + Act —— Variant 弱类型持有（静态 RefCounted 类型下
	# `is Node` 会被解析器判定恒假而报错，须经 Variant 才能运行时检查）
	var am: Variant = _audio_manager_of(sm)
	# Assert —— Variant `is` 运行时类型检查：
	# RefCounted 实例 is Node 应为 false
	assert_false(am is Node, "AudioManager 应为 RefCounted（非 Node）")


func test_scene_manager_set_audio_manager_injects_instance() -> void:
	## QA GAP-2：set_audio_manager 注入口零覆盖（死代码风险）——注入 mock
	## 实例后 get_audio_manager 应返回同一实例（测试注入口契约）。
	# Arrange —— 可用 adapter 的真实实例作替身（无须 mock 全部 11 API）
	var injected: AudioManager = AM_SCRIPT.new(null)
	# Act
	sm.set_audio_manager(injected)
	# Assert
	assert_eq(sm.get_audio_manager(), injected,
			"set_audio_manager 注入后 get_audio_manager 应返回同一实例")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-3：静默模式（边缘 #14）
# ═══════════════════════════════════════════════════════════════════════════════

func _build_silent_audio_manager() -> RefCounted:
	## 辅助——注入 unavailable adapter 的 AudioManager（模拟 AudioServer 不可用）。
	var adapter: AudioServerAdapter = ADAPTER_SCRIPT.new()
	adapter.unavailable = true
	return AM_SCRIPT.new(null, adapter)


func test_silent_mode_all_eleven_apis_noop_no_crash() -> void:
	## AC-3: 注入不可用 adapter → 调用全部 11 个 API → 不崩溃（no-op）
	# Arrange
	var am: RefCounted = _build_silent_audio_manager()
	# Act —— 11 个 API 全调用（含带参/默认参变体）
	am.play_sfx(&"test_sfx")
	am.play_bgm(&"test_bgm")
	am.stop_bgm()
	am.pause_all()
	am.resume_all()
	am.play_ambient(&"test_ambient")
	am.stop_ambient()
	am.set_bus_volume(AudioEnums.AudioBus.BGM, -12.0)
	var _vol: float = am.get_bus_volume(AudioEnums.AudioBus.BGM)
	am.toggle_mute()
	am.set_state(AudioEnums.AudioState.IN_COMBAT)
	# Assert —— 到达此处即未崩溃（GUT 失败以异常/断言失败呈现）
	assert_true(true, "全部 11 个 API 调用完成——静默模式不崩溃")
	# get_bus_volume 静默模式返回无害默认 0.0
	assert_almost_eq(_vol, 0.0, DB_TOLERANCE,
			"静默模式 get_bus_volume 应返回无害默认 0.0")


func test_silent_mode_logs_exactly_once_for_repeated_calls() -> void:
	## AC-3: 日志只记一次——首次 no-op push_warning，后续调用静默
	## （adapter._silent_logged 一次性标志）
	# Arrange
	var am: RefCounted = _build_silent_audio_manager()
	# Act —— 同一 adapter 上多次调用（触发 _noop_guard 多次）
	am.set_bus_volume(AudioEnums.AudioBus.MASTER, -6.0)
	am.set_bus_volume(AudioEnums.AudioBus.SFX, -12.0)
	am.toggle_mute()
	am.toggle_mute()
	var _v1: float = am.get_bus_volume(AudioEnums.AudioBus.UI)
	var _v2: float = am.get_bus_volume(AudioEnums.AudioBus.VOICE)
	# Assert
	assert_push_warning_count(1, "静默模式 5 次调用应只 push_warning 1 次")


func test_silent_mode_adapter_noop_returns_harmless_defaults() -> void:
	## AC-3 edge: 不可用 adapter 的返回值语义——get_bus_index -1 / volume 0.0 /
	## mute false（调用方无须判空的防御性契约）
	# Arrange
	var adapter: AudioServerAdapter = ADAPTER_SCRIPT.new()
	adapter.unavailable = true
	# Act + Assert
	assert_eq(adapter.get_bus_index(AudioEnums.AudioBus.MASTER), -1,
			"不可用时 get_bus_index 应返回 -1")
	assert_almost_eq(adapter.get_bus_volume_db(AudioEnums.AudioBus.BGM), 0.0,
			DB_TOLERANCE, "不可用时 get_bus_volume_db 应返回 0.0")
	assert_false(adapter.is_bus_muted(AudioEnums.AudioBus.SFX),
			"不可用时 is_bus_muted 应返回 false")
	# no-op set 调用不崩溃
	adapter.set_bus_volume_db(AudioEnums.AudioBus.MASTER, -80.0)
	adapter.set_bus_mute(AudioEnums.AudioBus.MASTER, true)
	assert_true(true, "set 类 no-op 调用完成——不崩溃")


func test_available_adapter_routes_to_real_audio_server() -> void:
	## AC-3 edge: 恢复可用后 API 正常——真实 adapter 走真（headless GUT 下
	## AudioServer 可用，project.godot 已加载总线布局，可按名称读写）[br]
	## 测试隔离：只动 UI 总线音量并恢复原值（不污染其他测试的默认 dB 断言）。
	# Arrange
	var adapter: AudioServerAdapter = ADAPTER_SCRIPT.new()
	assert_true(adapter.detect_availability(), "前置：真实 AudioServer 可用")
	var original_db: float = adapter.get_bus_volume_db(AudioEnums.AudioBus.UI)
	# Act
	adapter.set_bus_volume_db(AudioEnums.AudioBus.UI, -15.0)
	var read_back: float = adapter.get_bus_volume_db(AudioEnums.AudioBus.UI)
	adapter.set_bus_volume_db(AudioEnums.AudioBus.UI, original_db)
	# Assert
	assert_almost_eq(read_back, -15.0, DB_TOLERANCE,
			"可用 adapter set 后 get 应读回 -15.0dB")
	assert_almost_eq(adapter.get_bus_volume_db(AudioEnums.AudioBus.UI),
			original_db, DB_TOLERANCE, "清理：UI 总线音量已恢复原值")


func test_audio_manager_toggle_mute_routes_to_master_bus() -> void:
	## 走真路径补充：toggle_mute 经 adapter 操作 Master 总线（AC-MUTE-01 语义
	## ——Master -80dB ↔ 恢复快照）。测试隔离：结束时恢复 Master 原值。
	# Arrange
	var am: RefCounted = AM_SCRIPT.new(null)
	var original_db: float = am.get_bus_volume(AudioEnums.AudioBus.MASTER)
	# Act —— 静音
	am.toggle_mute()
	var muted_db: float = am.get_bus_volume(AudioEnums.AudioBus.MASTER)
	# Assert（静音态）
	assert_almost_eq(muted_db, -80.0, DB_TOLERANCE,
			"toggle_mute 后 Master 应为 -80dB")
	# Act —— 取消静音
	am.toggle_mute()
	var restored_db: float = am.get_bus_volume(AudioEnums.AudioBus.MASTER)
	# Assert（恢复态）+ 清理
	assert_almost_eq(restored_db, original_db, DB_TOLERANCE,
			"再次 toggle_mute 应恢复 Master 原值")
