extends RefCounted
## CombatSceneBattleLauncher —— 开战守卫与执行（从 [code]combat_scene.gd[/code] 拆出）。[br]
## [br][b]职责[/b]：三道守卫（战斗系统可用 / 未在战斗中 / 开战上下文齐备）+ 执行
## （备数据 → [code]init_deck[/code] → [code]battle_start[/code] → 建卡 → 放行输入）。[br]
## [br][b]为什么独立成文件[/b]：容器加上开战上下文消费后超出 300 行软上限；且
## 「什么时候允许开战」是一条可单独测试的策略，与「场景挂什么组件」无关
## （同 [code]combat_scene_exits.gd[/code] / [code]combat_scene_battle_setup.gd[/code]
## 先例）。[br]
## [br][b]不持状态[/b]（ADR-0031 §2）：容器、战斗系统、开战前置全部按调用传入；
## 本类只做一次性的守卫与转发。
##
## 来源: ADR-0008 §生命周期、ADR-0031 §2、本轮「探索→战斗」补链。

## 开战前置（布阵 / 牌堆 / 敌方阵容——数据来源见该类头注释）。
const BattleSetupScript := preload("res://src/feature/combat/combat_scene_battle_setup.gd")

## 守卫失败文案（玩家可读——本地化 epic 后替换为 key）。
const TEXT_NO_COMBAT_SYSTEM: String = "CombatSystem 不可用——战斗未开始"


## 执行开战。[br]
## [br][param p_combat] 战斗系统（须有 [code]battle_start[/code]）。[br]
## [param p_root] 战场根（建卡用；可空）。[br]
## [param p_interaction] 出牌交互接线（开战后放行；可空）。[br]
## [param p_launch] 开战上下文消费模块（[code]combat_scene_launch.gd[/code]）。[br]
## [param p_required] 是否必须有上下文（渡劫为 false）。[br]
## [param p_deps] 开战前置依赖 [code]{ai, deployment, deck, encounter, roster_override}[/code]。[br]
## [br][b]返回[/b]：空串 = 已开战；非空 = 拒绝原因（调用方 push_error 并展示）。
func start(p_combat: Node, p_root: Control, p_interaction: RefCounted,
		p_launch: RefCounted, p_required: bool, p_deps: Dictionary,
		p_character_ids: Array, p_realm: int, p_is_tribulation: bool) -> String:
	if p_combat == null or not p_combat.has_method(&"battle_start"):
		return TEXT_NO_COMBAT_SYSTEM
	if p_combat.has_method(&"is_battle_active") \
			and bool(p_combat.call(&"is_battle_active")):
		return ""  # 已开战——重复确认是空操作，不是失败
	if not bool(p_launch.call(&"can_start", p_required)):
		return str(p_launch.call(&"failure_text"))
	var setup: RefCounted = make_setup(p_deps, p_launch)
	setup.call(&"launch", p_combat, p_root, p_interaction,
			p_character_ids, p_realm, p_is_tribulation)
	return ""


## 构建开战前置——依赖顺序：AI / 布阵 / 卡组 / 显式遭遇 / 运行时名册 /
## 节点三件套（模板 ID / 等级 / 掉落，由上下文模块给出）。[br]
## [br][b]为什么公开[/b]：渡劫战的开战入口不在这里（它走
## [code]TribulationSystem.start_tribulation_combat[/code]），但那条路同样需要
## 「布阵 + 牌堆」先就位——渡劫场景借本方法拿到同一个 setup 实例，
## [code]setup_field[/code] / [code]init_deck[/code] 的实现与顺序仍只有一处。
func make_setup(p_deps: Dictionary, p_launch: RefCounted) -> RefCounted:
	var setup: RefCounted = BattleSetupScript.new()
	var args: Array = [p_deps.get("ai"), p_deps.get("deployment"), p_deps.get("deck"),
			p_deps.get("encounter"), p_deps.get("roster_override")]
	args.append_array(p_launch.call(&"battle_setup_args"))
	setup.callv(&"setup", args)
	return setup
