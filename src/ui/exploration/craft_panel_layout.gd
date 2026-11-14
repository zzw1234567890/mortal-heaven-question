extends RefCounted
## CraftPanelLayout —— 炼丹台/炼器台 overlay 的控件树与行文案
## （从 [CraftPanelScreen] 拆出）。[br]
## [br][b]为什么单独一处[/b]：与 [code]harvest_panel_layout.gd[/code] 同源理由——
## 「控件怎么搭、行文案怎么拼」与「炼制意图怎么发」是两件事，且面板脚本要守在
## 300 行软上限内。[br]
## [br][b]与商店/采集面板同构[/b]：遮罩 + 居中面板 + 标题 + 滚动列表 + 文案 + 底栏，
## 尺寸/边距/焦点环全部复用 [ShopPanelLayout] 的常量与样式助手——四处不各画一套
## （焦点环颜色或行高改一次即四处生效）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本模块只 new 节点，不持有任何引用
## （[method build] 把引用交回面板）——它没有可被写坏的玩法状态。[br]
## [br][b]文字即标记[/b]：行文案把名称/稀有度/材料需求与持有量/禁用原因都写进
## 按钮文本，不靠颜色单独承载信息（色盲可读）。[br]
##
## 来源: design/gdd/alchemy-crafting-system.md §1a/§2a/§4/§边界（灵材不足置灰）、
## ADR-0031 §2、.claude/rules/ui-code.md（双输入 + 焦点可见）、
## 先例 [code]harvest_panel_layout.gd[/code] / [code]shop_panel_layout.gd[/code]。

## 控件树样式来源（尺寸与焦点环只在那一处定义）。
const ShopLayoutScript := preload("res://src/ui/exploration/shop_panel_layout.gd")

const FONT_SIZE_BODY: int = ShopLayoutScript.FONT_SIZE_BODY
const ITEM_HEIGHT: int = ShopLayoutScript.ITEM_HEIGHT
const PANEL_WIDTH: int = 620
const PANEL_HEIGHT: int = 460

## 禁用原因的分隔符（行文案里材料清单之后接一段「——原因」）。
const REASON_SEPARATOR: String = " —— "


## 构建面板控件树（复用商店布局——标题与「离开」按钮的意图出口同源）。[br]
## [br][param p_panel] 面板根节点。[br]
## [param p_title] 标题文案（由面板给出——本模块不持有面向玩家的词条）。[br]
## [br][b]返回[/b]：[code]{title_label, balance_label, item_box, message_label,
## leave_button}[/code]——面板持有这些引用（不按控件路径查找）。
static func build(p_panel: Control, p_title: String) -> Dictionary:
	return ShopLayoutScript.build(p_panel, p_title)


## 追加一行可炼配方。[br]
## [br][param p_item_box] 配方列表容器。[br]
## [param p_entry] 条目（[code]ExplorationCraftList.entries_of[/code] 的产出）。[br]
## [param p_fallback_index] 无 [code]index[/code] 字段时的行号。[br]
## [param p_on_pressed] 点击/确认回调 [code]func(index: int) -> void[/code]。[br]
## [br][b]禁用态[/b]：等级不足 / 收藏已满 / 灵材不足的行 [code]disabled[/code]——
## 与鼠标点击被引擎拦住同口径，游标也会跳过（[ShopPanelNavigator]）。[br]
## [br][b]键盘可达[/b]：[code]focus_mode = FOCUS_ALL[/code] + 焦点环样式。
static func add_recipe_row(p_item_box: VBoxContainer, p_entry: Dictionary,
		p_fallback_index: int, p_on_pressed: Callable) -> Button:
	var enabled: bool = bool(p_entry.get("enabled", false))
	var parts: Array = [
		str(p_entry.get("name", "")),
		str(p_entry.get("rarity_name", "")),
		str(p_entry.get("cost_text", "")),
	]
	var reason: String = str(p_entry.get("reason", ""))
	if not reason.strip_edges().is_empty():
		parts.append(reason)

	var index: int = int(p_entry.get("index", p_fallback_index))
	var button := Button.new()
	button.name = "Recipe%d" % index
	button.text = " · ".join(parts)
	button.custom_minimum_size = Vector2(0.0, ITEM_HEIGHT)
	button.disabled = not enabled
	button.focus_mode = Control.FOCUS_ALL
	ShopLayoutScript.apply_focus_ring(button)
	button.pressed.connect(func() -> void: p_on_pressed.call(index))
	p_item_box.add_child(button)
	return button


## 灵材摘要文案——各品质档位当前持有量（面板顶部展示，采样自系统快照）。[br]
## [br][param p_counts] [code]{quality(int): count(int)}[/code]。[br]
## [param p_quality_names] 品质档位 → 中文名（由面板给出——本模块不持有词条表）。
static func balance_text(p_counts: Dictionary, p_quality_names: Dictionary) -> String:
	var parts: Array = []
	for quality: int in [1, 2, 3, 4]:
		parts.append("%s %d" % [str(p_quality_names.get(quality, "")),
				int(p_counts.get(quality, 0))])
	return "灵材：" + " · ".join(parts)
