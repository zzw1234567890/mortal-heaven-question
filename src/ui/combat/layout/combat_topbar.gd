class_name CombatTopbar
extends Control
## CombatTopbar —— 顶部条三组件组装器（combat-ui-layout Story 004）。
##
## [b]职责[/b]：将阶段指示器（[PhaseIndicator]）+ 阵法区（[FormationZone]）+
## 战斗日志（[CombatLog]）组装进 Story 001 的 TopBar 容器，并完成系统信号接线
## （phase_changed / battle_started / battle_ended / formation_* 信号驱动组件）。[br]
## [br][b]横向顺序[/b]（GDD §560）：日志入口 → 回合阶段指示器 → 阵法区 →
## 暂停按钮位（story 001 已建于 topbar 右端）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本组装器只做信号路由 + 组件引用，
## 不持游戏状态——阶段/阵法/日志数据均由各组件持渲染快照，经系统信号驱动。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]——纯信号驱动。[br]
## [br][b]依赖注入[/b]：战斗/阵法源对象经 [method bind_signals] 注入（测试注入
## mock——生产由 CombatLayout 传入 Autoload）。阵名/阵营解析经
## [method set_formation_info_callback]/[method set_tag_color_callback] 回调
## （测试免 CardSystem/FactionSystem 依赖）。
##
## @experimental
## 来源: ADR-0031、ADR-0008、design/gdd/combat-ui-system.md §顶部条/§560、
## combat-ui-layout Story 004。

## === 布局常量（1920×1080 基准 anchor 比例——非像素硬编码）====================

## 日志入口宽比例（90/1920）。
const LOG_WIDTH_RATIO: float = 90.0 / 1920.0
## 阶段指示器宽比例（260/1920）。
const PHASE_WIDTH_RATIO: float = 260.0 / 1920.0
## 阵法区宽比例（168/1920）。
const FORMATION_WIDTH_RATIO: float = 168.0 / 1920.0
## 组件间距（8/1920）。
const GAP_RATIO: float = 8.0 / 1920.0

## === 子组件引用 ==============================================================

var phase_indicator: PhaseIndicator = null
var formation_zone: FormationZone = null
var combat_log: CombatLog = null

## === 注入回调 ================================================================

## 阵法信息查询回调——func(template_id: StringName) -> {name, tag_id}。
## 转发给 FormationZone。
var _formation_info_cb: Callable = Callable()
## 阵营颜色查询回调——func(tag_id: StringName) -> {name, color}。
## 转发给 FormationZone（FactionSystem 查询）。
var _tag_color_cb: Callable = Callable()
## 阶段切换音回调——func(old_phase, new_phase)。转发给 PhaseIndicator。
var _phase_audio_cb: Callable = Callable()


func _init() -> void:
	_build()


## 构建三组件（_init 构建——不依赖场景树时序）。
func _build() -> void:
	custom_minimum_size = Vector2(500, 48)
	phase_indicator = PhaseIndicator.new()
	phase_indicator.name = "PhaseIndicator"
	add_child(phase_indicator)
	formation_zone = FormationZone.new()
	formation_zone.name = "FormationZone"
	add_child(formation_zone)
	combat_log = CombatLog.new()
	combat_log.name = "CombatLog"
	add_child(combat_log)


## 注入阵法信息查询回调（阵名 + 阵营标签）。[param cb]: func(template_id) -> {name, tag_id}。
func set_formation_info_callback(cb: Callable) -> void:
	_formation_info_cb = cb
	formation_zone.set_formation_info_callback(cb)


## 注入阵营颜色查询回调（转发 FormationZone）。[param cb]: func(tag_id) -> {name, color}。
func set_tag_color_callback(cb: Callable) -> void:
	_tag_color_cb = cb
	formation_zone.set_tag_color_callback(cb)


## 注入阶段切换音回调（转发 PhaseIndicator）。
func set_phase_audio_callback(cb: Callable) -> void:
	_phase_audio_cb = cb
	phase_indicator.set_phase_audio_callback(cb)


## 设置减少动态（转发三组件）。
func set_reduce_motion(reduce_motion: bool) -> void:
	phase_indicator.set_reduce_motion(reduce_motion)
	combat_log.set_reduce_motion(reduce_motion)


## 绑定系统信号（依赖注入——测试注入 mock Node，生产传 Autoload）。[br]
## [param combat_source]: CombatSystem 信号源（phase_changed/battle_started/battle_ended）。[br]
## [param formation_source]: FormationSystem 信号源（formation_deployed 等）。[br]
## [b]重复调用防护[/b]：同源已绑定则跳过（is_connected——hud.gd 先例）。
func bind_signals(combat_source: Node, formation_source: Node) -> void:
	if combat_source != null and combat_source.has_signal(&"phase_changed") \
			and not combat_source.phase_changed.is_connected(_on_phase_changed):
		combat_source.phase_changed.connect(_on_phase_changed)
	if combat_source != null and combat_source.has_signal(&"battle_started") \
			and not combat_source.battle_started.is_connected(_on_battle_started):
		combat_source.battle_started.connect(_on_battle_started)
	if combat_source != null and combat_source.has_signal(&"battle_ended") \
			and not combat_source.battle_ended.is_connected(_on_battle_ended):
		combat_source.battle_ended.connect(_on_battle_ended)
	if formation_source != null:
		_bind_formation_signals(formation_source)


## === 信号回调 ================================================================

## phase_changed → 阶段指示器更新 + 日志阶段 2 自动收起（AC-1/AC-2）。
func _on_phase_changed(old_phase: int, new_phase: int, turn: int) -> void:
	phase_indicator.apply_phase(old_phase, new_phase, turn)
	combat_log.apply_phase(new_phase)


## battle_started → 初始阶段落定（阶段 0「准备」+ 回合 1——消除「—/第 0 回合」初始态）。
func _on_battle_started(_config: Dictionary) -> void:
	phase_indicator.set_initial_phase(0, 1)


## battle_ended → 日志清空（AC-2 战后清理条款）。
func _on_battle_ended(_result: int, _rewards: Dictionary) -> void:
	combat_log.clear()


## === 布局 ====================================================================

## 三组件横向排布（_notification 尺寸落定后重排）。
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_relayout()


## 横向排布：日志入口（左）→ 阶段指示器 → 阵法区（anchor 比例——1920 基准）。
func _relayout() -> void:
	if phase_indicator == null or size.x <= 0.0:
		return
	var x: float = 0.0
	x = _place_ratio(combat_log, x, LOG_WIDTH_RATIO)
	x += GAP_RATIO * 1920.0
	x = _place_ratio(phase_indicator, x, PHASE_WIDTH_RATIO)
	x += GAP_RATIO * 1920.0
	_place_ratio(formation_zone, x, FORMATION_WIDTH_RATIO)


## 子组件定位（anchor 比例换算——按 1920 基准宽转为 offset 像素）。
func _place_ratio(node: Control, x: float, width_ratio: float) -> float:
	if node == null:
		return x
	node.anchor_left = 0.0
	node.anchor_right = 0.0
	node.anchor_top = 0.0
	node.anchor_bottom = 0.0
	node.offset_left = x
	node.offset_right = x + width_ratio * 1920.0
	node.offset_top = 0.0
	node.offset_bottom = size.y
	return node.offset_right


## === 阵法信号接线 =============================================================

## formation_* 信号 → 阵法区刷新（四信号族）。
func _bind_formation_signals(source: Node) -> void:
	if source.has_signal(&"formation_deployed") \
			and not source.formation_deployed.is_connected(_on_formation_deployed):
		source.formation_deployed.connect(_on_formation_deployed)
	if source.has_signal(&"formation_activated") \
			and not source.formation_activated.is_connected(_on_formation_activated):
		source.formation_activated.connect(_on_formation_activated)
	if source.has_signal(&"formation_deactivated") \
			and not source.formation_deactivated.is_connected(_on_formation_deactivated):
		source.formation_deactivated.connect(_on_formation_deactivated)
	if source.has_signal(&"formation_overwritten") \
			and not source.formation_overwritten.is_connected(_on_formation_overwritten):
		source.formation_overwritten.connect(_on_formation_overwritten)


## formation_deployed(_id, slot_index, template_id, _deployed_turn)。
func _on_formation_deployed(_formation_id: int, slot_index: int,
		template_id: StringName, _deployed_turn: int) -> void:
	formation_zone.apply_slot(slot_index, template_id, false)


## formation_activated(_id, slot_index, template_id, _reason)。
func _on_formation_activated(_formation_id: int, slot_index: int,
		template_id: StringName, _reason: String) -> void:
	formation_zone.apply_slot(slot_index, template_id, true)


## formation_deactivated(_id, slot_index, _reason)——信号不携带 template_id。[br]
## 阵位状态实为 DEPLOYED_UNACTIVE（阵法卡仍在位、光环消失），非空位。[br]
## 单点刷新拿不到阵名，故置 is_active=false 保留原 template_id/阵名——光环熄灭
## 而非清空（与 FormationSystem 状态机语义一致，避免「显示与实际漂移」）。
func _on_formation_deactivated(formation_id: int, slot_index: int, _reason: String) -> void:
	formation_zone.set_slot_active(slot_index, false)


## formation_overwritten(_old_id, _new_id, slot_index)——旧阵清空（新阵随后 deployed 信号刷新）。
func _on_formation_overwritten(_old_formation_id: int, _new_formation_id: int,
		slot_index: int) -> void:
	formation_zone.apply_slot(slot_index, StringName(&""), false)
