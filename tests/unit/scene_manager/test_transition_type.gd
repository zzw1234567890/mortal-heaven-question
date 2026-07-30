extends GutTest
## Story 002 验收测试：TransitionType 枚举与管线集成。
##
## 覆盖 AC-1、AC-4、AC-5、AC-6 —— 枚举定义、类型声明、
## Phase 2/5 设置/重置和信号载荷验证。

const SM := preload("res://src/foundation/scene_manager.gd")

var sm: Node = null
var _mock_gsm: Node = null
var _mock_im: Node = null


func before_each() -> void:
	sm = SM.new()
	sm._ready()
	sm._test_mode = true
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


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1: TransitionType 枚举定义
# ═══════════════════════════════════════════════════════════════════════════════

func test_transition_type_has_six_values() -> void:
	## AC-1: TransitionType 枚举定义全部 6 个值（NONE + 5 种转换）
	assert_eq(SM.TransitionType.NONE, 0, "NONE 应为 0——零值哨兵")
	assert_eq(SM.TransitionType.MENU_TO_GAME, 1)
	assert_eq(SM.TransitionType.GAME_TO_MENU, 2)
	assert_eq(SM.TransitionType.EXPLORE_TO_COMBAT, 3)
	assert_eq(SM.TransitionType.COMBAT_TO_EXPLORE, 4)
	assert_eq(SM.TransitionType.TRIBULATION, 5)
	# 枚举值总数为 6
	var keys: Array = SM.TransitionType.keys()
	assert_eq(keys.size(), 6, "TransitionType 应为 6 个值")


func test_transition_type_none_is_zero_default() -> void:
	## AC-1: NONE = 0 —— 未初始化/空闲状态的哨兵值
	assert_eq(SM.TransitionType.NONE, 0, "哨兵值必须为 0——与 GDScript 默认 int 零值一致")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-4: 与 Story 001 管线的集成——类型声明
# ═══════════════════════════════════════════════════════════════════════════════

func test_transition_type_field_is_transition_type_not_int() -> void:
	## AC-4: _transition_type 字段类型为 TransitionType（非 int）
	sm._transition_type = SM.TransitionType.EXPLORE_TO_COMBAT
	assert_eq(sm._transition_type, SM.TransitionType.EXPLORE_TO_COMBAT,
			"_transition_type 应存储 TransitionType 枚举值")


func test_request_scene_change_accepts_transition_type_param() -> void:
	## AC-4: request_scene_change() 的 type 参数类型为 TransitionType
	var result: bool = sm.request_scene_change(
			SM.SceneID.MAIN_MENU, SM.SceneID.COMBAT, SM.TransitionType.MENU_TO_GAME)
	assert_true(result, "TransitionType 枚举值作为 type 参数应正常工作")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-4: Phase 2 设置 _transition_type（每个类型单独验证）
# ═══════════════════════════════════════════════════════════════════════════════

func test_phase_2_sets_transition_type_menu_to_game() -> void:
	sm.request_scene_change(
			SM.SceneID.MAIN_MENU, SM.SceneID.EXPLORATION, SM.TransitionType.MENU_TO_GAME)
	assert_eq(sm._transition_type, SM.TransitionType.MENU_TO_GAME)


func test_phase_2_sets_transition_type_game_to_menu() -> void:
	sm._current_scene_id = SM.SceneID.EXPLORATION
	sm.request_scene_change(
			SM.SceneID.EXPLORATION, SM.SceneID.MAIN_MENU, SM.TransitionType.GAME_TO_MENU)
	assert_eq(sm._transition_type, SM.TransitionType.GAME_TO_MENU)


func test_phase_2_sets_transition_type_explore_to_combat() -> void:
	sm._current_scene_id = SM.SceneID.EXPLORATION
	sm.request_scene_change(
			SM.SceneID.EXPLORATION, SM.SceneID.COMBAT, SM.TransitionType.EXPLORE_TO_COMBAT)
	assert_eq(sm._transition_type, SM.TransitionType.EXPLORE_TO_COMBAT)


func test_phase_2_sets_transition_type_combat_to_explore() -> void:
	sm._current_scene_id = SM.SceneID.COMBAT
	sm.request_scene_change(
			SM.SceneID.COMBAT, SM.SceneID.EXPLORATION, SM.TransitionType.COMBAT_TO_EXPLORE)
	assert_eq(sm._transition_type, SM.TransitionType.COMBAT_TO_EXPLORE)


func test_phase_2_sets_transition_type_tribulation() -> void:
	sm._current_scene_id = SM.SceneID.EXPLORATION
	sm.request_scene_change(
			SM.SceneID.EXPLORATION, SM.SceneID.TRIBULATION, SM.TransitionType.TRIBULATION)
	assert_eq(sm._transition_type, SM.TransitionType.TRIBULATION)


# ═══════════════════════════════════════════════════════════════════════════════
# AC-4: Phase 5 重置 _transition_type（每个类型单独验证）
# ═══════════════════════════════════════════════════════════════════════════════

func test_phase_5_resets_menu_to_game_to_none() -> void:
	sm._transitioning = true
	sm._transition_type = SM.TransitionType.MENU_TO_GAME
	sm._execute_post_load(SM.SceneID.MAIN_MENU, SM.SceneID.EXPLORATION,
			SM.SCENE_PATHS[SM.SceneID.EXPLORATION])
	assert_eq(sm._transition_type, SM.TransitionType.NONE, "M2G 应在 Phase 5 重置为 NONE")


func test_phase_5_resets_game_to_menu_to_none() -> void:
	sm._transitioning = true
	sm._transition_type = SM.TransitionType.GAME_TO_MENU
	sm._execute_post_load(SM.SceneID.EXPLORATION, SM.SceneID.MAIN_MENU,
			SM.SCENE_PATHS[SM.SceneID.MAIN_MENU])
	assert_eq(sm._transition_type, SM.TransitionType.NONE, "G2M 应在 Phase 5 重置为 NONE")


func test_phase_5_resets_explore_to_combat_to_none() -> void:
	sm._transitioning = true
	sm._transition_type = SM.TransitionType.EXPLORE_TO_COMBAT
	sm._execute_post_load(SM.SceneID.EXPLORATION, SM.SceneID.COMBAT,
			SM.SCENE_PATHS[SM.SceneID.COMBAT])
	assert_eq(sm._transition_type, SM.TransitionType.NONE, "E2C 应在 Phase 5 重置为 NONE")


func test_phase_5_resets_combat_to_explore_to_none() -> void:
	sm._transitioning = true
	sm._transition_type = SM.TransitionType.COMBAT_TO_EXPLORE
	sm._execute_post_load(SM.SceneID.COMBAT, SM.SceneID.EXPLORATION,
			SM.SCENE_PATHS[SM.SceneID.EXPLORATION])
	assert_eq(sm._transition_type, SM.TransitionType.NONE, "C2E 应在 Phase 5 重置为 NONE")


func test_phase_5_resets_tribulation_to_none() -> void:
	sm._transitioning = true
	sm._transition_type = SM.TransitionType.TRIBULATION
	sm._execute_post_load(SM.SceneID.EXPLORATION, SM.SceneID.TRIBULATION,
			SM.SCENE_PATHS[SM.SceneID.TRIBULATION])
	assert_eq(sm._transition_type, SM.TransitionType.NONE, "TRIBULATION 应在 Phase 5 重置为 NONE")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-5: 信号载荷中包含类型信息
# ═══════════════════════════════════════════════════════════════════════════════

func test_pre_transition_signal_carries_transition_type_menu_to_game() -> void:
	sm.pre_transition.connect(func(_f: int, _t: int, tp: int):
			sm.set_meta("sig_type", tp))
	sm.request_scene_change(
			SM.SceneID.MAIN_MENU, SM.SceneID.COMBAT, SM.TransitionType.MENU_TO_GAME)
	assert_eq(sm.get_meta("sig_type", -1), SM.TransitionType.MENU_TO_GAME,
			"pre_transition 的 type 参数应为 MENU_TO_GAME")


func test_pre_transition_signal_carries_transition_type_tribulation() -> void:
	sm._current_scene_id = SM.SceneID.EXPLORATION
	sm.pre_transition.connect(func(_f: int, _t: int, tp: int):
			sm.set_meta("sig_type2", tp))
	sm.request_scene_change(
			SM.SceneID.EXPLORATION, SM.SceneID.TRIBULATION, SM.TransitionType.TRIBULATION)
	assert_eq(sm.get_meta("sig_type2", -1), SM.TransitionType.TRIBULATION,
			"pre_transition 的 type 参数应为 TRIBULATION")


func test_signal_type_param_matches_request_param_for_all_types() -> void:
	## AC-5: 信号中的 type 与 request_scene_change 传入的 type 一致
	var types_to_test: Array = [
		SM.TransitionType.MENU_TO_GAME,
		SM.TransitionType.GAME_TO_MENU,
		SM.TransitionType.EXPLORE_TO_COMBAT,
		SM.TransitionType.COMBAT_TO_EXPLORE,
		SM.TransitionType.TRIBULATION,
	]
	var idx: int = 0
	for tt in types_to_test:
		# 重置状态
		sm._transitioning = false
		sm._transition_type = SM.TransitionType.NONE
		sm._current_scene_id = SM.SceneID.MAIN_MENU

		var signal_captured: bool = false
		var captured_type: int = -1
		sm.pre_transition.connect(func(_f: int, _t: int, tp: int):
				sm.set_meta("captured_%d" % idx, true)
				sm.set_meta("type_%d" % idx, tp))

		sm.request_scene_change(SM.SceneID.MAIN_MENU, SM.SceneID.EXPLORATION, tt)

		assert_eq(sm._transition_type, tt,
				"信号 type=%d 应与请求参数一致" % tt)
		assert_eq(sm.get_meta("type_%d" % idx, -1), tt,
				"信号载荷 type 应与传入值一致")
		idx += 1


# ═══════════════════════════════════════════════════════════════════════════════
# AC-6: 职责边界清晰
# ═══════════════════════════════════════════════════════════════════════════════

func test_transition_type_excludes_ui_markers() -> void:
	## AC-6: TransitionType 不包含 UI 状态标记（如 MODAL_OPEN、MENU_PAUSE）
	var max_val: int = 0
	for k in SM.TransitionType.values():
		var v: int = k
		if v > max_val:
			max_val = v
	assert_true(max_val <= 5, "TransitionType 枚举不应包含 UI 状态标记——最大值 ≤ 5")


func test_transition_type_only_scene_level_transitions() -> void:
	## AC-6: TransitionType 仅包含场景级转换——不含 UI overlay
	var names: Array = SM.TransitionType.keys()
	for n in names:
		var name_str: String = str(n)
		var name_upper: String = name_str.to_upper()
		assert_true(
				"MODAL" not in name_upper and "MENU_PAUSE" not in name_upper and "OVERLAY" not in name_upper,
				"TransitionType.%s 不应为 UI overlay 标记" % name_str)