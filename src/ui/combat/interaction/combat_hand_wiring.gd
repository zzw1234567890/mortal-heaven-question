class_name CombatHandWiring
extends RefCounted
## CombatHandWiring —— 真实对局的手牌供给与刷新（combat-ui-interaction 001 / 本轮）。
##
## [b]职责[/b]：把「战斗系统手牌 → 手牌区快照」这条线接起来，并在会改变手牌可读性
## 的时机刷新——[br]
##   - 开战 / 建卡后：[method refresh] 首次供牌；[br]
##   - [code]phase_changed[/code]：阶段切换改变灵能预览态与可负担性；[br]
##   - [code]cost_changed[/code]：费用变化改变灰显；[br]
##   - [code]character_died[/code]：施法者阵亡 → 顺位，费用不变但选中可能失效。[br]
## [br][b]为什么独立成类[/b]：[code]combat_scene.gd[/code] 已贴 300 行软上限，
## 且「什么时候刷新手牌」是交互契约而不是场景转场逻辑。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：手牌快照每次从装配台现读，
## 费用从 CostSystem 现读；本类只持有信号连接。[br][b]零轮询[/b]：无 [code]_process()[/code]。
##
## 来源: ADR-0031、design/gdd/combat-ui-system.md §2 手牌区、
## combat-ui-interaction Story 001（真实输入路径）、DEBT-CUI-007-2。

## 手牌快照折出（可负担性判定同源）。
const SnapshotScript := preload("res://src/ui/combat/shared/combat_hand_snapshot.gd")

## 数据来源（交互挂载模块或门面——需提供 hand_area / hand_snapshot / current_phase）。
var _layout: Variant = null
## 战斗系统（信号源——可空）。
var _combat: Node = null
## 费用系统（信号源 + 可负担性取数——可空）。
var _cost: Node = null


## 注入数据源并订阅（全部可空——缺失时对应刷新入口静默退化）。[br]
## [param p_layout] 数据来源（交互挂载模块——它把这三件事收敛在一层）。
## [param p_combat] 战斗系统。[param p_cost] 费用系统。
func setup(p_layout: Variant, p_combat: Node, p_cost: Node = null) -> void:
	_layout = p_layout
	_combat = p_combat
	_cost = p_cost
	_connect(p_combat, &"phase_changed", _on_phase_changed)
	_connect(p_combat, &"character_died", _on_character_died)
	_connect(_cost, &"cost_changed", _on_cost_changed)
	refresh()


## 刷新手牌区：快照 + 可负担性 + 阶段（三件事一起做——单独刷任一项都会短暂不一致）。[br]
## [br][b]阶段未知（-1）时按当前阶段值下发[/b]：手牌区在阶段 2 内才灰显，
## 缺数据时保持「未知即宽松」（不把卡全判成灵能预览）。
func refresh() -> void:
	if _layout == null:
		return
	var hand: Variant = _layout.call(&"hand_area")
	if hand == null or not is_instance_valid(hand):
		return
	var snapshot: Array = _layout.call(&"hand_snapshot")
	var phase: int = int(_layout.call(&"current_phase"))
	if phase >= 0:
		hand.call(&"apply_phase", phase)
	hand.call(&"apply_hand", snapshot)
	hand.call(&"apply_affordability",
			SnapshotScript.affordability(snapshot, _current_cost()))


## 同步选中态（卡被移除后自清——防「手牌里没有的卡仍处于选中」）。[br]
## [b]返回[/b]: 控制器是否自清了选中（调用方据此清提示 / 重放视觉）。
func sync_selection(p_flow: RefCounted) -> bool:
	if p_flow == null or _layout == null:
		return false
	var hand: Variant = _layout.call(&"hand_area")
	if hand == null or not is_instance_valid(hand):
		return false
	var controller: RefCounted = p_flow.call(&"get_controller")
	if controller == null:
		return false
	return bool(controller.call(&"sync_hand", hand.call(&"get_card_instance_ids")))


## 取消订阅（场景退场——信号源是常驻 Autoload）。
func unbind() -> void:
	_disconnect(_combat, &"phase_changed", _on_phase_changed)
	_disconnect(_combat, &"character_died", _on_character_died)
	_disconnect(_cost, &"cost_changed", _on_cost_changed)


# === 信号回调 =================================================================

func _on_phase_changed(_old_phase: int, _new_phase: int, _turn: int) -> void:
	refresh()


func _on_character_died(_character_id: int, _side: int, _ids: Array) -> void:
	# 施法者阵亡由装配台自己顺位；这里只刷新手牌可读性（费用/阶段可能未变，
	# 但选中卡若已被移除需要重新落定）。
	refresh()


func _on_cost_changed(_current: int, _max_show: int, _total_max: int) -> void:
	refresh()


# === 内部 =====================================================================

## 当前灵力（费用系统不可用 → 0——可负担性按 0 费卡可出、其余灰显，保守但可解释）。
func _current_cost() -> int:
	if _cost == null or not _cost.has_method(&"get_current_cost"):
		return 0
	return int(_cost.call(&"get_current_cost"))


func _connect(p_source: Node, p_signal: StringName, p_handler: Callable) -> void:
	if p_source == null or not p_source.has_signal(p_signal):
		return
	if not p_source.is_connected(p_signal, p_handler):
		p_source.connect(p_signal, p_handler)


func _disconnect(p_source: Node, p_signal: StringName, p_handler: Callable) -> void:
	if p_source == null or not is_instance_valid(p_source):
		return
	if p_source.has_signal(p_signal) and p_source.is_connected(p_signal, p_handler):
		p_source.disconnect(p_signal, p_handler)
