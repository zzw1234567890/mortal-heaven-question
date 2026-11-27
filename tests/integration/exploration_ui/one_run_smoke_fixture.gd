extends "res://tests/integration/exploration_ui/one_run_base_fixture.gd"
## OneRunSmokeFixture —— 一周目冒烟「前三步」用例的共享装置。[br]
## [br][b]承接[/b]：[code]one_run_base_fixture.gd[/code] 给底座（真实 Autoload +
## 场景管理器桩 + 存档隔离），本文件只装「主菜单 → 身份选择 → 探索」这三段编排，
## 以及各段都要读的探索状态查询。[br]
## [br][b]为什么还要再拆战斗段[/b]：战斗相关的那组动作（点格 → 弹窗 → 确认开战 →
## 走到 Boss）比这层更窄，只有战斗用例需要，见 [code]one_run_battle_fixture.gd[/code]。
## 不拆的话三个用例文件共用的这份会越过 300 行软上限
## （.claude/docs/coding-standards.md）。[br]
## [br][b]文件前缀[/b]：不以 [code]test_[/code] 开头——只作基类被继承。[br]
##
## 来源: design/gdd/main-menu-system.md（三条路径）、design/gdd/exploration-system.md
## §1/§4、design/gdd/exploration-ui-system.md §1、ADR-0005、ADR-0014、ADR-0031 §2。

const SceneScript := preload("res://src/feature/exploration/exploration_scene.gd")
const MainMenuScene := preload("res://src/ui/main_menu/MainMenu.tscn")
## 身份选择跨场景意图（用例里显式清掉「新游戏」强制意图，见 open_identity_select）。
const IdentityIntentScript := preload("res://src/ui/identity_select/identity_select_intent.gd")
const IdentityScene := preload("res://src/ui/identity_select/identity_select.tscn")

var scene: Control = null
var menu: Control = null


# ═══════════════════════════════════════════════════════════════════════════════
# 第 1 步：主菜单「新游戏」
# ═══════════════════════════════════════════════════════════════════════════════

## 挂载真实主菜单（注入桩；关动画——用例关心路由不关心入场演出）。
func open_main_menu() -> Control:
	menu = MainMenuScene.instantiate() as Control
	menu.set(&"animate", false)
	menu.set(&"scene_manager", mock_sm)
	menu.set(&"save_load", mock_sl)
	add_child_autofree(menu)
	return menu


## 点「新游戏」按钮（走生产按钮的处理器，不是绕过它直调导航）。
func press_new_game() -> void:
	assert_not_null(menu, "前置：主菜单已挂载")
	menu.call(&"_on_new_game_pressed")


## 最近一次导航的目标场景 ID（-1 = 没有导航请求）。
func last_nav_target() -> int:
	return -1 if mock_sm == null else mock_sm.call(&"last_target")


# ═══════════════════════════════════════════════════════════════════════════════
# 第 2 步：身份选择
# ═══════════════════════════════════════════════════════════════════════════════

## 挂载真实身份选择场景（注入桩；关动画）。[br]
## [br][b]本 fixture 不代表「新游戏」[/b]：它模拟的是「身份已选过 ⇒ 跳过选择 UI」那条路
## （读档续玩 / 用例直接摆好身份态），所以先把主菜单「新游戏」落的强制意图清掉；
## 「新游戏必须走选择页」由 [code]test_new_game_forces_identity_select.gd[/code] 单独守。
func open_identity_select() -> Control:
	IdentityIntentScript.clear()
	var screen: Control = IdentityScene.instantiate() as Control
	screen.set(&"animate", false)
	screen.set(&"scene_manager", mock_sm)
	add_child_autofree(screen)
	return screen


## 身份表首项（默认解锁的那个）——不硬编码身份 ID。
func first_identity_id() -> StringName:
	var ids: Array = TemplatesScript.IDENTITY_TEMPLATES.keys()
	return &"" if ids.is_empty() else StringName(str(ids[0]))


## 在身份选择界面选中某身份并走确认（含二次门禁与 [code]apply_identity[/code]）。[br]
## [br][b]返回[/b]：确认路径是否被受理（门禁拦住时为 false）。
func confirm_identity(screen: Control, p_identity_id: StringName) -> bool:
	var entry: Dictionary = _entry_of(screen, p_identity_id)
	if entry.is_empty():
		return false
	screen.set(&"selected_id", p_identity_id)
	screen.set(&"selected_entry", entry)
	screen.call(&"_on_confirm_pressed")
	screen.call(&"_on_confirm_dialog_confirmed")
	return true


## 跳过开局叙事（真实路径上的跳过入口——同玩家按任意键）。[br]
## [br][b]为什么必须走它[/b]：确认之后要等叙事收尾才发导航请求；不跳过就停在
## 身份选择——「导航到探索」这条断言会假红。[br]
## [br][b]不直调 [code]skip_narrative[/code] 到宿主之外[/b]：宿主自己就拦了
## [code]_input[/code]，但本装置直接经 Presenter 的公开方法触发同一段收尾
## （叙事不可见时它自己返回——此时什么都不做）。
func skip_narrative(screen: Control) -> void:
	var presenter: Variant = screen.call(&"_get_presenter")
	if presenter != null:
		presenter.call(&"skip_narrative")


func _entry_of(screen: Control, p_identity_id: StringName) -> Dictionary:
	var nav: Variant = screen.call(&"_get_nav")
	var isys: Variant = nav.call(&"get_identity_system")
	if isys == null or not isys.has_method(&"get_available_identities"):
		return {}
	for entry: Dictionary in isys.call(&"get_available_identities"):
		if StringName(str(entry.get(&"identity_id", ""))) == p_identity_id:
			return entry
	return {}


# ═══════════════════════════════════════════════════════════════════════════════
# 第 3 步：探索
# ═══════════════════════════════════════════════════════════════════════════════

## 挂载真实探索薄容器——它会消费 [ExplorationEntryIntent]（新开局 → 首图）。[br]
## [br][b]为什么在这里挂而不是让主菜单导航真的发生[/b]：转场由桩拦下，
## 「导航到探索」与「探索真的挂起来」是两段；本方法接手第二段。
func open_exploration() -> Control:
	scene = SceneScript.new() as Control
	add_child_autofree(scene)
	return scene


## 探索容器当前的节点图屏幕（未进图时为 null）。
func node_graph() -> Variant:
	return null if scene == null else scene.get(&"node_graph_screen")


## 探明表首项（表序即剧情顺序）——青云剑宗。
func first_map_id() -> StringName:
	return IntentScript.first_map_id()


## GSM 里当前图。
func current_map() -> StringName:
	return StringName(str(gsm.exploration.get("current_map", "")))


## 剩余行动力 / 上限。
func ap() -> int:
	return int(gsm.exploration.get("action_points", 0))


func max_ap() -> int:
	return int(gsm.exploration.get("max_action_points", 0))


## 已访问节点列表（入口节点在进图那一刻就应记入）。
func visited() -> Array:
	return gsm.exploration.get("visited_nodes", [])


## 当前地图的邻接表（节点图渲染的那份）。
func graph() -> Dictionary:
	var raw: Variant = es.get(&"_node_graph")
	return raw if raw is Dictionary else {}


func map_state(p_map_id: StringName = &"") -> Dictionary:
	var target: StringName = p_map_id if p_map_id != &"" else current_map()
	var states: Dictionary = gsm.exploration.get("map_states", {})
	var state: Variant = states.get(target, {})
	return state if state is Dictionary else {}


func ling_shi() -> int:
	return int(gsm.player.resources.get("ling_shi", 0))


## 探明表的全部地图 ID（表序）。
func catalog_ids() -> Array:
	return CatalogScript.MAPS.keys()


# ═══════════════════════════════════════════════════════════════════════════════
# 图结构查询（第 4、5 步共用）
# ═══════════════════════════════════════════════════════════════════════════════

## 系统持有的 Boss 节点 ID（取节点详情里类型为 Boss 的最大 ID——末层固定）。[br]
## [br][b]不读 [code]generate_map[/code] 的返回值[/b]：意图消费路径只把渲染快照
## 交给 UI，[code]boss_node_id[/code] 不在快照里；从节点详情反查才是同一份事实。
func boss_node_id() -> int:
	var nodes: Dictionary = es.get(&"_node_details")
	var boss: int = -1
	for node_id: Variant in nodes.keys():
		if int(es.call(&"_get_node_type", int(node_id))) == int(es.get(&"NodeType").BOSS):
			boss = maxi(boss, int(node_id))
	return boss


## 入口的后继里第一个「要花行动力」的节点（AP 拒绝用例要挑不豁免的目标）。[br]
## [br][b]判据取自系统本身[/b]（[code]ap_cost_to[/code]）：不在这里重抄豁免表，
## 否则改豁免规则后用例会去挑一个不花 AP 的节点、断言随之失真。
func first_non_exempt_hop() -> int:
	var adjacency: Dictionary = graph()
	for neighbor: Variant in adjacency.get(ENTRY_NODE, []):
		var node: int = int(neighbor)
		if int(es.call(&"ap_cost_to", node)) > 0:
			return node
	return -1


## 从入口到 [param p_target] 的一条真实路径（广度优先，取最短）。[br]
## [br][b]返回[/b]：按行走顺序排列的节点 ID（不含入口；不可达时为空数组）。
func path_to(p_target: int) -> Array[int]:
	var adjacency: Dictionary = graph()
	var queue: Array[int] = [ENTRY_NODE]
	var came_from: Dictionary = {ENTRY_NODE: -1}
	while not queue.is_empty():
		var current: int = queue.pop_front()
		if current == p_target:
			break
		for neighbor: Variant in adjacency.get(current, []):
			var node: int = int(neighbor)
			if came_from.has(node):
				continue
			came_from[node] = current
			queue.append(node)
	if not came_from.has(p_target):
		return []
	var path: Array[int] = []
	var cursor: int = p_target
	while cursor != ENTRY_NODE and cursor != -1:
		path.push_front(cursor)
		cursor = int(came_from.get(cursor, -1))
	return path


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 进首图（生产时序：意图落盘 → 容器消费）。[br]
## [br][b]与 [method start_new_run] 的分工[/b]：这一条只走「探索容器消费意图」那
## 一跳，用来单验进图本身（AP / 入口 / DAG 快照）；要走完整开局（身份 → 阵容）
## 的用例用 [method start_new_run]。
func enter_first_map() -> void:
	IntentScript.request_new_run()
	open_exploration()


## 走完真实开局前三步，落在首图的节点图上。[br]
## [br][b]为什么不能省掉身份那一步[/b]：玩家出战阵容与初始卡组都是
## [code]apply_identity[/code] 写进 [code]deck.slots[/code] / [code]deck.cards[/code]
## 的（[code]identity_selection_system.gd:257-260[/code]）。只发意图直进地图的话
## 阵容是空的——后面「我方出战名单非空」的断言会红，而那是用例自造的假红。
## 端到端用例的意义正在于走真路，所以这里如实走完。
func start_new_run() -> void:
	open_main_menu()
	press_new_game()
	var screen: Control = open_identity_select()
	confirm_identity(screen, first_identity_id())
	skip_narrative(screen)
	# 2026-11-27 起身份确认不再落 FIRST_MAP（听风报的 bug）——新开局停在选图界面。
	# 这一层 fixture 的用途是「走完开局后落在首图节点图上」，所以由 fixture 自己补上
	# 「玩家点了第一张图」那一跳；专门验「停在选图界面」的用例不走这里。
	IntentScript.request_new_run()
	open_exploration()
