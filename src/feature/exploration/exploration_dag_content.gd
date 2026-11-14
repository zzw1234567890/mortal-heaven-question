## ExplorationDAGContent —— DAG 节点内容填充子模块（RefCounted）。
##
## 从 [code]exploration_dag_builder.gd[/code] 提取的「按节点类型填详情」逻辑：
## 战斗/精英的遭遇数据、事件池、商店货架、采集点材料载荷、各类节点的中文标签。[br]
## [br][b]为什么单独一处[/b]：骨架生成（层数/边连接/独立路径修复）与内容填充是
## 两件事——前者是纯图算法，后者依赖注入回调与外部表；且生成器脚本已贴 300 行
## 软上限（与 [code]exploration_dag_graph.gd[/code] 拆分同源理由）。[br]
## [br]来源: ADR-0014 §决策 2 / GDD exploration-system.md §2-3/§7。
extends RefCounted

## 遭遇数据契约（写入 / 读取的唯一口径——生成器与开战上下文共用）。
const Fields := preload("res://assets/enemies/encounter_fields.gd")
## 采集点材料载荷表（按地图 + 境界给产出——生成期写入节点详情）。
const HarvestTable := preload("res://src/feature/exploration/exploration_harvest_table.gd")

## 地图配置里敌人基准境界的键（缺键 = 旧配置，回退玩家境界并警告一次）。
const KEY_ENEMY_REALM: String = "enemy_realm"


## 父节点引用——ExplorationSystem Autoload 实例。
var _parent: Node = null

## 缺 [constant KEY_ENEMY_REALM] 的告警已发标志——每次生成只提醒一次，
## 避免每张图几十个战斗节点各刷一条（旧配置回退是过渡态，不是逐节点事件）。
var _warned_missing_enemy_realm: bool = false


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


## 填充全部节点的详情。[br]
## [br][param p_all_nodes] 全部节点 ID。[br]
## [param p_node_types] 节点 ID → [code]NodeType[/code] 枚举值。[br]
## [param p_map_id] 地图 ID（采集载荷按地图分档）。[br]
## [param p_player_realm] 玩家境界（配置衍生 + 名册生成用）。[br]
## [param p_config] 地图配置。[br]
## [br][b]返回[/b]：节点 ID → 详情字典（[code]type/layer/idx[/code] + 类型专属键）。
func fill(p_all_nodes: Array, p_node_types: Dictionary, p_map_id: StringName,
		p_player_realm: int, p_config: Dictionary) -> Dictionary:
	var details: Dictionary = {}
	for node_id in p_all_nodes:
		var layer: int = node_id / 100
		var idx: int = node_id % 100
		var ntype: int = int(p_node_types.get(node_id, _parent.NodeType.COMBAT))
		var detail: Dictionary = {
			"type": ntype,
			"layer": layer,
			"idx": idx,
		}
		_fill_one(detail, node_id, ntype, p_map_id, p_player_realm, p_config)
		details[node_id] = detail
	return details


## 按类型填一个节点的专属内容（[param p_detail] 就地补键）。
func _fill_one(p_detail: Dictionary, p_node_id: int, p_ntype: int,
		p_map_id: StringName, p_player_realm: int, p_config: Dictionary) -> void:
	match p_ntype:
		_parent.NodeType.ENTRY:
			p_detail["label"] = "入口"
		_parent.NodeType.BOSS:
			p_detail["label"] = "Boss"
		_parent.NodeType.COMBAT, _parent.NodeType.ELITE:
			_fill_encounter(p_detail, p_node_id, p_map_id, p_player_realm,
					p_ntype == _parent.NodeType.ELITE, p_config)
		_parent.NodeType.EVENT:
			# 不分配具体事件——仅记录 pool
			var event_cb: Callable = _parent.get("get_event_pool_cb")
			if event_cb.is_valid():
				p_detail["event_pool"] = event_cb.call(p_map_id, p_player_realm)
			else:
				p_detail["event_pool"] = []
		_parent.NodeType.SHOP:
			var shop_cb: Callable = _parent.get("generate_shop_inventory_cb")
			if shop_cb.is_valid():
				p_detail["inventory"] = shop_cb.call(p_player_realm)
			else:
				p_detail["inventory"] = {}
		_parent.NodeType.REST:
			p_detail["label"] = "回复点"
		_parent.NodeType.HARVEST:
			# 采集点——材料载荷在生成期定死（确定性：同图同境界恒同批），
			# 已采状态由 [ExplorationHarvest] 写在 map_states 里。
			p_detail["label"] = "采集点"
			p_detail["materials"] = HarvestTable.payload_for(p_map_id, p_player_realm)
		_parent.NodeType.ALCHEMY:
			# 炼丹台——配方不进节点详情：可炼清单来自 [AlchemyRecipes] 这份
			# 唯一配方源，写进 DAG 快照等于把同一份数据复制进存档
			# （改配方后旧档的节点还揣着过期清单）。
			p_detail["label"] = "炼丹台"
		_parent.NodeType.FORGE:
			# 炼器台——同炼丹台：配方源在 [AlchemyRecipes]，快照只记标签。
			p_detail["label"] = "炼器台"
		_parent.NodeType.MEDITATION:
			# 打坐/洞府——突破数值全在境界配置表与 [ExplorationBreakthroughTable]，
			# 快照不复制一份（改配置后旧档的节点不会揣着过期成功率）。
			p_detail["label"] = "洞府"
		_parent.NodeType.ACTION_SPRING:
			p_detail["label"] = "行动力泉"
		_parent.NodeType.TELEPORT:
			p_detail["label"] = "传送"
		_parent.NodeType.TRIBULATION:
			p_detail["label"] = "渡劫台"


## 填充战斗/精英节点的遭遇数据（[code]enemy_roster[/code] + 四键遭遇契约）。[br]
## [br][b]写入什么[/b]：名册 + [code]encounter[/code] 子字典 + 顶层
## [code]enemy_level[/code] / [code]rewards[/code] / [code]label[/code]——
## 顶层两键是 [code]CombatLaunchContext[/code] 的读取面，子字典是弹窗预览的聚合载体。[br]
## [br][b]等级口径[/b]（GDD §7 回旧地图：敌人强度按地图本身境界）：地图配置
## [code]enemy_realm[/code] > 玩家当前境界（旧配置缺键的过渡兜底，警告一次）。[br]
## [br][b]掉落口径[/b]：条目自带 [code]rewards[/code] > 模板 [code]reward_config[/code]
## 聚合；都没有则为 [code]{}[/code]（「本节点无掉落配置」，不是 0 掉落）。[br]
## [br][b]不臆造[/b]：名册回调缺失时名册为 [code][][/code]，由开战校验给出可读失败。
func _fill_encounter(p_detail: Dictionary, p_node_id: int, p_map_id: StringName,
		p_player_realm: int, p_is_elite: bool, p_config: Dictionary) -> void:
	var roster_cb: Callable = _parent.get("generate_enemy_roster_cb")
	var roster: Array = []
	if roster_cb.is_valid():
		roster = roster_cb.call(p_map_id, p_player_realm, p_is_elite)
		if not (roster is Array):
			roster = []
	var lookup: Callable = _template_lookup()
	var label: String = Fields.label_of(roster, p_is_elite)
	var encounter: Dictionary = Fields.make(
			"%s_%d" % [p_map_id, p_node_id], Fields.name_of(roster, p_is_elite),
			Fields.template_ids_of(roster), Fields.LEVEL_UNSPECIFIED, {})
	# 等级：地图境界定档优先（GDD「回旧地图」），旧配置缺键时回退玩家境界。
	var level: int = _level_of(p_map_id, p_player_realm, p_config)
	encounter[Fields.KEY_ENEMY_LEVEL] = level
	var rewards: Dictionary = Fields.rewards(encounter, roster, lookup)
	encounter[Fields.KEY_REWARDS] = rewards
	p_detail["enemy_roster"] = roster
	p_detail["label"] = label
	p_detail[Fields.KEY_ENCOUNTER] = encounter
	p_detail[Fields.KEY_ENEMY_LEVEL] = level
	p_detail[Fields.KEY_REWARDS] = rewards


## 节点等级定档——地图配置 [code]enemy_realm[/code] 优先，缺键（旧配置）时
## 回退玩家境界并警告一次。[br]
## [br][b]为什么不再让名册境界插队[/b]：GDD §7 要求「高境界玩家回低境界地图，
## 敌人强度仍按地图本身境界设定」。名册条目的境界来自敌人模板（出厂模板恒为
## 炼气），若它先命中，地图境界配置就永远不起作用——低境界图与高境界图的节点
## 强度会完全一样。名册境界只在开战上下文（[code]EncounterFields.enemy_level[/code]）
## 作为「节点未定档」时的读取兜底，不参与生成期定档。[br]
## [br][b]旧配置兼容[/b]：缺 [constant KEY_ENEMY_REALM] 时回退玩家境界并警告
## 一次（每次生成一条，不按节点刷屏）。
func _level_of(p_map_id: StringName, p_player_realm: int, p_config: Dictionary) -> int:
	var map_realm: int = int(p_config.get(KEY_ENEMY_REALM, 0))
	if map_realm > 0:
		return map_realm
	if not _warned_missing_enemy_realm:
		_warned_missing_enemy_realm = true
		push_warning("ExplorationDAGContent: 地图配置缺少 %s（map=%s），节点等级回退玩家境界 %d"
				% [KEY_ENEMY_REALM, p_map_id, p_player_realm])
	return maxi(p_player_realm, Fields.LEVEL_UNSPECIFIED)


## 模板查询闭包——注入回调优先，其次 Autoload AISystem，都没有时返回无效
## Callable（掉落聚合退化为「只读名册条目自带的 rewards」）。[br]
## [br][b]为什么允许注入[/b]：DAG 生成在单测里跑在裸 [code]Node[/code] 上
## （不在场景树中），此时拿不到 Autoload——注入让「据 reward_config 聚合掉落」
## 也能被单测覆盖。缺模板不应让地图生成崩溃。
func _template_lookup() -> Callable:
	if _parent == null:
		return Callable()
	var injected: Variant = _parent.get("enemy_template_lookup_cb")
	if injected is Callable and (injected as Callable).is_valid():
		return injected
	if not _parent.is_inside_tree():
		return Callable()
	var ai: Node = _parent.get_node_or_null(NodePath("/root/AISystem"))
	if ai != null and ai.has_method(&"get_template"):
		return Callable(ai, &"get_template")
	return Callable()
