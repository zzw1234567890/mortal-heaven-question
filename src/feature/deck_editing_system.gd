extends Node
## DeckEditingSystem —— 卡组编辑系统 Autoload（ADR-0023 #22）。
##
## Feature 层 Autoload。卡组校验 + 统一增删入口 + 变更日志。[br]
## 卡组数据存储在 GSM player.deck 域——本系统不持有数据副本。[br]
## 本文件持有卡组校验 API + 统一增删 API + 变更日志 + 查询接口。[br]
## [br][b]本 Story 范围[/b]（5-14）：验证器 + 统一增删 + 变更日志 + GSM deck 域扩展。[br]
## [b]不注册进 project.godot[/b]——待各系统接线后统一注册。[br]
## [br]来源: ADR-0023 §公共 API / GDD deck-editing-system.md §核心规则 #3/#7。


# === 常量 ========================================================================

## 卡组最低张数保护——GDD §核心规则 #3。
const MINIMUM_DECK_SIZE: int = 5


# === 内部状态 ====================================================================

## 可注入 RealmSystem 引用——测试时设置，绕过 Autoload 查找。
var _realm_override: Node = null


# === 卡组校验 API（纯函数——不修改 GSM 状态）==================================

## 检查是否可以添加卡牌到卡组——境界上限 + 天赋修正 + 当前张数比较。[br]
## [br][param count] 要添加的卡牌数量。[br]
## [br][b]返回[/b]: [code]{allowed: bool, reason: String}[/code] Dictionary。[br]
## [br]来源: ADR-0023 §can_add_to_deck + GDD §核心规则 #7。
func can_add_to_deck(count: int = 1) -> Dictionary:
	var gsm: Node = _get_gsm()
	if gsm == null:
		return {"allowed": false, "reason": "GSM 不可用"}
	var limit: int = get_deck_limit()
	var current_size: int = gsm.deck.get("current_deck", []).size()
	if current_size + count > limit:
		return {"allowed": false, "reason": "卡组已达上限（%d张）" % limit}
	return {"allowed": true, "reason": ""}


## 检查是否可以从卡组移除卡牌——最低 5 张保护。[br]
## [br][param count] 要移除的卡牌数量。[br]
## [br][b]返回[/b]: [code]{allowed: bool, reason: String}[/code] Dictionary。[br]
## [br]来源: ADR-0023 §can_remove_from_deck + GDD §核心规则 #3。
func can_remove_from_deck(count: int = 1) -> Dictionary:
	var gsm: Node = _get_gsm()
	if gsm == null:
		return {"allowed": false, "reason": "GSM 不可用"}
	var current_size: int = gsm.deck.get("current_deck", []).size()
	if current_size - count < MINIMUM_DECK_SIZE:
		return {"allowed": false, "reason": "卡组至少保留%d张" % MINIMUM_DECK_SIZE}
	return {"allowed": true, "reason": ""}


## 获取卡组上限——境界查询 + 天赋修正。[br]
## [br][b]返回[/b]: 当前境界卡组上限 + deck_limit_modifier。[br]
## [br]来源: ADR-0023 §get_deck_limit + GDD §核心规则 #7。
func get_deck_limit() -> int:
	var gsm: Node = _get_gsm()
	if gsm == null:
		return 20  # 默认炼气期上限
	var realm_sys: Node = _get_realm_system()
	var base_limit: int = 20
	if realm_sys != null and realm_sys.has_method("get_current_property"):
		var val: Variant = realm_sys.get_current_property(&"deck_limit")
		if val != null:
			base_limit = int(val)
	var modifier: int = int(gsm.deck.get("deck_limit_modifier", 0))
	return base_limit + modifier


# === 卡组操作 API（通过 GSM 第二层写入——发射 batch_updated）===================

## 统一添加入口——所有四种渠道必须通过此方法。[br]
## [br][param card_ids] 要添加的卡牌实例 ID 数组。[br]
## [br][param source] 来源标识（如 "loot" / "shop" / "event" / "initial"）。[br]
## [br][param detail] 附加描述。[br]
## [br][b]返回[/b]: [code]true[/code] 成功，[code]false[/code] 被拒绝。[br]
## [br]来源: ADR-0023 §add_cards_to_deck。
func add_cards_to_deck(card_ids: Array, source: String, detail: String = "") -> bool:
	var gsm: Node = _get_gsm()
	if gsm == null:
		push_warning("DeckEditingSystem.add_cards_to_deck: GSM 不可用")
		return false
	if card_ids.is_empty():
		push_warning("DeckEditingSystem.add_cards_to_deck: card_ids 为空")
		return false
	var check: Dictionary = can_add_to_deck(card_ids.size())
	if not check["allowed"]:
		push_warning("DeckEditingSystem.add_cards_to_deck: %s" % check["reason"])
		return false
	var new_deck: Array = gsm.deck.get("current_deck", []).duplicate()
	new_deck.append_array(card_ids)
	gsm._set_deck_cards(new_deck)
	_append_change_log(card_ids, "add", source, detail)
	return true


## 统一删除入口——用于散功、出售、事件销毁。[br]
## [br][param card_ids] 要移除的卡牌实例 ID 数组。[br]
## [br][param source] 来源标识。[br]
## [br][param detail] 附加描述。[br]
## [br][b]返回[/b]: [code]true[/code] 成功，[code]false[/code] 被拒绝。[br]
## [br]来源: ADR-0023 §remove_cards_from_deck。
func remove_cards_from_deck(card_ids: Array, source: String, detail: String = "") -> bool:
	var gsm: Node = _get_gsm()
	if gsm == null:
		push_warning("DeckEditingSystem.remove_cards_from_deck: GSM 不可用")
		return false
	if card_ids.is_empty():
		push_warning("DeckEditingSystem.remove_cards_from_deck: card_ids 为空")
		return false
	var check: Dictionary = can_remove_from_deck(card_ids.size())
	if not check["allowed"]:
		push_warning("DeckEditingSystem.remove_cards_from_deck: %s" % check["reason"])
		return false
	var new_deck: Array = []
	for id in gsm.deck.get("current_deck", []):
		if id not in card_ids:
			new_deck.append(id)
	gsm._set_deck_cards(new_deck)
	_append_change_log(card_ids, "remove", source, detail)
	return true


# === 变更日志 ====================================================================

## 追加变更日志条目到 GSM player.deck.change_log。[br]
## [br][param card_ids] 涉及的卡牌实例 ID 数组。[br]
## [br][param action] 操作类型（"add" / "remove"）。[br]
## [br][param source] 来源标识。[br]
## [br][param detail] 附加描述。[br]
## [br]来源: ADR-0023 §_append_change_log + GDD §核心规则 #8。
func _append_change_log(card_ids: Array, action: String, source: String, detail: String) -> void:
	var gsm: Node = _get_gsm()
	if gsm == null:
		return
	var log: Array = gsm.deck.get("change_log", []).duplicate()
	for card_id in card_ids:
		var entry: Dictionary = {
			"card_id": int(card_id),
			"action": action,
			"source": source,
			"detail": detail,
		}
		log.append(entry)
	gsm.deck.change_log = log
	gsm._buffer_change("deck.change_log", log.size() - card_ids.size(), log)


# === 查询接口 ====================================================================

## 获取卡组卡牌列表——返回 current_deck 副本。[br]
## [br][b]返回[/b]: Array[int] 副本——修改不影响 GSM 内部状态。[br]
## [br]来源: ADR-0023 §查询接口 + UI 查询需求。
func get_deck_cards() -> Array:
	var gsm: Node = _get_gsm()
	if gsm == null:
		return []
	return gsm.deck.get("current_deck", []).duplicate()


## 获取卡组变更日志——返回副本。[br]
## [br][b]返回[/b]: Array[Dictionary] 副本。[br]
## [br]来源: GDD §核心规则 #5。
func get_change_log() -> Array:
	var gsm: Node = _get_gsm()
	if gsm == null:
		return []
	return gsm.deck.get("change_log", []).duplicate(true)


## 获取散功已执行次数——驱动递增费用。[br]
## [br][b]返回[/b]: 当前本局散功次数。[br]
## [br]来源: ADR-0023 §坊市操作。
func get_session_remove_count() -> int:
	var gsm: Node = _get_gsm()
	if gsm == null:
		return 0
	return int(gsm.deck.get("session_remove_count", 0))


# === 内部辅助 ====================================================================

## 获取 GSM 引用——通过 SceneTree Autoload（同 CultivationSystem/TribulationSystem 模式）。
func _get_gsm() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/GameStateManager")


## 获取 RealmSystem 引用——优先使用注入的覆盖引用，否则通过 SceneTree Autoload 查找。[br]
## [br][b]返回[/b]: RealmSystem 节点或 [code]null[/code]（未注册时）。
func _get_realm_system() -> Node:
	if _realm_override != null and is_instance_valid(_realm_override):
		return _realm_override
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/RealmSystem")
