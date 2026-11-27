extends RefCounted
## NodeGraphTerrain —— 节点图的[b]地形底图[/b]（地图插画 + 压暗 + vignette）。[br]
##
## [b]为什么单独成文件[/b]：「这块画布垫的是什么」与「节点/连线画在哪」是两件事，
## 且本模块与布局、命中检测、状态判定都没有交集（同 [code]node_graph_style.gd[/code] /
## [code]node_graph_layout.gd[/code] 的拆分口径）。[br]
##
## [br][b]为什么是画布而不是 TextureRect 节点[/b]：地形必须画在 [code]NodeGraphRenderer[/code]
## 的局部坐标里——渲染器被 [code]NodeGraphViewport[/code] 整体缩放平移，插画要跟着
## 节点一起走（平移时像摊开的地图，而不是钉在屏幕上的壁纸）。用一个 TextureRect 做
## 就要在每次 [code]_apply_transform[/code] 后手工同步它的变换，等于把视口的单一写入点
## 拆成两处。[br]
##
## [br][b]零状态所有权[/b]（ADR-0031 §2）：纹理只读、矩形只算不存；调用方（渲染器）
## 每次 [code]_draw[/code] 传当前内容矩形进来。[br]
##
## [br][b]不新增美术资源[/b]：插画来自 [code]MapCardArt[/code] 已有 17 张
## （[code]assets/environments/maps/[/code]），本模块只负责「铺多大、压多暗、边缘多黑」。[br]
##
## 来源: 本轮任务书任务三（背景铺图 + 四边 vignette）、ADR-0031 §2/§5、
## .claude/rules/ui-code.md（最小分辨率下完整可读）。

## 视觉规格（常量唯一来源——与节点/连线共用同一份）。
const Style := preload("res://src/ui/exploration/node_graph_style.gd")
## 地图插画来源（[code]path_of[/code] / [code]texture_of[/code]，已有 17 张）。
const MapCardArtScript := preload("res://src/ui/exploration/map_card_art.gd")


## 画整块地形：底色 → 插画（cover 铺满）→ 压暗叠层 → 四边 vignette。[br]
## [br][param p_host] 绘制宿主（渲染器）。[br]
## [param p_rect] 地形铺满的局部矩形（渲染器传 [code]content_rect.grow(FOG_MARGIN)[/code]
## ——与迷雾遮罩同尺寸，免得地形露出「没被雾盖住的一圈边」）。[br]
## [param p_map_id] 当前地图 ID（未登记 / 无图时为空白，只留底色）。[br]
## [br][b]五笔固定顺序[/b]（后画的压在先画的上面）：底色矩形 → 插画 → 压暗 → vignette。[br]
## [br][b]为什么要单独一层压暗而不是靠 modulate 的 alpha[/b]：把插画本身调很透
## （α 0.3）时亮部细节已经看不见，而亮部正是「这是一张地图」的读法来源——先按
## 0.34 铺上，再叠一层暖黑把整体拉回暗底，亮部仍有相对落差，节点图标依旧跳得出来。[br]
## [br][b]与迷雾的关系[/b]：地形画在最底层（雾遮罩之下），遮罩负责「雾里/雾外」的
## 底色落差——两者不抢同一件事，故本模块不需要知道任何状态。
static func draw(p_host: Control, p_rect: Rect2, p_map_id: StringName) -> void:
	if p_rect.size.x <= 0.0 or p_rect.size.y <= 0.0:
		return
	p_host.draw_rect(p_rect, Style.TERRAIN_BASE_COLOR)
	var texture: Texture2D = MapCardArtScript.texture_of(p_map_id)
	if texture != null:
		p_host.draw_texture_rect(texture, cover_rect(p_rect, texture.get_size()), false,
				Color(1.0, 1.0, 1.0, Style.TERRAIN_IMAGE_ALPHA))
	p_host.draw_rect(p_rect, Style.TERRAIN_DARKEN_COLOR)
	draw_vignette(p_host, p_rect)


## 插画按[b]等比铺满[/b]映射到 [param p_area]（溢出的部分靠铺满自然出界，不拉伸变形）。[br]
## [br]口径同 [code]TextureRect.STRETCH_KEEP_ASPECT_COVERED[/code]，但手算——
## 本模块画在 [code]_draw[/code] 里，没有 [code]TextureRect[/code] 的 stretch 模式可用。[br]
## [br][b]纹理尺寸为 0 时原样返回[/b]（不臆造一个除数为 0 的缩放）。[br]
## [br][b]返回[/b]：以 [param p_area] 中心对齐的绘制矩形。
static func cover_rect(p_area: Rect2, p_texture_size: Vector2) -> Rect2:
	if p_texture_size.x <= 0.0 or p_texture_size.y <= 0.0:
		return p_area
	var scale_factor: float = maxf(p_area.size.x / p_texture_size.x,
			p_area.size.y / p_texture_size.y)
	var drawn: Vector2 = p_texture_size * scale_factor
	return Rect2(p_area.position + (p_area.size - drawn) * 0.5, drawn)


## 四边 vignette——[b]不重叠[/b]的同心框带，由外向内逐圈变浅。[br]
## [br][b]为什么用框带而不是叠 N 层实心矩形[/b]：实心矩形会层层叠在中心上，
## 越靠中间 alpha 累加越多，最后把整块图压黑（正好是上一轮「图画成一片黑」的同款
## 事故）。框带之间不重叠，每一圈的浓度就是常量表里那一个值，边缘深、中心净。[br]
## [br][b]为什么 3 圈就够[/b]：这是「暗角」不是渐变贴图，目标是让画面四边收进暗处、
## 视线留在中央的节点上——3 圈已经读得出过渡，再多只是加绘制调用。[br]
## [br][b]返回[/b]：无（就地绘制）。
static func draw_vignette(p_host: Control, p_rect: Rect2) -> void:
	var band: float = minf(p_rect.size.x, p_rect.size.y) * Style.VIGNETTE_BAND_RATIO
	if band <= 1.0:
		return
	var step: float = band / float(Style.VIGNETTE_STEPS)
	for i: int in Style.VIGNETTE_STEPS:
		# 第 0 圈最外、最浓；每向内一圈浓度按 1/(i+1) 衰减
		var alpha: float = Style.VIGNETTE_ALPHA / float(i + 1)
		var ring: Rect2 = p_rect.grow(-step * float(i))
		if ring.size.x <= 0.0 or ring.size.y <= 0.0:
			break
		var color := Color(Style.VIGNETTE_COLOR.r, Style.VIGNETTE_COLOR.g,
				Style.VIGNETTE_COLOR.b, alpha)
		# 上下两条横带 + 左右两条竖带（四边各一条，互不重叠）
		p_host.draw_rect(Rect2(ring.position, Vector2(ring.size.x, step)), color)
		p_host.draw_rect(Rect2(ring.position + Vector2(0.0, ring.size.y - step),
				Vector2(ring.size.x, step)), color)
		p_host.draw_rect(Rect2(ring.position, Vector2(step, ring.size.y)), color)
		p_host.draw_rect(Rect2(ring.position + Vector2(ring.size.x - step, 0.0),
				Vector2(step, ring.size.y)), color)
