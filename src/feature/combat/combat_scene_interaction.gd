extends RefCounted
## CombatSceneInteraction —— 战斗场景的出牌交互接线（combat-ui-interaction 001 / 本轮）。
##
## [b]职责[/b]：场景容器把「交互层 + 手牌供给」两件事委托给本模块——[br]
##   1. [method wire]：装配 [code]CombatLayout[/code] 的输入层与提示条
##      （手势 → [code]CombatPlayController[/code]），并建 [code]CombatHandWiring[/code]
##      （战斗手牌 → 手牌区快照）；备战期输入层[b]停用[/b]，避免隔面板点穿；[br]
##   2. [method enable]：开战 + 建卡后开启输入并首次供牌；[br]
##   3. [method unbind]：场景退场时退订（信号源是常驻 Autoload）。[br]
## [br][b]为什么单独成文件[/b]：[code]combat_scene.gd[/code] 已贴 300 行软上限，
## 而「何时供牌、何时放行输入」是交互契约而非转场逻辑。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：手牌 / 费用全部现读，本模块只持接线句柄。
##
## 来源: ADR-0031、combat-ui-interaction Story 001、DEBT-CUI-007-2。

## 手牌供给与刷新（战斗手牌 → 手牌区快照）。
const HandWiringScript := preload("res://src/ui/combat/interaction/combat_hand_wiring.gd")

## 出牌阶段号（结束出牌按钮只在此阶段生效）。
const PLAY_PHASE: int = 2

## 手牌供给实例（[method wire] 创建）。
var hand_wiring: RefCounted = null
## 战场门面（CombatLayout）。
var _layout: Control = null
## 战斗系统（结束出牌按钮转发目标）。
var _combat: Node = null
## 「结束出牌」按钮本体（退场时断开连接用）。
var _end_turn_button: Button = null


## 接线：装配交互层（输入层 + 提示条）与手牌供给。[br]
## [param p_layout] 战场门面（[code]CombatLayout[/code]）。[br]
## [param p_combat] 战斗系统（可空——缺失时供牌退化为空快照）。[br]
## [param p_cost] 费用系统（可空——缺失时按 0 灵力判定灰显）。[br]
## [param p_reduce_motion] 减少动态（提示条淡出改瞬时）。
func wire(p_layout: Control, p_combat: Node, p_cost: Node,
		p_reduce_motion: bool = false) -> void:
	_layout = p_layout
	_combat = p_combat
	p_layout.call(&"setup_interaction", p_reduce_motion)
	set_enabled(false)
	hand_wiring = HandWiringScript.new()
	hand_wiring.call(&"setup", p_layout.call(&"interaction"), p_combat, p_cost)
	_connect_input(p_layout.call(&"interaction"))
	_connect_end_turn(p_layout)


## 开战后的启用：放行输入并首次供牌（阶段 / 费用 / 手牌三件事一次落定）。
func enable() -> void:
	set_enabled(true)
	if hand_wiring != null:
		hand_wiring.call(&"refresh")


## 放行 / 停用输入（模态面板打开时停用——防止点穿）。
func set_enabled(p_enabled: bool) -> void:
	if _layout == null:
		return
	var interaction: Variant = _layout.call(&"interaction")
	if interaction != null:
		interaction.call(&"set_input_enabled", p_enabled)


## 退订（场景退场——信号源是常驻 Autoload）。
func unbind() -> void:
	if hand_wiring != null:
		hand_wiring.call(&"unbind")
	hand_wiring = null
	if _end_turn_button != null and is_instance_valid(_end_turn_button) \
			and _end_turn_button.pressed.is_connected(_on_end_turn_pressed):
		_end_turn_button.pressed.disconnect(_on_end_turn_pressed)
	_end_turn_button = null


# === 输入接线 ================================================================

## 订阅「出牌已提交」——重画手牌并同步选中（打出的卡离开手牌后自清）。
func _connect_input(p_interaction: Variant) -> void:
	if p_interaction == null or not (p_interaction as Object).has_method(&"get_input_layer"):
		return
	var input: Variant = p_interaction.call(&"get_input_layer")
	if input == null or not (input as Object).has_signal(&"play_committed"):
		return
	if not (input as Object).is_connected(&"play_committed", _on_play_committed):
		(input as Object).connect(&"play_committed", _on_play_committed)


## 结束出牌按钮 → [method CombatSystem.confirm_end_turn]。[br]
## [br][b]补的断链[/b]：按钮此前只有渲染（layout story 005 划给 interaction epic），
## 真实对局里点它没有任何反应——玩家无法结束回合。此处不新造规则：阶段与活跃
## 判定全部由战斗系统现读，按钮只在阶段 2 可见。
func _connect_end_turn(p_layout: Control) -> void:
	var bar: Variant = p_layout.get(&"combat_bottombar")
	if bar == null or not (bar as Object).has_method(&"get"):
		return
	var end_turn: Variant = (bar as Object).get("end_turn_button")
	if end_turn == null:
		return
	var button: Variant = (end_turn as Object).get("button")
	if not (button is Button):
		return
	_end_turn_button = button as Button
	if not _end_turn_button.pressed.is_connected(_on_end_turn_pressed):
		_end_turn_button.pressed.connect(_on_end_turn_pressed)


func _on_end_turn_pressed() -> void:
	if _combat == null or not _combat.has_method(&"confirm_end_turn"):
		return
	if _combat.has_method(&"is_battle_active") \
			and not bool(_combat.call(&"is_battle_active")):
		return
	if _combat.has_method(&"get_current_phase") \
			and int(_combat.call(&"get_current_phase")) != PLAY_PHASE:
		return
	_combat.call(&"confirm_end_turn")


func _on_play_committed() -> void:
	if hand_wiring == null:
		return
	hand_wiring.call(&"refresh")
	var interaction: Variant = _layout.call(&"interaction") if _layout != null else null
	if interaction != null and hand_wiring != null:
		var input: Variant = interaction.call(&"get_input_layer")
		if input != null and input.has_method(&"get_flow"):
			hand_wiring.call(&"sync_selection", input.call(&"get_flow"))
