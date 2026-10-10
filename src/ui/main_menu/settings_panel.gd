class_name SettingsPanel
extends Control
## SettingsPanel —— 设置面板覆盖层（main-menu Story 002/003）。
##
## [b]形态[/b]（ADR-0031 §1）：场景内 Control 树，由 [MainMenu] 实例化挂载。[br]
## [br][b]分类[/b]：TabContainer 四标签——音效（Story 002，实时生效）/ 画面
## （Story 003，统一「点应用」生效）/ 按键绑定（占位）/ 语言（占位）。[br]
## [br][b]画面类统一「点应用」生效[/b]（QL-STORY-READY 2026-09-19）：
## [GraphicsTab] 控件收集待应用值，[method _on_apply_pressed] 统一写引擎
## + 持久化写文件；关闭时有未应用变更 → 弹确认弹窗（AC-main-menu-013）。[br]
## [br][b]全局恢复默认[/b]（AC-main-menu-014）：[method _on_reset_all_pressed]
## 遍历已注册分类逐个重置 + 各 tab 刷新控件。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]。
##
## @experimental
## 来源: ADR-0031、story-002-settings-audio.md、story-003-settings-graphics.md。

## === Visual 常量 ================================================================

const OPEN_DURATION: float = 0.3
const CLOSE_DURATION: float = 0.2
const SLIDE_OFFSET: float = 640.0
const LOCK_SOURCE: StringName = &"settings_panel"

## === Logic 内核 =================================================================

const Logic := preload("res://src/ui/main_menu/settings_logic.gd")
const GfxLogic := preload("res://src/ui/main_menu/settings_graphics_logic.gd")
const StoreScript := preload("res://src/ui/main_menu/settings_store.gd")

## === 固定 UI 词条 ===============================================================

const TEXT_TITLE: String = "设置"
const TEXT_CLOSE: String = "关闭"
const TEXT_APPLY: String = "应用"
const TEXT_RESET_ALL: String = "恢复默认"
const TEXT_TAB_AUDIO: String = "音效"
const TEXT_TAB_GRAPHICS: String = "画面"
const TEXT_TAB_KEYBINDS: String = "按键绑定"
const TEXT_TAB_LANGUAGE: String = "语言"
const TEXT_MASTER: String = "总音量"
const TEXT_BGM: String = "音乐音量"
const TEXT_SFX: String = "音效音量"
const TEXT_PLACEHOLDER_KEYBINDS: String = "按键绑定（待实现）"
const TEXT_PLACEHOLDER_LANGUAGE: String = "语言（待实现）"
## 未保存确认弹窗文案（AC-main-menu-013）。
const TEXT_UNSAVED_CONFIRM: String = "未保存的设置将丢失，确认退出？"

## === 依赖注入 ===================================================================

var settings_store: SettingsStore = null
var animate: bool = true

## === 瞬态交互状态 ===============================================================

var _saved_volumes: Dictionary = {}
## 已保存画面设置快照——打开时从文件读取，应用成功后更新；关闭时脏检测基准。
var _saved_graphics: Dictionary = {}
var _lock_held: bool = false
var _closing: bool = false
var _slide_tween: Tween = null
var _base_panel_x: float = 0.0
## 确认弹窗实例——复用（首次创建后留树）。
var _confirm_dialog: ConfirmationDialog = null

## === 节点引用 ===================================================================

@onready var _panel: Control = $Panel
@onready var _title_label: Label = $Panel/PanelVBox/HeaderBox/TitleLabel
@onready var _close_button: Button = $Panel/PanelVBox/HeaderBox/CloseButton
@onready var _tab_container: TabContainer = $Panel/PanelVBox/TabContainer
@onready var master_slider: HSlider = \
		$Panel/PanelVBox/TabContainer/AudioTab/MasterRow/MasterSlider
@onready var bgm_slider: HSlider = \
		$Panel/PanelVBox/TabContainer/AudioTab/BgmRow/BgmSlider
@onready var sfx_slider: HSlider = \
		$Panel/PanelVBox/TabContainer/AudioTab/SfxRow/SfxSlider
@onready var _master_label: Label = \
		$Panel/PanelVBox/TabContainer/AudioTab/MasterRow/MasterLabel
@onready var _bgm_label: Label = \
		$Panel/PanelVBox/TabContainer/AudioTab/BgmRow/BgmLabel
@onready var _sfx_label: Label = \
		$Panel/PanelVBox/TabContainer/AudioTab/SfxRow/SfxLabel
@onready var _graphics_tab: GraphicsTab = \
		$Panel/PanelVBox/TabContainer/GraphicsTab
@onready var _keybinds_placeholder: Label = \
		$Panel/PanelVBox/TabContainer/KeybindsTab/KeybindsPlaceholder
@onready var _language_placeholder: Label = \
		$Panel/PanelVBox/TabContainer/LanguageTab/LanguagePlaceholder
@onready var _apply_button: Button = $Panel/PanelVBox/ButtonRow/ApplyButton
@onready var _reset_all_button: Button = $Panel/PanelVBox/ButtonRow/ResetAllButton

## === 生命周期 ===================================================================

func _ready() -> void:
	visible = false
	_apply_texts()
	_register_reset_handlers()

func _exit_tree() -> void:
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()
	_release_lock()

func _unhandled_input(event: InputEvent) -> void:
	if visible and not _closing and event is InputEventKey \
			and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		if InputManager.has_lock(LOCK_SOURCE):
			get_viewport().set_input_as_handled()
			_try_close()

## === 打开/关闭 ==================================================================

func open() -> void:
	if visible:
		push_warning("SettingsPanel.open: 面板已打开——幂等跳过")
		return
	_closing = false
	InputManager.push_lock(InputManager.LockType.MODAL, LOCK_SOURCE)
	_lock_held = true
	# 音量分类——打开时读取已保存值 + 对齐总线
	_saved_volumes = _get_store().load_volume_category()
	_sync_sliders_to(_saved_volumes)
	_apply_volumes_to_buses(_saved_volumes)
	# 画面分类——先刷新分辨率下拉（填充 OptionButton 项），再回填控件值。
	# 顺序不可逆——set_values → _select_resolution 依赖已填充的下拉列表
	# （对空 OptionButton select(0) 触发越界）。
	_saved_graphics = _get_store().load_graphics_category()
	var prev_res := Vector2i(
			int(_saved_graphics.get(StoreScript.GFX_KEY_RESOLUTION_X, 1920)),
			int(_saved_graphics.get(StoreScript.GFX_KEY_RESOLUTION_Y, 1080)))
	# 分辨率回退：以已保存值作 previous，refresh_resolutions 内部经
	# filter_resolutions 判定（已保存值不在可用列表 → 走回退链）
	var resolved: Vector2i = _graphics_tab.refresh_resolutions(prev_res)
	# 回填控件值到已刷新下拉（refresh_resolutions 后 _available_resolutions 非空）
	_graphics_tab.set_values(_saved_graphics)
	# 若回退后 differed 则更新快照（下次关闭以实际值作基准）
	if resolved != prev_res:
		_saved_graphics[StoreScript.GFX_KEY_RESOLUTION_X] = resolved.x
		_saved_graphics[StoreScript.GFX_KEY_RESOLUTION_Y] = resolved.y
	# 可见 + 动画
	visible = true
	_base_panel_x = _panel.position.x
	if animate:
		_play_slide_in()
	master_slider.grab_focus()

## 关闭——有未保存画面变更时弹确认弹窗；无变更或确认后关闭。
func close() -> void:
	if not visible or _closing:
		return
	_try_close()

func _try_close() -> void:
	if _has_graphics_unsaved():
		_show_unsaved_confirm()
		return
	_do_close()

func _do_close() -> void:
	if not visible or _closing:
		return
	_closing = true
	_apply_volumes_to_buses(_saved_volumes)
	_sync_sliders_to(_saved_volumes)
	_release_lock()
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()
	if animate:
		_slide_tween = create_tween()
		_slide_tween.tween_property(_panel, "position:x",
				_base_panel_x + SLIDE_OFFSET, CLOSE_DURATION)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_slide_tween.finished.connect(_on_slide_out_finished)
	else:
		_finish_close()

func _on_slide_out_finished() -> void:
	_finish_close()

func _finish_close() -> void:
	visible = false
	_closing = false
	_panel.position.x = _base_panel_x

## === 按钮路由 ===================================================================

## 音量滑条实时预览（AC-main-menu-008）。
func _on_slider_value_changed(value: float, bus: int) -> void:
	if _closing or not visible:
		return
	_set_bus_percent(bus, value)

## 应用——写入音量 + 画面到文件，画面统一应用到引擎。
func _on_apply_pressed() -> void:
	if _closing or not visible:
		return
	var store: SettingsStore = _get_store()
	# 音量——收集当前滑条值 → 写文件
	var current_vol: Dictionary = _collect_slider_values()
	if store.save_volume_category(current_vol):
		_saved_volumes = current_vol
	else:
		push_error("SettingsPanel: 音量设置写入失败")
	# 画面——收集 GraphicsTab 控件值 → 写文件 → 应用到引擎
	var current_gfx: Dictionary = _graphics_tab.collect()
	# 上一生效分辨率快照（apply 前的已保存值——分辨率回退候选）
	var prev_res := Vector2i(
			int(_saved_graphics.get(StoreScript.GFX_KEY_RESOLUTION_X, 1920)),
			int(_saved_graphics.get(StoreScript.GFX_KEY_RESOLUTION_Y, 1080)))
	if store.save_graphics_category(current_gfx):
		_saved_graphics = current_gfx
	else:
		push_error("SettingsPanel: 画面设置写入失败")
	# 画面引擎应用（点应用统一生效——AC-009~012）
	var res_result: Dictionary = _graphics_tab.apply_to_engine(current_gfx, prev_res)
	if bool(res_result.get("fallback_used", false)):
		push_warning("SettingsPanel: 分辨率回退——该分辨率不支持，已恢复")

## 恢复默认——遍历已注册分类重置 + 刷新控件。
func _on_reset_all_pressed() -> void:
	if _closing or not visible:
		return
	var store: SettingsStore = _get_store()
	store.reset_all_categories()
	# 刷新各分类控件到默认值
	_saved_volumes = store.load_volume_category()
	_sync_sliders_to(_saved_volumes)
	_apply_volumes_to_buses(_saved_volumes)
	_saved_graphics = store.load_graphics_category()
	# 分辨率下拉也刷新——先刷新后回填（同 open() 顺序，防空下拉 select 越界）
	var prev_res := Vector2i(
			int(_saved_graphics.get(StoreScript.GFX_KEY_RESOLUTION_X, 1920)),
			int(_saved_graphics.get(StoreScript.GFX_KEY_RESOLUTION_Y, 1080)))
	_graphics_tab.refresh_resolutions(prev_res)
	_graphics_tab.set_values(_saved_graphics)
	# 画面引擎同步回默认（与音量总线回默认对称——AC-014「全部归位」含引擎态）
	_graphics_tab.apply_to_engine(_saved_graphics, prev_res)

## 关闭按钮（UX 10m）。
func _on_close_pressed() -> void:
	_try_close()

## === 未保存确认弹窗（AC-main-menu-013）==========================================

func _show_unsaved_confirm() -> void:
	if _confirm_dialog == null:
		_confirm_dialog = ConfirmationDialog.new()
		_confirm_dialog.dialog_text = TEXT_UNSAVED_CONFIRM
		_confirm_dialog.confirmed.connect(_on_unsaved_confirm_accepted)
		add_child(_confirm_dialog)
	_confirm_dialog.popup_centered()

func _on_unsaved_confirm_accepted() -> void:
	# 丢弃画面变更——回滚控件到 _saved_graphics
	_graphics_tab.set_values(_saved_graphics)
	_do_close()

func _has_graphics_unsaved() -> bool:
	var current: Dictionary = _graphics_tab.collect()
	return GfxLogic.has_unsaved_changes(current, _saved_graphics)

## === 文案 =======================================================================

func _apply_texts() -> void:
	_title_label.text = TEXT_TITLE
	_close_button.text = TEXT_CLOSE
	_apply_button.text = TEXT_APPLY
	_reset_all_button.text = TEXT_RESET_ALL
	_tab_container.set_tab_title(0, TEXT_TAB_AUDIO)
	_tab_container.set_tab_title(1, TEXT_TAB_GRAPHICS)
	_tab_container.set_tab_title(2, TEXT_TAB_KEYBINDS)
	_tab_container.set_tab_title(3, TEXT_TAB_LANGUAGE)
	_master_label.text = TEXT_MASTER
	_bgm_label.text = TEXT_BGM
	_sfx_label.text = TEXT_SFX
	_keybinds_placeholder.text = TEXT_PLACEHOLDER_KEYBINDS
	_language_placeholder.text = TEXT_PLACEHOLDER_LANGUAGE

## === 恢复默认注册 ===============================================================

func _register_reset_handlers() -> void:
	var store: SettingsStore = _get_store()
	store.register_reset_handler("volume", store.reset_volume_category)
	store.register_reset_handler("graphics", store.reset_graphics_category)
	# 004 按键 / 005 语言落地时各自注册——未注册占位不崩溃

## === 滑入动画 ===================================================================

func _play_slide_in() -> void:
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()
	_panel.position.x = _base_panel_x + SLIDE_OFFSET
	_slide_tween = create_tween()
	_slide_tween.tween_property(_panel, "position:x", _base_panel_x,
			OPEN_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## === 内部辅助 ===================================================================

func _set_bus_percent(bus: int, percent: float) -> void:
	var bus_name: StringName = AudioEnums.BUS_NAMES[bus]
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		push_warning("SettingsPanel: 总线 %s 不存在——音量预览 no-op" % bus_name)
		return
	AudioServer.set_bus_volume_db(idx, Logic.db_from_percent(percent))

func _apply_volumes_to_buses(volumes: Dictionary) -> void:
	for bus: int in volumes.keys():
		_set_bus_percent(bus, float(volumes[bus]))

func _sync_sliders_to(volumes: Dictionary) -> void:
	master_slider.set_value_no_signal(
			float(volumes.get(AudioEnums.AudioBus.MASTER, 100)))
	bgm_slider.set_value_no_signal(
			float(volumes.get(AudioEnums.AudioBus.BGM, 100)))
	sfx_slider.set_value_no_signal(
			float(volumes.get(AudioEnums.AudioBus.SFX, 100)))

func _collect_slider_values() -> Dictionary:
	return {
		AudioEnums.AudioBus.MASTER: int(round(master_slider.value)),
		AudioEnums.AudioBus.BGM: int(round(bgm_slider.value)),
		AudioEnums.AudioBus.SFX: int(round(sfx_slider.value)),
	}

func _get_store() -> SettingsStore:
	if settings_store == null:
		settings_store = SettingsStore.new()
	return settings_store

func _release_lock() -> void:
	if _lock_held:
		if InputManager.has_lock(LOCK_SOURCE):
			InputManager.pop_lock(LOCK_SOURCE)
		_lock_held = false