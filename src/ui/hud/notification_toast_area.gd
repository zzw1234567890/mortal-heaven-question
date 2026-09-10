class_name NotificationToastArea
extends Control
## NotificationToastArea —— 中央顶部通知区域组件（hud Story 004）。
##
## [b]结构[/b]：VBoxContainer 动态堆叠容器——push 时生成 Toast（双层：外层
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
## [br][b]零状态所有权[/b]（ADR-0031 §2.1）：通知队列是瞬态交互状态（story ADR
## 摘要明示「可存于 HUD 组件本地，不写回 GSM」）——[member _stack] 为 UI 本地
## 合法持有的瞬态队列；[code]_last_*[/code]/[code]_toast_*[/code] 前缀成员均为
## 瞬态交互状态（§2.1 三分类，见各成员注释）。[br]
## [br][b]零轮询边界[/b]：无 [code]_process()[/code]——Timer 驱动的时间推进是
## 内核 [code]advance[/code] 的注入源（到期判定属 Logic 而非游戏状态读取）；
## Tween 动画属输入驱动的纯视觉变换豁免（ADR-0031 §3）。[br]
## [br][b]mouse_filter[/b]（story Engine Notes）：通知可点击关闭——本区域根
## IGNORE 透传（无通知时不拦截下层点击），内层 SlidePanel STOP 使 gui_input 可达。
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

## id → Toast holder 节点映射（渲染同步用——advance 移除/点击关闭/对账挤出时
## 定位节点）。
var _toast_nodes: Dictionary = {}
## id → 活跃 Tween（滑入/blink/滑出——一个 id 同时至多一个：后来者经
## [method _stop_blink] kill 并 erase 前任；各类 Tween 均在 [code]finished[/code]
## 回调 erase，键空间随 Toast 生命周期回收不泄漏——S-1 语义梳理）。
var _toast_tweens: Dictionary = {}
## 时间推进 Timer（本组件生命周期内创建/销毁）。
var _tick_timer: Timer = null

## === 节点引用 ==================================================================

@onready var _stack_container: VBoxContainer = $StackContainer

## === 生命周期 ==================================================================

func _ready() -> void:
	# 纯展示区域根节点 IGNORE 透传（G8 裁决透传先例）——无通知时不拦截下层点击；
	# 内层 SlidePanel STOP 使点击关闭可达。
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
## STOP 节点上（gui_input 可达）。
func _spawn_toast(id: int) -> void:
	var entry: Dictionary = _find_entry(id)
	if entry.is_empty():
		return
	var holder: Control = Control.new()
	holder.name = "Toast%d" % id
	holder.mouse_filter = MOUSE_FILTER_IGNORE
	holder.custom_minimum_size = Vector2(360, 32)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var panel: Panel = _build_toast_panel(entry)
	holder.add_child(panel)
	_stack_container.add_child(holder)
	_toast_nodes[id] = holder
	_play_slide_in(id, panel)
	if bool(entry[&"blink"]):
		_start_blink(id, panel)

## 构建内层 Toast 面板（文本 + 颜色映射 + 点击关闭绑定——B-2 双层结构拆出，
## 保持 _spawn_toast 紧凑）。Panel 与 Label 均 FULL_RECT 锚——跟随 holder
## 尺寸（holder 为普通 Control，无容器布局覆写内层 position）。
func _build_toast_panel(entry: Dictionary) -> Panel:
	var panel: Panel = Panel.new()
	panel.name = "SlidePanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = MOUSE_FILTER_STOP
	var label: Label = Label.new()
	label.text = str(entry[&"text"])
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	if label.label_settings == null:
		label.label_settings = LabelSettings.new()
		label.label_settings.font_size = 13
	# 颜色 String→Color 映射在 UI 层（G3 裁决——内核不返回 Color）。
	label.label_settings.font_color = TEXT_COLORS.get(
			str(entry[&"color"]), TEXT_COLORS["white"])
	panel.add_child(label)
	panel.gui_input.connect(_on_toast_gui_input.bind(int(entry[&"id"])))
	return panel

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

## === 动画（Tween——输入驱动的纯视觉变换，零轮询豁免）===========================

## 滑入：内层 SlidePanel 从上方 -32px 落位 + 淡入，0.2s（GDD 视觉表「通知弹出
## 0.2s」——AC-5）。动画目标为内层 Panel（holder 为普通 Control——position 不受
## 容器布局管理，B-2 修复：不再读 add_child 同帧布局槽位，消除滑入目标过期导致的
## 堆叠重叠）。[code]from(-32)[/code] 显式起点。Tween 入 [member _toast_tweens][id]
## ——滑出/blink 接管键位时经 [method _stop_blink] kill（避免同写 position:y 冲突）。
func _play_slide_in(id: int, panel: Panel) -> void:
	if not animate or not is_inside_tree():
		return
	panel.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "position:y", 0.0,
			SLIDE_DURATION).from(-32.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0,
			SLIDE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func() -> void: _toast_tweens.erase(id))
	_toast_tweens[id] = tween

## 滑出：内层 SlidePanel 向上滑出 + 淡出 0.2s，完成后释放 holder 节点（GDD 视觉表
## 「通知消失 0.2s」+ story Guardrail）。VBoxContainer 堆叠重排由引擎布局自动完成
## （后续 Toast 上移填补空位——AC-5 堆叠重排无重叠）。[br]
## [b]Tween 生命周期[/b]（S-1 修复）：滑出 Tween 存入 [member _toast_tweens][id]，
## [code]finished[/code] 回调 erase——字典不随通知量增长持有已失效 Tween 引用；
## 一个 id 同时至多一个活跃 Tween（滑入/blink 由 [method _stop_blink] kill 腾位）。
func _play_slide_out(id: int) -> void:
	var holder: Control = _toast_nodes.get(id, null)
	if holder == null or not is_instance_valid(holder):
		return
	_toast_nodes.erase(id)
	_stop_blink(id)
	if not animate or not is_inside_tree():
		holder.queue_free()
		return
	var panel: Panel = holder.get_node_or_null("SlidePanel") as Panel
	if panel == null:
		holder.queue_free()
		return
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "position:y", -32.0,
			SLIDE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "modulate:a", 0.0,
			SLIDE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(holder.queue_free)
	# S-1：完成时 erase——滑出是该 id 最后一个 Tween，键空间被回收不泄漏。
	tween.finished.connect(func() -> void: _toast_tweens.erase(id))
	_toast_tweens[id] = tween

## error 类型 blink 闪烁：0.8s 周期循环（透明度闪烁——GDD §4「红色闪烁」）。
## [b]reduce-motion 技债注记[/b]（TD-008 同源）：animate=false 时不建循环
## Tween，静态呈现。
func _start_blink(id: int, panel: Panel) -> void:
	if not animate or not is_inside_tree():
		return
	# 滑入 Tween 仍在播时 kill——blink 与滑入同写 modulate.a 会冲突；blink 自身
	# 循环（0→0.35→1.0）覆盖淡入语义，视觉无损。
	_stop_blink(id)
	var tween: Tween = create_tween().set_loops()
	tween.tween_property(panel, "modulate:a", 0.35,
			BLINK_PERIOD * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "modulate:a", 1.0,
			BLINK_PERIOD * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_toast_tweens[id] = tween

## 停止指定 Toast 的当前 Tween（滑入/blink——滑出前调用避免 Tween 泄漏到已隐藏
## 节点，同时腾出 [member _toast_tweens] 键位给滑出 Tween——一个 id 同时至多一个）。
func _stop_blink(id: int) -> void:
	var tween: Tween = _toast_tweens.get(id, null)
	if tween != null and tween.is_valid():
		tween.kill()
	_toast_tweens.erase(id)
