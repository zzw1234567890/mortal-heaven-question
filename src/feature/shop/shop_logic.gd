extends RefCounted
## ShopLogic —— 主菜单坊市的[b]纯逻辑[/b]（货架呈现 + 购买结算），不碰控件树。[br]
## [br][b]为什么单独一层[/b]：坊市界面要守 300 行软上限
## （.claude/docs/coding-standards.md），而「这件买不买得起、买了之后改什么」
## 与「行怎么画、按键意味着什么」是两件事（同 [code]exploration_shop.gd[/code]
## 拆出结算、[code]shop_panel_navigator.gd[/code] 拆出游标的先例）。[br]
## [br][b]依赖全部注入[/b]（构造参数或 [method set_dependencies]）：本模块自己不
## [code]get_node[/code]、不查 Autoload——三个依赖（资源 / 卡牌 / 存档）都按参数来，
## 测试可以只给需要的那个，不必把整棵场景树搭起来。[br]
## [br][b]零状态所有权（对游戏状态而言）[/b]（ADR-0031 §2）：本模块[b]不持有玩家数据[/b]
## ——灵石、收藏都在 GSM 里，每次现读。它唯一持有的 [member _goods] 是本次上架的
## [b]副本[/b]（货架表来自 [ShopGoodsCatalog]，是常量；持有副本只为让
## [code]index → template_id[/code] 的映射在两次刷新之间稳定）。[br]
## [br][b]灵石读写只用 ResourceSystem[/b]：余额查 [code]get_resource(&"ling_shi")[/code]、
## 扣减 [code]spend_resource(&"ling_shi", n)[/code]、退回 [code]add_resource[/code]
## ——它是灵石账户唯一的类型安全入口（[code]can_spend[/code] 前置校验 + 非负守卫
## + 委托 GSM 的原子写入），直接改 [code]player.resources.ling_shi[/code] 会绕过
## 这三层，故本模块一处都不直写。[br]
## [br][b]拒绝路径全在动手之前[/b]：下标越界 / 模板查不到 / 余额不足 / 收藏已满 /
## 系统不可用——五道校验全过才开始改状态。与探索侧商店同口径：宁可交易失败，
## 也不留下「钱没了卡也没到」。[br]
## [br][b]三件写入按「最会失败的放最前」排序[/b]：先建实例（模板缺失 / 卡牌系统
## 不可用会失败）→ 再扣灵石（已在校验期确认够，此处不该失败）→ 最后入收藏
## （GSM 校验未开启会被拒）。前两步已动钱/已占实例 ID 时第三步失败，退回灵石并
## 报告——这是最后一道保险，正常情况下走不到。[br]
## [br][b]文案本地化豁免[/b]：与 [code]exploration_shop.gd[/code] / [code]shop_panel_screen.gd[/code]
## 同源口径（项目暂无本地化系统），面向玩家的句子集中在本文件的 [constant TEXT_*]。[br]
##
## 来源: design/gdd/deck-editing-system.md §3 坊市买卖、design/ux/deck-editing-ui.md
## §坊市-买卡、ADR-0031 §2、ADR-0006 §GSM 集成合约、先例
## [code]exploration_shop.gd[/code]（货架 + 购买结算）、
## [code]exploration_craft.gd[/code]（收藏容量口径）。

## 商品表唯一来源（货架形态 + 定价档）。
const CatalogScript := preload("res://src/feature/shop/shop_goods_catalog.gd")
## 卡牌实例序列化（与事件发卡、战斗奖励、探索商店同一实现）。
const CardSerializer := preload("res://src/core/card_system/card_serializer.gd")
## 面板行文案里用的「已售罄 / 灵石不足」两个状态标记——不在这里另写一份字面量。
const LayoutScript := preload("res://src/ui/exploration/shop_panel_layout.gd")

## 收藏池容量——与 [code]ExplorationCraft.COLLECTION_CAP[/code] 同值同口径
## （GDD 未给总量上限，取一个可测的值并显式登记；300 覆盖全图鉴的 215~250 张）。[br]
## [br][b]为什么不引用那边的常量[/b]：那条常量属于炼制域，坊市引用它会让两个域
## 通过一个数字耦合；两处各写一份 + 一条断言对表（见测试）比跨域引用更稳。
const COLLECTION_CAP: int = 300

## 购买成功文案（面板原样显示——UI 不另写措辞）。
const TEXT_BOUGHT: String = "已购入 %s"
## 拒绝文案（每条都说明[b]为什么[/b]不能买，不含开发术语）。
const TEXT_NO_SUCH_ITEM: String = "没有这件商品"
const TEXT_NO_TEMPLATE: String = "这件货的来历不明，暂不可购"
const TEXT_NO_RESOURCE: String = "灵石账目不可用，无法购买"
const TEXT_NOT_AFFORDABLE: String = "灵石不足：需要 %d，当前 %d"
const TEXT_COLLECTION_FULL: String = "收藏已满（上限 %d 张），先清理再来"
const TEXT_NO_CARD_SYSTEM: String = "卡牌工坊不可用，无法生成这张牌"
const TEXT_NO_COLLECTION: String = "收藏系统不可用，已退回灵石"
const TEXT_WRITE_FAILED: String = "收藏写入失败，已退回灵石"

## 依赖注入（测试用桩；null 时按 Autoload 查找——各方法自带空守卫）。
var resource_system: Node = null
var card_system: Node = null
var gsm: Node = null

## 本次上架的货架[B]副本[/B]（[code]{template_id, price}[/code]）。
var _goods: Array[Dictionary] = []


## 构造——依赖可后置注入（[method set_dependencies]）。
## [br][param p_state] 存档状态（本轮传空字典——货架取默认表，见
## [code]ShopGoodsCatalog.from_state[/code]）。
func _init(p_resource_system: Node = null, p_card_system: Node = null,
		p_gsm: Node = null, p_state: Dictionary = {}) -> void:
	resource_system = p_resource_system
	card_system = p_card_system
	gsm = p_gsm
	_goods = CatalogScript.from_state(p_state)


## 后置注入（生产路径：Autoload 就绪后再接上——同 [code]CombatBagUse[/code] 形态）。
func set_dependencies(p_resource_system: Node, p_card_system: Node, p_gsm: Node) -> void:
	resource_system = p_resource_system
	card_system = p_card_system
	gsm = p_gsm


# ═══════════════════════════════════════════════════════════════════════════════
# 查询（面板渲染输入——可负担标记现算，UI 不做数值判断）
# ═══════════════════════════════════════════════════════════════════════════════

## 当前灵石余额（资源系统不可用时为 0——不臆造余额）。
func balance() -> int:
	var rs: Node = _rs()
	if rs == null or not rs.has_method(&"get_resource"):
		return 0
	return int(rs.call(&"get_resource", &"ling_shi"))


## 货架——[code]ShopPanelLayout.add_item_row[/code] 直接可用的行数组。[br]
## [br]每条含：面板认的全部键（[code]name / price / rarity / sold / affordable /
## index[/code]）。[br]
## [br][b]模板查不到的条目剔除[/b]：名字与稀有度都取不到时行里只剩一个 ID，
## 玩家看不懂、也无从判断值不值——宁可少一行，也不上架一条来历不明的货。[br]
## [br][b][code]sold[/code] 恒 false[/b]：坊市是常驻摊位（买多少有多少），
## 不存在探索节点那种「买走即售罄」。[br]
## [br][b][code]affordable[/code] 每次现算[/b]：买走一件后重取即刷新，
## 不缓存（缓存会让刚买的钱还留在屏幕上）。
func rows() -> Array[Dictionary]:
	var current: int = balance()
	var out: Array[Dictionary] = []
	for i: int in range(_goods.size()):
		var item: Dictionary = _goods[i]
		var template_id: String = str(item.get(CatalogScript.KEY_TEMPLATE_ID, ""))
		var tpl: Variant = _template_of(template_id)
		if tpl == null:
			continue
		var price: int = int(item.get(CatalogScript.KEY_PRICE, 0))
		out.append({
			"index": i,
			"name": _name_of(tpl, template_id),
			"price": price,
			"rarity": maxi(int(tpl.get("rarity")), 0),
			"sold": false,
			"affordable": current >= price,
		})
	return out


## 货架条目数（含模板缺失的条目——[method rows] 会剔除它们，两者在模板未装载时不等）。[br]
## [br]测试与「等模板就绪再刷」的守望读它判断「是不是还没上全」。
func goods_count() -> int:
	return _goods.size()


# ═══════════════════════════════════════════════════════════════════════════════
# 购买
# ═══════════════════════════════════════════════════════════════════════════════

## 购买第 [param p_index] 件商品（下标为 [method rows] 给出的那个）。[br]
## [br][b]返回[/b]：[code]{ok: bool, reason: String, name: String, price: int}[/code]
## ——[code]reason[/code] 是可直接显示的中文提示（面板原样展示，不做判断）；
## 成功时它是「已购入 XXX」，失败时是拒绝原因。[br]
## [br][b]失败时 [code]price[/code] 恒为 0[/b]：让「没花钱」在返回值里也读得出来，
## 不必靠调用方去比对余额快照。[br]
## [br][param p_index] 索引取 [code]rows()[/code] 里的 [code]index[/code] 键
## （模板缺失的行被剔除后，屏幕上第 N 行未必是货架第 N 件——故索引随行带走）。
func purchase(p_index: int) -> Dictionary:
	# ── 校验：五道门全过才动手（任何一道没过，灵石与收藏一字未动）──────────────
	if p_index < 0 or p_index >= _goods.size():
		return _failed(TEXT_NO_SUCH_ITEM)
	var item: Dictionary = _goods[p_index]
	var template_id: String = str(item.get(CatalogScript.KEY_TEMPLATE_ID, ""))
	var tpl: Variant = _template_of(template_id)
	if tpl == null:
		return _failed(TEXT_NO_TEMPLATE)
	var display: String = _name_of(tpl, template_id)
	var price: int = int(item.get(CatalogScript.KEY_PRICE, 0))
	var rs: Node = _rs()
	if rs == null or not rs.has_method(&"spend_resource"):
		return _failed(TEXT_NO_RESOURCE)
	if not bool(rs.call(&"can_spend", &"ling_shi", price)):
		return _failed(TEXT_NOT_AFFORDABLE % [price, balance()])
	if _collection_count() >= COLLECTION_CAP:
		return _failed(TEXT_COLLECTION_FULL % COLLECTION_CAP)
	var cs: Node = _cs()
	if cs == null or not cs.has_method(&"create_instance"):
		return _failed(TEXT_NO_CARD_SYSTEM)

	# ── 动手：先建实例（本链路里最会失败的一步）→ 扣灵石 → 入收藏 ──────────────
	var instance: Variant = cs.call(&"create_instance", StringName(template_id))
	if instance == null:
		return _failed(TEXT_NO_CARD_SYSTEM)
	if not bool(rs.call(&"spend_resource", &"ling_shi", price)):
		# 校验期已确认够，此处再失败只可能是同帧内被别处改了余额——什么都没发生，如实报告
		return _failed(TEXT_NOT_AFFORDABLE % [price, balance()])
	if not _store_instance(instance, template_id):
		rs.call(&"add_resource", &"ling_shi", price)  # 退回——不留下「钱没了卡也没到」
		return _failed(TEXT_NO_COLLECTION)
	return {"ok": true, "reason": TEXT_BOUGHT % display, "name": display, "price": price}


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 拒绝结果（统一形状——面板只读 [code]reason[/code]）。
static func _failed(p_message: String) -> Dictionary:
	return {"ok": false, "reason": p_message, "name": "", "price": 0}


## 把实例写进收藏（序列化口径与事件发卡 / 战斗奖励 / 探索商店完全一致）。[br]
## [br][b]写 path 前先确认系统在位[/b]：GSM 缺失时直接判失败，让调用方走退回灵石
## 那条路——悄悄吞掉这一步会留下「钱花了、卡没到」。
func _store_instance(p_instance: Variant, p_template_id: String) -> bool:
	var store: Node = _gsm()
	if store == null or not store.has_method(&"add_card_to_collection"):
		return false
	var entry: Dictionary = CardSerializer.serialize_instance(p_instance)
	entry["template_id"] = p_template_id
	return bool(store.call(&"add_card_to_collection", entry))


## 当前收藏张数（GSM 不可用时为 0——不臆造容量占用）。
## [br][b]读 GSM 的 total_count[/b]：它是收藏写入口同步维护的计数
## （[code]gsm_atomic_writes.add_card_to_collection[/code] 每次自增），
## 比现数一遍 [code]owned_cards.size()[/code] 少一次遍历。
func _collection_count() -> int:
	var store: Node = _gsm()
	if store == null:
		return 0
	var collection: Variant = store.get(&"collection")
	if collection == null:
		return 0
	return maxi(int(collection.get("total_count")), 0)


## 展示名——模板名优先，为空时回退模板 ID（不臆造名字）。
static func _name_of(p_template: Variant, p_template_id: String) -> String:
	var display: String = str(p_template.get("name"))
	return display if not display.is_empty() else p_template_id


## 模板查询（卡牌系统不可用 / ID 不存在时返回 null）。
func _template_of(p_template_id: String) -> Variant:
	var cs: Node = _cs()
	if cs == null or not cs.has_method(&"get_template"):
		return null
	return cs.call(&"get_template", StringName(p_template_id))


func _rs() -> Node:
	return resource_system if resource_system != null else _autoload(&"ResourceSystem")


func _cs() -> Node:
	return card_system if card_system != null else _autoload(&"CardSystem")


func _gsm() -> Node:
	return gsm if gsm != null else _autoload(&"GameStateManager")


## Autoload 查找——缺失（headless 单测 / 树未就绪）时返回 null，由调用方降级。
static func _autoload(p_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath(String(p_name)))
