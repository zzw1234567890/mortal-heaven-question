class_name StateTransitionMatrix
extends RefCounted
## StateTransitionMatrix —— 音频状态过渡矩阵 Logic 内核（audio-manager Story 004）。
##
## [b]职责[/b]：GDD §9 场景切换音频过渡矩阵（24 行）的唯一真源——数据驱动
## [constant STATE_TRANSITION_MATRIX] + 纯函数查询（[method transition_params] /
## [method map_transition_type]）。ADR-0031 §2 零状态所有权：全部纯函数，无状态、
## 无副作用、不访问 Autoload。[br]
## [br][b]行键[/b]：Vector2i(from_state, to_state)，[constant ANY_STATE](-1) 为通配哨兵
## ——编码 GDD §9 的「任意→X / X→任意」行（暂停双向、卡组编辑双向、修为养成双向）。[br]
## [br][b]行值字段[/b]：[br]
##   [code]bgm[/code]: StringName——切曲目标曲 id（[code]&""[/code] = 不切曲）；[br]
##   [code]fade_out_sec[/code]/[code]fade_in_sec[/code]: float——淡出/淡入时长；[br]
##   [code]duck_db[/code]: Variant——降低/恢复类 BGM 总线目标 dB（null = 切曲类）；[br]
##   [code]sequential[/code]: bool——顺序式（渡劫例外：先淡出完成再淡入）；[br]
##   [code]ambient_delta_db[/code]: float——环境音总线 dB 偏移（0 = 基准；-8 战斗 /
##   -6 事件商店——执行归 story 006 的 set_ambient_delta 接口，本 story 仅记录数据）；[br]
##   [code]action[/code]: StringName——特殊动作（[code]&"pause"[/code] /
##   [code]&"resume"[/code] / [code]&""[/code] = 常规 BGM 编排）。[br]
## [br][b]真源裁定[/b]（ADR-0031 + GDD 边界澄清 2026-09-07）：本矩阵为音频行为
## 唯一真源；SceneManager [code]TRANSITION_AUDIO_PARAMS[/code] 降级为场景级引用层；
## [BgmFadePlanner.params_for_state] 为按目标态塌缩的便捷查询——矩阵细分其缺口
## （战斗→探索 1.0s 淡入、事件→战斗 0.3s 淡出等，见本地常量注记）。[br]
## [br][b]N/A 转换[/b]（GDD §9 标记，不在矩阵中）：商店→战斗、身份选择→战斗、
## 战败→非主菜单。[br]
## [br][b]简化注记[/b]：卡组编辑/修为养成退出行（duck_db=0）恢复至常规 0dB——
## GDD「恢复前一状态 BGM」的精确还原（如从商店 -10dB 进入）归后续 story，
## 本 story 以「恢复至常规 0dB」为 MVP 基线。
##
## @experimental
## 来源: design/gdd/audio-system.md §9、audio Story 004、ADR-0031、
## src/ui/audio/bgm_fade_planner.gd。

## AudioEnums 脚本常量——class_name 在 headless 动态加载下不可靠，
## preload 脚本常量（S16-1/2/3 先例）。矩阵数值为编译时常量字面（时长/dB
## 与 BgmFadePlanner 同源——GDScript const Dictionary 不可引用脚本常量，
## 两处数值对齐由 test_state_matrix 交叉断言守护）。
const AE := preload("res://src/ui/audio/audio_enums.gd")

## === SceneManager 枚举镜像常量（环解耦——2026-10-29 code-review 阻塞项修复）=====
##
## [constant map_transition_type] 需消费 SceneManager 的 TransitionType / SceneID
## 枚举值，但 [code]preload("res://src/foundation/scene_manager.gd")[/code] 会闭合
## 三节点 preload 环（state_transition_matrix → scene_manager → audio_manager →
## 本脚本），违反 Foundation ← Presentation 单向依赖方向（ADR-0031 §1）。
## [br][b]解耦方案[/b]：枚举值在此以编译期字面常量镜像（唯一真源仍是
## scene_manager.gd 的 enum——两处数值对齐由
## [code]test_state_matrix.gd::test_matrix_enum_mirror_matches_scene_manager[/code]
## 交叉断言守护，枚举重排会触发测试失败而非静默漂移）。[br]
## [br][b]镜像范围[/b]：仅 map_transition_type 消费到的 5 类 TransitionType +
## 1 个 SceneID（IDENTITY_SELECT）——非全量复制。
const TT_NONE: int = 0
const TT_MENU_TO_GAME: int = 1
const TT_GAME_TO_MENU: int = 2
const TT_EXPLORE_TO_COMBAT: int = 3
const TT_COMBAT_TO_EXPLORE: int = 4
const TT_TRIBULATION: int = 5
const SCENE_IDENTITY_SELECT: int = 1

## 通配哨兵——「任意状态」行键分量（GDD §9 任意→X / X→任意）。
const ANY_STATE: int = -1

## BGM 曲目 id（GDD §4 BGM 曲目表——8 首；与 tests 既有先例命名一致）。
const BGM_MAIN_MENU: StringName = &"bgm_main_menu"
const BGM_EXPLORE: StringName = &"bgm_explore"
const BGM_COMBAT: StringName = &"bgm_combat"
const BGM_TRIBULATION: StringName = &"bgm_tribulation"
const BGM_VICTORY: StringName = &"bgm_victory"
const BGM_DEFEAT: StringName = &"bgm_defeat"

## === 环境音 dB 偏移常量（GDD §6/§9——矩阵行 ambient_delta_db 引用）===========

## 战斗环境音降低（-8dB——AC-AMBIENT-02：-10 - 8 = -18dB）。
const AMBIENT_COMBAT_DB: float = -8.0
## 事件/商店环境音降低（-6dB——AC-AMBIENT-02/§6）。
const AMBIENT_DUCK_DB: float = -6.0
## 环境音基准偏移（0 = 恢复 -10dB 出厂基准）。
const AMBIENT_NORMAL_DB: float = 0.0

## === 特殊动作 =================================================================

const ACTION_NONE: StringName = &""
const ACTION_PAUSE: StringName = &"pause"
const ACTION_RESUME: StringName = &"resume"

## 行字段键（执行层按键消费——与 BgmFadePlanner 指令键互补）。
const K_BGM: StringName = &"bgm"
const K_FADE_OUT_SEC: StringName = &"fade_out_sec"
const K_FADE_IN_SEC: StringName = &"fade_in_sec"
const K_DUCK_DB: StringName = &"duck_db"
const K_SEQUENTIAL: StringName = &"sequential"
const K_AMBIENT_DELTA_DB: StringName = &"ambient_delta_db"
const K_ACTION: StringName = &"action"

## 切曲类行——探索→战斗（0.5s/0.5s + 环境音 -8dB；探索与事件入口共用）。
const ROW_TO_COMBAT: Dictionary = {
	K_BGM: &"bgm_combat",
	K_FADE_OUT_SEC: 0.5,
	K_FADE_IN_SEC: 0.5,
	K_DUCK_DB: null,
	K_SEQUENTIAL: false,
	K_AMBIENT_DELTA_DB: -8.0,
	K_ACTION: &"",
}
## 切曲类行——事件→战斗（探索 BGM 快速淡出 0.3s / 战斗 BGM 淡入 0.5s；
## 环境音 -8dB——GDD §9 行「事件→战斗」与探索→战斗时长细分）。
const ROW_EVENT_TO_COMBAT: Dictionary = {
	K_BGM: &"bgm_combat",
	K_FADE_OUT_SEC: 0.3,
	K_FADE_IN_SEC: 0.5,
	K_DUCK_DB: null,
	K_SEQUENTIAL: false,
	K_AMBIENT_DELTA_DB: -8.0,
	K_ACTION: &"",
}
## 切曲类行——战斗→探索 / 通关结算→探索（战斗 BGM 淡出 1.0s / 探索 BGM 淡入 1.0s）。
const ROW_TO_EXPLORE: Dictionary = {
	K_BGM: &"bgm_explore",
	K_FADE_OUT_SEC: 1.0,
	K_FADE_IN_SEC: 1.0,
	K_DUCK_DB: null,
	K_SEQUENTIAL: false,
	K_AMBIENT_DELTA_DB: 0.0,
	K_ACTION: &"",
}
## 切曲类行——身份选择→探索（主菜单 BGM 淡出 1.0s / 地图 BGM 淡入 1.5s）。
const ROW_IDENTITY_TO_EXPLORE: Dictionary = {
	K_BGM: &"bgm_explore",
	K_FADE_OUT_SEC: 1.0,
	K_FADE_IN_SEC: 1.5,
	K_DUCK_DB: null,
	K_SEQUENTIAL: false,
	K_AMBIENT_DELTA_DB: 0.0,
	K_ACTION: &"",
}
## 切曲类行——战斗→通关（胜利 BGM 0.3s/0.5s）。
const ROW_TO_VICTORY: Dictionary = {
	K_BGM: &"bgm_victory",
	K_FADE_OUT_SEC: 0.3,
	K_FADE_IN_SEC: 0.5,
	K_DUCK_DB: null,
	K_SEQUENTIAL: false,
	K_AMBIENT_DELTA_DB: 0.0,
	K_ACTION: &"",
}
## 切曲类行——战斗→战败（战败 BGM 0.5s/0.3s）。
const ROW_TO_DEFEAT: Dictionary = {
	K_BGM: &"bgm_defeat",
	K_FADE_OUT_SEC: 0.5,
	K_FADE_IN_SEC: 0.3,
	K_DUCK_DB: null,
	K_SEQUENTIAL: false,
	K_AMBIENT_DELTA_DB: 0.0,
	K_ACTION: &"",
}
## 切曲类行——探索→渡劫（渡劫 BGM 0.3s/0.3s——顺序式，Boss 冲击感例外）。
const ROW_TO_TRIBULATION: Dictionary = {
	K_BGM: &"bgm_tribulation",
	K_FADE_OUT_SEC: 0.3,
	K_FADE_IN_SEC: 0.3,
	K_DUCK_DB: null,
	K_SEQUENTIAL: true,
	K_AMBIENT_DELTA_DB: 0.0,
	K_ACTION: &"",
}
## 切曲类行——回主菜单（1.0s 淡出 / 1.5s 淡入——战败/通关/探索回主菜单共用）。
const ROW_TO_MAIN_MENU: Dictionary = {
	K_BGM: &"bgm_main_menu",
	K_FADE_OUT_SEC: 1.0,
	K_FADE_IN_SEC: 1.5,
	K_DUCK_DB: null,
	K_SEQUENTIAL: false,
	K_AMBIENT_DELTA_DB: 0.0,
	K_ACTION: &"",
}
## 降低类行——主菜单→身份选择（主菜单 BGM 降至 -6dB，0.5s，不切曲）。
const ROW_TO_IDENTITY_SELECT: Dictionary = {
	K_BGM: &"",
	K_FADE_OUT_SEC: 0.5,
	K_FADE_IN_SEC: 0.5,
	K_DUCK_DB: -6.0,
	K_SEQUENTIAL: false,
	K_AMBIENT_DELTA_DB: 0.0,
	K_ACTION: &"",
}
## 恢复类行——身份选择/商店/事件→恢复 0dB（duck_db=0 = BGM 总线恢复常规 0dB）。
const ROW_RESTORE_NORMAL: Dictionary = {
	K_BGM: &"",
	K_FADE_OUT_SEC: 0.5,
	K_FADE_IN_SEC: 0.5,
	K_DUCK_DB: 0.0,
	K_SEQUENTIAL: false,
	K_AMBIENT_DELTA_DB: 0.0,
	K_ACTION: &"",
}
## 降低类行——探索→商店（探索 BGM 降至 -10dB，0.5s，不断播；环境音 -6dB）。
const ROW_TO_SHOP: Dictionary = {
	K_BGM: &"",
	K_FADE_OUT_SEC: 0.5,
	K_FADE_IN_SEC: 0.5,
	K_DUCK_DB: -10.0,
	K_SEQUENTIAL: false,
	K_AMBIENT_DELTA_DB: -6.0,
	K_ACTION: &"",
}
## 降低类行——探索→事件（探索 BGM 降至 -6dB，0.3s，不断播；环境音 -6dB）。
const ROW_TO_EVENT: Dictionary = {
	K_BGM: &"",
	K_FADE_OUT_SEC: 0.3,
	K_FADE_IN_SEC: 0.3,
	K_DUCK_DB: -6.0,
	K_SEQUENTIAL: false,
	K_AMBIENT_DELTA_DB: -6.0,
	K_ACTION: &"",
}
## 恢复类行——事件→探索（0.3s 恢复——GDD 矩阵行「事件→探索 0.3s」）。
const ROW_EVENT_TO_EXPLORE: Dictionary = {
	K_BGM: &"",
	K_FADE_OUT_SEC: 0.3,
	K_FADE_IN_SEC: 0.3,
	K_DUCK_DB: 0.0,
	K_SEQUENTIAL: false,
	K_AMBIENT_DELTA_DB: 0.0,
	K_ACTION: &"",
}
## 降低类行——任意→卡组编辑/修为养成（BGM 降至 -12dB，0.5s）。
const ROW_TO_DUCK_CULTIVATE: Dictionary = {
	K_BGM: &"",
	K_FADE_OUT_SEC: 0.5,
	K_FADE_IN_SEC: 0.5,
	K_DUCK_DB: -12.0,
	K_SEQUENTIAL: false,
	K_AMBIENT_DELTA_DB: 0.0,
	K_ACTION: &"",
}
## 特殊动作行——暂停（任意→暂停 = pause_all）。时长 0（无 BGM 淡化——
## pause_all 为瞬态暂停行为，非 dB 过渡）。
const ROW_ACTION_PAUSE: Dictionary = {
	K_BGM: &"",
	K_FADE_OUT_SEC: 0.0,
	K_FADE_IN_SEC: 0.0,
	K_DUCK_DB: null,
	K_SEQUENTIAL: false,
	K_AMBIENT_DELTA_DB: 0.0,
	K_ACTION: &"pause",
}
## 特殊动作行——恢复（暂停→任意 = resume_all）。
const ROW_ACTION_RESUME: Dictionary = {
	K_BGM: &"",
	K_FADE_OUT_SEC: 0.0,
	K_FADE_IN_SEC: 0.0,
	K_DUCK_DB: null,
	K_SEQUENTIAL: false,
	K_AMBIENT_DELTA_DB: 0.0,
	K_ACTION: &"resume",
}


## === 入口 BGM 映射（引导进入——无前置状态时的直接入场）====================

## 各切曲类状态的入口 BGM id（引导进入用；duck/no-bgm 态不在表中 → &""）。
## 引导进入（from_state = -1）时经 [method entry_bgm] 查询，配合
## [BgmFadePlanner.params_for_state] 的目标态参数直接淡入——无需前置状态。
const STATE_ENTRY_BGM: Dictionary = {
	AE.AudioState.MAIN_MENU: BGM_MAIN_MENU,
	AE.AudioState.EXPLORING: BGM_EXPLORE,
	AE.AudioState.IN_COMBAT: BGM_COMBAT,
	AE.AudioState.IN_TRIBULATION: BGM_TRIBULATION,
	AE.AudioState.MAP_CLEARED: BGM_VICTORY,
	AE.AudioState.DEFEATED: BGM_DEFEAT,
}


## 目标状态的入口 BGM id（引导进入）。[br]
## [br][b]返回[/b]：切曲类目标态返回其入口曲 id；duck/no-bgm 态返回 &""。
static func entry_bgm(target_state: int) -> StringName:
	return STATE_ENTRY_BGM.get(target_state, &"")


## === GDD §9 过渡矩阵（24 行——唯一真源）========================================

const STATE_TRANSITION_MATRIX: Dictionary = {
	# ── 主菜单 ↔ 身份选择（降低/恢复，不切曲）────────────────────────────
	Vector2i(AE.AudioState.MAIN_MENU, AE.AudioState.IDENTITY_SELECT):
			ROW_TO_IDENTITY_SELECT,
	Vector2i(AE.AudioState.IDENTITY_SELECT, AE.AudioState.MAIN_MENU):
			ROW_RESTORE_NORMAL,
	# ── 身份选择 → 探索（切曲）────────────────────────────────────────────
	Vector2i(AE.AudioState.IDENTITY_SELECT, AE.AudioState.EXPLORING):
			ROW_IDENTITY_TO_EXPLORE,
	# ── 探索 ↔ 战斗（切曲 0.5s；进入战斗环境音 -8dB）──────────────────────
	Vector2i(AE.AudioState.EXPLORING, AE.AudioState.IN_COMBAT):
			ROW_TO_COMBAT,
	Vector2i(AE.AudioState.IN_COMBAT, AE.AudioState.EXPLORING):
			ROW_TO_EXPLORE,
	# ── 探索 ↔ 商店（降低 -10dB 不断播 / 恢复 0dB）─────────────────────────
	Vector2i(AE.AudioState.EXPLORING, AE.AudioState.IN_SHOP):
			ROW_TO_SHOP,
	Vector2i(AE.AudioState.IN_SHOP, AE.AudioState.EXPLORING):
			ROW_RESTORE_NORMAL,
	# ── 探索 ↔ 事件（降低 -6dB 不断播 / 恢复 0dB）─────────────────────────
	Vector2i(AE.AudioState.EXPLORING, AE.AudioState.IN_EVENT):
			ROW_TO_EVENT,
	Vector2i(AE.AudioState.IN_EVENT, AE.AudioState.EXPLORING):
			ROW_EVENT_TO_EXPLORE,
	# ── 事件 → 战斗（切曲：探索 BGM 快速淡出 0.3s / 战斗 BGM 淡入 0.5s）────
	Vector2i(AE.AudioState.IN_EVENT, AE.AudioState.IN_COMBAT):
			ROW_EVENT_TO_COMBAT,
	# ── 战斗 → 通关 / 战败（切曲）────────────────────────────────────────
	Vector2i(AE.AudioState.IN_COMBAT, AE.AudioState.MAP_CLEARED):
			ROW_TO_VICTORY,
	Vector2i(AE.AudioState.IN_COMBAT, AE.AudioState.DEFEATED):
			ROW_TO_DEFEAT,
	# ── 探索 → 渡劫（切曲 0.3s/0.3s——顺序式，Boss 冲击感例外）──────────────
	Vector2i(AE.AudioState.EXPLORING, AE.AudioState.IN_TRIBULATION):
			ROW_TO_TRIBULATION,
	# ── 渡劫战 → 通关 / 战败（切曲）───────────────────────────────────────
	Vector2i(AE.AudioState.IN_TRIBULATION, AE.AudioState.MAP_CLEARED):
			ROW_TO_VICTORY,
	Vector2i(AE.AudioState.IN_TRIBULATION, AE.AudioState.DEFEATED):
			ROW_TO_DEFEAT,
	# ── 通关结算 → 探索 / 主菜单（切曲）───────────────────────────────────
	Vector2i(AE.AudioState.MAP_CLEARED, AE.AudioState.EXPLORING):
			ROW_TO_EXPLORE,
	Vector2i(AE.AudioState.MAP_CLEARED, AE.AudioState.MAIN_MENU):
			ROW_TO_MAIN_MENU,
	# ── 战败 → 主菜单（切曲；战败→非主菜单为 N/A）────────────────────────
	Vector2i(AE.AudioState.DEFEATED, AE.AudioState.MAIN_MENU):
			ROW_TO_MAIN_MENU,
	# ── 暂停双向（任意→暂停 = pause_all；暂停→任意 = resume_all）───────────
	Vector2i(ANY_STATE, AE.AudioState.PAUSED): ROW_ACTION_PAUSE,
	Vector2i(AE.AudioState.PAUSED, ANY_STATE): ROW_ACTION_RESUME,
	# ── 卡组编辑双向（任意→卡组编辑 降低 -12dB / 卡组编辑→任意 恢复 0dB）────
	Vector2i(ANY_STATE, AE.AudioState.DECK_EDITING):
			ROW_TO_DUCK_CULTIVATE,
	Vector2i(AE.AudioState.DECK_EDITING, ANY_STATE):
			ROW_RESTORE_NORMAL,
	# ── 修为养成双向（任意→修为养成 降低 -12dB / 修为养成→任意 恢复 0dB）────
	Vector2i(ANY_STATE, AE.AudioState.CULTIVATING):
			ROW_TO_DUCK_CULTIVATE,
	Vector2i(AE.AudioState.CULTIVATING, ANY_STATE):
			ROW_RESTORE_NORMAL,
}


## === 纯函数查询 ===============================================================

## 查询 (from_state, to_state) 的矩阵行。[br]
## [br][b]匹配顺序[/b]（短路）：精确行 → 任意→to（[constant ANY_STATE] 通配）→
## from→任意 → 空。[br]
## [br][b]空 Dictionary 语义[/b]：无该转换（N/A 或未定义）——调用侧 no-op 幂等。[br]
## [br][param from_state]: 源状态（[enum AudioEnums.AudioState]）。[br]
## [param to_state]: 目标状态（[enum AudioEnums.AudioState]）。[br]
## [b]返回[/b]：行 Dictionary（键见类头注记）；无匹配返回空。
static func transition_params(from_state: int, to_state: int) -> Dictionary:
	if from_state == to_state:
		return {}
	if STATE_TRANSITION_MATRIX.has(Vector2i(from_state, to_state)):
		return STATE_TRANSITION_MATRIX[Vector2i(from_state, to_state)]
	if STATE_TRANSITION_MATRIX.has(Vector2i(ANY_STATE, to_state)):
		return STATE_TRANSITION_MATRIX[Vector2i(ANY_STATE, to_state)]
	if STATE_TRANSITION_MATRIX.has(Vector2i(from_state, ANY_STATE)):
		return STATE_TRANSITION_MATRIX[Vector2i(from_state, ANY_STATE)]
	return {}


## SceneManager TransitionType → AudioState 目标态映射（场景级转换引用层——
## 唯一真源仍为 [constant STATE_TRANSITION_MATRIX]，本映射只决定「转场类型触发
## 哪个 set_state 目标」；时长数值以矩阵行为准）。[br]
## [br][b]覆盖[/b]：5 类 TransitionType（NONE 除外）→ AudioState 目标态。[br]
## [br][b]返回[/b]：目标 AudioState 枚举值；未映射返回 -1（防御性——调用侧跳过）。[br]
## [br][b]枚举来源[/b]：经本地镜像常量（[constant TT_MENU_TO_GAME] 等）消费——
## 不 preload scene_manager.gd（环解耦，见类头镜像注记）。
static func map_transition_type(from_scene: int, to_scene: int, type: int) -> int:
	match type:
		TT_MENU_TO_GAME:
			return _to_menu_game_state(to_scene)
		TT_GAME_TO_MENU:
			return AE.AudioState.MAIN_MENU
		TT_EXPLORE_TO_COMBAT:
			return AE.AudioState.IN_COMBAT
		TT_COMBAT_TO_EXPLORE:
			return AE.AudioState.EXPLORING
		TT_TRIBULATION:
			return AE.AudioState.IN_TRIBULATION
	return -1


## 矩阵完整性校验（AC-1/AC-2——测试中执行）。[br]
## [br][b]返回[/b]：Dictionary {ok: bool, errors: Array[String]}。[br]
## [br][b]校验项[/b]：12 态每态至少 1 入边或 1 出边；行数 = 24；每行参数完备
## 且在调优旋钮安全范围；N/A 转换（3 项）不存在于矩阵。
static func validate_matrix() -> Dictionary:
	var errors: Array = []
	# 12 态每态至少 1 入边或 1 出边（含 CULTIVATING）
	var has_edge: Dictionary = {}
	for key: Vector2i in STATE_TRANSITION_MATRIX.keys():
		if key.x != ANY_STATE:
			has_edge[key.x] = true
		if key.y != ANY_STATE:
			has_edge[key.y] = true
	for name: String in AE.AudioState.keys():
		var state: int = AE.AudioState[name]
		if not has_edge.get(state, false):
			errors.append("状态 %s(%d) 无入边/出边" % [name, state])
	# 行数 = 24
	if STATE_TRANSITION_MATRIX.size() != 24:
		errors.append("矩阵行数 %d 不等于 24" % STATE_TRANSITION_MATRIX.size())
	# N/A 转换（3 项）不存在
	var n_a: Array = [
		Vector2i(AE.AudioState.IN_SHOP, AE.AudioState.IN_COMBAT),
		Vector2i(AE.AudioState.IDENTITY_SELECT, AE.AudioState.IN_COMBAT),
		Vector2i(AE.AudioState.DEFEATED, AE.AudioState.IDENTITY_SELECT),
		Vector2i(AE.AudioState.DEFEATED, AE.AudioState.EXPLORING),
	]
	for n_a_key: Vector2i in n_a:
		if STATE_TRANSITION_MATRIX.has(n_a_key):
			errors.append("N/A 转换 %s 不应存在于矩阵" % str(n_a_key))
	# 每行参数完备 + 安全范围
	for key: Vector2i in STATE_TRANSITION_MATRIX.keys():
		var row: Dictionary = STATE_TRANSITION_MATRIX[key]
		if not _validate_row(key, row):
			errors.append("行 %s 参数不完备或越界" % str(key))
	return {"ok": errors.is_empty(), "errors": errors}


## 单行参数校验（键齐全 + 时长/dB 在调优旋钮安全范围）。[br]
## 特殊动作行（pause/resume）时长 0——豁免时长范围校验（无淡化）。
static func _validate_row(key: Vector2i, row: Dictionary) -> bool:
	for required_key: StringName in [K_BGM, K_FADE_OUT_SEC, K_FADE_IN_SEC, K_DUCK_DB,
			K_SEQUENTIAL, K_AMBIENT_DELTA_DB, K_ACTION]:
		if not row.has(required_key):
			return false
	if row[K_ACTION] != ACTION_NONE:
		return true  # 特殊动作行——时长 0 合法（pause/resume 非淡化）
	var fade_out: float = float(row[K_FADE_OUT_SEC])
	var fade_in: float = float(row[K_FADE_IN_SEC])
	# 调优旋钮安全范围（GDD 调优参数表：淡出 0.3~2.0 / 淡入 0.2~3.0）
	if fade_out < 0.3 or fade_out > 2.0:
		return false
	if fade_in < 0.2 or fade_in > 3.0:
		return false
	if row[K_DUCK_DB] != null:
		var duck: float = float(row[K_DUCK_DB])
		# 降低/恢复类 dB 安全范围（GDD：商店 -6~-15 / 事件 -3~-10 / 恢复 0）
		if duck < -15.0 or duck > 0.0:
			return false
	return true


## === 内部辅助 =================================================================

## 主菜单→游戏类转换：目标场景决定 AudioState（身份选择 vs 探索）。
## [br][param to_scene]: 目标场景 ID（[constant SCENE_IDENTITY_SELECT] 镜像值）。
static func _to_menu_game_state(to_scene: int) -> int:
	if to_scene == SCENE_IDENTITY_SELECT:
		return AE.AudioState.IDENTITY_SELECT
	return AE.AudioState.EXPLORING
