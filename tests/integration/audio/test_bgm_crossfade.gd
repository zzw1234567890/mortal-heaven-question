extends GutTest
## audio-manager Story 002 集成测试：BGM 双播放器交叉淡化（AC-6）。
##
## QA 规格：真实交叉淡化（时长缩至 0.05s + await）——终值 volume_db 与
## playing 状态正确；中途二次切换从当前 dB 继续；损坏文件路径→旧曲继续。
##
## Story 类型 Logic——此文件为 BLOCKING 证据。
## 风格先例：tests/integration/audio/test_bus_layout.gd。

const AudioManagerScript := preload("res://src/ui/audio/audio_manager.gd")
const Planner := preload("res://src/ui/audio/bgm_fade_planner.gd")
const SM_SCRIPT := preload("res://src/foundation/scene_manager.gd")
const MockFactory := preload("res://tests/integration/scene_manager/mocks/mock_factory.gd")

## 缩放后的过渡时长（QA 规格：真实过渡缩至 0.05s + await）。
const FADE_SEC: float = 0.05

var manager: AudioManager = null
var sm: Node = null
var _mock_gsm: Node = null
var _mock_im: Node = null
var _mock_sl: Node = null


func before_each() -> void:
	# 真实 SceneManager（_test_mode）——AudioManager 构造经其
	# register_persistent 挂载节点池（ADR-0031 §1.2 定死结构），
	# create_tween 经 sm（场景树节点）可用
	sm = SM_SCRIPT.new()
	sm._ready()
	sm._test_mode = true
	_mock_gsm = MockFactory.build_gsm()
	_mock_im = MockFactory.build_im()
	_mock_sl = MockFactory.build_sl()
	sm.set_dependencies(_mock_gsm, _mock_im, _mock_sl)
	add_child_autofree(sm)
	manager = AudioManagerScript.new(sm)
	# 注入静音 WAV 流对象（程序生成——真实播放无须音频设备判定；
	# 对象注入免落盘导入周期，headless GUT 直用）
	_stream_override(&"bgm_a")
	_stream_override(&"bgm_b")
	_stream_override(&"bgm_c")


## 注入静音 AudioStreamWAV 流对象（1.0s @ 24kHz 单声道——全零静音；时长须
## 覆盖全部等待窗口，否则流先于断言播完导致 playing=false）。
func _stream_override(bgm_id: StringName) -> void:
	var data: PackedByteArray = PackedByteArray()
	data.resize(48000)
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 24000
	wav.stereo = false
	manager._stream_overrides[bgm_id] = wav


func after_each() -> void:
	# sm 为独立实例（非 Autoload 原身）——显式释放（级联释放其
	# PersistentLayer 子树与 AudioManager 节点池）
	if sm != null and is_instance_valid(sm):
		sm.free()
	sm = null
	_free_mocks()


## 取当前播放侧/目标侧播放器（轮换语义——执行层 a/b 按
## _current_player_index 映射物理播放器，测试同源取用）。
func _cur(players: Array[AudioStreamPlayer]) -> AudioStreamPlayer:
	return players[manager._current_player_index]


func _nxt(players: Array[AudioStreamPlayer]) -> AudioStreamPlayer:
	return players[1 - manager._current_player_index]


# ═══════════════════════════════════════════════════════════════════════════════
# AC-6：真实交叉淡化（终值 + playing 状态）
# ═══════════════════════════════════════════════════════════════════════════════

func test_crossfade_final_db_and_playing_state() -> void:
	# Given: bgm_a 播放中 0dB（当前侧 = 轮换后的物理侧）
	manager.play_bgm(&"bgm_a", {"fade_in_sec": FADE_SEC})
	var players: Array[AudioStreamPlayer] = manager.get_bgm_players()
	var cur_a: AudioStreamPlayer = _cur(players)
	await sm.get_tree().create_timer(FADE_SEC * 3.0).timeout
	assert_true(cur_a.playing, "前置：a 播放中")
	# Act: 切 bgm_b（平行交叉淡化 0.05s/0.05s）
	manager.play_bgm(&"bgm_b",
		{"fade_out_sec": FADE_SEC, "fade_in_sec": FADE_SEC})
	await sm.get_tree().create_timer(FADE_SEC * 4.0).timeout
	# Then: 终值 volume_db 与 playing 状态正确（旧侧淡出 / 新侧播放）
	assert_almost_eq(cur_a.volume_db, Planner.SILENCE_DB, 1.0,
		"a 应淡出到静音")
	assert_almost_eq(_cur(players).volume_db, Planner.NORMAL_DB, 1.0,
		"b 应淡入到 0dB（切曲后成为当前侧）")
	assert_false(cur_a.playing, "a 到达静音后应停止")
	assert_true(_cur(players).playing, "b 应播放中")


func test_mid_transition_second_switch_continues_from_current_db() -> void:
	# Given: bgm_b 淡入进行中（0.05s——中途约一半处打断）
	manager.play_bgm(&"bgm_b", {"fade_in_sec": FADE_SEC})
	var players: Array[AudioStreamPlayer] = manager.get_bgm_players()
	var b_player: AudioStreamPlayer = _cur(players)
	# Act: 中途二次切换 bgm_c（b 未达 0dB 时打断）
	await sm.get_tree().create_timer(FADE_SEC * 0.5).timeout
	var b_db_at_interrupt: float = b_player.volume_db
	manager.play_bgm(&"bgm_c",
		{"fade_out_sec": FADE_SEC, "fade_in_sec": FADE_SEC})
	await sm.get_tree().create_timer(FADE_SEC * 4.0).timeout
	# Then: c 完成淡入（从中断时刻 b 的实际 dB 续接——AC-BGM-10）
	assert_almost_eq(_cur(players).volume_db, Planner.NORMAL_DB, 1.0,
		"c 应从中断点续接到 0dB（中断时 b=%0.1f）" % b_db_at_interrupt)
	assert_true(_cur(players).playing, "c 应播放中")


func test_corrupt_stream_keeps_previous_bgm() -> void:
	# Given: bgm_a 播放中
	manager.play_bgm(&"bgm_a", {"fade_in_sec": FADE_SEC})
	var players: Array[AudioStreamPlayer] = manager.get_bgm_players()
	await sm.get_tree().create_timer(FADE_SEC * 3.0).timeout
	var a_player: AudioStreamPlayer = _cur(players)
	assert_true(a_player.playing, "前置：a 播放中")
	# Act: 请求损坏路径的 bgm_broken（边缘 #1）
	manager._stream_path_overrides[&"bgm_broken"] = "res://.gut_tmp_nonexistent_bgm.wav"
	manager.play_bgm(&"bgm_broken",
		{"fade_out_sec": FADE_SEC, "fade_in_sec": FADE_SEC})
	await sm.get_tree().create_timer(FADE_SEC * 3.0).timeout
	# Then: 不崩溃 + 旧曲继续播放（流解析失败 → 目标侧不启动 → 不翻转当前侧）
	assert_true(a_player.playing, "损坏文件应保留旧曲继续播放")
	assert_false(_nxt(players).playing, "目标播放器不应启动")


func test_same_id_request_no_restart() -> void:
	# Given: bgm_a 播放中（AC-BGM-09——同 id 忽略）
	manager.play_bgm(&"bgm_a", {"fade_in_sec": FADE_SEC})
	var players: Array[AudioStreamPlayer] = manager.get_bgm_players()
	await sm.get_tree().create_timer(FADE_SEC * 3.0).timeout
	var a_player: AudioStreamPlayer = _cur(players)
	var play_pos: float = a_player.get_playback_position()
	# Act: 同 id 重复请求
	manager.play_bgm(&"bgm_a")
	await sm.get_tree().create_timer(FADE_SEC * 2.0).timeout
	# Then: 不重启（播放持续——无新过渡）
	assert_true(a_player.playing, "同 id 请求应忽略（继续播放）")
	assert_almost_eq(a_player.volume_db, Planner.NORMAL_DB, 0.001,
		"音量应保持 0dB（无重淡入）")


func test_stop_bgm_fades_out_and_stops() -> void:
	# Given: bgm_a 播放中
	manager.play_bgm(&"bgm_a", {"fade_in_sec": FADE_SEC})
	var players: Array[AudioStreamPlayer] = manager.get_bgm_players()
	await sm.get_tree().create_timer(FADE_SEC * 3.0).timeout
	var a_player: AudioStreamPlayer = _cur(players)
	# Act: stop_bgm
	manager.stop_bgm({"fade_out_sec": FADE_SEC})
	await sm.get_tree().create_timer(FADE_SEC * 4.0).timeout
	# Then: 淡出完成 + 停止
	assert_almost_eq(a_player.volume_db, Planner.SILENCE_DB, 1.0,
		"应淡出到静音")
	assert_false(a_player.playing, "停止后 playing 应为 false")


func _free_mocks() -> void:
	for m: Node in [_mock_gsm, _mock_im, _mock_sl]:
		if m != null and is_instance_valid(m):
			m.free()
	_mock_gsm = null
	_mock_im = null
	_mock_sl = null
