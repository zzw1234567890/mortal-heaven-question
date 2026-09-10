class_name NotificationToastArea
extends Control
## NotificationToastArea —— 中央顶部通知区域组件（hud Story 004）。
##
## [b]结构[/b]：VBoxContainer 动态堆叠容器——push 时实例化 Toast 子场景
## （滑入 0.2s），到期/关闭时播滑出动画后释放。[br]
## [br][b]Logic 内核[/b]：全部时长/容量/重要判定走 [NotificationStack]
## （时间注入模式 G1 裁决——本组件 Timer 每 tick 调用同一 [code]advance(delta)[/code]
## 入口，被移除条目播滑出动画）。[br]
## [br][b]通知请求接口[/b]（G7 裁决——本 story 实现）：暴露公共方法
## [method request_notification] + 信号 [signal notification_requested]——
## HUD 侧经方法转发；各系统经此请求显示，HUD 不主动轮询（信号按 ADR-0007
## 归类为 Cat 2b 动作通知，供未来系统连接）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2.1）：通知队列是瞬态交互状态（story ADR
## 摘要明示「可存于 HUD 组件本地，不写回 GSM」）——[member _stack] 为 UI 本地
## 合法持有的瞬态队列；[code]_last_*[/code]/[code]_toast_*[/code] 前缀成员均为
## 瞬态交互状态（§2.1 三分类，见各成员注释）。[br]
## [br][b]零轮询边界[/b]：无 [code]_process()[/code]——Timer 驱动的时间推进是
## 内核 [code]advance[/code] 的注入源（到期判定属 Logic 而非游戏状态读取）；
## Tween 动画属输入驱动的纯视觉变换豁免（ADR-0031 §3）。[br]
## [br][b]mouse_filter[/b]（story Engine Notes）：通知可点击关闭——本区域根
## IGNORE 透传（无通知时不拦截下层点击），Toast 子场景 STOP 使 gui_input 可达。
##
## [br]来源: ADR-0031、design/gdd/hud-system.md §4、design/ux/hud.md「元素 12」、
## design/ux/interaction-patterns.md「通知堆叠」、hud Story 004（2026-09-10
## QL-STORY-READY G1-G8 裁决）。

## 通知显示请求信号（G7 裁决）。[br]
## 载荷 [code](type: String, text: String)[/code]——各系统经 HUD 侧连接请求
## 显示（ADR-0007 Cat 2b 动作通知：请求本身不携带游戏状态变更——通知只读展示）。
signal notification_requested(type: String, text: String)

## === Visual 常量（数据驱动）===================================================

## 通知文本颜色映射（类型映射 color 标识 → 美术圣经 §4.1 主色调色板 +
## design/ux/hud.md 元素 12 视觉规范）：[br]
## green=松石青 #4A9494（获得/正向——修为运转语义复用）、gold=琉璃金 #C8A84E（稀有/
## 灵石）、purple=烟灰紫 #6E6878（修为变更——烟灰阶紫）、red=朱砂红 #C23B3B
## （战斗事件攻/错误——生命语义）、blue=松石青 #4A9494（战斗事件守——松石青复用，
## 界定交互模式库「朱砂红/松石青」双编码）、white=淡墨 #6B675E（系统提示——中性）。
const TEXT_COLORS: Dictionary = {
	"green": Color("#4A9494"),
	"gold": Color("#C8A84E"),
	"purple": Color("#6E6878"),
	"red": Color("#C23B3B"),
	"blue": Color("#4A9494"),
	"white": Color("#6B675E"),
}

## 滑入/滑出动画时长——0.2s（GDD §视觉/音频需求表「通知弹出/消失 0.2s」+
## story Guardrail）。
const SLIDE_DURATION: float = 0.2
## 时间推进 Timer 间隔（秒）——每 0.1s 调 advance(0.1)（到期判定精度 0.1s，
## 远小于最短通知 2s 的展示时长，帧预算友好）。
const TICK_INTERVAL: float = 0.1
## error 类型 blink 闪烁全周期（先例 realm_bar FALLEN_FLICKER_PERIOD 风格）。
const BLINK_PERIOD: float = 0.8

## === 依赖注入 ==================================================================

## Logic 内核队列实例（测试注入点——集成测试传独立实例断言 get_active；
## null 时 _ready 自建）。瞬态交互状态（ADR-0031 §2.1）——UI 本地合法持有，
## 不写回 GSM（story ADR 摘要明示）。
var _stack: NotificationStack = null

## === 瞬态交互状态（ADR-0031 §2.1——不进存档，刷新即弃）=========================

## 动画开关——测试注入点 + reduce-motion 预留接线点（TD-008 同源——设置系统
## 入库后由此开关接入跳过/弱化；先例 lingshi_deck_bar.animate）。
var animate: bool = true

## id → Toast 面板节点映射（渲染同步用——advance 移除/点击关闭时定位节点）。
var _toast_nodes: Dictionary = {}
## 滑出中待释放节点列表（Tween 完成回调延迟释放，_exit_tree 时一并清理）。
var _toast_tweens: Dictionary = {}
## 时间推进 Timer（本组件生命周期内创建/销毁）。
var _tick_timer: Timer = null

## === 节点引用 ==================================================================

@onready var _stack_container: VBoxContainer = $StackContainer

## === 生命周期 ==================================================================

func _ready() -> void:
	# 纯展示区域根节点 IGNORE 透传（G8 裁决透传先例）——无通知时不拦截下层点击；
	# Toast 子场景自身 STOP 使点击关闭可达。
	mouse_filter = MOUSE_FILTER_IGNORE
	if _stack == null:
		_stack = NotificationStack.new()
	_start_tick_timer()

func _exit_tree() -> void:
	if _tick_timer != null:
		_tick_timer.stop()
		_tick_timer = null
	# 清理全部 Tween（滑出/blink）——_exit_tree Tween 清理先例 realm_bar。
	for tween: Tween in _toast_tweens.values():
		if tween != null and tween.is_valid():
			tween.kill()
	_toast_tweens.clear()

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

## === Toast 渲染 ===============================================================

## 为新通知生成 Toast 面板节点（纯代码构建——先例：HUD.tscn 区域容器模式，
## Toast 为短生命周期动态节点，不建独立 tscn 子场景减少文件数）。
func _spawn_toast(id: int) -> void:
	var entry: Dictionary = _find_entry(id)
	if entry.is_empty():
		return
	var toast: PanelContainer = PanelContainer.new()
	toast.name = "Toast%d" % id
	toast.mouse_filter = MOUSE_FILTER_STOP
	toast.custom_minimum_size = Vector2(360, 32)
	var label: Label = Label.new()
	label.text = str(entry[&"text"])
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if label.label_settings == null:
		label.label_settings = LabelSettings.new()
		label.label_settings.font_size = 13
	# 颜色 String→Color 映射在 UI 层（G3 裁决——内核不返回 Color）。
	label.label_settings.font_color = TEXT_COLORS.get(
			str(entry[&"color"]), TEXT_COLORS["white"])
	toast.add_child(label)
	toast.gui_input.connect(_on_toast_gui_input.bind(id))
	_stack_container.add_child(toast)
	_toast_nodes[id] = toast
	_play_slide_in(toast)
	if bool(entry[&"blink"]):
		_start_blink(id, toast)

## 从内核队列查找条目（get_active 只读快照遍历）。
func _find_entry(id: int) -> Dictionary:
	for entry: Dictionary in _stack.get_active():
		if int(entry[&"id"]) == id:
			return entry
	return {}

## 点击关闭（AC-4）——mouse_filter STOP + gui_input（story Engine Notes：
## Control 内建输入处理，无焦点导航需求）。
func _on_toast_gui_input(event: InputEvent, id: int) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if _stack.dismiss(id):
			_play_slide_out(id)

## === 动画（Tween——输入驱动的纯视觉变换，零轮询豁免）===========================

## 滑入：从上方 -32px 落位 + 淡入，0.2s（GDD 视觉表「通知弹出 0.2s」——AC-5
## 手动验证项，代码路径实现）。
func _play_slide_in(toast: PanelContainer) -> void:
	if not animate or not is_inside_tree():
		return
	var target_y: float = toast.position.y
	toast.position.y = target_y - 32.0
	toast.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(toast, "position:y", target_y,
			SLIDE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(toast, "modulate:a", 1.0,
			SLIDE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## 滑出：向上滑出 + 淡出 0.2s，完成后释放节点（GDD 视觉表「通知消失 0.2s」+
## story Guardrail）。VBoxContainer 堆叠重排由引擎布局自动完成（后续 Toast
## 上移填补空位——AC-5 堆叠重排无重叠）。
func _play_slide_out(id: int) -> void:
	var toast: PanelContainer = _toast_nodes.get(id, null)
	if toast == null or not is_instance_valid(toast):
		return
	_toast_nodes.erase(id)
	_stop_blink(id)
	if not animate or not is_inside_tree():
		toast.queue_free()
		return
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(toast, "position:y",
			toast.position.y - 32.0,
			SLIDE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(toast, "modulate:a", 0.0,
			SLIDE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(toast.queue_free)
	_toast_tweens[id] = tween

## error 类型 blink 闪烁：0.8s 周期循环（透明度闪烁——GDD §4「红色闪烁」）。
## [b]reduce-motion 技债注记[/b]（TD-008 同源）：animate=false 时不建循环
## Tween，静态呈现。
func _start_blink(id: int, toast: PanelContainer) -> void:
	if not animate or not is_inside_tree():
		return
	var tween: Tween = create_tween().set_loops()
	tween.tween_property(toast, "modulate:a", 0.35,
			BLINK_PERIOD * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(toast, "modulate:a", 1.0,
			BLINK_PERIOD * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_toast_tweens[id] = tween

## 停止指定 Toast 的循环动画（blink——滑出前调用避免 Tween 泄漏到已隐藏节点）。
func _stop_blink(id: int) -> void:
	var tween: Tween = _toast_tweens.get(id, null)
	if tween != null and tween.is_valid():
		tween.kill()
	_toast_tweens.erase(id)
