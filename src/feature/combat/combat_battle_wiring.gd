extends RefCounted
## CombatBattleWiring —— 战斗开始/结束的接线子模块（Sprint 18 补链）。[br]
## [br][b]职责[/b][br]
##   1. [b]名册快照[/b]：开战瞬间定格敌我阵容（END 胜负判定的输入）；[br]
##   2. [b]费用激活/清理[/b]：把境界费用上限推入 CostSystem、战斗结束清零；[br]
##   3. [b]Phase 6 END 判定[/b]：调 [code]combat_end_check.gd[/code] 内核，记录待收尾结果；[br]
##   4. [b]结局收尾[/b]：由父节点在阶段簿记完成后调用 [code]battle_end()[/code]。[br]
## [br][b]为什么独立成文件[/b]：combat_system.gd 已是 900+ 行的 Autoload 聚合体
## （coding-standards 单文件软上限的先例偏差），本组逻辑只读写父节点少量状态，
## 拆出后父节点只保留薄委托（同 combat_phase_manager / combat_card_resolver 先例）。[br]
## [br][b]状态归属[/b]：[member _parent] 持有 [code]_battle_enemy_roster[/code] /
## [code]_battle_player_roster[/code] / [code]_field_engaged[/code] /
## [code]_pending_battle_result[/code] 四个字段（子模块经 get/set 访问，不自持副本——
## ADR-0008 §状态单一所有者）。[br]
## [br]来源: GDD combat-system.md §9 战斗结束规则、ADR-0008 §Phase 6、ADR-0015（费用）、
## gate-check 2026-11-08 §B1。

## 战斗结束判定内核（纯函数）。
const EndCheck := preload("res://src/feature/combat/combat_end_check.gd")

## 费用上限回退值——RealmSystem 不可用（剥离 Autoload 的测试环境）时的安全默认。
## 数值与 realm_table[1].cost_per_turn（炼气期 2 费）一致；生产路径永远走 RealmSystem 现读。
const DEFAULT_COST_PER_TURN: int = 2

## 父节点引用——CombatSystem 实例。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


# === 名册快照 ====================================================================

## 记录本场敌我名册快照（[method CombatSystem.battle_start] 调用）。[br]
## [br][b]敌方[/b]：config.enemy_roster 优先；缺省时从 AISystem 的当前阵容取拷贝。[br]
## [b]我方[/b]：config.character_ids 优先；缺省时取阵位上现有的角色 ID
## （渡劫等不携带名册的开战路径）。[br]
## [br][b]为什么快照[/b]：END 判定可能跨多回合执行，现读外部系统会读到「下一场」
## 或测试串场留下的数据；快照在开战瞬间定格，一场一份。[br]
## [br][b]副作用[/b]：重置「阵位曾有人」标志，并按开战瞬间的阵位初始化。
func capture_rosters(config: Dictionary) -> void:
	var enemy_source: Variant = config.get("enemy_roster")
	if enemy_source is Array:
		_parent.set("_battle_enemy_roster", (enemy_source as Array).duplicate())
	else:
		_parent.set("_battle_enemy_roster", _read_ai_enemy_roster())
	var field: Array = read_player_field()
	var roster_source: Variant = config.get("character_ids")
	if roster_source is Array:
		_parent.set("_battle_player_roster", (roster_source as Array).duplicate())
	else:
		_parent.set("_battle_player_roster", _occupied_character_ids(field))
	_parent.set("_field_engaged", false)
	update_field_engaged(field)


## 读取 AISystem 当前敌方阵容拷贝——AISystem 不可用时返回空（= 本场无胜负数据）。
func _read_ai_enemy_roster() -> Array:
	var ai: Node = _get_ai_system()
	if ai == null or not ai.has_method(&"get_enemy_roster"):
		return []
	var roster: Variant = ai.call(&"get_enemy_roster")
	if roster is Array:
		return (roster as Array).duplicate()
	return []


## 从阵位快照提取有人的角色 ID（空位 character_id = -1 跳过）。
func _occupied_character_ids(field: Array) -> Array:
	var ids: Array = []
	for entry: Variant in field:
		if not EndCheck.is_occupied(entry):
			continue
		if entry is Dictionary:
			ids.append(int((entry as Dictionary)["character_id"]))
		else:
			ids.append(int((entry as Object).get("character_id")))
	return ids


# === 费用系统 ====================================================================

## 费用系统激活——[code]CostSystem.init_for_battle(境界费用上限)[/code]。[br]
## [br][b]上限来源[/b]：RealmSystem 现读 [code]cost_per_turn[/code]（数据驱动——
## realm_table 是唯一真理来源）；取不到时回退 [constant DEFAULT_COST_PER_TURN]。[br]
## [br]CostSystem 不在树中或方法缺失时静默跳过（剥离 Autoload 的测试环境）。
func init_cost_for_battle() -> void:
	var cs: Node = _get_cost_system()
	if cs == null or not cs.has_method(&"init_for_battle"):
		return
	cs.call(&"init_for_battle", read_cost_cap())


## 战斗费用上限——RealmSystem 的 [code]cost_per_turn[/code]；无效值回退默认。
func read_cost_cap() -> int:
	var rs: Node = _get_realm_system()
	if rs != null and rs.has_method(&"get_current_property"):
		var raw: Variant = rs.call(&"get_current_property", &"cost_per_turn")
		if raw != null and int(raw) > 0:
			return int(raw)
		push_warning("CombatSystem: RealmSystem 未返回有效 cost_per_turn——回退 %d 费"
				% DEFAULT_COST_PER_TURN)
	return DEFAULT_COST_PER_TURN


## 费用系统清理——战斗结束（CostSystem 自身幂等，未开始时为 no-op）。
func clear_cost_for_battle() -> void:
	var cs: Node = _get_cost_system()
	if cs != null and cs.has_method(&"clear_for_battle_end"):
		cs.call(&"clear_for_battle_end")


# === Phase 6 END 判定 ============================================================

## 战斗结束检查——[b]返回 true 表示本场已判定结束[/b]。[br]
## [br]判定输入：敌方名册快照 + DeploymentSystem 现读阵位 + 我方名册快照 +
## 「阵位曾有人」标志。规则与「信息不足则不判」原则见 [code]combat_end_check.gd[/code]。[br]
## [br][b]只记录不执行[/b]：结果写入父节点 [code]_pending_battle_result[/code]，
## 由 [method CombatSystem.advance_phase] 在阶段簿记与信号完成后收尾。
func check_battle_end() -> bool:
	if int(_parent.get("_pending_battle_result")) != 0:
		return true
	if not bool(_parent.get("_is_active")):
		return false
	var field: Array = read_player_field()
	update_field_engaged(field)
	# 内核常量与 CombatResult 数值同源（RESULT_VICTORY=1 / RESULT_DEFEAT=2），
	# 直接写入避免二次映射（镜像枚举先例见 combat_phase_manager 的 PHASE_*）。
	var result: int = EndCheck.evaluate(
			_parent.get("_battle_enemy_roster"), field,
			_parent.get("_battle_player_roster"), bool(_parent.get("_field_engaged")))
	_parent.set("_pending_battle_result", result)
	return result != 0


## 读取 DeploymentSystem 阵位快照——不可用时返回空数组（= 无阵位信息）。
func read_player_field() -> Array:
	var ds: Node = _get_deployment_system()
	if ds != null and ds.has_method(&"get_field"):
		var field: Variant = ds.call(&"get_field")
		if field is Array:
			return field
	return []


## 累积「我方阵位曾处于有人状态」标志（只升不降——一场战斗一次）。[br]
## [br][b]为什么需要[/b]：阵位「当前全空」有两种含义——己方全灭，或本场从未布置
## 过阵位；后者不能判战败（[code]combat_end_check.gd[/code] 的信息不足原则）。[br]
## [br][b]采集点[/b]：开战快照 + 攻击结算前 + END 判定前（阵亡清位发生在这几处之后），
## 保证「开战 → 有人 → 全灭」的路径一定能被观测到。
func update_field_engaged(field: Array) -> void:
	if bool(_parent.get("_field_engaged")):
		return
	for entry: Variant in field:
		if EndCheck.is_occupied(entry):
			_parent.set("_field_engaged", true)
			return


## 结局收尾——先清待定标志再调 [code]battle_end()[/code]（防递归）。[br]
## 由父节点在 [code]advance_phase[/code] 的 phase_changed 发射之后调用；
## 无待定结果时为空操作。
func finish_pending_battle_end() -> void:
	var result: int = int(_parent.get("_pending_battle_result"))
	if result == 0:
		return
	_parent.set("_pending_battle_result", 0)
	_parent.call("battle_end", result)


# === Autoload 查找（子模块内自用）=================================================

func _get_cost_system() -> Node:
	return _autoload(&"CostSystem")


func _get_realm_system() -> Node:
	return _autoload(&"RealmSystem")


func _get_deployment_system() -> Node:
	return _autoload(&"DeploymentSystem")


func _get_ai_system() -> Node:
	return _autoload(&"AISystem")


## 以 SceneTree.root 查找 Autoload——测试环境缺该 Autoload 时返回 null（不抛错）。
func _autoload(node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath(String(node_name)))
