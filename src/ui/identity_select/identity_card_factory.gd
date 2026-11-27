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
## 立绘/配色解析子模块。
const Resolver := preload("res://src/ui/identity_select/identity_portrait_resolver.gd")
## 单角色小块（立绘 or 程序化占位）。
const TileScript := preload("res://src/ui/identity_select/identity_portrait_tile.gd")

## 被拦卡的常驻不透明度（半透明锁定遮罩）。
const ALPHA_BLOCKED: float = 0.45
## 卡片最小尺寸（GridContainer 三列布局下与 .tscn 的 900px 网格宽度相称）。[br]
## [br][b]为什么从 150 抬高到 168[/b]：卡面上沿让出一整条立绘带（见
## [constant AVATAR_MIN_SIZE]），文字仍在图[b]下方[/b]独立成行——图不压字。
const CARD_MIN_SIZE: Vector2 = Vector2(280, 168)
## 立绘带高度（px）——两名角色小块并排；其余高度留给文字行。
## [br][b]上限来源[/b]：.tscn 网格区 354px 高装两行 + 16px 间隔 → 单卡 169px。
const AVATAR_MIN_SIZE: Vector2 = Vector2(104, 72)
## 立绘/占位小块的容器最小高度（= [constant AVATAR_MIN_SIZE] 的 y）。
const AVATAR_ROW_HEIGHT: float = 72.0
## 立绘行内两块的横向间隔（px）。
const AVATAR_SEP: int = 8


## 构建单张身份卡片。[br]
## [br]结构：Panel（卡片底）+ VBox（名称 / 风格标签 / 立绘带 / 灵石）。[br]
## [br][b]文字与图分层[/b]：立绘带只占 VBox 中间一行，名称与灵石各占独立行——
## 图不叠在字上，不存在「图压住文字」。[br]
## [br][b]焦点环[/b]：纯 Control 默认 FOCUS_NONE，必须显式开 [code]FOCUS_ALL[/code]
## 才能 [code]grab_focus()[/code]（键盘/手柄焦点与鼠标悬停独立）。小块自身
## [code]MOUSE_FILTER_IGNORE[/code]，点击仍落到卡片上，焦点链不变。[br]
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
	box.add_child(build_avatar_row(entry))

	var ling_shi_label: Label = Label.new()
	ling_shi_label.text = "%d %s" % [int(entry.get(&"initial_ling_shi", 0)),
			Rules.TEXT_LING_SHI_SUFFIX]
	box.add_child(ling_shi_label)

	return card


## 立绘带——每名角色一块（有立绘走 [TextureRect]，没有走程序化占位）。[br]
## [br][b]配色/立绘来源[/b]：全部委托 [IdentityPortraitResolver]——本模块只负责排布。
static func build_avatar_row(entry: Dictionary) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "AvatarRow"
	row.custom_minimum_size = Vector2(0.0, AVATAR_ROW_HEIGHT)
	row.add_theme_constant_override(&"separation", AVATAR_SEP)
	var identity_id: StringName = StringName(str(entry.get(&"identity_id", &"")))
	var display_names: Array[String] = _entry_character_names(entry)
	var cards: Array[Dictionary] = Resolver.character_cards(identity_id, display_names)
	var palette: Dictionary = Resolver.palette_for(identity_id,
			str(entry.get(&"style_tag", "")))
	var fallback_char: String = _first_char(_entry_text(entry, &"name", ""))
	for card_info: Dictionary in cards:
		row.add_child(_make_tile(
				str(card_info.get("card_id", "")),
				str(card_info.get("display_name", "")),
				palette, AVATAR_MIN_SIZE, fallback_char))
	return row


## 单个角色小块——保留既有入口名（Presenter 弹窗按此调用），内部转交
## [IdentityPortraitTile]。[br]
## [br][b]颜色板口径[/b]：本入口拿不到身份 id（只有显示名），故恒用兜底色板——
## 卡片路径不经过这里（[method build_avatar_row] 直连小块并传入身份色板）。
static func make_avatar_button(display_name: String) -> Control:
	return _make_tile("", display_name, Resolver.FALLBACK_PALETTE, AVATAR_MIN_SIZE)


## 造一个已配置好的小块（[IdentityPortraitTile.new()] + [code]setup[/code]）。[br]
## [br][b]为什么静态工厂放在本文件[/b]：小块脚本没有 [code]class_name[/code]
## （局部控件，不值得占全局标识符），从外部只能经 [code]preload[/code] 后的
## [GDScript] 句柄 [code].new()[/code]——这层样板收在一处，调用点保持一行。
static func _make_tile(p_card_id: String, p_display_name: String,
		p_palette: Dictionary, p_tile_size: Vector2, p_seal_char: String = "") -> Control:
	var tile: Control = TileScript.new()
	tile.call(&"setup", p_card_id, p_display_name, p_palette, p_tile_size, p_seal_char)
	return tile


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


## 取首字（空串 → 空串）。
static func _first_char(p_text: String) -> String:
	return p_text.substr(0, 1) if not p_text.is_empty() else ""
