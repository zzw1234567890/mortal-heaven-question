extends RefCounted
## CultivationSceneLayout —— 修炼室的控件树（从 [CultivationScreen] 拆出）。[br]
## [br][b]为什么单独一处[/b]：与 [code]meditation_panel_layout.gd[/code] /
## [code]craft_panel_layout.gd[/code] 同源理由——「控件怎么搭、进度条怎么画」与
## 「动作怎么发、状态怎么读」是两件事，且屏幕脚本要守在 300 行软上限内
## （.claude/docs/coding-standards.md）。[br]
## [br][b]骨架复用 [ShopPanelLayout][/b]：遮罩 + 居中面板 + 标题 + 列表 + 文案 + 底栏
## 的尺寸、边距、焦点环只在那一处定义（改一次即坊市 / 洞府 / 采集 / 炼制 / 本屏五处
## 生效）；动作行工厂复用 [code]meditation_panel_layout.gd[/code]（同一套「按钮 +
## 焦点环 + 禁用态」）。[br]
## [br][b]为什么要撤掉骨架自带的那层压暗[/b]：那层半透明黑是 [b]overlay[/b] 用途
## （压在正在玩的节点图/战斗之上），而修炼室是[b]独立全屏场景[/b]——玩家从主菜单进来，
## 下面没有需要压暗的东西，留着只会把底色再压暗 55%（叠加后不是规格要的那支色号）。
## [br][br][b]零状态所有权[/b]（ADR-0031 §2）：只 new 控件、不读不写任何玩法状态；
## 全部引用经 [method build] 交回屏幕持有（不按控件路径查找——容器层级是构建细节）。[br]
## [br][b]零数值计算[/b]：本模块不拼任何数字或句子——文案由
## [code]cultivation_view_rules.gd[/code] 单点给出，屏幕负责填。[br]
##
## 来源: design/gdd/cultivation-system.md §4/§6、ADR-0031 §2/§4、
## .claude/rules/ui-code.md（双输入 + 色盲可读）、
## 先例 [code]meditation_panel_layout.gd[/code] / [code]shop_panel_layout.gd[/code]。

## 控件树骨架（尺寸 / 边距 / 焦点环的唯一定义处）。
const ShopLayoutScript := preload("res://src/ui/exploration/shop_panel_layout.gd")
## 动作行工厂（按钮 + 焦点环 + 禁用态——与洞府面板同一处）。
const RowScript := preload("res://src/ui/exploration/meditation_panel_layout.gd")

## 底色（深墨基底——与探索节点图屏幕同源 BG-0 口径）。
const BG_COLOR: Color = Color(0.055, 0.06, 0.086, 1.0)
## 进度条轨道色（极淡白——与焦点行底色同系）。
const TRACK_COLOR: Color = Color(1.0, 1.0, 1.0, 0.10)
## 进度条填充色（松石青——与焦点环同色系，配色体系只有一套）。
const FILL_COLOR: Color = Color(0.35, 0.85, 0.8, 1.0)
## 进度条高度（px）。
const BAR_HEIGHT: int = 22
## 中段信息块的纵向间距（px）。
const BLOCK_SEPARATION: int = 8


## 构建修炼室控件树并接线。[br]
## [br][param p_screen] 屏幕根节点（也是 [signal CultivationScreen.leave_requested]
## 的声明处）。[br]
## [param p_title] 标题文案（由屏幕给出——本模块不持有面向玩家的词条）。[br]
## [param p_on_meditate] 「打坐」回调 [code]func() -> void[/code]。[br]
## [param p_on_breakthrough] 「突破」回调 [code]func() -> void[/code]。[br]
## [br][b]返回[/b]：[code]{title_label, balance_label, realm_label, status_label,
## progress_label, progress_fill, item_box, message_label, meditate_button,
## breakthrough_button, leave_button, background}[/code]。[br]
## [br][b]「离开」按钮的意图出口[/b]：骨架已把它的 [signal Button.pressed] 转发到
## 屏幕的 [signal CultivationScreen.leave_requested]，本模块不持有任何回调——
## 屏幕接那一个信号（再接一次按钮会让同一次点击发两次转场请求）。[br]
## [br][b]禁用行的点击出口不在这里[/b]：那条路属于「键盘/手柄导航与焦点搬运」，
## 由 [code]cultivation_scene_input.gd[/code] 统一接（见它的
## [code]bind(...)[/code]）——两处各接一次会让同一次点击走两条路。
static func build(p_screen: Control, p_title: String,
		p_on_meditate: Callable, p_on_breakthrough: Callable) -> Dictionary:
	var parts: Dictionary = ShopLayoutScript.build(p_screen, p_title)
	_drop_overlay_dim(p_screen, parts.get("panel"))
	var background: ColorRect = _add_background(p_screen)
	var block: Dictionary = _make_status_block()
	ShopLayoutScript.insert_before_list(parts, block["root"])
	var buttons: Dictionary = _add_action_rows(parts.get("item_box"),
			p_on_meditate, p_on_breakthrough)
	parts["background"] = background
	parts["realm_label"] = block["realm_label"]
	parts["status_label"] = block["status_label"]
	parts["progress_label"] = block["progress_label"]
	parts["progress_fill"] = block["progress_fill"]
	parts["meditate_button"] = buttons["meditate_button"]
	parts["breakthrough_button"] = buttons["breakthrough_button"]
	return parts


## 撤掉骨架自带的那层压暗（见类文档——独立场景不需要它）。[br]
## [br][b]按名字找而不是按下标[/b]：骨架建的第一个控件就是它（默认名
## [code]"ColorRect"[/code]），面板叫 [code]"Panel"[/code]；按名字定位不受将来在它
## 前面插控件的改动影响。找不到就静默跳过（降级而非崩溃）。
static func _drop_overlay_dim(p_screen: Control, p_panel: Node) -> void:
	var dim: Node = p_screen.find_child("ColorRect", false, false)
	if dim == null or dim == p_panel:
		return
	p_screen.remove_child(dim)
	dim.queue_free()


## 深色全屏底（铺在根节点最底——不参与内容布局，也不吃鼠标）。[br]
## [br][b]插到下标 0[/b]：后加的兄弟画在上面，底色若不是第一个就会被面板盖住。
static func _add_background(p_screen: Control) -> ColorRect:
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = BG_COLOR
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p_screen.add_child(bg)
	p_screen.move_child(bg, 0)
	return bg


## 中段三块信息：当前境界 / 修为进度条 / 突破状态。[br]
## [br][b]数值全由文字承载[/b]，条只作第二通道（色盲可读）。
static func _make_status_block() -> Dictionary:
	var root := VBoxContainer.new()
	root.name = "StatusBlock"
	root.add_theme_constant_override("separation", BLOCK_SEPARATION)
	var realm_label: Label = _make_label()
	root.add_child(realm_label)
	var progress: Dictionary = _make_progress_row()
	root.add_child(progress["root"])
	var status_label: Label = _make_label()
	root.add_child(status_label)
	return {
		"root": root,
		"realm_label": realm_label,
		"status_label": status_label,
		"progress_label": progress["label"],
		"progress_fill": progress["fill"],
	}


## 进度行：轨道 + 填充 + 叠在轨道上的文字。[br]
## [br][b]为什么自绘而不是 [ProgressBar][/b]：数字由[b]文字[/b]承载——屏幕阅读器可读、
## 测试可直接断言文本，条只作第二通道；填充宽用[b]锚点比例[/b]而非每次改像素宽，
## 窗口缩放自动跟随（比例由屏幕按 [code]CultivationViewRules.fill_ratio[/code] 写入）。
static func _make_progress_row() -> Dictionary:
	var track := ColorRect.new()
	track.name = "ProgressTrack"
	track.color = TRACK_COLOR
	track.custom_minimum_size = Vector2(0.0, BAR_HEIGHT)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var fill := ColorRect.new()
	fill.name = "ProgressFill"
	fill.color = FILL_COLOR
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.anchor_left = 0.0
	fill.anchor_top = 0.0
	fill.anchor_right = 0.0
	fill.anchor_bottom = 1.0
	for offset: String in ["left", "top", "right", "bottom"]:
		fill.set("offset_" + offset, 0.0)
	track.add_child(fill)

	var label: Label = _make_label()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	track.add_child(label)

	return {"root": track, "fill": fill, "label": label}


## 两个动作行（打坐 / 突破）。[br]
## [br][b]突破默认禁用[/b]：初始态由 [method CultivationScreen.refresh] 按实况定
## ——这里给 false 只是「还没读到状态之前不承诺可点」。[br]
## [br][b]文案留空[/b]：两句词条都由屏幕在 [method CultivationScreen.refresh] 里按
## 规则层给出（本模块不持有面向玩家的词条，也不做格式化）。
static func _add_action_rows(p_item_box: VBoxContainer, p_on_meditate: Callable,
		p_on_breakthrough: Callable) -> Dictionary:
	return {
		"meditate_button": RowScript.add_action_row(p_item_box, "", true, p_on_meditate),
		"breakthrough_button": RowScript.add_action_row(p_item_box, "", false,
				p_on_breakthrough),
	}


## 标签工厂（字号统一取自骨架——各处不重复写主题覆盖）。
static func _make_label() -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", ShopLayoutScript.FONT_SIZE_BODY)
	return label
