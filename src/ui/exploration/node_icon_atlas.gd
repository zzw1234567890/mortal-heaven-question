class_name NodeIconAtlas
extends RefCounted
## NodeIconAtlas —— 节点类型 → 图标图集映射（exploration-ui Story 001 stub）。
##
## [b]纯函数静态类[/b]（ADR-0031 Logic 内核模式）：10 类节点类型的颜色/词条/
## 图集 region 判定——UI 节点只消费映射结果。[br]
## [br][b]stub 图标[/b]：程序化生成单一图集（320×32，10 格×32px）——
## ADR-0031 §5「UI 图标统一使用 AtlasTexture，禁止独立纹理逐图标渲染」的直接
## 兑现。真实图标美术归资产管线 story（替换点：[method _build_atlas]——
## hud TD-011 emoji 占位同源技债，届时一并替换）。[br]
## [br][b]类型 ID 对齐[/b]：与 [code]ExplorationSystem.NodeType[/code] 枚举值
## 一一对应（0=入口 … 9=渡劫台）——语义来源 GDD exploration-ui-system.md
## §公式 1 node_type_to_icon。
##
## [br]来源: ADR-0031 §5、design/gdd/exploration-ui-system.md §公式 1、
## exploration-ui Story 001（R-05 行为关卡）。

## 单元格边长（px）——节点图标 region 尺寸基准。
const CELL: int = 32
## 图集列数（10 类节点各占一格）。
const ATLAS_COLS: int = 10

## 节点类型规格——GDD node_type_to_icon 映射（id ↔ NodeType 枚举值）。
## color 为节点类型主色；glyph 为 stub 图标内白色图形标识（真实图标入库后废弃）。
const TYPE_SPECS: Dictionary = {
	0: {"label": "入口", "color": Color("#8B7355"), "glyph": "circle"},
	1: {"label": "战斗", "color": Color("#CC4444"), "glyph": "square"},
	2: {"label": "精英", "color": Color("#FF4444"), "glyph": "diamond"},
	3: {"label": "Boss", "color": Color("#FFD700"), "glyph": "crown"},
	4: {"label": "事件", "color": Color("#4488CC"), "glyph": "ring"},
	5: {"label": "商店", "color": Color("#44CC88"), "glyph": "triangle"},
	6: {"label": "传送", "color": Color("#9944CC"), "glyph": "star"},
	7: {"label": "灵泉", "color": Color("#44AAFF"), "glyph": "drop"},
	8: {"label": "回复点", "color": Color("#44CC66"), "glyph": "cross"},
	9: {"label": "渡劫台", "color": Color("#FFAA00"), "glyph": "bolt"},
}

## 图集缓存——单实例跨全部节点共享（合批前提：同纹理才能合批）。
static var _atlas: Texture2D = null


## 获取（或首次构建）节点图标图集。[br]
## [br][b]返回[/b]: 320×32 [ImageTexture]——10 格 × 32px，每格 = 类型主色底 +
## 白色 glyph 图形（stub 视觉，真实图标入库后替换本方法实现）。
static func get_atlas() -> Texture2D:
	if _atlas == null:
		_atlas = _build_atlas()
	return _atlas


## 获取节点类型的图集 region（AtlasTexture 语义——绘制时传
## [code]draw_texture_rect_region[/code] 的 src_rect）。
static func get_region(type_id: int) -> Rect2:
	var col: int = _clamp_id(type_id)
	return Rect2(float(col * CELL), 0.0, float(CELL), float(CELL))


## 获取节点类型主色（边框/连线视觉决策用——GDD 界面规则表）。
static func get_color(type_id: int) -> Color:
	return TYPE_SPECS[_clamp_id(type_id)]["color"]


## 获取节点类型词条（GDD 固定文案——项目暂无本地化系统，本地化入库后
## 替换为键，story 约束注记同 realm_bar TOOLTIP_PREFIX 先例）。
static func get_label(type_id: int) -> String:
	return TYPE_SPECS[_clamp_id(type_id)]["label"]


## 程序化构建 stub 图集——逐格填充类型主色 + 白色 glyph 像素。
static func _build_atlas() -> Texture2D:
	var img := Image.create_empty(CELL * ATLAS_COLS, CELL, false, Image.FORMAT_RGBA8)
	for col: int in ATLAS_COLS:
		var color: Color = TYPE_SPECS[col]["color"]
		var glyph: String = TYPE_SPECS[col]["glyph"]
		for py: int in CELL:
			for px: int in CELL:
				var c: Color = color
				if _glyph_pixel(glyph, float(px) / float(CELL), float(py) / float(CELL)):
					c = Color(0.96, 0.94, 0.88)  # 暖白——美术圣经底色系
				img.set_pixel(col * CELL + px, py, c)
	return ImageTexture.create_from_image(img)


## glyph 形状判定——cell 归一化坐标 (x, y) ∈ [0,1]² 是否属于白色图形。[br]
## 10 种图形互异（同色类型仍可区分：战斗红方 / 精英红菱形等）。
static func _glyph_pixel(glyph: String, x: float, y: float) -> bool:
	var cx: float = x - 0.5
	var cy: float = y - 0.5
	match glyph:
		"circle":
			return cx * cx + cy * cy <= 0.09
		"square":
			return absf(cx) <= 0.28 and absf(cy) <= 0.28
		"diamond":
			return absf(cx) + absf(cy) <= 0.42
		"crown":
			return (absf(x - 0.30) <= 0.06 or absf(x - 0.50) <= 0.06 or absf(x - 0.70) <= 0.06) \
					and y >= 0.30 and y <= 0.62
		"ring":
			var r: float = cx * cx + cy * cy
			return r >= 0.05 and r <= 0.11
		"triangle":
			return y >= 0.32 and y <= 0.70 and absf(cx) <= (y - 0.32) * 0.9
		"star":
			return absf(cx) <= 0.07 or absf(cy) <= 0.07  # 四芒星
		"drop":
			return (cx * cx + (cy - 0.10) * (cy - 0.10) <= 0.07) \
					or (absf(cx) <= 0.05 and cy < -0.05)
		"cross":
			return (absf(cx) <= 0.08 and absf(cy) <= 0.30) \
					or (absf(cy) <= 0.08 and absf(cx) <= 0.30)
		"bolt":
			return (absf(x - 0.45) <= 0.07 and y <= 0.50) \
					or (absf(x - 0.58) <= 0.07 and y >= 0.42)
	return false


## 类型 ID 钳制到合法区间（防御——未知 ID 回退 COMBAT 色）。
static func _clamp_id(type_id: int) -> int:
	return clampi(type_id, 0, ATLAS_COLS - 1)
