extends RefCounted
## PagedPanelLayout —— 「分类栏 + 条目列表」型面板的控件树构建。[br]
## [br][b]与商店/采集面板的关系[/b]：遮罩 + 居中面板 + 标题 + 滚动列表 + 文案 +
## 底栏的骨架直接复用 [ShopPanelLayout]（尺寸、边距、焦点环只在那一个文件里定义，
## 改一次四处生效）；本模块[b]只加一件新东西[/b]——标题与列表之间的[b]分类栏[/b]
## （背包与角色状态是本项目头两个带分类切换的面板，此前没有先例可抄）。[br]
## [br][b]分类栏为什么是 [Button] 而不是 [Label][/b]：切换分类是一项[b]交互[/b]，
## 而 `.claude/rules/ui-code.md` 要求所有交互元素同时支持键盘/鼠标/手柄——
## 一个纯 Label 只能靠方向键切换，鼠标玩家点不了。做成按钮后：鼠标可点（点一次
## 切到下一类）、键盘 Tab 可聚焦 + 回车、方向键左右也可切（面板另外接左/右）。[br]
## [br][b]条目行为什么是 [Label][/b]：背包与角色状态都是[b]看[/b]的面板——条目不
## 可点、不可买、不可用，做成按钮会让 Enter 做出一个不存在的承诺。列表
## [code]ItemBox[/code] 里全是 Label，[code]ShopPanelNavigator[/code] 会把非
## [Button] 的行按「不可选」跳过（它自述的判据），故上下键在这里无事可做、
## 游标恒为 -1，这是如实结果而非缺陷。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：只 new 节点，不持有引用（[method build]
## 把引用交回面板）。[br]
## [br][b]文字即标记[/b]：数量、稀有度、阵亡状态全部写进文本，不靠颜色单独承载信息。[br]
##
## 来源: .claude/rules/ui-code.md（双输入 + 焦点可见 + 色盲可读）、ADR-0031 §2/§4、
## 先例 [code]shop_panel_layout.gd[/code] / [code]harvest_panel_layout.gd[/code]。

## 控件树样式来源（尺寸与焦点环只在那一处定义）。
const ShopLayoutScript := preload("res://src/ui/exploration/shop_panel_layout.gd")

const FONT_SIZE_BODY: int = ShopLayoutScript.FONT_SIZE_BODY
const ITEM_HEIGHT: int = ShopLayoutScript.ITEM_HEIGHT
## 面板尺寸——比商店（760×520）窄一点：这里没有价格列与多列信息。
const PANEL_WIDTH: int = 720
const PANEL_HEIGHT: int = 560

## 分类栏左侧的前缀（后面接 [InventoryCatalog.category_bar_text] 的产出）。
const TEXT_CATEGORY_PREFIX: String = "分类："
## 分类栏右侧的操作提示（说明键盘怎么切——不靠玩家自己猜）。
const TEXT_CATEGORY_HINT: String = "  （← → 切换）"
## 「返回」按钮文案（复用商店面板的「离开」会与这里的语义不符）。
const TEXT_BACK: String = "返回"


## 构建面板控件树。[br]
## [br][param p_panel] 面板根节点。[br]
## [param p_title] 标题文案（由面板给出——本模块不持有面向玩家的词条）。[br]
## [param p_leave_signal] 「返回」按钮转发哪个信号名。[b]必须传面板自己声明过的信号[/b]
## ——[method Object.emit_signal] 遇到脚本里没有的信号名不会报编译错，只在运行时
## 抛出 [code]Can't emit non-existing signal[/code]（[code]ERR_UNAVAILABLE[/code]）：
## 表现是「按钮点了没反应」，且该错误会污染用例的 Unexpected Errors，集成测试跟着红。[br]
## [br][b]返回[/b]：商店布局的六个键 + [code]category_button[/code]——面板持有这些
## 引用（不按控件路径查找）。[br]
## [br][b]分类栏不发信号[/b]：它把按钮[b]交回给面板[/b]，由面板自己 [code]connect[/code]
## 到切分类的方法。这里刻意不再定义「分类切换请求」信号——那个信号没有任何外部
## 消费者（点分类栏的意图就在面板内部闭环），多发一次只是把同一条路径走两遍。
static func build(p_panel: Control, p_title: String,
		p_leave_signal: StringName = &"leave_requested") -> Dictionary:
	# 「返回」信号名必须显式传：商店骨架默认转发 &"leave_requested"，而背包面板声明的是
	# &"back_requested"——名字对不上时 emit_signal 只会静默失败（ERR_UNAVAILABLE），
	# 按钮看着能点、点了没反应。
	var parts: Dictionary = ShopLayoutScript.build(p_panel, p_title, &"back_requested")
	# 面板尺寸直接从返回值取（[code]panel[/code] 是那个居中 PanelContainer 本身）——
	# 不靠 [code]get_parent()[/code] 数层级：控件树的层数是构建细节，多数/少数一层
	# 就会拿到错误的节点（VBoxContainer → ScrollContainer → VBoxContainer →
	# MarginContainer → PanelContainer，看着像两层其实四层）。
	var panel_node: PanelContainer = parts["panel"]
	panel_node.custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)

	var category_button := Button.new()
	category_button.name = "CategoryButton"
	category_button.custom_minimum_size = Vector2(0.0, ITEM_HEIGHT)
	category_button.focus_mode = Control.FOCUS_ALL
	ShopLayoutScript.apply_focus_ring(category_button)
	# 这里[b]不接任何回调[/b]：按钮原样交回面板，由面板自己 connect（见上方注记）。

	# 插到滚动列表[b]之前[/b]（标题下方、条目上方）——用「列表 → 滚动容器 →
	# 纵列」的父子关系定位，不写字符串路径（路径会随布局改动碎掉）。
	var scroll: Node = parts["item_box"].get_parent()
	var column: Node = scroll.get_parent()
	column.add_child(category_button)
	column.move_child(category_button, scroll.get_index())

	parts["category_button"] = category_button
	return parts


## 刷新分类栏文案。[br]
## [br][param p_text] 由 [code]InventoryCatalog.category_bar_text[/code] 拼好的
## 分类串（「[灵材 (3)]  丹药」）——本模块不自建文案。[br]
## [br][b]操作提示写进按钮文本[/b]：屏幕阅读器可读，不只靠图标或颜色。
static func set_category_text(p_category_button: Button, p_text: String) -> void:
	p_category_button.text = TEXT_CATEGORY_PREFIX + p_text + TEXT_CATEGORY_HINT


## 追加一行只读条目（名称 · 稀有度 · 数量）。[br]
## [br][b]数量恒 ≥ 1[/b]：[code]InventoryModel[/code] 已按「数量为 0 不显示」过滤，
## 本模块不重复判定（口径只有一个地方）。[br]
## [br][b]空段自动跳过[/b]：灵材没有稀有度词条（品阶与卡牌稀有度是两套刻度，见
## [code]InventoryModel._ling_cai_entries[/code]），其 [code]rarity_name[/code] 为空串
## ——拼接时跳过空段，行文案不会出现「· ·」这种空档。[br]
## [br][param p_entry] 条目（[code]{name, rarity_name, count, detail}[/code]）。[br]
## [br][b]返回[/b]：该行的 [Label]（测试可读其 [member Label.text]）。
static func add_readout_row(p_item_box: VBoxContainer, p_entry: Dictionary,
		p_row_name: String) -> Label:
	var parts: Array = [str(p_entry.get("name", ""))]
	var rarity_name: String = str(p_entry.get("rarity_name", ""))
	if not rarity_name.strip_edges().is_empty():
		parts.append(rarity_name)
	parts.append("×%d" % int(p_entry.get("count", 0)))
	return add_text_row(p_item_box, " · ".join(parts), p_row_name)


## 追加一行只读文本（背包的「名称 · 稀有度 · ×数量」与角色状态的「修为上限 · 1000」
## 都是它的特例）。[br]
## [br][b]行文案由调用方拼[/b]：文案是各面板自己的口径（背包有稀有度与数量、角色状态
## 有生命与出战态），本模块只负责「怎么摆成一行」。[br]
## [br][b]返回[/b]：该行的 [Label]。
static func add_text_row(p_item_box: VBoxContainer, p_text: String,
		p_row_name: String) -> Label:
	var label := Label.new()
	label.name = p_row_name
	label.text = p_text
	label.custom_minimum_size = Vector2(0.0, ITEM_HEIGHT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
	p_item_box.add_child(label)
	return label
