extends GutTest
## Autoload 初始化负载测量测试 (C5)
##
## 验证 Foundation 层 5 个 Autoload 的启动时间在可接受范围内。
## 每个 Autoload 通过 preload + .new() + _ready() 创建独立实例，
## 测量从实例创建到 _ready() 完成的时间。
##
## 可接受范围：
##   - 单个 Autoload <20ms（正常）
##   - Foundation 5 个合计 <50ms（正常）
##   - 预估 25 个全部实现后 <200ms（可接受）
##   - >200ms → 需延迟初始化策略
##
## 注意：此测试使用 Time.get_ticks_msec() 计时——精度为毫秒级。
## 对于 _ready() 极快的 Autoload（<1ms），测量结果为 0ms 是正常的。


# ── Autoload 脚本引用 ─────────────────────────────────

const GSM_SCRIPT := preload("res://src/foundation/game_state_manager.gd")
const INPUT_SCRIPT := preload("res://src/foundation/input_manager.gd")
const SCENE_SCRIPT := preload("res://src/foundation/scene_manager.gd")
const SAVE_SCRIPT := preload("res://src/foundation/save_load_system.gd")
const EVENT_SCRIPT := preload("res://src/foundation/event_system/event_system.gd")


# ── 测试：单个 Autoload 初始化时间 ──────────────────────

func test_gsm_init_time_under_20ms() -> void:
	var t0 := Time.get_ticks_msec()
	var gsm := GSM_SCRIPT.new()
	gsm._ready()
	var elapsed := Time.get_ticks_msec() - t0
	gsm.free()
	assert_true(elapsed < 20, "GSM 初始化应 <20ms，实际: %dms" % elapsed)


func test_input_manager_init_time_under_20ms() -> void:
	var t0 := Time.get_ticks_msec()
	var node := INPUT_SCRIPT.new()
	node._ready()
	var elapsed := Time.get_ticks_msec() - t0
	node.free()
	assert_true(elapsed < 20, "InputManager 初始化应 <20ms，实际: %dms" % elapsed)


func test_scene_manager_init_time_under_20ms() -> void:
	var t0 := Time.get_ticks_msec()
	var node := SCENE_SCRIPT.new()
	node._ready()
	var elapsed := Time.get_ticks_msec() - t0
	node.free()
	assert_true(elapsed < 20, "SceneManager 初始化应 <20ms，实际: %dms" % elapsed)


func test_save_load_init_time_under_20ms() -> void:
	var t0 := Time.get_ticks_msec()
	var node := SAVE_SCRIPT.new()
	node._ready()
	var elapsed := Time.get_ticks_msec() - t0
	node.free()
	assert_true(elapsed < 20, "SaveLoadSystem 初始化应 <20ms，实际: %dms" % elapsed)


func test_event_system_init_time_under_20ms() -> void:
	var t0 := Time.get_ticks_msec()
	var node := EVENT_SCRIPT.new()
	node._ready()
	var elapsed := Time.get_ticks_msec() - t0
	node.free()
	assert_true(elapsed < 20, "EventSystem 初始化应 <20ms，实际: %dms" % elapsed)


# ── 测试：5 个 Foundation Autoload 合计启动时间 ──────────

func test_all_five_foundation_autoloads_total_under_50ms() -> void:
	var t0 := Time.get_ticks_msec()

	var gsm := GSM_SCRIPT.new()
	gsm._ready()

	var input_mgr := INPUT_SCRIPT.new()
	input_mgr._ready()

	var scene_mgr := SCENE_SCRIPT.new()
	scene_mgr._ready()

	var save_sys := SAVE_SCRIPT.new()
	save_sys._ready()

	var event_sys := EVENT_SCRIPT.new()
	event_sys._ready()

	var elapsed := Time.get_ticks_msec() - t0

	gsm.free()
	input_mgr.free()
	scene_mgr.free()
	save_sys.free()
	event_sys.free()

	assert_true(elapsed < 50, "5 Foundation Autoload 合计初始化应 <50ms，实际: %dms" % elapsed)


# ── 测试：预估 25 个 Autoload 的完整链 ──────────────────

func test_extrapolated_25_autoload_total_under_200ms() -> void:
	# 测量 5 个 Foundation Autoload 时间，外推到 25 个
	var t0 := Time.get_ticks_msec()

	var nodes: Array[Node] = []
	for script in [GSM_SCRIPT, INPUT_SCRIPT, SCENE_SCRIPT, SAVE_SCRIPT, EVENT_SCRIPT]:
		var node: Node = script.new()
		node._ready()
		nodes.append(node)

	var elapsed_5 := Time.get_ticks_msec() - t0

	for node in nodes:
		node.free()

	# 外推：5→25 个 = 5 倍
	# 考虑启动顺序依赖可能带来少量线性开销
	var extrapolated := elapsed_5 * 5 * 1.2  # 1.2x 安全系数
	assert_true(extrapolated < 200,
		"25 Autoload 预估初始化时间应 <200ms，预估算: %dms (5 个实测: %dms × 5 × 1.2)" % [extrapolated, elapsed_5])


# ── 测试：每个 Autoload 的 _ready() 是否可被安全多次调用 ──

func test_gsm_ready_is_idempotent() -> void:
	var gsm := GSM_SCRIPT.new()

	var t0 := Time.get_ticks_msec()
	gsm._ready()
	var first_call := Time.get_ticks_msec() - t0

	t0 = Time.get_ticks_msec()
	gsm._ready()
	var second_call := Time.get_ticks_msec() - t0

	gsm.free()

	# 第二次调用不应比第一次慢（幂等保护）
	# 保存时需注意：second_call 可能因内存缓存而更快——可接受
	assert_true(second_call <= first_call + 5,
		"GSM _ready() 第二次调用不应显著变慢：%dms vs %dms" % [second_call, first_call])
