extends RefCounted
## ShopGoodsCatalog —— 主菜单坊市的[b]商品表唯一来源[/b]（模块常量，与场景/节点生命期无关）。[br]
## [br][b]为什么需要一份常驻表[/b]：[code]SceneID.SHOP[/code] 此前挂的是占位屏，
## 而探索侧的商店货架来自 DAG 生成期写进节点详情的 [code]inventory[/code] 载荷
## ——那是[b]节点瞬态[/b]，随节点图释放而消失。坊市是主菜单上的一处常驻摊位，
## 没有「到达某个节点」这件事，因此它要有一条不依赖节点载荷的货源。[br]
## [br][b]为什么不复用 [code]ExplorationShopInventory[/code] 的生成器[/b]：那份生成器
## 的形态是「按境界轮转出 2~3 件、每件一件库存、买走即售罄」——它是为
## [b]一次性的探索节点[/b]设计的。坊市要的是「一列固定货、买多少有多少」，
## 两件事的差异在货架形态与库存口径，不在价格：故本表[b]沿用同一张定价表[/b]
## （[code]ExplorationShopInventory.PRICE_BY_RARITY[/code]），价格不另立一套。[br]
## [br][b]价格不是随手写的[/b]：每件的 [code]price[/code] 必须等于
## [code]price_for_rarity(该模板稀有度)[/code]，由
## [code]tests/integration/shop/test_shop_scene.gd[/code] 逐件对表——两处定价
## 一旦漂移，那条用例红。[br]
## [br][b]模板 ID 必须真实存在[/b]：[code]assets/cards/templates/[/code] 里查不到
## 模板的条目会在上架时被剔除（见 [ShopLogic.rows]），故本表写死的每个 ID 都是
## 该目录里实际存在的文件。[br]
## [br][b]可持久配置[/b]：货架是常量而非「进去现生成」——同一局里每次进坊市看到同一批货
## （无 rng，同 [code]ExplorationShopInventory[/code] 的确定性口径）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：纯静态函数 + 常量，不持节点、不读 GSM、
## 不写任何域。[br]
##
## 来源: design/gdd/deck-editing-system.md §3 坊市买卖、design/ux/deck-editing-ui.md
## §坊市-买卡、ADR-0031 §2、先例 [code]exploration_shop_inventory.gd[/code]。

## 商品条目里「模板 ID」与「单价」两个键的权威拼写——调用方（[ShopLogic] /
## 面板）照抄这两个名字，不各写一份字面量。
const KEY_TEMPLATE_ID: String = "template_id"
const KEY_PRICE: String = "price"

## 坊市货架（8 件，稀有度 1~5 各有覆盖）。[br]
## [br][code]{template_id: String, price: int}[/code]——[code]price[/code] 与
## [code]ExplorationShopInventory.PRICE_BY_RARITY[/code] 同档
## （白 10 / 蓝 25 / 紫 50 / 金 100 / 暗金 200）。[br]
## [br][b]为什么写死而不是算出来[/b]：[constant] 必须是编译期常量，不能在常量表里
## 调 [code]price_for_rarity[/code] 查模板稀有度；两者的一致性交给那条对表用例守。
const DEFAULT_GOODS: Array[Dictionary] = [
	{KEY_TEMPLATE_ID: "pei_yuan_dan", KEY_PRICE: 10},              # 培元丹 · 白
	{KEY_TEMPLATE_ID: "jin_zhong_fu", KEY_PRICE: 10},              # 金钟符 · 白
	{KEY_TEMPLATE_ID: "zhu_ji_dan", KEY_PRICE: 25},                # 筑基丹 · 蓝
	{KEY_TEMPLATE_ID: "artifact_ji_chu_fa_qi", KEY_PRICE: 25},     # 基础法器 · 蓝
	{KEY_TEMPLATE_ID: "pill_yu_ling_dan", KEY_PRICE: 50},          # 玉灵丹 · 紫
	{KEY_TEMPLATE_ID: "artifact_zhong_pin_fa_qi", KEY_PRICE: 50},  # 中品法器 · 紫
	{KEY_TEMPLATE_ID: "pill_tian_luo_dan", KEY_PRICE: 100},        # 天罗丹 · 金
	{KEY_TEMPLATE_ID: "artifact_tong_tian_ling_bao", KEY_PRICE: 200},  # 通天灵宝 · 暗金
]

## 存档里「坊市货架」那一段的键名（[method from_state] 读它）。[br]
## [br][b]本轮存档里还没有这一域[/b]——商品表是常量，故 [method from_state] 实际
## 走的是「取默认表」那条路；这个键是给「以后坊市进货随存档走」预留的入口。
const STATE_KEY_GOODS: String = "shop_goods"


## 本境界的坊市货架（[constant DEFAULT_GOODS] 的深拷贝）。[br]
## [br][b]深拷贝而非交出去[/b]：常量表是全局共享的，调用方一个不经意的
## [code]rows[0]["price"] = 0[/code] 就改写了整局乃至后续用例看到的价格。[br]
## [br][b]返回[/b]：条目数组，每条 [code]{template_id: String, price: int}[/code]。
static func goods() -> Array[Dictionary]:
	return _copy(DEFAULT_GOODS)


## 从状态字典取货架——存档里已有 [constant STATE_KEY_GOODS] 时用它，否则取默认表。[br]
## [br][b]为什么现在就写[/b]：[code]shop_scene[/code] 侧的取数入口一步到位用
## [method from_state]，将来「坊市进货随存档变」（补货 / 涨价 / 解锁好货）只需把
## GSM 里那一域传进来，界面与逻辑两侧零改动。[br]
## [br][b]非法条目按剔除处理[/b]：缺 ID / 价格 ≤ 0 的条目一律不上架——宁可少一件货，
## 也不凭空送出一张没标价的卡（与 [code]ExplorationShop._item_of[/code] 同口径）。[br]
## [br][param p_state] 存档状态（本轮传空字典）。
static func from_state(p_state: Dictionary) -> Array[Dictionary]:
	var raw: Variant = p_state.get(STATE_KEY_GOODS, null)
	if not (raw is Array) or (raw as Array).is_empty():
		return goods()
	var out: Array[Dictionary] = []
	for entry: Variant in raw:
		var item: Dictionary = _normalize(entry)
		if not item.is_empty():
			out.append(item)
	return out if not out.is_empty() else goods()


## 单条归一——两种键名都认（[code]template_id[/code] 与探索侧载荷用的
## [code]card_id[/code]），缺 ID 或价格非正返回空字典（调用方剔除）。[br]
## [br][b]为什么连 [code]card_id[/code] 也认[/b]：存档里若直接存的是探索侧那份
## 载荷（同形不同键），多认一个键名就免了一次迁移。
static func _normalize(p_entry: Variant) -> Dictionary:
	if not (p_entry is Dictionary):
		return {}
	var dict: Dictionary = p_entry
	var template_id: String = str(dict.get(KEY_TEMPLATE_ID, dict.get("card_id", "")))
	var price: int = int(dict.get(KEY_PRICE, 0))
	if template_id.is_empty() or price <= 0:
		return {}
	return {KEY_TEMPLATE_ID: template_id, KEY_PRICE: price}


## 条目数组深拷贝（[constant] 是共享的，交出去之前先复制）。
static func _copy(p_source: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Variant in p_source:
		out.append((entry as Dictionary).duplicate(true))
	return out
