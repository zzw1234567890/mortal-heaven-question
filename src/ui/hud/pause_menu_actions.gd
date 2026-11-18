extends RefCounted
## PauseMenuActions —— 暂停菜单「存档 / 读档 / 返回主菜单」三条动作的编排。[br]
## [br][b]为什么单独一处[/b]：[code]pause_menu.gd[/code] 已接近 300 行软上限
## （.claude/docs/coding-standards.md），而「按了存档之后要写哪一格、读档走哪条
## 导航链、离开前存不存」与「按钮怎么摆、模糊动画怎么放、ESC 从哪进来」是两件事
## ——后者才是那份文件的职责（同 [code]main_menu_launch.gd[/code] 的拆因）。[br]
## [br][b]存档[/b]：走真实 [code]SaveLoadSystem.save_game[/code] 写自动槽（与场景
## 切换的自动存档同一格）——先由 GSM [code]serialize()[/code] 取载荷，写失败返回
## 失败文案，玩家留在菜单里不丢进度。[br]
## [br][b]读档[/b]：复用主菜单那条链（[code]LoadSlotPanel[/code] 选槽位 +
## [code]MainMenuLaunch.load_and_resume[/code] 读档 → 发续玩意图 → 转场探索）。[br]
## [br][b]为什么要「先判后走」两次读[/b]：读档失败（档损坏 / 空载荷）时必须
## [b]留在暂停菜单里给玩家一句交代[/b]，而转场一旦发出就收不回来（还得先解除
## [code]SceneTree.paused[/code]，否则新场景停在冻结态）。所以先探一次拿判定，
## 判定通过才让导航层真正走那一跳——同一格读两次，读档本身幂等。[br]
## [br][b]依赖注入[/b]（ADR-0031 §2 / 先例 [code]main_menu_launch.gd[/code]）：
## 本模块[b]不直引 Autoload[/b]——[code]save_load[/code] / [code]scene_manager[/code]
## / [code]gsm[/code] 三个引用由 [PauseMenu] 每次调用时透传（HUD 在 setup 时注入）。
## 测试换掉它们即可脱离真实文件系统。[br]
## [br][b]零状态所有权[/b]：本模块不写任何玩法数据——GSM 的恢复由
## [code]SaveLoadSystem.load_game[/code] 内部完成，「这次进探索要干什么」经
## [ExplorationEntryIntent] 作为跨场景意图传递。[br]
## [br]来源: ADR-0005（导航唯一入口）、ADR-0031 §2、design/ux/pause-menu.md、
## design/gdd/main-menu-system.md（新游戏 / 继续游戏 / 读档三条路径）。

## SaveLoadSystem 脚本常量——SaveSlotType / SaveResult / LoadResult 枚举真理来源。
const SLScript := preload("res://src/foundation/save_load_system.gd")
## 读档列表组装内核（主菜单与暂停菜单共用同一份槽位文案口径）。
const LogicScript := preload("res://src/ui/main_menu/main_menu_logic.gd")
## 读档 → 进探索那一跳的编排（含「成功但空载荷」的判别）。
const LaunchScript := preload("res://src/ui/main_menu/main_menu_launch.gd")
## 槽位选择面板（纯代码构建——零主菜单耦合，故暂停菜单可原样复用）。
const LoadSlotPanelScript := preload("res://src/ui/main_menu/load_slot_panel.gd")
## SceneManager 脚本常量——SceneID / TransitionType 枚举真理来源。
const SceneManagerScript := preload("res://src/foundation/scene_manager.gd")
## 战斗快照抓取（「战斗中存档 → 读档回到这场战斗」的存侧——见该类文档）。
const CaptureScript := preload("res://src/feature/combat/combat_resume_capture.gd")

## 成功存档的反馈文案（需求：存档成功后要有明确反馈）。
const TEXT_SAVED: String = "已存档"
## 失败文案（带错误码——排障时不必翻日志）。
const TEXT_SAVE_FAILED: String = "存档失败（错误码 %d）"
const TEXT_SAVE_UNAVAILABLE: String = "存档系统不可用，未能存档"
const TEXT_LOAD_UNAVAILABLE: String = "读档系统不可用"
const TEXT_LOAD_FAILED: String = "读档失败（错误码 %d）"
const TEXT_LOAD_EMPTY_PAYLOAD: String = "该存档没有可续玩的内容"
## 探索进度行模板（GAP-2 降级裁决——仅显示「层 N」，不建 map_id 映射表）。
const TEXT_PROGRESS: String = "探索进度：层 %d"
## 战斗存档已写入的反馈（比「已存档」多说一句，玩家才知道读回来会回到战场上）。
const TEXT_SAVED_IN_BATTLE: String = "已存档（读取此档将回到当前战斗）"

## SaveLoadSystem 引用（HUD 注入；测试替换）。
var save_load: Node = null
## SceneManager 引用（HUD 注入；测试替换）。
var scene_manager: Node = null
## GameStateManager 引用（存档载荷来源与进度行读取面）。
var gsm: Node = null
## CombatSystem 引用（战斗快照的战斗侧取数面；HUD 注入，测试替换）。[br]
## [br][b]不查 Autoload 兜底[/b]：与 [code]pause_menu_combat_exit.gd[/code] 同口径——
## 「有没有战斗」这个判断的真理来源是宿主注入的那一个（生产是常驻 CombatSystem，
## 测试是替身）；自己去 [code]/root[/code] 摸一个回来，会让「探索中存档」意外读到
## 别处留下的活跃战斗，把一场早打完的仗写进档。[br]
## [br][b]null = 没有战斗[/b]：快照退化为「未写入且无原因」，存档照常。
var combat: Node = null
## DeploymentSystem 引用（我方阵位 / 前后排快照的来源；HUD 注入，测试替换）。[br]
## [br][b]为什么不查 Autoload[/b]：同上——替身缺席时阵位块退化为空，快照里没有
## 我方条目，[code]is_resumable_payload[/code] 便判为不可续（宁可不续，也不续一场
## 有我方缺席的仗）。生产由 HUD 注入。
var deployment: Node = null

## 读档面板实例（复用式单例——建一次，开合只切 visible）。
var _panel: Control = null
## 读档编排子模块（懒建一次，注入引用每次透传）。
var _launch: RefCounted = null


# ═══════════════════════════════════════════════════════════════════════════════
# 存档
# ═══════════════════════════════════════════════════════════════════════════════

## 存档一次（真实写盘）。[br]
## [br][b]返回[/b]：[code]{ok: bool, message: String}[/code]——调用方据此决定
## 「留在菜单给反馈」还是「可以走了」。[br]
## [br][b]为什么失败不抛异常[/b]：写盘失败（磁盘满 / 校验不过）是玩家能理解的
## 结果，给一句话让他再试一次，比崩掉或静默离开强。[br]
## [br][b]战斗中的存档要多做一步[/b]（[method capture_battle]）：先抓战斗快照再
## 序列化——[code]battle[/code] 域不可持久化，不抓的话玩家「打了一半存个档」读回来
## 只有探索地图，那场仗连同残血静默消失。[br]
## [br][b]不可续战时给中文提示而不是静默存**（需求 D）**：存档照存（探索进度
## 是真的），但反馈里带上原因——否则玩家会以为读回来还能接着打。
func save_now() -> Dictionary:
	var result: Dictionary = {"ok": false, "message": ""}
	if save_load == null or not save_load.has_method(&"save_game"):
		push_error("PauseMenu: SaveLoadSystem 不可用——存档中止")
		result["message"] = TEXT_SAVE_UNAVAILABLE
		return result
	var battle: Dictionary = capture_battle()
	var payload: Dictionary = serialize_gsm()
	if payload.is_empty():
		# 序列化失败（serialize_gsm 已 push_error）——不以空载荷覆盖自动槽
		result["message"] = TEXT_SAVE_UNAVAILABLE
		return result
	var code: int = save_load.save_game(
			SLScript.SaveSlotType.AUTOSAVE, 0, payload, {})
	if code != SLScript.SaveResult.SUCCESS:
		push_error("PauseMenu: 保存失败（code=%d）" % code)
		result["message"] = TEXT_SAVE_FAILED % code
		return result
	result["ok"] = true
	result["message"] = _saved_message(battle)
	return result


## 抓一次战斗快照写进 GSM（**必须在 [method serialize_gsm] 之前调**）。[br]
## [br][b]返回[/b]：[code]{written: bool, reason: String}[/code]；不在战斗中时为
## 「未写入且无原因」（不打扰玩家——没打仗就没什么好说的）。[br]
## [br][b]为什么在暂停菜单这里抓而不是挂在战斗系统上[/b]：快照只在存档那一刻有意义，
## 而「状态何时变」有阶段 / 回合 / HP / 费用四条路径；逐处挂钩必然漏改一处，存档时
## 现拉一次拿到的就是那一刻的真值（同 [code]combat_resume_capture.gd[/code] 类文档）。
func capture_battle() -> Dictionary:
	var capture: RefCounted = CaptureScript.new()
	capture.combat = combat
	capture.deployment = deployment
	capture.gsm = gsm
	return capture.call(&"capture", _scene_id())


## 存档反馈文案——战斗快照写入时多说一句，不可续战时把原因摆出来。[br]
## [br][b]为什么不可续战也要存[/b]：探索进度 / 角色成长都在同一份档里，为一场
## 续不了的战斗拒绝整次存档是拿玩家的进度陪葬；说清楚比不存更负责。
func _saved_message(p_battle: Dictionary) -> String:
	var reason: String = str(p_battle.get("reason", ""))
	if bool(p_battle.get("written", false)):
		return TEXT_SAVED_IN_BATTLE
	if reason.is_empty():
		return TEXT_SAVED
	return "%s（当前战斗无法续战：%s）" % [TEXT_SAVED, reason]


## 当前场景 ID（存档里记「在哪个场景存的」；SceneManager 不可用时回退 EXPLORATION）。
func _scene_id() -> int:
	if scene_manager != null and scene_manager.has_method(&"get_current_scene_id"):
		return int(scene_manager.get_current_scene_id())
	return SceneManagerScript.SceneID.EXPLORATION


## 战斗系统节点（暂停菜单不注入它——战斗是常驻 Autoload；缺失时快照退化为「无战斗」）。[br]
## [br][b]为什么不用注入[/b]：暂停菜单在探索 / 战斗两处都会开，注入一份战斗系统引用
## 会让「探索中存档」也持有一个不该有的句柄；查表失败即视为不在战斗中，语义正确。[br]
## [br][b]为什么经 Engine.get_main_loop 而不是 gsm.get_tree[/b]：注入的 gsm 在测试里
## 可能是 RefCounted 替身（没有 get_tree），而本方法只想要「场景树根」。
func _combat_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath("CombatSystem"))


## 转场前先自动存档一次（需求：返回主菜单先存一次再走）。[br]
## [br][b]为什么不判返回值[/b]：这是「顺手留个底」，失败也不该拦住玩家离开；
## 真正的可见存档动作是菜单里的「存档」按钮（它给反馈）。[br]
## [br][b]为什么还会写两次[/b]：[code]SceneManager.request_scene_change[/code]
## 在 Phase 2 也会自动存档——同一槽位、同一份内容，幂等。
func auto_save_first() -> void:
	if save_load != null and save_load.has_method(&"auto_save"):
		save_load.auto_save()


## GSM 序列化（存档载荷）——防御式读取，GSM 不可用时 push_error 并返回空字典[br]
## （调用方以空字典走失败分支，不以空载荷覆盖自动槽）。[br]
## [br]注意：GSM 是 Autoload 节点（[code]/root/GameStateManager[/code]），
## [b]不是[/b] Engine singleton——[code]Engine.has_singleton()[/code] 对 Autoload
## 恒 false，不能用作探测分支。
func serialize_gsm() -> Dictionary:
	if gsm != null and gsm.has_method(&"serialize"):
		return gsm.serialize()
	push_error("PauseMenu: GameStateManager 不可用——存档载荷序列化失败")
	return {}


# ═══════════════════════════════════════════════════════════════════════════════
# 读档
# ═══════════════════════════════════════════════════════════════════════════════

## 读档列表条目（自动槽 + 手动 1-3——与主菜单同一份口径）。[br]
## [br][b]现取现画[/b]：不缓存槽位状态（暂停期间槽位可能已被别处写变）。
func loadable_entries() -> Array:
	var slots: Array = []
	if save_load != null and save_load.has_method(&"list_slots"):
		slots = save_load.list_slots()
	return LogicScript.loadable_slots(slots)


## 打开读档面板（复用主菜单的 [code]LoadSlotPanel[/code]）。[br]
## [br][param p_host] 挂载宿主（暂停菜单本体——面板随菜单一起被树隐藏）。[br]
## [br][b]为什么每次打开都重新 populate[/b]：槽位状态可能在菜单停留期间变了
## （另一进程、刚从存档按钮写了一次）。[br]
## [br][b]返回[/b]：面板实例；宿主不可用时 null。
func open_load_panel(p_host: Control) -> Control:
	if p_host == null:
		return null
	if _panel == null or not is_instance_valid(_panel):
		_panel = LoadSlotPanelScript.new()
		# 信号接到宿主（PauseMenu）——面板只报意图，动作仍在宿主那条链上。
		_panel.connect(&"slot_chosen", Callable(p_host, &"_on_load_slot_chosen"))
		_panel.connect(&"back_requested", Callable(p_host, &"_on_load_panel_back"))
		p_host.add_child(_panel)
	_panel.call(&"populate", loadable_entries())
	_panel.call(&"open")
	var first: Variant = _panel.call(&"first_enabled_button")
	if first is Button and (first as Button).is_inside_tree():
		(first as Button).grab_focus()
	return _panel


## 收起读档面板（留树复用——下次打开不重建控件）。
func close_load_panel() -> void:
	if _panel != null and is_instance_valid(_panel):
		_panel.call(&"close")


## 读档面板是否处于打开态（ESC 分层用：面板在时 ESC 先收面板）。
func is_load_panel_open() -> bool:
	return _panel != null and is_instance_valid(_panel) \
			and bool(_panel.call(&"is_open"))


## 读某一格并（能续时）导航过去。[br]
## [br][b]返回[/b]：[code]{navigated: bool, message: String}[/code]。[br]
## [br][b]两步顺序不可反[/b]（见类文档「为什么要先判后走两次读」）：先探一次拿
## 判定，能续才调 [code]load_and_resume[/code]（它发续玩意图 + 请求转场）。
## 调用方在 [code]navigated == true[/code] 之后才解除暂停——否则新场景停在冻结态。
func load_slot(p_slot_type: int, p_slot_id: int) -> Dictionary:
	if save_load == null or not save_load.has_method(&"load_game"):
		return {"navigated": false, "message": TEXT_LOAD_UNAVAILABLE}
	var probe: Dictionary = save_load.load_game(p_slot_type, p_slot_id)
	var code: int = int(probe.get("result", SLScript.LoadResult.DESERIALIZE_ERROR))
	if code != SLScript.LoadResult.SUCCESS:
		return {"navigated": false, "message": TEXT_LOAD_FAILED % code}
	if not LaunchScript.has_payload(probe):
		# 成功但空载荷——文件没坏，只是没有可续玩的内容（不导航，也不说谎）
		return {"navigated": false, "message": TEXT_LOAD_EMPTY_PAYLOAD}
	var navigation: int = int(get_launch().call(&"load_and_resume",
			p_slot_type, p_slot_id))
	if navigation != SLScript.LoadResult.SUCCESS:
		return {"navigated": false, "message": TEXT_LOAD_FAILED % navigation}
	return {"navigated": true, "message": ""}


# ═══════════════════════════════════════════════════════════════════════════════
# 退出
# ═══════════════════════════════════════════════════════════════════════════════

## 返回主菜单（先自动存档一次再转场——GAP-5 裁决）。[br]
## [br][b]为什么不判存档结果[/b]：[method auto_save_first] 是「顺手留个底」，
## 失败不该拦住玩家离开（真正的可见存档是「存档」/「保存并退出」两个按钮，
## 它们给反馈）。[br]
## [br]from 取 [code]get_current_scene_id()[/code] 动态值（code-review M-2——
## 去魔数 + 不假设调用场景）；SceneManager 不可用时缺省 EXPLORATION。
func request_main_menu() -> void:
	auto_save_first()
	navigate_main_menu()


## 请求转场回主菜单。[br]
## [br]与 [method request_main_menu] 分开是给「保存并退出」用——那条路刚写过盘，
## 不必再顺手存一次（走同一个转场出口，不复制第二份转场参数）。
func navigate_main_menu() -> void:
	if scene_manager == null or not scene_manager.has_method(&"request_scene_change"):
		push_error("PauseMenu: SceneManager 不可用——返回主菜单转场中止")
		return
	var from_id: int = SceneManagerScript.SceneID.EXPLORATION  # 缺省值（守卫失败回退）
	if scene_manager.has_method(&"get_current_scene_id"):
		from_id = scene_manager.get_current_scene_id()
	else:
		push_warning("PauseMenu: get_current_scene_id 缺失——转场 from 缺省 EXPLORATION")
	scene_manager.request_scene_change(from_id,
			SceneManagerScript.SceneID.MAIN_MENU,
			SceneManagerScript.TransitionType.GAME_TO_MENU)


# ═══════════════════════════════════════════════════════════════════════════════
# 查询
# ═══════════════════════════════════════════════════════════════════════════════

## 探索进度行文案（零状态所有权——每次现读 GSM，不缓存副本）。[br]
## layer 为 0 基，显示时转 1 基（「层 N」）。
func progress_text() -> String:
	var layer_display: int = 1
	if gsm != null:
		var exploration: Variant = gsm.get("exploration")
		if exploration is Dictionary:
			# 键存在但值为 null 时 Dictionary.get 默认值不生效——显式判型
			var node_pos: Variant = (exploration as Dictionary).get("node_position")
			if node_pos is Dictionary:
				layer_display = int((node_pos as Dictionary).get("layer", 0)) + 1
	return TEXT_PROGRESS % layer_display


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 读档编排子模块——懒建一次；每次透传当前注入引用（宿主在 _ready 之后才赋值）。[br]
## [br][b]gsm 也要透传[/b]：编排层用它判「这份档在不在战斗中」（读档 → 战斗场景那条
## 分岔）。不传的话它只能回退 [code]host[/code] 找 Autoload，而暂停菜单这份的
## [code]host[/code] 是空的——续战段恒读成空，玩家在战斗中读档会被送回探索地图。
func get_launch() -> RefCounted:
	if _launch == null:
		_launch = LaunchScript.new()
	_launch.scene_manager = scene_manager
	_launch.save_load = save_load
	_launch.gsm = gsm
	return _launch
