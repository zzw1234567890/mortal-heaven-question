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
## AI 决策引擎辅助子模块（Sprint 12 Story 015 拆分）。
const _Helpers = preload("res://src/feature/ai/ai_helpers.gd")


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

## 决策引擎子模块——惰性初始化（Sprint 8 Story 8-12 拆分）。
var _decision_engine: RefCounted = null

## Boss 阶段转换子模块——惰性初始化（Sprint 8 Story 8-12 拆分）。
var _boss_phases: RefCounted = null

## 阵容工厂子模块——惰性初始化（Sprint 10 Story 2 拆分）。
var _roster_factory: RefCounted = null


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
	return _get_roster_factory().create_state(template)


## 按模板 ID 创建实例——内部查找注册表后调用 [method create_state]。[br]
## [br][param template_id] 模板 ID。[br]
## [br][b]返回[/b]: EnemyBattleState 实例；未知 template_id → push_error + 返回 null。
func _create_by_id(template_id: StringName) -> Object:
	return _get_roster_factory()._create_by_id(template_id)

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
	return _get_roster_factory().create_enemy_roster(template_ids, player_realm)


## 阵位自动分配——修改 roster 中每个 EnemyBattleState 的 field_position + is_front_row。[br]
## [br]分配逻辑：[br]
##   1. 敌方仅 1~2 人 → 全部前排[br]
##   2. [code]front_slot=true[/code] 强制前排（前排优先级最高）[br]
##   3. 其余按防御降序填充前排（容量 3），溢出 + 攻击降序填充后排[br]
## [br]来源: GDD ai-system.md §3 / Story 004 AC-008~009。
func _assign_positions(roster: Array) -> void:
	_get_roster_factory()._assign_positions(roster)


## 防御降序比较器——防御高的排在前面。[br]
## [b]untyped 参数[/b]——sort_custom 传入 Variant，类型化参数可能导致运行时类型不匹配。[br]
## [b]基于 template.base_defense[/b]——AC-005 要求缩放不影响分配逻辑，故比较模板原值非实例缩放值。
func _compare_by_defense_desc(a, b) -> bool:
	return _get_roster_factory()._compare_by_defense_desc(a, b)


## 攻击降序比较器——攻击高的排在前面。[br]
## [b]untyped 参数[/b]——同上。[br]
## [b]基于 template.base_attack[/b]——同上，缩放不影响分配。
func _compare_by_attack_desc(a, b) -> bool:
	return _get_roster_factory()._compare_by_attack_desc(a, b)


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
	return _get_roster_factory()._apply_difficulty_scaling(template, player_realm)


## 对整个 roster 应用难度缩放——遍历每个 EnemyBattleState 写入缩放后属性。[br]
## 缩放在阵位分配前应用（不影响分配逻辑——分配基于 defense 原值由 template 读取，[br]
## 缩放值写入实例 max_hp/attack/defense）。
func _apply_difficulty_scaling_to_roster(roster: Array, player_realm: int) -> void:
	_get_roster_factory()._apply_difficulty_scaling_to_roster(roster, player_realm)


## 注册预配置绑定——遍历 template.preconfigured_bindings 调用 BindingManager.bind_card（AC-006~009）。[br]
## [br]仅精英/Boss 有预配置绑定（普通敌人 preconfigured_bindings 为空 → 零调用，AC-007）。[br]
## [br][param enemy] EnemyBattleState——读取 template.preconfigured_bindings。[br]
## [br]绑定不消耗费用、不占出牌机会（预配置，AC-010）。[br]
## [br]来源: ADR-0017 §关键接口 register_preconfigured_bindings / GDD ai-system.md §6。
func register_preconfigured_bindings(enemy) -> void:
	_get_roster_factory().register_preconfigured_bindings(enemy)


## 敌方角色阵亡时移除全部绑定——直接移除，不走洗回牌库流程（AC-011）。[br]
## [br][param character_id] 阵亡敌方角色 ID。[br]
## [br]来源: GDD ai-system.md §6 / ADR-0017 §敌方绑定。
func remove_enemy_bindings(character_id: int) -> void:
	_get_roster_factory().remove_enemy_bindings(character_id)


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
	return _get_decision_engine().execute_turn(field_state)


## Boss 阶段转换检查——检测 + 执行（决策引擎经 _parent.call 调用）。[br]
## [br][b]返回[/b]: true 表示触发了阶段转换（调用方应跳过后续行动）。
func _check_phase_transition(enemy, field_state: Dictionary) -> bool:
	return _get_boss_phases().check_phase_transition(enemy, field_state)


## BossPhaseMgr 查询接口——get_phase（AC-001）。[br]
## [br][b]返回[/b]: Boss 当前阶段索引。
func get_phase(enemy) -> int:
	return _get_boss_phases().get_phase(enemy)


## BossPhaseMgr 查询接口——check（AC-001）。[br]
## [br][b]返回[/b]: 待触发阶段索引（-1 = 无转换）。
func check(enemy, turn: int, hp_pct: float) -> int:
	return _get_boss_phases().check(enemy, turn, hp_pct)


## BossPhaseMgr 执行接口——transition（AC-001）。[br]
## [br][param enemy] EnemyBattleState。[br]
## [br][param phase_idx] 阶段索引。
func transition(enemy, phase_idx: int) -> void:
	_get_boss_phases().transition(enemy, phase_idx)


## 阵法部署检查——空桩（Story 003/004 集成点）。
func _check_formation_deploy(enemy, _field_state: Dictionary) -> void:
	pass  # Story 003/004 实现


# === 决策引擎辅助 ===============================================================

# 以下辅助方法已提取到 ai_helpers.gd static 子模块（Sprint 12 Story 015 拆分）。
# 保留薄委托以兼容 _parent.call() 链路与测试动态分派。

## 获取行为配置——委托给 _Helpers static 方法（Sprint 12 Story 015 拆分）。
func _get_behavior_profile(enemy) -> Resource:
	return _Helpers.get_behavior_profile(enemy)


## 检查角色是否存活——委托给 _Helpers static 方法。
func _is_alive(char_state) -> bool:
	return _Helpers.is_alive(char_state)


## 检查技能是否在冷却中——委托给 _Helpers static 方法。
func _is_on_cooldown(enemy, skill) -> bool:
	return _Helpers.is_on_cooldown(enemy, skill)


## 获取角色 HP 百分比——委托给 _Helpers static 方法。
func _get_hp_pct(char_state) -> float:
	return _Helpers.get_hp_pct(char_state)


## 检查是否为攻击类技能——委托给 _Helpers static 方法。[br]
## [b]已废弃[/b]——改用 skill_result.skill_type 直接判断，保留供外部查询。
func _is_attack_skill_by_target_type(target_type: int) -> bool:
	return _Helpers.is_attack_skill_by_target_type(target_type)


## 查找嘲讽角色——委托给 _Helpers static 方法。
func _find_taunting(targets: Array) -> Variant:
	return _Helpers.find_taunting(targets)


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


## 惰性获取决策引擎子模块（Sprint 8 Story 8-12 拆分）。
func _get_decision_engine() -> RefCounted:
	if _decision_engine == null:
		_decision_engine = load("res://src/feature/ai/ai_decision_engine.gd").new(self)
	return _decision_engine


## 惰性获取 Boss 阶段转换子模块（Sprint 8 Story 8-12 拆分）。
func _get_boss_phases() -> RefCounted:
	if _boss_phases == null:
		_boss_phases = load("res://src/feature/ai/ai_boss_phases.gd").new(self)
	return _boss_phases


## 惰性获取阵容工厂子模块（Sprint 10 Story 2 拆分）。
func _get_roster_factory() -> RefCounted:
	if _roster_factory == null:
		_roster_factory = load("res://src/feature/ai/ai_roster_factory.gd").new(self)
	return _roster_factory
