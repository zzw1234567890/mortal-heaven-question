extends RefCounted
## CombatCardDefeatMarker —— 角色卡阵亡态判定与视觉规格（纯函数）。
##
## [b]职责[/b]：回答「这张卡算不算阵亡」「阵亡卡画成什么样」两件事，全部是纯函数——
## [code]CharacterStatusCard[/code] 只负责调用与绘制，判定本身可 GUT 直调。[br]
## [br][b]为什么单独成文件[/b]：[code]character_status_card.gd[/code] 已超单文件
## 300 行软上限（L0-L5 六层绘制本就占满），阵亡表现是独立的一小摊事，塞进去只会
## 让那个文件继续长。[br]
## [br][b]为什么阵亡是派生而不是状态位[/b]：阵亡的真理来源是 [code]CombatRosterState[/code]
## 的 [code]current_hp[/code]（全库唯一写入口是 [code]CombatRosterState.apply_damage[/code]）。
## 卡上再存一个「我以为他死了」的标志就是第二份真源——两处一旦不同步，玩家会看到
## 「已阵亡」的角色还满血站着。[method is_defeated] 因此只做一次纯判定，输入就是
## 卡上已有的 HP 渲染快照。[br]
## [br][b]max_hp > 0 才判[/b]：读不到数据的角色（[code]known=false[/code]，HP 全零）
## 不算阵亡——同 [code]CombatSystem.is_character_alive[/code] 的「不因缺数据判死」。
## 没有这条守卫，所有敌方卡在首帧「0/0 等刷新」的窗口里会集体盖戳。[br]
##
## @experimental
## 来源: ADR-0031 §2 零状态所有权、design/gdd/ai-system.md §敌方信息栏、
## 本轮任务书缺口一（全灭/阵亡要有视觉区分）。

## 阵亡戳记文案（本地化 epic 后替换为 key——与占位场景同一条豁免口径）。
const TEXT_DEFEATED: String = "已阵亡"

## 阵亡灰化覆盖色（半透明深灰——压住头像与 HP 条，与「已行动」的浅灰遮罩
## [code]ACTED_OVERLAY_COLOR[/code] 拉开明度差，两者同时出现也分得清）。
const OVERLAY_COLOR: Color = Color(0.16, 0.16, 0.18, 0.62)

## 阵亡戳记底色（暗红——文字与底色对比度 ≥4.5:1，见 GDD 无障碍条款）。
const STAMP_BG_COLOR: Color = Color(0.32, 0.06, 0.06, 0.92)

## 阵亡戳记文字色（暖白——同 [code]CharacterStatusCard.ATK_COLOR[/code] 的对比度口径）。
const STAMP_TEXT_COLOR: Color = Color(0.96, 0.94, 0.88)

## 阵亡戳记条高（px——横贯卡宽的一条，压在 L3 底部条之上）。
const STAMP_HEIGHT: float = 22.0

## 戳记条默认躲开的底部条高度（L3 的 40px——戳记压在它上方，不遮住 HP 数字）。[br]
## [br][b]调用方可以覆盖[/b]：卡自己知道底部条多高（[code]BOTTOM_BAR_HEIGHT[/code]），
## [method draw_on] 的 [param p_reserve_bottom] 收的就是那个值——这里只做默认值，
## 免得两处各写一个 40 然后某天只改了一处。
const BOTTOM_STRIP_RESERVE: float = 40.0


## 是否阵亡——[b]唯一判定入口[/b]。[br]
## [br][b]判定[/b]：[code]max_hp > 0[/code]（有 HP 数据）且 [code]current_hp <= 0[/code]。[br]
## [br][param p_current_hp] 当前 HP（渲染快照）。[param p_max_hp] 最大 HP；
## 为 0 表示读不到数据——不判阵亡。[br]
## [br][b]返回[/b]：true = 该角色已阵亡，卡应画灰化 + 「已阵亡」戳记。
static func is_defeated(p_current_hp: int, p_max_hp: int) -> bool:
	if p_max_hp <= 0:
		return false
	return p_current_hp <= 0


## 阵亡视觉规格——[code]{overlay, stamp_bg, stamp_text, text, stamp_height}[/code]。[br]
## [br][b]为什么给整份规格而不是散着调[/b]：绘制侧与断言侧读的是同一份字典，
## 改色只改这里一处（同 [code]NodeStateLogic.node_state_style[/code] 的口径）。[br]
## [br][param p_defeated] 由 [method is_defeated] 得出的判定结果；false 时
## 返回的 [code]overlay[/code] 为全透明、[code]text[/code] 为空串（绘制侧据此跳过）。
static func style(p_defeated: bool) -> Dictionary:
	if not p_defeated:
		return {
			"overlay": Color.TRANSPARENT,
			"stamp_bg": Color.TRANSPARENT,
			"stamp_text": STAMP_TEXT_COLOR,
			"text": "",
			"stamp_height": STAMP_HEIGHT,
		}
	return {
		"overlay": OVERLAY_COLOR,
		"stamp_bg": STAMP_BG_COLOR,
		"stamp_text": STAMP_TEXT_COLOR,
		"text": TEXT_DEFEATED,
		"stamp_height": STAMP_HEIGHT,
	}


## 阵亡是否应当压暗头像（与 [method style] 的 overlay 同源，供测试读语义）。[br]
## [br][b]返回[/b]: true = 该卡需要灰化处理。
static func dims_portrait(p_defeated: bool) -> bool:
	return p_defeated


## 在卡面上绘制阵亡灰化 + 戳记底色（[b]只在 [code]_draw()[/code] 调用栈内可用[/b]）。[br]
## [br][b]为什么收在这里[/b]：绘制规格与绘制动作必须同源——散在卡里写死颜色，
## 改色时要同时改 [method style] 和卡片两处。本方法接收 [param p_canvas]
## （即调用方自身）而不是继承 CanvasItem，是为了让规格保持纯函数、可单测。[br]
## [br][param p_reserve_bottom] 戳记要躲开的高度（调用方传自己的底部条高——
## 默认 [constant BOTTOM_STRIP_RESERVE]）。[br]
## [br][b]未阵亡时什么都不画[/b]（overlay 全透明短路）——调用方无条件调用即可。
static func draw_on(p_canvas: CanvasItem, p_size: Vector2, p_defeated: bool,
		p_reserve_bottom: float = BOTTOM_STRIP_RESERVE) -> void:
	var spec: Dictionary = style(p_defeated)
	var overlay: Color = spec.get("overlay", Color.TRANSPARENT)
	if overlay.a <= 0.0:
		return
	p_canvas.draw_rect(Rect2(Vector2.ZERO, p_size), overlay)
	var h: float = float(spec.get("stamp_height", STAMP_HEIGHT))
	p_canvas.draw_rect(Rect2(Vector2(0.0, p_size.y - p_reserve_bottom - h),
		Vector2(p_size.x, h)), spec.get("stamp_bg", Color.TRANSPARENT))
