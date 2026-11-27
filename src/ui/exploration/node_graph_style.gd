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

## 节点图标显示边长（px）——GDD「节点图标大小 48×48px」为下限。[br]
## [br][b]本轮 48 → 56[/b]：节点从「纯色方块」改成「地标」（地盘阴影 + 底盘 + 基座），
## 48 的方块里塞进这几层后图标只剩三十来像素。56 是「外扩一圈阴影、图标尺寸不变」的
## 最小可行值；再大会挤掉下方两行标签（余量见 [constant LAYER_GAP]）。[br]
## [br][b]命中框同步[/b]：[method NodeGraphRenderer.hit_test_node] 按本值算矩形——
## 「画得出来就点得到」不受影响。
const NODE_SIZE: float = 56.0
## 布局几何唯一来源（Feature 层纯数学模块——见 [member GeometryRules]）。[br]
## [br][b]★ 为什么间距常量搬到了 Feature 层 ★[/b]：本轮起移动消耗按「两节点在布局
## 坐标里的距离」定价，于是「节点画在哪」被 UI（画/命中）与系统（扣费）[b]两处[/b]读。
## 两处各写一套间距常量，改一次 [constant NODE_GAP] 就会出现「走过去花了 2 点、
## 看起来只有一格远」——玩家看得出来、单测抓不到（两套公式都自洽）。[br]
## [br][b]为什么是转发而不是让调用方改名字[/b]：全项目写的是
## [code]Style.LAYER_GAP[/code] 一族（含既有断言与 [code]node_graph_layout.gd[/code]），
## 转发后一个引用点都不用动；单一出处见 [ExplorationNodeGeometry]。
const GeometryRules := preload(
		"res://src/feature/exploration/exploration_node_geometry.gd")

## 层间距（px）——GDD「节点间距（最小）80px」的纵向分量。[br]
## [br][b]标定推导（第二轮 110 → 104）[/b]：包围盒要往横向长，纵向就得省。104 是
## 下限——地名行基线在图标下沿 +[constant LABEL_BASELINE_OFFSET]、类型行再
## +[constant TYPE_LABEL_EXTRA_OFFSET]，字身下缘距节点中心约 66px；下一层节点上沿
## 距其中心 [constant NODE_SIZE]/2 = 28px，故 104 − 28 = 76 > 66。[br]
## [br][b]不能再大[/b]：纵向越长越接近方形，节点退回「串珠」（第一轮 110 实测 0.44）。[br]
## [br][b]数值本体在 [ExplorationNodeGeometry.LAYER_GAP][/b]——扣费读的是同一个数。
const LAYER_GAP: float = GeometryRules.LAYER_GAP
## 同层节点间距（px）——横向分量。[br]
## [br][b]第二轮地图化 104 → 200[/b]：第一轮铺完后节点簇仍是一根竖条（实测内容
## 包围盒 264×606、宽高比 0.44），像串珠而不像「散落在地图上的一串地标」。拉到 200
## （≈ 3.6 个节点宽）后，同层两格能各容下自己的地名标签（[constant LABEL_BOX_RATIO]
## × [constant NODE_SIZE] = 134px）且中间还有 66px 空档。[br]
## [br][b]不能再大[/b]：层间连线会趋近水平线，而「下一层在下面」是这张 DAG 唯一的
## 读法。另有一条硬边界：内容包围盒左边界 x 必须 > −344（见
## [code]test_node_graph_pick_region.gd[/code] 的 [code]OUTSIDE_POINT[/code]）。[br]
## [br][b]数值本体在 [ExplorationNodeGeometry.NODE_GAP][/b]——扣费读的是同一个数。
const NODE_GAP: float = GeometryRules.NODE_GAP
## 层间水平错开量（px）——蛇形（见 [method NodeGraphLayout.layer_stagger]）。[br]
## [br][b]为什么需要它[/b]：只靠 [constant NODE_GAP] 加宽，各层仍上下对齐成规整网格
## ——「一串地标散在地图上」的观感来自各层走位不同。[br]
## [br][b]为什么是 70[/b]：与 [constant NODE_GAP] 同量级时相邻层节点横向擦肩（读成斜着
## 往下的路，正合地图意图）；再大会把左边界推过 −344 红线。[br]
## [br][b]第 0、1 层不错开[/b]（硬约束）：见 [method NodeGraphLayout.layer_stagger]。
const LAYER_STAGGER: float = GeometryRules.LAYER_STAGGER
## 虚线段长（px）——[b]地区墨边[/b]在「不可达」态下的段长。[br]
## [br][b]★ 本轮归属变了（连线的四个常量已删）★[/b]：它此前是节点连线的虚线参数；
## 连线整个删除之后（老板 2026-11-27 18:40「节点之间不需要线连接」），它是
## [code]node_graph_region_edge_painter.gd[/code] 的唯一读者。[br]
## [br][b]不跟着连线的其余常量一起删[/b]：地区墨边的「不可达=虚线」是六态视觉的一部分
## （地形贴图上的手描线用虚线读得出「此路不通」），与连线无关。[br]
## [br][b]14 这个数是怎么来的[/b]（历史，保留以免下一轮又调回去）：线宽翻倍到 6px 后
## 段长不跟着涨，虚线会读成一条毛边实线——段长必须明显大于线宽才有「断」的观感。
## 地区墨边本身只有 2.5px（[code]RegionStyle.EDGE_WIDTH[/code]），14 对它是宽裕的。
const DASH_LENGTH: float = 14.0
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
## 节点文字标签字号（pt）——可读下限 14。[br]
## [br][b]本轮 16 → 17[/b]：这一行现在是[b]地名[/b]（「青云绝顶」这类四字词）而不是
## 三字以内的类型名，四字在 16pt 下笔画容易连；17 是仍能塞进排版盒的上限（再涨会顶到
## 邻格，见 [constant LABEL_BOX_RATIO]）。
const LABEL_FONT_SIZE: int = 17
## 类型短标签字号（pt，第二行——比地名小一档）。[br]
## [br][b]为什么两行都留[/b]：地名回答「我去哪儿」，类型回答「那儿是什么」
## （战斗/商店/渡劫台），两者是不同的问题。地名为大、类型为小，主次一眼分明。
const TYPE_LABEL_FONT_SIZE: int = 13
## 标签基线相对图标下沿的偏移（px）——地名那一行的基线。
const LABEL_BASELINE_OFFSET: float = 17.0
## 第二行（类型短标签）相对地名基线的下移量（px）。
const TYPE_LABEL_EXTRA_OFFSET: float = 17.0
## 标签文字色（暖白——美术圣经底色系，与图集 glyph 同源）。
const LABEL_COLOR: Color = Color(0.97, 0.95, 0.90)
## 类型短标签色（暗一档的暖白——不与地名抢视线）。
const TYPE_LABEL_COLOR: Color = Color(0.80, 0.77, 0.70)
## 标签描边色与描边宽度（px）。[br]
## [br][b]为什么必须描边[/b]：标签现在压在[b]地图插画[/b]上，底色是山石草木的花纹，
## 深浅完全不规则；再叠一层压暗与暗角之后，同一条标签的两端可能落在亮度差一倍的
## 底色上。描边是这一行可读性的唯一保证（本轮把描边从 3 提到 4，配合字号上调）。[br]
## [br][b]描边色为什么不纯黑[/b]：地形是暖色调（土黄/赭石），纯黑描边会在插画亮部
## 割出一圈生硬的刀口；近黑暖调既压得住底，又不跳出色系。
const LABEL_OUTLINE_COLOR: Color = Color(0.035, 0.028, 0.020)
const LABEL_OUTLINE_SIZE: int = 4
## 标签排版盒宽度相对节点边长（倍）——居中排版用。[br]
## [br][b]本轮 2.0 → 2.4[/b]：56 × 2.0 = 112px 装不下 17pt 的 4 字地名（约 68px 文本
## 加两侧留白尚可，但 5 字地名「碎星外环」那种全角标点混排会顶格）。2.4 = 134px，
## 远小于 [constant NODE_GAP]（200），不会跨到隔壁节点的名字上；第二轮的横向
## 拉开同时把这条拥挤约束解掉了。[br]
## [br][b]第二轮不动它[/b]：字面的可读性不该靠排版盒宽度换——盒子宽度只影响
## 是否居中溢出，字号才是可读性的杠杆。
const LABEL_BOX_RATIO: float = 2.4

## === 节点地盘（本轮新增——节点从方块改成地标）=============================

## 地盘阴影（节点下方的一圈暗色投影）相对节点边长的放大倍率。[br]
## [br][b]为什么要有它[/b]：这是「地标[b]立在地图上[/b]」与「方块[b]浮在背景上[/b]」
## 的差别来源——只靠描边，节点读起来像贴纸；垫一圈投影就有了「压着地面」的观感。
const LANDMARK_SHADOW_SCALE: float = 1.42
## 地盘阴影色（暖黑，带一点透明度——把插画底纹压下去而不盖死）。[br]
## [br][b]为什么下半张更实[/b]：见 [method NodeGraphNodePainter.draw_landmark_plate]——
## 阴影只画在节点下半圈，上半圈留透，视觉上才是「影子落在地上」。
const LANDMARK_SHADOW_COLOR: Color = Color(0.02, 0.018, 0.015, 0.42)
## 地盘底盘（节点外那圈浅色石台）相对节点边长的放大倍率。
const LANDMARK_PLATE_SCALE: float = 1.16
## 底盘色（半透灰石——比插画亮一档，让节点从花纹里浮起来）。
const LANDMARK_PLATE_COLOR: Color = Color(0.22, 0.21, 0.19, 0.72)
## 底盘的浅色描边色与宽度（px——一条细亮边，读成「石台边缘」）。
const LANDMARK_PLATE_EDGE_COLOR: Color = Color(0.46, 0.43, 0.37, 0.75)
const LANDMARK_PLATE_EDGE_WIDTH: float = 1.5
## 底盘切角（八边形切去的比例——0 = 正方形，0.5 = 菱形）。
## [br][b]为什么切一个角而不是画菱形[/b]：菱形（0.5）会让 48px 级别的图标可用面积
## 掉到一半；切掉四角（0.22）在保留方形装载量的同时，形状上与「方块」明显不同——
## 远看是一块[b]地标石碑[/b]而不是 UI 色块。
const LANDMARK_CORNER_CUT: float = 0.22

## === 迷雾（常量已拆到 node_graph_style_fog.gd——此处逐条转出）===============
## [br][b]为什么拆[/b]：本表已贴 300 行软上限，而迷雾那一组数只被「画雾」的两处读
## （[code]node_graph_fog_region.gd[/code] 与迷雾节点分支），与尺寸/配色不相交。[br]
## [br][b]为什么转出而不是让调用方改名字[/b]：全项目写的是 [code]Style.FOG_COLOR[/code]
## （含既有断言），转出后一个引用点都不用动；单一出处仍在 [NodeGraphStyleFog]。
const FogStyle := preload("res://src/ui/exploration/node_graph_style_fog.gd")
## 雾心浓度（柔边把它从边界处的 0 渐升到本值——见 [constant FogStyle.FOG_FEATHER_BAND]）。
const FOG_COLOR: Color = FogStyle.FOG_COLOR
## 挖孔半径（px）——[b]本轮起没有读者[/b]（迷雾改走地区并集内羽化，不再挖孔）。
const FOG_HOLE_RADIUS: float = FogStyle.FOG_HOLE_RADIUS
## 迷雾节点个体暗纱色（遮罩在节点之下，故这一格得自己压暗）。
const FOG_NODE_VEIL_COLOR: Color = FogStyle.FOG_NODE_VEIL_COLOR
## 迷雾节点图标底衬色（类型不暴露——统一灰底）。
const FOGGED_FILL_COLOR: Color = FogStyle.FOGGED_FILL_COLOR
## 迷雾问号占位方框边长（px）与图集 region 列。
const FOG_GLYPH_SIZE: float = FogStyle.FOG_GLYPH_SIZE
const FOG_GLYPH_REGION_COL: int = FogStyle.FOG_GLYPH_REGION_COL
## 柔边羽化带宽（局部 px）与档数（本轮硬边改渐变的两个主旋钮）。
const FOG_FEATHER_BAND: float = FogStyle.FOG_FEATHER_BAND
const FOG_FEATHER_STEPS: int = FogStyle.FOG_FEATHER_STEPS

## === 地形底图（常量已拆到 node_graph_style_terrain.gd——此处逐条转出）=========
## [br][b]为什么拆[/b]：本表已贴 300 行软上限，而本轮要给地形这一组数[b]重新标定[/b]
## （背景清晰化），要写的注记比原来更长。那一组数只被 [code]node_graph_terrain.gd[/code]
## 一个文件读，与尺寸/连线/配色/迷雾不相交。[br]
## [br][b]为什么转出而不是让调用方改名字[/b]：全项目写的是
## [code]Style.TERRAIN_IMAGE_ALPHA[/code] 一族（含既有断言），转出后一个引用点都不用动；
## 单一出处仍在 [NodeGraphStyleTerrain]。[br]
## [br][b]★ 本轮标定：背景不许「虚」★[/b]：插画从半透明铺法改成[b]实铺[/b]
## （α 0.50 → 1.0），压暗量按「地名对比度 ≥ 100」的红线重算（0.40 → 0.42），
## 暗角再收一档（0.34 → 0.24）——推导与红线算术见被转出模块的注记。
const TerrainStyle := preload("res://src/ui/exploration/node_graph_style_terrain.gd")
## 地形底色（插画之下的兜底——插画缺失时不露冷黑底）。
const TERRAIN_BASE_COLOR: Color = TerrainStyle.TERRAIN_BASE_COLOR
## 地图插画不透明度（本轮 1.0——实铺，见 [NodeGraphStyleTerrain] 的推导）。
const TERRAIN_IMAGE_ALPHA: float = TerrainStyle.TERRAIN_IMAGE_ALPHA
## 插画之上的压暗叠层（本轮 0.42——由地名对比度红线算出）。
const TERRAIN_DARKEN_COLOR: Color = TerrainStyle.TERRAIN_DARKEN_COLOR
## vignette 暗角色 / 最外圈浓度 / 带比 / 圈数（本轮再收一档，退回「边缘收边」）。
const VIGNETTE_COLOR: Color = TerrainStyle.VIGNETTE_COLOR
const VIGNETTE_ALPHA: float = TerrainStyle.VIGNETTE_ALPHA
const VIGNETTE_BAND_RATIO: float = TerrainStyle.VIGNETTE_BAND_RATIO
const VIGNETTE_STEPS: int = TerrainStyle.VIGNETTE_STEPS

## === 节点图标（常量已拆到 node_graph_style_icon.gd——此处逐条转出）===========
## [br][b]为什么拆[/b]：本表已贴 300 行软上限，而图标那一组数只被「画一个类型图标」
## 的那一处读。转出后调用方照旧写 [code]Style.ICON_ALPHA[/code]，单一出处见
## [NodeGraphStyleIcon]。
const IconStyle := preload("res://src/ui/exploration/node_graph_style_icon.gd")
## 图标边长相对节点边长的倍率（随节点尺寸缩放——悬停放大时图标一起长）。
const ICON_EDGE_RATIO: float = IconStyle.ICON_EDGE_RATIO
## 图标深色圆盘色（线稿的对比底）与它相对图标的放大倍率。
const ICON_DISC_COLOR: Color = IconStyle.ICON_DISC_COLOR
const ICON_DISC_SCALE: float = IconStyle.ICON_DISC_SCALE
## 图标本体不透明度。
const ICON_ALPHA: float = IconStyle.ICON_ALPHA

## === 节点配色 ==============================================================

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
## 交互组件不再叠加放大环（避免两套视觉来源——ADR-0031 §4）。[br]
## [br][b]为什么只给可达态[/b]：放大是「这一步能走」的承诺，而不可达/AP 不足/
## 已访问的悬停不该暗示可操作。该口径由既有集成断言锁定
## （[code]test_node_move_interaction.gd[/code] 的两条 hover 倍率断言），
## 故六态全覆盖的悬停反馈走 [constant HIGHLIGHT_RING_COLOR] 那条通道而不是改本值。
const HOVER_SCALE_RATIO: float = 1.1
## 键盘焦点环色——松石青（ADR-0031 §4「键盘/手柄焦点：松石青 2px 外部光环」）。[br]
## [br][b]本轮起它也是鼠标悬停环的色[/b]：两种输入走同一条高亮通道（见
## [constant HIGHLIGHT_RING_WIDTH]），双输入对等的落点就是「同一套视觉」，
## 而不是「两套长得像的视觉」。
const FOCUS_RING_COLOR: Color = Color("#40E0D0")
## 焦点环半径相对节点半宽的余量（px）与分段数。
const FOCUS_RING_MARGIN: float = 6.0
const FOCUS_RING_SEGMENTS: int = 32
## 悬停 / 键盘焦点统一高亮的环线宽（px）。[br]
## [br][b]为什么比 [constant BORDER_WIDTH] 粗 1.4 倍[/b]：任务书要求悬停「更粗的轮廓」，
## 而节点边框本身已有 2.5 / 4.5 两档（六态强调态用后者）——高亮环若取 2.5 会与普通态
## 边框同宽、取 4.5 会与强调态边框同宽，两种都读成「这格的状态变了」而不是「鼠标在这儿」。
## 3.5 是一个[b]边框宽度表里不存在[/b]的值：它在任何六态下都不与状态混淆。[br]
## [br][b]为什么不破坏六态区分[/b]：环画在节点[b]之外[/b]（半径 = 半宽 +
## [constant FOCUS_RING_MARGIN]），六态的边框/底衬/暗纱/标记一个都没动；环还统一是
## 松石青——一个六态配色表里没有的色相，不会被误读成某一种状态。
const HIGHLIGHT_RING_WIDTH: float = 3.5
## 高亮外发光色与它相对节点半宽的外扩量（px）。[br]
## [br][b]为什么还要一层发光[/b]：环只有 3.5px，在 1920 取证图的自动适配缩放下
## （约 0.9×）落到屏幕上不足 3px——「鼠标移上去节点要亮」这句反馈靠一条细环单独兑现
## 不了。发光是一块[b]面[/b]，它让整个节点周围的局部亮度抬起来，缩放下也读得出。[br]
## [br][b]为什么是半透明青而不是白[/b]：白光晕会把节点压成灰白（盖住类型色）；
## 青色与状态色（金/绿/灰）都不同族，且 α 0.30 只抬亮度不改色相。
const HIGHLIGHT_GLOW_COLOR: Color = Color(0.25, 0.88, 0.82, 0.30)
const HIGHLIGHT_GLOW_GROW: float = 10.0

## === 悬停 tooltip ==========================================================

## tooltip 底色 / 边框色（stub 配色——真实主题归美术资产管线）。
const TOOLTIP_BG_COLOR: Color = Color(0.08, 0.09, 0.12, 0.94)
const TOOLTIP_BORDER_COLOR: Color = Color(0.55, 0.55, 0.58)
## tooltip 单行高度（px）与内边距。
const TOOLTIP_HEIGHT: float = 24.0
const TOOLTIP_PADDING: float = 8.0
## tooltip 文字基线相对盒子左上角的下移量（px）。
const TOOLTIP_BASELINE: float = 16.0
## 地形（插画 + 压暗 + 暗角）相对[b]可视矩形[/b]的外扩量（px）——单点出处见
## [NodeGraphStyleTerrain.GROUND_MARGIN]。[br]
## [br][b]第二轮：地形矩形从「内容包围盒」改成「可视矩形」[/b]。此前地形跟着内容走，
## 而内容图很窄——1920×1080 取证图里地形只占中间约 33% 宽，左右各 640px 是画布底色
## （左右各 200px 竖带实测「亮度>60 占比」0.00%，即两条纯黑带）。
const GROUND_MARGIN: float = TerrainStyle.GROUND_MARGIN
## 迷雾遮罩相对内容包围盒的外扩量（px）——[b]本轮起没有读者[/b]（同上：不再挖孔、
## 不再按矩形铺）。以下注记记录的是那套做法的取舍，留待决策是否删除。[br]
## [br][b]为什么迷雾不跟着地形铺满视口[/b]：遮罩的形状是「矩形减去已揭示圆孔」，铺满
## 视口就等于「除已揭示节点周围一小圈之外全屏皆雾」——开局只有 5 个节点揭示，整幅图
## 压成一片近黑（实测平均亮度 14.4、左右竖带亮度>60 占比 0.00%）。任务书要的是
## 「迷雾只压未揭示区、已揭示区能看清地形和地名」，不是「全屏皆雾」。[br]
## [br][b]两矩形各司其职[/b]：地形回答「画布上垫着什么」，遮罩回答「哪片山域还没走到」。
## 仍要外扩是因为孔开在节点上（半径 [constant FOG_HOLE_RADIUS]），最外圈的孔会把遮罩
## 边缘啃掉一块，不外扩会出现锯齿状缺口，读起来像渲染坏了。
const FOG_MARGIN: float = 40.0
## tooltip 最小宽度（px）与每字符估算宽度（px——stub，真实测量归字体资产管线）。
const TOOLTIP_MIN_WIDTH: float = 64.0
const TOOLTIP_CHAR_WIDTH: float = 12.0
## tooltip 锚点相对节点图标上沿的上移量（px）。
const TOOLTIP_ANCHOR_OFFSET: float = 30.0
