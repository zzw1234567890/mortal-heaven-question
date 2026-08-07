## RealmSystem —— 境界属性数据表 + 查询接口 Autoload（#11）。
##
## Core 层第 11 个 Autoload。持有 [constant realm_table] 编译时常量数据表，
## 提供 O(1) 查询接口 [method get_realm_property] 与便捷方法 [method get_current_property]。
## RealmSystem 是只读查询者 + 编排者——[code]player.realm[/code] 所有权保留在 GSM（ADR-0010）。
##
## [b]Autoload 顺序[/b]：GSM → ... → RealmSystem（#11）
## [b]原则[/b]：所有境界属性查询必须通过本系统，绝不硬编码境界数值。
extends Node
# class_name RealmSystem —— 不声明：Autoload 全局单例，
# 声明 class_name 会与全局名冲突，导致 RS_SCRIPT.new() 测试实例无法解析。
# 测试以 var rs: Node 持有 + 动态分派访问（同 GSM/EventSystem/CardSystem 先例，
# 控制清单 2026-08-05 规则）。


# === 信号声明 =====================================================================

## 境界突破升级完成通知——[method realm_up] 成功后发射。[br]
## Cat 2b 动作通知（ADR-0007）——携带事实"境界从 old 升级到 new"。[br]
## [br][b]消费者[/b]（下游系统监听信号执行响应逻辑，RealmSystem 不直接调用）：[br]
##   - CultivationSystem：溢出池结算 + 属性丹转换[br]
##   - TribulationSystem：行动力回满[br]
##   - ExplorationSystem：解锁新地图入口[br]
##   - CardSystem：扩展掉落池[br]
## [br][b]与 GSM.realm_changed 的语义区分[/b]（ADR-0010 §风险）：[br]
##   - [signal GameStateManager.realm_changed]（Cat 1）表示"GSM 中 realm 值已变更"——任何写入都触发[br]
##   - [signal realm_upgraded]（Cat 2b）表示"突破升级流程已完成"——仅在 [method realm_up] 成功后触发
signal realm_upgraded(old_level: int, new_level: int)


# === 常量 ========================================================================

## 稀有度掉落权重表——编译时常量 Dictionary，5 个池等级 × 5 种稀有度权重。[br]
## 键为池等级 [code]int[/code]（1-5），值为稀有度权重 Dictionary。[br]
## 权重为整数百分比，每个 tier 总和 == 100。[br]
## NOTE: GDScript [code]const Dictionary[/code] 非真正不可变——控制清单禁止运行时写入。
const DROP_POOL_WEIGHTS: Dictionary = {
	1: {&"white": 60, &"blue": 30, &"purple": 10, &"gold": 0, &"darkgold": 0},
	2: {&"white": 30, &"blue": 40, &"purple": 25, &"gold": 5, &"darkgold": 0},
	3: {&"white": 15, &"blue": 30, &"purple": 35, &"gold": 18, &"darkgold": 2},
	4: {&"white": 10, &"blue": 20, &"purple": 30, &"gold": 30, &"darkgold": 10},
	5: {&"white": 5, &"blue": 15, &"purple": 25, &"gold": 35, &"darkgold": 20},
}


## 境界属性表——编译时常量 Dictionary，5 个境界 × 10 项属性。
## 键为境界等级 [code]int[/code]（1=炼气 ~ 5=化神），值为属性 Dictionary。
## NOTE: GDScript [code]const Dictionary[/code] 非真正不可变（嵌套内容可被修改）——
## 控制清单禁止运行时写入，GUT 冒烟测试验证基准值。
const realm_table: Dictionary = {
	1: {
		"name": "炼气期",
		"max_cultivation": 1000,
		"max_deploy": 2,
		"cost_per_turn": 2,
		"deck_limit": 20,
		"action_points": 5,
		"base_speed": 1,
		"max_darkgold": 0,
		"card_pool_tier": 1,
		"map_unlock": "青云剑宗",
	},
	2: {
		"name": "筑基期",
		"max_cultivation": 1500,
		"max_deploy": 3,
		"cost_per_turn": 5,
		"deck_limit": 25,
		"action_points": 7,
		"base_speed": 2,
		"max_darkgold": 0,
		"card_pool_tier": 2,
		"map_unlock": "碎星群岛",
	},
	3: {
		"name": "金丹期",
		"max_cultivation": 2250,
		"max_deploy": 4,
		"cost_per_turn": 8,
		"deck_limit": 30,
		"action_points": 9,
		"base_speed": 3,
		"max_darkgold": 1,
		"card_pool_tier": 3,
		"map_unlock": "东域",
	},
	4: {
		"name": "元婴期",
		"max_cultivation": 3375,
		"max_deploy": 5,
		"cost_per_turn": 11,
		"deck_limit": 35,
		"action_points": 11,
		"base_speed": 4,
		"max_darkgold": 2,
		"card_pool_tier": 4,
		"map_unlock": "归墟之境",
	},
	5: {
		"name": "化神期",
		"max_cultivation": 5063,
		"max_deploy": 6,
		"cost_per_turn": 14,
		"deck_limit": 40,
		"action_points": 13,
		"base_speed": 5,
		"max_darkgold": 2,
		"card_pool_tier": 5,
		"map_unlock": "最终战场",
	},
}


# === 公共 API =====================================================================

## 查询指定境界的属性值——O(1) 双重字典查询。[br]
## [br][b]复杂度[/b]: O(1) <0.01ms（ADR-0010 §性能影响）。[br]
## [br][param level]: 境界等级（1-5）。[br]
## [br][param key]: 属性键名（StringName，如 [code]&"cost_per_turn"[/code]）。[br]
## [br][b]返回[/b]: 属性值（Variant），无效 level/key 返回 [code]null[/code] + [method @GlobalScope.push_warning]。
func get_realm_property(level: int, key: StringName) -> Variant:
	if not realm_table.has(level):
		push_warning("RealmSystem: 无效境界等级 %d（有效范围 1-5）" % level)
		return null
	var realm_data: Dictionary = realm_table[level]
	if not realm_data.has(key):
		push_warning("RealmSystem: 属性 '%s' 在境界 %d 中不存在" % [key, level])
		return null
	return realm_data[key]


## 查询当前境界的属性值——便捷方法，内部从 GSM 读取 [code]player.realm[/code]。[br]
## [br][b]GSM 守卫[/b]：若 GSM 未就绪或 [code]player.realm[/code] 无效，返回 [code]null[/code] + [method @GlobalScope.push_error]。[br]
## [br][param key]: 属性键名。[br]
## [br][b]返回[/b]: 属性值（Variant），GSM 未就绪或属性无效时返回 [code]null[/code]。
func get_current_property(key: StringName) -> Variant:
	if not is_instance_valid(GameStateManager) or GameStateManager.player == null:
		push_error("RealmSystem.get_current_property: GSM 未就绪（查询 '%s'）" % key)
		return null
	var realm_level: int = GameStateManager.player.realm
	if not realm_table.has(realm_level):
		push_error("RealmSystem.get_current_property: player.realm=%d 不在境界表中（查询 '%s'）" % [realm_level, key])
		return null
	return get_realm_property(realm_level, key)


# === 境界突破编排 =================================================================

## 境界突破升级——原子编排器。[br]
## [br][b]流程[/b]（ADR-0010 §realm_up 编排器）：[br]
##   1. 校验 [param current_level] + 1 不超过 [constant realm_table] 最大境界[br]
##   2. 调用 [method GameStateManager.change_realm] 原子写入新境界（触发 GSM Cat 1 [signal GameStateManager.realm_changed]）[br]
##   3. 发射 [signal realm_upgraded] Cat 2b 信号委托下游系统[br]
## [br][b]信号委托[/b]：RealmSystem 不直接调用 CultivationSystem/ExplorationSystem/CardSystem/TribulationSystem——
## 下游系统监听 [signal realm_upgraded] 并执行响应逻辑（ADR-0004 编排器模式，Foundation 原则 #3）。[br]
## [br][b]不重置的内容[/b]（GDD §4）：卡组、角色位、灵石、事件进度、轮回天赋——由各自系统管理。[br]
## [br][b]突破后更新内容[/b]（GDD §4，由下游系统监听信号处理）：境界数值上限（通过 realm_table 查询自动更新）、
## 行动力回满、卡牌掉落池扩展、新地图解锁。[br]
## [br][param current_level]: 当前境界等级（1-5）。[br]
## [br][b]边界[/b]：[param current_level] == 5（最高境界）→ [method @GlobalScope.push_error] + 不修改 GSM。
func realm_up(current_level: int) -> void:
	# 校验调用者传入的 current_level 与 GSM 实际境界一致——防止 realm_upgraded 信号载荷与 GSM 状态漂移（ADR-0007 Cat 2b 携带事实）
	if current_level != GameStateManager.player.realm:
		push_error("RealmSystem.realm_up: current_level=%d 与 GSM.player.realm=%d 不一致" % [current_level, GameStateManager.player.realm])
		return
	var new_level: int = current_level + 1
	if new_level > realm_table.size():
		push_error("RealmSystem.realm_up: 无法突破超过最高境界（当前 %d，最高 %d）" % [current_level, realm_table.size()])
		return
	# 1. 更新 GSM 中的境界等级（原子写入 + 触发 realm_changed Cat 1 信号）
	GameStateManager.change_realm(new_level)
	# 2. 发射 Cat 2b 信号委托给下游系统
	realm_upgraded.emit(current_level, new_level)


# === 境界压制计算 =================================================================

## 计算境界压制系数——玩家攻击高境界敌人时的伤害衰减比例。[br]
## [br][b]压制规则[/b]（GDD §3）：[br]
##   - [code]delta = defender_lv - attacker_lv[/code][br]
##   - [code]delta <= 0[/code]（己方同级或更高）→ 1.0（无压制）[br]
##   - [code]delta == 1[/code]（敌方高 1 级）→ 0.8（-20%）[br]
##   - [code]delta >= 2[/code]（敌方高 2 级以上）→ 0.5（-50%）[br]
## [br][b]注意[/b]：压制仅影响玩家→敌方的伤害，不影响敌方→玩家；
## 只计算大境界差距，不看同境界内修为进度；不影响卡牌效果/天赋/丹药回复。[br]
## [br][param attacker_lv]: 攻击方境界等级。[br]
## [br][param defender_lv]: 防御方境界等级。[br]
## [br][b]返回[/b]: 压制系数 [code]float[/code]（范围 [0.5, 1.0]）。
func realm_penalty(attacker_lv: int, defender_lv: int) -> float:
	var delta: int = defender_lv - attacker_lv
	if delta <= 0:
		return 1.0
	if delta == 1:
		return 0.8
	return 0.5  # delta >= 2


## 计算地图境界压制——柔性压制机制，进攻属性受限、防御保留。[br]
## [br][b]规则[/b]（GDD §6）：[br]
##   - 玩家境界 ≤ 地图上限 → 无压制（offensive/defensive 均为玩家境界）[br]
##   - 玩家境界 > 地图上限 → 进攻属性压制到地图上限，防御属性保留玩家境界[br]
## [br][b]参考实现声明[/b]：GDD §6 明确"完整公式由 exploration-system.md 定义，境界系统提供参考实现"。[br]
## 本方法为参考版本，探索系统 Epic 可调整——若出现差异以 exploration-system.md 为准。[br]
## [br][param player_lv]: 玩家境界等级。[br]
## [br][param map_max_lv]: 地图允许的最高境界等级。[br]
## [br][b]返回[/b]: 含 [code]offensive_lv[/code] 和 [code]defensive_lv[/code] 两个 int 字段的 Dictionary。
func map_effective_realm(player_lv: int, map_max_lv: int) -> Dictionary:
	if player_lv <= map_max_lv:
		return {"offensive_lv": player_lv, "defensive_lv": player_lv}
	return {"offensive_lv": map_max_lv, "defensive_lv": player_lv}


# === 稀有度权重查询 ===============================================================

## 查询指定池等级的稀有度掉落权重。[br]
## [br][param pool_tier]: 池等级（1-5），通常来自 [code]realm_table[L].card_pool_tier[/code]。[br]
## [br][b]返回[/b]: 稀有度权重 Dictionary 的**副本**（键为 [code]StringName[/code]：white/blue/purple/gold/darkgold，
## 值为整数百分比权重，总和 100）；无效 [param pool_tier] 返回空 Dictionary + [method @GlobalScope.push_warning]。[br]
## [br][b]语义[/b]：CardSystem 战利品生成时按权重做加权随机选择。[br]
## [br][b]不可变性保护[/b]：返回 [method Dictionary.duplicate] 副本而非内部 const 引用——
## GDScript [code]const Dictionary[/code] 非真正冻结，消费者修改副本不影响全局权重表（控制清单禁止写 DROP_POOL_WEIGHTS）。
func get_rarity_weights(pool_tier: int) -> Dictionary:
	if not DROP_POOL_WEIGHTS.has(pool_tier):
		push_warning("RealmSystem: 无效池等级 %d（有效范围 1-5）" % pool_tier)
		return {}
	return DROP_POOL_WEIGHTS[pool_tier].duplicate()
