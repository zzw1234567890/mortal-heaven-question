extends RefCounted
## CombatLaunchRequest —— 探索侧「确认进入战斗」的开战上下文构建（从
## [code]node_interaction_popup_host.gd[/code] 拆出）。[br]
## [br][b]职责[/b]：把弹窗此刻掌握的三份输入——节点详情（渲染快照）、到达信号
## 带来的敌方名册、玩家当前阵容——折成 [code]CombatLaunchContext[/code] 并发布到
## 跨场景缓存，供战斗场景 [code]_ready[/code] 一次性取走。[br]
## [br][b]为什么在确认时发布[/b]：场景切换会释放探索场景，上下文必须在请求转场
## [b]之前[/b]落盘；晚一步就只剩一份空字典。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：不缓存名册，玩家阵容每次现读
## （注入提供者优先，否则读 GSM [code]deck.slots[/code]）。[br]
##
## 来源: ADR-0014 §决策 3、ADR-0031 §2、exploration-system.md §3 步骤⑥。

## 开战上下文（跨场景缓存 + 契约校验的单一实现）。
const ContextScript := preload("res://src/feature/combat/combat_launch_context.gd")

## 玩家阵容提供者（[code]func() -> Array[/code]；空 = 读 GSM deck.slots）。
var player_roster_provider: Callable = Callable()


## 构建并发布上下文。[br]
## [param p_node_id] 到达节点 ID。[br]
## [param p_combat_type] [code]&"combat"[/code] / [code]&"elite"[/code]。[br]
## [param p_roster] 到达信号携带的敌方名册（运行时实例或预览字典）。[br]
## [param p_snapshot] 渲染快照（取 [code]nodes[node_id][/code] 的遭遇配置）。[br]
## [param p_ai] AISystem（模板查询——掉落 / 境界的兜底来源；可空）。
func publish(p_node_id: int, p_combat_type: StringName, p_roster: Array,
		p_snapshot: Dictionary, p_ai: Node = null) -> Dictionary:
	var nodes: Dictionary = p_snapshot.get("nodes", {})
	var detail: Variant = nodes.get(p_node_id, {})
	var context: Dictionary = ContextScript.build(p_node_id, p_combat_type,
			p_roster, player_roster(),
			detail if detail is Dictionary else {}, _lookup(p_ai))
	ContextScript.publish(context)
	return context


## 玩家出战阵容——注入提供者优先，否则读 GSM [code]deck.slots[/code] 的非空位。[br]
## [b]只读[/b]：UI 不筛选存活（阵亡过滤归备战面板的 [code]is_dead[/code] 判定）。
func player_roster() -> Array:
	if player_roster_provider.is_valid():
		var injected: Variant = player_roster_provider.call()
		return (injected as Array).duplicate() if injected is Array else []
	var gsm: Node = _autoload(&"GameStateManager")
	if gsm == null:
		return []
	var deck: Variant = gsm.get("deck")
	var slots: Variant = deck.get("slots") if deck is Dictionary else null
	if not (slots is Array):
		return []
	var ids: Array = []
	for raw: Variant in slots:
		if raw != null and int(raw) > 0:
			ids.append(int(raw))
	return ids


## 模板查询闭包——AISystem 不可用 / 缺入口时返回无效 Callable（不臆造模板）。
func _lookup(p_ai: Node) -> Callable:
	if p_ai != null and p_ai.has_method(&"get_template"):
		return Callable(p_ai, &"get_template")
	return Callable()


## Autoload 动态查找（测试环境缺 Autoload 时返回 null——宿主同源先例）。
func _autoload(p_node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath(String(p_node_name)))
