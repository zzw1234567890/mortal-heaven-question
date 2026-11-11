extends RefCounted
## CombatEnemyTurn —— 敌方回合执行与结算（回合流程第二块的核心）。
##
## [b]职责[/b]：把 AISystem 的「决策」变成「可观测的结算」——[br]
##   1. 构建 AI 的战场快照（[code]player_chars[/code] / [code]enemy_chars[/code]
##      等决策引擎真正会读的键）；[br]
##   2. 问 [code]AISystem.execute_turn()[/code] 要行动指令；[br]
##   3. 按敌方阵位顺序（[code]field_position[/code] 升序）逐个结算——解析目标 →
##      算伤害 → 落库（复用 [code]combat_damage_settlement.gd[/code]）；[br]
##   4. 每次行动发射 [code]enemy_action_resolved[/code]——选中谁 / 造成多少 / 是否击杀。[br]
## [br][b]为什么需要本模块[/b]：[code]execute_turn()[/code] 此前只返回行动指令列表就被
## 丢弃了——敌方「决策了但从不落库」，玩家看不到任何敌方伤害；且阶段管理器构建的
## 快照用 [code]characters[/code] 键，而决策引擎读的是 [code]player_chars[/code] /
## [code]enemy_chars[/code]，真实对局里 AI 恒拿空候选池、永远选不出目标。
## 本模块同时补上这两段断路。[br]
## [br][b]按阵位顺序而非 AI 返回顺序[/b]：AI 的返回顺序是「名册数组顺序」，与玩家
## 看到的阵位排布可以不同；按 [code]field_position[/code] 升序重排后结算顺序与画面
## 顺序一致（玩家能照着阵位从上往下读战报）。[br]
## [br][b]信息不足不臆造[/b]：目标 ID 判不出 / 角色无 HP 数据时不落库，载荷里如实
## 标注 [code]known=false[/code]（同 [code]combat_roster_state.gd[/code] 口径）。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]——敌方回合是阶段进入时的一次性执行。[br]
##
## 来源: design/gdd/ai-system.md §4 决策流程、design/gdd/combat-system.md §阶段5、
## ADR-0008 §Phase 5、ADR-0017 §关键接口 execute_turn、
## production/epics/combat-ui-interaction/story-002-turn-cycle.md。

## 战场状态表（AI 快照的 HP/ATK/防御取数来源——与落库侧同源）。
const RosterStateScript := preload("res://src/feature/combat/combat_roster_state.gd")
## 固定值防御结算纯函数（max(0, 伤害 − DEF)）。
const DefenseRules := preload("res://src/feature/combat/combat_defense_rules.gd")

## 阵位未知哨兵——排到末尾（与 [code]combat_caster_rules.gd[/code] 同口径）。
const POSITION_UNKNOWN: int = 1 << 30

## 行动类型标记（载荷 [code]action[/code] 字段——表现层据此选动画/音效）。
const ACTION_SKILL: StringName = &"skill"
const ACTION_RETREAT: StringName = &"retreat"
const ACTION_NONE: StringName = &"none"

## 父节点引用——CombatSystem 实例。
var _parent: Node = null

## 战场快照构建器——惰性创建（combat_enemy_field_state.gd）。
var _field_state: RefCounted = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


## 敌方回合完整入口——[code]CombatPhaseManager.enter_phase(ENEMY_TURN)[/code] 调用。[br]
## [br][b]返回[/b]: Array——每次行动的结算载荷（每条对应一次
## [code]enemy_action_resolved[/code] 发射；详见 [method resolve]）。
func run() -> Array:
	var ai: Node = _autoload(&"AISystem")
	if ai == null or not ai.has_method(&"execute_turn"):
		return []
	var raw: Variant = ai.call(&"execute_turn", build_field_state(ai))
	var actions: Array = raw if raw is Array else []
	return resolve(actions)


## 行动指令列表 → 逐条结算（按阵位顺序）。[br]
## [br][param p_actions] [code]AISystem.execute_turn()[/code] 的返回。
func resolve(p_actions: Array) -> Array:
	var settled: Array = []
	for action: Variant in sorted_actions(p_actions):
		if action is Dictionary:
			settled.append(_resolve_action(action))
	return settled


## 行动列表 → 按敌方阵位顺序重排（不改入参）。[br]
## [br][b]稳定排序[/b]：缺 [code]field_position[/code] 的条目排末尾且保持相对次序——
## 桩数据与真实 [code]EnemyBattleState[/code] 都能处理。
static func sorted_actions(p_actions: Array) -> Array:
	var copy: Array = p_actions.duplicate()
	copy.sort_custom(func(a: Variant, b: Variant) -> bool:
		return _position_of(a) < _position_of(b))
	return copy


## 构建 AI 决策引擎的战场快照——委托 [code]combat_enemy_field_state.gd[/code]。[br]
## [br][b]为什么拆出去[/b]：快照是「读」的一侧（决策引擎读哪些键、我方条目要补
## 哪些字段），结算是「写」的一侧（落库与广播）；合在本文件会同时超过单文件软上限，
## 且两者的变更理由不同——前者由 AI 系统的读取面决定，后者由战斗侧决定。[br]
## [br][param p_ai] AISystem（取敌方名册）；为 null 时敌方侧为空。
func build_field_state(p_ai: Node = null) -> Dictionary:
	return _get_field_state().call(&"build", p_ai)


## 战场快照构建器——惰性创建。
func _get_field_state() -> RefCounted:
	if _field_state == null:
		_field_state = preload("res://src/feature/combat/combat_enemy_field_state.gd").new(_parent)
	return _field_state


## 单条行动的结算——目标解析 → 伤害落库 → debuff 施加 → 发射观测信号。[br]
## [br][b]返回[/b]: 载荷 [code]{enemy_id, action, target_id, damage, is_kill,
## known, hp_after}[/code]。
func _resolve_action(p_action: Dictionary) -> Dictionary:
	var enemy_id: int = _enemy_id_of(p_action.get("enemy_id"))
	# 撤退行动——不造成伤害，如实标注（GDD §4 非 Boss 残血撤退）。
	if bool(p_action.get("is_retreat", false)):
		return _emit_result(enemy_id, ACTION_RETREAT, -1, 0, false, false, 0)
	var target_id: int = _target_id_of(p_action)
	if target_id < 0:
		# 无可作用目标（我方全灭 / 目标信息缺失）——发一条 none 记录，
		# 保持「每次行动都有可观测结果」的契约，而不是静默跳过。
		return _emit_result(enemy_id, ACTION_NONE, -1, 0, false, false, 0)
	if _target_already_dead(target_id):
		# 目标已被同回合先手击杀——不再对尸体落库（否则会飘出一次不存在的伤害），
		# 也不让阵亡角色在后续播报里再次出场。发 none 记录保持每次行动可观测。
		return _emit_result(enemy_id, ACTION_NONE, -1, 0, false, true, 0)
	var damage: int = _damage_of(p_action.get("enemy_id"), target_id, p_action)
	var outcome: Dictionary = _apply_damage(target_id, damage)
	# 施加 debuff（敌方行动带 debuff_config 时）
	_apply_debuff_from_action(p_action, target_id, enemy_id)
	return _emit_result(enemy_id, ACTION_SKILL, target_id, damage,
			bool(outcome.get("died", false)), bool(outcome.get("known", false)),
			int(outcome.get("current_hp", 0)))


## 伤害落库——经 [code]combat_damage_settlement.gd[/code]（唯一写 HP 的路径）。[br]
## [br][b]side 交给状态表推断[/b]（[code]SIDE_UNKNOWN[/code]）：目标在读得到的角色
## 一律以状态表的 side 为准——这里不硬写「我方」，那会在读不到状态时把伤害记错阵营。
func _apply_damage(p_target_id: int, p_damage: int) -> Dictionary:
	var settlement: Variant = _parent.call("_get_damage_settlement")
	return settlement.call(&"settle_attack",
			{"target_id": p_target_id, "attacker_id": -1},
			{"damage": p_damage, "is_kill": false})


## 伤害取数——[code]max(0, 技能威力/攻击力 − 目标防御)[/code]。[br]
## [br][b]增强[/b]：支持威力系数 [code]power_multiplier[/code]——
## 技能实际伤害 = attack × power_multiplier（Story 敌人技能池补齐）。[br]
## [br][b]与攻击声明路径的区别[/b]：本路径按下限 0 结算（允许高防完全免伤），
## 攻击声明路径保留 [code]max(1, ...)[/code] 保底；两套口径并存的原因写在
## [code]combat_defense_rules.gd[/code] 与 GDD §公式「玩家防御字段」。[br]
## [br][b]顺序[/b]：固定值 DEF 先减，百分比减伤后乘算（本路径目前没有百分比来源，
## 故只执行第一步）。[br]
## [br][b]为什么不用 [code]calculate_damage[/code][/b]：那条路径含境界压制与百分比
## 减伤，需要攻防双方境界与减伤来源（[code]combat_attack_coverage.gd[/code] 那套），
## 属攻击声明阶段的口径。[br]
## [br][b]拿不到攻击力时返回 0[/b]：不臆造伤害（0 伤害落库是无害空操作，
## 载荷里的 [code]known[/code] 会如实反映「没打成」）。
func _damage_of(p_enemy: Variant, p_target_id: int, p_action: Dictionary) -> int:
	var atk: int = _attack_of(p_enemy)
	# 降攻 debuff——攻击力按状态表读（已含 debuff 修正）
	var enemy_id: int = _enemy_id_of(p_enemy)
	if enemy_id >= 0:
		var roster: Variant = _parent.call("_get_roster_state")
		var debuffed_atk: int = int(roster.call(&"get_atk", enemy_id))
		if debuffed_atk > 0 or _roster_is_known(roster, enemy_id):
			atk = debuffed_atk
	if atk <= 0:
		return 0
	# 威力系数——AI 侧传递 power_multiplier，缺省 1.0
	var power_mult: float = float(p_action.get("power_multiplier", 1.0))
	var base: int = int(atk * power_mult)
	# 技能自带威力（AI 侧给了就以它为准，缺省回退攻击力 × 威力系数）
	var declared: int = int(p_action.get("damage", 0))
	var final_base: int = declared if declared > 0 else base
	return DefenseRules.apply_flat(final_base, _defense_of(p_target_id))


## 敌方攻击力——优先读对象自带的 [code]attack[/code]（[code]EnemyBattleState[/code]），
## 回退到状态表按派生 ID 现读。
func _attack_of(p_enemy: Variant) -> int:
	if p_enemy is Object:
		var raw: Variant = (p_enemy as Object).get("attack")
		if raw != null:
			return maxi(int(raw), 0)
	if p_enemy is Dictionary:
		return maxi(int((p_enemy as Dictionary).get("attack", 0)), 0)
	return 0


## 目标防御——读战斗状态表（[code]CombatRosterState[/code] 的 [code]defense[/code]）。
## [br][b]默认 0[/b]：未注入 [code]player_stats.defense[/code] 的角色按 0 处理，
## 不臆造防御数字；[b]未知角色[/b]的 [code]read_hp[/code] 同样返回 0。
## 防御力已受降防 debuff 修正（debuff → 防御减免 → 减伤比例）。
func _defense_of(p_target_id: int) -> int:
	var roster: Variant = _parent.call("_get_roster_state")
	return int(roster.call(&"get_defense", p_target_id))


## 目标是否已在本次结算中被击杀——只在 [code]known=true[/code] 时判死，
## 读不到 HP 的角色仍可被攻击（信息不足不臆造，同状态表口径）。
func _target_already_dead(p_target_id: int) -> bool:
	var roster: Variant = _parent.call("_get_roster_state")
	var info: Dictionary = roster.call(&"read_hp", p_target_id)
	return bool(info.get("known", false)) and not bool(info.get("is_alive", true))


## 目标角色 ID——AI 回传的是目标条目本身（我方快照字典），取其
## [code]id[/code] / [code]character_id[/code]；也兼容直接给整数的桩数据。
func _target_id_of(p_action: Dictionary) -> int:
	var raw: Variant = p_action.get("target_ids", [])
	if not (raw is Array) or (raw as Array).is_empty():
		var single: int = int(p_action.get("target_id", -1))
		return single
	var first: Variant = (raw as Array)[0]
	if first is Dictionary:
		var dict: Dictionary = first
		var cid: int = int(dict.get("id", dict.get("character_id", -1)))
		return cid
	if first is int or first is float:
		return int(first)
	return -1


## 敌方角色的稳定整数 ID——按「开战名册快照下标 ×步长 + 基数」派生，
## 与 [code]combat_roster_state.gd[/code] 落键同源（同一敌人两处 ID 必须一致，
## 否则 UI 拿载荷里的 ID 去读 HP 会恒读 0/0）。[br]
## [br][b]按身份匹配[/b]：[code]EnemyBattleState[/code] 自身不持 character_id，
## 只能回到「它在名册里排第几」。名册快照是浅拷贝（对象共享），身份匹配可靠。[br]
## [br][b]返回 -1[/b]：匹配不上（外部直接构造的行动列表）——不编造 ID。
func _enemy_id_of(p_enemy: Variant) -> int:
	var roster: Variant = _parent.call("get_battle_enemy_roster")
	if not (roster is Array):
		return -1
	var list: Array = roster
	for idx: int in range(list.size()):
		if list[idx] == p_enemy:
			return RosterStateScript.enemy_id_of(list[idx], idx)
	return -1


## 发射 [code]enemy_action_resolved[/code] 并返回同一份载荷。[br]
## [br][b]返回既是「回执」也是「广播」[/b]：调用方（测试 / 战报日志）拿到与订阅方
## 完全一致的载荷，不必再解析信号。
func _emit_result(p_enemy_id: int, p_action: StringName, p_target_id: int,
		p_damage: int, p_died: bool, p_known: bool, p_hp_after: int) -> Dictionary:
	var payload: Dictionary = {
		"enemy_id": p_enemy_id,
		"action": p_action,
		"target_id": p_target_id,
		"damage": p_damage,
		"is_kill": p_died,
		"known": p_known,
		"hp_after": p_hp_after,
	}
	_parent.call("_emit_safe", &"enemy_action_resolved", [payload])
	return payload


## 施加 debuff——从敌方行动载荷中解析 debuff_config 并施加到目标。[br]
## [br][param p_action] AI 行动载荷（含 debuff_config）。[br]
## [param p_target_id] 目标角色 ID。[br]
## [param p_source_id] 施加者角色 ID（敌方）。
func _apply_debuff_from_action(p_action: Dictionary, p_target_id: int, p_source_id: int) -> void:
	var debuff_cfg: Variant = p_action.get("debuff_config")
	if debuff_cfg == null:
		return
	if not (debuff_cfg is Object):
		return
	var cfg: Object = debuff_cfg as Object
	var debuff_type: int = int(cfg.debuff_type) if _has_property(cfg, &"debuff_type") else -1
	var duration: int = int(cfg.duration) if _has_property(cfg, &"duration") else 0
	var amount: int = int(cfg.amount) if _has_property(cfg, &"amount") else 0
	if debuff_type < 0 or amount <= 0:
		return
	var roster: Variant = _parent.call("_get_roster_state")
	roster.call(&"apply_debuff", p_target_id, debuff_type, duration, amount, p_source_id)


## 查询角色是否有可信 HP 数据（用于判断是否按状态表读 ATK）。
func _roster_is_known(p_roster: Variant, p_character_id: int) -> bool:
	if not (p_roster is RefCounted):
		return false
	return bool(p_roster.call(&"is_known", p_character_id))


## 属性存在性判定——Resource/Object 上用 [method Object.get] 会推 engine error，
## 故先用属性列表判定。
static func _has_property(p_object: Object, p_name: StringName) -> bool:
	for prop: Dictionary in p_object.get_property_list():
		if StringName(str(prop.get("name", ""))) == p_name:
			return true
	return false


# === 读取工具 ====================================================================

## 条目字段读取（Dictionary 与 Object 通吃——AI 名册两种形态都会出现）。
static func _prop(p_entry: Variant, p_key: String, p_fallback: Variant) -> Variant:
	if p_entry is Dictionary:
		return (p_entry as Dictionary).get(p_key, p_fallback)
	if p_entry is Object:
		var raw: Variant = (p_entry as Object).get(p_key)
		return raw if raw != null else p_fallback
	return p_fallback


## 条目阵位读取——行动条目的 [code]enemy_id[/code] 指向敌人本身，故先取出该引用
## 再读它的 [code]field_position[/code]（也要兼容行动条目自带阵位的桩数据）。
static func _position_of(p_action: Variant) -> int:
	if not (p_action is Dictionary):
		return POSITION_UNKNOWN
	var action: Dictionary = p_action
	if action.has("field_position"):
		return int(action["field_position"])
	var raw: Variant = _prop(action.get("enemy_id"), "field_position", POSITION_UNKNOWN)
	return int(raw)


## 以 SceneTree.root 查找 Autoload——测试环境缺该 Autoload 时返回 null（不抛错）。
func _autoload(p_node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath(String(p_node_name)))
