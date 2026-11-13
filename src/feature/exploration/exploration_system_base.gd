extends Node
## ExplorationSystemBase —— 探索系统 Autoload 的[b]基础设施层[/b]：枚举 / 常量 /
## 状态 / 注入点 / 子模块句柄 / 通用助手。[br]
## [br][b]为什么拆[/b]：[code]exploration_system.gd[/code] 686 行，超 300 行软上限
## （.claude/docs/coding-standards.md）。本层是[b]机械拆分[/b]的产物——成员的
## 名字、类型、默认值与拆分前逐字一致，只是换了落脚的脚本；行为零改动。[br]
## [br][b]为什么用继承链而不是 RefCounted 子模块[/b]：测试与子模块大量通过
## [code]es.get("DIFFICULTY_CONFIGS")[/code] / [code]es.set("_dag_ready", true)[/code] /
## [code]_parent.call("_get_map_config")[/code] / [code]_parent.NodeType.SHOP[/code]
## 访问这些成员。实测 [method Object.get] / [method Object.set] /
## [method Object.call] 与 [code]_parent.NodeType[/code] 都[b]沿继承链解析[/b]，
## 而 RefCounted 子模块做不到——那样得给每个成员补一个转发器，那才是真改行为面。
## 继承是 GDScript 里唯一能保持「成员名与访问路径不变」的拆法。[br]
## [br][b]层次[/b]（各守 300 行内）：[br]
##   1. 本文件——基础设施（枚举 / 常量 / 状态 / 注入点 / 助手）；[br]
##   2. [code]exploration_system_ops.gd[/code]——对外契约面（Cat 2b 信号 /
##      子模块转发 / 只读查询 / DAG 缓存生命周期 / 测试桩）；[br]
##   3. [code]exploration_system.gd[/code]——编排面（地图生成与进入、节点导航与
##      交互分发）——也是 project.godot 注册的 Autoload 脚本。[br]
## [br][b]本层不声明 [code]_ready[/code][/b]：Godot 只调最派生类的 [code]_ready[/code]
## （实测父类 [code]_ready[/code] 不会自动链式执行），故生命周期钩子统一放在链尾，
## 不存在「父子各写一半」的隐患。[br]
## [br]来源: ADR-0014 §决策 1 状态分层模型 / §决策 2 程序化 DAG 生成 / §决策 3 信号表、
## GDD exploration-system.md §2-3、本轮「exploration_system.gd 拆到 300 行以内」任务。


# === 枚举 ========================================================================

## 节点类型枚举——DAG 节点的类型标识。
enum NodeType {
	ENTRY = 0,         ## 入口——第 0 层固定
	COMBAT = 1,        ## 普通战斗
	ELITE = 2,         ## 精英战斗
	BOSS = 3,          ## Boss——末层固定
	EVENT = 4,         ## 事件
	SHOP = 5,          ## 商店
	TELEPORT = 6,      ## 传送——不消耗行动力
	ACTION_SPRING = 7, ## 行动力泉——回复全部行动力
	REST = 8,          ## 回复点——全体回复 50% 已损失 HP
	TRIBULATION = 9,   ## 渡劫台——修为已满时触发渡劫
}

## 地图难度枚举。
enum MapDifficulty {
	LOW = 0,       ## 低——4 层，2-3 节点/层
	MEDIUM = 1,    ## 中——5 层，2-4 节点/层
	HIGH = 2,      ## 高——5 层，3-4 节点/层
	VERY_HIGH = 3, ## 极高——6 层，3-4 节点/层
}

## 探索结束原因枚举。
enum EndReason {
	BOSS_DEFEATED,  ## Boss 击败——通关奖励结算
	BATTLE_LOST,    ## 战斗失败——修为保留 50%
	AP_DEPLETED,    ## 行动力耗尽——全额保留
	PLAYER_QUIT,    ## 玩家主动退出——全额保留
}


# === 状态与注入点 ================================================================

## DAG 邻接表——{node_id: [child_ids]}。
var _node_graph: Dictionary = {}

## 节点详情——{node_id: {type, layer, idx, ...}}。
var _node_details: Dictionary = {}

## 可达性缓存——{node_id: bool}。
var _reachable_cache: Dictionary = {}

## 当前地图配置快照。
var _map_config: Dictionary = {}

## DAG 缓存就绪标志——_ready() 末尾设为 true，公共方法入口守卫（ADR-0014 R7）。
var _dag_ready: bool = false

## 独立 RNG 实例——确定性 DAG 生成。
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

## 可注入回调——获取地图配置（桩阶段返回默认配置）。
var get_map_config_cb: Callable = Callable()

## 可注入回调——生成敌人阵容（桩阶段返回空 Array）。
var generate_enemy_roster_cb: Callable = Callable()

## 可注入回调——获取事件池（桩阶段返回空 Array）。
var get_event_pool_cb: Callable = Callable()

## 可注入回调——生成商店库存（桩阶段返回空 Dictionary）。
var generate_shop_inventory_cb: Callable = Callable()

## 可注入回调——按模板 ID 查 EnemyTemplate（[code]func(template_id) -> Resource[/code]）。[br]
## [b]用途[/b]：DAG 生成时按 [code]reward_config[/code] 聚合节点掉落；空 = 走
## Autoload AISystem 的 [code]get_template[/code]（单测可注入桩，不依赖场景树）。
var enemy_template_lookup_cb: Callable = Callable()

## 可注入回调——获取 RNG seed（桩阶段返回 42）。
var get_seed_cb: Callable = Callable()


# === 常量（留在继承链上——测试与子模块通过 es.get / _parent.get 访问）==========

## 默认地图难度配置表——按 MapDifficulty 枚举索引。[br]
## [br][code]enemy_realm[/code] 是节点敌人强度的定档基准（GDD「回旧地图」§7：
## 敌人强度按地图本身境界设定，不随玩家境界上涨）。缺键的地图配置会回退玩家
## 境界并警告一次——生产配置由 [code]exploration_map_catalog.gd[/code] 提供，
## 本表只是难度档位的通用兜底（境界取难度档位的默认值 1~4）。[br]
const DIFFICULTY_CONFIGS: Array = [
	{  # LOW
		"layers": 4, "min_nodes": 2, "max_nodes": 3,
		"elite_count": 1, "shop_count": 1, "event_count": 2, "enemy_realm": 1,
		"weights": {"combat": 40, "event": 30, "shop": 15, "rest": 10, "elite": 5},
	},
	{  # MEDIUM
		"layers": 5, "min_nodes": 2, "max_nodes": 4,
		"elite_count": 2, "shop_count": 1, "event_count": 3, "enemy_realm": 2,
		"weights": {"combat": 40, "event": 30, "shop": 15, "rest": 10, "elite": 5},
	},
	{  # HIGH
		"layers": 5, "min_nodes": 3, "max_nodes": 4,
		"elite_count": 2, "shop_count": 2, "event_count": 3, "enemy_realm": 3,
		"weights": {"combat": 40, "event": 30, "shop": 15, "rest": 10, "elite": 5},
	},
	{  # VERY_HIGH
		"layers": 6, "min_nodes": 3, "max_nodes": 4,
		"elite_count": 3, "shop_count": 2, "event_count": 4, "enemy_realm": 4,
		"weights": {"combat": 40, "event": 30, "shop": 15, "rest": 10, "elite": 5},
	},
]

## 入口节点 ID——DAG 编码 [code]layer * 100 + idx[/code]，第 0 层 0 号。
const ENTRY_NODE_ID: int = 0

## AP=0 豁免节点类型集合——不消耗行动力且行动力不足时仍可移动。
const AP_EXEMPT_TYPES: Array = [NodeType.TELEPORT, NodeType.ACTION_SPRING, NodeType.BOSS]

## 永久免费地图列表——每个境界 1 张，重入始终免费（GDD §1 经济安全阀）。
const PERMANENT_FREE_MAPS: Dictionary = {
	&"qing_yun_jian_zong": 1,   # 青云剑宗（炼气）
	&"sui_xing_wai_huan": 2,    # 碎星外环（筑基）
	&"xi_yu_gu_lin": 3,         # 西域古林（金丹）
	&"mu_lan_cao_yuan": 4,      # 慕兰草原（元婴）
	&"gui_xu_fu_yun_lu": 5,     # 归墟·浮云陆（化神）
}

## 重入费用基价表——按 MapDifficulty 枚举索引（GDD §公式 10）。
const REENTRY_BASE_COSTS: Array = [30, 60, 100, 150]  # LOW/MEDIUM/HIGH/VERY_HIGH

## 通关奖励基价表——按 MapDifficulty 枚举索引（GDD §公式 5）。
const CLEAR_REWARDS: Array = [
	{"ling_shi": 50,  "cultivation": 50},   # LOW
	{"ling_shi": 100, "cultivation": 80},   # MEDIUM
	{"ling_shi": 200, "cultivation": 120},  # HIGH
	{"ling_shi": 300, "cultivation": 150},  # VERY_HIGH
]


# === 子模块实例 ===================================================================

## DAG 生成器子模块。
var _dag_builder: RefCounted = null

## 经济计算子模块。
var _economy: RefCounted = null

## 结算刷新子模块（Sprint 12 Story 011 拆分）。
var _map_flush: RefCounted = null

## 回复点结算子模块（GDD §公式 7——全队回复 50% 已损失 HP）。
var _rest: RefCounted = null


# === 通用助手 ====================================================================

## 获取 GSM 引用——通过 SceneTree Autoload。[br]
## [br][b]返回[/b]: GSM 节点或 null（未注册时）。[br]
## [br]来源: ADR-0014 §决策 1 ExplorationSystem 作为 Autoload。
func _get_gsm() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/GameStateManager")


## 获取地图配置——优先注入回调，回退到难度配置表。
func _get_map_config(map_id: StringName, player_realm: int) -> Dictionary:
	if get_map_config_cb.is_valid():
		var cfg = get_map_config_cb.call(map_id, player_realm)
		if cfg is Dictionary and not cfg.is_empty():
			return cfg
	# 回退：默认中难度配置
	var difficulty: int = int(player_realm) - 1
	if difficulty < 0 or difficulty >= DIFFICULTY_CONFIGS.size():
		difficulty = 1  # MEDIUM
	return DIFFICULTY_CONFIGS[difficulty]


## 获取 RNG seed——优先注入回调，回退到默认 42。
func _get_seed() -> int:
	if get_seed_cb.is_valid():
		return int(get_seed_cb.call())
	return 42


## 获取当前地图的进入次数——从 GSM exploration.map_states 读取。[br]
## [br][param map_id] 地图 ID。[br]
## [br][b]返回[/b]: 进入次数（0 表示从未进入）。[br]
## [br]来源: ADR-0014 §决策 1 状态分层模型。
func _get_entry_count(map_id: StringName) -> int:
	var gsm: Node = _get_gsm()
	if gsm == null:
		return 0
	var map_states: Dictionary = gsm.exploration.get("map_states", {})
	var state: Dictionary = map_states.get(map_id, {})
	return int(state.get("entry_count", 0))


## 检查 from→to 是否邻接（graph[from] 包含 to）。
func _is_reachable(from_node: int, to_node: int) -> bool:
	if not _node_graph.has(from_node):
		return false
	return _node_graph[from_node].has(to_node)


## 获取节点类型——从 _node_details 读取。
func _get_node_type(node_id: int) -> int:
	var detail: Dictionary = _node_details.get(node_id, {})
	return int(detail.get("type", NodeType.COMBAT))


# === 子模块获取（惰性初始化）===================================================

## 获取 DAG 生成器子模块实例。
func _get_dag_builder() -> RefCounted:
	if _dag_builder == null:
		_dag_builder = preload("res://src/feature/exploration/exploration_dag_builder.gd").new(self)
	return _dag_builder


## 获取经济计算子模块实例。
func _get_economy() -> RefCounted:
	if _economy == null:
		_economy = preload("res://src/feature/exploration/exploration_economy.gd").new(self)
	return _economy


## 获取结算刷新子模块实例（Sprint 12 Story 011 拆分）。
func _get_map_flush() -> RefCounted:
	if _map_flush == null:
		_map_flush = preload("res://src/feature/exploration/exploration_map_flush.gd").new(self)
	return _map_flush


## 获取回复点结算子模块实例（GDD §公式 7——全队回复 50% 已损失 HP）。
func _get_rest() -> RefCounted:
	if _rest == null:
		_rest = preload("res://src/feature/exploration/exploration_rest.gd").new(self)
	return _rest
