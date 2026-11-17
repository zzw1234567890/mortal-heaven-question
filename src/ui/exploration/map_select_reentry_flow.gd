extends RefCounted
## MapSelectReentryFlow —— 重入确认之后的[b]编排接线[/b]：扣费 → 进图 / 拒绝提示。[br]
## [br][b]本模块补的断链[/b]：[signal MapSelectScreen.reentry_requested] 自 S16-2
## 起就摆在那里，但[b]全库无消费者[/b]——玩家在重入确认弹窗上点「确认传送」，
## 费用的扣除与地图的进入两件事都不会发生（信号发进虚空，弹窗关掉、界面停在原地，
## 点击看起来像失灵）。[br]
## [br][b]为什么单独一处[/b]：[code]exploration_scene.gd[/code] 已贴 300 行软上限
## （.claude/docs/coding-standards.md），而「重入意图怎么落地」与「节点图怎么挂、
## 退出怎么结算」是两件事（同 [code]map_clear_presenter.gd[/code] 先例）。[br]
## [br][b]扣费与放行都在 Feature 层[/b]：[method ExplorationReentry.enter] 负责全部
## 判定与扣费（拒绝路径一律不扣），本模块只做三件事——找依赖、转发意图、念结果
## 文案。UI 绝不自己算费用、绝不自己扣灵石（ADR-0031 §2 零状态所有权）。[br]
## [br][b]进图调用方给[/b]：本模块不认识节点图，放行后调宿主注入的
## [code]func(map_id: StringName) -> void[/code]（生产路径是
## [code]ExplorationScene._enter_map[/code]，已 [code]bind(false)[/code] 固定「新生成」
## ——重入要的是新 seed 与新 DAG，不是读档续玩）。[br]
## [br][b]依赖查找走 [MapSelectData][/b]：那里已有「注入优先、Autoload 兜底」的
## 探索/资源系统取法（测试可替换），本模块不另写一套查找。[br]
## [br][b]文案本地化豁免[/b]：与各 [code]TEXT_*[/code] 同源口径。[br]
##
## 来源: design/gdd/exploration-ui-system.md §1 重入确认弹窗、
## design/gdd/exploration-system.md §1 地图重入消耗规则、
## ADR-0014 §决策 4 经济、ADR-0031 §2。

## 数据读取面（探索/资源/GSM 的注入优先取法）。
const DataScript := preload("res://src/ui/exploration/map_select_data.gd")
## 重入编排（资格判定 + 扣费——Feature 层唯一实现）。
const ReentryScript := preload("res://src/feature/exploration/exploration_reentry.gd")
## 提示出口（与未解锁卡的条件提示同一处——两处各找一遍 HUD 必然出现口径差异）。
const NoticeScript := preload("res://src/ui/exploration/map_select_notice.gd")

## 重入结果的提示类型——与未解锁卡提示同档（`system`：重要通知，连点不被挤出）。
const NOTIFY_TYPE: String = NoticeScript.NOTIFY_TYPE

## 宿主（[code]notify_cb[/code] 注入字段 + 数据查找锚点）。
var _host: Node = null
## 地图选择屏幕（重入意图的来源）。
var _screen: Control = null
## 放行后的进图回调 [code]func(map_id: StringName) -> void[/code]。
var _enter: Callable = Callable()
## 信号是否已接（重复接线会让一次确认扣两次费）。
var _connected: bool = false


## 接线——注入宿主、意图来源与进图出口（可重复调用；[method connect_screen] 幂等）。[br]
## [br][param p_host] 宿主（通常是探索薄容器——[code]notify_cb[/code] 从它读）。[br]
## [param p_screen] 地图选择屏幕实例。[br]
## [param p_enter] 进图回调（已绑定好「新生成」的那一半参数）。[br]
## [br][b]宿主缺失不崩[/b]：本模块只在收到意图时判一次，未接线时不接信号。
func attach(p_host: Node, p_screen: Control, p_enter: Callable) -> void:
	_host = p_host
	_screen = p_screen
	_enter = p_enter


## 接上 [signal MapSelectScreen.reentry_requested]。[br]
## [br][b]返回[/b]：本次是否接了新信号（已接过 / 屏幕没有该信号时为 false）。[br]
## [br][b]幂等[/b]：重复接线会让同一次「确认传送」扣两次费——[code]_connected[/code]
## 把这个不变量收在一处，而不是靠调用方自觉。
func connect_screen() -> bool:
	if _connected or _screen == null or not is_instance_valid(_screen):
		return false
	if not _screen.has_signal(&"reentry_requested"):
		return false
	_screen.connect(&"reentry_requested", _on_requested)
	_connected = true
	return true


## 是否已接线（宿主查询 / 测试断言用）。
func is_connected_screen() -> bool:
	return _connected


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 收到重入意图——扣费并放行（拒绝时只提示，不扣费不进图）。
func _on_requested(p_map_id: StringName) -> void:
	handle(p_map_id)


## 执行一次重入——[b]本模块的唯一执行口[/b]（信号与测试都走它）。[br]
## [br][b]返回[/b]：[method ExplorationReentry.enter] 的结果字典
## （[code]ok / reason / message / cost / balance / map_id[/code]）。[br]
## [br][b]顺序[/b]：先念文案再进图——进图会挂上节点图盖住选图界面，提示要在那之前
## 交给通知区域（顺序反了玩家就看不到「消耗了多少灵石」）。
func handle(p_map_id: StringName) -> Dictionary:
	var data: RefCounted = DataScript.new(_host)
	var result: Dictionary = ReentryScript.enter(p_map_id,
			data.call(&"exploration_system"),
			data.call(&"game_state_manager"),
			data.call(&"resource_system"))
	_notify(str(result.get("message", "")))
	if bool(result.get("ok", false)) and _enter.is_valid():
		_enter.call(StringName(str(result.get("map_id", p_map_id))))
	return result


## 请求一条提示（空文案不出声；无出口时静默降级，不把缺 UI 变成崩溃）。[br]
## [br][b]返回[/b]：实际展示的文案（空串 = 没出声）。
func _notify(p_text: String) -> String:
	if p_text.strip_edges().is_empty():
		return ""
	var sink: Callable = NoticeScript.notification_sink(_host)
	if sink.is_valid():
		sink.call(NOTIFY_TYPE, p_text)
		return p_text
	push_warning("MapSelectReentryFlow: 无通知出口，重入结果未展示（%s）" % p_text)
	return ""
