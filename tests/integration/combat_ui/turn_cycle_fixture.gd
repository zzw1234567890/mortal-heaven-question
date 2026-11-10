extends GutTest
## TurnCycleFixture —— 回合流程集成测试的共享夹具（combat-ui-interaction 002）。[br]
##
## [b]为什么抽出来[/b]：回合循环与敌方行动两侧的测试需要[b]同一份[/b]开战前置
## （真实阵位 + 真实费用 + 真实 AI 名册 + 同样的阶段推进方式）。两份各写一遍，
## 迟早一处改了另一处没改——而「两个文件的夹具不一致」在这类跨系统测试里
## 表现为「同一个功能有时过有时不过」，极难归因。[br]
##
## [b]用法[/b]：测试文件以路径继承本类（本类 extends GutTest——断言 API 由它提供），
## 在 [code]before_each[/code] / [code]after_each[/code] 里调 [method setup]
## / [method teardown]，测试体直接用 [member cs] 与各夹方法。
##
## [br]测试策略（同 test_combat_click_play_end_to_end.gd）：[code]CS_SCRIPT.new()[/code]
## 独立实例 + 真实 DeploymentSystem 阵位 + 真实 CostSystem + 真实 AISystem 名册。

const CS_SCRIPT := preload("res://src/feature/combat_system.gd")
const Economy := preload("res://src/feature/combat/combat_turn_economy.gd")
const EnemyTurn := preload("res://src/feature/combat/combat_enemy_turn.gd")
const EnemyTemplate := preload("res://assets/enemies/enemy_template.gd")
const BehaviorProfile := preload("res://assets/enemies/behavior_profile.gd")
const SkillEntry := preload("res://assets/enemies/skill_entry.gd")
const EnemyBattleState := preload("res://src/feature/ai/enemy_battle_state.gd")

## 本文件独立的角色 ID 段——不与其它测试文件夹具冲突。
const CHAR_A: int = 8301
const CHAR_B: int = 8302
const ENEMY_HP: int = 20
const ENEMY_ATK: int = 4
const COST_CAP: int = 5

var cs: Node = null
var _release_ids: Array = []
var _ai_roster_before: Array = []


# ═══════════════════════════════════════════════════════════════════════════════
# 夹具
# ═══════════════════════════════════════════════════════════════════════════════

## 造一个敌方模板（技能池只放一个攻击技，保证决策结果确定）。[br]
## [param p_cd] 技能冷却（>0 可制造「冷却中 → 无可用技能」的分支）。
func _enemy_template(p_tid: StringName, p_atk: int = ENEMY_ATK) -> Object:
	var template := EnemyTemplate.new()
	template.template_id = p_tid
	template.display_name = str(p_tid)
	template.realm = 1
	template.base_hp = ENEMY_HP
	template.base_attack = p_atk
	template.base_defense = 0
	template.front_slot = true
	var profile := BehaviorProfile.new()
	profile.aggression = 0.7
	profile.focus_fire = 0.7  # 集火 → 目标确定（HP% 最低），避免分散模式的随机性
	profile.retreat_threshold = 0.0  # 不撤退（保证「敌方一定打人」）
	template.behavior_profile = profile
	template.skill_pool = [_attack_skill()]
	return template


func _attack_skill() -> Object:
	var skill := SkillEntry.new()
	skill.skill_id = &"strike"
	skill.display_name = "斩击"
	skill.skill_type = SkillEntry.SkillType.ATTACK
	skill.base_weight = 60
	skill.cost = 0
	skill.cooldown = 0
	skill.target_type = SkillEntry.TargetType.SINGLE_ENEMY
	skill.effect_template_ids = [&"effect_basic"]
	return skill


## 构造一个敌方运行时实例（含阵位——按阵位顺序结算的输入）。[br]
## [param p_pos] 阵位索引（0-5）。
func _enemy_state(p_tid: StringName, p_pos: int, p_atk: int = ENEMY_ATK) -> Object:
	var state: Object = AISystem.create_state(_enemy_template(p_tid, p_atk))
	state.field_position = p_pos
	state.is_front_row = p_pos < 3
	return state


## 开战：我方 2 人上场 + 敌方名册 + 费用就绪。[br]
## [param p_enemies] 敌方运行时实例列表（测试自建，可控制阵位与数量）。[br]
## [param p_is_first_player] 先后手（抽牌与首回合费用的分岔开关）。[br]
## [param p_player_stats] 我方属性覆盖（空 = 10 HP / 3 ATK 的基准夹具）；
## 防御相关用例用它注入 [code]defense[/code]。
func _start(p_enemies: Array, p_is_first_player: bool = true,
		p_player_stats: Dictionary = {}) -> void:
	var ok: bool = DeploymentSystem.setup_field([CHAR_A, CHAR_B], {})
	assert_true(ok, "前置：两名角色上场成功")
	if ok:
		_release_ids.append_array([CHAR_A, CHAR_B])
	AISystem.set_enemy_roster(p_enemies)
	var stats: Dictionary = p_player_stats if not p_player_stats.is_empty() else {
		CHAR_A: {"current_hp": 10, "max_hp": 10, "atk": 3},
		CHAR_B: {"current_hp": 10, "max_hp": 10, "atk": 3},
	}
	cs.call("battle_start", {
		"enemy_roster": p_enemies,
		"character_ids": [CHAR_A, CHAR_B],
		"is_first_player": p_is_first_player,
		"player_stats": stats,
	})
	# 开局手牌注入（牌堆 → 发牌 → 手牌就绪；GDD §2 先手 4 / 后手 5）
	cs.call("set_deck_state", _deck_ids(12), [], [])
	cs.call("set_hand", [])


## 造一组牌实例 ID（供发牌/抽牌用）。
func _deck_ids(p_count: int) -> Array:
	var ids: Array = []
	for i: int in range(p_count):
		ids.append(9000 + i)
	return ids


## 推进到指定阶段（带步数上限——校验失败时不会死循环）。[br]
## 出牌/攻击声明阶段需要玩家确认标志才放行，本助手代为置位。
func _advance_to(p_phase: int) -> void:
	for i: int in range(14):
		if int(cs.call("get_current_phase")) == p_phase:
			return
		if not bool(cs.call("advance_phase")):
			cs.set("_player_confirmed_end", true)
			cs.set("_player_confirmed_attack_skip", true)
			cs.call("advance_phase")


## 我方角色当前 HP。
func _hp(p_character_id: int) -> int:
	return int(cs.call("get_character_hp", p_character_id)["current"])


## 捕获敌方行动信号。
func _capture_enemy_actions() -> Array:
	var captured: Array = []
	cs.connect("enemy_action_resolved", Callable(func(payload: Dictionary) -> void:
		captured.append(payload)))
	return captured


## 捕获回合切换信号。
func _capture_turn_started() -> Array:
	var captured: Array = []
	cs.connect("turn_started", Callable(func(payload: Dictionary) -> void:
		captured.append(payload)))
	return captured


# ═══════════════════════════════════════════════════════════════════════════════
# 生命周期（子类 before_each / after_each 调用）
# ═══════════════════════════════════════════════════════════════════════════════

## 测试前置——创建独立 CombatSystem 实例并快照全局单例状态。[br]
## [br][b]为什么是普通方法而非 [code]before_each()[/code] 覆写[/b]：GUT 会按
## 继承链调用钩子，基类若自己声明 [code]before_each[/code]，子类不调 [code]super()
## [/code] 就会漏跑；显式 [method setup] / [method teardown] 让「跑没跑」在子类里
## 一眼可见。
func setup() -> void:
	cs = CS_SCRIPT.new()
	cs.call("set_auto_advance", false)
	cs.call("set_scene_change", false)
	cs.set("resolve_cb", Callable(func(_card, _targets) -> Array:
		return []))
	_ai_roster_before = AISystem.get_enemy_roster().duplicate()
	GameStateManager.battle = null
	GameStateManager._pending_changes.clear()
	GameStateManager._flush_scheduled = false
	_release_ids.clear()


## 测试后置——清阵位 / 费用 / 锁栈 / AI 名册 / GSM 战斗域。
func teardown() -> void:
	if cs != null:
		cs.free()
		cs = null
	for cid: int in _release_ids:
		DeploymentSystem.remove_character(cid)
	_release_ids.clear()
	CostSystem.clear_for_battle_end()
	InputManager.clear_locks(&"combat_system")
	AISystem.set_enemy_roster(_ai_roster_before)
	GameStateManager.battle = null
	GameStateManager._pending_changes.clear()
	GameStateManager._flush_scheduled = false
