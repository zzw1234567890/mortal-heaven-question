extends "res://tests/integration/hud/pause_menu_fixture.gd"
## 卡组的卡面渲染（本轮：从纯文本行改成画卡面）。[br]
## [br][b]为什么需要[/b]：规格 design/ux/deck-editing-ui.md §卡组浏览 明写「复用
## 手牌布局的卡片视觉」，而上一轮交付的卡组查看只有一行挤满的纯文本。本文件钉住：
## 每张牌渲染成[b]卡面行[/b]（至少卡名 / 类型 / 费用 / 效果摘要）、稀有度决定边框色、
## 文本仍走 [member Button.text]（屏幕阅读器与既有查询面都读它）、行的确认仍只展开
## 详情。[br]
## [br][b]纯逻辑与控件树各测一边[/b]：卡面字段与文案归
## [code]tests/unit/hud/test_card_face_rules.gd[/code]、单行控件归
## [code]tests/unit/hud/test_deck_card_row.gd[/code]；本文件只证明「面板里装的是
## 卡面行」这件事（换回文本行时那两边都不会红）。[br]
## [br]注：[code]SLS[/code] / [code]SM[/code] 等由夹具提供，此处不再声明——
## GDScript 里子类重复声明同名成员是解析错误，整个文件会被 GUT 静默忽略。[br]
##
## 来源: design/ux/deck-editing-ui.md（§卡组浏览 / §卡牌详情浮窗）、
## design/ux/pause-menu.md（§Interaction Map 战斗中特殊规则 第 321 行）、
## .claude/rules/ui-code.md（双输入 + 文字即标记 + 色盲可读）、ADR-0031 §1/§2。

const RowScript := preload("res://src/ui/hud/deck_card_row.gd")
const FaceRules := preload("res://src/ui/shared/card_face_rules.gd")
## 行构建与行文本读取（退回分支的断言面——与生产同一个入口）。
const CardRowsScript := preload("res://src/ui/hud/deck_card_rows.gd")
const PanelLayoutScript := preload("res://src/ui/inventory/inventory_panel_layout.gd")


## 装一副带效果描述的三张牌并进战斗场景（返回卡组替身）。[br]
## [br]效果摘要来自模板 [code]description[/code]——卡面第三行要真的有内容可画
## （模板本身由夹具的 [method attach_deck] 造好并挂在 MockCards 上）。
func _enter_combat_with_described_deck() -> MockDeck:
	sm.scene_id = SM.SceneID.COMBAT
	var templates: Dictionary = {
		1: make_template("林远", 1, 1),
		2: make_template("御剑术", 2, 2, 1),
		3: make_template("聚灵丹", 3, 0, 4),
	}
	for instance_id: int in templates.keys():
		(templates[instance_id] as CardTemplate).description = "造成 %d 点伤害" % instance_id
	var deck: MockDeck = attach_deck(templates)
	attach_combat()
	return deck


## 打开面板并返回它（三步路径在多个用例里重复）。
func _open_viewer() -> Control:
	open_menu()
	menu_button("DeckViewButton").pressed.emit()
	return deck_view()


# ═══════════════════════════════════════════════════════════════════════════════
# 行是卡面行
# ═══════════════════════════════════════════════════════════════════════════════

func test_rows_are_card_faces_not_text_rows() -> void:
	## 核心断言：列表里装的是 [code]DeckCardRow[/code]，而不是普通文本行。
	# Arrange
	_enter_combat_with_described_deck()
	# Act
	var view: Control = _open_viewer()
	# Assert
	assert_eq(int(view.call(&"entry_count")), 3, "三张牌应渲染三行")
	for index: int in range(3):
		var row: Node = view.call(&"row_node", index)
		assert_not_null(row, "第 %d 行应存在" % index)
		assert_true(row is RowScript, "第 %d 行应是卡面行（当前 %s）" % [index, row])


func test_card_face_shows_name_type_cost_and_effect() -> void:
	## 至少显示卡名 / 类型 / 费用 / 效果摘要——四条都在该行的文本里。
	# Arrange
	_enter_combat_with_described_deck()
	# Act
	var view: Control = _open_viewer()
	var texts: Array = view.call(&"entry_texts")
	# Assert
	var second: String = str(texts[1])
	assert_true(second.contains("御剑术"), "第二行应是卡组里的第二张：" + second)
	assert_true(second.contains("功法"), "卡面应含类型：" + second)
	assert_true(second.contains("2 灵力"), "卡面应含费用：" + second)
	assert_true(second.contains("造成 2 点伤害"), "卡面应含效果摘要：" + second)


func test_card_face_is_multiline() -> void:
	## 卡面是多行版面（卡名 / 类型·稀有度·费用 / 效果）——单行说明还是文本行。
	# Arrange
	_enter_combat_with_described_deck()
	# Act
	var view: Control = _open_viewer()
	# Assert
	var texts: Array = view.call(&"entry_texts")
	assert_eq(str(texts[0]).split("\n").size(), 3, "卡面应为三行：" + str(texts[0]))


func test_card_face_height_exceeds_text_row() -> void:
	## 卡面行明显高于普通条目行（同高就还是文本）。
	# Arrange
	_enter_combat_with_described_deck()
	# Act
	var row: Node = _open_viewer().call(&"row_node", 0)
	# Assert
	assert_gt((row as Control).custom_minimum_size.y, 48.0,
			"卡面行应高于商店/背包的普通条目行（48px）")


func test_card_face_marker_still_written_into_text() -> void:
	## 战斗中标注仍是文字（色盲可读）：卡面第二行带「已抽出」。
	# Arrange
	_enter_combat_with_described_deck()
	(menu.combat_system as MockCombat).hand = [1]
	# Act
	var view: Control = _open_viewer()
	# Assert
	var texts: Array = view.call(&"entry_texts")
	assert_true(str(texts[0]).contains("已抽出"), "手牌那张的卡面应标「已抽出」：" + str(texts[0]))
	assert_true(str(texts[1]).contains("仍在牌库"), "牌库那张应标「仍在牌库」：" + str(texts[1]))


# ═══════════════════════════════════════════════════════════════════════════════
# 稀有度与卡面观感
# ═══════════════════════════════════════════════════════════════════════════════

func test_card_face_border_color_follows_rarity() -> void:
	## 三张牌的稀有度是 1 / 2 / 3——边框色应逐行对应（与手牌卡面同一色表）。
	# Arrange
	_enter_combat_with_described_deck()
	# Act
	var view: Control = _open_viewer()
	# Assert
	for index: int in range(3):
		var row: Node = view.call(&"row_node", index)
		var expected: Color = FaceRules.rarity_color(index + 1)
		assert_eq(row.call(&"border_color"), expected,
				"第 %d 行的边框色应按稀有度 %d 取色" % [index, index + 1])


func test_card_face_is_keyboard_focusable() -> void:
	## 键盘/手柄可达：卡面行必须可聚焦，否则游标（只认可聚焦 Button）会跳过它。
	# Arrange
	_enter_combat_with_described_deck()
	# Act
	var view: Control = _open_viewer()
	var row: Node = view.call(&"row_node", 0)
	# Assert
	assert_eq((row as Button).focus_mode, Control.FOCUS_ALL, "卡面行必须可聚焦")
	assert_gt(int(view.call(&"focused_index")), -1, "打开后游标应落到首个卡面行")
	assert_true(bool(view.call(&"is_row_focused", 0)), "首个卡面行应持有键盘焦点")


# ═══════════════════════════════════════════════════════════════════════════════
# 只读面不变
# ═══════════════════════════════════════════════════════════════════════════════

func test_card_face_row_confirm_still_only_expands_detail() -> void:
	## 换成卡面行不该改变只读语义——确认仍只展开详情，卡组内容一字未动。
	# Arrange
	var deck: MockDeck = _enter_combat_with_described_deck()
	var before: Array = deck.cards.duplicate()
	var view: Control = _open_viewer()
	# Act
	view.call(&"press_row", 0)
	# Assert
	var detail: Array = view.call(&"detail_texts")
	assert_gt(detail.size(), 0, "确认卡面行应展开详情")
	assert_true(str(detail[0]).contains("林远"), "详情首行应是该牌名称：" + str(detail[0]))
	assert_eq(deck.cards, before, "只读查看不得改动卡组内容")
	assert_true(bool(view.call(&"is_open")), "展开详情不应收起面板")


func test_text_row_fallback_when_face_missing() -> void:
	## 半截数据（行载荷没有 face）退回纯文本行——画一张白板卡面比画一行字更糟。
	# Arrange
	_enter_combat_with_described_deck()
	var view: Control = _open_viewer()
	var box: VBoxContainer = view.call(&"rows_parent")
	assert_not_null(box, "面板应给出行的宿主容器")
	PanelLayoutScript.clear_box(box)
	# Act——手工塞一行没有 face 的行数据
	var rows: Array = [{"text": "半截数据行", "payload": {"instance_id": 99}}]
	var written: int = CardRowsScript.add_rows(box, rows, "Fallback", Callable())
	# Assert
	assert_eq(written, 1, "缺 face 的行仍应写入（不丢行）")
	assert_false(box.get_child(0) is RowScript, "缺 face 的行不应画成卡面")
	assert_eq(PanelLayoutScript.row_text(box.get_child(0)), "半截数据行", "应退回纯文本行")
