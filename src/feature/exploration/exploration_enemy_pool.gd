extends RefCounted
## ExplorationEnemyPool —— 按地图配置生成战斗节点的敌人名册。[br]
## [br][b]为什么需要[/b]：[code]ExplorationSystem.generate_enemy_roster_cb[/code]
## 在生产路径此前没有注入点，真实 [code]enter_map[/code] 生成的战斗节点名册恒为
## 空数组——弹窗显示「敌人：未知 ×0」、开战时 [code]CombatLaunchContext.validate[/code]
## 直接失败（DEBT-EUI-006-5）。本模块把「地图敌人池 → 名册」这条生产链路补齐。[br]
## [br][b]名册形态[/b]：预览字典 [code]{template_id, name, realm}[/code]——与
## [code]RosterEntries[/code] 的字典分支同构，弹窗与开战上下文都能直接读。[br]
## [br][b]掉落不进名册[/b]：掉落由 [code]EncounterFields.rewards[/code] 按模板
## [code]reward_config[/code] 聚合（同一事实只在一处派生）。[br]
## [br][b]模板缺失不崩溃[/b]：池里登记的模板 ID 在 AISystem 注册表里查不到时
## 跳过该条目并告警——地图生成不应因数据缺项而失败；整池都缺失时返回空名册
## （由开战校验给出可读失败，而不是塞一个虚构敌人）。[br]
## [br][b]确定性[/b]：每次调用按 [code](map_id, player_realm, is_elite)[/code] 派生
## RNG 种子——同一张图、同一境界下重入得到同一份名册（可复现、可测试）；跨地图
## 与精英/普通之间才有差异。要「同图逐节点不同」需要把节点 ID 传进来，属后续
## 扩展（回调签名是探索系统既有契约，本轮不改）。[br]
##
## 来源: GDD exploration-system.md §3 步骤⑥（阵容在节点生成时确定）、
## §7 回旧地图、DEBT-EUI-006-5。

## 名册条目的模板 ID 键（与 [code]RosterEntries.template_id[/code] 同源）。
const KEY_TEMPLATE_ID: String = "template_id"
const KEY_NAME: String = "name"
const KEY_REALM: String = "realm"

## 随机源——每次 [method make_roster] 按地图参数重设种子。
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

## 模板查询闭包 [code]func(template_id) -> Resource[/code]（可空——空时按
## Autoload AISystem 查，仍查不到则名册只含模板 ID）。
var _lookup: Callable = Callable()

## 已告警的缺失模板 ID（同一 ID 只提醒一次，避免每节点刷屏）。
var _warned_ids: Dictionary = {}


## 构造——可选注入模板查询闭包（测试用；生产留空走 Autoload）。
func _init(p_lookup: Callable = Callable()) -> void:
	_lookup = p_lookup


## 重设随机源（测试 / 特殊变体用；[method make_roster] 每次调用也会重设）。
func set_seed(p_seed: int) -> void:
	_rng.seed = p_seed


## 生成一份名册。[br]
## [br][param p_map_id] 地图 ID（池与数量范围来自地图配置）。[br]
## [param p_player_realm] 玩家境界（参与种子派生）。[br]
## [param p_is_elite] 精英节点（数量 +[code]elite_bonus[/code]）。[br]
## [param p_config] 地图配置（[code]enemy_pool[/code] / [code]enemy_count_min[/code]
## / [code]enemy_count_max[/code] / [code]elite_bonus[/code]）。[br]
## [br][b]返回[/b]：名册条目数组（空数组 = 池为空或模板全缺失）。[br]
func make_roster(p_map_id: StringName, p_player_realm: int, p_is_elite: bool,
		p_config: Dictionary) -> Array:
	# 每次调用按地图参数重设种子——同图同境界重入得到同一份名册（可复现）
	_rng.seed = hash(p_map_id) ^ (int(p_player_realm) << 8) ^ (1 if p_is_elite else 0)
	var pool: Array = p_config.get("enemy_pool", [])
	if pool.is_empty():
		return []
	var count: int = _roll_count(p_config, p_is_elite)
	var roster: Array = []
	for i in range(count):
		var tid: StringName = _pick(pool)
		if tid == &"":
			continue
		var entry: Dictionary = _entry_of(tid)
		if entry.is_empty():
			continue
		roster.append(entry)
	return roster


## 掷名册人数——[code][min, max] + 精英加成[/code]，至少 1。
func _roll_count(p_config: Dictionary, p_is_elite: bool) -> int:
	var lo: int = maxi(int(p_config.get("enemy_count_min", 1)), 1)
	var hi: int = maxi(int(p_config.get("enemy_count_max", lo)), lo)
	var count: int = _rng.randi_range(lo, hi)
	if p_is_elite:
		count += maxi(int(p_config.get("elite_bonus", 1)), 0)
	return maxi(count, 1)


## 按权重抽一个模板 ID——权重全 0 / 池非法时返回空（调用方跳过该条目）。
func _pick(p_pool: Array) -> StringName:
	var total: int = 0
	for item: Variant in p_pool:
		if item is Dictionary:
			total += maxi(int((item as Dictionary).get("weight", 0)), 0)
	if total <= 0:
		return &""
	var roll: int = _rng.randi_range(1, total)
	var cumulative: int = 0
	for item: Variant in p_pool:
		if not (item is Dictionary):
			continue
		var weight: int = maxi(int((item as Dictionary).get("weight", 0)), 0)
		if weight <= 0:
			continue
		cumulative += weight
		if roll <= cumulative:
			return StringName(str((item as Dictionary).get(KEY_TEMPLATE_ID, "")))
	return &""


## 模板 ID → 预览条目（模板缺失时告警一次并返回空字典）。[br]
## [br][b]名称/境界取模板[/b]：名册自带境界会让 [code]EncounterFields.enemy_level[/code]
## 的「名册最高境界」优先分支恒生效，地图境界配置就被绕过了——预览条目只给
## 真实模板数据，等级口径统一由生成器按地图境界定档。
func _entry_of(p_template_id: StringName) -> Dictionary:
	var template: Variant = _template(p_template_id)
	if template == null:
		if not _warned_ids.has(p_template_id):
			_warned_ids[p_template_id] = true
			push_warning("ExplorationEnemyPool: 敌人模板 '%s' 不存在，已跳过" % p_template_id)
		return {}
	var name: String = str(template.get("display_name"))
	if name.is_empty():
		name = str(p_template_id)
	return {
		KEY_TEMPLATE_ID: p_template_id,
		KEY_NAME: name,
		KEY_REALM: int(template.get("realm")),
	}


## 模板查询——注入闭包优先，其次 Autoload AISystem；都不可用返回 null。
func _template(p_template_id: StringName) -> Variant:
	if p_template_id == &"":
		return null
	if _lookup.is_valid():
		return _lookup.call(p_template_id)
	var ai: Node = _autoload(&"AISystem")
	if ai != null and ai.has_method(&"get_template"):
		return ai.get_template(p_template_id)
	return null


## Autoload 动态查找（测试环境缺 Autoload 时返回 null）。
func _autoload(p_node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath(String(p_node_name)))
