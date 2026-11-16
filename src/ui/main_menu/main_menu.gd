class_name MainMenu
extends Control
## MainMenu —— 主菜单场景（main-menu Story 001）。
##
## [b]节点形态[/b]（ADR-0031 §1）：场景内 Control 树（零新增 Autoload），
## 由 SceneManager 场景路径注册表 [code]res://src/ui/main_menu/MainMenu.tscn[/code]
## 挂载（[constant SceneManager.SCENE_PATHS] MAIN_MENU 条目）。[br]
## [br][b]结构[/b]（UX 规范「左序右境」方案 B 骨架——背景动态场景归打磨 story，
## 本 story 为布局/交互骨架）：标题 + 4 按钮（新游戏/继续游戏/设置/退出）+
## 存档摘要行（继续按钮旁，无存档时 visible=false 占位保留）+ 版本号（左下角）
## + 损坏提示对话框（AcceptDialog——存档损坏路径）。[br]
## [br][b]Logic 内核[/b]：全部存档判定走 [MainMenuLogic] 纯函数（control-manifest
## Presentation 必需模式——「存档存在性判定提取纯函数」）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：存档存在性/摘要不缓存——
## [method _refresh_save_state] 每次从 SaveLoadSystem [code]list_slots()[/code]
## 读取（_ready + 返回主菜单时 [method _on_save_load_completed] 刷新）。[br]
## [br][b]场景导航[/b]：新游戏→身份选择经 [code]SceneManager.request_scene_change(
## MAIN_MENU, IDENTITY_SELECT)[/code]（control-manifest 必需——禁止直调
## change_scene_to_file）；设置按钮（Story 002 恢复启用）→ 实例化
## [SettingsPanel] 挂载本节点树并打开（ADR-0031 §1 场景内节点——设置面板为
## 主菜单子 Control，非独立场景切换，不经 SceneManager）。[br]
## [br][b]损坏路径[/b]（GDD 边缘情况）：点击继续 → [code]load_game()[/code] 返回非
## SUCCESS 或 [signal SaveLoadSystem.save_corrupted] → 弹「存档损坏，无法读取」
## AcceptDialog → 确认后返回主菜单（按钮恢复可用）。[br]
## [br][b]焦点导航[/b]（story Implementation Notes）：焦点顺序 新游戏→继续→设置→
## 退出（VBox 树序天然满足）；初始焦点 = 继续游戏（无存档回退新游戏）。[br]
## [code]grab_focus()[/code] 在 4.6 双焦点下只影响键盘/手柄焦点（story Engine
## Notes）。焦点环+悬停双视觉（ADR-0031 §4）由引擎默认主题 + 后续视觉 story
## 落实（本 story 骨架先例 PauseMenu 同源）。[br]
## [br][b]动画[/b]：0.8s 淡入 + 标题滑落（GDD §视觉/音频需求表）——Tween 纯视觉
## 变换豁免（ADR-0031 §3 零轮询）。[member animate] 为 reduce-motion 预留接线点
##（设置系统 Story 003 入库后接入——先例 [member NotificationToastArea.animate]）。
## [br][br][b]零轮询[/b]：无 [code]_process()[/code]。
## [br][br][b]启动承载者[/b]（gate-check 2026-11-08 §B1）：主菜单是 [code]run/main_scene[/code]，
## 由它在 [method _ready] 经 [HudBootstrap] 把全局 HUD 挂进
## [code]SceneManager.PersistentLayer[/code]——此后所有转场 HUD 常驻，主菜单本体结构不变。
## 「只在当前主场景时挂载」的守卫见 [method _mount_global_hud]。
##
## @experimental
## 来源: ADR-0031、design/gdd/main-menu-system.md、design/ux/main-menu.md、
## story-001-main-menu-scene.md。

## === Visual 常量（数据驱动）====================================================

## 冷启动入场动画总时长——0.8s（GDD §视觉/音频需求「主菜单加载 0.8s」）。
const INTRO_DURATION: float = 0.8
## 标题滑落起始位移（px，自上方 -60 滑入——UX 规范「标题从上方滑落」）。
const TITLE_SLIDE_OFFSET: float = -60.0

## 固定 UI 词条（GDD main-menu-system.md §2 原文；项目暂无本地化系统——
## 先例 CultivationBarState LABEL_* 同源豁免注记，本地化入库后替换为键）。
const TEXT_TITLE: String = "仙途问道"
const TEXT_NEW_GAME: String = "新游戏"
const TEXT_CONTINUE: String = "继续游戏"
const TEXT_SETTINGS: String = "设置"
const TEXT_QUIT: String = "退出"
## 「行囊与道友」入口文案——一个按钮开两个界面（背包 + 角色状态，宿主内页签切换）。
## 名字取「行囊（物）与道友（人）」：玩家的两类诉求各占一字，比「背包」更贴实际内容。
const TEXT_INVENTORY: String = "行囊与道友"
## 「读档」入口文案——与「继续游戏」（读最新档）并列的第三条路径：这一条让玩家
## 自己挑槽位。两条路径都能进游戏，差别只在这里（GDD §新游戏/继续游戏/读档）。
const TEXT_LOAD: String = "读档"
## 无存档时的中文提示（GDD 边界：无档时继续游戏置灰并给出说明）。[br]
## [br][b]为什么两个按钮各说一句[/b]：它们被禁用的原因不同——「继续游戏」要的是
## 「至少有一份档」，「读档」要的是「有一格非空槽位」；共用一句会让其中一边说谎。
const TEXT_NO_SAVE_CONTINUE: String = "还没有存档——先点「新游戏」开始一轮"
const TEXT_NO_SAVE_LOAD: String = "还没有任何存档槽位可读"

## 版本号缺省回退（ProjectSettings 未配置 version 键时的安全默认——
## story Implementation Notes「不硬编码」指不在 UI 层写死版本值，读取失败
## 仍需一个可显示占位）。
const VERSION_FALLBACK: String = "v?"

## === Logic 内核（preload——class_name 在测试动态加载下不可靠，先例
## scene_manager 持有子模块模式）===============================================

const Logic := preload("res://src/ui/main_menu/main_menu_logic.gd")

## SettingsPanel 场景——设置面板实例化源（Story 002；场景内节点模式 ADR-0031 §1）。
const SETTINGS_PANEL_SCENE: PackedScene = \
		preload("res://src/ui/main_menu/SettingsPanel.tscn")

## SceneManager 脚本常量——枚举单一真理来源（SceneID/TransitionType 均为
## const，preload 引用不依赖 Autoload 实例存在，与注入式设计兼容——
## code-review H-1 裁决：替换裸数字，防枚举重排静默漂移）。
const SceneManagerScript := preload("res://src/foundation/scene_manager.gd")
## SaveLoadSystem 脚本常量——LoadResult 枚举单一真理来源（同上，H-1 姊妹项：
## 点击继续的返回值判定去魔数）。
const SLScript := preload("res://src/foundation/save_load_system.gd")
## KeybindStore 脚本常量——启动按键加载（Story 004：键位持久化加载，
## GDD 边界澄清「重启不失效」）。
const KeybindStoreScript := preload("res://src/ui/main_menu/keybind_store.gd")
## HudBootstrap 脚本常量——全局 HUD 的生产挂载入口（gate-check §B1）。
## 主菜单是进程启动后的第一个场景（[code]run/main_scene[/code]），因此由它担任
## 「启动承载者」：HUD 经 [code]SceneManager.register_persistent()[/code] 挂入
## PersistentLayer 后跨场景常驻，主菜单本体结构不变（ADR-0031 §1.2）。
const HudBootstrapScript := preload("res://src/ui/hud/hud_bootstrap.gd")
## ExplorationBootstrap 脚本常量——探索系统的生产装配入口（地图配置 + 敌人池）。
## 与 HUD 同源：主菜单是启动承载者，探索系统的回调注入点必须在场景层装配，
## 而不是写进 ExplorationSystem 内部（DEBT-EUI-006-3 / DEBT-EUI-006-5）。
const ExplorationBootstrapScript := preload("res://src/feature/exploration/exploration_bootstrap.gd")
## 「行囊与道友」界面（背包 + 角色状态双页）——主菜单的覆盖层入口。
const InventoryScreensHostScript := preload("res://src/ui/inventory/inventory_screens_host.gd")
## 两页的只读模型——主菜单在装配时把 Autoload 接进去（面板不直连 Autoload）。
const InventoryModelScript := preload("res://src/feature/inventory/inventory_model.gd")
const StatusModelScript := preload("res://src/feature/inventory/character_status_model.gd")
## 背包内「使用丹药」的结算层——背包页只发意图，由宿主持有它去结算。
const PillUseScript := preload("res://src/feature/inventory/inventory_pill_use.gd")
## 读档槽位选择面板——「读档」按钮打开的覆盖层（纯代码构建，与设置面板同形态）。
const LoadSlotPanelScript := preload("res://src/ui/main_menu/load_slot_panel.gd")
## 读档 → 进探索这一跳的编排（含「成功但空载荷」的判别——见该模块类文档）。
const LaunchScript := preload("res://src/ui/main_menu/main_menu_launch.gd")

## === 依赖注入（测试可替换）=====================================================

## SceneManager 引用——导航转场用（null 时回退 Autoload，先例 PauseMenu）。
var scene_manager: Node = null
## SaveLoadSystem 引用——存档列表/读档用（null 时回退 Autoload，先例 PauseMenu）。
var save_load: Node = null
## 动画开关——测试注入 + reduce-motion 预留接线点（头注释）。
var animate: bool = true

## === 瞬态交互状态（ADR-0031 §2.1）=============================================

## 入场 Tween 句柄（新请求时 kill 防悬挂——先例 PauseMenu._blur_tween）。
var _intro_tween: Tween = null

## 设置面板实例——复用式单例（首次点击实例化，重开不重建——关闭后
## [code]visible=false[/code] 留树）。
var _settings_panel: SettingsPanel = null
## 「行囊与道友」界面实例——复用式单例（同设置面板的形态：首次点击实例化，
## 关闭留树）。它自带背包与角色状态两页，故主菜单只需一个入口按钮。[br]
## 类型写作 [Control] 而非其 [code]class_name[/code]：本脚本在测试里被动态加载，
## 全局类名注册时序不保证（先例 card_system 的「不依赖 class_name」注记）。
var _inventory_screens: Control = null
## 读档槽位选择面板实例——复用式单例（同设置面板形态：首次点击实例化，关闭留树）。
var _load_slot_panel: Control = null
## 读档编排子模块——懒建一次（注入引用在 [method _get_launch] 里透传）。
var _launch: RefCounted = null
## 按键绑定 store——启动加载用（Story 004；注入项供测试替换路径）。
var keybind_store: KeybindStore = null

## === 节点引用 ==================================================================

@onready var title_label: Label = $LayoutAnchor/TitleLabel
@onready var new_game_button: Button = $LayoutAnchor/ButtonBox/NewGameButton
@onready var continue_button: Button = $LayoutAnchor/ButtonBox/ContinueButton
@onready var save_summary_label: Label = $LayoutAnchor/ButtonBox/SaveSummaryLabel
@onready var settings_button: Button = $LayoutAnchor/ButtonBox/SettingsButton
@onready var quit_button: Button = $LayoutAnchor/ButtonBox/QuitButton
@onready var inventory_button: Button = $LayoutAnchor/UtilityBox/InventoryButton
@onready var load_button: Button = $LayoutAnchor/UtilityBox/LoadButton
@onready var no_save_hint_label: Label = $LayoutAnchor/NoSaveHintLabel
@onready var version_label: Label = $VersionLabel
@onready var corrupt_dialog: CorruptSaveDialog = $CorruptDialog

## === 生命周期 ==================================================================

func _ready() -> void:
	_apply_texts()
	_apply_version()
	_load_keybinds()
	_refresh_save_state()
	_connect_save_signals()
	_mount_global_hud_if_boot_scene()
	_mount_exploration_bootstrap()
	if animate:
		_play_intro()
	# 初始焦点：继续游戏优先（UX 规范场景 2「零摩擦中转站」），
	# 无存档回退新游戏（story Implementation Notes）。
	if continue_button.disabled:
		new_game_button.grab_focus()
	else:
		continue_button.grab_focus()

func _exit_tree() -> void:
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()

## === 全局 HUD 生产挂载（gate-check 2026-11-08 §B1）=============================

## 仅在「本节点就是运行中的主场景」时挂载全局 HUD。[br]
## [br][b]为什么延后一帧[/b]：场景切换时 [code]current_scene[/code] 要到整个装载流程
## 结束才落定，[code]_ready[/code] 内读取可能还是旧值；[method Node.call_deferred]
## 在空闲帧执行，读到的一定是最终值。[br]
## [br][b]为什么要这道守卫[/b]：集成测试把 MainMenu.tscn 当普通节点 add_child，
## 此时 [code]current_scene[/code] 不是它——不挂载，避免测试进程里凭空多出一个
## 常驻 HUD（它订阅全局 ESC 信号与转场信号）。生产路径（[code]run/main_scene[/code]，
## 含读档/转场回到主菜单）守卫恒真。
func _mount_global_hud_if_boot_scene() -> void:
	if not is_inside_tree():
		return
	call_deferred(&"_mount_global_hud")

## 守卫实现——[b]测试可直接调用 [method _mount_global_hud]（守卫）/ [method _mount_hud]（无守卫）[/b]。
## [br][b]current_scene 为 null 时放行[/b]：场景切换的中间态（旧场景已释放、新场景
## 尚未登记）不该被误判成「不是主场景」而漏挂；此时本节点必然就是刚装载的主菜单。
func _mount_global_hud() -> void:
	if not is_inside_tree():
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var current: Node = tree.current_scene
	if current != null and current != self:
		return
	_mount_hud()

## 挂载全局 HUD（幂等——重复进入主菜单复用同一实例）。[br]
## [br][b]返回[/b]：已挂载的 HUD；SceneManager 不可用/不支持时 null（静默降级）。
func _mount_hud() -> CanvasLayer:
	return HudBootstrapScript.mount(_get_scene_manager())

## === 探索系统生产装配（地图配置 + 敌人池）====================================

## 把地图配置目录与敌人池接进 ExplorationSystem 的注入点。[br]
## [br][b]为什么由主菜单做[/b]：与 HUD 挂载同源——启动承载者负责把「数据实现」
## 接到「系统接口」上；系统内部不硬编码地图表与敌人池。[br]
## [br][b]为什么不做 current_scene 守卫[/b]：本装配只改回调字段、不挂节点，
## 集成测试把主菜单当普通节点 add_child 时装配同样有意义（测试正是要验真实
## 回调路径）；重复执行幂等。[br]
## [br][b]返回[/b]：是否装配成功（探索系统缺失时为 false，静默降级）。
func _mount_exploration_bootstrap() -> bool:
	var es: Node = get_node_or_null(NodePath("/root/ExplorationSystem"))
	if es == null:
		return false
	return ExplorationBootstrapScript.mount(es, get_node_or_null(NodePath("/root/AISystem")))

## === 按键绑定启动加载（Story 004）==============================================

## 启动加载自定义按键（GDD 边界澄清「键位持久化加载」——重启不失效）。[br]
## [b]顺序[/b]：先快照当前 InputMap 为默认基准（首次 [code]_ready[/code]——
## 快照法，QL-STORY-READY 2026-09-20 裁决），后从设置文件加载并应用——
## 顺序不可逆（先加载再快照会把自定义键污染进默认基准）。[br]
## 文件无 keybinds 键（首次启动）→ 空绑定 → 跳过应用（InputMap 维持
## project.godot 默认）。
func _load_keybinds() -> void:
	var store: KeybindStore = keybind_store
	if store == null:
		store = KeybindStoreScript.new()
		keybind_store = store  # 留存共享——SettingsPanel 装配时注入（H-3）
	store.snapshot_defaults()
	var bindings: Dictionary = store.load_bindings()
	if not bindings.is_empty():
		KeybindStoreScript.apply_bindings(bindings)

## === 文本与版本 ================================================================

## 应用固定词条（本地化入库后改为键查找——头注释豁免注记）。[br]
## 全部按钮文案统一由代码赋值（单一真理来源——code-review S-1 裁决：
## 常量声明而不消费会与 .tscn text 属性形成双源漂移）。
func _apply_texts() -> void:
	title_label.text = TEXT_TITLE
	new_game_button.text = TEXT_NEW_GAME
	continue_button.text = TEXT_CONTINUE
	settings_button.text = TEXT_SETTINGS
	quit_button.text = TEXT_QUIT
	inventory_button.text = TEXT_INVENTORY
	load_button.text = TEXT_LOAD
	save_summary_label.text = ""
	no_save_hint_label.text = ""

## 版本号——从 ProjectSettings 读取（story：不硬编码）。[br]
## project.godot [code]application/config/version[/code] = "0.1.0-dev"。[br]
## _ready 经 [method _apply_texts] 后调用（[method _read_version] 结果直写标签）。
func _apply_version() -> void:
	version_label.text = _read_version()

## 版本号——从 ProjectSettings 读取（story：不硬编码）。[br]
## project.godot [code]application/config/version[/code] = "0.1.0-dev"。
func _read_version() -> String:
	var version: String = str(ProjectSettings.get_setting(
			&"application/config/version", ""))
	if version.is_empty():
		push_warning("MainMenu: project.godot 未配置 application/config/version")
		return VERSION_FALLBACK
	return "v" + version

## === 存档状态（零缓存——每刷新周期从 SaveLoadSystem 读取）=====================

## 刷新存档存在性 + 摘要（_ready + 读档完成信号驱动）。[br]
## UI 不缓存列表——每次调用重新 [code]list_slots()[/code]（ADR-0031 §2）。[br]
## [br][b]两个入口一起刷[/b]：「继续游戏」（读最新档）与「读档」（挑槽位）读的是
## 同一份 [code]list_slots()[/code]，只是判定宽严不同——前者只要有档，后者要有非空
## 槽位。分两次读会出现「继续游戏亮着、读档灰着」这种自相矛盾的界面。[br]
## [br][b]中文提示的落点[/b]：无档时下方提示行说明原因（GDD 边界：无档时置灰并给出
## 说明）——只说一句，且两个按钮的说明不同（见 TEXT_NO_SAVE_* 常量注记）。
func _refresh_save_state() -> void:
	var slots: Array = _list_slots_safe()
	var has_save: bool = Logic.has_continuable_save(slots)
	continue_button.disabled = not has_save
	if has_save:
		var latest: Dictionary = Logic.select_latest_save(slots)
		save_summary_label.text = Logic.build_save_summary(latest)
	else:
		save_summary_label.text = ""
	# 摘要行 visible 控制（story AC：无存档时隐藏，布局占位保留——
	# visible 而非从树移除）
	save_summary_label.visible = has_save
	# 「读档」按槽位判定——自动槽空但有手动档时它仍该亮着（两者不等价）
	var entries: Array[Dictionary] = Logic.loadable_slots(slots)
	load_button.disabled = not _has_any_slot(entries)
	no_save_hint_label.text = "" if has_save else TEXT_NO_SAVE_CONTINUE
	if _load_slot_panel != null and is_instance_valid(_load_slot_panel) \
			and bool(_load_slot_panel.call(&"is_open")):
		# 面板正开着（读档失败退回的场景）：列表可能已变，跟着重刷一次
		_load_slot_panel.call(&"populate", entries)


## 槽位条目里是否有至少一个非空（「读档」按钮的启用判据）。[br]
## [br][b]与 [method Logic.has_continuable_save] 的差别[/b]：那个判的是
## [code]list_slots()[/code] 的原始列表（含战前快照槽），本判据只看玩家可在读档
## 界面里选到的那几格——快照槽非空不该让「读档」亮起来（点进去列表里没有它）。
static func _has_any_slot(p_entries: Array) -> bool:
	for entry: Dictionary in p_entries:
		if bool(entry.get("exists", false)):
			return true
	return false

## list_slots 防御读取——SaveLoadSystem 不可用时返回空数组（安全默认：
## 按无存档处理，按钮禁用——Logic 内核空状态防御对齐）。
func _list_slots_safe() -> Array:
	var sl: Node = _get_save_load()
	if sl != null and sl.has_method(&"list_slots"):
		return sl.list_slots()
	push_warning("MainMenu: SaveLoadSystem 不可用——按无存档处理")
	return []

## 连接读档完成信号——返回主菜单（暂停菜单退出路径）后刷新存档状态。
func _connect_save_signals() -> void:
	var sl: Node = _get_save_load()
	if sl != null and sl.has_signal(&"load_completed"):
		if not sl.load_completed.is_connected(_on_save_load_completed):
			sl.load_completed.connect(_on_save_load_completed)
	if sl != null and sl.has_signal(&"save_corrupted"):
		if not sl.save_corrupted.is_connected(_on_save_corrupted):
			sl.save_corrupted.connect(_on_save_corrupted)

## 读档完成信号回调——无论成败（转场或弹窗路径）刷新存档状态。[br]
## Cat 2b 动作通知（ADR-0007）——UI 只读刷新，不写状态。
func _on_save_load_completed(_success: bool) -> void:
	_refresh_save_state()

## save_corrupted 信号回调（GDD 边缘情况）——弹「存档损坏，无法读取」提示。[br]
## 对话框确认后 [method _on_corrupt_dialog_confirmed] 恢复按钮可用态。
func _on_save_corrupted(_slot_type: int, _slot_id: int, _reason: String) -> void:
	corrupt_dialog.show_corrupt()

## === 按钮路由 ==================================================================

## 新游戏 → 身份选择（AC-main-menu-004）。[br]
## 经 SceneManager 唯一入口（control-manifest 必需——绝不直调
## change_scene_to_file）。from 动态取当前场景 ID（先例 PauseMenu M-2 去魔数）。
func _on_new_game_pressed() -> void:
	var sm: Node = _get_scene_manager()
	if sm == null or not sm.has_method(&"request_scene_change"):
		push_error("MainMenu: SceneManager 不可用——新游戏导航中止")
		return
	var from_id: int = SceneManagerScript.SceneID.MAIN_MENU  # 守卫失败回退
	if sm.has_method(&"get_current_scene_id"):
		from_id = sm.get_current_scene_id()
	sm.request_scene_change(from_id,
			SceneManagerScript.SceneID.IDENTITY_SELECT,
			SceneManagerScript.TransitionType.MENU_TO_GAME)

## 继续游戏 → 读最近存档并[b]回到上次那张图[/b]（AC-main-menu-003 + 损坏路径）。[br]
## [br][b]此前这里是死路[/b]：读档成功后没有任何导航——玩家点了按钮，界面纹丝不动，
## 只有损坏分支有后续（弹对话框）。「继续游戏」的全部意义就在读完那一跳。[br]
## [br][b]导航归 [MainMenuLaunch][/b]：读档 → 发跨场景意图 → 请求转场三件事在那里
## 一条线走完（本类已超 300 行，且这条链与「读档按钮」共用同一份实现）。[br]
## [br][b]失败才弹损坏框[/b]：成功但载荷为空、或依赖不可用，都[b]不[/b]弹——文件没坏，
## 弹「存档损坏」是在对玩家说谎（那条链的判别见 [method MainMenuLaunch.load_and_resume]）。
func _on_continue_pressed() -> void:
	if continue_button.disabled:
		return  # 守卫：disabled 态不可达（键盘焦点防御）
	var slots: Array = _list_slots_safe()
	var latest: Dictionary = Logic.select_latest_save(slots)
	if latest.is_empty():
		# 零状态所有权副作用：disabled 判定与点击间列表可能已变——重刷一次，
		# 仍空则按无存档处理（不弹损坏框，静默禁用）。
		_refresh_save_state()
		return
	var code: int = int(_get_launch().call(&"load_and_resume",
			int(latest.get("slot_type", 0)), int(latest.get("slot_id", 0))))
	if code != SLScript.LoadResult.SUCCESS:
		corrupt_dialog.show_corrupt()


## 读档 → 打开槽位选择面板（第三条路径）。[br]
## [br][b]与设置/行囊同源形态[/b]：场景内覆盖层、复用式单例、首次点击实例化后
## [code]add_child[/code] 挂本节点树（ADR-0031 §1——不经 SceneManager 转场）。[br]
## [br][b]每次打开都重新 populate[/b]：槽位状态可能在主菜单停留期间变了（另一个
## 进程、或刚从暂停菜单退出来），面板不缓存列表（ADR-0031 §2）。[br]
## [br][b]空列表也照开[/b]（按钮 disabled 时不可达，键盘焦点防御除外）：面板会把四格
## 全画成「（空）」——比什么都不发生更能说明「你还没有存档」。
func _on_load_pressed() -> void:
	if _load_slot_panel == null or not is_instance_valid(_load_slot_panel):
		_load_slot_panel = LoadSlotPanelScript.new()
		_load_slot_panel.connect(&"slot_chosen", _on_load_slot_chosen)
		_load_slot_panel.connect(&"back_requested", _on_load_panel_back)
		add_child(_load_slot_panel)
	_load_slot_panel.call(&"populate", Logic.loadable_slots(_list_slots_safe()))
	_load_slot_panel.call(&"open")
	var first: Variant = _load_slot_panel.call(&"first_enabled_button")
	if first is Button and (first as Button).is_inside_tree():
		(first as Button).grab_focus()


## 玩家在读档面板选中一格——执行与「继续游戏」同一条读档链。[br]
## [br]面板已在 [method LoadSlotPanel._on_slot_pressed] 里自行收起（先收起再报意图，
## 避免读档成功转场时两层画面叠在一起）。[br]
## [br]失败弹损坏框——与「继续游戏」同一条判别（同一份存档，两条路径不该给两种说法）。
func _on_load_slot_chosen(p_slot_type: int, p_slot_id: int) -> void:
	var code: int = int(_get_launch().call(&"load_and_resume", p_slot_type, p_slot_id))
	if code != SLScript.LoadResult.SUCCESS:
		corrupt_dialog.show_corrupt()


## 读档面板「返回」——关闭并重刷按钮态（关闭期间槽位可能已变）。
func _on_load_panel_back() -> void:
	_refresh_save_state()


## 设置 → 打开设置面板（AC-main-menu-007；Story 002 恢复启用）。[br]
## 首次点击实例化 [SettingsPanel] 挂载本节点树（顶层 CanvasItem——
## 覆盖主菜单按钮区）；重复点击复用实例。[member animate] 透传（reduce-motion
## 接线点随设置面板动画行为统一）。
func _on_settings_pressed() -> void:
	if _settings_panel == null or not is_instance_valid(_settings_panel):
		_settings_panel = SETTINGS_PANEL_SCENE.instantiate()
		_settings_panel.animate = animate
		# 已快照的 keybind store 注入面板（LP-CODE-REVIEW H-3——共享同一实例，
		# 面板注册的「恢复默认」才能拿到启动时快照的默认基准）
		if keybind_store != null:
			_settings_panel.keybind_store = keybind_store
		add_child(_settings_panel)
	_settings_panel.open()

## 退出 → 关闭进程（AC-main-menu-006；UX 规范：直接退出无确认）。
func _on_quit_pressed() -> void:
	get_tree().quit()

## 「行囊与道友」→ 打开背包 + 角色状态界面（两页签，共用一次开合）。[br]
## [br][b]与设置按钮同源形态[/b]：场景内覆盖层、复用式单例、首次点击实例化后
## [code]add_child[/code] 挂本节点树（ADR-0031 §1 场景内节点——不经 SceneManager
## 转场）。面板自带输入锁与「返回」出口，主菜单只负责开。[br]
## [br][b]两页的模型在这里装配[/b]：面板不直连 Autoload（零状态所有权），
## 由主菜单把「数据实现」接到「界面接口」上——与 [method _mount_exploration_bootstrap]
## 同一分工。面板在 [method InventoryScreensHost.open] 时现读，故不必在此预热数据。
func _on_inventory_pressed() -> void:
	if _inventory_screens == null or not is_instance_valid(_inventory_screens):
		_inventory_screens = InventoryScreensHostScript.new()
		_inventory_screens.inventory_model = InventoryModelScript.new(
				get_node_or_null(NodePath("/root/GameStateManager")),
				get_node_or_null(NodePath("/root/CardSystem")))
		_inventory_screens.status_model = StatusModelScript.new(
				get_node_or_null(NodePath("/root/GameStateManager")),
				get_node_or_null(NodePath("/root/RealmSystem")))
		# 丹药结算层也在这里接线（背包页的确认 → 用丹药走它）。它自己也会去找
		# Autoload，但显式接上与其余依赖同口径——装配点漏接这类依赖不会报错，
		# 只会让功能静默失效（先例见 test_character_status_flow 的阵亡标记用例）。
		var pill_use: RefCounted = PillUseScript.new(
				get_node_or_null(NodePath("/root/GameStateManager")),
				get_node_or_null(NodePath("/root/CardSystem")))
		_inventory_screens.pill_use = pill_use
		add_child(_inventory_screens)
	_inventory_screens.open()

## === 损坏对话框 ================================================================

## 对话框确认回调——刷新存档状态（确认后按钮恢复可用态语义：若损坏存档
## 仍为唯一存档，重刷后依旧亮起——点击再次走损坏路径，与 AC-3 自洽）。
func _on_corrupt_dialog_confirmed() -> void:
	_refresh_save_state()

## === 入场动画（Tween 纯视觉变换——ADR-0031 §3 豁免）=========================

## 0.8s 淡入 + 标题滑落（GDD §视觉/音频需求）。[br]
## [member animate] false（测试/reduce-motion）时直接跳到位。
func _play_intro() -> void:
	if not is_inside_tree():
		return
	modulate.a = 0.0
	title_label.position.y += TITLE_SLIDE_OFFSET
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	_intro_tween = create_tween()
	_intro_tween.set_parallel(true)
	_intro_tween.tween_property(self, "modulate:a", 1.0,
			INTRO_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_property(title_label, "position:y",
			title_label.position.y - TITLE_SLIDE_OFFSET,
			INTRO_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## === 内部辅助 ==================================================================

## 获取 SceneManager——注入对象优先，否则回退 Autoload（get_node_or_null
## 保持脚本可脱离 Autoload 环境解析——先例 RealmBar._get_gsm）。
func _get_scene_manager() -> Node:
	if scene_manager != null:
		return scene_manager
	return get_node_or_null("/root/SceneManager")

## 获取 SaveLoadSystem——同上。
func _get_save_load() -> Node:
	if save_load != null:
		return save_load
	return get_node_or_null("/root/SaveLoadSystem")

## 取/建读档编排子模块——注入引用透传（本类已超 300 行，编排实现见该模块）。[br]
## [br][b]为什么每次都透传一遍注入引用[/b]：测试在 [code]_ready[/code] 之后才注入
## [code]save_load[/code] / [code]scene_manager[/code]（[code]before_each[/code] 先
## [code]add_child[/code] 再赋值），只认建模块那一刻的注入会让读档打到真实 Autoload。
func _get_launch() -> RefCounted:
	if _launch == null:
		_launch = LaunchScript.new()
		_launch.host = self
	_launch.scene_manager = scene_manager
	_launch.save_load = save_load
	return _launch
