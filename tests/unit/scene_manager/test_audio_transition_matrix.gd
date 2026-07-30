extends GutTest
## Story 002 验收测试：TRANSITION_AUDIO_PARAMS 映射表完整性。
##
## 覆盖 AC-2、AC-3 —— 映射表与 audio-system.md 严格一致、
## 编译时覆盖验证（无 NONE 条目、无万用分支）。

const SM := preload("res://src/foundation/scene_manager.gd")

var _params: Dictionary = {}


func before_all() -> void:
	_params = SM.TRANSITION_AUDIO_PARAMS


# ═══════════════════════════════════════════════════════════════════════════════
# AC-2: TRANSITION_AUDIO_PARAMS 映射表结构
# ═══════════════════════════════════════════════════════════════════════════════

func test_audio_params_is_compile_time_constant() -> void:
	## AC-2: TRANSITION_AUDIO_PARAMS 为编译时常量——直接引用不报错即通过
	assert_true(_params is Dictionary, "TRANSITION_AUDIO_PARAMS 应为 Dictionary")


func test_audio_params_contains_all_types_except_none() -> void:
	## AC-2: 5 个 TransitionType 值（除 NONE）在映射表中
	assert_true(_params.has(SM.TransitionType.MENU_TO_GAME),
			"映射表应包含 MENU_TO_GAME")
	assert_true(_params.has(SM.TransitionType.GAME_TO_MENU),
			"映射表应包含 GAME_TO_MENU")
	assert_true(_params.has(SM.TransitionType.EXPLORE_TO_COMBAT),
			"映射表应包含 EXPLORE_TO_COMBAT")
	assert_true(_params.has(SM.TransitionType.COMBAT_TO_EXPLORE),
			"映射表应包含 COMBAT_TO_EXPLORE")
	assert_true(_params.has(SM.TransitionType.TRIBULATION),
			"映射表应包含 TRIBULATION")

	assert_eq(_params.size(), 5, "映射表应恰好包含 5 个条目（无 NONE）")


func test_audio_params_none_not_present() -> void:
	## AC-2/AC-6: NONE 不出现在映射表中——不是有效转换，不应有音频参数
	assert_false(_params.has(SM.TransitionType.NONE),
			"NONE 不应出现在音频参数表中——零值哨兵，无音频行为")


func test_audio_params_entries_have_required_keys() -> void:
	## AC-2: 每个条目包含 duration_seconds、from_behavior、to_behavior
	for type_key in _params:
		var entry: Dictionary = _params[type_key]
		assert_true(entry.has("duration_seconds"),
				"TransitionType=%d 缺少 duration_seconds 键" % type_key)
		assert_true(entry.has("from_behavior"),
				"TransitionType=%d 缺少 from_behavior 键" % type_key)
		assert_true(entry.has("to_behavior"),
				"TransitionType=%d 缺少 to_behavior 键" % type_key)

		assert_eq(typeof(entry.duration_seconds), TYPE_FLOAT,
				"duration_seconds 应为 float")
		assert_eq(typeof(entry.from_behavior), TYPE_STRING_NAME,
				"from_behavior 应为 StringName")
		assert_eq(typeof(entry.to_behavior), TYPE_STRING_NAME,
				"to_behavior 应为 StringName")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-2: 映射表值与 audio-system.md 严格一致
# ═══════════════════════════════════════════════════════════════════════════════

func test_audio_params_menu_to_game() -> void:
	## AC-2: MENU_TO_GAME → 1.5s fade_out + fade_in
	var entry: Dictionary = _params[SM.TransitionType.MENU_TO_GAME]
	assert_eq(entry.duration_seconds, 1.5, "M2G 时长应为 1.5s")
	assert_eq(entry.from_behavior, &"fade_out", "M2G 前场景行为")
	assert_eq(entry.to_behavior, &"fade_in", "M2G 新场景行为")


func test_audio_params_game_to_menu() -> void:
	## AC-2: GAME_TO_MENU → 1.5s fade_out + fade_in
	var entry: Dictionary = _params[SM.TransitionType.GAME_TO_MENU]
	assert_eq(entry.duration_seconds, 1.5, "G2M 时长应为 1.5s")
	assert_eq(entry.from_behavior, &"fade_out", "G2M 前场景行为")
	assert_eq(entry.to_behavior, &"fade_in", "G2M 新场景行为")


func test_audio_params_explore_to_combat() -> void:
	## AC-2: EXPLORE_TO_COMBAT → 0.5s cut + fade_in
	var entry: Dictionary = _params[SM.TransitionType.EXPLORE_TO_COMBAT]
	assert_eq(entry.duration_seconds, 0.5, "E2C 时长应为 0.5s")
	assert_eq(entry.from_behavior, &"cut", "E2C 前场景行为——快速切入")
	assert_eq(entry.to_behavior, &"fade_in", "E2C 新场景行为")


func test_audio_params_combat_to_explore() -> void:
	## AC-2: COMBAT_TO_EXPLORE → 1.0s fade_out + fade_in
	var entry: Dictionary = _params[SM.TransitionType.COMBAT_TO_EXPLORE]
	assert_eq(entry.duration_seconds, 1.0, "C2E 时长应为 1.0s")
	assert_eq(entry.from_behavior, &"fade_out", "C2E 前场景行为")
	assert_eq(entry.to_behavior, &"fade_in", "C2E 新场景行为")


func test_audio_params_tribulation() -> void:
	## AC-2: TRIBULATION → 0.3s cut + cut
	var entry: Dictionary = _params[SM.TransitionType.TRIBULATION]
	assert_eq(entry.duration_seconds, 0.3, "TRIB 时长应为 0.3s")
	assert_eq(entry.from_behavior, &"cut", "TRIB 前场景行为——硬切")
	assert_eq(entry.to_behavior, &"cut", "TRIB 新场景行为——硬切")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-3: 编译时覆盖验证
# ═══════════════════════════════════════════════════════════════════════════════

func test_compile_time_coverage_all_enum_except_none() -> void:
	## AC-3: 遍历 TransitionType，除 NONE 外的每个值在映射表中都有条目。
	## 这模拟了音频系统 match 语句的编译时覆盖——新增枚举值后
	## 若未同步添加映射条目，本测试失败（替代编译器 missing-branch warning）。
	var covered: int = 0
	for type_name in SM.TransitionType:
		if type_name == "NONE":
			continue
		var type_val: int = SM.TransitionType[type_name]
		assert_true(_params.has(type_val),
				"%s (%d) 在 TRANSITION_AUDIO_PARAMS 中缺少条目——音频系统
				match 语句将报 missing-branch 编译警告" % [type_name, type_val])
		covered += 1
	assert_eq(covered, 5, "应覆盖全部 5 个非 NONE 转换类型")


func test_compile_time_coverage_params_size_matches_enum_size_minus_none() -> void:
	## AC-3: 映射表条目数 = TransitionType 枚举值数 - 1（排除 NONE）
	var enum_count: int = SM.TransitionType.size()
	var params_count: int = _params.size()
	assert_eq(params_count, enum_count - 1,
			"映射表条目数应 = %d（枚举 %d 个值 - NONE）" % [enum_count - 1, enum_count])
