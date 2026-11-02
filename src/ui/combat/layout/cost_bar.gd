class_name CostBar
extends Control
## CostBar —— 底部条费用栏组件（combat-ui-layout Story 005）。
##
## [b]职责[/b]：费用显示渲染态——实际可用/基础上限大字 + 临时费用绿色
## 额外数字（如 [code]0/0 [+3临时][/code]）。费用颜色经
## [method CombatUiRules.cost_color] 纯函数解析（含 base_max=0 双守卫）。[br]
## [br][b]消耗动画[/b]（AC-3）：数字跳动 Tween 0.2s + 光粒消散（D3D12 烟雾项——
## CPUParticles2D 瞬发，009b 统一执行本地验证）；临时费用归零时绿色数字淡出。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：费用数据所有权在 CostSystem——
## 本组件只持渲染快照（[method apply_cost_state] 由 [signal CostSystem.cost_changed]
## 信号驱动），无 [code]_process()[/code] 轮询。[br]
## [br][b]依赖注入[/b]：数据经 [method apply_cost_state] 直接调用（测试直调）；
## 生产由底部条组装器订阅 CostSystem 信号转发。[br]
##
## @experimental
## 来源: ADR-0031、ADR-0015、design/gdd/combat-ui-system.md §4/§费用栏、
## combat-ui-layout Story 005（AC-1/AC-3）。

## === 视觉常量 ================================================================

## 费用主数字字号（pt——1920×1080 基准，响应式由组装器统一处理）。
const COST_FONT_SIZE: int = 22
## 临时费用绿色。
const TEMP_COLOR: Color = Color(0.30, 0.75, 0.38)
## 数字跳动动画时长（秒——GDD AC「数字跳动减少 0.2s」）。
const JUMP_ANIM_SEC: float = 0.2
## 数字跳动放大峰值。
const JUMP_SCALE_PEAK: float = 1.25
## 临时费用淡出动画时长（秒）。
const TEMP_FADE_SEC: float = 0.2

## === 子节点引用（_build 创建）=================================================

## 费用主数字 Label（「实际可用 / 基础上限」）。
var cost_label: Label = null
## 临时费用绿色 Label（「[+N临时]」——无临时时隐藏）。
var temp_label: Label = null

## === 运行态（渲染快照——§2.1 豁免）===========================================

## 实际可用费用（含临时）。
var _available: int = 0
## 基础费用上限。
var _base_max: int = 0
## 临时费用加值。
var _temporary: int = 0
## 减少动态标志（true = 动画跳过直跳终态）。
var _reduce_motion: bool = false
## 数字跳动 Tween（重入 kill 重建）。
var _jump_tween: Tween = null
## 临时费用淡出 Tween（重入 kill 重建）。
var _temp_tween: Tween = null


func _init() -> void:
	_build()


## 构建子节点（费用数字 + 临时费用 Label——_init 构建，不依赖场景树时序）。
func _build() -> void:
	custom_minimum_size = Vector2(120, 40)
	cost_label = Label.new()
	cost_label.name = "CostLabel"
	cost_label.add_theme_font_size_override("font_size", COST_FONT_SIZE)
	cost_label.add_theme_color_override("font_color", CombatUiRules.COST_COLOR_WHITE)
	cost_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(cost_label)
	temp_label = Label.new()
	temp_label.name = "TempLabel"
	temp_label.add_theme_font_size_override("font_size", 14)
	temp_label.add_theme_color_override("font_color", TEMP_COLOR)
	temp_label.anchor_left = 0.0
	temp_label.anchor_top = 0.0
	temp_label.anchor_right = 0.0
	temp_label.anchor_bottom = 0.0
	temp_label.offset_top = 4.0
	temp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	temp_label.visible = false
	add_child(temp_label)
	_apply_texts()


## 设置减少动态（true = 动画跳过直跳终态——UX 减少动态替代）。
func set_reduce_motion(reduce_motion: bool) -> void:
	_reduce_motion = reduce_motion


## 应用费用状态（cost_changed 信号载荷消费入口——AC-2 信号驱动）。[br]
## [param available]: 实际可用费用（含临时加成）。[br]
## [param base_max]: 基础费用上限。[br]
## [param temporary]: 临时费用加值。
func apply_cost_state(available: int, base_max: int, temporary: int) -> void:
	var prev_available: int = _available
	var prev_temporary: int = _temporary
	_available = available
	_base_max = base_max
	_temporary = temporary
	_apply_texts()
	# 数字跳动：可用费用减少时触发（费用消耗——AC-3）
	if available < prev_available:
		_play_jump_anim()
	else:
		_reset_jump_scale()
	# 临时费用用完：绿色数字淡出（基础费用不变——AC-4）
	if temporary == 0 and prev_temporary > 0:
		_play_temp_fade()


## 获取费用文本（测试断言用）。
func get_cost_text() -> String:
	return cost_label.text


## 获取临时费用文本（测试断言用）。
func get_temp_text() -> String:
	return temp_label.text


## 获取临时费用可见性（测试断言用）。
func is_temp_visible() -> bool:
	return temp_label.visible


## 获取费用颜色（测试断言用——应为 cost_color 解析结果）。
func get_cost_color() -> Color:
	return cost_label.get_theme_color("font_color")


## 是否有进行中的数字跳动动画（测试探针——替代直访 _jump_tween 私有成员）。
func has_jump_anim_active() -> bool:
	return _jump_tween != null and _jump_tween.is_valid()


## 是否有进行中的临时费用淡出动画（测试探针——替代直访 _temp_tween 私有成员）。
func has_temp_fade_active() -> bool:
	return _temp_tween != null and _temp_tween.is_valid()


## === 内部 ====================================================================

## 费用文本 + 颜色落定（cost_color 纯函数解析）。
func _apply_texts() -> void:
	cost_label.text = "%d / %d" % [_available, _base_max]
	cost_label.add_theme_color_override("font_color",
			CombatUiRules.cost_color(_available, _base_max, _temporary))
	if _temporary > 0:
		# 重新显示：kill 进行中的淡出 Tween 并恢复 alpha（re-entry 竞态修复——
		# 淡出窗口内临时费用重新注入时，旧 fade 不得把刚恢复的数字再隐藏）
		_kill_temp_tween()
		temp_label.modulate.a = 1.0
		temp_label.text = "[+%d临时]" % _temporary
		temp_label.visible = true
		# 临时 Label 紧随主数字右侧——偏移按主数字宽估算（固定基准偏移）
		temp_label.offset_left = cost_label.get_minimum_size().x + 6.0
	else:
		temp_label.visible = false


## 数字跳动——放大回落（0.2s；reduce_motion 直跳）。
func _play_jump_anim() -> void:
	_kill_jump_tween()
	if _reduce_motion:
		cost_label.scale = Vector2.ONE
		return
	cost_label.pivot_offset = cost_label.size * 0.5
	cost_label.scale = Vector2(JUMP_SCALE_PEAK, JUMP_SCALE_PEAK)
	_jump_tween = create_tween()
	_jump_tween.tween_property(cost_label, "scale", Vector2.ONE, JUMP_ANIM_SEC) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 数字跳动 scale 复位（非消耗路径——中断跳动后 scale 不得卡在中间值）。
func _reset_jump_scale() -> void:
	_kill_jump_tween()
	cost_label.scale = Vector2.ONE


## 临时费用淡出——绿色数字淡出（0.2s；reduce_motion 直跳隐藏）。[br]
## [b]可见性前置[/b]：temporary 归零时 [method _apply_texts] 已先 hidden 临时段，
## 故淡出前需重新置 visible 并恢复 alpha——否则淡出过程不可见（AC-4 视觉需求）。
func _play_temp_fade() -> void:
	_kill_temp_tween()
	if _reduce_motion:
		temp_label.modulate.a = 0.0
		temp_label.visible = false
		return
	temp_label.visible = true
	temp_label.modulate.a = 1.0
	_temp_tween = create_tween()
	_temp_tween.tween_property(temp_label, "modulate:a", 0.0, TEMP_FADE_SEC)
	_temp_tween.tween_callback(func() -> void: temp_label.visible = false)


func _kill_jump_tween() -> void:
	if _jump_tween != null and _jump_tween.is_valid():
		_jump_tween.kill()
	_jump_tween = null


func _kill_temp_tween() -> void:
	if _temp_tween != null and _temp_tween.is_valid():
		_temp_tween.kill()
	_temp_tween = null
