class_name ExplorationBootstrap
extends RefCounted
## ExplorationBootstrap —— 探索系统的生产装配（地图配置 + 敌人池 + 商店货架注入）。[br]
## [br][b]为什么在启动层装配而不是系统内部硬编码[/b]：[code]ExplorationSystem[/code]
## 的回调字段（[code]get_map_config_cb[/code] / [code]generate_enemy_roster_cb[/code]
## / [code]enemy_template_lookup_cb[/code] / [code]generate_shop_inventory_cb[/code]）
## 是[b]注入点[/b]——单测用桩替换、生产由启动层接真实实现。把数据目录与敌人池直接
## 写进系统内部，等于让「哪些地图、哪些敌人」与「DAG 怎么长」耦合，也让单测无法替换。[br]
## [br][b]装配时机[/b]：主菜单 [code]_ready()[/code]（进程第一个场景，与
## [code]HudBootstrap[/code] 同源）——此时 [code]AISystem[/code] 已就绪
## （Autoload 顺序在它之前），模板注册表可查。[br]
## [br][b]幂等[/b]：重复调用只替换回调，不累积状态——返回主菜单会重新实例化
## MainMenu，装配会被再跑一次。[br]
## [br][b]失败语义（静默降级）[/b]：探索系统缺失 / 不支持回调字段时返回 false
## 且不抛错——调用方继续工作，只是真实 [code]enter_map[/code] 的名册仍为空
## （开战校验会给出可读失败，不静默兜底）。[br]
##
## 来源: ADR-0014 §决策 2/3、DEBT-EUI-006-3 / DEBT-EUI-006-5、hud Story 001
## （[code]hud_bootstrap.gd[/code] 同源先例）。

## 地图配置目录（每张地图的层数 / 敌人境界 / 敌人池）。
const CatalogScript := preload("res://src/feature/exploration/exploration_map_catalog.gd")
## 敌人池（按地图配置生成名册）。
const PoolScript := preload("res://src/feature/exploration/exploration_enemy_pool.gd")
## 商店货架默认生成器（价格按模板稀有度定档）。
const ShopInventoryScript := preload(
		"res://src/feature/exploration/exploration_shop_inventory.gd")


## 装配探索系统（幂等）。[br]
## [br][param p_exploration] ExplorationSystem 实例（生产为 Autoload；测试可注入）。[br]
## [param p_ai] AISystem 实例（模板查询；可空——空时敌人池运行时自找 Autoload）。[br]
## [br][b]返回[/b]：是否完成装配。[br]
static func mount(p_exploration: Node, p_ai: Node = null) -> bool:
	if p_exploration == null:
		return false
	if not _has_property(p_exploration, &"get_map_config_cb"):
		push_warning("ExplorationBootstrap: 探索系统缺少回调字段，跳过装配")
		return false

	var pool: RefCounted = PoolScript.new(_lookup_of(p_ai))
	# 地图配置——登记表优先，未登记地图按难度档位兜底（含 enemy_realm）
	p_exploration.set(&"get_map_config_cb", CatalogScript.config_for)
	# 敌人名册——按地图配置的敌人池生成（预览字典形态）
	p_exploration.set(&"generate_enemy_roster_cb",
			func(p_map_id: StringName, p_player_realm: int, p_is_elite: bool) -> Array:
				return pool.call(&"make_roster", p_map_id, p_player_realm, p_is_elite,
						CatalogScript.config_for(p_map_id, p_player_realm)))
	# 模板查询——掉落聚合（EncounterFields.rewards）与名册共用同一注册表
	if _has_property(p_exploration, &"enemy_template_lookup_cb"):
		p_exploration.set(&"enemy_template_lookup_cb", _lookup_of(p_ai))
	# 商店货架——DAG 生成期按玩家境界生成（此前无生产注入点，商店节点恒空货架）
	if _has_property(p_exploration, &"generate_shop_inventory_cb"):
		p_exploration.set(&"generate_shop_inventory_cb",
				Callable(ShopInventoryScript, &"make_for_realm"))
	return true


## 模板查询闭包——AISystem 可用时绑定 [code]get_template[/code]，否则返回无效
## Callable（掉落聚合退化为只读名册条目自带 rewards，不臆造模板）。
static func _lookup_of(p_ai: Node) -> Callable:
	var ai: Node = p_ai
	if ai == null:
		ai = _autoload(&"AISystem")
	if ai != null and ai.has_method(&"get_template"):
		return Callable(ai, &"get_template")
	return Callable()


## 属性存在性判定——回调字段是普通成员变量，[method Object.get] 对缺失属性
## 返回 null 且会推 engine error，故先用属性列表判定。
static func _has_property(p_object: Object, p_name: StringName) -> bool:
	for prop: Dictionary in p_object.get_property_list():
		if StringName(str(prop.get("name", ""))) == p_name:
			return true
	return false


## Autoload 动态查找（测试环境缺 Autoload 时返回 null）。
static func _autoload(p_node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath(String(p_node_name)))
