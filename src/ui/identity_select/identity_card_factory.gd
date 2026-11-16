extends RefCounted
## IdentityCardFactory —— 身份卡片的纯构建（静态，从 Presenter 拆出）。
##
## 只负责「把一条身份条目画成一个 Control」与「头像占位行」——不持有节点引用、
## 不连接事件、不改游戏状态。事件接线由调用方（Presenter）负责，故本模块可被
## 单测直接调用（喂一条 entry，断言卡片结构与遮罩）。
##
## [br][b]遮罩不变量[/b]：被拦的卡（[code]Rules.is_identity_ready[/code] 为假）
## 恒为 [constant ALPHA_BLOCKED] 半透明且名称带 🔒，并
## [code]set_meta(&amp;"unlocked", false)[/code]——供高亮/入场动画据此保护遮罩，
## 否则「这张卡不能选」的视觉与「点了没反应」的行为会互相打脸。
##
## [br]来源: ADR-0031 §2（UI 零状态所有权）、design/gdd/identity-selection-system.md
## §用户界面需求、story-004-identity-select-ui.md。

## 判定/文本纯函数子模块。
const Rules := preload("res://src/ui/identity_select/identity_select_rules.gd")

## 被拦卡的常驻不透明度（半透明锁定遮罩）。
const ALPHA_BLOCKED: float = 0.45
## 卡片最小尺寸（GridContainer 三列布局下与 .tscn 的 900px 网格宽度相称）。
const CARD_MIN_SIZE: Vector2 = Vector2(280, 150)
## 头像占位按钮的最小高度。
const AVATAR_MIN_SIZE: Vector2 = Vector2(0, 32)


## 构建单张身份卡片。[br]
## [br]结构：Panel（卡片底）+ VBox（名称 / 风格标签 / 角色头像占位 / 灵石）。[br]
## [br][b]焦点环[/b]：纯 Control 默认 FOCUS_NONE，必须显式开 [code]FOCUS_ALL[/code]
## 才能 [code]grab_focus()[/code]（键盘/手柄焦点与鼠标悬停独立）。[br]
## [br][b]事件[/b]：不在此连接——由 Presenter 拿到返回值后
## [code]gui_input.connect(...)[/code]，保持本模块无副作用。
static func build_card(entry: Dictionary, index: int) -> Control:
	var startable: bool = Rules.is_identity_ready(entry)
	var card: Panel = Panel.new()
	card.name = "Card%d" % index
	card.custom_minimum_size = CARD_MIN_SIZE
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.focus_mode = Control.FOCUS_ALL
	card.set_meta(&"unlocked", startable)
	if not startable:
		card.modulate = Color(1.0, 1.0, 1.0, ALPHA_BLOCKED)

	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 12.0
	box.offset_top = 10.0
	box.offset_right = -12.0
	box.offset_bottom = -10.0
	card.add_child(box)

	var name_label: Label = Label.new()
	name_label.text = _entry_text(entry, &"name", "—")
	if not startable:
		name_label.text += " 🔒"
	box.add_child(name_label)

	var tag_label: Label = Label.new()
	tag_label.text = str(entry.get(&"style_tag", ""))
	box.add_child(tag_label)
	box.add_child(build_avatar_row(_entry_character_names(entry)))

	var ling_shi_label: Label = Label.new()
	ling_shi_label.text = "%d %s" % [int(entry.get(&"initial_ling_shi", 0)),
			Rules.TEXT_LING_SHI_SUFFIX]
	box.add_child(ling_shi_label)

	return card


## 头像占位行——每名角色一个 disabled Button（不可交互）。[br]
## 头像纹理由后续视觉 story 走统一图集替换（control-manifest R-02 禁独立纹理）。
static func build_avatar_row(names: Array[String]) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	for display_name: String in names:
		row.add_child(make_avatar_button(display_name))
	return row


## 单个头像占位按钮。
static func make_avatar_button(display_name: String) -> Button:
	var avatar: Button = Button.new()
	avatar.text = display_name
	avatar.disabled = true
	avatar.custom_minimum_size = AVATAR_MIN_SIZE
	return avatar


## 从 entry 取文本字段（防御空值——数据缺失时安全占位）。
static func _entry_text(entry: Dictionary, key: StringName, fallback: String) -> String:
	var value: String = str(entry.get(key, ""))
	return value if not value.is_empty() else fallback


## 从 entry 取角色显示名列表（防御——兼容 character_display_names 缺失）。
static func _entry_character_names(entry: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for n: Variant in entry.get(&"character_display_names", []):
		result.append(str(n))
	return result
