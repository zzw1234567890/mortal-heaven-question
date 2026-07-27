# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: 玩家能否在 4 分钟内无需引导完成「炼气战斗→修为满→渡劫→突破→再战」？
# Date: 2026-07-27
##
## 修为养成系统 —— 管理修为获取、进度跟踪和溢出池。
## 生产环境中由 CultivationSystem Autoload #20（ADR-0020）管理。
## 遵循 gain_cultivation() 统一入口 + 溢出池模式。

class_name VSCultivationSystem
extends RefCounted

## === 信号（生产环境中挂在 CultivationSystem Autoload 上） =======================

signal cultivation_changed(old_amount: int, new_amount: int)
signal cultivation_max_changed(old_max: int, new_max: int)
signal breakthrough_ready()  ## 修为已满，可以触发渡劫

## === 内部状态 ==================================================================

var _current_cultivation: int = 0
var _max_cultivation: int = 100     ## 炼气期默认值
var _overflow_pool: int = 0         ## 溢出池（突破后转化的修为）
var _realm_level: int = VSRealmData.RealmLevel.QI_REFINING


## === 初始化 ====================================================================

## 按境界设置修为上限（不重置当前修为——新局从零开始）。
func init(realm_level: int) -> void:
	_realm_level = realm_level
	var new_max: int = VSRealmData.get_realm_property(realm_level, "max_cultivation")
	_max_cultivation = new_max


## 境界突破后更新上限——保留溢出修为。
func update_realm(new_level: int) -> void:
	_realm_level = new_level
	var old_max := _max_cultivation
	var new_max: int = VSRealmData.get_realm_property(new_level, "max_cultivation")
	_max_cultivation = new_max
	cultivation_max_changed.emit(old_max, new_max)


## === 核心 API ==================================================================

## 修为获取统一入口——所有来源通过此方法。
## [br]
## [b]参数:[/b]
##   - [param amount]: 获取的修为量（必须 > 0）。[br]
##   - [param source]: 来源标识字符串（战斗/丹药/事件等——用于日志）。[br]
## [b]返回:[/b] 实际增加的修为量（超出上限部分进入溢出池）。
func gain_cultivation(amount: int, source: String = "") -> int:
	if amount <= 0:
		return 0

	var old_cult := _current_cultivation
	_current_cultivation += amount

	var over: int = 0
	if _current_cultivation >= _max_cultivation:
		over = _current_cultivation - _max_cultivation
		_current_cultivation = _max_cultivation
		if over > 0:
			_overflow_pool += over
		breakthrough_ready.emit()

	cultivation_changed.emit(old_cult, _current_cultivation)

	var gained: int = (_current_cultivation - old_cult)
	return gained


## 消耗修为（渡劫突破后清零——生产环境中由 TribulationSystem 调用）。
func consume_progress(amount: int) -> int:
	var old_cult := _current_cultivation
	_current_cultivation = maxi(0, _current_cultivation - amount)
	cultivation_changed.emit(old_cult, _current_cultivation)
	return old_cult - _current_cultivation


## 结算溢出池——突破后调用，将溢出修为转化为资源。
## [br]
## [b]返回:[/b] 从溢出池中提取的修为量。
func settle_overflow() -> int:
	var amount := _overflow_pool
	_overflow_pool = 0
	return amount


## === 查询方法 ==================================================================

func get_current_cultivation() -> int:
	return _current_cultivation


func get_max_cultivation() -> int:
	return _max_cultivation


func get_progress() -> float:
	## 返回 0.0~1.0 的进度比例
	if _max_cultivation <= 0:
		return 0.0
	return minf(1.0, float(_current_cultivation) / float(_max_cultivation))


func is_breakthrough_ready() -> bool:
	return _current_cultivation >= _max_cultivation


func get_overflow_pool() -> int:
	return _overflow_pool


func get_realm_level() -> int:
	return _realm_level
