extends "res://tests/unit/inventory/inventory_pill_use_fixture.gd"
## InventoryPillUse 单元测试（一）：数值口径 / 目标选择 / 消耗与回滚。[br]
## [br][b]装置见 [inventory_pill_use_fixture.gd][/b]；文案与拒绝路径的用例在
## [code]test_inventory_pill_use_refusal.gd[/code]（两个文件共用装置，各自回 300 行内）。[br]
##
## 覆盖本轮点名验收：② 丹药使用后数量减一（结算层的存档侧半边）。
##
## 来源: 本轮任务书第 2 条、design/gdd/alchemy-crafting-system.md §1c。


# ═══════════════════════════════════════════════════════════════════════════════
# 数值口径：读模板、走既有结算
# ═══════════════════════════════════════════════════════════════════════════════

func test_heal_amount_comes_from_card_template_effect_value() -> void:
	## 回血量逐字取自模板 [code]effect_value[/code]——本模块不认识「玉灵丹是 8 点」。
	# Arrange
	add_pill("p1", "玉灵丹", 8)
	set_hp(101, 3, 10)
	gsm.removable = [11]
	# Act
	var result: Dictionary = use.use_entry(entry("p1", [11]))
	# Assert
	assert_true(bool(result["ok"]), "应成功")
	assert_eq(int(result["healed"]), 7, "缺口 7 < 回复 8，实得 7")
	assert_eq(int(hp.table[101]["current_hp"]), 10, "应回到满血")
	assert_true(str(result["message"]).contains("回复 7 点生命"),
			"文案应报实际回复量: %s" % str(result["message"]))


func test_template_without_recognizable_heal_is_refused() -> void:
	## 模板存在但效果类型未建模（如「永久 +1 最大生命」）→ 如实说用不了，
	## 不拿 0 点回血冒充成功。
	# Arrange
	add_pill("p2", "九转金丹", 0)
	set_hp(101, 3, 10)
	# Act
	var result: Dictionary = use.use_entry(entry("p2", [21]))
	# Assert
	assert_false(bool(result["ok"]), "无治疗量时应失败")
	assert_false(bool(result["consumed"]), "失败时不应消耗")
	assert_eq(hp.writes, 0, "失败时不应写 HP")
	assert_eq(gsm.removals, [], "失败时不应动收藏")
	assert_eq(int(hp.table[101]["current_hp"]), 3, "血量应原封不动")


func test_heal_is_clamped_to_the_character_gap() -> void:
	## 回复量超过缺口时只补到满血——不虚报被上限吃掉的部分。
	# Arrange
	add_pill("p3", "大还丹", 99)
	set_hp(101, 8, 10)
	gsm.removable = [31]
	# Act
	var result: Dictionary = use.use_entry(entry("p3", [31]))
	# Assert
	assert_eq(int(result["healed"]), 2, "应只报实际补上的 2 点")
	assert_eq(int(hp.table[101]["current_hp"]), 10, "应夹在满血")


func test_single_target_pill_heals_only_one_character() -> void:
	## [code]single_ally[/code] 只治首个需要的人（角色 ID 升序）——另一个有缺口的人
	## 保持原样（多目标选择是出手 UI 的事，本轮按既有先例取首个）。
	# Arrange
	add_pill("p4", "小还丹", 5)
	set_hp(101, 4, 10)
	set_hp(202, 4, 10)
	gsm.removable = [41]
	# Act
	var result: Dictionary = use.use_entry(entry("p4", [41]))
	# Assert
	assert_eq(int(hp.table[101]["current_hp"]), 9, "ID 最小的角色应先被治")
	assert_eq(int(hp.table[202]["current_hp"]), 4, "另一名角色应保持原样")
	assert_eq(int(result["healed"]), 5, "只报一名角色的回复量")


func test_all_allies_pill_heals_everyone_with_a_gap() -> void:
	## [code]all_allies[/code] 治全队可治者——满血的人白拿不到（也无所谓），
	## 有缺口的人各得一份。
	# Arrange
	add_pill("p5", "天罗丹", 4, "all_allies")
	set_hp(101, 4, 10)
	set_hp(202, 6, 10)
	set_hp(303, 10, 10)   # 满血——不该被写
	gsm.removable = [51]
	# Act
	var result: Dictionary = use.use_entry(entry("p5", [51]))
	# Assert
	assert_eq(int(hp.table[101]["current_hp"]), 8, "第一名应回 4 点")
	assert_eq(int(hp.table[202]["current_hp"]), 10, "第二名缺口 4，应正好补满")
	assert_eq(int(hp.table[303]["current_hp"]), 10, "满血角色应保持满血")
	assert_eq(int(result["healed"]), 8, "应汇总两人实际回复量（4 + 4）")


func test_dead_character_is_not_healed_nor_revived() -> void:
	## 阵亡（[code]current_hp <= 0[/code]）既不是治疗对象，也不会被顺带复活——
	## 复活是 [code]DeploymentSystem.revive_character[/code] 的职责。
	# Arrange
	add_pill("p6", "还魂丹", 10, "all_allies")
	set_hp(101, 0, 10)
	# Act
	var result: Dictionary = use.use_entry(entry("p6", [61]))
	# Assert
	assert_false(bool(result["ok"]), "无人可治时不应成功")
	assert_eq(int(hp.table[101]["current_hp"]), 0, "阵亡角色不应被复活")


func test_a_character_without_ledger_record_is_not_treated_as_wounded() -> void:
	## 账本里没有记录 ≠ 零血——那是「从没受过伤」（模板满血基准），治它等于给没缺口
	## 的人加血。与回复点（[code]ExplorationRest.plan[/code]）同一口径。
	# Arrange
	add_pill("p7", "清心丹", 5)
	# Act——一条 HP 记录都没有
	var result: Dictionary = use.use_entry(entry("p7", [71]))
	# Assert
	assert_false(bool(result["ok"]), "无记录时不应视为残血")
	assert_eq(hp.writes, 0, "不应写 HP")


# ═══════════════════════════════════════════════════════════════════════════════
# 消耗：数量减一（平台侧）
# ═══════════════════════════════════════════════════════════════════════════════

func test_successful_use_consumes_exactly_one_instance() -> void:
	## 同名多张时只少一张（[code]instance_ids[/code] 的第一张）。
	# Arrange
	add_pill("p8", "玉灵丹", 8)
	set_hp(101, 3, 10)
	gsm.removable = [81, 82]
	# Act
	var result: Dictionary = use.use_entry(entry("p8", [81, 82]))
	# Assert
	assert_true(bool(result["consumed"]), "应报告已消耗")
	assert_eq(gsm.removals, [81], "应只移除一张（第一张）")
	assert_eq(gsm.removable, [82], "另一张应还在收藏里")


func test_consume_failure_rolls_the_hp_back() -> void:
	## [b]失败不半完成[/b]：取出丹药失败时血量按原值回滚——先把血写上再发现取不出药，
	## 等于白送一次回血。
	# Arrange
	add_pill("p9", "玉灵丹", 8)
	set_hp(101, 3, 10)
	gsm.removable = []   # 移除一定失败
	# Act
	var result: Dictionary = use.use_entry(entry("p9", [91]))
	# Assert
	assert_false(bool(result["ok"]), "取出失败应整体失败")
	assert_false(bool(result["consumed"]), "失败时不应报告已消耗")
	assert_eq(int(hp.table[101]["current_hp"]), 3, "血量应回滚到原值")
	assert_eq(hp.writes, 2, "应写两次：一次治疗、一次回滚")


func test_write_failure_does_not_consume_the_pill() -> void:
	## 写 HP 不可用（[code]write_back[/code] 返回 -1）时丹药原样留在行囊里——
	## 丹药是有限资源，宁可丢掉一次回血也不能凭空吞掉玩家的物品。
	# Arrange
	add_pill("p10", "玉灵丹", 8)
	set_hp(101, 3, 10)
	gsm.removable = [1001]
	hp.unavailable = true
	# Act
	var result: Dictionary = use.use_entry(entry("p10", [1001]))
	# Assert
	assert_false(bool(result["ok"]), "写血失败应整体失败")
	assert_eq(gsm.removals, [], "不应动收藏")
	assert_eq(gsm.removable, [1001], "丹药应原样留在行囊里")
