extends RefCounted
## BattleResumeRestore —— 把存档里的续战段[b]还原成战斗侧能用的形态[/b]（纯函数）。[br]
## [br][b]职责[/b]：读档回到战斗时，敌我两侧必须是[b]存档那一刻的样子[/b]，而不是
## 「按模板重开一场」——[br]
##   · [b]敌方[/b]：按 [code]template_id[/code] 重建 [code]EnemyBattleState[/code] 后
##     把存档里的 HP / 存活 / 阵位覆盖回去（不覆盖就是满血重打，等于白存）；[br]
##   · [b]我方[/b]：出战阵容与 HP 表由 [method PayloadScript.player_ids] /
##     [method PayloadScript.player_stats] 给出，经
##     [code]battle_start.player_stats[/code] 注入种子（比模板 [code]base_hp[/code] 优先）。[br]
## [br][b]为什么重建而不是复用 AISystem 的 [code]create_enemy_roster[/code][/b]：那条链会
## 走一遍难度缩放并把 HP 拉满（[code]max_hp = current_hp = 缩放后最大生命[/code]），
## 与本模块「HP 以存档为准」的裁定直接冲突；重建后再覆盖则是单向的。[br]
## [br][b]AISystem 缺席时降级[/b]：重建不出对象时返回空数组，调用方保持原阵容
## （战斗照常进行——缺的是「敌方残血」，不是崩溃）。[br]
## [br]来源: ADR-0017 §EnemyFactory、ADR-0008 §GSM 边界、
## [code]battle_resume_payload.gd[/code] §「能不能回到这场战斗」。

## 载荷模块（条目字段名的唯一真理来源）。
const PayloadScript := preload("res://src/feature/combat/battle_resume_payload.gd")


## 重建敌方名册——顺序与存档一致（阵位与 UI 建卡按顺序读）。[br]
## [br][param p_payload] 存档里的续战段。[br]
## [param p_ai] AISystem（缺席时返回空数组——见类文档降级节）。[br]
## [br][b]返回[/b]：[code]EnemyBattleState[/code] 数组；没有可重建的条目时为空。
static func enemy_roster(p_payload: Dictionary, p_ai: Node) -> Array:
	if p_ai == null or not p_ai.has_method(&"get_template") \
			or not p_ai.has_method(&"create_state"):
		return []
	var out: Array = []
	for raw: Variant in p_payload.get(PayloadScript.KEY_ENEMY_ROSTER, []):
		if not (raw is Dictionary):
			continue
		var entry: Dictionary = raw
		var template: Variant = p_ai.call(&"get_template",
				StringName(str(entry.get(PayloadScript.KEY_TEMPLATE_ID, ""))))
		if template == null:
			continue  # 模板已不存在（图鉴改版）——跳过该条，不臆造一个敌人
		var state: Variant = p_ai.call(&"create_state", template)
		if state == null:
			continue
		_apply_entry(state, entry)
		out.append(state)
	return out


## 把存档条目里的可变状态覆盖到重建出来的实例上。[br]
## [br][b]HP 夹取[/b]：不超过 [code]max_hp[/code]（存档被手改过时不让敌人凭空更肉）。
static func _apply_entry(p_state: Variant, p_entry: Dictionary) -> void:
	var max_hp: int = maxi(int(p_entry.get(PayloadScript.KEY_MAX_HP, 0)), 0)
	var hp: int = maxi(int(p_entry.get(PayloadScript.KEY_CURRENT_HP, 0)), 0)
	if max_hp > 0:
		hp = mini(hp, max_hp)
	p_state.set("max_hp", max_hp)
	p_state.set("current_hp", hp)
	p_state.set("is_alive", bool(p_entry.get(PayloadScript.KEY_IS_ALIVE, hp > 0)))
	p_state.set("field_position", int(p_entry.get(PayloadScript.KEY_SLOT_INDEX, -1)))
	p_state.set("is_front_row", bool(p_entry.get(PayloadScript.KEY_IS_FRONT, true)))
