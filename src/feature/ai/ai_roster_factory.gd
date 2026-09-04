extends RefCounted
## AIRosterFactory —— 敌方阵容工厂子模块（从 ai_system.gd 拆分）。
##
## 持有对 AISystem 父节点的引用，通过它访问 _template_registry / _enemy_roster /
## FRONT_CAPACITY / BACK_CAPACITY 常量 / _EnemyBattleState / _EnemyTemplate 等状态和资源。
##
## [br]来源: ADR-0017 §关键接口 EnemyFactory / GDD ai-system.md §3/§9。
## [br]Sprint 10 Story 2：从 ai_system.gd 拆分。

const _EnemyBattleState = preload("res://src/feature/ai/enemy_battle_state.gd")
const _EnemyTemplate = preload("res://assets/enemies/enemy_template.gd")

## 父节点引用——AISystem Autoload 实例。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


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
	var registry: Dictionary = _parent.get("_template_registry")
	if not registry.has(template_id):
		push_error("AISystem: 未知 template_id '%s'" % template_id)
		return null
	return create_state(registry[template_id])


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
	var front_capacity: int = _parent.get("FRONT_CAPACITY")
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
		if front_slots_used < front_capacity:
			front_list.append(forced_front[i])
			front_slots_used += 1
	for i in range(others.size()):
		if front_slots_used < front_capacity:
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
		back_list[i].field_position = front_capacity + i
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
	var roster: Array = _parent.get("_enemy_roster")
	var roster_idx: int = roster.find(enemy)
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
