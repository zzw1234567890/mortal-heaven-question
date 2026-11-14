extends RefCounted
## ExplorationHarvestTable —— 采集节点（灵草 / 矿脉）的载荷表。[br]
## [br][b]为什么单独一处[/b]：「这张图第 N 层的采集点能采到什么」是[b]数据[/b]，
## 与「采到的材料怎么进背包、已采状态怎么持久化」（[ExplorationHarvest]）是两件事。
## 同 [code]exploration_shop_inventory.gd[/code] 与 [code]exploration_shop.gd[/code]
## 的分工先例——后者结算，前者供货。[br]
## [br][b]两类材料[/b]：[code]herb[/code]（灵草）与 [code]ore[/code]（矿脉）——
## 二者都进同一本背包（[code]player.resources.ling_cai[/code]，四档品质），
## 区别只在名称与品质档位（矿脉偏高品质）。GDD 资源表把灵材的获取途径写作
## 「探索事件（灵脉采掘）」，本表是该途径在节点图上的落点。[br]
## [br][b]确定性[/b]：载荷不掷随机数——按 [code]map_id[/code] 的哈希在变体内取一个，
## 因此同一张图的采集点每次生成都是同一批（读档重建、重进地图都不漂移，
## 存档里的「已采 slot」才有意义）。[br]
## [br][b]slot 是持久化键[/b]：条目在数组里的下标即其 [constant KEY_SLOT]——
## 已采状态按 slot 记在 [code]map_states[map_id]["harvested_<node_id>"][/code] 里，
## 不用名称做键（改名不该让玩家白采一次）。[br]
##
## 来源: design/gdd/resource-system.md §资源表（灵材）/ §获取途径、
## design/gdd/exploration-system.md §节点类型一览、ADR-0019 §资源类型、
## 先例 [code]exploration_shop_inventory.gd[/code]。

## 材料类别（载荷里的 [constant KEY_KIND] 取值）。
const KIND_HERB: StringName = &"herb"
const KIND_ORE: StringName = &"ore"

## 载荷条目的键（生成器写入 / 结算与面板读取的同一口径）。
const KEY_SLOT: String = "slot"
const KEY_NAME: String = "name"
const KEY_KIND: String = "kind"
const KEY_QUALITY: String = "quality"
const KEY_AMOUNT: String = "amount"

## 类别 → 中文名（面板与提示文案共用；项目暂无本地化系统，豁免口径同
## [code]node_interaction_rules.gd[/code]）。
const KIND_NAMES: Dictionary = {
	KIND_HERB: "灵草",
	KIND_ORE: "矿脉",
}

## 品质档位 → 中文名（与 [code]ResourceSystem.LingCaiQuality[/code] 1-4 对齐）。
const QUALITY_NAMES: Dictionary = {
	1: "下品", 2: "中品", 3: "上品", 4: "极品",
}

## 载荷池——按玩家境界索引（越界时夹到最近档），每档两个变体。[br]
## [br][b]为什么按境界分层[/b]：炼气期的采集点不该冒出极品材料——与商店货架
## （[code]ShopInventory.POOLS_BY_REALM[/code]）同一「按境界给产出」的口径。[br]
## [br][b]每个变体都含灵草与矿脉各一[/b]：玩家到达任一采集点都能看到两类材料，
## 「灵草/矿脉」的区分是可见的，不靠碰运气。[br]
const POOLS_BY_REALM: Array = [
	[  # 炼气期
		[
			{KEY_KIND: KIND_HERB, KEY_NAME: "青灵草", KEY_QUALITY: 1, KEY_AMOUNT: 2},
			{KEY_KIND: KIND_ORE, KEY_NAME: "玄铁矿", KEY_QUALITY: 1, KEY_AMOUNT: 1},
		],
		[
			{KEY_KIND: KIND_HERB, KEY_NAME: "凝露草", KEY_QUALITY: 1, KEY_AMOUNT: 1},
			{KEY_KIND: KIND_ORE, KEY_NAME: "赤铜矿", KEY_QUALITY: 1, KEY_AMOUNT: 2},
		],
	],
	[  # 筑基期
		[
			{KEY_KIND: KIND_HERB, KEY_NAME: "玉髓草", KEY_QUALITY: 2, KEY_AMOUNT: 2},
			{KEY_KIND: KIND_ORE, KEY_NAME: "寒铁砂", KEY_QUALITY: 2, KEY_AMOUNT: 1},
		],
		[
			{KEY_KIND: KIND_HERB, KEY_NAME: "紫芝", KEY_QUALITY: 2, KEY_AMOUNT: 1},
			{KEY_KIND: KIND_ORE, KEY_NAME: "黑曜矿", KEY_QUALITY: 2, KEY_AMOUNT: 2},
		],
	],
	[  # 金丹期
		[
			{KEY_KIND: KIND_HERB, KEY_NAME: "九叶芝", KEY_QUALITY: 3, KEY_AMOUNT: 1},
			{KEY_KIND: KIND_ORE, KEY_NAME: "玄晶矿", KEY_QUALITY: 3, KEY_AMOUNT: 1},
		],
		[
			{KEY_KIND: KIND_HERB, KEY_NAME: "龙涎草", KEY_QUALITY: 3, KEY_AMOUNT: 2},
			{KEY_KIND: KIND_ORE, KEY_NAME: "星辰砂", KEY_QUALITY: 3, KEY_AMOUNT: 1},
		],
	],
	[  # 元婴期及以上
		[
			{KEY_KIND: KIND_HERB, KEY_NAME: "万年灵芝", KEY_QUALITY: 4, KEY_AMOUNT: 1},
			{KEY_KIND: KIND_ORE, KEY_NAME: "太初矿", KEY_QUALITY: 4, KEY_AMOUNT: 1},
		],
		[
			{KEY_KIND: KIND_HERB, KEY_NAME: "不死草", KEY_QUALITY: 4, KEY_AMOUNT: 1},
			{KEY_KIND: KIND_ORE, KEY_NAME: "混沌石", KEY_QUALITY: 4, KEY_AMOUNT: 1},
		],
	],
]


## 生成采集节点的载荷（确定性——同 map_id + 同境界恒得同一批）。[br]
## [br][param p_map_id] 地图 ID（哈希参与变体选择——不同地图产出有别）。[br]
## [param p_player_realm] 玩家境界（越界夹到最近档，不崩溃）。[br]
## [br][b]返回[/b]：规范化条目数组（见 [method normalize]）；空数组表示该档无配置。[br]
static func payload_for(p_map_id: StringName, p_player_realm: int) -> Array:
	var variants: Array = POOLS_BY_REALM[
			clampi(p_player_realm - 1, 0, POOLS_BY_REALM.size() - 1)]
	if variants.is_empty():
		return []
	var pick: int = absi(hash(p_map_id)) % variants.size()
	return normalize(variants[pick])


## 规范化条目数组——补齐 [constant KEY_SLOT]（下标）、夹品质到 1-4、负数归零。[br]
## [br][b]不丢弃非法条目[/b]：非字典元素跳过，其余字段缺失时取安全默认
## （名称空串、类别灵草、品质 1、数量 0）——载荷坏了也不该让节点生成崩溃。[br]
static func normalize(p_entries: Array) -> Array:
	var out: Array = []
	for i: int in p_entries.size():
		var raw: Variant = p_entries[i]
		if not (raw is Dictionary):
			continue
		var entry: Dictionary = raw
		out.append({
			KEY_SLOT: int(entry.get(KEY_SLOT, i)),
			KEY_NAME: str(entry.get(KEY_NAME, "")),
			KEY_KIND: StringName(entry.get(KEY_KIND, KIND_HERB)),
			KEY_QUALITY: clampi(int(entry.get(KEY_QUALITY, 1)), 1, 4),
			KEY_AMOUNT: maxi(int(entry.get(KEY_AMOUNT, 0)), 0),
		})
	return out


## 类别 → 中文名（未知类别返回「材料」，不臆造具体名）。
static func kind_name(p_kind: StringName) -> String:
	return str(KIND_NAMES.get(p_kind, "材料"))


## 品质档位 → 中文名（未知档位返回空串，不臆造）。
static func quality_name(p_quality: int) -> String:
	return str(QUALITY_NAMES.get(p_quality, ""))
