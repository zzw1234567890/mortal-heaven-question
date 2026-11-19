extends RefCounted
## CombatLayoutZones —— 战场五区域骨架 + 条内组装器 + 按钮位（combat_layout 拆分模块·骨架组）。
##
## [b]职责[/b]：按 UX Layout Zones 表以 anchor 百分比建五区域容器（TopBar / EnemyArea /
## Midline / AllyArea / BottomBar）、暂停按钮位、顶部/底部条组装器、全屏手牌区与右上角
## 撤退按钮位。[b]顺序即绘制层级[/b]——本模块建出的节点一律是宿主布局的直接子节点，
## 只有条内组件（pause / topbar / bottombar）挂在条容器之下。[br]
## [b]零状态所有权[/b]（ADR-0031 §2）：全部成员都是渲染节点与其 anchor 参数，不含游戏状态；
## 内容与行为归后续 story 的组件。[br]
## [b]为什么单独成文件[/b]：[code]combat_layout.gd[/code] 拆分四组挂载后仍超 300 行软上限，
## 骨架块（常量 + 建区 + anchor 换算 + 中线绘制）是最后一块可整体搬走的。
##
## 来源: combat-ui-layout Story 001 AC-1/AC-2/AC-5、design/ux/combat-ui.md §Layout Zones、
## DEBT-CUI-007-2（combat_layout 拆分）。

## 条内组装器脚本（story 004/005/006）。
const TopbarScript: GDScript = preload("res://src/ui/combat/layout/combat_topbar.gd")
const BottombarScript: GDScript = preload("res://src/ui/combat/layout/combat_bottombar.gd")
const HandAreaScript: GDScript = preload("res://src/ui/combat/layout/hand_area.gd")

## 区域高度比例（1920×1080 基准 → anchor 百分比）。
const TOPBAR_HEIGHT_RATIO: float = 60.0 / 1080.0
const ENEMY_AREA_HEIGHT_RATIO: float = 340.0 / 1080.0
const ALLY_AREA_HEIGHT_RATIO: float = 340.0 / 1080.0
const BOTTOMBAR_HEIGHT_RATIO: float = 180.0 / 1080.0
## 中线颜色（UX「全宽 1px 淡墨」）。
const MIDLINE_COLOR: Color = Color(0.30, 0.30, 0.32, 0.6)

## 五区域规格——[code][名字, left, top, right, bottom][/code]，顺序即节点顺序与绘制层级。
const ZONE_SPECS: Array = [
	["TopBar", 0.0, 0.0, 1.0, TOPBAR_HEIGHT_RATIO],
	["EnemyArea", 0.0, TOPBAR_HEIGHT_RATIO, 1.0,
			TOPBAR_HEIGHT_RATIO + ENEMY_AREA_HEIGHT_RATIO],
	["Midline", 0.0, 0.5, 1.0, 0.5],
	["AllyArea", 0.0, 0.5, 1.0, 0.5 + ALLY_AREA_HEIGHT_RATIO],
	["BottomBar", 0.0, 1.0 - BOTTOMBAR_HEIGHT_RATIO, 1.0, 1.0],
]

## 宿主布局根（区域节点挂在它下面）。
var _layout: Control = null

## 五区域容器。
var topbar: Control = null
var enemy_area: Control = null
var midline: Control = null
var ally_area: Control = null
var bottombar: Control = null
## 右上角撤退按钮位（内容/点击行为归 story 008 / interaction）。
var retreat_button_slot: Control = null
## 暂停按钮位（顶部条内——点击/ESC 转发 hud 暂停菜单，菜单本体归 hud 005）。
var pause_button_slot: Control = null
## 顶部条 / 底部条 / 手牌区组装器（story 004/005/006）。
var combat_topbar: Control = null
var combat_bottombar: Control = null
var hand_area: Control = null


## 构造——传入宿主布局根。
func _init(p_layout: Control) -> void:
	_layout = p_layout


## 建全部区域与组装器（[code]_init[/code] 中调用——不依赖场景树时序）。
func build() -> void:
	_build_zones()
	_build_children()


## 五区域容器 + 暂停按钮位（anchor 百分比——1920×1080 基准换算）。
func _build_zones() -> void:
	for spec: Array in ZONE_SPECS:
		var zone: Control = _make_zone(String(spec[0]))
		_anchor_ratio(zone, spec[1], spec[2], spec[3], spec[4])
		_layout.add_child(zone)
		match String(spec[0]):
			"TopBar": topbar = zone
			"EnemyArea": enemy_area = zone
			"Midline":
				# 中线：1px 淡墨自绘线（draw 信号接自绘 zone）
				midline = zone
				zone.custom_minimum_size.y = 1.0
				zone.draw.connect(_draw_midline.bind(zone))
			"AllyArea": ally_area = zone
			"BottomBar": bottombar = zone
	pause_button_slot = _make_zone("PauseButtonSlot")
	pause_button_slot.custom_minimum_size = Vector2(48, 48)
	_anchor_ratio(pause_button_slot, 1.0 - 48.0 / 1920.0, 6.0 / 1080.0,
			1.0 - 6.0 / 1920.0, 6.0 / 1080.0 + 48.0 / 1080.0)
	topbar.add_child(pause_button_slot)


## 三个条内组装器 + 手牌区（全屏层，根末——卡牌按全屏坐标弧形定位）+ 撤退按钮位。
func _build_children() -> void:
	combat_topbar = TopbarScript.new()
	combat_topbar.name = "CombatTopbar"
	_fill_bar(combat_topbar, 1.0 - 60.0 / 1920.0)  # 留出暂停按钮位右端
	topbar.add_child(combat_topbar)
	combat_bottombar = BottombarScript.new()
	combat_bottombar.name = "CombatBottombar"
	_fill_bar(combat_bottombar, 1.0)
	combat_bottombar.anchor_top = 0.5
	bottombar.add_child(combat_bottombar)
	hand_area = HandAreaScript.new()
	hand_area.name = "HandArea"
	hand_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layout.add_child(hand_area)
	retreat_button_slot = _make_zone("RetreatButtonSlot")
	retreat_button_slot.custom_minimum_size = Vector2(48, 48)
	_layout.add_child(retreat_button_slot)
	retreat_button_slot.anchor_left = 1.0 - 60.0 / 1920.0
	retreat_button_slot.anchor_right = 1.0 - 12.0 / 1920.0
	retreat_button_slot.anchor_top = 60.0 / 1080.0 + 8.0 / 1080.0
	retreat_button_slot.anchor_bottom = 60.0 / 1080.0 + 8.0 / 1080.0 + 48.0 / 1080.0


## 条内组件铺满顶部/底部条（左右 8px、上下 6px 内边距）。
func _fill_bar(node: Control, right: float) -> void:
	_anchor_ratio(node, 0.0, 0.0, right, 1.0)
	node.offset_left = 8.0
	node.offset_top = 6.0
	node.offset_right = 0.0
	node.offset_bottom = -6.0


## 区域容器工厂（Control——内容后续 story 填充）。[br]
## [br][b]容器一律不接收鼠标[/b]（2026-11-19 修复）：五区域与两个按钮位都只是布局，
## 真正吃鼠标的只有它们内部的按钮与全屏手势层。[code]Control[/code] 默认是
## [code]MOUSE_FILTER_STOP[/code]，容器带着这个默认值就等于在画面上铺了五块
## 看不见的挡板——底部条那 180px 会连手牌一起截住，敌方区那 340px 会截住点选目标，
## 而界面上完全看不出原因。[br]
## [b]IGNORE 只作用于容器自身[/b]：子控件（按钮 / 角色卡）照常参与拾取，
## 不需要父级替它们放行。
func _make_zone(zone_name: String) -> Control:
	var zone := Control.new()
	zone.name = zone_name
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return zone


## anchor 百分比 + offset 归零（统一入口——story 禁止像素绝对定位）。
func _anchor_ratio(zone: Control, left: float, top: float, right: float,
		bottom: float) -> void:
	zone.anchor_left = left
	zone.anchor_top = top
	zone.anchor_right = right
	zone.anchor_bottom = bottom
	zone.offset_left = 0.0
	zone.offset_top = 0.0
	zone.offset_right = 0.0
	zone.offset_bottom = 0.0


## 中线绘制（1px 淡墨——draw 信号接自绘 zone）。
func _draw_midline(zone: Control) -> void:
	if zone.size.y <= 0.0:
		return
	zone.draw_line(Vector2(0, zone.size.y * 0.5),
			Vector2(zone.size.x, zone.size.y * 0.5), MIDLINE_COLOR, 1.0)
