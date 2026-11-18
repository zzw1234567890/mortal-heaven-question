extends RefCounted
## CombatResumeCapture —— 把「正在打的这场仗」折算成存档形态并写进 GSM。[br]
## [br][b]职责[/b]：从各处[b]现读[/b]一手状态（战斗系统 / 布阵 / 费用 / 跨场景上下文），
## 交 [code]battle_resume_payload.gd[/code] 组装，再经 GSM 第二层原子方法
## [code]_set_battle_resume[/code] 落库。[br]
## [br][b]为什么是「拉」不是「推」[/b]：快照只在玩家存档那一刻需要（其余时间白算），
## 而「状态什么时候变」有阶段 / 回合 / HP / 费用四条路径——分别挂钩会在每处留一个
## 可能漏改的埋点。存档时现拉一次，存进去的必然是那一刻的真实状态。[br]
## [br][b]不可续玩的情形不写快照[/b]（渡劫等无探索来源的战斗）：写一份读回来没人认得的
## 档，比不写更糟——调用方据 [method capture] 的返回值给玩家一句中文提示。[br]
## [br][b]保存前先清档再写[/b]：上一场留下的快照若不先清，本场不可续玩时会把
## [b]上一场[/b]的进度当成「进行中」写进存档——读档后回到的是一盘已经打完的棋。[br]
## [br]来源: ADR-0002 §存档容器、ADR-0008 §GSM 边界、ADR-0014 §决策 1、
## 本轮「战斗中存档 → 读档回到战斗」。

## 载荷模块（形状与解析的唯一真理来源）。
const PayloadScript := preload("res://src/feature/combat/battle_resume_payload.gd")
## 跨场景上下文的来源读取（origin node id / combat type）。
const ContextScript := preload("res://src/feature/combat/combat_launch_context.gd")

## 我方阵营取值（[code]CombatRosterState.snapshot_all[/code] 的 side 字段）。
const SIDE_PLAYER: int = 0

## 战斗系统 / 布阵系统 / 费用系统 句柄（全部可空——缺失时对应块退化为空）。[br]
## [br][b]为 null 时回退 Autoload 查找[/b]（同 [code]combat_hp_carryover.gd[/code] 口径）：
## 生产路径上调用方（暂停菜单的动作层）只注战斗系统一处，布阵与费用按常驻路径取；
## 测试换掉任意一个即可脱离真实系统。
var combat: Node = null
var deployment: Node = null
var cost: Node = null
## GSM 句柄（写入目标；缺失时整场跳过，见 [method capture] 的返回值）。
var gsm: Node = null


## 抓一次快照并写进 GSM。[br]
## [br][param p_scene_id] 当前场景 ID（存档里记「在哪个场景存的」）。[br]
## [br][b]返回[/b]：[code]{written: bool, reason: String}[/code]——[code]reason[/code]
## 为中文可读原因（可写时为空串），调用方据此决定要不要给玩家提示。[br]
## [br][b]不写有三种情形[/b]：没有进行中的战斗（战斗已结束/从未开战——不必提示）、
## 「进行中但不可续玩」（无探索来源——[method PayloadScript.reason] 给文案）、
## 以及[b]组装出来却读不回来[/b]的载荷（名册残缺——[method
## PayloadScript.payload_reason] 给文案）。[br]
## [br][b]为什么最后一种也要挡[/b]：本方法的返回值就是存档反馈文案的口径——写一份
## 读回来判为「不可续战」的档却回一句「读取此档将回到当前战斗」，是对玩家说谎。
## 挡在这里，存档反馈与读档实际行为才是同一件事。[br]
## [br][b]为什么以 [method write] 的落库结果为准[/b]：GSM 缺失时写入是无声失败，
## 报「已写入」等于让玩家以为残血存下来了。
func capture(p_scene_id: int) -> Dictionary:
	if not _in_battle():
		_clear()
		return {"written": false, "reason": ""}
	var state: Dictionary = _gather(p_scene_id)
	var reason: String = PayloadScript.reason(state)
	if not reason.is_empty():
		# 不可续玩（渡劫等）——清掉上一场的快照，别把别人的进度当本场写进去
		_clear()
		return {"written": false, "reason": reason}
	var payload: Dictionary = PayloadScript.build(state)
	var crippled: String = PayloadScript.payload_reason(payload)
	if not crippled.is_empty():
		_clear()
		return {"written": false, "reason": crippled}
	if not write(payload):
		return {"written": false, "reason": "存档系统不可用，战斗进度未能写入"}
	return {"written": true, "reason": ""}


## 直接写入一份已组装好的载荷（测试与「读档后重写」用）。[br]
## [br][b]返回[/b]：是否真的落库（GSM 缺失 / 无写入面时为 false——见 [method capture]
## 「为什么以落库结果为准」）。
func write(p_payload: Dictionary) -> bool:
	if gsm == null or not gsm.has_method(&"_set_battle_resume"):
		return false
	gsm.call(&"_set_battle_resume", p_payload.duplicate(true))
	return true


## 清空快照（战斗结束 / 存档时不可续玩——见类文档「保存前先清档再写」）。
func _clear() -> void:
	if gsm != null and gsm.has_method(&"_set_battle_resume"):
		gsm.call(&"_set_battle_resume", {})


## 本场战斗是否正在进行——[code]is_battle_active()[/code] 是唯一判据（战斗系统缺席
## 即视为没有战斗）。
func _in_battle() -> bool:
	var cs: Node = _combat()
	if cs == null or not cs.has_method(&"is_battle_active"):
		return false
	return bool(cs.call(&"is_battle_active"))


## 现读一手状态——各块独立降级（缺哪个来源就只有哪一块为空，不整场放弃）。
func _gather(p_scene_id: int) -> Dictionary:
	return {
		"scene_id": p_scene_id,
		"phase": _combat_int(&"get_current_phase", 0),
		"turn": _combat_int(&"get_turn_number", 1),
		"current_cost": _cost_int(&"get_current_cost", 0),
		"max_cost": _cost_int(&"get_max_cost", 0),
		"origin_node_id": int(ContextScript.get_origin_node_id()),
		"origin_combat_type": String(ContextScript.get_origin_combat_type()),
		"player_field": _player_field(),
		"player_hp": _player_hp(),
		"enemy_roster": _enemy_roster(),
		"config": _battle_config(),
	}


## 本场开战配置（战斗系统持有的那份副本；缺席时为空——载荷按白名单折叠）。
func _battle_config() -> Dictionary:
	var cs: Node = _combat()
	if cs == null or not cs.has_method(&"get_battle_config"):
		return {}
	var raw: Variant = cs.call(&"get_battle_config")
	return raw if raw is Dictionary else {}


## 我方阵位快照（[code]DeploymentSystem.get_field()[/code]——含前后排与阵位序号）。
func _player_field() -> Array:
	var ds: Node = _deployment()
	if ds == null or not ds.has_method(&"get_field"):
		return []
	var raw: Variant = ds.call(&"get_field")
	return raw if raw is Array else []


## 我方 HP 表——[code]{character_id: {current_hp, max_hp, is_alive}}[/code]。[br]
## [br][b]取数走状态表全量快照[/b]（[code]CombatRosterState.snapshot_all[/code]）：
## 与战斗内结算、结算回流同一取数口径，另开一处读 HP 必然与真实值漂移。
func _player_hp() -> Dictionary:
	var out: Dictionary = {}
	var cs: Node = _combat()
	if cs == null or not cs.has_method(&"get_roster_state"):
		return out
	var state: Variant = cs.call(&"get_roster_state")
	if state == null or not (state is RefCounted) \
			or not (state as RefCounted).has_method(&"snapshot_all"):
		return out
	for raw: Variant in (state as RefCounted).call(&"snapshot_all"):
		if not (raw is Dictionary):
			continue
		var entry: Dictionary = raw
		if int(entry.get("side", SIDE_PLAYER)) != SIDE_PLAYER:
			continue
		out[int(entry.get("character_id", -1))] = {
			"current_hp": int(entry.get("current_hp", 0)),
			"max_hp": int(entry.get("max_hp", 0)),
			"is_alive": bool(entry.get("is_alive", true)),
		}
	return out


## 本场敌方名册快照（战斗系统在开战瞬间定格的那份——不现读 AISystem，见该类文档）。
func _enemy_roster() -> Array:
	var cs: Node = _combat()
	if cs == null or not cs.has_method(&"get_battle_enemy_roster"):
		return []
	var raw: Variant = cs.call(&"get_battle_enemy_roster")
	return raw if raw is Array else []


## 战斗系统——注入优先，否则回退 Autoload。
func _combat() -> Node:
	if combat != null:
		return combat
	return _autoload(&"CombatSystem")


## 布阵系统——注入优先，否则回退 Autoload。
func _deployment() -> Node:
	if deployment != null:
		return deployment
	return _autoload(&"DeploymentSystem")


## 费用系统——注入优先，否则回退 Autoload。
func _cost() -> Node:
	if cost != null:
		return cost
	return _autoload(&"CostSystem")


## Autoload 动态查找（测试环境缺 Autoload 时返回 null——同容器先例）。
func _autoload(p_node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath(String(p_node_name)))


## 战斗系统上的整数取数（缺席 / 无该方法时回退）。
func _combat_int(p_method: StringName, p_fallback: int) -> int:
	var cs: Node = _combat()
	if cs == null or not cs.has_method(p_method):
		return p_fallback
	return int(cs.call(p_method))


## 费用系统上的整数取数（缺席时回退——费用上限缺省 0 表示「未知」，不臆造）。
func _cost_int(p_method: StringName, p_fallback: int) -> int:
	var cs: Node = _cost()
	if cs == null or not cs.has_method(p_method):
		return p_fallback
	return int(cs.call(p_method))
