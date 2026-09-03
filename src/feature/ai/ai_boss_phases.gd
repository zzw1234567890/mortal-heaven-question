extends RefCounted
## AIBossPhases —— Boss 阶段转换子模块（从 ai_system.gd 拆分）。
##
## 持有对 AISystem 父节点的引用，通过它访问 _rng / _emit_safe 等方法。[br]
## [br]来源: ADR-0017 §决策 §Boss 阶段转换 / GDD ai-system.md §7/§公式 4。[br]
## [br]Sprint 8 Story 8-12：从 ai_system.gd 拆分。

## 父节点引用——AISystem Autoload 实例。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


## Boss 阶段转换检查——检测 + 执行（Story 003 实现）。[br]
## [br][b]流程[/b]（ADR-0017 §决策引擎设计 ②）：[br]
##   1. 仅 is_alive 时检查（击杀优先）[br]
##   2. should_transition 遍历 phase_transitions（OR 语义 + 哨兵）[br]
##   3. 触发则 transition 执行替换/解锁/冷却/回血 + 发射信号[br]
## [br][b]返回[/b]: true 表示触发了阶段转换（调用方应跳过后续行动）。
func check_phase_transition(enemy, field_state: Dictionary) -> bool:
	# AC-007：击杀优先——仅 is_alive 时检查
	if not _parent.call("_is_alive", enemy):
		return false
	var template = enemy.template
	if not template.is_boss:
		return false
	var phase_transitions: Array = template.phase_transitions
	if phase_transitions.is_empty():
		return false  # 无阶段转换定义
	var hp_pct: float = _parent.call("_get_hp_pct", enemy)
	var turn: int = int(field_state.get("turn", 0))
	var phase_idx: int = should_transition(enemy, phase_transitions, turn, hp_pct)
	if phase_idx < 0:
		return false
	# AC-013：所有阶段已触发 → 不再转换
	if (enemy.triggered_transitions as Array).has(phase_idx):
		return false
	do_boss_phase_transition(enemy, phase_idx)
	return true


## should_transition 公式——遍历 phase_transitions，OR 语义 + 哨兵（AC-010/011）。[br]
## [br][param phase_transitions] Boss 阶段转换列表。[br]
## [br][param turn] 当前回合数。[br]
## [br][param hp_pct] Boss HP 百分比。[br]
## [br][b]返回[/b]: 待触发阶段索引（-1 = 不触发）。[br]
## [br]公式: `(hp_below > 0 AND hp_pct <= hp_below) OR (turn_after > 0 AND turn >= turn_after)` 且 `not triggered`。[br]
## [br]来源: GDD ai-system.md §公式 4 / Story 003 AC-010。
func should_transition(enemy, phase_transitions: Array, turn: int, hp_pct: float) -> int:
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
## runtime_behavior_profile/runtime_skill_pool，绝不写回模板。[br]
## [br][param enemy] EnemyBattleState。[br]
## [br][param phase_idx] 待执行阶段索引。
func do_boss_phase_transition(enemy, phase_idx: int) -> void:
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
	_parent.call("_emit_safe", &"boss_phase_transitioned", [enemy, phase_idx, enemy.current_phase_index])


## BossPhaseMgr 查询接口——get_phase（AC-001）。[br]
## [br][b]返回[/b]: Boss 当前阶段索引。
func get_phase(enemy) -> int:
	return int(enemy.current_phase_index)


## BossPhaseMgr 查询接口——check（AC-001）。[br]
## [br][b]返回[/b]: 待触发阶段索引（-1 = 无转换）。
func check(enemy, turn: int, hp_pct: float) -> int:
	if not _parent.call("_is_alive", enemy):
		return -1
	var template = enemy.template
	if not template.is_boss:
		return -1
	var phase_transitions: Array = template.phase_transitions
	if phase_transitions.is_empty():
		return -1
	return should_transition(enemy, phase_transitions, turn, hp_pct)


## BossPhaseMgr 执行接口——transition（AC-001）。[br]
## [br][param enemy] EnemyBattleState。[br]
## [br][param phase_idx] 阶段索引。
func transition(enemy, phase_idx: int) -> void:
	if not (enemy.triggered_transitions as Array).has(phase_idx):
		do_boss_phase_transition(enemy, phase_idx)
