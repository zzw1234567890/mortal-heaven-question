extends RefCounted
## TopBarLayout —— 顶栏[b]两侧元素的分栏口径[/b]（节点图 / 地图选择共用一份）。[br]
##
## [b]为什么需要[/b]：两个界面的顶栏此前各写各的偏移量——地图选择的标题与余额
## 只隔 20px（[code]TitleLabel.offset_right = -420[/code] 对
## [code]BalanceLabel.offset_left = -400[/code]），节点图的退出按钮距左边缘 16px、
## AP 行距右边缘 16px，中间的「走投无路」提示从 144px 起。没有一处是错的，
## 但也没有一处是同一套口径——玩家反馈的「左上角与右上角元素重叠」正是这种
## 「各写各的」在窄分辨率下的必然结果。[br]
##
## [br][b]本模块是那份口径的唯一落点[/b]：贴边多少、中间至少留多少，改一处即
## 两个界面同时改（禁止两处各写一份——.claude/rules「硬性规则：禁止重复」）。[br]
##
## [br][b]纯函数 / 纯常量[/b]：不 extends Node、不访问 Autoload、不持有控件——
## 单测零依赖（[code]ApDisplayRules[/code] / [code]combat_ui_rules.gd[/code] 先例）。
## 判据函数收控件也只读它们的 rect。[br]
##
## 来源: 玩家反馈「左上角与右上角元素重叠（图标与文字压在一起）」、
## design/gdd/exploration-ui-system.md §1/§2（顶栏草图）、
## .claude/rules/ui-code.md（最小与最大分辨率下都要完整）。

## 顶栏元素距屏幕边缘的统一留白（px）——左侧元素从这里起，右侧元素右缘到这里止。[br]
## [br][b]为什么是 24[/b]：项目内其余贴边元素（HUD 各区域容器）都在 16px 上下，
## 顶栏既有按钮又有文字，比纯图标类宽一档才不显得贴边（16px 时按钮边框几乎
## 压着屏幕边）。
const EDGE_MARGIN: float = 24.0

## 两侧元素之间必须留出的空白（px）——留给标题类文字（地图名 / 关卡名）。[br]
## [br][b]为什么钉死在代码里[/b]：这是「两栏不打架」的量化口径。写死像素的
## 单侧宽度只要遇到长标题就会互相压——把中间留出来，标题再长也只是被自己的
## 裁切收尾，不会顶到另一侧。
const MIDDLE_GAP_MIN: float = 100.0

## 顶栏高度（px）——两个界面的顶栏同高（节点图把节点图视口压在它下面，
## 地图选择把卡片滚动区压在它下面，改高度时两处一起改）。
const BAR_HEIGHT: float = 48.0

## 左上角留给全局 HUD「境界修为区」的宽度（px）——顶栏左侧元素从这里[b]之后[/b]起。[br]
## [br][b]为什么顶栏要让 HUD[/b]：HUD 是 [code]CanvasLayer.layer = 90[/code] 的常驻层，
## 在探索/地图选择/商店/事件/卡组编辑里都可见，它的境界修为区锚在左上角
## [code](16,12)-(256,72)[/code]（[code]HUD.tscn[/code] 的 [code]RealmBarArea[/code]）。
## 两块矩形一重叠，Godot 的控件拾取先按 [code]layer[/code] 降序排——HUD 在上，
## 落在顶栏按钮上的左键会被它吃掉（[code]RealmBar[/code] 根节点
## [code]mouse_filter = STOP[/code]，G8 裁决为 tooltip 悬停而设），玩家鼠标点不动
## [code]TopBar/ExitButton[/code]。鼠标点不动「退出探索」= 主动结束探索这条退路断开。[br]
## [br][b]为什么让的是顶栏而不是把 HUD 挪走/改成 IGNORE[/b]：境界修为区在左上角是
## GDD/UX 两处写死的全局约定（[code]design/gdd/hud-system.md[/code] §布局表、
## [code]design/ux/hud.md[/code]「元素 1」，五个场景共用），而为 tooltip 而设的
## STOP 是 G8 裁决的既有结论——两者都不该为探索顶栏的一个按钮让路。顶栏的位置反倒是
## 本模块能定的：横向排布，往右挪一段不影响任何语义。[br]
## [br][b]取值 = HUD 锚区右缘（256）+ 一段留白[/b]：256 是 [code]HUD.tscn[/code] 里
## [code]RealmBarArea.offset_right[/code] 的设计值，本模块不 import 场景——那会把
## 「读 .tscn」变成编译期依赖。改 HUD 锚区宽度时这里要一起改，由
## [code]tests/integration/playtest/test_top_bar_hud_occlusion.gd[/code] 的真实矩形
## 断言兜住（改了不同步会红）。
const HUD_LEFT_ANCHOR_EDGE: float = 256.0


## 两个控件之间的水平间距（[param p_right] 左缘 - [param p_left] 右缘）。[br]
## [br][param p_left] 左侧控件（可 null——返回 0 表示无从判定）。[br]
## [param p_right] 右侧控件（可 null——同上）。[br]
## [br][b]返回[/b]：间距（px）；控件缺失时为 0（调用方按「判不了」处理，
## 不要当成「贴在一起」）。[br]
## [br][b]用 [method Control.get_global_rect] 而非 [member Control.position][/b]：
## 两个控件可能挂在不同父节点下（本项目的顶栏就是一层 Control 套一层），
## 各自的局部坐标不可比——全局矩形才是玩家看得见的那个相对位置。
static func gap_between(p_left: Control, p_right: Control) -> float:
	if p_left == null or p_right == null:
		return 0.0
	return p_right.get_global_rect().position.x - p_left.get_global_rect().end.x


## 控件右缘距视口右边缘的距离（px）。[br]
## [br][param p_node] 待测控件（可 null——返回 0）。[br]
## [param p_viewport_width] 视口宽度（调用方从 [method Control.get_viewport_rect]
## 取——本模块不伸手去拿 Autoload / 单例）。[br]
static func right_margin_of(p_node: Control, p_viewport_width: float) -> float:
	if p_node == null:
		return 0.0
	return p_viewport_width - p_node.get_global_rect().end.x


## 两个控件是否互不相交（矩形不相交 / 相切算通过）。[br]
## [br][b]相切算通过[/b]：间距为 0 时两块矩形刚好贴着，没有像素重叠——
## 玩家看到的「压在一起」需要真的重叠。
static func is_clear_of(p_left: Control, p_right: Control) -> bool:
	if p_left == null or p_right == null:
		return false
	return p_left.get_global_rect().intersection(p_right.get_global_rect()).get_area() <= 0.0


## 两侧元素是否满足分栏口径（不相交 + 中间留白够）。[br]
## [br][b]返回[/b]：满足为 true；任一控件缺失为 false（判不了就不放行——
## 分栏断言宁严勿松）。[br]
static func respects_split(p_left: Control, p_right: Control) -> bool:
	if p_left == null or p_right == null:
		return false
	return is_clear_of(p_left, p_right) and gap_between(p_left, p_right) >= MIDDLE_GAP_MIN
