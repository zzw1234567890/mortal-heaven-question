extends RefCounted
## BgmPlayback —— BGM 播放编排（自 AudioManager 拆出）。
##
## [b]职责[/b]：把一次「放 BGM / 停 BGM / 预加载」串起来——
## 读起点 → 交 [code]BgmFadePlanner[/code] 出计划 → 前置解析全部目标曲
## （边缘 #1）→ 交 [BgmFadeExecutor] 演出 → 成功后推进「当前曲 / 当前侧 /
## 流缓存」。[br]
## [br][b]状态所有权[/b]：在播曲 id、双播放器轮换侧索引、BGM 流缓存三项归本类
## ——AudioManager 以同名只读属性转发（既有测试直读那几个字段）。[br]
## [br][b]注入为共享引用的表[/b]：路径覆盖表与对象覆盖表由 AudioManager 持有
## （测试直接往里塞），本类只持同一份引用，不复制。[br]
## [br][b]不建节点[/b]：播放器节点归 [AudioNodePool]，本类与执行层都只持引用。
##
## 来源: design/gdd/audio-system.md §8、audio Story 002、AC-8/AC-BGM-06/07/08/10、边缘 #1。

## BGM 淡化纯计划器（数值决策唯一落地处）。
const BgmFadePlanner := preload("res://src/ui/audio/bgm_fade_planner.gd")

## BGM 流加载与缓存（AC-8——异步预加载 + 常驻 ≤2 首）。
const BgmStreamCacheScript := preload("res://src/ui/audio/bgm_stream_cache.gd")

## 常驻节点池（BGM 双播放器——本类只读，用于「无挂载」判定）。
var _pool: RefCounted = null

## 淡化执行层（轮换映射/顺序延迟/总线插值的演出）。
var _executor: RefCounted = null

## AudioServer 适配器（duck 起点读 BGM 总线实际音量）。
var _adapter: AudioServerAdapter = null

## 测试注入的 bgm_id → 资源路径覆盖表（共享引用——生产为空）。
var _path_overrides: Dictionary = {}

## 测试注入的 bgm_id → AudioStream 对象覆盖表（共享引用——优先于路径，
## 免落盘导入周期，headless GUT 下程序生成流直用）。
var _object_overrides: Dictionary = {}

## 当前播放 BGM id（空 = 无播放）。
var _current_bgm_id: StringName = &""

## 当前播放侧索引（0/1 轮换——切曲后目标侧成为新的当前侧）。
var _player_index: int = 0

## BGM 流缓存（AC-8——异步加载/预加载/释放；共享 [member _path_overrides]）。
var _stream_cache: RefCounted = null


## 构造（三个覆盖表引用在构造期接入——缓存与解析器共用同一份）。[br]
## [br][param pool]: 常驻节点池（AudioNodePool）。[br]
## [param executor]: 淡化执行层（BgmFadeExecutor）。[br]
## [param adapter]: AudioServerAdapter 实例。[br]
## [param path_overrides]: 路径覆盖表（共享引用）。[br]
## [param object_overrides]: 对象覆盖表（共享引用）。
func _init(pool: RefCounted, executor: RefCounted, adapter: AudioServerAdapter,
		path_overrides: Dictionary, object_overrides: Dictionary) -> void:
	_pool = pool
	_executor = executor
	_adapter = adapter
	_path_overrides = path_overrides
	_object_overrides = object_overrides
	_stream_cache = BgmStreamCacheScript.new(_path_overrides)


## 当前播放曲 id（AudioManager 经转发暴露给测试/上层）。
func current_bgm_id() -> StringName:
	return _current_bgm_id


## 当前播放侧索引（0/1）。
func player_index() -> int:
	return _player_index


## BGM 流缓存（测试直接断言缓存内容用）。
func stream_cache() -> RefCounted:
	return _stream_cache


## 播放 BGM（自动处理交叉淡入淡出）。[br]
## [br][param bgm_id]: BGM 资源标识符（音频流经 [method resolve_stream] 解析）。[br]
## [param options]: 可选参数（fade_in_sec/fade_out_sec/duck_db/sequential/
## preload_next——完整语义见 GDD §8）。
func play_bgm(bgm_id: StringName, options: Dictionary = {}) -> void:
	var fade_out_sec: float = float(options.get("fade_out_sec", 0.5))
	var fade_in_sec: float = float(options.get("fade_in_sec", 0.5))
	var duck_db: Variant = options.get("duck_db", null)
	var sequential: bool = bool(options.get("sequential", false))
	# 降低类起点读 BGM 总线实际音量——播放器 dB 与总线 dB 无关（duck
	# 不触碰播放器音量）；duck 态二次切换从总线当前值续接（AC-BGM-10）
	var from_db: float = _adapter.get_bus_volume_db(AudioEnums.AudioBus.BGM) \
			if duck_db != null else current_db()
	var plan: Array[Dictionary] = BgmFadePlanner.plan_transition(
		_current_bgm_id, bgm_id, from_db, target_db(),
		fade_out_sec, fade_in_sec, duck_db, sequential)
	var executed: bool = execute_plan(plan)
	if not executed:
		return  # 边缘 #1：目标曲损坏——状态零变更（旧曲 id/当前侧均保留）
	# id 更新仅限真实切曲（duck 不换流——id 始终反映实际在播曲目）
	if bgm_id != _current_bgm_id and duck_db == null:
		_current_bgm_id = bgm_id
		if bgm_id != &"":
			# 切曲成功——目标侧成为新的当前侧（降低类/仅停止不翻转）
			_player_index = 1 - _player_index
			# AC-8：当前曲置保留头 + 逐出超容量条目 + 预加载下一首（可缺省）
			_stream_cache.set_current(bgm_id)
			_stream_cache.trim()
			var preload_next: Variant = options.get("preload_next", null)
			if preload_next != null:
				preload_bgm(preload_next)


## 停止 BGM。[br]
## [br][param options]: 可选参数（fade_out_sec）——完整语义见 GDD §8。
func stop_bgm(options: Dictionary = {}) -> void:
	var fade_out_sec: float = float(options.get("fade_out_sec", 0.5))
	var plan: Array[Dictionary] = BgmFadePlanner.plan_transition(
		_current_bgm_id, &"", current_db(), BgmFadePlanner.SILENCE_DB,
		fade_out_sec, 0.0)
	execute_plan(plan)
	_current_bgm_id = &""


## 异步预加载 BGM（AC-8——[code]load_threaded_request[/code] 主线程不阻塞；
## 常驻 ≤2 首：当前 + 预加载下一首）。[br]
## [param bgm_id]: 预加载的 BGM id（路径经 [member _path_overrides]）。
func preload_bgm(bgm_id: StringName) -> void:
	_stream_cache.preload_bgm(bgm_id)


## 当前播放侧 dB——中断续接时新计划以当前实际 dB 为起点（非 -80）。[br]
## 无播放器时返回 [constant BgmFadePlanner.SILENCE_DB]。
func current_db() -> float:
	return _executor.current_db(_player_index)


## 目标播放器当前 dB（双播放器轮换——转发执行层，目标侧为 1 - 当前侧）。
func target_db() -> float:
	return _executor.target_db(_player_index)


## 执行淡化计划（Tween 薄执行层——数值决策全在 BgmFadePlanner）。[br]
## [br][b]边缘 #1 前置解析[/b]：计划内任一目标曲解析失败 → 整份计划放弃
## （旧曲原样继续播放——不淡出、不停止、不翻转当前侧）。解析必须先于任何
## 演出动作完成。[br]
## [b]返回[/b]：true = 已演出或无事可做；false = 目标曲损坏（状态零变更）。
func execute_plan(plan: Array[Dictionary]) -> bool:
	if plan.is_empty():
		return true  # 同 id/无事可做——非失败
	if _pool.bgm_players().is_empty():
		return true  # 静默模式/测试无挂载——计划放弃（API 不崩溃）
	# 前置解析全部 play_stream（边缘 #1：任一目标曲损坏/缺失 → 放弃整份计划，
	# 旧曲保持原样继续播放——「不切换」而非「淡出旧曲后无声」）
	var resolved: Dictionary = {}
	for cmd: Dictionary in plan:
		var play_stream: StringName = cmd[BgmFadePlanner.K_PLAY_STREAM]
		if play_stream != &"" and not resolved.has(play_stream):
			var stream: AudioStream = resolve_stream(play_stream)
			if stream == null:
				return false  # 损坏/缺失：保留旧曲继续播放（边缘 #1）
			resolved[play_stream] = stream
	return _executor.execute(plan, _player_index, resolved)


## 解析 bgm_id → 音频流（对象注入优先 → 流缓存 → 路径表）。[br]
## 文件损坏/缺失（GDD 边缘 #1）：返回 null——调用侧保留旧曲继续播放。
## 路径加载经 [member _stream_cache]（AC-8——缓存命中免 IO；冷路径
## [code]load_threaded_request + get[/code] 回退）。
func resolve_stream(bgm_id: StringName) -> AudioStream:
	# 对象注入优先（测试直用程序生成流——优先级高于缓存）
	if _object_overrides.has(bgm_id):
		return _object_overrides[bgm_id]
	return _stream_cache.resolve(bgm_id)


## === 执行层透传（门面兼容路径——AudioManager 旧方法名转发至此）=============

## 当前淡化 Tween 句柄（无 Tween 时为 null）。
func fade_tween() -> Tween:
	return _executor.fade_tween()


## 淡化 Tween 重入清理（执行层透传）。
func kill_fade_tween() -> void:
	_executor.kill_tween()


## 总线淡化指令（执行层透传——门面兼容路径用）。
func bus_fade(from_db: float, to_db: float, duration: float) -> void:
	_executor.bus_fade(from_db, to_db, duration)
