extends RefCounted
## ExplorationEnemyPool —— 按地图配置生成战斗节点的敌人名册。[br]
## [br][b]为什么需要[/b]：[code]ExplorationSystem.generate_enemy_roster_cb[/code]
## 在生产路径此前没有注入点，真实 [code]enter_map[/code] 生成的战斗节点名册恒为
## 空数组——弹窗显示「敌人：未知 ×0」、开战时 [code]CombatLaunchContext.validate[/code]
## 直接失败（DEBT-EUI-006-5）。本模块把「地图敌人池 → 名册」这条生产链路补齐。[br]
## [br][b]名册形态[/b]：预览字典 [code]{template_id, name, realm}[/code]——与
## [code]RosterEntries[/code] 的字典分支同构，弹窗与开战上下文都能直接读。[br]
## [br][b]人数不进地图配置[/b]：人数由 [code]DifficultyCurve.count_range_of[/code]
## 按「地图境界档 − 玩家境界」给出，本模块只负责掷骰——[b]系数与区间只许一处[/b]
## （[code]assets/enemies/difficulty_curve.gd[/code]）。地图配置的
## [code]enemy_count_max[/code] 退居「上限兜底」（首图靠它保持 1 人），
## [code]enemy_count_min[/code] 在生成路径[b]不再被读取[/b]（见该类文档的遗留说明）。[br]
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
## §7 回旧地图、DEBT-EUI-006-5、DEBT-EQT-001（人数轴）。

## 难度曲线（人数区间与属性系数的唯一来源——本模块不自己写系数）。
const CurveScript := preload("res://assets/enemies/difficulty_curve.gd")

## 境界表（[code]max_deploy[/code] 的单一来源——人数上限「玩家出战名额 + 1」读它）。
## [br][b]为什么直接读表而不是 Autoload[/b]：名册生成跑在 DAG 生成期，此时
## RealmSystem 未必已就绪（[code]-s[/code] 脚本 / 单测桩环境无 Autoload）；
## 境界表是编译期常量，静态读它零依赖。同 [code]exploration_breakthrough_table.gd[/code] 先例。
const RealmSystemScript := preload("res://src/core/realm_system.gd")

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
## [br][param p_map_id] 地图 ID（决定敌人池与随机种子）。[br]
## [param p_player_realm] 玩家境界（人数轴的一端 + 种子派生）。[br]
## [param p_is_elite] 精英节点（数量 +[code]elite_bonus[/code]）。[br]
## [param p_config] 地图配置（[code]enemy_pool[/code] / [code]enemy_realm[/code]
## / [code]enemy_count_max[/code] / [code]elite_bonus[/code]）。[br]
## [br][b]返回[/b]：名册条目数组（空数组 = 池为空或模板全缺失）。[br]
func make_roster(p_map_id: StringName, p_player_realm: int, p_is_elite: bool,
		p_config: Dictionary) -> Array:
	# 每次调用按地图参数重设种子——同图同境界重入得到同一份名册（可复现）
	_rng.seed = hash(p_map_id) ^ (int(p_player_realm) << 8) ^ (1 if p_is_elite else 0)
	var pool: Array = p_config.get("enemy_pool", [])
	if pool.is_empty():
		return []
	var count: int = _roll_count(p_player_realm, p_is_elite, p_config)
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


## 掷名册人数——区间来自 [code]DifficultyCurve.count_range_of[/code]（唯一来源），
## 精英再加 [code]elite_bonus[/code]，最后夹到硬边界。[br]
## [br][b]为什么不再读 [code]enemy_count_min[/code][/b]：区间现在是「境界差」的函数，
## 地图配置的下限若还参与，同一张图会同时被两套口径拉扯（改一处不生效）；
## 配置只剩 [code]enemy_count_max[/code] 作上限兜底（首图靠它保持 1 人）。[br]
## [br][b]精英加成也受硬边界约束[/b]：越级档本身可掷到 5 人，精英再加就爆表——
## 夹到 [constant DifficultyCurve.COUNT_MAX] 而不是让战斗规模失控。[br]
## [br][param p_player_realm] 玩家境界（人数轴与 [code]max_deploy[/code] 夹取的一端）。[br]
func _roll_count(p_player_realm: int, p_is_elite: bool, p_config: Dictionary) -> int:
	var span: Dictionary = CurveScript.count_range_of(
			int(p_config.get("enemy_realm", 0)), p_player_realm,
			int(p_config.get("enemy_count_max", 0)), _max_deploy_of(p_player_realm))
	var count: int = _rng.randi_range(int(span["min"]), int(span["max"]))
	if p_is_elite:
		count += maxi(int(p_config.get("elite_bonus", 1)), 0)
	return clampi(count, CurveScript.COUNT_MIN, CurveScript.COUNT_MAX)


## 玩家出战名额——境界表 [code]max_deploy[/code]（人数上限 = 它 + 1）。[br]
## [br][b]读不到返回 0[/b]：境界非法（≤0 / 越界）时[code]DifficultyCurve[/code]
## 会跳过这层夹取，而不是按「0 个名额」把敌人压成 1 人。[br]
func _max_deploy_of(p_player_realm: int) -> int:
	var row: Variant = RealmSystemScript.realm_table.get(int(p_player_realm), null)
	if not (row is Dictionary):
		return 0
	return maxi(int((row as Dictionary).get("max_deploy", 0)), 0)


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
