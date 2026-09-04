extends RefCounted
## DeckSummary —— 卡组摘要/状态查询子模块（从 deck_editing_system.gd 拆分）。
##
## 持有对 DeckEditingSystem 父节点的引用，通过它访问 _get_gsm / get_deck_limit /
## can_remove_from_deck / get_session_remove_count / get_delete_cost 等方法。
##
## [br]来源: ADR-0023 §查询接口 + GDD §核心规则 #5/#7。
## [br]Sprint 10 Story 3：从 deck_editing_system.gd 拆分。

## 父节点引用——DeckEditingSystem Autoload 实例。
var _parent: Node = null

## 最低卡组张数常量（从父节点镜像——避免 _parent.get() 运行时开销）。
const MINIMUM_DECK_SIZE: int = 5


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


## 获取卡组摘要——供 UI 显示卡组计数和状态。[br]
## [br][b]返回[/b]: [code]{total, limit, is_full, is_minimal}[/code] Dictionary。[br]
## [br]来源: ADR-0023 §查询接口 + GDD §核心规则 #5/#7。
func get_deck_summary() -> Dictionary:
	var gsm: Node = _parent.call("_get_gsm")
	if gsm == null:
		return {"total": 0, "limit": 0, "is_full": false, "is_minimal": true}
	var total: int = gsm.deck.get("current_deck", []).size()
	var limit: int = _parent.call("get_deck_limit")
	return {
		"total": total,
		"limit": limit,
		"is_full": total >= limit,
		"is_minimal": total <= MINIMUM_DECK_SIZE,
	}


## 获取当前缓存的战利品选项——供 UI 展示。[br]
## [br][b]返回[/b]: Array[Dictionary] 副本——generate_loot_options 后缓存。[br]
## [br]来源: ADR-0023 §战利品操作 + GDD §核心规则 #2。
func get_loot_options() -> Array:
	var loot: Array = _parent.get("_loot_options")
	return loot.duplicate(true)


## 获取卡组综合状态——供 UI 一次性刷新。[br]
## [br][b]返回[/b]: [code]{deck_count, deck_limit, is_full, remove_count, can_delete, delete_cost}[/code] Dictionary。[br]
## [br]来源: ADR-0023 §查询接口 + GDD §核心规则 #3/#7。
func get_deck_status() -> Dictionary:
	var summary: Dictionary = get_deck_summary()
	var can_remove: Dictionary = _parent.call("can_remove_from_deck", 1)
	return {
		"deck_count": summary["total"],
		"deck_limit": summary["limit"],
		"is_full": summary["is_full"],
		"remove_count": _parent.call("get_session_remove_count"),
		"can_delete": can_remove["allowed"],
		"delete_cost": _parent.call("get_delete_cost"),
	}
