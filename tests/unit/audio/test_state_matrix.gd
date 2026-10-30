extends GutTest
## audio-manager Story 004 单元测试：状态过渡矩阵 Logic 内核。
##
## 覆盖 QA Test Cases：
##   - AC-1 矩阵完整性——12 态每态至少 1 入边/出边、行数 24、N/A 转换不存在
##   - AC-2 每行参数完备——7 键齐全 + 时长/dB 在调优旋钮安全范围
##   - AC-3 TransitionType 映射——5 类全覆盖 + 未映射返回 -1（防御性）
##   - AC-6 set_state 幂等——同状态重复调用无副作用
##
## Story 类型 Logic + Integration——此文件为 BLOCKING 证据（Logic 侧）。
## 风格先例：tests/unit/audio/test_bgm_fade_planner.gd（纯函数直调）。

const Matrix := preload("res://src/ui/audio/state_transition_matrix.gd")
const AE := preload("res://src/ui/audio/audio_enums.gd")
const Bfp := preload("res://src/ui/audio/bgm_fade_planner.gd")
const AM_SCRIPT := preload("res://src/ui/audio/audio_manager.gd")
const ADAPTER_SCRIPT := preload("res://src/ui/audio/audio_server_adapter.gd")
const SM := preload("res://src/foundation/scene_manager.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1：矩阵完整性
# ═══════════════════════════════════════════════════════════════════════════════

func test_matrix_completeness_validation_passes() -> void:
	## AC-1：validate_matrix() 返回 ok=true（12 态有边 / 24 行 / N/A 不存在）
	var result: Dictionary = Matrix.validate_matrix()
	assert_true(bool(result["ok"]), "矩阵校验应通过：%s" % str(result["errors"]))


func test_matrix_has_exactly_24_rows() -> void:
	## AC-1：行数 = 24（GDD §9 完整矩阵）
	assert_eq(Matrix.STATE_TRANSITION_MATRIX.size(), 24,
			"矩阵应为 24 行（GDD §9 完整版）")


func test_matrix_every_state_has_edge() -> void:
	## AC-1：12 态每态至少 1 入边或 1 出边（含 CULTIVATING）
	var has_edge: Dictionary = {}
	for key: Vector2i in Matrix.STATE_TRANSITION_MATRIX.keys():
		if key.x != Matrix.ANY_STATE:
			has_edge[key.x] = true
		if key.y != Matrix.ANY_STATE:
			has_edge[key.y] = true
	for name: String in AE.AudioState.keys():
		var state: int = AE.AudioState[name]
		assert_true(has_edge.get(state, false),
				"状态 %s(%d) 应有至少 1 入边或出边" % [name, state])


func test_matrix_cultivating_has_edge() -> void:
	## AC-1 Edge：CULTIVATING（修为养成）有边——此前遗漏重点
	var found: bool = false
	for key: Vector2i in Matrix.STATE_TRANSITION_MATRIX.keys():
		if key.x == AE.AudioState.CULTIVATING or key.y == AE.AudioState.CULTIVATING:
			found = true
			break
	assert_true(found, "CULTIVATING 应在矩阵中有边（修为养成双向）")


func test_matrix_n_a_transitions_absent() -> void:
	## AC-1 Edge：N/A 转换不存在（商店→战斗、身份选择→战斗、战败→非主菜单）
	assert_false(Matrix.STATE_TRANSITION_MATRIX.has(
			Vector2i(AE.AudioState.IN_SHOP, AE.AudioState.IN_COMBAT)),
			"商店→战斗不应存在（N/A）")
	assert_false(Matrix.STATE_TRANSITION_MATRIX.has(
			Vector2i(AE.AudioState.IDENTITY_SELECT, AE.AudioState.IN_COMBAT)),
			"身份选择→战斗不应存在（N/A）")
	assert_false(Matrix.STATE_TRANSITION_MATRIX.has(
			Vector2i(AE.AudioState.DEFEATED, AE.AudioState.EXPLORING)),
			"战败→探索不应存在（N/A——战败后必须回主菜单）")
	assert_false(Matrix.STATE_TRANSITION_MATRIX.has(
			Vector2i(AE.AudioState.DEFEATED, AE.AudioState.IDENTITY_SELECT)),
			"战败→身份选择不应存在（N/A）")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-2：每行参数完备 + 安全范围
# ═══════════════════════════════════════════════════════════════════════════════

func test_matrix_every_row_has_all_keys() -> void:
	## AC-2：每行 7 键齐全（bgm/fade_out_sec/fade_in_sec/duck_db/sequential/
	## ambient_delta_db/action）
	var required: Array = [Matrix.K_BGM, Matrix.K_FADE_OUT_SEC, Matrix.K_FADE_IN_SEC,
			Matrix.K_DUCK_DB, Matrix.K_SEQUENTIAL, Matrix.K_AMBIENT_DELTA_DB,
			Matrix.K_ACTION]
	for key: Vector2i in Matrix.STATE_TRANSITION_MATRIX.keys():
		var row: Dictionary = Matrix.STATE_TRANSITION_MATRIX[key]
		for k: StringName in required:
			assert_true(row.has(k), "行 %s 缺少键 '%s'" % [str(key), k])


func test_matrix_fade_durations_in_safe_range() -> void:
	## AC-2：时长在调优旋钮安全范围（淡出 0.3~2.0 / 淡入 0.2~3.0）。
	## 特殊动作行（pause/resume 时长 0）豁免——非淡化行为。
	for key: Vector2i in Matrix.STATE_TRANSITION_MATRIX.keys():
		var row: Dictionary = Matrix.STATE_TRANSITION_MATRIX[key]
		if row[Matrix.K_ACTION] != Matrix.ACTION_NONE:
			continue  # 特殊动作行豁免时长范围
		var fade_out: float = float(row[Matrix.K_FADE_OUT_SEC])
		var fade_in: float = float(row[Matrix.K_FADE_IN_SEC])
		assert_between(fade_out, 0.3, 2.0, "行 %s 淡出时长越界" % str(key))
		assert_between(fade_in, 0.2, 3.0, "行 %s 淡入时长越界" % str(key))


func test_matrix_duck_db_in_safe_range() -> void:
	## AC-2 Edge：降低类行（duck_db 非 null）dB 在安全范围 -15~0
	for key: Vector2i in Matrix.STATE_TRANSITION_MATRIX.keys():
		var row: Dictionary = Matrix.STATE_TRANSITION_MATRIX[key]
		if row[Matrix.K_DUCK_DB] != null:
			var duck: float = float(row[Matrix.K_DUCK_DB])
			assert_between(duck, -15.0, 0.0, "行 %s 降低类 dB 越界" % str(key))


func test_matrix_tribulation_sequential_flag() -> void:
	## AC-2：渡劫行 sequential=true（Boss 冲击感例外——先淡出完成再淡入）
	var row: Dictionary = Matrix.STATE_TRANSITION_MATRIX[
			Vector2i(AE.AudioState.EXPLORING, AE.AudioState.IN_TRIBULATION)]
	assert_true(bool(row[Matrix.K_SEQUENTIAL]), "探索→渡劫应为顺序式")
	assert_eq(row[Matrix.K_BGM], &"bgm_tribulation", "渡劫行目标曲应为 bgm_tribulation")


func test_matrix_rows_align_with_fade_planner_constants() -> void:
	## AC-2 交叉守卫：矩阵时长/dB 与 BgmFadePlanner 常量同源（GDScript const
	## Dictionary 不可引用脚本常量，两处数值由本测试交叉断言守护）
	assert_eq(float(Matrix.ROW_IDENTITY_TO_EXPLORE[Matrix.K_FADE_OUT_SEC]),
			Bfp.FADE_OUT_TO_EXPLORING_SEC, "身份→探索淡出应与计划器常量一致")
	assert_eq(float(Matrix.ROW_IDENTITY_TO_EXPLORE[Matrix.K_FADE_IN_SEC]),
			Bfp.FADE_IN_TO_EXPLORING_SEC, "身份→探索淡入应与计划器常量一致")
	assert_eq(float(Matrix.ROW_TO_COMBAT[Matrix.K_FADE_OUT_SEC]),
			Bfp.FADE_OUT_TO_COMBAT_SEC, "探索→战斗淡出应与计划器常量一致")
	assert_eq(float(Matrix.ROW_TO_COMBAT[Matrix.K_FADE_IN_SEC]),
			Bfp.FADE_IN_TO_COMBAT_SEC, "探索→战斗淡入应与计划器常量一致")
	assert_eq(float(Matrix.ROW_TO_TRIBULATION[Matrix.K_FADE_OUT_SEC]),
			Bfp.FADE_OUT_TO_TRIBULATION_SEC, "渡劫淡出应与计划器常量一致")
	assert_eq(float(Matrix.ROW_TO_TRIBULATION[Matrix.K_FADE_IN_SEC]),
			Bfp.FADE_IN_TO_TRIBULATION_SEC, "渡劫淡入应与计划器常量一致")
	assert_eq(float(Matrix.ROW_TO_VICTORY[Matrix.K_FADE_OUT_SEC]),
			Bfp.FADE_OUT_TO_VICTORY_SEC, "胜利淡出应与计划器常量一致")
	assert_eq(float(Matrix.ROW_TO_VICTORY[Matrix.K_FADE_IN_SEC]),
			Bfp.FADE_IN_TO_VICTORY_SEC, "胜利淡入应与计划器常量一致")
	assert_eq(float(Matrix.ROW_TO_DEFEAT[Matrix.K_FADE_OUT_SEC]),
			Bfp.FADE_OUT_TO_DEFEAT_SEC, "战败淡出应与计划器常量一致")
	assert_eq(float(Matrix.ROW_TO_DEFEAT[Matrix.K_FADE_IN_SEC]),
			Bfp.FADE_IN_TO_DEFEAT_SEC, "战败淡入应与计划器常量一致")
	assert_eq(float(Matrix.ROW_TO_SHOP[Matrix.K_DUCK_DB]), Bfp.SHOP_DB,
			"商店降低 dB 应与计划器常量一致")
	assert_eq(float(Matrix.ROW_TO_EVENT[Matrix.K_DUCK_DB]), Bfp.EVENT_DB,
			"事件降低 dB 应与计划器常量一致")
	assert_eq(float(Matrix.ROW_TO_DUCK_CULTIVATE[Matrix.K_DUCK_DB]), Bfp.CULTIVATE_DB,
			"修为/卡编降低 dB 应与计划器常量一致")


func test_matrix_rows_align_with_scene_manager_params() -> void:
	## 矩阵 ↔ SceneManager TRANSITION_AUDIO_PARAMS 交叉守卫（code-review 缺口）：
	## 引用层时长数值须与矩阵真源一致——探索→战斗 0.5s、战斗→探索 1.0s、
	## 渡劫 0.3s 顺序式（MENU_TO_GAME 引用层为 1.5s 单一值，矩阵为 1.0/1.5
	## 非对称——按 ADR 裁定引用层已文档化陈旧，此处只守护已对齐的三项）
	var tap: Dictionary = SM.TRANSITION_AUDIO_PARAMS
	assert_eq(float(Matrix.ROW_TO_COMBAT[Matrix.K_FADE_OUT_SEC]),
			float(tap[SM.TransitionType.EXPLORE_TO_COMBAT]["duration_seconds"]),
			"探索→战斗淡出 0.5s 应与引用层一致")
	assert_eq(float(Matrix.ROW_TO_COMBAT[Matrix.K_FADE_IN_SEC]),
			float(tap[SM.TransitionType.EXPLORE_TO_COMBAT]["duration_seconds"]),
			"探索→战斗淡入 0.5s 应与引用层一致")
	assert_eq(float(Matrix.ROW_TO_EXPLORE[Matrix.K_FADE_OUT_SEC]),
			float(tap[SM.TransitionType.COMBAT_TO_EXPLORE]["duration_seconds"]),
			"战斗→探索淡出 1.0s 应与引用层一致")
	assert_eq(float(Matrix.ROW_TO_EXPLORE[Matrix.K_FADE_IN_SEC]),
			float(tap[SM.TransitionType.COMBAT_TO_EXPLORE]["duration_seconds"]),
			"战斗→探索淡入 1.0s 应与引用层一致")
	assert_eq(float(Matrix.ROW_TO_TRIBULATION[Matrix.K_FADE_OUT_SEC]),
			float(tap[SM.TransitionType.TRIBULATION]["duration_seconds"]),
			"渡劫淡出 0.3s 应与引用层一致")
	assert_eq(float(Matrix.ROW_TO_TRIBULATION[Matrix.K_FADE_IN_SEC]),
			float(tap[SM.TransitionType.TRIBULATION]["duration_seconds"]),
			"渡劫淡入 0.3s 应与引用层一致")
	assert_true(bool(tap[SM.TransitionType.TRIBULATION].get("sequential", false)),
			"渡劫引用层应为顺序式标记")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-3：TransitionType 映射
# ═══════════════════════════════════════════════════════════════════════════════

func test_map_transition_type_all_five_types() -> void:
	## AC-3：5 类 TransitionType 全覆盖 → 正确 AudioState 目标态（枚举常量——
	## 环解耦后镜像值，枚举漂移由 test_matrix_enum_mirror_matches_scene_manager 守护）
	assert_eq(Matrix.map_transition_type(0, SM.SceneID.EXPLORATION,
			SM.TransitionType.MENU_TO_GAME), AE.AudioState.EXPLORING,
			"MENU_TO_GAME→探索 应为 EXPLORING")
	assert_eq(Matrix.map_transition_type(0, SM.SceneID.IDENTITY_SELECT,
			SM.TransitionType.MENU_TO_GAME), AE.AudioState.IDENTITY_SELECT,
			"MENU_TO_GAME→身份选择 应为 IDENTITY_SELECT")
	assert_eq(Matrix.map_transition_type(SM.SceneID.EXPLORATION, SM.SceneID.MAIN_MENU,
			SM.TransitionType.GAME_TO_MENU), AE.AudioState.MAIN_MENU,
			"GAME_TO_MENU 应为 MAIN_MENU")
	assert_eq(Matrix.map_transition_type(SM.SceneID.EXPLORATION, SM.SceneID.COMBAT,
			SM.TransitionType.EXPLORE_TO_COMBAT), AE.AudioState.IN_COMBAT,
			"EXPLORE_TO_COMBAT 应为 IN_COMBAT")
	assert_eq(Matrix.map_transition_type(SM.SceneID.COMBAT, SM.SceneID.EXPLORATION,
			SM.TransitionType.COMBAT_TO_EXPLORE), AE.AudioState.EXPLORING,
			"COMBAT_TO_EXPLORE 应为 EXPLORING")
	assert_eq(Matrix.map_transition_type(SM.SceneID.EXPLORATION, SM.SceneID.TRIBULATION,
			SM.TransitionType.TRIBULATION), AE.AudioState.IN_TRIBULATION,
			"TRIBULATION 应为 IN_TRIBULATION")


func test_map_transition_type_unmapped_returns_minus1() -> void:
	## AC-3 Edge：未映射组合（NONE）返回 -1（防御性——调用侧跳过）
	assert_eq(Matrix.map_transition_type(0, 0, SM.TransitionType.NONE), -1,
			"NONE 应返回 -1")
	assert_eq(Matrix.map_transition_type(0, 0, 99), -1, "未知类型应返回 -1")


func test_matrix_enum_mirror_matches_scene_manager() -> void:
	## 环解耦交叉守卫：矩阵本地镜像常量与 scene_manager.gd 枚举真源数值一致
	## （枚举重排会触发本测试失败，而非 map_transition_type 静默漂移）
	assert_eq(Matrix.TT_NONE, SM.TransitionType.NONE, "TT_NONE 镜像")
	assert_eq(Matrix.TT_MENU_TO_GAME, SM.TransitionType.MENU_TO_GAME, "TT_MENU_TO_GAME 镜像")
	assert_eq(Matrix.TT_GAME_TO_MENU, SM.TransitionType.GAME_TO_MENU, "TT_GAME_TO_MENU 镜像")
	assert_eq(Matrix.TT_EXPLORE_TO_COMBAT, SM.TransitionType.EXPLORE_TO_COMBAT, "TT_EXPLORE_TO_COMBAT 镜像")
	assert_eq(Matrix.TT_COMBAT_TO_EXPLORE, SM.TransitionType.COMBAT_TO_EXPLORE, "TT_COMBAT_TO_EXPLORE 镜像")
	assert_eq(Matrix.TT_TRIBULATION, SM.TransitionType.TRIBULATION, "TT_TRIBULATION 镜像")
	assert_eq(Matrix.SCENE_IDENTITY_SELECT, SM.SceneID.IDENTITY_SELECT, "SCENE_IDENTITY_SELECT 镜像")


func test_entry_bgm_switching_and_duck_states() -> void:
	## 引导进入入口曲映射（QA 缺口 2）：切曲类返回入口曲 id，duck/no-bgm 态返回 &""
	assert_eq(Matrix.entry_bgm(AE.AudioState.MAIN_MENU), &"bgm_main_menu",
			"主菜单入口曲")
	assert_eq(Matrix.entry_bgm(AE.AudioState.EXPLORING), &"bgm_explore",
			"探索入口曲")
	assert_eq(Matrix.entry_bgm(AE.AudioState.IN_COMBAT), &"bgm_combat",
			"战斗入口曲")
	assert_eq(Matrix.entry_bgm(AE.AudioState.IN_TRIBULATION), &"bgm_tribulation",
			"渡劫入口曲")
	assert_eq(Matrix.entry_bgm(AE.AudioState.MAP_CLEARED), &"bgm_victory",
			"通关入口曲")
	assert_eq(Matrix.entry_bgm(AE.AudioState.DEFEATED), &"bgm_defeat",
			"战败入口曲")
	assert_eq(Matrix.entry_bgm(AE.AudioState.IN_SHOP), &"",
			"商店为 duck 态——无入口曲")
	assert_eq(Matrix.entry_bgm(AE.AudioState.IN_EVENT), &"",
			"事件为 duck 态——无入口曲")
	assert_eq(Matrix.entry_bgm(AE.AudioState.DECK_EDITING), &"",
			"卡组编辑无入口曲")
	assert_eq(Matrix.entry_bgm(AE.AudioState.CULTIVATING), &"",
			"修为养成无入口曲")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-6：set_state 幂等（经真实 AudioManager——同状态重复调用无副作用）
# ═══════════════════════════════════════════════════════════════════════════════

func test_set_state_same_state_no_side_effect() -> void:
	## AC-6：当前 IN_COMBAT，再次 set_state(IN_COMBAT) → 无 BGM 重启/无重复淡化
	var am: AudioManager = AM_SCRIPT.new(null, _unavailable_adapter())
	am.set_state(AE.AudioState.IN_COMBAT)
	var players: Array = am.get_bgm_players()
	assert_true(players.is_empty(), "前置：null scene_manager 无节点池")
	var state_before: int = am._current_state
	am.set_state(AE.AudioState.IN_COMBAT)
	assert_eq(am._current_state, state_before, "同状态调用后状态不变（幂等无副作用）")


func test_set_state_changes_state() -> void:
	## AC-6 互补：不同状态切换 → 状态推进（合法转换序列——主菜单→身份选择
	## 有 ROW_TO_IDENTITY_SELECT 行；主菜单→战斗是 N/A 已由回滚测试覆盖）
	var am: AudioManager = AM_SCRIPT.new(null, _unavailable_adapter())
	am.set_state(AE.AudioState.MAIN_MENU)
	assert_eq(am._current_state, AE.AudioState.MAIN_MENU)
	am.set_state(AE.AudioState.IDENTITY_SELECT)
	assert_eq(am._current_state, AE.AudioState.IDENTITY_SELECT, "不同状态应推进 _current_state")


func test_set_state_n_a_transition_rolls_back() -> void:
	## N/A 转换回滚（code-review 阻塞项回归）：商店→战斗为 N/A——set_state 后
	## _current_state 保持源态（IN_SHOP）不推进，后续转换从正确源态出发
	var am: AudioManager = AM_SCRIPT.new(null, _unavailable_adapter())
	am.set_state(AE.AudioState.IN_SHOP)
	assert_eq(am._current_state, AE.AudioState.IN_SHOP, "前置：当前 IN_SHOP")
	am.set_state(AE.AudioState.IN_COMBAT)  # 商店→战斗 N/A
	assert_eq(am._current_state, AE.AudioState.IN_SHOP,
			"N/A 转换应回滚——状态保持 IN_SHOP（不推进到 IN_COMBAT）")
	# 后续转换从正确源态出发：商店→探索命中 ROW_RESTORE_NORMAL（duck_db=0）
	am.set_state(AE.AudioState.EXPLORING)
	assert_eq(am._current_state, AE.AudioState.EXPLORING,
			"N/A 后应从正确源态 IN_SHOP 出发（商店→探索 = 恢复 0dB 行）")


func test_set_state_identity_select_to_combat_is_n_a() -> void:
	## N/A 转换采样（QA 缺口 3）：身份选择→战斗也是 N/A（战败→非主菜单同理）
	var am: AudioManager = AM_SCRIPT.new(null, _unavailable_adapter())
	am.set_state(AE.AudioState.IDENTITY_SELECT)
	assert_eq(am._current_state, AE.AudioState.IDENTITY_SELECT)
	am.set_state(AE.AudioState.IN_COMBAT)
	assert_eq(am._current_state, AE.AudioState.IDENTITY_SELECT,
			"身份选择→战斗 N/A 应回滚——状态保持 IDENTITY_SELECT")


## 静默 adapter——AudioServer 不可用（set_state 路径不崩溃、幂等仍成立）。
func _unavailable_adapter() -> AudioServerAdapter:
	var adapter: AudioServerAdapter = ADAPTER_SCRIPT.new()
	adapter.unavailable = true
	return adapter
