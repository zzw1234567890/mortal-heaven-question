extends GutTest
## InventoryPillUseFixture —— 背包内使用丹药的单元测试装置。[br]
## [br][b]全部依赖走桩[/b]：GSM（移除卡牌 + 存档域）、卡牌系统（按 ID 查模板）、
## HP 账本（[code]read_all[/code] / [code]write_back[/code]）——本模块的公式与
## 边缘情况因此能在不碰真实存档的前提下逐条验证（同
## [code]character_status_model_fixture.gd[/code] 的取舍）。[br]
## [br][b]效果数值不桩[/b]：[code]CardEffectEvaluator[/code] 是真跑的——「丹药效果读
## 模板」这条口径正是被测对象，用桩替换它等于把被测行为换成自己的假设。[br]
## [br][b]原名不带 [code]test_[/code] 前缀[/b]：GUT 不把它当用例收集，只作基类。
##
## 来源: 先例 [code]tests/unit/inventory/character_status_model_fixture.gd[/code]。

const UseScript := preload("res://src/feature/inventory/inventory_pill_use.gd")
const CarryoverScript := preload("res://src/feature/combat/combat_hp_carryover.gd")

## 丹药卡的分类值（[code]CardTemplate.CardType.PILL[/code]）。
const CARD_TYPE_PILL: int = 4
const CARD_TYPE_ARTIFACT: int = 2
## 法宝 / 灵材行的分类值（灵材用非卡片哨兵，见 [code]InventoryModel.NON_CARD_TYPE[/code]）。
const CARD_TYPE_NONE: int = -1


## GSM 桩——「移出收藏」这一个写入口 + 探索域行动力的读 / 写（回复行动力类丹药用）。[br]
## [br][b]为什么 AP 也在这里[/b]：两类丹药（治疗 / 回复行动力）走的是同一个
## [code]UseScript.use_entry[/code] 入口与同一份装置，把 AP 拆到另一个桩只会让
## 「同一枚丹药换个效果类型」这件事跨两个文件才说得清。
class StubGsm:
	extends Node
	## 可移除的实例 ID（不在表里的移除一律失败——真实 GSM 的返回值语义）。
	var removable: Array = []
	## 移除调用记录（断言「拒绝路径没有动过存档」用）。
	var removals: Array = []
	## 探索域（读 [code]action_points[/code] / [code]max_action_points[/code]）。
	## [br]默认与出厂存档同形（两字段都是 0 = 上限未知）——用例显式摆值才进入
	## 「有上限」的口径。
	var exploration: Dictionary = {"action_points": 0, "max_action_points": 0}
	## [code]restore_action_points[/code] 调用记录（断言回滚路径没走它）。
	var ap_restores: Array = []
	## [code]set_exploration_ap[/code] 调用记录（回滚写的是这个）。
	var ap_sets: Array = []

	func remove_card_from_collection(p_instance_id: int) -> bool:
		removals.append(p_instance_id)
		if not removable.has(p_instance_id):
			return false
		removable.erase(p_instance_id)
		return true

	## 恢复行动力——夹到上限（与真实 [code]GSMExplorationWrites.restore_action_points]
	## 同口径：上限为 0 表示「上限未知」，此时不夹），并返回[b]实际写入[/b]的量。
	func restore_action_points(p_amount: int) -> void:
		var current: int = int(exploration.get("action_points", 0))
		var max_ap: int = int(exploration.get("max_action_points", 0))
		var new_val: int = current + p_amount
		if max_ap > 0:
			new_val = mini(new_val, max_ap)
		exploration["action_points"] = new_val
		ap_restores.append(p_amount)

	## 设置行动力（回滚路径用的「设回原值」语义）。
	func set_exploration_ap(p_current: int, p_max_ap: int) -> void:
		exploration["action_points"] = p_current
		exploration["max_action_points"] = p_max_ap
		ap_sets.append([p_current, p_max_ap])


## 卡牌系统桩——[code]get_template(StringName) -> Variant[/code] 契约。
class StubCards:
	extends Node
	var templates: Dictionary = {}

	func get_template(p_card_id: StringName) -> Variant:
		return templates.get(str(p_card_id), null)


## HP 账本桩——[code]CombatHpCarryover[/code] 的读写契约（写回就地更新表，
## 让「回滚」这类二次读取能看到第一次写入的痕迹）。
class StubHp:
	extends RefCounted
	var table: Dictionary = {}
	## 写回调用次数（断言「拒绝路径一次都没写」用）。
	var writes: int = 0
	## 置真时 [code]write_back[/code] 返回 [code]WRITE_UNAVAILABLE[/code]（-1）——
	## 模拟 GSM 缺入口的降级路径。
	var unavailable: bool = false

	func read_all() -> Dictionary:
		return table.duplicate(true)

	func write_back(p_entries: Array) -> int:
		writes += 1
		if unavailable:
			return CarryoverScript.WRITE_UNAVAILABLE
		var written: int = 0
		for raw: Variant in p_entries:
			if not (raw is Dictionary):
				continue
			var entry: Dictionary = raw
			if int(entry.get("side", -1)) != CarryoverScript.SIDE_PLAYER:
				continue
			if not bool(entry.get("known", false)):
				continue
			var character_id: int = int(entry.get("character_id", -1))
			table[character_id] = {
				"current_hp": int(entry.get("current_hp", 0)),
				"max_hp": int(entry.get("max_hp", 0)),
			}
			written += 1
		return written


var gsm: StubGsm = null
var cards: StubCards = null
var hp: StubHp = null
var use: RefCounted = null


func before_each() -> void:
	gsm = StubGsm.new()
	cards = StubCards.new()
	hp = StubHp.new()
	add_child_autofree(gsm)
	add_child_autofree(cards)
	use = UseScript.new(gsm, cards)
	use.hp_carryover = hp


## 造一枚丹药模板。[br]
## [br][param p_value] 治疗量；[code]<= 0[/code] 表示模板没有可识别的治疗效果
## （九转金丹那种「永久加最大生命」的形态）。[br]
## [br][param p_effect_type] 效果类型词表字符串——默认治疗（[code]heal[/code]）；
## 传 [code]restore_ap[/code] 即造一枚[b]回复行动力[/b]类丹药（数值同走
## [param p_value]）。
func add_pill(p_template_id: String, p_name: String, p_value: int,
		p_target_type: String = "single_ally",
		p_effect_type: String = "heal") -> void:
	cards.templates[p_template_id] = {
		"card_id": p_template_id, "name": p_name, "type": CARD_TYPE_PILL,
		"rarity": 3, "cost": 1, "effect_type": StringName(p_effect_type),
		"effect_value": p_value, "target_type": StringName(p_target_type),
	}


## 摆当前行动力与上限（回复行动力类丹药的读 / 写都落在这个桩上）。
func set_ap(p_current: int, p_max: int) -> void:
	gsm.exploration["action_points"] = p_current
	gsm.exploration["max_action_points"] = p_max


## 当前行动力。
func ap() -> int:
	return int(gsm.exploration.get("action_points", -1))


## 造一条背包条目（[code]InventoryModel.category_entries[/code] 的形状）。
func entry(p_template_id: String, p_instance_ids: Array,
		p_card_type: int = CARD_TYPE_PILL) -> Dictionary:
	return {
		"name": p_template_id, "count": p_instance_ids.size(),
		"card_type": p_card_type, "template_id": p_template_id,
		"instance_ids": p_instance_ids,
	}


## 摆一名角色的 HP（账本原值）。
func set_hp(p_character_id: int, p_current: int, p_max: int) -> void:
	hp.table[p_character_id] = {"current_hp": p_current, "max_hp": p_max}
