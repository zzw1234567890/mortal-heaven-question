extends RefCounted
## MapCardArt —— 地图卡片的[b]插图来源、顶部预览块与图标行[/b]（从 [MapCard] 拆出）。[br]
##
## [b]为什么单独一处[/b]：卡片脚本已贴 300 行软上限
## （.claude/docs/coding-standards.md），而「哪张地图配哪张插图、预览块与图标行
## 怎么搭」是资产侧的事，与「卡面文字怎么写、点击怎么转发」分开（同
## [code]map_select_cards.gd[/code] / [code]map_select_animator.gd[/code] 拆分先例）。[br]
##
## [br][b]本模块补的断链[/b]：卡片此前[b]一个图片节点都没有[/b]——[code]_build()[/code]
## 只建七行 Label，玩家看到的是「一张只有字的卡片」（反馈原话：地图选择里看不到
## 地图），而 17 张插图其实早已落盘在 [code]assets/environments/maps/[/code]。[br]
##
## [br][b]对照表是唯一真理来源[/b]：[constant ILLUSTRATIONS] 的键 = 探明表
## [code]ExplorationMapCatalog.MAPS[/code] 的键，文件名见
## [code]design/assets/specs/map-card-illustrations-assets.md[/code]
## （ASSET-211~227 逐张标注，也是全库唯一覆盖全部 17 张地图的逐图规格）。
## 单测对「探明表每张图都有插图、且文件真的在盘上」做完整性断言——漏一张就是
## 一张没有图的卡，而那种缺陷不会在运行时报错，只会让玩家看到占位块。[br]
##
## [br][b]缺图不留白[/b]：查不到插图（未登记地图 / 文件缺失）时预览块改成深色
## 占位块 + 居中「暂无图」，而不是一块空白——空白看起来像加载失败，占位块明说
## 「这里本来没图」。[br]
##
## [br][b]图标与文字分开成两个节点[/b]：🔒 / ⭐ 这类图标此前是拼进文字标签的
## （「⭐首次通关」「名字 🔒」），图标与文字之间既量不出间距，长名字还会被图标
## 挤掉（玩家反馈「图标与文字压在一起」）。[method build_icon_row] 把图标与文字
## 拆成两个标签，间距由 [constant ICON_GAP] 钉死。[br]
##
## [br][b]零状态所有权[/b]（ADR-0031 §2）：只读资源与纯控件搭建，不读 GSM、
## 不写任何玩法状态。[br]
##
## 来源: design/gdd/exploration-ui-system.md §1 地图选择界面（卡片含地图插图）、
## design/assets/specs/map-card-illustrations-assets.md、ADR-0031 §2、
## .claude/rules/ui-code.md（色盲可读 / 最小分辨率下完整）。

## 地图 ID → 插图资源路径（17 张，键与探明表逐一对齐）。[br]
## [br][b]键写规范写法[/b]（与 [code]ExplorationMapCatalog.MAPS[/code] 同源）——
## 历史写法经 [code]canonical_id[/code] 归一后才进本表；写错键等于那张图没图。[br]
## [br][b]文件名不带地图 ID[/b]：插图按美术规格里的笔法域命名
## （如 [code]qingyun_sword_sect[/code]），与探明表的 ID 是两套命名——
## 本表就是这两套命名的唯一对接处。
const ILLUSTRATIONS: Dictionary = {
	&"qing_yun_jian_zong": "res://assets/environments/maps/qingyun_sword_sect.png",
	&"xue_yuan_mi_jing": "res://assets/environments/maps/xueyuan_secret_realm.png",
	&"yun_lan_cheng": "res://assets/environments/maps/yunlan_city.png",
	&"dan_xia_gu": "res://assets/environments/maps/danxia_valley.png",
	&"cang_xuan_zheng_dao_meng": "res://assets/environments/maps/cangxuan_league.png",
	&"cang_xuan_gu_zhan_chang": "res://assets/environments/maps/cangxuan_battlefield.png",
	&"sui_xing_wai_huan": "res://assets/environments/maps/suixing_outer_ring.png",
	&"sui_xing_nei_hai": "res://assets/environments/maps/suixing_inner_sea.png",
	&"wan_gu_dian": "res://assets/environments/maps/wangu_palace.png",
	&"xi_yu_gu_lin": "res://assets/environments/maps/xiyu_ancient_forest.png",
	&"xi_yu_bian_jing": "res://assets/environments/maps/xiyu_border.png",
	&"xi_yu": "res://assets/environments/maps/xiyu_desert.png",
	&"mu_lan_cao_yuan": "res://assets/environments/maps/mulan_grassland.png",
	&"gui_xu_tong_dao": "res://assets/environments/maps/guixu_passage.png",
	&"gui_xu_fu_yun_lu": "res://assets/environments/maps/guixu_floating_cloud.png",
	&"gui_xu_wan_yao_gu": "res://assets/environments/maps/guixu_demon_valley.png",
	&"gui_xu_gu_mo_zhan_chang": "res://assets/environments/maps/guixu_demon_battlefield.png",
}

## === 节点名（测试与宿主按名查找——预览块与图标行都是运行期拼的，无场景路径）====

const NODE_PREVIEW: StringName = &"MapPreview"
const NODE_ART: StringName = &"PreviewArt"
const NODE_PLACEHOLDER: StringName = &"PreviewPlaceholder"
const NODE_PLACEHOLDER_LABEL: StringName = &"PreviewPlaceholderLabel"
## 图标行内的两个标签名（[method build_icon_row] 的产物——间距断言按名取）。
const NODE_ICON: StringName = &"Icon"
const NODE_ICON_TEXT: StringName = &"IconText"

## === 视觉常量 ================================================================

## 占位块底色——比卡面底色（[code]MapCard.apply_border[/code] 的 0.129）更深一档，
## 使「没有图」这件事本身看得出来（同色会读成卡面留白）。
const PLACEHOLDER_COLOR: Color = Color(0.086, 0.094, 0.12, 1.0)
## 占位块居中文案。本地化注记：项目暂无本地化系统（同 [code]MapCard.TEXT_*[/code]
## 豁免口径）。
const TEXT_NO_IMAGE: String = "暂无图"
## 占位文案字号与色（深底上取烟灰中档，不与卡面正文抢视线）。
const PLACEHOLDER_FONT_SIZE: int = 14
const PLACEHOLDER_TEXT_COLOR: Color = Color(0.62, 0.66, 0.74, 1.0)

## 图标与紧邻文字之间的间距（px）。[br]
## [br][b]为什么钉死在代码里[/b]：这是「图标不压字」的量化口径
## （.claude/rules/ui-code.md 最小分辨率下也要读得清）——交给主题默认值
## （VBox 的 4px）时，紧凑排版下图标会贴到文字上。单测按此常量断言实际间距。
const ICON_GAP: int = 8

## 主题缺省字号（[code]ThemeDB.fallback_font_size[/code] 的出厂值——字体拿不到时
## 的兜底度量基准）。
const FALLBACK_FONT_SIZE: int = 16

## 已加载插图缓存（[code]路径 → Texture2D[/code]）。[br]
## [br][b]为什么自己缓存[/b]：卡片是每次刷新重建的（GSM 变化即重建），17 张卡
## 每轮重建都过一次 [code]load()[/code]；引擎的资源缓存虽在，但显式持一份引用
## 才不会被中途释放掉再重载（打开选图界面时的卡顿来源）。[br]
## [br][b]null 也缓存[/b]：加载失败的路径同样写进表，避免每轮刷新刷一条告警。
static var _cache: Dictionary = {}


## 地图 ID → 插图资源路径；未登记地图返回空串（调用方据此走占位）。[br]
## [br][param p_map_id] 地图 ID（与探明表同源的规范写法）。[br]
static func path_of(p_map_id: StringName) -> String:
	return str(ILLUSTRATIONS.get(StringName(str(p_map_id)), ""))


## 地图 ID → 插图纹理；未登记地图 / 加载失败返回 null（调用方走占位，不崩溃）。[br]
## [br][b]加载失败只告警一次[/b]：null 也写进缓存（见 [member _cache]）。[br]
static func texture_of(p_map_id: StringName) -> Texture2D:
	var path: String = path_of(p_map_id)
	if path.is_empty():
		return null
	if _cache.has(path):
		return _cache[path] as Texture2D
	var texture: Texture2D = load(path) as Texture2D
	if texture == null:
		push_warning("MapCardArt: 插图加载失败（%s）——预览块退回占位" % path)
	_cache[path] = texture
	return texture


## 搭建卡片顶部预览块（有图只留图 / 缺图深色占位 + 居中「暂无图」）。[br]
## [br][param p_map_id] 地图 ID。[br]
## [param p_height] 预览块高度（像素——由卡片高度按比例算得，见
## [code]MapCard.CARD_PREVIEW_HEIGHT[/code]）。[br]
## [br][b]返回[/b]：预览块 [Control]（内层节点名见 [constant NODE_ART] /
## [constant NODE_PLACEHOLDER]）。[br]
## [br][b]为什么是 Control 而不是容器[/b]：卡面内容盒是卡里唯一的 VBoxContainer，
## 测试与宿主靠它认内容盒——预览块再用容器会让「那个盒子」出现第二个候选。[br]
## [br][b]缩放置信[/b]：[code]EXPAND_IGNORE_SIZE[/code] 让纹理不参与最小尺寸
## （否则 360×420 的竖图会把卡面顶高），[code]KEEP_ASPECT_COVERED[/code] 铺满
## 预览框并裁掉溢出——不拉伸变形，也不留边。
static func build_preview(p_map_id: StringName, p_height: float) -> Control:
	var box: Control = Control.new()
	box.name = String(NODE_PREVIEW)
	# 全宽出血贴卡片上沿：卡片是 Panel（不是容器），运行期节点没有编辑器写的
	# 锚点——不显式给就退回锚点预设 0（左上角、宽 0），预览块会缩成一条竖线。
	box.anchor_left = 0.0
	box.anchor_top = 0.0
	box.anchor_right = 1.0
	box.anchor_bottom = 0.0
	box.offset_left = 0.0
	box.offset_top = 0.0
	box.offset_right = 0.0
	box.offset_bottom = p_height
	# 铺满即裁切：KEEP_ASPECT_COVERED 的溢出部分由它剪掉，不外溢到名称行上。
	box.clip_contents = true
	box.custom_minimum_size = Vector2(0.0, p_height)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var placeholder: ColorRect = ColorRect.new()
	placeholder.name = String(NODE_PLACEHOLDER)
	placeholder.set_anchors_preset(Control.PRESET_FULL_RECT)
	placeholder.color = PLACEHOLDER_COLOR
	placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(placeholder)

	var art: TextureRect = TextureRect.new()
	art.name = String(NODE_ART)
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture = texture_of(p_map_id)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(art)

	var label: Label = Label.new()
	label.name = String(NODE_PLACEHOLDER_LABEL)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.text = TEXT_NO_IMAGE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", PLACEHOLDER_FONT_SIZE)
	label.add_theme_color_override(&"font_color", PLACEHOLDER_TEXT_COLOR)
	# 卡面高度写死，行样式统一单行 + 省略号兜底（与 MapCard._trim_single_line 同口径）。
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)

	# 有图只留图；缺图才出占位块与「暂无图」（两层同显会互相盖住）。
	var has_art: bool = art.texture != null
	placeholder.visible = not has_art
	label.visible = not has_art
	art.visible = has_art
	return box


## 搭建「图标 + 文字」一行（🔒 未解锁 / ⭐⭐ 低 这类）。[br]
## [br][param p_name] 行节点名（[code]LockRow[/code] / [code]DifficultyRow[/code]——
## 测试按名取行，再按 [constant NODE_ICON] / [constant NODE_ICON_TEXT] 取内层）。[br]
## [param p_icon] 图标文本（单个字形——🔒 / ⭐ / ▶）。[br]
## [param p_text] 紧随其后的文字。[br]
## [param p_color] 文字与图标的颜色（不填则用主题默认）。[br]
## [param p_icon_size] 图标字号。[br]
## [param p_text_size] 文字字号（0 = 用主题默认）。[br]
## [br][b]图标标签不开 [code]clip_text[/code][/b]：裁切会把最小宽收敛到 1px，
## 而 HBox 是按最小宽分配宽度的——图标会被压成一条缝。图标是固定单字形、不会
## 撑破卡面，故此处豁免（可变的文案标签仍必须带裁切，见
## [code]MapCard._trim_single_line[/code]）。[br]
## [br][b]文字标签带裁切 + 省略号[/b]：长文案兜底与卡面其余各行同口径。
static func build_icon_row(p_name: StringName, p_icon: String, p_text: String,
		p_color: Color, p_icon_size: int, p_text_size: int = 0) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = String(p_name)
	row.add_theme_constant_override(&"separation", ICON_GAP)
	# 行要占满内容盒宽度（VBoxContainer 的横向拉伸只到行这一层，行内两格由 HBox 分）。
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon: Label = Label.new()
	icon.name = String(NODE_ICON)
	icon.text = p_icon
	icon.add_theme_font_size_override(&"font_size", p_icon_size)
	if p_color.a > 0.0:
		icon.add_theme_color_override(&"font_color", p_color)
	# 图标是固定单字形，撑不破卡面——但卡面的「每行都带裁切 + 省略号」不变量
	# （MapCard._trim_single_line 口径）对它同样适用。问题是这两个属性会把 Label
	# 的最小宽收敛到 1px，HBox 按最小宽分配后图标会被压成一条缝——故显式钉上
	# 量得的实宽（见 measure_text），让裁切成为纯兜底而不是实际生效的约束。
	icon.clip_text = true
	icon.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	icon.custom_minimum_size = Vector2(measure_text(p_icon, p_icon_size), 0.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var text: Label = Label.new()
	text.name = String(NODE_ICON_TEXT)
	text.text = p_text
	if p_text_size > 0:
		text.add_theme_font_size_override(&"font_size", p_text_size)
	if p_color.a > 0.0:
		text.add_theme_color_override(&"font_color", p_color)
	text.clip_text = true
	text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	return row


## === 查找入口（测试与宿主用——预览块与图标行都是运行期拼的）===================

## 卡片内的预览纹理节点（无预览块时 null）。
static func art_of(p_card: Node) -> TextureRect:
	return p_card.find_child(String(NODE_ART), true, false) as TextureRect


## 卡片内的占位色块（无预览块时 null）。
static func placeholder_of(p_card: Node) -> ColorRect:
	return p_card.find_child(String(NODE_PLACEHOLDER), true, false) as ColorRect


## 卡片内的占位文案标签（无预览块时 null）。
static func placeholder_label_of(p_card: Node) -> Label:
	return p_card.find_child(String(NODE_PLACEHOLDER_LABEL), true, false) as Label


## 卡片内的预览框本身（无预览块时 null）。
static func preview_of(p_card: Node) -> Control:
	return p_card.find_child(String(NODE_PREVIEW), true, false) as Control


## 卡片内的某个图标行（[param p_name] 见 [method build_icon_row]；无则 null）。
static func icon_row_of(p_card: Node, p_name: StringName) -> HBoxContainer:
	return p_card.find_child(String(p_name), true, false) as HBoxContainer


## 文本的渲染像素宽（图标行的最小宽兜底用——见 [method build_icon_row]）。[br]
## [br][b]为什么不用 [method Control.get_minimum_size][/b]：开了 [code]clip_text[/code]
## 之后最小尺寸恒为 1px，量不出内容；字体的 [method Font.get_string_size] 给的是
## 渲染实际宽度（[code]ExplorationInfoArea._text_width[/code] 同源做法）。[br]
## [br][b]字体取不到时返回 0[/b]：不臆造一个宽度，交给布局自己算。[br]
static func measure_text(p_text: String, p_size: int) -> float:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return 0.0
	var size: int = p_size if p_size > 0 else FALLBACK_FONT_SIZE
	return font.get_string_size(p_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
