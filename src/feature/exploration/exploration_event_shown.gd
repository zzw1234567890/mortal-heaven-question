extends RefCounted
## ExplorationEventShown —— 「本图这个事件节点弹过没有」的[b]唯一判定与记录[/b]。[br]
## [br][b]为什么需要单独一处[/b]：事件面板此前把「弹过哪些节点」记在自己的成员变量
## 里（[code]event_node_presenter.gd[/code] 的 [code]_shown_nodes[/code]），而那个变量
## 不进程存续——玩家在事件节点选了选项、退出游戏再读档回来，同一格会[b]再弹一次[/b]，
## 同一份奖励也就再给一次。[br]
## [br][b]为什么不留在 UI 里[/b]：ADR-0031 §2 零状态所有权——UI 只发请求、显示系统
## 返回的文案，玩法状态的归属地在 Feature 层。本模块就是那个归属地：判定与写入都在
## 这里，Presenter 只调 [method is_shown] / [method mark_shown]。[br]
## [br][b]存在哪里[/b]：[code]map_states[map_id]["events_shown"] = [已弹节点 ID, ...][/code]
## ——与「已采槽位」（[code]harvested[/code]）、「灵泉已用次数」
## （[code]action_spring_uses[/code]）同一层，随 exploration 域一起持久化
## （[code]PERSISTABLE_DOMAINS[/code] 含 exploration）。[b]不另开一条存档通路[/b]：
## 写入一律经 [code]GSM.update_exploration_map_state[/code]（顶层键合并覆盖）。[br]
## [br][b]按地图分记[/b]：同一张图重进（[code]entry_count[/code] +1）不该让已读过的事件
## 再弹；换一张图则从零开始——ID 只在图内有意义（节点 ID 编码
## [code]layer*100+idx[/code]，两张图都会出现 [code]101[/code]）。[br]
## [br][b]为什么是数组而不是字典[/b]：节点 ID 是 int，JSON 会把 int 键写成 String 键，
## 读回来若不再还原，[code]has(int)[/code] 查不到（同 [GsmSaveTypes] 记的那条）；
## 数组元素则被读档归一还原成 int，判定天然成立。[br]
## [br]来源: ADR-0014 §决策 1 状态分层模型、ADR-0031 §2 零状态所有权、
## 先例 [code]exploration_harvest.gd[/code]（已采状态）/ [code]exploration_action_spring.gd[/code]（限次）。

## 已弹节点在 [code]map_states[map_id][/code] 下的键（v2 起随存档持久化）。
const KEY_EVENTS_SHOWN: String = "events_shown"


## 该图已弹过的事件节点 ID 列表（无从记录时空数组）。[br]
## [br][param p_state] 该图的 [code]map_states[/code] 条目。[br]
## [br][b]非数组按空处理[/b]：脏存档不至于让节点图崩，退化为「都没弹过」。[br]
static func shown_of(p_state: Dictionary) -> Array:
	var raw: Variant = p_state.get(KEY_EVENTS_SHOWN, [])
	return (raw as Array).duplicate() if raw is Array else []


## 该节点是否已经弹过（幂等判定的唯一实现）。[br]
## [br][param p_state] 该图的 [code]map_states[/code] 条目。[br]
## [param p_node_id] 事件节点 ID（负数一律 false——调用方取不到位置时的哨兵）。[br]
static func is_shown(p_state: Dictionary, p_node_id: int) -> bool:
	if p_node_id < 0:
		return false
	return shown_of(p_state).has(p_node_id)


## 取某张图的 [code]map_states[/code] 条目（GSM 不可用 / 无该图记录 → 空字典）。[br]
## [br][param p_gsm] GSM（Autoload 或注入的桩）。[br]
## [param p_map_id] 地图 ID。[br]
## [br][b]空字典即「都没弹过」[/b]：读档前 / 未进图时不该把判定复杂化。[br]
static func state_of(p_gsm: Node, p_map_id: StringName) -> Dictionary:
	if p_gsm == null or str(p_map_id).is_empty():
		return {}
	var exploration: Variant = p_gsm.get(&"exploration")
	if not (exploration is Dictionary):
		return {}
	var map_states: Variant = (exploration as Dictionary).get("map_states", {})
	if not (map_states is Dictionary):
		return {}
	var state: Variant = (map_states as Dictionary).get(p_map_id, {})
	return state if state is Dictionary else {}


## 当前地图 ID——GSM 缺失 / 未进图时返回 [code]&""[/code]。[br]
static func current_map_of(p_gsm: Node) -> StringName:
	if p_gsm == null:
		return &""
	var exploration: Variant = p_gsm.get(&"exploration")
	if not (exploration is Dictionary):
		return &""
	return StringName(str((exploration as Dictionary).get("current_map", "")))


## 「当前地图的这个节点弹过了吗」——读侧一步到位（调用方不必自己拼
## [method current_map_of] + [method state_of]）。[br]
## [br][param p_gsm] GSM。[br]
## [param p_node_id] 事件节点 ID（负数一律 false）。[br]
static func is_shown_in_gsm(p_gsm: Node, p_node_id: int) -> bool:
	return is_shown(state_of(p_gsm, current_map_of(p_gsm)), p_node_id)


## 记下「本图这个节点弹过」——整块写回 [constant KEY_EVENTS_SHOWN]。[br]
## [br][param p_gsm] GSM（null / 缺写入入口时只告警——不臆造写入成功的假象）。[br]
## [param p_node_id] 事件节点 ID（负数不写）。[br]
## [br][b]返回[/b]：是否真的写进存档（无活跃地图时为 [code]false[/code]）。[br]
## [br][b]无活跃地图不写[/b]：地图 ID 是这份记录的归属键——没有它就无处可存
## （调用方据此决定是否退回进程内瞬态记录）。[br]
## [br][b]幂等[/b]：已记录过的节点不重复 append（也不发一次无意义的变更广播）。[br]
static func mark_shown(p_gsm: Node, p_node_id: int) -> bool:
	if p_gsm == null or p_node_id < 0:
		return false
	if not p_gsm.has_method(&"update_exploration_map_state"):
		return false
	var current_map: StringName = current_map_of(p_gsm)
	if str(current_map).is_empty():
		return false
	var shown: Array = shown_of(state_of(p_gsm, current_map))
	if shown.has(p_node_id):
		return true
	shown.append(p_node_id)
	p_gsm.call(&"update_exploration_map_state", current_map,
			{KEY_EVENTS_SHOWN: shown})
	return true
