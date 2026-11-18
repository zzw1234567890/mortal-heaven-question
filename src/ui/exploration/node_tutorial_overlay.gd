class_name NodeTutorialOverlay
extends Control
## NodeTutorialOverlay —— 节点图教程覆盖（exploration-ui Story S17-005，B10）。
##
## [b]职责[/b]：新档首次进入第一张地图时显示 3 步教程提示（看路径→看AP→
## 点击移动），任意点击/Enter 跳过；第二次进入不再显示。[br]
## [br][b]已完成标记[/b]（story AC-8 + UX 规范 Data Requirements）：写入走
## [b]EventSystem.set_flag()[/b]（control-manifest：story_flags 的唯一运行时
## 写入者——UI 不直调 GSM 第二层），读取走 [code]EventSystem.get_flag()[/code]
## （只读无限制）。读写经注入 Callable（测试免 EventSystem 依赖）。[br]
## [br][b]跳过语义锁定[/b]（QA 计划 17-1 边缘 #3）：步骤经 [member _step_timer]
## 自动推进；[b]任意点击/Enter 立即跳过整个教程[/b]，[signal tutorial_skipped]
## 载荷 [code]step_reached[/code] = 跳过时所在步（1/2/3）；走完 3 步自然完成
## 也发射（step_reached=3——完整走完的语义等同跳过，标记写入一致）。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]——Timer 驱动步进（Logic 时间
## 推进注入源——notification_toast_area G1 先例）；点击经 [method _gui_input]，
## Enter 经焦点（[method on_map_entered] 时 grab_focus）。[br]
## [br][b]文案本地化豁免[/b]：STEP_TEXTS 为 UX OQ#6 占位文案，待 localization
## epic 落地后迁入词条表（与 node_move_interactor REASON_TEXTS 同源豁免口径）。
##
## 来源: story-005-node-move-interaction.md AC-8/B10 裁决、ADR-0003（story_flags
## 唯一写入者）、design/ux/exploration-ui.md States「教程覆盖（首次进入）」+
## Events Fired「tutorial_skipped {step_reached}」、ADR-0031 §2/§2.1。

## === 信号 ==================================================================

## 教程完成/跳过（UX Events Fired 表——analysis 用 Cat 2b 通知）。[br]
## [param step_reached]: 跳过/完成时所在步（1/2/3——QA 边缘 #3 载荷区分）。
signal tutorial_skipped(step_reached: int)

## === 常量（数据驱动）=======================================================

## 教程步数。
const TOTAL_STEPS: int = 3
## 每步自动推进时长（秒）。
const STEP_DURATION: float = 4.0
## 覆盖层半透明底色（节点图可见性保留——非全屏遮断）。
const DIM_COLOR: Color = Color(0.0, 0.0, 0.0, 0.35)
## 提示文字颜色（暖白——UX 可访问性对比度基准）。
const TEXT_COLOR: Color = Color(0.96, 0.94, 0.88)
## 提示字号。
const FONT_SIZE: int = 18
## 提示条左右留白（像素）——文字宽度按视口宽减两侧留白算，窄屏上自动折行。
const TEXT_MARGIN: float = 96.0
## 提示条上边距（相对视口底——贴底但不压住节点图的底边）。
const TEXT_BOTTOM_OFFSET: float = -112.0
## 单行提示条高度（[constant FONT_SIZE] 的行高 + 上下呼吸）。
const TEXT_LINE_HEIGHT: float = 40.0

## 3 步文案（UX OQ#6 占位——writer 定稿后替换本表，结构不变）。
const STEP_TEXTS: PackedStringArray = [
	"观察节点间的路径连线，规划前往 Boss 的路线",
	"留意右上角行动力（AP），每次移动消耗 1 点",
	"点击发光的可达节点即可移动",
]

## GSM narrative story_flags 的教程完成标记键（经 EventSystem 读写）。
const TUTORIAL_FLAG: String = "exploration_tutorial_done"

## === 依赖注入（测试可替换）=================================================

## 已完成标记读取 Callable（无参 → bool）。默认经 EventSystem.get_flag。
var read_flag_cb: Callable = Callable()
## 已完成标记写入 Callable（bool 参数）。默认经 EventSystem.set_flag。
var write_flag_cb: Callable = Callable()

## === 瞬态交互状态（ADR-0031 §2.1）=========================================

## 当前教程步（0 = 未开始，1-3 = 进行中步号）。
var _step: int = 0
## 步进 Timer（单实例复用——每步 start() 重启，免每步节点分配）。
var _step_timer: Timer = null
## 提示 Label。
var _label: Label = null


func _init() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Enter 跳过需要焦点（审查 H7——无 focus_mode 时键盘事件永不到达本控件）
	focus_mode = FOCUS_ALL
	_label = Label.new()
	_label.name = "TutorialLabel"
	# 提示贴底居中：原先锚在正中，直接盖在节点图上（玩家反馈「字挡着、显示不全」）。
	# 宽度按视口宽算（左右各留 [constant TEXT_MARGIN]），而不是量一段够长的固定
	# 像素——文案是本表的占位串，将来换词变长时固定宽度会把它裁掉。
	# [b]不能用 PRESET_CENTER_BOTTOM[/b]：那个预设把左右锚都定在 0.5，两个 offset
	# 只能给出「2×留白」的宽度（实测 192px），文字照样被裁。
	_label.anchor_left = 0.0
	_label.anchor_right = 1.0
	_label.anchor_top = 1.0
	_label.anchor_bottom = 1.0
	_label.offset_left = TEXT_MARGIN
	_label.offset_right = -TEXT_MARGIN
	_label.offset_top = TEXT_BOTTOM_OFFSET - TEXT_LINE_HEIGHT
	_label.offset_bottom = TEXT_BOTTOM_OFFSET
	# 折行后向上长（底边不动）——提示条永远贴在节点图下沿，不会往下顶出屏幕。
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 长句折行：文案变长时先折行（Label 的最小高度随之长高，提示条向上撑开），
	# 而不是把后半句裁掉。
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", TEXT_COLOR)
	add_child(_label)
	_step_timer = Timer.new()
	_step_timer.wait_time = STEP_DURATION
	_step_timer.one_shot = true
	_step_timer.timeout.connect(_on_step_timeout)
	add_child(_step_timer)
	visible = false


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), DIM_COLOR)


## 首次进入地图入口（宿主 _on_map_entered 编排调用）——已完成标记为真时
## 不显示；否则从第 1 步开始（并取得焦点以接收 Enter 跳过）。
func on_map_entered() -> void:
	if _read_done_flag():
		return
	_start_step(1)


## 任意输入跳过（AC-8——点击/Enter）。[br]
## [param step_reached]: 跳过时所在步（调用方传入当前步；载荷区分 1 vs 3）。
func skip(step_reached: int) -> void:
	if _step == 0:
		return
	_finish(step_reached)


## 任意输入跳过（AC-8——左键点击 / Enter）。[br]
## [b]滚轮不算点击[/b]（审查 LOW）：仅响应 [constant MOUSE_BUTTON_LEFT]——
## 滚动阅读类输入不应关闭教程；Enter 同时识别主键盘与小键盘（与
## [NodeMoveInteractor] 的确认键同口径）。
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		skip(_step)
		accept_event()
	elif event is InputEventKey and event.pressed \
			and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		skip(_step)
		accept_event()


## === 内部 ==================================================================

## 开始指定步——显示文案 + 启动步进 Timer。
func _start_step(step: int) -> void:
	_step = step
	visible = true
	if is_inside_tree() and not has_focus():
		grab_focus()
	_label.text = "%d/%d  %s" % [step, TOTAL_STEPS, STEP_TEXTS[step - 1]]
	_step_timer.start()

## 步进 Timer 到期——推进下一步或完成。
func _on_step_timeout() -> void:
	if _step >= TOTAL_STEPS:
		_finish(TOTAL_STEPS)
		return
	_start_step(_step + 1)

## 完成教程——写标记 + 发信号 + 隐藏。
func _finish(step_reached: int) -> void:
	_step_timer.stop()
	_step = 0
	visible = false
	if has_focus():
		release_focus()
	_write_done_flag()
	tutorial_skipped.emit(step_reached)

## 读取已完成标记（注入优先 → EventSystem.get_flag 只读 → false）。
func _read_done_flag() -> bool:
	if read_flag_cb.is_valid():
		return bool(read_flag_cb.call())
	var es: Node = get_node_or_null("/root/EventSystem")
	if es == null or not es.has_method(&"get_flag"):
		return false
	return bool(es.get_flag(TUTORIAL_FLAG, false))

## 写入已完成标记（注入优先 → EventSystem.set_flag 唯一写入入口，ADR-0003）。[br]
## [b]写入失败上报[/b]：EventSystem 缺失时 push_warning（否则教程每次进入重复
## 显示且无任何诊断线索——审查 M11）。
func _write_done_flag() -> void:
	if write_flag_cb.is_valid():
		write_flag_cb.call(true)
		return
	var es: Node = get_node_or_null("/root/EventSystem")
	if es != null and es.has_method(&"set_flag"):
		es.set_flag(TUTORIAL_FLAG, true)
		return
	push_warning("NodeTutorialOverlay: EventSystem 不可用——教程完成标记未写入")
