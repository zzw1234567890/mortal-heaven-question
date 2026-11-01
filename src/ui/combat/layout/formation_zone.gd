class_name FormationZone
extends Control
## FormationZone —— 顶部条阵法区（combat-ui-layout Story 004）。
##
## [b]职责[/b]：3 个阵法槽位展示——已部署阵法卡（阵名 + 阵营标签）+ 空位灰色
## 虚线框常驻；激活阵法外发光（颜色对应阵营）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：阵法数据所有权在 FormationSystem——
## 本组件只持渲染快照，[method apply_slot]/[method apply_slot_states] 由
## [code]formation_deployed/activated/deactivated/overwritten[/code] 信号驱动。[br]
## [br][b]阵名与阵营解析[/b]（ADR-0018 绝不硬编码标签定义）：经注入的
## [member _formation_info_cb]（template_id → {name, tag_id}）与
## [member _tag_color_cb]（tag_id → {name, color}）回调查询；回调缺失时
## 阵名退化为 template_id 字面、光环退化为 [constant DEFAULT_AURA_COLOR]。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]——光环为静态自绘（不随帧变化），
## 激活状态变化由信号触发重绘。[br]
## [br][b]第 4 个部署拒绝[/b]归阵法系统（can_deploy/slots_full）——本组件只展示
## 固定 3 位。阵法悬停详情归 interaction epic（300ms hover）。
##
## @experimental
## 来源: ADR-0031、ADR-0018、design/gdd/combat-ui-system.md §阵法区、
## combat-ui-layout Story 004（AC-4）。

## === 槽位常量（GDD：最多 3 阵法位）===========================================

const MAX_SLOTS: int = 3
## 空位虚线框颜色（灰——与角色空位框蓝区分，阵法空位语义）。
const EMPTY_FRAME_COLOR: Color = Color(0.55, 0.55, 0.58, 0.6)
## 虚线段长。
const DASH_LENGTH: float = 5.0
## 线宽。
const LINE_WIDTH: float = 1.5
## 光环默认色（阵营元数据缺失时的安全回退——淡金）。
const DEFAULT_AURA_COLOR: Color = Color(0.95, 0.80, 0.35)
## 光环透明度上限（激活态）。
const AURA_ALPHA: float = 0.45
## 阵名文本色。
const NAME_COLOR: Color = Color(0.92, 0.92, 0.90)
## 阵营标签文本色。
const TAG_COLOR: Color = Color(0.80, 0.80, 0.78)
## 激活边框色（金）。
const ACTIVE_BORDER_COLOR: Color = Color(0.95, 0.80, 0.35, 0.5)
## 未激活边框色（暗灰）。
const INACTIVE_BORDER_COLOR: Color = Color(0.45, 0.48, 0.52, 0.5)

## === 子节点引用（_build 创建）=================================================

## 3 个槽位 Control（每个含光环/边框/阵名/阵营标签自绘）。
var _slots: Array[Control] = []

## === 运行态（渲染快照）========================================================

## 每槽位状态快照：{template_id, display_name, is_active, tag_id, tag_name, tag_color}。
## 空位 = template_id 为空且 is_active=false。
var _slot_data: Array[Dictionary] = []

## 阵名/阵营标签查询回调——func(template_id: StringName) -> {name, tag_id}。
var _formation_info_cb: Callable = Callable()
## 阵营颜色查询回调——func(tag_id: StringName) -> {name, color}。
var _tag_color_cb: Callable = Callable()


func _init() -> void:
	_build()


## 构建 3 槽位（_init 构建——不依赖场景树时序）。槽位等宽横排，
## 每槽位空位虚线框常驻（_draw 自绘）。
func _build() -> void:
	custom_minimum_size = Vector2(168, 48)
	_slot_data.clear()
	for i: int in range(MAX_SLOTS):
		var slot := Control.new()
		slot.name = "Slot%d" % i
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.draw.connect(_draw_slot.bind(slot, i))
		add_child(slot)
		_slots.append(slot)
		_slot_data.append(_empty_slot_data())


## 注入阵名/阵营标签查询回调。[param cb]: func(template_id) -> {name, tag_id}。
func set_formation_info_callback(cb: Callable) -> void:
	_formation_info_cb = cb


## 注入阵营颜色查询回调。[param cb]: func(tag_id) -> {name, color}。
func set_tag_color_callback(cb: Callable) -> void:
	_tag_color_cb = cb


## 应用单槽位部署状态（formation_deployed/activated 信号载荷——单点刷新）。[br]
## [param template_id]: 阵法模板 ID（空 = 清空槽位为空格）。[br]
## [param is_active]: 激活态（光环开关）。
func apply_slot(slot_index: int, template_id: StringName, is_active: bool) -> void:
	if slot_index < 0 or slot_index >= MAX_SLOTS:
		return
	_slot_data[slot_index] = _resolve_slot(template_id, is_active)
	_slots[slot_index].queue_redraw()


## 应用全部槽位状态（FormationSystem.get_slot_states() 全量重扫——deactivated /
## overwritten 信号不携带 template_id 时经此恢复真实状态，避免「清空后残留」漂移）。[br]
## [param slot_states]: Array[Dictionary]——每项含 template_id/is_active。
func apply_slot_states(slot_states: Array) -> void:
	for i: int in range(MAX_SLOTS):
		if i < slot_states.size():
			var src: Dictionary = slot_states[i]
			var template_id: StringName = src.get("template_id", StringName(&""))
			var is_active: bool = bool(src.get("is_active", false))
			_slot_data[i] = _resolve_slot(template_id, is_active)
		else:
			_slot_data[i] = _empty_slot_data()
		_slots[i].queue_redraw()


## 仅切换槽位激活态（formation_deactivated——信号不携带 template_id，阵卡仍在位，
## 只熄灭光环；保留原阵名/template_id，与 FormationSystem DEPLOYED_UNACTIVE 语义一致）。
func set_slot_active(slot_index: int, is_active: bool) -> void:
	if slot_index < 0 or slot_index >= MAX_SLOTS:
		return
	_slot_data[slot_index]["is_active"] = is_active
	_slots[slot_index].queue_redraw()


## 获取槽位快照（测试断言用）。
func get_slot_data() -> Array[Dictionary]:
	return _slot_data


## === 内部 ====================================================================

## 空槽位快照。
func _empty_slot_data() -> Dictionary:
	return {"template_id": StringName(&""), "display_name": "", "is_active": false,
			"tag_id": StringName(&""), "tag_name": "", "tag_color": Color(1, 1, 1)}


## 解析槽位快照——阵名/阵营标签/光环色均在此解析（回调缺失时安全回退）。
func _resolve_slot(template_id: StringName, is_active: bool) -> Dictionary:
	if template_id == &"":
		return _empty_slot_data()
	var display_name: String = String(template_id)
	var tag_id: StringName = StringName(&"")
	if _formation_info_cb.is_valid():
		var info: Dictionary = _formation_info_cb.call(template_id)
		if not info.is_empty():
			display_name = String(info.get("name", display_name))
			tag_id = StringName(info.get("tag_id", StringName(&"")))
	var tag_name: String = ""
	var tag_color: Color = DEFAULT_AURA_COLOR
	if tag_id != &"" and _tag_color_cb.is_valid():
		var tag_info: Dictionary = _tag_color_cb.call(tag_id)
		if not tag_info.is_empty():
			tag_name = String(tag_info.get("name", ""))
			var resolved: Variant = tag_info.get("color", DEFAULT_AURA_COLOR)
			if resolved is Color:
				tag_color = resolved
	return {"template_id": template_id, "display_name": display_name,
			"is_active": is_active, "tag_id": tag_id, "tag_name": tag_name,
			"tag_color": tag_color}


## 槽位布局——3 等分（_notification 在尺寸落定后重排子槽位 anchor）。
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_relayout_slots()


## 子槽位 anchor 重排（等宽 3 列）。
func _relayout_slots() -> void:
	if _slots.is_empty() or size.x <= 0.0:
		return
	var w: float = size.x / MAX_SLOTS
	for i: int in range(MAX_SLOTS):
		var slot: Control = _slots[i]
		slot.anchor_left = 0.0
		slot.anchor_right = 0.0
		slot.anchor_top = 0.0
		slot.anchor_bottom = 0.0
		slot.offset_left = i * w
		slot.offset_right = i * w + w
		slot.offset_top = 0.0
		slot.offset_bottom = size.y
		slot.queue_redraw()


## 槽位自绘——空位虚线框 / 已部署阵名 + 阵营标签 / 激活光环。
func _draw_slot(slot: Control, slot_index: int) -> void:
	if slot.size.x <= 0.0 or slot.size.y <= 0.0:
		return
	var data: Dictionary = _slot_data[slot_index]
	var is_empty: bool = StringName(data["template_id"]) == &""
	# 激活光环（外发光——半透明扩边，颜色对应阵营；未解析走默认色）
	if bool(data["is_active"]):
		var aura_color: Color = data["tag_color"] as Color
		aura_color.a = AURA_ALPHA
		slot.draw_rect(Rect2(Vector2(-2, -2), slot.size + Vector2(4, 4)), aura_color)
	# 空位：灰色虚线框
	if is_empty:
		_draw_dashed_border(slot, EMPTY_FRAME_COLOR)
		return
	# 已部署：实线边框 + 阵名 + 阵营标签
	var border_color: Color = ACTIVE_BORDER_COLOR \
			if bool(data["is_active"]) else INACTIVE_BORDER_COLOR
	slot.draw_rect(Rect2(Vector2.ZERO, slot.size), border_color, false, 1.5)
	slot.draw_string(ThemeDB.fallback_font, Vector2(4, 18),
			String(data["display_name"]), HORIZONTAL_ALIGNMENT_LEFT,
			slot.size.x - 8, 13, NAME_COLOR)
	var tag_text: String = String(data["tag_name"])
	if tag_text != "":
		slot.draw_string(ThemeDB.fallback_font, Vector2(4, 34), tag_text,
				HORIZONTAL_ALIGNMENT_LEFT, slot.size.x - 8, 11, TAG_COLOR)


## 四边虚线框（灰色——空位语义）。
func _draw_dashed_border(slot: Control, color: Color) -> void:
	var w: float = slot.size.x
	var h: float = slot.size.y
	slot.draw_dashed_line(Vector2(0, 0), Vector2(w, 0), color, LINE_WIDTH, DASH_LENGTH, true)
	slot.draw_dashed_line(Vector2(w, 0), Vector2(w, h), color, LINE_WIDTH, DASH_LENGTH, true)
	slot.draw_dashed_line(Vector2(w, h), Vector2(0, h), color, LINE_WIDTH, DASH_LENGTH, true)
	slot.draw_dashed_line(Vector2(0, h), Vector2(0, 0), color, LINE_WIDTH, DASH_LENGTH, true)
