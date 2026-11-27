extends RefCounted
## NodeGraphRegionPaper —— 地区层的[b]第三笔：地名纸条[/b]（半透明宣纸 + 1px 墨边）。[br]
##
## [b]为什么地名要在地区上再写一遍[/b]（节点下方那行已经有了）：两者回答不同的距离。
## 节点下方那行是「凑近看这一格叫什么」；地区纸条是「扫一眼这片地叫什么」——缩放到
## [constant NodeGraphViewport.LABEL_HIDE_ZOOM] 时节点标签整批隐藏，而地图上仍需要
## 读得出地名，否则缩放之后整张图变成一片无名色块。[br]
##
## [br][b]★ 深字压浅底，与节点标签恰好相反 ★[/b]：节点标签是浅字压深底（描边字），
## 纸条是深字压浅底——因为纸条本身是一张[b]纸[/b]，纸上的字只能是墨。这条不是审美
## 偏好：同一张图上两种「字压底」的关系若都做成浅压深，纸条就与节点标签糊成一类，
## 「哪一行属于哪一格」立刻分不清。[br]
##
## [br][b]纸条画在图标下方[/b]（[constant RegionStyle.PAPER_OFFSET_Y]），不与圆印重叠
## ——圆印是 44~56px 的实体，纸条压上去会把图标的关键笔画盖掉。[br]
##
## [br][b]零状态所有权[/b]（ADR-0031 §2）：宿主经参数传入，只读快照。[br]
##
## [br]来源: 本轮任务书任务二（地名纸条与图标不重叠）、老板 2026-11-27 反馈、
## ADR-0031 §2。

## 地区视觉规格（纸条尺寸/配色/字号）。
const RegionStyle := preload("res://src/ui/exploration/node_graph_style_region.gd")
## 地区层共享读写口（可见集合与六态视觉——朱红印记按态决定画不画）。
const RegionCommon := preload("res://src/ui/exploration/node_graph_region_common.gd")
## 字体口径（与节点标签同源）。
const Style := preload("res://src/ui/exploration/node_graph_style.gd")


## 逐地区画地名纸条。[br]
## [br][b]中心取地区多边形的几何重心，而不是节点坐标[/b]：Voronoi 的种子不必落在自己的
## 单元内部（节点分布不均时种子可能被邻块挤到自己地盘之外），按种子画纸条会飘到邻块上
## 去——而纸条正是用来回答「这一片叫什么」的。[br]
## [br][b]没有地名的地区不画纸条[/b]：空串画出来是一个没有字的空白纸块，比不画更可疑。[br]
## [br][param p_cells] 分块表；[param p_ids] 参与绘制的地区 ID（已按层过滤并排序）。
static func draw_papers(p_host: Control, p_cells: Dictionary, p_ids: Array) -> void:
	var font: Font = font_of(p_host)
	for node_id: int in p_ids:
		var poly: PackedVector2Array = p_cells[node_id]
		if poly.size() < 3:
			continue
		var text: String = str(p_host.call(&"place_name_of", node_id))
		if text.is_empty():
			continue
		draw_paper(p_host, font, centroid(poly), text,
				bool(RegionCommon.visual_of(p_host, node_id).get("seal", false)))


## 单张纸条——纸块 + 墨边 + 文字 + 可选的朱红印记。[br]
## [br][b]为什么单独一个入口（而不是并进 [method draw_papers]）[/b]：截图工具与集成测试
## 要用[b]定点[/b]画一张纸条来验证「字不溢出纸面」「印记不压字」，而这需要绕过
## [code]place_name_of[/code] 那一层宿主协议。[br]
## [br][param p_anchor] 纸条中心（调用方给的是地区重心 + 下移量）。[br]
## [param p_with_seal] 是否画朱红印记（当前节点——[method RegionStyle.region_visual]
## 的 [code]seal[/code] 键）。
static func draw_paper(p_host: Control, p_font: Font, p_anchor: Vector2, p_text: String,
		p_with_seal: bool) -> void:
	var text_width: float = maxf(measure_width(p_font, p_text),
			float(p_text.length()) * RegionStyle.PAPER_MIN_CHAR_WIDTH)
	var width: float = text_width + RegionStyle.PAPER_PADDING * 2.0
	var box := Rect2(p_anchor - Vector2(width * 0.5, RegionStyle.PAPER_HEIGHT * 0.5),
			Vector2(width, RegionStyle.PAPER_HEIGHT))
	p_host.draw_rect(box, RegionStyle.PAPER_COLOR)
	p_host.draw_rect(box, RegionStyle.PAPER_EDGE_COLOR, false, RegionStyle.PAPER_EDGE_WIDTH)
	# 基线：纸面垂直居中（0.36 是 CJK 字体 ascent 的经验占比——按字形框算会偏低）
	var baseline: Vector2 = box.position + Vector2(RegionStyle.PAPER_PADDING,
			RegionStyle.PAPER_HEIGHT * 0.5 + float(RegionStyle.PAPER_FONT_SIZE) * 0.36)
	p_host.draw_string(p_font, baseline, p_text, HORIZONTAL_ALIGNMENT_LEFT,
			text_width, RegionStyle.PAPER_FONT_SIZE, RegionStyle.PAPER_TEXT_COLOR)
	if p_with_seal:
		p_host.draw_circle(Vector2(box.end.x, box.position.y), RegionStyle.SEAL_RADIUS,
				RegionStyle.SEAL_COLOR)


## 文本宽度——[b]真测[/b]（字体可测则测）。[br]
## [br][b]为什么要真测而不是按字符数估[/b]：中文字宽几乎等于字号，拉丁字符只有一半
## ——纯按字符数估会让纯中文地名（本项目地名全是中文）的纸条过宽、把字与纸边拉开一大截，
## 而混排地名又会被截掉。[br]
## [br][b]为什么还要留一个字符数下限[/b]（[constant RegionStyle.PAPER_MIN_CHAR_WIDTH]）：
## 字体资产缺失时 [code]ThemeDB.fallback_font[/code] 对中日韩字形可能给 0 宽（缺字形
## 时不报错、直接量出 0），纸条会缩成一条缝。[br]
## [br][b]返回[/b]：文字宽度（不含内边距）。
static func measure_width(p_font: Font, p_text: String) -> float:
	if p_font == null:
		return 0.0
	return p_font.get_string_size(p_text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			RegionStyle.PAPER_FONT_SIZE).x


## 多边形顶点均值（几何重心的近似）。[br]
## [br][b]为什么不用面积加权重心[/b]：均值在凸多边形上与真重心通常只差几像素，而纸条
## 本身有 30px 高、由玩家粗读——精确重心带来的差别读不出来；均值是三行代码。[br]
## [br][b]空表保护[/b]：调用方已按 [code]size() < 3[/code] 过滤，这里是二层保险
## （除零会得到 NaN 坐标，画出来的纸条会消失在一个无法调试的位置）。
static func centroid(p_poly: PackedVector2Array) -> Vector2:
	if p_poly.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	for p: Vector2 in p_poly:
		sum += p
	return sum / float(p_poly.size())


## 文字字体——主题默认（同节点标签的口径：两处问同一个来源，字体资产接入时一起生效）。[br]
## [br][b]fallback 为什么必需[/b]：headless 测试里没有 Control 的场景树，主题字体可能
## 为 null；给了 fallback 才能在无主题环境下也画出一张纸条（截图工具依赖它）。
static func font_of(p_host: Control) -> Font:
	var theme_font: Font = p_host.get_theme_default_font()
	return theme_font if theme_font != null else ThemeDB.fallback_font
