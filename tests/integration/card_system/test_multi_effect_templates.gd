extends GutTest
## 多效果卡模板资产验收测试（DEBT-CBT-018-10 第一阶段）。[br]
## [br][b]背景[/b]：[code]CardTemplate[/code] 原先只有一套扁平效果字段（一卡一效果），
## 本轮新增 [code]effects: Array[EffectEntry][/code] 承载多条异质效果。本文件锁住三件事：[br]
##   1. [b]示范卡迁移正确[/b]：血杀掌 = 造成 ATK×1.0 伤害（打出即生效，[code]single_enemy[/code]）
##      + 击杀后回复 2 HP（[code]trigger="kill"[/code]，[code]self[/code]），数值与 GDD §② 一致；[br]
##   2. [b]迁移不丢旧口径[/b]：迁移后卡片的伤害仍等于旧扁平写法（ATK=4 → 4），治疗按击杀触发才出；
##   3. [b]未迁移的卡不受影响[/b]：其余模板 [code]effects[/code] 为空且扁平字段照旧读得到
##      （逐张在 [code]test_template_assets.gd[/code] / [code]test_template_effect_vocabulary.gd[/code] 已锁，
##      这里只做「没有任何卡被顺手迁移」的整体断言）。[br]
## [br][b]数值唯一真理来源[/b]：[code]design/gdd/identity-selection-system.md[/code] §②
## 「初始卡牌详情」表：血杀掌「造成ATK×1.0伤害，击杀后回复2HP」。[br]
## 加载方式与 [code]test_template_assets.gd[/code] 相同（独立实例 + 重试驱动，避免 Autoload 污染）。

const CS_SCRIPT: GDScript = preload("res://src/core/card_system/card_system.gd")
const CardTemplateClass: GDScript = preload("res://src/core/card_system/card_template.gd")
const EffectEntryClass: GDScript = preload("res://src/core/card_system/effect_entry.gd")
const EvaluatorClass: GDScript = preload("res://src/feature/card_effect_engine/card_effect_evaluator.gd")
const SnapshotClass: GDScript = preload("res://src/feature/card_effect_engine/game_state_snapshot.gd")

## 本阶段唯一迁到 [code]effects[/code] 的卡——其余 36 张走旧扁平通道。
const MIGRATED_IDS: Array[StringName] = [&"xue_sha_zhang"]

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


## 目标 1：HP 5/10、ATK 4；出血的那一刀按 ATK=4 打。
func _make_snapshot() -> RefCounted:
	return SnapshotClass.build({
		1: {"hp": 5, "max_hp": 10, "atk": 4, "statuses": [], "binding_multiplier": 1.0},
	})


# ---- 1. 示范卡迁移：两条效果的字段与 GDD 一致 ----

func test_xue_sha_zhang_declares_two_effects() -> void:
	var tpl: CardTemplateClass = cs.get_template(&"xue_sha_zhang")
	assert_not_null(tpl, "应存在 xue_sha_zhang 模板")
	if tpl == null:
		return
	assert_eq(tpl.effects.size(), 2, "血杀掌应声明 2 条效果（伤害 + 击杀回血）")
	var damage: EffectEntryClass = tpl.effects[0]
	var heal: EffectEntryClass = tpl.effects[1]
	assert_eq(String(damage.effect_type), "damage_multiplier", "首条应为伤害倍率")
	assert_eq(damage.value, 100, "GDD §②：ATK×1.0 → 倍率百分比整数 100")
	assert_eq(damage.trigger, EffectEntryClass.TRIGGER_ON_PLAY, "首条打出即生效")
	assert_eq(damage.target, &"single_enemy", "首条指向敌方单体")
	assert_eq(String(heal.effect_type), "heal", "次条应为治疗")
	assert_eq(heal.value, 2, "GDD §②：击杀后回复 2 HP")
	assert_eq(heal.trigger, EffectEntryClass.TRIGGER_KILL, "次条为击杀触发")
	assert_eq(heal.target, &"self", "回复对象是自己")


func test_migrated_card_has_no_flat_effect_tombstone() -> void:
	# effects 非空时扁平字段被忽略——留着旧值会让「哪份是真源」在代码评审里永远吵不清。
	# 故迁移时一并清空扁平效果字段（本卡此前是 effect_type=damage_multiplier / effect_value=100）。
	var tpl: CardTemplateClass = cs.get_template(&"xue_sha_zhang")
	if tpl == null:
		return
	assert_eq(String(tpl.effect_type), "",
		"迁移后不应保留扁平 effect_type（effects 非空时它被忽略，留着只是误导）")
	assert_eq(tpl.effect_value, 0, "迁移后不应保留扁平 effect_value")


# ---- 2. 迁移后数值口径不变（伤害同旧写法、治疗走击杀触发） ----

func test_migrated_damage_matches_old_flat_behaviour() -> void:
	var tpl: CardTemplateClass = cs.get_template(&"xue_sha_zhang")
	if tpl == null:
		return
	var evaluator: RefCounted = EvaluatorClass.new()
	var play: RefCounted = evaluator.evaluate_effects(tpl, 1, _make_snapshot())
	assert_eq(play.damage, 4, "ATK=4 × 1.0 → 4 伤害（与迁移前扁平写法一致）")
	assert_almost_eq(play.damage_multiplier, 1.0, 0.0001, "倍率仍是 ×1.0")
	assert_eq(play.healing, 0, "击杀回血不得计入打出结算（干跑不知道会不会击杀）")


func test_migrated_kill_heal_requires_kill_trigger() -> void:
	var tpl: CardTemplateClass = cs.get_template(&"xue_sha_zhang")
	if tpl == null:
		return
	var evaluator: RefCounted = EvaluatorClass.new()
	var kill: RefCounted = evaluator.evaluate_effects(tpl, 1, _make_snapshot(),
		EffectEntryClass.TRIGGER_KILL)
	assert_eq(kill.healing, 2, "显式取击杀触发 → 回复 2 HP（GDD §②）")
	assert_eq(kill.damage, 0, "击杀触发条目不含伤害（伤害在打出条目里）")


# ---- 3. 未被迁移的卡：effects 为空，旧扁平通道仍工作 ----

func test_only_demonstration_card_is_migrated() -> void:
	var migrated: Array = []
	for id: StringName in cs.templates.keys():
		var tpl: CardTemplateClass = cs.templates[id]
		if tpl.effects.size() > 0:
			migrated.append(id)
	assert_eq(migrated, MIGRATED_IDS,
		"本阶段只迁移示范卡（血杀掌）——其余 36 张留待后续批次")


func test_unmigrated_card_still_reads_flat_fields() -> void:
	var tpl: CardTemplateClass = cs.get_template(&"sha_qi_zhan")
	assert_not_null(tpl, "应存在 sha_qi_zhan 模板")
	if tpl == null:
		return
	assert_eq(tpl.effects.size(), 0, "未迁移卡 effects 应为空")
	assert_eq(String(tpl.effect_type), "damage_multiplier", "未迁移卡仍走扁平 effect_type")
	assert_eq(tpl.effect_value, 150, "未迁移卡仍走扁平 effect_value（GDD §②：ATK×1.5）")
	var evaluator: RefCounted = EvaluatorClass.new()
	assert_eq(evaluator.evaluate_effects(tpl, 1, _make_snapshot()).damage, 6,
		"未迁移卡经多效果入口评估仍得 4 × 1.5 = 6（旧行为逐字节不变）")
