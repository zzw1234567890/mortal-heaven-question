extends Control
## NodeGraphRenderer 声明面（继承链首段）——[b]preload / 视觉常量 / 信号 / 渲染输入字段[/b]。
##
## [b]为什么拆成继承链[/b]：[code]node_graph_renderer.gd[/code] 本轮地图化后越过单文件
## 300 行软上限（coding-standards）。本层只放[b]声明[/b]（不含任何方法体），方法面全部
## 留在链尾——[code]class_name NodeGraphRenderer[/code] / [code]extends Control[/code]
## 的对外身份一字未变（[NodeGraphViewport] 的 [code]renderer: NodeGraphRenderer[/code]
## 等引用点不受影响）。[br]
##
## [br][b]为什么这些常量必须落链首[/b]：它们被相邻 UI 与测试直接读
## （[code]r.TRIBULATION_TYPE[/code] / [code]renderer.HOVER_SCALE_RATIO[/code] /
## [code]renderer.NODE_SIZE[/code]），转发层留在这里则「常量住在哪」可以继续演进。[br]
##
## [br][b]信号只能声明在链首[/b]（GDScript 解析期硬约束）：派生段 [code]emit[/code]
## 一个祖先段没声明的信号会解析失败。[br]
##
## [br]来源: ADR-0031 §2/§4/§5、design/gdd/exploration-ui-system.md §2、
## exploration-ui Story 001 / 003。

## 视觉规格（常量唯一来源）。
const Style := preload("res://src/ui/exploration/node_graph_style.gd")
## 几何换算（坐标 / 包围盒 / 迷雾集合，纯函数）。
const Layout := preload("res://src/ui/exploration/node_graph_layout.gd")
## 单节点绘制（legacy + 六态）。
const Painter := preload("res://src/ui/exploration/node_graph_node_painter.gd")
## 地形底图 + 迷雾遮罩（含多边形挖孔缓存）——本轮地图化的「地面层」。
const GroundLayer := preload(
		"res://src/ui/exploration/node_graph_ground_layer.gd")
## 小径（连线）绘制（已走过 / 未走过 / 雾中——从本文件拆出，见类文档）。
const EdgePainter := preload(
		"res://src/ui/exploration/node_graph_edge_painter.gd")
## 悬停 tooltip 绘制（与节点绘制分开一层——见该模块文档）。
const Tooltip := preload("res://src/ui/exploration/node_graph_tooltip_painter.gd")
## 六态样式查询（判定与绘制共用同一套枚举）。
const NodeStateLogicScript := preload("res://src/ui/exploration/node_state_logic.gd")
## 悬停提示文案组装（纯函数——see [NodeGraphHoverText]）。
const HoverTextScript := preload(
		"res://src/ui/exploration/node_graph_hover_text.gd")
## 地名池（节点 → 地名——渲染快照里没有地名，绘制期按 map_id + node_id 取）。
const PlaceCatalogScript := preload(
		"res://src/feature/exploration/exploration_place_catalog.gd")

## === Visual 常量（转发 [NodeGraphStyle]——外部既有引用点不变）==================
## [br][b]为什么留一层转发[/b]：这些常量被测试与相邻 UI 直接读
## （[code]r.TRIBULATION_TYPE[/code] / [code]renderer.HOVER_SCALE_RATIO[/code]
## 等），转发后「常量住在哪」可以继续演进而不牵动调用方。

## 节点图标显示边长（px——GDD 调优参数「节点图标大小 48×48px」）。
const NODE_SIZE: float = Style.NODE_SIZE
## 层间距（px）——GDD 调优参数「节点间距（最小）80px」的纵向分量。
const LAYER_GAP: float = Style.LAYER_GAP
## 同层节点间距（px）——横向分量。
const NODE_GAP: float = Style.NODE_GAP
## 节点连线线宽（px）——GDD「节点连线线宽 2px」的下限之上（本轮起为「小径」宽度）。
const EDGE_WIDTH: float = Style.EDGE_WIDTH
## 已走过小径的线宽（px）——踩实的路更宽（第二根独立的轴，色觉障碍下也读得出）。
const EDGE_WALKED_WIDTH: float = Style.EDGE_WALKED_WIDTH
## 虚线段长（未访问路径——GDD「暗色虚线」）。
const DASH_LENGTH: float = Style.DASH_LENGTH
## 已访问路径连线色——金色实线（GDD 连线规则）。
const EDGE_VISITED_COLOR: Color = Style.EDGE_VISITED_COLOR
## 未访问路径连线色——亮灰（GDD 连线规则）。
const EDGE_UNVISITED_COLOR: Color = Style.EDGE_UNVISITED_COLOR
## 雾中路径连线色——两端未揭示的连线（压在遮罩语义下，见 [method _draw]）。
const EDGE_FOGGED_COLOR: Color = Style.EDGE_FOGGED_COLOR
## 已访问节点边框色——绿色（GDD 界面规则「已访问：绿色边框 + ✓」）。
const NODE_VISITED_BORDER: Color = Style.NODE_VISITED_BORDER
## 当前节点边框色——金色（GDD「当前节点：金色边框」）。
const NODE_CURRENT_BORDER: Color = Style.NODE_CURRENT_BORDER
## 未知类型边框色——中性暗（迷雾内节点不显示类型色）。
const NODE_DEFAULT_BORDER: Color = Style.NODE_DEFAULT_BORDER
## 迷雾节点图集 region——❓占位（stub：暗灰底白环，类型不暴露）。
const FOG_GLYPH_REGION_COL: int = Style.FOG_GLYPH_REGION_COL
## 渡劫台节点类型 ID——锚定 [code]ExplorationSystem.NodeType.TRIBULATION[/code]（=9）。
const TRIBULATION_TYPE: int = Style.TRIBULATION_TYPE
## 渡劫台金色脉冲外发光色（AC-11——类型恒常视觉）。
const TRIBULATION_GLOW_COLOR: Color = Style.TRIBULATION_GLOW_COLOR
## 悬停可达节点放大倍率（story-005 AC-5——UX 规格 110%）。[br]
## [b]单一视觉来源[/b]：悬停放大归渲染层，交互组件不再叠加放大环。
const HOVER_SCALE_RATIO: float = Style.HOVER_SCALE_RATIO

## === 信号 ==================================================================

## 悬停目标变化（[param node_id] = -1 表示无悬停）。交互层如需响应悬停可订阅；
## 悬停视觉本身由本类绘制（单一来源）。
signal hover_changed(node_id: int)

## === 渲染输入（stub 数据——003 接真实源）=================================

## 邻接表 {node_id: [child_id, ...]}——ExplorationSystem.generate_map().graph 同构。
var graph: Dictionary = {}
## 节点详情 {node_id: {type, layer, idx, ...}}——同构 node_details。
var nodes: Dictionary = {}
## 已访问节点集合（Array——含到达节点）。
var visited: Array = []
## 当前节点 ID（金色边框 + 迷雾豁免）。
var current_node: int = -1
## 六态样式映射 {node_id: NodeState 枚举值}——[method set_states] 注入
## （S16-3；空字典走 legacy 分支）。
var states: Dictionary = {}
## 文字标签显隐——缩放联动（Viewport 在 50% 缩放时置 false——模式库「画布缩放平移」）。
var show_labels: bool = true
## 已揭示的最大层索引（-1 = 全部揭示）。逐层展开浮现动画（0.8s）由宿主 tween
## 驱动本字段逐步递增——超过该层的节点不绘制（AC-1 逐层浮现；动画时序归手动证据）。
var reveal_max_layer: int = -1
## 当前悬停节点 ID（-1 = 无）——[method hit_test_node] 命中检测维护，
## tooltip 与悬停放大据此绘制（AC-10；0.3s 浮出时序归手动证据）。[br]
## [b]悬停放大[/b]（AC-5）：悬停视觉单一来源在本类（ADR-0031 §4 鼠标悬停态）。
var hovered_node: int = -1
## 键盘焦点节点 ID（-1 = 无）——[method set_focused_node] 注入（A3 键盘路径）。[br]
## 焦点环为松石青 2px 外环（ADR-0031 §4 双焦点双视觉）。鼠标悬停优先显示。
var focused_node: int = -1
## 当前地图 ID——地形插画（[NodeGraphTerrain]）与节点地名（[NodeGraphLandmark]）
## 都按它取内容。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：这是渲染输入快照的一个字段（探索系统在
## [code]enter_map[/code] 里写进 [code]map_data[/code]），不是本类自己维护的游戏状态。
var map_id: StringName = &""
## 地名覆盖（[code]{node_id: 地名}[/code]）——测试与截图脚本注入确定性文案用；
## 空字典时走 [code]ExplorationPlaceCatalog.place_for[/code]（正常路径）。
var place_overrides: Dictionary = {}
## 地图配置快照（[method set_ap_cost_hint] 注入）——[method hover_text_for] 的
## 行动力消耗短语按它算。空字典 = 按 GDD 默认开销（与配置缺失时的扣费行为一致）。
var _map_config: Dictionary = {}

## === 内部 ===================================================================

## 节点中心坐标缓存——setup 时布局计算（零轮询：不每帧重算）。
var _positions: Dictionary = {}
## 内容包围盒——Viewport 整图适配基准（复位/初始 fit 用）。
var _content_rect: Rect2 = Rect2()
## 地面层（地形 + 迷雾挖孔缓存）——持有实例以跨帧复用挖孔结果（见该模块文档）。
var _ground: RefCounted = GroundLayer.new()
