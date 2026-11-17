extends GutTest
## DeckViewRows —— 卡组行数据的组装（含本轮新增的卡面字段与牌库标注）。[br]
## [br][b]为什么需要本文件[/b]：卡组面板的行数据由它产出——行文案（纯文本回退用）、
## 卡面字段（[code]face[/code]）、牌库标注（[code]marker[/code]）、详情行三样都要
## 对得上。这是纯逻辑，能在没有控件树、没有 DeckEditingSystem 的用例里逐条摆数据
## 断言。[br]
## [br][b]本轮新增的两项[/b]：[code]KEY_FACE[/code]（由
## [code]CardFaceRules.fields_of[/code] 产出，卡面行据此画卡）与
## [code]KEY_MARKER[/code]（「已抽出 / 仍在牌库」，由卡面行拼进第二行）。两者都
## 必须与行文案里的信息[b]同源[/b]——文案说「仍在牌库」而标注为空就会自相矛盾。[br]
## [br]来源: design/ux/deck-editing-ui.md（§多入口到达 / §卡组浏览）、
## design/ux/pause-menu.md（§Interaction Map 战斗中特殊规则）、ADR-0031 §2。

const RowsScript := preload("res://src/ui/hud/deck_view_rows.gd")
const FaceRules := preload("res://src/ui/shared/card_face_rules.gd")


## CardSystem 替身——按实例 ID 给模板（真实 [CardTemplate] 资源）。
class MockCards:
	extends Node

	var templates: Dictionary = {}

	func get_template_by_instance_id(card_instance_id: int) -> CardTemplate:
		var raw: Variant = templates.get(card_instance_id)
		return raw if raw is CardTemplate else null


## CombatSystem 替身——只提供牌库标注真正会碰的三个面。
class MockCombat:
	extends Node

	var active: bool = true
	var hand: Array = []

	func is_battle_active() -> bool:
		return active

	func get_hand() -> Array:
		return hand

	func get_deck() -> Array:
		return []


var cards: MockCards = null
var combat: MockCombat = null


func before_each() -> void:
	cards = MockCards.new()
	combat = MockCombat.new()
	add_child_autofree(cards)
	add_child_autofree(combat)


## 造一张模板并登记到替身卡牌系统上。
func _register(p_instance_id: int, p_name: String = "御剑术", p_type: int = 1,
		p_cost: int = 2, p_rarity: int = 3, p_description: String = "") -> void:
	var template: CardTemplate = CardTemplate.new()
	template.name = p_name
	template.type = p_type
	template.cost = p_cost
	template.rarity = p_rarity
	template.description = p_description
	cards.templates[p_instance_id] = template


# ═══════════════════════════════════════════════════════════════════════════════
# 卡面字段（本轮新增）
# ═══════════════════════════════════════════════════════════════════════════════

func test_build_attaches_face_fields_to_every_row() -> void:
	# Arrange
	_register(1, "林远", 0, 1, 1)
	_register(2, "御剑术", 1, 2, 3, "造成 3 点伤害")
	# Act
	var built: Dictionary = RowsScript.build([1, 2], cards, combat)
	# Assert
	var rows: Array = built["rows"]
	assert_eq(rows.size(), 2, "两张牌应出两行")
	for index: int in range(2):
		var payload: Dictionary = (rows[index] as Dictionary)["payload"]
		assert_true(payload.has(RowsScript.KEY_FACE), "第 %d 行载荷应带卡面字段" % index)
		var face: Dictionary = payload[RowsScript.KEY_FACE]
		assert_eq(str(face[FaceRules.KEY_NAME]),
				"林远" if index == 0 else "御剑术", "卡面卡名应与模板一致")
	assert_eq(str((rows[1] as Dictionary)["payload"][RowsScript.KEY_FACE][FaceRules.KEY_EFFECT]),
			"造成 3 点伤害", "卡面效果摘要应来自模板 description")


func test_face_fields_match_the_row_text() -> void:
	## 卡面与行文案同源——同一张牌的两处产出不能各说各话（名字 / 费用必须一致）。
	# Arrange
	_register(1, "御剑术", 1, 2, 3)
	# Act
	var row: Dictionary = (RowsScript.build([1], cards, combat)["rows"] as Array)[0]
	var face: Dictionary = (row["payload"] as Dictionary)[RowsScript.KEY_FACE]
	# Assert
	assert_true(str(row["text"]).contains(str(face[FaceRules.KEY_NAME])),
			"行文案应含卡面里的卡名：" + str(row["text"]))
	assert_true(str(row["text"]).contains(FaceRules.cost_text(face)),
			"行文案应含卡面里的费用段：" + str(row["text"]))


func test_unresolved_card_yields_no_row_and_no_face() -> void:
	## 模板读不到时那一张不出行——不臆造一张空白卡面。
	# Arrange
	_register(1, "林远", 0, 1, 1)
	# Act
	var built: Dictionary = RowsScript.build([1, 99], cards, combat)
	# Assert
	assert_eq((built["rows"] as Array).size(), 1, "查不到模板的那张不应出行")
	assert_eq(int(built["total"]), 2, "总张数仍如实报 2")
	assert_eq(int(built["unresolved"]), 1, "缺失张数应报 1")


# ═══════════════════════════════════════════════════════════════════════════════
# 牌库标注（本轮新增键；判定与行文案同源）
# ═══════════════════════════════════════════════════════════════════════════════

func test_marker_is_in_hand_for_drawn_card() -> void:
	# Arrange——实例 1 已抽到手上
	_register(1, "林远", 0, 1, 1)
	_register(2, "御剑术", 1, 2, 3)
	combat.hand = [1]
	# Act
	var rows: Array = RowsScript.build([1, 2], cards, combat)["rows"]
	# Assert
	assert_eq(str((rows[0] as Dictionary)["payload"][RowsScript.KEY_MARKER]),
			RowsScript.TEXT_IN_HAND, "手牌那张应标「已抽出」")
	assert_eq(str((rows[1] as Dictionary)["payload"][RowsScript.KEY_MARKER]),
			RowsScript.TEXT_IN_DECK, "牌库那张应标「仍在牌库」")


func test_marker_is_empty_when_battle_inactive() -> void:
	## 非活跃战斗不标注——[code]get_hand()[/code] 本就是空的，给每张都标「仍在牌库」
	## 等于凭空断言一件尚未发生的事。
	# Arrange
	_register(1, "林远", 0, 1, 1)
	combat.active = false
	combat.hand = [1]
	# Act
	var rows: Array = RowsScript.build([1], cards, combat)["rows"]
	# Assert
	assert_eq(str((rows[0] as Dictionary)["payload"][RowsScript.KEY_MARKER]), "",
			"非活跃战斗不应标注")


func test_marker_agrees_with_row_text() -> void:
	## 标注与行文案里的那两个词必须同源——一处说「已抽出」另一处为空就自相矛盾。
	# Arrange
	_register(1, "林远", 0, 1, 1)
	_register(2, "御剑术", 1, 2, 3)
	combat.hand = [1]
	# Act
	var rows: Array = RowsScript.build([1, 2], cards, combat)["rows"]
	# Assert
	for row: Dictionary in rows:
		var marker: String = str((row["payload"] as Dictionary)[RowsScript.KEY_MARKER])
		assert_true(str(row["text"]).contains(marker),
				"行文案应含本行的标注（%s）：%s" % [marker, str(row["text"])])
