extends RefCounted
## AudioSfxWiring —— SFX 子系统接线（自 AudioManager 拆出）。
##
## [b]职责[/b]：把 SFX 这条链装起来——读调优参数资产 → 造 [code]SfxPool[/code]
## Logic 内核（注入时钟/RNG）→ 解析 sfx_id → AudioStream → 转发播放请求。[br]
## [br][b]时钟与 RNG 显式注入[/b]：池内冷却/淘汰逻辑用它们做确定性判定，
## 注入而非内取，测试可替身（story 003 Engine Notes）。[br]
## [br][b]流解析现状[/b]：SFX 资产（~50）归资产管线任务（story Out of Scope）
## ——资产未落盘前解析总是 null，[code]SfxPool[/code] 静默丢弃 + 每 id 一次
## push_warning。对象覆盖表由调用方（AudioManager）持有并共享引用（测试注入
## 程序生成流直用）。[br]
## [br][b]不建节点[/b]：播放器节点归 [AudioNodePool]，本类只把池与解析器交出去。
##
## 来源: design/gdd/audio-system.md §5/§7/§8、audio Story 003、AC-7、
## src/ui/audio/sfx_pool.gd、src/ui/audio/sfx_pool_config.gd。

## SFX 池 Logic 内核（冷却/淘汰/随机化/UI 打断确定性逻辑）。
const SfxPoolScript := preload("res://src/ui/audio/sfx_pool.gd")

## SFX 池调优参数资产路径（story 003——数据驱动，改数值不改代码；
## 与 default_bus_layout.tres 同构的 .tres 出厂基准）。
const CONFIG_PATH := "res://resources/audio/sfx_pool_config.tres"

## SFX 池 Logic 内核实例（节点池/UI 槽/流解析器由 AudioNodePool 注入）。
var _pool: RefCounted = null

## sfx_id → AudioStream 对象覆盖表（共享引用——归 AudioManager 所有）。
var _object_overrides: Dictionary = {}


## 构造。[br]
## [br][param object_overrides]: 对象覆盖表（共享引用——测试注入程序生成流）。[br]
## [param ticks_provider]: 毫秒时钟（冷却判定——默认 [code]Time.get_ticks_msec[/code]）。[br]
## [param rng]: 随机数发生器（随机化判定——默认新建）。
func _init(object_overrides: Dictionary, ticks_provider: Callable = Callable(),
		rng: RandomNumberGenerator = null) -> void:
	_object_overrides = object_overrides
	var sfx_config: SfxPoolConfig = null
	if ResourceLoader.exists(CONFIG_PATH):
		sfx_config = load(CONFIG_PATH) as SfxPoolConfig
	_pool = SfxPoolScript.new(
			ticks_provider if ticks_provider.is_valid() else Time.get_ticks_msec,
			rng if rng != null else RandomNumberGenerator.new(),
			sfx_config)


## SFX 池 Logic 内核（AudioNodePool 接线目标——池节点/UI 槽/解析器注入）。
func pool() -> RefCounted:
	return _pool


## 播放 SFX（委托池内冷却/淘汰/随机化/UI 打断确定性逻辑）。[br]
## [br][param sfx_id]: SFX 资源标识符。[br]
## [param options]: 可选参数（volume_db/pitch/eviction_priority/is_attack_sfx/
## bus——完整语义见 GDD §8 + story 003 Engine Notes；[code]delay_sec[/code]
## 归 story 004 编排（播放时机触发），本件忽略）。
func request(sfx_id: StringName, options: Dictionary = {}) -> void:
	_pool.request_sfx(sfx_id, options)


## 解析 sfx_id → AudioStream（注入 SfxPool 的流解析器——AC-7）。[br]
## 对象覆盖表优先（测试注入程序生成流直用）；否则 null（资产未落盘——
## 池侧静默丢弃 + 每 id 一次 push_warning）。
func resolve(sfx_id: StringName) -> AudioStream:
	if _object_overrides.has(sfx_id):
		return _object_overrides[sfx_id]
	return null
