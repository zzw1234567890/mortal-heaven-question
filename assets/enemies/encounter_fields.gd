class_name EncounterFields
extends RefCounted
## EncounterFields —— 探索节点「遭遇数据」的唯一口径（生成 / 预览 / 开战三方共用）。[br]
## [br][b]为什么需要[/b]：节点遭遇此前只有 [code]enemy_roster[/code] 一个字段——
## 生成器写它、弹窗读它、开战上下文再从它反推模板 ID / 等级 / 掉落。反推口径
## 分散在三处，且「没配置」被表达成 null / 空数组 / 0 的混合形态。本模块把
## 五键契约（[code]encounter_id / display_name / enemy_template_ids /
## enemy_level / rewards[/code]）收成一处，写方与读方都走同一套规范化。[br]
## [br][b]顶层与子字典[/b]：节点详情同时写 [code]encounter[/code] 子字典与顶层
## [code]enemy_level[/code] / [code]rewards[/code]——顶层是
## [code]CombatLaunchContext[/code] 的既有契约，子字典是弹窗预览的聚合载体。
## 读取时 [method of_detail] 保证两者同值：顶层非缺省优先，其余由子字典补齐。[br]
## [br][b]缺省语义[/b]（不用 null 混用）：[br]
##   - [code]enemy_level = 0[/code]：节点未指定等级，交由名册最高境界推定；
##     仍推不出就是「未知」，展示层不得臆造境界名。[br]
##   - [code]rewards = {}[/code]：本节点没有掉落配置（不是「掉落为 0」）。[br]
##   - [code]enemy_template_ids = [][/code]：没有显式模板列表，交由名册派生。[br]
##   - [code]encounter_id[/code] 永不为空——节点生成时为空则按节点 ID 兜底
##     （[code]node_101[/code]），保证每场遭遇可被追踪。[br]
## [br][b]掉落键名[/b]：统一为战斗结算口径 [code]{lingshi, cultivation, cards}[/code]。
## 探索经济域的历史写法 [code]ling_shi[/code] 在读取时兼容（同一事实不出现两个
## 键名——写入方只写 [code]lingshi[/code]）。[br]
## [br]来源: ADR-0014 §决策 2/3、ADR-0017 §关键接口 RewardConfig、
## GDD exploration-system.md §3 步骤⑥、GDD ai-system.md §2 rewards。

## 节点详情里的子字典键。
const KEY_ENCOUNTER: String = "encounter"
## 子字典五键（顶层 [code]enemy_level[/code] / [code]rewards[/code] 复用同名键）。
const KEY_ENCOUNTER_ID: String = "encounter_id"
const KEY_DISPLAY_NAME: String = "display_name"
const KEY_TEMPLATE_IDS: String = "enemy_template_ids"
const KEY_ENEMY_LEVEL: String = "enemy_level"
const KEY_REWARDS: String = "rewards"

## 名册条目字段读取（运行时对象 / 预览字典双形态）。
const RosterEntries := preload("res://assets/enemies/roster_entries.gd")

## 敌方等级缺省值——「节点未指定」，不是第 0 境界。
const LEVEL_UNSPECIFIED: int = 0


## 构造一份规范化的遭遇配置（生成器写入节点时调用）。[br]
## [br][param p_encounter_id] 遭遇唯一标识（空串时按节点 ID 兜底，见 [method of_detail]）。[br]
## [param p_display_name] 展示名（战斗标题 / 弹窗预览用，可空——读取方回退节点描述）。[br]
## [param p_template_ids] 敌方模板 ID 列表（保留重复：散修 ×2 就是两名敌人）。[br]
## [param p_enemy_level] 基准境界（≤0 = 未指定）。[br]
## [param p_rewards] 掉落（非字典/空 = 无掉落配置）。
static func make(p_encounter_id: String, p_display_name: String,
		p_template_ids: Array, p_enemy_level: int, p_rewards: Variant) -> Dictionary:
	return {
		KEY_ENCOUNTER_ID: p_encounter_id,
		KEY_DISPLAY_NAME: p_display_name,
		KEY_TEMPLATE_IDS: _ids(p_template_ids),
		KEY_ENEMY_LEVEL: maxi(p_enemy_level, LEVEL_UNSPECIFIED),
		KEY_REWARDS: sanitize_rewards(p_rewards),
	}


## 从节点详情读出规范化遭遇配置——子字典 + 顶层字段合并，缺键补明确缺省。[br]
## [br][b]合并规则[/b]：顶层 [code]enemy_level[/code] 大于 0、顶层 [code]rewards[/code]
## 非空时优先（[code]CombatLaunchContext[/code] 的既有读取面）；否则用子字典。
## 展示名缺失时回退节点 [code]description[/code] / [code]label[/code]。[br]
## [br][param p_detail] 节点详情。[br]
## [param p_node_id] 节点 ID（≥0 时用于 encounter_id 兜底；-1 = 不兜底）。
static func of_detail(p_detail: Dictionary, p_node_id: int = -1) -> Dictionary:
	var result: Dictionary = make("", "", [], LEVEL_UNSPECIFIED, {})
	var raw: Variant = p_detail.get(KEY_ENCOUNTER, {})
	if raw is Dictionary:
		var source: Dictionary = raw
		result[KEY_ENCOUNTER_ID] = str(source.get(KEY_ENCOUNTER_ID, ""))
		result[KEY_DISPLAY_NAME] = str(source.get(KEY_DISPLAY_NAME, ""))
		result[KEY_TEMPLATE_IDS] = _ids(source.get(KEY_TEMPLATE_IDS, []))
		result[KEY_ENEMY_LEVEL] = maxi(int(source.get(KEY_ENEMY_LEVEL, LEVEL_UNSPECIFIED)),
				LEVEL_UNSPECIFIED)
		result[KEY_REWARDS] = sanitize_rewards(source.get(KEY_REWARDS, {}))
	# 顶层字段非缺省时优先——生成器两者都写，手写详情可能只给一侧。
	var top_level: int = int(p_detail.get(KEY_ENEMY_LEVEL, LEVEL_UNSPECIFIED))
	if top_level > 0:
		result[KEY_ENEMY_LEVEL] = top_level
	var top_rewards: Variant = p_detail.get(KEY_REWARDS, {})
	if top_rewards is Dictionary and not (top_rewards as Dictionary).is_empty():
		result[KEY_REWARDS] = sanitize_rewards(top_rewards)
	if str(result[KEY_DISPLAY_NAME]).is_empty():
		result[KEY_DISPLAY_NAME] = detail_label(p_detail)
	if str(result[KEY_ENCOUNTER_ID]).is_empty() and p_node_id >= 0:
		result[KEY_ENCOUNTER_ID] = "node_%d" % p_node_id
	return result


## 从渲染快照取节点遭遇——[code]snapshot.nodes[node_id][/code] 经 [method of_detail]
## 规范化；快照/节点缺失或类型不符时返回空详情契约（不臆造敌人）。[br]
## [br][b]为什么放在这里[/b]：弹窗与开战上下文都要「按节点 ID 读同一份遭遇」，
## 读取入口只留一处，两边不会各自写一套兜底。
static func of_snapshot(p_snapshot: Dictionary, p_node_id: int) -> Dictionary:
	var nodes: Variant = p_snapshot.get("nodes", {})
	if not (nodes is Dictionary):
		return of_detail({}, p_node_id)
	var detail: Variant = (nodes as Dictionary).get(p_node_id, {})
	return of_detail(detail if detail is Dictionary else {}, p_node_id)


## 名册载荷拷贝（非 Array 退化为空——弹窗正文与开战上下文共用同一份快照）。
static func roster_copy(p_raw: Variant) -> Array:
	return (p_raw as Array).duplicate(true) if p_raw is Array else []


## 敌方模板 ID——显式配置优先，否则从名册条目派生（派生路径按模板去重）。[br]
## [br][b]统一成 StringName[/b]：两条路径的产物必须同型——
## [code]AISystem.create_enemy_roster[/code] 按 StringName 查模板注册表，
## 混入 String 会变成「模板不存在」。[br]
## [br][b]显式列表保留重复[/b]：「散修 ×2」就是两名敌人，去重会少打一个。
static func template_ids(p_encounter: Dictionary, p_roster: Array) -> Array:
	var explicit: Variant = p_encounter.get(KEY_TEMPLATE_IDS, [])
	if explicit is Array:
		var listed: Array = []
		for raw: Variant in explicit:
			var tid: StringName = StringName(str(raw))
			if tid != &"":
				listed.append(tid)
		if not listed.is_empty():
			return listed
	var derived: Array = []
	for entry: Variant in p_roster:
		var tid: StringName = RosterEntries.template_id(entry)
		if tid != &"" and not derived.has(tid):
			derived.append(tid)
	return derived


## 敌方基准等级——显式配置优先，否则取名册条目的最大境界。[br]
## [br][b]返回 0 = 未知[/b]（不臆造境界）：展示层据此省略境界行。
static func enemy_level(p_encounter: Dictionary, p_roster: Array,
		p_lookup: Callable) -> int:
	var explicit: int = int(p_encounter.get(KEY_ENEMY_LEVEL, LEVEL_UNSPECIFIED))
	if explicit > 0:
		return explicit
	var level: int = 0
	for entry: Variant in p_roster:
		level = maxi(level, RosterEntries.realm(entry, p_lookup))
	return level


## 掉落——显式配置 > 名册条目自带的 [code]rewards[/code] > 模板 reward_config 聚合。[br]
## [br][b]灵石取区间中值[/b]：节点生成时不掷骰，保证同节点重复进入口径稳定。[br]
## [br][b]全零归空字典[/b]：三者都没配时返回 [code]{}[/code]（「本节点无掉落配置」），
## 而不是 [code]{lingshi: 0, cultivation: 0, cards: []}[/code]——后者会被下游当成
## 「有配置但全是 0」。[br]
static func rewards(p_encounter: Dictionary, p_roster: Array,
		p_lookup: Callable) -> Dictionary:
	var explicit: Dictionary = sanitize_rewards(p_encounter.get(KEY_REWARDS, {}))
	if not explicit.is_empty():
		return explicit
	var lingshi: int = 0
	var cultivation: int = 0
	var cards: Array = []
	for entry: Variant in p_roster:
		var entry_rewards: Variant = RosterEntries.field(entry, KEY_REWARDS)
		if entry_rewards is Dictionary:
			lingshi += int((entry_rewards as Dictionary).get("lingshi",
					(entry_rewards as Dictionary).get("ling_shi", 0)))
			cultivation += int((entry_rewards as Dictionary).get("cultivation", 0))
			_append_cards(cards, (entry_rewards as Dictionary).get("cards", []))
			continue
		var config: Variant = RosterEntries.reward_config(entry, p_lookup)
		if config == null:
			continue
		lingshi += int(round((float(int(config.get("ling_shi_min")))
				+ float(int(config.get("ling_shi_max")))) * 0.5))
		cultivation += int(config.get("cultivation_reward"))
		_append_cards(cards, config.get("card_drops"))
	if lingshi <= 0 and cultivation <= 0 and cards.is_empty():
		return {}
	return {"lingshi": lingshi, "cultivation": cultivation, "cards": cards}


## 掉落载荷规范化——非字典/全零 → [code]{}[/code]；否则补齐三键。[br]
## [code]ling_shi[/code] 是探索经济域的旧写法，读取时兼容，写出统一为 [code]lingshi[/code]。
static func sanitize_rewards(p_raw: Variant) -> Dictionary:
	if not (p_raw is Dictionary):
		return {}
	var source: Dictionary = p_raw
	var lingshi: int = int(source.get("lingshi", source.get("ling_shi", 0)))
	var cultivation: int = int(source.get("cultivation", 0))
	var cards: Array = []
	_append_cards(cards, source.get("cards", []))
	if lingshi <= 0 and cultivation <= 0 and cards.is_empty():
		return {}
	return {"lingshi": lingshi, "cultivation": cultivation, "cards": cards}


## 名册派生的模板 ID 去重列表（生成器写节点时的预览口径）。[br]
## 与 [method template_ids] 的派生分支同源——生成器只调用本入口，避免传空 encounter。
static func template_ids_of(p_roster: Array) -> Array:
	return template_ids({}, p_roster)


## 名册派生的敌人名称——单个敌人名（不带数量）；无名称时回退「战斗 / 精英」。[br]
## [br][b]用途[/b]：遭遇的 [code]display_name[/code]（战斗标题）。数量由
## [method label_of] 与弹窗正文各自负责，别让标题里出现「×2」。[br]
## [br][b]不臆造[/b]：名册条目既无名称也无模板 ID 时用类型名，而不是空白。
static func name_of(p_roster: Array, p_is_elite: bool) -> String:
	var fallback: String = "精英" if p_is_elite else "战斗"
	for entry: Variant in p_roster:
		var name: String = str(RosterEntries.field(entry, "name"))
		if name.is_empty():
			name = str(RosterEntries.field(entry, "display_name"))
		if name.is_empty():
			name = str(RosterEntries.template_id(entry))
		if not name.is_empty():
			return name
	return fallback


## 节点标签——「散修 ×2」；名册为空时退化为「战斗 ×0」→ 类型名。[br]
## [br]节点图在节点下方绘制的文字，需要数量才有信息量（[method name_of] 不带数量）。
static func label_of(p_roster: Array, p_is_elite: bool) -> String:
	var name: String = name_of(p_roster, p_is_elite)
	if p_roster.is_empty():
		return name
	return "%s ×%d" % [name, p_roster.size()]


## 节点展示名——[code]encounter.display_name[/code] > description > label。
static func detail_label(p_detail: Dictionary) -> String:
	for key: String in ["description", "label"]:
		var text: String = str(p_detail.get(key, ""))
		if not text.is_empty():
			return text
	return ""


## 模板 ID 列表规范化（丢弃空串；去重语义由调用方决定）。
static func _ids(p_raw: Variant) -> Array:
	var ids: Array = []
	if not (p_raw is Array):
		return ids
	for raw: Variant in p_raw:
		var text: String = str(raw)
		if not text.is_empty():
			ids.append(text)
	return ids


## 追加卡牌掉落条目（字典深拷贝；非字典忽略）。
static func _append_cards(p_cards: Array, p_source: Variant) -> void:
	if not (p_source is Array):
		return
	for item: Variant in p_source:
		if item is Dictionary:
			p_cards.append((item as Dictionary).duplicate(true))
