class_name CharacterStatusCard
extends Control
## CharacterStatusCard —— 角色状态卡组件 L0-L5 分层（combat-ui-layout Story 002）。
##
## [b]职责[/b]：单 Control 自绘角色卡——六层从底到顶：[br]
##   L0 头像全幅背景 → L1 底部渐变遮罩（对比度保障）→ L2 左右 28px
##   功法/法宝竖排栏（各最多 3）→ L3 底部 40px HP 条+ATK → L4 buff 左下
##   （最多 5）+境界右下 → L5 待命/已行动左上。[br]
## [br][b]合批[/b]（R-02 §3 分组方案）：图标全部走 [code]CombatIconAtlas[/code]
## 单图集（[code]draw_texture_rect_region[/code] 同纹理合批）；HP 条
## [code]draw_rect[/code] 纯色绘制（非纹理 ProgressBar——R-02 §2）；文字单
## Label（名+数值合并）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：角色数据（HP/buff/绑定）所有权在
## 战斗/绑定系统——本组件只持渲染快照，[method apply_hp] 等由系统信号驱动。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]——HP 过渡 0.3s 一次性 Tween
## （§2.1 豁免），数字 ≤100ms 终值直显（GDD 批量伤害免抖条款）。[br]
## [br][b]前排/后排[/b]：缩放经 [code]Rules.formation_row_scale()[/code]；
## 边框实线金/虚线蓝为独立属性（story AC-4——不内联进纯函数）。
##
## @experimental
## 来源: ADR-0031、design/ux/combat-ui.md §角色状态卡、
## production/qa/evidence/r02-batching-spec.md、combat-ui-layout Story 002。

## 共享纯函数/图集模块（story 001/002 唯一落地处——禁止内联）。
const Rules := preload("res://src/ui/combat/shared/combat_ui_rules.gd")
const Icons := preload("res://src/ui/combat/shared/combat_icon_atlas.gd")
const UiFont := preload("res://src/ui/combat/shared/combat_ui_font.gd")

## === 卡牌尺寸常量（UX Layout Zones：120×168 前排基准）=======================

const CARD_WIDTH: float = 120.0
const CARD_HEIGHT: float = 168.0
## L2 侧栏宽（px）。
const SIDE_BAR_WIDTH: float = 28.0
## L2 图标尺寸（20×20px，间距 4px——UX 规格表）。
const ICON_SIZE: float = 20.0
const ICON_GAP: float = 4.0
## L2 图标每侧上限（UX：功法/法宝各最多 3）。
const SIDE_ICON_LIMIT: int = 3
## L3 底部条高（px）。
const BOTTOM_BAR_HEIGHT: float = 40.0
## L4 buff 图标上限（UX：最多 3-5——取 5 上限）。
const BUFF_LIMIT: int = 5
## L4/L5 角标尺寸（R-02 corner_badge 20×20）。
const BADGE_SIZE: float = 20.0

## === HP 过渡常量（GDD 公式 3 调优旋钮）=======================================

## HP 条平滑过渡时长（0.3s 线性——GDD 调优表 0.2~0.5 默认 0.3）。
const HP_TWEEN_SEC: float = 0.3

## 沙漏标记淡出时长（GDD 动画表 L611 前半句——待命→已就绪 0.3s；
## 文字通道推迟见 DEBT-CUI-003，角标部分归本 story）。
const BADGE_FADE_SEC: float = 0.3

## === 视觉常量（集中定义——R-02 数据驱动条款）=================================

## 前排边框色（金色实线）。
const FRONT_BORDER_COLOR: Color = Color(0.91, 0.76, 0.35)
## 后排边框色（蓝色虚线）。
const BACK_BORDER_COLOR: Color = Color(0.45, 0.62, 0.85)
## 边框线宽。
const BORDER_WIDTH: float = 2.0
## 虚线段长/间隔（后排虚线边框）。
const DASH_LENGTH: float = 6.0
## L3 底部条不透明背板色。
const BOTTOM_BAR_BG: Color = Color(0.06, 0.06, 0.09, 0.92)
## HP 条底槽色。
const HP_TRACK_COLOR: Color = Color(0.16, 0.16, 0.20, 0.9)
## ATK 数字色（暖白——对比度 ≥4.5:1 on 遮罩）。
const ATK_COLOR: Color = Color(0.96, 0.94, 0.88)

## === 渲染快照（零状态所有权——系统信号驱动写入）==============================

## 当前/最大 HP（渲染快照——所有权在战斗系统）。
var current_hp: int = 0
var max_hp: int = 0
## ATK 数值快照。
var atk_value: int = 0
## 功法/法宝图标显示数（L2——绑定数据经 [method set_bindings] 从
## BindingManager 零分配查询结果写入）。
var gongfa_count: int = 0
var fabao_count: int = 0
## buff/debuff 计数快照（L4——各占位图标，实际图标集归 interaction/美术）。
var buff_count: int = 0
var debuff_count: int = 0
## 角色境界（L4 境界角标仅当 realm > player_realm 时显示——story AC-6）。
var realm: int = 0
## 玩家境界（比较基准——由场景层注入）。
var player_realm: int = 0
## 待命/已行动标记（L5 渲染归本 story；切换信号逻辑归 story 003）。
var is_standby: bool = false
## 已行动遮罩标志（story 003 AC-2——true 时全卡幅半透明灰色遮罩）。
## [br][b]语义澄清[/b]（story 002 遗留）：[member is_standby]=false 本渲染
## 「已行动对勾」，但未覆盖 GDD「灰色遮罩」完整语义——本属性补齐：
## is_acted=true 同时驱动遮罩+对勾（[method set_acted_state]），默认 false
## 使 is_standby=false 的旧语义（仅对勾）不自动出现遮罩。
var is_acted: bool = false
## 前后排定位（true 前排——边框样式+缩放决策）。
var is_front_row: bool = true
## 减少动态（进场时从设置读取——进场后静态，零轮询）。
var reduce_motion: bool = false

## HP 条显示宽度（Tween 插值目标——0..1 比例）。
var _hp_display_ratio: float = 1.0
## HP 过渡 Tween 句柄（重入 kill 重建——批量伤害直算终值条款）。
var _hp_tween: Tween = null
## 沙漏淡出透明度（>0 时 L5 继续绘制沙漏——待命→已就绪 0.3s 淡出通道；
## 瞬态视觉状态 §2.1 豁免）。
var _badge_alpha: float = 0.0
## 沙漏淡出 Tween 句柄（重入 kill）。
var _badge_tween: Tween = null
## 名+数值合并 Label（R-02 §3 文字合并——单 Label 不拆多）。
var _stat_label: Label = null
## 头像纹理（每角色唯一独立纹理——R-02 §3 头像分组；null 时色块占位）。
var portrait: Texture2D = null


## _init 构建文字子节点（不依赖场景树时序）。
func _init() -> void:
	custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	_stat_label = Label.new()
	_stat_label.name = "StatLabel"
	add_child(_stat_label)


func _draw() -> void:
	var card_size: Vector2 = size
	if card_size.x <= 0.0 or card_size.y <= 0.0:
		return
	# L0 头像全幅背景（null → 深色占位块——stub 阶段头像未入库）
	if portrait != null:
		draw_texture_rect(portrait, Rect2(Vector2.ZERO, card_size), true)
	else:
		draw_rect(Rect2(Vector2.ZERO, card_size), Color(0.18, 0.20, 0.24))
	# L1 底部渐变遮罩（透明 → 黑 60%——L3 文字可读性）
	draw_texture_rect(Icons.get_mask(), Rect2(Vector2.ZERO, card_size), true)
	# L2 左右功法/法宝竖排（同一图集批次）
	_draw_side_icons(true)
	_draw_side_icons(false)
	# L3 底部条：不透明背板 + HP 条（draw_rect 纯色）+ ATK
	var bar_rect: Rect2 = Rect2(0.0, card_size.y - BOTTOM_BAR_HEIGHT,
		card_size.x, BOTTOM_BAR_HEIGHT)
	draw_rect(bar_rect, BOTTOM_BAR_BG)
	_draw_hp_bar(bar_rect)
	# L4 左下 buff/debuff 角标 + 右下境界角标（仅高于玩家境界）
	_draw_badges()
	# L5 左上待命/已行动标记
	_draw_standby_badge()
	# 已行动灰色遮罩（story 003 AC-2——顶层覆盖，L5 标记之上边框之下）
	if is_acted:
		draw_rect(Rect2(Vector2.ZERO, size), ACTED_OVERLAY_COLOR)
	# 前后排边框（最后绘——顶层描边）
	_draw_border()


## === 信号驱动更新入口（战斗系统信号 → 渲染快照）==============================

## 应用 HP 变更（战斗系统 HP 变更信号驱动）。[br]
## [br][b]批量伤害免抖[/b]（GDD 公式 3）：同帧多次调用直算终值——Tween 重入
## kill 重建，从当前显示比例向终值单次 0.3s 过渡；数字 ≤100ms 终值直显
## （Label 直接更新——无数字 Tween）。[br]
## [param p_current]: 新当前 HP。[param p_max]: 最大 HP（守卫 0 → 比例 1.0，
## 防除零——QA 规格 AC-1 edge）。
func apply_hp(p_current: int, p_max: int) -> void:
	current_hp = maxi(p_current, 0)
	max_hp = maxi(p_max, 0)
	var target_ratio: float = 1.0 if max_hp == 0 \
			else clampf(float(current_hp) / float(max_hp), 0.0, 1.0)
	if reduce_motion:
		_hp_display_ratio = target_ratio
		_kill_hp_tween()
	else:
		_kill_hp_tween()
		_hp_tween = create_tween()
		_hp_tween.tween_method(_set_hp_display_ratio,
			_hp_display_ratio, target_ratio, HP_TWEEN_SEC)
	_refresh()


## 应用 ATK 变更。
func apply_atk(p_atk: int) -> void:
	atk_value = p_atk
	_refresh()


## 设置绑定图标数（L2——[code]BindingManager.get_binding_ids_by_character()[/code]
## 查询结果经 slot_type 分组计数后写入；本组件不直接访问系统——零状态所有权）。
func set_bindings(p_gongfa: int, p_fabao: int) -> void:
	gongfa_count = clampi(p_gongfa, 0, SIDE_ICON_LIMIT)
	fabao_count = clampi(p_fabao, 0, SIDE_ICON_LIMIT)
	_refresh()


## 设置 buff/debuff 计数（L4——状态系统信号驱动；实际图标集归美术管线）。
func set_status_effects(p_buff: int, p_debuff: int) -> void:
	buff_count = clampi(p_buff, 0, BUFF_LIMIT)
	debuff_count = clampi(p_debuff, 0, BUFF_LIMIT)
	_refresh()


## 设置境界数据（L4——境界角标仅 realm > player_realm 时显示）。
func set_realm(p_realm: int, p_player_realm: int) -> void:
	realm = p_realm
	player_realm = p_player_realm
	_refresh()


## 设置前后排（缩放 + 边框样式决策——story AC-4）。
func set_front_row(p_front: bool) -> void:
	is_front_row = p_front
	var scale_factor: float = Rules.formation_row_scale(p_front)
	scale = Vector2(scale_factor, scale_factor)
	_refresh()


## === 已行动遮罩常量（story 003 AC-2——数值数据驱动）==========================

## 已行动遮罩色（GDD §角色状态标记——「已行动角色：灰色遮罩」）。
const ACTED_OVERLAY_COLOR: Color = Color(0.5, 0.5, 0.52, 0.5)

## 设置待命标记（L5 渲染归本 story——切换信号逻辑归 story 003）。[br]
## 待命→已就绪：沙漏标记 0.3s 淡出（GDD 动画表 L611——语义位立即翻转，
## 视觉通道经 [member _badge_alpha] 渐隐；reduce_motion 瞬时清除）。
func set_standby(p_standby: bool) -> void:
	if p_standby:
		is_standby = true
		_kill_badge_tween()
		_badge_alpha = 0.0
	elif is_standby:
		is_standby = false
		if reduce_motion:
			_badge_alpha = 0.0
		else:
			_badge_alpha = 1.0
			_kill_badge_tween()
			_badge_tween = create_tween()
			_badge_tween.tween_method(_set_badge_alpha, 1.0, 0.0, BADGE_FADE_SEC)
	_refresh()


## 设置已行动状态（story 003 AC-2——灰色遮罩 + 已行动对勾）。[br]
## true = 遮罩+对勾（遮罩由 [member is_acted] 驱动，对勾由
## [member is_standby]=false 驱动——两属性合一入口）；false = 清除遮罩。
func set_acted_state(p_acted: bool) -> void:
	is_acted = p_acted
	if p_acted:
		is_standby = false  # 已行动与待命互斥（FieldState 状态机语义）
		_kill_badge_tween()  # 互斥路径直接终结沙漏淡出（对勾+遮罩接替）
		_badge_alpha = 0.0
	_refresh()


## 应用减少动态（进场时读取设置——进场后静态）。
func set_reduce_motion(p_reduce: bool) -> void:
	reduce_motion = p_reduce


## === 内部 ====================================================================

## HP 显示比例 Tween 插值回调。
func _set_hp_display_ratio(value: float) -> void:
	_hp_display_ratio = value
	_refresh()


## 标记重绘 + 同步合并 Label（文字合批——R-02 §3 单 Label 条款）。
func _refresh() -> void:
	_stat_label.text = "HP %d/%d  ATK %d" % [current_hp, max_hp, atk_value]
	var font_size: int = UiFont.font_size_responsive(14,
		int(get_viewport_rect().size.y) if get_viewport() != null else 1080)
	_stat_label.add_theme_font_size_override("font_size", font_size)
	_stat_label.add_theme_color_override("font_color", ATK_COLOR)
	_stat_label.position = Vector2(SIDE_BAR_WIDTH,
		size.y - BOTTOM_BAR_HEIGHT + 22.0)
	_stat_label.size = Vector2(size.x - SIDE_BAR_WIDTH * 2.0, 18.0)
	queue_redraw()


## HP 条绘制（R-02 §2——draw_rect 纯色三段：底槽/前景/边框省略——§5 实测
## 边框 outline 可裁剪省 1 DC，本实现裁剪）。
func _draw_hp_bar(bar_rect: Rect2) -> void:
	var track: Rect2 = Rect2(
		bar_rect.position.x + SIDE_BAR_WIDTH,
		bar_rect.position.y + 6.0,
		bar_rect.size.x - SIDE_BAR_WIDTH * 2.0, 8.0)
	draw_rect(track, HP_TRACK_COLOR)
	var fill_width: float = track.size.x * _hp_display_ratio
	if fill_width > 0.0:
		var fill: Rect2 = Rect2(track.position.x, track.position.y,
			fill_width, track.size.y)
		var ratio: float = 1.0 if max_hp == 0 \
				else clampf(float(current_hp) / float(max_hp), 0.0, 1.0)
		draw_rect(fill, Rules.hp_bar_color(ratio))


## L2 侧栏图标绘制（同图集合批——左功法/右法宝竖排）。
func _draw_side_icons(left_side: bool) -> void:
	var count: int = gongfa_count if left_side else fabao_count
	var icon_id: int = Icons.IconId.GONGFA if left_side \
			else Icons.IconId.FABAO
	var backing_region: Rect2 = Icons.get_region(
		Icons.IconId.BACKING)
	var icon_region: Rect2 = Icons.get_region(icon_id)
	var atlas: Texture2D = Icons.get_atlas()
	var x: float = 4.0 if left_side else size.x - SIDE_BAR_WIDTH + 4.0
	# 侧栏半透明背板（整栏一条）
	var backing: Rect2 = Rect2(x - 4.0, 4.0, SIDE_BAR_WIDTH,
		float(count) * (ICON_SIZE + ICON_GAP) + 4.0)
	draw_texture_rect_region(atlas, backing, backing_region)
	for i: int in count:
		var y: float = 8.0 + float(i) * (ICON_SIZE + ICON_GAP)
		draw_texture_rect_region(atlas,
			Rect2(x, y, ICON_SIZE, ICON_SIZE), icon_region)


## L4 角标绘制：左下 buff/debuff + 右下境界（仅高于玩家境界）。
func _draw_badges() -> void:
	var atlas: Texture2D = Icons.get_atlas()
	var buff_region: Rect2 = Icons.get_region(Icons.IconId.BUFF)
	var debuff_region: Rect2 = Icons.get_region(Icons.IconId.DEBUFF)
	# 左下：buff 在上 debuff 在下（合计 ≤5——上限钳制在 set_status_effects）
	var y_base: float = size.y - BOTTOM_BAR_HEIGHT - BADGE_SIZE - 4.0
	var x: float = SIDE_BAR_WIDTH + 2.0
	var slot: int = 0
	for i: int in buff_count:
		draw_texture_rect_region(atlas,
			Rect2(x, y_base - float(slot) * (BADGE_SIZE + 2.0),
				BADGE_SIZE, BADGE_SIZE), buff_region)
		slot += 1
	for i: int in debuff_count:
		draw_texture_rect_region(atlas,
			Rect2(x, y_base - float(slot) * (BADGE_SIZE + 2.0),
				BADGE_SIZE, BADGE_SIZE), debuff_region)
		slot += 1
	# 右下：境界角标（story AC-6——仅高于玩家境界时显示）
	if realm > player_realm and realm > 0:
		var realm_region: Rect2 = Icons.get_region(
			Icons.IconId.BADGE_REALM)
		draw_texture_rect_region(atlas,
			Rect2(size.x - SIDE_BAR_WIDTH - BADGE_SIZE - 2.0,
				size.y - BOTTOM_BAR_HEIGHT - BADGE_SIZE - 4.0,
				BADGE_SIZE, BADGE_SIZE), realm_region)


## L5 待命/已行动标记（左上——is_standby=true 待命沙漏 / false 已行动对勾；
## 渲染归本 story，切换逻辑归 story 003）。
func _draw_standby_badge() -> void:
	var badge_id: int
	var alpha: float = 1.0
	if is_standby:
		badge_id = Icons.IconId.BADGE_STANDBY
	elif _badge_alpha > 0.0:
		badge_id = Icons.IconId.BADGE_STANDBY  # 淡出中的沙漏（语义已就绪）
		alpha = _badge_alpha
	else:
		badge_id = Icons.IconId.BADGE_ACTED
	var region: Rect2 = Icons.get_region(badge_id)
	draw_texture_rect_region(Icons.get_atlas(),
		Rect2(SIDE_BAR_WIDTH + 2.0, 4.0, BADGE_SIZE, BADGE_SIZE),
		region, Color(1.0, 1.0, 1.0, alpha))


## 前后排边框（story AC-4：前排金色实线 / 后排蓝色虚线）。
func _draw_border() -> void:
	var border_rect: Rect2 = Rect2(Vector2.ZERO, size)
	if is_front_row:
		draw_rect(border_rect, FRONT_BORDER_COLOR, false, BORDER_WIDTH)
	else:
		# 虚线边框：四边分段 draw_dashed_line（同色 4 次绘制——直线合批友好）
		var w: float = size.x
		var h: float = size.y
		draw_dashed_line(Vector2(0, 0), Vector2(w, 0), BACK_BORDER_COLOR,
			BORDER_WIDTH, DASH_LENGTH, true)
		draw_dashed_line(Vector2(w, 0), Vector2(w, h), BACK_BORDER_COLOR,
			BORDER_WIDTH, DASH_LENGTH, true)
		draw_dashed_line(Vector2(w, h), Vector2(0, h), BACK_BORDER_COLOR,
			BORDER_WIDTH, DASH_LENGTH, true)
		draw_dashed_line(Vector2(0, h), Vector2(0, 0), BACK_BORDER_COLOR,
			BORDER_WIDTH, DASH_LENGTH, true)


## 沙漏淡出 Tween 插值回调。
func _set_badge_alpha(value: float) -> void:
	_badge_alpha = value
	queue_redraw()

## 沙漏淡出 Tween 重入清理。
func _kill_badge_tween() -> void:
	if _badge_tween != null and _badge_tween.is_valid():
		_badge_tween.kill()
	_badge_tween = null

## HP Tween 重入清理（批量伤害终值条款——kill 重建单次过渡）。
func _kill_hp_tween() -> void:
	if _hp_tween != null and _hp_tween.is_valid():
		_hp_tween.kill()
	_hp_tween = null
