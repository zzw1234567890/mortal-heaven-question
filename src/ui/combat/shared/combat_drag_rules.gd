class_name CombatDragRules
extends RefCounted
## CombatDragRules —— 手牌拖拽启动阈值纯函数（combat-ui-interaction 001 / 本轮：
## 真实输入路径）。
##
## [b]职责[/b]：判断「按下后移动了多少」是否已经越过拖拽启动阈值——
## GDD 手牌交互 AC 明文「鼠标移动 ≥8px 后启动拖拽」，不足 8px 视为点击/悬停，
## 不能因为手抖把「点一下看详情」变成「拖拽出牌」。[br]
## [br][b]为什么独立成纯函数[/b]：阈值是审查过的规格数字（不是魔法值），
## 输入组件只负责取坐标；把它抽出来后边界（7px/8px/9px）能零 UI 依赖断言。
## [br][b]纯函数[/b]（ADR-0031 Logic 内核模式）：无状态、无副作用。
##
## @experimental
## 来源: ADR-0004、design/gdd/combat-ui-system.md §手牌交互、
## production/epics/combat-ui-interaction/story-003-drag-play-flow.md（AC-1）。

## 拖拽启动阈值（px——GDD「≥8px」，含边界）。
const DRAG_THRESHOLD: float = 8.0

## 是否越过拖拽阈值。[br]
## [br][b]含边界[/b]：距离恰好 8px 即启动（GDD 写的是「≥8px」）。[br]
## [param p_press_pos] 按下时的本地坐标。[br]
## [param p_current_pos] 当前指针的本地坐标。[br]
## [param p_threshold] 阈值（默认 [constant DRAG_THRESHOLD]——测试可注入）。[br]
## [b]返回[/b]: 是否启动拖拽。
static func should_start(p_press_pos: Vector2, p_current_pos: Vector2,
		p_threshold: float = DRAG_THRESHOLD) -> bool:
	return p_press_pos.distance_to(p_current_pos) >= p_threshold


## 本次释放是否算「点击」（从未启动拖拽）。[br]
## [param p_dragged] 本次按压期间是否已启动过拖拽。
static func is_click(p_dragged: bool) -> bool:
	return not p_dragged
