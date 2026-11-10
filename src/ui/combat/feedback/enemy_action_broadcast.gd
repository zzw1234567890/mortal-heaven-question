class_name EnemyActionBroadcast
extends Control
## EnemyActionBroadcast —— 敌方行动的逐条播报（combat-ui-interaction 002 表现层）。
##
## [b]职责[/b]：消费 [code]enemy_action_resolved[/code]，逐条打出战报，条间隔
## [member interval_ms]（默认 350ms，可注入）；播报期间持有 [code]ANIMATION[/code]
## 输入锁（source = [code]enemy_broadcast[/code]），队列播完（含末条停留）后释放；
## 文本同时经 [code]log_sink[/code] 追加战斗日志。[br]
## [br][b]与伤害飘字的分工（去重口径）[/b]：[code]character_damaged[/code] 是伤害
## 数值动画的唯一来源（落库后的实际增量）；本组件[b]只生成文字[/b]，不调飘字池、
## 不播阵亡动画、不写 HP——同一次伤害的数值动画只会播一次。[br]
## [br][b]批内去重[/b]：同一批中字段完全相同的载荷只播一次；新批重置，故下一回合
## 数值恰好相同的两次攻击不会被误吞。[br]
## [br][b]阵亡不重复出场[/b]：批内目标一旦 [code]is_kill[/code] 或已 0 HP，后续行动
## 不再显示其名字/伤害，改记「行动落空」。[br]
## [br][b]零轮询[/b]：一次性 [code]Timer[/code] 串队列；测试可注入调度器。[br]
##
## @experimental
## 来源: design/gdd/combat-ui-system.md §回合切换与敌方行动的可观测性、
## design/gdd/combat-system.md §公式、combat-ui-interaction 002。

## 文本/命名/去重键工具（纯函数）。
const TextScript := preload("res://src/ui/combat/feedback/enemy_action_text.gd")
## 单行背板视图（「怎么画」与「什么时候播」分离）。
const BannerScript := preload("res://src/ui/combat/feedback/enemy_action_banner.gd")
## 输入管理器脚本——取其 [code]LockType.ANIMATION[/code] 枚举（不裸写魔数）。
const InputManagerScript := preload("res://src/foundation/input_manager.gd")

## 条与条之间的默认间隔（毫秒）。
const DEFAULT_INTERVAL_MS: int = 350
## 播报输入锁的 source（与其他锁配对，不整栈清空）。
const LOCK_SOURCE: StringName = &"enemy_broadcast"

## 队列（载荷副本——播报是渲染快照，不持游戏状态）。
var _queue: Array = []
## 当前批次的已播文本 / 载荷键 / 阵亡目标（新批开始时清空）。
var _lines: Array[String] = []
var _batch_seen: Dictionary = {}
var _fallen: Dictionary = {}
## 播报间隔（毫秒，可注入；0 = 立即）。
var interval_ms: int = DEFAULT_INTERVAL_MS
## 是否处于一批播报中（含末条停留）/ 是否持播报输入锁（push-pop 配对）。
var _playing: bool = false
var _lock_held: bool = false
var _sources: Array = []  # 已连接的信号源（幂等）
## 名称解析闭包——func(character_id) -> String。
var _name_resolver: Callable = Callable()
## 日志追加闭包——func(line: String) -> void。
var _log_sink: Callable = Callable()
## 测试注入调度器——func(delay_ms: int, callback: Callable) -> void。
var _scheduler: Callable = Callable()
## 当前等待回调 / 一次性计时器 / 单行背板视图。
var _wait_cb: Callable = Callable()
var _timer: Timer = null
var _banner_view: Variant = null


func _init() -> void:
	_build()


## 构建背板视图与间隔计时器（_init 构建——不依赖场景树时序）。
func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_banner_view = BannerScript.new()
	_banner_view.name = "BroadcastBanner"
	add_child(_banner_view)
	_timer = Timer.new()
	_timer.name = "IntervalTimer"
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_on_timer_timeout)


## 注入信号源与渲染依赖（场景挂载侧调用）。[br]
## [param p_sources] 订阅 [code]enemy_action_resolved[/code] / [code]battle_ended[/code]
## 的信号源（通常是 CombatSystem；缺失对应信号时静默跳过）。[br]
## [param p_interval_ms] 条间间隔（默认 350ms）。[br]
## [param p_name_resolver] 角色显示名闭包（空 → 按 ID 段给可读兜底）。[br]
## [param p_log_sink] 战报追加闭包（空 → 只显示背板）。
func setup(p_sources: Array, p_interval_ms: int = DEFAULT_INTERVAL_MS,
		p_name_resolver: Callable = Callable(),
		p_log_sink: Callable = Callable()) -> void:
	set_interval_ms(p_interval_ms)
	_name_resolver = p_name_resolver
	_log_sink = p_log_sink
	for source: Node in p_sources:
		_connect_source(source)


## 设置条间间隔（毫秒；负值按 0）。[br]
## [b]注入点[/b]：测试与策划调参都走这里，播报组件内不存在第二份间隔数值。
func set_interval_ms(p_interval_ms: int) -> void:
	interval_ms = maxi(p_interval_ms, 0)


## 注入调度器（测试用）——签名 [code]func(delay_ms, callback)[/code]。
## 空闭包 = 生产路径（一次性 Timer）。
func set_scheduler(p_scheduler: Callable) -> void:
	_scheduler = p_scheduler


## 是否正在播报（含最后一条的停留间隔）。
func is_playing() -> bool:
	return _playing


## 当前批次的播报文本（副本——调用方改不到内部列表）。
func get_lines() -> Array[String]:
	return _lines.duplicate()


## 当前批次的播报条数。
func line_count() -> int:
	return _lines.size()


## 当前背板文本（测试断言用）。
func banner_text() -> String:
	return _banner_view.call(&"text") if _banner_view != null else ""


## === 信号入口 ================================================================

## [code]enemy_action_resolved[/code] 处理器。[br]
## [b]公开方法[/b]：信号缺失/测试直调都走同一条队列路径。
func on_enemy_action(action_data: Dictionary) -> void:
	if action_data.is_empty():
		return
	if not _playing:
		_begin_batch()
		_playing = true
		_hold_lock()
		# 延迟到本帧信号簇结束后再开播：AI 一次结算会连发多条，
		# 同步开播会让测试注入的即刻调度器把同一批拆成多批。
		_play_next.call_deferred()
	var key: String = TextScript.duplicate_key(action_data)
	if _batch_seen.has(key):
		return  # 批内完全相同的载荷只播一次
	_batch_seen[key] = true
	_queue.append(action_data.duplicate(true))


## [code]battle_ended[/code] 处理器——清队列、释放锁、收起背板（不把播报带进结算场景）。
func on_battle_ended(_result: int, _rewards: Dictionary) -> void:
	_reset()


func _exit_tree() -> void:
	_reset()


## === 队列播放 ================================================================

## 开始一批：清空批内状态与文本历史。
func _begin_batch() -> void:
	_batch_seen.clear()
	_fallen.clear()
	_lines.clear()


## 播下一条；队列空则结束本批（最后一条也已停留过）。
func _play_next() -> void:
	if not _playing:
		return
	if _queue.is_empty():
		_finish_batch()
		return
	var payload: Dictionary = _queue.pop_front()
	_show_line(payload)
	_wait_then(_on_wait_elapsed)


## 停留结束——还有下一条就继续，否则收尾。
func _on_wait_elapsed() -> void:
	if not _playing:
		return
	if _queue.is_empty():
		_finish_batch()
	else:
		_play_next()


## 显示一条战报（文本 + 日志；数值动画不在这里播）。
func _show_line(p_payload: Dictionary) -> void:
	var target_id: int = int(p_payload.get("target_id", -1))
	var fallen: bool = target_id >= 0 and _fallen.has(target_id)
	if not fallen and _already_dead_payload(p_payload):
		fallen = true
		_fallen[target_id] = true
	var text: String = TextScript.format_line(p_payload, _name_resolver, fallen)
	_lines.append(text)
	if _banner_view != null:
		_banner_view.call(&"show_line", text)
	if _log_sink.is_valid():
		_log_sink.call(text)
	if bool(p_payload.get("is_kill", false)) and target_id >= 0:
		_fallen[target_id] = true


## 结束一批——释放输入锁、收起背板（文本历史保留到下一批开始）。
func _finish_batch() -> void:
	_playing = false
	_queue.clear()
	_release_lock()
	if _banner_view != null:
		_banner_view.call(&"hide_banner")


## 兜底清场（战斗结束 / 场景退场）——不留下悬空计时器或输入锁。
func _reset() -> void:
	_playing = false
	_queue.clear()
	_wait_cb = Callable()
	if _timer != null and not _timer.is_stopped():
		_timer.stop()
	_release_lock()
	if _banner_view != null:
		_banner_view.call(&"hide_banner")


## 载荷是否描述「打在一个已死目标上」——[code]known[/code] 且 0 HP 且非本次击杀。
func _already_dead_payload(p_payload: Dictionary) -> bool:
	if not bool(p_payload.get("known", false)):
		return false
	if bool(p_payload.get("is_kill", false)):
		return false
	return int(p_payload.get("hp_after", 1)) <= 0


## === 间隔调度 ================================================================

## 等待一个间隔后执行回调——测试调度器优先，其次一次性 Timer。
func _wait_then(p_callback: Callable) -> void:
	_wait_cb = p_callback
	if _scheduler.is_valid():
		_scheduler.call(interval_ms, p_callback)
		return
	if interval_ms <= 0 or not is_inside_tree() or _timer == null:
		p_callback.call_deferred()
		return
	_timer.wait_time = float(interval_ms) / 1000.0
	_timer.start()


func _on_timer_timeout() -> void:
	var callback: Callable = _wait_cb
	_wait_cb = Callable()
	if callback.is_valid():
		callback.call()


## === 输入锁 ==================================================================

## 持锁——播报期间玩家输入仍被屏蔽（阶段守卫之外的第三层保险：
## 播报开始时阶段可能已回到我方，单靠阶段守卫拦不住）。
func _hold_lock() -> void:
	if _lock_held:
		return
	var manager: Node = _input_manager()
	if manager == null or not manager.has_method(&"push_lock"):
		return
	manager.call(&"push_lock", InputManagerScript.LockType.ANIMATION, LOCK_SOURCE)
	_lock_held = true


## 释放本组件推入的锁——只弹自己的 source，不动别的锁。[br]
## [br][b]先判 [code]has_lock[/code] 再 pop[/b]：本组件的锁会被外部清掉
## （[code]SceneManager[/code] 的 [code]tree_changed[/code] 清栈、
## [code]CombatSystem._clear_animation_lock[/code] 的按 source 清理），
## 此时 [member _lock_held] 仍为 true 而栈里已没有本 source——直接 pop 会
## 触发 InputManager 的「source not found」警告，战斗结束路径上尤其明显。
func _release_lock() -> void:
	if not _lock_held:
		return
	var manager: Node = _input_manager()
	if manager != null and manager.has_method(&"pop_lock"):
		var still_held: bool = not manager.has_method(&"has_lock") \
				or bool(manager.call(&"has_lock", LOCK_SOURCE))
		if still_held:
			manager.call(&"pop_lock", LOCK_SOURCE)
	_lock_held = false


## === 接线与工具 ==============================================================

func _connect_source(p_source: Node) -> void:
	if p_source == null or p_source in _sources:
		return
	_sources.append(p_source)
	if p_source.has_signal(&"enemy_action_resolved"):
		var action_signal: Signal = p_source.get("enemy_action_resolved")
		if not action_signal.is_connected(on_enemy_action):
			action_signal.connect(on_enemy_action)
	if p_source.has_signal(&"battle_ended"):
		var end_signal: Signal = p_source.get("battle_ended")
		if not end_signal.is_connected(on_battle_ended):
			end_signal.connect(on_battle_ended)


## InputManager Autoload——缺失时返回 null；走 Engine 主循环而非 get_tree()，
## 因为 _exit_tree 时节点已离树，get_tree() 为 null 会弹不掉播报锁。
func _input_manager() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("InputManager")
