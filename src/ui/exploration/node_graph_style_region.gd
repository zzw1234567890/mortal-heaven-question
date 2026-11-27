extends RefCounted
## NodeGraphStyleRegion —— 节点图[b]地区[/b]这一块的视觉规格（常量 + 状态映射，纯数据/纯函数）。[br]
##
## [b]为什么单独成文件[/b]：[code]node_graph_style.gd[/code] 已贴 300 行软上限
## （coding-standards），而地区是本轮新增的一整层视觉；拆的判据是[b]内聚[/b]——
## 下面这组数只被「画一块地区」的那一处读（[code]node_graph_region_painter.gd[/code]），
## 与节点尺寸、图标、迷雾都不相交。[br]
##
## [br][b]★ 与六态的关系：只读不写 ★[/b]：地区外观由节点六态派生（见
## [method region_visual]），但它[b]不改[/b] [code]node_state_logic.gd[/code] 的
## 六态样式表——那张表被既有断言逐键钉死（[code]test_node_state_logic.gd[/code] /
## [code]test_walked_path_visual.gd[/code]），而地区的读法与节点本身不是同一件事：
## 节点回答「这一格是什么」，地区回答「这一片山域跟我什么关系」。[br]
##
## [br][b]为什么状态映射要单独一张表**[/b]：地区是[b]面[/b]，节点是[b]点[/b]——
## 面的视觉轴只有三条（底渍浓淡 / 边的粗细虚实 / 有没有朱红印记），而节点有六条
## （边框色/标记/底衬/暗纱/发光/斜线）。把同一份六态折进三条轴里需要有取舍，
## 取舍的理由逐条写在 [method region_visual] 的注记里。[br]
##
## [br]来源: 本轮任务书任务一（地区生成）/ 任务二（地区的画法）、
## design/gdd/exploration-ui-system.md §2 界面规则表、ADR-0031 §5。

## === 尺寸与边距 ============================================================

## 地区边界超出内容包围盒的外扩量（px）。[br]
## [br][b]为什么要外扩[/b]：分区是在一个矩形里切的，矩形多大决定「地图铺到哪」。
## 用内容包围盒本身会让最外圈的节点贴着地区边缘、像被框住；外扩一圈之后，地区的
## 边界落在画布上而不是节点上，「一片山域」才读得出来。[br]
## [br][b]为什么是 260[/b]：实测内容图约 1073×700 局部像素；外扩后分区矩形约
## 1593×1220，铺满 1920×1080 视口的自动适配视野（缩放约 0.9）——玩家即便不复位
## 视角也看不见「地区之外」的空白。[br]
## [br][b]为什么不做成「视口矩形」[/b]：那会让分区随缩放平移[b]每帧重算[/b]，
## 缓存失效、悬停归属漂移，而地区要的是「地图上的固定疆域」。
const BOUNDS_GROW: float = 260.0

## === 底渍（第一层：极淡墨色）===============================================

## 地区底渍浓度（极淡——能看出是一块块地，但不花）。[br]
## [br][b]为什么必须这么淡[/b]：底下是地图插画，底渍是[b]叠在插画之上[/b]的。
## 浓度到 0.2 以上就会把插画的花纹糊掉，「背景不要虚化」这条验收同时失效。[br]
## [br][b]为什么不用「相邻地区不同色相」（要求的冷/暖微差）**：色相微差在 0.1 的
## 浓度下几乎读不出来，而对比度会随地形底色漂移（浅色地形上偏黄、深色地形上偏蓝）。
## 本实现改用[b]浓度微差 + 温度微差[/b]两条：浓度差 0.02（可量化、可断言），温度差
## 由一个按节点 ID 奇偶的固定偏移给出（同 0.03 量级，肉眼只在相邻两块之间才分辨得出）。
const WASH_ALPHA_MIN: float = 0.08
## 地区底渍浓度的另一档（相邻地区交替使用——见 [constant WASH_ALPHA_MIN]）。
const WASH_ALPHA_MAX: float = 0.10
## 底渍色（墨色——美术圣经「墨骨丹青」的墨）。
const WASH_COLOR: Color = Color(0.09, 0.085, 0.075)
## 冷暖微差的幅度（叠加在底渍色上的 R/B 偏移；见 [constant WASH_ALPHA_MIN]）。
const WASH_TEMP_SHIFT: float = 0.03

## === 墨边（第二层）=========================================================

## 地区边线宽度（px）——细墨边。[br]
## [br][b]为什么是 2.5[/b]：节点边框的普通态也是 2.5（[constant NodeGraphStyle.BORDER_WIDTH]），
## 两者同宽会让「地区的边界」与「节点的边框」读成同一层；但地区边是[b]长线段[/b]，
## 视觉重量远大于同宽的短边，故同值反而读得出主次。[br]
## [br]任务书给的区间是 2–2.5px，取上限。
const EDGE_WIDTH: float = 1.6
## 地区边线色（墨——比底渍深、比节点边框柔）。[br]
## [br][b]为什么不纯黑[/b]：纯黑边会把插画割成一块块「填色图」，而这是一张舆图；
## 近黑暖调压得住底，又不跳出色系（同 [constant NodeGraphStyle.LABEL_OUTLINE_COLOR] 的取向）。
const EDGE_COLOR: Color = Color(0.055, 0.048, 0.038, 0.30)
## 边的「略抖」幅度（px）。[br]
## [br][b]为什么要抖[/b]：Voronoi 的边是直线段，围起来是一张几何网格——而舆图上的
## 疆界是手绘的。抖动量按顶点序做确定性偏移（同一个顶点永远偏同一个方向），幅度取
## [constant DASH_LENGTH] 量级之下，肉眼读成「手描的线」而不是「画歪了」。[br]
## [br][b]抖动必须确定性[/b]：地区块进缓存指纹，随机抖动会让「同输入不同输出」，
## 缓存在每帧失效（拖动画布时整张图闪）。偏移由顶点坐标的整数哈希给出——纯函数。
const EDGE_JITTER: float = 2.2
## 抖动采样的分段长度（px）——每段独立偏移，越长越像折线。
const EDGE_JITTER_SEGMENT: float = 34.0

## === 地名纸条（第三层）=====================================================

## 纸条（半透明宣纸）色——暖白，略透明。[br]
## [br][b]为什么单独描一层纸而不是直接写字[/b]：地名现在压在[b]地区底渍 + 地图插画[/b]
## 两层之上，底下亮度不均；纸条给文字一个稳定的对比底，「读得清」不再取决于脚下是
## 山还是水（同 [constant NodeGraphStyle.LABEL_OUTLINE_COLOR] 的注记，这里是它的
## 面版本）。
const PAPER_COLOR: Color = Color(0.93, 0.89, 0.79, 0.80)
## 纸条的 1px 墨边色与宽度。
const PAPER_EDGE_COLOR: Color = Color(0.10, 0.085, 0.065, 0.85)
const PAPER_EDGE_WIDTH: float = 1.0
## 纸条高度（px）与左右内边距（px）。
const PAPER_HEIGHT: float = 30.0
const PAPER_PADDING: float = 12.0
## 纸条文字字号（pt）与颜色。[br]
## [br][b]比节点下方那行地名（17pt）大 2pt[/b]：地区名是「这一片叫什么」，它是
## 玩家扫描地图时的第一个落点；而节点名回答「这一格去哪」。[br]
## [br][b]纸条底色浅、字色必须深**：这是与节点标签相反的一处——节点标签是浅字压深底，
## 纸条是深字压浅底（宣纸的读法）。深浅不能两处都调。
const PAPER_FONT_SIZE: int = 19
const PAPER_TEXT_COLOR: Color = Color(0.10, 0.085, 0.065)
## 纸条排版的[b]单字最小占宽[/b]（px）——字体测不出宽度时的兜底。[br]
## [br][b]为什么需要兜底[/b]：字体资产缺失时 [code]ThemeDB.fallback_font[/code] 对中日韩
## 字形可能量出 0 宽（缺字形不报错），纸条会缩成一条缝、文字溢出纸面。[br]
## [br][b]为什么是 14[/b]：19pt 的汉字实际占宽约 19px、拉丁字符约 9px，14 落在这两者
## 之间——按它估宽度时中文纸条略偏窄（真测值更大、以真测为准），而缺字形时仍能框住文字。
const PAPER_MIN_CHAR_WIDTH: float = 14.0
## 纸条相对地区中心的下移量（px）——纸条画在图标[b]下方[/b]，避免与图标重叠。
const PAPER_OFFSET_Y: float = 62.0

## === 六态映射（面的三条轴）=================================================

## 悬停/焦点高亮时的底渍提亮倍率（1.0 = 不提亮）。[br]
## [br][b]为什么用「提亮底渍 + 加粗边」而不是换一套色[/b]：老板的原话是「鼠标移到哪块
## 地区，那块地区整体亮起来」。换色会与六态配色打架（一块地区同时表达「我是商店」
## 与「鼠标在这」），而亮起来只动亮度这一根轴——六态的信息一个像素没丢。
const HIGHLIGHT_WASH_GAIN: float = 2.1
## 高亮时的边线宽（px）与外扩量（px）。
const HIGHLIGHT_EDGE_WIDTH: float = 4.0
const HIGHLIGHT_EDGE_GROW: float = 2.0
## 高亮时的边色（墨黑——比常态边更实）。
const HIGHLIGHT_EDGE_COLOR: Color = Color(0.02, 0.018, 0.014, 0.95)
## 高亮时图标额外放大倍率（6%）。[br]
## [br][b]为什么图标也要动[/b]：地区整块亮起来之后，如果图标纹丝不动，视线会落在
## 「亮面上」而不是「这块地代表的那一格」；6% 的放大足以把视线收回到图标上，
## 又小到不与可达态的悬停放大（110%）混淆。
const HIGHLIGHT_ICON_GAIN: float = 1.06

## 当前节点的朱红印记半径（px）——地区里的一枚小印章。[br]
## [br][b]为什么要它**：「当前在哪儿」在地图化的画面上必须一眼可见，而地区的底色
## 变化在 264px 宽的一片地上太弱；一枚朱红印是整张图上唯一的暖红点（六态配色表里
## 没有朱红），读法明确。位置在地区名纸条的右上角，不压图标。
const SEAL_RADIUS: float = 7.0
## 朱红印记色（印章红——美术圣经的朱砂）。
const SEAL_COLOR: Color = Color(0.72, 0.16, 0.12, 0.92)


## 六态 → 地区视觉（纯函数映射表——本文件是它的唯一出处）。[br]
## [br][b]返回[/b] 键约定：[br]
##   [code]wash_gain[/code]：float——底渍浓度相对基线的倍率（1.0 不变）；[br]
##   [code]edge_grow[/code]：float——边线宽倍率（1.0 不变）；[br]
##   [code]edge_dashed[/code]：bool——边线画成虚线（不可达）；[br]
##   [code]desaturate[/code]：float——底渍去饱和量（0..1）；[br]
##   [code]dim[/code]：float——整块压暗浓度（0..1，画在地区之上）；[br]
##   [code]seal[/code]：bool——画朱红印记（当前节点）。[br]
## [br][b]★ 三条轴的取舍（逐态理由）★[/b]：[br]
##   · [b]当前[/b]：底渍偏暖（1.25×）+ 边加粗（1.3×）+ 朱红印——三样一起，因为它在
##     地图上必须最先被看见；[br]
##   · [b]可达[/b]：底渍最亮（1.15×）+ 边最清晰（不加粗——加粗留给当前）——「能去」
##     与「我在」必须是两种读法，故可达不加印记；[br]
##   · [b]已访问[/b]：底渍去饱和 0.45、边暗下去（边宽不变）——走过的地方还在图上，
##     但不再抢视线；[br]
##   · [b]不可达[/b]：整块压暗 0.30 + 边虚线——「走不到」在面上读成「这块地不通」，
##     虚线是唯一不与「走过了」混淆的手段（走过用实线+去饱和）；[br]
##   · [b]行动力不足[/b]：整块压暗 0.22（比不可达浅）+ 边加粗成警示——两者的区别
##     在于「暂时够不着」与「根本不通」，压暗差 0.08 是这两档之间可读的下限；[br]
##   · [b]迷雾[/b]：整块压暗 0.55，且绘制顺序上会被迷雾遮罩[b]再压一层[/b]——迷雾
##     地区的底渍不给亮度信息（玩家还不知道那儿是什么）。[br]
## [br][b]不加新的枚举值**：六态是既有契约（[code]NodeStateLogic.NodeState[/code]），
## 本表只映射不改枚举（任务书硬约束）。
static func region_visual(p_state: int) -> Dictionary:
	match p_state:
		NodeStateLogicScript.NodeState.CURRENT:
			return {"wash_gain": 1.25, "edge_grow": 1.3, "edge_dashed": false,
					"desaturate": 0.0, "dim": 0.0, "seal": true}
		NodeStateLogicScript.NodeState.REACHABLE:
			return {"wash_gain": 1.15, "edge_grow": 1.0, "edge_dashed": false,
					"desaturate": 0.0, "dim": 0.0, "seal": false}
		NodeStateLogicScript.NodeState.VISITED:
			return {"wash_gain": 0.85, "edge_grow": 1.0, "edge_dashed": false,
					"desaturate": 0.45, "dim": 0.0, "seal": false}
		NodeStateLogicScript.NodeState.UNREACHABLE:
			return {"wash_gain": 0.9, "edge_grow": 1.0, "edge_dashed": true,
					"desaturate": 0.0, "dim": 0.30, "seal": false}
		NodeStateLogicScript.NodeState.AP_INSUFFICIENT:
			return {"wash_gain": 1.05, "edge_grow": 1.2, "edge_dashed": false,
					"desaturate": 0.0, "dim": 0.22, "seal": false}
		NodeStateLogicScript.NodeState.FOGGED:
			return {"wash_gain": 0.7, "edge_grow": 1.0, "edge_dashed": false,
					"desaturate": 0.0, "dim": 0.55, "seal": false}
	return {"wash_gain": 1.0, "edge_grow": 1.0, "edge_dashed": false,
			"desaturate": 0.0, "dim": 0.0, "seal": false}


## 六态样式查询（判定来源——[method region_visual] 与节点样式共用同一套枚举）。
const NodeStateLogicScript := preload("res://src/ui/exploration/node_state_logic.gd")
