extends RefCounted
## DeckShop —— 卡组坊市操作子模块（从 deck_editing_system.gd 拆分）。
##
## 持有对 DeckEditingSystem 父节点的引用，通过它访问 _get_gsm / _get_resource_system /
## get_session_remove_count / remove_cards_from_deck 等方法和状态。
##
## [br]来源: ADR-0023 §坊市操作 + GDD §核心规则 #3。
## [br]Sprint 10 Story 3：从 deck_editing_system.gd 拆分。

## 父节点引用——DeckEditingSystem Autoload 实例。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


## 获取散功费用——委托 ResourceSystem.delete_card_cost。[br]
## [br][b]返回[/b]: 下一次散功费用灵石数。[br]
## [br][b]注意[/b]: session_remove_count 是已执行次数，delete_card_cost 期望次数从 1 开始。[br]
## [br]来源: ADR-0023 §坊市操作 + GDD §核心规则 #3 ②散功。
func get_delete_cost() -> int:
	var rs: Node = _parent.call("_get_resource_system")
	if rs == null or not rs.has_method("delete_card_cost"):
		return 50  # 默认基价
	var count: int = _parent.call("get_session_remove_count") + 1  # 下一次散功次数
	return rs.delete_card_cost(count)


## 执行散功——支付灵石永久移除一张卡牌。[br]
## [br][param card_id] 要移除的卡牌实例 ID。[br]
## [br][b]返回[/b]: [code]true[/code] 成功，[code]false[/code] 被拒绝。[br]
## [br][b]流程[/b]: get_delete_cost → can_spend → remove_cards → spend_resource → session_remove_count+1。[br]
## [br]来源: ADR-0023 §execute_delete + GDD §核心规则 #3 ②散功。
func execute_delete(card_id: int) -> bool:
	var gsm: Node = _parent.call("_get_gsm")
	if gsm == null:
		push_warning("DeckEditingSystem.execute_delete: GSM 不可用")
		return false
	var rs: Node = _parent.call("_get_resource_system")
	if rs == null:
		push_warning("DeckEditingSystem.execute_delete: ResourceSystem 不可用")
		return false
	var cost: int = get_delete_cost()
	# 灵石不足时拒绝
	if rs.has_method("can_spend") and not rs.can_spend(&"ling_shi", cost):
		push_warning("DeckEditingSystem.execute_delete: 灵石不足（需要 %d）" % cost)
		return false
	# 移除卡牌（含最低张数保护）
	if not _parent.call("remove_cards_from_deck", [card_id], "shop_delete", "散功"):
		return false
	# 扣除灵石
	if rs.has_method("spend_resource"):
		rs.spend_resource(&"ling_shi", cost)
	# 递增散功计数
	var new_count: int = _parent.call("get_session_remove_count") + 1
	gsm._set_deck_session_remove_count(new_count)
	return true


## 获取拆解价值——委托 ResourceSystem.dismantle_value。[br]
## [br][param card_id] 卡牌实例 ID（桩阶段用默认 rarity=1, level=1）。[br]
## [br][b]返回[/b]: 拆解所得灵石数。[br]
## [br]来源: ADR-0023 §get_sell_price + GDD §核心规则 #3 ③拆解。
func get_sell_price(card_id: int) -> int:
	var rs: Node = _parent.call("_get_resource_system")
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
	var gsm: Node = _parent.call("_get_gsm")
	if gsm == null:
		push_warning("DeckEditingSystem.execute_sell: GSM 不可用")
		return false
	var rs: Node = _parent.call("_get_resource_system")
	if rs == null:
		push_warning("DeckEditingSystem.execute_sell: ResourceSystem 不可用")
		return false
	var price: int = get_sell_price(card_id)
	# 移除卡牌（含最低张数保护）
	if not _parent.call("remove_cards_from_deck", [card_id], "shop_sell", "拆解"):
		return false
	# 增加灵石
	if rs.has_method("add_resource"):
		rs.add_resource(&"ling_shi", price)
	return true
