## TribulationSystem 接缝与访问面（继承链第 2 段）——[b]惰性获取器 + 信号发射包装 + Autoload 获取器[/b]。
##
## [b]本层职责[/b]：把「外部世界怎么接进来」收在一处。[br]
##   · 两个惰性子模块获取器——[method _get_settlement]（结算实现体
##     [code]tribulation_settlement.gd[/code]，Sprint 9 Story 7 切出）与
##     [method _get_combat_delegation]（战斗委托实现体 [code]tribulation_combat.gd[/code]，
##     Sprint 12 Story 017 切出）；[br]
##   · 信号发射包装——[method _emit_safe]（经 ADR-0007 信号链深度追踪路由，
##     GSM 侧不可用时回退直接 [code]emit[/code]）；[br]
##   · 依赖访问五件——[method _get_gsm] 与四个 Autoload 获取器
##     （[method _get_combat_system] / [method _get_realm_system] /
##     [method _get_ai_system] / [method _get_card_system]），前三个支持测试注入覆盖。[br]
## [b]为什么本层排在声明面之后、流程面之前[/b]：流程段的 [method trigger_tribulation]
## 与链尾的 [method _ready] / 结算转发都要取这些依赖与子模块，而被调方必须在本段或祖先段
## ——「谁调谁靠后」定死链序。[b]不管什么[/b]：不做状态转换（下一段）、不装配（链尾）。
##
## [b]继承链[/b]（各段守 300 行内，成员名与访问路径逐字不变）：[br]
## [code]  tribulation_system_contract.gd [/code] ← 声明面：2 枚举 / 3 标量常量 / 1 转换白名单 / 5 信号 / 7 实例字段[br]
## [code]  tribulation_system_access.gd   [/code] ← 本层：惰性获取器 / 信号发射包装 / GSM 与四个 Autoload 获取器[br]
## [code]  tribulation_system_flow.gd     [/code] ← 流程面：触发 / 取消 / 状态转换 / 查询 / 渡劫丹[br]
## [code]  tribulation_system.gd          [/code] ← 链尾：装配（_ready）+ 战斗委托 / 结算 / 雷伤 / Boss 查询出口[br]
##
## 来源: ADR-0021 §渡劫战启动与结算监听 / §信号分类、ADR-0007 §_emit_signal_safe
## （同 CombatSystem 模式）。

extends "res://src/feature/tribulation/tribulation_system_contract.gd"


## 惰性获取结算子模块。
func _get_settlement() -> RefCounted:
	if _settlement == null:
		_settlement = load("res://src/feature/tribulation/tribulation_settlement.gd").new(self)
	return _settlement


## 惰性获取渡劫战斗委托子模块（Sprint 12 Story 017 拆分）。
func _get_combat_delegation() -> RefCounted:
	if _combat_delegation == null:
		_combat_delegation = load("res://src/feature/tribulation/tribulation_combat.gd").new(self)
	return _combat_delegation


# === 内部辅助 ====================================================================

## Cat 2b 信号安全发射——经 GSM._emit_signal_safe 路由（ADR-0007 信号链深度追踪）。[br]
## [br][b]GSM 不可用时回退[/b]到直接 emit_signal + push_warning 告警。[br]
## [br]来源: ADR-0021 §信号分类 / ADR-0007 §_emit_signal_safe（同 CombatSystem 模式）。
func _emit_safe(signal_name: StringName, args: Array) -> void:
	var gsm = _get_gsm()
	if gsm != null and gsm.has_method("_emit_signal_safe"):
		gsm._emit_signal_safe(self, signal_name, args)
		return
	push_warning("TribulationSystem: GSM 不可用，%s 信号绕过 _emit_signal_safe 路由" % signal_name)
	var call_args: Array = [signal_name]
	call_args.append_array(args)
	callv("emit_signal", call_args)


## 获取 GSM 引用——通过 SceneTree Autoload（同 CultivationSystem/CombatSystem 模式）。
func _get_gsm() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/GameStateManager")


# === CombatSystem 引用 =========================================================

## 获取 CombatSystem 引用——优先使用注入的覆盖引用，否则通过 SceneTree Autoload 查找。[br]
## [br][b]返回[/b]: CombatSystem 节点或 [code]null[/code]（未注册时）。
func _get_combat_system() -> Node:
	if _combat_override != null and is_instance_valid(_combat_override):
		return _combat_override
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/CombatSystem")


## 获取 RealmSystem 引用——优先使用注入的覆盖引用，否则通过 SceneTree Autoload 查找。[br]
## [br][b]返回[/b]: RealmSystem 节点或 [code]null[/code]（未注册时）。
func _get_realm_system() -> Node:
	if _realm_override != null and is_instance_valid(_realm_override):
		return _realm_override
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/RealmSystem")


## 获取 AISystem 引用——优先使用 SceneTree Autoload 查找。[br]
## [br][b]为什么这里补一个[/b]：渡劫战的名册由 [code]TribulationBossRoster.build[/code]
## 经 AISystem 现建（模板 → [code]EnemyBattleState[/code]），取的就是这个入口——
## 跨模块 `_autoload` 各写一份会让「找不到时怎么办」的口径散开。[br]
## [br][b]返回[/b]: AISystem 节点或 [code]null[/code]（未注册时）。
func _get_ai_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/AISystem")


## 获取 CardSystem 引用——优先使用注入的覆盖引用，否则通过 SceneTree Autoload 查找。[br]
## [br][b]返回[/b]: CardSystem 节点或 [code]null[/code]（未注册时——金卡走「未发放」降级）。
func _get_card_system() -> Node:
	if _card_override != null and is_instance_valid(_card_override):
		return _card_override
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/CardSystem")
