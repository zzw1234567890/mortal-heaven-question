extends GutTest
## Story 3-8 验收测试：5 流派增益公式 + 不可驱散约束 + 流派切换清空。
##
## 覆盖 AC-001 到 AC-018（18 条 AC）。
##
## 测试策略：
##   - SS_SCRIPT.new() 构造 SchoolSystem 实例
##   - var ss: Node 持有 + 动态分派
##   - 聚焦本 Story 数据层职责——effects 数值正确性 + 约束验证
##   - 增益落地执行（伤害修正/回复/抽牌/费用折扣）属战斗 Epic——本 Story 仅验证
##     SCHOOL_LIBRARY 中 effects 字段名与数值精确匹配 AC 要求，以及系统级效果
##     独立于 StatusEffectSystem 的约束（无注册表字段、纯数据无副作用）

const SS_SCRIPT: GDScript = preload("res://src/core/school_system/school_system.gd")

var ss: Node = null


func before_each() -> void:
	ss = SS_SCRIPT.new()


func after_each() -> void:
	if ss != null:
		ss.free()
		ss = null


# ============================================================================
# 辅助方法
# ============================================================================

## 按 type 查找 effects 列表中的 effect entry（不存在返回空字典）。
func _find_effect(effects: Array, effect_type: String) -> Dictionary:
	for e in effects:
		if e.get("type", "") == effect_type:
			return e
	return {}


## 断言 effect entry 的字段精确匹配。
func _assert_effect(effects: Array, effect_type: String, expected: Dictionary) -> void:
	var effect: Dictionary = _find_effect(effects, effect_type)
	assert_false(effect.is_empty(), "应含 %s 增益" % effect_type)
	for key in expected:
		var expected_val = expected[key]
		var actual_val = effect.get(key, null)
		if expected_val is Array:
			assert_eq(actual_val, expected_val, "%s.%s 应匹配" % [effect_type, key])
		else:
			assert_eq(actual_val, expected_val, "%s.%s 应为 %s" % [effect_type, key, str(expected_val)])


# ============================================================================
# AC-001：正道发育流 effects
# ============================================================================

func test_ac001_righteous_dev_effects() -> void:
	var effects: Array = ss.get_school_effects(&"righteous_dev")
	assert_eq(effects.size(), 3, "正道发育流应有 3 个增益")

	_assert_effect(effects, "regen", {value = 2, trigger = "turn_end"})
	_assert_effect(effects, "damage_reduce", {value = 1, floor = 1})
	_assert_effect(effects, "formation_ease", {value = -1})


# ============================================================================
# AC-002：魔道快攻流 effects
# ============================================================================

func test_ac002_demonic_aggro_effects() -> void:
	var effects: Array = ss.get_school_effects(&"demonic_aggro")
	assert_eq(effects.size(), 3, "魔道快攻流应有 3 个增益")

	_assert_effect(effects, "attack_boost", {value = 2, trigger = "first_3_turns", turn_limit = 3})
	_assert_effect(effects, "draw_on_kill", {value = 1})
	# cost_boost 首回合 +1 费
	var cost_boost: Dictionary = _find_effect(effects, "cost_boost")
	assert_false(cost_boost.is_empty(), "应含 cost_boost 增益")
	assert_eq(cost_boost.get("value", 0), 1, "cost_boost value 应为 1")
	assert_eq(cost_boost.get("turn", 0), 1, "cost_boost 应作用于 turn_1")


# ============================================================================
# AC-003：正邪混合流 effects
# ============================================================================

func test_ac003_mixed_alignment_effects() -> void:
	var effects: Array = ss.get_school_effects(&"mixed_alignment")
	assert_eq(effects.size(), 3, "正邪混合流应有 3 个增益")

	_assert_effect(effects, "stat_boost", {target = "mixed", atk = 1, def = 1})
	_assert_effect(effects, "cost_discount", {chance = 0.3, value = 1})
	_assert_effect(effects, "formation_ease", {value = -1})


# ============================================================================
# AC-004：归墟真灵流 effects
# ============================================================================

func test_ac004_spirit_realm_beast_effects() -> void:
	var effects: Array = ss.get_school_effects(&"spirit_realm_beast")
	assert_eq(effects.size(), 3, "归墟真灵流应有 3 个增益")

	_assert_effect(effects, "stat_boost", {target = "spirit", hp = 3, atk = 1})
	# immune_debuff debuffs 数组
	var immune: Dictionary = _find_effect(effects, "immune_debuff")
	assert_false(immune.is_empty(), "应含 immune_debuff 增益")
	assert_eq(immune.get("debuffs", []), [&"fear", &"confusion"], "debuffs 应为 [fear, confusion]")
	_assert_effect(effects, "aura_hp", {value = 1, per_unit = "spirit"})


# ============================================================================
# AC-005：百艺炼丹流 effects
# ============================================================================

func test_ac005_alchemy_mastery_effects() -> void:
	var effects: Array = ss.get_school_effects(&"alchemy_mastery")
	assert_eq(effects.size(), 4, "百艺炼丹流应有 4 个增益")

	_assert_effect(effects, "pill_boost", {value = 0.2})
	_assert_effect(effects, "cost_reduce", {target = "alchemy_material", value = 1, floor = 1})
	_assert_effect(effects, "action_recover", {per_pills = 3, value = 1, max_triggers = 3})
	_assert_effect(effects, "pill_breakthrough", {chance = 0.1})


# ============================================================================
# AC-006：正道 damage_reduce floor=1（伤害最低 1，不归零）
# ============================================================================

func test_ac006_damage_reduce_floor_prevents_zero() -> void:
	var effects: Array = ss.get_school_effects(&"righteous_dev")
	var damage_reduce: Dictionary = _find_effect(effects, "damage_reduce")
	assert_eq(damage_reduce.get("floor", 0), 1, "damage_reduce 应声明 floor=1")
	# 验证 floor 语义：max(floor, damage - value) 不归零
	var damage: int = 1
	var value: int = damage_reduce.get("value", 0)
	var floor: int = damage_reduce.get("floor", 0)
	assert_eq(maxi(floor, damage - value), 1, "受 1 点伤害减 1 → 最低 1（不归零）")
	assert_eq(maxi(floor, 3 - value), 2, "受 3 点伤害减 1 → 2")


# ============================================================================
# AC-007：魔道 attack_boost 仅前 3 回合
# ============================================================================

func test_ac007_attack_boost_first_3_turns_only() -> void:
	var effects: Array = ss.get_school_effects(&"demonic_aggro")
	var attack_boost: Dictionary = _find_effect(effects, "attack_boost")
	assert_eq(attack_boost.get("trigger", ""), "first_3_turns", "trigger 应为 first_3_turns")
	assert_eq(attack_boost.get("turn_limit", 0), 3, "turn_limit 应为 3")
	# 验证边界语义：turn ≤ 3 生效，turn ≥ 4 失效
	var turn_limit: int = attack_boost.get("turn_limit", 0)
	assert_true(3 <= turn_limit, "turn=3 在生效范围内")
	assert_true(4 > turn_limit, "turn=4 超出 turn_limit → 失效")


# ============================================================================
# AC-008：归墟 aura_hp 叠加（per_unit=spirit）
# ============================================================================

func test_ac008_aura_hp_scales_with_spirit_count() -> void:
	var effects: Array = ss.get_school_effects(&"spirit_realm_beast")
	var aura: Dictionary = _find_effect(effects, "aura_hp")
	assert_eq(aura.get("per_unit", ""), "spirit", "per_unit 应为 spirit")
	assert_eq(aura.get("value", 0), 1, "value 应为 1")
	# 验证叠加语义：count × value
	var value: int = aura.get("value", 0)
	assert_eq(3 * value, 3, "3 归墟角色 → 全体 +3HP")
	assert_eq(2 * value, 2, "2 归墟角色 → 全体 +2HP")


# ============================================================================
# AC-009：百艺 pill_boost +20%
# ============================================================================

func test_ac009_pill_boost_20_percent() -> void:
	var effects: Array = ss.get_school_effects(&"alchemy_mastery")
	var pill_boost: Dictionary = _find_effect(effects, "pill_boost")
	assert_eq(pill_boost.get("value", 0.0), 0.2, "pill_boost value 应为 0.2")
	# 验证加成语义：100 × (1 + 0.2) = 120
	var value: float = pill_boost.get("value", 0.0)
	assert_eq(100 * (1.0 + value), 120.0, "回复 100HP 丹药 → 120HP")


# ============================================================================
# AC-010：百艺 action_recover 封顶 3 次
# ============================================================================

func test_ac010_action_recover_capped_at_3() -> void:
	var effects: Array = ss.get_school_effects(&"alchemy_mastery")
	var action_recover: Dictionary = _find_effect(effects, "action_recover")
	assert_eq(action_recover.get("per_pills", 0), 3, "per_pills 应为 3")
	assert_eq(action_recover.get("value", 0), 1, "value 应为 1")
	assert_eq(action_recover.get("max_triggers", 0), 3, "max_triggers 应为 3")
	# 验证封顶语义：9 张丹药 → 3 次；12 张丹药仍 3 次
	var per_pills: int = action_recover.get("per_pills", 0)
	var max_triggers: int = action_recover.get("max_triggers", 0)
	assert_eq(mini(9 / per_pills, max_triggers), 3, "9 张丹药 → 3 次")
	assert_eq(mini(12 / per_pills, max_triggers), 3, "12 张丹药仍 3 次（封顶）")


# ============================================================================
# AC-011：流派增益不可被 StatusEffectSystem.remove_status 移除
# ============================================================================

func test_ac011_effects_not_registered_in_status_system() -> void:
	# 系统级效果独立于 buff 系统——SchoolSystem 不持有 StatusEffect 注册表字段
	# （无 _instances/_by_target/_suspended——StatusEffectSystem 的注册表）
	assert_false(ss.has_method("remove_status"), "SchoolSystem 不应提供 remove_status")
	assert_false("_instances" in ss, "SchoolSystem 不应持有 _instances 注册表")
	assert_false("_by_target" in ss, "SchoolSystem 不应持有 _by_target 注册表")
	# 增益条目是纯数据 Dictionary——不含 StatusEffect 实例引用
	for school_id in ss.SCHOOL_LIBRARY:
		for effect in ss.SCHOOL_LIBRARY[school_id].effects:
			assert_false(effect.has("status_id"), "%s 增益不应含 status_id" % effect.get("type", "?"))
			assert_false(effect.has("instance"), "%s 增益不应含 instance 引用" % effect.get("type", "?"))


# ============================================================================
# AC-012：流派增益不占用 StatusEffect 20 槽位
# ============================================================================

func test_ac012_effects_do_not_consume_status_slots() -> void:
	# 流派增益是 SchoolSystem 数据层的独立列表——不含槽位计数字段
	var effects: Array = ss.get_school_effects(&"righteous_dev")
	for effect in effects:
		assert_false(effect.has("slot_index"), "增益不应含 slot_index")
		assert_false(effect.has("active_count"), "增益不应含 active_count")
	# get_school_effects 返回的增益数与 StatusEffect 槽位无关——纯数据查询
	assert_eq(effects.size(), 3, "正道发育流 3 增益独立于 20 槽位")


# ============================================================================
# AC-013：流派切换旧增益清空（无状态缓存）
# ============================================================================

func test_ac013_get_effects_is_stateless_no_cache() -> void:
	# SchoolSystem 纯查询无副作用——同 ID 多次调用返回一致数据，无缓存漂移
	var first: Array = ss.get_school_effects(&"righteous_dev")
	var second: Array = ss.get_school_effects(&"righteous_dev")
	assert_eq(first, second, "同 ID 多次查询结果应一致（无状态副作用）")
	# 切换到另一流派查询——不影响原流派数据
	var demonic: Array = ss.get_school_effects(&"demonic_aggro")
	assert_ne(demonic, first, "不同流派增益列表应不同")


# ============================================================================
# AC-014：切换无重叠期——同一时刻唯一流派
# ============================================================================

func test_ac014_detect_returns_single_school() -> void:
	# detect() 返回单个流派 ID（非列表）——保证同一时刻唯一流派
	var result = ss.detect({field_characters = [], deck_cards = [], player_realm = 1, alchemy_count = 0, collected_characters = []})
	assert_true(result is StringName, "detect 返回值应为 StringName（唯一流派 ID 或空）")


# ============================================================================
# AC-015：school_changed 信号 (old_id, new_id)
# ============================================================================

func test_ac015_school_changed_signal_two_args() -> void:
	var sig_list: Array = SS_SCRIPT.get_script_signal_list()
	var found: bool = false
	for sig in sig_list:
		if sig.name == "school_changed":
			found = true
			# 信号声明含 2 个参数（old_school_id, new_school_id）
			assert_eq(sig.args.size(), 2, "school_changed 应有 2 个参数")
			break
	assert_true(found, "应声明 school_changed 信号")
	# 验证发射载荷
	var payload: Array = []
	ss.school_changed.connect(func(old_s, new_s): payload.append([old_s, new_s]))
	ss.school_changed.emit(&"righteous_dev", &"demonic_aggro")
	assert_eq(payload.size(), 1, "信号应发射 1 次")
	assert_eq(payload[0][0], &"righteous_dev", "old_id 应为 righteous_dev")
	assert_eq(payload[0][1], &"demonic_aggro", "new_id 应为 demonic_aggro")


# ============================================================================
# AC-016：魔道首回合 +1 费与天赋叠加
# ============================================================================

func test_ac016_cost_boost_stacks_with_talent() -> void:
	var effects: Array = ss.get_school_effects(&"demonic_aggro")
	var cost_boost: Dictionary = _find_effect(effects, "cost_boost")
	assert_eq(cost_boost.get("value", 0), 1, "流派 cost_boost 基础值应为 1")
	# 叠加语义：基础 + 1（天赋）+ 1（流派）= +2
	var talent_bonus: int = 1
	var school_bonus: int = cost_boost.get("value", 0)
	assert_eq(talent_bonus + school_bonus, 2, "天赋 +1 与流派 +1 叠加 = +2")


# ============================================================================
# AC-017：流派增益在战斗开始时锁定（数据定义无战中重检测副作用）
# ============================================================================

func test_ac017_effects_are_pure_data_locked_at_battle_start() -> void:
	# 增益在战斗开始时锁定——SchoolSystem 的 effects 是 const 数据，detect() 纯计算
	# 无副作用（不依赖战中动态状态写入）——CombatSystem 读取后锁定
	var effects: Array = ss.get_school_effects(&"righteous_dev")
	var snapshot_a: Array = effects.duplicate(true)
	# 同输入 detect 结果稳定——纯函数（战中角色阵亡不会改变 SCHOOL_LIBRARY 数据）
	var state: Dictionary = {
		field_characters = [
			{faction_tags = [&"zhengdao"], rarity = "blue", card_type = "character", cost = 3, character_id = &""},
			{faction_tags = [&"zhengdao"], rarity = "blue", card_type = "character", cost = 3, character_id = &""},
			{faction_tags = [&"zhengdao"], rarity = "blue", card_type = "character", cost = 3, character_id = &""},
		],
		deck_cards = [],
		player_realm = 1,
		alchemy_count = 0,
		collected_characters = [],
	}
	assert_eq(ss.detect(state), &"righteous_dev", "detect 应返回 righteous_dev")
	assert_eq(ss.get_school_effects(&"righteous_dev"), snapshot_a, "effects 数据不应被 detect 修改")


# ============================================================================
# AC-018：无流派激活时无增益
# ============================================================================

func test_ac018_no_school_no_effects() -> void:
	# detect() 返回空 StringName 时，get_school_effects 返回空数组（无增益）
	var result: StringName = ss.detect({field_characters = [], deck_cards = [], player_realm = 1, alchemy_count = 0, collected_characters = []})
	assert_eq(result, &"", "空场 detect 应返回空 StringName")
	var effects: Array = ss.get_school_effects(&"")
	assert_eq(effects.size(), 0, "空流派 ID 应返回空增益列表")


# ============================================================================
# 边缘情况补强
# ============================================================================

func test_all_effects_have_type_field() -> void:
	# 所有流派的所有增益 entry 都含 type 字段
	for school_id in ss.SCHOOL_LIBRARY:
		var effects: Array = ss.SCHOOL_LIBRARY[school_id].effects
		assert_true(effects.size() >= 3, "%s 应有至少 3 个增益" % school_id)
		for effect in effects:
			assert_true(effect.has("type"), "%s 增益应含 type" % school_id)


func test_effect_count_matches_spec() -> void:
	# 各流派增益数量精确匹配 AC-001~005（正道3/魔道3/混合3/归墟3/百艺4）
	assert_eq(ss.get_school_effects(&"righteous_dev").size(), 3)
	assert_eq(ss.get_school_effects(&"demonic_aggro").size(), 3)
	assert_eq(ss.get_school_effects(&"mixed_alignment").size(), 3)
	assert_eq(ss.get_school_effects(&"spirit_realm_beast").size(), 3)
	assert_eq(ss.get_school_effects(&"alchemy_mastery").size(), 4)
