extends RefCounted
## InventoryCatalog —— 背包分类表 + 排序口径 + 境界属性中文标签（纯数据 / 纯函数）。[br]
## [br][b]「分类」是界面结构，「物品」是存档内容[/b]：本表硬编码的是[b]三个分类
## 有哪几类[/b]（灵材 / 丹药 / 法宝）——界面不可能凭空知道自己该分几类；而每一类
## [b]里面有什么、各有多少[/b]一律从真实存档读（[InventoryModel]），本表一条物品
## 记录都没有。这条区分是本模块存在的全部理由。[br]
## [br][b]为什么灵材的枚举与卡片分类不同源[/b]：灵材存在
## [code]player.resources.ling_cai[/code]（四档品质的计数，不是卡牌实例），丹药与
## 法宝存在 [code]collection.owned_cards[/code]（卡牌实例，按 [code]CardTemplate.type[/code]
## 区分）。两者的数据形态根本不同，故分类项里记 [code]source[/code] 声明该去哪儿取。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：全静态纯函数，不 new 节点、不访问 Autoload。[br]
## [br][b]文案本地化豁免[/b]：与 shop_panel_screen / node_interaction_rules 同源口径
## （项目暂无本地化系统）。
##
## 来源: design/gdd/resource-system.md §资源表（灵材）、design/gdd/card-system.md
## §卡牌类型、ADR-0031 §2、先例 [code]exploration_harvest_table.gd[/code]（表 + 中文名
## 单点）、[code]exploration_breakthrough_status.gd[/code]（属性快照只读半边）。

## 数据来源标识——分类项据此决定去哪儿取数（见类文档第 2 段）。
const SOURCE_LING_CAI: StringName = &"ling_cai"
const SOURCE_COLLECTION: StringName = &"collection"

## 三分类定义（顺序即界面上的分类顺序，也是方向键左右切换的顺序）。[br]
## [br][code]card_type[/code] 为 [code]CardTemplate.CardType[/code] 的字面值——
## 不引用该类常量：本表需在 CardSystem 尚未加载任何模板时也能被解析（先例
## [code]card_system.get_templates_by_type[/code] 的「type 传 int 避免 class_name
## 依赖」同源注记）。
const CATEGORIES: Array = [
	{
		"id": SOURCE_LING_CAI,
		"name": "灵材",
		"source": SOURCE_LING_CAI,
		"card_type": -1,
		"empty_text": "行囊里一颗灵材也没有——去灵脉采掘处采些回来。",
	},
	{
		"id": &"pill",
		"name": "丹药",
		"source": SOURCE_COLLECTION,
		"card_type": 4,  # CardTemplate.CardType.PILL
		"empty_text": "行囊里还没有丹药——丹成之后自会出现在这里。",
	},
	{
		"id": &"artifact",
		"name": "法宝",
		"source": SOURCE_COLLECTION,
		"card_type": 2,  # CardTemplate.CardType.ARTIFACT
		"empty_text": "行囊里还没有法宝——炼器台上炼成一件便有了。",
	},
]

## 灵材四档品质键 → 中文名（与 [code]ResourceSystem.LingCaiQuality[/code] 1-4 对齐，
## 与 [code]ExplorationHarvestTable.QUALITY_NAMES[/code] 同口径——两处各写一份是
## 刻意的：那张表属采集域，本表属背包域，谁都不该为了对方改名）。
const LING_CAI_QUALITY_KEYS: Array = ["low", "medium", "high", "top"]
const LING_CAI_QUALITY_NAMES: Dictionary = {
	"low": "下品", "medium": "中品", "high": "上品", "top": "极品",
}
## 各品质的展示稀有度（排序用——与 [code]CardTemplate.Rarity[/code] 同刻度）。
const LING_CAI_QUALITY_RARITY: Dictionary = {
	"low": 1, "medium": 2, "high": 3, "top": 4,
}

## 稀有度 int → 中文名（与 shop_panel_layout.RARITY_NAMES 同口径）。
const RARITY_NAMES: Dictionary = {1: "白", 2: "蓝", 3: "紫", 4: "金", 5: "暗金"}

## 境界属性键 → 中文标签（面板按此展示 [code]RealmSystem.realm_table[/code] 的条目）。[br]
## [br][b]只做标签，不做数值[/b]：数值一律现查境界表——本表多一个数就是第二条真理来源。[br]
## [br][b]未登记的键[/b]：走 [method attribute_label] 回退为键名本身，不隐藏——境界表
## 新增键时面板自动多一行（宁可显示得朴素，也不静默吞掉一个已配置的属性）。
const ATTRIBUTE_LABELS: Dictionary = {
	"max_cultivation": "修为上限",
	"max_deploy": "出战上限",
	"cost_per_turn": "灵能上限",
	"deck_limit": "卡组上限",
	"action_points": "行动力上限",
	"base_speed": "基础速度",
	"max_darkgold": "暗金卡上限",
	"card_pool_tier": "掉落池等级",
	"map_unlock": "解锁地图",
	"gongfa_slots": "功法位",
	"fabao_slots": "法宝位",
}


## 分类数量。
static func category_count() -> int:
	return CATEGORIES.size()


## 按下标取分类（越界返回空字典——调用方据此显示空态而非崩溃）。
static func category_at(p_index: int) -> Dictionary:
	if p_index < 0 or p_index >= CATEGORIES.size():
		return {}
	return CATEGORIES[p_index]


## 按下标取分类中文名（越界返回空串）。
static func category_name(p_index: int) -> String:
	return str(category_at(p_index).get("name", ""))


## 按下标取该分类的空态文案（越界返回通用文案）。
static func empty_text(p_index: int) -> String:
	var text: String = str(category_at(p_index).get("empty_text", ""))
	return text if not text.is_empty() else "这一类暂时空着。"


## 分类标签栏文案——「灵材 (3) · 丹药 · 法宝 (1)」，选中项用方括号括起。[br]
## [br][b]数量为 0 的分类不显示数字[/b]（与条目「数量为 0 不显示」同一口径——
## 屏上不留 0 这种噪声）。[br]
## [br][param p_counts] [code]{category_index: 条目数}[/code]。[br]
## [param p_selected] 当前选中的分类下标。
static func category_bar_text(p_counts: Dictionary, p_selected: int) -> String:
	var parts: Array = []
	for index: int in range(CATEGORIES.size()):
		var label: String = category_name(index)
		var count: int = int(p_counts.get(index, 0))
		if count > 0:
			label = "%s (%d)" % [label, count]
		if index == p_selected:
			label = "[%s]" % label
		parts.append(label)
	return "  ".join(parts)


## 境界属性键 → 中文标签（未登记回退键名本身，见常量注记）。
static func attribute_label(p_key: String) -> String:
	var label: String = str(ATTRIBUTE_LABELS.get(p_key, ""))
	return label if not label.is_empty() else p_key


## 稀有度中文名（未知档位返回空串，不臆造）。
static func rarity_name(p_rarity: int) -> String:
	return str(RARITY_NAMES.get(p_rarity, ""))


## 条目排序比较器——[b]稀有度降序 → 名称升序[/b]。[br]
## [br]稀有度相同时按名称排（而非插入顺序）：收藏池的追加顺序会随玩法变化，
## 按名称排才能让「同一份存档每次打开看到的顺序一致」。[br]
## [br][param p_a] / [param p_b] 条目字典（需含 [code]rarity[/code] / [code]name[/code]）。
static func sort_desc_by_rarity(p_a: Dictionary, p_b: Dictionary) -> bool:
	var ra: int = int(p_a.get("rarity", 0))
	var rb: int = int(p_b.get("rarity", 0))
	if ra != rb:
		return ra > rb
	return str(p_a.get("name", "")) < str(p_b.get("name", ""))
