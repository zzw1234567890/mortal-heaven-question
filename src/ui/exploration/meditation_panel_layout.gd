extends RefCounted
## MeditationPanelLayout —— 打坐/洞府 overlay 的控件树与行文案
## （从 [MeditationPanelScreen] 拆出）。[br]
## [br][b]为什么单独一处[/b]：与 [code]craft_panel_layout.gd[/code] 同源理由——
## 「控件怎么搭、行文案怎么拼」与「突破意图怎么发」是两件事，且面板脚本要守在
## 300 行软上限内。[br]
## [br][b]与商店/采集/炼制面板同构[/b]：遮罩 + 居中面板 + 标题 + 状态行 + 列表 +
## 文案 + 底栏，尺寸/边距/焦点环全部复用 [ShopPanelLayout] 的常量与样式助手
## ——四处不各画一套（焦点环颜色或行高改一次即四处生效）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本模块只 new 节点，不持有任何引用
## （[method build] 把引用交回面板）——它没有可被写坏的玩法状态。[br]
## [br][b]文字即标记[/b]：状态行与动作行把境界、所需修为、成功率、失败代价都写成
## 文本，不靠颜色单独承载信息（色盲可读）。[br]
## [br][b]UI 零数值计算[/b]：所有数字都由 Feature 层的
## [code]ExplorationBreakthroughStatus.status[/code] 格式化好传进来，本模块只做
## 拼接与排版。[br]
##
## 来源: design/gdd/cultivation-system.md §4/§6/§边界、ADR-0031 §2、
## .claude/rules/ui-code.md（双输入 + 焦点可见）、
## 先例 [code]craft_panel_layout.gd[/code] / [code]shop_panel_layout.gd[/code]。

## 控件树样式来源（尺寸与焦点环只在那一处定义）。
const ShopLayoutScript := preload("res://src/ui/exploration/shop_panel_layout.gd")

const FONT_SIZE_BODY: int = ShopLayoutScript.FONT_SIZE_BODY
const ITEM_HEIGHT: int = ShopLayoutScript.ITEM_HEIGHT
const PANEL_WIDTH: int = 620
const PANEL_HEIGHT: int = 420

## 状态行高度（只读文本——比可点行矮）。
const LINE_HEIGHT: int = 26


## 构建面板控件树（复用商店布局——标题与「离开」按钮的意图出口同源）。[br]
## [br][param p_panel] 面板根节点。[br]
## [param p_title] 标题文案（由面板给出——本模块不持有面向玩家的词条）。[br]
## [br][b]返回[/b]：[code]{title_label, balance_label, item_box, message_label,
## leave_button}[/code]——面板持有这些引用（不按控件路径查找）。
static func build(p_panel: Control, p_title: String) -> Dictionary:
	return ShopLayoutScript.build(p_panel, p_title)


## 追加一行只读状态文本（当前修为 / 所需修为 / 失败代价）。[br]
## [br][b]不是 [Button][/b]：状态行不可点——游标（[ShopPanelNavigator]）会把非
## [Button] 的行当禁用跳过，键盘不会停在纯文本上。[br]
## [br][b]文字即标记[/b]：数值本身写在文本里，不靠颜色区分。
static func add_status_line(p_item_box: VBoxContainer, p_text: String) -> Label:
	var label := Label.new()
	label.name = "Status%d" % p_item_box.get_child_count()
	label.text = p_text
	label.custom_minimum_size = Vector2(0.0, LINE_HEIGHT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
	p_item_box.add_child(label)
	return label


## 追加动作行（「尝试突破」——成功率与所需修为已由 Feature 层拼进文案）。[br]
## [br][param p_enabled] false 时 [code]disabled[/code]——与鼠标点击被引擎拦住同
## 口径，游标也会跳过（不可突破时键盘不会停在上面）。[br]
## [br][b]键盘可达[/b]：[code]focus_mode = FOCUS_ALL[/code] + 焦点环样式。
static func add_action_row(p_item_box: VBoxContainer, p_text: String,
		p_enabled: bool, p_on_pressed: Callable) -> Button:
	var button := Button.new()
	button.name = "AttemptButton"
	button.text = p_text
	button.custom_minimum_size = Vector2(0.0, ITEM_HEIGHT)
	button.disabled = not p_enabled
	button.focus_mode = Control.FOCUS_ALL
	ShopLayoutScript.apply_focus_ring(button)
	button.pressed.connect(func() -> void: p_on_pressed.call())
	p_item_box.add_child(button)
	return button


## 顶部摘要文案——境界跃迁标题（[code]headline[/code]；已达最高境界时为空串，
## 由面板换成「已达最高境界」的状态文案）。
static func headline_text(p_headline: String, p_at_max: bool, p_at_max_text: String) -> String:
	return p_at_max_text if p_at_max or p_headline.strip_edges().is_empty() else p_headline
