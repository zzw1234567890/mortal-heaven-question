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
## 节点连线线宽（px）——GDD「节点连线线宽 2px」。
const EDGE_WIDTH: float = 2.0
## 虚线段长（未访问路径——GDD「暗色虚线」）。
const DASH_LENGTH: float = 8.0
## 节点边框线宽（px）。
const BORDER_WIDTH: float = 2.0
## 节点文字标签字号（pt）。
const LABEL_FONT_SIZE: int = 12
## 标签基线相对图标下沿的偏移（px）。
const LABEL_BASELINE_OFFSET: float = 14.0

## === 迷雾 ==================================================================

## 迷雾底色——深色覆盖（GDD「迷雾节点：深色覆盖 + ❓标记」）。
const FOG_COLOR: Color = Color(0.05, 0.06, 0.08, 0.72)
## 迷雾挖孔半径——已访问/已揭示节点区域从遮罩中挖出（px）。
const FOG_HOLE_RADIUS: float = 34.0
## 挖孔填充色（画布底色近似——stub 实现，真实揭雾渐变归后续 story）。
const FOG_HOLE_COLOR: Color = Color(0.08, 0.09, 0.12)
## 迷雾节点图标底衬色（类型不暴露——统一灰底）。
const FOGGED_FILL_COLOR: Color = Color(0.22, 0.23, 0.26)
## 迷雾问号占位方框边长（px）与相对节点中心的半宽。
const FOG_GLYPH_SIZE: float = 24.0
## 迷雾节点图集 region——❓占位（stub：暗灰底白环，类型不暴露）。
const FOG_GLYPH_REGION_COL: int = 4

## === 节点配色 ==============================================================

## 已访问路径连线色——金色实线（GDD 连线规则）。
const EDGE_VISITED_COLOR: Color = Color("#C8A84E")
## 未访问路径连线色——暗灰（GDD 连线规则）。
const EDGE_UNVISITED_COLOR: Color = Color(0.30, 0.30, 0.32, 0.85)
## 已访问节点边框色——绿色（GDD 界面规则「已访问：绿色边框 + ✓」）。
const NODE_VISITED_BORDER: Color = Color("#44CC66")
## 当前节点边框色——金色（GDD「当前节点：金色边框」）。
const NODE_CURRENT_BORDER: Color = Color("#FFD700")
## 未知类型边框色——中性暗（迷雾内节点不显示类型色）。
const NODE_DEFAULT_BORDER: Color = Color(0.45, 0.45, 0.48)
## 已访问节点图标暗化强度（AC-4——稍暗）。
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
