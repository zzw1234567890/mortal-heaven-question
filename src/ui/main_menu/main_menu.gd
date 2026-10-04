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
## change_scene_to_file）；设置目标归 Story 002（Out of Scope——留桩禁用）。[br]
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
const TEXT_CORRUPTED: String = "存档损坏，无法读取"

## 版本号缺省回退（ProjectSettings 未配置 version 键时的安全默认——
## story Implementation Notes「不硬编码」指不在 UI 层写死版本值，读取失败
## 仍需一个可显示占位）。
const VERSION_FALLBACK: String = "v?"

## === Logic 内核（preload——class_name 在测试动态加载下不可靠，先例
## scene_manager 持有子模块模式）===============================================

const Logic := preload("res://src/ui/main_menu/main_menu_logic.gd")

## SceneManager 脚本常量——枚举单一真理来源（SceneID/TransitionType 均为
## const，preload 引用不依赖 Autoload 实例存在，与注入式设计兼容——
## code-review H-1 裁决：替换裸数字，防枚举重排静默漂移）。
const SceneManagerScript := preload("res://src/foundation/scene_manager.gd")
## SaveLoadSystem 脚本常量——LoadResult 枚举单一真理来源（同上，H-1 姊妹项：
## 点击继续的返回值判定去魔数）。
const SLScript := preload("res://src/foundation/save_load_system.gd")

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

## === 节点引用 ==================================================================

@onready var title_label: Label = $LayoutAnchor/TitleLabel
@onready var new_game_button: Button = $LayoutAnchor/ButtonBox/NewGameButton
@onready var continue_button: Button = $LayoutAnchor/ButtonBox/ContinueButton
@onready var save_summary_label: Label = $LayoutAnchor/ButtonBox/SaveSummaryLabel
@onready var settings_button: Button = $LayoutAnchor/ButtonBox/SettingsButton
@onready var quit_button: Button = $LayoutAnchor/ButtonBox/QuitButton
@onready var version_label: Label = $VersionLabel
@onready var corrupt_dialog: AcceptDialog = $CorruptDialog

## === 生命周期 ==================================================================

func _ready() -> void:
	_apply_texts()
	_apply_version()
	_refresh_save_state()
	_connect_save_signals()
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
	save_summary_label.text = ""

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
## UI 不缓存列表——每次调用重新 [code]list_slots()[/code]（ADR-0031 §2）。
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
	_show_corrupt_dialog()

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

## 继续游戏 → 读最近存档（AC-main-menu-003 + 损坏路径）。[br]
## [code]load_game()[/code] 失败（非 SUCCESS）或发 [signal save_corrupted] →
## 弹损坏提示；成功 → 读档流程由 GSM/SceneManager 编排（转场归后续 story）。
func _on_continue_pressed() -> void:
	if continue_button.disabled:
		return  # 守卫：disabled 态不可达（键盘焦点防御）
	var sl: Node = _get_save_load()
	if sl == null or not sl.has_method(&"load_game"):
		push_error("MainMenu: SaveLoadSystem 不可用——继续游戏中止")
		return
	var slots: Array = _list_slots_safe()
	var latest: Dictionary = Logic.select_latest_save(slots)
	if latest.is_empty():
		# 零状态所有权副作用：disabled 判定与点击间列表可能已变——重刷一次，
		# 仍空则按无存档处理（不弹损坏框，静默禁用）。
		_refresh_save_state()
		return
	var result: Dictionary = sl.load_game(
			int(latest.get("slot_type", 0)), int(latest.get("slot_id", 0)))
	if result.is_empty() \
			or int(result.get("result", SLScript.LoadResult.DESERIALIZE_ERROR)) \
			!= SLScript.LoadResult.SUCCESS:
		_show_corrupt_dialog()

## 设置 → 目标界面归 Story 002（Out of Scope）——按钮禁用 + 留桩注释。[br]
## story 裁决：不阻塞主流程；Story 002 落地时恢复启用并接 [method _on_settings_pressed]。
func _on_settings_pressed() -> void:
	# Story 002 留桩——设置面板本体不在本 story（Out of Scope）。
	pass

## 退出 → 关闭进程（AC-main-menu-006；UX 规范：直接退出无确认）。
func _on_quit_pressed() -> void:
	get_tree().quit()

## === 损坏对话框 ================================================================

## 弹「存档损坏，无法读取」提示（GDD 边缘情况 + UX「存档读取失败」状态）。[br]
## 弹窗期间继续按钮保持可用态（meta 层 exists==true 未变——QL-STORY-READY
## 2026-09-19 裁决：按钮亮起，损坏由读档检测）；确认后统一重刷存档状态。
func _show_corrupt_dialog() -> void:
	# 重入守卫（code-review H-3）：真实 SaveLoadSystem.load_game() 的
	# DESERIALIZE_ERROR 路径同时发 save_corrupted 信号且返回非 SUCCESS——
	# 信号路径 + 返回值路径在同一调用栈内双触发，此守卫去重防双弹。
	if corrupt_dialog.visible:
		return
	corrupt_dialog.dialog_text = TEXT_CORRUPTED
	corrupt_dialog.popup_centered()

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
