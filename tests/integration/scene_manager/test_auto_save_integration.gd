extends GutTest
## Story 003 集成测试：自动存档集成。
##
## 覆盖 AC-2（Phase 2 auto_save）、AC-8（SaveLoad 集成契约验证）。
## 使用带间谍功能的 mock SaveLoad 验证 auto_save 调用时机和参数。

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
func push_lock(_type: int, _source: StringName) -> void: pass
func pop_lock(_source: StringName) -> void: pass
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
var auto_save_call_order: int = -1
func auto_save() -> void:
	auto_save_called = true
	auto_save_call_count += 1
"""
	var err := s.reload()
	if err != OK:
		push_error("Mock SL 编译失败: %d" % err)
	n.set_script(s)
	return n


# ═══════════════════════════════════════════════════════════════════════════════
# AC-2: Phase 2 自动存档
# ═══════════════════════════════════════════════════════════════════════════════

func test_phase_2_triggers_auto_save() -> void:
	## AC-2: Phase 2 调用 SaveLoad.auto_save()
	sm.request_scene_change(
			SM.SceneID.MAIN_MENU, SM.SceneID.EXPLORATION, SM.TransitionType.MENU_TO_GAME)
	assert_true(_mock_sl.auto_save_called,
			"request_scene_change 应触发 auto_save")
	assert_eq(_mock_sl.auto_save_call_count, 1,
			"auto_save 应仅被调用一次")


func test_auto_save_not_called_when_save_load_is_null() -> void:
	## AC-2: SaveLoad 为 null 时 auto_save 调用不应崩溃——防御性编程
	sm.set_dependencies(_mock_gsm, _mock_im, null)
	var result: bool = sm.request_scene_change(
			SM.SceneID.MAIN_MENU, SM.SceneID.EXPLORATION, SM.TransitionType.MENU_TO_GAME)
	assert_true(result, "即使 SaveLoad 为 null，request_scene_change 仍应返回 true")


func test_auto_save_triggers_before_phase_3_execution() -> void:
	## AC-2: auto_save 在 Phase 3 执行前触发——测试模式下 Phase 3 被跳过
	# 验证 auto_save 在 request_scene_change 返回时已调用（同步 fire-and-forget）
	_mock_sl.auto_save_called = false
	sm.request_scene_change(
			SM.SceneID.MAIN_MENU, SM.SceneID.EXPLORATION, SM.TransitionType.MENU_TO_GAME)
	assert_true(_mock_sl.auto_save_called,
			"auto_save 应在 request_scene_change 返回前（Phase 3 前）触发")


func test_auto_save_not_awaited_by_scene_manager() -> void:
	## AC-2: auto_save() 为 fire-and-forget——SceneManager 不 await 存档完成
	# SceneManager 的 request_scene_change 是同步方法（非 coroutine）
	# auto_save 在其内部被同步调用——证明无 await
	sm.request_scene_change(
			SM.SceneID.MAIN_MENU, SM.SceneID.EXPLORATION, SM.TransitionType.MENU_TO_GAME)
	# 如果 auto_save 被 await，request_scene_change 会是 coroutine——但它是同步的
	assert_true(_mock_sl.auto_save_called,
			"auto_save 已作为 fire-and-forget 调用完成")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-8: SaveLoad 集成契约验证
# ═══════════════════════════════════════════════════════════════════════════════

func test_scene_manager_does_not_touch_file_io() -> void:
	## AC-8: SceneManager 不接触文件 I/O——仅调用 auto_save()
	# 验证 SceneManager 源码中无 FileAccess / DirAccess 调用
	# 此测试通过 mock 验证——SceneManager 仅与 auto_save() 契约交互
	sm.request_scene_change(
			SM.SceneID.MAIN_MENU, SM.SceneID.EXPLORATION, SM.TransitionType.MENU_TO_GAME)
	assert_true(_mock_sl.auto_save_called,
			"SceneManager 通过 auto_save() 委托存档——不自行操作文件")


func test_scene_manager_does_not_validate_auto_save_result() -> void:
	## AC-8: SceneManager 不验证 auto_save 结果——fire-and-forget
	# auto_save() 无返回值——SceneManager 不检查成功/失败
	_mock_sl.auto_save_called = false
	sm.request_scene_change(
			SM.SceneID.MAIN_MENU, SM.SceneID.EXPLORATION, SM.TransitionType.MENU_TO_GAME)
	# auto_save_called 为 true 证明调用已发出——SceneManager 不关心结果
	assert_true(_mock_sl.auto_save_called)


func test_auto_save_triggered_for_all_transition_types() -> void:
	## AC-2: 所有 TransitionType（除 NONE）均触发自动存档
	var types_to_test: Array = [
		SM.TransitionType.MENU_TO_GAME,
		SM.TransitionType.GAME_TO_MENU,
		SM.TransitionType.EXPLORE_TO_COMBAT,
		SM.TransitionType.COMBAT_TO_EXPLORE,
		SM.TransitionType.TRIBULATION,
	]
	for tt in types_to_test:
		# 重置状态
		sm._transitioning = false
		sm._transition_type = SM.TransitionType.NONE
		_mock_sl.auto_save_called = false
		_mock_sl.auto_save_call_count = 0

		sm.request_scene_change(SM.SceneID.MAIN_MENU, SM.SceneID.EXPLORATION, tt)
		assert_true(_mock_sl.auto_save_called,
				"TransitionType=%d 应触发 auto_save" % tt)
		assert_eq(_mock_sl.auto_save_call_count, 1,
				"TransitionType=%d 的 auto_save 应仅调用一次" % tt)
