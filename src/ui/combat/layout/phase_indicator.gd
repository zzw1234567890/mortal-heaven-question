class_name PhaseIndicator
extends Control
## PhaseIndicator —— 顶部条阶段指示器（combat-ui-layout Story 004）。
##
## [b]职责[/b]：7 阶段（0-6）名称 + 7 格进度位置指示 + 回合编号。阶段 0 名称
## 统一显示「准备」（边界澄清 2026-09-07——「备战」为阶段 0 全屏面板名，两者
## 不同对象）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：阶段数据所有权在 CombatSystem——
## 本组件只持渲染快照，[method apply_phase] 由 [code]phase_changed[/code] 信号
## 驱动。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]；阶段切换动画 0.2s 一次性 Tween
## （§2.1 豁免）。节点树无 Timer 驱动 UI（阶段 2 无倒计时——GDD 明文，策略游戏
## 不施加时间压力）。[br]
## [br][b]阶段切换音[/b]：经 [member _phase_audio_cb] 回调触发音频事件
## （audio-manager 播放——本组件不直接依赖音频系统，回调由顶层注入）。
##
## @experimental
## 来源: ADR-0031、design/gdd/combat-ui-system.md §回合阶段指示器/§阶段切换音、
## combat-ui-layout Story 004（AC-1）。

## === 阶段名称常量（数据驱动——7 阶段 0-6，GDD §6 快速参考表）=================

const PHASE_NAMES: Array[String] = [
	"准备",      # 0 PREPARATION
	"抽牌",      # 1 DRAW
	"出牌",      # 2 PLAY
	"攻击声明",  # 3 ATTACK_DECLARATION
	"攻击结算",  # 4 ATTACK_RESOLUTION
	"敌方行动",  # 5 ENEMY_TURN
	"结束",      # 6 END
]

## === 动画常量（UX Transitions）================================================

## 阶段名切换动画时长（秒——GDD AC「短暂放大/滑入 0.2s」）。
const PHASE_ANIM_SEC: float = 0.2
## 阶段名放大峰值（1.0 → 峰值 → 回落 1.0）。
const PHASE_SCALE_PEAK: float = 1.18

## === 视觉常量（R-02 数据驱动）=================================================

## 进度格数（7 阶段）。
const PHASE_STEP_COUNT: int = 7
## 当前阶段格高亮色（青金——阵营主色系）。
const STEP_ACTIVE_COLOR: Color = Color(0.95, 0.80, 0.35)
## 已过阶段格色（淡青）。
const STEP_DONE_COLOR: Color = Color(0.42, 0.66, 0.55)
## 未来阶段格色（暗灰）。
const STEP_PENDING_COLOR: Color = Color(0.24, 0.26, 0.30)
## 阶段名文本色（近白）。
const LABEL_COLOR: Color = Color(0.92, 0.92, 0.90)
## 回合编号文本色（暖白）。
const TURN_COLOR: Color = Color(0.82, 0.80, 0.76)

## === 子节点引用（_build 创建）=================================================

## 阶段名 Label。
var phase_label: Label = null
## 回合编号 Label（「第 X 回合」）。
var turn_label: Label = null
## 进度条自绘区域（7 格）。
var _progress_rect: Control = null

## === 运行态（渲染快照——瞬态视觉状态 §2.1 豁免）===============================

## 当前阶段（-1 = 未初始化）。
var _phase: int = -1
## 当前回合编号。
var _turn: int = 0
## 减少动态标志（true = 切换动画跳过，直跳）。
var _reduce_motion: bool = false
## 阶段切换音回调——func(old_phase, new_phase)。null = 不触发。
var _phase_audio_cb: Callable = Callable()
## 阶段名动画 Tween（重入 kill 重建）。
var _anim_tween: Tween = null


func _init() -> void:
	_build()


## 构建子节点（Label + 进度条自绘区——_init 构建，不依赖场景树时序）。
func _build() -> void:
	custom_minimum_size = Vector2(240, 48)
	phase_label = Label.new()
	phase_label.name = "PhaseLabel"
	phase_label.add_theme_font_size_override("font_size", 18)
	phase_label.add_theme_color_override("font_color", LABEL_COLOR)
	phase_label.anchor_left = 0.0
	phase_label.anchor_right = 0.55
	phase_label.anchor_top = 0.0
	phase_label.anchor_bottom = 1.0
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(phase_label)
	turn_label = Label.new()
	turn_label.name = "TurnLabel"
	turn_label.add_theme_font_size_override("font_size", 14)
	turn_label.add_theme_color_override("font_color", TURN_COLOR)
	turn_label.anchor_left = 0.55
	turn_label.anchor_right = 0.78
	turn_label.anchor_top = 0.0
	turn_label.anchor_bottom = 1.0
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	turn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(turn_label)
	_progress_rect = Control.new()
	_progress_rect.name = "ProgressRect"
	_progress_rect.anchor_left = 0.78
	_progress_rect.anchor_right = 1.0
	_progress_rect.anchor_top = 0.25
	_progress_rect.anchor_bottom = 0.75
	_progress_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_rect.draw.connect(_draw_progress.bind(_progress_rect))
	add_child(_progress_rect)
	_apply_texts()


## 设置减少动态（true = 阶段切换动画跳过，直跳终态——UX 减少动态替代）。
func set_reduce_motion(reduce_motion: bool) -> void:
	_reduce_motion = reduce_motion


## 注入阶段切换音回调。[param cb]: func(old_phase, new_phase) -> void。
func set_phase_audio_callback(cb: Callable) -> void:
	_phase_audio_cb = cb


## 应用阶段切换（phase_changed 信号载荷消费入口——AC-1）。[br]
## [param old_phase]: 旧阶段。[param new_phase]: 新阶段。[param turn]: 回合编号。
func apply_phase(old_phase: int, new_phase: int, turn: int) -> void:
	# 同阶段重复信号——无变化（AC-1 edge）
	if new_phase == _phase and turn == _turn:
		return
	_phase = new_phase
	_turn = turn
	_apply_texts()
	_progress_rect.queue_redraw()
	# 阶段切换音（仅真实阶段变化时触发）
	if _phase_audio_cb.is_valid() and old_phase != new_phase:
		_phase_audio_cb.call(old_phase, new_phase)
	# 阶段名动画（reduce_motion 直跳）
	if not _reduce_motion and old_phase != new_phase:
		_play_phase_anim()


## 回合编号单独更新（turn 递增——phase 可能不变）。
func apply_turn(turn: int) -> void:
	if turn == _turn:
		return
	_turn = turn
	turn_label.text = "第 %d 回合" % turn


## 获取当前阶段（测试断言用）。
func get_phase() -> int:
	return _phase


## 获取进度条 7 格位置指示状态（测试断言用——QA 缺口 #8）。[br]
## [b]返回[/b]: Array[int]——每格状态（0=未来暗灰 / 1=已过淡青 / 2=当前高亮）。
func get_step_states() -> Array[int]:
	var states: Array[int] = []
	for i: int in range(PHASE_STEP_COUNT):
		if i < _phase:
			states.append(1)
		elif i == _phase:
			states.append(2)
		else:
			states.append(0)
	return states


## 设置初始阶段（引导进入——无动画，直接落定渲染态）。
func set_initial_phase(phase: int, turn: int) -> void:
	_phase = phase
	_turn = turn
	_apply_texts()
	_progress_rect.queue_redraw()


## === 内部 ====================================================================

## 阶段名 + 回合文本落定（数据驱动——PHASE_NAMES 查询）。
func _apply_texts() -> void:
	if _phase >= 0 and _phase < PHASE_NAMES.size():
		phase_label.text = PHASE_NAMES[_phase]
	else:
		phase_label.text = "—"
	turn_label.text = "第 %d 回合" % _turn


## 阶段名切换动画——放大 + 滑入（0.2s，峰值回落）。
func _play_phase_anim() -> void:
	_kill_anim_tween()
	# pivot_offset 依赖已布局 size——未布局（size 0）时以 0.5 比例作为兜底中心
	phase_label.pivot_offset = phase_label.size * 0.5
	phase_label.scale = Vector2(PHASE_SCALE_PEAK, PHASE_SCALE_PEAK)
	phase_label.position.x = 8.0  # 滑入起点（略右移）
	_anim_tween = create_tween()
	_anim_tween.set_parallel(true)
	_anim_tween.tween_property(phase_label, "scale", Vector2.ONE, PHASE_ANIM_SEC) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_anim_tween.tween_property(phase_label, "position:x", 0.0, PHASE_ANIM_SEC) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## 进度条自绘——7 格位置指示（当前高亮 / 已过淡青 / 未来暗灰）。
func _draw_progress(rect: Control) -> void:
	if rect.size.x <= 0.0:
		return
	var gap: float = 3.0
	var cell_w: float = (rect.size.x - gap * (PHASE_STEP_COUNT - 1)) / PHASE_STEP_COUNT
	for i: int in range(PHASE_STEP_COUNT):
		var color: Color = STEP_PENDING_COLOR
		if i < _phase:
			color = STEP_DONE_COLOR
		elif i == _phase:
			color = STEP_ACTIVE_COLOR
		rect.draw_rect(Rect2(Vector2(i * (cell_w + gap), 0),
				Vector2(cell_w, rect.size.y)), color)


func _kill_anim_tween() -> void:
	if _anim_tween != null and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = null
