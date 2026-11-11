extends RefCounted
## CombatRewardRoller —— 战斗奖励的掷骰与发放（[b]唯一实现[/b]）。[br]
## [br][b]职责[/b]：把探索侧定档的掉落配置（[code]{lingshi_min, lingshi_max,
## cultivation, cards}[/code]）变成「本场实得」，并真正写进玩家数据——[br]
##   1. [method roll]：灵石按区间掷骰；卡牌按 [code]chance[/code] 掷骰；[br]
##   2. [method apply]：灵石 → [code]ResourceSystem.add_resource[/code]、
##      修为 → [code]CultivationSystem.gain_cultivation[/code]、
##      命中卡牌 → [code]CardSystem.create_instance[/code] +
##      [code]GSM.add_card_to_collection[/code]。[br]
## [br][b]为什么单独成文件[/b]：掷骰口径（区间端点、概率边界、抽取顺序、RNG 所有权）
## 必须只有一份。散在 [code]CombatSystem[/code] 与探索侧就会两处各写一套，改一处漏一处
## （同 [code]combat_turn_economy.gd[/code] / [code]combat_hp_carryover.gd[/code] 先例）。[br]
## [br][b]RNG 所有权[/b]：本模块[b]不自建[/b] RNG——[param p_rng] 由调用方持有并注入
## （生产为 [code]CombatSystem._reward_rng[/code]，测试可注入固定种子的实例）。
## 种子口径与「哪些调用会消耗随机数」由调用方文档化（见
## [method CombatSystem.set_reward_rng_seed]）。[br]
## [br][b]抽取顺序[/b]（[b]口径的一部分，改动即破坏可复现性[/b]）：[br]
##   1. 灵石区间掷一次 [code]randi_range(min, max)[/code]（仅当配置了区间）；[br]
##   2. 按 [code]cards[/code] 配置顺序逐张掷 [code]randf() < chance[/code]。[br]
##   [code]chance >= 1[/code] 恒命中、[code]chance <= 0[/code] 恒未命中，
##   这两种[b]不消耗[/b]随机数（概率是确定的，抽不抽都一样）。[br]
## [br][b]缺 [code]chance[/code] 的条目按 1.0 处理[/b]：探索经济域/旧配置的
## [code]cards[/code] 只是卡牌清单（没有概率），「列出来就给」是其既有语义；
## 有 [code]chance[/code] 才表示「按概率抽」。[br]
## [br][b]发放失败可见[/b]：系统缺失 / 模板未知 / 收藏写入被拒一律记进
## [code]cards_failed[/code]（带原因），灵石与修为以 [code]*_granted[/code] 布尔暴露——
## 结算界面据此区分「有奖励」与「奖励没到账」，不把失败静默成 0。[br]
## [br]来源: GDD combat-system.md §9 战斗奖励结算、GDD ai-system.md §2 rewards、
## ADR-0019（资源写入）、ADR-0006（卡牌实例 + 收藏入库）、DEBT-EUI-006-4。

## 卡牌实例序列化（收藏条目形状的唯一实现）。
const CardSerializer := preload("res://src/core/card_system/card_serializer.gd")

## 稀有度枚举值 → 中文（[code]CardTemplate.Rarity[/code]：1=白 … 5=暗金）。
const RARITY_NAMES: Dictionary = {1: "白", 2: "蓝", 3: "紫", 4: "金", 5: "暗金"}

## 卡牌类型枚举值 → 中文（[code]CardTemplate.CardType[/code]）。
const TYPE_NAMES: Dictionary = {0: "角色", 1: "功法", 2: "法宝", 3: "阵法", 4: "丹药", 5: "符箓"}

## 缺省概率——配置里没有 [code]chance[/code] 时的口径（见类文档）。
const DEFAULT_CHANCE: float = 1.0


## 掷骰——把掉落配置折成「本场掷出的结果」（[b]尚未发放[/b]）。[br]
## [br][param p_config] 掉落配置（[code]{lingshi_min, lingshi_max, lingshi,
## cultivation, cards} [/code]；非字典按空配置处理）。[br]
## [param p_rng] 调用方持有的 RNG（本方法会推进它——顺序见类文档）。[br]
## [br][b]返回[/b]：[code]{lingshi, lingshi_min, lingshi_max, lingshi_rolled,
## cultivation, cards: [{card_id, chance}], cards_missed: [{card_id, chance}]}[/code]。[br]
##   · 配置了区间 → [code]lingshi_min/max[/code] 为本次区间，[code]lingshi[/code] 为掷出的整数；[br]
##   · 只有定值 → 三项相同、[code]lingshi_rolled = false[/code]（没有随机性）；[br]
##   · 卡牌命中/未命中分别落进 [code]cards[/code] / [code]cards_missed[/code]。[br]
static func roll(p_config: Dictionary, p_rng: RandomNumberGenerator) -> Dictionary:
	var result: Dictionary = {
		"lingshi": 0, "lingshi_min": 0, "lingshi_max": 0, "lingshi_rolled": false,
		"cultivation": 0, "cards": [], "cards_missed": [],
	}
	if p_config == null or p_config.is_empty():
		return result
	var has_range: bool = p_config.has("lingshi_min") and p_config.has("lingshi_max")
	var lo: int = maxi(int(p_config.get("lingshi_min", 0)), 0)
	var hi: int = maxi(int(p_config.get("lingshi_max", 0)), 0)
	if has_range and lo > hi:
		var swap: int = lo
		lo = hi
		hi = swap
	# 区间收成一点同样是定值——没有随机性，也不消耗随机数（同「确定性概率不掷骰」）
	if not has_range or (lo == 0 and hi == 0) or lo == hi:
		var fixed: int = lo if has_range else maxi(int(p_config.get("lingshi", 0)), 0)
		result["lingshi"] = fixed
		result["lingshi_min"] = fixed
		result["lingshi_max"] = fixed
	else:
		result["lingshi_min"] = lo
		result["lingshi_max"] = hi
		result["lingshi"] = p_rng.randi_range(lo, hi) if p_rng != null else lo
		result["lingshi_rolled"] = true
	result["cultivation"] = maxi(int(p_config.get("cultivation", 0)), 0)
	var raw_cards: Variant = p_config.get("cards", [])
	if raw_cards is Array:
		for raw: Variant in raw_cards:
			var entry: Dictionary = _parse_card(raw)
			if str(entry.get("card_id", "")).is_empty():
				continue
			if _roll_card(entry, p_rng):
				(result["cards"] as Array).append(entry)
			else:
				(result["cards_missed"] as Array).append(entry)
	return result


## 发放掷骰结果——真正写进玩家数据。[br]
## [br][param p_rolled] [method roll] 的产出（也接受只带 [code]lingshi /
## cultivation / cards[/code] 的旧形状——缺 [code]chance[/code] 的卡牌按恒命中处理）。[br]
## [param p_resource_system] [code]ResourceSystem[/code]（可空——缺失时灵石不入账）。[br]
## [param p_cultivation_system] [code]CultivationSystem[/code]（可空）。[br]
## [param p_card_system] [code]CardSystem[/code]（可空——缺失时卡牌不入收藏）。[br]
## [param p_gsm] [code]GameStateManager[/code]（收藏写入入口）。[br]
## [br][b]返回[/b]：[code]{lingshi_granted, cultivation_granted,
## cards: [<到手卡牌（含 name/rarity/school）>], cards_failed: [{card_id, reason}]}[/code]。[br]
## [br][b]幂等边界[/b]：本方法[b]本身不幂等[/b]——每次调用都会再发一次；
## 「同一场只结算一次」由调用方（[method CombatSystem.battle_end]）保证映射。[br]
static func apply(p_rolled: Dictionary, p_resource_system: Node,
		p_cultivation_system: Node, p_card_system: Node,
		p_gsm: Node) -> Dictionary:
	var report: Dictionary = {
		"lingshi_granted": true, "cultivation_granted": true,
		"cards": [], "cards_failed": [],
	}
	var lingshi: int = maxi(int(p_rolled.get("lingshi", 0)), 0)
	if lingshi > 0:
		report["lingshi_granted"] = _grant_lingshi(p_resource_system, lingshi)
	var cultivation: int = maxi(int(p_rolled.get("cultivation", 0)), 0)
	if cultivation > 0:
		report["cultivation_granted"] = _grant_cultivation(
				p_cultivation_system, cultivation)
	var raw_cards: Variant = p_rolled.get("cards", [])
	if raw_cards is Array:
		for raw: Variant in raw_cards:
			var entry: Dictionary = _parse_card(raw)
			if str(entry.get("card_id", "")).is_empty():
				continue
			_grant_card(entry, p_card_system, p_gsm, report)
	return report


# === 内部：掷骰 ================================================================

## 卡牌条目规范化——字符串 / 字典两种写法统一成 [code]{card_id, chance}[/code]。
static func _parse_card(p_raw: Variant) -> Dictionary:
	if p_raw is String or p_raw is StringName:
		return {"card_id": str(p_raw), "chance": DEFAULT_CHANCE}
	if not (p_raw is Dictionary):
		return {}
	var source: Dictionary = p_raw
	var card_id: String = str(source.get("card_id", source.get("template_id", "")))
	if card_id.is_empty():
		return {}
	var raw_chance: Variant = source.get("chance")
	if raw_chance == null:
		return {"card_id": card_id, "chance": DEFAULT_CHANCE}
	return {"card_id": card_id, "chance": clampf(float(raw_chance), 0.0, 1.0)}


## 单张卡牌掷骰——概率边界不消耗随机数（见类文档「抽取顺序」）。
static func _roll_card(p_entry: Dictionary, p_rng: RandomNumberGenerator) -> bool:
	var chance: float = float(p_entry.get("chance", DEFAULT_CHANCE))
	if chance >= 1.0:
		return true
	if chance <= 0.0:
		return false
	if p_rng == null:
		return false
	return p_rng.randf() < chance


# === 内部：发放 ================================================================

## 灵石入账——系统缺失或拒绝时返回 false（调用方据此标注「未能发放」）。
static func _grant_lingshi(p_resource_system: Node, p_amount: int) -> bool:
	if p_resource_system == null or not p_resource_system.has_method(&"add_resource"):
		return false
	return bool(p_resource_system.call(&"add_resource", &"ling_shi", p_amount))


## 修为入账——走 [code]gain_cultivation[/code]（来源标记 [code]battle_victory[/code]）。
static func _grant_cultivation(p_cultivation_system: Node, p_amount: int) -> bool:
	if p_cultivation_system == null \
			or not p_cultivation_system.has_method(&"gain_cultivation"):
		return false
	p_cultivation_system.call(&"gain_cultivation", p_amount, "battle_victory")
	return true


## 卡牌入收藏——实例化 + 序列化 + GSM 入库；失败记原因。[br]
## [br][b]先查模板再实例化[/b]：[code]create_instance[/code] 对未知模板会
## [code]push_error[/code]，而「配置了一张不存在的卡」是数据问题、不是崩溃点——
## 查表后记为发放失败，让结算界面显示「未到手」而不是刷红字。[br]
static func _grant_card(p_entry: Dictionary, p_card_system: Node, p_gsm: Node,
		p_report: Dictionary) -> void:
	var card_id: String = str(p_entry.get("card_id", ""))
	var template: Variant = null
	if p_card_system != null and p_card_system.has_method(&"get_template"):
		template = p_card_system.call(&"get_template", StringName(card_id))
	if template == null:
		_fail_card(p_report, card_id, "未知卡牌")
		return
	if p_card_system == null or not p_card_system.has_method(&"create_instance"):
		_fail_card(p_report, card_id, "卡牌系统不可用")
		return
	var inst: Variant = p_card_system.call(&"create_instance", StringName(card_id))
	if inst == null:
		_fail_card(p_report, card_id, "实例创建失败")
		return
	if p_gsm == null or not p_gsm.has_method(&"add_card_to_collection"):
		_fail_card(p_report, card_id, "收藏系统不可用")
		return
	var entry: Dictionary = CardSerializer.serialize_instance(inst)
	entry["template_id"] = card_id
	if not bool(p_gsm.call(&"add_card_to_collection", entry)):
		_fail_card(p_report, card_id, "收藏写入被拒")
		return
	(p_report["cards"] as Array).append(_enrich(card_id, template, p_entry))


## 发放失败记入报告（去重不做——同一张卡两个配置项是两个独立失败条目）。
static func _fail_card(p_report: Dictionary, p_card_id: String, p_reason: String) -> void:
	(p_report["cards_failed"] as Array).append(
			{"card_id": p_card_id, "reason": p_reason})


## 为条目补齐展示字段（[code]name / rarity / rarity_id / school[/code]）。[br]
## [br][b]用途[/b]：未命中的卡牌没走发放路径，结算界面仍要显示「没抽到什么」——
## 名称取自模板（模板缺失时回退卡牌 ID，不臆造）。原地修改传入的条目数组。[br]
## [param p_entries] 条目数组（元素含 [code]card_id[/code]，可含 [code]reason[/code]）。[br]
## [param p_card_system] [code]CardSystem[/code]（可空——缺失时只补默认展示字段）。
static func enrich(p_entries: Array, p_card_system: Node) -> void:
	for entry: Variant in p_entries:
		if not (entry is Dictionary):
			continue
		var target: Dictionary = entry
		var card_id: String = str(target.get("card_id", ""))
		if card_id.is_empty() or target.has("name"):
			continue
		var template: Variant = null
		if p_card_system != null and p_card_system.has_method(&"get_template"):
			template = p_card_system.call(&"get_template", StringName(card_id))
		target.merge(_enrich(card_id, template, target), true)


## 卡牌展示信息——模板可读时带名称/稀有度/类型，否则回退卡牌 ID。[br]
## [br][code]rarity[/code] 写中文名（与 [code]SettlementRules.loot_option_label[/code]
## 的展示口径一致）、[code]rarity_id[/code] 保留枚举值供其他消费者判档。[br]
static func _enrich(p_card_id: String, p_template: Variant,
		p_entry: Dictionary) -> Dictionary:
	var rarity_id: int = clampi(int(p_template.get("rarity")), 1, 5) \
			if p_template != null else 1
	var type_id: int = int(p_template.get("type")) if p_template != null else -1
	var name: String = str(p_template.get("name")) if p_template != null else ""
	return {
		"card_id": p_card_id,
		"name": name if not name.is_empty() else p_card_id,
		"rarity": str(RARITY_NAMES.get(rarity_id, "")),
		"rarity_id": rarity_id,
		"school": str(TYPE_NAMES.get(type_id, "")),
		"chance": float(p_entry.get("chance", DEFAULT_CHANCE)),
	}
