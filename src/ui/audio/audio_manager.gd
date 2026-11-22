class_name AudioManager
extends RefCounted
## AudioManager —— 音频系统门面（audio Epic Story 001）。
##
## [b]形态[/b]：RefCounted 控制类，非节点、非 Autoload（ADR-0031 §1——零新增
## Autoload）。启动时由 SceneManager 惰性实例化（[method SceneManager.get_audio_manager]），
## 生命周期与进程等长——SceneManager 持有引用防 RefCounted 提前释放。[br]
## [br][b]本类只做门面与执行出口[/b]：11 个 GDD §8 API 在此（公共 API 表面唯一
## 入口），音频动作也在此一处发出——状态机只裁决「做什么」。[br]
## [br][b]分工[/b]（细节各归其类，本类不重复叙述）：[AudioNodePool] 建节点池并
## 挂 PersistentLayer；[BgmFadeExecutor] 演出淡化 Tween；[BgmPlayback] 编排 BGM
## 播放与在播态；[AudioStateOrchestrator] 裁决状态矩阵；[AudioBusControl] 管总线
## 音量与 Master 静音；[AudioSfxWiring] 装 SFX 池与流解析。[br]
## [br][b]静默模式[/b]（GDD 边缘 #14）：AudioServer 不可用时所有 API no-op
## 不崩溃、日志记录一次——经注入的 [member _adapter] 的
## [code]unavailable[/code] 标志实现。[br]
## [br][b]数据驱动[/b]：dB 默认值在 default_bus_layout.tres 资产中；
## 本类不定义 dB 常量。总线访问一律按名称（经 AudioEnums.BUS_NAMES）。[br]
## [br][b]兼容转发[/b]：迁出态以同名只读属性转发、迁出方法以同名薄转发保留——
## 既有测试与调用点无需改动（见「迁出态的兼容转发」「执行层门面转发」两段）。
##
## @experimental
## 来源: design/gdd/audio-system.md §2/§8/边缘 #14、audio Story 001、ADR-0031 §1.2。

## BGM 淡化纯计划器（story 002——数值决策唯一落地处）。本类已不直接消费
## （规划迁 [BgmPlayback] 与 [AudioStateOrchestrator]），保留常量以保
## [code]AudioManager.BgmFadePlanner[/code] 既有引用点口径不变。
const BgmFadePlanner := preload("res://src/ui/audio/bgm_fade_planner.gd")

## 常驻音频节点池（story 001/003——节点建造与挂载；本类只发指令）。
const AudioNodePoolScript := preload("res://src/ui/audio/audio_node_pool.gd")

## BGM 淡化 Tween 执行层（story 002——轮换映射/顺序延迟/总线插值演出）。
const BgmFadeExecutorScript := preload("res://src/ui/audio/bgm_fade_executor.gd")

## BGM 播放编排（story 002——计划/解析/在播态推进）。
const BgmPlaybackScript := preload("res://src/ui/audio/bgm_playback.gd")

## 音频状态机（story 004——矩阵裁决，产出动作计划；执行留本类）。
const AudioStateOrchestratorScript := preload("res://src/ui/audio/audio_state_orchestrator.gd")

## 总线音量与 Master 静音（story 001/005——静音快照状态归它）。
const AudioBusControlScript := preload("res://src/ui/audio/audio_bus_control.gd")

## 静音时 Master 总线音量（dB）——真源在 [AudioBusControl]，此处同名转发
## 以保 [code]AudioManager.MUTE_VOLUME_DB[/code] 既有引用点（settings_logic.gd 等）。
const MUTE_VOLUME_DB: float = AudioBusControlScript.MUTE_VOLUME_DB

## SFX 子系统接线（story 003——池的构造/解析器/转发；本类只发指令）。
const AudioSfxWiringScript := preload("res://src/ui/audio/audio_sfx_wiring.gd")

## 状态过渡矩阵 Logic 内核（story 004——GDD §9 24 行唯一真源 + TransitionType
## 映射）。本类已不直接消费（裁决迁 [AudioStateOrchestrator]），保留常量以保
## 既有引用点口径不变。
const StateTransitionMatrixScript := preload("res://src/ui/audio/state_transition_matrix.gd")

## SFX 池调优参数资产路径（story 003——数据驱动；真源已迁 [AudioSfxWiring]，
## 此处同名转发以保既有引用点）。
const SFX_POOL_CONFIG_PATH: String = AudioSfxWiringScript.CONFIG_PATH

## AudioServer 适配器——依赖注入（测试可注入 unavailable/mock 实例）。
var _adapter: AudioServerAdapter = null

## SceneManager 引用（Autoload 实例或测试注入的 mock）——节点池挂载目标。
var _scene_manager: Node = null

## 常驻音频节点池（BGM 双播放器 + SFX 16+1）。节点所有权归该对象，
## PersistentLayer 负责挂载。
var _node_pool: RefCounted = null

## BGM 播放编排（在播曲 id / 当前侧 / 流缓存三项状态归它——本类只转发）。
var _bgm_playback: RefCounted = null

## SFX 子系统接线（池的构造/解析/转发——节点池就绪后由本类注入节点）。
var _sfx_wiring: RefCounted = null

## 音频状态机（当前音频状态归它——本类只转发 set_state/信号回调）。
var _state_machine: RefCounted = null

## 总线音量与 Master 静音（静音态与静音前快照归它——本类只转发）。
var _bus_control: RefCounted = null

## 测试注入的 bgm_id → 资源路径覆盖表（生产为空——按 id 推导默认路径）。[br]
## 本类是所有者；[BgmPlayback] 与 [BgmStreamCache] 持同一份引用（写入互见）。
var _stream_path_overrides: Dictionary = {}

## 测试注入的 bgm_id → AudioStream 对象覆盖表（优先于路径——免落盘
## 导入周期，headless GUT 下程序生成流直用）。本类是所有者。
var _stream_overrides: Dictionary = {}

## 当前音频状态（[enum AudioEnums.AudioState]）——归 [AudioStateOrchestrator]，
## 本类只读转发（set_state 幂等守卫与场景信号映射的源态，非游戏状态）。
var _current_state: int:
	get:
		return _state_machine.current_state()

## === 迁出态的兼容转发（实现归 BgmPlayback，引用点不变）========================
## 注入表经 getter 返回同一 Dictionary 引用——`am._stream_overrides[k] = v`
## 这类下标写入作用于共享引用本身，语义与拆分前一致。

## 在播 BGM id（迁 BgmPlayback——只读转发；写入只在播放编排内）。
var _current_bgm_id: StringName:
	get:
		return _bgm_playback.current_bgm_id()

## 当前播放侧索引 0/1（迁 BgmPlayback——只读转发）。
var _current_player_index: int:
	get:
		return _bgm_playback.player_index()

## BGM 流缓存（迁 BgmPlayback——只读转发；测试断言缓存内容用）。
var _stream_cache: RefCounted:
	get:
		return _bgm_playback.stream_cache()

## 淡化 Tween 句柄（迁 BgmFadeExecutor——只读转发；无 Tween 时为 null）。
var _fade_tween: Tween:
	get:
		return _bgm_playback.fade_tween()


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
	_sfx_wiring = AudioSfxWiringScript.new(_stream_overrides)
	# 节点池先建（BGM 双播放器就绪后执行层/播放编排才拿得到数组引用）；
	# 节点全程常驻不重建，故一次注入即可。
	_node_pool = AudioNodePoolScript.new()
	_setup_node_pool()
	var executor: RefCounted = BgmFadeExecutorScript.new(
			_node_pool.bgm_players(), _adapter, _scene_manager)
	_bgm_playback = BgmPlaybackScript.new(_node_pool, executor, _adapter,
			_stream_path_overrides, _stream_overrides)
	# 状态机（裁决矩阵独有——执行仍在本类，见 set_state/_apply_state_plan）。
	_state_machine = AudioStateOrchestratorScript.new()
	# 总线音量与静音（静音快照状态归它——本类 API 转发）。
	_bus_control = AudioBusControlScript.new(_adapter)
	# story 004：场景级转换自动触发——绑定 SceneManager pre_transition 信号
	# → TransitionType→AudioState 映射 → set_state（AC-4 场景信号驱动）。
	# is_connected 防护（与 hud.gd setup 先例对齐——防重复连接导致一次信号
	# 触发多次 set_state）。
	if _scene_manager != null and _scene_manager.has_signal(&"pre_transition"):
		if not _scene_manager.pre_transition.is_connected(_on_pre_transition):
			_scene_manager.pre_transition.connect(_on_pre_transition)


## === GDD §8 API（签名逐字一致——实现按职责分给上面六个件）====================

## 播放 SFX（story 003——委托 SFX 池 Logic 内核）。[br]
## [br][param sfx_id]: SFX 资源标识符。[br]
## [param options]: 可选参数（volume_db/pitch/eviction_priority/is_attack_sfx/
## bus——完整语义见 GDD §8 + story 003 Engine Notes；[code]delay_sec[/code]
## 归 story 004 编排（播放时机触发），本 story 忽略）。冷却/淘汰/随机化/
## UI 打断全部确定性逻辑在 SfxPool.request_sfx 内完成。
func play_sfx(sfx_id: StringName, options: Dictionary = {}) -> void:
	_sfx_wiring.request(sfx_id, options)


## 播放 BGM（自动处理交叉淡入淡出）。[br]
## [br][b]编排[/b]（story 002）：经 [code]BgmFadePlanner.plan_transition()[/code]
## 纯计划器产出指令集 → [method _execute_fade_plan] Tween 薄执行层。[br]
## [br][param bgm_id]: BGM 资源标识符（音频流经 [method _resolve_stream]
## 解析——测试注入路径覆盖）。[br]
## [param options]: 可选参数（fade_in_sec/fade_out_sec/duck_db/sequential/
## loop——完整语义见 GDD §8）。
func play_bgm(bgm_id: StringName, options: Dictionary = {}) -> void:
	_bgm_playback.play_bgm(bgm_id, options)


## 停止 BGM。[br]
## [br][param options]: 可选参数（fade_out_sec）——完整语义见 GDD §8。
func stop_bgm(options: Dictionary = {}) -> void:
	_bgm_playback.stop_bgm(options)


## 异步预加载 BGM（AC-8——[code]load_threaded_request[/code] 主线程不阻塞；
## 常驻 ≤2 首：当前 + 预加载下一首）。[br]
## [param bgm_id]: 预加载的 BGM id（路径经 [member _stream_path_overrides]）。
func preload_bgm(bgm_id: StringName) -> void:
	_bgm_playback.preload_bgm(bgm_id)


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


## 设置总线音量（经 adapter 走真——最简单可用路径）。[br]
## [br][param bus]: [enum AudioEnums.AudioBus] 枚举值。[br]
## [param volume_db]: 目标音量（dB，范围 -80 ~ +6——范围钳制归 story 005 音量控制）。
func set_bus_volume(bus: AudioEnums.AudioBus, volume_db: float) -> void:
	_bus_control.set_volume(bus, volume_db)


## 获取总线当前音量（dB）。[br]
## [br][param bus]: [enum AudioEnums.AudioBus] 枚举值。[br]
## [b]返回[/b]：当前音量（dB）——静默模式时返回 0.0（无害默认）。
func get_bus_volume(bus: AudioEnums.AudioBus) -> float:
	return _bus_control.get_volume(bus)


## 静音/取消静音所有音频（F1 热键调用）。[br]
## [br]经 adapter 走真（Master 总线 -80dB ↔ 恢复快照——委托 [AudioBusControl]）。
## debounce 200ms（GDD 边缘 #5）归 story 005；HUD 静音图标信号
## [code]mute_state_changed[/code] 亦归 story 005。
func toggle_mute() -> void:
	_bus_control.toggle_mute()


## 切换指定场景音频状态（编排 BGM 切换、环境音淡入淡出、SFX 清理等）。[br]
## [br][b]编排[/b]（story 004）：裁决委托 [AudioStateOrchestrator]（矩阵查询 →
## 动作计划），执行在本类 [method _apply_state_plan]。[br]
## [br][b]幂等[/b]（AC-6）：同 [param state] 重复调用无副作用。[br]
## [br][b]N/A 转换回滚[/b]：无矩阵行的转换视为拒绝转换——状态不推进、保持源态
## 并 push_warning 一次（状态与音频实际状态始终同源，避免漂移链）。[br]
## [br][param state]: [enum AudioEnums.AudioState] 枚举值。
func set_state(state: AudioEnums.AudioState) -> void:
	# 裁决归状态机（只算不做），执行留本类（音频动作仍只有一处出口）
	_apply_state_plan(_state_machine.plan_state(state, _current_bgm_id))


## 执行状态机产出的动作计划（[AudioStateOrchestrator.plan_state]）。[br]
## [br][param plan]: 计划 Dictionary（键见 [constant AudioStateOrchestrator.K_KIND]）。[br]
## [code]none[/code]（同态 / N/A 拒绝）零动作；pause/resume 走本类对应方法；
## duck 与切曲都经 [method play_bgm]（duck 不切曲、sequential 渡劫顺序式）。
func _apply_state_plan(plan: Dictionary) -> void:
	var kind: StringName = plan[AudioStateOrchestratorScript.K_KIND]
	if kind == AudioStateOrchestratorScript.KIND_PAUSE:
		pause_all()
	elif kind == AudioStateOrchestratorScript.KIND_RESUME:
		resume_all()
	elif kind == AudioStateOrchestratorScript.KIND_DUCK:
		play_bgm(plan[AudioStateOrchestratorScript.K_BGM],
				{"fade_out_sec": plan[AudioStateOrchestratorScript.K_FADE_OUT_SEC],
				"fade_in_sec": plan[AudioStateOrchestratorScript.K_FADE_IN_SEC],
				"duck_db": plan[AudioStateOrchestratorScript.K_DUCK_DB]})
	elif kind == AudioStateOrchestratorScript.KIND_SWITCH:
		play_bgm(plan[AudioStateOrchestratorScript.K_BGM],
				{"fade_out_sec": plan[AudioStateOrchestratorScript.K_FADE_OUT_SEC],
				"fade_in_sec": plan[AudioStateOrchestratorScript.K_FADE_IN_SEC],
				"sequential": plan[AudioStateOrchestratorScript.K_SEQUENTIAL]})
	_apply_ambient_delta(plan[AudioStateOrchestratorScript.K_AMBIENT_DELTA_DB])


## 环境音 dB 偏移（story 006 接口——未实现前静默跳过，仅记录数据）。[br]
## [br]经 [code]call()[/code] 间接调用：story 006 尚未定义 set_ambient_delta，
## 直接调用会在本脚本编译期解析失败（GDScript 静态解析非存在方法）。
func _apply_ambient_delta(ambient_delta: float) -> void:
	if ambient_delta != 0.0 and has_method(&"set_ambient_delta"):
		call(&"set_ambient_delta", ambient_delta)


## === 内部实现 ==================================================================

## 建造节点池并挂入 PersistentLayer（story 001/003——委托 [AudioNodePool]）。[br]
## [br]节点命名/总线路由/process_mode 与 SFX 池接线全在池对象内完成；
## AudioManager 只提供 SFX 流解析器（归本类所有）。[br]
## [br]_scene_manager 为 null 时池对象整池跳过（单元测试直建 AudioManager
## 场景——无须 SceneManager）。
func _setup_node_pool() -> void:
	_node_pool.build(_scene_manager, _sfx_wiring.pool(), _sfx_wiring.resolve)


## 获取 BGM 播放器池（story 002 交叉淡化消费；测试断言挂载结构用）。
func get_bgm_players() -> Array[AudioStreamPlayer]:
	return _node_pool.bgm_players()


## 获取 SFX 通用池播放器节点（story 003 测试断言挂载结构用）。
func get_sfx_players() -> Array[AudioStreamPlayer]:
	return _node_pool.sfx_players()


## 获取 UI 音效单实例播放器（story 003 测试断言挂载结构用）。
func get_ui_sfx_player() -> AudioStreamPlayer:
	return _node_pool.ui_player()


## 解析 sfx_id → AudioStream（既有引用点兼容——实现已迁 [AudioSfxWiring]）。[br]
## 当前 SFX 资产（~50）归资产管线任务（story Out of Scope）——资产未落盘前
## 解析始终返回 null，由 SfxPool 静默丢弃 + push_warning（每 id 一次）。
func _resolve_sfx_stream(sfx_id: StringName) -> AudioStream:
	return _sfx_wiring.resolve(sfx_id)


## === 执行层门面转发（既有引用点兼容——实现已迁 BgmFadeExecutor / BgmPlayback）

## 淡化 Tween 重入清理——转发执行层。[br]
## 公开形态保留：audio story 002 的 QA 规格按此名引用执行层，改名会打断
## 既有引用点（本轮要求「拆出的件用同名转发保持外部引用可用」）。
func _kill_fade_tween() -> void:
	_bgm_playback.kill_fade_tween()


## 总线淡化指令——转发执行层（总线插值演出）。
func _bus_fade_cmd(from_db: float, to_db: float, duration: float) -> void:
	_bgm_playback.bus_fade(from_db, to_db, duration)


## 执行淡化计划——转发播放编排（解析归 BgmPlayback，演出归 BgmFadeExecutor）。[br]
## [b]返回[/b]：true = 已演出或无事可做；false = 目标曲损坏（状态零变更）。
func _execute_fade_plan(plan: Array[Dictionary]) -> bool:
	return _bgm_playback.execute_plan(plan)


## === 状态编排内部（story 004——信号绑定；矩阵执行归 AudioStateOrchestrator）=

## 场景转场前信号回调（AC-4）——TransitionType→AudioState 映射 → set_state。[br]
## [br]转场中二次 pre_transition（续接语义）：中断当前 Tween 由执行层的
## kill 重建实现（委托 story 002），本回调仅按最新转场类型触发目标态。[br]
## [br][param from]: 源场景 ID。[param to]: 目标场景 ID。[param type]: 转场类型。
func _on_pre_transition(from: int, to: int, type: int) -> void:
	var target_state: int = _state_machine.resolve_transition(from, to, type)
	if target_state < 0:
		return  # 未映射（NONE/防御性）——跳过
	# 状态对齐：当前态与目标态一致时无动作（幂等）；当前态与本次转场的
	# 源态预期不符时仍按目标态推进（引导/续接——矩阵无行则 no-op）
	set_state(target_state as AudioEnums.AudioState)
