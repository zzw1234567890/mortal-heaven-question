class_name NotificationToastArea
extends Control
## NotificationToastArea —— 中央顶部通知区域组件（hud Story 004）。[br]
## [br][b]结构[/b]：VBoxContainer 动态堆叠容器——push 时生成 Toast（双层：外层
## holder 占容器布局槽位 + 内层 SlidePanel 为动画目标，滑入 0.2s），
## 到期/关闭/被挤出时播滑出动画后释放（挤出经 UI 对账同步——见
## [method _reconcile_toast_nodes]）。[br]
## [br][b]Logic 内核[/b]：全部时长/容量/重要判定走 [NotificationStack]
## （时间注入模式 G1 裁决——本组件 Timer 每 tick 调用同一 [code]advance(delta)[/code]
## 入口，被移除条目播滑出动画）。[br]
## [br][b]通知请求接口[/b]（G7 裁决——本 story 实现）：暴露公共方法
## [method request_notification] + 信号 [signal notification_requested]——
## HUD 侧经方法转发；各系统经此请求显示，HUD 不主动轮询（信号按 ADR-0007
## 归类为 Cat 2b 动作通知，供未来系统连接）。[br]
## [br][b]三件外援[/b]（本组件超 300 行软上限后按职责拆出，本类只留接线与门面）：[br]
##   · [NotificationStack]（先于本组件存在）——队列与时间推进的 Logic 内核；[br]
##   · [NotificationToastRender]——Toast 长什么样、占多高、文字什么颜色（版式为纯计算）；[br]
##   · [NotificationToastAnim]——滑入/滑出/blink 三条 Tween 与键空间簿记。[br]
## 拆因：三者都是「照本念」的纯件（无宿主上下文 / 只吃入参），留在组件里只会让
## 「队列接线」与「版式数字」混在一个文件里。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2.1）：通知队列是瞬态交互状态（story ADR
## 摘要明示「可存于 HUD 组件本地，不写回 GSM」）——[member _stack] 为 UI 本地
## 合法持有的瞬态队列；[code]_toast_*[/code] 前缀成员为瞬态交互状态。[br]
## [br][b]零轮询边界[/b]：无 [code]_process()[/code]——Timer 驱动的时间推进是
## 内核 [code]advance[/code] 的注入源（到期判定属 Logic 而非游戏状态读取）；
## Tween 动画属输入驱动的纯视觉变换豁免（ADR-0031 §3，落在 [NotificationToastAnim]）。[br]
## [br][b]mouse_filter[/b]（story Engine Notes）：通知可点击关闭——本区域根
## IGNORE 透传（无通知时不拦截下层点击），内层 SlidePanel STOP 使 gui_input 可达。[br]
## [br][b]常量在本类留同名转发[/b]：既有用例按 [code]AreaScript.TOAST_*[/code] 读它们，
## 转发后取法不变——[NotificationToastRender] 是定义的唯一出处，本类只转述
## （先例 [code]main_menu.gd[/code] 转发 [code]MainMenuTexts[/code] 的词条）。[br]
##
## [br]来源: ADR-0031、design/gdd/hud-system.md §4、design/ux/hud.md「元素 12」、
## design/ux/interaction-patterns.md「通知堆叠」、hud Story 004（2026-09-10
## QL-STORY-READY G1-G8 裁决）。

## 通知显示请求信号（G7 裁决）。[br]
## 载荷 [code](type: String, text: String)[/code]——各系统经 HUD 侧连接请求
## 显示（ADR-0007 Cat 2b 动作通知：请求本身不携带游戏状态变更——通知只读展示）。
signal notification_requested(type: String, text: String)

## === 拆出的两件外援（定义出处——先于下方转发常量声明，GDScript 常量按书写序解析）==

## Toast 渲染与版式（长什么样、占多高、文字什么颜色）。
const RenderScript := preload("res://src/ui/hud/notification_toast_render.gd")
## Tween 动效与生命周期账本（滑入/滑出/blink）。
const AnimScript := preload("res://src/ui/hud/notification_toast_anim.gd")

## === 版式/视觉常量（定义见 [NotificationToastRender]——此处转发保取法不变）=======

## 通知文本颜色映射（color 标识 → 美术圣经 §4.1 调色板）。
const TEXT_COLORS: Dictionary = RenderScript.TEXT_COLORS
## Toast 最小宽度（通知区的设计宽——短提示不缩成一条）。
const TOAST_MIN_WIDTH: float = RenderScript.TOAST_MIN_WIDTH
## 单行 Toast 高度（与容器 offset 高度同源）。
const TOAST_LINE_HEIGHT: float = RenderScript.TOAST_LINE_HEIGHT
## 通知文本字号。
const TOAST_FONT_SIZE: int = RenderScript.TOAST_FONT_SIZE
## 文本左右留白（Toast 内的内边距——文字不贴面板边）。
const TOAST_PAD_H: float = RenderScript.TOAST_PAD_H
## 文本可用宽 = 最小宽度减两侧留白——超长文案在这里折行，不裁字。
const TOAST_TEXT_WIDTH: float = RenderScript.TOAST_TEXT_WIDTH
## 滑入/滑出动画时长（定义见 [NotificationToastAnim]）。
const SLIDE_DURATION: float = AnimScript.SLIDE_DURATION
## blink 闪烁全周期。
const BLINK_PERIOD: float = AnimScript.BLINK_PERIOD

## 时间推进 Timer 间隔（秒）——每 0.1s 调 advance(0.1)（到期判定精度 0.1s，
## 远小于最短通知 2s 的展示时长，帧预算友好）。归于本类：它描述的是「谁在推时间」，
## 不是「动画多长」。
const TICK_INTERVAL: float = 0.1

## === 依赖注入 ==================================================================

## Logic 内核队列实例（测试注入点——集成测试传独立实例断言 get_active；
## null 时 _ready 自建）。瞬态交互状态（ADR-0031 §2.1）——UI 本地合法持有，
## 不写回 GSM（story ADR 摘要明示）。
var _stack: NotificationStack = null

## === 瞬态交互状态（ADR-0031 §2.1——不进存档，刷新即弃）=========================

## 动画开关——测试注入点 + reduce-motion 预留接线点（TD-008 同源——设置系统
## 入库后由此开关接入跳过/弱化；先例 lingshi_deck_bar.animate）。
var animate: bool = true

## id → Toast holder 节点映射（渲染同步用——advance 移除/点击关闭/对账挤出时
## 定位节点）。
var _toast_nodes: Dictionary = {}
## 时间推进 Timer（本组件生命周期内创建/销毁）。
var _tick_timer: Timer = null
## Tween 账本（滑入/滑出/blink——键空间回收的簿记在件内，见 [NotificationToastAnim]）。
var _anim: RefCounted = null

## === 节点引用 ==================================================================

@onready var _stack_container: VBoxContainer = $StackContainer

## === 生命周期 ==================================================================

func _ready() -> void:
	# 纯展示区域根节点 IGNORE 透传（G8 裁决透传先例）——无通知时不拦截下层点击；
	# 内层 SlidePanel STOP 使点击关闭可达。
	mouse_filter = MOUSE_FILTER_IGNORE
	if _stack == null:
		_stack = NotificationStack.new()
	_anim = AnimScript.new(self)
	_start_tick_timer()

func _exit_tree() -> void:
	if _tick_timer != null:
		_tick_timer.stop()
		_tick_timer = null
	# 清理全部 Tween（滑出/blink）——_exit_tree Tween 清理先例 realm_bar。
	if _anim != null:
		_anim.stop_all()

## === 通知请求接口（G7 裁决——本 story 实现）====================================

## 请求显示一条通知（公共入口——HUD 侧转发，各系统经此请求）。[br]
## [br][param type]: 通知类型（未知类型由内核安全默认处理 + push_warning）。[br]
## [param text]: 通知文本。[br]
## [br][b]返回[/b]：通知 id（内核 push 返回值——0 表示被容量规则拒绝；UI 层
## 0 值不渲染 Toast）。[br]
## [br][b]零状态所有权[/b]：通知只读展示——请求不携带游戏状态变更（story
## Forbidden：玩家点击仅关闭通知本身）。
func request_notification(type: String, text: String) -> int:
	var id: int = _stack.push(type, text)
	if id != 0:
		_spawn_toast(id)
		notification_requested.emit(type, text)
	return id

## === 时间注入（G1 裁决——Timer 驱动调内核统一入口）=============================

## 启动时间推进 Timer（0.1s 间隔调 advance——到期判定在内核，UI 只消费
## 被移除条目播滑出动画）。
func _start_tick_timer() -> void:
	_tick_timer = Timer.new()
	_tick_timer.wait_time = TICK_INTERVAL
	_tick_timer.timeout.connect(_on_tick)
	add_child(_tick_timer)
	_tick_timer.start()

func _on_tick() -> void:
	var removed: Array = _stack.advance(TICK_INTERVAL)
	for entry: Dictionary in removed:
		_play_slide_out(int(entry[&"id"]))
	# B-1 修复：UI 侧对账——内核 push 容量挤出对 advance 返回值不可见（挤出条目
	# 不经到期移除路径），UI 有节点但内核无条目的差集即被挤出 Toast，逐个滑出
	# 释放（HUD persistent 跨场景常驻——不对账则泄漏累积，AC-hud-009）。
	_reconcile_toast_nodes()

## 对账：比对 [member _toast_nodes] 键集与内核 [code]get_active()[/code] 的 id 集，
## 对差集（UI 有节点但内核无条目）逐个播滑出（挤出同步——[method _play_slide_out]
## 内部 erase [member _toast_nodes]，故遍历前复制键集避免遍历中修改）。
func _reconcile_toast_nodes() -> void:
	var active_ids: Array = []
	for entry: Dictionary in _stack.get_active():
		active_ids.append(int(entry[&"id"]))
	var stale_ids: Array = []
	for id: int in _toast_nodes.keys():
		if not active_ids.has(id):
			stale_ids.append(id)
	for id: int in stale_ids:
		_play_slide_out(id)

## === Toast 渲染 ===============================================================

## 为新通知生成 Toast 节点（纯代码构建——先例：HUD.tscn 区域容器模式，
## Toast 为短生命周期动态节点，不建独立 tscn 子场景减少文件数）。[br]
## [b]双层结构[/b]（B-2 修复）：外层 holder（Control，命名 "Toast%d"）进
## StackContainer 接受容器布局（VBox 只管理直接子节点——holder 的槽位/拉伸；
## holder 为普通 Control 而非容器，确保内层 position 不被容器布局覆写），
## 高度由 [member custom_minimum_size] 保持堆叠高度；内层 SlidePanel（Panel，
## FULL_RECT 锚跟随 holder 尺寸）为动画目标——滑入/滑出对其做
## [code]position.y + modulate.a[/code]，彻底消除对容器布局槽位读数的依赖
## （add_child 同帧读布局结果是 OVERLAP 缺陷根因）。点击关闭绑在内层
## STOP 节点上（gui_input 可达）。[br]
## [br][b]面板构建交给 [NotificationToastRender][/b]：颜色映射与版式数字都在那边，
## 本方法只管「挂哪、叫什么名字、存进哪个映射」。
func _spawn_toast(id: int) -> void:
	var entry: Dictionary = _find_entry(id)
	if entry.is_empty():
		return
	var holder: Control = Control.new()
	holder.name = "Toast%d" % id
	holder.mouse_filter = MOUSE_FILTER_IGNORE
	# 高度按文本行数给——通知文案长度不受控（来源是各系统的拼接串），
	# 固定 32px 单行会把后半句裁掉；短提示仍是单行高，观感不变。
	holder.custom_minimum_size = Vector2(TOAST_MIN_WIDTH,
			toast_height(str(entry[&"text"])))
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var panel: Panel = RenderScript.build_panel(entry, _on_toast_gui_input)
	holder.add_child(panel)
	_stack_container.add_child(holder)
	_toast_nodes[id] = holder
	_play_slide_in(id, panel)
	if bool(entry[&"blink"]):
		_start_blink(id, panel)

## Toast 应占高度——按文本在可用宽度下折成几行算（算法与常量见
## [method NotificationToastRender.height_for_text]）。[br]
## [br][b]为什么要算[/b]：内层 Label 开了 [code]autowrap[/code] 后高度由布局决定，
## 而外层 holder 的高度是 VBox 分配槽位的依据——holder 先按 32px 占位，文本折成
## 两行时第二行会画到下一个 Toast 上（堆叠重叠）。[br]
## [br][param p_text] 通知文本。[br]
## [br][b]返回[/b]：高度（至少一行）。
func toast_height(p_text: String) -> float:
	return RenderScript.height_for_text(p_text, _stack_container.get_theme_font(&"font"))

## 从内核队列查找条目（get_active 只读快照遍历）。
func _find_entry(id: int) -> Dictionary:
	for entry: Dictionary in _stack.get_active():
		if int(entry[&"id"]) == id:
			return entry
	return {}

## 点击关闭（AC-4）——内层 SlidePanel mouse_filter STOP + gui_input（story Engine
## Notes：Control 内建输入处理，无焦点导航需求）。dismiss 返回 false（条目已被
## 内核挤出/移除）时点击不播动画——挤出节点由对账路径在下一 tick 统一滑出。
func _on_toast_gui_input(event: InputEvent, id: int) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if _stack.dismiss(id):
			_play_slide_out(id)

## === 动画转发（实现见 [NotificationToastAnim]）=================================

## 滑入（[code]animate=false[/code] 时件内直接返回，不动面板）。
func _play_slide_in(id: int, panel: Panel) -> void:
	_anim.slide_in(id, panel, animate)

## 滑出 + 释放 holder（[code]animate=false[/code] 时件内走 queue_free 快路径）。
func _play_slide_out(id: int) -> void:
	var holder: Control = _toast_nodes.get(id, null)
	if holder == null or not is_instance_valid(holder):
		return
	_toast_nodes.erase(id)
	_anim.stop(id)
	_anim.slide_out(id, holder, animate)

## error 类型 blink 闪烁（0.8s 周期循环——GDD §4「红色闪烁」）。
func _start_blink(id: int, panel: Panel) -> void:
	_anim.start_blink(id, panel, animate)

## 停止指定 Toast 的当前 Tween（滑入/blink——滑出前调用避免 Tween 写到已隐藏节点，
## 同时腾出键位给滑出 Tween）。
func _stop_blink(id: int) -> void:
	_anim.stop(id)
