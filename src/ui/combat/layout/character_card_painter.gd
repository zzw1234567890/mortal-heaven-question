extends RefCounted
## CharacterCardPainter —— 角色状态卡的六层绘制（L0-L5，纯绘制）。[br]
## [br][b]为什么单独成文件[/b]：[code]character_status_card.gd[/code] 越过单文件
## 300 行软上限（coding-standards），而「六层画成什么样」占了其中一大块——
## 与状态更新的入口方法（[code]apply_hp[/code] 等）、Tween 编排都不相交。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本模块不持任何状态——宿主（卡）作为
## [param p_host] 传入，只[b]读[/b]它的渲染快照并把画笔落在它身上；状态更新仍走
## 卡上的入口方法。[br]
## [br]来源: ADR-0031、design/ux/combat-ui.md §角色状态卡、
## production/qa/evidence/r02-batching-spec.md、combat-ui-layout Story 002/003。

## 共享图集与纯函数模块（story 001/002 唯一落地处——禁止内联）。
const Icons := preload("res://src/ui/combat/shared/combat_icon_atlas.gd")
const Rules := preload("res://src/ui/combat/shared/combat_ui_rules.gd")
## 阵亡判定与视觉规格（判定收在那边，本模块只画）。
const DefeatMarker := preload("res://src/ui/combat/layout/combat_card_defeat_marker.gd")
## 视觉规格常量（尺寸/配色/时长——唯一来源）。
const Style := preload("res://src/ui/combat/layout/character_card_style.gd")


## 六层绘制总入口（宿主 [code]_draw()[/code] 内调用）。[br]
## [br][b]层序[/b]：L0 头像 → L1 渐变遮罩 → L2 侧栏 → L3 底条 → L4 角标 →
## L5 待命标记 → 阵亡灰化 → 已行动遮罩 → 边框（最后绘——顶层描边）。
static func draw_all(p_host: Control) -> void:
	var card_size: Vector2 = p_host.size
	if card_size.x <= 0.0 or card_size.y <= 0.0:
		return
	draw_portrait(p_host, card_size)
	draw_bottom_bar(p_host, card_size)
	draw_badges(p_host)
	draw_standby_badge(p_host)
	# 阵亡灰化（story 003 AC-4——压住头像与 HP 条，让「这格倒了」一眼可见；
	# 画在文字子节点之下、边框之上）。规格与绘制同源，见 DefeatMarker；
	# 底部条高度由本卡给出，免得那边也写一个 40。
	DefeatMarker.draw_on(p_host, card_size, p_host.is_defeated, Style.BOTTOM_BAR_HEIGHT)
	# 已行动灰色遮罩（story 003 AC-2——顶层覆盖，L5 标记之上边框之下）
	if p_host.is_acted:
		p_host.draw_rect(Rect2(Vector2.ZERO, card_size), Style.ACTED_OVERLAY_COLOR)
	draw_border(p_host)


## L0 头像全幅背景 + L1 底部渐变遮罩 + L2 左右侧栏。[br]
## [br][b]合批[/b]（R-02 §3）：头像走独立纹理（每角色唯一），遮罩与侧栏图标
## 同走 [CombatIconAtlas] 单图集（同纹理 [code]draw_texture_rect_region[/code] 合批）。
static func draw_portrait(p_host: Control, card_size: Vector2) -> void:
	if p_host.portrait != null:
		p_host.draw_texture_rect(p_host.portrait,
				Rect2(Vector2.ZERO, card_size), true)
	else:
		p_host.draw_rect(Rect2(Vector2.ZERO, card_size), Style.PORTRAIT_PLACEHOLDER)
	# L1 底部渐变遮罩（透明 → 黑 60%——L3 文字可读性）
	p_host.draw_texture_rect(Icons.get_mask(), Rect2(Vector2.ZERO, card_size), true)
	# L2 左右功法/法宝竖排（同一图集批次）
	draw_side_icons(p_host, true)
	draw_side_icons(p_host, false)


## L3 底部条：不透明背板 + HP 条（[code]draw_rect[/code] 纯色）+ ATK 文字。[br]
## [br][b]文字在 Label 子节点上[/b]（R-02 §3 单 Label 合并）——本模块只画背板与血条，
## 数值文字由卡的 [code]_refresh()[/code] 摆放（文字要随响应式字号重排）。
static func draw_bottom_bar(p_host: Control, card_size: Vector2) -> void:
	var bar_rect: Rect2 = Rect2(0.0, card_size.y - Style.BOTTOM_BAR_HEIGHT,
			card_size.x, Style.BOTTOM_BAR_HEIGHT)
	p_host.draw_rect(bar_rect, Style.BOTTOM_BAR_BG)
	draw_hp_bar(p_host, bar_rect)


## HP 条绘制（R-02 §2——[code]draw_rect[/code] 纯色三段：底槽 / 前景 /
## 边框省略——§5 实测边框 outline 可裁剪省 1 DC，本实现裁剪）。
static func draw_hp_bar(p_host: Control, bar_rect: Rect2) -> void:
	var track: Rect2 = Rect2(
			bar_rect.position.x + Style.SIDE_BAR_WIDTH,
			bar_rect.position.y + Style.HP_TRACK_TOP,
			bar_rect.size.x - Style.SIDE_BAR_WIDTH * 2.0, Style.HP_TRACK_HEIGHT)
	p_host.draw_rect(track, Style.HP_TRACK_COLOR)
	var fill_width: float = track.size.x * p_host._hp_display_ratio
	if fill_width > 0.0:
		var fill: Rect2 = Rect2(track.position.x, track.position.y,
				fill_width, track.size.y)
		p_host.draw_rect(fill, Rules.hp_bar_color(hp_ratio(p_host)))


## 当前 HP 比例（[code]max_hp == 0[/code] 时给 1.0——除零守卫，同
## [code]apply_hp[/code] 的口径）。
static func hp_ratio(p_host: Control) -> float:
	if p_host.max_hp == 0:
		return 1.0
	return clampf(float(p_host.current_hp) / float(p_host.max_hp), 0.0, 1.0)


## L4 角标绘制：左下 buff/debuff + 右下境界（仅高于玩家境界）。[br]
## [br][b]左 buff 上 / debuff 下[/b]，合计 ≤5——上限钳制在
## [code]set_status_effects[/code]（本模块不再钳一次）。
static func draw_badges(p_host: Control) -> void:
	var atlas: Texture2D = Icons.get_atlas()
	var buff_region: Rect2 = Icons.get_region(Icons.IconId.BUFF)
	var debuff_region: Rect2 = Icons.get_region(Icons.IconId.DEBUFF)
	var y_base: float = p_host.size.y - Style.BOTTOM_BAR_HEIGHT \
			- Style.BADGE_SIZE - Style.BADGE_BOTTOM_INSET
	var x: float = Style.SIDE_BAR_WIDTH + Style.BADGE_INSET
	var slot: int = 0
	for i: int in p_host.buff_count:
		p_host.draw_texture_rect_region(atlas,
			Rect2(x, y_base - float(slot) * (Style.BADGE_SIZE + Style.BADGE_GAP),
				Style.BADGE_SIZE, Style.BADGE_SIZE), buff_region)
		slot += 1
	for i: int in p_host.debuff_count:
		p_host.draw_texture_rect_region(atlas,
			Rect2(x, y_base - float(slot) * (Style.BADGE_SIZE + Style.BADGE_GAP),
				Style.BADGE_SIZE, Style.BADGE_SIZE), debuff_region)
		slot += 1
	# 右下：境界角标（story AC-6——仅高于玩家境界时显示）
	if p_host.realm > p_host.player_realm and p_host.realm > 0:
		var realm_region: Rect2 = Icons.get_region(Icons.IconId.BADGE_REALM)
		p_host.draw_texture_rect_region(atlas,
			Rect2(p_host.size.x - Style.SIDE_BAR_WIDTH - Style.BADGE_SIZE
				- Style.BADGE_INSET,
				y_base, Style.BADGE_SIZE, Style.BADGE_SIZE), realm_region)


## L5 待命/已行动标记（左上——is_standby=true 待命沙漏 / false 已行动对勾；
## 渲染归本 story，切换逻辑归 story 003）。[br]
## [br][b]淡出中的沙漏[/b]：语义已就绪但仍按 [code]_badge_alpha[/code] 画沙漏
## （待命→已就绪的 0.3s 渐隐通道——瞬态视觉状态，§2.1 豁免）。
static func draw_standby_badge(p_host: Control) -> void:
	var badge_id: int
	var alpha: float = 1.0
	if p_host.is_standby:
		badge_id = Icons.IconId.BADGE_STANDBY
	elif p_host._badge_alpha > 0.0:
		badge_id = Icons.IconId.BADGE_STANDBY  # 淡出中的沙漏（语义已就绪）
		alpha = p_host._badge_alpha
	else:
		badge_id = Icons.IconId.BADGE_ACTED
	var region: Rect2 = Icons.get_region(badge_id)
	p_host.draw_texture_rect_region(Icons.get_atlas(),
			Rect2(Style.SIDE_BAR_WIDTH + Style.BADGE_INSET, Style.ICON_ORIGIN,
				Style.BADGE_SIZE, Style.BADGE_SIZE),
			region, Color(1.0, 1.0, 1.0, alpha))


## 前后排边框（story AC-4：前排金色实线 / 后排蓝色虚线）。
static func draw_border(p_host: Control) -> void:
	var border_rect: Rect2 = Rect2(Vector2.ZERO, p_host.size)
	if p_host.is_front_row:
		p_host.draw_rect(border_rect, Style.FRONT_BORDER_COLOR, false,
				Style.BORDER_WIDTH)
		return
	# 虚线边框：四边分段 draw_dashed_line（同色 4 次绘制——直线合批友好）
	var w: float = p_host.size.x
	var h: float = p_host.size.y
	for segment: Array in [[Vector2(0, 0), Vector2(w, 0)],
			[Vector2(w, 0), Vector2(w, h)], [Vector2(w, h), Vector2(0, h)],
			[Vector2(0, h), Vector2(0, 0)]]:
		p_host.draw_dashed_line(segment[0], segment[1], Style.BACK_BORDER_COLOR,
				Style.BORDER_WIDTH, Style.DASH_LENGTH, true)


## L2 侧栏图标绘制（同图集合批——左功法/右法宝竖排）。[br]
## [br][b]背板整栏一条[/b]：半透明底衬按当前图标数定高——空侧栏不画底衬。
static func draw_side_icons(p_host: Control, left_side: bool) -> void:
	var count: int = p_host.gongfa_count if left_side else p_host.fabao_count
	var icon_id: int = Icons.IconId.GONGFA if left_side else Icons.IconId.FABAO
	var atlas: Texture2D = Icons.get_atlas()
	var backing_region: Rect2 = Icons.get_region(Icons.IconId.BACKING)
	var icon_region: Rect2 = Icons.get_region(icon_id)
	var x: float = Style.ICON_ORIGIN if left_side \
			else p_host.size.x - Style.SIDE_BAR_WIDTH + Style.ICON_ORIGIN
	var backing: Rect2 = Rect2(x - Style.ICON_BACKING_INSET, Style.ICON_ORIGIN,
			Style.SIDE_BAR_WIDTH,
			float(count) * (Style.ICON_SIZE + Style.ICON_GAP)
			+ Style.ICON_BACKING_INSET)
	p_host.draw_texture_rect_region(atlas, backing, backing_region)
	for i: int in count:
		var y: float = Style.ICON_SLOT_TOP \
				+ float(i) * (Style.ICON_SIZE + Style.ICON_GAP)
		p_host.draw_texture_rect_region(atlas,
				Rect2(x, y, Style.ICON_SIZE, Style.ICON_SIZE), icon_region)
