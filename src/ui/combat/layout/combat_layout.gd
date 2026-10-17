class_name CombatLayout
extends Control
## CombatLayout —— 战场四区域布局骨架（combat-ui-layout Story 001）。
##
## [b]职责[/b]：战斗 UI 场景根——五区域容器（顶部条 / 敌方区 / 中线 /
## 己方区 / 底部条）按 UX Layout Zones 表以 **anchor 百分比** 搭建，
## 外加右上角撤退按钮位 + 暂停按钮位预留 + 进场过渡编排。
## 区域内容（角色卡/手牌/阶段指示器）由 002-006 story 填充。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本类不持有游戏状态——
## 布局常量为渲染参数；进场过渡的进度是瞬态视觉状态（§2.1 豁免）。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]——进场过渡用一次性
## Tween（完成即停），HUD 隐藏由 [signal post_transition] 驱动。[br]
## [br][b]anchor 百分比响应式[/b]（story 禁止像素硬编码布局）：
## 区域位置尺寸按 1920×1080 基准的百分比 anchor 设定，任意 16:9 分辨率
## 等比缩放（control-manifest「分辨率基准 1920×1080」）。
##
## @experimental
## 来源: ADR-0031、design/ux/combat-ui.md §Layout Zones/§Transitions、
## combat-ui-layout Story 001。

## === 区域常量（1920×1080 基准 → anchor 百分比）=============================

## 顶部条高度（px）→ anchor 百分比（60/1080）。
const TOPBAR_HEIGHT_RATIO: float = 60.0 / 1080.0
## 敌方区高度（~340px → 340/1080）。
const ENEMY_AREA_HEIGHT_RATIO: float = 340.0 / 1080.0
## 己方区高度（~340px → 340/1080）。
const ALLY_AREA_HEIGHT_RATIO: float = 340.0 / 1080.0
## 底部条高度（~180px → 180/1080）。
const BOTTOMBAR_HEIGHT_RATIO: float = 180.0 / 1080.0

## === 过渡常量（UX Transitions & Animations）=================================

## 顶部条滑入时长（秒，ease-out）。
const T_TOPBAR_SEC: float = 0.3
## 敌方区淡入时长（延迟 0.1s）。
const T_ENEMY_SEC: float = 0.4
const T_ENEMY_DELAY_SEC: float = 0.1
## 己方区淡入时长（延迟 0.2s）。
const T_ALLY_SEC: float = 0.4
const T_ALLY_DELAY_SEC: float = 0.2
## 底部条滑入时长（延迟 0.3s）。
const T_BOTTOMBAR_SEC: float = 0.3
const T_BOTTOMBAR_DELAY_SEC: float = 0.3
## 滑入位移距离（px——从区域外滑入的偏移量，瞬态视觉参数非布局值）。
const SLIDE_OFFSET_PX: float = 60.0

## === 中线颜色（UX「全宽 1px 淡墨」）=========================================

const MIDLINE_COLOR: Color = Color(0.30, 0.30, 0.32, 0.6)

## === 瞬态视觉状态（§2.1 豁免——过渡一次性）==================================

## 进场过渡 Tween 句柄（重入 kill 重建）。
var _entrance_tween: Tween = null
## 减少动态标志（进场时从设置读取——进场后静态，零轮询）。
var reduce_motion: bool = false

## === 子节点引用（_build_layout 创建）=========================================

var topbar: Control = null
var enemy_area: Control = null
var midline: Control = null
var ally_area: Control = null
var bottombar: Control = null
## 右上角撤退按钮位（内容/点击行为归 008/interaction）。
var retreat_button_slot: Control = null
## 暂停按钮位（顶部条内——点击/ESC 转发 hud 暂停菜单，菜单本体归 hud 005）。
var pause_button_slot: Control = null

## 音频管理器引用（进入战斗触发 set_state(IN_COMBAT)——依赖注入，
## 未注入时静默跳过：story AC-7 消费 audio-manager API， AudioManager 由
## SceneManager 持有（ADR-0031 §1.2 零新增 Autoload））。
var _audio_manager: AudioManager = null


## 注入音频管理器（战斗场景挂载时由 SceneManager.get_audio_manager() 传入）。
func set_audio_manager(p_audio_manager: AudioManager) -> void:
	_audio_manager = p_audio_manager


## 请求进入战斗音频状态（AC-7——仅触发 set_state(IN_COMBAT) 请求，
## 过渡矩阵实现归 audio-manager story 004）。未注入时无操作（布局骨架
## 独立于音频系统可测试）。
func request_in_combat_audio() -> void:
	if _audio_manager != null:
		_audio_manager.set_state(AudioEnums.AudioState.IN_COMBAT)


## 构建五区域容器 + 按钮位（_init 构建——不依赖场景树时序）。
func _init() -> void:
	_build_layout()


## 进场过渡编排（UX Transitions：滑入/淡入序列 + ≤2s 全可见）。[br]
## [param p_reduce_motion]: true 直接就位无动画（UX 减少动态替代）。[br]
## [b]编排[/b]：顶部条上方滑入 0.3s → 敌方区淡入 0.4s（延迟 0.1s）→
## 己方区淡入 0.4s（延迟 0.2s）→ 底部条下方滑入 0.3s（延迟 0.3s）。
## 串行总时长 0.3+0.1+0.4+0.2+0.4+0.3+0.3 = 2.0s 上限内（UX AC）。
func play_entrance(p_reduce_motion: bool = false) -> void:
	reduce_motion = p_reduce_motion
	if p_reduce_motion:
		_kill_entrance_tween()
		_reset_zone_transforms()
		return
	_kill_entrance_tween()
	# 起始态：滑入类区域移出 + 淡入类区域透明
	topbar.position.y -= SLIDE_OFFSET_PX
	topbar.modulate.a = 0.0
	enemy_area.modulate.a = 0.0
	ally_area.modulate.a = 0.0
	bottombar.position.y += SLIDE_OFFSET_PX
	bottombar.modulate.a = 0.0
	_entrance_tween = create_tween()
	_entrance_tween.set_parallel(true)
	# 顶部条：上方滑入 0.3s（ease-out）
	_entrance_tween.tween_property(topbar, "position:y",
			topbar.position.y + SLIDE_OFFSET_PX, T_TOPBAR_SEC) \
			.from(topbar.position.y - SLIDE_OFFSET_PX * 2.0) \
			.set_ease(Tween.EASE_OUT)
	_entrance_tween.tween_property(topbar, "modulate:a", 1.0, T_TOPBAR_SEC)
	# 敌方区：淡入 0.4s 延迟 0.1s
	_entrance_tween.tween_property(enemy_area, "modulate:a", 1.0, T_ENEMY_SEC) \
			.set_delay(T_ENEMY_DELAY_SEC)
	# 己方区：淡入 0.4s 延迟 0.2s
	_entrance_tween.tween_property(ally_area, "modulate:a", 1.0, T_ALLY_SEC) \
			.set_delay(T_ALLY_DELAY_SEC)
	# 底部条：下方滑入 0.3s 延迟 0.3s（ease-out）
	_entrance_tween.tween_property(bottombar, "position:y",
			bottombar.position.y - SLIDE_OFFSET_PX, T_BOTTOMBAR_SEC) \
			.set_delay(T_BOTTOMBAR_DELAY_SEC) \
			.set_ease(Tween.EASE_OUT)
	_entrance_tween.tween_property(bottombar, "modulate:a", 1.0,
			T_BOTTOMBAR_SEC).set_delay(T_BOTTOMBAR_DELAY_SEC)


## 布局就位（无过渡终态——reduce_motion 路径 + 测试断言基准）。
func _reset_zone_transforms() -> void:
	for zone: Control in [topbar, enemy_area, ally_area, bottombar]:
		if zone != null:
			zone.modulate.a = 1.0
	# anchor 布局下 position 由容器排布——滑入偏移在 reduce_motion 路径不应用
	# （play_entrance 的位移只作为过渡起始态，reset 恢复 modulate 即可）


## === 内部 ====================================================================

## 构建五区域 + 按钮位（anchor 百分比——1920×1080 基准换算）。
func _build_layout() -> void:
	# 顶部条：顶部全宽 60px
	topbar = _make_zone("TopBar")
	_anchor_ratio(topbar, 0.0, 0.0, 1.0, TOPBAR_HEIGHT_RATIO)
	add_child(topbar)
	# 敌方区：上半场中央 ~340px（顶部条下方）
	enemy_area = _make_zone("EnemyArea")
	_anchor_ratio(enemy_area, 0.0, TOPBAR_HEIGHT_RATIO, 1.0,
			TOPBAR_HEIGHT_RATIO + ENEMY_AREA_HEIGHT_RATIO)
	add_child(enemy_area)
	# 中线分隔：水平中分线全宽（自绘 1px 淡墨线）
	midline = _make_zone("Midline")
	_anchor_ratio(midline, 0.0, 0.5, 1.0, 0.5)
	add_child(midline)
	midline.custom_minimum_size.y = 1.0
	midline.draw.connect(_draw_midline.bind(midline))
	# 己方区：下半场中央 ~340px
	ally_area = _make_zone("AllyArea")
	_anchor_ratio(ally_area, 0.0, 0.5, 1.0, 0.5 + ALLY_AREA_HEIGHT_RATIO)
	add_child(ally_area)
	# 底部条：底部全宽 ~180px
	bottombar = _make_zone("BottomBar")
	_anchor_ratio(bottombar, 0.0, 1.0 - BOTTOMBAR_HEIGHT_RATIO, 1.0, 1.0)
	add_child(bottombar)
	# 暂停按钮位（顶部条右端——内容归 004，转发归 hud 005）
	pause_button_slot = _make_zone("PauseButtonSlot")
	pause_button_slot.custom_minimum_size = Vector2(48, 48)
	_anchor_ratio(pause_button_slot, 1.0 - 48.0 / 1920.0, 6.0 / 1080.0,
			1.0 - 6.0 / 1920.0, 6.0 / 1080.0 + 48.0 / 1080.0)
	topbar.add_child(pause_button_slot)
	# 撤退按钮位（右上角常驻——独立于顶部条，内容/行为归 008/interaction）
	retreat_button_slot = _make_zone("RetreatButtonSlot")
	retreat_button_slot.custom_minimum_size = Vector2(48, 48)
	add_child(retreat_button_slot)
	retreat_button_slot.anchor_left = 1.0 - 60.0 / 1920.0
	retreat_button_slot.anchor_right = 1.0 - 12.0 / 1920.0
	retreat_button_slot.anchor_top = 60.0 / 1080.0 + 8.0 / 1080.0
	retreat_button_slot.anchor_bottom = 60.0 / 1080.0 + 8.0 / 1080.0 + 48.0 / 1080.0


## 区域容器工厂（Control——内容后续 story 填充）。
func _make_zone(zone_name: String) -> Control:
	var zone := Control.new()
	zone.name = zone_name
	return zone


## anchor 百分比设置（统一入口——story 禁止像素绝对定位）。
func _anchor_ratio(zone: Control, left: float, top: float, right: float, bottom: float) -> void:
	zone.anchor_left = left
	zone.anchor_top = top
	zone.anchor_right = right
	zone.anchor_bottom = bottom
	zone.offset_left = 0
	zone.offset_top = 0
	zone.offset_right = 0
	zone.offset_bottom = 0


## 中线绘制（1px 淡墨——draw 信号接自绘 zone）。
func _draw_midline(zone: Control) -> void:
	if zone.size.y <= 0.0:
		return
	zone.draw_line(Vector2(0, zone.size.y * 0.5),
			Vector2(zone.size.x, zone.size.y * 0.5), MIDLINE_COLOR, 1.0)


func _kill_entrance_tween() -> void:
	if _entrance_tween != null and _entrance_tween.is_valid():
		_entrance_tween.kill()
	_entrance_tween = null
