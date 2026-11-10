extends RefCounted
## CombatResultBridge —— 战斗结束 → 结算对象的接线（Sprint 18 结算回流）。[br]
## [br][b]职责[/b]：订阅 [signal CombatSystem.battle_ended]，把载荷折成
## [code]CombatResultView[/code] 并发布到 [method CombatResultView.publish]，
## 供 [code]result_screen[/code] / [code]defeat_screen[/code] 占位场景消费。[br]
## [br][b]为什么独立成文件[/b]：战斗容器（[code]combat_scene.gd[/code]）已接近
## coding-standards 的 300 行软上限，且「载荷 → 结算对象」是一条可单独测试的纯接线
## （同 [code]combat_play_bridge.gd[/code] 先例）。[br]
## [br][b]可变源[/b]：[method bind] 可重复调用——换源时先断开旧源，避免一次战斗
## 发布两份结算对象（同 [code]SettlementHost.setup[/code] 的换源口径）。[br]
## [br][b]降级[/b]：战斗系统为 null / 无 [code]battle_ended[/code] 信号时静默跳过——
## 缺数据源不该让战斗场景崩溃（发布缓存保持上一次的值，展示端自行判空）。[br]
## [br]来源: production/session-state/active.md（Sprint 18 结算回流）、ADR-0031 §2。

## 结算对象类型——载荷折叠与跨场景缓存的单一实现。
const ViewScript := preload("res://src/feature/combat/combat_result_view.gd")

## 已接线的战斗系统（换源时用于断开）。
var _bound: Node = null

## 最近一次发布的结算对象（测试断言用；与 [method CombatResultView.last] 同一份）。
var published: RefCounted = null


## 接线——订阅战斗结束信号（幂等，含换源）。
func bind(combat_system: Node) -> void:
	unbind()
	if combat_system == null or not combat_system.has_signal(&"battle_ended"):
		return
	_bound = combat_system
	_bound.connect(&"battle_ended", _on_battle_ended)


## 断开当前信号源（未接线时为空操作）。
func unbind() -> void:
	if _bound == null:
		return
	var handler := Callable(self, &"_on_battle_ended")
	if _bound.has_signal(&"battle_ended") and _bound.is_connected(&"battle_ended", handler):
		_bound.disconnect(&"battle_ended", handler)
	_bound = null


## 战斗结束——折叠载荷并发布结算对象。[br]
## [br][param result] [code]CombatSystem.CombatResult[/code] 取值。[br]
## [param rewards] 信号载荷（含 [code]record[/code] / 奖励字段）。[br]
## [br][b]返回[/b]：发布的 [code]CombatResultView[/code]（调用方/测试可直接断言）。
func _on_battle_ended(result: int, rewards: Dictionary) -> void:
	published = ViewScript.from_battle_ended(result, rewards)
	ViewScript.publish(published)
