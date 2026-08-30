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

## 默认卡组——6 个身份的初始卡组 card_instance_id 列表（GDD §核心规则 #1）。[br]
## [br]身份 ID 1-6 对应 GDD 表中的 6 个开局身份。实际 card_instance_id 由身份选择系统[br]
## 调用 CardSystem.create_instance 生成——本常量为桩阶段占位，后续接线时替换。
const DEFAULT_DECKS: Dictionary = {
	1: [101, 102, 103, 104, 105, 106, 107],  # 青云剑宗外门弟子（7张）
	2: [201, 202, 203, 204, 205, 206, 207],  # 血海殿遗孤（7张）
	3: [301, 302, 303, 304, 305, 306, 307],  # 碎星群岛散修（7张）
	4: [401, 402, 403, 404, 405, 406, 407],  # 玄冰宫弟子（7张）
	5: [501, 502, 503, 504, 505, 506, 507],  # 丹霞谷弟子（7张）
	6: [601, 602, 603, 604, 605, 606],          # 阵道双杰（6张）
}


# === 内部状态 ====================================================================

## 可注入 RealmSystem 引用——测试时设置，绕过 Autoload 查找。
var _realm_override: Node = null

## 可注入 ResourceSystem 引用——测试时设置，绕过 Autoload 查找。
var _resource_override: Node = null

## 当前战利品选项缓存——generate_loot_options 生成，apply_loot_choice 消费。
var _loot_options: Array = []


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


# === 开局初始化（Story 5-16）===================================================

## 初始化初始卡组——开局身份绑定的固定卡组写入。[br]
## [br][param identity_preset] 初始卡组 card_instance_id 数组。[br]
## [br][b]流程[/b]（ADR-0023 §initialize_initial_deck）:[br]
##   1. 直接写入 GSM deck.current_deck——不受境界上限约束[br]
##   2. 重置 slots = [null×6][br]
##   3. 重置 change_log = [][br]
##   4. 重置 session_remove_count = 0[br]
##   5. 重置 deck_limit_modifier = 0[br]
## [br][b]注意[/b]: 初始卡组 6-7 张远低于炼气期 20 上限——无需校验。[br]
## [br]来源: ADR-0023 §initialize_initial_deck + GDD §核心规则 #1。
func initialize_initial_deck(identity_preset: Array) -> void:
	var gsm: Node = _get_gsm()
	if gsm == null:
		push_warning("DeckEditingSystem.initialize_initial_deck: GSM 不可用")
		return
	gsm._set_deck_cards(identity_preset.duplicate())
	gsm.deck.slots = [null, null, null, null, null, null]
	gsm.deck.change_log = []
	gsm._set_deck_session_remove_count(0)
	gsm.deck.deck_limit_modifier = 0
	gsm._buffer_change("deck.slots", [], gsm.deck.slots)
	gsm._buffer_change("deck.change_log", [], [])
	gsm._buffer_change("deck.deck_limit_modifier", 0, 0)


## 根据身份 ID 获取默认卡组——返回 card_instance_id 列表副本。[br]
## [br][param identity_id] 身份 ID（1-6）。[br]
## [br][b]返回[/b]: Array[int] 副本——无效 ID 返回空数组。[br]
## [br]来源: GDD §核心规则 #1 + ADR-0023 §默认卡组。
func get_default_deck(identity_id: int) -> Array:
	if not DEFAULT_DECKS.has(identity_id):
		push_warning("DeckEditingSystem.get_default_deck: 无效身份 ID %d" % identity_id)
		return []
	return DEFAULT_DECKS[identity_id].duplicate()


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


## 获取 ResourceSystem 引用——优先使用注入的覆盖引用，否则通过 SceneTree Autoload 查找。[br]
## [br][b]返回[/b]: ResourceSystem 节点或 [code]null[/code]（未注册时）。
func _get_resource_system() -> Node:
	if _resource_override != null and is_instance_valid(_resource_override):
		return _resource_override
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/ResourceSystem")


# === 坊市操作（Story 5-15）=======================================================

## 获取散功费用——委托 ResourceSystem.delete_card_cost。[br]
## [br][b]返回[/b]: 下一次散功费用灵石数。[br]
## [br][b]注意[/b]: session_remove_count 是已执行次数，delete_card_cost 期望次数从 1 开始。[br]
## [br]来源: ADR-0023 §坊市操作 + GDD §核心规则 #3 ②散功。
func get_delete_cost() -> int:
	var rs: Node = _get_resource_system()
	if rs == null or not rs.has_method("delete_card_cost"):
		return 50  # 默认基价
	var count: int = get_session_remove_count() + 1  # 下一次散功次数
	return rs.delete_card_cost(count)


## 执行散功——支付灵石永久移除一张卡牌。[br]
## [br][param card_id] 要移除的卡牌实例 ID。[br]
## [br][b]返回[/b]: [code]true[/code] 成功，[code]false[/code] 被拒绝。[br]
## [br][b]流程[/b]: get_delete_cost → can_spend → remove_cards → spend_resource → session_remove_count+1。[br]
## [br]来源: ADR-0023 §execute_delete + GDD §核心规则 #3 ②散功。
func execute_delete(card_id: int) -> bool:
	var gsm: Node = _get_gsm()
	if gsm == null:
		push_warning("DeckEditingSystem.execute_delete: GSM 不可用")
		return false
	var rs: Node = _get_resource_system()
	if rs == null:
		push_warning("DeckEditingSystem.execute_delete: ResourceSystem 不可用")
		return false
	var cost: int = get_delete_cost()
	# 灵石不足时拒绝
	if rs.has_method("can_spend") and not rs.can_spend(&"ling_shi", cost):
		push_warning("DeckEditingSystem.execute_delete: 灵石不足（需要 %d）" % cost)
		return false
	# 移除卡牌（含最低张数保护）
	if not remove_cards_from_deck([card_id], "shop_delete", "散功"):
		return false
	# 扣除灵石
	if rs.has_method("spend_resource"):
		rs.spend_resource(&"ling_shi", cost)
	# 递增散功计数
	var new_count: int = get_session_remove_count() + 1
	gsm._set_deck_session_remove_count(new_count)
	return true


## 获取拆解价值——委托 ResourceSystem.dismantle_value。[br]
## [br][param card_id] 卡牌实例 ID（桩阶段用默认 rarity=1, level=1）。[br]
## [br][b]返回[/b]: 拆解所得灵石数。[br]
## [br]来源: ADR-0023 §get_sell_price + GDD §核心规则 #3 ③拆解。
func get_sell_price(card_id: int) -> int:
	var rs: Node = _get_resource_system()
	if rs == null or not rs.has_method("dismantle_value"):
		return 10  # 默认白色拆解值
	# 桩阶段——用默认 rarity=1(白), level=1
	# 后续接线：从 CardSystem.get_instance(card_id) 查询 rarity + level
	return rs.dismantle_value(1, 1)


## 执行拆解——移除卡牌并获取灵石。[br]
## [br][param card_id] 要拆解的卡牌实例 ID。[br]
## [br][b]返回[/b]: [code]true[/code] 成功，[code]false[/code] 被拒绝。[br]
## [br][b]流程[/b]: get_sell_price → remove_cards → add_resource。[br]
## [br]来源: ADR-0023 §execute_sell + GDD §核心规则 #3 ③拆解。
func execute_sell(card_id: int) -> bool:
	var gsm: Node = _get_gsm()
	if gsm == null:
		push_warning("DeckEditingSystem.execute_sell: GSM 不可用")
		return false
	var rs: Node = _get_resource_system()
	if rs == null:
		push_warning("DeckEditingSystem.execute_sell: ResourceSystem 不可用")
		return false
	var price: int = get_sell_price(card_id)
	# 移除卡牌（含最低张数保护）
	if not remove_cards_from_deck([card_id], "shop_sell", "拆解"):
		return false
	# 增加灵石
	if rs.has_method("add_resource"):
		rs.add_resource(&"ling_shi", price)
	return true


# === 战利品编排（Story 5-15 桩实现）===========================================

## 生成战利品选项——桩实现返回固定 3 选项（2卡+1灵石模式）。[br]
## [br][param enemy_data] 敌人数据字典。[br]
## [br][b]返回[/b]: Array[Dictionary]——3 个选项 [{type, data}]。[br]
## [br][b]桩阶段[/b]: 返回固定模式，后续接线 CardSystem 掉落规则。[br]
## [br]来源: ADR-0023 §generate_loot_options + GDD §核心规则 #2。
func generate_loot_options(enemy_data: Dictionary) -> Array:
	# 桩阶段——固定返回 2卡+1灵石模式
	var options: Array = [
		{"type": "card", "data": {"card_id": 1001}},
		{"type": "card", "data": {"card_id": 1002}},
		{"type": "lingshi", "data": {"amount": 15}},
	]
	_loot_options = options.duplicate(true)
	return options


## 应用战利品选择——桩实现根据选项类型执行操作。[br]
## [br][param option_index] 选项索引（0-based）。[br]
## [br][b]流程[/b]: card 选项 → add_cards_to_deck；lingshi 选项 → add_resource。[br]
## [br]来源: ADR-0023 §apply_loot_choice + GDD §核心规则 #2。
func apply_loot_choice(option_index: int) -> bool:
	if option_index < 0 or option_index >= _loot_options.size():
		push_warning("DeckEditingSystem.apply_loot_choice: 无效选项索引 %d" % option_index)
		return false
	var option: Dictionary = _loot_options[option_index]
	var opt_type: String = str(option.get("type", ""))
	match opt_type:
		"card":
			var card_id: int = int(option["data"]["card_id"])
			return add_cards_to_deck([card_id], "loot", "战利品")
		"lingshi":
			var amount: int = int(option["data"]["amount"])
			var rs: Node = _get_resource_system()
			if rs != null and rs.has_method("add_resource"):
				rs.add_resource(&"ling_shi", amount)
			return true
		_:
			push_warning("DeckEditingSystem.apply_loot_choice: 未知选项类型 '%s'" % opt_type)
			return false
