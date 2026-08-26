## AISystem —— 敌方 AI 系统 Autoload（#18）。
##
## Feature 层 Autoload。负责敌方所有战斗决策。[br]
## 本文件持有 EnemyFactory 创建方法 + 模板注册表 + 阵位自动分配逻辑 +[br]
## execute_turn 决策主循环（三级智能分支 + 技能评分 + 目标选择 + 撤退判定）+[br]
## BossPhaseMgr 阶段转换内部状态机（HP/回合触发 → 行为替换 → 技能解锁/锁定 →[br]
## 冷却重置 → 回血 → boss_phase_transitioned 信号）。[br]
## [br][b]本 Story 范围[/b]（4-20）：BossPhaseMgr——check/transition/get_phase +[br]
## should_transition OR 语义 + 防重复 triggered_transitions + 击杀优先。[br]
## [b]不注册进 project.godot[/b]——待各系统实现完毕后统一注册（4-0b 终验）。[br]
## [b]后续 story[/b]：难度缩放 + 绑定注册（4-21）。[br]
## [br]来源: ADR-0017 §决策 §决策引擎设计 ② §Boss 阶段转换 / GDD ai-system.md §7/§公式 4。
extends Node
# class_name AISystem —— 不声明：Autoload 全局单例，
# 声明 class_name 会与全局名冲突，导致 AI_SCRIPT.new() 测试实例无法解析。
# 测试以 var ai: Node 持有 + 动态分派访问（同 DeploymentSystem/FormationSystem/BindingManager 先例）。

const _EnemyBattleState = preload("res://src/feature/ai/enemy_battle_state.gd")
const _EnemyTemplate = preload("res://assets/enemies/enemy_template.gd")
const _SkillEntry = preload("res://assets/enemies/skill_entry.gd")


# === 常量 ========================================================================

## 敌方前排阵位数量上限（slot 0-2）。
const FRONT_CAPACITY: int = 3

## 敌方后排阵位数量上限（slot 3-5）。
const BACK_CAPACITY: int = 3

## 敌方阵位总数（前 3 后 3）。
const TOTAL_SLOTS: int = 6

## 模板目录路径。
const TEMPLATE_DIR: String = "res://assets/enemies/"


# === 内部数据 ====================================================================

## 模板注册表——template_id → EnemyTemplate Resource。[br]
## [b]声明为无类型 Dictionary[/b]——Dictionary[StringName, EnemyTemplate] 是嵌套类型化集合，
## Godot 4.6 GDScript 不支持。类型保证由 load 入口路径维护。
var _template_registry: Dictionary = {}

## 模板已加载标志。
var _templates_loaded: bool = false

## 独立 RNG 实例（ADR-0017 §RNG——确定性种子，支持回归测试）。
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

## 敌方阵容（战斗期间持有——由 create_enemy_roster 创建）。
var _enemy_roster: Array = []

## 当前回合数。
var _current_turn: int = 0


# === 信号声明（Cat 2b）============================================================

## AI 行动执行——CombatSystem 在 Phase 6 执行 AIAction 时发射。[br]
## 载荷: (enemy_id: int, action: Dictionary)。
signal ai_action_executed(enemy_id: int, action: Dictionary)

## Boss 阶段转换——HP/回合触发阶段转换时发射。[br]
## 载荷: (enemy: Object, from_phase: int, to_phase: int)。[br]
## [b]首参无类型[/b]——EnemyBattleState 为 RefCounted，Godot 4.6 信号类型检查中
## Object 不接受 RefCounted，去除类型标注以避免 emit_signal 静默失败。
signal boss_phase_transitioned(enemy, from_phase: int, to_phase: int)

## 敌方撤退——非 Boss 敌人 HP 低于阈值且概率判定通过时发射。[br]
## 载荷: (retreated_enemy_ids: Array[int])。
signal enemy_retreated(retreated_enemy_ids: Array[int])

## 模板加载完成——load_templates 扫描完毕时发射。
signal enemy_templates_loaded()


# === 初始化 ====================================================================

func _ready() -> void:
	load_templates()


## 加载所有 EnemyTemplate Resource 到注册表。[br]
## 扫描 [code]res://assets/enemies/[/code] 目录下的所有 [code].tres[/code] 文件。[br]
## 空目录不崩溃；重复 template_id 记录 push_warning。[br]
## [br]来源: ADR-0017 §关键接口 load_templates / GDD ai-system.md §2。
func load_templates() -> void:
	_template_registry.clear()
	var dir: DirAccess = DirAccess.open(TEMPLATE_DIR)
	if dir == null:
		_templates_loaded = true
		enemy_templates_loaded.emit()
		return  # 目录不存在——空注册表
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var res_path: String = TEMPLATE_DIR + file_name
			var loaded: Resource = load(res_path)
			if loaded != null and loaded is _EnemyTemplate:
				var tid: StringName = loaded.template_id
				if _template_registry.has(tid):
					push_warning("AISystem.load_templates: 重复 template_id '%s'（文件: %s）" % [tid, res_path])
				# AC-009：Boss phase_transitions 上限 2（起始阶段 + 2 转换 = 3 阶段）
				if loaded.is_boss and (loaded.phase_transitions as Array).size() > 2:
					push_warning("AISystem.load_templates: Boss '%s' phase_transitions 超过 2 项上限（%d 项）" % [tid, (loaded.phase_transitions as Array).size()])
				_template_registry[tid] = loaded
		file_name = dir.get_next()
	dir.list_dir_end()
	_templates_loaded = true
	enemy_templates_loaded.emit()


# === EnemyFactory：模板 → 实例 ================================================

## 从模板创建 EnemyBattleState 实例——纯映射，不缩放、不分配阵位。[br]
## [br][param template] EnemyTemplate Resource。[br]
## [br][b]返回[/b]: EnemyBattleState 实例（max_hp=base_hp, attack=base_attack, defense=base_defense,
## is_alive=true, skill_cooldowns={}, current_phase_index=0, triggered_transitions=[]）。[br]
## [br]来源: ADR-0017 §关键接口 EnemyFactory / Story 004 AC-004。
func create_state(template) -> Object:
	var state = _EnemyBattleState.new()
	state.template_id = template.template_id
	state.template = template
	state.current_hp = template.base_hp
	state.max_hp = template.base_hp
	state.attack = template.base_attack
	state.defense = template.base_defense
	state.skill_cooldowns = {}
	state.is_alive = true
	state.field_position = -1
	state.is_front_row = false
	state.current_phase_index = 0
	state.triggered_transitions = []
	return state


## 按模板 ID 创建实例——内部查找注册表后调用 [method create_state]。[br]
## [br][param template_id] 模板 ID。[br]
## [br][b]返回[/b]: EnemyBattleState 实例；未知 template_id → push_error + 返回 null。
func _create_by_id(template_id: StringName) -> Object:
	if not _template_registry.has(template_id):
		push_error("AISystem: 未知 template_id '%s'" % template_id)
		return null
	return create_state(_template_registry[template_id])

# === 阵位自动分配 ================================================================

## 创建敌方战斗阵容——模板→实例 + 阵位自动分配。[br]
## [br]阵位分配规则（GDD §3 前排/后排分配规则）：[br]
##   1. 敌方仅 1~2 人 → 全部分配前排（无后排保护）[br]
##   2. [code]front_slot=true[/code] 的敌人强制前排[br]
##   3. 其余按防御降序 → 前排（前排容量 3）；攻击降序 → 后排[br]
## [br][param template_ids] 模板 ID 列表。[br]
## [br][param player_realm] 玩家当前境界（Story 004 难度缩放时使用）。[br]
## [br][b]返回[/b]: Array——元素为 EnemyBattleState（已缩放 + 已分配 field_position + is_front_row + 已注册预配置绑定）。
## [br]来源: ADR-0017 §关键接口 create_enemy_roster / GDD ai-system.md §3/§9 / Story 004 AC-005~009。
func create_enemy_roster(template_ids: Array, player_realm: int) -> Array:
	var roster: Array = []
	for tid: StringName in template_ids:
		var state = _create_by_id(tid)
		if state != null:
			roster.append(state)
	# AC-005：缩放在阵位分配前应用（不影响分配逻辑）
	_apply_difficulty_scaling_to_roster(roster, player_realm)
	_assign_positions(roster)
	# AC-006~009：预配置绑定注册（精英/Boss）
	for enemy in roster:
		register_preconfigured_bindings(enemy)
	return roster


## 阵位自动分配——修改 roster 中每个 EnemyBattleState 的 field_position + is_front_row。[br]
## [br]分配逻辑：[br]
##   1. 敌方仅 1~2 人 → 全部前排[br]
##   2. [code]front_slot=true[/code] 强制前排（前排优先级最高）[br]
##   3. 其余按防御降序填充前排（容量 3），溢出 + 攻击降序填充后排[br]
## [br]来源: GDD ai-system.md §3 / Story 004 AC-008~009。
func _assign_positions(roster: Array) -> void:
	var count: int = roster.size()
	if count == 0:
		return

	# AC-009：≤2 人全部前排
	if count <= 2:
		for i in range(count):
			var st = roster[i]
			st.field_position = i
			st.is_front_row = true
		return

	# AC-008：front_slot=true 强制前排 + 其余按防御降序→前排、攻击降序→后排
	var forced_front: Array = []
	var others: Array = []
	for i in range(roster.size()):
		var st = roster[i]
		if st.template.front_slot:
			forced_front.append(st)
		else:
			others.append(st)

	# 其余按防御降序排序（防御高→前排优先）
	others.sort_custom(_compare_by_defense_desc)

	# 前排分配：forced_front 优先 + others 填充至 FRONT_CAPACITY
	var front_slots_used: int = 0
	var front_list: Array = []
	for i in range(forced_front.size()):
		if front_slots_used < FRONT_CAPACITY:
			front_list.append(forced_front[i])
			front_slots_used += 1
	for i in range(others.size()):
		if front_slots_used < FRONT_CAPACITY:
			front_list.append(others[i])
			front_slots_used += 1

	# 后排：others 中未分配前排的，按攻击降序排序
	var back_list: Array = []
	for i in range(others.size()):
		if not front_list.has(others[i]):
			back_list.append(others[i])
	back_list.sort_custom(_compare_by_attack_desc)

	# 分配 field_position（前排 0-2，后排 3-5）
	for i in range(front_list.size()):
		front_list[i].field_position = i
		front_list[i].is_front_row = true
	for i in range(back_list.size()):
		back_list[i].field_position = FRONT_CAPACITY + i
		back_list[i].is_front_row = false


## 防御降序比较器——防御高的排在前面。[br]
## [b]untyped 参数[/b]——sort_custom 传入 Variant，类型化参数可能导致运行时类型不匹配。[br]
## [b]基于 template.base_defense[/b]——AC-005 要求缩放不影响分配逻辑，故比较模板原值非实例缩放值。
func _compare_by_defense_desc(a, b) -> bool:
	return a.template.base_defense > b.template.base_defense


## 攻击降序比较器——攻击高的排在前面。[br]
## [b]untyped 参数[/b]——同上。[br]
## [b]基于 template.base_attack[/b]——同上，缩放不影响分配。
func _compare_by_attack_desc(a, b) -> bool:
	return a.template.base_attack > b.template.base_attack


# === 查询 API ===================================================================

## 查询模板注册表大小。
func get_template_count() -> int:
	return _template_registry.size()


## 查询模板是否存在。
func has_template(template_id: StringName) -> bool:
	return _template_registry.has(template_id)


## 获取模板——不存在返回 null。
func get_template(template_id: StringName) -> Resource:
	if not _template_registry.has(template_id):
		return null
	return _template_registry[template_id]


# === Story 004：难度缩放 + 预配置绑定注册 =====================================

## 难度缩放公式——`scale = 1.0 + (player_realm - enemy_realm) × 0.3`（AC-001/002）。[br]
## 玩家境界高于敌人基准时应用，否则返回基础值（AC-003）。[br]
## [br][param template] EnemyTemplate——读取 base_hp/base_attack/base_defense/realm。[br]
## [br][param player_realm] 玩家当前境界等级。[br]
## [br][b]返回[/b]: [code]{max_hp, attack, defense}[/code]——缩放后数值。[br]
## [br]公式: `player_realm > enemy_realm → round(base × (1.0 + gap × 0.3))`，否则 base 原值。[br]
## [br]来源: ADR-0017 §关键接口 _apply_difficulty_scaling / GDD ai-system.md §9 / §公式 5。
func _apply_difficulty_scaling(template, player_realm: int) -> Dictionary:
	var enemy_realm: int = int(template.realm)
	if player_realm <= enemy_realm:
		return {"max_hp": int(template.base_hp), "attack": int(template.base_attack), "defense": int(template.base_defense)}
	var scale: float = 1.0 + (player_realm - enemy_realm) * 0.3
	return {
		"max_hp": int(round(float(template.base_hp) * scale)),
		"attack": int(round(float(template.base_attack) * scale)),
		"defense": int(round(float(template.base_defense) * scale)),
	}


## 对整个 roster 应用难度缩放——遍历每个 EnemyBattleState 写入缩放后属性。[br]
## 缩放在阵位分配前应用（不影响分配逻辑——分配基于 defense 原值由 template 读取，[br]
## 缩放值写入实例 max_hp/attack/defense）。
func _apply_difficulty_scaling_to_roster(roster: Array, player_realm: int) -> void:
	for state in roster:
		var scaled: Dictionary = _apply_difficulty_scaling(state.template, player_realm)
		state.max_hp = int(scaled["max_hp"])
		state.current_hp = state.max_hp
		state.attack = int(scaled["attack"])
		state.defense = int(scaled["defense"])


## 注册预配置绑定——遍历 template.preconfigured_bindings 调用 BindingManager.bind_card（AC-006~009）。[br]
## [br]仅精英/Boss 有预配置绑定（普通敌人 preconfigured_bindings 为空 → 零调用，AC-007）。[br]
## [br][param enemy] EnemyBattleState——读取 template.preconfigured_bindings。[br]
## [br]绑定不消耗费用、不占出牌机会（预配置，AC-010）。[br]
## [br]来源: ADR-0017 §关键接口 register_preconfigured_bindings / GDD ai-system.md §6。
func register_preconfigured_bindings(enemy) -> void:
	var template = enemy.template
	var bindings: Array = template.preconfigured_bindings
	if bindings.is_empty():
		return
	# 通过 SceneTree 查找 BindingManager（AI 不持有引用，避免循环依赖）
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		push_warning("AISystem.register_preconfigured_bindings: 无 SceneTree，跳过绑定注册")
		return
	var bm = tree.root.get_node_or_null("/root/BindingManager")
	if bm == null:
		push_warning("AISystem.register_preconfigured_bindings: BindingManager 未注册，跳过")
		return
	# character_id 用实例索引 ×10000 + 基数 100000 避免与玩家角色 ID 冲突
	var roster_idx: int = _enemy_roster.find(enemy)
	var character_id: int = 100000 + roster_idx * 10000
	# card_instance_id 用 character_id + 绑定序号保证唯一（同模板不同实例不冲突）
	var binding_idx: int = 0
	for card_template_id in bindings:
		var card_instance_id: int = character_id + binding_idx
		var result: Dictionary = bm.bind_card(
			card_instance_id,                    # card_instance_id（唯一）
			card_template_id as StringName,     # template_id
			character_id,                        # character_id
			0,                                   # slot_type=GONGFA
			"" as StringName,                     # native_owner
			"" as StringName                      # character_card_id
		)
		if not result.get("success", false):
			push_warning("AISystem.register_preconfigured_bindings: 绑定失败（card=%s, reason=%s）"
				% [card_template_id, result.get("reason", "unknown")])
		binding_idx += 1


## 敌方角色阵亡时移除全部绑定——直接移除，不走洗回牌库流程（AC-011）。[br]
## [br][param character_id] 阵亡敌方角色 ID。[br]
## [br]来源: GDD ai-system.md §6 / ADR-0017 §敌方绑定。
func remove_enemy_bindings(character_id: int) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var bm = tree.root.get_node_or_null("/root/BindingManager")
	if bm == null:
		return
	bm.remove_all_bindings(character_id)


# === 决策引擎（Story 002）======================================================

## 设置 RNG 种子（确定性测试用）。
func set_rng_seed(seed: int) -> void:
	_rng.seed = seed


## 设置敌方阵容（测试/CombatSystem 调用）。
func set_enemy_roster(roster: Array) -> void:
	_enemy_roster = roster


## 设置当前回合数。
func set_current_turn(turn: int) -> void:
	_current_turn = turn


## Phase 6 入口——CombatSystem 在敌方行动阶段调用（AC-001）。[br]
## 对每个存活敌方角色执行决策，返回行动指令列表。[br]
## [br][param field_state] 战场状态快照——{player_chars: Array, enemy_chars: Array, turn: int}。[br]
## [br][b]返回[/b]: Array——元素为 AIAction Dictionary。
## [br]来源: ADR-0017 §关键接口 execute_turn / GDD ai-system.md §4。
func execute_turn(field_state: Dictionary) -> Array:
	_current_turn = int(field_state.get("turn", 0))
	var actions: Array = []
	var retreated_ids: Array = []
	for enemy in _enemy_roster:
		if not _is_alive(enemy):
			continue
		# AC-012：撤退判定（非 Boss）
		if _check_retreat(enemy, field_state):
			retreated_ids.append(enemy)
			actions.append({"enemy_id": enemy, "skill_id": &"", "target_ids": [], "is_retreat": true})
			continue
		var action: Dictionary = _decide_action(enemy, field_state)
		actions.append(action)
	if not retreated_ids.is_empty():
		_emit_safe(&"enemy_retreated", [retreated_ids])
	return actions


## 三级智能分支分派（AC-002）。[br]
## Boss 优先 → 精英 → 普通。
func _decide_action(enemy, field_state: Dictionary) -> Dictionary:
	var template = enemy.template
	if template.is_boss:
		return _decide_boss_action(enemy, field_state)
	elif template.is_elite:
		return _decide_elite_action(enemy, field_state)
	else:
		return _decide_normal_action(enemy, field_state)


## 普通敌人决策——仅技能评估 + 目标选择（AC-002）。
func _decide_normal_action(enemy, field_state: Dictionary) -> Dictionary:
	var skill_result = _evaluate_skills(enemy, field_state)
	var target_ids = _select_target(enemy, skill_result, field_state)
	return {"enemy_id": enemy, "skill_id": skill_result.skill_id, "target_ids": target_ids, "is_retreat": false}


## 精英敌人决策——阵法部署检查 + 技能评估 + 目标选择（AC-002）。[br]
## _check_formation_deploy 钩子——Story 003/004 集成点，本 Story 为空桩。[br]
## 空桩确保分支结构完整，后续 Story 仅需填充钩子实现。
func _decide_elite_action(enemy, field_state: Dictionary) -> Dictionary:
	_check_formation_deploy(enemy, field_state)
	var skill_result = _evaluate_skills(enemy, field_state)
	var target_ids = _select_target(enemy, skill_result, field_state)
	return {"enemy_id": enemy, "skill_id": skill_result.skill_id, "target_ids": target_ids, "is_retreat": false}


## Boss 决策——阶段转换检查 + 阵法部署 + 技能评估 + 目标选择（AC-002）。[br]
## _check_phase_transition 实现——Story 003，检测 + 执行阶段转换。[br]
## 转换触发时该 Boss 本回合不产出技能行动（AC-012）。
func _decide_boss_action(enemy, field_state: Dictionary) -> Dictionary:
	var transitioned: bool = _check_phase_transition(enemy, field_state)
	if transitioned:
		# AC-012：阶段转换回合不进行其他行动
		return {"enemy_id": enemy, "skill_id": &"", "target_ids": [], "is_retreat": false}
	_check_formation_deploy(enemy, field_state)
	var skill_result = _evaluate_skills(enemy, field_state)
	var target_ids = _select_target(enemy, skill_result, field_state)
	return {"enemy_id": enemy, "skill_id": skill_result.skill_id, "target_ids": target_ids, "is_retreat": false}


## Boss 阶段转换检查——检测 + 执行（Story 003 实现）。[br]
## [br][b]流程[/b]（ADR-0017 §决策引擎设计 ②）：[br]
##   1. 仅 is_alive 时检查（击杀优先）[br]
##   2. should_transition 遍历 phase_transitions（OR 语义 + 哨兵）[br]
##   3. 触发则 transition 执行替换/解锁/冷却/回血 + 发射信号[br]
## [br][b]返回[/b]: true 表示触发了阶段转换（调用方应跳过后续行动）。
func _check_phase_transition(enemy, field_state: Dictionary) -> bool:
	# AC-007：击杀优先——仅 is_alive 时检查
	if not _is_alive(enemy):
		return false
	var template = enemy.template
	if not template.is_boss:
		return false
	var phase_transitions: Array = template.phase_transitions
	if phase_transitions.is_empty():
		return false  # 无阶段转换定义
	var hp_pct: float = _get_hp_pct(enemy)
	var turn: int = int(field_state.get("turn", 0))
	var phase_idx: int = _should_transition(enemy, phase_transitions, turn, hp_pct)
	if phase_idx < 0:
		return false
	# AC-013：所有阶段已触发 → 不再转换
	if (enemy.triggered_transitions as Array).has(phase_idx):
		return false
	_do_boss_phase_transition(enemy, phase_idx)
	return true


## should_transition 公式——遍历 phase_transitions，OR 语义 + 哨兵（AC-010/011）。[br]
## [br][param phase_transitions] Boss 阶段转换列表。[br]
## [br][param turn] 当前回合数。[br]
## [br][param hp_pct] Boss HP 百分比。[br]
## [br][b]返回[/b]: 待触发阶段索引（-1 = 不触发）。[br]
## [br]公式: `(hp_below > 0 AND hp_pct <= hp_below) OR (turn_after > 0 AND turn >= turn_after)` 且 `not triggered`。[br]
## [br]来源: GDD ai-system.md §公式 4 / Story 003 AC-010。
func _should_transition(enemy, phase_transitions: Array, turn: int, hp_pct: float) -> int:
	var triggered: Array = enemy.triggered_transitions
	for i in range(phase_transitions.size()):
		if triggered.has(i):
			continue  # 已触发
		var phase = phase_transitions[i]
		var hp_triggered: bool = phase.hp_below > 0.0 and hp_pct <= phase.hp_below
		var turn_triggered: bool = phase.turn_after > 0 and turn >= phase.turn_after
		if hp_triggered or turn_triggered:
			return i
	return -1


## 执行 Boss 阶段转换——替换行为 + 解锁/锁定技能 + 冷却重置 + 回血 + 信号（AC-002~006）。[br]
## [br][b]模板只读约定[/b]（ADR-0017）：behavior_profile/skill_pool 修改写入实例字段
## runtime_behavior_profile/runtime_skill_pool，绝不写回 template。[br]
## [br][param enemy] EnemyBattleState。[br]
## [br][param phase_idx] 待执行阶段索引。
func _do_boss_phase_transition(enemy, phase_idx: int) -> void:
	var template = enemy.template
	var phase = template.phase_transitions[phase_idx]
	# AC-008：标记防重复触发
	(enemy.triggered_transitions as Array).append(phase_idx)
	# 首次转换时初始化实例级运行时副本（深拷贝模板 skill_pool）
	if (enemy.runtime_skill_pool as Array).is_empty() and not (template.skill_pool as Array).is_empty():
		enemy.runtime_skill_pool = (template.skill_pool as Array).duplicate(true)
	# AC-002：行为配置替换（实例级，不写回模板）
	if phase.behavior_override != null:
		enemy.runtime_behavior_profile = phase.behavior_override
	# AC-003：技能解锁/锁定（实例级 runtime_skill_pool）
	var skill_pool: Array = enemy.runtime_skill_pool if not (enemy.runtime_skill_pool as Array).is_empty() else (template.skill_pool as Array)
	# skill_remove: 从技能池移除指定 ID
	for remove_id in phase.skill_remove:
		for i in range(skill_pool.size() - 1, -1, -1):
			if skill_pool[i].skill_id == remove_id:
				skill_pool.remove_at(i)
				break
	# skill_unlock: 添加新 SkillEntry 到技能池
	for new_skill in phase.skill_unlock:
		skill_pool.append(new_skill)
	# AC-004：冷却重置
	if phase.reset_cooldowns:
		enemy.skill_cooldowns.clear()
	# AC-005：转换回血
	if phase.heal_percent > 0.0:
		var heal_amount: int = int(round(float(enemy.max_hp) * phase.heal_percent))
		enemy.current_hp = mini(enemy.current_hp + heal_amount, enemy.max_hp)
	# 更新阶段索引
	enemy.current_phase_index = phase_idx + 1
	# AC-006：发射 boss_phase_transitioned 信号（经 GSM _emit_signal_safe 路由，ADR-0007）
	_emit_safe(&"boss_phase_transitioned", [enemy, phase_idx, enemy.current_phase_index])


## BossPhaseMgr 查询接口——get_phase（AC-001）。[br]
## [br][b]返回[/b]: Boss 当前阶段索引。
func get_phase(enemy) -> int:
	return int(enemy.current_phase_index)


## BossPhaseMgr 查询接口——check（AC-001）。[br]
## [br][b]返回[/b]: 待触发阶段索引（-1 = 无转换）。
func check(enemy, turn: int, hp_pct: float) -> int:
	if not _is_alive(enemy):
		return -1
	var template = enemy.template
	if not template.is_boss:
		return -1
	var phase_transitions: Array = template.phase_transitions
	if phase_transitions.is_empty():
		return -1
	return _should_transition(enemy, phase_transitions, turn, hp_pct)


## BossPhaseMgr 执行接口——transition（AC-001）。[br]
## [br][param enemy] EnemyBattleState。[br]
## [br][param phase_idx] 阶段索引。
func transition(enemy, phase_idx: int) -> void:
	if not (enemy.triggered_transitions as Array).has(phase_idx):
		_do_boss_phase_transition(enemy, phase_idx)


## 阵法部署检查——空桩（Story 003/004 集成点）。
func _check_formation_deploy(enemy, _field_state: Dictionary) -> void:
	pass  # Story 003/004 实现


## 技能评估——加权分数 + 修正系数 → 选 top 1~2 技能（AC-003~005/009/010）。[br]
## [br][b]返回[/b]: Dictionary——{skill_id: StringName, cost: int, target_type: int, skill_type: int}。[br]
## 全技能冷却/费用不足 → basic_attack 兜底。
func _evaluate_skills(enemy, field_state: Dictionary) -> Dictionary:
	var template = enemy.template
	# 优先使用实例级 runtime_skill_pool（Boss 阶段转换后修改），回退到模板
	var skill_pool: Array = enemy.runtime_skill_pool if not (enemy.runtime_skill_pool as Array).is_empty() else (template.skill_pool as Array)
	var available_budget: int = int(field_state.get("enemy_cost_budget", 3))
	var scored: Array = []
	for skill in skill_pool:
		# AC-009：冷却中 → 跳过
		if _is_on_cooldown(enemy, skill):
			continue
		# AC-010：费用不足 → 跳过
		if skill.cost > available_budget:
			continue
		var score: float = _calculate_skill_score(enemy, skill, field_state)
		scored.append({"skill": skill, "score": score})
	# AC-009/010：无可用技能 → basic_attack 兜底
	if scored.is_empty():
		return {"skill_id": &"basic_attack", "cost": 0, "target_type": _SkillEntry.TargetType.SINGLE_ENEMY, "skill_type": _SkillEntry.SkillType.ATTACK}
	# 按分数降序排序
	scored.sort_custom(_compare_by_score_desc)
	var best = scored[0]
	return {"skill_id": best.skill.skill_id, "cost": best.skill.cost, "target_type": best.skill.target_type, "skill_type": best.skill.skill_type}


## 计算技能分数——base_weight × modifier（AC-003/004）。
func _calculate_skill_score(enemy, skill, field_state: Dictionary) -> float:
	var base_weight: float = float(skill.base_weight)
	var modifier: float = _calculate_modifier(enemy, skill, field_state)
	var score: float = base_weight * modifier
	# 阵法部署为加法修正（+20 若阵法位空）
	if skill.skill_type == _SkillEntry.SkillType.FORMATION:
		var formation_slots_available: int = int(field_state.get("enemy_formation_slots_available", 0))
		if formation_slots_available > 0:
			score += 20.0
	return score


## 修正系数——治疗(+0.5 若友方残血) + 防御(+0.3 若前排阵亡) + 攻击(+0.4 若高威胁)（AC-004）。
func _calculate_modifier(enemy, skill, field_state: Dictionary) -> float:
	var modifier: float = 1.0
	var ally_low_hp_count: int = int(field_state.get("ally_low_hp_count", 0))
	var ally_front_dead: bool = bool(field_state.get("ally_front_dead", false))
	var player_high_threat: bool = bool(field_state.get("player_high_threat", false))
	# 治疗技能 + 残血友方 → +0.5
	if skill.skill_type == _SkillEntry.SkillType.HEAL and ally_low_hp_count > 0:
		modifier += 0.5
	# 防御技能 + 前排阵亡 → +0.3
	if skill.skill_type == _SkillEntry.SkillType.DEFENSE and ally_front_dead:
		modifier += 0.3
	# 攻击技能 + 高威胁 → +0.4
	if skill.skill_type == _SkillEntry.SkillType.ATTACK and player_high_threat:
		modifier += 0.4
	return modifier


## 目标选择——集火/分散/嘲讽 + 多目标类型（AC-006~008）。[br]
## 根据 skill_result.target_type 决定目标数量。[br]
## - SELF → 返回空（由 CombatSystem 处理自身）[br]
## - ALL_ENEMY / ALL_ALLIES → 返回全部可用目标[br]
## - SINGLE_ENEMY / ALLY → 走集火/分散/嘲讽逻辑[br]
## [br][b]嘲讽限制仅对攻击类技能生效[/b]（skill_type==ATTACK）——
## 非攻击类（UTILITY/HEAL/DEFENSE/FORMATION）可绕过嘲讽（AC-008 边缘情况）。
func _select_target(enemy, skill_result: Dictionary, field_state: Dictionary) -> Array:
	var target_type: int = int(skill_result.get("target_type", _SkillEntry.TargetType.SINGLE_ENEMY))
	# SELF → 空目标列表（CombatSystem 处理）
	if target_type == _SkillEntry.TargetType.SELF:
		return []
	var player_chars: Array = field_state.get("player_chars", [])
	var available_targets: Array = []
	for char_state in player_chars:
		if _is_alive(char_state):
			available_targets.append(char_state)
	# ALL_ENEMY → 全部可用目标
	if target_type == _SkillEntry.TargetType.ALL_ENEMY:
		return available_targets
	# ALL_ALLIES → 友方目标（field_state.enemy_chars 中存活者）
	if target_type == _SkillEntry.TargetType.ALL_ALLIES:
		var enemy_chars: Array = field_state.get("enemy_chars", [])
		var allies: Array = []
		for ally in enemy_chars:
			if _is_alive(ally):
				allies.append(ally)
		return allies
	if available_targets.is_empty():
		return []
	# AC-008：嘲讽强制目标（仅攻击类技能受嘲讽限制——非攻击可绕过）
	var skill_type: int = int(skill_result.get("skill_type", _SkillEntry.SkillType.ATTACK))
	if skill_type == _SkillEntry.SkillType.ATTACK:
		var taunting = _find_taunting(available_targets)
		if taunting != null:
			return [taunting]
	# AC-006：集火模式（focus_fire>0.5）→ HP% 最低
	var behavior = _get_behavior_profile(enemy)
	if behavior != null and behavior.focus_fire > 0.5:
		var target = _select_focus_fire_target(available_targets)
		return [target]
	# AC-007：分散模式 → 加权随机
	var target = _select_spread_target(available_targets)
	return [target]


## 集火模式——选择 HP% 最低的目标；同 HP% → 防御最低（AC-006）。
func _select_focus_fire_target(targets: Array) -> Variant:
	var best = null
	var best_hp_pct: float = 2.0  # 超出范围确保首次赋值
	for target in targets:
		var hp_pct: float = _get_hp_pct(target)
		if hp_pct < best_hp_pct or (hp_pct == best_hp_pct and best != null and target.defense < best.defense):
			best = target
			best_hp_pct = hp_pct
	return best


## 分散模式——加权随机，残血角色权重 ×2（AC-007）。
func _select_spread_target(targets: Array) -> Variant:
	var weights: Array = []
	var total_weight: float = 0.0
	for target in targets:
		var w: float = 1.0
		if _get_hp_pct(target) < 0.3:
			w = 2.0
		weights.append(w)
		total_weight += w
	var roll: float = _rng.randf() * total_weight
	var cumulative: float = 0.0
	for i in range(targets.size()):
		cumulative += weights[i]
		if roll <= cumulative:
			return targets[i]
	return targets[targets.size() - 1]


## 撤退判定——非 Boss + ally_hp_ratio < retreat_threshold → 50% 概率（AC-012）。
func _check_retreat(enemy, field_state: Dictionary) -> bool:
	var template = enemy.template
	if template.is_boss:
		return false
	var behavior = _get_behavior_profile(enemy)
	if behavior == null or behavior.retreat_threshold <= 0.0:
		return false
	var ally_hp_ratio: float = float(field_state.get("ally_hp_ratio", 1.0))
	if ally_hp_ratio >= behavior.retreat_threshold:
		return false
	return _rng.randf() < 0.5


# === 决策引擎辅助 ===============================================================

## 获取行为配置——优先实例级 runtime_behavior_profile（Boss 阶段转换后替换），[br]
## 回退到 template.behavior_profile。避免写回模板（ADR-0017 只读约定）。
func _get_behavior_profile(enemy) -> Resource:
	if enemy.runtime_behavior_profile != null:
		return enemy.runtime_behavior_profile
	return enemy.template.behavior_profile


## 检查角色是否存活。
func _is_alive(char_state) -> bool:
	return char_state != null and char_state.is_alive


## 检查技能是否在冷却中。
func _is_on_cooldown(enemy, skill) -> bool:
	if skill.cooldown <= 0:
		return false
	var cooldowns: Dictionary = enemy.skill_cooldowns
	return int(cooldowns.get(skill.skill_id, 0)) > 0


## 获取角色 HP 百分比。
func _get_hp_pct(char_state) -> float:
	if char_state.max_hp <= 0:
		return 0.0
	return float(char_state.current_hp) / float(char_state.max_hp)


## 检查是否为攻击类技能——仅攻击类受嘲讽限制（AC-008 边缘情况）。[br]
## 非攻击类（UTILITY/HEAL/DEFENSE/FORMATION）可绕过嘲讽作用于其他目标。[br]
## [br][b]已废弃[/b]——改用 skill_result.skill_type 直接判断，保留供外部查询。
func _is_attack_skill_by_target_type(target_type: int) -> bool:
	return target_type == _SkillEntry.TargetType.SINGLE_ENEMY or target_type == _SkillEntry.TargetType.ALL_ENEMY


## 查找嘲讽角色。
func _find_taunting(targets: Array) -> Variant:
	for target in targets:
		if target.get("is_taunting", false):
			return target
	return null


## 分数降序比较器。
func _compare_by_score_desc(a, b) -> bool:
	return a.score > b.score


## Cat 2b 信号安全发射——经 GSM._emit_signal_safe 路由（ADR-0007 信号链深度追踪）。
func _emit_safe(signal_name: StringName, args: Array) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		callv("emit_signal", [signal_name] + args)
		return
	var gsm = tree.root.get_node_or_null("/root/GameStateManager")
	if gsm != null and gsm.get_script().has_method("_emit_signal_safe"):
		gsm.get_script()._emit_signal_safe(self, signal_name, args)
	else:
		var call_args: Array = [signal_name]
		call_args.append_array(args)
		callv("emit_signal", call_args)
