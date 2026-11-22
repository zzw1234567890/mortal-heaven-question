extends RefCounted
## StateTransitionRows —— 音频过渡的[b]行值词表[/b]（GDD §9 矩阵的行数据源）。
##
## [b]职责[/b]：只放数据——行字段键、BGM 曲目 id、环境音 dB 偏移、特殊动作、
## 16 条行值字典、各切曲态入口曲映射。没有任何行为，没有查询函数。[br]
## [br][b]为什么与矩阵分开[/b]：[code]state_transition_matrix.gd[/code] 要做的是
## 「查哪一行、校验行是否合规」（行为），本文件是「行里写什么」（数据）。两者原本
## 同处一文件超 400 行——行值一条条加下去（商店、事件、渡劫、养成）时，查询逻辑被
## 埋在两百行常量后面，改一边要翻过另一边。切分后加行只碰本文件，改查询只碰矩阵。[br]
## [br][b]数值全为字面[/b]：GDScript 的 const Dictionary 不能引用其它脚本常量，
## 故时长/dB 在此以字面书写（与 [BgmFadePlanner] 常量同源——两处对齐由
## [code]test_state_matrix.gd[/code] 的交叉断言守护，不靠人眼）。[br]
## [br][b]行键口径[/b]：字段键 [constant K_*] 是执行层（[code]audio_manager.gd[/code]）
## 消费字典的键名，唯一出处在此——矩阵转发、执行层引用，不各写一份字符串。
##
## 来源: design/gdd/audio-system.md §4/§6/§9、audio-manager Story 004、ADR-0031。

## AudioEnums 脚本常量——class_name 在 headless 动态加载下不可靠，
## preload 脚本常量（S16-1/2/3 先例）。供 [constant STATE_ENTRY_BGM] 的行键使用。
const AE := preload("res://src/ui/audio/audio_enums.gd")

## === BGM 曲目 id（GDD §4 BGM 曲目表——8 首；与 tests 既有先例命名一致）=========

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

## === 行值 =====================================================================

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
## 引导进入（from_state = -1）时经 [code]StateTransitionMatrix.entry_bgm[/code]
## 查询，配合 [BgmFadePlanner.params_for_state] 的目标态参数直接淡入——
## 无需前置状态。
const STATE_ENTRY_BGM: Dictionary = {
	AE.AudioState.MAIN_MENU: BGM_MAIN_MENU,
	AE.AudioState.EXPLORING: BGM_EXPLORE,
	AE.AudioState.IN_COMBAT: BGM_COMBAT,
	AE.AudioState.IN_TRIBULATION: BGM_TRIBULATION,
	AE.AudioState.MAP_CLEARED: BGM_VICTORY,
	AE.AudioState.DEFEATED: BGM_DEFEAT,
}
