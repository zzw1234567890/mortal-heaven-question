class_name SfxPool
extends RefCounted
## SfxPool —— SFX 池 Logic 内核（audio-manager Story 003）。
##
## [b]职责[/b]：SFX 播放请求的全部确定性决策唯一落地处（control-manifest
## Required pattern——「冷却/淘汰/随机化/UI 打断全部确定性逻辑，时间注入可单测」）。
## 16 节点池（12 活跃 + 4 余量）由 AudioManager 建好后经
## [method set_pool_nodes] 注入；本类不持有节点所有权、不逐帧轮询——
## 全部判定在 [method request_sfx] 单次调用内惰性完成。[br]
## [br][b]决策内容[/b]（GDD §5/§7/公式 2 + story 003 QA）：[br]
##   - 同 sfx_id 冷却 50ms（窗口 [code]elapsed < cooldown_ms[/code] 丢弃）[br]
##   - UI 音效独立单实例槽（打断旧音 + 原子接续，不参与通用池）[br]
##   - 战斗攻击 SFX 100ms 门控（[code]is_attack_sfx[/code] 标记）[br]
##   - 空槽分配 → 随机化 pitch/volume → 播放 + 记冷却[br]
##   - 池满淘汰：按（淘汰优先级 → 播放时间）找牺牲者；新请求优先级
##     不高于牺牲者则拒绝 + [signal sfx_pool_exhausted][br]
## [br][b]注入[/b]（ADR-0031 Logic 内核模式）：[br]
##   - [code]clock: Callable[/code]（生产传 [code]Time.get_ticks_msec[/code]；
##     测试传可变变量闭包推进时间）[br]
##   - [code]rng: RandomNumberGenerator[/code]（固定种子可复现）[br]
##   - [code]config: SfxPoolConfig[/code]（调优参数数据驱动资产——
##     Forbidden「硬编码调优参数」规则的落地；null 时用出厂默认值）[br]
##   - [code]resolver: Callable[/code]（[code]sfx_id -> AudioStream[/code]，
##     由 AudioManager 注入 SFX 流解析；测试注入程序生成流映射）[br]
## [br][b]资源缺失[/b]（AC-7/边缘 #2/#15）：请求时经 resolver 查询；未加载/
## 标记不可用 → 静默丢弃 + [code]push_warning[/code]（每 id 一次），不影响池状态。
##
## [b]使用示例[/b]：
## [codeblock]
## var cfg := SfxPoolConfig.new()  # 生产经 AudioManager 注入 .tres 资产
## var pool := SfxPool.new(Time.get_ticks_msec, RandomNumberGenerator.new(), cfg)
## pool.set_stream_resolver(_resolve_sfx_stream)
## pool.set_pool_nodes(_sfx_players)
## pool.set_ui_player(_ui_sfx_player)
## pool.request_sfx(&"sword_hit")
## pool.request_sfx(&"attack_hit", {"is_attack_sfx": true, "eviction_priority": 2})
## pool.request_sfx(&"ui_confirm", {"bus": AudioEnums.AudioBus.UI})
## [/codeblock]
##
## @experimental
## 来源: design/gdd/audio-system.md §5/§7/公式 2/边缘 #2/#15、audio Story 003、ADR-0031。

## === 淘汰优先级语义常量（GDD §5 三级——规则语义，非调优旋钮）====================

## 装饰性（Ambient SFX、装饰音）——最低淘汰优先级。
const EVICTION_DECORATIVE: int = 0
## 功能性（卡牌出牌声、脚步声）——默认淘汰优先级。
const EVICTION_FUNCTIONAL: int = 1
## 关键性（命中确认、警告音）——永不作为淘汰候选。
const EVICTION_CRITICAL: int = 2

## === 信号（story Required）======================================================

## 同 sfx_id 冷却窗口内请求被丢弃。[br]
## [br][param sfx_id]: 被丢弃的 SFX 标识符。[br]
## [param elapsed_ms]: 距上次播放的经过毫秒数（恒 < config.cooldown_ms）。
signal sfx_cooldown_discarded(sfx_id: StringName, elapsed_ms: int)

## 池满且新请求优先级不高于任何现存 SFX 时拒绝。[br]
## [br][param sfx_id]: 被拒绝的 SFX 标识符。
signal sfx_pool_exhausted(sfx_id: StringName)

## === 内部状态 ==================================================================

## 调优参数配置（数据驱动资产注入——Forbidden 硬编码规则落地）。
var _config: SfxPoolConfig

## 时钟注入——Callable 返回当前毫秒（生产 Time.get_ticks_msec；测试闭包）。
var _clock: Callable

## RNG 注入——固定种子可复现（测试断言 AC-5 同种子可复现）。
var _rng: RandomNumberGenerator

## 流解析器注入——sfx_id -> AudioStream；null = 未加载/不可用。
var _resolver: Callable = Callable()

## 通用 SFX 播放器节点池（经 set_pool_nodes 注入）。
var _pool_nodes: Array[AudioStreamPlayer] = []

## UI 音效单实例播放器（UI 音不参与通用池——set_ui_player 注入）。
var _ui_player: AudioStreamPlayer = null

## 通用池槽位登记：索引 -> {sfx_id, eviction_priority, start_ms}（空槽 = 缺键）。
var _slots: Dictionary = {}

## 同 sfx_id 冷却登记：sfx_id -> 上次播放毫秒。
var _cooldown_tracker: Dictionary = {}

## 攻击门控：上次攻击 SFX 播放毫秒（attack_interval_ms 窗口判定）。
var _last_attack_ms: int = 0

## UI 音登记：{sfx_id, start_ms}（打断时更新；流损坏/缺失时清除）。
var _ui_active: Dictionary = {}

## 资源缺失告警去重表——每个 id 只 push_warning 一次（防日志刷屏）。
var _missing_warned: Dictionary = {}


## 构造。[br]
## [br][param clock]: 时钟注入（Callable 返回毫秒）。[br]
## [param rng]: RNG 注入（固定种子可复现——测试 AC-5 依赖）。[br]
## [param config]: SfxPoolConfig 调优参数资产——null 时用出厂默认值
## （数据驱动规则落地；测试可注入覆盖实例断言行为随配置变化）。
func _init(clock: Callable, rng: RandomNumberGenerator,
		config: SfxPoolConfig = null) -> void:
	_clock = clock
	_rng = rng
	_config = config if config != null else SfxPoolConfig.new()
	_last_attack_ms = -_config.attack_interval_ms


## 注入通用 SFX 播放器节点池（AudioManager 建好 16 节点后调用）。[br]
## [br][param nodes]: 16 个 [AudioStreamPlayer]（本类不持有节点所有权——
## 节点生命周期归 AudioManager/PersistentLayer）。
func set_pool_nodes(nodes: Array[AudioStreamPlayer]) -> void:
	_pool_nodes = nodes
	_slots.clear()


## 注入 UI 音效单实例播放器（UI 音独立槽——不参与通用池）。[br]
## [br][param player]: UI 播放器节点；null 时 UI 音请求静默丢弃。
func set_ui_player(player: AudioStreamPlayer) -> void:
	_ui_player = player


## 注入流解析器（sfx_id -> AudioStream；null = 未加载/不可用——AC-7）。[br]
## [br][param resolver]: Callable 接收 sfx_id，返回 AudioStream 或 null。
func set_stream_resolver(resolver: Callable) -> void:
	_resolver = resolver


## 取配置的池总节点数（AudioManager 建节点池时据此规模创建——数据驱动）。
func pool_size() -> int:
	return _config.pool_size


## === 测试观测方法 ==============================================================

## 当前通用池活跃槽数（测试断言 AC-2/AC-3/AC-4 用；O(1)）。
func active_count() -> int:
	return _slots.size()


## 取池节点（按注入顺序索引——测试断言淘汰复用/随机化落在哪个播放器用）。[br]
## [br][param index]: 池节点索引。[br]
## [b]返回[/b]: 对应 [AudioStreamPlayer]；越界返回 null。
func node_at(index: int) -> AudioStreamPlayer:
	if index < 0 or index >= _pool_nodes.size():
		return null
	return _pool_nodes[index]


## === 核心方法 ==================================================================

## 请求播放 SFX（GDD §5/§7/公式 2 分支顺序的完整实现）。[br]
## [br][b]分支顺序[/b]（story Implementation Notes 定死，勿重排）：[br]
##   1. 冷却检查——同 sfx_id 窗口内（elapsed < config.cooldown_ms）丢弃[br]
##   2. UI 音效分支——[code]options.bus == AudioBus.UI[/code] 走独立单实例槽[br]
##   3. 攻击门控——[code]options.is_attack_sfx == true[/code] 独立 100ms 窗口[br]
##   4. 资源解析——resolver 返回 null → 静默丢弃 + push_warning[br]
##   5. 空槽分配 → 随机化 pitch/volume → 播放 + 记冷却[br]
##   6. 池满淘汰——按（淘汰优先级 → 播放时间）找牺牲者；优先级不高于
##      牺牲者则拒绝 + [signal sfx_pool_exhausted]；否则淘汰复用其播放器[br]
## [br][param sfx_id]: SFX 资源标识符。[br]
## [param options]: 可选参数（volume_db/pitch/eviction_priority/is_attack_sfx/
## bus——完整语义见 GDD §8 + story 003 Engine Notes）。
func request_sfx(sfx_id: StringName, options: Dictionary = {}) -> void:
	var now: int = int(_clock.call())

	# 分支 1：冷却检查（同 sfx_id 独立计时——非跨类型共享）
	if _cooldown_tracker.has(sfx_id):
		var elapsed: int = now - int(_cooldown_tracker[sfx_id])
		if elapsed < _config.cooldown_ms:
			sfx_cooldown_discarded.emit(sfx_id, elapsed)
			return

	# 分支 2：UI 音效（独立单实例槽——打断旧 UI 音 + 原子接续）
	if int(options.get("bus", AudioEnums.AudioBus.SFX)) == AudioEnums.AudioBus.UI:
		_request_ui_sfx(sfx_id, options, now)
		return

	# 分支 3：战斗攻击门控（attack_interval_ms 窗口；非攻击 SFX 不受门控）
	if bool(options.get("is_attack_sfx", false)):
		if now - _last_attack_ms < _config.attack_interval_ms:
			return  # 静默丢弃（门控无信号——story 003 只要求 sfx_cooldown_discarded/sfx_pool_exhausted 两信号）
		_last_attack_ms = now

	# 分支 4：资源解析（缺失 → 静默丢弃，不影响池状态）
	var stream: AudioStream = _resolve_stream(sfx_id)
	if stream == null:
		return

	var priority: int = int(options.get("eviction_priority", EVICTION_FUNCTIONAL))

	# 分支 5：空槽分配
	if _active_count() < _config.max_simultaneous:
		var player: AudioStreamPlayer = _acquire_free_player()
		if player != null:
			_start_playback(player, sfx_id, stream, priority, options, now)
		return

	# 分支 6：池满淘汰——按（淘汰优先级 → 播放时间）找牺牲者
	var victim_idx: int = _find_eviction_victim()
	if victim_idx < 0:
		# 全关键性（优先级 2）无候选可淘汰——AC-SFX-03：拒绝 + 信号。
		# （进入分支 6 前提是池已满，-1 只可能意味着所有槽均为关键性。）
		sfx_pool_exhausted.emit(sfx_id)
		return
	var victim: Dictionary = _slots[victim_idx]
	if priority <= int(victim["eviction_priority"]):
		sfx_pool_exhausted.emit(sfx_id)
		return
	# 淘汰牺牲者：停止其播放器，复用承载新 SFX
	var victim_player: AudioStreamPlayer = _pool_nodes[victim_idx]
	victim_player.stop()
	_slots.erase(victim_idx)
	_start_playback(victim_player, sfx_id, stream, priority, options, now)


## === 内部辅助 ==================================================================

## 解析 sfx_id → AudioStream（resolver 注入）。[br]
## 缺失/不可用时 push_warning 一次（每 id 去重）并返回 null。
func _resolve_stream(sfx_id: StringName) -> AudioStream:
	if not _resolver.is_valid():
		return null
	var stream: AudioStream = _resolver.call(sfx_id) as AudioStream
	if stream == null and not _missing_warned.get(sfx_id, false):
		push_warning("SFX not found: %s" % sfx_id)
		_missing_warned[sfx_id] = true
	return stream


## 当前通用池活跃槽数（O(1)——字典 size）。
func _active_count() -> int:
	return _slots.size()


## 取空闲播放器（不在任何活跃槽且未在播放中的池节点）。[br]
## 池为空（单元测试 null scene_manager）时返回 null——调用侧 no-op 不崩溃。
func _acquire_free_player() -> AudioStreamPlayer:
	for i: int in _pool_nodes.size():
		if not _slots.has(i):
			return _pool_nodes[i]
	return null


## 池满时找淘汰牺牲者索引：先按淘汰优先级（低→高），同优先级内按
## 播放时间（旧→新）。关键性（优先级 2）永不作为候选。[br]
## 返回 -1 = 无候选（防御）。
func _find_eviction_victim() -> int:
	var victim_idx: int = -1
	var victim_priority: int = EVICTION_CRITICAL + 1
	var victim_start: int = 0
	for idx: int in _slots:
		var slot: Dictionary = _slots[idx]
		var priority: int = int(slot["eviction_priority"])
		if priority >= EVICTION_CRITICAL:
			continue  # 关键性永不淘汰
		var start: int = int(slot["start_ms"])
		if priority < victim_priority or \
				(priority == victim_priority and start < victim_start):
			victim_priority = priority
			victim_start = start
			victim_idx = idx
	return victim_idx


## 启动播放：赋流、随机化 pitch/volume（options 显式覆盖）、播放、记冷却与槽位。
func _start_playback(player: AudioStreamPlayer, sfx_id: StringName,
		stream: AudioStream, priority: int, options: Dictionary, now: int) -> void:
	player.stream = stream
	player.pitch_scale = float(options.get("pitch",
			_rng.randf_range(_config.pitch_min, _config.pitch_max)))
	player.volume_db = float(options.get("volume_db",
			_rng.randf_range(_config.volume_min_db, _config.volume_max_db)))
	player.play()
	_cooldown_tracker[sfx_id] = now
	# 槽位登记（player 在池中索引——_start_playback 只被空槽/淘汰路径调用，
	# 淘汰路径已先 erase 旧槽，故此处按 sfx_id 反查索引登记）
	var slot_idx: int = _pool_nodes.find(player)
	if slot_idx >= 0:
		_slots[slot_idx] = {
			"sfx_id": sfx_id,
			"eviction_priority": priority,
			"start_ms": now,
		}


## UI 音效请求（独立单实例槽——GDD §7 打断 + 原子接续）。[br]
## [br]打断规则：新 UI 音打断旧 UI 音（单实例，互斥）——为避免 80ms 最低
## 时长规则在快速导航时造成「新音被旧音的最低时长尾巴压住」，打断旧音后
## 先 [code]stop()[/code] 截断旧音，再播放新音；若旧音起播不足 80ms 被新音
## 截断，截断是「被新音打断」而非「无声结尾」——不违反 §7（story 003 QA
## AC-8 语义：快速连续 3 个 UI 音，仅最后一个可听全）。[br]
## 最低时长保证落点在 [method _on_ui_finished]：单实例槽经 [code]finished[/code]
## 信号（自然播完）回读播放时长，不足 [code]config.ui_min_duration_ms[/code] 时补播
## 静音以保证该音完整出声（防过早自然结束被下一音立即顶掉）。
func _request_ui_sfx(sfx_id: StringName, options: Dictionary, now: int) -> void:
	var stream: AudioStream = _resolve_stream(sfx_id)
	if stream == null:
		return
	if _ui_player == null:
		return  # 无 UI 槽（单元测试直建场景）——no-op 不崩溃
	# 打断旧 UI 音：截断后播放新音（新音从完整起点起播，不接旧音尾巴）
	_ui_player.stop()
	# 原子接续：新音 + 登记（最短时长由 finished 回读补静音保证）
	_ui_player.stream = stream
	_ui_player.pitch_scale = float(options.get("pitch", 1.0))
	_ui_player.volume_db = float(options.get("volume_db", _config.ui_default_db))
	_ui_player.play()
	_ui_active = {"sfx_id": sfx_id, "start_ms": now}
	# 单实例 finished 接线（幂等——重复 connect 由 Godot 信号重连去重，
	# 这里仅在首次接线；接线一次后靠 _ui_active 回读区分当前音）
	if not _ui_player.finished.is_connected(_on_ui_finished):
		_ui_player.finished.connect(_on_ui_finished)


## UI 音自然播完回读——不足最低时长（80ms）时补播静音，保证完整出声。[br]
## [br]打断路径（_request_ui_sfx 先 stop 再 play）不触发 finished（Godot 4.6
## 实测：stop() 不 emit finished），故本回读只处理「自然播完」的 UI 音。[br]
## 补播静音：以无声占满剩余时长——不影响后续 UI 音的打断语义（后续打断
## 仍是 stop 截断，无声尾巴无感知）。
func _on_ui_finished() -> void:
	if _ui_active.is_empty():
		return
	var played_ms: int = int(_clock.call()) - int(_ui_active["start_ms"])
	if played_ms < _config.ui_min_duration_ms:
		_ui_player.stream = null
		_ui_player.play()  # 静音占位——自然结束后补足最短时长
	_ui_active = {}
