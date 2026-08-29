extends Node
## CultivationSystem —— 修为养成系统 Autoload。
##
## Feature 层 Autoload。修为获取统一入口 + 溢出判定 + 查询接口。[br]
## 本文件是 GSM add_cultivation 的薄封装——不重复溢出逻辑，仅委托 + 信号传播 + 查询。[br]
## [br][b]不注册进 project.godot[/b]——待各系统接线后统一注册。[br]
## [br]来源: GDD cultivation-system.md §5 修为获取流程 + GSM 现有接口。


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
