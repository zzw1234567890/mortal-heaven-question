extends RefCounted
## NodeGraphStyle —— 节点图的视觉规格（常量唯一来源，纯数据）。[br]
## [br][b]为什么单独成文件[/b]：[code]node_graph_renderer.gd[/code] 越过单文件
## 300 行软上限（coding-standards），而「画成什么样」与「画什么/什么时候画」是
## 两件事——把尺寸、配色、段长收在一处，改配色不必翻绘制逻辑。[br]
## [br][b]数据驱动[/b]：取值来自 GDD 调优参数表与 ADR-0031 §5 合批方案，
## 绘制侧只引用不内联（同 [code]combat_ui_rules.gd[/code] 的口径）。[br]
## [br]来源: ADR-0031 §5、design/gdd/exploration-ui-system.md §2、
## exploration-ui Story 001 / 003。

## === 尺寸/布局（GDD 调优参数表）===========================================

## 节点图标显示边长（px）——GDD「节点图标大小 48×48px」。
const NODE_SIZE: float = 48.0
## 层间距（px）——GDD「节点间距（最小）80px」的纵向分量。
const LAYER_GAP: float = 110.0
## 同层节点间距（px）——横向分量。
const NODE_GAP: float = 90.0
## 节点连线线宽（px）——GDD「节点连线线宽 2px」为下限；本轮提到 3px，
## 因为 2px 暗色虚线在 1920×1080 的暗底上实测量不到（见任务书「虚线不要细到看不见」）。
const EDGE_WIDTH: float = 3.0
## 虚线段长（未访问路径——GDD「暗色虚线」）。
const DASH_LENGTH: float = 10.0
## 节点边框线宽（px）——非强调态基线。
const BORDER_WIDTH: float = 2.5
## 强调态（当前/可达/已访问）的边框线宽（px）——比普通态粗近一倍，让
## 「我在这 / 能去 / 走过」在三米外也分得出来。[br]
## [br][b]为什么是 1.8 倍而不是 +1px[/b]：2px→3px 在 1080p 截图上只有 1 个像素差，
## 缩到 50%（[code]NodeGraphViewport[/code] 的下限）后基本同宽——「粗细也是一层信息」
## 就落空了。
const EMPHASIS_BORDER_WIDTH: float = 4.5
## 类型色底板相对图标的外扩量（px）——图标外一圈类型主色，暗底上更跳。
const TYPE_BACKDROP_GROW: float = 4.0
## 类型色底板的不透明度（低于 0.5——是衬底不是实心块，图标仍读得清）。[br]
## [br]本轮 0.32 → 0.45：暗底上「一圈类型色」要真的看得见，否则这层衬底等于没画。
const TYPE_BACKDROP_ALPHA: float = 0.45
## 节点文字标签字号（pt）——可读下限 14，本轮取 16（12px 在 1080p 上读不出笔画）。
const LABEL_FONT_SIZE: int = 16
## 标签基线相对图标下沿的偏移（px）——跟随字号上调。
const LABEL_BASELINE_OFFSET: float = 16.0
## 标签文字色（暖白——美术圣经底色系，与图集 glyph 同源）。
const LABEL_COLOR: Color = Color(0.97, 0.95, 0.90)
## 标签描边色与描边宽度（px）。[br]
## [br][b]为什么必须描边[/b]：标签落在深色画布与亮色节点图标两种底上（节点下沿
## 一半压在图标外），单一前景色在任一侧都会糊——描边让两种底上都读得清。
const LABEL_OUTLINE_COLOR: Color = Color(0.02, 0.02, 0.03)
const LABEL_OUTLINE_SIZE: int = 3
## 标签排版盒宽度相对节点边长（倍）——居中排版用；比节点宽一倍，
## 三字标签（「渡劫台」）不会被截断。
const LABEL_BOX_RATIO: float = 2.0

## === 迷雾 ==================================================================

## 迷雾底色——深色覆盖（GDD「迷雾节点：深色覆盖 + ❓标记」）。[br]
## [br]本轮 0.72 → 0.80：遮罩画在节点[b]之下[/b]（见
## [method NodeGraphNodePainter.draw_fog] 的顺序注记），要让「雾里」与「雾外」
## 在亮度上有明显落差，遮罩本身就得压得住。
const FOG_COLOR: Color = Color(0.04, 0.05, 0.07, 0.80)
## 迷雾挖孔半径——已揭示/已访问节点区域从遮罩中挖出（px）。[br]
## [br]本轮 34 → 60：34 半径盖不住 48px 的节点与它下方的标签，四角还压在雾里，
## 节点看上去像被啃掉一块。60 = 半个节点 + 标签行高 + 余量。
const FOG_HOLE_RADIUS: float = 60.0
## 迷雾节点个体暗纱色（叠在迷雾节点[b]之上[/b]——遮罩在节点之下，见
## [method NodeGraphNodePainter.draw_fog]）。[br]
## [br][b]为什么遮罩之下还要一层个体暗纱[/b]：遮罩在节点之下才能让已揭示节点
## 保持原本的亮度；但迷雾节点因此也不再被「盖住」了。个体暗纱把这一格压暗，
## 于是「亮的=我知道 / 暗的=还不知道」这层落差照样成立，而图不再是一片黑。
const FOG_NODE_VEIL_COLOR: Color = Color(0.04, 0.05, 0.07, 0.45)
## 挖孔填充色（画布底色——挖孔是「把雾拿掉」，不是「再盖一层近黑」）。[br]
## [br][b]上一版为什么把图画黑[/b]：挖孔用 [code]Color(0.08,0.09,0.12)[/code]
## 近黑，而遮罩画在节点之上——每个已揭示节点都被这层近黑圆盘重涂了一遍，
## 类型色一个不剩（1920×1080 取证图里只剩 1388 个金色边缘像素）。
## 现在遮罩画在节点之下、挖孔用底色，两处一并修掉。
const FOG_HOLE_COLOR: Color = Color(0.055, 0.059, 0.086)
## 迷雾节点图标底衬色（类型不暴露——统一灰底）。[br]
## [br]本轮 0.22 → 0.30：灰底压在更深的新遮罩上，不提亮就沉进背景里，
## 「这里有个我不知道的东西」这层信息也读不出来了。
const FOGGED_FILL_COLOR: Color = Color(0.30, 0.31, 0.35)
## 迷雾问号占位方框边长（px）与相对节点中心的半宽。
const FOG_GLYPH_SIZE: float = 24.0
## 迷雾节点图集 region——❓占位（stub：暗灰底白环，类型不暴露）。
const FOG_GLYPH_REGION_COL: int = 4

## === 节点配色 ==============================================================

## 已访问路径连线色——金色实线（GDD 连线规则）。[br]
## 本轮提亮（#C8A84E → #E8C86A）：暗底上 0.78 的亮度过了一半，取证图里只剩
## 一千多个可见像素——「走过的路」是玩家最该一眼看到的信息。
const EDGE_VISITED_COLOR: Color = Color("#E8C86A")
## 未访问路径连线色——暗灰（GDD 连线规则）。[br]
## 本轮 0.30 → 0.52：虚线本来就比实线弱，再压到三成亮度就彻底读不出来了。
const EDGE_UNVISITED_COLOR: Color = Color(0.52, 0.52, 0.56, 0.95)
## 雾中路径连线色——两端都还没揭示的连线（迷雾战雾语义：图的结构不该被读出来）。[br]
## [br][b]为什么需要一档「雾中线色[/b]」：迷雾遮罩现在画在连线[b]之下[/b]
## （见 [method NodeGraphNodePainter.draw_fog]），连线不再被遮罩压暗——雾里雾外
## 的线就一样亮了，整张图的结构一眼看穿。这一档把雾中线单独压回去。
const EDGE_FOGGED_COLOR: Color = Color(0.20, 0.20, 0.23, 0.55)
## 已访问节点边框色——绿色（GDD 界面规则「已访问：绿色边框 + ✓」）。[br]
## 本轮提亮到 #5AE07A：绿边框要在一堆类型色（战斗红/商店绿/事件蓝）里跳出来。
const NODE_VISITED_BORDER: Color = Color("#5AE07A")
## 当前节点边框色——金色（GDD「当前节点：金色边框」）。
const NODE_CURRENT_BORDER: Color = Color("#FFD700")
## 未知类型边框色——中性灰（迷雾内节点不显示类型色）。[br]
## 本轮 0.45 → 0.58：不可达态的唯一标识就是这条窄灰边，太暗等于没有。
const NODE_DEFAULT_BORDER: Color = Color(0.58, 0.58, 0.62)
## 已访问 / 不可达节点图标暗化强度（AC-4——稍暗）。[br]
## [br][b]亮度也是一层信息[/b]：当前与可达是「亮的」，已访问与不可达压一档，
## 三米外不用读图标就能分出「哪些跟我有关」。
const VISITED_DIM_ALPHA: float = 0.35

## === 状态提示 ==============================================================

## 可达节点脉冲发光外圈色（AC-2——白色/蓝色脉冲外发光；静态近似，动画归手动证据）。
const REACHABLE_GLOW_COLOR: Color = Color(0.35, 0.55, 1.0, 0.45)
## 当前节点的金色发光色（AC-1——与渡劫台恒常金色脉冲独立叠加）。
const GOLD_GLOW_COLOR: Color = Color(1.0, 0.84, 0.0, 0.35)
## 行动力不足红色斜线色（AC-5——灰色 + 红色斜线）。
const AP_INSUFFICIENT_SLASH_COLOR: Color = Color(0.85, 0.20, 0.20)
## 渡劫台「修为尚未圆满」灰色斜线色（AC-8——与 AP 不足红色斜线区分：
## 红=行动力不足不可达，灰=可进入不可触发）。
const TRIBULATION_UNREADY_SLASH_COLOR: Color = Color(0.55, 0.55, 0.58)
## 渡劫台金色脉冲外发光色（AC-11——类型恒常视觉「金色脉冲」，与精英⚡区分；
## 色取自渡劫台类型主色 #FFAA00 带透明度）。
const TRIBULATION_GLOW_COLOR: Color = Color(1.0, 0.667, 0.0, 0.4)
## 渡劫台节点类型 ID——锚定 [code]ExplorationSystem.NodeType.TRIBULATION[/code]
##（=9）。GDD 界面规则表「渡劫台：⚡图标 + 金色脉冲」的类型恒常视觉判定。
const TRIBULATION_TYPE: int = 9
## 状态标记的灰色（锁体/锁梁——AC-5 不可达）。
const MARKER_GRAY: Color = Color(0.78, 0.78, 0.80)

## === 交互视觉 ==============================================================

## 悬停可达节点放大倍率（story-005 AC-5——UX 规格 110%）。[br]
## [b]单一视觉来源[/b]：悬停放大归渲染层（渲染器消费 hovered_node），
## 交互组件不再叠加放大环（避免两套视觉来源——ADR-0031 §4）。
const HOVER_SCALE_RATIO: float = 1.1
## 键盘焦点环色——松石青（ADR-0031 §4「键盘/手柄焦点：松石青 2px 外部光环」）。
const FOCUS_RING_COLOR: Color = Color("#40E0D0")
## 焦点环半径相对节点半宽的余量（px）与分段数。
const FOCUS_RING_MARGIN: float = 6.0
const FOCUS_RING_SEGMENTS: int = 32

## === 悬停 tooltip ==========================================================

## tooltip 底色 / 边框色（stub 配色——真实主题归美术资产管线）。
const TOOLTIP_BG_COLOR: Color = Color(0.08, 0.09, 0.12, 0.94)
const TOOLTIP_BORDER_COLOR: Color = Color(0.55, 0.55, 0.58)
## tooltip 单行高度（px）与内边距。
const TOOLTIP_HEIGHT: float = 24.0
const TOOLTIP_PADDING: float = 8.0
## tooltip 文字基线相对盒子左上角的下移量（px）。
const TOOLTIP_BASELINE: float = 16.0
## 迷雾遮罩相对内容包围盒的外扩量（px）与其两倍（遮罩总数）。
const FOG_MARGIN: float = 40.0
## tooltip 最小宽度（px）与每字符估算宽度（px——stub，真实测量归字体资产管线）。
const TOOLTIP_MIN_WIDTH: float = 64.0
const TOOLTIP_CHAR_WIDTH: float = 12.0
## tooltip 锚点相对节点图标上沿的上移量（px）。
const TOOLTIP_ANCHOR_OFFSET: float = 30.0
