extends RefCounted
## ExplorationMapGate —— 地图解锁门槛的[b]唯一判定与文案[/b]（纯函数）。[br]
## [br][b]为什么需要[/b]：本轮之前「这张图能不能进」只在
## [code]ExplorationMapList[/code] 里就地写过一行
## [code]p_player_realm >= unlock_realm[/code]——于是三件事各缺一块：[br]
##   1. [b]条件只有境界[/b]：探明表里没有任何「需先通关哪张图」的落点，而
##      GDD §8 明写「苍玄古战场是唯一序列锁定的地图——必须在此触发剧情才能
##      解锁碎星群岛」，这条规则在代码里无处表达；[br]
##   2. [b]文案只有数字[/b]：面向玩家的是「需3境界」而不是「需筑基期」；[br]
##   3. [b]判定散落[/b]：卡片灰显、tooltip、点击分流三处各自读字段，加一条
##      条件就要改三处。[br]
## [br][b]本模块的定位[/b]：把「达成条件没有 / 还差什么 / 缺的那一条怎么念」
## 收成一次求值（[method evaluate]），消费方（[ExplorationMapList] 组装载荷 →
## [MapCard] 灰显 → [MapSelectScreen] 点击提示）全部只读结果，不再各判一遍。[br]
## [br][b]纯函数、无状态[/b]：不读 GSM、不写任何东西——玩家的已通关集合由调用方
## 读好后以 [code]{地图ID: bool}[/code] 传入，故 GUT 直调可测（先例
## [code]exploration_ap_rules.gd[/code]）。[br]
## [br][b]为什么是「每次重算」而不是「解锁时写一次存档[/b]」：解锁态是本模块对
## （境界 × 已通关集合）的纯函数求值——读档后重算即得，不需要一次性写入，也就
## 不会出现「存档里的解锁标记与玩家实际进度不一致」这一类漂移（任务要求的
## 「读档后重算，不依赖一次性写入」由本设计保证：本模块[b]没有任何写入路径[/b]）。[br]
## [br][b]缺省语义[/b]：未登记地图按最保守值处理（门槛 [constant FALLBACK_REALM]、
## 无前置）——不静默借用别的地图的解锁规则。[br]
##
## 来源: design/gdd/exploration-system.md §1 地图选择 / §8 地图初始解锁顺序 /
## §公式 1 地图解锁判定、design/gdd/exploration-ui-system.md §1（灰色锁 + 悬停
## 显示所需境界）、ADR-0014 §get_map_list 契约。

## 地图配置目录（探明表——[code]unlock_realm[/code] / [code]unlock_after_clear[/code]
## 的唯一来源）。
const CatalogScript := preload("res://src/feature/exploration/exploration_map_catalog.gd")

## 玩家境界缺省值（GSM 不可用 / 未登记地图的门槛兜底——炼气，最保守）。
const FALLBACK_REALM: int = 1

## 境界等级 → 中文名（1 炼气 … 5 化神）。[br]
## [br][b]与 [code]exploration_craft_list.gd[/code] 的 [code]REALM_NAMES[/code]
## 同源口径[/b]（都是「等级 → 中文短名」），差异只在拼装后缀——那边拼「期」
## 得「筑基期」，本模块拼「需…期」得「需筑基期」。
const REALM_NAMES: Dictionary = {
	1: "炼气", 2: "筑基", 3: "金丹", 4: "元婴", 5: "化神",
}

## 条件文案前缀 / 后缀——「需」+ 境界名 + 「期」=「需筑基期」。
const TEXT_NEED_PREFIX: String = "需"
const TEXT_REALM_SUFFIX: String = "期"

## 「需通关[X]」的整句前缀（GDD §8 剧情锁的读法——「需」与「通关」同属一句，
## 不给两条条件各留一半，免得拼出「需筑基期 · 通关青云剑宗」这种缺字的并排）。
const TEXT_CLEAR_PREFIX: String = "需通关"

## 越界境界名的兜底词——不显示「需0期」这种读不通的字。
const TEXT_REALM_UNKNOWN: String = "更高境界"

## 多条条件的分隔符（同时缺境界与前置时并排展示）。
const TEXT_CONDITION_SEPARATOR: String = " · "


## 求值一张地图的解锁态——[b]本模块的唯一入口[/b]。[br]
## [br][param p_map_id] 地图 ID（历史写法经探明表别名归一到规范写法）。[br]
## [param p_player_realm] 玩家当前境界。[br]
## [param p_cleared] [code]{地图ID: 是否已通关}[/code]——读档后现取，
## 本模块不查 GSM（纯函数）。[br]
## [br][b]返回[/b]：[br]
##   · [code]map_id[/code] 规范写法；[br]
##   · [code]is_unlocked[/code] 两项条件是否[b]全部[/b]达成；[br]
##   · [code]realm_ok[/code] / [code]realm_requirement[/code] 境界条件与门槛；[br]
##   · [code]unlock_after_clear[/code] 前置地图 ID（无前置为 [code]&""[/code]）；[br]
##   · [code]prerequisite_name[/code] 前置地图中文名（无前置为空串）；[br]
##   · [code]prerequisite_cleared[/code] 前置是否已通关（无前置恒 [code]true[/code]
##     ——「没有前置」等于「前置已满足」，免得消费方分两种缺省判）；[br]
##   · [code]locked_hint[/code] 未解锁时的中文条件文案（已解锁为空串）。[br]
static func evaluate(p_map_id: StringName, p_player_realm: int,
		p_cleared: Dictionary) -> Dictionary:
	var map_id: StringName = CatalogScript.canonical_id(p_map_id)
	var config: Dictionary = registered_config(map_id)
	var requirement: int = int(config.get("unlock_realm", FALLBACK_REALM))
	var realm_ok: bool = int(p_player_realm) >= requirement

	var prerequisite: StringName = prerequisite_of(map_id)
	var prerequisite_ok: bool = prerequisite.is_empty() \
			or bool(p_cleared.get(prerequisite, false))

	var result: Dictionary = {
		"map_id": map_id,
		"is_unlocked": realm_ok and prerequisite_ok,
		"realm_ok": realm_ok,
		"realm_requirement": requirement,
		"unlock_after_clear": prerequisite,
		"prerequisite_name": map_display_name(prerequisite),
		"prerequisite_cleared": prerequisite_ok,
	}
	# 文案由同一份求值结果派生——「判定说没解锁、文案说不出缺什么」不可能发生。
	result["locked_hint"] = "" if bool(result["is_unlocked"]) \
			else locked_hint_of(result)
	return result


## 未解锁时的中文条件文案——缺哪条念哪条，两条都缺则并排。[br]
## [br][param p_result] [method evaluate] 的返回值（就地派生，不另传参数免得
## 判定与文案各拿一份入参而对不上）。[br]
## [br][b]返回[/b]：如「需筑基期」「需通关苍玄古战场」「需筑基期 · 需通关青云剑宗」；
## 已解锁时为空串。[br]
static func locked_hint_of(p_result: Dictionary) -> String:
	if bool(p_result.get("is_unlocked", false)):
		return ""
	var parts: Array = []
	if not bool(p_result.get("realm_ok", true)):
		parts.append(realm_text(int(p_result.get("realm_requirement", FALLBACK_REALM))))
	if not bool(p_result.get("prerequisite_cleared", true)):
		parts.append("%s%s" % [TEXT_CLEAR_PREFIX,
				str(p_result.get("prerequisite_name", ""))])
	return TEXT_CONDITION_SEPARATOR.join(parts)


## 境界门槛文案——「需筑基期」。[br]
## [br][b]越界等级[/b]（境界表里没有的等级）给「需更高境界」而不是「需0期」——
## 配置写错时玩家读到的是模糊但读得通的字，不是故障字样。[br]
static func realm_text(p_realm: int) -> String:
	var name: String = str(REALM_NAMES.get(int(p_realm), ""))
	if name.is_empty():
		return TEXT_NEED_PREFIX + TEXT_REALM_UNKNOWN
	return "%s%s%s" % [TEXT_NEED_PREFIX, name, TEXT_REALM_SUFFIX]


## 该地图的前置地图 ID（探明表 [code]unlock_after_clear[/code]；缺省 [code]&""[/code]）。[br]
## [br][b]返回值一律是规范写法[/b]：[code]config_for[/code] 会为未登记 ID 静默
## 兜底难度档位，前置若拼错就永远判不出「已通关」——故这里显式过
## [method ExplorationMapCatalog.canonical_id]，单测另有全表完整性断言。[br]
static func prerequisite_of(p_map_id: StringName) -> StringName:
	var declared: Variant = registered_config(
			CatalogScript.canonical_id(p_map_id)).get("unlock_after_clear", "")
	var raw: StringName = StringName(str(declared))
	if raw.is_empty():
		return &""
	return CatalogScript.canonical_id(raw)


## 地图中文名（登记名优先，未登记 / 空 ID 回退地图 ID 字面量——不臆造名字）。[br]
## [br][b]空 ID 返回空串[/b]：无前置时文案里不该出现任何占位字。
static func map_display_name(p_map_id: StringName) -> String:
	if p_map_id.is_empty():
		return ""
	var config: Dictionary = registered_config(p_map_id)
	var name: String = str(config.get("name", ""))
	return name if not name.is_empty() else str(p_map_id)


## 登记配置副本——未登记地图返回空字典（[code]MAPS.get[/code] 命中非字典时同样
## 按未登记处理，脏数据不至于让求值崩）。[br]
static func registered_config(p_map_id: StringName) -> Dictionary:
	var registered: Variant = CatalogScript.MAPS.get(
			CatalogScript.canonical_id(p_map_id))
	return (registered as Dictionary) if registered is Dictionary else {}
