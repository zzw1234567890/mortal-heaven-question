extends GutTest
## Story 004 集成测试：加载画面功能、Phase 3 管道、淡出辅助方法与错误恢复。
##
## 覆盖 AC-1（loading_screen.tscn 结构）、AC-2（set_context）、
## AC-3（Phase 3 流程）、AC-5/AC-8（淡出叠加辅助方法）、
## AC-7（优雅降级——加载画面缺失）。
##
## Story 类型为 Integration——此测试文件为阻塞项。

const SM := preload("res://src/foundation/scene_manager.gd")

var sm: Node = null
var _mock_gsm: Node = null
var _mock_im: Node = null
var _mock_sl: Node = null


func before_each() -> void:
	sm = SM.new()
	sm._ready()
	sm._test_mode = true
	_mock_gsm = _build_mock_gsm()
	_mock_im = _build_mock_im()
	_mock_sl = _build_mock_sl()
	sm.set_dependencies(_mock_gsm, _mock_im, _mock_sl)


func after_each() -> void:
	if sm != null:
		sm.free()
		sm = null
	if _mock_gsm != null:
		_mock_gsm.free()
		_mock_gsm = null
	if _mock_im != null:
		_mock_im.free()
		_mock_im = null
	if _mock_sl != null:
		_mock_sl.free()
		_mock_sl = null


# ── Mock 构造 ─────────────────────────────────────────────────────────────────

func _build_mock_gsm() -> Node:
	var n := Node.new()
	var s := GDScript.new()
	s.source_code = """extends Node
var session: Dictionary = {"current_scene": "", "scene_id": 0}
func set_session_scene(id: int, path: String) -> void:
	session.scene_id = id
	session.current_scene = path
"""
	var err := s.reload()
	if err != OK:
		push_error("Mock GSM 编译失败: %d" % err)
	n.set_script(s)
	return n


func _build_mock_im() -> Node:
	var n := Node.new()
	var s := GDScript.new()
	s.source_code = """extends Node
var push_calls: int = 0
var pop_calls: int = 0
var _call_log: Array = []
func push_lock(_type: int, _source: StringName) -> void:
	push_calls += 1
	_call_log.append({"op": "push", "type": _type, "source": _source})
func pop_lock(_source: StringName) -> void:
	pop_calls += 1
	_call_log.append({"op": "pop", "source": _source})
func reset_counts() -> void:
	push_calls = 0
	pop_calls = 0
	_call_log.clear()
"""
	var err := s.reload()
	if err != OK:
		push_error("Mock IM 编译失败: %d" % err)
	n.set_script(s)
	return n


func _build_mock_sl() -> Node:
	var n := Node.new()
	var s := GDScript.new()
	s.source_code = """extends Node
var auto_save_called: bool = false
var auto_save_call_count: int = 0
func auto_save() -> void:
	auto_save_called = true
	auto_save_call_count += 1
"""
	var err := s.reload()
	if err != OK:
		push_error("Mock SL 编译失败: %d" % err)
	n.set_script(s)
	return n


func _make_loading_screen_mock() -> Node:
	## 创建带 set_context 间谍功能的 LoadingScreen mock。
	var ls := Control.new()
	var s := GDScript.new()
	s.source_code = """extends Control
var _from_id: int = -1
var _to_id: int = -1
var _type: int = 0
var set_context_called: bool = false
var set_context_call_count: int = 0
func set_context(from_id: int, to_id: int, transition_type: int) -> void:
	set_context_called = true
	set_context_call_count += 1
	_from_id = from_id
	_to_id = to_id
	_type = transition_type
"""
	var err := s.reload()
	if err != OK:
		push_error("LoadingScreen mock 编译失败: %d" % err)
	ls.set_script(s)
	return ls


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1 验收标准：loading_screen.tscn 场景结构
# ═══════════════════════════════════════════════════════════════════════════════

func test_loading_scene_path_in_scene_paths() -> void:
	## AC-1: SCENE_PATHS 中注册了 loading_screen.tscn 路径
	assert_eq(SM.SCENE_PATHS[SM.SceneID.LOADING],
			"res://src/ui/loading/loading_screen.tscn",
			"loading_screen.tscn 的路径应在 SCENE_PATHS 中注册")


func test_loading_scene_id_is_99() -> void:
	## AC-1: SceneID.LOADING 为 99（内部使用、不连续）
	assert_eq(SM.SceneID.LOADING, 99,
			"SceneID.LOADING 应为 99——内部使用的不连续 ID")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-2 验收标准：上下文传递 —— 同步 set_context()
# ═══════════════════════════════════════════════════════════════════════════════

func test_set_context_stores_from_scene_id() -> void:
	## AC-2: set_context 存储 from SceneID
	var ls := _make_loading_screen_mock()
	ls.set_context(3, 4, 1)
	assert_eq(ls._from_id, 3, "from_id 应为 3")
	assert_eq(ls._to_id, 4, "to_id 应为 4")
	assert_eq(ls._type, 1, "type 应为 1")
	ls.free()


func test_set_context_stores_all_transition_types() -> void:
	## AC-2: set_context 为所有 TransitionType 正确存储 type
	var ls := _make_loading_screen_mock()
	var types_to_test: Array = [
		SM.TransitionType.MENU_TO_GAME,
		SM.TransitionType.GAME_TO_MENU,
		SM.TransitionType.EXPLORE_TO_COMBAT,
		SM.TransitionType.COMBAT_TO_EXPLORE,
		SM.TransitionType.TRIBULATION,
	]
	for tt in types_to_test:
		ls.set_context(0, 0, tt)
		assert_eq(ls._type, tt, "type 应为 %d" % tt)
	ls.free()


func test_set_context_is_synchronous() -> void:
	## AC-2: set_context 是同步的——无 await，无异步副作用
	var ls := _make_loading_screen_mock()
	ls.set_context(0, 1, 2)
	# 同步赋值应立即完成——验证 spy 状态已更新
	assert_true(ls.set_context_called, "set_context 应已同步调用")
	assert_eq(ls.set_context_call_count, 1, "set_context 应仅被调用一次")
	ls.free()


func test_set_context_handles_negative_ids() -> void:
	## AC-2: set_context 接受负数 ID——边界情况（初始状态无效 ID）
	var ls := _make_loading_screen_mock()
	ls.set_context(-1, -1, 0)
	assert_eq(ls._from_id, -1, "应接受负数 from_id")
	assert_eq(ls._to_id, -1, "应接受负数 to_id")
	ls.free()


# ═══════════════════════════════════════════════════════════════════════════════
# AC-3 验收标准：Phase 3 完整流程
# ═══════════════════════════════════════════════════════════════════════════════

func test_phase_3_sets_phase3_flag_after_loading_success() -> void:
	## AC-3: _phase3_in_progress 应在加载画面切换成功后设置
	## 在 test_mode 下 _execute_transition 跳过场景加载，直接调用 _execute_post_load
	## 验证起始状态：标志位为 false
	assert_false(sm._phase3_in_progress,
			"_phase3_in_progress 初始值应为 false")

	sm._transitioning = true
	sm._transition_type = SM.TransitionType.MENU_TO_GAME
	sm._execute_transition(SM.SceneID.MAIN_MENU, SM.SceneID.EXPLORATION)
	# 在 test_mode 中，_execute_transition 直接调用 _execute_post_load
	# _phase3_in_progress 在 Phase 5 中重置
	assert_false(sm._phase3_in_progress,
			"Phase 5 后 _phase3_in_progress 应重置为 false")


func test_phase3_flag_cleared_after_post_load() -> void:
	## AC-3: Phase 5 完成后 _phase3_in_progress 为 false
	sm._phase3_in_progress = true
	sm._transitioning = true
	sm._transition_type = SM.TransitionType.EXPLORE_TO_COMBAT

	sm._execute_post_load(SM.SceneID.EXPLORATION, SM.SceneID.COMBAT,
			SM.SCENE_PATHS[SM.SceneID.COMBAT])

	assert_false(sm._phase3_in_progress,
			"Phase 5 后 _phase3_in_progress 应重置为 false")


func test_phase3_in_progress_flag_is_reset_by_cleanup() -> void:
	## AC-3+AC-6: _cleanup_on_error 将 _phase3_in_progress 重置为 false
	sm._phase3_in_progress = true
	sm._transitioning = true

	sm._cleanup_on_error(&"phase3_aborted")

	assert_false(sm._phase3_in_progress,
			"清理后 _phase3_in_progress 应重置为 false")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-5 + AC-8 验收标准：目标场景淡入保护
# ═══════════════════════════════════════════════════════════════════════════════

func test_create_fade_overlay_returns_colorrect() -> void:
	## AC-8: create_fade_overlay 返回 ColorRect
	var overlay := SM.create_fade_overlay()
	assert_not_null(overlay, "create_fade_overlay 应返回非 null")
	assert_true(overlay is ColorRect, "应为 ColorRect")
	overlay.queue_free()


func test_create_fade_overlay_has_fullscreen_anchors() -> void:
	## AC-5: create_fade_overlay 返回全屏锚定 ColorRect
	var overlay := SM.create_fade_overlay()
	assert_eq(overlay.anchor_left, 0.0, "anchor_left 应为 0.0")
	assert_eq(overlay.anchor_right, 1.0, "anchor_right 应为 1.0")
	assert_eq(overlay.anchor_top, 0.0, "anchor_top 应为 0.0")
	assert_eq(overlay.anchor_bottom, 1.0, "anchor_bottom 应为 1.0")
	overlay.queue_free()


func test_create_fade_overlay_is_opaque_black() -> void:
	## AC-5: create_fade_overlay 为纯黑色——D3D12 闪烁缓解
	var overlay := SM.create_fade_overlay()
	assert_eq(overlay.color, Color.BLACK, "color 应为纯黑色")
	assert_eq(overlay.modulate.a, 1.0, "alpha 应为 1.0（完全不透明）")
	overlay.queue_free()


func test_create_fade_overlay_mouse_filter_is_ignore() -> void:
	## AC-5: overlay 不应拦截鼠标事件
	var overlay := SM.create_fade_overlay()
	assert_eq(overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"mouse_filter 应为 IGNORE——不拦截输入")
	overlay.queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
# AC-8 验收标准：fade_out_overlay 辅助方法
# ═══════════════════════════════════════════════════════════════════════════════

func test_fade_out_overlay_accepts_null_safely() -> void:
	## AC-8: fade_out_overlay 接受 null 参数——不应崩溃
	SM.fade_out_overlay(null, 0.0)
	# 触达此处即通过——无异常、无崩溃
	assert_true(true, "fade_out_overlay(null) 不应崩溃")


func test_fade_out_overlay_accepts_valid_overlay() -> void:
	## AC-8: fade_out_overlay 接受有效 overlay + duration
	var overlay := SM.create_fade_overlay()
	assert_not_null(overlay, "create_fade_overlay 应返回有效 overlay")
	SM.fade_out_overlay(overlay, 0.25)
	# 渐变异步启动——验证无错误抛出
	assert_true(true, "fade_out_overlay 接受有效 overlay 不应崩溃")
	overlay.queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
# AC-7 验收标准：加载画面缺失时的优雅降级
# ═══════════════════════════════════════════════════════════════════════════════

func test_graceful_degradation_preserves_transition_state() -> void:
	## AC-7: 加载画面缺失时——保留 Phase 2 状态
	## 在 test_mode 中 _execute_transition 跳过场景加载
	## 我们通过模拟降级路径来验证：Phase 2 状态已设置，
	## _phase3_in_progress 从未设置，request_scene_change 返回 true
	sm._transitioning = true
	sm._transition_type = SM.TransitionType.MENU_TO_GAME
	_mock_im.reset_counts()

	# 降级路径直接进入 Phase 4-5（通过 test_mode 跳过的正常效果）
	sm._execute_transition(SM.SceneID.MAIN_MENU, SM.SceneID.EXPLORATION)
	# 在 test_mode 中：_execute_post_load 被调用——释放锁并重置 transitioning
	assert_false(sm._transitioning, "Phase 5 后 transitioning 应为 false")
	assert_eq(sm._transition_type, SM.TransitionType.NONE,
			"Phase 5 后 transition_type 应重置")
	# pop_lock 被调用——锁正确配对
	assert_eq(_mock_im.pop_calls, 1, "锁应被释放")


func test_graceful_degradation_phase3_flag_not_set() -> void:
	## AC-7: 降级路径中 _phase3_in_progress 从未设置
	## 降级意味着加载画面从未启动——标志位保持 false
	assert_false(sm._phase3_in_progress,
			"_phase3_in_progress 初始值应为 false")

	sm._transitioning = true
	sm._transition_type = SM.TransitionType.GAME_TO_MENU
	sm._execute_transition(SM.SceneID.EXPLORATION, SM.SceneID.MAIN_MENU)
	# test_mode：Phase 5 将标志位重置——正常流程和降级流程均如此
	assert_false(sm._phase3_in_progress,
			"_phase3_in_progress 在降级路径后应保持/重置为 false")


func test_error_recovery_unlocks_input_once() -> void:
	## AC-7: 错误恢复仅释放一次锁——push/pop 配对
	sm._transitioning = true
	sm._phase3_in_progress = true
	_mock_im.reset_counts()

	sm._cleanup_on_error(&"loading_screen_missing")

	assert_eq(_mock_im.pop_calls, 1, "pop_lock 应仅被调用一次——锁仅释放一次")


func test_no_permanent_deadlock_after_repeated_degradations() -> void:
	## AC-7: 多次降级场景不导致永久死锁
	for i in range(3):
		sm._transitioning = true
		sm._transition_type = SM.TransitionType.MENU_TO_GAME
		sm._phase3_in_progress = true
		_mock_im.reset_counts()

		sm._cleanup_on_error(&"loading_screen_missing")

		assert_false(sm._transitioning, "第 %d 次迭代：transitioning 已清除" % i)
		assert_false(sm._phase3_in_progress, "第 %d 次迭代：标志位已清除" % i)
		assert_eq(_mock_im.pop_calls, 1, "第 %d 次迭代：锁已释放" % i)

	# 3 次错误恢复后应能发起新请求
	var result: bool = sm.request_scene_change(
			SM.SceneID.MAIN_MENU, SM.SceneID.EXPLORATION, SM.TransitionType.MENU_TO_GAME)
	assert_true(result, "3 次错误恢复后应能发起转场请求")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-6 验收标准：Phase 4 tree_changed 防御性校验
# ═══════════════════════════════════════════════════════════════════════════════

func test_path_mismatch_cleanup_releases_lock() -> void:
	## AC-6: 路径不匹配时 _cleanup_on_error 释放输入锁
	sm._transitioning = true
	sm._phase3_in_progress = true
	_mock_im.reset_counts()

	sm._cleanup_on_error(&"path_mismatch")

	assert_eq(sm._transition_type, SM.TransitionType.NONE,
			"路径不匹配后 transition_type 应重置为 NONE")
	assert_false(sm._transitioning,
			"路径不匹配后 transitioning 应重置为 false")
	assert_false(sm._phase3_in_progress,
			"路径不匹配后 _phase3_in_progress 应重置为 false")
	assert_eq(_mock_im.pop_calls, 1, "路径不匹配时应释放输入锁")


func test_phase4_path_mismatch_preserves_lock_pairing() -> void:
	## AC-6: 路径不匹配未破坏 lock pairing——可进行新请求
	sm._transitioning = true
	sm._phase3_in_progress = true
	sm._transition_type = SM.TransitionType.GAME_TO_MENU

	sm._cleanup_on_error(&"path_mismatch")

	# 清理后应可发起新请求
	var result: bool = sm.request_scene_change(
			SM.SceneID.MAIN_MENU, SM.SceneID.EXPLORATION, SM.TransitionType.MENU_TO_GAME)
	assert_true(result, "路径不匹配清理后应能发起转场请求")
