extends RefCounted
## BgmFadeExecutor —— BGM 淡化 Tween 薄执行层（自 AudioManager 拆出）。
##
## [b]职责[/b]：把 [code]BgmFadePlanner[/code] 产出的指令集「演出来」——
## 播放器「当前侧/目标侧」轮换映射、顺序式起音延迟、BGM 总线 dB 插值、中断
## 重入 kill 重建。[b]数值决策一概不在本类[/b]（起点/终点/时长全由计划器
## 给定），本类只走时间轴。[br]
## [br][b]所有权[/b]：播放器节点池归 [AudioNodePool]（挂在 SceneManager 的
## PersistentLayer 上）——本类只持数组引用，不创建也不释放节点。BGM 双播放器
## 全程常驻、重入时也不换节点，故引用不会失效。[br]
## [br][b]Tween 归本类[/b]：AudioManager 不持淡化 Tween 句柄；重入时
## [method kill_tween] 停住正在插值的属性——新计划以当前实际值为起点
## （AC-BGM-10 中断续接）。[br]
## [br][b]边缘 #1 不在本类[/b]：目标曲损坏的判定由调用侧先行完成（解析全部
## play_stream，任一失败即整份计划放弃、旧曲原样续播），故本类收到的
## [param resolved] 保证齐备。
##
## 来源: design/gdd/audio-system.md §8、audio Story 002、AC-BGM-06/07/08/10、边缘 #1。

## BGM 淡化纯计划器（指令字段名与时长数值来源）。
const BgmFadePlanner := preload("res://src/ui/audio/bgm_fade_planner.gd")

## 播放器节点池（AudioManager 持有所有权——本类只读）。
var _players: Array[AudioStreamPlayer] = []

## AudioServer 适配器（总线过渡经它落地——静默模式下为 no-op 壳）。
var _adapter: AudioServerAdapter = null

## 场景树持有者（[code]create_tween[/code] 需要——null 时计划放弃）。
var _scene_manager: Node = null

## 当前淡化 Tween 句柄（重入 kill 重建——中断续接条款 AC-BGM-10）。
var _fade_tween: Tween = null


## 构造。[br]
## [br][param players]: BGM 双播放器数组（AudioManager 的节点池——须在节点池
## 就绪后注入，本类持引用不再重取）。[br]
## [param adapter]: AudioServerAdapter 实例。[br]
## [param scene_manager]: SceneManager 引用（Tween 宿主——null 时淡化 no-op）。
func _init(players: Array[AudioStreamPlayer], adapter: AudioServerAdapter,
		scene_manager: Node) -> void:
	_players = players
	_adapter = adapter
	_scene_manager = scene_manager


## 当前播放侧 dB——中断续接时新计划以当前实际 dB 为起点（非 -80）。[br]
## 无播放器时返回 [constant BgmFadePlanner.SILENCE_DB]。
func current_db(index: int) -> float:
	if _players.is_empty() or not _players[index].playing:
		return BgmFadePlanner.SILENCE_DB
	return _players[index].volume_db


## 目标播放器当前 dB（双播放器轮换——目标侧为 1 - 当前侧；池未挂满/目标侧
## 未播时返回 [constant BgmFadePlanner.SILENCE_DB]，计划器据此从静音起淡入）。
func target_db(index: int) -> float:
	if _players.size() < 2:
		return BgmFadePlanner.SILENCE_DB
	var target: AudioStreamPlayer = _players[1 - index]
	if not target.playing:
		return BgmFadePlanner.SILENCE_DB
	return target.volume_db


## 执行淡化计划。[br]
## [br][b]中断续接[/b]：重入 kill 旧 Tween——正在插值的属性停留在当前实际值，
## 新计划以该值为起点（AC-BGM-10）。[br]
## [br][b]顺序式[/b]（渡劫例外）：sequential 指令经 [code]set_delay[/code]
## 前移等待前序时长。[br]
## [br][param plan]: [code]BgmFadePlanner.plan_transition()[/code] 产出的指令集。[br]
## [param index]: 当前播放侧索引（0/1）。[br]
## [param resolved]: play_stream → AudioStream 解析表（调用侧已保证齐备）。[br]
## [b]返回[/b]：true = 已演出或无事可做（空计划/无挂载/无场景树均非失败）。
func execute(plan: Array[Dictionary], index: int, resolved: Dictionary) -> bool:
	if plan.is_empty():
		return true  # 同 id/无事可做——非失败
	if _players.is_empty():
		return true  # 静默模式/测试无挂载——计划放弃（API 不崩溃）
	kill_tween()
	_fade_tween = _scene_manager.create_tween() if _scene_manager != null \
			else null
	if _fade_tween == null:
		return true  # 无场景树——非失败
	_fade_tween.set_parallel(true)
	var sequential_delay_sec: float = 0.0
	for cmd: Dictionary in plan:
		var target: StringName = cmd[BgmFadePlanner.K_TARGET]
		var from_db: float = cmd[BgmFadePlanner.K_FROM_DB]
		var to_db: float = cmd[BgmFadePlanner.K_TO_DB]
		var duration: float = cmd[BgmFadePlanner.K_DURATION]
		var is_sequential: bool = cmd[BgmFadePlanner.K_SEQUENTIAL]
		if target == &"bus":
			# 降低类：BGM 总线 dB 过渡（不切曲——AC-BGM-06/07）
			_bus_fade(from_db, to_db, duration)
			continue
		# 计划器「当前/目标」→ 物理播放器轮换映射（a = 当前侧 / b = 目标侧）
		var player_idx: int = index if target == &"a" else 1 - index
		if player_idx >= _players.size():
			continue
		var player: AudioStreamPlayer = _players[player_idx]
		var play_stream: StringName = cmd[BgmFadePlanner.K_PLAY_STREAM]
		var delay_sec: float = sequential_delay_sec if is_sequential else 0.0
		if play_stream != &"":
			var stream: AudioStream = resolved[play_stream]
			player.stream = stream
			player.volume_db = from_db
			# 顺序式起音延迟：淡出完成前目标侧不起音（AC-BGM-08 字面
			# 语义——play() 经回调延迟触发，音量插值同窗口 set_delay）
			if delay_sec > 0.0:
				_fade_tween.tween_callback(player.play).set_delay(delay_sec)
			else:
				player.play()
		# 初值不经 .from()——属性当前值已是计划起点（play 分支显式赋
		# from_db；续接分支为播放器实际 dB）；且 .from() 在
		# set_parallel+set_delay 组合下会吞掉 delay（帧级探针实证）
		# set_delay 须先于 set_trans/set_ease 链式调用——后置会吞掉 delay
		# 4.6 PropertyTweener 链式顺序敏感（帧级探针实证）
		var step: PropertyTweener = _fade_tween.tween_property(player,
				"volume_db", to_db, duration)
		if delay_sec > 0.0:
			step.set_delay(delay_sec)
		step.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# 每条指令时长均累入顺序等待池（sequential 指令消费其当前值——
		# 平行指令在前时其淡出时长同样构成「前序」，渡劫 b 须等 a 完成）
		sequential_delay_sec += duration
		if cmd[BgmFadePlanner.K_STOP_AFTER]:
			_fade_tween.tween_callback(player.stop).set_delay(duration + delay_sec)
	return true


## 总线淡化指令（降低类——经 adapter 写 AudioServer 的 BGM 总线）。[br]
## 总线是 AudioServer 静态 API、无对象可 tween，故用
## [code]tween_method[/code] 驱动插值回调；回调只捕获 adapter 局部引用，
## 不捕获本类实例（避免与 Tween 形成引用环）。
func _bus_fade(from_db: float, to_db: float, duration: float) -> void:
	var bus: int = AudioEnums.AudioBus.BGM
	var adapter: AudioServerAdapter = _adapter
	_fade_tween.tween_method(
		func(value: float) -> void: adapter.set_bus_volume_db(bus, value),
		from_db, to_db, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## 淡化 Tween 重入清理（中断续接——kill 停留在当前实际值）。
func kill_tween() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null


## 当前淡化 Tween 句柄（无 Tween 时为 null——门面转发与测试观测用）。
func fade_tween() -> Tween:
	return _fade_tween


## 总线淡化指令（转发——门面兼容路径用；正常演出由 [method execute] 内部调用）。
func bus_fade(from_db: float, to_db: float, duration: float) -> void:
	_bus_fade(from_db, to_db, duration)
