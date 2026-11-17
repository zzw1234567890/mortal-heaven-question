extends RefCounted
## ExplorationEntryFlow —— 探索薄容器的[b]「本次进入要干什么」落地编排[/b]
## （从 [code]exploration_scene.gd[/code] 拆出）。[br]
## [br][b]为什么单独一处[/b]：[code]exploration_scene.gd[/code] 已贴 300 行软上限
## （.claude/docs/coding-standards.md），而「进来的那一刻该不该自动进图、进哪张」
## 与「界面怎么挂、退出怎么结算」是两件事（同 [code]map_clear_presenter.gd[/code]、
## [code]map_select_reentry_flow.gd[/code] 先例）。[br]
## [br][b]为什么需要这条路径[/b]：探索容器是「新开局」「读档续玩」「从别处回来」
## 三条路径的共同终点，而它挂载那一刻无从分辨自己是被谁叫来的——不消费意图的话，
## 无论从哪条路进来，玩家都停在选图界面，得再点一次地图卡才看到节点图
## （新开局因此要多两跳，读档则完全回不到上次那张图）。[br]
## [br][b]进图出口由调用方注入[/b]：[code]func(map_id: StringName, resume: bool)[/code]
## ——生产路径是 [code]ExplorationScene._enter_map[/code]。本模块不认识节点图，
## 只决定「进不进、进哪张、走新生成还是续玩」。[br]
## [br][b]地图 ID 不在这里硬编码[/b]：新开局的落点取
## [method ExplorationEntryIntent.first_map_id]（探明表首项，表序即剧情序）。
##
## 来源: design/gdd/exploration-system.md §1（探明表顺序 = 剧情顺序）、
## design/gdd/main-menu-system.md（新游戏 / 继续游戏 / 读档三条路径）、ADR-0031 §2。

## 跨场景进入意图（三条路径在进入探索之前留下的一个枚举）。
const IntentScript := preload("res://src/feature/exploration/exploration_entry_intent.gd")

## GSM 常驻路径（读档续玩要读 [code]current_map[/code]——存档里的事实）。
const GSM_PATH: StringName = &"/root/GameStateManager"


## 消费「本次进探索要干什么」的意图（[ExplorationEntryIntent]——取走即清）。[br]
## [br][param p_enter] 进图出口 [code]func(map_id: StringName, resume: bool) -> void[/code]。[br]
## [br][b]FIRST_MAP[/b]：新开局——直接进第一张图（[code]resume = false[/code]：新 seed、
## 新 DAG、行动力回满）。[br]
## [br][b]RESUME[/b]：读档续玩——GSM 里 [code]current_map[/code] 非空才进（且走
## [code]resume = true[/code]：从存档快照重建，不重生成）；为空则[b]停在选图界面[/b]
## （存档没有进行中的图，让玩家自己挑一张）。[br]
## [br][b]NONE[/b]：其余路径（占位场景 / 暂停菜单回来）——维持现状，不自动进图。[br]
## [br][b]返回[/b]：实际消费到的模式（[enum ExplorationEntryIntent.EntryMode]；
## 无意图时为 NONE——测试断言用）。
static func consume(p_enter: Callable) -> int:
	var mode: int = IntentScript.take_entry_mode()
	match mode:
		IntentScript.EntryMode.FIRST_MAP:
			var first: StringName = IntentScript.first_map_id()
			if first != &"":
				_enter(p_enter, first, false)
		IntentScript.EntryMode.RESUME:
			resume_last(p_enter)
	return mode


## 读档续玩——回到存档里那张图（[code]current_map[/code] 为空则停在选图界面）。[br]
## [br][b]为什么读 GSM 而不是从意图里带地图 ID[/b]：意图只持一个枚举（见
## [code]exploration_entry_intent.gd[/code] 类文档「只持一个枚举」），地图 ID 是
## 存档里的事实——UI 层缓存一份就会与存档漂移。[br]
## [br][b]返回[/b]：实际进入的地图 ID（空 = 没有可续玩的图 / 存档不可用，
## 停在选图界面）。
static func resume_last(p_enter: Callable) -> StringName:
	var gsm: Node = _gsm()
	if gsm == null:
		push_warning("ExplorationEntryFlow: GSM 不可用，读档续玩中止")
		return &""
	var exploration: Variant = gsm.get(&"exploration")
	if not (exploration is Dictionary):
		return &""
	var map_id: StringName = StringName(str(
			(exploration as Dictionary).get("current_map", "")))
	if map_id.is_empty():
		# 存档里没有进行中的图（在选图界面存的档 / 第一次进探索）——不臆造一张
		return &""
	_enter(p_enter, map_id, true)
	return map_id


## 调进图出口（未接线时静默跳过——缺一条接线不该变成崩溃）。[br]
static func _enter(p_enter: Callable, p_map_id: StringName, p_resume: bool) -> void:
	if p_enter.is_valid():
		p_enter.call(p_map_id, p_resume)


## GSM 查找——本模块是静态工具（无宿主可锚），按常驻路径取；不可用时返回 null。[br]
## [br][b]宿主进树与否都试一次[/b]：测试里探索容器挂在 GUT 的测试树上，而 Autoload
## 在 [code]/root[/code] 下——两者同一个 [SceneTree]，直接问 [code]root[/code] 即可。
static func _gsm() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath(String(GSM_PATH)))
