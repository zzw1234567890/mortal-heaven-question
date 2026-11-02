class_name CombatUiRules
extends RefCounted
## CombatUiRules —— combat-ui 视觉规则纯函数（combat-ui-layout Story 002/005）。
##
## [b]职责[/b]：角色状态卡与费用栏视觉规则的 Logic 内核——HP 颜色阈值、
## 前后排缩放（story 002）+ 费用显示颜色 cost_color（story 005）。与
## [CombatUiFont] 同处 [code]src/ui/combat/shared/[/code]，供 combat-ui
## 后续 story 消费，不得内联实现。[br]
## [br][b]纯函数[/b]（ADR-0031 Logic 内核模式）：无状态、无副作用、
## 确定映射——单元测试零依赖。[br]
## [br][b]阈值集中[/b]（control-manifest 禁止硬编码阈值）：0.6/0.3（HP）与
## 0.5（费用）阈值常量集中定义于此，组件层只消费不复制。
##
## @experimental
## 来源: ADR-0031、design/ux/combat-ui.md §角色状态卡/§费用栏、
## combat-ui-layout Story 002（AC-1/AC-2）+ Story 005（AC-1 cost_color）。

## HP 绿色阈值下界（比例 > 此值 → 绿；恰好等于 → 黄）。
const HP_GREEN_THRESHOLD: float = 0.6
## HP 红色阈值上界（比例 ≤ 此值 → 红；GDD AC 明文 30% 为红）。
const HP_RED_THRESHOLD: float = 0.3

## HP 条颜色（集中定义——R-02 §2 数据驱动条款）。
const HP_COLOR_GREEN: Color = Color(0.22, 0.72, 0.30)
const HP_COLOR_YELLOW: Color = Color(0.92, 0.78, 0.18)
const HP_COLOR_RED: Color = Color(0.85, 0.25, 0.22)

## 前排缩放（100%）。
const FRONT_ROW_SCALE: float = 1.0
## 后排缩放（85%）。
const BACK_ROW_SCALE: float = 0.85

## 费用白色阈值（比例 > 此值 → 白；GDD §4 费用颜色用 50% 阈值——非 HP 的 60%）。
const COST_WHITE_THRESHOLD: float = 0.5

## 费用颜色（集中定义——R-02 §2 数据驱动条款）。[br]
## 色值与 HP 色系一致（充裕=近白/紧张=黄/枯竭=红），阈值独立（50% vs 60%）。
const COST_COLOR_WHITE: Color = Color(0.92, 0.92, 0.90)
const COST_COLOR_YELLOW: Color = Color(0.92, 0.78, 0.18)
const COST_COLOR_RED: Color = Color(0.85, 0.25, 0.22)


## HP 条颜色——按比例分段。[br]
## [br][b]分段[/b]（GDD HP条与视觉反馈 AC）：[br]
##   - ratio > 0.6 → 绿[br]
##   - 0.3 < ratio ≤ 0.6 → 黄（0.6 恰好黄——>0.6 才绿）[br]
##   - ratio ≤ 0.3 → 红（0.3 恰好红——AC 明文）[br]
## [param hp_ratio]: HP 比例（current / max，0.0-1.0）。调用侧需
## 守卫 max_hp == 0（防除零——本函数契约假设 ratio 已合法）。
static func hp_bar_color(hp_ratio: float) -> Color:
	if hp_ratio > HP_GREEN_THRESHOLD:
		return HP_COLOR_GREEN
	if hp_ratio > HP_RED_THRESHOLD:
		return HP_COLOR_YELLOW
	return HP_COLOR_RED


## 前后排缩放系数（UX 交互模式库——角色状态卡）。[br]
## [param is_front_row]: true 前排（100%）/ false 后排（85%）。
## 边框样式（实线金/虚线蓝）为组件独立属性，不经此函数。
static func formation_row_scale(is_front_row: bool) -> float:
	return FRONT_ROW_SCALE if is_front_row else BACK_ROW_SCALE


## 费用显示颜色——按可用/总上限比率分段（GDD §4 公式，含双守卫）。[br]
## [br][b]双守卫[/b]（base_max=0 边界——GDD 明文）：[br]
##   - base_max=0 且 temporary=0 → RED（无费用上限时费用枯竭）[br]
##   - base_max=0 且 temporary>0 → YELLOW（仅临时费用，不视为充裕）[br]
## [br][b]正常分段[/b]（total_max = base_max + temporary；ratio = available/total_max）：[br]
##   - ratio > 0.5 → WHITE（充裕）[br]
##   - ratio > 0.0 → YELLOW（紧张）[br]
##   - ratio ≤ 0.0 → RED（枯竭）[br]
## [br][b]负值契约[/b]：available < 0 时 ratio < 0 → RED（枯竭）；temporary < 0
## 视为 0（负临时加成无意义——调用侧不应传负值，本函数防御性钳制）。[br]
## [param available]: 实际可用费用（含临时加成）。[br]
## [param base_max]: 基础费用上限（境界）。[br]
## [param temporary]: 临时费用加值。
static func cost_color(available: int, base_max: int, temporary: int) -> Color:
	if base_max == 0 and temporary <= 0:
		return COST_COLOR_RED
	if base_max == 0:
		return COST_COLOR_YELLOW
	var temp: int = maxi(temporary, 0)
	var total_max: int = base_max + temp
	if total_max <= 0:
		return COST_COLOR_RED
	var ratio: float = float(available) / float(total_max)
	if ratio > COST_WHITE_THRESHOLD:
		return COST_COLOR_WHITE
	if ratio > 0.0:
		return COST_COLOR_YELLOW
	return COST_COLOR_RED
