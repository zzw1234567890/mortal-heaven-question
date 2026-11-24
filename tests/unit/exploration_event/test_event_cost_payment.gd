extends GutTest
## 事件「收费选项」付款验收——负数灵石效果必须真的扣钱，付不起就整条不落。[br]
## [br][b]为什么单独立一份[/b]：`EventDefEffect` 明说灵石可正可负（负 = 事件向玩家
## 收费：借丹炉 40、坊市交易 60），但结算是走 `ResourceSystem.add_resource` 落库的，
## 而那个口[b]明令拒收负数[/b]（`push_error` 后返回 false）。于是真机上点「借丹炉一用」
## 得到的是 `ERROR: ResourceSystem.add_resource: amount 不能为负数（-40）`——炉资没扣、
## 丹药照发，玩家白拿。本文件把「扣费」与「付不起」两条口径钉死。
##
## 走真实 Autoload（GameStateManager / ResourceSystem / CultivationSystem）——
## 断言落在余额与修为的实际变化上，不看调用次数。

const EventSystemScript := preload("res://src/feature/exploration_event_system.gd")

const KIND_LING_SHI: int = 0
const KIND_CULTIVATION: int = 1
## 生产事件「山间丹炉」——选项 0 是「借丹炉一用」（灵石 -40 + 一张卡）。
const BUNDLED_COST_EVENT: String = "lian_dan_lian_qi_001"
const BUNDLED_COST_OPTION: int = 0
const BUNDLED_COST_AMOUNT: int = 40

var _system: RefCounted = null
var _gsm: Node = null


func before_each() -> void:
	_system = EventSystemScript.new()
	_system.call(&"load_events")
	_gsm = get_node_or_null(NodePath("/root/GameStateManager"))


func after_each() -> void:
	_set_ling_shi(0)


func _deps() -> Dictionary:
	return {
		"gsm": _gsm,
		"resource_system": get_node_or_null(NodePath("/root/ResourceSystem")),
		"cultivation_system": get_node_or_null(NodePath("/root/CultivationSystem")),
		"card_system": get_node_or_null(NodePath("/root/CardSystem")),
	}


# === 扣费 =====================================================================

func test_negative_ling_shi_effect_deducts_balance() -> void:
	_set_ling_shi(100)
	_resolve(tmp_event([_effect(KIND_LING_SHI, -40)]))
	assert_eq(_ling_shi(), 60, "收费选项应从余额里真的扣掉 40")


func test_negative_ling_shi_line_reads_as_cost() -> void:
	_set_ling_shi(100)
	var result: Dictionary = _resolve(tmp_event([_effect(KIND_LING_SHI, -40)]))
	var lines: Array = result.get("lines", [])
	assert_eq(lines.size(), 1, "收费应产生一条明细")
	assert_eq(str(lines[0]), "灵石 -40", "明细应读作扣费，而不是『未能发放』")


func test_positive_ling_shi_still_gains() -> void:
	_set_ling_shi(100)
	_resolve(tmp_event([_effect(KIND_LING_SHI, 12)]))
	assert_eq(_ling_shi(), 112, "正向灵石效果不应被收费改造影响")


# === 付不起 ===================================================================

func test_cost_option_with_insufficient_balance_leaves_balance_untouched() -> void:
	_set_ling_shi(10)
	var result: Dictionary = _resolve(tmp_event([_effect(KIND_LING_SHI, -40)]))
	assert_eq(_ling_shi(), 10, "付不起时余额不得变动（也不得被负向写入）")
	assert_string_contains(str(result.get("lines")), "灵石不足",
			"应付不起时明说「灵石不足」")


func test_cost_option_with_insufficient_balance_applies_no_other_effect() -> void:
	_set_ling_shi(10)
	var before: int = _cultivation()
	var result: Dictionary = _resolve(tmp_event(
			[_effect(KIND_LING_SHI, -40), _effect(KIND_CULTIVATION, 25)]))
	assert_eq(_cultivation(), before, "炉资付不起，同一选项的后续效果一件都不该落")
	assert_eq(int(result.get("applied")), 0, "付不起时落库条数应为 0")


func test_affordable_cost_applies_the_following_effect() -> void:
	_set_ling_shi(100)
	var before: int = _cultivation()
	_resolve(tmp_event([_effect(KIND_LING_SHI, -40), _effect(KIND_CULTIVATION, 25)]))
	assert_eq(_ling_shi(), 60, "付得起时应扣费")
	assert_eq(_cultivation(), before + 25, "付得起时后续效果应照常落库")


# === 生产事件 ==================================================================

func test_bundled_cost_event_deducts_real_balance() -> void:
	_set_ling_shi(100)
	var result: Dictionary = _system.call(&"resolve_option",
			BUNDLED_COST_EVENT, BUNDLED_COST_OPTION, _deps())
	assert_true(bool(result.get("ok")), "生产收费选项应能结算")
	assert_eq(_ling_shi(), 100 - BUNDLED_COST_AMOUNT,
			"「借丹炉一用」应付 40 灵石（实际未扣即本用例要抓的断链）")


func test_bundled_cost_event_with_poor_player_grants_nothing() -> void:
	_set_ling_shi(5)
	var before: int = _ling_shi()
	var result: Dictionary = _system.call(&"resolve_option",
			BUNDLED_COST_EVENT, BUNDLED_COST_OPTION, _deps())
	assert_eq(_ling_shi(), before, "灵石不足时余额不变")
	assert_string_contains(str(result.get("lines")), "灵石不足", "应提示灵石不足")


# === 辅助 =====================================================================

var _tmp_counter: int = 0


func tmp_event(p_effects: Array) -> Dictionary:
	var option := EventDefOption.new()
	option.text = "试试"
	option.result_text = "结果文案"
	option.effects = p_effects
	var def := EventDef.new()
	_tmp_counter += 1
	def.event_id = "tmp_cost_event_%d" % _tmp_counter
	def.title = "临时事件"
	def.body = "临时正文"
	def.options = [option]
	_register({"def": def, "option": option})
	return {"def": def, "option": option}


func _register(p_built: Dictionary) -> String:
	var def: EventDef = p_built["def"]
	var table: Dictionary = _system.get(&"_registry")
	table[def.event_id] = def
	return def.event_id


func _resolve(p_built: Dictionary) -> Dictionary:
	var event_id: String = _register(p_built)
	return _system.call(&"resolve_option", event_id, 0, _deps())


func _effect(p_kind: int, p_amount: int) -> EventDefEffect:
	var effect := EventDefEffect.new()
	effect.kind = p_kind
	effect.amount = p_amount
	return effect


func _set_ling_shi(p_value: int) -> void:
	_gsm.call(&"_set_resource_ling_shi", p_value)


func _ling_shi() -> int:
	return int(_gsm.call(&"get_state", "player.resources.ling_shi"))


func _cultivation() -> int:
	return int(_gsm.call(&"get_state", "player.cultivation"))
