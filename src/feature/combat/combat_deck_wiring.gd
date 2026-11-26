extends RefCounted
## CombatDeckWiring —— 底部条牌库/弃牌计数的[b]订阅层[/b]（tech-debt DEBT-CUI-010）。[br]
## [br][b]职责[/b]：把 [signal CombatSystem.pile_changed] 推到
## [method DeckCounter.set_deck_counts]，并在开战时补拉一次初值；退场成对退订。[br]
## [br][b]为什么单独成文件而不是写进 CombatBottombar.bind_signals[/b]：计数组件在
## [code]src/ui/[/code]，而 [signal CombatSystem.pile_changed] 是 Feature 层的系统信号——
## 把「哪个系统信号对应哪个展示位」的映射写进 UI 组件，等于让展示层知道战斗系统的
## 信号名与载荷形状（[code]combat_scene_mounting.gd[/code] 的既有分工是：装配点负责
## 把系统信号接到组件，组件只认自己那几个 setter）。行囊 / 结算回流 / 表现反馈
## 三处订阅都走这条分工，本模块与之同构。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：只存两个句柄，不缓存任何计数——
## 重进战斗时新实例重新订阅，不残留上一场的数字。[br]
##
## 来源: ADR-0031 §1/§2、ADR-0008 §信号分类、GDD combat-ui-system §4、
## combat-ui-layout Story 005（AC-5）、tech-debt DEBT-CUI-010。

## 订阅的系统信号（变量而非内联字符串——退订时要用同一份名字）。
const PILE_SIGNAL: StringName = &"pile_changed"
const STARTED_SIGNAL: StringName = &"battle_started"

## 信号源（CombatSystem Autoload；不可用时静默降级）。
var _source: Node = null
## 计数组件（[code]combat_bottombar.deck_counter[/code]；缺失时静默降级）。
var _counter: Control = null


## 订阅——两次连接各自成对记录，[method unbind] 按同一份判据断开。[br]
## [br][b]为什么不用 [code]is_connected[/code] 判重[/b]：本模块一次生命周期只
## [code]bind[/code] 一次（由装配点持有），重复 [code]bind[/code] 是调用点的错，
## 自查会让它静默吞掉；改用「已是同一个源/组件」短路，其余情形都如实连上。[br]
## [br][param p_source] 战斗系统（须有 [signal CombatSystem.pile_changed]）。[br]
## [param p_counter] 计数组件（须有 [method DeckCounter.set_deck_counts]）。[br]
## [br][b]返回[/b]：是否真的建立起订阅（缺任一侧为 false——装配点据此决定是否持有句柄）。
func bind(p_source: Node, p_counter: Control) -> bool:
	if p_source == null or p_counter == null:
		return false
	if not p_source.has_signal(PILE_SIGNAL) or not p_counter.has_method(&"set_deck_counts"):
		return false
	_source = p_source
	_counter = p_counter
	if not _source.is_connected(PILE_SIGNAL, _on_pile_changed):
		_source.connect(PILE_SIGNAL, _on_pile_changed)
	# 开战收尾补拉一次初值：正常路径上 init_deck 的 pile_changed 已经先到，
	# 这一次拉的是[b]同值重放[/b]（幂等）；它兜住的是「订阅建立晚于牌堆就绪」
	# 的路径（如读档续战：牌面在 battle_start 之前已由存档段写回）。
	if _source.has_signal(STARTED_SIGNAL) \
			and not _source.is_connected(STARTED_SIGNAL, _on_battle_started):
		_source.connect(STARTED_SIGNAL, _on_battle_started)
	return true


## 退订——场景退场时调用（装配点 [code]_exit_tree[/code] 路径）。[br]
## [br][b]为什么必须成对[/b]：信号源是常驻 Autoload，不退订会让旧容器在
## 下一次战斗里继续收到推送（节点虽已 freed，连接仍在源上）。
func unbind() -> void:
	if _source != null:
		if _source.is_connected(PILE_SIGNAL, _on_pile_changed):
			_source.disconnect(PILE_SIGNAL, _on_pile_changed)
		if _source.is_connected(STARTED_SIGNAL, _on_battle_started):
			_source.disconnect(STARTED_SIGNAL, _on_battle_started)
	_source = null
	_counter = null


# === 信号回调 ================================================================

## pile_changed(deck, discard) → 计数位刷新。[br]
## [br][b]载荷逐位透传[/b]：不在这一层做钳制或换算——「张数不可能为负」的
## 防御在 [method DeckCounter.set_deck_counts] 里（唯一实现）。
func _on_pile_changed(deck_count: int, discard_count: int) -> void:
	_push(deck_count, discard_count)


## battle_started → 拉一次当前值（开战收尾的初值补齐）。[br]
## [br][b]读不到时不推[/b]：源不可用 / 没有查询口时保持占位符——绝不推一个
## 猜出来的 0（那正是本轮要修的「假 0」）。
func _on_battle_started(_config: Dictionary) -> void:
	if _source == null or not _source.has_method(&"get_deck"):
		return
	if not _source.has_method(&"get_discard_pile"):
		return
	var deck: Variant = _source.call(&"get_deck")
	var discard: Variant = _source.call(&"get_discard_pile")
	if not (deck is Array) or not (discard is Array):
		return
	_push((deck as Array).size(), (discard as Array).size())


## 推到计数组件（组件已释放时静默跳过——帧末释放与信号同帧的窗口）。
func _push(deck_count: int, discard_count: int) -> void:
	if _counter == null or not is_instance_valid(_counter):
		return
	_counter.call(&"set_deck_counts", deck_count, discard_count)
