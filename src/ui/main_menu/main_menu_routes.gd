extends RefCounted
## MainMenuRoutes —— 主菜单的导航出口与读档三条路径的收尾（从 main_menu.gd 拆出）。[br]
## [br][b]职责[/b]：把一次按钮点击翻成一个转场请求或一次读档——新游戏 / 继续游戏 /
## 读档选中 / 卡组编辑 / 退出，以及两张存档信号进来之后做什么。[br]
## [b]不管什么[/b]：不建控件、不摆布局、不写文案、不判两个按钮的亮灭
## （控件与按钮态归 [MainMenuOverlays] / [MainMenuSaveState]）。[br]
## [br][b]为什么单独成文件[/b]：[code]main_menu.gd[/code] 超 300 行软上限
## （.claude/docs/coding-standards.md），而「按下去往哪走」与「界面上有什么、怎么摆」
## 是两件事——后者才是那份文件的职责。[br]
## [br][b]导航唯一入口[/b]（ADR-0005 / control-manifest 必需模式）：一律经
## [code]SceneManager.request_scene_change[/code]，绝不直调
## [code]change_scene_to_file[/code]；[code]from[/code] 动态取
## [code]get_current_scene_id()[/code]（先例 PauseMenu M-2 去魔数）。[br]
## [br][b]读档那两条共用 [MainMenuLaunch][/b]：读档 → 发跨场景意图 → 请求转场三件事
## 在那里一条线走完（含「成功但载荷为空」的判别）；本件只多管一件事——
## [b]失败才弹损坏框[/b]：成功但载荷为空、或依赖不可用都不弹，文件没坏，
## 弹「存档损坏」是在对玩家说谎。[br]
## [br][b]依赖解析归宿主一处[/b]：SceneManager / SaveLoadSystem / 读档编排 /
## 按钮态重刷都经宿主既有的 [code]_get_scene_manager[/code] /
## [code]_get_save_load[/code] / [code]_get_launch[/code] /
## [code]_refresh_save_state[/code] 取——注入覆盖表只有一份，两个模块各写一份
## 回退规则迟早会漂移（测试在 [code]_ready[/code] 之后才注入引用，各模块自己
## 抄一份就会读到真实 Autoload）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：[b]什么都不缓存[/b]——存档列表每次现读；
## 点击时的判定与 [code]disabled[/code] 态可能已不一致（别处刚写过盘），此时重刷一次
## 界面而不是拿旧决定办事。[b]零轮询[/b]：无 [code]_process()[/code]。
##
## 来源: ADR-0005（导航唯一入口）、ADR-0031 §2、design/gdd/main-menu-system.md
## （新游戏 / 继续游戏 / 读档三条路径）、story-001-main-menu-scene.md
## （AC-003 / 004 / 006 / 007）。

## SceneManager 脚本常量——SceneID / TransitionType 枚举真理来源（同宿主口径，
## 替换裸数字防枚举重排静默漂移——code-review H-1）。
const SceneManagerScript := preload("res://src/foundation/scene_manager.gd")
## SaveLoadSystem 脚本常量——LoadResult 枚举真理来源（点击继续的返回值判定去魔数）。
const SLScript := preload("res://src/foundation/save_load_system.gd")
## 存档判定内核（「继续游戏」要挑最新那一格；本件不另写一份挑选规则）。
const Logic := preload("res://src/ui/main_menu/main_menu_logic.gd")
## 卡组编辑的来路意图（「保存并返回」该回哪——见那边类文档）。
const DeckEditingEntryScript := preload(
		"res://src/ui/deck_editing/deck_editing_entry.gd")


## 新游戏 → 身份选择（AC-main-menu-004）。[br]
## [br][b]失败语义[/b]：SceneManager 不可用（null / 缺
## [code]request_scene_change[/code]）时 [method @GlobalScope.push_error] 中止，
## 不崩溃（测试以「缺方法的 mock」走这条守卫分支）。[br]
## [br][b]返回[/b]：是否发出了转场请求（守卫拦下时为 false）。
static func new_game(p_host: Node) -> bool:
	var sm: Node = get_scene_manager(p_host)
	if sm == null or not sm.has_method(&"request_scene_change"):
		push_error("MainMenu: SceneManager 不可用——新游戏导航中止")
		return false
	sm.request_scene_change(resolve_from(sm),
			SceneManagerScript.SceneID.IDENTITY_SELECT,
			SceneManagerScript.TransitionType.MENU_TO_GAME)
	return true


## 继续游戏 → 读最近存档并[b]回到上次那张图[/b]（AC-main-menu-003 + 损坏路径）。[br]
## [br][b]此前这里是死路[/b]：读档成功后没有任何导航——玩家点了按钮，界面纹丝不动，
## 只有损坏分支有后续（弹对话框）。「继续游戏」的全部意义就在读完那一跳。[br]
## [br][b]零状态所有权副作用[/b]：disabled 判定与点击之间列表可能已变——挑不到档时
## 先重刷一次界面，仍空则按无存档处理（不弹损坏框，静默禁用）。[br]
## [br][b]返回[/b]：读档返回码（挑不到档时为 SUCCESS——「无档可读」不是损坏）。
static func continue_game(p_host: Node) -> int:
	var continue_button: Button = p_host.get(&"continue_button") as Button
	if continue_button != null and continue_button.disabled:
		return SLScript.LoadResult.SUCCESS  # 守卫：disabled 态不可达（键盘焦点防御）
	var slots: Array = list_slots(p_host)
	var latest: Dictionary = Logic.select_latest_save(slots)
	if latest.is_empty():
		refresh(p_host)
		return SLScript.LoadResult.SUCCESS
	return read_slot(p_host,
			int(latest.get("slot_type", 0)), int(latest.get("slot_id", 0)))


## 玩家在读档面板选中一格——执行与「继续游戏」同一条读档链。[br]
## [br]面板已在 [method LoadSlotPanel._on_slot_pressed] 里自行收起（先收起再报意图，
## 避免读档成功转场时两层画面叠在一起）。[br]
## [br]失败弹损坏框——与「继续游戏」同一条判别（同一份存档，两条路径不该给两种说法）。
## [br][br][b]返回[/b]：读档返回码。
static func load_slot(p_host: Node, p_slot_type: int, p_slot_id: int) -> int:
	return read_slot(p_host, p_slot_type, p_slot_id)


## 「卡组编辑」→ 进卡组编辑场景（[code]SceneID.DECK_EDITING[/code]）。[br]
## [br][b]与「行囊与道友」相反：这一条是转场而不是覆盖层[/b]——整屏两栏编辑与主菜单
## 的按钮列没有共存的余地（ADR-0031 §1：能一屏共存才用覆盖层）。[br]
## [br][b]先记来路再请求转场[/b]：编辑屏挂载时已无从知道是谁开的它，
## [code]DeckEditingEntry[/code] 记下这一枚场景 ID，「保存并返回」据此回到主菜单
## （而不是把玩家丢进探索）。[br]
## [br][b]转场类型 MENU_TO_GAME[/b]：音频矩阵按它索引（主菜单 → 游戏的长淡入）。[br]
## [br][b]返回[/b]：是否发出了转场请求。
static func deck_edit(p_host: Node) -> bool:
	var sm: Node = get_scene_manager(p_host)
	if sm == null or not sm.has_method(&"request_scene_change"):
		push_error("MainMenu: SceneManager 不可用——卡组编辑导航中止")
		return false
	var from_id: int = resolve_from(sm)
	DeckEditingEntryScript.request_edit(from_id)
	sm.call(&"request_scene_change", from_id,
			SceneManagerScript.SceneID.DECK_EDITING,
			SceneManagerScript.TransitionType.MENU_TO_GAME)
	return true


## 退出 → 关闭进程（AC-main-menu-006；UX 规范：直接退出无确认）。[br]
## [br][b]返回[/b]：是否发出了退出请求（宿主未入树、取不到树时为 false——不崩）。
static func quit(p_host: Node) -> bool:
	var tree: SceneTree = p_host.get_tree()
	if tree == null:
		return false
	tree.quit()
	return true


## 读档完成信号回调——无论成败（转场或弹窗路径）刷新存档状态。[br]
## Cat 2b 动作通知（ADR-0007）——UI 只读刷新，不写状态。
static func save_load_completed(p_host: Node, _success: bool) -> void:
	refresh(p_host)


## save_corrupted 信号回调（GDD 边缘情况）——弹「存档损坏，无法读取」提示。[br]
## 对话框确认后走 [method corrupt_confirmed] 恢复按钮可用态。
static func save_corrupted(p_host: Node, _slot_type: int, _slot_id: int,
		_reason: String) -> void:
	show_corrupt(p_host)


## 损坏对话框确认回调——刷新存档状态（确认后按钮恢复可用态语义：若损坏存档仍为
## 唯一存档，重刷后依旧亮起——点击再次走损坏路径，与 AC-3 自洽）。
static func corrupt_confirmed(p_host: Node) -> void:
	refresh(p_host)


## 弹「存档损坏，无法读取」（对话框缺失 / 宿主未装配时静默——界面缺失不该让
## 读档链崩掉）。
static func show_corrupt(p_host: Node) -> void:
	var dialog: Object = p_host.get(&"corrupt_dialog") as Object
	if dialog != null:
		dialog.call(&"show_corrupt")


## === 内部 ======================================================================

## 读某一格；失败（含依赖不可用）弹损坏框。[br]
## [br][b]为什么不判「成功但载荷为空」[/b]：那一跳的判别在
## [method MainMenuLaunch.load_and_resume] 内部（它按返回码语义停住，不导航），
## 本件只看返回码——返回 SUCCESS 就是「读到了、也走了」，返回非 SUCCESS 才是损坏。
static func read_slot(p_host: Node, p_slot_type: int, p_slot_id: int) -> int:
	var code: int = int(load_and_resume(p_host, p_slot_type, p_slot_id))
	if code != SLScript.LoadResult.SUCCESS:
		show_corrupt(p_host)
	return code


## 读档编排（宿主 [code]_get_launch[/code]——注入引用每次由它透传，测试在
## [code]_ready[/code] 之后才赋值）。
static func load_and_resume(p_host: Node, p_slot_type: int, p_slot_id: int) -> int:
	var launch: RefCounted = p_host.call(&"_get_launch")
	return int(launch.call(&"load_and_resume", p_slot_type, p_slot_id))


## 存档列表（宿主 [code]_list_slots_safe[/code]——零缓存、防御读取）。
static func list_slots(p_host: Node) -> Array:
	var slots: Variant = p_host.call(&"_list_slots_safe")
	return slots if slots is Array else []


## 重刷按钮态（宿主 [code]_refresh_save_state[/code]）。
static func refresh(p_host: Node) -> void:
	p_host.call(&"_refresh_save_state")


## SceneManager——解析归宿主一处（注入项在测试里被替换过，各模块自抄回退规则会漂移）。
static func get_scene_manager(p_host: Node) -> Node:
	return p_host.call(&"_get_scene_manager") as Node


## 转场 [code]from[/code]——动态取当前场景 ID（去魔数）。[br]
## [br][b]为什么取不到时回退 MAIN_MENU[/b]：本件只被主菜单调用，回退值与「谁是
## 调用方」一致；SceneManager 缺 [code]get_current_scene_id[/code] 时沿用该回退。
static func resolve_from(p_scene_manager: Node) -> int:
	if p_scene_manager != null \
			and p_scene_manager.has_method(&"get_current_scene_id"):
		return int(p_scene_manager.call(&"get_current_scene_id"))
	return SceneManagerScript.SceneID.MAIN_MENU
