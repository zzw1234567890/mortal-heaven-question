extends RefCounted
## TribulationRewardPool —— 渡劫金卡奖励的[b]选池与发放单点[/b]（GDD §6）。[br]
## [br][b]它做什么[/b]：渡劫成功后按 GDD 发金卡——普通 1 张、越阶 2 张；从卡牌模板池的
## [b]金档[/b]里随机取，实例化后进 [code]collection.owned_cards[/code]。[br]
## [br][b]为什么单独一处[/b]：「金卡」是哪一档稀有度、发几张、池子取不到时怎么降级——
## 这三件事只该有一份口径。散进结算子模块，将来天劫试炼（GDD §7 金卡降为蓝卡）
## 再写一遍就会与这里漂移。[br]
## [br][b]入库复用战斗侧 [code]CombatRewardRoller.apply[/code][/b]：「实例化 → 序列化 →
## GSM 入库」全库只有那一份实现，连失败原因的中文措辞（「未知卡牌」「收藏写入被拒」）
## 都在那边。本模块只负责「选出哪几张」，不重写入库，也不另造一套失败原因。[br]
## [br][b]金档只取 [code]Rarity.GOLD[/code](4)，不含暗金(5)[/b]：GDD §6 写的是「必定
## 获得1张金色稀有度卡牌」。暗金另有境界上限（[code]realm_table.max_darkgold[/code]），
## 顺手发暗金会绕开那道闸。[br]
## [br][b]允许同一次发两张同名金卡[/b]：GDD §6 承诺越阶「共2张」，池子里只有一张金卡时
## 「不重复取」会悄悄少发一张——卡牌实例本就允许同名多张，按张数兑现更贴合承诺。[br]
## [br][b]「全卡池金档随机」是 GDD 明示的过渡态[/b]：GDD §未决问题 2「金卡奖励的卡池
## 具体内容——需要为新境界定义『该境界专属金卡列表』而非全卡池随机」。本模块按过渡态
## 实现；卡牌系统给出分境界卡池后，只改 [method gold_ids] 一处。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：不读 GSM、不持节点——[param p_card_system] /
## [param p_gsm] 由调用方传进，本模块只做选取与转发。[br]
##
## 来源: design/gdd/tribulation-system.md §6 越阶渡劫 + §未决问题 2、
## ADR-0021 §_handle_tribulation_success、ADR-0006（卡牌实例 + 收藏入库）、
## 先例 src/feature/combat/combat_reward_roller.gd。

## 发放入口（卡牌进收藏的唯一实现——本模块不重写）。
const RewardRoller := preload("res://src/feature/combat/combat_reward_roller.gd")
## 稀有度枚举真理来源（不写魔数 4）。
const TemplateScript := preload("res://src/core/card_system/card_template.gd")

## 金档稀有度值（[code]CardTemplate.Rarity.GOLD[/code]）。
const GOLD_RARITY: int = TemplateScript.Rarity.GOLD

## 普通渡劫的金卡张数——GDD §6「渡劫成功后必定获得1张金色稀有度卡牌」。
const CARDS_NORMAL: int = 1
## 越阶渡劫的金卡张数——GDD §6「越阶渡劫额外+1张金卡（共2张）」。
const CARDS_CROSS_REALM: int = 2

## 奖励写进 [code]battle_ended[/code] 载荷的键名（[b]唯一出处[/b]——结算子模块与
## 结算屏文案两个消费方都引这里，不各写一份字符串）。
const KEY_PAYLOAD: String = "tribulation_rewards"
## 载荷内：到手卡数组（元素带 name/rarity/rarity_id/school 展示字段）。
const KEY_CARDS: String = "cards"
## 载荷内：未发放条目数组（元素带 name/reason）。
const KEY_FAILED: String = "cards_failed"

## 池空时的展示名——没有具体卡可指，但结算界面要说得出来是什么没发。
const NAME_GOLD_CARD: String = "渡劫金卡"
## 池空时的中文原因（[b]必写[/b]：玩家看到的不能是一句「有东西没发」）。
const REASON_EMPTY_POOL: String = "卡牌模板池中没有金档卡牌"

## 选牌用 RNG——本模块自持（与战斗侧的奖励 RNG 分开：渡劫金卡与战利品掷骰是两条
## 互不相干的随机流，共用一个实例会让「同一种子下的战利品」随渡劫次数漂移）。
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()


## 本场渡劫发几张金卡（GDD §6——唯一算式来源）。
static func card_count(p_is_cross_realm: bool) -> int:
	return CARDS_CROSS_REALM if p_is_cross_realm else CARDS_NORMAL


## 金档模板 ID 列表——渡劫奖励的候选池。[br]
## [br][param p_card_system] [code]CardSystem[/code]（可空 / 无模板注册表时返回空数组）。[br]
## [br][b]读注册表而不是新增 CardSystem 方法[/b]：[code]templates[/code] 是公开成员
## （[code]get_templates_by_type[/code] 的同一张表）。「按稀有度挑金卡」是渡劫奖励自己的
## 口径（[code]exploration_shop_inventory[/code] 的货架池同理自持），不必为它扩 Core 的接口。[br]
## [br][b]返回[/b]：卡牌 ID 数组（[StringName]）；注册表缺席或一张金档都没有时为空数组
## ——调用方据此走「未发放」降级，不臆造卡牌 ID。[br]
## [br][b]为什么不用 [code]Object.get(key, default)[/code] 的带默认值形式[/b]：
## [code]Resource[/code]（[CardTemplate] 的基类）的 [method Object.get] 只收一个参数，
## 传两个会在运行时抛「Expected 1 argument(s)」。取值一律先 [method Object.get] 再判空。
static func gold_ids(p_card_system: Node) -> Array:
	var ids: Array = []
	if p_card_system == null or not ("templates" in p_card_system):
		return ids
	var registry: Variant = p_card_system.get("templates")
	if not (registry is Dictionary):
		return ids
	for key: Variant in (registry as Dictionary).keys():
		var tpl: Variant = (registry as Dictionary)[key]
		if not (tpl is Object):
			continue
		if int(tpl.get("rarity")) != GOLD_RARITY:
			continue
		var card_id: Variant = tpl.get("card_id")
		var resolved: StringName = card_id if card_id is StringName else StringName(str(card_id))
		ids.append(resolved if not String(resolved).is_empty() else StringName(str(key)))
	return ids


## 发放本场金卡并返回报告——[b]唯一入口[/b]。[br]
## [br][param p_card_system] [code]CardSystem[/code]（可空——缺失时记「未发放」）。[br]
## [param p_gsm] [code]GameStateManager[/code]（收藏写入入口）。[br]
## [param p_is_cross_realm] 是否越阶渡劫（决定 1 张还是 2 张）。[br]
## [br][b]返回[/b]：[code]{cards: [<到手卡（含 name/rarity/school）>],
## cards_failed: [{name, reason}]}[/code]——两个键[b]恒在[/b]（空数组也不省），
## 消费方无需判 null。[br]
## [br][b]池空不是崩溃点[/b]：没有任何金档模板时给一条中文原因，不抛错、不 push_error
## ——这是数据缺口（GDD §未决问题 2 未落地），不是实现缺陷；渡劫本身该照常成功。[br]
func grant(p_card_system: Node, p_gsm: Node, p_is_cross_realm: bool) -> Dictionary:
	var report: Dictionary = {KEY_CARDS: [], KEY_FAILED: []}
	var ids: Array = gold_ids(p_card_system)
	if ids.is_empty():
		(report[KEY_FAILED] as Array).append({
			"card_id": "",
			"name": NAME_GOLD_CARD,
			"reason": REASON_EMPTY_POOL,
		})
		return report
	var entries: Array = []
	for _i: int in range(card_count(p_is_cross_realm)):
		var picked: StringName = ids[rng.randi_range(0, ids.size() - 1)]
		entries.append({"card_id": String(picked)})
	var granted: Dictionary = RewardRoller.apply({"cards": entries}, null, null,
			p_card_system, p_gsm)
	report[KEY_CARDS] = granted.get(KEY_CARDS, [])
	report[KEY_FAILED] = granted.get(KEY_FAILED, [])
	return report
