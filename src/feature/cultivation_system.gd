extends Node
## CultivationSystem —— 修为养成系统 Autoload。
##
## Feature 层 Autoload。修为获取统一入口 + 溢出判定 + 溢出结算 + 查询接口。[br]
## 本文件是 GSM add_cultivation 的薄封装——不重复溢出逻辑，仅委托 + 信号传播 + 查询。[br]
## [br][b]不注册进 project.godot[/b]——待各系统接线后统一注册。[br]
## [br]来源: GDD cultivation-system.md §5 修为获取流程 + §6-7 溢出结算 + GSM 现有接口。


# === 常量 ======================================================================

## 溢出→属性丹转化单位——每 100 溢出修为 = 1 属性丹（GDD §公式 2）。
const PILL_CONVERSION_UNIT: int = 100

## 修为上限基价——炼气期 max_cultivation = BASE_MAX（GDD §2）。
const BASE_MAX: int = 1000


# === 修为获取（Story 001）=====================================================

## 修为获取统一入口——委托 GSM.add_cultivation。[br]
## [br][param amount] 获取量（必须为正值）。[br]
## [br][param source] 来源标识（用于日志，如 "combat" / "pill" / "event"）。[br]
## [br][b]溢出逻辑[/b]：修为满后继续获取，溢出存入 overflow_pool（GSM.add_cultivation 已实现）。[br]
## [br][b]信号[/b]：cultivation_changed / cultivation_full 由 GSM 帧末统一发射。[br]
## [br]来源: GDD §5 修为获取流程。
func gain_cultivation(amount: int, source: String = "") -> void:
	if amount <= 0:
		push_error("CultivationSystem.gain_cultivation: amount 必须为正值（收到: %d, 来源: '%s'）" % [amount, source])
		return
	var gsm: Node = _get_gsm()
	if gsm == null:
		push_warning("CultivationSystem.gain_cultivation: GSM 不可用")
		return
	gsm.add_cultivation(amount, source)


# === 溢出结算（Story 003）=====================================================

## 溢出结算——突破后调用，将 overflow_pool 转化为属性丹（GDD §7 + 公式 2）。[br]
## [br][b]流程[/b]:[br]
## [br]1. pill_count = floor(overflow_pool / PILL_CONVERSION_UNIT)[br]
## [br]2. remaining = overflow_pool mod PILL_CONVERSION_UNIT[br]
## [br]3. 更新 GSM player.overflow_pool = remaining[br]
## [br]4. 返回 {pill_count, remaining_overflow}[br]
## [br][b]注意[/b]: 本方法只计算数量，不实际发放丹药——丹药发放由炼丹系统处理。[br]
## [br]来源: GDD §7 溢出属性丹自动发放 + §公式 2。
func settle_overflow() -> Dictionary:
	var gsm: Node = _get_gsm()
	if gsm == null:
		push_warning("CultivationSystem.settle_overflow: GSM 不可用")
		return {"pill_count": 0, "remaining_overflow": 0}
	var overflow_pool: int = int(gsm.player.overflow_pool)
	var pill_count: int = int(floor(overflow_pool / float(PILL_CONVERSION_UNIT)))
	var remaining: int = overflow_pool % PILL_CONVERSION_UNIT

	# 更新 GSM overflow_pool（通过 _buffer_change 传播）
	if remaining != overflow_pool:
		var old_val: int = overflow_pool
		gsm.player.overflow_pool = remaining
		gsm._buffer_change("player.overflow_pool", old_val, remaining)

	return {"pill_count": pill_count, "remaining_overflow": remaining}


## 更新修为上限——突破后调用，更新 max_cultivation 并触发溢出结算（GDD §6）。[br]
## [br][param new_realm] 新境界等级（1-5）。[br]
## [br][b]流程[/b]:[br]
## [br]1. max_cultivation = BASE_MAX × 1.5^(new_realm - 1)[br]
## [br]2. 更新 GSM player.max_cultivation[br]
## [br]3. 调用 settle_overflow()[br]
## [br]来源: GDD §2 修为上限 + §6 突破后修为处理。
func update_max_cultivation(new_realm: int) -> void:
	var gsm: Node = _get_gsm()
	if gsm == null:
		push_warning("CultivationSystem.update_max_cultivation: GSM 不可用")
		return
	var new_max: int = int(float(BASE_MAX) * pow(1.5, new_realm - 1))
	var old_max: int = int(gsm.player.max_cultivation)
	if old_max != new_max:
		gsm.player.max_cultivation = new_max
		gsm._buffer_change("player.max_cultivation", old_max, new_max)
	# 突破后立即触发溢出结算
	settle_overflow()


# === 查询接口 ==================================================================

## 检查修为是否已满——cultivation >= max_cultivation。[br]
## [br][b]返回[/b]: [code]true[/code] 已满，[code]false[/code] 未满。[br]
## [br]来源: GDD §4 修为满值提示。
func check_cultivation_full() -> bool:
	var gsm: Node = _get_gsm()
	if gsm == null:
		return false
	return int(gsm.player.cultivation) >= int(gsm.player.max_cultivation)


## 获取修为状态摘要。[br]
## [br][b]返回[/b]: [code]{current, max, overflow_pool, is_full}[/code] Dictionary。[br]
## [br]来源: GDD §5 + UI 查询需求。
func get_cultivation_status() -> Dictionary:
	var gsm: Node = _get_gsm()
	if gsm == null:
		return {"current": 0, "max": 0, "overflow_pool": 0, "is_full": false}
	var current: int = int(gsm.player.cultivation)
	var max_cult: int = int(gsm.player.max_cultivation)
	return {
		"current": current,
		"max": max_cult,
		"overflow_pool": int(gsm.player.overflow_pool),
		"is_full": current >= max_cult,
	}


# === 内部辅助 ==================================================================

## 获取 GSM 引用——通过 SceneTree Autoload。
func _get_gsm() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/GameStateManager")
