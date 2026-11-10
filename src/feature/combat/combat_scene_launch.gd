extends RefCounted
## CombatSceneLaunch —— 战斗场景的开战上下文消费（探索→战斗补链）。[br]
## [br][b]职责[/b]：把 [code]CombatLaunchContext[/code] 的四份输入翻成战斗场景能用的
## 形态——[br]
##   1. [b]校验[/b]：缺字段时给出可读失败（[method failure_text]），不静默兜底；[br]
##   2. [b]标题[/b]：遭遇展示名 > 调用方默认标题；[br]
##   3. [b]敌方阵容[/b]：模板 ID 列表 + 基准等级（交 [code]AISystem.create_enemy_roster[/code]）；[br]
##   4. [b]掉落[/b]：折进 [code]battle_start[/code] 配置，结算时由战斗系统读取；[br]
##   5. [b]玩家阵容[/b]：备战面板预选。[br]
## [br][b]为什么独立成文件[/b]：[code]combat_scene.gd[/code] 贴 300 行软上限，且
## 「上下文怎么读」与「什么时候开战」是两件事（同 [code]combat_scene_battle_setup.gd[/code]
## 先例）。[br]
## [br][b]降级[/b]：上下文缺失时 [method is_valid] 为 false，场景只展示可读失败，
## 不再读取默认遭遇资源——上一轮「探索点哪一格都打同一批敌人」正是兜底造成的。
##
## 来源: exploration-system.md §3 步骤⑥、ADR-0014 §决策 3、ADR-0031 §2。

## 上下文模块（跨场景缓存与契约校验的唯一实现）。
const ContextScript := preload("res://src/feature/combat/combat_launch_context.gd")

## 战斗标题前缀（与 [code]CombatScene.TEXT_BATTLE_TITLE[/code] 同源口径）。
const TEXT_TITLE_PREFIX: String = "⚔ "
## 缺字段失败文案前缀（玩家可见——本地化 epic 后替换为 key）。
const TEXT_FAILURE_PREFIX: String = "无法进入战斗："

## 本次开战的上下文（[method consume] 取走；空 = 无探索侧上下文）。
var _context: Dictionary = {}
## 是否已消费过（防重复 take 造成二次清空）。
var _consumed: bool = false
## 契约校验失败文案（空串 = 可开战；[method consume] 时计算一次）。
var failure: String = ""


## 取走探索侧发布的上下文（一次性——[method CombatLaunchContext.take]）。[br]
## [br][b]幂等[/b]：重复调用返回同一份快照，不再次 take（否则第二次读到空字典）。[br]
## [param p_override] 非空时用它替代跨场景缓存（测试注入 / 特殊变体）。
func consume(p_override: Dictionary = {}) -> void:
	if _consumed:
		return
	_consumed = true
	_context = p_override.duplicate(true) if p_override is Dictionary \
			and not p_override.is_empty() else ContextScript.take()
	failure = ContextScript.validate(_context)


## 注入上下文（测试直调——跳过跨场景缓存）。
func apply(p_context: Dictionary) -> void:
	_consumed = true
	_context = p_context.duplicate(true) if p_context is Dictionary else {}
	failure = ContextScript.validate(_context)


## 原始上下文（只读副本——测试断言用）。
func context() -> Dictionary:
	return _context.duplicate(true)


## 是否可直接开战（上下文非空且通过契约校验）。
func is_valid() -> bool:
	return failure.is_empty()


## 是否允许开战——[param p_required] 为 false 时不要求上下文（渡劫路径）。
func can_start(p_required: bool = true) -> bool:
	return is_valid() or not p_required


## 可读失败文案（空串 = 无失败——[method is_valid] 为 true 时）。
func failure_text() -> String:
	return "" if failure.is_empty() else TEXT_FAILURE_PREFIX + failure


## 战斗标题——遭遇展示名优先，缺失时回退调用方默认标题。[br]
## 名称已带图标时不重复加前缀（数据资源里可自带「⚔」）。
func title(p_fallback: String) -> String:
	var name: String = ContextScript.title(_context, "")
	if name.is_empty():
		return p_fallback
	return name if name.begins_with(TEXT_TITLE_PREFIX.strip_edges()) else TEXT_TITLE_PREFIX + name


## 敌方模板 ID 列表（空 = 无模板可生成）。
func enemy_template_ids() -> Array:
	var ids: Variant = _context.get(ContextScript.KEY_TEMPLATE_IDS, [])
	return (ids as Array).duplicate() if ids is Array else []


## 敌方基准等级（≤0 = 未提供——由 AISystem 按玩家境界缩放）。
func enemy_level() -> int:
	return int(_context.get(ContextScript.KEY_ENEMY_LEVEL, 0))


## 本场掉落（空字典 = 本节点无掉落配置）。[br]
## 结构 [code]{lingshi, cultivation, cards}[/code]——与结算载荷同构，直接透传。
func rewards() -> Dictionary:
	var raw: Variant = _context.get(ContextScript.KEY_REWARDS, {})
	return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}


## 开战前置的三份节点数据——顺序即 [code]CombatSceneBattleSetup.setup[/code] 尾部参数。
func battle_setup_args() -> Array:
	return [enemy_template_ids(), enemy_level(), rewards()]


## 玩家出战阵容（正整数角色实例 ID 列表）。
func player_roster() -> Array:
	var raw: Variant = _context.get(ContextScript.KEY_PLAYER_ROSTER, [])
	if not (raw is Array):
		return []
	var ids: Array = []
	for item: Variant in raw:
		var cid: int = int(item)
		if cid > 0 and not ids.has(cid):
			ids.append(cid)
	return ids


## 备战面板预选——把上下文带来的玩家阵容点选上（玩家仍可改选）。[br]
## [br][b]只走公开交互入口[/b]（[code]toggle_selection[/code]），不直接改面板状态；
## 已在选择里的角色跳过，阵亡角色由面板自身拒绝（返回 false）。[br]
## [br][b]返回[/b]：实际点选成功的角色 ID 列表（测试断言用）。
func preselect(p_deploy: Variant) -> Array:
	var picked: Array = []
	if _context.is_empty() or p_deploy == null:
		return picked
	if not p_deploy.has_method(&"toggle_selection"):
		return picked
	var selected: Array = p_deploy.call(&"get_selected_ids") \
			if p_deploy.has_method(&"get_selected_ids") else []
	for cid: int in player_roster():
		if selected.has(cid):
			continue
		if bool(p_deploy.call(&"toggle_selection", cid)):
			selected.append(cid)
			picked.append(cid)
	return picked
