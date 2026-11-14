extends "res://tests/unit/inventory/character_status_model_fixture.gd"
## CharacterStatusModel 单元测试（一）：境界与修为 / 属性与境界配置表一致。[br]
## [br][b]装置见 [character_status_model_fixture.gd][/b]；角色名册与阵亡标记的用例
## 在 [code]test_character_status_model_characters.gd[/code]
## （两个文件共用装置，各自回 300 行内）。[br]
##
## 覆盖本轮点名验收：② 角色状态数值与境界配置一致。


# ═══════════════════════════════════════════════════════════════════════════════
# 境界与修为
# ═══════════════════════════════════════════════════════════════════════════════

func test_realm_status_reads_level_cultivation_and_cap_from_gsm() -> void:
	## 境界等级 / 修为 / 修为上限三者都取自 GSM 的既有字段（本模型不推算上限）。
	# Arrange
	gsm.player = {"realm": 2, "cultivation": 300, "max_cultivation": 1500}
	# Act
	var status: Dictionary = model.realm_status()
	# Assert
	assert_eq(int(status["realm"]), 2, "境界等级应取自 player.realm")
	assert_eq(int(status["cultivation"]), 300, "修为应取自 player.cultivation")
	assert_eq(int(status["max_cultivation"]), 1500,
			"修为上限应取自 player.max_cultivation（GSM 的既有权，不在此重算）")
	assert_eq(str(status["cultivation_text"]), "300 / 1500",
			"修为行应同时给出当前与上限")


func test_realm_name_comes_from_realm_table() -> void:
	## 境界名现查境界配置表——与表逐字一致（不引第二份名单）。
	# Arrange
	var table: Dictionary = RealmScript.realm_table
	# Act + Assert
	for level: int in table.keys():
		assert_eq(model.realm_name(level), str((table[level] as Dictionary)["name"]),
				"境界 %d 的名字应与境界表一致" % level)


func test_unknown_realm_level_falls_back_without_fabricating_name() -> void:
	## 表里没有的等级回退「境界 N」——不臆造名字，也不让整行变空白。
	# Arrange + Act + Assert
	assert_eq(model.realm_name(9), "境界 9", "未登记的等级应回退为「境界 N」")
	assert_eq(model.realm_name(0), "未知境界", "等级 0（未知）应给出明确的未知文案")


func test_max_realm_level_follows_table_size() -> void:
	## 最高境界 = 境界表的键数（表是唯一真理来源——本模型不写死 5）。
	# Arrange + Act + Assert
	assert_eq(model.max_realm_level(), RealmScript.realm_table.size(),
			"最高境界应等于境界表的条目数")


func test_at_max_realm_flag_only_on_top_level() -> void:
	## 「已至最高境界」只在最高级为真——它是例外态提示，不该常驻屏幕。
	# Arrange
	var top: int = RealmScript.realm_table.size()
	gsm.player = {"realm": top, "cultivation": 1, "max_cultivation": 1}
	# Act + Assert
	assert_true(bool(model.realm_status()["at_max_realm"]), "最高境界应为真")
	gsm.player = {"realm": top - 1, "cultivation": 1, "max_cultivation": 1}
	assert_false(bool(model.realm_status()["at_max_realm"]), "非最高境界应为假")


func test_is_fallen_passes_through_from_gsm() -> void:
	## 「已陨落」原样透传 GSM 的 is_fallen（本模型不自己判定陨落条件）。
	# Arrange
	gsm.player = {"realm": 1, "is_fallen": true}
	# Act + Assert
	assert_true(bool(model.realm_status()["is_fallen"]), "应透传 GSM 的 is_fallen")


func test_unavailable_player_domain_yields_legal_zero_shape() -> void:
	## [code]player[/code] 域不可用时返回合法形状的全零值（面板据此显示空态，不崩）。[br]
	## [br][b]为什么注入「player 为 null 的桩」而不是置 gsm 为 null[/b]：gsm 为 null 时
	## 模型会回退到真实 Autoload（生产路径需要它），那是「另一条链路」而不是
	## 「读不到数据」——本用例要验的是后者，故给出一个确实读不出东西的注入源。
	# Arrange
	var empty: StubGsm = StubGsm.new()
	empty.player = null
	add_child_autofree(empty)
	var bare: RefCounted = ModelScript.new(empty, null)
	# Act
	var status: Dictionary = bare.call(&"realm_status")
	# Assert
	assert_eq(int(status["realm"]), 0, "读不到 player 域时境界应为 0（未知）")
	assert_eq(str(status["cultivation_text"]), "0 / 0", "修为行应为 0 / 0")
	assert_false(bool(status["at_max_realm"]), "未知境界不应被判为最高境界")


# ═══════════════════════════════════════════════════════════════════════════════
# 属性（与境界配置表逐字一致——点名验收 ②）
# ═══════════════════════════════════════════════════════════════════════════════

func test_attributes_match_realm_table_entry_exactly() -> void:
	## 属性行的值与境界配置表那一档逐字一致——本模型不做单位换算、不做区间夹取。[br]
	## 这是「角色状态数值与境界配置一致」这条验收的核心断言。
	# Arrange
	gsm.player = {"realm": 3}
	var table_entry: Dictionary = RealmScript.realm_table[3]
	# Act
	var rows: Array = model.attributes()
	# Assert
	var checked: int = 0
	for row: Variant in rows:
		var entry: Dictionary = row
		var key: String = str(entry["key"])
		assert_true(table_entry.has(key), "属性键 '%s' 应存在于境界表" % key)
		assert_eq(str(entry["value_text"]), str(table_entry[key]),
				"属性 '%s' 的值应与境界表逐字一致" % key)
		checked += 1
	assert_eq(checked, table_entry.size() - 1,
			"除境界名外的每个键都应出一行（表里加键界面自动多行）")


func test_attributes_cover_every_level_without_gaps() -> void:
	## 换境界后属性整体跟着换（同一个遍历口径）——不存在「只有炼气期才全」的情况。
	# Arrange
	var top: int = RealmScript.realm_table.size()
	# Act + Assert
	for level: int in range(1, top + 1):
		gsm.player = {"realm": level}
		var rows: Array = model.attributes()
		var table_entry: Dictionary = RealmScript.realm_table[level]
		assert_eq(rows.size(), table_entry.size() - 1,
				"境界 %d 的属性行数应为该档键数减一（除 name）" % level)


func test_attributes_exclude_realm_name_key() -> void:
	## 境界名不作为属性行重复出现——它已由境界节的「当前境界」承载。
	# Arrange
	gsm.player = {"realm": 1}
	# Act
	var rows: Array = model.attributes()
	# Assert
	for row: Variant in rows:
		assert_ne(str((row as Dictionary)["key"]), "name",
				"属性行不应包含境界名键")


func test_attributes_have_chinese_labels() -> void:
	## 每行都有中文标签（不是裸露的英文键名）——玩家看得懂才叫状态界面。
	# Arrange
	gsm.player = {"realm": 4}
	# Act
	var rows: Array = model.attributes()
	# Assert
	for row: Variant in rows:
		var label: String = str((row as Dictionary)["label"])
		assert_false(label.strip_edges().is_empty(), "属性行应有标签")
		assert_ne(label, str((row as Dictionary)["key"]),
				"境界表里的键都应已登记中文标签: %s" % label)


func test_attributes_source_is_a_deep_copy_of_the_table_entry() -> void:
	## [method attributes_source] 返回表条目的深拷贝——改它不会污染境界表的常量。
	# Arrange
	gsm.player = {"realm": 2}
	# Act
	var source: Dictionary = model.attributes_source()
	var original: int = int((RealmScript.realm_table[2] as Dictionary)["max_deploy"])
	source["max_deploy"] = 999
	# Assert
	assert_eq(int((RealmScript.realm_table[2] as Dictionary)["max_deploy"]), original,
			"改动返回值不得污染境界表（const 非真不可变，靠拷贝隔离）")


func test_unknown_realm_level_yields_no_attribute_rows() -> void:
	## 境界等级不在表里 → 无属性行（面板走空态，不臆造数值）。
	# Arrange
	gsm.player = {"realm": 99}
	# Act + Assert
	assert_eq(model.attributes(), [], "未知境界不应产出属性行")
