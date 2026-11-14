extends "res://src/feature/exploration/exploration_system_base.gd"
## ExplorationSystemHelpers —— 探索系统 Autoload 继承链的[b]常量与助手层[/b]：
## 难度权重表 / 经济常量 / 子模块句柄与惰性获取 / 通用助手。[br]
## [br][b]为什么再拆一层[/b]：加入炼丹台/炼器台两个节点类型后，[code]NodeType[/code]
## 枚举与权重表注释一并变长，底层那份文件抵到 300 行软上限
## （.claude/docs/coding-standards.md）。本层与 [code]exploration_system_base.gd[/code]
## 的分工是「状态 ↔ 查表与助手」，仍是[b]机械拆分、零行为改动[/b]——常量名、方法名、
## 参数名逐字保留（测试与子模块走 [code]es.get("DIFFICULTY_CONFIGS")[/code] /
## [code]_parent.call("_get_map_config")[/code]，继承链上照旧解析）。[br]
## [br]来源: ADR-0014 §决策 1/2/4/5、GDD exploration-system.md §2-3、
## 本轮「炼丹台/炼器台节点」任务。


# === 常量（留在继承链上——测试与子模块通过 es.get / _parent.get 访问）==========

## 默认地图难度配置表——按 MapDifficulty 枚举索引。[br]
## [br][code]enemy_realm[/code] 是节点敌人强度的定档基准（GDD「回旧地图」§7：
## 敌人强度按地图本身境界设定，不随玩家境界上涨）。缺键的地图配置会回退玩家
## 境界并警告一次——生产配置由 [code]exploration_map_catalog.gd[/code] 提供，
## 本表只是难度档位的通用兜底。[br]
## [br][b]权重表两处同源[/b]：[code]exploration_map_catalog.gd[/code] 的
## [code]_difficulty_defaults[/code] 必须与本表一致；新增键会改变
## [code]_weighted_random[/code] 的 [code]total[/code] 从而重排所有种子的 DAG
## 结果（确定性仍在，只是每张图长得不一样）。[br]
## [br][b]alchemy / forge 为本轮新增[/b]：炼丹台与炼器台的权重各 8——与采集点
## （10）同一量级，「探索路上偶遇一座丹炉」是偶发事件而非每图必得。[br]
const DIFFICULTY_CONFIGS: Array = [
	{  # LOW
		"layers": 4, "min_nodes": 2, "max_nodes": 3,
		"elite_count": 1, "shop_count": 1, "event_count": 2, "enemy_realm": 1,
		"weights": {"combat": 40, "event": 30, "shop": 15, "rest": 10,
				"harvest": 10, "alchemy": 8, "forge": 8, "meditation": 6, "elite": 5},
	},
	{  # MEDIUM
		"layers": 5, "min_nodes": 2, "max_nodes": 4,
		"elite_count": 2, "shop_count": 1, "event_count": 3, "enemy_realm": 2,
		"weights": {"combat": 40, "event": 30, "shop": 15, "rest": 10,
				"harvest": 10, "alchemy": 8, "forge": 8, "meditation": 6, "elite": 5},
	},
	{  # HIGH
		"layers": 5, "min_nodes": 3, "max_nodes": 4,
		"elite_count": 2, "shop_count": 2, "event_count": 3, "enemy_realm": 3,
		"weights": {"combat": 40, "event": 30, "shop": 15, "rest": 10,
				"harvest": 10, "alchemy": 8, "forge": 8, "meditation": 6, "elite": 5},
	},
	{  # VERY_HIGH
		"layers": 6, "min_nodes": 3, "max_nodes": 4,
		"elite_count": 3, "shop_count": 2, "event_count": 4, "enemy_realm": 4,
		"weights": {"combat": 40, "event": 30, "shop": 15, "rest": 10,
				"harvest": 10, "alchemy": 8, "forge": 8, "meditation": 6, "elite": 5},
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

## 行动力泉结算子模块（GDD §节点类型一览——回复全部行动力）。
var _action_spring: RefCounted = null

## 传送子模块（目标层解锁判定 + 跨层跳转执行）。
var _teleport: RefCounted = null

## 地图选择列表载荷组装子模块（探明表 × GSM → 卡片条目）。
var _map_list: RefCounted = null

## 采集点结算子模块（GDD §资源表——材料入背包 + 已采状态持久化）。
var _harvest: RefCounted = null

## 炼丹台/炼器台结算子模块（GDD alchemy-crafting-system §1a/§2a——配方列表 + 炼制）。
var _craft: RefCounted = null

## 打坐/洞府结算子模块（境界突破——读既有境界配置表，成功率掷骰可注入）。
var _breakthrough: RefCounted = null

## 卡牌系统注入（测试用桩；null 时 [ExplorationCraft] 按 Autoload 查找）。
var craft_card_system: Node = null

## 突破随机源注入（测试用固定种子；null 时 [ExplorationBreakthrough] 自建随机实例）。
var breakthrough_rng: RandomNumberGenerator = null


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


## 获取采集点结算子模块实例（材料入背包 + 已采状态持久化）。
func _get_harvest() -> RefCounted:
	if _harvest == null:
		_harvest = preload("res://src/feature/exploration/exploration_harvest.gd").new(self)
	return _harvest


## 获取炼丹台/炼器台结算子模块实例（配方列表 + 炼制 + 卡牌入库）。[br]
## [br][b]卡牌系统注入[/b]：优先 [member craft_card_system]（单测用桩），
## 否则由子模块按 Autoload 查找。
func _get_craft() -> RefCounted:
	if _craft == null:
		_craft = preload("res://src/feature/exploration/exploration_craft.gd").new(self)
		if craft_card_system != null:
			_craft.set("card_system", craft_card_system)
	return _craft


## 获取打坐/洞府突破结算子模块实例（境界突破——读既有境界配置表）。[br]
## [br][b]随机源注入[/b]：优先 [member breakthrough_rng]（测试用固定种子——
## 同种子同结果），否则由子模块自建随机实例。
func _get_breakthrough() -> RefCounted:
	if _breakthrough == null:
		_breakthrough = preload(
				"res://src/feature/exploration/exploration_breakthrough.gd").new(self)
		if breakthrough_rng != null:
			_breakthrough.set("rng", breakthrough_rng)
	return _breakthrough


## 获取行动力泉结算子模块实例（GDD §节点类型一览——回复全部行动力）。
func _get_action_spring() -> RefCounted:
	if _action_spring == null:
		_action_spring = preload(
				"res://src/feature/exploration/exploration_action_spring.gd").new(self)
	return _action_spring


## 获取传送子模块实例（目标层解锁判定 + 跨层跳转执行）。
func _get_teleport() -> RefCounted:
	if _teleport == null:
		_teleport = preload("res://src/feature/exploration/exploration_teleport.gd").new(self)
	return _teleport


## 获取地图列表组装子模块实例（探明表 × GSM → 卡片条目）。
func _get_map_list() -> RefCounted:
	if _map_list == null:
		_map_list = preload("res://src/feature/exploration/exploration_map_list.gd").new(self)
	return _map_list
