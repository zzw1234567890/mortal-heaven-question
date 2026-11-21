extends RefCounted
## CultivationTribulationFeed —— 渡劫结果的[b]回流接线[/b]（从修炼室屏幕拆出）。[br]
## [br][b]为什么单独一处[/b]：屏幕脚本要守在 300 行软上限内
## （.claude/docs/coding-standards.md），而「订哪个信号、断得干不干净、失败那句怎么讲」
## 是纯接线，与「控件怎么搭、焦点怎么走」无关。[br]
## [br][b]订的是 [code]TribulationSystem[/code] 的成败信号，不是轮询[/b]：渡劫战在
## [b]另一个场景[/b]里打，打完（[code]tribulation_succeeded[/code] /
## [code]tribulation_failed[/code]）玩家才回到修炼室。没有这条回流，屏幕上显示的还是
## 出发前的数字——玩家看不到自己刚赢下的那个境界。[br]
## [br][b]断线交给 [method unbind]，且必须被调用[/b]：[code]TribulationSystem[/code] 是
## Autoload、活得比本屏久——不摘会让它继续持有一个指向已释放界面的 [Callable]
## （同屏幕订阅 GSM [code]realm_changed[/code] 的口径）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本模块不读 GSM、不写任何玩法数值——只把
## 信号载荷转成一句中文再交回给屏幕，[b]刷新数字仍由屏幕自己重读系统[/b]
## （回流只负责「告诉你该看一眼了」）。[br]
## [br][b]文案本地化豁免[/b]：句子取自 [code]CultivationViewRules[/code] 的
## [code]TEXT_*[/code]（本模块不自己措辞）。[br]
##
## 来源: design/gdd/tribulation-system.md §4/§5、ADR-0021 §信号分类
## （[code]tribulation_succeeded[/code] / [code]tribulation_failed[/code] 载荷）、
## ADR-0031 §2、先例 [code]cultivation_screen.gd[/code] §_connect_realm_changed。

## 文案单点（成功 / 失败两句都在那边，本模块只填数字）。
const RulesScript := preload("res://src/ui/cultivation/cultivation_view_rules.gd")

## 渡劫系统（绑定期间持有——[method unbind] 时置空）。
var _ts: Node = null
## 结果出口 [code]func(message: String) -> void[/code]（屏幕注入）。
var _on_result: Callable = Callable()


## 订阅渡劫成败信号。[br]
## [br][param p_ts] [code]TribulationSystem[/code]（可为 null——此时什么都不订，
## 屏幕仍走自己的降级形态）。[br]
## [param p_on_result] 结果出口 [code]func(message: String) -> void[/code]。[br]
## [br][b]重复绑定先解绑[/b]：屏幕可能因重挂而再绑一次，叠加连接会让一次渡劫发两句回执。
func bind(p_ts: Node, p_on_result: Callable) -> void:
	unbind()
	_on_result = p_on_result
	if p_ts == null or not is_instance_valid(p_ts):
		return
	_ts = p_ts
	_connect(&"tribulation_succeeded", _on_succeeded)
	_connect(&"tribulation_failed", _on_failed)


## 摘掉订阅（屏幕 [method Node._exit_tree] 必须调——见类文档）。
func unbind() -> void:
	if _ts != null and is_instance_valid(_ts):
		_disconnect(&"tribulation_succeeded", _on_succeeded)
		_disconnect(&"tribulation_failed", _on_failed)
	_ts = null
	_on_result = Callable()


## 是否已接上渡劫系统（测试断言用——「没系统时不硬订」同样是契约）。
func is_bound() -> bool:
	return _ts != null and is_instance_valid(_ts)


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 渡劫成功——境界名取自配置表（两个名字都由文案层格式化）。
func _on_succeeded(p_old_realm: int, p_new_realm: int, _p_is_cross_realm: bool) -> void:
	_report(RulesScript.tribulation_succeeded_line(p_old_realm, p_new_realm))


## 渡劫失败——损失量由结算给出（本模块不自己算）。
func _on_failed(p_penalty: int, _p_realm_level: int) -> void:
	_report(RulesScript.tribulation_failed_line(p_penalty))


## 交回给屏幕（出口失效时静默——屏幕可能已经离场，不是错误）。
func _report(p_message: String) -> void:
	if _on_result.is_valid():
		_on_result.call(p_message)


## 接一个信号（系统没有该信号名时静默跳过——降级而非崩溃）。
func _connect(p_signal: StringName, p_handler: Callable) -> void:
	if not _ts.has_signal(p_signal) or _ts.is_connected(p_signal, p_handler):
		return
	_ts.connect(p_signal, p_handler)


## 摘一个信号（未接上时静默跳过——[method unbind] 可重复调用）。
func _disconnect(p_signal: StringName, p_handler: Callable) -> void:
	if not _ts.has_signal(p_signal) or not _ts.is_connected(p_signal, p_handler):
		return
	_ts.disconnect(p_signal, p_handler)
