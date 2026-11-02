class_name NodeGraphDataStub
## NodeGraphDataStub —— 节点图 stub 载荷数据源（exploration-ui Story S16-3）。
##
## [b]角色[/b]：承载节点图的临时 stub 载荷——探索系统 [code]map_generated[/code]
## 信号 / [code]get_node_detail()[/code] 单数 API / 六态查询均未实现（Feature 层
## 依赖缺口，story-003 Dependencies 已裁决「stub 先行」）。[br]
## [br][b]生命周期[/b]：Feature 层补齐后删除本文件与 [method NodeGraphScreen] 的
## stub 信号发射器——stub 数据与 UI 逻辑分离，删除不牵连 UI。[br]
## [br][b]契约[/b]：节点详情字段与 story-003 stub 契约一致——Feature 层补齐时
## 必须沿用同一契约：
##   [code]type[/code]（NodeType 枚举值）、[code]layer[/code]、[code]idx[/code]、
##   [code]label[/code]、[code]description[/code]（悬停简短描述）、
##   [code]enemy_detail[/code]（战斗类敌人构成）、[code]tribulation_ready[/code]
##   （渡劫台修为是否圆满 bool）。[br]
## [br][b]覆盖[/b]：10 种节点类型 + 六态 + 渡劫台未圆满 + 传送按普通节点渲染
## （无交互）——AC-1/AC-8 自动化断言与 AC-3 手动走查的完整样本。
##
## 来源: ADR-0014 §关键接口 get_node_detail 契约、
## story-003-node-graph-data-states.md stub 契约、
## design/gdd/exploration-ui-system.md §2 界面规则表。

## 入口节点 ID（DAG 编码 layer*100+idx——0 层 0 号）。
const ENTRY_NODE_ID: int = 0


## 返回 stub 节点详情——{node_id: {type, layer, idx, label, description,
## enemy_detail, tribulation_ready}}。覆盖 10 类型 + 渡劫台未圆满样本。
static func stub_node_details() -> Dictionary:
	return {
		0: {"type": 0, "layer": 0, "idx": 0, "label": "入口",
				"description": "青云剑宗山门", "enemy_detail": "",
				"tribulation_ready": true},
		101: {"type": 1, "layer": 1, "idx": 0, "label": "战斗",
				"description": "山道巡守", "enemy_detail": "青云剑宗外门弟子×2",
				"tribulation_ready": true},
		102: {"type": 4, "layer": 1, "idx": 1, "label": "事件",
				"description": "山道偶遇", "enemy_detail": "",
				"tribulation_ready": true},
		201: {"type": 5, "layer": 2, "idx": 0, "label": "商店",
				"description": "坊市", "enemy_detail": "",
				"tribulation_ready": true},
		202: {"type": 1, "layer": 2, "idx": 1, "label": "战斗",
				"description": "竹林遭遇", "enemy_detail": "竹林剑客×1",
				"tribulation_ready": true},
		203: {"type": 7, "layer": 2, "idx": 2, "label": "灵泉",
				"description": "回复全部行动力", "enemy_detail": "",
				"tribulation_ready": true},
		301: {"type": 2, "layer": 3, "idx": 0, "label": "精英",
				"description": "精英守卫", "enemy_detail": "内门精英×1",
				"tribulation_ready": true},
		302: {"type": 4, "layer": 3, "idx": 1, "label": "事件",
				"description": "古碑残刻", "enemy_detail": "",
				"tribulation_ready": true},
		303: {"type": 8, "layer": 3, "idx": 2, "label": "回复点",
				"description": "歇脚处——全队回复50%已损失HP", "enemy_detail": "",
				"tribulation_ready": true},
		401: {"type": 9, "layer": 4, "idx": 0, "label": "渡劫台",
				"description": "雷云汇聚——修为尚未圆满", "enemy_detail": "",
				"tribulation_ready": false},
		402: {"type": 6, "layer": 4, "idx": 1, "label": "传送",
				"description": "传送阵（机制未闭合，仅渲染）", "enemy_detail": "",
				"tribulation_ready": true},
		500: {"type": 3, "layer": 5, "idx": 0, "label": "Boss",
				"description": "剑宗掌门", "enemy_detail": "苏剑鸣（炼气期）",
				"tribulation_ready": true},
	}


## 返回 stub 邻接表——{from_node: [child_ids]}。DAG 有分支汇聚（≥2 条路径到 Boss）。
static func stub_graph() -> Dictionary:
	return {
		0: [101, 102],
		101: [201, 202],
		102: [202, 203],
		201: [301],
		202: [301, 302],
		203: [302, 303],
		301: [401, 402],
		302: [402],
		303: [401, 402],
		401: [500],
		402: [500],
		500: [],
	}


## 返回 stub 渲染快照——初始状态（入口为当前节点、入口已访问、满行动力）。[br]
## [b]六态分布[/b]：入口=当前；101/102=可达；其余未揭示=迷雾；行动力不足与
## 已访问由测试用例注入快照变异构造（初始快照不含此二态）。
static func stub_snapshot() -> Dictionary:
	return {
		"graph": stub_graph(),
		"nodes": stub_node_details(),
		"visited": [ENTRY_NODE_ID] as Array,
		"current_node": ENTRY_NODE_ID,
		"ap_remaining": 3,
	}
