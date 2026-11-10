extends RefCounted
## CombatEnemyFieldState —— 敌方行动阶段的「决策输入」快照构建（纯取数）。
##
## [b]职责[/b]：把战斗侧的状态拼成 [code]AISystem.execute_turn()[/code] 决策引擎
## [b]真正会读[/b]的那组键——[code]player_chars[/code] / [code]enemy_chars[/code] /
## [code]turn[/code] / [code]ally_hp_ratio[/code] / [code]ally_low_hp_count[/code] /
## [code]ally_front_dead[/code] / [code]player_high_threat[/code]。[br]
## [br][b]为什么独立成文件[/b]：这是「读」的一侧（快照的形状），
## [code]combat_enemy_turn.gd[/code] 是「写」的一侧（结算与广播）。两者合在一个
## 文件里会同时超过单文件软上限，且它们的变更理由不同——决策引擎读什么键由 AI
## 系统决定，而结算形状由战斗侧决定。[br]
## [br][b]历史坑[/b]：此前阶段管理器构建的快照用 [code]characters[/code] 键，
## 而决策引擎读 [code]player_chars[/code] / [code]enemy_chars[/code]——真实对局里
## AI 恒拿空候选池、永远选不出目标（[method _select_target] 直接命中
## [code]available_targets.is_empty()[/code] 分支）。键名对齐是本模块存在的首要理由。[br]
## [br][b]零状态所有权[/b]：每次现读阵位与状态表，不缓存。[br]
##
## 来源: design/gdd/ai-system.md §4 决策流程、ADR-0017 §决策引擎设计、
## production/epics/combat-ui-interaction/story-002-turn-cycle.md。

## 父节点引用——CombatSystem 实例。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


## 构建决策引擎的战场快照。[br]
## [br][b]我方条目补齐 HP/防御字段[/b]：[code]DeploymentSystem.get_field()[/code] 的条目
## 只有阵位与状态（ADR-0016 §阵位数据模型），而决策引擎要读
## [code]current_hp[/code] / [code]max_hp[/code] / [code]is_alive[/code] / [code]defense[/code]——
## 缺少这些键会让 [code]char_state.is_alive[/code] 取键报错。HP 从战斗状态表现读（同源）。[br]
## [br][b]防御恒 0[/b]：玩家角色的 defense 尚无状态字段，不臆造数值——
## 按 GDD §边缘情况「0 防御时伤害 = 攻击力」处理。[br]
## [br][param p_ai] AISystem（取敌方名册）；为 null 时敌方侧为空。
func build(p_ai: Node = null) -> Dictionary:
	var roster: RefCounted = _parent.call("_get_roster_state")
	var players: Array = _player_chars(roster)
	var enemies: Array = enemy_chars(p_ai)
	return {
		"player_chars": players,
		"enemy_chars": enemies,
		"turn": int(_parent.get("_turn")),
		"ally_hp_ratio": hp_ratio(enemies),
		"ally_low_hp_count": low_hp_count(enemies),
		"ally_front_dead": front_dead(enemies),
		"player_high_threat": high_threat(players),
	}


## 敌方条目——直接用 [code]EnemyBattleState[/code] 对象（自带 HP/防御/存活字段），
## 决策引擎的 [code]_Helpers[/code] 正是按这些字段读的。[br]
## [br][b]为什么不做成字典副本[/b]：AI 的目标选择会把条目原样回传给自己，
## 用对象可以让「AI 看到的」与「AI 返回的」是同一份引用，不必再翻译一次。
static func enemy_chars(p_ai: Node) -> Array:
	if p_ai == null or not p_ai.has_method(&"get_enemy_roster"):
		return []
	var raw: Variant = p_ai.call(&"get_enemy_roster")
	return (raw as Array).duplicate() if raw is Array else []


## 我方候选条目——阵位快照 + 状态表 HP（决策引擎的目标选择读这份）。[br]
## [br][b]id 用 [code]character_id[/code][/b]：AI 的 [code]target_ids[/code] 回传的就是
## 这些条目本身，落库时按 [code]id[/code] 取角色 ID。
func _player_chars(p_roster: RefCounted) -> Array:
	var out: Array = []
	for entry: Variant in _field():
		var character_id: int = _entry_int(entry, "character_id", -1)
		if character_id < 0:
			continue
		var info: Dictionary = p_roster.call(&"read_hp", character_id)
		out.append({
			"id": character_id,
			"character_id": character_id,
			"current_hp": int(info.get("current_hp", 0)),
			"max_hp": int(info.get("max_hp", 0)),
			"atk": int(info.get("atk", 0)),
			"defense": 0,
			"is_alive": bool(p_roster.call(&"is_alive", character_id)),
			"is_taunting": _entry_bool(entry, "is_taunting", false),
		})
	return out


# === 场上态势派生（决策引擎的修正系数输入）=========================================

## 敌方整体 HP 比例——撤退判定与治疗修正的输入（空名册按 1.0 不触发撤退）。
static func hp_ratio(p_enemies: Array) -> float:
	var total_max: int = 0
	var total_hp: int = 0
	for enemy: Variant in p_enemies:
		total_max += int(_prop(enemy, "max_hp", 0))
		total_hp += int(_prop(enemy, "current_hp", 0))
	if total_max <= 0:
		return 1.0
	return float(total_hp) / float(total_max)


## 残血敌人计数（HP 比例 < 0.3——治疗技能修正 +0.5 的输入）。
static func low_hp_count(p_enemies: Array) -> int:
	var count: int = 0
	for enemy: Variant in p_enemies:
		var max_hp: int = int(_prop(enemy, "max_hp", 0))
		if max_hp <= 0:
			continue
		if float(int(_prop(enemy, "current_hp", 0))) / float(max_hp) < 0.3:
			count += 1
	return count


## 敌方前排是否全灭（防御技能修正 +0.3 的输入）。[br]
## [br][b]只统计前排条目[/b]：名册不带前排标记时视为前排（同
## [code]combat_roster_state.enemy_is_front[/code] 口径）。
static func front_dead(p_enemies: Array) -> bool:
	var seen_front: bool = false
	for enemy: Variant in p_enemies:
		if not bool(_prop(enemy, "is_front_row", true)):
			continue
		seen_front = true
		if bool(_prop(enemy, "is_alive", true)):
			return false
	return seen_front


## 我方是否处于高威胁（攻击技能修正 +0.4 的输入）。[br]
## [br][b]口径[/b]：存活人数 ≥ 2——人数优势即威胁（不做伤害量统计：
## 那需要跨回合历史，属后续 story）。
static func high_threat(p_players: Array) -> bool:
	var alive: int = 0
	for char_state: Variant in p_players:
		if bool(_prop(char_state, "is_alive", true)):
			alive += 1
	return alive >= 2


# === 读取工具 ====================================================================

## 条目字段读取（Dictionary 与 Object 通吃——AI 名册两种形态都会出现）。
static func _prop(p_entry: Variant, p_key: String, p_fallback: Variant) -> Variant:
	if p_entry is Dictionary:
		return (p_entry as Dictionary).get(p_key, p_fallback)
	if p_entry is Object:
		var raw: Variant = (p_entry as Object).get(p_key)
		return raw if raw != null else p_fallback
	return p_fallback


static func _entry_int(p_entry: Variant, p_key: String, p_fallback: int) -> int:
	return int(_prop(p_entry, p_key, p_fallback))


static func _entry_bool(p_entry: Variant, p_key: String, p_fallback: bool) -> bool:
	return bool(_prop(p_entry, p_key, p_fallback))


## 我方阵位快照——DeploymentSystem 不可用时返回空数组。
func _field() -> Array:
	var ds: Node = _autoload(&"DeploymentSystem")
	if ds == null or not ds.has_method(&"get_field"):
		return []
	var raw: Variant = ds.call(&"get_field")
	return raw if raw is Array else []


## 以 SceneTree.root 查找 Autoload——测试环境缺该 Autoload 时返回 null（不抛错）。
func _autoload(p_node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath(String(p_node_name)))
