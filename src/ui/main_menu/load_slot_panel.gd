extends Control
## LoadSlotPanel —— 主菜单的「读档」槽位选择覆盖层（纯代码构建 UI）。[br]
## [br][b]为什么需要它[/b]：主菜单此前只有「继续游戏」（= 隐式读最新档），玩家
## 想读哪一格、哪一格是空的，界面上完全看不出来——[code]select_latest_save[/code]
## 按时间戳挑一个，玩家只能接受。[br]
## [br][b]形态与 [SettingsPanel] / [InventoryScreensHost] 同源[/b]：主菜单
## [code]add_child[/code] 一个场景内覆盖层、复用式单例、[code]visible=false[/code]
## 起手——不经 SceneManager 转场（ADR-0031 §1 场景内节点）。[br]
## [br][b]为什么不用 [AcceptDialog][/b]：本面板要列四行可聚焦的槽位按钮，
## 而 [AcceptDialog] 的内容区归引擎自己排布（内置 OK 按钮与自定义 [code]add_child[/code]
## 的控件争同一块位置）。设置面板已经证明「自建遮罩 + 自建返回出口」在这个项目里
## 更可控。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本面板不读也不写存档——槽位文案由调用方
## 经 [method populate] 送进来（含「（空）」与摘要），玩家点了哪一格只经
## [signal slot_chosen] 报出去，读档由宿主的结算层执行。[br]
## [br][b]文案本地化豁免[/b]：与 main_menu / inventory_screen 同源口径。
##
## 来源: ADR-0031 §1/§2、.claude/rules/ui-code.md、
## design/gdd/main-menu-system.md（新游戏 / 继续游戏 / 读档三条路径）、
## 先例 [code]settings_panel.gd[/code]（主菜单内覆盖层）。

## 玩家选中某格——由宿主接住去执行读档（本面板不碰 SaveLoadSystem）。[br]
## [param p_slot_type] [enum SaveLoadSystem.SaveSlotType]。[br]
## [param p_slot_id] 手动槽编号（自动槽为 0）。
signal slot_chosen(p_slot_type: int, p_slot_id: int)

## 返回主菜单意图（返回按钮 / Esc）——宿主据此关闭本面板。
signal back_requested

const TEXT_TITLE: String = "读档"
const TEXT_HINT: String = "选择一个存档槽位"
const TEXT_BACK: String = "返回"
## 空槽位的悬停说明（按钮置灰，玩家要知道为什么点不动）。
const TEXT_EMPTY_TOOLTIP: String = "该槽位没有存档"

## 槽位按钮的尺寸（宽度与主菜单按钮列同宽）。
const SLOT_BUTTON_SIZE: Vector2 = Vector2(420, 44)

var _slot_box: VBoxContainer = null
var _buttons: Array[Button] = []


func _init() -> void:
	name = "LoadSlotPanel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


## 打开面板（幂等——已打开时只恢复可见，不重复申请任何资源）。
func open() -> void:
	visible = true


## 关闭面板——隐藏但[b]留树[/b]（复用式单例，重开不重建控件）。
func close() -> void:
	visible = false


## 是否处于打开态。
func is_open() -> bool:
	return visible


## 按槽位条目重建按钮行。[br]
## [br][param p_entries] [code]{slot_type, slot_id, exists, label}[/code] 数组
## （由 [code]MainMenuLogic.loadable_slots[/code] 组装）。[br]
## [br][b]每个槽位都建按钮[/b]（空的也建，只是置灰）——「第 2 格是空的」这件事
## 本身就是玩家要的信息，隐藏它等于让界面说不出「你还能存到哪」。[br]
func populate(p_entries: Array) -> void:
	_clear_buttons()
	for entry: Dictionary in p_entries:
		var slot_type: int = int(entry.get("slot_type", 0))
		var slot_id: int = int(entry.get("slot_id", 0))
		var exists: bool = bool(entry.get("exists", false))
		var button := Button.new()
		button.name = "Slot_%d_%d" % [slot_type, slot_id]
		button.text = str(entry.get("label", ""))
		button.custom_minimum_size = SLOT_BUTTON_SIZE
		button.focus_mode = Control.FOCUS_ALL
		button.disabled = not exists
		if not exists:
			button.tooltip_text = TEXT_EMPTY_TOOLTIP
		button.pressed.connect(_on_slot_pressed.bind(slot_type, slot_id))
		_slot_box.add_child(button)
		_buttons.append(button)


## 槽位按钮（测试与宿主取焦点用——顺序即 [method populate] 的入参顺序）。
func slot_buttons() -> Array[Button]:
	return _buttons


## 首个可聚焦（有存档）的槽位按钮——列表全空时返回 null。
func first_enabled_button() -> Button:
	for button: Button in _buttons:
		if not button.disabled:
			return button
	return null


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 构建：遮罩 + 居中面板（标题 + 提示 + 槽位列 + 返回）。[br]
## [br][b]为什么不用 [Container] 自动居中[/b]：主菜单的布局锚点是固定偏移的
## （[code]LayoutAnchor[/code] 96/120 起），本面板照同一直觉坐标摆放，避免两套
## 定位口径在主菜单里并存。
func _build() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var box := VBoxContainer.new()
	box.name = "Content"
	box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	box.offset_left = 96.0
	box.offset_top = 120.0
	box.offset_right = 540.0
	box.offset_bottom = 560.0
	box.add_theme_constant_override(&"separation", 12)
	add_child(box)

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = TEXT_TITLE
	title.add_theme_font_size_override(&"font_size", 32)
	box.add_child(title)

	var hint := Label.new()
	hint.name = "HintLabel"
	hint.text = TEXT_HINT
	hint.add_theme_font_size_override(&"font_size", 14)
	box.add_child(hint)

	_slot_box = VBoxContainer.new()
	_slot_box.name = "SlotBox"
	_slot_box.add_theme_constant_override(&"separation", 8)
	box.add_child(_slot_box)

	var back := Button.new()
	back.name = "BackButton"
	back.text = TEXT_BACK
	back.custom_minimum_size = SLOT_BUTTON_SIZE
	back.focus_mode = Control.FOCUS_ALL
	back.pressed.connect(_on_back_pressed)
	box.add_child(back)


## 清空既有按钮行（重开面板时槽位状态可能已变——现取现画，同 ADR-0031 §2）。
func _clear_buttons() -> void:
	for child: Node in _slot_box.get_children():
		_slot_box.remove_child(child)
		child.queue_free()
	_buttons.clear()


## 槽位被选中——先收起面板再报意图（避免宿主读档失败弹损坏框时两层叠在一起）。[br]
## [br][b]顺序不可反[/b]：宿主的成功路径会立刻转场，此时面板还可见的话会跟着
## 上一帧的画面一起淡出；先收起则玩家看到的是干净的转场。
func _on_slot_pressed(p_slot_type: int, p_slot_id: int) -> void:
	close()
	slot_chosen.emit(p_slot_type, p_slot_id)


func _on_back_pressed() -> void:
	close()
	back_requested.emit()
