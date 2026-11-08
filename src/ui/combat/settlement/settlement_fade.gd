class_name SettlementFade
extends RefCounted
## SettlementFade —— 结算/撤退/警示三面板共用的开合淡入淡出（combat-ui-layout Story 008）。
##
## [b]职责[/b]：把「打开 0.2s 淡入 / 关闭 0.15s 淡出后隐藏」这套三处重复的
## Tween 逻辑收在一处（[SettlementPanel] / [RetreatDialog] /
## [TribulationWarningDialog] 各持一个实例）。[br]
## [br][b]零轮询[/b]（ADR-0031 §3）：Tween 是输入驱动的纯视觉变换，豁免轮询禁令；
## 本类只做一次性 Tween 的创建/替换/清理。[br]
## [br][b]减少动态[/b]（ADR-0031 动画偏好）：[param reduce_motion] 为 true 时
## 直跳终态，不建 Tween。[br]
## [br][b]实例持有 Tween 句柄[/b]——不可做成纯静态函数（同一面板重开需 kill 旧的）。
##
## @experimental
## 来源: ADR-0031、combat-ui-layout Story 008（面板开合动画）。

## 打开时长（秒）。
const OPEN_SEC: float = 0.2
## 关闭时长（秒）。
const CLOSE_SEC: float = 0.15

var _tween: Tween = null


## 播放打开（淡入到不透明）。[br]
## [param node]: 被动画的控件（面板根）。[br]
## [param reduce_motion]: true 时直跳终态。
func play_open(node: Control, reduce_motion: bool) -> void:
	kill()
	if node == null:
		return
	node.pivot_offset = node.size * 0.5
	if reduce_motion:
		node.modulate.a = 1.0
		return
	node.modulate.a = 0.0
	_tween = node.create_tween()
	_tween.tween_property(node, "modulate:a", 1.0, OPEN_SEC)


## 播放关闭（淡出后隐藏）。[br]
## [param node]: 被动画的控件。[br]
## [param reduce_motion]: true 时直接隐藏。[br]
## [param on_finished]: 终态回调（可选）。
func play_close(node: Control, reduce_motion: bool,
		on_finished: Callable = Callable()) -> void:
	kill()
	if node == null:
		return
	if reduce_motion:
		node.visible = false
		node.modulate.a = 1.0
		if on_finished.is_valid():
			on_finished.call()
		return
	_tween = node.create_tween()
	_tween.tween_property(node, "modulate:a", 0.0, CLOSE_SEC)
	_tween.tween_callback(func() -> void:
		node.visible = false
		if on_finished.is_valid():
			on_finished.call())


## 清理进行中的 Tween（重开 / 销毁前调用）。
func kill() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
