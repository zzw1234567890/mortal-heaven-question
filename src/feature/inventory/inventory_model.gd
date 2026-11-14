extends RefCounted
## InventoryModel —— 背包的只读取数半边（读真实存档，不硬编码任何物品）。[br]
## [br][b]两条数据源，形态不同[/b]（见 [InventoryCatalog] 类文档）：[br]
##   · 灵材——[code]GameStateManager.player.resources.ling_cai = {low, medium, high, top}[/code]
##     四档计数（ADR-0019 §资源类型）。非零档位各成一行。[br]
##   · 丹药 / 法宝——[code]GameStateManager.collection.owned_cards[/code] 里的卡牌实例
##     （9 字段 Dictionary），用 [code]CardSystem.get_template(StringName(template_id))[/code]
##     取 [code]type[/code] 过滤、取 [code]name[/code] / [code]rarity[/code] 展示。[br]
## [br][b]同名合并计数[/b]：GDD card-system.md §边界「收藏池允许同名多张」——同一
## [code]template_id[/code] 的多张实例合成一行「名称 ×N」，不铺成 N 行重复项。[br]
## [br][b]数量为 0 不显示[/b]（本轮硬性要求）：灵材的零档位与空分类都不出行；
## 分类本身仍存在（界面靠分类知道「这里本该有什么」）。[br]
## [br][b]取不到就是空，不臆造[/b]：GSM 缺失 / 域不是字典 / 模板查不到（卡牌系统还在
## 异步加载）时该条目不出现——宁可少显示一项，也不显示一个编造的数量。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：每次调用现读 GSM/卡牌系统，不缓存快照
## （缓存会让「刚炼成的丹」在背包里迟到一帧）。[br]
## [br][b]不写任何数据[/b]：本模块只有读方法——背包是展示面，不是结算面。
##
## 来源: ADR-0019 §资源类型、ADR-0001 §第一层数据读取、GDD card-system.md §卡牌类型
## / §边界（同名多张）、GDD resource-system.md §资源表（灵材）、ADR-0031 §2、
## 先例 [code]deploy_roster_reader.gd[/code]（注入式只读名册读取器）。

## 分类表 + 排序 + 中文词条（单一真理来源）。
const CatalogScript := preload("res://src/feature/inventory/inventory_catalog.gd")

## 依赖注入（测试用桩；null 时按 Autoload 查找——先例 DeployRosterReader 的注入式签名）。
var gsm: Node = null
var card_system: Node = null


## 构造——两个依赖都可后置注入（[method set_dependencies]）。
func _init(p_gsm: Node = null, p_card_system: Node = null) -> void:
	gsm = p_gsm
	card_system = p_card_system


## 后置注入（生产路径：Autoload 就绪后再接上）。
func set_dependencies(p_gsm: Node, p_card_system: Node) -> void:
	gsm = p_gsm
	card_system = p_card_system


# ═══════════════════════════════════════════════════════════════════════════════
# 对外
# ═══════════════════════════════════════════════════════════════════════════════

## 取某分类的全部条目——已按 [method InventoryCatalog.sort_desc_by_rarity] 排序。[br]
## [br][b]返回[/b]：[code]Array[Dictionary][/code]，每条
## [code]{name, rarity, rarity_name, count, detail, key}[/code]；越界分类或没东西 → 空数组。[br]
## [br][code]count[/code] 为该行持有数量（恒 ≥ 1——0 的行不产出）；[code]detail[/code]
## 是副标题（灵材写品质、卡片写类别），[code]key[/code] 是合并用的稳定标识。
func category_entries(p_category_index: int) -> Array:
	var category: Dictionary = CatalogScript.category_at(p_category_index)
	if category.is_empty():
		return []
	var entries: Array = []
	match str(category.get("source", "")):
		CatalogScript.SOURCE_LING_CAI:
			entries = _ling_cai_entries()
		CatalogScript.SOURCE_COLLECTION:
			entries = _collection_entries(int(category.get("card_type", -1)))
	entries.sort_custom(CatalogScript.sort_desc_by_rarity)
	return entries


## 各分类的条目数——[code]{category_index: count}[/code]（分类栏角标用）。[br]
## 越界分类自然缺席（[method category_entries] 返回空数组）。
func category_counts() -> Dictionary:
	var out: Dictionary = {}
	for index: int in range(CatalogScript.category_count()):
		out[index] = category_entries(index).size()
	return out


## 分类栏文案（数与选中态都在 [InventoryCatalog] 里拼——面板不做文本组装）。
func category_bar_text(p_selected: int) -> String:
	return CatalogScript.category_bar_text(category_counts(), p_selected)


# ═══════════════════════════════════════════════════════════════════════════════
# 灵材（player.resources.ling_cai 四档计数）
# ═══════════════════════════════════════════════════════════════════════════════

## 灵材行——非零品质档位各一行（下品/中品/上品/极品）。[br]
## [br]条目名即品质名（「下品灵材」）——[code]ling_cai[/code] 是四档计数而非具名物品，
## 没有比品质更细的名字可用；不为此编造一堆材料名（那是采集载荷表的事）。[br]
## [br][b]不借卡牌稀有度当品阶[/b]：[code]rarity[/code] 只作[b]排序刻度[/b]用
## （下品 1 → 极品 4），[code]rarity_name[/code] 留空——「极品/下品」与卡牌的
## 「金/暗金」是两套不同刻度的词，混用会让玩家以为灵材也有暗金档。布局把空段
## 过滤掉，故行文案就是「极品灵材 · ×2」。
func _ling_cai_entries() -> Array:
	var out: Array = []
	var counts: Variant = _ling_cai_counts()
	if not (counts is Dictionary):
		return out
	for key: String in CatalogScript.LING_CAI_QUALITY_KEYS:
		var amount: int = int((counts as Dictionary).get(key, 0))
		if amount <= 0:
			continue  # 数量为 0 不显示
		var quality_name: String = str(CatalogScript.LING_CAI_QUALITY_NAMES.get(key, key))
		out.append({
			"key": "ling_cai:%s" % key,
			"name": "%s灵材" % quality_name,
			"rarity": int(CatalogScript.LING_CAI_QUALITY_RARITY.get(key, 0)),
			"rarity_name": "",
			"count": amount,
			"detail": "灵材",
		})
	return out


## [code]player.resources.ling_cai[/code] 原始值——任一层缺失返回 null。[br]
## [br]旧存档可能是扁平 int（GSM 迁移前的格式，见 gsm_serializer 的向前兼容分支）：
## 那种形态读不出四档，按「没有灵材」处理而非报错——背包不该为旧档崩溃。
func _ling_cai_counts() -> Variant:
	var store: Node = _resolve_gsm()
	if store == null:
		return null
	var player: Variant = store.get("player")
	if not (player is Dictionary):
		return null
	var resources: Variant = (player as Dictionary).get("resources", null)
	if not (resources is Dictionary):
		return null
	var counts: Variant = (resources as Dictionary).get("ling_cai", null)
	return counts if counts is Dictionary else null


# ═══════════════════════════════════════════════════════════════════════════════
# 丹药 / 法宝（collection.owned_cards 按模板类型过滤 + 同名合并）
# ═══════════════════════════════════════════════════════════════════════════════

## 收藏里某类型的行——按 [code]template_id[/code] 合并同名多张。[br]
## [br][param p_card_type] [code]CardTemplate.CardType[/code] 值；模板 [code]type[/code]
## 不匹配即跳过。模板查不到（异步加载未完成 / 未知 ID）时跳过该实例——不臆造名称。
func _collection_entries(p_card_type: int) -> Array:
	var owned: Variant = _owned_cards()
	if not (owned is Array):
		return []
	var merged: Dictionary = {}
	var order: Array = []
	for raw: Variant in (owned as Array):
		if not (raw is Dictionary):
			continue
		var instance: Dictionary = raw
		var template: Variant = _template_of(str(instance.get("template_id", "")))
		if template == null:
			continue
		if int(template.get("type")) != p_card_type:
			continue
		var key: String = str(template.get("card_id"))
		if not merged.has(key):
			merged[key] = {
				"key": key,
				"name": str(template.get("name")),
				"rarity": int(template.get("rarity")),
				"rarity_name": CatalogScript.rarity_name(int(template.get("rarity"))),
				"count": 0,
				"detail": _type_name(p_card_type),
			}
			order.append(key)
		(merged[key] as Dictionary)["count"] += 1
	var out: Array = []
	for key: Variant in order:
		var entry: Dictionary = merged[key]
		if int(entry.get("count", 0)) <= 0:
			continue  # 数量为 0 不显示（合并计数下恒 ≥1，此处为口径完备性守卫）
		out.append(entry)
	return out


## [code]collection.owned_cards[/code] 原始值——任一层缺失返回 null。
func _owned_cards() -> Variant:
	var store: Node = _resolve_gsm()
	if store == null:
		return null
	var collection: Variant = store.get("collection")
	if not (collection is Dictionary):
		return null
	return (collection as Dictionary).get("owned_cards", null)


## 按 [code]template_id[/code] 查模板——卡牌系统缺失或 ID 为空时返回 null。[br]
## [br]模板 ID 在 JSON 往返后是 String（存档把它序列化成字符串），故显式转
## [code]StringName[/code] 再查（先例 card_system 的 [code]_to_stringname[/code]）。
func _template_of(p_template_id: String) -> Variant:
	if p_template_id.is_empty():
		return null
	var system: Node = _resolve_card_system()
	if system == null or not system.has_method(&"get_template"):
		return null
	return system.call(&"get_template", StringName(p_template_id))


## 卡片类型 → 中文类别名（面板副标题用；未登记的取值回退空串，不臆造词）。
static func _type_name(p_card_type: int) -> String:
	match p_card_type:
		2:
			return "法宝"
		4:
			return "丹药"
		0:
			return "角色"
		1:
			return "功法"
		3:
			return "阵法"
		5:
			return "符箓"
	return ""


# ═══════════════════════════════════════════════════════════════════════════════
# 内部辅助
# ═══════════════════════════════════════════════════════════════════════════════

## GSM——注入优先，否则 Autoload 查找（测试脱离 Autoload 时可注入桩）。
func _resolve_gsm() -> Node:
	if gsm != null:
		return gsm
	return _autoload(&"GameStateManager")


## 卡牌系统——同上。
func _resolve_card_system() -> Node:
	if card_system != null:
		return card_system
	return _autoload(&"CardSystem")


## Autoload 动态查找（无 SceneTree / 未注册时返回 null，不抛错）。
static func _autoload(p_node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath(String(p_node_name)))
