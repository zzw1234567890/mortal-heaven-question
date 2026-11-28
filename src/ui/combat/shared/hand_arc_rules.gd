class_name HandArcRules
extends RefCounted
## HandArcRules —— 手牌弧形几何纯函数（combat-ui-layout Story 006）。
##
## [b]职责[/b]：手牌区 Logic 内核——弧形排位 [method hand_card_position]、堆叠
## 重叠量 [method card_overlap_offset]、Z 层序 [method hand_card_z_index] 三个
## 纯函数（GDD combat-ui-system.md §1/§2 公式），供 [HandArea] 组件消费，
## 不得内联实现（story 001 共享纯函数模块条款）。[br]
## [br][b]纯函数[/b]（ADR-0031 Logic 内核模式）：无状态、无副作用、确定映射——
## 单元测试零依赖。[br]
## [br][b]>7 张合成语义[/b]（GDD 2026-09-07 裁决）：间距优先、角度自适应——
## [method hand_card_position] 在 total_cards>7 时先消费 [method card_overlap_offset]
## 求有效间距，再压缩 arc_angle 使弦长匹配（角度随卡数收敛）。
##
## @experimental
## 来源: ADR-0031、design/gdd/combat-ui-system.md §1/§2、
## combat-ui-layout Story 006（AC-1/AC-2/AC-3/AC-4）。

## === 公式常量（GDD §1/§2 调优旋钮——集中定义，禁止内联硬编码）===============

## 默认卡宽（px——UX hud.md「手牌中宽度 100px，宽高比 5:7」）。
const DEFAULT_CARD_WIDTH: float = 180.0
## 屏幕两侧边距（px——GDD 公式 1 两侧各 20px）。
const EDGE_MARGIN: float = 20.0
## 标准间距加值（px——GDD「卡宽+10px」）。
const SPACING_GAP: float = 10.0
## 手牌底缘基准（GDD——屏幕高度 × 86%，响应式）。
const BASE_Y_RATIO: float = 0.86
## 默认卡高（px——与 [constant DEFAULT_CARD_WIDTH] 守 5:7，UX hud.md）。
const DEFAULT_CARD_HEIGHT: float = 252.0
## 底栏高度占屏比（与 CombatLayoutZones.BOTTOMBAR_HEIGHT_RATIO 同源）。
const BOTTOMBAR_HEIGHT_RATIO: float = 180.0 / 1080.0
## 卡底与底栏顶之间留的空隙（px——太小会读成「贴在底栏上」）。
const BOTTOMBAR_GAP: float = 8.0
## 弧形最大角度（度——GDD 最多 30°）。
const MAX_ARC_ANGLE_DEG: float = 30.0
## 每张卡增加角度（度——GDD total_cards × 3°）。
const ARC_PER_CARD_DEG: float = 3.0
## 堆叠触发阈值（张——GDD 公式 2「>7 张重叠」）。
const OVERLAP_THRESHOLD: int = 7
## 每多一张重叠比例（GDD——30% 卡宽，与调优参数表一致）。
const OVERLAP_RATIO: float = 0.3
## 最小间距下限（GDD——不低于 40% 卡宽，保证可辨认）。
const OVERLAP_MIN_RATIO: float = 0.4
## 手牌上限（张——GDD 公式 1 变量范围 [0, 10]）。
const HAND_MAX_CARDS: int = 10


## 手牌弧形排位——单张卡牌位置与旋转（GDD §1 公式）。[br]
## [br][b]守卫[/b]：[br]
##   - total_cards ≤ 0 → 返回空字典（空手牌不计算位置）[br]
##   - total_cards == 1 → (屏幕中心, 0.86H, 0)（单张无弧度）[br]
## [br][b]≤7 张[/b]：GDD 半径法圆弧——radius×sin / radius×(1-cos)（2026-09-06
## 修订否决 tan V 形），端点恰好落 20px 边距守恒。[br]
## [br][b]>7 张合成[/b]（间距优先、角度自适应）：先经 [method card_overlap_offset]
## 求有效间距，水平均匀分布（相邻卡水平间距 == overlap 返回值），再压缩
## arc_angle（21°×7/total 收敛）使弦长匹配，弧形抬升为 radius×(1-cos) 剖面。[br]
## [br][b]响应式卡宽[/b]：card_width = min(默认, 可用宽/total)，保证低分辨率 +
## 满手牌不溢出。[br]
## [br][param index]: 卡牌索引 [0, total_cards-1]。[br]
## [param total_cards]: 手牌数量 [0, 10]。[br]
## [param screen_width]: 屏幕宽度（px）。[br]
## [param screen_height]: 屏幕高度（px）。[br]
## [b]返回[/b]: [code]{"x": float, "y": float, "rotation": float}[/code]——
## x/y 为卡牌**中心**坐标；rotation 为弧度（Godot 约定），从 -half 到 +half
## 随 index 单调递增。
static func hand_card_position(index: int, total_cards: int,
		screen_width: float, screen_height: float) -> Dictionary:
	if total_cards <= 0:
		return {}  # 守卫：空手牌不计算位置
	var center: float = screen_width * 0.5
	var available_width: float = screen_width - EDGE_MARGIN * 2.0
	# 响应式卡宽：低分辨率 + 满手牌不溢出
	var card_width: float = minf(DEFAULT_CARD_WIDTH,
			available_width / float(total_cards))
	# 底缘贴底栏上方 BOTTOMBAR_GAP：按卡高反推中心 y（不用 0.86H 硬口径——
	# 卡放大到 180×252 后 0.86H 会把卡压到底栏上）。
	var base_y: float = bottom_limit_y(screen_height) - card_height_of(card_width) * 0.5
	if total_cards == 1:
		return {"x": center, "y": base_y, "rotation": 0.0}  # 单张卡无弧度
	if total_cards <= OVERLAP_THRESHOLD:
		# GDD 半径法圆弧（radius×sin / radius×(1-cos)——端点 20px 边距守恒）
		var arc_angle_deg: float = minf(MAX_ARC_ANGLE_DEG,
				float(total_cards) * ARC_PER_CARD_DEG)
		var arc_rad: float = deg_to_rad(arc_angle_deg)
		var half_angle: float = arc_rad * 0.5
		var span: float = maxf(available_width - card_width, 0.0)
		var radius: float = (span * 0.5) / sin(half_angle) \
				if sin(half_angle) > 0.01 else 9999.0
		var angle: float = -half_angle \
				+ (float(index) / float(total_cards - 1)) * arc_rad
		return {
			"x": center + radius * sin(angle),
			"y": base_y - radius * (1.0 - cos(angle)),
			"rotation": angle,
		}
	# >7 张——间距优先、角度自适应（GDD 2026-09-07 裁决）：先 overlap 求有效间距，
	# 相邻卡水平间距恒等于 spacing；再压缩 arc_angle 使弦长匹配（角度随卡数收敛）
	var spacing: float = card_overlap_offset(total_cards, card_width)
	var half_index: float = float(total_cards - 1) * 0.5
	var arc_angle_deg: float = float(OVERLAP_THRESHOLD) * ARC_PER_CARD_DEG \
			* float(OVERLAP_THRESHOLD) / float(total_cards)  # 21°×7/total 收敛
	var half_angle: float = deg_to_rad(arc_angle_deg) * 0.5
	var chord: float = float(total_cards - 1) * spacing  # 弦长 = 水平总跨度
	var radius: float = chord * 0.5 / sin(half_angle) \
			if sin(half_angle) > 0.01 else 9999.0
	var t: float = (float(index) - half_index) / half_index  # 归一化 [-1, 1]
	var angle: float = t * half_angle
	return {
		"x": center + (float(index) - half_index) * spacing,
		"y": base_y - radius * (1.0 - cos(angle)),
		"rotation": angle,
	}


## 卡高——由卡宽按 5:7 等比推导（宽高比是 GDD 硬约束，宽度响应式时高跟着走）。[br]
## [param card_width]: 卡宽（px）。[br]
## [b]返回[/b]: 卡高（px）。
## 手牌实际卡宽——响应式：满手牌 + 窄视口时按可用宽等分，否则取默认宽。[br]
## [param total_cards]: 手牌张数（≥1）。[param viewport_w]: 视口宽（px）。[br]
## [b]返回[/b]: 卡宽（px）。
static func card_width_of(total_cards: int, viewport_w: float) -> float:
	var available_width: float = viewport_w - EDGE_MARGIN * 2.0
	return minf(DEFAULT_CARD_WIDTH, available_width / float(maxi(total_cards, 1)))


## 手牌实际卡尺寸——宽随视口响应，高按 5:7 等比。[br]
## [param total_cards]: 手牌张数（≥1）。[param viewport_w]: 视口宽（px）。[br]
## [b]返回[/b]: [code]Vector2(卡宽, 卡高)[/code]。
static func card_size(total_cards: int, viewport_w: float) -> Vector2:
	var w: float = card_width_of(total_cards, viewport_w)
	return Vector2(w, card_height_of(w))


static func card_height_of(card_width: float) -> float:
	return card_width * (DEFAULT_CARD_HEIGHT / DEFAULT_CARD_WIDTH)


## 手牌可用底边——底栏顶再往上让 [constant BOTTOMBAR_GAP]（px）。[br]
## [param viewport_h]: 视口高（px）。[br]
## [b]返回[/b]: 卡底允许到达的最低 y。
static func bottom_limit_y(viewport_h: float) -> float:
	return viewport_h * (1.0 - BOTTOMBAR_HEIGHT_RATIO) - BOTTOMBAR_GAP


## 手牌堆叠重叠量（GDD §2 公式——>7 张时相邻卡牌间距）。[br]
## [br][b]语义[/b]：≤7 张标准间距（卡宽+10px）；>7 张每多一张重叠 30% 卡宽，
## 最终间距 = 卡宽 - 总重叠量，下限守卫 40% 卡宽保证可辨认。[br]
## [br][param total_cards]: 手牌数量。[br]
## [param card_width]: 卡宽（px）。[br]
## [b]返回[/b]: 相邻卡牌有效间距（px）。
static func card_overlap_offset(total_cards: int, card_width: float) -> float:
	if total_cards <= OVERLAP_THRESHOLD:
		return card_width + SPACING_GAP  # 无重叠，标准间距
	var excess: int = total_cards - OVERLAP_THRESHOLD
	var total_overlap: float = card_width * OVERLAP_RATIO * float(excess)
	var spacing: float = card_width - total_overlap
	return maxf(spacing, card_width * OVERLAP_MIN_RATIO)  # 下限守卫


## 手牌 Z 层序——中心卡最高，向两侧递减（GDD §2「中心卡牌优先」）。[br]
## [br][b]公式[/b]：(total_cards-1) - ⌊|2×index - (total_cards-1)| / 2⌋——相邻 index
## z 差 1，中心 index 得最高 z，两侧对称递减；奇数张单中心、偶数张双中心
## 同层（tie-break 确定且一致）。[br]
## [br][param index]: 卡牌索引 [0, total_cards-1]。[br]
## [param total_cards]: 手牌数量。[br]
## [b]返回[/b]: z_index（非负——中心最高，Godot 高 z 渲染在上）。
static func hand_card_z_index(index: int, total_cards: int) -> int:
	if total_cards <= 0:
		return 0  # 守卫：空手牌 z=0（自洽——非负契约）
	return (total_cards - 1) - absi(2 * index - (total_cards - 1)) / 2
