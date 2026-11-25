extends RefCounted

## AiRosterGuard —— 测试期对 [code]AISystem[/code] 全局名册的「借用—归还」守卫。[br]
## [br][b]为什么需要它[/b]：[code]AISystem[/code] 是跨全部套件共享的 Autoload，而
## [code]_enemy_roster[/code] 是它的[b]单份可变状态[/b]。两条生产路径都会写它（都
## 在开战前置里，理由正当）：[br]
##   · [code]combat_scene_battle_setup.gd §_resolve_roster[/code]——探索开战；[br]
##   · [code]tribulation_boss_roster.gd §build[/code]——天劫开战（AI 决策读的正是它，
##     不写回则敌方回合拿到空候选池）。[br]
## 生产侧写完[b]不还原[/b]是既有口径：每一场仗在开战前置里都会重新写一遍，名册是
## 「本场」的战斗态，跨场残留无人读（下一次开战即被覆盖）。[br]
## [br][b]测试侧不还原就会越界[/b]：Autoload 跨套件存活，写进去的天劫雷灵会留给
## 后面任何一个「开了仗、又让敌方回合真的跑一遍」的用例——它以为在打自己的敌人，
## 实际打的是雷灵，于是断言碎在与它无关的地方。2026-11-25 实测到的现场：
## [code]tests/unit/combat_system/test_resume_playable_count.gd[/code] 的
## [code]test_snapshot_carries_no_enemy_intent_section[/code] 在
## [code]integration/tribulation[/code] 先跑时变红（我方角色被雷灵打死、阵位清空、
## 抓快照判「战斗记录不完整」），单跑 unit 全绿。[br]
## [br][b]用法[/b]：在 [code]before_each[/code] 里 [code]capture()[/code] 存进成员，
## 在 [code]after_each[/code] 里 [code]restore(成员)[/code]。归还的是[b]浅拷贝[/b]
## ——名册条目是对象，身份必须原样交回（AI 按身份匹配目标）。[br]
## [br]来源: ADR-0017 §关键接口 set_enemy_roster / get_enemy_roster、
## ADR-0032、2026-11-25 全量红点定位。

## Autoload 查找器——本模块内的查找已收拢到它（唯一实现）。
const AutoloadAccess := preload("res://src/feature/combat/combat_autoload_access.gd")


## 记下当前名册（浅拷贝；AISystem 缺席时为 [code][][/code]）。[br]
## [br][b]返回[/b]：[code]Array[/code]——交给 [method restore] 原样交回的凭据。
static func capture() -> Array:
	var ai: Node = _ai()
	if ai == null or not ai.has_method(&"get_enemy_roster"):
		return []
	var raw: Variant = ai.call(&"get_enemy_roster")
	return (raw as Array).duplicate() if raw is Array else []


## 把名册交回 [method capture] 记下的那份（AISystem 缺席时静默无操作）。[br]
## [br][param p_snapshot] [method capture] 的返回。[br]
## [br][b]为什么自己也 [code]duplicate()[/code][/b]：凭据可能被多个
## [code]after_each[/code] 共用（子类 [code]super()[/code] 链），交出去的必须是
## 独立数组，否则后一处还原会读到前一处的改动。
static func restore(p_snapshot: Array) -> void:
	var ai: Node = _ai()
	if ai == null or not ai.has_method(&"set_enemy_roster"):
		return
	ai.call(&"set_enemy_roster", p_snapshot.duplicate())


## AISystem Autoload——未注册时为 [code]null[/code]（剥离 Autoload 的用例）。
static func _ai() -> Node:
	return AutoloadAccess.find(&"AISystem")
