extends RefCounted
## CombatRosterOps —— 本场名册 / HP 状态表 / 战绩的读与写（从 combat_system.gd 拆分）。[br]
## [br][b]职责边界[/b]（一条线：战斗结局所依赖的角色状态）[br]
##   1. [b]开战种子[/b]：把敌我名册 + 上一场残血折成 HP 状态表（[method seed_roster_state]）；[br]
##   2. [b]取数口[/b]：HP / 存活 / 敌方名册快照 / 开战配置——战斗域[b]之外[/b]的表现层装配
##      按这几个名字取数（[method get_character_hp] / [method is_character_alive] /
##      [method get_battle_enemy_roster] / [method get_battle_config]）；[br]
##   3. [b]结束定格[/b]：本场战绩 + 我方残血回写 + 阵亡角色标记不可用
##      （[method build_battle_record]），必须在状态表清空前调用；[br]
##   4. [b]读档落位[/b]：[method restore_battle_state] —— 只改内部状态与 GSM 镜像，
##      不重放阶段入口。[br]
## [br][b]状态归属[/b]（ADR-0008 §状态单一所有者）：[code]_turn[/code] /
## [code]_battle_serial[/code] / [code]_battle_enemy_roster[/code] /
## [code]_battle_player_roster[/code] / [code]_battle_config[/code] /
## [code]_is_active[/code] / [code]_phase[/code] 仍归父节点；本模块只经
## [code]_parent.get/set[/code] 读写——测试会直接 [code]cs.get("_battle_player_roster")[/code]
## 与 [code]cs.set("_battle_config", ...)[/code]，字段搬走会让这些既有路径全断。[br]
## [br][b]为什么拆出来[/b]：这一组方法读写父节点少量状态、调 5 个既存子模块
## （状态表 / HP 回写 / 战绩累积 / 伤害落库 / 战斗接线），与阶段推进和出牌结算都没有交集；
## 而 [code]combat_system.gd[/code] 的单文件软上限（300 行）主要被它撑爆。[br]
## [br]来源: ADR-0008 §Phase 6 / §生命周期、ADR-0016 §阵位数据模型、
## GDD combat-system.md §7/§9、tech-debt DEBT-CBT-018-1 / DEBT-CBT-018-3。

## HP 跨战斗持久化子模块——[constant WRITE_UNAVAILABLE] 的出处（回写失败判别）。
const HpCarryoverScript := preload("res://src/feature/combat/combat_hp_carryover.gd")

## 阵营常量（镜像 [signal CombatSystem.character_died] 的 side 参数：0 己方 / 1 敌方）。
const SIDE_PLAYER: int = 0

## Autoload 查找器——本模块内的查找已收拢到它（唯一实现）。
const AutoloadAccess := preload("res://src/feature/combat/combat_autoload_access.gd")

## 父节点引用——CombatSystem Autoload 实例。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


# === 开战种子 ====================================================================

## 种子敌我 HP 状态表——我方阵位（模板 base_hp 回退）+ 敌方阵容快照。[br]
## [br][param config] 可带 [code]player_stats: {character_id: {current_hp, max_hp}}[/code]
## 覆盖模板值（interaction epic 的 battle_start 扩展契约；缺省走模板）。[br]
## [br][b]Sprint 18 结算回流[/b]：显式 [code]player_stats[/code] 缺省时，由
## [code]combat_hp_carryover.gd[/code] 补上上一场的残血（[code]player.character_hp[/code]）——
## 「带伤进入下一场」据此成立；持久层没有该角色时仍回退模板 [code]base_hp[/code]（满血）。[br]
## [br][b]阵亡角色警告[/b]：读回 [code]current_hp == 0[/code] 时警告，角色后续由
## DeploymentSystem.mark_unavailable 处理不可用逻辑。
func seed_roster_state(config: Dictionary) -> void:
	var stats: Variant = config.get("player_stats", {})
	var explicit: Dictionary = stats if stats is Dictionary else {}
	var persisted: Dictionary = _get_hp_carryover().call(
			&"seed_stats", _read_player_field(), explicit)
	warn_zero_hp_characters(persisted)
	_get_roster_state().call(&"seed", _read_player_field(), persisted,
			_parent.get("_battle_enemy_roster"), _get_card_system())


## 警告零 HP 角色——开战种子时调用（GDD combat-system.md §7）。[br]
## [br][b]判定规则[/b]：读回 [code]current_hp == 0[/code] 时警告，提示角色处于阵亡状态。
## [br][b]警告等级[/b]：warning 而非 error——战斗照常进行（角色上场后 HP 为 0，
## 需由 DeploymentSystem 的不可用列表拦截）。
func warn_zero_hp_characters(persisted: Dictionary) -> void:
	for character_id: Variant in persisted.keys():
		var entry: Dictionary = persisted[character_id]
		if not (entry is Dictionary):
			continue
		if int(entry.get("current_hp", 1)) == 0:
			push_warning("CombatSystem: 角色 %d 上场时 HP 为 0（阵亡状态）——如需请先通过复活机制恢复" % int(character_id))


## 订阅自身 [signal CombatSystem.character_died]——阵亡清位（幂等连接）。委托伤害落库子模块。[br]
## [br][b]为什么在战斗侧订阅自己的信号[/b]：character_died 是「谁死了」的事实广播，
## 而「把阵位清空」是战斗编排的处置职责（ADR-0008 §架构原则 #2 信号不承载逻辑）。
## CombatUI / BindingManager / DeploymentSystem 是同一信号的另外三类消费者。
func connect_death_cleanup() -> void:
	_get_damage_settlement().call(&"connect_death_cleanup")


# === 结束定格 ====================================================================

## 定格本场战绩 + 回写我方残血（Sprint 18 结算回流——必须在清表前调用）。[br]
## [br]取数：HP 状态表全量快照（[method CombatRosterState.snapshot_all]）——
##   1. 交战绩累积器定格 [code]{result, outcome, turn_count, effect_entries, player, enemy}[/code]；[br]
##   2. 交 [code]combat_hp_carryover.gd[/code] 把 [code]side == 我方 且 known[/code]
##      的条目写进 [code]player.character_hp[/code]；[br]
##   3. 阵亡角色标记不可用（DeploymentSystem.mark_unavailable）。[br]
## [br][b]回写失败要可见[/b]：持久化没写成意味着「带伤进下一场」断链——
## [code]push_error[/code]（不是 warning：这是功能失效，而 warning 在 Godot 里不打断
## 测试与 CI）。战斗结算本身照常进行，调用方不需要处理返回值。
## [br][b]返回值[/b]：只给 [method CombatSystem.battle_end] 收进 [code]rewards["record"][/code]，
## 不参与任何分支（回写成败都不改变本场结局）。
func build_battle_record(result: int) -> Dictionary:
	var entries: Array = _get_roster_state().call(&"snapshot_all")
	var written: int = int(_get_hp_carryover().call(&"write_back", entries))
	if written == HpCarryoverScript.WRITE_UNAVAILABLE:
		push_error("CombatSystem: 我方 HP 回写失败（无 GSM 入口）——"
				+ "本场残血未持久化，下一场将按模板满血开局")
	mark_dead_characters_unavailable(entries)
	return _get_battle_record().call(&"build", result, int(_parent.get("_turn")), entries)


## 标记阵亡角色为不可用——战斗结束时调用（GDD combat-system.md §7）。[br]
## [br][b]调用时机[/b]：HP 回写之后，状态表清空之前（entries 尚可用）。[br]
## [br][b]判定规则[/b]：只标记我方（side == 0）且 current_hp == 0 的角色。[br]
## [br][b]责任边界[/b]：只负责调用 DeploymentSystem.mark_unavailable，
## 是否复活由 DeploymentSystem / 事件系统处理（ADR-0016）。
func mark_dead_characters_unavailable(entries: Array) -> void:
	var ds: Node = _get_deployment_system()
	if ds == null or not ds.has_method(&"mark_unavailable"):
		return
	for raw: Variant in entries:
		if not (raw is Dictionary):
			continue
		var entry: Dictionary = raw
		if int(entry.get("side", 1)) != SIDE_PLAYER:
			continue  # 跳过敌方
		if int(entry.get("current_hp", 1)) != 0:
			continue  # 跳过存活角色
		var character_id: int = int(entry.get("character_id", -1))
		if character_id < 0:
			continue
		ds.call(&"mark_unavailable", character_id, {
			"death_turn": int(_parent.get("_turn")),
			"death_battle_id": str(int(_parent.get("_battle_serial"))),
		})


# === 取数口（战斗域之外的表现层装配用）==========================================

## 伤害落库结果读取——战斗 UI 的 hp_reader_cb 契约（[code]{current, max}[/code]）。[br]
## [br]未知角色返回 0/0（UI 侧 apply_hp 已有 max=0 除零守卫）。
func get_character_hp(character_id: int) -> Dictionary:
	return _get_roster_state().call(&"get_hp", character_id)


## 角色是否存活——出牌目标候选池的存活判定入口。[br]
## [br][b]为什么 UI 要问这里而不是自己比 HP[/b]：存活的真理来源是战斗状态表
## （[code]is_alive[/code] 在落库时与 HP 一同写入，[code]known=false[/code] 的角色
## 另有「不据 HP 判死」的既有裁决）。UI 自己拿 [code]current_hp == 0[/code] 去推，
## 会在「读不到 HP」时把活着的敌人从候选池里抹掉。[br]
## [br][b]未知角色返回 true[/b]（同 [method CombatRosterState.is_alive] 口径）——
## 不因缺数据把角色判死。
func is_character_alive(character_id: int) -> bool:
	return bool(_get_roster_state().call(&"is_alive", character_id))


## 本场敌方名册快照（只读）。[br]
## [br][b]为什么暴露快照而非 AISystem 现读[/b]：战斗 UI 建敌方角色卡要跟 END 判定
## 看同一份数据——跨回合现读 AISystem 可能已换阵容（下一场 / 测试串场）。[br]
## [br][b]返回原引用而非拷贝[/b]（既有口径）：快照在开战后不再变动，逐次深拷贝
## 只会让「本场同一份」这件事多出几个副本。
func get_battle_enemy_roster() -> Array:
	return _parent.get("_battle_enemy_roster")


## 本场开战配置副本（只读）。[br]
## [br][b]为什么暴露副本而不是现读调用方[/b]：开战配置在
## [method CombatSystem.battle_start] 时定格（[code]_battle_config[/code]），
## 存档快照要存的正是「这场仗开打时的那份」——现读探索侧只会拿到节点当前状态，
## 玩家中途换图后两者就不再是同一场仗。[br]
## [br][b]返回[/b]：配置深拷贝；未开战时为空字典。
func get_battle_config() -> Dictionary:
	return (_parent.get("_battle_config") as Dictionary).duplicate(true)


# === 读档落位 ====================================================================

## 按存档值落位本场战况——[b]读档续战专用[/b]（常规开战路径逐字不动）。[br]
## [br][b]为什么要这个方法[/b]：[method CombatSystem.battle_start] 恒定从第 1 回合的
## PREPARATION 起手，而存档里的那场仗可能停在任意阶段。读档后若不落位，玩家面对的
## 是「血量和敌人都对、但回合与阶段被重置」的半场仗——费用也一并回满。[br]
## [br][b]只动内部状态与镜像，不推进阶段[/b]：阶段入口的那些副作用（抽牌 / 结算 /
## 自动推进）不能重放——玩家已经经历过一遍了。故这里直接改内部字段 + GSM 镜像，
## 再由调用方（[code]combat_scene_resume.gd[/code]）恢复自动推进。[br]
## [br][param p_turn] 存档里的回合数（≥1）。[br]
## [param p_phase] 存档里的阶段（[enum CombatSystem.CombatPhase]；越界夹进合法区间）。[br]
## [param p_current_cost] 存档里的当前可用费用。[br]
## [param p_max_cost] 存档里的费用上限（0 = 未记录——保留 [method CombatSystem.battle_start]
## 已按境界算好的上限，不把费用系统打成 0 费）。[br]
## [br][b]返回[/b]：是否真的落位（未开战时 false——调用方据此报警）。
func restore_battle_state(p_turn: int, p_phase: int, p_current_cost: int,
		p_max_cost: int) -> bool:
	if not bool(_parent.get("_is_active")):
		push_error("CombatSystem.restore_battle_state: 没有活跃战斗，拒绝落位")
		return false
	var turn: int = maxi(p_turn, 1)
	var phase: int = clampi(p_phase, PHASE_PREPARATION, PHASE_END)
	_parent.set("_turn", turn)
	_parent.set("_phase", phase)
	_parent.call("_gsm_set_battle_turn", turn)
	_parent.call("_gsm_set_battle_phase", phase)
	if p_max_cost > 0:
		var cost_system: Node = _get_cost_system()
		if cost_system != null and cost_system.has_method(&"restore_for_battle"):
			cost_system.call(&"restore_for_battle", p_current_cost, p_max_cost)
	return true


## 阶段区间端点——镜像 [enum CombatSystem.CombatPhase]（同
## [code]combat_phase_manager.gd[/code] 的 [code]PHASE_*[/code] 先例；本模块只做夹取，
## 不判语义）。
const PHASE_PREPARATION: int = 0
const PHASE_END: int = 6


# === 委托取数（父节点的既存子模块与接缝）========================================

func _read_player_field() -> Array:
	return _parent.call("_read_player_field")


func _get_roster_state() -> RefCounted:
	return _parent.call("_get_roster_state")


func _get_hp_carryover() -> RefCounted:
	return _parent.call("_get_hp_carryover")


func _get_battle_record() -> RefCounted:
	return _parent.call("_get_battle_record")


func _get_damage_settlement() -> RefCounted:
	return _parent.call("_get_damage_settlement")


# === Autoload 查找（子模块内自用）================================================

## 以 SceneTree.root 查找 Autoload——测试环境缺该 Autoload 时返回 null（不抛错）。[br]
## [br]实现已收拢到 [code]combat_autoload_access.gd[/code]（本方法是该实现的转发口，
## 保留原名以免动调用点）。
func _autoload(node_name: StringName) -> Node:
	return AutoloadAccess.find(node_name)


func _get_deployment_system() -> Node:
	return _autoload(&"DeploymentSystem")


func _get_cost_system() -> Node:
	return _autoload(&"CostSystem")


func _get_card_system() -> Node:
	return _autoload(&"CardSystem")
