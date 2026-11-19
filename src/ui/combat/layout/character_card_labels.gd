extends RefCounted
## CharacterCardLabels —— 角色状态卡的三个文字子节点（创建 / 摆放 / 内容同步）。[br]
## [br][b]为什么单独成文件[/b]：[code]character_status_card.gd[/code] 要守单文件
## 300 行软上限（coding-standards），而这三个 Label 是[b]子节点[/b]——与
## [code]_draw()[/code] 里的绘制是两条不同的渲染通道，混在一处最占篇幅。[br]
## [br][b]为什么文字走 Label 而不是自绘[/b]（R-02 §3 文字合并条款）：名 + 数值
## 合成单 Label，避免为每个字段各建一个节点；字色与字号经主题覆盖设置，
## 不额外贴图。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本模块不持引用——节点建好后挂在宿主
## 名下（[param p_host]），每次同步现读宿主的渲染快照。[br]
## [br]来源: ADR-0031、production/qa/evidence/r02-batching-spec.md、
## combat-ui-layout Story 002/003。

## 共享纯函数（响应式字号——story 001 唯一落地处，禁止内联）。
const UiFont := preload("res://src/ui/combat/shared/combat_ui_font.gd")
## 阵亡戳记的文案与规格（判定只有那一处）。
const DefeatMarker := preload("res://src/ui/combat/layout/combat_card_defeat_marker.gd")
## 视觉规格常量。
const Style := preload("res://src/ui/combat/layout/character_card_style.gd")

## 子节点名（测试按名取——[code]get_node("NameLabel")[/code] 等既有断言依赖）。
const NAME_STAT: String = "StatLabel"
const NAME_DISPLAY: String = "NameLabel"
const NAME_DEFEAT: String = "DefeatStamp"


## 创建三个文字子节点并挂到宿主下（[code]_init[/code] 内调用——不依赖场景树时序）。[br]
## [br][b]返回[/b]：[code]{stat, name, defeat}[/code] 三个 Label，宿主持有引用
## （不按控件路径查找：路径会随布局改动碎掉）。
static func create(p_host: Control) -> Dictionary:
	var stat: Label = _make_label(p_host, NAME_STAT)
	var display: Label = _make_label(p_host, NAME_DISPLAY)
	var defeat: Label = _make_label(p_host, NAME_DEFEAT)
	defeat.visible = false
	return {"stat": stat, "name": display, "defeat": defeat}


## 建一个 Label 子节点（居中排版——卡片文字统一居中）。
static func _make_label(p_host: Control, p_name: String) -> Label:
	var label := Label.new()
	label.name = p_name
	p_host.add_child(label)
	return label


## 同步全部文字（宿主 [code]_refresh()[/code] 内调用）。[br]
## [br][param p_labels] [method create] 的产出；宿主在 [code]_init[/code] 里存下它。
static func sync(p_host: Control, p_labels: Dictionary) -> void:
	var font_size: int = _responsive_font_size(p_host)
	sync_stat(p_host, p_labels.get("stat"), font_size)
	sync_display_name(p_host, p_labels.get("name"), font_size)
	sync_defeat_stamp(p_host, p_labels.get("defeat"), font_size)


## 响应式字号——屏幕高度分档（[code]get_viewport()[/code] 为空时按基准 1080 处理）。
static func _responsive_font_size(p_host: Control) -> int:
	var screen_height: int = int(p_host.get_viewport_rect().size.y) \
			if p_host.get_viewport() != null else 1080
	return UiFont.font_size_responsive(Style.BASE_FONT_SIZE, screen_height)


## HP/ATK 数值行（L3 底部条内——单 Label 合并，R-02 §3）。
static func sync_stat(p_host: Control, p_label: Label, p_font_size: int) -> void:
	if p_label == null:
		return
	p_label.text = "HP %d/%d  ATK %d" % [
			p_host.current_hp, p_host.max_hp, p_host.atk_value]
	p_label.add_theme_font_size_override("font_size", p_font_size)
	p_label.add_theme_color_override("font_color", Style.ATK_COLOR)
	p_label.position = Vector2(Style.SIDE_BAR_WIDTH,
			p_host.size.y - Style.BOTTOM_BAR_HEIGHT + Style.STAT_LABEL_BASELINE)
	p_label.size = Vector2(p_host.size.x - Style.SIDE_BAR_WIDTH * 2.0,
			Style.LABEL_HEIGHT)


## 名牌（L5 顶部横条——名字为空时隐藏，不留一条空底色）。
static func sync_display_name(p_host: Control, p_label: Label,
		p_font_size: int) -> void:
	if p_label == null:
		return
	p_label.visible = not p_host.display_name.is_empty()
	p_label.text = p_host.display_name
	p_label.add_theme_font_size_override("font_size", p_font_size)
	p_label.add_theme_color_override("font_color", Style.ATK_COLOR)
	p_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_label.position = Vector2(Style.SIDE_BAR_WIDTH, Style.NAME_LABEL_TOP)
	p_label.size = Vector2(p_host.size.x - Style.SIDE_BAR_WIDTH * 2.0,
			Style.LABEL_HEIGHT)


## 阵亡戳记（文案与可见性都从纯函数规格取——判定只有一处）。[br]
## [br][b]为什么戳记与灰化并存[/b]：灰化（绘制模块的 overlay）在缩到 50%
## 时未必读得出，一条写着「已阵亡」的实色横条是灰度模式下也读得到的那一层信息。[br]
## [br][b]卡被摘除时怎么办[/b]：阵亡动画结束后卡会换成带同款戳记的空位框
## （[code]CombatDeathHandoff[/code]）——戳记在动画那 0.5s、以及「已阵亡但仍
## 留在场上」两条路径上出现，两条都比没有强。
static func sync_defeat_stamp(p_host: Control, p_label: Label,
		p_font_size: int) -> void:
	if p_label == null:
		return
	var spec: Dictionary = DefeatMarker.style(p_host.is_defeated)
	var text: String = str(spec.get("text", ""))
	p_label.visible = not text.is_empty()
	p_label.text = text
	if text.is_empty():
		return
	p_label.add_theme_font_size_override("font_size", p_font_size)
	p_label.add_theme_color_override("font_color",
			spec.get("stamp_text", DefeatMarker.STAMP_TEXT_COLOR))
	p_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var h: float = float(spec.get("stamp_height", DefeatMarker.STAMP_HEIGHT))
	p_label.position = Vector2(0.0,
			p_host.size.y - Style.BOTTOM_BAR_HEIGHT - h)
	p_label.size = Vector2(p_host.size.x, h)
