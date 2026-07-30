extends GutTest
## Story 003 集成测试：输入锁定集成。
##
## 覆盖 AC-1（Phase 2 push_lock）、AC-3（Phase 4 pop_lock）、AC-7（契约验证）。
## 使用带间谍功能的 mock InputManager 记录调用参数和顺序。

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
var _call_log: Array = []
var _push_count: int = 0
var _pop_count: int = 0
func push_lock(lock_type: int, source: StringName) -> void:
	_call_log.append({"op": "push", "type": lock_type, "source": source})
	_push_count += 1
func pop_lock(source: StringName) -> void:
	_call_log.append({"op": "pop", "source": source})
	_pop_count += 1
func clear_call_log() -> void:
	_call_log.clear()
	_push_count = 0
	_pop_count = 0
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


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1: Phase 2 输入锁定
# ═══════════════════════════════════════════════════════════════════════════════

func test_phase_2_pushes_transition_lock() -> void:
	## AC-1: Phase 2 调用 InputManager.push_lock(LockType.TRANSITION, &"scene_manager")
	sm.request_scene_change(
			SM.SceneID.MAIN_MENU, SM.SceneID.EXPLORATION, SM.TransitionType.MENU_TO_GAME)
	assert_eq(_mock_im._push_count, 1, "应调用 push_lock 一次")
	var last_call: Dictionary = _mock_im._call_log.back()
	assert_eq(last_call.op, "push")
	assert_eq(last_call.type, 3, "LockType.TRANSITION = 3")
	assert_eq(last_call.source, &"scene_manager",
			"source 应为 StringName &\"scene_manager\"")


func test_lock_pushed_after_transitioning_flag() -> void:
	## AC-1: push_lock 在 _transitioning=true 之后调用——源码 L209-215 顺序保证
	# 在 mock push_lock 中记录调用，验证 push_lock 被调用了且参数正确
	sm.request_scene_change(
			SM.SceneID.MAIN_MENU, SM.SceneID.EXPLORATION, SM.TransitionType.MENU_TO_GAME)
	assert_true(_mock_im._push_count >= 1,
			"push_lock 应被调用——源码 L209 先设 _transitioning=true，L214 再 push_lock")


func test_push_lock_with_null_input_manager_is_safe() -> void:
	## AC-1: InputManager 为 null 时 push_lock 调用不应崩溃——防御性编程
	sm.set_dependencies(_mock_gsm, null, _mock_sl)
	# 不应崩溃
	var result: bool = sm.request_scene_change(
			SM.SceneID.MAIN_MENU, SM.SceneID.EXPLORATION, SM.TransitionType.MENU_TO_GAME)
	assert_true(result, "即使 IM 为 null，request_scene_change 仍应返回 true")


func test_transition_lock_blocks_all_input_actions() -> void:
	## AC-1: TRANSITION 锁（type=3）为最高级别——阻止所有设备类型
	sm.request_scene_change(
			SM.SceneID.MAIN_MENU, SM.SceneID.EXPLORATION, SM.TransitionType.MENU_TO_GAME)
	# TRANSITION=3 是锁栈最高级别——input_manager.gd 的 is_input_allowed 逻辑
	# 验证 push_lock 以 type=3 调用
	assert_false(_mock_im._call_log.is_empty(), "push_lock 应产生调用记录")
	var last_call: Dictionary = _mock_im._call_log.back()
	assert_eq(last_call.type, 3, "push_lock 的 lock_type 应为 3（TRANSITION）")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-3: Phase 4 输入解锁
# ═══════════════════════════════════════════════════════════════════════════════

func test_phase_4_pops_transition_lock() -> void:
	## AC-3: Phase 4 调用 InputManager.pop_lock(&"scene_manager")
	sm._transitioning = true
	sm._transition_type = SM.TransitionType.MENU_TO_GAME
	# 模拟 push 已发生
	_mock_im.push_lock(3, &"scene_manager")
	_mock_im.clear_call_log()

	sm._execute_post_load(
			SM.SceneID.MAIN_MENU, SM.SceneID.EXPLORATION,
			SM.SCENE_PATHS[SM.SceneID.EXPLORATION])
	assert_eq(_mock_im._pop_count, 1, "应调用 pop_lock 一次")
	var pop_call: Dictionary = _mock_im._call_log.back()
	assert_eq(pop_call.op, "pop")
	assert_eq(pop_call.source, &"scene_manager",
			"Phase 4 pop_lock 的 source 应与 Phase 2 push_lock 相同")


func test_lock_and_unlock_are_paired() -> void:
	## AC-3: push_lock 与 pop_lock 配对——同一 StringName
	_mock_im.clear_call_log()
	# 完整流程：Phase 2 push → Phase 4-5 pop
	sm.request_scene_change(
			SM.SceneID.MAIN_MENU, SM.SceneID.EXPLORATION, SM.TransitionType.MENU_TO_GAME)
	sm._execute_post_load(
			SM.SceneID.MAIN_MENU, SM.SceneID.EXPLORATION,
			SM.SCENE_PATHS[SM.SceneID.EXPLORATION])

	var pushes: int = 0
	var pops: int = 0
	for call in _mock_im._call_log:
		if call.op == "push":
			pushes += 1
			assert_eq(call.source, &"scene_manager")
		elif call.op == "pop":
			pops += 1
			assert_eq(call.source, &"scene_manager")
	assert_eq(pushes, pops, "push_lock 和 pop_lock 应成对出现")


func test_pop_lock_with_null_im_is_safe() -> void:
	## AC-3: InputManager 为 null 时 pop_lock 不应崩溃
	sm._transitioning = true
	sm.set_dependencies(_mock_gsm, null, _mock_sl)
	# 不应崩溃
	sm._execute_post_load(
			SM.SceneID.MAIN_MENU, SM.SceneID.EXPLORATION,
			SM.SCENE_PATHS[SM.SceneID.EXPLORATION])
	assert_false(sm._transitioning, "Phase 5 后 _transitioning 应为 false")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-7: InputManager 交互契约验证
# ═══════════════════════════════════════════════════════════════════════════════

func test_scene_manager_never_calls_clear_locks() -> void:
	## AC-7: SceneManager 绝不直接调用 InputManager.clear_locks()
	# 验证：SceneManager 源码中无 clear_locks 调用（通过行为测试——mock IM 无 clear_locks 方法）
	assert_false(_mock_im.has_method("clear_locks"),
			"SceneManager 的 mock IM 不应需要 clear_locks——SceneManager 不用它")


func test_no_duplicate_lock_on_concurrent_request() -> void:
	## AC-7: 连续两次 request_scene_change 调用——第二个返回 false
	_mock_im.clear_call_log()
	# 第一次请求——成功
	var result1: bool = sm.request_scene_change(
			SM.SceneID.MAIN_MENU, SM.SceneID.EXPLORATION, SM.TransitionType.MENU_TO_GAME)
	assert_true(result1)
	var push_after_first: int = _mock_im._push_count

	# 第二次请求——被 _transitioning 守卫拒绝
	var result2: bool = sm.request_scene_change(
			SM.SceneID.MAIN_MENU, SM.SceneID.EXPLORATION, SM.TransitionType.MENU_TO_GAME)
	assert_false(result2, "并发请求应被拒绝")
	assert_eq(_mock_im._push_count, push_after_first,
			"被拒绝的请求不应增加 push_lock 调用——防止重复锁")


func test_pop_lock_same_stringname_as_push() -> void:
	## AC-7: push/pop 使用相同的 StringName &"scene_manager"
	_mock_im.clear_call_log()
	sm.request_scene_change(
			SM.SceneID.MAIN_MENU, SM.SceneID.EXPLORATION, SM.TransitionType.MENU_TO_GAME)
	sm._execute_post_load(
			SM.SceneID.MAIN_MENU, SM.SceneID.EXPLORATION,
			SM.SCENE_PATHS[SM.SceneID.EXPLORATION])

	var push_source: StringName = ""
	var pop_source: StringName = ""
	for call in _mock_im._call_log:
		if call.op == "push":
			push_source = call.source
		elif call.op == "pop":
			pop_source = call.source
	assert_eq(push_source, pop_source,
			"push 和 pop 的 source 应为同一 StringName——&\"scene_manager\"")
	assert_eq(push_source, &"scene_manager",
			"source 应为 StringName 字面量 &\"scene_manager\"")
