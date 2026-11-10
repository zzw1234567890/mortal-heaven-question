extends GutTest
## 多效果卡模板资产验收测试（DEBT-CBT-018-10 第一 / 第二阶段）。[br]
## [br][b]背景[/b]：[code]CardTemplate[/code] 原先只有一套扁平效果字段（一卡一效果），
## 本轮新增 [code]effects: Array[EffectEntry][/code] 承载多条异质效果。本文件锁住五件事：[br]
##   1. [b]示范卡迁移正确[/b]：血杀掌 = 造成 ATK×1.0 伤害（打出即生效，[code]single_enemy[/code]）
##      + 击杀后回复 2 HP（[code]trigger="kill"[/code]，[code]self[/code]），数值与 GDD §② 一致；[br]
##   2. [b]迁移不丢旧口径[/b]：迁移后卡片的伤害仍等于旧扁平写法（ATK=4 → 4），治疗按击杀触发才出；
##   3. [b]未迁移的卡不受影响[/b]：其余模板 [code]effects[/code] 为空且扁平字段照旧读得到；[br]
##   4. [b]迁移批次白名单[/b]：全库只有 [constant MIGRATED_IDS] 里的卡有 [code]effects[/code]，
##      且扁平效果字段已清空（不留「两处都有值」的墓碑）。[br]
##   5. [b]条目自洽[/b]：全库每条效果都有类型、正数值、合法 [code]trigger[/code]
##      ——资产层只查扁平字段，迁移卡的条目数值否则无人校验。[br]
## [br][b]数值唯一真理来源[/b]：[code]design/gdd/identity-selection-system.md[/code] §②
## 「初始卡牌详情」表：血杀掌「造成ATK×1.0伤害，击杀后回复2HP」。[br]
## 加载方式与 [code]test_template_assets.gd[/code] 相同（独立实例 + 重试驱动，避免 Autoload 污染）。

const CS_SCRIPT: GDScript = preload("res://src/core/card_system/card_system.gd")
const CardTemplateClass: GDScript = preload("res://src/core/card_system/card_template.gd")
const EffectEntryClass: GDScript = preload("res://src/core/card_system/effect_entry.gd")
const EvaluatorClass: GDScript = preload("res://src/feature/card_effect_engine/card_effect_evaluator.gd")
const SnapshotClass: GDScript = preload("res://src/feature/card_effect_engine/game_state_snapshot.gd")

## 已迁到 [code]effects[/code] 的卡——其余 30 张仍走旧扁平通道。[br]
## [br]第一批（第一 / 第二阶段）：血杀掌（示范卡）+ 6 张——减伤 2 / 治疗 2 / 倍率 2，
## 三类各取两张，只覆盖「已建模且已有执行端」的效果类别；其余类别（增益/控制/抽牌/阵法）
## 等各自 epic 落地后再迁，避免迁完仍无人消费。
const MIGRATED_IDS: Array[StringName] = [
	&"basic_attack", &"huan_hua_mi_zong_bu", &"ku_mu_feng_chun_jue",
	&"pei_yuan_dan", &"sha_qi_zhan", &"xue_sha_zhang", &"yan_yun_bu",
]

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


## 迁移卡不得留「扁平效果字段墓碑」——[code]effects[/code] 非空时扁平字段被忽略，
## 留着旧值会让「哪份是真源」在代码评审里永远吵不清。[br]
## [br][b]逐张检查全批次[/b]（不只示范卡）：7 张卡各自此前都有扁平效果值，
## 任何一张漏清都会造成「改了列表但旧值还在」的隐性双源。[br]
## [br][b]不清 [code]target_type[/code][/b]：它是「这张卡打谁」的卡片级描述，
## 不属于单条效果（示范卡迁移时即保留，见 [code]xue_sha_zhang.tres[/code]）。
func test_migrated_cards_have_no_flat_effect_tombstone() -> void:
	for id: StringName in MIGRATED_IDS:
		var tpl: CardTemplateClass = cs.get_template(id)
		assert_not_null(tpl, "应存在已迁移模板 %s" % id)
		if tpl == null:
			continue
		assert_eq(String(tpl.effect_type), "",
			"%s 迁移后不应保留扁平 effect_type（effects 非空时它被忽略，留着只是误导）" % id)
		assert_eq(tpl.effect_value, 0, "%s 迁移后不应保留扁平 effect_value" % id)
		assert_eq(tpl.native_effect_value, 0, "%s 迁移后不应保留扁平 native_effect_value" % id)


## 迁移批次的[b]手段与效果类型逐张对齐 GDD[/b]。[br]
## [br]减伤 / 倍率四张已在 [code]test_template_effect_vocabulary.gd[/code] 经统一取值口径锁过
## （本文件不重复），这里补该文件未覆盖的两张治疗卡：培元丹（§⑤ 回复3点生命，[code]target=self[/code]）
## 与枯木逢春诀（§① 每回合回复1点，迁移前未写 [code]target_type[/code]，故 [code]target[/code] 留空）。[br]
## [br][b]目标字段是迁移等价性的关键[/b]：条目 [code]target[/code] 由扁平 [code]target_type[/code] 映射而来，
## 漏搬会让执行端的落点裁定改变（留空 = 未声明，走施法者兜底；写成别的值则可能被跳过）。[br]
## [br][b]血杀掌不在本表[/b]：它是唯一的双条目卡，由上文两条用例单独锁定。
func test_migrated_batch_primary_effects_match_gdd() -> void:
	var expected: Dictionary = {
		&"pei_yuan_dan": {"type": "heal", "value": 3, "target": &"self"},   # GDD §⑤：回复3点生命
		&"ku_mu_feng_chun_jue": {"type": "heal", "value": 1, "target": &""}, # GDD §①：每回合回复1点
	}
	for id: StringName in expected.keys():
		var tpl: CardTemplateClass = cs.get_template(id)
		assert_not_null(tpl, "应存在已迁移模板 %s" % id)
		if tpl == null:
			continue
		assert_eq(tpl.effects.size(), 1, "%s 应声明 1 条效果" % id)
		if tpl.effects.size() == 0:
			continue
		var entry: EffectEntryClass = tpl.effects[0]
		assert_eq(String(entry.effect_type), String(expected[id]["type"]), "%s 的效果类型应与 GDD 一致" % id)
		assert_eq(entry.value, int(expected[id]["value"]), "%s 的数值应与 GDD 一致" % id)
		assert_eq(entry.trigger, EffectEntryClass.TRIGGER_ON_PLAY, "%s 应为打出即生效" % id)
		assert_eq(entry.target, StringName(expected[id]["target"]),
			"%s 的目标应与迁移前扁平 target_type 一致（留空＝未声明，不臆造）" % id)


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

## 全库有 [code]effects[/code] 的卡必须[b]恰好[/b]是本批次白名单——多一张即「顺手迁移」
## （可能绕过了某个执行端尚未接线的类别），少一张即漏迁。[br]
## [br][b]比较前排序[/b]：注册表键序取决于加载顺序（目录遍历），与迁移批次无关。
func test_only_whitelisted_cards_are_migrated() -> void:
	var migrated: Array = []
	for id: StringName in cs.templates.keys():
		var tpl: CardTemplateClass = cs.templates[id]
		if tpl.effects.size() > 0:
			migrated.append(id)
	migrated.sort()
	var expected: Array = MIGRATED_IDS.duplicate()
	expected.sort()
	assert_eq(migrated, expected,
		"只有本批次白名单的卡可带 effects——其余 %d 张留待后续批次"
		% [cs.templates.size() - MIGRATED_IDS.size()])


## 未迁移卡（[code]effects[/code] 为空）仍走扁平字段，且经多效果入口评估[b]逐位不变[/b]。[br]
## [br]取 [code]dan_xia_jian_qi[/code]（GDD §⑤：ATK ×1.4）——[code]sha_qi_zhan[/code]
## 已在本批次迁到 [code]effects[/code]，不再是「未迁移卡」的代表。
func test_unmigrated_card_still_reads_flat_fields() -> void:
	var tpl: CardTemplateClass = cs.get_template(&"dan_xia_jian_qi")
	assert_not_null(tpl, "应存在 dan_xia_jian_qi 模板")
	if tpl == null:
		return
	assert_eq(tpl.effects.size(), 0, "未迁移卡 effects 应为空")
	assert_eq(String(tpl.effect_type), "damage_multiplier", "未迁移卡仍走扁平 effect_type")
	assert_eq(tpl.effect_value, 140, "未迁移卡仍走扁平 effect_value（GDD §⑤：ATK×1.4）")
	var evaluator: RefCounted = EvaluatorClass.new()
	assert_eq(evaluator.evaluate_effects(tpl, 1, _make_snapshot()).damage, 5,
		"未迁移卡经多效果入口评估仍得 4 × 1.4 = 5（floor，旧行为逐字节不变）")


# ---- 4. 条目自洽：全库逐条校验（资产层盲区修补） ----

## 每条效果都要有类型与正数值，[code]trigger[/code] 只能是空（打出即生效）或 [code]kill[/code]。[br]
## [br][b]为什么必须有这条[/b]：[code]test_template_assets.gd[/code] 的「有 effect_type 必有正
## effect_value」只覆盖[b]扁平[/b]字段；迁移卡清空扁平字段后，其条目数值会变成无人校验的盲区
## ——写 0 也会静默评估成 0，而上面各例只锁了 7 张白名单卡，将来新增迁移批次不会自动被覆盖。[br]
## [br]放在本文件而非资产测试文件：本文件就是「多效果承载」的家，且
## [code]test_template_assets.gd[/code] 已到 300 行软上限附近。
func test_effects_entries_are_self_consistent() -> void:
	var checked: int = 0
	for id: StringName in cs.templates.keys():
		var tpl: CardTemplateClass = cs.templates[id]
		for i: int in range(tpl.effects.size()):
			checked += 1
			var entry: EffectEntryClass = tpl.effects[i]
			assert_not_null(entry, "%s 的第 %d 条效果不应为空" % [id, i])
			if entry == null:
				continue
			var etype: String = String(entry.effect_type)
			assert_false(etype.is_empty(), "%s 的第 %d 条效果应声明 effect_type" % [id, i])
			assert_true(entry.value > 0,
				"%s 的第 %d 条效果（%s）数值应 > 0（实际 %d）" % [id, i, etype, entry.value])
			assert_true(entry.trigger == EffectEntryClass.TRIGGER_ON_PLAY
					or entry.trigger == EffectEntryClass.TRIGGER_KILL,
				"%s 的第 %d 条效果 trigger 应为空或 kill（实际 '%s'）"
				% [id, i, entry.trigger])
	assert_true(checked >= MIGRATED_IDS.size(),
		"至少应校验到白名单内每条效果（实际 %d 条）" % checked)
