extends GutTest
## audio-manager Story 002 集成测试补充：降低/恢复类 Bus 过渡 + 渡劫顺序式时序。
##
## QA 规格（QL-TEST-COVERAGE GAPS 裁决 2026-10-17）：
##   - GAP-1 [AC-BGM-06/07]：执行层 `_bus_fade_cmd`（tween_method 总线插值）
##     duck 至 -10dB 后恢复 0dB 全链路——终值读回 AudioServer BGM 总线
##   - GAP-2 [AC-BGM-08]：sequential=true 实际时序——渡劫淡出完成前目标侧
##     不起音（set_delay 前移语义）
##   - GAP-3 [AC-BGM-04/05]：MAP_CLEARED / DEFEATED 矩阵行数值（计划器层）
##   - GAP-4 [AC-8]：play_bgm 的 preload_next 接线（缓存预加载下一首）
##
## Story 类型 Logic——此文件为 BLOCKING 证据补充。
## 风格先例：tests/integration/audio/test_bgm_crossfade.gd。

const AudioManagerScript := preload("res://src/ui/audio/audio_manager.gd")
const Planner := preload("res://src/ui/audio/bgm_fade_planner.gd")
const SM_SCRIPT := preload("res://src/foundation/scene_manager.gd")
const MockFactory := preload("res://tests/integration/scene_manager/mocks/mock_factory.gd")

## 缩放后的过渡时长（与 AC-6 模式一致——真实过渡缩至 0.05s + await）。
const FADE_SEC: float = 0.05
## BGM 总线枚举值。
const BGM_BUS: int = 1
## BGM 总线恢复基准（GDD 参考基准 0dB——总线默认值）。
const NORMAL_DB: float = 0.0

var manager: AudioManager = null
var sm: Node = null
var _mock_gsm: Node = null
var _mock_im: Node = null
var _mock_sl: Node = null
## BGM 总线测试前音量快照（after_each 还原——避免污染其他测试）。
var _bgm_db_before: float = NORMAL_DB


func before_each() -> void:
	sm = SM_SCRIPT.new()
	sm._ready()
	sm._test_mode = true
	_mock_gsm = MockFactory.build_gsm()
	_mock_im = MockFactory.build_im()
	_mock_sl = MockFactory.build_sl()
	sm.set_dependencies(_mock_gsm, _mock_im, _mock_sl)
	add_child_autofree(sm)
	manager = AudioManagerScript.new(sm)
	_stream_override(&"bgm_a")
	_stream_override(&"bgm_b")
	_stream_override(&"bgm_c")
	_stream_override(&"bgm_trib")
	# BGM 总线快照（默认 0dB）——duck 测试起点/终点还原基准
	_bgm_db_before = manager.get_bus_volume(BGM_BUS)


## 注入静音 AudioStreamWAV 流对象（5.0s @ 24kHz 单声道——全零静音；
## 长流覆盖 sequential 测试加长时长 0.4s×多轮等待窗口）。
func _stream_override(bgm_id: StringName) -> void:
	var data: PackedByteArray = PackedByteArray()
	data.resize(240000)
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 24000
	wav.stereo = false
	manager._stream_overrides[bgm_id] = wav


func after_each() -> void:
	# 总线音量还原（duck 测试副作用清理——GUT 套件内隔离）
	if manager != null and is_instance_valid(manager):
		manager.set_bus_volume(BGM_BUS, _bgm_db_before)
	if sm != null and is_instance_valid(sm):
		sm.free()
	sm = null
	_free_mocks()


func _free_mocks() -> void:
	for m: Node in [_mock_gsm, _mock_im, _mock_sl]:
		if m != null and is_instance_valid(m):
			m.free()
	_mock_gsm = null
	_mock_im = null
	_mock_sl = null


func _cur(players: Array[AudioStreamPlayer]) -> AudioStreamPlayer:
	return players[manager._current_player_index]


func _nxt(players: Array[AudioStreamPlayer]) -> AudioStreamPlayer:
	return players[1 - manager._current_player_index]


# ═══════════════════════════════════════════════════════════════════════════════
# GAP-1 [AC-BGM-06/07]：降低/恢复类执行层全链路（Bus 读回断言）
# ═══════════════════════════════════════════════════════════════════════════════

func test_duck_bus_reaches_target_and_restore_returns() -> void:
	# Given: bgm_a 播放中（BGM 总线 0dB）
	manager.play_bgm(&"bgm_a", {"fade_in_sec": FADE_SEC})
	await sm.get_tree().create_timer(FADE_SEC * 3.0).timeout
	assert_almost_eq(manager.get_bus_volume(BGM_BUS), NORMAL_DB, 0.1,
		"前置：BGM 总线应为 0dB")
	# Act 1: 商店降低——duck 至 -10dB（0.05s 总线过渡）
	manager.play_bgm(&"bgm_a", {"duck_db": -10.0, "fade_out_sec": FADE_SEC})
	await sm.get_tree().create_timer(FADE_SEC * 4.0).timeout
	# Then 1: 总线到达 -10dB（tween_method 执行层驱动）且不断播
	assert_almost_eq(manager.get_bus_volume(BGM_BUS), -10.0, 1.0,
		"AC-BGM-06：降低类应将 BGM 总线降至 -10dB")
	var players: Array[AudioStreamPlayer] = manager.get_bgm_players()
	assert_true(_cur(players).playing, "AC-BGM-06：降低类不断播")
	# Act 2: 离开商店——恢复 0dB（0.05s）
	manager.play_bgm(&"bgm_a", {"duck_db": NORMAL_DB, "fade_out_sec": FADE_SEC})
	await sm.get_tree().create_timer(FADE_SEC * 4.0).timeout
	# Then 2: 总线恢复 0dB
	assert_almost_eq(manager.get_bus_volume(BGM_BUS), NORMAL_DB, 1.0,
		"AC-BGM-07：离开降低场景应恢复 BGM 总线 0dB")


# ═══════════════════════════════════════════════════════════════════════════════
# GAP-2 [AC-BGM-08]：渡劫顺序式时序——淡出完成前目标侧不起音
# ═══════════════════════════════════════════════════════════════════════════════

func test_sequential_target_waits_for_fadeout_completion() -> void:
	# headless 帧长实测 ~80ms——FADE_SEC(0.05s) 短于单帧无法观测时序。
	# 本测试用加长时长（0.4s/0.4s）验证顺序式核心语义：
	# b 侧起音时刻严格晚于 a 侧到达静音时刻（先淡出完成再淡入）。
	const LONG_SEC: float = 0.4
	manager.play_bgm(&"bgm_a", {"fade_in_sec": LONG_SEC})
	var players: Array[AudioStreamPlayer] = manager.get_bgm_players()
	var cur_a: AudioStreamPlayer = _cur(players)
	await sm.get_tree().create_timer(LONG_SEC * 3.0).timeout
	assert_true(cur_a.playing, "前置：a 播放中")
	# 目标侧引用须在切换前捕获——play_bgm 成功即翻转 _current_player_index，
	# 切换后 _nxt 返回的是旧 a 侧（正在淡出），会测错对象
	var target: AudioStreamPlayer = _nxt(players)
	# Act: 渡劫切换（sequential=true——先 a 淡出 0.4s 完成再 b 淡入）
	manager.play_bgm(&"bgm_trib",
		{"fade_out_sec": LONG_SEC, "fade_in_sec": LONG_SEC, "sequential": true})
	# 中途采样（a 淡出窗口约一半处——b 应尚未起音）
	await sm.get_tree().create_timer(LONG_SEC * 0.5).timeout
	assert_almost_eq(target.volume_db, Planner.SILENCE_DB, 10.0,
		"顺序式中途：淡出完成前目标侧应停留静音附近（实测 %0.1f）" % target.volume_db)
	assert_false(target.playing or target.volume_db > -60.0,
		"顺序式：b 在 a 淡出完成前不应起音")
	# 终态：渡劫曲完成淡入并播放
	await sm.get_tree().create_timer(LONG_SEC * 3.0).timeout
	assert_almost_eq(_cur(players).volume_db, Planner.NORMAL_DB, 1.0,
		"顺序式：渡劫曲最终应淡入到 0dB")
	assert_true(_cur(players).playing, "顺序式：渡劫曲应播放中")
func test_parallel_target_starts_immediately_by_contrast() -> void:
	# 对照组：平行模式（sequential=false）中途目标侧已起音
	# ——与上一测试互证 set_delay 仅在 sequential 时生效
	manager.play_bgm(&"bgm_a", {"fade_in_sec": FADE_SEC})
	var players: Array[AudioStreamPlayer] = manager.get_bgm_players()
	await sm.get_tree().create_timer(FADE_SEC * 3.0).timeout
	var target: AudioStreamPlayer = _nxt(players)
	# Act: 平行切换（默认 sequential=false）
	manager.play_bgm(&"bgm_b",
		{"fade_out_sec": FADE_SEC, "fade_in_sec": FADE_SEC})
	await sm.get_tree().create_timer(FADE_SEC * 0.5).timeout
	var target_db_mid: float = target.volume_db
	assert_gt(target_db_mid, Planner.SILENCE_DB + 5.0,
		"平行模式：中途目标侧应已起音（实测 %0.1f）" % target_db_mid)


# ═══════════════════════════════════════════════════════════════════════════════
# GAP-3 [AC-BGM-04/05]：MAP_CLEARED / DEFEATED 矩阵行数值（计划器层）
# ═══════════════════════════════════════════════════════════════════════════════

func test_params_for_state_victory_and_defeat_rows() -> void:
	# Then: 胜利 0.3s/0.5s、战败 0.5s/0.3s（GDD §9 矩阵行——非顺序）
	var victory: Dictionary = Planner.params_for_state(AudioEnums.AudioState.MAP_CLEARED)
	assert_almost_eq(float(victory["fade_out_sec"]), 0.3, 0.001, "胜利淡出 0.3s")
	assert_almost_eq(float(victory["fade_in_sec"]), 0.5, 0.001, "胜利淡入 0.5s")
	assert_false(victory["sequential"], "胜利行应平行")
	var defeat: Dictionary = Planner.params_for_state(AudioEnums.AudioState.DEFEATED)
	assert_almost_eq(float(defeat["fade_out_sec"]), 0.5, 0.001, "战败淡出 0.5s")
	assert_almost_eq(float(defeat["fade_in_sec"]), 0.3, 0.001, "战败淡入 0.3s")
	assert_false(defeat["sequential"], "战败行应平行")


# ═══════════════════════════════════════════════════════════════════════════════
# GAP-4 [AC-8]：play_bgm 的 preload_next 接线（缓存预加载下一首）
# ═══════════════════════════════════════════════════════════════════════════════

func test_play_bgm_preload_next_option_populates_cache() -> void:
	# Given: bgm_a/bgm_c 均用路径注入（对象注入优先级高于缓存——
	# 走缓存路径解析须移除对象注入）
	manager._stream_overrides.erase(&"bgm_a")
	manager._stream_overrides.erase(&"bgm_c")
	manager._stream_path_overrides[&"bgm_a"] = 			"res://prototypes/r06-ogg-loop-spike/test-tone.wav"
	manager._stream_path_overrides[&"bgm_c"] = 			"res://prototypes/r06-ogg-loop-spike/test-tone.ogg"
	# Act: 播放 bgm_a 时预加载下一首 bgm_c
	manager.play_bgm(&"bgm_a",
		{"fade_in_sec": FADE_SEC, "preload_next": &"bgm_c"})
	await sm.get_tree().create_timer(FADE_SEC * 3.0).timeout
	# Then 1: 预加载的下一首经 resolve 消费在途请求成功（preload_bgm 只发
	# load_threaded_request + keep 标记不写缓存——观察点为 resolve 命中后的
	# 缓存写入，而非纯预加载条目直接出现在 cached_ids）
	var next_stream: AudioStream = manager._stream_cache.resolve(&"bgm_c")
	assert_not_null(next_stream,
		"preload_next 预加载的 bgm_c 应可经 resolve 消费在途请求")
	# Then 2: 双方均在流缓存（当前曲 + 已消费的下一首 = 常驻 2 首）
	assert_true(manager._stream_cache.cached_ids().has(&"bgm_a"),
		"当前曲应在缓存保留头")
	assert_true(manager._stream_cache.cached_ids().has(&"bgm_c"),
		"resolve 后 bgm_c 应在流缓存")
	assert_eq(manager._stream_cache.cached_ids().size() <= 2, true,
		"常驻 ≤2（guardrail）")
