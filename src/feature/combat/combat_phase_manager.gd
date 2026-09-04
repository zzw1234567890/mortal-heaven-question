extends RefCounted
## CombatPhaseManager —— 战斗阶段编排子模块（从 combat_system.gd 拆分）。
##
## 持有对 CombatSystem 父节点的引用，通过它访问 _phase / _turn / _is_active /
## _auto_advance_enabled / _attack_queue / _hand / _deck / _discard_pile / _rng 等
## 状态字段以及 _get_status_effect_system / _get_cost_system / _get_deployment_system /
## _get_ai_system / _get_card_cost / advance_phase 等方法。
##
## [br]来源: ADR-0008 §7 阶段状态机 §阶段转换验证矩阵 §子系统编排顺序。
## [br]Sprint 9 Story 8：从 combat_system.gd 拆分。

## CombatPhase 枚举值（避免依赖父节点枚举）。
const PHASE_PREPARATION: int = 0
const PHASE_DRAW: int = 1
const PHASE_PLAY: int = 2
const PHASE_ATTACK_DECLARATION: int = 3
const PHASE_ATTACK_RESOLUTION: int = 4
const PHASE_ENEMY_TURN: int = 5
const PHASE_END: int = 6

## 父节点引用——CombatSystem Autoload 实例。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


## 计算下一阶段——END(6) 回绕到 PREPARATION(0)，其余 +1。
func compute_next_phase(current: int) -> int:
	if current >= PHASE_END:
		return PHASE_PREPARATION
	return current + 1


## 阶段转换验证矩阵（ADR-0008 §验证矩阵）。[br]
## [br]无条件推进：0→1, 1→2, 4→5, 5→6, 6→0。[br]
## [br]条件推进：2→3（player_confirmed_end || timer_exceeded || hand_empty && !can_afford_any），[br]
## 3→4（all_characters_targeted || player_confirmed_skip || attack_queue.is_empty()）。
func validate_transition(from: int, _to: int) -> bool:
	match from:
		PHASE_PLAY:
			# AC-006：出牌→攻击声明
			return (_parent.get("_player_confirmed_end")
				or _parent.get("_phase_timer_exceeded")
				or (_parent.get("_hand").is_empty() and not _parent.call("_can_afford_any_card")))
		PHASE_ATTACK_DECLARATION:
			# AC-007/012：攻击声明→结算——空队列空真自动推进
			return (_parent.call("_all_characters_targeted")
				or _parent.get("_player_confirmed_attack_skip")
				or _parent.get("_attack_queue").is_empty())
		_:
			# AC-005：0→1, 1→2, 4→5, 5→6, 6→0 无条件
			return true


## 阶段入口——按固定顺序调用子系统（ADR-0008 §子系统编排顺序）。[br]
## [br]Sprint 8 Story 003：接线 StatusEffectSystem / CostSystem / DeploymentSystem。
func enter_phase(phase: int) -> void:
	match phase:
		PHASE_PREPARATION:
			# 1. 状态效果 tick
			_tick_status_effects()
			# 2. 触发"回合开始"效果（CardEffectEngine 接线属后续 Sprint）
			_schedule_auto_advance()
		PHASE_DRAW:
			# 1. 计算抽牌数量（基础 2 + 修正）
			var draw_count: int = _calculate_draw_count()
			# 2. 从牌库抽牌（AC-013 牌库抽空返还）
			_parent.call("_draw_cards", draw_count)
			# 3. 触发"抽牌时"效果（CardEffectEngine 接线属后续 Sprint）
			_schedule_auto_advance()
		PHASE_PLAY:
			# 玩家主动阶段——不自动推进，等待 confirm_end_turn() 或超时
			_parent.set("_phase_timer_exceeded", false)
		PHASE_ATTACK_DECLARATION:
			# 玩家主动阶段——不自动推进，等待 confirm_attack_targets()
			# AC-012：空队列空真——_validate_transition 已放行，但仍需手动调用 advance_phase
			pass
		PHASE_ATTACK_RESOLUTION:
			# 按速度排序依次结算
			_parent.call("_resolve_attack_queue")
			_schedule_auto_advance()
		PHASE_ENEMY_TURN:
			# AISystem.execute_turn——Sprint 8 Story 004 接线
			_execute_ai_turn()
			_schedule_auto_advance()
		PHASE_END:
			# 1. CostSystem.reset_for_turn
			_reset_cost_for_turn()
			# 2. DeploymentSystem.clear_standby_state
			_clear_standby_state()
			# 3. 战斗结束检查（Story 8-5 接线）
			_schedule_auto_advance()


## 阶段出口——清理当前阶段状态（ADR-0008 §子系统编排顺序）。
func exit_phase(phase: int) -> void:
	match phase:
		PHASE_PLAY:
			_parent.set("_player_confirmed_end", false)
		PHASE_ATTACK_DECLARATION:
			_parent.set("_player_confirmed_attack_skip", false)
		PHASE_ATTACK_RESOLUTION:
			_parent.get("_attack_queue").clear()
		PHASE_END:
			# 清除"已行动"和"待命"标记——已由 _clear_standby_state 在 _enter_phase(END) 处理
			pass


## 自动阶段调度——call_deferred 推进（ADR-0008 §准备阶段调度模式）。[br]
## [br][b]区别于 ADR-0007 的 call_deferred 禁令[/b]：此处用于编排调度（确保每阶段至少 1 帧渲染），[br]
## 而非信号处理器内部打破信号链——ADR-0008 明确声明合法。[br]
## [br][b]测试时禁用[/b]——_auto_advance_enabled=false 时跳过，手动控制 advance_phase。
func _schedule_auto_advance() -> void:
	if not _parent.get("_auto_advance_enabled"):
		return
	if not _parent.get("_is_active"):
		return
	_parent.call_deferred("advance_phase")


## 状态效果 tick——通过 StatusEffectSystem Autoload。[br]
## 不可用时静默跳过。
func _tick_status_effects() -> void:
	var ses = _get_status_effect_system()
	if ses != null and ses.has_method("tick_all"):
		var field_chars: Array = _get_field_characters()
		ses.tick_all(field_chars, _parent.get("_turn"))


## 重置费用——通过 CostSystem Autoload。[br]
## 不可用时静默跳过。
func _reset_cost_for_turn() -> void:
	var cs = _get_cost_system()
	if cs != null and cs.has_method("reset_for_turn"):
		# is_first_player / is_first_turn 由战斗上下文决定——此处用简化默认值
		cs.reset_for_turn(true, _parent.get("_turn") == 1)


## 清除待命状态——通过 DeploymentSystem Autoload。[br]
## 不可用时静默跳过。
func _clear_standby_state() -> void:
	var ds = _get_deployment_system()
	if ds != null and ds.has_method("clear_standby_state"):
		ds.clear_standby_state()


## 执行 AI 回合——通过 AISystem Autoload。[br]
## 不可用时静默跳过。
func _execute_ai_turn() -> void:
	var ai = _get_ai_system()
	if ai != null and ai.has_method("execute_turn"):
		var field_state: Dictionary = _build_field_state()
		ai.execute_turn(field_state)


## 构建场上状态快照——供 AISystem.execute_turn 使用。
func _build_field_state() -> Dictionary:
	var ds = _get_deployment_system()
	if ds != null and ds.has_method("get_field"):
		return {"characters": ds.get_field(), "turn": _parent.get("_turn")}
	return {"characters": [], "turn": _parent.get("_turn")}


## 获取场上角色列表——通过 DeploymentSystem Autoload。
func _get_field_characters() -> Array:
	var ds = _get_deployment_system()
	if ds != null and ds.has_method("get_field"):
		return ds.get_field()
	return []


## 计算抽牌数量——基础 2 张（GDD §2 抽牌规则）。[br]
## [br][b]桩实现[/b]——Story 002 接线后补后手补偿 +3 逻辑。
func _calculate_draw_count() -> int:
	return 2


# === Autoload 查找（子模块内自用）=================================================

func _get_status_effect_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/StatusEffectSystem")


func _get_cost_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/CostSystem")


func _get_deployment_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/DeploymentSystem")


func _get_ai_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/AISystem")
