class_name BgmFadePlanner
extends RefCounted
## BgmFadePlanner —— BGM 交叉淡化纯计划器（audio-manager Story 002）。
##
## [b]职责[/b]：全部 BGM 过渡数值决策的唯一落地处（control-manifest
## Required pattern——「淡化编排提取为纯计划器函数，Tween 为薄执行层」）。[br]
## [br][b]纯函数[/b]（ADR-0031 Logic 内核模式）：[method plan_transition]
## 无状态、无副作用、确定映射——输入 (当前 id / 目标 id / 当前 dB / 参数)，
## 输出淡化指令集（目标播放器/起止 dB/时长/曲线/顺序标记），Tween 只执行。[br]
## [br][b]决策内容[/b]（GDD §9 过渡矩阵 + 公式 1）：[br]
##   - 平行交叉淡化（默认）vs 顺序式（渡劫例外）[br]
##   - 降低类（商店/事件/修为/卡编）单条 Bus 指令不切曲[br]
##   - 中断续接：新计划以**当前实际 dB** 为起点（非 -80）[br]
##   - 同 bgm_id 重复请求 → 空计划[br]
## [br][b]dB 常量[/b]：静音下限 -80 与各场景目标 dB 集中定义（数据驱动条款）。
##
## @experimental
## 来源: design/gdd/audio-system.md §9/§公式 1、audio Story 002、ADR-0031。

## 静音下限（dB）——淡出终点（AudioServer 等效无声）。
const SILENCE_DB: float = -80.0

## === 场景目标 dB（GDD §9 过渡矩阵数值——集中定义）=========================

## 主菜单/探索/战斗常规 BGM 音量（BGM Bus 参考基准 0dB）。
const NORMAL_DB: float = 0.0
## 身份选择降低（-6dB，0.5s）。
const IDENTITY_SELECT_DB: float = -6.0
## 事件中降低（-6dB，0.3s，不断播）。
const EVENT_DB: float = -6.0
## 商店中降低（-10dB，0.5s，不断播）。
const SHOP_DB: float = -10.0
## 卡组编辑/修为养成降低（-12dB，0.5s）。
const CULTIVATE_DB: float = -12.0

## === 过渡时长（GDD §9 矩阵——切曲类）=======================================

## 身份选择→探索：主菜单 BGM 淡出 1.0s + 探索 BGM 淡入 1.5s。
const FADE_OUT_TO_EXPLORING_SEC: float = 1.0
const FADE_IN_TO_EXPLORING_SEC: float = 1.5
## 探索→战斗 0.5s/0.5s。
const FADE_OUT_TO_COMBAT_SEC: float = 0.5
const FADE_IN_TO_COMBAT_SEC: float = 0.5
## 战斗→胜利 0.3s/0.5s。
const FADE_OUT_TO_VICTORY_SEC: float = 0.3
const FADE_IN_TO_VICTORY_SEC: float = 0.5
## 战斗→战败 0.5s/0.3s。
const FADE_OUT_TO_DEFEAT_SEC: float = 0.5
const FADE_IN_TO_DEFEAT_SEC: float = 0.3
## 渡劫入口 0.3s/0.3s——顺序式（先淡出完成再淡入，Boss 冲击感例外）。
const FADE_OUT_TO_TRIBULATION_SEC: float = 0.3
const FADE_IN_TO_TRIBULATION_SEC: float = 0.3
## 降低/恢复类时长。
const DUCK_SEC: float = 0.5
## 恢复类（事件→探索 0.3s 矩阵行）。
const RESTORE_EVENT_SEC: float = 0.3

## === 指令键（计划器输出 Dictionary 契约——执行层按键消费）===================

## 指令类型：PLAYER_FADE（播放器 dB 过渡）/ BUS_FADE（BGM 总线 dB 过渡）。
const CMD_PLAYER_FADE: StringName = &"player_fade"
const CMD_BUS_FADE: StringName = &"bus_fade"
## 指令字段键。
const K_TARGET: StringName = &"target"          # "a" / "b" / "bus"
const K_FROM_DB: StringName = &"from_db"
const K_TO_DB: StringName = &"to_db"
const K_DURATION: StringName = &"duration_sec"
const K_SEQUENTIAL: StringName = &"sequential"  # true = 前序完成后再执行
const K_STOP_AFTER: StringName = &"stop_after"  # true = 到达 to_db 后停止播放
const K_PLAY_STREAM: StringName = &"play_stream"  # 非 null = 开始播放该 bgm_id


## 计划一次 BGM 过渡。[br]
## [br][b]决策表[/b]：[br]
##   1. [param target_id] == [param current_id]（含均为空）→ 空计划（AC-BGM-09）[br]
##   2. target_id 为空 → 仅淡出当前播放器（stop_bgm 语义）[br]
##   3. duck 目标 dB 非 null 且无切曲（降低类）→ 单条 BUS_FADE 指令[br]
##   4. 切曲 → 两条 PLAYER_FADE（平行默认 / sequential 渡劫例外）；
##      新播放器起点 = [param target_from_db]（中断续接传当前实际 dB，
##      首次播放传 SILENCE_DB）[br]
## [br][param current_id]: 当前播放 BGM id（空 = 无播放）。[br]
## [param target_id]: 目标 BGM id（空 = 停止）。[br]
## [param current_from_db]: 当前播放器起始 dB（中断续接——旧 Tween kill 后
## 新计划从当前实际 dB 续接；调用侧传当前实际读数）。[br]
## [param target_from_db]: 目标播放器起始 dB（中断续接传实际值；首播传 -80）。[br]
## [param fade_out_sec]: 淡出时长。[param fade_in_sec]: 淡入时长。[br]
## [param duck_db]: 降低类目标 dB（null = 非降低类）。[br]
## [param sequential]: true 顺序式（渡劫例外——先淡出完成再淡入）。[br]
## [b]返回[/b]: Array[Dictionary] 指令集（空 = 忽略请求）。
static func plan_transition(current_id: StringName, target_id: StringName,
		current_from_db: float, target_from_db: float,
		fade_out_sec: float = 0.5, fade_in_sec: float = 0.5,
		duck_db: Variant = null, sequential: bool = false) -> Array[Dictionary]:
	# 降低类优先判定：BGM 不变（target == current 是常态——AC-BGM-06 不断播），
	# 仅总线音量变化，故须先于同 id 忽略检查
	if duck_db != null:
		var commands_duck: Array[Dictionary] = [{
			K_TARGET: &"bus",
			K_FROM_DB: current_from_db,
			K_TO_DB: float(duck_db),
			K_DURATION: fade_out_sec,
			K_SEQUENTIAL: false,
			K_STOP_AFTER: false,
			K_PLAY_STREAM: StringName(&""),
		}]
		return commands_duck
	# 1. 同 id 忽略（含双空——无事可做）
	if target_id == current_id:
		return []
	var commands: Array[Dictionary] = []
	# 2. 仅停止（无目标曲）
	if target_id == &"":
		if current_id == &"":
			return []
		commands.append({
			K_TARGET: &"a",
			K_FROM_DB: current_from_db,
			K_TO_DB: SILENCE_DB,
			K_DURATION: fade_out_sec,
			K_SEQUENTIAL: false,
			K_STOP_AFTER: true,
			K_PLAY_STREAM: StringName(&""),
		})
		return commands
	# 4. 切曲：双播放器交叉淡化（当前 a 淡出 / 目标 b 淡入）
	commands.append({
		K_TARGET: &"a",
		K_FROM_DB: current_from_db,
		K_TO_DB: SILENCE_DB,
		K_DURATION: fade_out_sec,
		K_SEQUENTIAL: false,
		K_STOP_AFTER: current_id != &"",
		K_PLAY_STREAM: StringName(&""),
	})
	commands.append({
		K_TARGET: &"b",
		K_FROM_DB: target_from_db,
		K_TO_DB: NORMAL_DB,
		K_DURATION: fade_in_sec,
		K_SEQUENTIAL: sequential,
		K_STOP_AFTER: false,
		K_PLAY_STREAM: target_id,
	})
	return commands


## GDD §9 矩阵行 → 过渡参数查询（切曲类时长真源）。[br]
## [br][param target_state]: 目标 [enum AudioEnums.AudioState]。[br]
## [b]返回[/b]: Dictionary {fade_out_sec, fade_in_sec, duck_db, sequential}。
static func params_for_state(target_state: int) -> Dictionary:
	match target_state:
		AudioEnums.AudioState.EXPLORING:
			return {"fade_out_sec": FADE_OUT_TO_EXPLORING_SEC,
				"fade_in_sec": FADE_IN_TO_EXPLORING_SEC, "duck_db": null,
				"sequential": false}
		AudioEnums.AudioState.IN_COMBAT:
			return {"fade_out_sec": FADE_OUT_TO_COMBAT_SEC,
				"fade_in_sec": FADE_IN_TO_COMBAT_SEC, "duck_db": null,
				"sequential": false}
		AudioEnums.AudioState.IN_TRIBULATION:
			return {"fade_out_sec": FADE_OUT_TO_TRIBULATION_SEC,
				"fade_in_sec": FADE_IN_TO_TRIBULATION_SEC, "duck_db": null,
				"sequential": true}
		AudioEnums.AudioState.MAP_CLEARED:
			return {"fade_out_sec": FADE_OUT_TO_VICTORY_SEC,
				"fade_in_sec": FADE_IN_TO_VICTORY_SEC, "duck_db": null,
				"sequential": false}
		AudioEnums.AudioState.DEFEATED:
			return {"fade_out_sec": FADE_OUT_TO_DEFEAT_SEC,
				"fade_in_sec": FADE_IN_TO_DEFEAT_SEC, "duck_db": null,
				"sequential": false}
		AudioEnums.AudioState.IDENTITY_SELECT:
			return {"fade_out_sec": DUCK_SEC, "fade_in_sec": DUCK_SEC,
				"duck_db": IDENTITY_SELECT_DB, "sequential": false}
		AudioEnums.AudioState.IN_EVENT:
			return {"fade_out_sec": RESTORE_EVENT_SEC, "fade_in_sec": RESTORE_EVENT_SEC,
				"duck_db": EVENT_DB, "sequential": false}
		AudioEnums.AudioState.IN_SHOP:
			return {"fade_out_sec": DUCK_SEC, "fade_in_sec": DUCK_SEC,
				"duck_db": SHOP_DB, "sequential": false}
		AudioEnums.AudioState.DECK_EDITING, AudioEnums.AudioState.CULTIVATING:
			return {"fade_out_sec": DUCK_SEC, "fade_in_sec": DUCK_SEC,
				"duck_db": CULTIVATE_DB, "sequential": false}
	return {"fade_out_sec": DUCK_SEC, "fade_in_sec": DUCK_SEC,
		"duck_db": null, "sequential": false}
