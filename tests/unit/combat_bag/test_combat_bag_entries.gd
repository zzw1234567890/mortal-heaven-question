extends "res://tests/unit/combat_bag/combat_bag_fixture.gd"
## CombatBagEntries 单元测试——「真实收藏 → 一列可确认条目」的取数半边。[br]
## [br][b]本条最重要的断言是「不硬编码」[/b]：往收藏里放一张，条目就多一条；
## 拿走一张，条目就少一条。任何写死的物品清单都会在这里露馅。[br]
## [br][b]判据不在这里重写[/b]：本模块只把取数结果喂给 [CombatBagRules]——
## 故断言的是「条目上带着正确的 reason」，而不是逐条重算一遍可用性。[br]
## [br]装置见 [combat_bag_fixture.gd]。
##
## 来源: 本轮任务书第 1 条（读真实收藏）/ 第 3 条（不可用写明原因）。

const EvaluatorScript := preload("res://src/feature/card_effect_engine/card_effect_evaluator.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# 条目来自真实收藏（不硬编码）
# ═══════════════════════════════════════════════════════════════════════════════

func test_empty_collection_yields_no_entries() -> void:
	# Arrange——收藏空、场上有人
	set_hp(CHAR_A, 5, 10)
	# Act
	var rows: Array = entries.call(&"entries")
	# Assert
	assert_eq(rows.size(), 0, "空收藏不该凭空生出条目")


func test_entry_appears_after_card_enters_collection() -> void:
	## 收藏里放一张回春丹 → 条目里就多一条，且模板/费用/效果数值逐项来自模板。
	# Arrange
	set_hp(CHAR_A, 5, 10)
	own(PILL_HEAL, 71)
	# Act
	var row: Dictionary = entry_of(PILL_HEAL)
	# Assert
	assert_false(row.is_empty(), "收藏里有回春丹，条目里就该有它")
	assert_eq(str(row["name"]), "回春丹", "名称来自模板")
	assert_eq(int(row["count"]), 1, "数量取自收藏里的实例数")
	assert_eq(int(row["instance_id"]), 71, "实例 ID 指向真实那一张")
	assert_eq(int(row["cost"]), 1, "费用来自模板 cost")
	assert_eq(int(row["effect_value"]), 4, "治疗量来自模板 effect_value 现算")
	assert_eq(str(row["target_type"]), "single_ally", "目标词来自模板")
	assert_eq(str(row["kind"]), "pill", "丹药归 pill 一类")


func test_entry_disappears_after_card_leaves_collection() -> void:
	# Arrange
	set_hp(CHAR_A, 5, 10)
	own(PILL_HEAL, 72)
	assert_false(entry_of(PILL_HEAL).is_empty(), "前置：条目已出现")
	# Act——把这张移出收藏（走桩的移出入口）
	gsm.call(&"remove_card_from_collection", 72)
	# Assert
	assert_true(entry_of(PILL_HEAL).is_empty(), "收藏里没有的卡不该还列在行囊里")


func test_same_template_many_copies_merge_into_one_row() -> void:
	## 同名多张合并成一行「×N」（GDD card-system.md §边界：收藏池允许同名多张）。
	# Arrange
	set_hp(CHAR_A, 5, 10)
	own(PILL_HEAL, 81)
	own(PILL_HEAL, 82)
	own(PILL_HEAL, 83)
	# Act
	var row: Dictionary = entry_of(PILL_HEAL)
	# Assert
	assert_eq(int(row["count"]), 3, "三张同名应合成一行 ×3")
	assert_eq(entries.call(&"entries").size(), 1, "不该铺成三行重复项")


func test_pills_come_before_artifacts() -> void:
	## 丹药在前、法宝在后——界面分组的稳定次序（同名同稀有度时尤其重要）。
	# Arrange
	set_hp(CHAR_A, 5, 10)
	own(ARTIFACT_BUFF, 91)
	own(PILL_HEAL, 92)
	# Act
	var rows: Array = entries.call(&"entries")
	# Assert
	assert_eq(rows.size(), 2, "应有两类各一条")
	assert_eq(str((rows[0] as Dictionary)["kind"]), "pill", "丹药应排在前面")
	assert_eq(str((rows[1] as Dictionary)["kind"]), "artifact", "法宝应排在后面")


func test_pill_not_in_collection_is_not_listed() -> void:
	## 只持有法宝时不该出现丹药行——本模块不按分类表补齐空行。
	# Arrange
	set_hp(CHAR_A, 5, 10)
	own(ARTIFACT_BUFF, 93)
	# Act / Assert
	assert_true(entry_of(PILL_HEAL).is_empty(), "没持有的丹药不该出现")


# ═══════════════════════════════════════════════════════════════════════════════
# 可用性结论随场上情势而变（取数 → 判据的接线正确）
# ═══════════════════════════════════════════════════════════════════════════════

func test_pill_is_usable_when_someone_is_hurt() -> void:
	# Arrange
	set_hp(CHAR_A, 5, 10)
	own(PILL_HEAL, 101)
	# Act
	var row: Dictionary = entry_of(PILL_HEAL)
	# Assert
	assert_true(bool(row["usable"]), "有人缺血的丹应可用")
	assert_eq(str(row["reason"]), "", "可用时不该带理由句")


func test_pill_is_disabled_when_everyone_is_at_full_hp() -> void:
	## 满血吃药是无意义操作——候选池滤掉无缺口者，条目据此灰显并写明原因。
	# Arrange
	set_hp(CHAR_A, 10, 10)
	own(PILL_HEAL, 102)
	# Act
	var row: Dictionary = entry_of(PILL_HEAL)
	# Assert
	assert_false(bool(row["usable"]), "无人缺血时丹药应不可用")
	assert_eq(str(row["reason"]), RulesScript.TEXT_NOBODY_NEEDS, "应写明「此刻无人需要」")


func test_pill_is_disabled_when_cost_not_affordable() -> void:
	## 灵力不足 → 灰显并写明「需要几点，当前几点」（点名验收 ③ 的取数侧）。
	# Arrange
	set_hp(CHAR_A, 5, 10)
	own(PILL_HEAL, 103)
	cost.current = 0
	# Act
	var row: Dictionary = entry_of(PILL_HEAL)
	# Assert
	assert_false(bool(row["usable"]), "灵力不足时丹药应不可用")
	assert_eq(str(row["reason"]), RulesScript.TEXT_NO_COST % [1, 0],
			"应写明需要 1 点、当前 0 点")
	assert_true(str(row["text"]).contains("灵力不足"),
			"原因应写进行文本（色盲可读）：%s" % str(row["text"]))


func test_artifact_is_usable_even_when_everyone_is_at_full_hp() -> void:
	## 法宝加的是攻防，满血也吃得着——它的候选池是全部存活者。
	# Arrange
	set_hp(CHAR_A, 10, 10)
	own(ARTIFACT_BUFF, 104)
	# Act
	var row: Dictionary = entry_of(ARTIFACT_BUFF)
	# Assert
	assert_true(bool(row["usable"]), "满血时法宝仍应可用")
	assert_eq(str(row["effect_kind"]), str(EvaluatorScript.EffectCategory.BUFF),
			"法宝的效果类别应是增益")


func test_pill_with_unmodelled_effect_is_disabled_with_reason() -> void:
	## 九转金丹（永久加最大生命）本轮不建模 → 灰显且写明「效用尚未参透」，
	## 而不是给一个点了没反应的可用行。
	# Arrange
	set_hp(CHAR_A, 5, 10)
	own(PILL_INERT, 105)
	# Act
	var row: Dictionary = entry_of(PILL_INERT)
	# Assert
	assert_false(bool(row["usable"]), "效果未建模的丹应不可用")
	assert_eq(str(row["reason"]), RulesScript.TEXT_PILL_UNKNOWN, "应写明「效用尚未参透」")


func test_entry_without_template_is_disabled_with_reason() -> void:
	## 收藏里有条目、模板查不到（卡牌系统还没加载完 / 图谱丢了）→ 灰显并写明原因，
	## 不臆造一个名字与数值。
	# Arrange
	set_hp(CHAR_A, 5, 10)
	(gsm.collection["owned_cards"] as Array).append({
		"card_instance_id": 106, "template_id": "pill_ghost",
	})
	(gsm.collection["owned_cards"] as Array).append({
		"card_instance_id": 107, "template_id": str(PILL_HEAL.get("card_id")),
	})
	# Act——模板缺失的那一条被 [InventoryModel] 直接跳过（它查不到类型），
	# 故这里断言的是「不崩、不多出臆造行」
	var rows: Array = entries.call(&"entries")
	# Assert
	assert_eq(rows.size(), 1, "查不到模板的实例不应生成行（不臆造名称）")
	assert_eq(str((rows[0] as Dictionary)["template_id"]),
			str(PILL_HEAL.get("card_id")), "留下的应是模板查得到的那一条")


# ═══════════════════════════════════════════════════════════════════════════════
# 目标候选池（丹药只列有缺口者；法宝列全部存活者）
# ═══════════════════════════════════════════════════════════════════════════════

func test_pill_targets_skip_full_hp_and_keep_the_hurt() -> void:
	# Arrange
	set_hp(CHAR_A, 10, 10)  # 满血
	set_hp(CHAR_B, 4, 10)   # 有缺口
	# Act
	var pool: Array = entries.call(&"targets", true)
	# Assert
	assert_eq(pool.size(), 1, "丹药候选池只列有缺口者")
	assert_eq(int((pool[0] as Dictionary)["character_id"]), CHAR_B,
			"留下的应是有缺口的那一位")


func test_artifact_targets_keep_everyone_alive() -> void:
	# Arrange
	set_hp(CHAR_A, 10, 10)
	set_hp(CHAR_B, 4, 10)
	# Act
	var pool: Array = entries.call(&"targets", false)
	# Assert
	assert_eq(pool.size(), 2, "法宝候选池列全部存活者")


func test_targets_are_sorted_by_character_id() -> void:
	## 顺序稳定（ID 升序）——默认目标取首个时才有确定的答案。
	# Arrange
	set_hp(CHAR_B, 4, 10)
	set_hp(CHAR_A, 3, 10)
	# Act
	var pool: Array = entries.call(&"targets", true)
	# Assert
	assert_eq(int((pool[0] as Dictionary)["character_id"]), CHAR_A,
			"候选池应按 ID 升序（先 A 后 B）")
	assert_eq(int((pool[1] as Dictionary)["character_id"]), CHAR_B, "第二位应是 B")


func test_targets_carry_hp_for_the_row_label() -> void:
	## 候选行带当前 / 上限 HP——界面据此显示缺口（本模块不臆造名字，只用 ID 兜底）。
	# Arrange
	set_hp(CHAR_A, 3, 10)
	# Act
	var row: Dictionary = (entries.call(&"targets", true) as Array)[0]
	# Assert
	assert_eq(int(row["current_hp"]), 3, "应带当前 HP")
	assert_eq(int(row["max_hp"]), 10, "应带上限 HP")
	assert_eq(str(row["label"]), RulesScript.target_label(CHAR_A), "标签走判据模块的兜底措辞")


func test_dead_character_is_not_a_target() -> void:
	# Arrange——把 B 打到 0（真实落库路径：阵亡）
	set_hp(CHAR_B, 4, 10)
	roster.call(&"apply_damage", CHAR_B, 99)
	# Act
	var pool: Array = entries.call(&"targets", false)
	# Assert
	assert_eq(pool.size(), 0, "已阵亡者不该出现在候选池里")


func test_no_roster_means_no_targets_and_disabled_rows() -> void:
	## 状态表缺失（战斗系统未接线）→ 候选池空 → 条目一律灰显并写「无人需要」，
	## 而不是给一个点了落不下去的可用行。
	# Arrange——不摆任何角色，只往收藏放一枚丹
	own(PILL_HEAL, 108)
	# Act
	var row: Dictionary = entry_of(PILL_HEAL)
	# Assert
	assert_eq((entries.call(&"targets", true) as Array).size(), 0, "无状态表则无候选")
	assert_false(bool(row["usable"]), "无候选时丹药应不可用")
	assert_eq(str(row["reason"]), RulesScript.TEXT_NOBODY_NEEDS, "应写明原因")
