extends RefCounted
## NotificationToastAnim —— Toast 的[b]Tween 动效与生命周期账本[/b]（从
## [code]notification_toast_area.gd[/code] 拆出）。[br]
## [br][b]职责[/b]：滑入 / 滑出 / blink 三条 Tween 的建立与回收，以及「一个 id 同时
## 至多一个活跃 Tween」这条不变量的簿记（[member _tweens]）。[br]
## [br][b]为什么单独一处[/b]：动效属输入驱动的纯视觉变换（ADR-0031 §3 零轮询豁免），
## 与「队列怎么排、Timer 怎么推、节点怎么对账」是两件事；且 Tween 的键空间回收
## 曾在 S-1 上出过泄漏，把它收进一个有名字的账本比散在组件里好审。[br]
## [br][b]为什么 animate 由调用方逐次传入而不是自己持一份[/b]：开关的唯一出处是组件
## 的 [code]animate[/code] 成员（既有用例就按 [code]area.animate = false[/code] 注入），
## 动效件再存一份就会出现「改了一处另一处没改」的两处开关。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：[member _tweens] 是瞬态交互状态的簿记，
## 不进存档；本件不读任何游戏状态。[br]
## [br]来源: design/gdd/hud-system.md §4 视觉/音频需求表、design/ux/hud.md 元素 12、
## ADR-0031 §2.1 §3、编码标准「单文件 ≤300 行」。

## 滑入 / 滑出动画时长——0.2s（GDD 视觉/音频需求表「通知弹出/消失 0.2s」+
## story Guardrail）。
const SLIDE_DURATION: float = 0.2
## 滑入/滑出的位移量（px）——从上方落位、向上滑出。
const SLIDE_OFFSET: float = 32.0
## error 类型 blink 闪烁全周期（先例 realm_bar FALLEN_FLICKER_PERIOD 风格）。
const BLINK_PERIOD: float = 0.8
## blink 谷值透明度（GDD §4「红色闪烁」——不闪到全透明，否则像在消失）。
const BLINK_DIM_ALPHA: float = 0.35

## 动效宿主（提供 [method Node.create_tween] 与 [method Node.is_inside_tree]）。
var _host: Node = null
## id → 活跃 Tween。一个 id 同时至多一个：后来者经 [method stop] kill 并 erase 前任；
## 各类 Tween 均在 [code]finished[/code] 回调 erase——键空间随 Toast 生命周期回收不泄漏
## （S-1 语义梳理）。
var _tweens: Dictionary = {}


func _init(p_host: Node) -> void:
	_host = p_host


## 当前活跃 Tween 数（诊断/用例用——正常应随 Toast 数收敛，不随通知量增长）。
func active_tween_count() -> int:
	return _tweens.size()


## 停掉指定 id 的当前 Tween（滑入/blink——滑出前调用避免 Tween 写到已释放节点，
## 同时腾出键位给滑出 Tween）。
func stop(p_id: int) -> void:
	var tween: Tween = _tweens.get(p_id, null)
	if tween != null and tween.is_valid():
		tween.kill()
	_tweens.erase(p_id)


## 清空全部 Tween（组件 [method Node._exit_tree] 调用——退出时不让 Tween 留在树外跑）。
func stop_all() -> void:
	for tween: Tween in _tweens.values():
		if tween != null and tween.is_valid():
			tween.kill()
	_tweens.clear()


## 滑入：内层 SlidePanel 从上方 [constant SLIDE_OFFSET] 落位 + 淡入。[br]
## 动画目标为内层 Panel（holder 为普通 Control——position 不受容器布局管理，
## B-2 修复：不再读 add_child 同帧布局槽位，消除滑入目标过期导致的堆叠重叠）。
func slide_in(p_id: int, p_panel: Panel, p_animate: bool) -> void:
	if not p_animate or not _can_tween():
		return
	p_panel.modulate.a = 0.0
	var tween: Tween = _host.create_tween()
	tween.set_parallel(true)
	tween.tween_property(p_panel, "position:y", 0.0, SLIDE_DURATION).from(-SLIDE_OFFSET) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(p_panel, "modulate:a", 1.0, SLIDE_DURATION) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func() -> void: _tweens.erase(p_id))
	_tweens[p_id] = tween


## 滑出：面板向上滑出 + 淡出，完成后释放 holder 节点（GDD「通知消失 0.2s」）。
## VBoxContainer 堆叠重排由引擎布局自动完成（后续 Toast 上移填补空位——AC-5 无重叠）。[br]
## [br][b]不播动画时[/b]（[code]animate=false[/code] 或不在树内）直接
## [method Node.queue_free]——调用方不必自己分支。[br]
## [br][b]名字 "SlidePanel" 找不到时[/b]也直接释放：面板不在，动画没有目标，
## 留着 holder 才是泄漏。
func slide_out(p_id: int, p_holder: Control, p_animate: bool) -> void:
	if not p_animate or not _can_tween():
		p_holder.queue_free()
		return
	var panel: Panel = p_holder.get_node_or_null("SlidePanel") as Panel
	if panel == null:
		p_holder.queue_free()
		return
	var tween: Tween = _host.create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "position:y", -SLIDE_OFFSET, SLIDE_DURATION) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "modulate:a", 0.0, SLIDE_DURATION) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(p_holder.queue_free)
	# S-1：完成时 erase——滑出是该 id 最后一个 Tween，键空间被回收不泄漏。
	tween.finished.connect(func() -> void: _tweens.erase(p_id))
	_tweens[p_id] = tween


## error 类型 blink 闪烁：循环透明度 1.0 → [constant BLINK_DIM_ALPHA] → 1.0。[br]
## [br][b]reduce-motion 技债注记[/b]（TD-008 同源）：[code]animate=false[/code] 时不建
## 循环 Tween，静态呈现。
func start_blink(p_id: int, p_panel: Panel, p_animate: bool) -> void:
	if not p_animate or not _can_tween():
		return
	# 滑入 Tween 仍在播时 kill——blink 与滑入同写 modulate.a 会冲突；blink 自身
	# 循环覆盖淡入语义，视觉无损。
	stop(p_id)
	var tween: Tween = _host.create_tween().set_loops()
	tween.tween_property(p_panel, "modulate:a", BLINK_DIM_ALPHA, BLINK_PERIOD * 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(p_panel, "modulate:a", 1.0, BLINK_PERIOD * 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tweens[p_id] = tween


## 能不能建 Tween——宿主在树内才有 [method Node.create_tween]（脱树建出来的是 null）。
func _can_tween() -> bool:
	return _host != null and _host.is_inside_tree()
