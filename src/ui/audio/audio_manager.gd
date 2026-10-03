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
## [br][b]API 骨架[/b]：11 个方法签名与 GDD §8 逐字一致——本 story 为空桩实现
## （set_bus_volume/get_bus_volume/toggle_mute 经 adapter 走真）。[br]
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
## [br][param bgm_id]: BGM 资源标识符。[br]
## [param options]: 可选参数（fade_in_sec/loop）——完整语义见 GDD §8。
## 实现归 story 002（BGM 交叉淡化）。
func play_bgm(bgm_id: StringName, options: Dictionary = {}) -> void:
	pass  # story 002：BGM 交叉淡化


## 停止 BGM。[br]
## [br][param options]: 可选参数（fade_out_sec）——完整语义见 GDD §8。
## 实现归 story 002。
func stop_bgm(options: Dictionary = {}) -> void:
	pass  # story 002：BGM 淡出


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
