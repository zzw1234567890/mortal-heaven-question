extends RefCounted
## TribulationBossRoster —— 天劫 Boss「哪一个境界打哪一只」的[b]唯一出处[/b]。[br]
## [br][b]它回答一个问题[/b]：境界 L 的天劫，上场的雷灵是哪份模板？[br]
## [br][b]为什么单独一张表，而不并进 [code]difficulty_curve.gd[/code] 或探索敌人池[/b]：[br]
##   · 难度曲线回答「敌人有多强」（乘数），本表回答「敌人是谁」（身份）——两件事的
##     变更理由不同，混在一处会让「加一只 Boss」变成改一张系数表；[br]
##   · 探索侧的敌人池是按地图配置点名的（[code]exploration_enemy_pool.gd[/code]），
##     天劫 Boss 不属于任何地图——塞进去只会在「这张图能刷出什么」的配置面里多出一类
##     永远不该被刷出来的条目。[br]
## [br][b]为什么这四份 .tres 不进 [code]AISystem[/code] 的共享注册表[/b]：注册表是
## 「探索/遭遇战能点到的敌人」的全集（[code]ai_system.gd §load_templates[/code] 只扫
## [code]assets/enemies/[/code] 顶层）。渡劫 Boss 是渡劫域私有资产，[b]刻意[/b]放在
## 子目录里不进那张表：进了表，任何一张地图配置写错一个 id 就能把天劫雷灵刷进普通
## 遭遇。运行时状态由 [code]EnemyBattleState[/code] 直接从模板现建
## （[code]AISystem.create_state[/code] 是纯映射，不查注册表）。[br]
## [br][b]四档对应关系[/b]（GDD tribulation-system.md §3 天劫Boss 雷灵那张表——
## 「炼气→筑基 | 炼气雷灵」「筑基→金丹 | 筑基雷灵」「金丹→元婴 | 金丹雷灵」
## 「元婴→化神 | 元婴雷灵」；渡劫战的 Boss 取[b]当前境界[/b]那一只）：[br]
##   · 常规渡劫：玩家境界 L → Boss 境界 L → 打第 L 档雷灵；[br]
##   · 越阶渡劫：玩家境界 L → Boss 境界 L+1 → 打第 L+1 档雷灵（GDD §6
##     「天劫Boss = 当前境界+1 的雷灵」）。[br]
## [br][b]数值口径[/b]：四份 .tres 的 [code]base_hp[/code] / [code]base_attack[/code] /
## [code]base_defense[/code] 是[b]唯一[/b]的数值出处——本模块与调用方都不写死任何数字，
## 只读模板。取数口径见 [code]docs/decisions/ADR-0032-tribulation-boss-roster.md[/code]。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：全是常量与静态纯函数——不读 GSM、不持节点、
## 不改任何系统状态。[br]
##
## 来源: design/gdd/tribulation-system.md §3 天劫Boss 雷灵 / §6 越阶渡劫、
## ADR-0021 §get_tribulation_boss_config、ADR-0032。

## 四档雷灵的模板路径——键为 [b]Boss 境界[/b]（GDD §3 表的 Boss境界 列）。[br]
## [br][b]键的范围就是「配了几档」[/b]：表里有 1~4 四档，故 Boss 境界超出 1~4 时
## 由 [method tier_of] 夹到端点，不臆造第五档。[br]
## [br][b]路径写全而不是拼目录 + 文件名[/b]：本表是「哪只 Boss 在哪」的唯一书面记录，
## 拼字符串会让「文件改名」与「改表」变成两处改动。
const TEMPLATE_PATHS: Dictionary = {
	1: "res://assets/enemies/tribulation/lianqi_leiling.tres",
	2: "res://assets/enemies/tribulation/zhuji_leiling.tres",
	3: "res://assets/enemies/tribulation/jindan_leiling.tres",
	4: "res://assets/enemies/tribulation/yuanying_leiling.tres",
}

## 档位下界 / 上界——与 [constant TEMPLATE_PATHS] 的键一一对应。
const MIN_TIER: int = 1
const MAX_TIER: int = 4

## 雷灵模板 id 的前缀——[b]只用于诊断文案[/b]（真正的 id 从模板里读，不在这里拼）。
const ID_PREFIX: String = "tribulation_leiling_"


## Boss 境界 → 本表档位（夹到 [constant MIN_TIER] ~ [constant MAX_TIER]）。[br]
## [br][b]为什么要夹[/b]：元婴期的越阶渡劫会算出 Boss 境界 5（GDD §6「+1」），而 GDD §3
## 只给了四档雷灵——化神是最高境界，没有第五只。夹到 4 档意味着[b]这一场按元婴雷灵打[/b]
## （与常规渡劫同一只），越阶的额外金卡奖励仍按 [code]is_cross_realm[/code] 保留。[br]
## [br][b]不夹的后果[/b]：返回空模板 → 空名册 → [code]CombatEndCheck._all_enemies_dead[/code]
## 对空名册返回 false → 战斗永远打不完（DEBT-TRB-001 的形态）。宁可退到邻档，
## 也不给出一场判不出胜负的仗。[br]
## [br][b]表外等级（0 / 负数）[/b]同夹：不存在的境界没有雷灵，退到最低档是唯一能打的选择。
static func tier_of(p_boss_realm: int) -> int:
	return clampi(int(p_boss_realm), MIN_TIER, MAX_TIER)


## Boss 境界对应的雷灵模板——加载失败时返回 [code]null[/code]（不臆造）。[br]
## [br][param p_boss_realm] Boss 境界（常规渡劫 = 玩家境界；越阶 = 玩家境界 + 1）。[br]
## [br][b]返回[/b]：模板 [Resource]（[code]EnemyTemplate[/code]）或 [code]null[/code]
## （资产缺失是构建事故——由调用方决定怎么报，本模块只如实回答「没有」）。[br]
## [br][b]为什么在这里 load 而不查 AISystem 注册表[/b]：这四份模板刻意不进共享注册表
## （见类文档），路径只在本表里写一次。
static func template_for(p_boss_realm: int) -> Resource:
	var tier: int = tier_of(p_boss_realm)
	var path: String = str(TEMPLATE_PATHS[tier])
	var tpl: Resource = load(path)
	if tpl == null:
		push_error("TribulationBossRoster: 天劫雷灵模板加载失败（档 %d）——%s" % [tier, path])
	return tpl


## Boss 境界对应的模板列表（本系统每档只有一只雷灵——元婴劫的「雷球小怪」是战斗内
## 召唤机制，不是开战名册的一部分，见 ADR-0032 §范围边界）。[br]
## [br][b]返回[/b]：[code]Array[Resource][/code]；模板缺失时为空数组。
static func templates_for(p_boss_realm: int) -> Array:
	var tpl: Resource = template_for(p_boss_realm)
	return [] if tpl == null else [tpl]


## Boss 境界对应的模板 id 列表——[code]get_tribulation_boss_config()[/code] 的
## [code]enemy_roster[/code] 字段就是它（字符串标识，供审计与用例断言）。[br]
## [br][b]返回[/b]：[code]Array[StringName][/code]；模板缺失时为空数组。
static func template_ids_for(p_boss_realm: int) -> Array:
	var ids: Array = []
	for tpl: Resource in templates_for(p_boss_realm):
		ids.append(tpl.get("template_id"))
	return ids


## 组装天劫 Boss 的[b]运行时名册[/b]——模板 → [code]EnemyBattleState[/code] + 阵位 +
## 写回 AISystem。[br]
## [br][param p_ai] AISystem（缺失 / 缺所需方法时返回空名册并报错——没有它就没有
## 运行时状态可建）。[br]
## [param p_boss_realm] Boss 境界。[br]
## [br][b]返回[/b]：[code]Array[/code]——元素为 [code]EnemyBattleState[/code]。[br]
## [br][b]为什么写回 AISystem[/b]：AI 决策读 [code]AISystem.get_enemy_roster()[/code]，
## 只把名册塞进 battle_start config 的话，敌方回合会拿到空候选池、选不出目标
## （同 [code]combat_scene_battle_setup.gd §_resolve_roster[/code] 的理由）。[br]
## [br][b]为什么不用 AISystem.create_enemy_roster[/b]：那条链按 [b]模板 id[/b] 查注册表，
## 而雷灵不在注册表里（见类文档）。这里改走 [code]create_state[/code]——它是纯的
## 模板→实例映射，不查注册表；阵位与预配置绑定两步单独补上，保证名册形状与
## [code]create_enemy_roster[/code] 的产物一致。[br]
## [br][b]不做难度缩放[/b]：雷灵的模板境界与它要打的那一劫一一对应（第 L 档 =
## 境界 L），[code]difficulty_curve[/code] 的追赶轴在此 gap ≤ 0、系数恒 1.0
## ——缺省即不缩放。本模块也因此不碰那条曲线（见 ADR-0032 §数值来源）。[br]
static func build(p_ai: Node, p_boss_realm: int) -> Array:
	var templates: Array = templates_for(p_boss_realm)
	if templates.is_empty():
		return []
	if p_ai == null or not p_ai.has_method(&"create_state"):
		push_error("TribulationBossRoster: AISystem 不可用——天劫名册取不到运行时状态")
		return []
	var roster: Array = []
	for tpl: Resource in templates:
		var state: Variant = p_ai.call(&"create_state", tpl)
		if state != null:
			roster.append(state)
	if roster.is_empty():
		return []
	if p_ai.has_method(&"_assign_positions"):
		p_ai.call(&"_assign_positions", roster)
	if p_ai.has_method(&"set_enemy_roster"):
		p_ai.call(&"set_enemy_roster", roster)
		# 预配置绑定要在名册写回之后注册（登记用的实例索引取自 AI 的现名册）。
		if p_ai.has_method(&"register_preconfigured_bindings"):
			for enemy: Variant in roster:
				p_ai.call(&"register_preconfigured_bindings", enemy)
	return roster
