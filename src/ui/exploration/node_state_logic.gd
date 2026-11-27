class_name NodeStateLogic
extends RefCounted
## NodeStateLogic —— 节点六态分类器 + 样式查询（exploration-ui Story S16-3）。
##
## [b]Logic 内核[/b]（BLOCKING 单测目标——ADR-0031 §2 零状态所有权）：
## 六态分类与样式查询提取为纯函数，GUT 直调可测。[br]
## [br][b]六态[/b]（AC-1/AC-5——不可达与行动力不足是不同状态，必须区分）：
## 当前/可达/已访问/不可达/行动力不足/迷雾。[br]
## [br][b]数据源[/b]：渲染快照（邻接表 graph / 已访问 visited / 当前节点
## current_node / 行动力 ap_remaining / 节点详情 node_details）——纯输入，
## 不缓存、不访问 Autoload、不写任何状态（ADR-0031 §2）。[br]
## [br][b]与 [code]can_move_to()[/code] 的关系[/b]：布尔接口三态混叠（可达 /
## 已访问 / AP 不足都返回 false），六态要分开画，分类器因此不能问它。系统侧现已
## 补上可判别结果 [code]ExplorationSystem.can_move_to_detail[/code]（[code]{ok,
## reason}[/code]），本文件改用[b]同一形状、同一词表[/b]：
## [method verdict_for] 产出同款 [code]{ok, reason}[/code]，
## [method state_from_verdict] 把它翻成六态——[method classify_node_state] 走这条
## 路。[br]
## [br][b]为什么不直连系统[/b]：headless 下不加载 Feature 层（同
## [constant AP_EXEMPT_TYPES] 的处境），且六态分类是渲染期的纯函数（ADR-0031 §2
## 零状态所有权）——直连会把渲染判定绑到 Autoload 生命周期上。两侧共用形状与
## 词表，由单测锁定同源（[code]test_can_move_to_verdict.gd[/code] 的跨层断言 +
## [code]test_move_verdict_ui_system_sync.gd[/code] 的真实地图对照）。[br]
## [br][b]AP=0 豁免[/b]：Boss/传送/灵泉三类型行动力不足时仍可达（与
## [code]ExplorationSystem.AP_EXEMPT_TYPES[/code] 对齐）。
##
## 来源: story-003-node-graph-data-states.md、ADR-0031 §2、
## design/gdd/exploration-ui-system.md §2 界面规则表、ADR-0014 §关键接口、
## 本轮任务书第 3 条（三态混叠）。

## 节点六态枚举——[method classify_node_state] 返回值。
enum NodeState {
	CURRENT = 0,        ## 当前节点——金色边框 + 玩家标记（人形）
	REACHABLE = 1,      ## 可达节点——彩色正常 + 白/蓝脉冲外发光
	VISITED = 2,        ## 已访问——绿色边框 + ✓ + 稍暗
	UNREACHABLE = 3,    ## 不可达——灰色 + 锁标记
	AP_INSUFFICIENT = 4, ## 行动力不足——灰色 + 红色斜线
	FOGGED = 5,         ## 迷雾（未暴露）——深色覆盖 + ❓ + 不显示类型
}

## AP=0 豁免节点类型（Boss/传送/灵泉）——行动力不足时仍可达。[br]
## 魔数值与 [code]ExplorationSystem.NodeType[/code] 枚举对齐（3=BOSS/6=TELEPORT/
## 7=ACTION_SPRING），与 [code]ExplorationSystem.AP_EXEMPT_TYPES[/code] 同源；
## Feature 层补齐后本文件不动，豁免集合单点锚定 Feature 层。
const AP_EXEMPT_TYPES: Array[int] = [3, 6, 7]

## 战斗类节点类型集合（悬停 tooltip 附敌人详情）——1=COMBAT/2=ELITE/3=BOSS。
const COMBAT_TYPES: Array[int] = [1, 2, 3]

## 已访问节点的底衬色（暗青绿——与边框的亮绿同族但压暗到不抢图标）。[br]
## [b]为什么不复用边框绿[/b]：那是描边的亮色，铺满整格会把节点图变成一片绿；
## 底衬的职责是「这格有主了」，不是「这格在发光」。

## 拒绝原因词表——[b]与 [code]ExplorationSystem.REASON_*[/code] 逐字同源的 UI 副本[/b]。[br]
## [br][b]为什么 UI 也要有一份[/b]：headless 下不加载 Feature 层（同
## [constant AP_EXEMPT_TYPES] 的处境），而 UI 侧的 toast 映射表
## （[code]NodeMoveInteractor.REASON_TEXTS[/code]）正是拿这些字符串当键——词表是
## 两侧共用的契约，副本由 [code]test_move_verdict_ui_system_sync.gd[/code] 锁定。[br]
## [br][b]前两条 UI 分类器产不出[/b]（纯函数不碰 GSM / DAG 缓存），但仍列在这里：
## 词表是一份契约，缺了就不成其为「同一套说法」。它们在
## [method state_from_verdict] 里有明确的归属（按不可达处理）。
const REASON_NOT_READY: String = "DAG 缓存未就绪"
const REASON_UNREACHABLE: String = "不可达"
const REASON_NO_GSM: String = "GSM 不可用"
const REASON_VISITED: String = "已访问"
const REASON_AP_SHORT: String = "行动力不足"

## 已访问节点的底衬色（暗青绿——与边框的亮绿同族但压暗到不抢图标）。[br]
## [b]为什么不复用边框绿[/b]：那是描边的亮色，铺满整格会把节点图变成一片绿；
## 底衬的职责是「这格有主了」，不是「这格在发光」。
const PLATE_VISITED: Color = Color(0.10, 0.24, 0.16, 0.85)
## 当前节点底衬色（暗金——与 [constant PLATE_VISITED] 同一条「压暗描边色」逻辑）。
const PLATE_CURRENT: Color = Color(0.28, 0.22, 0.06, 0.85)

## 六态「亮度档」——图标之上叠加的暗纱浓度（0 = 最亮，1 = 全黑）。[br]
## [br][b]为什么单独立一个键而不是复用 [code]dim[/code][/b]：[code]dim[/code] 是布尔，
## 只能表达「压暗 / 不压暗」两档，而六态里「与我有关」的三态（当前/可达/已访问）
## 本身还需要彼此拉开；一个连续档位让「亮度也是一层信息」这句话在数据里成立，
## 绘制侧直接取来当 alpha 用，不必再写 [code]if[/code] 分支。[br]
## [br][b]取值口径[/b]：当前/可达 = 0（全亮，玩家现在该看的就是这两格）；
## 已访问 = 0.35（走过——暗一档，与 [constant VISITED_DIM_ALPHA] 同值同源）；
## 不可达 = 0.55（灰下去，比已访问更暗：它连「走过」都不是）；
## 行动力不足 = 0.70（比不可达再暗一档——前面还压着一道红斜线）；
## 迷雾 = 0.85（几乎只有个灰底轮廓）。
const VEIL_CURRENT: float = 0.0
const VEIL_REACHABLE: float = 0.0
const VEIL_VISITED: float = 0.35
const VEIL_UNREACHABLE: float = 0.55
const VEIL_AP_INSUFFICIENT: float = 0.70
const VEIL_FOGGED: float = 0.85


## 六态分类器（AC-1/AC-2/AC-5 自动化断言目标）。[br]
## [br][b]判定顺序[/b]（短路）：迷雾 → 当前 → 已访问 → 依 [method verdict_for] 的结果
## 翻六态（见 [method state_from_verdict]）。[br]
## [br][b]迷雾揭示集合[/b]（[method is_revealed]）：已访问 ∪ 当前 ∪ 当前前向邻接
## ∪ 已访问节点的前向邻接——走过的分支不重新迷雾（AC-6 迷雾消散语义）。[br]
## [br][b]参数[/b]: [param node_id] 目标节点；[param graph] 邻接表
## [code]{node_id: [child_ids]}[/code]；[param visited] 已访问节点 ID 数组；
## [param current_node] 当前节点 ID；[param ap_remaining] 剩余行动力；
## [param node_details] 节点详情 [code]{node_id: {type, ...}}[/code]。[br]
## [br][b]返回[/b]: [enum NodeState] 六态枚举值。[br]
## [br][b]签名不变[/b]：五个调用点（[code]test_node_state_logic[/code] 单测 +
## 三个节点图集成测试 + 动画重算子模块）直接传六个参数，改成「收一个 verdict」会
## 连带改一圈调用方——本方法在内部问 [method verdict_for]，对外仍是同一份纯函数契约。
static func classify_node_state(node_id: int, graph: Dictionary, visited: Array,
		current_node: int, ap_remaining: int, node_details: Dictionary) -> int:
	return classify_with_verdict(node_id, graph, visited, current_node,
			verdict_for(current_node, node_id, graph, visited, ap_remaining, node_details))


## 六态分类器（外部判定版）——迷雾 / 当前 / 已访问仍由快照决定，[b]可达性那一格
## 用传入的 verdict[/b]。[br]
## [br][b]为什么单独一个入口[/b]：真实系统在场时（[code]NodeGraphRevealAnimator[/code]
## 注入 [code]system[/code]）可达性判定该由系统作答——它才算得出本图的
## [code]ap_cost[/code]，也可能有 UI 快照里没有的规则。本方法让「用谁的判定」与
## 「怎么翻六态」解耦：[method classify_node_state] 传自算的 verdict，真实渲染路径
## 传系统的 [code]can_move_to_detail[/code] 返回值。[br]
## [br][param verdict] [code]{ok, reason}[/code]——形状与词表见 [method verdict_for]。
static func classify_with_verdict(node_id: int, graph: Dictionary, visited: Array,
		current_node: int, verdict: Dictionary) -> int:
	if not is_revealed(node_id, graph, visited, current_node):
		return NodeState.FOGGED
	if node_id == current_node:
		return NodeState.CURRENT
	if visited.has(node_id):
		return NodeState.VISITED
	return state_from_verdict(verdict)


## 可判别版移动判定——[b]与 [code]ExplorationSystem.can_move_to_detail[/code] 同形状、
## 同词表[/b]的 UI 纯函数副本。[br]
## [br][b]为什么需要它[/b]：布尔把「这格不存在」与「走不起」压成同一个 [code]false[/code]，
## 而界面要画的是两种不同的东西（灰色锁标记 / 红色斜线）。分类器此前直接推导这两种
## 情况，与系统侧的判定规则是两份实现——系统改口径而 UI 没跟着改，只有玩家能发现。[br]
## [br][b]★ 本轮起判据与系统逐条对齐（只剩两条）★[/b]：目标存在 → 行动力足够。
## 邻接门槛与「已访问不可重入」两条本轮作废（全连通 + 距离定价），UI 不得再拿
## [param graph] / [param visited] 去挡移动——那会让「画成不可达」与「系统允许点」
## 分家，而这类分家只有玩家能发现。[br]
## [br][b]与系统的已知口径差[/b]（保留并记录）：本函数算不出本图的 [code]ap_distance_unit[/code]
## / [code]ap_move_max[/code]（渲染快照里没有地图配置），故它只看
## [param ap_remaining] 是否 ≥ 1。出厂配置下「隔一层」正是 1 点，两者一致；某张图把
## 单位距离调小、或玩家要跨很远时，UI 可能在 AP=1 时画成可达而点击被系统拒——[b]这一条
## 在拆分前就存在[/b]（原分类器同样只看 [code]< 1[/code]），此处记录而非新引入。
## 真实渲染路径已经把判定交给系统（[code]NodeGraphRevealAnimator[/code] 注入
## [code]verdict_provider[/code]），本函数是「系统不在场」时的兜底。[br]
## [br][b]参数[/b]：[param from_node] 出发节点（保留入参以便与系统签名同形——
## 距离定价下它本会影响消耗，而 UI 快照算不出距离，故此处未用）；
## [param graph] / [param visited] 同样保留签名，见上「不再参与判定」。
## [param to_node] 目标节点；[param ap_remaining] 剩余行动力；
## [param node_details] 节点详情。[br]
## [br][b]返回[/b]：[code]{ok: bool, reason: String}[/code]——[code]ok[/code] 为真时
## [code]reason[/code] 为空串，为假时取自 [constant REASON_NOT_READY] 一族。[br]
## [br][b]不改任何状态[/b]：纯函数（ADR-0031 §2 零状态所有权）。
static func verdict_for(from_node: int, to_node: int, graph: Dictionary, visited: Array,
		ap_remaining: int, node_details: Dictionary) -> Dictionary:
	if not node_details.has(to_node):
		return {"ok": false, "reason": REASON_UNREACHABLE}
	var type_id: int = int(node_details.get(to_node, {}).get("type", 1))
	if ap_remaining < 1 and not AP_EXEMPT_TYPES.has(type_id):
		return {"ok": false, "reason": REASON_AP_SHORT}
	return {"ok": true, "reason": ""}


## 可判别结果 → 六态（AC-5：不可达与行动力不足必须画得不一样）。[br]
## [br][b]映射[/b]：[code]ok[/code] → 可达；「行动力不足」→ 行动力不足；「已访问」→
## 已访问；其余（不可达 / DAG 未就绪 / GSM 不可用）→ 不可达。[br]
## [br][b]为什么后两条也归不可达[/b]：它们是「这一刻问不出答案」而不是第四种视觉
## 状态——渲染层没有对应的标记/样式，硬造一个只会多一种没人看得懂的图标。分类器
## 本身产不出这两条（纯函数不碰 DAG 缓存与 GSM），列在这里是为了让映射[b]穷尽[/b]
## 词表——外部拿系统返回值来问同一件事时不会落空。
static func state_from_verdict(verdict: Dictionary) -> int:
	if bool(verdict.get("ok", false)):
		return NodeState.REACHABLE
	match str(verdict.get("reason", "")):
		REASON_AP_SHORT:
			return NodeState.AP_INSUFFICIENT
		REASON_VISITED:
			return NodeState.VISITED
	return NodeState.UNREACHABLE


## 六态 → 视觉样式查询（AC-1 自动化断言目标——纯函数映射表数据驱动）。[br]
## [br][b]返回[/b]: Dictionary，键约定：[br]
##   [code]border[/code]: Color——边框色（[code]border_is_type=true[/code] 时由
##   节点类型色覆盖）；[br]
##   [code]border_is_type[/code]: bool——可达节点用类型主色作边框；[br]
##   [code]marker[/code]: String——[code]""[/code] / [code]"player"[/code] /
##   [code]"check"[/code] / [code]"lock"[/code] / [code]"question"[/code]；[br]
##   [code]dim[/code]: bool——已访问稍暗；[br]
##   [code]glow[/code]: String——[code]""[/code] / [code]"pulse_blue"[/code] /
##   [code]"gold"[/code]；[br]
##   [code]slash[/code]: bool——行动力不足红色斜线；[br]
##   [code]fogged[/code]: bool——迷雾（不显示类型）；[br]
##   [code]emphasis[/code]: bool——强调态（当前/可达/已访问）用更粗的描边；[br]
##   [code]plate[/code]: Color——节点底衬（不透明色块，画在图标之下）。[br]
## [br][b]为什么要有底衬[/b]：已访问此前只靠「绿色边框 + ✓ + 压暗」区分，而压暗是
## 透明度手段、边框只有 2px——节点图标本身有类型主色（战斗红/精英红/商店绿…），
## 走过与没走过在缩放到 50% 时几乎同色。底衬是一块与类型色无关的[b]实色[/b]，
## 灰度模式下也能读出「这格走过了」。[br]
## [br][b]透明 = 不画[/b]（可达/不可达/行动力不足三种）：它们的类型色边框本身
## 就是信息，压一层底衬只会把类型颜色糊掉。[br]
## [br][b]emphasis 为什么是布尔而不是线宽[/b]：线宽是视觉规格（住
## [code]node_graph_style.gd[/code]），这里是判定——给个「粗一档」的旗标，
## 由绘制侧取 [code]Style.EMPHASIS_BORDER_WIDTH[/code]，尺寸改动不必回来改本文件。[br]
## [br][b]veil 为什么与 plate 并存[/b]：plate 是「这格有主了」的实色块（只两态有），
## veil 是覆盖在图标之上的暗纱浓度（六态都有）。前者回答「走没走过」，
## 后者回答「该不该看它」——两个问题，两个键。四态（当前/可达/已访问/不可达）
## 一眼分得开靠的正是 veil 给的亮度差 + emphasis 给的描边粗细差 + glow 给的发光差。
static func node_state_style(state: int) -> Dictionary:
	match state:
		NodeState.CURRENT:
			return {"border": Color("#FFD700"), "border_is_type": false,
					"marker": "player", "dim": false, "glow": "gold",
					"slash": false, "fogged": false, "emphasis": true,
					"plate": PLATE_CURRENT, "veil": VEIL_CURRENT}
		NodeState.REACHABLE:
			return {"border": Color.TRANSPARENT, "border_is_type": true,
					"marker": "", "dim": false, "glow": "pulse_blue",
					"slash": false, "fogged": false, "emphasis": true,
					"plate": Color.TRANSPARENT, "veil": VEIL_REACHABLE}
		NodeState.VISITED:
			return {"border": Color("#5AE07A"), "border_is_type": false,
					"marker": "check", "dim": true, "glow": "",
					"slash": false, "fogged": false, "emphasis": true,
					"plate": PLATE_VISITED, "veil": VEIL_VISITED}
		NodeState.UNREACHABLE:
			return {"border": Color(0.58, 0.58, 0.62), "border_is_type": false,
					"marker": "lock", "dim": false, "glow": "",
					"slash": false, "fogged": false, "emphasis": false,
					"plate": Color.TRANSPARENT, "veil": VEIL_UNREACHABLE}
		NodeState.AP_INSUFFICIENT:
			return {"border": Color(0.58, 0.58, 0.62), "border_is_type": false,
					"marker": "", "dim": false, "glow": "",
					"slash": true, "fogged": false, "emphasis": false,
					"plate": Color.TRANSPARENT, "veil": VEIL_AP_INSUFFICIENT}
		NodeState.FOGGED:
			return {"border": Color.TRANSPARENT, "border_is_type": false,
					"marker": "question", "dim": false, "glow": "",
					"slash": false, "fogged": true, "emphasis": false,
					"plate": Color.TRANSPARENT, "veil": VEIL_FOGGED}
	return {"border": Color.TRANSPARENT, "border_is_type": false,
			"marker": "", "dim": false, "glow": "", "slash": false, "fogged": false,
			"emphasis": false, "plate": Color.TRANSPARENT, "veil": VEIL_FOGGED}


## 节点是否已揭示（迷雾判定）——纯函数。[br]
## [br][b]揭示集合[/b]：已访问 ∪ 当前 ∪ 当前前向邻接 ∪ 已访问节点的前向邻接。
static func is_revealed(node_id: int, graph: Dictionary, visited: Array,
		current_node: int) -> bool:
	if visited.has(node_id):
		return true
	if node_id == current_node:
		return true
	if _is_reachable(node_id, graph, current_node):
		return true
	for v: int in visited:
		if _is_reachable(node_id, graph, v):
			return true
	return false


## 渡劫台修为未满判定（AC-8——可进入但不可触发）。[br]
## [b]返回[/b]: type==渡劫台(9) 且 [code]tribulation_ready=false[/code] → true。
static func is_tribulation_not_ready(detail: Dictionary) -> bool:
	return int(detail.get("type", 1)) == 9 \
			and not bool(detail.get("tribulation_ready", true))


## 悬停 tooltip 文本构建（AC-10——数据源 [code]description[/code]/
## [code]enemy_detail[/code]）。[br]
## [br][b]迷雾节点[/b]：显示「?」不显示敌人构成（AC-2 Edge）。[br]
## [br][b]战斗类[/b]（战斗/精英/Boss）：名称 + 描述 + 敌人详情；其余仅名称 + 描述。
static func tooltip_text(detail: Dictionary, is_fogged: bool) -> String:
	if is_fogged:
		return "?"
	var label: String = str(detail.get("label", "未知"))
	var desc: String = str(detail.get("description", ""))
	var enemy: String = str(detail.get("enemy_detail", ""))
	var type_id: int = int(detail.get("type", 1))
	var text: String = "%s：%s" % [label, desc]
	if COMBAT_TYPES.has(type_id) and not enemy.is_empty():
		text += "（敌人：%s）" % enemy
	return text


## 前向邻接判定——[code]graph[from][/code] 是否包含 [param node_id]。
static func _is_reachable(node_id: int, graph: Dictionary, from_node: int) -> bool:
	return (graph.get(from_node, []) as Array).has(node_id)


## 一条连线是否「走过」——两端都已访问。[br]
## [br][b]为什么收在这一个纯函数里[/b]：渲染层此前直接写 [code]visited.has()[/code]
## 比较两遍，而六态分类（[method classify_node_state]）看的是同一份 visited——
## 两处各判一次「什么算走过」，就必然出现「节点已变绿、连着它的线还是虚线」的图。
## 判定只有一处，渲染层[method NodeGraphRenderer._is_edge_visited] 转发本方法。[br]
## [br][b]参数顺序[/b]（[param p_visited], [param p_from], [param p_to]）：
## 判定与方向无关（无向），两个端点谁先谁后结果相同——顺序只影响可读性。
static func edge_is_walked(p_visited: Array, p_from: int, p_to: int) -> bool:
	return p_visited.has(p_from) and p_visited.has(p_to)
