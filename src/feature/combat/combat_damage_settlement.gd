extends RefCounted
## CombatDamageSettlement —— 伤害落库 + 阵亡处理子模块（Sprint 18 补链 / DEBT-CBT-018-1）。[br]
## [br][b]职责[/b]：把一次伤害结算的结果落到「防御方角色状态」上，并据此驱动阵亡链路：[br]
##   1. HP 回写——经 [code]combat_roster_state.gd[/code] 写 [code]current_hp[/code] /
##      [code]is_alive[/code]（敌方写回 [code]EnemyBattleState[/code]，我方写战斗内状态表）；[br]
##   2. 阵亡广播——HP 归零且此前存活时发射 [code]character_died[/code]（Cat 2b，
##      ADR-0008 §信号分类）；[br]
## [br][b]清位由本模块订阅父节点的 character_died 完成[/b]（[method connect_death_cleanup]
## → [method on_character_died] → [code]DeploymentSystem.remove_character[/code]），
## 本模块不直接操作阵位（信号用于通知，逻辑走编排——ADR-0008 §架构原则 #2）。[br]
## [br][b]两条伤害源[/b]：[method settle_attack]（Phase 4 攻击结算）与
## [method settle_effect]（出牌效果结算），共用 [method _apply] 落库逻辑。[br]
## [br][b]信息不足时不落库[/b]：角色没有可信 HP（未种子 / 模板读不到）时，
## 回退到调用方载荷里的 [code]is_kill[/code]——与 [code]combat_end_check.gd[/code]
## 的「读不到数据不判死」原则同源。[br]
## [br]来源: ADR-0008 §Phase 4/§Phase 6、ADR-0016 §阵亡清位、GDD combat-system.md §3/§9、
## tech-debt DEBT-CBT-018-1。

## 阵营常量——镜像 [code]combat_roster_state.gd[/code]（0 己方 / 1 敌方）。
const SIDE_PLAYER: int = 0
const SIDE_ENEMY: int = 1
## 未知阵营哨兵（调用方未声明 side 时）。
const SIDE_UNKNOWN: int = -1

## 父节点引用——CombatSystem 实例。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


# === 两个伤害源 ==================================================================

## 攻击结算（Phase 4）——[method resolve_attack_queue] 发射 attack_resolved 之后调用。[br]
## [br][param entry] 攻击队列原始条目（含 target_id）。[br]
## [param payload] 刚发射的 attack_resolved 载荷（damage / is_kill）。[br]
## [b]返回[/b]: 落库结果（见 [method _apply]）。
func settle_attack(entry: Dictionary, payload: Dictionary) -> Dictionary:
	return _apply(
		int(entry.get("target_id", -1)),
		int(payload.get("damage", 0)),
		SIDE_UNKNOWN,
		bool(payload.get("is_kill", false)),
		[])


## 出牌效果结算（play_card）——遍历 CardEffectEngine.resolve 返回的结果项。[br]
## [br][b]结果项字段[/b]（宽松兼容 stub）：[code]{target_id, damage | value, is_kill,
## side, binding_card_ids}[/code]；[code]damage[/code] 缺省时读 [code]value[/code]。[br]
## [b]返回[/b]: 落库结果列表（跳过无效 target_id 的项）。
func settle_effect(results: Array) -> Array:
	var outcomes: Array = []
	for result: Variant in results:
		if not (result is Dictionary):
			continue
		var item: Dictionary = result
		var character_id: int = int(item.get("target_id", -1))
		if character_id < 0:
			push_warning("CombatSystem: 伤害结算跳过无效 target_id 的结果项")
			continue
		var damage: int = int(item.get("damage", item.get("value", 0)))
		var binding_ids: Array = item.get("binding_card_ids", [])
		if not (binding_ids is Array):
			binding_ids = []
		outcomes.append(_apply(character_id, damage,
				int(item.get("side", SIDE_UNKNOWN)),
				bool(item.get("is_kill", false)), binding_ids))
	return outcomes


## 站位清位（阵亡处置）——[method connect_death_cleanup] 在开战时订阅父节点的
## [code]character_died[/code]，本方法做实际清位：我方角色移出阵位
## （敌方阵位由 AI epic 维护）。[br]
## [br][b]签名对齐信号[/b]：[code](character_id, side, binding_card_ids)[/code]——
## 绑定卡洗回归 BindingManager（ADR-0016），此处只作透传丢弃。[br]
## [br][b]副作用[/b]：[code]remove_character[/code] 把槽位写回空位，
## Phase 6 END 的 [code]combat_end_check.gd[/code] 据此判「己方全灭 → DEFEAT」。
func on_character_died(character_id: int, side: int, _binding_card_ids: Array) -> void:
	if side != SIDE_PLAYER:
		return
	var ds: Node = _autoload(&"DeploymentSystem")
	if ds != null and ds.has_method(&"remove_character"):
		ds.call(&"remove_character", character_id)


## 订阅父节点的 character_died——阵亡清位（幂等连接）。[br]
## [br][b]为什么战斗侧订阅自己的信号[/b]：character_died 是「谁死了」的事实广播，
## 而「把阵位清空」是战斗编排的处置职责（ADR-0008 §架构原则 #2 信号不承载逻辑）。
## CombatUI / BindingManager / DeploymentSystem 是同一信号的另外三类消费者。
func connect_death_cleanup() -> void:
	if _parent == null or not _parent.has_signal(&"character_died"):
		return
	var handler := Callable(self, &"on_character_died")
	if not _parent.is_connected(&"character_died", handler):
		_parent.connect(&"character_died", handler)


# === 核心落库 ====================================================================

## 落库一次伤害并处理阵亡。[br]
## [br][param character_id] 防御方角色 ID（敌方按 AI 绑定 ID 约定派生）。[br]
## [param damage] 伤害值（负数 = 治疗，与 UI 的 damage 符号约定同源）。[br]
## [param side_hint] 调用方声明的阵营（[constant SIDE_UNKNOWN] = 由状态表/阵位推断）。[br]
## [param fallback_kill] 状态未知时的阵亡判据（载荷 is_kill）。[br]
## [param binding_ids] 载荷自带的绑定卡列表（空则现查 BindingManager）。[br]
## [br][b]返回[/b]: [code]{known, died, side, current_hp, max_hp, character_id}[/code]。
func _apply(character_id: int, damage: int, side_hint: int,
		fallback_kill: bool, binding_ids: Array) -> Dictionary:
	var state: RefCounted = _roster_state()
	var info: Dictionary = state.call(&"read_hp", character_id)
	var side: int = _resolve_side(state, character_id, side_hint, info)
	# 载荷声明击杀但没带伤害数值（旧 is_kill 桩口径）→ 按「打空当前 HP」处理，
	# 保持 is_kill=true 的既有语义不因落库改造而失效。
	var effective_damage: int = damage
	if effective_damage == 0 and fallback_kill and bool(info.get("known", false)):
		effective_damage = int(info.get("current_hp", 0))
	var outcome: Dictionary = state.call(&"apply_damage", character_id, effective_damage)
	var died: bool = bool(outcome["died"]) if bool(outcome["known"]) else fallback_kill
	outcome["side"] = side
	outcome["character_id"] = character_id
	if died:
		_emit_death(character_id, side, binding_ids)
	return outcome


## 发射 character_died——同一角色只发一次（状态表已保证 died 幂等）。[br]
## [br][b]不在这里清阵位[/b]：CombatSystem 订阅自身信号后调
## [code]DeploymentSystem.remove_character()[/code]，保证「谁死了」与「怎么处置」
## 的解耦（UI 阵亡动画 / 绑定解绑 / 阵位清空是同一条信号的三类消费者）。
func _emit_death(character_id: int, side: int, binding_ids: Array) -> void:
	var ids: Array = binding_ids.duplicate()
	if ids.is_empty():
		ids = _read_binding_ids(character_id)
	_parent.call("_emit_safe", &"character_died", [character_id, side, ids])


## 阵营推断——状态表（真理来源）> 调用方声明 > DeploymentSystem 阵位。[br]
func _resolve_side(state: RefCounted, character_id: int, side_hint: int,
		info: Dictionary) -> int:
	if bool(info.get("known", false)):
		return int(info.get("side", SIDE_PLAYER))
	if side_hint == SIDE_PLAYER or side_hint == SIDE_ENEMY:
		return side_hint
	var ds: Node = _autoload(&"DeploymentSystem")
	if ds != null and ds.has_method(&"get_character_slot"):
		if int(ds.call(&"get_character_slot", character_id)) != -1:
			return SIDE_PLAYER
	return SIDE_ENEMY


## 现查绑定卡列表——BindingManager 不可用/无该方法时返回空数组。
func _read_binding_ids(character_id: int) -> Array:
	var bm: Node = _autoload(&"BindingManager")
	if bm == null or not bm.has_method(&"get_binding_ids_by_character"):
		return []
	var ids: Variant = bm.call(&"get_binding_ids_by_character", character_id)
	return (ids as Array).duplicate() if ids is Array else []


# === 依赖查找 ====================================================================

func _roster_state() -> RefCounted:
	return _parent.call(&"_get_roster_state") as RefCounted


## 以 SceneTree.root 查找 Autoload——测试环境缺该 Autoload 时返回 null（不抛错）。
func _autoload(node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath(String(node_name)))
