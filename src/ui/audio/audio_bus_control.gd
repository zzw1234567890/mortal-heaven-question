extends RefCounted
## AudioBusControl —— 总线音量与 Master 静音（自 AudioManager 拆出）。
##
## [b]职责[/b]：写读总线音量、Master 静音/恢复（含静音前音量快照）。全部经
## 注入的 [AudioServerAdapter] 走真——本类不直接碰 AudioServer，静默模式
## （adapter.unavailable）自然 no-op。[br]
## [br][b]状态很小但独立[/b]：只有「是否静音」与「静音前音量」两项——它们是
## 用户操作留下的运行态，与音频状态机的 scene 状态无关，故不同放一处。[br]
## [br][b]MUTE_VOLUME_DB 真源在本类[/b]（GDD AC-MUTE-01：Master = -80dB）；
## AudioManager 与 settings_logic.gd 经同名常量转发引用。[br]
## [br][b]未落地项[/b]：200ms debounce（GDD 边缘 #5）与 HUD 静音图标信号
## [code]mute_state_changed[/code] 归 story 005。
##
## 来源: design/gdd/audio-system.md §8/AC-MUTE-01/边缘 #5、audio Story 001/005、
## src/ui/audio/audio_server_adapter.gd。

## 静音时 Master 总线音量（dB）——GDD AC-MUTE-01 语义（Master volume_db = -80）。
const MUTE_VOLUME_DB: float = -80.0

## AudioServer 适配器——依赖注入（测试可注入 unavailable/mock 实例）。
var _adapter: AudioServerAdapter = null

## Master 静音前音量快照（取消静音时恢复用）。
var _volume_before_mute: float = 0.0

## 静音态标志——true 表示当前处于 Master 静音态。
var _muted: bool = false


## 构造。[br]
## [br][param adapter]: AudioServerAdapter 实例（不可用时全部调用为无害 no-op）。
func _init(adapter: AudioServerAdapter) -> void:
	_adapter = adapter


## 设置总线音量。[br]
## [br][param bus]: [enum AudioEnums.AudioBus] 枚举值。[br]
## [param volume_db]: 目标音量（dB，范围 -80 ~ +6——范围钳制归 story 005 音量控制）。
func set_volume(bus: AudioEnums.AudioBus, volume_db: float) -> void:
	_adapter.set_bus_volume_db(bus, volume_db)


## 读取总线当前音量（dB）。[br]
## [br][param bus]: [enum AudioEnums.AudioBus] 枚举值。[br]
## [b]返回[/b]：当前音量（dB）——静默模式时返回 0.0（无害默认）。
func get_volume(bus: AudioEnums.AudioBus) -> float:
	return _adapter.get_bus_volume_db(bus)


## 静音/取消静音所有音频（F1 热键调用）。[br]
## [br]Master 总线 -80dB ↔ 恢复快照（GDD AC-MUTE-01）。debounce 200ms
## （GDD 边缘 #5）归 story 005；HUD 静音图标信号 [code]mute_state_changed[/code]
## 亦归 story 005。
func toggle_mute() -> void:
	if _muted:
		_adapter.set_bus_volume_db(AudioEnums.AudioBus.MASTER, _volume_before_mute)
		_muted = false
		return
	_volume_before_mute = _adapter.get_bus_volume_db(AudioEnums.AudioBus.MASTER)
	_adapter.set_bus_volume_db(AudioEnums.AudioBus.MASTER, MUTE_VOLUME_DB)
	_muted = true


## 当前是否处于 Master 静音态（story 005 的 HUD 图标信号与 debounce 消费）。
func is_muted() -> bool:
	return _muted
