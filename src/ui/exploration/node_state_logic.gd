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
## [br][b]stub 先行裁决[/b]（2026-10-26）：Feature 层 [code]can_move_to()[/code]
## 当前三态混叠返回 false，本分类器先行按 GDD §2 规则区分六态；Feature 层
## 补齐后本文件不动（渲染路径不变），仅替换信号源与数据源。[br]
## [br][b]AP=0 豁免[/b]：Boss/传送/灵泉三类型行动力不足时仍可达（与
## [code]ExplorationSystem.AP_EXEMPT_TYPES[/code] 对齐）。
##
## 来源: story-003-node-graph-data-states.md、ADR-0031 §2、
## design/gdd/exploration-ui-system.md §2 界面规则表、ADR-0014 §关键接口。

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


## 六态分类器（AC-1/AC-2/AC-5 自动化断言目标）。[br]
## [br][b]判定顺序[/b]（短路）：迷雾 → 当前 → 已访问 → 可达（含行动力）→ 不可达。[br]
## [br][b]迷雾揭示集合[/b]（[method is_revealed]）：已访问 ∪ 当前 ∪ 当前前向邻接
## ∪ 已访问节点的前向邻接——走过的分支不重新迷雾（AC-6 迷雾消散语义）。[br]
## [br][b]参数[/b]: [param node_id] 目标节点；[param graph] 邻接表
## [code]{node_id: [child_ids]}[/code]；[param visited] 已访问节点 ID 数组；
## [param current_node] 当前节点 ID；[param ap_remaining] 剩余行动力；
## [param node_details] 节点详情 [code]{node_id: {type, ...}}[/code]。[br]
## [br][b]返回[/b]: [enum NodeState] 六态枚举值。
static func classify_node_state(node_id: int, graph: Dictionary, visited: Array,
		current_node: int, ap_remaining: int, node_details: Dictionary) -> int:
	if not is_revealed(node_id, graph, visited, current_node):
		return NodeState.FOGGED
	if node_id == current_node:
		return NodeState.CURRENT
	if visited.has(node_id):
		return NodeState.VISITED
	if _is_reachable(node_id, graph, current_node):
		var type_id: int = int(node_details.get(node_id, {}).get("type", 1))
		if ap_remaining < 1 and not AP_EXEMPT_TYPES.has(type_id):
			return NodeState.AP_INSUFFICIENT
		return NodeState.REACHABLE
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
##   [code]fogged[/code]: bool——迷雾（不显示类型）。
static func node_state_style(state: int) -> Dictionary:
	match state:
		NodeState.CURRENT:
			return {"border": Color("#FFD700"), "border_is_type": false,
					"marker": "player", "dim": false, "glow": "gold",
					"slash": false, "fogged": false}
		NodeState.REACHABLE:
			return {"border": Color.TRANSPARENT, "border_is_type": true,
					"marker": "", "dim": false, "glow": "pulse_blue",
					"slash": false, "fogged": false}
		NodeState.VISITED:
			return {"border": Color("#44CC66"), "border_is_type": false,
					"marker": "check", "dim": true, "glow": "",
					"slash": false, "fogged": false}
		NodeState.UNREACHABLE:
			return {"border": Color(0.45, 0.45, 0.48), "border_is_type": false,
					"marker": "lock", "dim": false, "glow": "",
					"slash": false, "fogged": false}
		NodeState.AP_INSUFFICIENT:
			return {"border": Color(0.45, 0.45, 0.48), "border_is_type": false,
					"marker": "", "dim": false, "glow": "",
					"slash": true, "fogged": false}
		NodeState.FOGGED:
			return {"border": Color.TRANSPARENT, "border_is_type": false,
					"marker": "question", "dim": false, "glow": "",
					"slash": false, "fogged": true}
	return {"border": Color.TRANSPARENT, "border_is_type": false,
			"marker": "", "dim": false, "glow": "", "slash": false, "fogged": false}


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
