extends GutTest
## CardFaceRules —— 卡面字段读取与三行文案拼装的纯逻辑回归。[br]
## [br][b]为什么需要本文件[/b]：卡组查看从「一行挤满的纯文本」改成「画卡面」之后，
## 卡面上到底写哪几项（卡名 / 类型 / 稀有度 / 费用 / 效果摘要）、字段缺失时怎么降级、
## 超长描述怎么压进一行，全部由这个模块裁决。它是纯函数，能在没有控件树、没有
## DeckEditingSystem 的用例里逐条摆数据比对。[br]
## [br][b]缺字段不臆造[/b]：名字缺失回退 [code]#实例号[/code]、类型未登记不出那一段、
## 效果为空不占第三行——宁可少一行，也不编造「未知卡牌」这类看起来像真的的假信息。[br]
## [br]来源: design/ux/deck-editing-ui.md（§卡组浏览「复用手牌布局的卡片视觉」/
## §卡牌详情浮窗「卡名 / 稀有度 / 类型 / 费用 / 效果全文」）、
## design/gdd/deck-editing-system.md §5、ADR-0031 §2。

const FaceRules := preload("res://src/ui/shared/card_face_rules.gd")
const HandCardScript := preload("res://src/ui/combat/layout/hand_card.gd")


## 造一张卡牌模板（字段与真实 [CardTemplate] 同名同类型）。
func _template(p_name: String = "御剑术", p_type: int = 1, p_cost: int = 2,
		p_rarity: int = 3, p_description: String = "") -> CardTemplate:
	var template: CardTemplate = CardTemplate.new()
	template.name = p_name
	template.type = p_type
	template.cost = p_cost
	template.rarity = p_rarity
	template.description = p_description
	return template


# ═══════════════════════════════════════════════════════════════════════════════
# 字段读取
# ═══════════════════════════════════════════════════════════════════════════════

func test_fields_read_name_type_cost_and_rarity() -> void:
	# Arrange
	var template: CardTemplate = _template("御剑术", 1, 2, 3)
	# Act
	var fields: Dictionary = FaceRules.fields_of(template, 7)
	# Assert
	assert_eq(str(fields[FaceRules.KEY_NAME]), "御剑术", "卡名应取模板 name")
	assert_eq(int(fields[FaceRules.KEY_COST]), 2, "费用应取模板 cost")
	assert_eq(int(fields[FaceRules.KEY_RARITY_LEVEL]), 3, "稀有度等级应取模板 rarity")
	assert_eq(str(fields[FaceRules.KEY_RARITY_NAME]), "紫", "稀有度应给出中文名")
	assert_eq(str(fields[FaceRules.KEY_TYPE_NAME]), "功法", "类型应给出中文名（1=功法）")


func test_fields_fall_back_to_instance_id_when_name_missing() -> void:
	## 空名字不写空串——白板卡面比「#7」更难认。
	var fields: Dictionary = FaceRules.fields_of(_template("", 1, 0, 1), 7)
	assert_eq(str(fields[FaceRules.KEY_NAME]), "#7", "名字缺失应回退为 #实例号")


func test_fields_treat_blank_name_as_missing() -> void:
	var fields: Dictionary = FaceRules.fields_of(_template("   ", 1, 0, 1), 12)
	assert_eq(str(fields[FaceRules.KEY_NAME]), "#12", "纯空白名字同样按缺失处理")


func test_fields_do_not_invent_type_name_for_unknown_type() -> void:
	## 类型未登记时那一段不出——不编造「未知类型」。
	var fields: Dictionary = FaceRules.fields_of(_template("甲", 99, 1, 1), 1)
	assert_eq(str(fields[FaceRules.KEY_TYPE_NAME]), "", "未登记的类型不应给中文名")


func test_fields_clamp_negative_cost_to_zero() -> void:
	var fields: Dictionary = FaceRules.fields_of(_template("甲", 1, -5, 1), 1)
	assert_eq(int(fields[FaceRules.KEY_COST]), 0, "负数费用应夹到 0")


func test_fields_survive_null_template() -> void:
	## 模板缺失时全部降级，不崩——卡组面板照常能开出这一行（名字回退实例号）。
	var fields: Dictionary = FaceRules.fields_of(null, 3)
	assert_eq(str(fields[FaceRules.KEY_NAME]), "#3", "模板缺失时名字回退实例号")
	assert_eq(str(fields[FaceRules.KEY_EFFECT]), "", "模板缺失时效果摘要为空")


# ═══════════════════════════════════════════════════════════════════════════════
# 效果摘要（第三行）
# ═══════════════════════════════════════════════════════════════════════════════

func test_effect_summary_keeps_short_description() -> void:
	var template: CardTemplate = _template("甲", 1, 1, 1, "造成 3 点伤害")
	assert_eq(FaceRules.effect_summary(template), "造成 3 点伤害", "短描述应原样保留")


func test_effect_summary_flattens_newlines() -> void:
	## 卡面第三行只有一行的位置——换行不折平会把后半段顶出卡面。
	var template: CardTemplate = _template("甲", 1, 1, 1, "造成 3 点伤害\n并抽一张牌")
	assert_eq(FaceRules.effect_summary(template), "造成 3 点伤害 并抽一张牌",
			"换行应折成空格")


func test_effect_summary_truncates_with_ellipsis() -> void:
	# Arrange——构造一段远超上限的描述
	var long_text: String = ""
	for i: int in range(60):
		long_text += "字"
	var template: CardTemplate = _template("甲", 1, 1, 1, long_text)
	# Act
	var summary: String = FaceRules.effect_summary(template)
	# Assert
	assert_eq(summary.length(), FaceRules.EFFECT_MAX_CHARS + FaceRules.ELLIPSIS.length(),
			"超长描述应截到上限 + 省略号")
	assert_true(summary.ends_with(FaceRules.ELLIPSIS), "截断应带省略号")
	assert_eq(summary.substr(0, FaceRules.EFFECT_MAX_CHARS),
			long_text.substr(0, FaceRules.EFFECT_MAX_CHARS), "截断应保留开头部分")


func test_effect_summary_at_boundary_is_not_truncated() -> void:
	## 边界：正好等于上限时不截断（多一个省略号就意味着丢了一个字）。
	var exact: String = ""
	for i: int in range(FaceRules.EFFECT_MAX_CHARS):
		exact += "字"
	var template: CardTemplate = _template("甲", 1, 1, 1, exact)
	assert_eq(FaceRules.effect_summary(template), exact, "正好到上限不应截断")


func test_effect_summary_empty_when_no_description() -> void:
	var template: CardTemplate = _template("甲", 1, 1, 1, "   ")
	assert_eq(FaceRules.effect_summary(template), "", "无描述应返回空串（不占第三行）")


# ═══════════════════════════════════════════════════════════════════════════════
# 三行文案
# ═══════════════════════════════════════════════════════════════════════════════

func test_face_text_has_three_lines_with_effect() -> void:
	var fields: Dictionary = FaceRules.fields_of(
			_template("御剑术", 1, 2, 3, "造成 3 点伤害"), 1)
	var lines: Array = FaceRules.face_lines(fields)
	assert_eq(lines.size(), 3, "卡面固定三行")
	assert_eq(str(lines[0]), "御剑术", "第一行是卡名")
	assert_true(str(lines[1]).contains("功法"), "第二行含类型")
	assert_true(str(lines[1]).contains("紫"), "第二行含稀有度")
	assert_true(str(lines[1]).contains("2 灵力"), "第二行含费用")
	assert_eq(str(lines[2]), "造成 3 点伤害", "第三行是效果摘要")


func test_face_text_skips_empty_effect_line() -> void:
	## 无效果正文时第三行不占位——卡面高度保持可预期（滚动位置不跳）。
	var fields: Dictionary = FaceRules.fields_of(_template("甲", 1, 1, 1), 1)
	var text: String = FaceRules.face_text(fields)
	assert_eq(text.split("\n").size(), 2, "无效果摘要时卡面只有两行")
	assert_false(text.contains("\n\n"), "不应留下空行")


func test_face_text_includes_marker_in_second_line() -> void:
	var fields: Dictionary = FaceRules.fields_of(_template("甲", 1, 1, 1), 1)
	var text: String = FaceRules.face_text(fields, "已抽出")
	assert_true(text.split("\n")[1].contains("已抽出"), "标注应进第二行")
	assert_eq(text.split("\n").size(), 2, "标注不应另起一行")


func test_meta_line_keeps_zero_cost() -> void:
	## 0 费卡是构筑里最值钱的一类，藏掉等于误导。
	var fields: Dictionary = FaceRules.fields_of(_template("甲", 1, 0, 1), 1)
	assert_true(FaceRules.meta_text(fields).contains("0 灵力"), "0 费也应写出来")


func test_meta_line_skips_type_when_it_equals_name() -> void:
	## 角色卡的卡名就是角色名——「林远 · 角色」里的类型段是重复信息。
	var fields: Dictionary = FaceRules.fields_of(_template("角色", 0, 1, 1), 1)
	assert_eq(FaceRules.meta_text(fields), "白 · 1 灵力", "类型与卡名相同时应跳过类型段")


func test_cost_text_reports_unit() -> void:
	assert_eq(FaceRules.cost_text({FaceRules.KEY_COST: 3}), "3 灵力", "费用带单位")
	assert_eq(FaceRules.cost_text({FaceRules.KEY_COST: -1}), "0 灵力", "负数夹到 0")


# ═══════════════════════════════════════════════════════════════════════════════
# 稀有度配色（与手牌同源）
# ═══════════════════════════════════════════════════════════════════════════════

func test_rarity_color_matches_hand_card_table() -> void:
	## 手牌卡面与卡组卡面是同一种「这张牌多稀有」的视觉语言——色表各写一份必然漂移。
	for rarity: int in range(1, 6):
		assert_eq(FaceRules.rarity_color(rarity),
				HandCardScript.RARITY_BORDER_COLORS[rarity - 1],
				"稀有度 %d 的卡面边框色应与手牌一致" % rarity)


func test_rarity_color_clamps_out_of_range() -> void:
	assert_eq(FaceRules.rarity_color(0), HandCardScript.RARITY_BORDER_COLORS[0],
			"越界低值应按白卡")
	assert_eq(FaceRules.rarity_color(99),
			HandCardScript.RARITY_BORDER_COLORS[HandCardScript.RARITY_BORDER_COLORS.size() - 1],
			"越界高值应按最高档")
