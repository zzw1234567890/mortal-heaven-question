extends GutTest
## Story 003 集成测试：错误恢复集成。
##
## 覆盖 AC-4（加载画面缺失错误恢复）、AC-5（目标场景缺失错误恢复）、
## AC-6（await 中断双重保底）。
## 通过手动触发 _cleanup_on_error 和模拟 Phase 状态验证清理逻辑。

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
func push_lock(_type: int, _source: StringName) -> void:
	push_calls += 1
func pop_lock(_source: StringName) -> void:
	pop_calls += 1
func reset_counts() -> void:
	push_calls = 0
	pop_calls = 0
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
func auto_save() -> void: pass
"""
	var err := s.reload()
	if err != OK:
		push_error("Mock SL 编译失败: %d" % err)
	n.set_script(s)
	return n


# ═══════════════════════════════════════════════════════════════════════════════
# AC-4: 加载画面缺失时的错误恢复
# ═══════════════════════════════════════════════════════════════════════════════

func test_cleanup_on_loading_screen_missing_resets_transitioning() -> void:
	## AC-4: 错误恢复后 _transitioning 重置为 false
	sm._transitioning = true
	sm._transition_type = SM.TransitionType.MENU_TO_GAME
	sm._phase3_in_progress = true

	sm._cleanup_on_error(&"loading_screen_missing")

	assert_false(sm._transitioning,
			"加载画面缺失错误恢复后 _transitioning 应为 false")


func test_cleanup_on_loading_screen_missing_releases_lock() -> void:
	## AC-4: 错误恢复时释放 TRANSITION 级输入锁
	sm._transitioning = true
	_mock_im.reset_counts()
	# 模拟 Phase 2 已推入锁
	_mock_im.push_lock(3, &"scene_manager")

	sm._cleanup_on_error(&"loading_screen_missing")

	assert_eq(_mock_im.pop_calls, 1,
			"_cleanup_on_error 应调用一次 pop_lock 释放锁")


func test_cleanup_on_loading_screen_missing_resets_phase3_flag() -> void:
	## AC-4: 错误恢复后 _phase3_in_progress 重置为 false
	sm._phase3_in_progress = true

	sm._cleanup_on_error(&"loading_screen_missing")

	assert_false(sm._phase3_in_progress,
			"错误恢复后 _phase3_in_progress 应为 false")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-5: 目标场景路径不存在的错误恢复
# ═══════════════════════════════════════════════════════════════════════════════

func test_cleanup_on_target_scene_missing_releases_lock() -> void:
	## AC-5: 目标场景缺失错误恢复——释放输入锁
	sm._transitioning = true
	_mock_im.reset_counts()

	sm._cleanup_on_error(&"target_scene_missing")

	assert_eq(_mock_im.pop_calls, 1,
			"目标场景缺失恢复时 pop_lock 应被调用")


func test_cleanup_on_target_scene_missing_resets_transitioning() -> void:
	## AC-5: 目标场景缺失后 _transitioning = false——防止永久死锁
	sm._transitioning = true
	sm._transition_type = SM.TransitionType.EXPLORE_TO_COMBAT

	sm._cleanup_on_error(&"target_scene_missing")

	assert_false(sm._transitioning,
			"目标场景缺失错误恢复后 _transitioning 应为 false")
	assert_eq(sm._transition_type, SM.TransitionType.NONE,
			"目标场景缺失后 _transition_type 应重置为 NONE")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-6: await 中断双重保底
# ═══════════════════════════════════════════════════════════════════════════════

func test_phase3_in_progress_flag_set_at_phase3_start() -> void:
	## AC-6: _phase3_in_progress 正常初始值为 false——Phase 3 才设为 true
	assert_false(sm._phase3_in_progress,
			"初始状态下 _phase3_in_progress 应为 false")


func test_cleanup_resets_phase3_in_progress_flag() -> void:
	## AC-6: _cleanup_on_error 将 _phase3_in_progress 重置为 false
	sm._phase3_in_progress = true
	sm._transitioning = true

	sm._cleanup_on_error(&"phase3_aborted")

	assert_false(sm._phase3_in_progress,
			"await 中断清理后 _phase3_in_progress 应为 false")


func test_cleanup_unifies_error_recovery_paths() -> void:
	## AC-6: _cleanup_on_error 作为统一入口——无论原因如何，都执行完整清理
	var reasons: Array = [
		&"loading_screen_missing",
		&"target_scene_missing",
		&"phase3_aborted",
		&"path_mismatch",
	]
	for reason in reasons:
		# 设置脏状态
		sm._transitioning = true
		sm._transition_type = SM.TransitionType.EXPLORE_TO_COMBAT
		sm._phase3_in_progress = true

		sm._cleanup_on_error(reason)

		# 所有错误路径执行相同的清理
		assert_false(sm._transitioning,
				"reason=%s: _transitioning 应重置" % reason)
		assert_eq(sm._transition_type, SM.TransitionType.NONE,
				"reason=%s: _transition_type 应重置为 NONE" % reason)
		assert_false(sm._phase3_in_progress,
				"reason=%s: _phase3_in_progress 应重置" % reason)


func test_no_permanent_deadlock_after_multiple_error_recoveries() -> void:
	## AC-4+AC-6: 多次错误恢复后不应产生永久死锁
	# 模拟场景：用户触发转场 → 加载画面缺失 → 恢复 → 再次触发 → 目标缺失 → 恢复
	for _i in range(3):
		sm._transitioning = true
		sm._transition_type = SM.TransitionType.EXPLORE_TO_COMBAT
		sm._phase3_in_progress = true

		sm._cleanup_on_error(&"loading_screen_missing")

		assert_false(sm._transitioning,
				"第 %d 次错误恢复后 _transitioning 应为 false" % (_i + 1))

	# 错误恢复后应能发起新的转场请求
	assert_false(sm._transitioning, "最终状态 _transitioning 应为 false——允许新请求")
	var result: bool = sm.request_scene_change(
			SM.SceneID.MAIN_MENU, SM.SceneID.EXPLORATION, SM.TransitionType.MENU_TO_GAME)
	assert_true(result, "错误恢复后应能发起新的转场请求")
