extends RefCounted
## CardFaceRules —— 卡组的[b]卡面字段读取与三行文案拼装[/b]（纯逻辑，不碰控件树）。[br]
## [br][b]为什么单独一处[/b]：卡组查看面板要把每张牌画成[b]卡面[/b]（卡名 / 类型 /
## 费用 / 效果摘要）而不是一行挤满的纯文本，而「模板里哪几个字段构成卡面正面、缺字段
## 时怎么降级、长描述怎么压进固定行高」是纯判定——它能在没有控件树的用例里逐条摆数据
## 断言（同 [code]deck_view_rows.gd[/code] / [code]map_clear_panel_rules.gd[/code]
## 的拆因）。[br]
## [br][b]为什么不读 CardSystem[/b]：本模块只认「一个模板对象」，不认识注册表——
## 查表由取数侧（[code]deck_view_rows.gd[/code]）完成，卡面只负责「拿到模板之后
## 怎么画」。这是 UI 零状态所有权的边界（ADR-0031 §2）。[br]
## [br][b]缺字段不臆造[/b]（同 [code]InventoryModel[/code] / [code]DeckViewRows[/code]
## 口径）：名字缺失回退 [code]#实例号[/code]、类型未登记则不出现那一段、效果摘要为空
## 就不占第三行——宁可少一行，也不编造「未知卡牌」这类看起来像真的的假信息。[br]
## [br][b]配色与词表不另写一份[/b]：边框色取 [code]HandCard[/code] 的稀有度色表
## ——手牌卡面与卡组卡面是同一种「这张牌多稀有」的视觉语言，各写一份必然漂移；
## 稀有度/类型中文名与背包、商店同源。[br]
## [br][b]文案本地化豁免[/b]：与 [code]deck_view_rows.gd[/code] /
## [code]placeholder_scene.gd[/code] 同源口径——项目暂无本地化系统。[br]
##
## 来源: design/ux/deck-editing-ui.md（§卡组浏览「卡组网格：复用手牌布局的卡片视觉」、
## §卡牌详情浮窗「卡名>稀有度/类型/费用>效果全文」）、
## design/gdd/deck-editing-system.md §5、ADR-0031 §2、.claude/rules/ui-code.md
## （双输入 + 文字即标记 + 色盲可读）。

## 手牌卡面的稀有度色表（卡面边框色的单一真理来源——见类文档）。
const HandCardScript := preload("res://src/ui/combat/layout/hand_card.gd")
## 卡牌类型中文名（与背包、商店同一份词表）。
const CatalogScript := preload("res://src/feature/inventory/inventory_catalog.gd")
## 稀有度中文名（与商店 / 背包 / 卡组查看同一口径）。
const ShopLayoutScript := preload("res://src/ui/exploration/shop_panel_layout.gd")

## 行内各段之间的分隔符（与商店商品行、卡组查看行的「 · 」同源）。
const SEPARATOR: String = " · "

## 效果摘要的单行长度上限（字符数）。[br]
## [br][b]为什么按字符数截断而不是按像素[/b]：截断要能在纯函数里被断言，而像素宽度
## 得等控件量完；卡面第三行只有一行的位置，不截断超长描述会被 [code]clip_text[/code]
## 从中间硬切，玩家看到半句话。取值按面板宽度减两侧留白、14pt 中文实测一行约 36 字，
## 留一档余量。
const EFFECT_MAX_CHARS: int = 32
## 截断标记（中文省略号——与项目文案风格一致）。
const ELLIPSIS: String = "…"

## 卡面字段的键（构建侧与渲染侧共用——不裸写字符串）。
const KEY_NAME: String = "name"
const KEY_TYPE_NAME: String = "type_name"
const KEY_COST: String = "cost"
const KEY_RARITY_NAME: String = "rarity_name"
const KEY_RARITY_LEVEL: String = "rarity"
const KEY_EFFECT: String = "effect"


## 从卡牌模板读出一张卡面的全部字段。[br]
## [br][param p_template] 卡牌模板对象（[code]CardTemplate[/code]；不可读时全部降级）。[br]
## [param p_instance_id] 卡牌实例 ID（名称缺失时用作兜底显示名——不写空串让卡面变白板）。[br]
## [br][b]返回[/b]：[code]{name, type_name, cost, rarity, rarity_name, effect}[/code]。
static func fields_of(p_template: Variant, p_instance_id: int) -> Dictionary:
	var name: String = _field(p_template, "name")
	if name.strip_edges().is_empty():
		name = "#%d" % p_instance_id
	var rarity: int = _int_field(p_template, "rarity")
	return {
		KEY_NAME: name,
		KEY_TYPE_NAME: CatalogScript.card_type_name(_int_field(p_template, "type")),
		KEY_COST: maxi(_int_field(p_template, "cost"), 0),
		KEY_RARITY_LEVEL: rarity,
		KEY_RARITY_NAME: ShopLayoutScript.rarity_name(rarity),
		KEY_EFFECT: effect_summary(p_template),
	}


## 效果正文压进一行（空 / 纯空白返回空串，超长截断加省略号）。[br]
## [br][b]换行先折成空格[/b]：策划在模板里用换行分段是常见写法，而卡面第三行只有
## 一行位置——不折行会把后半段直接顶出卡面。
static func effect_summary(p_template: Variant, p_max_chars: int = EFFECT_MAX_CHARS) -> String:
	var raw: String = _field(p_template, "description")
	var flat: String = raw.replace("\n", " ").replace("\r", " ").strip_edges()
	if flat.is_empty():
		return ""
	if p_max_chars <= 0 or flat.length() <= p_max_chars:
		return flat
	return flat.substr(0, p_max_chars) + ELLIPSIS


## 卡面的三行文案（[brief]卡名 / 类型·稀有度·费用·标注 / 效果摘要[/brief]）。[br]
## [br][b]为什么固定三行[/b]：卡面是列表里的一行，行高必须可预期（长度不一的行会让
## 滚动位置在刷新后跳动）。第三行没有效果正文时返回空串——由 [method face_text]
## 跳过，不占位。[br]
## [br][param p_fields] [method fields_of] 的产出。[br]
## [param p_marker] 额外标注（「已抽出」/「仍在牌库」；空串 = 不加）。[br]
## [br][b]标注并进第二行[/b]：它回答的是「这张在不在手上」，与费用同属「这一行的状态」，
## 单独占第四行会把卡面高度再推高一档。
static func face_lines(p_fields: Dictionary, p_marker: String = "") -> Array:
	return [name_text(p_fields), meta_text(p_fields, p_marker), str(p_fields.get(KEY_EFFECT, ""))]


## 卡面的完整文本（三行用换行连接，空行跳过）。[br]
## [br][b]为什么要有这个方法[/b]：卡面是按钮文本渲染的，屏幕阅读器与测试都需要一个
## 「这张卡面上到底写了哪些字」的客观答案——渲染与断言读同一份产出，不存在第二份文案。
static func face_text(p_fields: Dictionary, p_marker: String = "") -> String:
	var parts: Array = []
	for line: Variant in face_lines(p_fields, p_marker):
		var text: String = str(line)
		if not text.strip_edges().is_empty():
			parts.append(text)
	return "\n".join(parts)


## 第一行——卡名（本身即兜底名，恒非空）。
static func name_text(p_fields: Dictionary) -> String:
	return str(p_fields.get(KEY_NAME, ""))


## 第二行——类型 · 稀有度 · N 灵力 [· 标注]（空段自动跳过）。[br]
## [br][b]类型与卡名相同时跳过类型段[/b]：角色卡的卡名就是角色名，此时「林远 · 角色」
## 里的类型段是重复信息（同 [code]DeckViewRows._row_text[/code] 的口径）。[br]
## [br][b]费用恒显示[/b]：0 费卡是构筑里最值钱的一类，藏掉等于误导。
static func meta_text(p_fields: Dictionary, p_marker: String = "") -> String:
	var parts: Array = []
	var type_name: String = str(p_fields.get(KEY_TYPE_NAME, ""))
	if not type_name.is_empty() and type_name != name_text(p_fields):
		parts.append(type_name)
	var rarity_name: String = str(p_fields.get(KEY_RARITY_NAME, ""))
	if not rarity_name.is_empty():
		parts.append(rarity_name)
	parts.append(cost_text(p_fields))
	if not p_marker.strip_edges().is_empty():
		parts.append(p_marker)
	return SEPARATOR.join(parts)


## 费用段文案（[code]0 灵力[/code] 也照写——见 [method meta_text]）。
static func cost_text(p_fields: Dictionary) -> String:
	return "%d 灵力" % maxi(int(p_fields.get(KEY_COST, 0)), 0)


## 稀有度边框色（越界取值按白卡——与 [code]HandCard.get_border_color[/code] 同源夹取）。[br]
## [br][b]色表取 [code]HandCard[/code][/b]：手牌卡面与卡组卡面是同一种视觉语言，
## 各写一份必然漂移（见类文档）。
static func rarity_color(p_rarity: int) -> Color:
	var colors: Array = HandCardScript.RARITY_BORDER_COLORS
	return colors[clampi(p_rarity, 1, colors.size()) - 1]


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 读一个字符串字段（模板缺失 / 字段类型不符时返回空串——不臆造）。
static func _field(p_template: Variant, p_key: String) -> String:
	if p_template == null or not (p_template is Object):
		return ""
	var raw: Variant = (p_template as Object).get(p_key)
	return str(raw) if raw != null else ""


## 读一个整数字段（同上，缺失返回 0）。
static func _int_field(p_template: Variant, p_key: String) -> int:
	if p_template == null or not (p_template is Object):
		return 0
	var raw: Variant = (p_template as Object).get(p_key)
	return int(raw) if raw != null else 0
