extends RefCounted
## ExplorationDifficultyConfigs —— 地图难度档位表（[b]纯数据[/b]）。[br]
##
## [b]为什么单独一份[/b]：[code]exploration_system_helpers.gd[/code] 抵到单文件
## 300 行软上限（.claude/docs/coding-standards.md）。本表是「难度 → 生成参数」的
## 一张常量表——它不读任何状态、不调任何方法，与同层的助手函数没有交集，是这一层里
## 最容易整体搬走的一块。[br]
##
## [br][b]访问方式不变[/b]：[code]es.get("DIFFICULTY_CONFIGS")[/code] 照旧可用——
## 助手层用 [code]const DIFFICULTY_CONFIGS: Array = TABLE[/code] 转发，继承链上仍能
## 解析。测试与子模块（[code]exploration_dag_builder.gd[/code]）的读法一个字没改。[br]
##
## 来源: ADR-0014 §决策 1/2/4/5、GDD exploration-system.md §2-3、
## 本轮「炼丹台/炼器台节点」任务。


## 默认地图难度配置表——按 MapDifficulty 枚举索引。[br]
## [br][code]enemy_realm[/code] 是节点敌人强度的定档基准（GDD「回旧地图」§7：
## 敌人强度按地图本身境界设定，不随玩家境界上涨）。缺键的地图配置会回退玩家
## 境界并警告一次——生产配置由 [code]exploration_map_catalog.gd[/code] 提供，
## 本表只是难度档位的通用兜底。[br]
## [br][b]权重表两处同源[/b]：[code]exploration_map_catalog.gd[/code] 的
## [code]_difficulty_defaults[/code] 必须与本表一致；新增键会改变
## [code]_weighted_random[/code] 的 [code]total[/code] 从而重排所有种子的 DAG
## 结果（确定性仍在，只是每张图长得不一样）。新增的炼丹台/炼器台/灵泉权重各 8
## ——与采集点（10）同一量级，「路上偶遇一座丹炉」是偶发事件而非每图必得。[br]
## [br][b]ap_cost 是遗留键[/b]：移动开销本轮起按两节点距离定价（见
## [code]exploration_ap_rules.gd[/code]），本键不再参与计算；保留只为旧地图表与
## 旧存档不报错。[code]action_spring_count[/code] 仍是活键（灵泉每图限次）。[br]
const TABLE: Array = [
	{  # LOW
		"layers": 4, "min_nodes": 2, "max_nodes": 3,
		"elite_count": 1, "shop_count": 1, "event_count": 2, "enemy_realm": 1,
		"ap_cost": 1, "action_spring_count": 1,
		"weights": {"combat": 40, "event": 30, "shop": 15, "rest": 10,
				"harvest": 10, "alchemy": 8, "forge": 8, "meditation": 6,
				"elite": 5, "action_spring": 8},
	},
	{  # MEDIUM
		"layers": 5, "min_nodes": 2, "max_nodes": 4,
		"elite_count": 2, "shop_count": 1, "event_count": 3, "enemy_realm": 2,
		"ap_cost": 1, "action_spring_count": 1,
		"weights": {"combat": 40, "event": 30, "shop": 15, "rest": 10,
				"harvest": 10, "alchemy": 8, "forge": 8, "meditation": 6,
				"elite": 5, "action_spring": 8},
	},
	{  # HIGH
		"layers": 5, "min_nodes": 3, "max_nodes": 4,
		"elite_count": 2, "shop_count": 2, "event_count": 3, "enemy_realm": 3,
		"ap_cost": 1, "action_spring_count": 1,
		"weights": {"combat": 40, "event": 30, "shop": 15, "rest": 10,
				"harvest": 10, "alchemy": 8, "forge": 8, "meditation": 6,
				"elite": 5, "action_spring": 8},
	},
	{  # VERY_HIGH
		"layers": 6, "min_nodes": 3, "max_nodes": 4,
		"elite_count": 3, "shop_count": 2, "event_count": 4, "enemy_realm": 4,
		"ap_cost": 1, "action_spring_count": 1,
		"weights": {"combat": 40, "event": 30, "shop": 15, "rest": 10,
				"harvest": 10, "alchemy": 8, "forge": 8, "meditation": 6,
				"elite": 5, "action_spring": 8},
	},
]
