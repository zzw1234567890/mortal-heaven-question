class_name SettingsPanel
extends Control
## SettingsPanel —— 设置面板覆盖层（main-menu Story 002）。
##
## [b]结构[/b]：全屏遮罩（[code]DimMask[/code] 半透明暗色，UX「设置面板打开」
## 状态变体）+ 左侧面板 [code]Panel[/code]（宽 640 = 1920 基准的 1/3——UX 面板级
## 过渡「覆盖左 1/3 留出背景可见，保留右侧水墨世界」）。[br]
## [br][b]4 分类标签页框架[/b]（AC-main-menu-007）：TabContainer 音效/画面/按键/
## 语言——音效分类本 story 实现（三滑条 Master/BGM/SFX，QL-STORY-READY
## 2026-09-19 裁决一一对应），后三类占位容器归 Story 003/004/005 填充。[br]
## [br][b]音量生效/持久化时机[/b]（GDD 边界澄清 2026-09-07 + story 裁决）：[br]
## 1. 拖动 [code]value_changed[/code] → [b]实时[/b] [code]AudioServer.
## set_bus_volume_db()[/code]（即时可听——AC-main-menu-008）；[br]
## 2. 点「应用」→ 写设置文件（ADR-0031 §2.1 持久设置直写
## [code]user://settings.json[/code]，不经 GSM 不经 SaveLoadSystem）；[br]
## 3. 未保存关闭 → 总线回滚到已保存值（[member _saved_volumes] 快照——
## 拖动中零文件写入，guardrail）。[br]
## [br][b]总线访问[/b]：一律 [code]AudioServer.get_bus_index(名称)[/code] 动态查找
## （[code]AudioEnums.BUS_NAMES[/code] 单一真源——禁硬编码索引）。[br]
## [br][b]输入锁[/b]（ADR-0031 §4 + ADR-0004）：打开时 push MODAL 锁
## （底层主菜单输入冻结），关闭/退出树时 pop 配对；ESC 经
## [method _unhandled_input] 兜底接收（先例 [PauseMenu] B-3——模态拥有者
## 自判 [code]has_lock[/code]；MODAL 锁使 InputManager 路径 B 不拦截本面板的
## ESC，主菜单未来 ESC 语义不受影响）。[br]
## [br][b]动画[/b]：打开 0.3s 滑入（自右侧位移入位，ease-out）/ 关闭 0.2s 滑出
## （ease-in）——story AC 时长（UX 已同步）。[member animate] 为测试注入 +
## reduce-motion 预留接线点（先例 [member MainMenu.animate]）。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]（滑条信号驱动）。
##
## @experimental
## 来源: ADR-0031 §2.1/§4、design/gdd/main-menu-system.md §公式/§边缘情况、
## design/ux/main-menu.md 10a~10m + 面板级过渡、story-002-settings-audio.md。

## === Visual 常量（数据驱动）====================================================

## 打开滑入时长（story AC「打开 0.3s 滑入」——UX 面板级过渡已同步 0.3s）。
const OPEN_DURATION: float = 0.3
## 关闭滑出时长（story AC「关闭 0.2s 滑出」）。
const CLOSE_DURATION: float = 0.2
## 滑入起始位移（px，自右侧入位——UX「从右侧滑入」；数值 = 面板宽度 640）。
const SLIDE_OFFSET: float = 640.0

## MODAL 锁 source——push/pop 配对标识（ADR-0004）。
const LOCK_SOURCE: StringName = &"settings_panel"

## === Logic 内核（preload——先例 MainMenu.Logic 模式）==========================

const Logic := preload("res://src/ui/main_menu/settings_logic.gd")

## === 固定 UI 词条（本地化豁免注记——先例 MainMenu.TEXT_*：项目暂无本地化
## 系统，入库后替换为键）=========================================================

const TEXT_TITLE: String = "设置"
const TEXT_CLOSE: String = "关闭"
const TEXT_APPLY: String = "应用"
const TEXT_TAB_AUDIO: String = "音效"
const TEXT_TAB_GRAPHICS: String = "画面"
const TEXT_TAB_KEYBINDS: String = "按键绑定"
const TEXT_TAB_LANGUAGE: String = "语言"
const TEXT_MASTER: String = "总音量"
const TEXT_BGM: String = "音乐音量"
const TEXT_SFX: String = "音效音量"
## 占位分类文案（内容归 Story 003/004/005——本 story 仅框架容器）。
const TEXT_PLACEHOLDER_GRAPHICS: String = "画面设置（待实现）"
const TEXT_PLACEHOLDER_KEYBINDS: String = "按键绑定（待实现）"
const TEXT_PLACEHOLDER_LANGUAGE: String = "语言（待实现）"

## === 依赖注入（测试可替换）=====================================================

## 设置文件读写模块——null 时新建（默认路径 user://settings.json）；
## 测试注入临时路径实例（先例 PauseMenu.audio_adapter 注入模式）。
var settings_store: SettingsStore = null
## 动画开关——测试注入 + reduce-motion 预留接线点（先例 MainMenu.animate）。
var animate: bool = true

## === 瞬态交互状态（ADR-0031 §2.1）=============================================

## 已保存音量快照（{AudioBus 枚举: int 百分比}）——打开时从设置文件读取，
## 应用成功后更新；未保存关闭的回滚目标。[b]非游戏状态[/b]——面板 UI 脏检测
## 基准（story：与 Story 003 共用脏检测/回滚机制）。
var _saved_volumes: Dictionary = {}
## MODAL 锁持有标志——_exit_tree 兜底 pop 配对（防泄漏锁）。
var _lock_held: bool = false
## 关闭中标志——滑出动画期间屏蔽交互（重复关闭/滑条信号）。
var _closing: bool = false
## 滑入/滑出 Tween 句柄（重入时 kill 防悬挂——先例 PauseMenu._blur_tween）。
var _slide_tween: Tween = null
## 面板停靠基准 x（滑入/滑出动画的目标/起点）。
var _base_panel_x: float = 0.0

## === 节点引用 ==================================================================

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
@onready var _graphics_placeholder: Label = \
		$Panel/PanelVBox/TabContainer/GraphicsTab/GraphicsPlaceholder
@onready var _keybinds_placeholder: Label = \
		$Panel/PanelVBox/TabContainer/KeybindsTab/KeybindsPlaceholder
@onready var _language_placeholder: Label = \
		$Panel/PanelVBox/TabContainer/LanguageTab/LanguagePlaceholder
@onready var _apply_button: Button = $Panel/PanelVBox/ButtonRow/ApplyButton

## === 生命周期 ==================================================================

func _ready() -> void:
	visible = false
	_apply_texts()

func _exit_tree() -> void:
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()
	_release_lock()

## ESC 关闭兜底（先例 PauseMenu._unhandled_input B-3——模态拥有者自判模式）。[br]
## 面板打开持有 MODAL 锁 → InputManager 路径 B 的 ESC 拦截被锁判定阻断
## （不误发 [code]pause_requested[/code]）→ 事件流转至本组件；经
## [method InputManager.has_lock] 确认自己仍是活跃模态拥有者后关闭并标记
## 已处理（阻止主菜单未来 ESC 语义重复响应）。
func _unhandled_input(event: InputEvent) -> void:
	if visible and not _closing and event is InputEventKey \
			and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		if InputManager.has_lock(LOCK_SOURCE):
			get_viewport().set_input_as_handled()
			close()

## === 打开/关闭 =================================================================

## 打开设置面板（幂等——已打开时跳过）。[br]
## 流程：push MODAL 锁 → 从设置文件读取已保存音量（零状态所有权——
## 每次打开重读，不缓存跨会话副本）→ 滑条/总线对齐到已保存值 →
## 可见 + 滑入动画（0.3s）→ 键盘焦点锚定总音量滑条（4.6 双焦点：
## grab_focus 只影响键盘/手柄焦点——先例 PauseMenu）。
func open() -> void:
	if visible:
		push_warning("SettingsPanel.open: 面板已打开——幂等跳过")
		return
	_closing = false
	InputManager.push_lock(InputManager.LockType.MODAL, LOCK_SOURCE)
	_lock_held = true
	_saved_volumes = _get_store().load_volume_category()
	_sync_sliders_to(_saved_volumes)
	_apply_volumes_to_buses(_saved_volumes)
	visible = true
	_base_panel_x = _panel.position.x
	if animate:
		_play_slide_in()
	master_slider.grab_focus()

## 关闭设置面板——未应用变更回滚（story AC：未保存关闭 → 回滚）。[br]
## 回滚总线到 [member _saved_volumes]（应用成功时已更新为最新保存值——
## 「先应用后关闭」场景无回滚感知）；滑条同步复位（重开显示已保存值）。
## pop 锁在滑出动画开始前同步执行（动画期间面板不再持有输入权）。
func close() -> void:
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

## 滑出动画完成回调——隐藏面板并复位关闭中标志。
func _on_slide_out_finished() -> void:
	_finish_close()

## 关闭收尾（动画完成 / animate=false 直达共用）。
func _finish_close() -> void:
	visible = false
	_closing = false
	_panel.position.x = _base_panel_x

## === 按钮与滑条路由 ============================================================

## 滑条拖动/键盘调节 → 总线实时生效（AC-main-menu-008）。[br]
## [param value]: 滑条当前值（0~100）。[param bus]: 总线枚举
## （场景 connection binds 绑定——Master=0/BGM=1/SFX=2）。[br]
## 仅实时预览到总线——[b]不写文件[/b]（guardrail：拖动中无逐帧文件写入）。
func _on_slider_value_changed(value: float, bus: int) -> void:
	if _closing or not visible:
		return
	_set_bus_percent(bus, value)

## 应用 → 持久化写入设置文件（ADR-0031 §2.1 直写）。[br]
## 写入成功后更新 [member _saved_volumes]（后续关闭不再回滚）；失败时
## push_error 保持面板打开、总线维持当前值（可重试——不静默丢设置）。
func _on_apply_pressed() -> void:
	if _closing or not visible:
		return
	var current: Dictionary = _collect_slider_values()
	if _get_store().save_volume_category(current):
		_saved_volumes = current
	else:
		push_error("SettingsPanel: 设置写入失败——保持面板打开（可重试）")

## 关闭按钮（UX 10m）——ESC 同路径（未保存回滚）。
func _on_close_pressed() -> void:
	close()

## === 文案（本地化豁免注记——TEXT_* 单一真理来源，先例 MainMenu._apply_texts）==

func _apply_texts() -> void:
	_title_label.text = TEXT_TITLE
	_close_button.text = TEXT_CLOSE
	_apply_button.text = TEXT_APPLY
	_tab_container.set_tab_title(0, TEXT_TAB_AUDIO)
	_tab_container.set_tab_title(1, TEXT_TAB_GRAPHICS)
	_tab_container.set_tab_title(2, TEXT_TAB_KEYBINDS)
	_tab_container.set_tab_title(3, TEXT_TAB_LANGUAGE)
	_master_label.text = TEXT_MASTER
	_bgm_label.text = TEXT_BGM
	_sfx_label.text = TEXT_SFX
	_graphics_placeholder.text = TEXT_PLACEHOLDER_GRAPHICS
	_keybinds_placeholder.text = TEXT_PLACEHOLDER_KEYBINDS
	_language_placeholder.text = TEXT_PLACEHOLDER_LANGUAGE

## === 滑入动画（Tween 纯视觉变换——ADR-0031 §3 豁免）=========================

## 0.3s 自右侧滑入（UX 面板级过渡 ease-out）。
func _play_slide_in() -> void:
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()
	_panel.position.x = _base_panel_x + SLIDE_OFFSET
	_slide_tween = create_tween()
	_slide_tween.tween_property(_panel, "position:x", _base_panel_x,
			OPEN_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## === 内部辅助 ==================================================================

## 设置总线音量（dB）——经 [code]db_from_percent[/code] 转换（GDD §公式）。[br]
## 总线索引动态查找（禁硬编码——AudioEnums.BUS_NAMES 单一真源）；总线缺失
## 时 push_warning no-op（布局回归可见）。
func _set_bus_percent(bus: int, percent: float) -> void:
	var bus_name: StringName = AudioEnums.BUS_NAMES[bus]
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		push_warning("SettingsPanel: 总线 %s 不存在——音量预览 no-op" % bus_name)
		return
	AudioServer.set_bus_volume_db(idx, Logic.db_from_percent(percent))

## 批量写总线（打开对齐 / 关闭回滚共用）。
func _apply_volumes_to_buses(volumes: Dictionary) -> void:
	for bus: int in volumes.keys():
		_set_bus_percent(bus, float(volumes[bus]))

## 滑条批量复位（不触发 value_changed——set_value_no_signal）。
func _sync_sliders_to(volumes: Dictionary) -> void:
	master_slider.set_value_no_signal(
			float(volumes.get(AudioEnums.AudioBus.MASTER, 100)))
	bgm_slider.set_value_no_signal(
			float(volumes.get(AudioEnums.AudioBus.BGM, 100)))
	sfx_slider.set_value_no_signal(
			float(volumes.get(AudioEnums.AudioBus.SFX, 100)))

## 收集滑条当前值（{AudioBus 枚举: int 百分比}——应用写入的载荷结构）。
func _collect_slider_values() -> Dictionary:
	return {
		AudioEnums.AudioBus.MASTER: int(round(master_slider.value)),
		AudioEnums.AudioBus.BGM: int(round(bgm_slider.value)),
		AudioEnums.AudioBus.SFX: int(round(sfx_slider.value)),
	}

## 获取设置读写模块——注入优先，否则新建（默认路径）。
func _get_store() -> SettingsStore:
	if settings_store == null:
		settings_store = SettingsStore.new()
	return settings_store

## 释放 MODAL 锁（幂等——_exit_tree 兜底与 close 正常路径共用）。[br]
## 先经 [method InputManager.has_lock] 确认锁仍在栈中——场景树变更
## （[code]tree_changed[/code]）已清栈时静默跳过（锁栈清空是合法生命周期，
## 兜底 pop 不应告警）。
func _release_lock() -> void:
	if _lock_held:
		if InputManager.has_lock(LOCK_SOURCE):
			InputManager.pop_lock(LOCK_SOURCE)
		_lock_held = false
