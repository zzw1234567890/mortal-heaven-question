class_name AudioServerAdapter
extends RefCounted
## AudioServerAdapter —— AudioServer 薄包装层（audio Epic Story 001）。
##
## [b]职责[/b]：封装 AudioServer 的总线音量/静音操作，供 AudioManager 经依赖注入
## 消费——测试可注入 [code]unavailable[/code] 实例或子类 mock 替代真实引擎单例
## （headless 测试无法直接模拟 AudioServer 初始化失败，story Engine Notes）。[br]
## [br][b]静默模式[/b]（GDD 边缘 #14）：[code]unavailable = true[/code] 时所有调用
## no-op 不崩溃；首次 no-op 时 [code]push_warning[/code] 一次（一次性日志——
## 后续调用静默，避免日志刷屏）。[br]
## [br][b]总线访问[/b]：一律按名称（[code]get_bus_index(name)[/code]）——禁硬编码
## 索引（control-manifest Presentation 层必需模式）。总线名称映射来自
## [code]AudioEnums.BUS_NAMES[/code]（单一真源）。[br]
## [br][b]dB 值[/b]：本层不做数值定义——默认 dB 在 default_bus_layout.tres 资产中
## （数据驱动）；本层只做读写透传。
##
## @experimental
## 来源: design/gdd/audio-system.md 边缘 #14、audio Story 001、ADR-0031。

## AudioServer 不可用标志——true 时进入静默模式（所有调用 no-op）。[br]
## 生产启动时由 AudioManager 检测设置；测试直接注入 true 模拟不可用
## （headless GUT 下真实 AudioServer 仍可用，无法自然触发——story Engine Notes）。
var unavailable: bool = false

## 一次性日志标志——静默模式只 push_warning 一次（后续调用不再刷日志）。
var _silent_logged: bool = false

## 总线缺失告警去重表——按总线枚举记 flag（每条总线只告警一次）。[br]
## 布局配置回归（default_bus_layout.tres 加载失败/总线被误删）时，所有
## set 调用不再无声吞掉（code-review H-B：静默模式的现实成因须可见）。
var _missing_bus_warned: Dictionary = {}


## 按总线枚举查询 AudioServer 总线索引。[br]
## [br][b]返回[/b]：总线索引；总线不存在或静默模式时返回 [code]-1[/code]
## （与 [code]AudioServer.get_bus_index[/code] 的不存在语义一致）。[br]
## [br]总线缺失时 push_warning 一次（每总线去重）——布局配置回归可见。
func get_bus_index(bus: int) -> int:
	if _noop_guard():
		return -1
	var bus_name: StringName = AudioEnums.BUS_NAMES.get(bus, &"")
	if bus_name == &"":
		push_error("AudioServerAdapter: 未知总线枚举值 %d" % bus)
		return -1
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0 and not _missing_bus_warned.get(bus, false):
		push_warning("AudioServerAdapter: 总线 '%s' 不存在（布局资产加载失败或被误删？）——相关操作 no-op（每总线只告警一次）" % bus_name)
		_missing_bus_warned[bus] = true
	return idx


## 读取总线当前音量（dB）。[br]
## 静默模式或总线不存在时返回 [code]0.0[/code]（无害默认——调用方无须判空）。
func get_bus_volume_db(bus: int) -> float:
	if _noop_guard():
		return 0.0
	var idx: int = get_bus_index(bus)
	if idx < 0:
		return 0.0
	return AudioServer.get_bus_volume_db(idx)


## 设置总线音量（dB）。静默模式或总线不存在时 no-op。
func set_bus_volume_db(bus: int, volume_db: float) -> void:
	if _noop_guard():
		return
	var idx: int = get_bus_index(bus)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, volume_db)


## 读取总线静音状态。静默模式或总线不存在时返回 [code]false[/code]。
func is_bus_muted(bus: int) -> bool:
	if _noop_guard():
		return false
	var idx: int = get_bus_index(bus)
	if idx < 0:
		return false
	return AudioServer.is_bus_mute(idx)


## 设置总线静音。静默模式或总线不存在时 no-op。
func set_bus_mute(bus: int, muted: bool) -> void:
	if _noop_guard():
		return
	var idx: int = get_bus_index(bus)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, muted)


## 检测 AudioServer 是否可用（供 AudioManager 启动判定静默模式）。[br]
## [br]判定方式：查询 Master 总线索引——AudioServer 初始化失败时不可得。
## 本方法 [b]不受[/b] [member unavailable] 标志影响（检测先于标志设置）。
func detect_availability() -> bool:
	return AudioServer.get_bus_index(&"Master") >= 0


## 静默模式守卫——不可用时 no-op 并首调记一次日志。[br]
## [br][b]返回[/b]：[code]true[/code] = 调用方应 no-op 返回。
func _noop_guard() -> bool:
	if not unavailable:
		return false
	if not _silent_logged:
		push_warning("AudioServerAdapter: AudioServer 不可用——音频系统进入静默模式（边缘 #14，后续调用 no-op 不再记录）")
		_silent_logged = true
	return true
