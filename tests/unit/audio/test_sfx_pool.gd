extends GutTest
## audio-manager Story 003 单元测试：SFX 池 Logic 内核（AC-1~AC-8）。
##
## QA 规格（story「QA Test Cases」逐条）：[br]
##   - AC-1 冷却窗口内丢弃（AC-SFX-04）[br]
##   - AC-2 冷却到期接受（AC-SFX-05，49/50 分界）[br]
##   - AC-3 池满淘汰——优先级然后年龄（AC-SFX-02）[br]
##   - AC-4 全优先级 2 拒绝（AC-SFX-03）[br]
##   - AC-5 随机化范围（AC-SFX-01，同种子可复现 + options 覆盖）[br]
##   - AC-6 战斗攻击门控（AC-SFX-06，99/100 分界 + 非攻击不受门控）[br]
##   - AC-7 缺失资源静默失败（AC-SFX-07 + 边缘 #15 标记不可用）[br]
##   - AC-8 UI 音效打断 + 80ms 最低时长（GDD §7）[br]
##
## [b]注入策略[/b]：[br]
##   - 时间：可变 [code]var t[/code] + 闭包 [code]func(): return t[/code][br]
##   - RNG：[code]RandomNumberGenerator[/code] 固定种子（AC-5 可复现）[br]
##   - 节点池：程序生成 16 个 [code]AudioStreamPlayer.new()[/code]（
##     [code]add_child_autofree[/code] 挂测试场景树——出树 play() 不置
##     playing=true），纯逻辑断言 playing/active_count/信号发射）[br]
##
## Story 类型 Logic——此文件为 BLOCKING 证据。
## 风格先例：tests/unit/audio/test_bgm_stream_cache.gd。

const SfxPoolScript := preload("res://src/ui/audio/sfx_pool.gd")

## 固定种子（AC-5 复现断言依赖——改变需同步 AC-5 期望值）。
const FIXED_SEED: int = 42

## 默认配置池节点数（GDD：16 = 12 活跃 + 4 余量）——测试注入节点池规模。
const POOL_SIZE: int = 16


## 可变时钟源——测试推进时间（arrange/act 间赋值 t 模拟流逝）。
var t: int = 0

## 冷却/攻击门控专用可变时钟（独立于 t，避免单一时钟在多场景间串扰）。
var _gate_t: int = 0


## 程序生成一个有效 AudioStreamWAV（无声 8kHz 16-bit 单声道——快速可播）。
func _make_stream() -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 8000
	wav.stereo = false
	var pcm := PackedByteArray()
	pcm.resize(4000)
	wav.data = pcm
	return wav


## 程序生成 n 个 AudioStreamPlayer（挂测试场景树——出树节点 play() 不置
## playing=true（引擎 4.6 实测「Playback can only happen when a node is inside
## the scene tree」），故须 add_child_autofree 挂树）。
func _make_players(n: int) -> Array[AudioStreamPlayer]:
	var players: Array[AudioStreamPlayer] = []
	for i: int in n:
		var p := AudioStreamPlayer.new()
		p.name = "sfx_player_%d" % i
		add_child_autofree(p)
		players.append(p)
	return players


## 构造 SfxPool：时钟注入 t 闭包 + 固定种子 RNG + 空流解析映射。
func _make_pool() -> RefCounted:
	var rng := RandomNumberGenerator.new()
	rng.seed = FIXED_SEED
	var pool: RefCounted = SfxPoolScript.new(
		func() -> int: return t, rng)
	pool.set_stream_resolver(_resolver_of({}))
	return pool


## 流解析器工厂：映射表 {sfx_id: AudioStream}，未命中返回 null（静默丢弃）。
func _resolver_of(map: Dictionary) -> Callable:
	return func(sfx_id: StringName) -> AudioStream:
		return map.get(sfx_id, null)


## 注入 16 节点池并设置 ui 播放器（返回 pool）。
func _wire_pool(pool: RefCounted, ui_player: AudioStreamPlayer = null) -> RefCounted:
	pool.set_pool_nodes(_make_players(POOL_SIZE))
	if ui_player != null:
		pool.set_ui_player(ui_player)
	return pool


## 用固定 RNG 重建 pool（AC-5 复现：同种子两次实例同值）。
func _rebuild_pool_with_seed(seed: int, map: Dictionary) -> RefCounted:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var pool: RefCounted = SfxPoolScript.new(
		func() -> int: return t, rng)
	pool.set_stream_resolver(_resolver_of(map))
	pool.set_pool_nodes(_make_players(POOL_SIZE))
	return pool


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1：冷却窗口内丢弃（AC-SFX-04）
# ═══════════════════════════════════════════════════════════════════════════════

func test_cooldown_within_window_discards_and_emits_signal() -> void:
	# Given: t=0 时 play("sword_hit") 成功
	t = 0
	var pool: RefCounted = _wire_pool(_make_pool())
	pool.set_stream_resolver(_resolver_of({&"sword_hit": _make_stream()}))
	pool.request_sfx(&"sword_hit")
	var active_after_first: int = pool.active_count()
	assert_eq(active_after_first, 1, "首次播放应占用 1 槽")
	watch_signals(pool)
	# When: t=30 再次 play（窗口内 elapsed=30 < 50）
	t = 30
	pool.request_sfx(&"sword_hit")
	# Then: 不分配播放器、emit sfx_cooldown_discarded("sword_hit", 30)、active 不变
	assert_eq(pool.active_count(), 1, "窗口内请求不新增活跃槽")
	assert_signal_emitted_with_parameters(pool, "sfx_cooldown_discarded",
			[&"sword_hit", 30])
	# Edge: 窗口内第 3 次请求同样丢弃
	t = 45
	pool.request_sfx(&"sword_hit")
	assert_eq(pool.active_count(), 1, "窗口内第 3 次请求同样丢弃")
	assert_signal_emit_count(pool, "sfx_cooldown_discarded", 2,
			"窗口内两次丢弃各发射一次信号")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-2：冷却到期接受（AC-SFX-05）
# ═══════════════════════════════════════════════════════════════════════════════

func test_cooldown_expired_at_boundary_accepted_and_reset() -> void:
	# Given: t=0 播放
	t = 0
	var pool: RefCounted = _wire_pool(_make_pool())
	pool.set_stream_resolver(_resolver_of({&"sword_hit": _make_stream()}))
	pool.request_sfx(&"sword_hit")
	watch_signals(pool)
	# When: t=50（恰为边界）再次请求
	t = 50
	pool.request_sfx(&"sword_hit")
	# Then: 正常播放（新占一槽——同一 sfx_id 可并行占用多槽，GDD 无同 id 互斥）
	assert_eq(pool.active_count(), 2, "50ms 边界请求应正常播放")
	assert_signal_emit_count(pool, "sfx_cooldown_discarded", 0,
			"边界请求不应触发冷却丢弃信号")
	# Then: 计时器重置——t=80（距第二次 30ms）再次请求应丢弃
	t = 80
	pool.request_sfx(&"sword_hit")
	assert_signal_emit_count(pool, "sfx_cooldown_discarded", 1,
			"重置后窗口内请求应再次丢弃（计时器已重置为 50）")


func test_cooldown_boundary_49_discard_50_accept() -> void:
	# Edge: 49ms（丢弃）与 50ms（接受）分界
	var pool49: RefCounted = _wire_pool(_make_pool())
	pool49.set_stream_resolver(_resolver_of({&"sword_hit": _make_stream()}))
	t = 0
	pool49.request_sfx(&"sword_hit")
	watch_signals(pool49)
	t = 49
	pool49.request_sfx(&"sword_hit")
	assert_signal_emit_count(pool49, "sfx_cooldown_discarded", 1,
			"49ms 应丢弃")

	var pool50: RefCounted = _wire_pool(_make_pool())
	pool50.set_stream_resolver(_resolver_of({&"sword_hit": _make_stream()}))
	t = 0
	pool50.request_sfx(&"sword_hit")
	watch_signals(pool50)
	t = 50
	pool50.request_sfx(&"sword_hit")
	assert_signal_emit_count(pool50, "sfx_cooldown_discarded", 0,
			"50ms 应接受")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-3：池满淘汰——优先级然后年龄（AC-SFX-02）
# ═══════════════════════════════════════════════════════════════════════════════

func _fill_slots(pool: RefCounted, entries: Array) -> void:
	## 辅助：按 entries 依次填充池（每条 [sfx_id, priority, start_ms]）。
	## 时钟推进用 _gate_t 独立变量（不污染主 t 断言）。
	for e: Array in entries:
		_gate_t = int(e[2])
		pool.request_sfx(e[0], {"eviction_priority": int(e[1])})


func _make_gated_pool() -> RefCounted:
	## 辅助：构造使用独立 _gate_t 时钟的 pool（AC-3/AC-4 专用——
	## 填充阶段与断言阶段时钟同源，控制 start_ms 精确分布）。
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var pool: RefCounted = SfxPoolScript.new(
		func() -> int: return _gate_t, rng)
	pool.set_stream_resolver(_resolver_of({
		&"deco_a": _make_stream(), &"deco_b": _make_stream(),
		&"func_a": _make_stream(), &"func_b": _make_stream(),
		&"func_c": _make_stream(), &"crit_a": _make_stream(),
		&"crit_b": _make_stream(), &"crit_c": _make_stream(),
		&"crit_d": _make_stream(), &"crit_e": _make_stream(),
		&"crit_f": _make_stream(), &"crit_g": _make_stream(),
		&"crit_h": _make_stream(), &"crit_i": _make_stream(),
		&"crit_j": _make_stream(), &"crit_k": _make_stream(),
		&"crit_l": _make_stream(),
		&"new_prio_2": _make_stream(), &"new_prio_1": _make_stream(),
	}))
	pool.set_pool_nodes(_make_players(POOL_SIZE))
	return pool


func test_eviction_priority_then_age_lowest_oldest_stopped() -> void:
	# Given: 12 槽满（2 个 prio0 于 t=0/t=100，3 个 prio1，7 个 prio2）
	_gate_t = 0
	var pool: RefCounted = _make_gated_pool()
	var entries: Array = [
		[&"deco_a", 0, 0], [&"deco_b", 0, 100],
		[&"func_a", 1, 200], [&"func_b", 1, 300], [&"func_c", 1, 400],
		[&"crit_a", 2, 500], [&"crit_b", 2, 600], [&"crit_c", 2, 700],
		[&"crit_d", 2, 800], [&"crit_e", 2, 900], [&"crit_f", 2, 1000],
		[&"crit_g", 2, 1100],
	]
	_fill_slots(pool, entries)
	assert_eq(pool.active_count(), 12, "前置：12 槽满")
	var deco_a_player: AudioStreamPlayer = pool.node_at(0)
	assert_true(deco_a_player.playing, "前置：deco_a 在播")
	var victim_stream_before: AudioStream = deco_a_player.stream
	# When: 新请求 prio 2（时钟推进到 1200，越过所有冷却）
	_gate_t = 1200
	watch_signals(pool)
	pool.request_sfx(&"new_prio_2", {"eviction_priority": 2})
	# Then: t=0 的 prio0（deco_a）被淘汰——其播放器复用承载新 SFX 流
	# （stop→play 同步完成，中间态不可观测；以流替换 + 复播为可观测证据）
	assert_ne(deco_a_player.stream, victim_stream_before,
			"牺牲者 deco_a 播放器应复用并承载新 SFX 流")
	assert_true(deco_a_player.playing, "牺牲者播放器应复用并播放新 SFX")
	assert_eq(pool.active_count(), 12, "淘汰后活跃槽仍为 12（复用不新增）")
	assert_signal_emit_count(pool, "sfx_pool_exhausted", 0,
			"优先级更高不应触发 exhausted 信号")


func test_eviction_candidate_same_priority_rejected() -> void:
	# Edge: 候选与请求优先级相同时拒绝（AC-SFX-02 edge「候选与请求优先级相同时拒绝」）
	_gate_t = 0
	var pool: RefCounted = _make_gated_pool()
	# 1 个 prio1 + 11 个 prio2 制造唯一最低候选 func_a
	var entries: Array = [
		[&"func_a", 1, 0],
		[&"crit_a", 2, 100], [&"crit_b", 2, 200], [&"crit_c", 2, 300],
		[&"crit_d", 2, 400], [&"crit_e", 2, 500], [&"crit_f", 2, 600],
		[&"crit_g", 2, 700], [&"crit_h", 2, 800], [&"crit_i", 2, 900],
		[&"crit_j", 2, 1000], [&"crit_k", 2, 1100],
	]
	_fill_slots(pool, entries)
	assert_eq(pool.active_count(), 12, "前置：12 槽满")
	_gate_t = 1200
	watch_signals(pool)
	# When: 新请求 prio1（与最低候选 func_a 优先级相同）
	pool.request_sfx(&"new_prio_1", {"eviction_priority": 1})
	# Then: 拒绝 + 无播放器状态变化
	assert_signal_emit_count(pool, "sfx_pool_exhausted", 1,
			"优先级相同应拒绝 + sfx_pool_exhausted")
	assert_true(pool.node_at(0).playing, "func_a 播放器状态不变（未被淘汰）")
	assert_eq(pool.active_count(), 12, "拒绝后活跃槽不变")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-4：全优先级 2 拒绝（AC-SFX-03）
# ═══════════════════════════════════════════════════════════════════════════════

func test_all_critical_rejects_thirteenth_request() -> void:
	# Given: 12 槽全为 prio2（crit_a~crit_l 全部在 resolver 映射中）
	_gate_t = 0
	var pool: RefCounted = _make_gated_pool()
	var crit_ids: Array[StringName] = [
		&"crit_a", &"crit_b", &"crit_c", &"crit_d", &"crit_e", &"crit_f",
		&"crit_g", &"crit_h", &"crit_i", &"crit_j", &"crit_k", &"crit_l"]
	var entries: Array = []
	for i: int in crit_ids.size():
		entries.append([crit_ids[i], 2, i * 100])
	_fill_slots(pool, entries)
	assert_eq(pool.active_count(), 12, "前置：12 槽全优先级 2")
	# When: 第 13 个请求（prio2）
	_gate_t = 1300
	watch_signals(pool)
	pool.request_sfx(&"new_prio_2", {"eviction_priority": 2})
	# Then: 拒绝 + sfx_pool_exhausted + 无播放器状态变化
	assert_signal_emit_count(pool, "sfx_pool_exhausted", 1,
			"全优先级 2 应拒绝 + sfx_pool_exhausted(sfx_id)")
	assert_eq(pool.active_count(), 12, "拒绝后活跃槽不变")
	assert_true(pool.node_at(0).playing, "首个播放器状态不变")
	assert_true(pool.node_at(11).playing, "末个播放器状态不变")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-5：随机化范围（AC-SFX-01）
# ═══════════════════════════════════════════════════════════════════════════════

func test_randomization_range_and_same_seed_reproducible() -> void:
	# Given: 注入固定 RNG 种子（42）两次独立实例
	t = 0
	var pool_a: RefCounted = _rebuild_pool_with_seed(FIXED_SEED,
			{&"card_play_gongfa": _make_stream()})
	var pool_b: RefCounted = _rebuild_pool_with_seed(FIXED_SEED,
			{&"card_play_gongfa": _make_stream()})
	# When: play("card_play_gongfa")
	pool_a.request_sfx(&"card_play_gongfa")
	pool_b.request_sfx(&"card_play_gongfa")
	var player_a: AudioStreamPlayer = pool_a.node_at(0)
	var player_b: AudioStreamPlayer = pool_b.node_at(0)
	# Then: pitch ∈ [0.9, 1.1]，volume_db ∈ [-6, 0]，同种子可复现
	assert_between(player_a.pitch_scale, 0.9, 1.1,
			"pitch_scale 应在 [0.9, 1.1]")
	assert_between(player_a.volume_db, -6.0, 0.0,
			"volume_db 应在 [-6, 0]")
	assert_almost_eq(player_a.pitch_scale, player_b.pitch_scale, 0.0001,
			"同种子 pitch 可复现")
	assert_almost_eq(player_a.volume_db, player_b.volume_db, 0.0001,
			"同种子 volume 可复现")


func test_randomization_options_override_no_randomize() -> void:
	# Edge: options 显式覆盖（不随机化）
	t = 0
	var pool: RefCounted = _wire_pool(_make_pool())
	pool.set_stream_resolver(_resolver_of({&"card_play_gongfa": _make_stream()}))
	# When: options 传 pitch=1.5 / volume_db=-3.5（超出随机范围——证明未随机化）
	pool.request_sfx(&"card_play_gongfa", {"pitch": 1.5, "volume_db": -3.5})
	var player: AudioStreamPlayer = pool.node_at(0)
	# Then: 精确等于显式值（非随机）
	assert_almost_eq(player.pitch_scale, 1.5, 0.0001,
			"显式 pitch 应精确覆盖（不随机化）")
	assert_almost_eq(player.volume_db, -3.5, 0.0001,
			"显式 volume_db 应精确覆盖（不随机化）")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-6：战斗攻击门控（AC-SFX-06）
# ═══════════════════════════════════════════════════════════════════════════════

func test_attack_gating_99_discard_100_pass() -> void:
	# Given: is_attack_sfx 请求于 t=0
	t = 0
	var pool: RefCounted = _wire_pool(_make_pool())
	pool.set_stream_resolver(_resolver_of({&"attack_hit": _make_stream()}))
	pool.request_sfx(&"attack_hit", {"is_attack_sfx": true})
	assert_eq(pool.active_count(), 1, "首次攻击 SFX 应播放")
	# When: 同类请求于 t=99 / t=100
	t = 99
	pool.request_sfx(&"attack_hit", {"is_attack_sfx": true})
	assert_eq(pool.active_count(), 1, "99ms 内同类攻击应被门控丢弃")
	t = 100
	pool.request_sfx(&"attack_hit", {"is_attack_sfx": true})
	assert_eq(pool.active_count(), 2, "100ms 边界应通过（门控窗口已过）")


func test_attack_gating_non_attack_sfx_not_gated() -> void:
	# Edge: 非攻击 SFX 不受 100ms 门控
	t = 0
	var pool: RefCounted = _wire_pool(_make_pool())
	pool.set_stream_resolver(_resolver_of({
		&"attack_hit": _make_stream(), &"sword_hit": _make_stream()}))
	pool.request_sfx(&"attack_hit", {"is_attack_sfx": true})
	# When: 10ms 后非攻击 SFX（不同 id，冷却互不影响）
	t = 10
	pool.request_sfx(&"sword_hit")
	# Then: 正常播放（不受攻击门控）
	assert_eq(pool.active_count(), 2, "非攻击 SFX 不受攻击门控")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-7：缺失资源静默失败（AC-SFX-07）
# ═══════════════════════════════════════════════════════════════════════════════

func test_missing_resource_silent_fail_no_pool_impact() -> void:
	# Given: resolver 无 missing_sfx 映射
	t = 0
	var pool: RefCounted = _wire_pool(_make_pool())
	pool.set_stream_resolver(_resolver_of({&"sword_hit": _make_stream()}))
	# When: play("missing_sfx")
	pool.request_sfx(&"missing_sfx")
	# Then: 无崩溃、无播放器分配、push_warning 记录、后续 play 正常
	assert_eq(pool.active_count(), 0, "缺失资源不分配播放器")
	assert_push_warning_count(1, "缺失资源应 push_warning 一次")
	pool.request_sfx(&"sword_hit")
	assert_eq(pool.active_count(), 1, "后续正常 play 不受影响")


func test_missing_resource_warns_once_then_silent() -> void:
	# Edge: 同一缺失 id 第二次请求不再刷 warning（去重）
	t = 0
	var pool: RefCounted = _wire_pool(_make_pool())
	pool.request_sfx(&"missing_sfx")
	pool.request_sfx(&"missing_sfx")
	assert_push_warning_count(1, "同一缺失 id 只 push_warning 一次")


func test_missing_resource_marked_unavailable_silent_discard() -> void:
	# Edge #15: 标记不可用的资源（resolver 返回 null——模拟加载失败标记）同样静默丢弃
	t = 0
	var pool: RefCounted = _wire_pool(_make_pool())
	pool.set_stream_resolver(_resolver_of({&"broken_sfx": null}))
	pool.request_sfx(&"broken_sfx")
	assert_eq(pool.active_count(), 0, "不可用资源静默丢弃")
	assert_push_warning_count(1, "不可用资源 push_warning 一次")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-8：UI 音效打断 + 80ms 最低时长（GDD §7）
# ═══════════════════════════════════════════════════════════════════════════════

func test_ui_sfx_interrupt_old_and_play_new() -> void:
	# Given: UI 确认音正在播放（bus=UI 走独立单实例槽）
	t = 0
	var ui_player: AudioStreamPlayer = add_child_autofree(AudioStreamPlayer.new())
	var pool: RefCounted = _wire_pool(_make_pool(), ui_player)
	pool.set_stream_resolver(_resolver_of({
		&"ui_confirm": _make_stream(), &"ui_cancel": _make_stream()}))
	pool.request_sfx(&"ui_confirm", {"bus": AudioEnums.AudioBus.UI})
	assert_true(ui_player.playing, "UI 确认音应在播")
	assert_eq(pool.active_count(), 0, "UI 音不参与通用池（active_count 不变）")
	var first_stream: AudioStream = ui_player.stream
	# When: 30ms 后新 UI 取消音请求
	t = 30
	pool.request_sfx(&"ui_cancel", {"bus": AudioEnums.AudioBus.UI})
	# Then: 旧 UI 音被打断（stop 截断），新音播放
	assert_true(ui_player.playing, "新 UI 音应播放")
	assert_ne(ui_player.stream, first_stream, "新 UI 音应替换旧音流")
	assert_eq(pool.active_count(), 0, "UI 打断不触碰通用池")


func test_ui_sfx_single_instance_last_audible_full() -> void:
	# Edge: 快速连续 3 个 UI 音（仅最后一个可听全）——单实例槽互斥
	t = 0
	var ui_player: AudioStreamPlayer = add_child_autofree(AudioStreamPlayer.new())
	var pool: RefCounted = _wire_pool(_make_pool(), ui_player)
	pool.set_stream_resolver(_resolver_of({
		&"ui_a": _make_stream(), &"ui_b": _make_stream(), &"ui_c": _make_stream()}))
	pool.request_sfx(&"ui_a", {"bus": AudioEnums.AudioBus.UI})
	var stream_a: AudioStream = ui_player.stream
	t = 10
	pool.request_sfx(&"ui_b", {"bus": AudioEnums.AudioBus.UI})
	var stream_b: AudioStream = ui_player.stream
	t = 20
	pool.request_sfx(&"ui_c", {"bus": AudioEnums.AudioBus.UI})
	# Then: 每次新 UI 音替换旧音流（单实例槽互斥）
	assert_ne(stream_b, stream_a, "ui_b 应替换 ui_a")
	assert_ne(ui_player.stream, stream_b, "ui_c 应替换 ui_b")
	assert_true(ui_player.playing, "最后一个 UI 音在播")
	# 80ms 最低时长保证：最后一个音起播于 t=20，时间未满 80ms——
	# 自然播完回读会补静音（finished 路径），但打断路径不触发 finished，
	# 故此处只断言「未被截断状态」——完整播出由自然播完保证
	assert_eq(pool.active_count(), 0, "UI 音全程不参与通用池")


func test_ui_sfx_without_player_noop_no_crash() -> void:
	# Edge: 无 UI 槽（单元测试直建场景）——UI 音请求 no-op 不崩溃
	t = 0
	var pool: RefCounted = _wire_pool(_make_pool(), null)
	pool.set_stream_resolver(_resolver_of({&"ui_confirm": _make_stream()}))
	pool.request_sfx(&"ui_confirm", {"bus": AudioEnums.AudioBus.UI})
	assert_true(true, "无 UI 槽时 UI 音请求 no-op 不崩溃")


func test_ui_sfx_natural_finish_below_min_duration_replays_silence() -> void:
	# AC-8 最低时长保证：自然播完不足 80ms → 补播静音（stream 置 null）。
	# 打断路径（stop→play）不触发 finished，故「自然播完回读」分支只能
	# 手动 emit finished 驱动——这是唯一能触达 _on_ui_finished 的路径。
	# Given: UI 音起播于 t=0
	t = 0
	var ui_player: AudioStreamPlayer = add_child_autofree(AudioStreamPlayer.new())
	var pool: RefCounted = _wire_pool(_make_pool(), ui_player)
	pool.set_stream_resolver(_resolver_of({&"ui_a": _make_stream()}))
	pool.request_sfx(&"ui_a", {"bus": AudioEnums.AudioBus.UI})
	assert_not_null(ui_player.stream, "前置：UI 音已赋流")
	# When: 30ms 后自然播完（不足 80ms 最低时长）
	t = 30
	ui_player.finished.emit()
	# Then: 补播静音——stream 置 null（占位无声）
	assert_null(ui_player.stream, "不足 80ms 自然播完应补播静音（stream 置 null）")


func test_ui_sfx_natural_finish_at_min_duration_no_silence() -> void:
	# AC-8 最低时长边界：自然播完 >= 80ms → 不补播静音（流保留）
	# Given: UI 音起播于 t=0
	t = 0
	var ui_player: AudioStreamPlayer = add_child_autofree(AudioStreamPlayer.new())
	var pool: RefCounted = _wire_pool(_make_pool(), ui_player)
	pool.set_stream_resolver(_resolver_of({&"ui_b": _make_stream()}))
	pool.request_sfx(&"ui_b", {"bus": AudioEnums.AudioBus.UI})
	var stream_before: AudioStream = ui_player.stream
	# When: 100ms 后自然播完（>= 80ms 最低时长）
	t = 100
	ui_player.finished.emit()
	# Then: 不补播静音——流保留
	assert_eq(ui_player.stream, stream_before, ">=80ms 自然播完不补播静音（流保留）")


# ═══════════════════════════════════════════════════════════════════════════════
# 补充：池空守卫（AudioManager 单元测试直建场景 null scene_manager）
# ═══════════════════════════════════════════════════════════════════════════════

func test_empty_pool_request_noop_no_crash() -> void:
	# Edge: 未注入节点池（AudioManager null scene_manager 直建场景）——no-op 不崩溃
	t = 0
	var pool: RefCounted = _make_pool()
	pool.set_stream_resolver(_resolver_of({&"sword_hit": _make_stream()}))
	pool.request_sfx(&"sword_hit")
	assert_true(true, "空池请求 no-op 不崩溃")
