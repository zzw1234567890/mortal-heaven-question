extends RefCounted
## AudioStateOrchestrator —— 音频状态机 Logic 内核（自 AudioManager 拆出）。
##
## [b]职责[/b]：持「当前音频状态」，把一次状态切换裁决成一份[b]动作计划[/b]——
## 查 [code]StateTransitionMatrix[/code] 矩阵行，产出「该做什么」（暂停/恢复/
## duck/切曲/无事），连带该转换是否被接受。[br]
## [br][b]不持有宿主、不持有 Callable[/b]：本类只算不做——计划交回 AudioManager
## 执行。理由有二：① 执行面（pause_all/play_bgm/adapter）仍只有 AudioManager
## 一处；② 无反向引用，避免 RefCounted 引用环。[br]
## [br][b]N/A 回滚[/b]（2026-10-29 code-review 阻塞项）：无矩阵行的转换视为
## 「拒绝转换」——[member _current_state] 不推进、保持源态并 push_warning 一次。
## 状态与音频实际状态始终保持同源（避免 N/A 后从错误源态出发的漂移链）。[br]
## [br][b]引导进入[/b]：源态为 -1（未设置）时跳过矩阵，按入口 BGM 直接淡入。
##
## 来源: design/gdd/audio-system.md §9、audio Story 004、AC-4/AC-6。

## 状态过渡矩阵 Logic 内核（GDD §9 24 行唯一真源 + TransitionType 映射）。
const StateTransitionMatrixScript := preload("res://src/ui/audio/state_transition_matrix.gd")

## BGM 淡化纯计划器（引导进入的时长参数查询——与矩阵同源）。
const BgmFadePlanner := preload("res://src/ui/audio/bgm_fade_planner.gd")

## 计划动作种类（[member _plan] 的 K_KIND 取值）。
const KIND_NONE: StringName = &"none"      # 幂等 no-op / N/A 拒绝
const KIND_PAUSE: StringName = &"pause"    # 暂停所有音频
const KIND_RESUME: StringName = &"resume"  # 恢复所有音频
const KIND_DUCK: StringName = &"duck"      # BGM 总线 dB 过渡（不切曲）
const KIND_SWITCH: StringName = &"switch"  # 交叉淡化切曲

## 计划字段键。
const K_KIND: StringName = &"kind"
const K_BGM: StringName = &"bgm_id"
const K_FADE_OUT_SEC: StringName = &"fade_out_sec"
const K_FADE_IN_SEC: StringName = &"fade_in_sec"
const K_DUCK_DB: StringName = &"duck_db"
const K_SEQUENTIAL: StringName = &"sequential"
const K_AMBIENT_DELTA_DB: StringName = &"ambient_delta_db"

## 当前音频状态（[enum AudioEnums.AudioState]；-1 = 尚未设置）。
var _current_state: int = -1


## 当前音频状态（-1 = 尚未设置）。
func current_state() -> int:
	return _current_state


## 裁决一次状态切换，返回动作计划（不动音频——执行归调用方）。[br]
## [br][b]幂等[/b]（AC-6）：同状态重复调用返回 [constant KIND_NONE]（且状态不变）。[br]
## [br][b]参数 current_bgm_id[/b]：duck 类行需以「当前在播曲」为目标——
## 传 [code]&""[/code] 时 duck 退化为「对空 id 做 dB 过渡」（不切曲语义维持）。[br]
## [br][param state]: 目标 [enum AudioEnums.AudioState]。[br]
## [param current_bgm_id]: 当前在播 BGM id（调用方持有）。[br]
## [b]返回[/b]：计划 Dictionary（键见 [constant K_KIND] 等）；被拒/同态时为
## 仅含 [constant K_KIND] = [constant KIND_NONE] 的计划。
func plan_state(state: AudioEnums.AudioState, current_bgm_id: StringName) -> Dictionary:
	var target: int = int(state)
	if _current_state == target:
		return _plan(KIND_NONE)
	var from_state: int = _current_state
	if from_state < 0:
		# 引导进入（无前置状态）——按入口 BGM 直接淡入，查目标态参数
		_current_state = target
		return _entry_plan(target)
	var row: Dictionary = StateTransitionMatrixScript.transition_params(
			from_state, target)
	if row.is_empty():
		# N/A 转换 / 无行——拒绝转换：状态回滚（不推进），音频零动作
		push_warning("AudioManager.set_state: N/A 转换 %d → %d 无矩阵行——拒绝，状态保持 %d" % [from_state, target, from_state])
		return _plan(KIND_NONE)
	_current_state = target
	var action: StringName = row[StateTransitionMatrixScript.K_ACTION]
	if action == StateTransitionMatrixScript.ACTION_PAUSE:
		return _plan(KIND_PAUSE)
	if action == StateTransitionMatrixScript.ACTION_RESUME:
		return _plan(KIND_RESUME)
	var fade_out_sec: float = float(row[StateTransitionMatrixScript.K_FADE_OUT_SEC])
	var fade_in_sec: float = float(row[StateTransitionMatrixScript.K_FADE_IN_SEC])
	var duck_db: Variant = row[StateTransitionMatrixScript.K_DUCK_DB]
	var sequential: bool = bool(row[StateTransitionMatrixScript.K_SEQUENTIAL])
	var ambient_delta: float = float(row[StateTransitionMatrixScript.K_AMBIENT_DELTA_DB])
	if duck_db != null:
		# 降低/恢复类——BGM 总线 dB 过渡，不切曲（play_bgm duck 语义）
		var duck_plan: Dictionary = _plan(KIND_DUCK)
		duck_plan[K_BGM] = current_bgm_id
		duck_plan[K_FADE_OUT_SEC] = fade_out_sec
		duck_plan[K_FADE_IN_SEC] = fade_in_sec
		duck_plan[K_DUCK_DB] = duck_db
		duck_plan[K_AMBIENT_DELTA_DB] = ambient_delta
		return duck_plan
	# 切曲类——交叉淡化（sequential 渡劫顺序式）
	var switch_plan: Dictionary = _plan(KIND_SWITCH)
	switch_plan[K_BGM] = row[StateTransitionMatrixScript.K_BGM]
	switch_plan[K_FADE_OUT_SEC] = fade_out_sec
	switch_plan[K_FADE_IN_SEC] = fade_in_sec
	switch_plan[K_SEQUENTIAL] = sequential
	switch_plan[K_AMBIENT_DELTA_DB] = ambient_delta
	return switch_plan


## 场景转场类型 → 是否推进状态。转场信号回调的裁决部分（AC-4）。[br]
## [br]返回 [code]-1[/code] 表示未映射（NONE/防御性——调用方跳过）；否则为
## 应推进到的目标 AudioState（调用方据此调 [method plan_state]）。[br]
## [br][param from_scene]: 源场景 ID（透传矩阵映射，未参与裁决）。[br]
## [param to_scene]: 目标场景 ID。[br]
## [param type]: 转场类型（SceneManager TransitionType）。
func resolve_transition(from_scene: int, to_scene: int, type: int) -> int:
	return StateTransitionMatrixScript.map_transition_type(from_scene, to_scene, type)


## 引导进入计划（无前置状态）——入口 BGM 直接淡入，或 no-op（duck 态）。[br]
## [br][param target]: 目标 [enum AudioEnums.AudioState]。[br]
## 时长参数查 [BgmFadePlanner.params_for_state]（目标态塌缩查询——与矩阵同源）。
func _entry_plan(target: int) -> Dictionary:
	var bgm_id: StringName = StateTransitionMatrixScript.entry_bgm(target)
	if bgm_id == &"":
		return _plan(KIND_NONE)  # duck/no-bgm 态——无入口曲（引导进入 no-op）
	var params: Dictionary = BgmFadePlanner.params_for_state(target)
	var entry_plan: Dictionary = _plan(KIND_SWITCH)
	entry_plan[K_BGM] = bgm_id
	entry_plan[K_FADE_OUT_SEC] = 0.0
	entry_plan[K_FADE_IN_SEC] = float(params["fade_in_sec"])
	entry_plan[K_SEQUENTIAL] = bool(params["sequential"])
	return entry_plan


## 空计划骨架（只带动作种类——其余字段由各分支补齐）。
func _plan(kind: StringName) -> Dictionary:
	return {K_KIND: kind, K_AMBIENT_DELTA_DB: 0.0}
