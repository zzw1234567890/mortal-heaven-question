class_name ExplorationEventSelector
extends RefCounted
## ExplorationEventSelector —— 事件节点「按境界筛选 + 随机取一」的纯函数集。
##
## 服务 [ExplorationEventSystem.pick_for_node]：选取策略从注册表/结算职责里拆出
## （单文件行数预算），全部 static 纯函数——不持有状态，相同输入 + 相同 rng 状态
## 时输出相同。
##
## [b]筛选规则[/b]：[member EventDef.min_realm] <= 玩家境界（境界下限 1——信号
## 载荷异常时按炼气期兜底，与 GSM [code]player.realm[/code] 缺省一致）。[br]
## [b]选取规则[/b]：有 rng → 候选内均匀随机；无 rng → 按节点 id 取模（确定性兜底，
## 测试可复现）。
##
## 来源: Sprint 18 探索事件节点（Story 018-events）、GDD exploration-system.md
## §10（事件内容到达时才确定——防 SL）。

## 境界下限——玩家境界低于 1（载荷异常）时按炼气期处理，不把候选池整个筛空。
const REALM_FLOOR: int = 1


## 筛出玩家境界可触发的事件 id（按 id 稳定排序——顺序确定，取模/随机才可复现）。
static func eligible_ids(p_events: Object, p_player_realm: int) -> Array:
	var realm: int = maxi(p_player_realm, REALM_FLOOR)
	var ids: Array = p_events.call(&"event_ids")
	ids.sort()
	var eligible: Array = []
	for raw: Variant in ids:
		var def: Variant = p_events.call(&"get_event", String(raw))
		if def == null:
			continue
		if int(def.get(&"min_realm")) <= realm:
			eligible.append(String(raw))
	return eligible


## 在候选里取一个事件；候选为空返回 [code]null[/code]——调用方据此不弹面板、
## 不报错。
static func pick_for_node(p_events: Object, p_node_id: int, p_player_realm: int,
		p_rng: RandomNumberGenerator = null) -> EventDef:
	var eligible: Array = eligible_ids(p_events, p_player_realm)
	if eligible.is_empty():
		return null
	var index: int = posmod(p_node_id, eligible.size())
	if p_rng != null:
		index = p_rng.randi_range(0, eligible.size() - 1)
	var raw: Variant = p_events.call(&"get_event", String(eligible[index]))
	return raw if raw is EventDef else null
