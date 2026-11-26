## FormationSystem 接缝与访问面（继承链第 2 段）——[b]默认状态构造 + 子模块获取器 + Autoload 获取器[/b]。
##
## [b]本层职责[/b]：把「对象怎么起、外部世界怎么接进来」收在一处。[br]
##   · 默认状态构造——[method _init] → [method _reset_slots] → [method _make_empty_slot]
##     三件套（构造即铺 3 个 [code]EMPTY[/code] 空位，字段默认态的单一出处）与公开写入口
##     [method set_deploy_turn]；[br]
##   · 三个惰性子模块获取器——[method _get_serializer] / [method _get_aura] /
##     [method _get_slot_ops]，[code]null[/code] 时按需 [code]load().new(self)[/code]，
##     把父引用交给 [code]formation_serializer.gd[/code] / [code]formation_aura.gd[/code] /
##     [code]formation_slot_ops.gd[/code]——三者按[b]名字符串[/b]
##     [code]_parent.call / .get / .set[/code] 穿透继承链回取 21 个去重成员
##     （子模块只认名字符串，不认成员落在哪个文件）；[br]
##   · 信号发射包装——[method _emit_safe]（经 ADR-0007 信号链深度追踪路由，
##     GSM 侧不可用时回退直接 [code]emit[/code]）与存根调用器 [method _invoke_cb]；[br]
##   · 依赖访问两件——[method _get_faction_system]（条件判定走 FactionSystem.check_condition、
##     梯度阵法走 count_on_field）与 [method _get_gsm]（快照写 battle 域）。
## [b]为什么本层排在声明面之后、流程面之前[/b]：流程段的 [method deploy_formation] /
## [method set_character_affilation] 与链尾的序列化三出口都要取这些子模块与依赖，
## 而被调方必须在本段或祖先段——「谁调谁靠后」定死链序。[b]不管什么[/b]：
## 不做阵位状态转换（下一段）、不转发出口（链尾）；本链[b]没有 _ready[/b]，
## 信号接线在战斗域做（既有集成测试自己 [code]fs.call("_on_field_changed", …)[/code]）。
##
## [b]继承链[/b]（各段守 300 行内，成员名与访问路径逐字不变）：[br]
## [code]  formation_system_contract.gd [/code] ← 声明面：2 枚举 / 6 信号 / 1 标量常量 / 15 实例字段[br]
## [code]  formation_system_access.gd   [/code] ← 接缝与访问面：默认状态构造 / 三个惰性子模块获取器 / 信号发射包装 / 两个 Autoload 获取器[br]
## [code]  formation_system_flow.gd     [/code] ← 流程面：部署与覆盖 / 归属管理 / 查询 API / 内部原语[br]
## [code]  formation_system.gd          [/code] ← 链尾：条件重判与光环委托 / 序列化三出口 / 战斗结束清理[br]
##
## 来源: ADR-0024 §GSM 边界 §关键接口、ADR-0007 §_emit_signal_safe（同 CombatSystem 模式）。

extends "res://src/feature/formation/formation_system_contract.gd"


# === 初始化 ====================================================================

func _init() -> void:
	_reset_slots()


func _reset_slots() -> void:
	_slots.clear()
	for i in range(MAX_SLOTS):
		_slots[i] = _make_empty_slot()


func _make_empty_slot() -> Dictionary:
	return {
		"formation_id": -1,
		"card_instance_id": -1,
		"template_id": &"",
		"state": SlotState.EMPTY,
		"deployed_turn": -1,
		"requirement": {},
		"aura_scope": AuraScope.AFFILIATED_CHARACTERS,
		"effect_config": {},
		"max_level": 0,
		"base_value": 0.0,
		"affiliated_chars": [],
	}


func set_deploy_turn(turn: int) -> void:
	_deploy_turn = turn


## 惰性获取序列化子模块。
func _get_serializer() -> RefCounted:
	if _serializer == null:
		_serializer = load("res://src/feature/formation/formation_serializer.gd").new(self)
	return _serializer

## 惰性获取光环查询子模块。
func _get_aura() -> RefCounted:
	if _aura == null:
		_aura = load("res://src/feature/formation/formation_aura.gd").new(self)
	return _aura

## 惰性获取部署/覆盖/条件重判子模块（Sprint 12 Story 019 拆分）。
func _get_slot_ops() -> RefCounted:
	if _slot_ops == null:
		_slot_ops = load("res://src/feature/formation/formation_slot_ops.gd").new(self)
	return _slot_ops


## 动态获取 FactionSystem Autoload 节点。
func _get_faction_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/FactionSystem")


## Cat 2b 信号安全发射——经 GSM._emit_signal_safe 路由（ADR-0007 信号链深度追踪）。
func _emit_safe(signal_name: StringName, args: Array) -> void:
	if GameStateManager != null and GameStateManager.get_script().has_method("_emit_signal_safe"):
		GameStateManager.get_script()._emit_signal_safe(self, signal_name, args)
	else:
		var call_args: Array = [signal_name]
		call_args.append_array(args)
		callv("emit_signal", call_args)


## 调用可注入存根——无效 Callable 静默跳过。
func _invoke_cb(cb: Callable, args: Array) -> void:
	if cb.is_valid():
		cb.callv(args)


## 动态获取 GSM Autoload 节点（同 DeploymentSystem 先例）。
func _get_gsm() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/GameStateManager")
