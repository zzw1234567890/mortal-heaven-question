extends RefCounted
## ExplorationShop —— 探索商店节点的货架与购买结算（Feature 层实现）。[br]
## [br][b]职责[/b]：把「到达商店节点拿到的库存载荷」变成一份可购买的货架，
## 并执行购买——校验余额 → 建卡实例 → 扣灵石 → 入收藏。[br]
## [br][b]为什么在 Feature 层而不是 UI 里[/b]：扣费与入收藏是玩法状态变更
## （control-manifest：UI 只发起请求、显示系统返回的文案，不碰 GSM）。
## 面板只调 [method items] / [method purchase]，并把返回的 [code]message[/code]
## 原样显示——「灵石不足」这类文案只有一处措辞。[br]
## [br][b]复用的既有设施（不另开第二条通路）[/b]：[br]
##   · 余额与扣费——[code]ResourceSystem.can_spend[/code] /
##     [code]spend_resource[/code] / [code]add_resource[/code]（退回）；[br]
##   · 建实例——[code]CardSystem.create_instance[/code]（实例 ID 由 GSM 分配）；[br]
##   · 入收藏——[code]GameStateManager.add_card_to_collection[/code]
##     （经 [code]CardSerializer.serialize_instance[/code] 序列化，与事件发卡同一口径）。[br]
## [br][b]库存来源[/b]：[method open] 收到的载荷来自 [code]ExplorationSystem[/code]
## 的 [code]node_interaction_triggered[/code]（DAG 生成期由
## [ExplorationShopInventory.make] 写入）。载荷无可售条目时[b]按玩家境界兜底
## 生成一份[/b]（最低可用性：商店节点永远有货可看），生成逻辑只在那一个模块里。[br]
## [br][b]失败不半完成[/b]：扣费成功后入收藏被拒 → 原价退回灵石并返回失败
## （宁可交易失败，也不留下「钱没了卡也没到」）。[br]
## [br][b]售罄即库存清零[/b]：每件带 [code]stock[/code] 件（默认 1），买走递减，
## 归零即售罄——[method items] 的 [code]sold[/code] 直接由库存推导，不另存一份
## 「已售」状态（两份状态必然漂移）。[br]
##
## 来源: GDD exploration-system.md §3 步骤⑦/§4 节点交互表/§8 边界（灵石不足）、
## design/ux/deck-editing-ui.md §数据契约与 §错误-灵石不足、
## ADR-0031 §2（UI 零状态所有权）、DEBT-EUI-006-3 同源。

## 库存生成器（货架形态与价格的唯一来源）。
const InventoryScript := preload("res://src/feature/exploration/exploration_shop_inventory.gd")
## 卡牌实例序列化（与事件发卡、战斗奖励同一实现）。
const CardSerializer := preload("res://src/core/card_system/card_serializer.gd")

## 依赖注入（测试用桩；null 时按 Autoload 查找）。
var resource_system: Node = null
var card_system: Node = null
var gsm: Node = null

## 本次访问的节点 ID（-1 = 未打开）。
var _node_id: int = -1
## 货架条目（[code]{card_id, rarity, price, stock}[/code]）。
var _items: Array = []
## 是否存在打开的货架。
var _opened: bool = false


# ═══════════════════════════════════════════════════════════════════════════════
# 开合
# ═══════════════════════════════════════════════════════════════════════════════

## 打开货架。[br]
## [br][param p_node_id] 商店节点 ID。[br]
## [param p_inventory] 节点库存载荷（[code]{items: [...], generated_for_realm: N}[/code]）；
## 无可售条目时按境界兜底生成。[br]
## [br][b]返回[/b]：本次上架的条目数（0 = 无货可售，面板据此显示空货架）。[br]
## [br][b]节点 ID 变了才重置库存[/b]：同一节点重复到达（面板重开）保留已售状态；
## 换了节点则是新货架。
func open(p_node_id: int, p_inventory: Dictionary) -> int:
	var same_node: bool = _opened and p_node_id == _node_id
	_node_id = p_node_id
	_opened = true
	if same_node:
		return _items.size()
	var realm: int = _resolve_realm(p_inventory)
	var lookup: Callable = _lookup()
	_items = _normalize(p_inventory, lookup)
	if _items.is_empty():
		# 兜底：载荷无货（未装配回调 / 空池）——按玩家境界生成一份最低可用的货架
		_items = _normalize(InventoryScript.make(realm, lookup), lookup)
	return _items.size()


## 关闭货架（清空本次访问的瞬态状态）。
func close() -> void:
	_opened = false
	_node_id = -1
	_items = []


## 货架是否已打开。
func is_open() -> bool:
	return _opened


## 本次访问的节点 ID（未打开为 -1）。
func node_id() -> int:
	return _node_id


# ═══════════════════════════════════════════════════════════════════════════════
# 查询（面板渲染输入——含可负担与售罄标记，UI 不做数值判断）
# ═══════════════════════════════════════════════════════════════════════════════

## 当前灵石余额（资源系统不可用时为 0——不臆造余额）。
func balance() -> int:
	var rs: Node = _rs()
	if rs == null or not rs.has_method(&"get_resource"):
		return 0
	return int(rs.call(&"get_resource", &"ling_shi"))


## 货架条目（面板渲染输入）。[br]
## [br]每条含：载荷四键 + [code]index[/code]（购买时回传）+ [code]name[/code]
## （模板名，模板缺失时回退卡牌 ID）+ [code]sold[/code]（库存归零）+ [code]affordable[/code]
## （余额是否够）——[code]affordable[/code] 每次现算，购买后重取即刷新。[br]
func items() -> Array:
	var current: int = balance()
	var out: Array = []
	for i in range(_items.size()):
		var item: Dictionary = (_items[i] as Dictionary).duplicate()
		var card_id: String = str(item.get("card_id", ""))
		item["index"] = i
		item["name"] = _name_of(card_id)
		item["sold"] = int(item.get("stock", 0)) <= 0
		item["affordable"] = current >= int(item.get("price", 0))
		out.append(item)
	return out


# ═══════════════════════════════════════════════════════════════════════════════
# 购买
# ═══════════════════════════════════════════════════════════════════════════════

## 购买第 [param p_index] 件商品。[br]
## [br][b]返回[/b]：[code]{ok: bool, message: String, spent: int, card_id: String}[/code]
## ——[code]message[/code] 是可直接显示的中文提示（面板原样展示，不做判断）。[br]
## [br][b]拒绝路径全部不扣钱[/b]：下标越界 / 已售罄 / 余额不足 / 卡牌系统不可用
## 都在扣费之前返回。[br]
func purchase(p_index: int) -> Dictionary:
	if not _opened:
		return _fail("商店尚未打开")
	if p_index < 0 or p_index >= _items.size():
		return _fail("没有这件商品")
	if int((_items[p_index] as Dictionary).get("stock", 0)) <= 0:
		return _fail("这件已经卖完了")

	var item: Dictionary = _items[p_index]
	var card_id: String = str(item.get("card_id", ""))
	var price: int = int(item.get("price", 0))

	var rs: Node = _rs()
	if rs == null or not rs.has_method(&"spend_resource"):
		return _fail("资源系统不可用，无法购买")
	if not bool(rs.call(&"can_spend", &"ling_shi", price)):
		return _fail("灵石不足：需要 %d，当前 %d" % [price, balance()])

	# 先建实例再扣费——建不出卡就不动钱（「失败不半完成」的第一道保险）
	var instance: Variant = _create_instance(card_id)
	if instance == null:
		return _fail("无法生成卡牌 %s" % card_id)
	if not bool(rs.call(&"spend_resource", &"ling_shi", price)):
		return _fail("灵石不足：需要 %d，当前 %d" % [price, balance()])

	var entry: Dictionary = CardSerializer.serialize_instance(instance)
	entry["template_id"] = card_id
	var store: Node = _gsm()
	if store == null or not store.has_method(&"add_card_to_collection"):
		rs.call(&"add_resource", &"ling_shi", price)  # 退回——不留下「钱没了卡也没到」
		return _fail("收藏系统不可用，已退回灵石")
	if not bool(store.call(&"add_card_to_collection", entry)):
		rs.call(&"add_resource", &"ling_shi", price)
		return _fail("收藏写入失败，已退回灵石")

	item["stock"] = int(item.get("stock", 1)) - 1
	_items[p_index] = item
	return {
		"ok": true,
		"message": "购入 %s，花费 %d 灵石" % [_name_of(card_id), price],
		"spent": price,
		"card_id": card_id,
	}


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 拒绝结果（统一形状——面板只读 message）。
static func _fail(p_message: String) -> Dictionary:
	return {"ok": false, "message": p_message, "spent": 0, "card_id": ""}


## 建卡实例——卡牌系统不可用 / 模板缺失时返回 null（调用方据此拒绝购买）。[br]
## 模板存在性由 [code]create_instance[/code] 内部校验（未知 ID 会 push_error 并返回 null），
## 这里只做「系统是否可用」的前置判定，不重复实现校验。
func _create_instance(p_card_id: String) -> Variant:
	var cs: Node = _cs()
	if cs == null or not cs.has_method(&"create_instance"):
		return null
	if cs.has_method(&"has_template") and not bool(cs.call(&"has_template", StringName(p_card_id))):
		return null
	return cs.call(&"create_instance", StringName(p_card_id))


## 货架归一——载荷条目 → 可售条目；无卡牌 ID / 无库存 / 价格与稀有度都读不到的剔除。[br]
## [br]条目形态两种都认：字典 [code]{card_id, price?, rarity?, stock?}[/code]
## 与裸字符串（只有卡牌 ID，价格按模板稀有度定档）。
func _normalize(p_inventory: Dictionary, p_lookup: Callable) -> Array:
	var raw: Variant = p_inventory.get("items", [])
	if not (raw is Array):
		return []
	var out: Array = []
	for entry: Variant in raw:
		var item: Dictionary = _item_of(entry, p_lookup)
		if not item.is_empty():
			out.append(item)
	return out


## 单条归一（模板不可查且未给显式价格 → 剔除，绝不臆造价格）。[br]
## 静态以便 GUT 直调（不经 Autoload）。
static func _item_of(p_entry: Variant, p_lookup: Callable) -> Dictionary:
	var card_id: String = ""
	var price: int = 0
	var stock: int = 1
	if p_entry is Dictionary:
		var dict: Dictionary = p_entry
		card_id = str(dict.get("card_id", ""))
		price = int(dict.get("price", 0))
		stock = int(dict.get("stock", 1))
	else:
		card_id = str(p_entry)
	if card_id.is_empty() or stock <= 0:
		return {}
	var rarity: int = _rarity_of(card_id, p_lookup)
	if price <= 0:
		if rarity <= 0:
			return {}
		price = InventoryScript.price_for_rarity(rarity)
	return {"card_id": card_id, "rarity": rarity, "price": price, "stock": stock}


## 模板稀有度——模板不可查时返回 0（调用方据此判定「无价可定」）。
static func _rarity_of(p_card_id: String, p_lookup: Callable) -> int:
	if not p_lookup.is_valid():
		return 0
	var tpl: Variant = p_lookup.call(StringName(p_card_id))
	if tpl == null:
		return 0
	return maxi(int(tpl.get("rarity")), 0)


## 展示名——模板名优先，模板不可查时回退卡牌 ID（不臆造名字）。
func _name_of(p_card_id: String) -> String:
	var tpl: Variant = _template_of(p_card_id)
	if tpl == null:
		return p_card_id
	var display: String = str(tpl.get("name"))
	return display if not display.is_empty() else p_card_id


## 模板查询（卡牌系统不可用时返回 null）。
func _template_of(p_card_id: String) -> Variant:
	var cs: Node = _cs()
	if cs == null or not cs.has_method(&"get_template"):
		return null
	return cs.call(&"get_template", StringName(p_card_id))


## 境界——载荷自带生成境界优先，否则读 GSM 玩家境界，再否则炼气（1）。
func _resolve_realm(p_inventory: Dictionary) -> int:
	var realm: int = int(p_inventory.get("generated_for_realm", 0))
	if realm > 0:
		return clampi(realm, 1, 5)
	var store: Node = _gsm()
	if store != null:
		var player: Variant = store.get(&"player")
		if player is Dictionary:
			return clampi(int((player as Dictionary).get("realm", 1)), 1, 5)
	return 1


## 模板查询闭包——注入卡牌系统优先，否则 Autoload。
func _lookup() -> Callable:
	var cs: Node = _cs()
	if cs != null and cs.has_method(&"get_template"):
		return Callable(cs, &"get_template")
	return Callable()


func _rs() -> Node:
	return resource_system if resource_system != null else _autoload(&"ResourceSystem")


func _cs() -> Node:
	return card_system if card_system != null else _autoload(&"CardSystem")


func _gsm() -> Node:
	return gsm if gsm != null else _autoload(&"GameStateManager")


## Autoload 查找——缺失（headless 单测）时返回 null，由调用方降级。
static func _autoload(p_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath(String(p_name)))
