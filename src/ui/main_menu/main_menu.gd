class_name MainMenu
extends Control
## MainMenu —— 主菜单场景（main-menu Story 001）。[br]
## [br][b]节点形态[/b]（ADR-0031 §1）：场景内 Control 树（零新增 Autoload），场景路径
## [code]res://src/ui/main_menu/MainMenu.tscn[/code] 由 [constant SceneManager.SCENE_PATHS]
## 的 MAIN_MENU 条目挂载。[br]
## [br][b]结构[/b]（UX 规范「左序右境」方案 B 骨架——背景动态场景归打磨 story）：标题 +
## 按钮列（新游戏 / 继续游戏 / 设置 / 卡组编辑 / 退出）+ 底行（行囊与道友 / 读档）+
## 存档摘要行（无存档时 visible=false 占位保留）+ 版本号 + 损坏提示对话框。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：存档存在性/摘要不缓存——每次从
## [code]SaveLoadSystem.list_slots()[/code] 现读；[b]零轮询[/b]：无 [code]_process()[/code]。[br]
## [br][b]场景导航[/b]：一律经 [code]SceneManager.request_scene_change[/code]
## （control-manifest 必需——禁止直调 [code]change_scene_to_file[/code]）；设置 /
## 行囊与道友 / 读档槽位三块面板是场景内覆盖层，不经 SceneManager。[br]
## [br][b]焦点导航[/b]（story Implementation Notes）：焦点顺序 = VBox 树序（新游戏 →
## 继续 → 设置 → 退出）；初始焦点 = 继续游戏（无存档回退新游戏）。[code]grab_focus()[/code]
## 在 4.6 双焦点下只影响键盘/手柄焦点。[br]
## [br][b]动画[/b]：0.8s 淡入 + 标题滑落（GDD §视觉/音频需求）——Tween 纯视觉变换豁免
## （ADR-0031 §3）。[member animate] 为 reduce-motion 接线点。[br]
## [br][b]启动承载者[/b]（gate-check 2026-11-08 §B1）：本场景是 [code]run/main_scene[/code]，
## 由它在 [method _ready] 经 [HudBootstrap] 把全局 HUD 挂进
## [code]SceneManager.PersistentLayer[/code]，此后所有转场 HUD 常驻；「只在当前主场景时
## 挂载」的守卫见 [method _mount_global_hud]。[br]
## [br][b]按职责拆出的五件[/b]（.claude/docs/coding-standards.md「单文件 ≤300 行」）：
## [MainMenuTexts]（固定词条与版本号）、[MainMenuBootstrap]（HUD 挂载 / 探索装配 /
## 按键加载）、[MainMenuSaveState]（存档判定与按钮态）、[MainMenuOverlays]（三块覆盖层
## 的建造与开合）、[MainMenuRoutes]（按钮路由与导航出口）。本类保留门面职责——节点引用、
## 生命周期、入场动画——以及上述五件的[b]同名薄转发[/b]（既有用例与场景
## [code]connection[/code] 一律按名字取用，转发后取法不变）；词条常量同样转发，
## 定义的唯一出处是 [MainMenuTexts]。
##
## @experimental
## 来源: ADR-0031、design/gdd/main-menu-system.md、design/ux/main-menu.md、
## story-001-main-menu-scene.md。

## === Visual 常量（数据驱动）====================================================

## 冷启动入场动画总时长——0.8s（GDD §视觉/音频需求「主菜单加载 0.8s」）；标题滑落起始
## 位移（px，自上方滑入——UX 规范「标题从上方滑落」）。
const INTRO_DURATION: float = 0.8
const TITLE_SLIDE_OFFSET: float = -60.0

## === 拆出件的脚本常量（preload——class_name 在测试动态加载下不可靠，先例
## scene_manager 持有子模块模式）===============================================

## 五件拆出件（实现归各件，本类只经它们转发）。
const TextsScript := preload("res://src/ui/main_menu/main_menu_texts.gd")
const BootstrapScript := preload("res://src/ui/main_menu/main_menu_bootstrap.gd")
const SaveStateScript := preload("res://src/ui/main_menu/main_menu_save_state.gd")
const OverlaysScript := preload("res://src/ui/main_menu/main_menu_overlays.gd")
const RoutesScript := preload("res://src/ui/main_menu/main_menu_routes.gd")
## 存档判定内核（纯函数——control-manifest「存档存在性判定提取纯函数」必需模式）。
## 本类已不直接消费（判定迁 [MainMenuSaveState]），保留常量以保
## [code]MainMenu.Logic[/code] 既有引用点口径不变（先例 [code]AudioManager[/code] 的
## [code]BgmFadePlanner[/code] 同款注记）。
const Logic := preload("res://src/ui/main_menu/main_menu_logic.gd")
## 读档 → 进探索这一跳的编排（[method _get_launch] 懒建它；含「成功但空载荷」判别）。
const LaunchScript := preload("res://src/ui/main_menu/main_menu_launch.gd")

## 固定 UI 词条——定义在 [MainMenuTexts]，此处同名转发（既有用例按实例取用，
## 先例 [code]identity_select.gd[/code] 转发 [code]INTRO_DURATION[/code]）。
const TEXT_TITLE: String = TextsScript.TEXT_TITLE
const TEXT_NEW_GAME: String = TextsScript.TEXT_NEW_GAME
const TEXT_CONTINUE: String = TextsScript.TEXT_CONTINUE
const TEXT_SETTINGS: String = TextsScript.TEXT_SETTINGS
const TEXT_QUIT: String = TextsScript.TEXT_QUIT
const TEXT_INVENTORY: String = TextsScript.TEXT_INVENTORY
const TEXT_LOAD: String = TextsScript.TEXT_LOAD
const TEXT_DECK_EDIT: String = TextsScript.TEXT_DECK_EDIT
const TEXT_NO_SAVE_CONTINUE: String = TextsScript.TEXT_NO_SAVE_CONTINUE
const TEXT_NO_SAVE_LOAD: String = TextsScript.TEXT_NO_SAVE_LOAD
## 版本号缺省回退（同上转发）。本类已不直接消费（读取迁 [MainMenuTexts]），
## 保留常量以保既有引用点口径不变。
const VERSION_FALLBACK: String = TextsScript.VERSION_FALLBACK
## SettingsPanel 场景——设置面板实例化源（同上，转发 [MainMenuOverlays] 的同名常量）。
const SETTINGS_PANEL_SCENE: PackedScene = OverlaysScript.SETTINGS_PANEL_SCENE

## SceneManager / SaveLoadSystem 脚本常量——SceneID / TransitionType / LoadResult
## 枚举真理来源（preload 引用不依赖 Autoload 实例存在，与注入式设计兼容——
## code-review H-1：替换裸数字，防枚举重排静默漂移）。本类已不直接消费（路由迁
## [MainMenuRoutes]），保留常量以保既有引用点口径不变。
const SceneManagerScript := preload("res://src/foundation/scene_manager.gd")
const SLScript := preload("res://src/foundation/save_load_system.gd")
## 以下启动承载者 / 覆盖层素材的脚本常量——实现已迁 [MainMenuBootstrap] /
## [MainMenuOverlays]，此处同名转发以保既有引用点（测试与排障按
## [code]MainMenu.XXX[/code] 取用）。
const KeybindStoreScript := preload("res://src/ui/main_menu/keybind_store.gd")
const HudBootstrapScript := preload("res://src/ui/hud/hud_bootstrap.gd")
const ExplorationBootstrapScript := preload("res://src/feature/exploration/exploration_bootstrap.gd")
const InventoryScreensHostScript := preload("res://src/ui/inventory/inventory_screens_host.gd")
const InventoryModelScript := preload("res://src/feature/inventory/inventory_model.gd")
const StatusModelScript := preload("res://src/feature/inventory/character_status_model.gd")
const PillUseScript := preload("res://src/feature/inventory/inventory_pill_use.gd")
const LoadSlotPanelScript := preload("res://src/ui/main_menu/load_slot_panel.gd")
const DeckEditingEntryScript := preload("res://src/ui/deck_editing/deck_editing_entry.gd")

## === 依赖注入（测试可替换）=====================================================

## SceneManager 引用——导航转场用（null 时回退 Autoload，先例 PauseMenu）。
var scene_manager: Node = null
## SaveLoadSystem 引用——存档列表/读档用（null 时回退 Autoload，先例 PauseMenu）。
var save_load: Node = null
## 动画开关——测试注入 + reduce-motion 预留接线点（类文档）。
var animate: bool = true

## === 瞬态交互状态（ADR-0031 §2.1）=============================================

## 入场 Tween 句柄（新请求时 kill 防悬挂——先例 PauseMenu._blur_tween）。
var _intro_tween: Tween = null
## 设置面板 / 行囊界面 / 读档槽位面板实例——复用式单例（首次点击实例化，关闭留树）；
## 建造与开合归 [MainMenuOverlays]，句柄归本类（测试按名字读）。
var _settings_panel: SettingsPanel = null
## 类型写作 [Control] 而非其 [code]class_name[/code]：本脚本在测试里被动态加载，
## 全局类名注册时序不保证（先例 card_system 的「不依赖 class_name」注记）。
var _inventory_screens: Control = null
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
@onready var deck_edit_button: Button = $LayoutAnchor/ButtonBox/DeckEditButton
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

## === 启动承载者三件事（HUD 挂载 / 探索装配 / 按键加载）=========================

## 生产挂载全局 HUD（gate-check 2026-11-08 §B1）——实现见 [MainMenuBootstrap]。[br]
## [br]自动路径延后一帧 + 加 [code]current_scene[/code] 守卫（守卫拦住集成测试里
## 被当普通节点 [code]add_child[/code] 的主菜单，避免测试进程多出常驻 HUD）。
func _mount_global_hud_if_boot_scene() -> void:
	BootstrapScript.mount_global_hud_if_boot_scene(self)

## 守卫实现——[b]测试可直接调用本方法（守卫）/ [method _mount_hud]（无守卫）[/b]；
## [code]current_scene[/code] 为 null 时放行（场景切换的中间态不该漏挂）。
func _mount_global_hud() -> void:
	BootstrapScript.mount_global_hud(self, _get_scene_manager())

## 挂载全局 HUD（幂等——重复进入主菜单复用同一实例）。[br]
## [br][b]返回[/b]：已挂载的 HUD；SceneManager 不可用/不支持时 null（静默降级）。
func _mount_hud() -> CanvasLayer:
	return BootstrapScript.mount_hud(_get_scene_manager())

## 探索系统生产装配（地图配置 + 敌人池）。[br]
## [br][b]为什么由主菜单做[/b]：与 HUD 挂载同源——启动承载者把「数据实现」接到
## 「系统接口」上；系统内部不硬编码地图表与敌人池。不做 current_scene 守卫（只改
## 回调字段、不挂节点，测试正是要验真实回调路径），重复执行幂等。[br]
## [br][b]返回[/b]：是否装配成功（探索系统缺失时为 false，静默降级）。
func _mount_exploration_bootstrap() -> bool:
	return BootstrapScript.mount_exploration(self)

## 启动加载自定义按键（GDD 边界澄清「键位持久化加载」——重启不失效）。[br]
## [br][b]顺序不可逆[/b]：先快照当前 InputMap 为默认基准，再加载设置文件并应用
## （反了会把自定义键污染进默认基准）。文件无 keybinds 键 → 空绑定 → 跳过应用。
func _load_keybinds() -> void:
	BootstrapScript.load_keybinds(self)

## === 文本与版本 ================================================================

## 应用固定词条（本地化入库后改为键查找——头注释豁免注记）。[br]
## [br]全部按钮文案统一由代码赋值（单一真理来源——code-review S-1：常量声明而不消费
## 会与 .tscn text 属性形成双源漂移）。词条出处见 [MainMenuTexts]。
func _apply_texts() -> void:
	title_label.text = TEXT_TITLE
	new_game_button.text = TEXT_NEW_GAME
	continue_button.text = TEXT_CONTINUE
	settings_button.text = TEXT_SETTINGS
	deck_edit_button.text = TEXT_DECK_EDIT
	quit_button.text = TEXT_QUIT
	inventory_button.text = TEXT_INVENTORY
	load_button.text = TEXT_LOAD
	save_summary_label.text = ""
	no_save_hint_label.text = ""

## 版本号（project.godot [code]application/config/version[/code]，story：不硬编码）。
func _apply_version() -> void:
	TextsScript.apply_version(version_label)

## 版本号读取（实现见 [MainMenuTexts.read_version]）。
func _read_version() -> String:
	return TextsScript.read_version()

## === 存档状态（零缓存——每刷新周期从 SaveLoadSystem 读取；实现见
## [MainMenuSaveState]）========================================================

## 刷新存档存在性 + 摘要 + 两个按钮态（_ready 与两张存档信号驱动）。[br]
## [br][b]两个入口一起刷[/b]：「继续游戏」（读最新档）与「读档」（挑槽位）读的是同一份
## 列表，只是判据宽严不同（前者只要有档，后者要有非空槽位）——分两次读会出现
## 「继续游戏亮着、读档灰着」这种自相矛盾的界面。实现见 [MainMenuSaveState]。
func _refresh_save_state() -> void:
	SaveStateScript.refresh(self)

## 槽位条目里是否有至少一个非空（「读档」按钮的启用判据）。[br]
## [br][b]与 [method MainMenuLogic.has_continuable_save] 的差别[/b]：那个判的是
## [code]list_slots()[/code] 的原始列表（含战前快照槽），本判据只看玩家可在读档界面里
## 选到的那几格——快照槽非空不该让「读档」亮起来（点进去列表里没有它）。
static func _has_any_slot(p_entries: Array) -> bool:
	return SaveStateScript.has_any_slot(p_entries)

## list_slots 防御读取——SaveLoadSystem 不可用时返回空数组（安全默认：按无存档处理，
## 按钮禁用——Logic 内核空状态防御对齐）。
func _list_slots_safe() -> Array:
	return SaveStateScript.list_slots_safe(self)

## 连接两张存档信号（返回主菜单后刷新存档状态）；回调仍指着本类的
## [method _on_save_load_completed] / [method _on_save_corrupted]。
func _connect_save_signals() -> void:
	SaveStateScript.connect_signals(self,
			Callable(self, &"_on_save_load_completed"),
			Callable(self, &"_on_save_corrupted"))

## 读档完成信号回调——无论成败（转场或弹窗路径）刷新存档状态（Cat 2b 动作通知
## ADR-0007——UI 只读刷新，不写状态）。
func _on_save_load_completed(_success: bool) -> void:
	RoutesScript.save_load_completed(self, _success)

## save_corrupted 信号回调（GDD 边缘情况）——弹「存档损坏，无法读取」提示；
## 确认后 [method _on_corrupt_dialog_confirmed] 恢复按钮可用态。
func _on_save_corrupted(_slot_type: int, _slot_id: int, _reason: String) -> void:
	RoutesScript.save_corrupted(self, _slot_type, _slot_id, _reason)

## === 按钮路由（实现见 [MainMenuRoutes]；本类只保留同名入口——场景
## [code]connection[/code] 与既有用例一律按这些名字取用）======================

## 新游戏 → 身份选择（AC-main-menu-004，经 SceneManager 唯一入口）。
func _on_new_game_pressed() -> void:
	RoutesScript.new_game(self)

## 继续游戏 → 读最近存档并[b]回到上次那张图[/b]（AC-main-menu-003 + 损坏路径）。[br]
## [br][b]此前这里是死路[/b]：读档成功后没有任何导航——玩家点了按钮，界面纹丝不动。
## 「继续游戏」的全部意义就在读完那一跳，而那条链（读档 → 发跨场景意图 → 请求转场）
## 归 [MainMenuLaunch]。[br]
## [br][b]失败才弹损坏框[/b]：成功但载荷为空、或依赖不可用都[b]不[/b]弹——文件没坏，
## 弹「存档损坏」是在对玩家说谎。
func _on_continue_pressed() -> void:
	RoutesScript.continue_game(self)

## 读档 → 打开槽位选择面板（第三条路径；场景内覆盖层，不经 SceneManager 转场）。[br]
## [br]每次打开都重新 populate（槽位状态可能在停留期间变了——零状态所有权）；
## 空列表也照开：面板把四格全画成「（空）」，比什么都不发生更能说明「你还没有存档」。
func _on_load_pressed() -> void:
	OverlaysScript.open_load_panel(self)

## 玩家在读档面板选中一格——与「继续游戏」同一条读档链、同一条失败判别
## （同一份存档，两条路径不该给两种说法）；面板已自行收起，避免两层画面叠在一起。
func _on_load_slot_chosen(p_slot_type: int, p_slot_id: int) -> void:
	RoutesScript.load_slot(self, p_slot_type, p_slot_id)

## 读档面板「返回」——重刷按钮态（关闭期间槽位可能已变）。
func _on_load_panel_back() -> void:
	_refresh_save_state()

## 设置 → 打开设置面板（AC-main-menu-007；Story 002 恢复启用）。[br]
## [br]场景内覆盖层、复用式单例；[member animate] 与已快照的 keybind store 在装配时
## 透传（「恢复默认」要的是启动时那份默认基准）。实现见 [MainMenuOverlays]。
func _on_settings_pressed() -> void:
	OverlaysScript.open_settings(self, animate)

## 退出 → 关闭进程（AC-main-menu-006；UX 规范：直接退出无确认）。
func _on_quit_pressed() -> void:
	RoutesScript.quit(self)

## 「卡组编辑」→ 进卡组编辑场景（[code]SceneID.DECK_EDITING[/code]）。[br]
## [br][b]与「行囊与道友」相反：这一条是转场而不是覆盖层[/b]——整屏两栏编辑与主菜单的
## 按钮列没有共存的余地（ADR-0031 §1：能一屏共存才用覆盖层）。先记来路（编辑屏挂载时
## 已无从知道是谁开的它）再请求转场。
func _on_deck_edit_pressed() -> void:
	RoutesScript.deck_edit(self)

## 「行囊与道友」→ 打开背包 + 角色状态界面（两页签，共用一次开合）。[br]
## [br][b]两页的模型在装配时接线[/b]：面板不直连 Autoload（零状态所有权），由主菜单把
## 「数据实现」接到「界面接口」上——与探索装配同一分工。实现见 [MainMenuOverlays]。
func _on_inventory_pressed() -> void:
	OverlaysScript.open_inventory(self)

## === 损坏对话框 ================================================================

## 对话框确认回调——刷新存档状态（确认后按钮恢复可用态语义：若损坏存档仍为唯一存档，
## 重刷后依旧亮起——点击再次走损坏路径，与 AC-3 自洽）。
func _on_corrupt_dialog_confirmed() -> void:
	RoutesScript.corrupt_confirmed(self)

## === 入场动画（Tween 纯视觉变换——ADR-0031 §3 豁免）=========================

## 0.8s 淡入 + 标题滑落（GDD §视觉/音频需求）。[member animate] false
##（测试/reduce-motion）时直接跳到位。
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

## === 内部辅助（拆出件的解析面——注入覆盖只有这一处）==========================

## 获取 SceneManager——注入对象优先，否则回退 Autoload（[code]get_node_or_null[/code]
## 保持脚本可脱离 Autoload 环境解析——先例 [code]RealmBar._get_gsm[/code]）。
func _get_scene_manager() -> Node:
	if scene_manager != null:
		return scene_manager
	return get_node_or_null("/root/SceneManager")

## 获取 SaveLoadSystem——同上。
func _get_save_load() -> Node:
	if save_load != null:
		return save_load
	return get_node_or_null("/root/SaveLoadSystem")

## 取/建读档编排子模块——注入引用透传（编排实现见该模块）。[br]
## [br][b]为什么每次都透传一遍[/b]：测试在 [code]_ready[/code] 之后才注入
## [code]save_load[/code] / [code]scene_manager[/code]（[code]before_each[/code] 先
## [code]add_child[/code] 再赋值），只认建模块那一刻的注入会让读档打到真实 Autoload。
func _get_launch() -> RefCounted:
	if _launch == null:
		_launch = LaunchScript.new()
		_launch.host = self
	_launch.scene_manager = scene_manager
	_launch.save_load = save_load
	return _launch
