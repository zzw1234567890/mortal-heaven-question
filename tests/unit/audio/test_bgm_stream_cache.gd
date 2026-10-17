extends GutTest
## audio-manager Story 002 单元测试：BGM 流缓存（AC-8）。
##
## QA 规格：异步预加载幂等 / 缓存命中免重复加载 / 常驻 ≤2 逐出 /
## 损坏路径返回 null（边缘 #1）。
##
## Story 类型 Logic——此文件为 BLOCKING 证据。
## 风格先例：tests/unit/audio/test_bgm_fade_planner.gd。

const CacheScript := preload("res://src/ui/audio/bgm_stream_cache.gd")

## R-06 spike 真实资产（已过导入周期——headless GUT 可加载）。
const WAV_A: String = "res://prototypes/r06-ogg-loop-spike/test-tone.wav"
const WAV_B: String = "res://prototypes/r06-ogg-loop-spike/test-tone.ogg"


## 构造缓存实例（注入真实资产路径覆盖表）。
func _make_cache() -> RefCounted:
	return CacheScript.new({
		&"bgm_a": WAV_A,
		&"bgm_b": WAV_B,
		&"bgm_broken": "res://.gut_cache_nonexistent.wav",
	})


func test_resolve_cold_path_loads_and_caches() -> void:
	# Given: 冷缓存 + 真实资产路径
	var cache: RefCounted = _make_cache()
	# When: 首次 resolve
	var stream: AudioStream = cache.resolve(&"bgm_a")
	# Then: 加载成功 + 进入缓存（二次命中同对象）
	assert_not_null(stream, "真实 WAV 应加载成功")
	assert_true(cache.cached_ids().has(&"bgm_a"), "resolve 后应进入缓存")
	var again: AudioStream = cache.resolve(&"bgm_a")
	assert_eq(again, stream, "缓存命中应返回同一流对象（免重复加载）")


func test_resolve_missing_mapping_returns_null() -> void:
	# Edge: 无路径映射（边缘 #1）
	var cache: RefCounted = _make_cache()
	var stream: AudioStream = cache.resolve(&"bgm_unknown")
	assert_null(stream, "无映射应返回 null（保留旧曲语义）")


func test_resolve_corrupt_path_returns_null() -> void:
	# Edge: 路径不存在（边缘 #1）
	var cache: RefCounted = _make_cache()
	var stream: AudioStream = cache.resolve(&"bgm_broken")
	assert_null(stream, "损坏路径应返回 null 且不崩溃")


func test_preload_bgm_idempotent_and_cached() -> void:
	# Given: 冷缓存
	var cache: RefCounted = _make_cache()
	# When: 预加载两次（幂等）+ resolve
	cache.preload_bgm(&"bgm_a")
	cache.preload_bgm(&"bgm_a")
	var stream: AudioStream = cache.resolve(&"bgm_a")
	# Then: resolve 消费在途请求成功 + 缓存命中
	assert_not_null(stream, "预加载后 resolve 应成功")
	assert_true(cache.cached_ids().has(&"bgm_a"), "应进入缓存")


func test_trim_evicts_beyond_capacity() -> void:
	# Given: 三首入缓存（常驻上限 2——当前 + 预加载下一首）
	var cache: RefCounted = CacheScript.new({
		&"bgm_a": WAV_A,
		&"bgm_b": WAV_B,
		&"bgm_c": WAV_A,
	})
	cache.resolve(&"bgm_a")
	cache.resolve(&"bgm_b")
	cache.resolve(&"bgm_c")
	# When: set_current(bgm_a) 置保留头 + trim
	cache.set_current(&"bgm_a")
	cache.trim()
	# Then: a（当前）保留；常驻 ≤2（guardrail）
	assert_true(cache.cached_ids().has(&"bgm_a"), "当前曲应保留")
	assert_eq(cache.cached_ids().size() <= 2, true, "常驻 ≤2（guardrail）")
	# Then: 逐出条目可重新加载（引用语义释放）
	var evicted: StringName = &""
	for bgm_id: StringName in [&"bgm_b", &"bgm_c"]:
		if not cache.cached_ids().has(bgm_id):
			evicted = bgm_id
			break
	assert_ne(evicted, &"", "至少一首被逐出")
	var stream: AudioStream = cache.resolve(evicted)
	assert_not_null(stream, "逐出后重加载应成功")


func test_current_and_preload_both_kept() -> void:
	# Given: 当前 + 预加载 = 恰好容量 2
	var cache: RefCounted = _make_cache()
	cache.resolve(&"bgm_a")
	cache.set_current(&"bgm_a")
	cache.preload_bgm(&"bgm_b")
	cache.resolve(&"bgm_b")
	# When: trim
	cache.trim()
	# Then: 两首均保留（≤2 合规）
	assert_true(cache.cached_ids().has(&"bgm_a"), "当前曲保留")
	assert_true(cache.cached_ids().has(&"bgm_b"), "预加载曲保留")
	assert_eq(cache.cached_ids().size() <= 2, true, "常驻 ≤2（guardrail）")
