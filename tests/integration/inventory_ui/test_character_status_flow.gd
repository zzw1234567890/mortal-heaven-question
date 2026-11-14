extends "res://tests/integration/inventory_ui/inventory_screens_fixture.gd"
## 角色状态页端到端测试（真实 Autoload + 真实存档 + 真实界面控件）。[br]
## [br][b]覆盖本轮点名验收[/b]：[br]
##   ② 角色状态数值与境界配置一致——境界/属性行与
##      [code]RealmSystem.realm_table[/code] 及 GSM 字段逐字对照；[br]
##   ③ 阵亡角色标记——[code]DeploymentSystem.mark_unavailable[/code] 后界面出现中文标记；[br]
##   ④ 空态文案——角色位空着时的中文空态。[br]
## [br][b]背包那一半在[/b] [code]test_inventory_screens_flow.gd[/code]
## （两个文件共用 [inventory_screens_fixture.gd]，各自回 300 行内）。[br]
## [br][b]装置见 [inventory_screens_fixture.gd][/b]（快照还原 + 真实写入入口 + 模板就位）。
##
## 来源: 本轮任务书第 2-4 条、先例
## [code]tests/integration/exploration_ui/test_shop_and_rest_node_flow.gd[/code]。


# ═══════════════════════════════════════════════════════════════════════════════
# 境界与属性（点名验收 ②：数值与境界配置一致）
# ═══════════════════════════════════════════════════════════════════════════════

func test_status_page_shows_realm_and_cultivation_from_gsm() -> void:
	## 境界名与修为/上限逐字来自 GSM 与境界配置表。
	# Arrange
	GameStateManager.player.realm = 3
	GameStateManager.player.cultivation = 800
	GameStateManager.player.max_cultivation = 2250
	# Act
	open_page(1)
	var rows: Array = rows_of(status_page())
	var joined: String = " | ".join(rows)
	# Assert
	assert_true(joined.contains("当前境界 · 金丹期"),
			"境界名应取自境界表: %s" % joined)
	assert_true(joined.contains("修为 · 800 / 2250"),
			"修为与上限应取自 GSM 字段: %s" % joined)


func test_status_page_attributes_match_realm_table_exactly() -> void:
	## 属性行与 [code]RealmSystem.realm_table[/code] 那一档逐字一致——本轮的
	## 「角色状态数值与境界配置一致」验收（界面不做任何换算）。
	# Arrange
	GameStateManager.player.realm = 4
	var table_entry: Dictionary = RealmSystem.realm_table[4]
	# Act
	open_page(1)
	status_page().call(&"press_section")  # 境界 → 属性
	var rows: Array = rows_of(status_page())
	# Assert
	var joined: String = " | ".join(rows)
	for key: Variant in table_entry.keys():
		var text_key: String = str(key)
		if text_key == "name":
			continue
		assert_true(joined.contains(str(table_entry[key])),
				"属性 '%s' 的值 %s 应出现在界面上: %s" % [
					text_key, str(table_entry[key]), joined])
	assert_eq(rows.size(), table_entry.size() - 1,
			"属性行数应为该档键数减一（除境界名）")


func test_status_page_attributes_follow_realm_change() -> void:
	## 换境界后属性整体跟着换（界面不缓存旧值）。
	# Arrange
	GameStateManager.player.realm = 1
	open_page(1)
	status_page().call(&"press_section")
	var first: Array = rows_of(status_page())
	# Act
	GameStateManager.player.realm = 2
	status_page().call(&"refresh")
	var second: Array = rows_of(status_page())
	# Assert
	assert_ne(first, second, "换境界后属性行应变化")
	var joined: String = " | ".join(second)
	assert_true(joined.contains(str(RealmSystem.realm_table[2]["max_deploy"])),
			"应显示新境界的出战上限: %s" % joined)


func test_status_page_section_switch_by_arrow_keys() -> void:
	## 方向键左右切换小节（境界 → 属性 → 角色 → 回到境界）。
	# Act
	open_page(1)
	assert_eq(int(status_page().call(&"section_index")), 0, "前置：应从境界小节开始")
	status_page().call(&"_input", key_event(KEY_RIGHT))
	# Assert
	assert_eq(str(status_page().call(&"section_name")), "属性", "→ 应切到属性小节")
	status_page().call(&"_input", key_event(KEY_RIGHT))
	assert_eq(str(status_page().call(&"section_name")), "角色", "再 → 应切到角色小节")
	status_page().call(&"_input", key_event(KEY_RIGHT))
	assert_eq(str(status_page().call(&"section_name")), "境界", "继续 → 应绕回境界")


# ═══════════════════════════════════════════════════════════════════════════════
# 角色名册：生命 / 阵亡（点名验收 ③）
# ═══════════════════════════════════════════════════════════════════════════════

func test_status_page_lists_character_with_ledger_hp() -> void:
	## 角色的生命取自 HP 账本（残血显示残血），攻击取自卡牌模板。
	# Arrange
	give_character(0, CHAR_INSTANCE_A, 3, 10)
	# Act
	open_page(1)
	status_page().call(&"_move_section", 2)
	var rows: Array = rows_of(status_page())
	# Assert
	assert_eq(rows.size(), 1, "应恰有一名角色")
	var row: String = str(rows[0])
	assert_true(row.contains("林渊"), "应显示模板名: %s" % row)
	assert_true(row.contains("生命 3 / 10"), "应显示账本里的残血: %s" % row)
	assert_true(row.contains("可出战"), "存活角色应标为可出战: %s" % row)


func test_status_page_marks_dead_character() -> void:
	## 阵亡角色带中文标记且[b]仍列出[/b]——玩家必须看得到谁倒了。
	# Arrange
	var dead_id: int = give_character(0, CHAR_INSTANCE_A, 0, 10)
	mark_dead(dead_id)
	# Act
	open_page(1)
	status_page().call(&"_move_section", 2)
	var rows: Array = rows_of(status_page())
	# Assert
	assert_eq(rows.size(), 1, "阵亡角色仍应出现在名册里")
	var row: String = str(rows[0])
	assert_true(row.contains("已阵亡"), "应带阵亡标记: %s" % row)
	assert_true(row.contains("生命 0 / 10"), "阵亡角色生命应照实显示 0: %s" % row)


func test_status_page_marks_only_the_dead_one() -> void:
	## 两名角色中只有被标记的那名带阵亡文案——标记不是「所有人都有」的装饰。
	# Arrange
	give_character(0, CHAR_INSTANCE_A, 10, 10)
	var dead_id: int = give_character(1, CHAR_INSTANCE_B, 0, 10)
	mark_dead(dead_id)
	# Act
	open_page(1)
	status_page().call(&"_move_section", 2)
	var rows: Array = rows_of(status_page())
	# Assert
	assert_eq(rows.size(), 2, "两名角色都应列出")
	var dead_rows: Array = []
	for row: Variant in rows:
		if str(row).contains("已阵亡"):
			dead_rows.append(row)
	assert_eq(dead_rows.size(), 1, "应恰有一行带阵亡标记")


func test_dead_marking_works_with_production_wiring() -> void:
	## [b]回归用例[/b]：只按主菜单那样接 GSM + RealmSystem 两个依赖时，阵亡标记
	## 依然出得来。[br]
	## [br][b]为什么值得单测[/b]：名册读取器另外要 [code]DeploymentSystem[/code]，
	## 而生产装配点只接得到那两个——若模型对这条依赖只认注入、没有回落，界面上
	## 全部角色都会显示「可出战」，且[b]不报任何错[/b]（静默失效）。这条用例把
	## 「装配点漏接依赖」这种缺陷钉在测试里，而不是靠人记得接。
	# Arrange
	var dead_id: int = give_character(0, CHAR_INSTANCE_A, 0, 10)
	mark_dead(dead_id)
	# 换上一个「只按主菜单那样接线」的模型（只给 GSM + RealmSystem）
	host.status_model = StatusModelScript.new(GameStateManager, RealmSystem)
	# Act
	open_page(1)
	status_page().call(&"_move_section", 2)
	var rows: Array = rows_of(status_page())
	# Assert
	assert_eq(rows.size(), 1, "应恰有一名角色")
	assert_true(str(rows[0]).contains("已阵亡"),
			"未注入 DeploymentSystem 时阵亡标记仍应可见: %s" % str(rows[0]))


# ═══════════════════════════════════════════════════════════════════════════════
# 空态（点名验收 ④）
# ═══════════════════════════════════════════════════════════════════════════════

func test_status_page_empty_roster_shows_chinese_empty_text() -> void:
	## 角色位空着时给中文空态（与「属性为空」不是同一句）。
	# Act
	open_page(1)
	status_page().call(&"_move_section", 2)  # 切到角色小节
	# Act + Assert
	var message: String = str(status_page().call(&"message_text"))
	assert_false(message.strip_edges().is_empty(), "角色为空时应有空态文案")
	assert_true(message.contains("角色位"), "文案应指出角色位还是空的: %s" % message)


func test_status_page_each_section_has_its_own_empty_text() -> void:
	## 三个小节的空态文案互不相同——「境界读不到」「境界表没给属性」「没人上场」
	## 指向三个不同的下一步，共用一句会让人查错方向。
	# Arrange
	var SectionScript := preload("res://src/ui/inventory/character_status_screen.gd")
	var seen: Array = []
	# Act + Assert
	for section: Variant in SectionScript.SECTIONS:
		var text: String = str((section as Dictionary).get("empty_text", ""))
		assert_false(text.strip_edges().is_empty(),
				"小节 '%s' 应有空态文案" % str((section as Dictionary).get("name", "")))
		assert_false(seen.has(text), "空态文案不应与其他小节重复: %s" % text)
		seen.append(text)
