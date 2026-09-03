extends RefCounted
## GSMBattleWrites —— 战斗域原子写入子模块（从 gsm_atomic_writes.gd 拆分）。
##
## 持有对 GSM 父节点的引用，提供战斗域第二层原子写入方法。[br]
## 每个方法写入数据后通过 [method GameStateManager._buffer_change] 进入帧末信号缓冲管线。[br]
## [br]Sprint 8 Story 8-11：从 gsm_atomic_writes.gd 拆分。

## 指向 GSM 父节点的引用。
var _gsm: Node = null


## 构造——传入 GSM 引用。
func _init(gsm: Node = null) -> void:
	_gsm = gsm


## 原子写入战斗费用上下限——仅 CostSystem 调用。[br]
## [br][b]窄范围[/b]：仅写入 battle.current_cost / battle.max_cost——不操作 battle 域其他字段。[br]
## [br][b]null 守卫[/b]：battle 非活跃时 push_warning 并返回。[br]
## [br][b]去重[/b]：同值不写入，避免无意义 [signal GameStateManager.batch_updated]。[br]
## [br]来源: ADR-0015 §GSM 第二层扩展。
func _set_battle_cost(current_cost: int, max_cost: int) -> void:
	if _gsm.battle == null:
		push_warning("GSM._set_battle_cost: 无活跃战斗，拒绝写入")
		return

	var old_current: int = _gsm.battle.get("current_cost", 0)
	var old_max: int = _gsm.battle.get("max_cost", 0)

	if old_current == current_cost and old_max == max_cost:
		return  # 值无变化——去重

	_gsm.battle.current_cost = current_cost
	_gsm.battle.max_cost = max_cost

	_gsm._buffer_change("battle.current_cost", old_current, current_cost)
	_gsm._buffer_change("battle.max_cost", old_max, max_cost)


## 原子写入战斗状态快照——仅 StatusEffectSystem 调用（战斗结束导出）。
func _set_battle_status_snapshot(snapshot: Array) -> void:
	if _gsm.battle == null:
		push_warning("GSM._set_battle_status_snapshot: 无活跃战斗，拒绝写入")
		return

	var old_snapshot: Array = _gsm.battle.get("status_snapshot", [])
	if _gsm._deep_equal(old_snapshot, snapshot):
		return  # 值无变化——去重

	_gsm.battle.status_snapshot = snapshot
	_gsm._buffer_change("battle.status_snapshot", old_snapshot, snapshot)


## 原子写入战斗阵位快照——仅 DeploymentSystem 调用（战斗结束导出）。
func _set_battle_deployment_snapshot(snapshot: Dictionary) -> void:
	if _gsm.battle == null:
		push_warning("GSM._set_battle_deployment_snapshot: 无活跃战斗，拒绝写入")
		return

	var old_snapshot: Dictionary = _gsm.battle.get("deployment_snapshot", {})
	if _gsm._deep_equal(old_snapshot, snapshot):
		return  # 值无变化——去重

	_gsm.battle.deployment_snapshot = snapshot
	_gsm._buffer_change("battle.deployment_snapshot", old_snapshot, snapshot)


## 原子写入不可用角色列表——仅 DeploymentSystem 调用。
func _set_player_unavailable_characters(data: Dictionary) -> void:
	var old: Dictionary = _gsm.player.get("unavailable_characters", {})
	if _gsm._deep_equal(old, data):
		return  # 值无变化——去重

	_gsm.player.unavailable_characters = data
	_gsm._buffer_change("player.unavailable_characters", old, data)


## 原子写入战斗绑定快照——仅 BindingManager 调用（战斗结束导出）。
func _set_battle_bindings(snapshot: Array) -> void:
	if _gsm.battle == null:
		push_warning("GSM._set_battle_bindings: 无活跃战斗，拒绝写入")
		return

	# 首次写入——battle 中尚无 bindings 键，跳过去重确保键被创建
	if not _gsm.battle.has("bindings"):
		_gsm.battle.bindings = snapshot
		_gsm._buffer_change("battle.bindings", [], snapshot)
		return

	var old: Array = _gsm.battle.get("bindings", [])
	if _gsm._deep_equal(old, snapshot):
		return  # 值无变化——去重

	_gsm.battle.bindings = snapshot
	_gsm._buffer_change("battle.bindings", old, snapshot)


## 原子写入战斗阵法快照——仅 FormationSystem 调用（战斗结束导出）。
func _set_battle_formation_snapshot(snapshot: Dictionary) -> void:
	if _gsm.battle == null:
		push_warning("GSM._set_battle_formation_snapshot: 无活跃战斗，拒绝写入")
		return

	if not _gsm.battle.has("formation_snapshot"):
		_gsm.battle.formation_snapshot = snapshot
		_gsm._buffer_change("battle.formation_snapshot", {}, snapshot)
		return

	var old: Dictionary = _gsm.battle.get("formation_snapshot", {})
	if _gsm._deep_equal(old, snapshot):
		return  # 值无变化——去重

	_gsm.battle.formation_snapshot = snapshot
	_gsm._buffer_change("battle.formation_snapshot", old, snapshot)


## 原子写入战斗阶段——仅 CombatSystem 调用。
func _set_battle_phase(phase: int) -> void:
	if _gsm.battle == null:
		push_warning("GSM._set_battle_phase: 无活跃战斗，拒绝写入")
		return

	var old_phase: int = int(_gsm.battle.get("phase", 0))
	if old_phase == phase:
		return  # 值无变化——去重

	_gsm.battle.phase = phase
	_gsm._buffer_change("battle.phase", old_phase, phase)


## 原子递增战斗回合数——仅 CombatSystem 调用。
func _increment_battle_turn() -> void:
	if _gsm.battle == null:
		push_warning("GSM._increment_battle_turn: 无活跃战斗，拒绝写入")
		return

	var old_turn: int = int(_gsm.battle.get("turn", 1))
	_gsm.battle.turn = old_turn + 1
	_gsm._buffer_change("battle.turn", old_turn, old_turn + 1)


## 原子写入战斗活跃标志——仅 CombatSystem 调用。[br]
## [br][b]active=true 时创建 battle 域[/b]：若 battle == null，初始化默认 battle 字典。[br]
## [br][b]active=false 时清理 battle 域[/b]：设为 null。[br]
## [br]来源: ADR-0008 §GSM battle.* 域写入所有权例外。
func _set_battle_active(active: bool) -> void:
	if active:
		# active=true：如果 battle 域不存在，初始化默认值
		if _gsm.battle == null:
			_gsm.battle = {
				"is_active": true,
				"phase": 0,  # CombatPhase.PREPARATION
				"turn": 1,
				"current_cost": 0,
				"max_cost": 0,
				"player_field": [],
				"enemy_field": [],
				"result": null,
			}
			_gsm._buffer_change("battle", null, _gsm.battle)
			return
		# battle 域已存在——仅更新 is_active
		var old_active: bool = bool(_gsm.battle.get("is_active", false))
		if old_active == active:
			return  # 值无变化——去重
		_gsm.battle.is_active = active
		_gsm._buffer_change("battle.is_active", old_active, active)
	else:
		# active=false：清理 battle 域（设为 null）——ADR-0008 §GSM 边界
		if _gsm.battle == null:
			push_warning("GSM._set_battle_active: 无活跃战斗，拒绝写入")
			return
		var old_battle: Dictionary = _gsm.battle
		_gsm.battle = null
		_gsm._buffer_change("battle", old_battle, null)


## 战斗开始——仅 CombatSystem 调用。Cat 2a 生命周期信号，立即发射不缓冲。
func battle_start(config: Dictionary) -> void:
	if _gsm.battle != null:
		push_warning("GSM.battle_start: 已有活跃战斗，拒绝重复调用")
		return

	_gsm.battle = {
		"config": config.duplicate(true),
		"player_snapshot": _gsm.player.duplicate(true),
		"collection_snapshot": _gsm.collection.duplicate(true),
		"snapshot_realm": _gsm.player.realm,
	}

	_gsm.battle_started.emit(config.duplicate(true))


## 战斗结束——仅 CombatSystem 调用。Cat 2a 生命周期信号，立即发射不缓冲。
func battle_end(result: Dictionary) -> void:
	if _gsm.battle == null:
		push_warning("GSM.battle_end: 没有活跃战斗，拒绝调用")
		return

	_gsm.battle = null
	_gsm.battle_ended.emit(result.duplicate(true))
