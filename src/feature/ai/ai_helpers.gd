extends RefCounted
## AIHelpers —— AI 决策引擎辅助方法子模块（从 ai_system.gd 拆分）。
##
## 无状态纯函数集合——存活/冷却/HP 百分比/行为配置/嘲讽查找/分数比较器。
## 原通过 _parent.call() 间接访问（13 处调用），提取为独立子模块后
## 子模块可直接实例化调用，减少 _parent 引用链路。
##
## [br]来源: ADR-0017 §决策引擎辅助 / GDD ai-system.md §4。
## [br]Sprint 12 Story 015：从 ai_system.gd 拆分。


const _SkillEntry = preload("res://assets/enemies/skill_entry.gd")


## 获取行为配置——优先实例级 runtime_behavior_profile（Boss 阶段转换后替换），[br]
## 回退到 template.behavior_profile。避免写回模板（ADR-0017 只读约定）。
static func get_behavior_profile(enemy) -> Resource:
	if enemy.runtime_behavior_profile != null:
		return enemy.runtime_behavior_profile
	return enemy.template.behavior_profile


## 检查角色是否存活。
static func is_alive(char_state) -> bool:
	return char_state != null and char_state.is_alive


## 检查技能是否在冷却中。
static func is_on_cooldown(enemy, skill) -> bool:
	if skill.cooldown <= 0:
		return false
	var cooldowns: Dictionary = enemy.skill_cooldowns
	return int(cooldowns.get(skill.skill_id, 0)) > 0


## 获取角色 HP 百分比。
static func get_hp_pct(char_state) -> float:
	if char_state.max_hp <= 0:
		return 0.0
	return float(char_state.current_hp) / float(char_state.max_hp)


## 检查是否为攻击类技能——仅攻击类受嘲讽限制（AC-008 边缘情况）。[br]
## 非攻击类（UTILITY/HEAL/DEFENSE/FORMATION）可绕过嘲讽作用于其他目标。[br]
## [br][b]已废弃[/b]——改用 skill_result.skill_type 直接判断，保留供外部查询。
static func is_attack_skill_by_target_type(target_type: int) -> bool:
	return target_type == _SkillEntry.TargetType.SINGLE_ENEMY or target_type == _SkillEntry.TargetType.ALL_ENEMY


## 查找嘲讽角色。
static func find_taunting(targets: Array) -> Variant:
	for target in targets:
		if target.get("is_taunting", false):
			return target
	return null


## 分数降序比较器。
static func compare_by_score_desc(a, b) -> bool:
	return a.score > b.score
