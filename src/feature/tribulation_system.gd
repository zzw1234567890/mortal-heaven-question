## TribulationSystem —— 渡劫突破系统 Autoload（ADR-0021 #24）。[b]链尾：装配 + 四个出口面[/b]。
##
## Feature 层 Autoload。渡劫流程编排器——拥有渡劫生命周期状态机，[br]
## 委托 CombatSystem 启动渡劫战、委托 RealmSystem 境界升级、委托 GSM 修为扣除。[br]
## [b]Story 5-10 范围[/b]：状态机骨架 + GSM 域扩展 + 触发条件检查 + 信号声明。[br]
## [b]Story 5-11 范围[/b]：渡劫战斗委托 CombatSystem + 雷伤纯函数 + Boss 配置查询。[br]
## [b]已注册进 project.godot[/b]——Autoload #22（TribulationSystem）。[br]
## [br]来源: ADR-0021 §关键接口 / GDD tribulation-system.md §1-7 + §状态与转换。
##
## [b]本层职责[/b]：装配与四个出口面。[br]
##   · 装配——[method _ready] 订阅 [code]CombatSystem.battle_ended[/code]；[br]
##   · 渡劫战斗委托转发——[method start_tribulation_combat] /
##     [method _build_tribulation_config] / [method _on_battle_ended]
##     （实现体在 [code]tribulation_combat.gd[/code]）；[br]
##   · 结算转发——[method _handle_tribulation_success] / [method _handle_tribulation_failure]
##     （实现体在 [code]tribulation_settlement.gd[/code]）；[br]
##   · 雷伤纯函数与 Boss 配置查询——[method calculate_lightning_damage] /
##     [method get_lightning_layers_per_turn] / [method get_tribulation_boss_config]。
##
## [b]继承链[/b]（各段守 300 行内，成员名与访问路径逐字不变）：[br]
## [code]  tribulation_system_contract.gd [/code] ← 声明面：2 枚举 / 3 标量常量 / 1 转换白名单 / 5 信号 / 7 实例字段[br]
## [code]  tribulation_system_access.gd   [/code] ← 接缝与访问面：惰性获取器 / 信号发射包装 / GSM 与四个 Autoload 获取器[br]
## [code]  tribulation_system_flow.gd     [/code] ← 流程面：触发 / 取消 / 状态转换 / 查询 / 渡劫丹[br]
## [code]  tribulation_system.gd          [/code] ← 本层：装配（_ready）+ 战斗委托 / 结算 / 雷伤 / Boss 查询出口[br]
##
## [b]链序不是自由选择[/b]：GDScript 解析期要求被调方在[b]本段或祖先段[/b]——祖先段用裸
## 标识符引用后代段成员会直接报 [code]Function "xxx()" not found in base self[/code]。
## 故 [method _ready]（要调全部 Autoload 获取器）、结算转发（要调
## [method _get_settlement]）与战斗委托转发（要调 [method _get_combat_delegation]）
## 都必须排在接缝段之后；而信号因为有两个发射方，只能整体落在链首。[br]
## [code]trigger_tribulation[/code] 的默认参数值 [code]TribulationType.NORMAL[/code] 是
## 解析期求值，只能引用本段或祖先段常量，故枚举随声明落链首。[br]
## [b]路径即契约[/b]：[code]project.godot[/code] 的 [code][autoload][/code] 把
## [code]TribulationSystem[/code] 绑在 [code]res://src/feature/tribulation_system.gd[/code]
## 这一串字符上，另有 [code]tribulation_launch.gd[/code] /
## [code]cultivation_actions.gd[/code] / [code]cultivation_tribulation_gate.gd[/code] 三处
## 按同一路径 [code]preload[/code] 取类（读枚举），故本文件名逐字不动（本类[b]不声明[/b]
## [code]class_name[/code]——Feature Autoload 固有惯例）。[br]
## 守卫用例：[code]tests/unit/tribulation_system/test_tribulation_public_face_lock.gd[/code]。

extends "res://src/feature/tribulation/tribulation_system_flow.gd"


# === 渡劫战斗委托（Story 5-11）==================================================

## Autoload 就绪——订阅 CombatSystem.battle_ended 信号（ADR-0021 §结算监听）。[br]
## [br][b]流程[/b]: 获取 CombatSystem 引用 → 连接 battle_ended → _on_battle_ended。[br]
## [br]来源: ADR-0021 §渡劫战启动与结算监听（同 CultivationSystem 订阅 realm_changed 模式）。
func _ready() -> void:
	var combat: Node = _get_combat_system()
	if combat == null:
		push_warning("TribulationSystem._ready: CombatSystem 不可用，battle_ended 信号未订阅")
		return
	if not combat.battle_ended.is_connected(_on_battle_ended):
		combat.battle_ended.connect(_on_battle_ended)


## 启动渡劫战斗——委托给战斗委托子模块（Sprint 12 Story 017 拆分）。
func start_tribulation_combat() -> void:
	_get_combat_delegation().start_tribulation_combat()


## 构建渡劫战斗配置——委托给战斗委托子模块。
func _build_tribulation_config() -> Dictionary:
	return _get_combat_delegation().build_tribulation_config()


## 监听 CombatSystem.battle_ended——委托给战斗委托子模块。[br]
## [br][param result] 战斗结果（CombatResult.VICTORY/DEFEAT/RETREAT）。[br]
## [br][param rewards] 奖励字典。
func _on_battle_ended(result: int, rewards: Dictionary) -> void:
	_get_combat_delegation().on_battle_ended(result, rewards)


# === 成功/失败结算（Story 5-12——委托给 tribulation_settlement.gd 子模块）===

## 渡劫成功结算——委托给子模块（Sprint 9 Story 7 拆分）。[br]
## [br][b]返回[/b]：本场金卡发放报告 [code]{cards, cards_failed}[/code]（见
## [method TribulationSettlement.handle_success]）——[code]TribulationCombat[/code]
## 把它写进 [code]battle_ended[/code] 载荷，结算屏据此写出「获得：×××（金）」。
func _handle_tribulation_success() -> Dictionary:
	return _get_settlement().handle_success()


## 渡劫失败结算——委托给子模块。
func _handle_tribulation_failure() -> void:
	_get_settlement().handle_failure()


# === 雷伤计算（纯函数——委托给 tribulation_settlement.gd 子模块）========

## 计算雷伤层数伤害——委托给子模块。
func calculate_lightning_damage(turn: int, layers_per_turn: int) -> int:
	return _get_settlement().calculate_lightning_damage(turn, layers_per_turn)


## 获取雷伤每回合叠层数——委托给子模块。
func get_lightning_layers_per_turn(realm_level: int) -> int:
	return _get_settlement().get_lightning_layers_per_turn(realm_level)


# === 天劫 Boss 配置查询 ========================================================

## 查询天劫 Boss 配置——委托给子模块。
func get_tribulation_boss_config(realm: int) -> Dictionary:
	return _get_settlement().get_tribulation_boss_config(realm)
