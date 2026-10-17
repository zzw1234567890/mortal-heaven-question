class_name CombatIconAtlas
extends RefCounted
## CombatIconAtlas —— combat-ui 图标 stub 图集（combat-ui-layout Story 002）。
##
## [b]纯函数静态类[/b]（ADR-0031 Logic 内核模式）：角色状态卡全部图标
## 的图集 region 判定——R-02 §1「图集合批为 Required pattern」的直接兑现
## （禁止独立纹理逐图标渲染）。[br]
## [br][b]stub 图标[/b]：程序化生成单一图集（256×32，8 格×32px）——
## 真实图标美术归资产管线 story（替换点：[method _build_atlas]——
## [code]NodeIconAtlas[/code] 同源技债，届时一并替换）。[br]
## [br][b]region 索引[/b]：与 [code]IconId[/code] 枚举一一对应——语义来源
## R-02 §1 图集划分（status/corner_badge 合并为单图集——stub 阶段
## 合批优先，美术入库后按 R-02 四图集拆分）。
##
## @experimental
## 来源: ADR-0031 §5、production/qa/evidence/r02-batching-spec.md §1/§3、
## combat-ui-layout Story 002。

## 图标 ID——图集 region 列索引。
enum IconId {
	GONGFA = 0,   ## 功法（L2 左栏）
	FABAO = 1,    ## 法宝（L2 右栏）
	BUFF = 2,     ## 增益（L4 左下——绿色上箭头）
	DEBUFF = 3,   ## 减益（L4 左下——红色下箭头，形状异于增益供色盲区分）
	BADGE_STANDBY = 4,  ## 待命标记（L5 左上——沙漏形）
	BADGE_ACTED = 5,    ## 已行动标记（L5 左上——对勾形）
	BADGE_REALM = 6,    ## 境界标记（L4 右下——上尖角，仅高于玩家境界时显示）
	BACKING = 7,  ## 半透明背板格（L2 侧栏底）
}

## 单元格边长（px）——region 尺寸基准。
const CELL: int = 32
## 图集列数（IconId 数量）。
const ATLAS_COLS: int = 8

## 图标规格——glyph 形状 + 底色（stub 视觉参数）。
const ICON_SPECS: Dictionary = {
	IconId.GONGFA: {"glyph": "scroll", "color": Color("#8B7355")},
	IconId.FABAO: {"glyph": "sword", "color": Color("#7A8BA8")},
	IconId.BUFF: {"glyph": "arrow_up", "color": Color("#44CC66")},
	IconId.DEBUFF: {"glyph": "arrow_down", "color": Color("#CC4444")},
	IconId.BADGE_STANDBY: {"glyph": "hourglass", "color": Color("#E8C06A")},
	IconId.BADGE_ACTED: {"glyph": "check", "color": Color("#9A9A9A")},
	IconId.BADGE_REALM: {"glyph": "chevron_up", "color": Color("#9944CC")},
	IconId.BACKING: {"glyph": "none", "color": Color(0.05, 0.05, 0.08, 0.45)},
}

## 图集缓存——单实例跨全部角色卡共享（合批前提：同纹理才能合批）。
static var _atlas: Texture2D = null

## 底部渐变遮罩（L1）——静态共享 GradientTexture2D（透明 → 黑 60%，
## 保证 L3 文字对比度 ≥4.5:1——UX 角色状态卡验收）。
static var _mask: Texture2D = null


## 获取（或首次构建）图标图集。
static func get_atlas() -> Texture2D:
	if _atlas == null:
		_atlas = _build_atlas()
	return _atlas


## 获取图标的图集 region（绘制时传 [code]draw_texture_rect_region[/code]
## 的 src_rect）。
static func get_region(icon_id: int) -> Rect2:
	var col: int = clampi(icon_id, 0, ATLAS_COLS - 1)
	return Rect2(float(col * CELL), 0.0, float(CELL), float(CELL))


## 获取 L1 渐变遮罩纹理（全卡幅绘制——竖向透明→黑）。
static func get_mask() -> Texture2D:
	if _mask == null:
		var grad := Gradient.new()
		grad.set_color(0, Color(0, 0, 0, 0))
		grad.set_color(1, Color(0, 0, 0, 0.6))
		var tex := GradientTexture2D.new()
		tex.gradient = grad
		tex.fill_from = Vector2(0.4, 0.0)
		tex.fill_to = Vector2(0.6, 1.0)
		_mask = tex
	return _mask


## 程序化构建 stub 图集——逐格填充底色 + 白色 glyph 像素。
static func _build_atlas() -> Texture2D:
	var img := Image.create_empty(CELL * ATLAS_COLS, CELL, false, Image.FORMAT_RGBA8)
	for col: int in ATLAS_COLS:
		var spec: Dictionary = ICON_SPECS[col]
		var color: Color = spec["color"]
		var glyph: String = spec["glyph"]
		for py: int in CELL:
			for px: int in CELL:
				var c: Color = color
				if _glyph_pixel(glyph, float(px) / float(CELL), float(py) / float(CELL)):
					c = Color(0.96, 0.94, 0.88)  # 暖白——美术圣经底色系
				img.set_pixel(col * CELL + px, py, c)
	return ImageTexture.create_from_image(img)


## glyph 形状判定——cell 归一化坐标 (x, y) ∈ [0,1]² 是否属于白色图形。[br]
## 增益/减益形状互异（上/下箭头）——色盲可区分（UX 无障碍：非仅颜色传达）。
static func _glyph_pixel(glyph: String, x: float, y: float) -> bool:
	var cx: float = x - 0.5
	var cy: float = y - 0.5
	match glyph:
		"none":
			return false
		"scroll":  # 卷轴：横条 + 上下卷边
			return (absf(cy) <= 0.10 and absf(cx) <= 0.34) \
					or (absf(cx) <= 0.34 and absf(cy - 0.26) <= 0.05) \
					or (absf(cx) <= 0.34 and absf(cy + 0.26) <= 0.05)
		"sword":  # 剑：竖刃 + 横格 + 柄
			return (absf(cx) <= 0.06 and cy <= 0.10) \
					or (absf(cy - 0.16) <= 0.05 and absf(cx) <= 0.24) \
					or (absf(cx) <= 0.05 and cy >= 0.22)
		"arrow_up":  # 上箭头：竖杆 + 上三角头
			return (absf(cx) <= 0.09 and cy >= -0.08 and cy <= 0.36) \
					or (cy <= -0.06 and cy >= -0.34 and absf(cx) <= (cy + 0.36))
		"arrow_down":  # 下箭头：竖杆 + 下三角头（与上箭头镜像互异——色盲可区分）
			return (absf(cx) <= 0.09 and cy >= -0.36 and cy <= 0.08) \
					or (cy >= 0.06 and cy <= 0.34 and absf(cx) <= (0.34 - cy))
		"hourglass":  # 沙漏：上下三角对顶
			return absf(cx) <= 0.30 * (1.0 - absf(cy) * 2.0) and absf(cy) <= 0.36 \
					or (absf(cx) <= 0.06 and absf(cy) <= 0.36)
		"check":  # 对勾
			return (cy >= -0.05 and cy <= 0.20 and absf(cx + (cy - 0.075) * 1.6) <= 0.06) \
					or (cy >= -0.30 and cy <= 0.02 and absf(cx - (cy + 0.30) * 0.45 - 0.02) <= 0.055)
		"chevron_up":
			return absf(cx) <= (0.38 + cy * 0.9) and absf(cx) >= (cy * 0.9 - 0.02) \
					and cy >= -0.34 and cy <= 0.16
	return false
