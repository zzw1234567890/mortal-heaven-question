class_name AudioManager
extends RefCounted
## AudioManager —— 音频系统控制类骨架（audio Epic Story 001）。
##
## [b]形态[/b]：RefCounted 控制类，非节点、非 Autoload（ADR-0031 §1——零新增
## Autoload）。启动时由 SceneManager 惰性实例化（[method SceneManager.get_audio_manager]），
## 生命周期与进程等长——SceneManager 持有引用防 RefCounted 提前释放。[br]
## [br][b]节点池[/b]：[method _setup_node_pool] 创建 BGM 双播放器
## （[code]bgm_player_a/bgm_player_b[/code]，交叉淡化归 story 002）挂入
## SceneManager 的 PersistentLayer（经 [code]SceneManager.register_persistent()[/code]
## ——ADR-0031 §1.2 定死结构）。节点 [code]process_mode = PROCESS_MODE_ALWAYS[/code]
## （暂停时音频由暂停逻辑显式控制，节点本身不受 SceneTree.paused 冻结）。
## SFX 池归 story 003，本 story 不创建。[br]
## [br][b]API 骨架[/b]：11 个方法签名与 GDD §8 逐字一致——set_state 编排归
## story 004；[method play_bgm]/[method stop_bgm] 自 story 002 起为真实实现
## （[code]BgmFadePlanner[/code] 纯计划器 + Tween 薄执行层）。[br]
## [br][b]静默模式[/b]（GDD 边缘 #14）：AudioServer 不可用时所有 API no-op
## 不崩溃、日志记录一次——经注入的 [member _adapter] 的
## [code]unavailable[/code] 标志实现。[br]
## [br][b]数据驱动[/b]：dB 默认值在 default_bus_layout.tres 资产中；
## 本类不定义 dB 常量。总线访问一律按名称（经 AudioEnums.BUS_NAMES）。
##
## @experimental
## 来源: design/gdd/audio-system.md §2/§8/边缘 #14、audio Story 001、ADR-0031 §1.2。

## 静音时 Master 总线音量（dB）——GDD AC-MUTE-01 语义（Master volume_db = -80）。
const MUTE_VOLUME_DB: float = -80.0

## BGM 淡化纯计划器（story 002——数值决策唯一落地处）。
const BgmFadePlanner := preload("res://src/ui/audio/bgm_fade_planner.gd")

## AudioServer 适配器——依赖注入（测试可注入 unavailable/mock 实例）。
var _adapter: AudioServerAdapter = null

## SceneManager 引用（Autoload 实例或测试注入的 mock）——节点池挂载目标。
var _scene_manager: Node = null

## BGM 双播放器节点池（交叉淡化实现归 story 002——本 story 仅挂载骨架）。
var _bgm_players: Array[AudioStreamPlayer] = []

## Master 静音前音量快照（toggle_mute 恢复用——非游戏状态，UI 无关）。
var _master_volume_before_mute: float = 0.0

## toggle_mute 状态标志——true 表示当前处于 Master 静音态。
var _master_muted: bool = false

## === BGM 交叉淡化状态（story 002——BGM 播放状态归 AudioManager 自身，
## 非 GSM 游戏状态——ADR-0031 §2 零状态所有权豁免注释）=========================

## 当前播放 BGM id（空 = 无播放）。
var _current_bgm_id: StringName = &""
## 当前播放侧索引（0/1 轮换——切曲后目标侧成为新的当前侧）。[br]
## 执行层将计划器的「当前/目标」指令按轮换映射到物理播放器：当前侧
## 淡出、目标侧（1 - 当前侧）淡入；完成后翻转。
var _current_player_index: int = 0
## 淡化 Tween 句柄（重入 kill 重建——中断续接条款 AC-BGM-10）。
var _fade_tween: Tween = null
## 测试注入的 bgm_id → 资源路径覆盖表（生产为空——按 id 推导默认路径）。
var _stream_path_overrides: Dictionary = {}
## 测试注入的 bgm_id → AudioStream 对象覆盖表（优先于路径——免落盘
## 导入周期，headless GUT 下程序生成流直用）。
var _stream_overrides: Dictionary = {}


## 构造。[br]
## [br][param scene_manager]: SceneManager 引用（节点池挂载目标——生产传 Autoload，
## 测试传 mock 或 null 跳过挂载）。[br]
## [param adapter]: AudioServerAdapter 实例——null 时新建并自动检测可用性
## （不可用 → 静默模式）；测试注入 unavailable 实例覆盖检测。
func _init(scene_manager: Node = null, adapter: AudioServerAdapter = null) -> void:
	_scene_manager = scene_manager
	if adapter != null:
		_adapter = adapter
	else:
		_adapter = AudioServerAdapter.new()
		if not _adapter.detect_availability():
			_adapter.unavailable = true
	_setup_node_pool()


## === GDD §8 API 骨架（签名逐字一致——本 story 空桩）=========================

## 播放 SFX。[br]
## [br][param sfx_id]: SFX 资源标识符。[br]
## [param options]: 可选参数（volume_db/pitch/eviction_priority/delay_sec）——
## 完整语义见 GDD §8。实现归 story 003（SFX 池）。
func play_sfx(sfx_id: StringName, options: Dictionary = {}) -> void:
	pass  # story 003：SFX 池逻辑


## 播放 BGM（自动处理交叉淡入淡出）。[br]
## [br][b]编排[/b]（story 002）：经 [code]BgmFadePlanner.plan_transition()[/code]
## 纯计划器产出指令集 → [method _execute_fade_plan] Tween 薄执行层。[br]
## [br][param bgm_id]: BGM 资源标识符（音频流经 [method _resolve_stream]
## 解析——测试注入路径覆盖）。[br]
## [param options]: 可选参数（fade_in_sec/fade_out_sec/duck_db/sequential/
## loop——完整语义见 GDD §8）。
func play_bgm(bgm_id: StringName, options: Dictionary = {}) -> void:
	var fade_out_sec: float = float(options.get("fade_out_sec", 0.5))
	var fade_in_sec: float = float(options.get("fade_in_sec", 0.5))
	var duck_db: Variant = options.get("duck_db", null)
	var sequential: bool = bool(options.get("sequential", false))
	var plan: Array[Dictionary] = BgmFadePlanner.plan_transition(
		_current_bgm_id, bgm_id, _current_bgm_db(), _target_player_db(),
		fade_out_sec, fade_in_sec, duck_db, sequential)
	var executed: bool = _execute_fade_plan(plan)
	if not executed:
		return  # 边缘 #1：目标曲损坏——状态零变更（旧曲 id/当前侧均保留）
	if bgm_id != _current_bgm_id:
		_current_bgm_id = bgm_id
		if duck_db == null and bgm_id != &"":
			# 切曲成功——目标侧成为新的当前侧（降低类/仅停止不翻转）
			_current_player_index = 1 - _current_player_index


## 停止 BGM。[br]
## [br][param options]: 可选参数（fade_out_sec）——完整语义见 GDD §8。
func stop_bgm(options: Dictionary = {}) -> void:
	var fade_out_sec: float = float(options.get("fade_out_sec", 0.5))
	var plan: Array[Dictionary] = BgmFadePlanner.plan_transition(
		_current_bgm_id, &"", _current_bgm_db(), BgmFadePlanner.SILENCE_DB,
		fade_out_sec, 0.0)
	_execute_fade_plan(plan)
	_current_bgm_id = &""


## 暂停所有音频（用于游戏暂停状态）。实现归 story 005（暂停行为）。
func pause_all() -> void:
	pass  # story 005：暂停行为


## 恢复所有音频（用于取消暂停）。实现归 story 005。
func resume_all() -> void:
	pass  # story 005：暂停行为


## 播放环境音。[br]
## [br][param ambient_id]: 环境音预设标识符。实现归 story 006（环境音层）。
func play_ambient(ambient_id: StringName) -> void:
	pass  # story 006：环境音层


## 停止环境音。[br]
## [br][param fade_out_sec]: 淡出时长（秒）。实现归 story 006。
func stop_ambient(fade_out_sec: float = 1.0) -> void:
	pass  # story 006：环境音层


## 设置总线音量（本 story 经 adapter 走真——最简单可用路径）。[br]
## [br][param bus]: [enum AudioEnums.AudioBus] 枚举值。[br]
## [param volume_db]: 目标音量（dB，范围 -80 ~ +6——范围钳制归 story 005 音量控制）。
func set_bus_volume(bus: AudioEnums.AudioBus, volume_db: float) -> void:
	_adapter.set_bus_volume_db(bus, volume_db)


## 获取总线当前音量（dB）。[br]
## [br][param bus]: [enum AudioEnums.AudioBus] 枚举值。[br]
## [b]返回[/b]：当前音量（dB）——静默模式时返回 0.0（无害默认）。
func get_bus_volume(bus: AudioEnums.AudioBus) -> float:
	return _adapter.get_bus_volume_db(bus)


## 静音/取消静音所有音频（F1 热键调用）。[br]
## [br]本 story 经 adapter 走真（Master 总线 -80dB ↔ 恢复快照）。
## debounce 200ms（GDD 边缘 #5）归 story 005；HUD 静音图标信号
## [code]mute_state_changed[/code] 亦归 story 005。
func toggle_mute() -> void:
	if _master_muted:
		_adapter.set_bus_volume_db(AudioEnums.AudioBus.MASTER, _master_volume_before_mute)
		_master_muted = false
		return
	_master_volume_before_mute = _adapter.get_bus_volume_db(AudioEnums.AudioBus.MASTER)
	_adapter.set_bus_volume_db(AudioEnums.AudioBus.MASTER, MUTE_VOLUME_DB)
	_master_muted = true


## 切换指定场景音频状态（编排 BGM 切换、环境音淡入淡出、SFX 清理等）。[br]
## [br][param state]: [enum AudioEnums.AudioState] 枚举值。[br]
## 内部经 GDD §9 过渡矩阵执行——矩阵实现归 story 004（本 story 空桩，
## 枚举类型已完整定义供直接消费）。
func set_state(state: AudioEnums.AudioState) -> void:
	pass  # story 004：过渡矩阵


## === 内部实现 ==================================================================

## 实例化 BGM 双播放器节点池并挂入 PersistentLayer。[br]
## [br]节点命名与 GDD §4 BGM 架构一致（bgm_player_a/bgm_player_b——交叉淡化
## 归 story 002）。[code]process_mode = PROCESS_MODE_ALWAYS[/code]（ADR-0031 §1.2——
## 暂停中节点不被冻结，暂停行为由暂停逻辑显式控制）。[br]
## [br]_scene_manager 为 null 时跳过挂载（单元测试直建 AudioManager 场景——
## 无须 SceneManager）。
func _setup_node_pool() -> void:
	if _scene_manager == null:
		return
	for player_name: String in [&"bgm_player_a", &"bgm_player_b"]:
		var player := AudioStreamPlayer.new()
		player.name = player_name
		player.bus = AudioEnums.BUS_NAMES[AudioEnums.AudioBus.BGM]
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		_bgm_players.append(player)
		_scene_manager.register_persistent(player)


## 获取 BGM 播放器池（story 002 交叉淡化消费；测试断言挂载结构用）。
func get_bgm_players() -> Array[AudioStreamPlayer]:
	return _bgm_players


## === BGM 交叉淡化执行层（story 002——Tween 薄执行）===========================

## 当前播放侧 dB——中断续接时新计划以当前实际 dB 为起点（非 -80）。[br]
## 无播放器时返回 [constant BgmFadePlanner.SILENCE_DB]。
func _current_bgm_db() -> float:
	if _bgm_players.is_empty() or not _bgm_players[_current_player_index].playing:
		return BgmFadePlanner.SILENCE_DB
	return _bgm_players[_current_player_index].volume_db


## 目标播放器当前 dB（双播放器轮换——目标侧为 players[1]；池空/未挂载时
## 返回 [constant BgmFadePlanner.SILENCE_DB]，计划器据此从静音起淡入）。
func _target_player_db() -> float:
	if _bgm_players.size() < 2:
		return BgmFadePlanner.SILENCE_DB
	var target: AudioStreamPlayer = _bgm_players[1 - _current_player_index]
	if not target.playing:
		return BgmFadePlanner.SILENCE_DB
	return target.volume_db


## 解析 bgm_id → 音频流（测试注入路径覆盖优先；生产按默认路径加载）。[br]
## 文件损坏/缺失（GDD 边缘 #1）：返回 null——调用侧保留旧曲继续播放。
func _resolve_stream(bgm_id: StringName) -> AudioStream:
	# 对象注入优先（测试直用程序生成流）
	if _stream_overrides.has(bgm_id):
		return _stream_overrides[bgm_id]
	var path: String = _stream_path_overrides.get(bgm_id, "")
	if path == "":
		push_error("AudioManager: BGM '%s' 无资源路径映射（保持旧曲）" % bgm_id)
		return null
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: BGM 路径加载失败或类型不匹配（保持旧曲）: %s" % path)
		return null
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		push_warning("AudioManager: BGM 路径加载失败或类型不匹配（保持旧曲）: %s" % path)
	return stream


## 执行淡化计划（Tween 薄执行层——数值决策全在 BgmFadePlanner）。[br]
## [br][b]中断续接[/b]：重入 kill 旧 Tween——正在插值的属性停留在当前实际值，
## 新计划以该值为起点（AC-BGM-10）。[br]
## [br][b]顺序式[/b]（渡劫例外）：sequential 指令经 [code]set_delay[/code]
## 前移等待前序时长。[br]
## [br][b]边缘 #1[/b]：计划内任一目标曲解析失败 → 整份计划放弃（旧曲原样
## 继续播放——不淡出、不停止、不翻转当前侧）。
func _execute_fade_plan(plan: Array[Dictionary]) -> bool:
	if plan.is_empty():
		return true  # 同 id/无事可做——非失败
	if _bgm_players.is_empty():
		return true  # 静默模式/测试无挂载——计划放弃（API 不崩溃）
	# 前置解析全部 play_stream（边缘 #1：任一目标曲损坏/缺失 → 放弃整份计划，
	# 旧曲保持原样继续播放——「不切换」而非「淡出旧曲后无声」）
	var resolved: Dictionary = {}
	for cmd: Dictionary in plan:
		var play_stream: StringName = cmd[BgmFadePlanner.K_PLAY_STREAM]
		if play_stream != &"" and not resolved.has(play_stream):
			var stream: AudioStream = _resolve_stream(play_stream)
			if stream == null:
				return false  # 损坏/缺失：保留旧曲继续播放（边缘 #1）
			resolved[play_stream] = stream
	_kill_fade_tween()
	_fade_tween = _scene_manager.create_tween() if _scene_manager != null \
			else null
	if _fade_tween == null:
		return true  # 无场景树——非失败
	_fade_tween.set_parallel(true)
	var sequential_delay_sec: float = 0.0
	for cmd: Dictionary in plan:
		var target: StringName = cmd[BgmFadePlanner.K_TARGET]
		var from_db: float = cmd[BgmFadePlanner.K_FROM_DB]
		var to_db: float = cmd[BgmFadePlanner.K_TO_DB]
		var duration: float = cmd[BgmFadePlanner.K_DURATION]
		var is_sequential: bool = cmd[BgmFadePlanner.K_SEQUENTIAL]
		if target == &"bus":
			# 降低类：BGM 总线 dB 过渡（不切曲——AC-BGM-06/07）
			_bus_fade_cmd(from_db, to_db, duration)
			continue
		# 计划器「当前/目标」→ 物理播放器轮换映射（a = 当前侧 / b = 目标侧）
		var player_idx: int = _current_player_index if target == &"a" 				else 1 - _current_player_index
		if player_idx >= _bgm_players.size():
			continue
		var player: AudioStreamPlayer = _bgm_players[player_idx]
		var play_stream: StringName = cmd[BgmFadePlanner.K_PLAY_STREAM]
		if play_stream != &"":
			var stream: AudioStream = resolved[play_stream]
			player.stream = stream
			player.volume_db = from_db
			player.play()
		var delay_sec: float = sequential_delay_sec if is_sequential else 0.0
		var step: PropertyTweener = _fade_tween.tween_property(player,
			"volume_db", to_db, duration).from(from_db) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if delay_sec > 0.0:
			step.set_delay(delay_sec)
		if is_sequential:
			sequential_delay_sec += duration
		if cmd[BgmFadePlanner.K_STOP_AFTER]:
			_fade_tween.tween_callback(player.stop) \
				.set_delay(duration + delay_sec)
	return true


## 总线淡化指令（降低类——经 adapter 操作 AudioServer BGM 总线）。
func _bus_fade_cmd(from_db: float, to_db: float, duration: float) -> void:
	# 总线音量过渡经 _fade_tween 插值方法回调（无总线对象可 tween——
	# AudioServer 静态 API，用 tween_method 驱动）
	var bus: int = AudioEnums.AudioBus.BGM
	_fade_tween.tween_method(
		func(value: float) -> void: _adapter.set_bus_volume_db(bus, value),
		from_db, to_db, duration) 		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## 淡化 Tween 重入清理（中断续接——kill 停留在当前实际值）。
func _kill_fade_tween() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null
