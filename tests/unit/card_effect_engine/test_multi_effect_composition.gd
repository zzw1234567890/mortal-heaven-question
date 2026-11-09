extends GutTest
## 多效果评估链路验收测试（DEBT-CBT-018-10 第一阶段）。[br]
## [br][b]锁定的五件事[/b]：[br]
##   1. [b]旧卡行为不变[/b]：[code]effects[/code] 为空时经
##      [method CardEffectEvaluator.evaluate_effects] 的结果与直接调
##      [method CardEffectEvaluator.evaluate_effect] 逐字段一致（伤害/治疗/减伤/属性/状态/溢出）；[br]
##   2. [b]多效果全部生效[/b]：同质字段累加（伤害+伤害、治疗+治疗）、异质字段各归各位
##      （伤害 + 属性增量 + 减伤并存）；[br]
##   3. [b]部分未知不污染[/b]：一条落 [code]UNEVALUABLE[/code] 时其余照常生效、
##      未知条零贡献，且 [code]unevaluable_count[/code] 如实报数；[br]
##   4. [b]触发时机分离[/b]：击杀类条目只在显式指定 [code]trigger[/code] 时参与；[br]
##   5. [b]减伤仍只有一处公式[/b]：多来源走 [code]combine_damage_reduction[/code]（乘算 + 60% 封顶），
##      单来源逐位保留该条自身数值。[br]
## [br]纯单元测试：[code]EvaluatorClass.new()[/code]，不触碰 Autoload / 文件系统。

const EvaluatorClass: GDScript = preload("res://src/feature/card_effect_engine/card_effect_evaluator.gd")
const ComposerClass: GDScript = preload("res://src/feature/card_effect_engine/card_effect_composer.gd")
const EntryClass: GDScript = preload("res://src/core/card_system/effect_entry.gd")
const SnapshotClass: GDScript = preload("res://src/feature/card_effect_engine/game_state_snapshot.gd")

var evaluator: RefCounted = null
var composer: RefCounted = null


func before_each() -> void:
	evaluator = EvaluatorClass.new()
	composer = ComposerClass.new(evaluator)


## 目标 1：HP 5/10、ATK 4、绑定 ×1.0；目标 2：HP 3/8、绑定 ×1.5。
func _make_snapshot() -> RefCounted:
	return SnapshotClass.build({
		1: {"hp": 5, "max_hp": 10, "atk": 4, "statuses": [], "binding_multiplier": 1.0},
		2: {"hp": 3, "max_hp": 8, "atk": 2, "statuses": [], "binding_multiplier": 1.5},
	})


## 构造一条效果条目（同测试内联，避免共享可变状态）。
func _entry(effect_type: StringName, value: int, trigger: StringName = &"") -> Resource:
	var entry: Resource = EntryClass.new()
	entry.effect_type = effect_type
	entry.value = value
	entry.trigger = trigger
	return entry


func _card(entries: Array, extra: Dictionary = {}) -> Dictionary:
	var data: Dictionary = {"card_id": &"test_card", "effects": entries}
	for key: Variant in extra:
		data[key] = extra[key]
	return data


# === 1. 旧卡行为不变 ==============================================================

func test_flat_card_matches_single_entry_evaluation() -> void:
	# 扁平卡（effects 为空）→ 合成一条，结果应与直接 evaluate_effect 完全一致。
	var flat: Dictionary = {"effect_type": &"damage", "effect_value": 3, "card_id": &"x"}
	var direct: RefCounted = evaluator.evaluate_effect(flat, 2, _make_snapshot())
	var through: RefCounted = evaluator.evaluate_effects(flat, 2, _make_snapshot())
	assert_eq(through.damage, direct.damage, "伤害一致（含绑定 ×1.5 floor 取整）")
	assert_eq(through.damage, 4, "3 × 1.5 = 4（floor）")
	assert_eq(through.is_overkill, direct.is_overkill, "溢出标记一致")


func test_flat_damage_reduce_keeps_exact_values() -> void:
	# 单来源减伤不得绕乘算再反解——0.1 无法精确表示，逐位一致是硬要求。
	var flat: Dictionary = {"effect_type": &"damage_reduce", "effect_value": 10, "card_id": &"x"}
	var direct: RefCounted = evaluator.evaluate_effect(flat, 1, _make_snapshot())
	var through: RefCounted = evaluator.evaluate_effects(flat, 1, _make_snapshot())
	assert_eq(through.damage_reduction_pct, direct.damage_reduction_pct, "减伤百分比逐位一致")
	assert_eq(through.damage_reduction_multiplier, direct.damage_reduction_multiplier,
		"减伤系数逐位一致（不经乘算往返）")


func test_flat_buff_and_status_match_direct_evaluation() -> void:
	var snapshot := _make_snapshot()
	var buff: Dictionary = {"effect_type": &"buff", "effect_value": 2, "card_id": &"x"}
	var control: Dictionary = {"effect_type": &"control_freeze", "effect_value": 0, "card_id": &"x"}
	assert_eq(evaluator.evaluate_effects(buff, 2, snapshot).stat_changes.get("ATK"),
		evaluator.evaluate_effect(buff, 2, snapshot).stat_changes.get("ATK"), "增益增量一致")
	var statuses: Array = evaluator.evaluate_effects(control, 1, snapshot).statuses_applied
	assert_eq(statuses, evaluator.evaluate_effect(control, 1, snapshot).statuses_applied,
		"施加状态一致")


func test_empty_card_data_yields_empty_evaluation() -> void:
	# 无 effects 且无 effect_type（旧「留空」卡）→ 一条空条目 → UNEVALUABLE → 空评估。
	var eval: RefCounted = evaluator.evaluate_effects({}, 1, _make_snapshot())
	assert_eq(eval.damage, 0)
	assert_eq(eval.healing, 0)
	assert_eq(eval.stat_changes, {}, "未知/留空绝不静默当 buff")
	assert_eq(eval.damage_reduction_pct, 0.0)


# === 2. 多效果全部生效 ============================================================

func test_multiple_effects_all_applied() -> void:
	var card: Dictionary = _card([
		_entry(&"damage", 3), _entry(&"damage", 2), _entry(&"buff", 1),
	])
	var eval: RefCounted = evaluator.evaluate_effects(card, 1, _make_snapshot())
	assert_eq(eval.damage, 5, "两条伤害应累加 3 + 2")
	assert_eq(eval.stat_changes.get("ATK"), 1, "属性增量与伤害各归各位")
	assert_false(eval.is_overkill, "汇总 5 与目标 HP 5 —— 5 > 5 不溢出")


func test_damage_and_healing_coexist() -> void:
	# 血杀掌式组合的简化版：打出伤害 + 治疗同时在一条列表里。
	var card: Dictionary = _card([_entry(&"damage", 4), _entry(&"heal", 3)])
	var eval: RefCounted = evaluator.evaluate_effects(card, 1, _make_snapshot())
	assert_eq(eval.damage, 4, "伤害保留")
	assert_eq(eval.healing, 3, "治疗保留（HP 5/10 + 3 未溢出）")
	assert_false(eval.is_overheal, "5 + 3 = 8 ≤ 10 不溢出")


func test_mixed_reduction_and_damage_do_not_leak_into_each_other() -> void:
	var card: Dictionary = _card([_entry(&"damage", 3), _entry(&"damage_reduce", 10)])
	var eval: RefCounted = evaluator.evaluate_effects(card, 1, _make_snapshot())
	assert_eq(eval.damage, 3, "减伤不产生伤害")
	assert_eq(eval.damage_reduction_pct, 10.0, "伤害不干扰减伤（单来源原值）")
	assert_eq(eval.stat_changes, {}, "两者都不写 ATK 面板")


func test_stat_changes_merge_same_key() -> void:
	var card: Dictionary = _card([_entry(&"buff", 2), _entry(&"debuff", 1)])
	var eval: RefCounted = evaluator.evaluate_effects(card, 1, _make_snapshot())
	assert_eq(eval.stat_changes.get("ATK"), 1, "同键累加：+2 与 -1 → +1")


func test_per_entry_categories_reported() -> void:
	var card: Dictionary = _card([
		_entry(&"damage", 1), _entry(&"heal", 1), _entry(&"damage_reduce", 5),
	])
	var categories: Array = evaluator.get_effect_categories(card)
	assert_eq(categories.size(), 3, "逐条给出标签")
	assert_eq(categories[0], EvaluatorClass.EffectCategory.DAMAGE)
	assert_eq(categories[1], EvaluatorClass.EffectCategory.HEAL)
	assert_eq(categories[2], EvaluatorClass.EffectCategory.DAMAGE_REDUCE)


# === 3. 部分未知不污染 ============================================================

func test_unknown_entry_does_not_pollute_others() -> void:
	var card: Dictionary = _card([_entry(&"damage", 3), _entry(&"steal_soul", 9)])
	var detailed: Dictionary = composer.combine_detailed(card, 1, _make_snapshot())
	assert_eq(detailed["evaluation"].damage, 3, "已知条照常生效")
	assert_eq(detailed["evaluation"].stat_changes, {}, "未知条不得变成 buff")
	assert_eq(detailed["unevaluable_count"], 1, "未知条数如实上报")
	assert_eq(detailed["entries"].size(), 2, "两条都参与汇总（未知条贡献为零）")


func test_all_unknown_entries_yield_empty_aggregate() -> void:
	var card: Dictionary = _card([_entry(&"steal_soul", 9), _entry(&"", 0)])
	var detailed: Dictionary = composer.combine_detailed(card, 1, _make_snapshot())
	assert_eq(detailed["unevaluable_count"], 2, "两条都评估不出")
	var eval: RefCounted = detailed["evaluation"]
	assert_eq(eval.damage, 0)
	assert_eq(eval.healing, 0)
	assert_eq(eval.stat_changes, {})
	assert_eq(eval.damage_reduction_pct, 0.0)
	assert_eq(eval.statuses_applied.size(), 0)


# === 4. 触发时机分离 ==============================================================

func test_kill_triggered_entry_excluded_by_default() -> void:
	var card: Dictionary = _card([
		_entry(&"damage", 4), _entry(&"heal", 2, EntryClass.TRIGGER_KILL),
	])
	var play: RefCounted = evaluator.evaluate_effects(card, 1, _make_snapshot())
	assert_eq(play.damage, 4, "打出条目照常")
	assert_eq(play.healing, 0, "击杀条目默认不参与（干跑不知道会不会击杀）")
	var kill: RefCounted = evaluator.evaluate_effects(card, 1, _make_snapshot(),
		EntryClass.TRIGGER_KILL)
	assert_eq(kill.healing, 2, "显式指定击杀触发 → 回报治疗")
	assert_eq(kill.damage, 0, "击杀回合不重复结算伤害")


func test_skipped_count_reports_trigger_filter() -> void:
	var card: Dictionary = _card([
		_entry(&"damage", 4), _entry(&"heal", 2, EntryClass.TRIGGER_KILL),
	])
	var detailed: Dictionary = composer.combine_detailed(card, 1, _make_snapshot())
	assert_eq(detailed["skipped_count"], 1, "被触发时机挡掉的条数应上报")
	assert_eq(detailed["entries"].size(), 1, "只有打出条目进汇总")


# === 5. 减伤合成（唯一公式） ======================================================

func test_single_reduction_entry_keeps_own_value() -> void:
	var card: Dictionary = _card([_entry(&"damage_reduce", 10)])
	var eval: RefCounted = evaluator.evaluate_effects(card, 1, _make_snapshot())
	assert_eq(eval.damage_reduction_pct, 10.0)
	assert_almost_eq(eval.damage_reduction_multiplier, 0.9, 0.0001)


func test_multiple_reduction_entries_combine_multiplicatively() -> void:
	var card: Dictionary = _card([_entry(&"damage_reduce", 10), _entry(&"damage_reduce", 15)])
	var eval: RefCounted = evaluator.evaluate_effects(card, 1, _make_snapshot())
	assert_almost_eq(eval.damage_reduction_multiplier, 0.9 * 0.85, 0.0001, "多来源乘算 0.9×0.85")
	assert_almost_eq(eval.damage_reduction_pct, 23.5, 0.0001, "等效 23.5%")


func test_multiple_reduction_entries_respect_sixty_percent_cap() -> void:
	var card: Dictionary = _card([
		_entry(&"damage_reduce", 30), _entry(&"damage_reduce", 30), _entry(&"damage_reduce", 30),
	])
	var eval: RefCounted = evaluator.evaluate_effects(card, 1, _make_snapshot())
	assert_almost_eq(eval.damage_reduction_multiplier, 0.4, 0.0001, "封顶 60% → ×0.4")
	assert_almost_eq(eval.damage_reduction_pct, 60.0, 0.0001)


func test_zero_pct_reduction_entry_is_not_a_source() -> void:
	var card: Dictionary = _card([_entry(&"damage_reduce", 0), _entry(&"damage_reduce", 20)])
	var eval: RefCounted = evaluator.evaluate_effects(card, 1, _make_snapshot())
	assert_almost_eq(eval.damage_reduction_pct, 20.0, 0.0001,
		"0% 不算来源——单来源路径仍取 20% 原值")


# === 6. 条目级字段与上下文 ========================================================

func test_entry_honours_native_override_from_context() -> void:
	var card: Dictionary = _card([_entry(&"damage_reduce", 10)], {"is_native": true})
	# native_value 未在条目上声明 → 沿用条目原值（本命覆盖只在声明了才生效）。
	assert_eq(evaluator.evaluate_effects(card, 2, _make_snapshot()).damage_reduction_pct, 10.0)


func test_entry_attacker_atk_comes_from_card_context() -> void:
	var card: Dictionary = _card([_entry(&"damage_multiplier", 150)], {"attacker_atk": 4})
	var eval: RefCounted = evaluator.evaluate_effects(card, 1, _make_snapshot())
	assert_eq(eval.damage, 6, "卡片级 attacker_atk=4 × 1.5 → 6")


func test_effect_entry_roundtrip_preserves_fields() -> void:
	var entry: Resource = _entry(&"damage_reduce", 15)
	entry.native_value = 20
	entry.target = &"self"
	entry.duration_turns = 2
	entry.trigger_chance = 0.25
	var data: Dictionary = entry.call("to_card_data", {})
	assert_eq(String(data["effect_type"]), "damage_reduce")
	assert_eq(data["effect_value"], 15, "value 映射到评估器读取的 effect_value")
	assert_eq(data["native_effect_value"], 20, "native_value 映射到 native_effect_value")
	assert_eq(data["target"], &"self")
	assert_eq(data["duration_turns"], 2)
	assert_almost_eq(data["trigger_chance"], 0.25, 0.0001)


func test_effects_of_expands_flat_card_to_single_entry() -> void:
	var entries: Array = ComposerClass.effects_of({"effect_type": &"damage", "effect_value": 3})
	assert_eq(entries.size(), 1, "扁平卡合成一条")
	assert_eq(String(entries[0].effect_type), "damage")
	assert_eq(entries[0].value, 3)
	var declared: Array = ComposerClass.effects_of(_card([_entry(&"heal", 1)]))
	assert_eq(declared.size(), 1, "显式列表原样返回")


func test_effects_of_ignores_flat_fields_when_list_present() -> void:
	# effects 非空 → 以列表为准；扁平字段即使残留也不叠加。
	var card: Dictionary = _card([_entry(&"heal", 2)], {"effect_type": &"damage", "effect_value": 9})
	var entries: Array = ComposerClass.effects_of(card)
	assert_eq(entries.size(), 1, "不因扁平字段多出一条")
	if entries.size() == 1:
		assert_eq(String(entries[0].effect_type), "heal", "以列表为准，扁平字段不参与")


# === 7. simulate_chain 汇总根效果 =================================================

func test_simulate_chain_uses_aggregate_for_multi_effect_card() -> void:
	var card: Dictionary = _card([_entry(&"damage", 3), _entry(&"damage", 2)])
	var preview: Dictionary = evaluator.simulate_chain(card, 1, _make_snapshot(), 5)
	assert_eq(preview["chain"].size(), 1, "仍只含根效果")
	assert_eq(preview["chain"][0]["effect"].damage, 5, "根效果为多条目汇总值")
	assert_eq(preview["would_overflow"], false, "深度 1 不溢出")
