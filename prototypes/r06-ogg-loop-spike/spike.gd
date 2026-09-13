extends SceneTree
## R-06 Ogg Vorbis 循环间隙 spike harness——录制回放输出，PCM 层量化循环间隙。
##
## 用法（窗口模式——需真实音频驱动，headless Dummy 驱动不推进混音）：
##   Godot_v4.6.3-stable_win64.exe --path . \
##     --script prototypes/r06-ogg-loop-spike/spike.gd
##
## 方法论：
##   AudioEffectRecord 挂 Master 总线（Godot 混音器内部、OS 音效之前），
##   录制循环播放的实际输出 PCM。测试音为 440Hz 整数周期正弦（880 周期
##   @ 2.0s / 44100Hz）——循环正确时输出是相位连续的无限正弦，
##   无任何静音；循环间隙在 PCM 上表现为静音段（间隙）或相位跳变（咔哒声）。
##   直接扫描录制 PCM 量化之——这是「可听见间隙」的权威测量
##   （headless get_playback_position() 采样已证实不可靠——Dummy 驱动不实时混音）。
##
## 验证项（对应风险登记册 R-06 待办）：
##   V1  AudioStreamOggVorbis.loop = true 时 finished 信号不触发（GDD 前提）
##   V2  Ogg 循环间隙量化——最长静音段 ms（GDD 接受线 30ms）
##   V3  WAV loop_begin/loop_end 样本级循环对照——间隙应 ≈ 0
##   V4  Ogg vs WAV 间隙差值（格式裁决依据）
##   V5  相位跳变（click）计数——间隙之外的第二种循环瑕疵形态
##   V6  真实音频驱动生效（非 Dummy）

const OUTPUT_PATH: String = "res://prototypes/r06-ogg-loop-spike/results.json"
const OGG_PATH: String = "res://prototypes/r06-ogg-loop-spike/test-tone.ogg"
const WAV_PATH: String = "res://prototypes/r06-ogg-loop-spike/test-tone.wav"
const RECORD_SEC: float = 6.5   # 每阶段录制时长（覆盖 2s 音色 × 3 次循环）
const PLAYER_VOLUME_DB: float = -18.0  # 可听但不过响
const SILENCE_RATIO: float = 0.02      # 静音判定：|幅度| < 峰值 × 2%
const SILENCE_MIN_MS: float = 2.0      # 记录的最短静音段（<2ms 视为正常过零附近）
const CLICK_RATIO: float = 0.25        # 跳变判定：帧间 |Δ| > 峰值 × 25%（正弦
                                       # 理论最大帧间 Δ ≈ 峰值 × 6.3%）

var _results: Dictionary = {}
var _phase: String = ""          # "" | "ogg" | "wav" | "done"
var _player: AudioStreamPlayer = null
var _recorder: AudioEffectRecord = null
var _elapsed: float = 0.0
var _finished_fired: bool = false
var _loop_count: int = 0
var _last_pos: float = -1.0

func _init() -> void:
	_results = {"godot_version": Engine.get_version_info().string}
	_results["audio_driver"] = AudioServer.get_driver_name()
	# 录制效果挂 Master 总线（索引 0）
	_recorder = AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, _recorder)

func _process(delta: float) -> bool:
	if _phase == "":
		_start_phase("ogg")
		return false
	if _phase == "done":
		return true
	_elapsed += delta
	if _frame_dbg() % 60 == 0:
		print("R06-DBG phase=%s elapsed=%.2f playing=%s" % [_phase, _elapsed, _player.playing])
	if _phase != "" and _phase != "done":
		_track_loops()
	if _elapsed >= RECORD_SEC:
		print("R06-DBG end phase %s" % _phase)
		return _end_phase()
	return false

var _dbg_count: int = 0

func _frame_dbg() -> int:
	_dbg_count += 1
	return _dbg_count

func _track_loops() -> void:
	# V1 辅助：循环回绕计数 + finished 信号监测
	var pos: float = _player.get_playback_position()
	if _last_pos >= 0.0 and pos < _last_pos:
		_loop_count += 1
	_last_pos = pos

func _start_phase(next: String) -> void:
	_phase = next
	_elapsed = 0.0
	_finished_fired = false
	_loop_count = 0
	_last_pos = -1.0
	if _player != null:
		_player.queue_free()
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	_player.volume_db = PLAYER_VOLUME_DB
	if next == "ogg":
		var stream: AudioStreamOggVorbis = load(OGG_PATH)
		stream.loop = true
		_player.stream = stream
	else:
		var wav: AudioStreamWAV = load(WAV_PATH)
		var channels: int = 2 if wav.stereo else 1
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = wav.data.size() / (2 * channels)  # 16-bit 帧数
		_player.stream = wav
	_player.finished.connect(func() -> void: _finished_fired = true)
	root.add_child(_player)
	_player.play()
	_recorder.set_recording_active(true)

func _end_phase() -> bool:
	print("R06-DBG %s: stopping recorder" % _phase)
	_recorder.set_recording_active(false)
	print("R06-DBG %s: getting recording" % _phase)
	var rec: AudioStreamWAV = _recorder.get_recording()
	print("R06-DBG %s: analyzing pcm" % _phase)
	var analysis: Dictionary = _analyze_pcm(rec)
	print("R06-DBG %s: analysis done %s" % [_phase, JSON.stringify(analysis)])
	_results["%s_started" % _phase] = _player.playing
	_results["%s_loop_count" % _phase] = _loop_count
	_results["%s_finished_fired" % _phase] = _finished_fired
	_results["%s_recorded_sec" % _phase] = analysis.get("recorded_sec", 0.0)
	_results["%s_peak" % _phase] = analysis.get("peak", 0.0)
	_results["%s_max_silence_ms" % _phase] = analysis.get("max_silence_ms", 0.0)
	_results["%s_silence_runs" % _phase] = analysis.get("silence_runs", 0)
	_results["%s_max_click_ratio" % _phase] = analysis.get("max_click_ratio", 0.0)
	_results["%s_clicks" % _phase] = analysis.get("clicks", 0)
	if _phase == "ogg":
		_start_phase("wav")
		return false
	_finalize()
	return true

## PCM 分析：静音段（间隙）+ 帧间跳变（click）扫描。
func _analyze_pcm(rec: AudioStreamWAV) -> Dictionary:
	var out: Dictionary = {"recorded_sec": 0.0, "peak": 0.0, "max_silence_ms": 0.0,
			"silence_runs": 0, "max_click_ratio": 0.0, "clicks": 0}
	if rec == null or rec.data.is_empty():
		out["error"] = "no recording"
		return out
	var channels: int = 2 if rec.stereo else 1
	var bytes_per_frame: int = 2 * channels  # FORMAT_16_BITS
	var frames: int = rec.data.size() / bytes_per_frame
	if frames < 1000:
		out["error"] = "recording too short"
		return out
	var rate: int = rec.mix_rate
	out["recorded_sec"] = snappedf(float(frames) / float(rate), 0.001)
	print("R06-DBG pcm frames=%d rate=%d" % [frames, rate])
	# 混出单声道幅度序列（int16 → [-1,1] 浮点）——记录式 PCM 立体声交错
	var mono: PackedFloat32Array = PackedFloat32Array()
	mono.resize(frames)
	var peak: float = 0.0
	for i: int in frames:
		var acc: float = 0.0
		for c: int in channels:
			var idx: int = (i * channels + c) * 2
			var s: int = rec.data.decode_s16(idx)
			acc += float(s) / 32768.0
		var v: float = acc / float(channels)
		mono[i] = v
		peak = maxf(peak, absf(v))
		if i % 100000 == 0:
			print("R06-DBG mix at %d" % i)
	print("R06-DBG pcm mix done peak=%.4f" % peak)
	out["peak"] = snappedf(peak, 0.0001)
	if peak < 0.001:
		out["error"] = "silent recording (peak < 0.001)"
		return out
	# 静音段扫描（跳过首尾 50ms——起播/停止瞬态）
	var skip: int = int(rate * 0.05)
	var silence_threshold: float = peak * SILENCE_RATIO
	var run: int = 0
	var max_run: int = 0
	var runs: int = 0
	for i: int in range(skip, frames - skip):
		if absf(mono[i]) < silence_threshold:
			run += 1
		else:
			if run > 0:
				var ms: float = float(run) * 1000.0 / float(rate)
				if ms >= SILENCE_MIN_MS:
					runs += 1
					max_run = maxi(max_run, run)
			run = 0
	out["max_silence_ms"] = snappedf(float(max_run) * 1000.0 / float(rate), 0.01)
	out["silence_runs"] = runs
	# 帧间跳变扫描（相位不连续 → click）
	var click_threshold: float = peak * CLICK_RATIO
	var clicks: int = 0
	var max_click: float = 0.0
	for i: int in range(skip + 1, frames - skip):
		var d: float = absf(mono[i] - mono[i - 1])
		if d > click_threshold:
			clicks += 1
			max_click = maxf(max_click, d / peak)
	out["clicks"] = clicks
	out["max_click_ratio"] = snappedf(max_click, 0.001)
	return out

func _finalize() -> void:
	_phase = "done"
	var ogg_gap: float = _results.get("ogg_max_silence_ms", -1.0)
	var wav_gap: float = _results.get("wav_max_silence_ms", -1.0)
	# V1：Ogg 循环下 finished 不触发（且回绕计数 > 0 证实确实在循环）
	_results["v1_ogg_loop_finished_not_fired"] = \
			(not _results["ogg_finished_fired"]) and _results["ogg_loop_count"] > 0
	# V6：真实驱动（非 Dummy）
	_results["v6_real_audio_driver"] = _results["audio_driver"] != "Dummy"
	# V4：间隙裁决（GDD 接受线 30ms）
	_results["gdd_accept_line_ms"] = 30.0
	if ogg_gap >= 0.0 and wav_gap >= 0.0:
		_results["v2_ogg_gap_ms"] = ogg_gap
		_results["v3_wav_gap_ms"] = wav_gap
		_results["v4_ogg_within_gdd_line"] = ogg_gap < 30.0
		_results["v4_ogg_minus_wav_ms"] = snappedf(ogg_gap - wav_gap, 0.01)
	var f: FileAccess = FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_results, "\t"))
		f.close()
	print("R06-SPIKE-DONE ", JSON.stringify(_results))
