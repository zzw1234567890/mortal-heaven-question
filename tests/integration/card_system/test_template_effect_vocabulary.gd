extends GutTest
## 卡牌模板「效果词表回填」验收测试（DEBT-CBT-018-8）。[br]
## [br][b]背景[/b]：`card_effect_evaluator._category_for` 原先只有 8 个 `effect_type` 前缀，
## 补上减伤/倍率/伤害加成/治疗加成/阵法亲和五类后，模板侧逐张回填并在此锁定。[br]
## [br][b]锁定的四件事[/b]：[br]
##   1. 百分比减伤卡 → [code]damage_reduce[/code]，数值为百分比整数，本命值走 [code]native_effect_value[/code]；[br]
##   2. 攻击类符箓 → [code]damage_multiplier[/code]，数值为倍率百分比整数；[br]
##   3. 三张此前「留空」的卡各自回填为新类别（不得留空，也不得退回 buff）；[br]
##   4. 概率触发卡声明 [code]trigger_chance[/code] / [code]native_trigger_chance[/code]。[br]
## [br][b]数值唯一真理来源[/b]：[code]design/gdd/identity-selection-system.md[/code] §①~§⑥
## 的「初始卡牌详情」表。[br]
## [br]加载方式与 `test_template_assets.gd` 相同（独立实例 + 重试驱动，避免 Autoload 污染）。

const CS_SCRIPT: GDScript = preload("res://src/core/card_system/card_system.gd")
const CardTemplateClass: GDScript = preload("res://src/core/card_system/card_template.gd")

var cs: Node = null
var _gsm_validation_before: bool = false
var _gsm_database_before: Dictionary = {}


func before_all() -> void:
	_gsm_validation_before = GameStateManager.validation_enabled
	_gsm_database_before = GameStateManager._card_template_database
	cs = CS_SCRIPT.new()
	cs._load_templates_from(CS_SCRIPT.DEFAULT_TEMPLATE_PATH)
	_drive_loading_to_completion()


func after_all() -> void:
	if cs != null:
		cs.free()
		cs = null
	GameStateManager.validation_enabled = _gsm_validation_before
	GameStateManager._card_template_database = _gsm_database_before


## 推进异步加载至完成——重试驱动（同 test_card_system_loading.gd 的 TD-014 修复）。
func _drive_loading_to_completion() -> void:
	for _attempt: int in range(3):
		if cs._pending_paths.is_empty():
			break
		for _frame: int in range(100):
			cs._process(0.016)
			if cs._pending_paths.is_empty():
				break
			OS.delay_msec(4)
	assert_true(cs._pending_paths.is_empty(),
		"真实模板应在 3 轮 × 100 帧内加载完成（失败即实现/资产问题）")


func _require(id: StringName) -> CardTemplateClass:
	var tpl: CardTemplateClass = cs.get_template(id)
	assert_not_null(tpl, "应存在 %s 模板" % id)
	return tpl


# ---- 1. 百分比减伤 ----

## 「受到伤害降低 X%」→ [code]damage_reduce[/code]，[code]effect_value[/code] 为百分比整数，
## 本命值放 [code]native_effect_value[/code]（GDD 的 10→15、15→20 不是 ×1.5 关系）。
func test_damage_reduction_cards_use_damage_reduce() -> void:
	var expected: Dictionary = {
		&"yan_yun_bu": {"pct": 10, "native": 15},          # GDD §①：10%（林渊本命 15%）
		&"huan_hua_mi_zong_bu": {"pct": 15, "native": 20}, # GDD §③：15%（汐音本命 20%）
	}
	for id: StringName in expected.keys():
		var tpl: CardTemplateClass = _require(id)
		if tpl == null:
			continue
		assert_eq(String(tpl.effect_type), "damage_reduce", "%s 应归 damage_reduce" % id)
		assert_eq(tpl.effect_value, int(expected[id]["pct"]),
			"%s 的减伤百分比应与 GDD 一致" % id)
		assert_eq(tpl.native_effect_value, int(expected[id]["native"]),
			"%s 的本命减伤百分比应与 GDD 一致（不做 ×1.5）" % id)
		assert_true(tpl.description.contains("受到伤害降低"),
			"%s 的描述应保留 GDD 的百分比减伤口径" % id)


# ---- 2. 此前留空的三张卡 ----

## 三张「留空」卡各自回填成新类别——数值与 GDD 一致，且[b]不得[/b]落回 buff/空值。
func test_previously_blank_effect_types_backfilled() -> void:
	var expected: Dictionary = {
		&"you_ying_bu": {"type": "damage_bonus", "value": 1, "native": 2},
		&"san_yuan_ju_qi_gong": {"type": "heal_bonus", "value": 1, "native": 2},
		&"wan_xiang_zhen_dian": {"type": "formation_attune", "value": 1, "native": 2},
	}
	for id: StringName in expected.keys():
		var tpl: CardTemplateClass = _require(id)
		if tpl == null:
			continue
		assert_eq(String(tpl.effect_type), String(expected[id]["type"]),
			"%s 应回填为 %s（留空会让评估落 UNEVALUABLE）" % [id, expected[id]["type"]])
		assert_eq(tpl.effect_value, int(expected[id]["value"]), "%s 主数值应与 GDD 一致" % id)
		assert_eq(tpl.native_effect_value, int(expected[id]["native"]),
			"%s 本命值应与 GDD 一致" % id)


# ---- 3. 攻击类符箓 ----

## 攻击类符箓 → [code]damage_multiplier[/code]，[code]effect_value[/code] 为倍率百分比整数。
func test_attack_talismans_use_damage_multiplier() -> void:
	var expected: Dictionary = {
		&"basic_attack": 100, &"sha_qi_zhan": 150, &"xue_sha_zhang": 100,
		&"jian_bo_zhan": 120, &"dan_xia_jian_qi": 140, &"jin_qian_biao": 80,
		&"bing_leng_ci": 100,
	}
	for id: StringName in expected.keys():
		var tpl: CardTemplateClass = _require(id)
		if tpl == null:
			continue
		assert_eq(String(tpl.effect_type), "damage_multiplier", "%s 应归 damage_multiplier" % id)
		assert_eq(tpl.effect_value, int(expected[id]),
			"%s 的伤害倍率（百分比整数）应与 GDD 一致" % id)


# ---- 4. 概率触发 ----

## 概率触发类——[code]trigger_chance[/code] 基础值与 [code]native_trigger_chance[/code] 本命值。
func test_probabilistic_control_cards_declare_trigger_chance() -> void:
	var expected: Dictionary = {
		&"wan_hun_fan": {"base": 0.3, "native": 0.5},         # GDD §②：30%（屠夜本命 50%）
		&"shuang_po_jian_jue": {"base": 0.25, "native": 0.4}, # GDD §④：25%（姜雪本命 40%）
	}
	for id: StringName in expected.keys():
		var tpl: CardTemplateClass = _require(id)
		if tpl == null:
			continue
		assert_almost_eq(tpl.trigger_chance, float(expected[id]["base"]), 0.0001,
			"%s 的基础触发概率应与 GDD 一致" % id)
		assert_almost_eq(tpl.native_trigger_chance, float(expected[id]["native"]), 0.0001,
			"%s 的本命触发概率应与 GDD 一致（不是 ×1.5）" % id)


# ---- 5. 类型枚举约束 ----

func test_basic_attack_stays_talisman_pending_adr() -> void:
	# GDD 把基础攻击的类型写作「普通」，CardTemplate.CardType 的 6 个枚举无对应项。
	# 取 TALISMAN(5)（一次性·目标敌方单体，语义最近）——若未来 ADR 追加「普通」枚举，
	# 本断言与 EXPECTED_CARD_FIELDS 一并更新即可。
	var tpl: CardTemplateClass = _require(&"basic_attack")
	if tpl == null:
		return
	assert_eq(tpl.type, CardTemplateClass.CardType.TALISMAN,
		"basic_attack 暂取 TALISMAN(5)——GDD「普通」类型待 ADR 追加（DEBT-CBT-018-8）")
	assert_eq(tpl.target_type, &"single_enemy", "基础攻击应指向敌方单体")
