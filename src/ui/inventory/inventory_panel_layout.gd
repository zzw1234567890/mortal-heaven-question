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
## [br][b]两种行，判据在载荷[/b]：可确认的行（背包条目 / 角色行）做成 [Button]
## ——[code]ShopPanelNavigator[/code] 只认 [Button] 的可选性，[Label] 在它眼里一律
## 「不可选」，上下键会直接跳过；纯信息行（角色状态的境界/属性）仍是 [Label]
## ——点了没有下一步动作，做成按钮等于承诺一个不存在的操作。哪一种由
## [method add_rows] 按「这一行有没有载荷」判定，判据只此一处。[br]
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
## 抛出 [code]Can't emit non-existent signal[/code]（[code]ERR_UNAVAILABLE[/code]）：
## 表现是「按钮点了没反应」，且该错误会污染用例的 Unexpected Errors，集成测试跟着红。[br]
## [br][b]返回[/b]：商店布局的六个键 + [code]category_button[/code] +
## [code]detail_box[/code]——面板持有这些引用（不按控件路径查找）。[br]
## [br][b]分类栏不发信号[/b]：它把按钮[b]交回给面板[/b]，由面板自己 [code]connect[/code]
## 到切分类的方法。这里刻意不再定义「分类切换请求」信号——那个信号没有任何外部
## 消费者（点分类栏的意图就在面板内部闭环），多发一次只是把同一条路径走两遍。[br]
## [br][b]详情区为什么在列表外[/b]：角色状态的「选中一行 → 看它的详情」若要挤进
## 列表本身，就得把行替换成多行文本再换回来，游标下标会跟着错位。独立一块
## （列表下方、提示文案上方）让列表始终是列表；空时隐藏，不占版面。
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

	# 插到滚动列表[b]之前[/b]（标题下方、条目上方）——用「列表 → 滚动容器 →
	# 纵列」的父子关系定位，不写字符串路径（路径会随布局改动碎掉）。
	var scroll: Node = parts["item_box"].get_parent()
	var column: Node = scroll.get_parent()

	var category_button := Button.new()
	category_button.name = "CategoryButton"
	category_button.custom_minimum_size = Vector2(0.0, ITEM_HEIGHT)
	category_button.focus_mode = Control.FOCUS_ALL
	ShopLayoutScript.apply_focus_ring(category_button)
	# 这里[b]不接任何回调[/b]：按钮原样交回面板，由面板自己 connect（见上方注记）。
	column.add_child(category_button)
	column.move_child(category_button, scroll.get_index())

	var detail_box := VBoxContainer.new()
	detail_box.name = "DetailBox"
	detail_box.add_theme_constant_override("separation", 4)
	detail_box.visible = false  # 空时隐藏（没选中任何东西就不占版面）
	column.add_child(detail_box)
	# 摆在滚动列表[b]之后[/b]、提示文案之前（用列表的兄弟下标定位，不写字符串路径）。
	column.move_child(detail_box, scroll.get_index() + 1)

	parts["category_button"] = category_button
	parts["detail_box"] = detail_box
	return parts


## 刷新分类栏文案。[br]
## [br][param p_text] 由 [code]InventoryCatalog.category_bar_text[/code] 拼好的
## 分类串（「[灵材 (3)]  丹药」）——本模块不自建文案。[br]
## [br][b]操作提示写进按钮文本[/b]：屏幕阅读器可读，不只靠图标或颜色。
static func set_category_text(p_category_button: Button, p_text: String) -> void:
	p_category_button.text = TEXT_CATEGORY_PREFIX + p_text + TEXT_CATEGORY_HINT


## 追加一行只读条目（名称 · 稀有度 · 数量）+ 把条目挂到行的元数据上。[br]
## [br][b]数量恒 ≥ 1[/b]：[code]InventoryModel[/code] 已按「数量为 0 不显示」过滤，
## 本模块不重复判定（口径只有一个地方）。[br]
## [br][b]空段自动跳过[/b]：灵材没有稀有度词条（品阶与卡牌稀有度是两套刻度，见
## [code]InventoryModel._ling_cai_entries[/code]），其 [code]rarity_name[/code] 为空串
## ——拼接时跳过空段，行文案不会出现「· ·」这种空档。[br]
## [br][param p_entry] 条目（[code]{name, rarity_name, count, detail}[/code]）。[br]
## [br][b]返回[/b]：该行控件（确认时要拿回条目本身——见 [method add_selectable_row]）。
static func add_readout_row(p_item_box: VBoxContainer, p_entry: Dictionary,
		p_row_name: String, p_on_pressed: Callable = Callable()) -> Button:
	var parts: Array = [str(p_entry.get("name", ""))]
	var rarity_name: String = str(p_entry.get("rarity_name", ""))
	if not rarity_name.strip_edges().is_empty():
		parts.append(rarity_name)
	parts.append("×%d" % int(p_entry.get("count", 0)))
	return add_selectable_row(p_item_box, " · ".join(parts), p_row_name, p_entry,
			p_on_pressed)


## 追加一行[b]可聚焦[/b]文本行（背包条目与角色行都是它的特例）。[br]
## [br][b]为什么行是 [Button] 而不是 [Label][/b]：`.claude/rules/ui-code.md` 要求所有
## 交互元素同时支持键盘/鼠标/手柄，而游标实现（[ShopPanelNavigator]）的判据是
## [member Button.disabled]——[Label] 行在它眼里一律「不可选」，上下键会直接跳过。
## 做成按钮后：键盘上下可选中（焦点环随焦点绘制）、鼠标可点、手柄同键位。[br]
## [br][b]左对齐[/b]：[Button] 文本默认居中，列表行居中会让名称与数量在行内漂移，
## 左对齐才有清单的观感。[br]
## [br][b]条目挂元数据而不另存一份[/b]：确认时要拿回「这一行是哪个条目」，把它记在
## 行自己的 [method Node.set_meta] 上，面板就不必维护「下标 → 条目」的第二份副本
## （刷新会换一批控件，副本必然与控件错位）。[br]
## [br][b]点击也要接上[/b]（[param p_on_pressed]）：键盘路径经游标确认、
## 鼠标路径经 [signal Button.pressed]，两条最后必须落到同一个出口——只在游标那边
## 处理，就等于给鼠标玩家一个点了没反应的按钮。[br]
## [br][b]返回[/b]：该行的 [Button]（测试可读其 [member Button.text]）。
static func add_selectable_row(p_item_box: VBoxContainer, p_text: String,
		p_row_name: String, p_payload: Dictionary = {},
		p_on_pressed: Callable = Callable()) -> Button:
	var button := Button.new()
	button.name = p_row_name
	button.text = p_text
	button.custom_minimum_size = Vector2(0.0, ITEM_HEIGHT)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	ShopLayoutScript.apply_focus_ring(button)
	if not p_payload.is_empty():
		button.set_meta(META_PAYLOAD, p_payload)
	p_item_box.add_child(button)
	if p_on_pressed.is_valid():
		# 下标在[b]接线时[/b]绑定（= 该按钮在列表里的序号）：回调方拿到的是
		# 「第几行」，与游标给的 `_activate_row(index)` 同一口径。
		button.pressed.connect(p_on_pressed.bind(p_item_box.get_child_count() - 1))
	return button


## 追加一行[b]不可聚焦[/b]的只读文本（纯信息行——如角色状态的小节摘要）。[br]
## [br][b]为什么保留 Label[/b]：这些行点了也没有下一步动作，做成按钮等于承诺一个
## 不存在的操作（同 [code]shop_panel_layout[/code] 对禁用行的处置思路）。[br]
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


## 读一行的文本（[Label] 与 [Button] 两种行都读）。[br]
## [br][b]为什么不按类型各写一遍[/b]：面板的「渲染实证」查询（[code]entry_texts[/code] /
## [code]row_texts[/code]）要覆盖两种行——各处自己判类型会让同一件事有三个版本。
static func row_text(p_row: Node) -> String:
	if p_row is Button:
		return (p_row as Button).text
	if p_row is Label:
		return (p_row as Label).text
	return ""


## 取某行携带的条目载荷（没有则空字典）。
static func row_payload(p_row: Node) -> Dictionary:
	if not p_row.has_meta(META_PAYLOAD):
		return {}
	var payload: Variant = p_row.get_meta(META_PAYLOAD)
	return payload if payload is Dictionary else {}


## 一次渲染一整列行——[param p_rows] 是 [code]Array[{text, payload}][/code]。[br]
## [br][b]载荷决定行的种类[/b]：有载荷 = 可确认（[Button]，确认后能找回这一条是什么）；
## 无载荷 = 纯信息（[Label]，点了没有下一步动作）——判据只此一处，面板不必逐行判类型。[br]
## [br][b]为什么收进布局模块[/b]：「一串行 → 一批控件」是纯构建（不读模型、不写状态），
## 且两个面板都要做；写在各面板里会让「空的载荷该渲染成什么」出现两份可能不同的答案。[br]
## [br][param p_on_pressed] 可选点击出口 [code]func(index: int) -> void[/code]
## ——只为可确认的行接线（见 [method add_selectable_row]）。[br]
## [br][b]返回[/b]：写入的行数（面板据此更新行计数，不必再数一遍子节点）。
static func add_rows(p_item_box: VBoxContainer, p_rows: Array,
		p_prefix: String = "Row", p_on_pressed: Callable = Callable()) -> int:
	var count: int = 0
	for raw: Variant in p_rows:
		if not (raw is Dictionary):
			continue
		var row: Dictionary = raw
		var payload: Dictionary = row.get("payload", {})
		var name: String = "%s%d" % [p_prefix, count]
		var text: String = str(row.get("text", ""))
		if payload.is_empty():
			add_text_row(p_item_box, text, name)
		else:
			add_selectable_row(p_item_box, text, name, payload, p_on_pressed)
		count += 1
	return count


## 填充详情区（选中某行后在其下方展开的那一块）。[br]
## [br][b]传空数组 = 收起[/b]：没有可展示的详情时整块隐藏（[member Control.visible]
## 为假），不留一片空白占版面。[br]
## [br][b]详情恒为只读文本行[/b]：展开的内容是给人看的，不是又一层可选列表。[br]
## [br][b]返回[/b]：详情区当前是否可见（测试可据此断言「详情确实展开了」）。
static func fill_detail(p_detail_box: VBoxContainer, p_texts: Array,
		p_prefix: String = "Detail") -> bool:
	clear_box(p_detail_box)
	if p_texts.is_empty():
		return false
	for index: int in range(p_texts.size()):
		add_text_row(p_detail_box, str(p_texts[index]), "%s%d" % [p_prefix, index])
	p_detail_box.visible = true
	return true


## 清空一个容器并[b]收起[/b]它（下一次填充会自己重新展开）。[br]
## [br][b]先 [method Node.remove_child] 再 [method Node.queue_free][/b]：只
## [code]queue_free[/code] 的话节点要到帧末才真正离开，同一帧内 [method
## Node.get_child_count] 仍然数得到它——「刷新后行数」的断言会看到上一批行。
static func clear_box(p_box: Node) -> void:
	for child: Node in p_box.get_children():
		p_box.remove_child(child)
		child.queue_free()
	p_box.visible = false


## 行条目载荷的元数据键（见 [method add_selectable_row]）。
const META_PAYLOAD: StringName = &"row_payload"
