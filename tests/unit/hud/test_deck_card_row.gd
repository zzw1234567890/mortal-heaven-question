extends GutTest
## DeckCardRow —— 卡组卡面行的渲染回归（自绘卡底 + 引擎文本）。[br]
## [br][b]为什么需要本文件[/b]：卡组查看从「一行挤满的纯文本」改成「画卡面」之后，
## 「行上真的画了卡面」「卡面文本含卡名/类型/费用/效果」「键盘可达」「读出仍走
## [member Button.text]」四件事都只在控件树里成立——纯逻辑用例（
## [code]test_card_face_rules.gd[/code]）证不了控件真的长这样。[br]
## [br][b]为什么不断言「像素画出来了」[/b]：GUT 的 headless 模式下自绘调用数可以数，
## 画出来的像素不能读。故本文件断言的是「[method CanvasItem._draw] 被调用过」
## （[member CanvasItem.draw] 信号）与「卡面字段真的进了行控件的文本」——前者证明
## 卡底在画，后者证明玩家读得到内容。[br]
## [br]来源: .claude/rules/ui-code.md（双输入 + 焦点可见 + 文字即标记 + 色盲可读）、
## design/ux/deck-editing-ui.md（§卡组浏览）、ADR-0031 §2。

const RowScript := preload("res://src/ui/hud/deck_card_row.gd")
const FaceRules := preload("res://src/ui/shared/card_face_rules.gd")
const ShopLayoutScript := preload("res://src/ui/exploration/shop_panel_layout.gd")

var row: Button = null


func before_each() -> void:
	row = RowScript.new()
	add_child_autofree(row)


## 造一份卡面字段（走真实 [CardFaceRules]——不手搓字典，免得与生产口径脱节）。
func _face(p_name: String = "御剑术", p_type: int = 1, p_cost: int = 2,
		p_rarity: int = 3, p_description: String = "造成 3 点伤害") -> Dictionary:
	var template: CardTemplate = CardTemplate.new()
	template.name = p_name
	template.type = p_type
	template.cost = p_cost
	template.rarity = p_rarity
	template.description = p_description
	return FaceRules.fields_of(template, 1)


# ═══════════════════════════════════════════════════════════════════════════════
# 卡面内容
# ═══════════════════════════════════════════════════════════════════════════════

func test_row_text_carries_all_face_fields() -> void:
	## 至少显示卡名 / 类型 / 费用 / 效果摘要——四条都在按钮文本里
	## （屏幕阅读器与测试读同一份产出）。
	row.call(&"apply_face", _face(), "")
	var text: String = row.text
	assert_true(text.contains("御剑术"), "卡面应含卡名：" + text)
	assert_true(text.contains("功法"), "卡面应含类型：" + text)
	assert_true(text.contains("2 灵力"), "卡面应含费用：" + text)
	assert_true(text.contains("造成 3 点伤害"), "卡面应含效果摘要：" + text)


func test_row_text_has_three_lines() -> void:
	row.call(&"apply_face", _face(), "")
	assert_eq(row.text.split("\n").size(), 3, "卡面应为三行（卡名 / 类型·费用 / 效果）")


func test_row_text_includes_deck_marker() -> void:
	row.call(&"apply_face", _face(), "仍在牌库")
	assert_true(row.text.contains("仍在牌库"), "卡面应带牌库标注：" + row.text)


func test_row_text_omits_effect_line_when_absent() -> void:
	row.call(&"apply_face", _face("甲", 1, 1, 1, ""), "")
	assert_eq(row.text.split("\n").size(), 2, "无效果摘要时卡面只有两行")


func test_row_has_focus_for_keyboard_navigation() -> void:
	## .claude/rules/ui-code.md：所有交互元素必须同时支持键盘/鼠标和手柄——
	## 游标（ShopPanelNavigator）只认可聚焦的 Button，FOCUS_NONE 的行会被跳过。
	assert_eq(row.focus_mode, Control.FOCUS_ALL, "卡面行必须可聚焦（键盘/手柄可达）")


func test_row_has_focus_ring_stylebox() -> void:
	## 焦点可见：焦点环样式盒与商店/背包面板同源（同一处定义，不各写一份）。
	var ours: StyleBox = row.get_theme_stylebox(&"focus")
	var reference: StyleBox = ShopLayoutScript.focus_stylebox()
	assert_not_null(ours, "卡面行应挂焦点环样式盒")
	assert_true(ours is StyleBoxFlat, "焦点环应为 StyleBoxFlat")
	assert_eq((ours as StyleBoxFlat).border_color, (reference as StyleBoxFlat).border_color,
			"焦点环边框色应与商店面板同源")


func test_state_styleboxes_do_not_cover_the_face() -> void:
	## 自绘卡底必须看得见——引擎默认的不透明灰底会把它糊死。[br]
	## [br][b]常态盒是无底色的 [StyleBoxEmpty][/b]（连 [member StyleBox.bg_color]
	## 都没有，所以不读它的颜色）；悬停/按下是半透明白的叠加层，透明度必须低到
	## 卡面仍读得清。
	for key: StringName in [&"normal", &"hover", &"pressed"]:
		var box: StyleBox = row.get_theme_stylebox(key)
		assert_not_null(box, "%s 状态应挂样式盒" % key)
		if box is StyleBoxEmpty:
			continue
		assert_lt((box as StyleBoxFlat).bg_color.a, 0.5,
				"%s 样式盒底色必须半透明以下（否则盖住卡面）" % key)
	assert_true(row.get_theme_stylebox(&"normal") is StyleBoxEmpty,
			"常态盒应为无底色空盒（卡底由自绘提供）")
	assert_eq(row.get_theme_stylebox(&"normal").content_margin_left, RowScript.TEXT_INSET,
			"文本左边距应让开左侧稀有度色条")


func test_row_height_is_a_card_not_a_text_line() -> void:
	## 卡面行明显高于普通文本行（商店行 48px——三行卡面若与文本行同高就还是文本）。
	assert_gt(row.custom_minimum_size.y, ShopLayoutScript.ITEM_HEIGHT,
			"卡面行应高于普通条目行")


# ═══════════════════════════════════════════════════════════════════════════════
# 卡底绘制（自绘被调用）
# ═══════════════════════════════════════════════════════════════════════════════

func test_card_background_is_drawn() -> void:
	## 自绘入口被真的调用过——这是「卡面在画」的唯一客观证据（[member CanvasItem.draw]
	## 信号在每次 [method CanvasItem._draw] 前后发出，headless 下也读得到；像素读不到，
	## 故断言的是「画了没有」而不是「画成了什么」）。[br]
	## [br][b]布局尺寸要非零[/b]：真实运行时由容器给定，测试里手动给——
	## [method _draw] 对零尺寸会提前返回（那一档没有可断言的外部行为）。
	var draws: Array = []
	row.draw.connect(func() -> void: draws.append(true))
	row.size = Vector2(400.0, RowScript.ROW_HEIGHT)
	row.call(&"apply_face", _face(), "")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_gt(draws.size(), 0, "写入卡面后应触发重绘（卡底真的在画）")


func test_border_color_follows_rarity() -> void:
	## 稀有度色条与边框色与手牌同源——两处各写一份必然漂移。
	for rarity: int in range(1, 6):
		row.call(&"apply_face", _face("甲", 1, 1, rarity), "")
		assert_eq(row.call(&"border_color"), FaceRules.rarity_color(rarity),
				"稀有度 %d 的行边框色应与卡面规则一致" % rarity)


func test_border_color_defaults_to_white_before_apply() -> void:
	## 未写入卡面时按白卡——不猜一个更漂亮的档位。
	assert_eq(row.call(&"border_color"), FaceRules.rarity_color(1),
			"未写入卡面前应按白卡取色")
