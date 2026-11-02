class_name HandCard
extends Control
## HandCard —— 手牌缩略卡渲染（combat-ui-layout Story 006）。
##
## [b]职责[/b]：手牌区单张缩略卡的静态渲染——卡名（顶部）、费用（左上角）、
## 类型标签（右下角）、稀有度色边框（描边）。三态视觉（GDD §2 手牌区状态表）：[br]
##   - [b]默认[/b]（阶段 2 内 + 费用充足）→ 彩色，费用正常色[br]
##   - [b]灰显[/b]（阶段 2 内 + 费用不足）→ 整体降饱和（modulate）+ 费用数字红[br]
##   - [b]灵能预览[/b]（阶段 2 外）→ 60% 饱和度近似（modulate）+ 🔒 角标[br]
## [br][b]R-02 §3 合批[/b]：全部文字经 [code]draw_string[/code] 在单一
## [code]_draw()[/code] 内绘制（零独立 Label 子节点——单 CanvasItem 合批，
## 避免 10 张手牌 × 4 Label 的 DC 膨胀）；颜色/尺寸常量集中定义。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：卡牌数据（名称/费用/稀有度/类型）为
## 渲染快照，经 [method set_card_data] 由 [HandArea] 信号驱动写入；本组件不
## 访问卡牌系统。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]。[br]
## [br][b]范围划分[/b]：卡面美术本体归资产管线（story Out of Scope——
## 缩略卡渲染 stub）；悬停放大 1.2×/拖拽归 interaction epic。
##
## @experimental
## 来源: ADR-0031、design/gdd/combat-ui-system.md §2 手牌区/§手牌区状态、
## design/ux/hud.md §手牌区、production/qa/evidence/r02-batching-spec.md §3、
## combat-ui-layout Story 006（AC-4）。

## 共享字号纯函数（story 001 唯一落地处——禁止内联）。
const UiFont := preload("res://src/ui/combat/shared/combat_ui_font.gd")

## === 尺寸常量（UX hud.md「手牌中宽度 100px → 高度 140px，宽高比 5:7」）=======

const CARD_WIDTH: float = 100.0
const CARD_HEIGHT: float = 140.0

## === 视觉常量（集中定义——数据驱动条款）=======================================

## 卡面底色（深色——stub 阶段无插画）。
const CARD_BG: Color = Color(0.16, 0.17, 0.21)
## 卡面顶部（近似插画位置——浅色头，stub 占位）。
const CARD_HEAD: Color = Color(0.22, 0.24, 0.30)
## 卡名字色。
const NAME_COLOR: Color = Color(0.92, 0.92, 0.88)
## 费用数字色（正常态）。
const COST_COLOR: Color = Color(0.95, 0.90, 0.55)
## 费用数字色（费用不足态——GDD「费用数字红色」）。
const COST_UNAFFORDABLE_COLOR: Color = Color(0.85, 0.25, 0.22)
## 锁标记色（灵能预览）。
const LOCK_COLOR: Color = Color(0.95, 0.85, 0.40)
## 灰显 modulate（费用不足——整体降饱和）。
const GRAYED_MODULATE: Color = Color(0.55, 0.55, 0.55)
## 灵能预览 modulate（60% 饱和度近似——偏灰仍保留色相）。
const PSYCHIC_MODULATE: Color = Color(0.80, 0.78, 0.74)

## 稀有度边框色（CardTemplate.Rarity 1=白 2=蓝 3=紫 4=金 5=暗金——集中定义）。
const RARITY_BORDER_COLORS: Array[Color] = [
	Color(0.72, 0.72, 0.72),  # 白
	Color(0.35, 0.55, 0.95),  # 蓝
	Color(0.70, 0.42, 0.95),  # 紫
	Color(0.95, 0.78, 0.28),  # 金
	Color(0.90, 0.42, 0.20),  # 暗金
]

## 类型标签文本（CardTemplate.CardType 0-5）。
const TYPE_LABELS: Array[String] = ["角色", "功法", "法宝", "阵法", "丹药", "符箓"]

## 字号基准（pt——经 font_size_responsive 响应式缩放，1280×720 下 ≥12pt）。
const NAME_FONT_SIZE: int = 12
const COST_FONT_SIZE: int = 16
const TYPE_FONT_SIZE: int = 12
const LOCK_FONT_SIZE: int = 14

## 边框线宽。
const BORDER_WIDTH: float = 2.0

## === 渲染快照（零状态所有权——HandArea 写入）==================================

## 卡名。
var card_name: String = ""
## 灵力消耗。
var cost: int = 0
## 稀有度（1-5）。
var rarity: int = 1
## 卡牌类型（0-5）。
var card_type: int = 0
## 费用是否充足（false → 灰显 + 费用红）。
var is_affordable: bool = true
## 是否灵能预览（阶段 2 外——true 时 60% 饱和 + 🔒）。
var is_psychic: bool = false


func _init() -> void:
	custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 设置卡牌数据（渲染快照——HandArea 信号驱动写入）。[br]
## [param p_name]: 卡名。[param p_cost]: 灵力消耗。[param p_rarity]: 稀有度 1-5。
## [param p_type]: 卡牌类型 0-5。
func set_card_data(p_name: String, p_cost: int, p_rarity: int, p_type: int) -> void:
	card_name = p_name
	cost = maxi(p_cost, 0)
	rarity = clampi(p_rarity, 1, 5)
	card_type = clampi(p_type, 0, TYPE_LABELS.size() - 1)
	_apply()


## 设置费用充足标志（灰显判定——阶段 2 内有效）。
func set_affordable(p_affordable: bool) -> void:
	is_affordable = p_affordable
	_apply()


## 设置灵能预览（阶段 2 外——60% 饱和 + 🔒）。
func set_psychic(p_psychic: bool) -> void:
	is_psychic = p_psychic
	_apply()


## 获取当前 modulate（测试断言用——三态视觉可区分）。
func get_current_modulate() -> Color:
	return modulate


## 锁标记可见性（测试断言用）。
func is_lock_visible() -> bool:
	return is_psychic


## 费用数字色（测试断言用——费用不足时红）。
func get_cost_color() -> Color:
	return COST_UNAFFORDABLE_COLOR if not is_affordable else COST_COLOR


## === 内部 ====================================================================

## 状态落定（modulate 三态 + 重绘）。
func _apply() -> void:
	# 状态优先级：灵能预览 > 灰显（阶段 2 外统一灵能预览，费用不足仅在阶段 2 内灰显）
	if is_psychic:
		modulate = PSYCHIC_MODULATE
	elif not is_affordable:
		modulate = GRAYED_MODULATE
	else:
		modulate = Color.WHITE
	queue_redraw()


## 屏幕高度（未入树时回退 1080——font_size_responsive 输入）。
func _screen_height() -> int:
	return int(get_viewport_rect().size.y) if get_viewport() != null else 1080


## 卡面绘制（R-02 §3 合批——底色/头部/边框 + draw_string 三文字 + 锁，
## 单一 CanvasItem 零子节点）。
func _draw() -> void:
	var card_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(CARD_WIDTH, CARD_HEIGHT))
	draw_rect(card_rect, CARD_BG)
	# 顶部浅色头（近似卡面插画位置——stub 阶段占位）
	draw_rect(Rect2(0.0, 0.0, CARD_WIDTH, 24.0), CARD_HEAD)
	# 稀有度边框（描边——索引 clamp 防越界）
	var border_color: Color = RARITY_BORDER_COLORS[clampi(rarity, 1, 5) - 1]
	draw_rect(card_rect, border_color, false, BORDER_WIDTH)
	var font: Font = ThemeDB.fallback_font
	var h: int = _screen_height()
	# 卡名（顶部左）
	draw_string(font, Vector2(6.0, 14.0), card_name, HORIZONTAL_ALIGNMENT_LEFT,
			CARD_WIDTH - 12.0,
			UiFont.font_size_responsive(NAME_FONT_SIZE, h), NAME_COLOR)
	# 费用（左上角——费用数字色按可负担性）
	draw_string(font, Vector2(6.0, 32.0), str(cost), HORIZONTAL_ALIGNMENT_LEFT,
			22.0, UiFont.font_size_responsive(COST_FONT_SIZE, h),
			get_cost_color())
	# 类型标签（右下角）
	draw_string(font, Vector2(6.0, CARD_HEIGHT - 6.0), TYPE_LABELS[card_type],
			HORIZONTAL_ALIGNMENT_RIGHT, CARD_WIDTH - 12.0,
			UiFont.font_size_responsive(TYPE_FONT_SIZE, h), NAME_COLOR)
	# 锁标记（灵能预览——右上角）
	if is_psychic:
		draw_string(font, Vector2(CARD_WIDTH - 20.0, 16.0), "🔒",
				HORIZONTAL_ALIGNMENT_LEFT, 18.0, LOCK_FONT_SIZE, LOCK_COLOR)
