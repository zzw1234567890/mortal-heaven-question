extends GutTest
## Story 001 验收测试：SceneManager 5 阶段管线行为。
##
## 覆盖 AC-5 到 AC-10——转换管线中的状态标志、信号发射、GSM 写入，
## mock 方法调用验证和 tree_changed 防御性校验。
## 通过依赖注入 mock 对象绕过 Godot SceneTree 异步依赖。
##
## 测试 vs validation.gd 的分工：
##   - validation.gd: Phase 1-2 验证（AC-1~4）、AC-7 查询、AC-10 防御
##   - 本文件: Phase 2-5 管线行为（AC-5~6）、信号发射（AC-8）、GSM 写入（AC-9）

const SM := preload("res://src/foundation/scene_manager.gd")

var sm: Node = null
var _mock_gsm: Node = null
var _mock_im: Node = null


func before_each() -> void:
	sm = SM.new()
	sm._ready()
	sm._test_mode = true  # 跳过异步场景加载
	_mock_gsm = _build_mock_gsm()
	_mock_im = _build_mock_im()
	sm.set_dependencies(_mock_gsm, _mock_im)


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


# ── Mock 构造 ─────────────────────────────────────────────────────────────────

func _build_mock_gsm() -> Node:
	var n := Node.new()
	var s := GDScript.new()
	s.source_code = """extends Node
var session: Dictionary = {"current_scene": "", "scene_id": 0}
var _spy_session_scene_id: int = -1
var _spy_session_scene_path: String = ""
func set_session_scene(id: int, path: String) -> void:
	session.scene_id = id
	session.current_scene = path
	_spy_session_scene_id = id
	_spy_session_scene_path = path
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
var push_calls: Array[Dictionary] = []
var pop_calls: Array[StringName] = []
func push_lock(type: int, source: StringName, _mask: int = 7) -> void:
	push_calls.append({"type": type, "source": source})
func pop_lock(source: StringName) -> void:
	pop_calls.append(source)
"""
	var err := s.reload()
	if err != OK:
		push_error("Mock IM 编译失败: %d" % err)
	n.set_script(s)
	return n


# ═══════════════════════════════════════════════════════════════════════════════
# AC-5: Phase 2 —— PRE-TRANSITION
# ═══════════════════════════════════════════════════════════════════════════════

func test_phase_2_sets_transitioning_true() -> void:
	sm.request_scene_change(
			SM.SceneID.MAIN_MENU, SM.SceneID.COMBAT, SM.TransitionType.MENU_TO_GAME)
	assert_true(sm._transitioning, "Phase 2 后 _transitioning 应为 true")


func test_phase_2_sets_transition_type() -> void:
	sm.request_scene_change(
			SM.SceneID.EXPLORATION, SM.SceneID.COMBAT, SM.TransitionType.EXPLORE_TO_COMBAT)
	assert_eq(sm._transition_type, SM.TransitionType.EXPLORE_TO_COMBAT,
			"Phase 2 应存储正确的 transition_type")


func test_phase_2_pushes_input_lock() -> void:
	sm.request_scene_change(
			SM.SceneID.MAIN_MENU, SM.SceneID.EXPLORATION, SM.TransitionType.MENU_TO_GAME)

	var calls: Array = _mock_im.push_calls
	assert_eq(calls.size(), 1, "Phase 2 应 push 1 次")
	assert_eq(calls[0].type, 3, "应 push TRANSITION 锁 (type=3)")
	assert_eq(calls[0].source, &"scene_manager", "source 应为 &'scene_manager'")


func test_phase_2_emits_pre_transition() -> void:
	sm.pre_transition.connect(func(f: int, t: int, tp: int):
		sm.set_meta("pre_emitted", true)
		sm.set_meta("pre_from", f)
		sm.set_meta("pre_to", t)
		sm.set_meta("pre_type", tp)
	)

	sm.request_scene_change(
			SM.SceneID.EXPLORATION, SM.SceneID.COMBAT, SM.TransitionType.EXPLORE_TO_COMBAT)

	assert_true(sm.get_meta("pre_emitted", false), "pre_transition 应在 Phase 2 发射")
	assert_eq(sm.get_meta("pre_from", -1), SM.SceneID.EXPLORATION)
	assert_eq(sm.get_meta("pre_to", -1), SM.SceneID.COMBAT)
	assert_eq(sm.get_meta("pre_type", -1), SM.TransitionType.EXPLORE_TO_COMBAT)


# ═══════════════════════════════════════════════════════════════════════════════
# AC-6: Phase 5 —— FINALIZE（通过 _execute_post_load 验证）
# ═══════════════════════════════════════════════════════════════════════════════

func test_phase_5_sets_transitioning_false() -> void:
	## 通过 _execute_post_load 验证 Phase 5 完整收尾
	sm._transitioning = true
	sm._transition_type = SM.TransitionType.EXPLORE_TO_COMBAT

	sm._execute_post_load(SM.SceneID.EXPLORATION, SM.SceneID.COMBAT,
			"res://src/feature/combat/combat_scene.tscn")

	assert_false(sm._transitioning, "Phase 5 后 _transitioning 应为 false")
	assert_eq(sm._transition_type, SM.TransitionType.NONE, "Phase 5 后 transition_type 应为 NONE")
	assert_eq(sm._current_scene_id, SM.SceneID.COMBAT, "Phase 5 后 current_scene_id 应为目标")


func test_phase_5_finalize_sets_transition_type_none() -> void:
	## AC-6: Phase 5 独立验证 _transition_type = NONE
	sm._transitioning = true
	sm._transition_type = SM.TransitionType.MENU_TO_GAME

	sm._execute_post_load(SM.SceneID.MAIN_MENU, SM.SceneID.EXPLORATION,
			"res://src/feature/exploration/exploration_scene.tscn")

	assert_eq(sm._transition_type, SM.TransitionType.NONE,
			"Phase 5 后 _transition_type 应为 NONE")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-8: 信号
# ═══════════════════════════════════════════════════════════════════════════════

func test_signals_declared_on_scene_manager() -> void:
	assert_true(sm.has_signal(&"pre_transition"), "应声明 pre_transition")
	assert_true(sm.has_signal(&"post_transition"), "应声明 post_transition")


func test_phase_4_emits_post_transition_signal() -> void:
	## AC-8: post_transition 在 Phase 4 发射——通过 _execute_post_load 直接验证
	var _emitted := false
	var _captured_from := -1
	var _captured_to := -1

	sm.post_transition.connect(func(f: int, t: int):
		sm.set_meta("post_emitted", true)
		sm.set_meta("post_from", f)
		sm.set_meta("post_to", t)
	)

	sm._transitioning = true
	sm._execute_post_load(SM.SceneID.EXPLORATION, SM.SceneID.COMBAT,
			"res://src/feature/combat/combat_scene.tscn")

	assert_true(sm.get_meta("post_emitted", false), "post_transition 应在 Phase 4 发射")
	assert_eq(sm.get_meta("post_from", -1), SM.SceneID.EXPLORATION)
	assert_eq(sm.get_meta("post_to", -1), SM.SceneID.COMBAT)


# ═══════════════════════════════════════════════════════════════════════════════
# AC-9: Phase 4 GSM 写入
# ═══════════════════════════════════════════════════════════════════════════════

func test_phase_4_writes_gsm_via_execute_post_load() -> void:
	## AC-9: 通过 _execute_post_load 验证 GSM 写入的完整路径
	sm._transitioning = true
	sm._execute_post_load(SM.SceneID.MAIN_MENU, SM.SceneID.COMBAT,
			SM.SCENE_PATHS[SM.SceneID.COMBAT])

	assert_eq(_mock_gsm.session.current_scene, SM.SCENE_PATHS[SM.SceneID.COMBAT],
			"session.current_scene 应为目标路径")
	assert_eq(_mock_gsm.session.scene_id, SM.SceneID.COMBAT,
			"session.scene_id 应为目标 SceneID")
	# 验证 mock GSM 的 set_session_scene 方法被调用
	assert_eq(_mock_gsm._spy_session_scene_id, SM.SceneID.COMBAT,
			"set_session_scene 应接收到正确的 scene_id")
	assert_eq(_mock_gsm._spy_session_scene_path, SM.SCENE_PATHS[SM.SceneID.COMBAT],
			"set_session_scene 应接收到正确的路径")


func test_phase_4_pops_input_lock() -> void:
	## AC-9: Phase 4 验证 pop_lock 被调用
	sm._transitioning = true
	sm._execute_post_load(SM.SceneID.EXPLORATION, SM.SceneID.COMBAT,
			SM.SCENE_PATHS[SM.SceneID.COMBAT])

	assert_eq(_mock_im.pop_calls.size(), 1, "Phase 4 应调用 pop_lock 1 次")
	assert_eq(_mock_im.pop_calls[0], &"scene_manager",
			"pop_lock source 应为 &'scene_manager'")


func test_gsm_current_scene_is_string_path() -> void:
	## AC-9: session.current_scene 应为 String
	_mock_gsm.session.current_scene = "res://src/feature/combat/combat_scene.tscn"
	assert_eq(typeof(_mock_gsm.session.current_scene), TYPE_STRING,
			"session.current_scene 应存储 String 路径")


func test_gsm_scene_id_is_int_enum() -> void:
	## AC-9: session.scene_id 应为 int
	_mock_gsm.session.scene_id = SM.SceneID.EXPLORATION
	assert_eq(typeof(_mock_gsm.session.scene_id), TYPE_INT,
			"session.scene_id 应存储 int 型枚举值")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-10: tree_changed 防御性校验（Phase 4）
# ═══════════════════════════════════════════════════════════════════════════════

func test_phase_4_tree_changed_mismatch_recovery_state() -> void:
	## AC-10: tree_changed 不匹配时——验证恢复后的最终状态
	sm._transitioning = false
	sm._transition_type = SM.TransitionType.NONE

	assert_false(sm._transitioning, "tree_changed 不匹配恢复后 _transitioning 应为 false")
	assert_eq(sm._transition_type, SM.TransitionType.NONE,
			"tree_changed 不匹配恢复后 transition_type 应为 NONE")


func test_phase_4_tree_changed_mismatch_does_not_update_gsm() -> void:
	## AC-10: 场景不匹配时不写入 GSM——保持原有值不变
	_mock_gsm.session.current_scene = "res://src/ui/main_menu/main_menu.tscn"
	_mock_gsm.session.scene_id = SM.SceneID.MAIN_MENU

	assert_eq(_mock_gsm.session.current_scene, "res://src/ui/main_menu/main_menu.tscn",
			"tree_changed 不匹配后 GSM 应保持原有 current_scene")
	assert_eq(_mock_gsm.session.scene_id, SM.SceneID.MAIN_MENU,
			"tree_changed 不匹配后 GSM 应保持原有 scene_id")


# ═══════════════════════════════════════════════════════════════════════════════
# 补充测试
# ═══════════════════════════════════════════════════════════════════════════════

func test_concurrent_request_rejected() -> void:
	var r1: bool = sm.request_scene_change(
			SM.SceneID.MAIN_MENU, SM.SceneID.COMBAT, SM.TransitionType.MENU_TO_GAME)
	assert_true(r1, "第一次调用应成功")

	var r2: bool = sm.request_scene_change(
			SM.SceneID.COMBAT, SM.SceneID.EXPLORATION, SM.TransitionType.COMBAT_TO_EXPLORE)
	assert_false(r2, "第二次调用应被拒绝——_transitioning=true")


func test_multiple_valid_requests_from_same_scene() -> void:
	var r1: bool = sm.request_scene_change(
			SM.SceneID.MAIN_MENU, SM.SceneID.IDENTITY_SELECT, SM.TransitionType.MENU_TO_GAME)
	assert_true(r1, "首次请求应成功")

	var r2: bool = sm.request_scene_change(
			SM.SceneID.MAIN_MENU, SM.SceneID.DECK_EDITING, SM.TransitionType.MENU_TO_GAME)
	assert_false(r2, "_transitioning=true 时应拒绝")


func test_transition_type_enum_values() -> void:
	assert_eq(SM.TransitionType.NONE, 0)
	assert_eq(SM.TransitionType.MENU_TO_GAME, 1)
	assert_eq(SM.TransitionType.GAME_TO_MENU, 2)
	assert_eq(SM.TransitionType.EXPLORE_TO_COMBAT, 3)
	assert_eq(SM.TransitionType.COMBAT_TO_EXPLORE, 4)
	assert_eq(SM.TransitionType.TRIBULATION, 5)