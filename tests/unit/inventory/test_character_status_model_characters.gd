extends "res://tests/unit/inventory/character_status_model_fixture.gd"
## CharacterStatusModel 单元测试（二）：角色名册 / 生命 / 阵亡标记。[br]
## [br][b]装置见 [character_status_model_fixture.gd][/b]；境界与属性的用例在
## [code]test_character_status_model.gd[/code]
## （两个文件共用装置，各自回 300 行内）。[br]
##
## 覆盖本轮点名验收：③ 阵亡角色标记。


func test_character_hp_comes_from_the_hp_ledger_when_present() -> void:
	## 有 HP 记录时显示记账值（残血）——不是模板满血基准。
	# Arrange
	add_character(0, 101, "林渊", 10, 2)
	hp.table = {101: {"current_hp": 3, "max_hp": 10}}
	# Act
	var entry: Dictionary = model.characters()[0]
	# Assert
	assert_eq(int(entry["current_hp"]), 3, "应显示账本里的残血")
	assert_eq(str(entry["hp_text"]), "3 / 10", "生命行应为 3 / 10")
	assert_true(bool(entry["hp_known"]), "有账本记录时应标为已知")


func test_character_hp_falls_back_to_template_baseline_when_unrecorded() -> void:
	## 无 HP 记录时用模板 base_hp 作分子分母，并把 hp_known 标为 false——
	## 让「满血」与「没数据」在界面上可区分。
	# Arrange
	add_character(0, 202, "苏牧", 12, 3)
	# Act
	var entry: Dictionary = model.characters()[0]
	# Assert
	assert_eq(str(entry["hp_text"]), "12 / 12", "无记录时应回退模板基准")
	assert_false(bool(entry["hp_known"]), "无记录时应标为未记账")


func test_dead_character_is_marked_and_still_listed() -> void:
	## 阵亡角色[b]照实列出且带中文标记[/b]——不隐藏（玩家必须看得到谁倒了，
	## GDD combat-system.md §7 的死亡跨场持久）。
	# Arrange
	add_character(0, 303, "赵四", 10, 2)
	deployment.unavailable = [303]
	hp.table = {303: {"current_hp": 0, "max_hp": 10}}
	# Act
	var roster: Array = model.characters()
	# Assert
	assert_eq(roster.size(), 1, "阵亡角色仍应出现在名册里")
	assert_true(bool((roster[0] as Dictionary)["is_dead"]), "应带阵亡标记")
	assert_eq(str((roster[0] as Dictionary)["status_text"]), "已阵亡（不可出战）",
			"阵亡标记应是可读的中文")
	assert_eq(int((roster[0] as Dictionary)["current_hp"]), 0,
			"阵亡角色的生命应照实显示 0（不夹到 1 冒充存活）")


func test_alive_character_has_available_status_text() -> void:
	## 可出战角色带正面的中文状态——不用「没有标记」来表达「还活着」。
	# Arrange
	add_character(0, 404, "钱五", 10, 2)
	# Act
	var entry: Dictionary = model.characters()[0]
	# Assert
	assert_false(bool(entry["is_dead"]), "未列入不可用名单的角色不应被标阵亡")
	assert_eq(str(entry["status_text"]), "可出战", "存活角色应有明确的可出战标记")


func test_dead_count_counts_only_marked_characters() -> void:
	## 阵亡计数与逐条标记同一判据（面板顶部摘要与列表不会互相打架）。
	# Arrange
	add_character(0, 501, "甲", 10, 2)
	add_character(1, 502, "乙", 10, 2)
	add_character(2, 503, "丙", 10, 2)
	deployment.unavailable = [502]
	# Act + Assert
	assert_eq(model.dead_count(), 1, "应恰有 1 名阵亡")


func test_characters_keep_slot_order_and_skip_empty_slots() -> void:
	## 名册按角色位顺序输出且跳过空位——界面上的次序与备战面板一致。
	# Arrange
	add_character(2, 601, "后排甲", 10, 2)
	add_character(0, 602, "前排乙", 10, 2)
	# Act
	var roster: Array = model.characters()
	# Assert
	assert_eq(roster.size(), 2, "空位不应产出条目")
	assert_eq(int((roster[0] as Dictionary)["slot_index"]), 0,
			"第 1 条应是 0 号角色位")
	assert_eq(str((roster[0] as Dictionary)["name"]), "前排乙",
			"应按角色位顺序而非插入顺序")


func test_character_attack_and_name_come_from_card_template() -> void:
	## 攻击力与名字取自卡牌模板（本模型不推算角色属性）。
	# Arrange
	add_character(0, 701, "陆青", 14, 5)
	# Act
	var entry: Dictionary = model.characters()[0]
	# Assert
	assert_eq(int(entry["attack"]), 5, "攻击力应取自模板 base_attack")
	assert_eq(str(entry["name"]), "陆青", "名字应取自模板")


func test_no_characters_yields_empty_roster() -> void:
	## 角色位全空 → 空名册（面板走空态文案，不产出占位行）。
	# Arrange + Act + Assert
	assert_eq(model.characters(), [], "无角色时名册应为空")
	assert_eq(model.dead_count(), 0, "无角色时阵亡数应为 0")


func test_missing_card_system_yields_empty_roster() -> void:
	## 卡牌系统不可用（模板查不到）→ 名册为空，不崩。
	# Arrange
	add_character(0, 801, "无卡系统", 10, 2)
	model.set_dependencies(gsm, null, null, deployment, null)
	# Act + Assert
	assert_eq(model.characters(), [], "卡牌系统不可用时应返回空名册")


func test_repeated_reads_are_consistent() -> void:
	## 连读两次结果一致（零缓存 + 纯读）——界面刷新不该让数值跳动。
	# Arrange
	add_character(0, 901, "稳定", 10, 2)
	hp.table = {901: {"current_hp": 6, "max_hp": 10}}
	# Act
	var first: Array = model.characters()
	var second: Array = model.characters()
	# Assert
	assert_eq(first, second, "两次读取应完全一致")
