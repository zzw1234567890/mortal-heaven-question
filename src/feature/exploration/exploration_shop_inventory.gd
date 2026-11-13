extends RefCounted
## ExplorationShopInventory —— 坊市库存的默认生成实现（
## [code]ExplorationSystem.generate_shop_inventory_cb[/code] 的生产装配）。[br]
## [br][b]为什么需要[/b]：DAG 生成期 [code]_fill_node_content[/code] 对商店节点调
## [code]generate_shop_inventory_cb(player_realm)[/code]，而该回调此前[b]没有任何生产
## 注入点[/b]——真实 [code]enter_map[/code] 生成的商店节点 [code]inventory[/code] 恒为
## 空字典（面板即使做出来也无货可卖）。本模块补上这条链路。[br]
## [br][b]货架形态[/b]（写入 [code]_node_details[node_id].inventory[/code]）：[br]
## [code]{items: [{card_id: String, rarity: int, price: int, stock: int}],
## generated_for_realm: int}[/code]——[code]price[/code] 与 [code]stock[/code] 在
## [b]生成期[/b]定死，消费侧（[ExplorationShop] / 面板）只读不算。[br]
## [br][b]确定性[/b]：选取只按境界做索引轮转，不用随机——同一境界每次生成同一货架
## （同 [code]ExplorationEventSelector[/code] 的无 rng 口径）。[br]
## [br][b]稀有度来自模板[/b]：候选卡牌必须能在卡牌系统查到模板（价格按模板稀有度
## 定档）；查不到的候选跳过并告警一次，整池都查不到时返回空货架——不臆造价格，
## 也不假造卡牌 ID。[br]
## [br][b]价格是调优旋钮[/b]：GDD 未定义购买价（资源系统只定义出售价），本表按
## 「白 10 / 蓝 25 / 紫 50 / 金 100 / 暗金 200」起步，与初始灵石（10~25）和
## 低难度图通关奖励（50）成比例——后续按经济平衡报告调整本表即可。[br]
##
## 来源: GDD exploration-system.md §3 步骤⑦（商店库存到节点）、§4 节点交互表、
## §8 边界「商店节点中灵石不足购买」、design/ux/deck-editing-ui.md §数据契约、
## DEBT-EUI-006-3/-5 同源（生产回调缺注入点）。

## 价格表——按稀有度索引（0=白 … 4=暗金，即 rarity - 1）。
const PRICE_BY_RARITY: PackedInt32Array = [10, 25, 50, 100, 200]

## 货架数量——按境界分档（低境界 2 件，金丹及以上 3 件）。
const ITEM_COUNT_LOW: int = 2
const ITEM_COUNT_HIGH: int = 3
## 从该境界起上三件货（GDD §节点分布：高难度图商店更多）。
const HIGH_TIER_REALM: int = 3

## 候选卡池——按玩家境界分档（ID 取自 [code]assets/cards/templates/[/code] 的实际模板）。
const POOLS_BY_REALM: Dictionary = {
	1: [&"pei_yuan_dan", &"jian_yi_hu_dun", &"sha_qi_zhan", &"bing_leng_ci"],
	2: [&"zhu_ji_dan", &"dan_xia_jian_qi", &"ku_mu_feng_chun_jue", &"yan_yun_bu"],
	3: [&"wan_xiang_zhen_dian", &"su_jian_ming", &"xun_bao_fu", &"shuang_po_jian_jue"],
	4: [&"wan_xiang_zhen_dian", &"su_jian_ming", &"xun_bao_fu", &"qi_xing_kun_long_zhen"],
	5: [&"wan_xiang_zhen_dian", &"su_jian_ming", &"shuang_po_jian_jue", &"qi_xing_kun_long_zhen"],
}

## 已告警的缺失模板 ID（同一 ID 只提醒一次）。
static var _warned_ids: Dictionary = {}


## 生成一份货架（[code]generate_shop_inventory_cb[/code] 的默认实现）。[br]
## [br][param p_player_realm] 玩家境界（决定候选池、件数与价格档）。[br]
## [param p_lookup] 卡牌模板查询 [code]func(card_id) -> Resource[/code]（可空——
## 空时按 Autoload CardSystem 查；查不到模板的候选一律跳过）。[br]
## [br][b]返回[/b]：[code]{items: Array, generated_for_realm: int}[/code]——池空或
## 模板全缺失时 [code]items[/code] 为空数组（面板显示「货架空空」，不崩溃）。
static func make(p_player_realm: int, p_lookup: Callable = Callable()) -> Dictionary:
	var realm: int = clampi(p_player_realm, 1, 5)
	var pool: Array = POOLS_BY_REALM.get(realm, POOLS_BY_REALM[1])
	var lookup: Callable = p_lookup if p_lookup.is_valid() else _card_lookup()
	var wanted: int = ITEM_COUNT_HIGH if realm >= HIGH_TIER_REALM else ITEM_COUNT_LOW
	var offset: int = (realm - 1) % pool.size()
	var items: Array = []
	for i in range(wanted):
		var card_id: StringName = pool[(offset + i) % pool.size()]
		var item: Dictionary = _item_of(card_id, lookup)
		if item.is_empty():
			continue
		items.append(item)
	return {"items": items, "generated_for_realm": realm}


## [b]一级入口[/b]——生产装配注入的就是这一层：只收玩家境界，模板查询闭包在
## 调用时现取。[br]
## [br][b]为什么不在装配期取一次闭包[/b]：CardSystem 是[b]异步[/b]加载模板的
## （[code]load_threaded_request[/code]，每帧 10 个）。装配发生在主菜单 [code]_ready[/code]，
## 此刻 [code]templates[/code] 大概率为空；但「模板为空」只是当下状态，闭包绑定的
## 是系统实例本身，加载完成后查表自然有值。装配期取一次也一样能拿到实例——
## 这里现取是为了让「CardSystem 缺席 → 空闭包 → 空货架」这条降级路径在
## 每次生成时都重新判定（测试可注入后替换）。
static func make_for_realm(p_player_realm: int) -> Dictionary:
	return make(p_player_realm, _card_lookup())


## 单价——按稀有度取表（越界稀有度夹到 1~5，绝不返回负数）。
static func price_for_rarity(p_rarity: int) -> int:
	var index: int = clampi(p_rarity, 1, PRICE_BY_RARITY.size()) - 1
	return int(PRICE_BY_RARITY[index])


## 候选 → 货架条目；模板缺失返回空字典（调用方跳过该候选）。[br]
## [param p_card_id] 卡牌模板 ID。[param p_lookup] 模板查询闭包。
static func _item_of(p_card_id: StringName, p_lookup: Callable) -> Dictionary:
	if not p_lookup.is_valid():
		_warn_missing(p_card_id)
		return {}
	var tpl: Variant = p_lookup.call(p_card_id)
	if tpl == null:
		_warn_missing(p_card_id)
		return {}
	var rarity: int = clampi(int(tpl.get("rarity")), 1, PRICE_BY_RARITY.size())
	return {
		"card_id": String(p_card_id),
		"rarity": rarity,
		"price": price_for_rarity(rarity),
		"stock": 1,  # 每件一件（买走即售罄；重进地图重新生成）
	}


## 缺失模板告警——同一 ID 只提醒一次（整池全缺时不刷屏）。
static func _warn_missing(p_card_id: StringName) -> void:
	var key: String = String(p_card_id)
	if _warned_ids.has(key):
		return
	_warned_ids[key] = true
	push_warning("ExplorationShopInventory: 卡牌模板 '%s' 不可用，已从货架剔除" % key)


## 卡牌模板查询闭包——Autoload CardSystem 可用时绑定 [code]get_template[/code]，
## 否则返回无效 Callable（生成期拿不到模板 → 货架为空，不臆造价格）。
static func _card_lookup() -> Callable:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return Callable()
	var cs: Node = tree.root.get_node_or_null(NodePath("/root/CardSystem"))
	if cs != null and cs.has_method(&"get_template"):
		return Callable(cs, &"get_template")
	return Callable()
