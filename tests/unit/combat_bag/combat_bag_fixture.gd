extends GutTest
## CombatBagFixture —— 战斗行囊的单元测试装置。[br]
## [br][b]哪些是桩、哪些是真跑[/b]：[br]
##   · [b]桩[/b]——存档（只留「移出收藏」这一个写入口）、卡牌系统（按 ID 查模板）、
##     费用系统（够不够 / 扣 / 当前值）；它们是外部世界的边界，桩掉才能让
##     「拒绝路径没动过存档」这类断言逐条钉死。[br]
##   · [b]真跑[/b]——[code]CombatRosterState[/code]（HP 的真理来源）、
##     [code]CombatDamageSettlement[/code]（治疗 = 负伤害的唯一落库路径）、
##     [code]CardEffectEvaluator[/code]（数值只从模板读）、
##     [code]InventoryModel[/code]（收藏投影）。用桩替换它们等于把被测行为换成
##     自己的假设——「回春丹是 4 点」「上限夹取」「阵亡判定」正是要证的。[br]
## [br][b]模板用真实 .tres[/b]（[code]assets/cards/templates/[/code] 里已落盘的那几个）：
## 行囊读的正是真实注册表，临时造资源只会让「模板字段名写错」这类问题跑到生产里。[br]
## [br][b]原名不符 [code]test_[/code] 前缀[/b]：GUT 不把它当用例收集，只作基类
## （先例 [code]inventory_pill_use_fixture.gd[/code]）。
##
## 来源: 本轮任务书第 1-4 条、先例
## [code]tests/unit/inventory/inventory_pill_use_fixture.gd[/code]。

const EntriesScript := preload("res://src/feature/combat/combat_bag_entries.gd")
const EffectScript := preload("res://src/feature/combat/combat_bag_effect.gd")
const UseScript := preload("res://src/feature/combat/combat_bag_use.gd")
const RulesScript := preload("res://src/feature/combat/combat_bag_rules.gd")
const ModelScript := preload("res://src/feature/inventory/inventory_model.gd")
const RosterScript := preload("res://src/feature/combat/combat_roster_state.gd")
const SettlementScript := preload("res://src/feature/combat/combat_damage_settlement.gd")

## 落盘的具名模板——丹药 / 法宝各取一枚可评估的，外加一枚「效果未建模」的。
const PILL_HEAL: Resource = preload("res://assets/cards/templates/pill_hui_chun_dan.tres")
const PILL_ALL: Resource = preload("res://assets/cards/templates/pill_tian_luo_dan.tres")
const PILL_INERT: Resource = preload("res://assets/cards/templates/pill_jiu_zhuan_jin_dan.tres")
const ARTIFACT_BUFF: Resource = preload("res://assets/cards/templates/artifact_ji_chu_fa_qi.tres")

## 本文件独立的角色 ID 段——不与其它测试文件撞车。
const CHAR_A: int = 8601
const CHAR_B: int = 8602


## 存档桩——只需「移出收藏」这一个写入口与 [code]collection[/code] 只读域。
class StubGsm extends Node:
	var collection: Dictionary = {"owned_cards": [], "total_count": 0}
	## 移除调用记录（断言「拒绝路径没有动过存档」用）。
	var removals: Array = []
	## 置假时移除一律失败（模拟「校验未开启 / 实例已被移除」）。
	var removable: bool = true

	func remove_card_from_collection(p_instance_id: int) -> bool:
		removals.append(p_instance_id)
		if not removable:
			return false
		for raw: Variant in collection["owned_cards"]:
			if int((raw as Dictionary).get("card_instance_id", -1)) == p_instance_id:
				collection["owned_cards"].erase(raw)
				return true
		return false


## 卡牌系统桩——[code]get_template(StringName) -> Variant[/code] 契约。
class StubCards extends Node:
	var templates: Dictionary = {}

	func get_template(p_card_id: StringName) -> Variant:
		return templates.get(str(p_card_id), null)


## 费用系统桩——够不够 / 扣 / 当前值三件事（判定与扣费都归它）。
class StubCost extends Node:
	var current: int = 5
	## 每次扣费的金额记录（断言「拒绝路径没扣费」用）。
	var spends: Array = []

	func get_current_cost() -> int:
		return current

	func can_afford(p_cost: int) -> bool:
		return p_cost <= 0 or current >= p_cost

	func spend(p_amount: int) -> bool:
		spends.append(p_amount)
		if p_amount <= 0:
			return true
		if current < p_amount:
			return false
		current -= p_amount
		return true


## 战斗系统桩——落库子模块要的三件事：状态表、广播出口、公开取数口。
class StubCombat extends Node:
	var roster: RefCounted = null
	var settlement: RefCounted = null
	## [code]_emit_safe[/code] 的调用记录（断言「治疗按实际增量广播」用）。
	var emitted: Array = []

	func _get_roster_state() -> RefCounted:
		return roster

	func get_roster_state() -> RefCounted:
		return roster

	func get_damage_settlement() -> RefCounted:
		return settlement

	func _emit_safe(p_signal_name: StringName, p_args: Array) -> void:
		emitted.append({"signal": p_signal_name, "args": p_args})


var gsm: StubGsm = null
var cards: StubCards = null
var cost: StubCost = null
var combat: StubCombat = null
var roster: RefCounted = null
var entries: RefCounted = null
var use: RefCounted = null


func before_each() -> void:
	gsm = StubGsm.new()
	cards = StubCards.new()
	cost = StubCost.new()
	combat = StubCombat.new()
	add_child_autofree(gsm)
	add_child_autofree(cards)
	add_child_autofree(cost)
	add_child_autofree(combat)
	roster = RosterScript.new()
	combat.roster = roster
	combat.settlement = SettlementScript.new(combat)
	cards.templates[str(PILL_HEAL.get("card_id"))] = PILL_HEAL
	cards.templates[str(PILL_ALL.get("card_id"))] = PILL_ALL
	cards.templates[str(PILL_INERT.get("card_id"))] = PILL_INERT
	cards.templates[str(ARTIFACT_BUFF.get("card_id"))] = ARTIFACT_BUFF
	entries = EntriesScript.new(ModelScript.new(gsm, cards), cards, cost, roster)
	use = UseScript.new(entries, EffectScript.new(combat.settlement, roster), gsm, cost)


# ═══════════════════════════════════════════════════════════════════════════════
# 摆场景（全部走真实入口——桩只替代外部世界，不替代被测路径）
# ═══════════════════════════════════════════════════════════════════════════════

## 往收藏里放一张某模板的实例（同名多张时多次调用）。[br]
## [br][b]返回[/b]：实例 ID（调用方拿它断言「被扣掉的正是这一张」）。
func own(p_template: Resource, p_instance_id: int) -> int:
	(gsm.collection["owned_cards"] as Array).append({
		"card_instance_id": p_instance_id,
		"template_id": str(p_template.get("card_id")),
	})
	gsm.collection["total_count"] = int(gsm.collection["total_count"]) + 1
	return p_instance_id


## 摆我方一员的 HP（走真实状态表种子）。[br]
## [br][param p_current] 当前 HP；[code]>= p_max[/code] 表示满血（丹药候选池会滤掉）。
func set_hp(p_character_id: int, p_current: int, p_max: int) -> void:
	roster.call(&"seed_player_field", [{"character_id": p_character_id}],
			{p_character_id: {"current_hp": p_current, "max_hp": p_max, "atk": 3}})


## 当前 HP（读真实状态表）。
func hp_of(p_character_id: int) -> int:
	return int(roster.call(&"get_hp", p_character_id)["current"])


## 收藏里某模板的实例数（「用掉一枚」的存档侧实证）。
func owned_count(p_template: Resource) -> int:
	return owned_count_by_id(str(p_template.get("card_id")))


## 按 [code]template_id[/code] 数收藏里的实例数（模板以字典形态注册时的用例用）。
func owned_count_by_id(p_template_id: String) -> int:
	var count: int = 0
	for raw: Variant in (gsm.collection["owned_cards"] as Array):
		if str((raw as Dictionary).get("template_id", "")) == p_template_id:
			count += 1
	return count


## 行囊条目里某模板的那一条（找不到返回空字典）。
func entry_of(p_template: Resource) -> Dictionary:
	return entry_of_by_id(str(p_template.get("card_id")))


## 按 [code]template_id[/code] 取条目（模板以字典形态注册时的用例用）。
func entry_of_by_id(p_template_id: String) -> Dictionary:
	for raw: Variant in entries.call(&"entries"):
		if str((raw as Dictionary).get("template_id", "")) == p_template_id:
			return raw
	return {}


## 走完整链路用一枚条目：先取条目（带真实模板结论），再交给结算层。[br]
## [br][b]为什么必须经条目[/b]：手搓条目会绕过「条目带对了 cost / instance_id」
## 这一段，而那正是生产路径的输入（面板交给宿主的正是它）。
func use_template(p_template: Resource, p_targets: Array = []) -> Dictionary:
	return use.call(&"use_entry", entry_of(p_template), p_targets)


## 造一条与 [method entry_of] 同形状的裸条目（判据层的用例直接喂它）。[br]
## [br][b]为什么允许造裸条目[/b]：判据是纯函数，它的输入契约就是这条字典——
## 逐分支单测不该被「先摆一套存档」拖住（同 [code]test_combat_play_result.gd[/code]）。
func bare_entry(p_kind: StringName, p_effect_kind: int, p_cost: int = 1,
		p_instance_id: int = 1, p_target_type: String = "single_ally") -> Dictionary:
	return {
		"kind": p_kind, "instance_id": p_instance_id, "cost": p_cost,
		"effect_kind": p_effect_kind, "target_type": p_target_type,
	}
