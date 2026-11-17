extends GutTest
## BattleRecordExit —— 结算屏出口裁决的纯逻辑回归。[br]
## [br][b]为什么需要本文件[/b]：战败屏与胜利结算屏此前共用「一律回探索」这一个出口，
## 而规格要求战败回主菜单（design/ux/pause-menu.md §Events Fired 战斗投降链 /
## design/gdd/audio-system.md §9 把「战败→任意非主菜单状态」列为 N/A 转换）。
## 本文件把裁决的三项产出——目的地 / 转场类型 / 按钮文案——逐条钉死，并守住它们
## [b]同进同退[/b]（一个屏幕不能「按钮写着回主菜单、实际转场去探索」）。[br]
## [br][b]为什么是单测而不是只靠场景用例[/b]：这三项是纯映射，能在没有控件树、
## 没有 SceneManager 的用例里把每个屏 ID 摆出来比对；场景用例只证明「接上了」，
## 证不了「所有取值都对」。[br]
## [br]来源: design/ux/pause-menu.md（§Events Fired / §Interaction Map 第 314 行）、
## design/gdd/audio-system.md §9、ADR-0005、ADR-0031 §2。

const ExitScript := preload("res://src/ui/shared/battle_record_exit.gd")
const SM := preload("res://src/foundation/scene_manager.gd")

## 回探索的四块屏（胜利结算 + 三个非战斗占位屏）。
const EXPLORE_SCREENS: Array[int] = [
	SM.SceneID.DECK_EDITING,
	SM.SceneID.SHOP,
	SM.SceneID.RESULT_SCREEN,
	SM.SceneID.CULTIVATION,
]


# ═══════════════════════════════════════════════════════════════════════════════
# 目的地
# ═══════════════════════════════════════════════════════════════════════════════

func test_defeat_screen_returns_to_main_menu() -> void:
	assert_eq(ExitScript.target_scene(SM.SceneID.DEFEAT_SCREEN), SM.SceneID.MAIN_MENU,
			"战败屏应回主菜单（本局已结束，不该继续探索）")


func test_result_screen_returns_to_exploration() -> void:
	assert_eq(ExitScript.target_scene(SM.SceneID.RESULT_SCREEN), SM.SceneID.EXPLORATION,
			"胜利结算屏应回探索（奖励已入账，玩家继续玩下去）")


func test_other_placeholder_screens_return_to_exploration() -> void:
	for screen_id: int in EXPLORE_SCREENS:
		assert_eq(ExitScript.target_scene(screen_id), SM.SceneID.EXPLORATION,
				"屏 %d 应回探索" % screen_id)


func test_unknown_screen_id_falls_back_to_exploration() -> void:
	## 未登记的屏按「继续玩下去」处理——把玩家丢回主菜单比留在原地更糟。
	assert_eq(ExitScript.target_scene(-1), SM.SceneID.EXPLORATION, "未知屏应回探索")
	assert_eq(ExitScript.target_scene(SM.SceneID.LOADING), SM.SceneID.EXPLORATION,
			"加载屏不在本模块的范围内，应按回探索处理")


# ═══════════════════════════════════════════════════════════════════════════════
# 转场类型（驱动音频 BGM 过渡）
# ═══════════════════════════════════════════════════════════════════════════════

func test_defeat_transition_is_game_to_menu() -> void:
	## 音频矩阵的 DEFEATED → MAIN_MENU 行由它索引；错用 COMBAT_TO_EXPLORE 会把
	## 战败 BGM 接到探索 BGM 上（战败的唯一出边是主菜单）。
	assert_eq(ExitScript.transition_type(SM.SceneID.DEFEAT_SCREEN),
			SM.TransitionType.GAME_TO_MENU, "战败转场类型应为 GAME_TO_MENU")


func test_result_transition_is_combat_to_explore() -> void:
	assert_eq(ExitScript.transition_type(SM.SceneID.RESULT_SCREEN),
			SM.TransitionType.COMBAT_TO_EXPLORE, "胜利结算转场类型应为 COMBAT_TO_EXPLORE")


# ═══════════════════════════════════════════════════════════════════════════════
# 按钮文案
# ═══════════════════════════════════════════════════════════════════════════════

func test_defeat_button_names_its_destination() -> void:
	assert_eq(ExitScript.button_text(SM.SceneID.DEFEAT_SCREEN),
			ExitScript.TEXT_RETURN_MAIN_MENU, "战败屏按钮应写明「返回主菜单」")


func test_result_button_names_its_destination() -> void:
	assert_eq(ExitScript.button_text(SM.SceneID.RESULT_SCREEN),
			ExitScript.TEXT_RETURN_EXPLORE, "胜利屏按钮应写明「返回探索」")


func test_no_button_text_is_the_vague_return() -> void:
	## 「返回」二字单独成词时玩家分不清回的是哪一层——两块屏都要写明目的地。
	for screen_id: int in EXPLORE_SCREENS + [SM.SceneID.DEFEAT_SCREEN]:
		var text: String = ExitScript.button_text(screen_id)
		assert_ne(text, "返回", "屏 %d 的按钮文案不得是含糊的「返回」" % screen_id)
		assert_true(text.begins_with("返回"), "屏 %d 的按钮文案应以「返回」起头" % screen_id)


func test_two_settlement_screens_have_distinct_labels() -> void:
	assert_ne(ExitScript.button_text(SM.SceneID.DEFEAT_SCREEN),
			ExitScript.button_text(SM.SceneID.RESULT_SCREEN),
			"战败屏与胜利屏并排看时文案必须能区分")


# ═══════════════════════════════════════════════════════════════════════════════
# 三项同进同退
# ═══════════════════════════════════════════════════════════════════════════════

func test_label_and_target_never_disagree() -> void:
	## 文案 / 目的地 / 转场类型是同一次裁决的三个面——不能出现「写着回主菜单、
	## 实际去探索」。判据用文案里出现的目的地词条比对实际目标。
	for screen_id: int in EXPLORE_SCREENS + [SM.SceneID.DEFEAT_SCREEN]:
		var text: String = ExitScript.button_text(screen_id)
		var target: int = ExitScript.target_scene(screen_id)
		var type: int = ExitScript.transition_type(screen_id)
		if text == ExitScript.TEXT_RETURN_MAIN_MENU:
			assert_eq(target, SM.SceneID.MAIN_MENU, "写着回主菜单就该去主菜单")
			assert_eq(type, SM.TransitionType.GAME_TO_MENU, "回主菜单应配 GAME_TO_MENU")
		else:
			assert_eq(target, SM.SceneID.EXPLORATION, "写着回探索就该去探索")
			assert_eq(type, SM.TransitionType.COMBAT_TO_EXPLORE,
					"回探索应配 COMBAT_TO_EXPLORE")


func test_returns_to_exploration_matches_target() -> void:
	## 收尾判定（「胜利则标节点已清」）与目的地同源——不能各写一份屏 ID 比较。
	assert_true(ExitScript.returns_to_exploration(SM.SceneID.RESULT_SCREEN),
			"胜利结算回探索，需要跑探索侧收尾")
	assert_false(ExitScript.returns_to_exploration(SM.SceneID.DEFEAT_SCREEN),
			"战败回主菜单，不需要（也不该）跑探索侧收尾")


# ═══════════════════════════════════════════════════════════════════════════════
# 与音频矩阵的一致性
# ═══════════════════════════════════════════════════════════════════════════════

func test_defeat_to_main_menu_row_exists_in_audio_matrix() -> void:
	## 战败回主菜单这条路径在音频矩阵里必须有对应行——本模块选的转场类型要能真的
	## 索引到一条过渡参数，否则转场时 BGM 无参数可用。
	const MatrixScript := preload("res://src/ui/audio/state_transition_matrix.gd")
	const AudioEnumsScript := preload("res://src/ui/audio/audio_enums.gd")
	var mapped: int = MatrixScript.map_transition_type(SM.SceneID.DEFEAT_SCREEN,
			SM.SceneID.MAIN_MENU, ExitScript.transition_type(SM.SceneID.DEFEAT_SCREEN))
	assert_eq(mapped, AudioEnumsScript.AudioState.MAIN_MENU,
			"GAME_TO_MENU 应映射到主菜单音频态")
	var row: Dictionary = MatrixScript.transition_params(AudioEnumsScript.AudioState.DEFEATED,
			mapped)
	assert_false(row.is_empty(), "战败 → 主菜单 应在音频矩阵里有过渡参数")


func test_defeat_to_exploration_is_not_a_mapped_transition() -> void:
	## 反向钉死：战败回探索这条（现已不再走的）路在矩阵里是 N/A——若哪天有人把
	## 战败屏改回探索，本断言与音频矩阵会同时亮红（两条独立证据）。
	const MatrixScript := preload("res://src/ui/audio/state_transition_matrix.gd")
	const AudioEnumsScript := preload("res://src/ui/audio/audio_enums.gd")
	var row: Dictionary = MatrixScript.transition_params(AudioEnumsScript.AudioState.DEFEATED,
			AudioEnumsScript.AudioState.EXPLORING)
	assert_true(row.is_empty(), "战败 → 探索 是 N/A 转换，矩阵里不应有这一行")
	assert_eq(MatrixScript.map_transition_type(SM.SceneID.DEFEAT_SCREEN,
			SM.SceneID.EXPLORATION, SM.TransitionType.COMBAT_TO_EXPLORE),
			AudioEnumsScript.AudioState.EXPLORING,
			"（对照）COMBAT_TO_EXPLORE 自身映射到探索态——问题出在战败不该用它")
