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
## 键盘/手柄焦点链（手牌 ↔ 底栏 ↔ 撤退，阶段驱动可聚焦性）。
const FocusChainScript := preload("res://src/ui/combat/interaction/combat_focus_chain.gd")
## 出牌结果文案表（拒绝原因 → 提示文本——唯一来源，不另写一份）。
const PlayResultScript := preload("res://src/feature/combat/combat_play_result.gd")
## Esc「退一层」路由（弹窗 → 取消选中 → 放行给暂停菜单）。
const EscapeRouterScript := preload("res://src/ui/combat/interaction/combat_escape_router.gd")
## 键盘/手柄焦点记忆（弹窗开合时把焦点还给打开前的控件）。
const FocusMemoryScript := preload("res://src/ui/combat/interaction/combat_focus_memory.gd")

## 出牌阶段号（结束出牌按钮只在此阶段生效）。
const PLAY_PHASE: int = 2

## 手牌供给实例（[method wire] 创建）。
var hand_wiring: RefCounted = null
## 键盘/手柄焦点链实例（[method wire] 创建）。
var focus_chain: RefCounted = null
## 键盘/手柄焦点记忆（[method wire] 创建——整场战斗一份，见 [method focus_memory]）。
var _focus_memory: RefCounted = null
## Esc 退层路由节点（[method wire] 挂到战场根上）。
var escape_router: Node = null
## 战场门面（CombatLayout）。
var _layout: Control = null
## 战斗系统（结束出牌按钮转发目标）。
var _combat: Node = null
## 「结束出牌」按钮本体（退场时断开连接用）。
var _end_turn_button: Button = null
## 手牌区（退场时清掉键盘确认出口用）。
var _hand_area: Control = null


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
	_connect_focus_chain(p_layout, p_combat)
	_connect_card_keyboard(p_layout)
	_connect_escape_router(p_layout)


## 开战后的启用：放行输入并首次供牌（阶段 / 费用 / 手牌三件事一次落定）。
func enable() -> void:
	set_enabled(true)
	if hand_wiring != null:
		hand_wiring.call(&"refresh")
	if focus_chain != null:
		focus_chain.call(&"set_enabled", true)


## 键盘/手柄焦点记忆（面板开合的还原位置——整场战斗一份，惰性创建）。[br]
## [br][b]为什么挂在本模块而不是焦点链上[/b]：行囊面板与结算宿主都要用它，而这两处
## 面板的装配点在场景挂载侧、不持链；记忆归交互接线（它同时持链与面板装配时机），
## 「默认焦点是谁」仍由链回答——记忆只持一个 [Callable] 兜底。[br]
## [br][b]兜底在建立时注册[/b]：链未装配时为无兜底的空记忆（还不了原处就如实返回
## null，不假装成功）。
func focus_memory() -> RefCounted:
	if _focus_memory == null:
		_focus_memory = FocusMemoryScript.new()
		if focus_chain != null:
			_focus_memory.call(&"set_fallback",
					Callable(focus_chain, &"focus_default"))
	return _focus_memory


## 放行 / 停用输入（模态面板打开时停用——防止点穿）。[br]
## [br][b]焦点链同步让位[/b]：面板盖住的按钮不该还落得到焦点，否则玩家按 Tab
## 会在看不见的链上乱走、按回车又什么都不发生。
func set_enabled(p_enabled: bool) -> void:
	if _layout == null:
		return
	var interaction: Variant = _layout.call(&"interaction")
	if interaction != null:
		interaction.call(&"set_input_enabled", p_enabled)
	if focus_chain != null:
		focus_chain.call(&"set_enabled", p_enabled)


## 退订（场景退场——信号源是常驻 Autoload）。
func unbind() -> void:
	if hand_wiring != null:
		hand_wiring.call(&"unbind")
	hand_wiring = null
	if focus_chain != null:
		focus_chain.call(&"unbind")
	focus_chain = null
	if _focus_memory != null:
		_focus_memory.call(&"clear")
	_focus_memory = null
	if escape_router != null and is_instance_valid(escape_router):
		escape_router.queue_free()
	escape_router = null
	if _hand_area != null and is_instance_valid(_hand_area):
		_hand_area.set(&"card_activated", Callable())
	_hand_area = null
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
	# 手牌换了节点，焦点环的 NodePath 要跟着重建（旧路径指向已释放的卡节点）。
	if focus_chain != null:
		focus_chain.call(&"rebuild")


# === 键盘/手柄焦点接线 ========================================================

## 建焦点链并注入门面与战斗系统（阶段驱动由链自己订阅）。[br]
## [br][b]建完即停用[/b]：备战 / 续战面板期间不该有可聚焦的战场控件——
## 与输入层同一条「开战才放行」的时序（[method enable] 里一起开）。
func _connect_focus_chain(p_layout: Control, p_combat: Node) -> void:
	focus_chain = FocusChainScript.new()
	focus_chain.call(&"bind", p_layout, p_combat)
	focus_chain.call(&"set_enabled", false)


## 手牌卡的键盘确认（回车/空格）→ 交给出牌流程。[br]
## [br][b]为什么走 [code]card_activated[/code] 回调而不是让卡自己出牌[/b]：
## 手牌区是渲染层（零状态所有权，ADR-0031 §2），「这张卡能不能出、打谁」全部归
## 出牌流程；这条回调正是把「哪张被确认了」送进来的那一口。[br]
## [br][b]打成与鼠标点击同一形状[/b]：走 [code]click_card[/code]——第一次选中、
## 同一张再按一次确认，与鼠标「点两次」完全一致，不新造一套键盘语义。
func _connect_card_keyboard(p_layout: Control) -> void:
	var hand: Variant = p_layout.get(&"hand_area")
	if hand == null or not is_instance_valid(hand):
		return
	_hand_area = hand as Control
	_hand_area.set(&"card_activated", Callable(self, &"_on_card_activated"))


func _on_card_activated(p_card_instance_id: int) -> void:
	if _layout == null or p_card_instance_id < 0:
		return
	if not _input_allowed():
		return
	var interaction: Variant = _layout.call(&"interaction")
	if interaction == null or not (interaction as Object).has_method(&"get_input_layer"):
		return
	var input: Variant = interaction.call(&"get_input_layer")
	if input == null or not (input as Object).has_method(&"get_flow"):
		return
	var flow: Variant = input.call(&"get_flow")
	# 非出牌阶段的按键不做任何事——与鼠标路径同一道阶段闸（「敌方回合按回车
	# 不会触发任何出牌」这条要求就落在这里，不在卡上）。阶段口径与
	# [code]CombatInputLayer._is_play_phase[/code] 同源：未知（-1）按宽松。
	if not _is_play_phase(int(interaction.call(&"current_phase"))):
		return
	_apply_outcome(flow.call(&"click_card", p_card_instance_id))


## 当前阶段是否允许出牌（未知按宽松——与输入层同一口径）。
func _is_play_phase(p_phase: int) -> bool:
	return p_phase < 0 or p_phase == PLAY_PHASE


## Esc「退一层」路由——挂在战场根上（不是 Autoload）。[br]
## [br][b]为什么挂在场景侧[/b]：Esc 的层级语义（先关弹窗 / 再取消选中 / 都没有才
## 轮得到暂停菜单）属于战斗界面，不属于全局；挂在场景节点上的另一个好处是
## [code]_input[/code] 早于 Autoload 那一份（实测），能先一步消费。[br]
## [br][b]已存在则复用[/b]：续战等路径可能二次 wire，重复挂会让一次 Esc 退两层。
func _connect_escape_router(p_layout: Control) -> void:
	if escape_router == null or not is_instance_valid(escape_router):
		escape_router = EscapeRouterScript.new()
		escape_router.name = "CombatEscapeRouter"
		p_layout.add_child(escape_router)
	escape_router.call(&"bind", p_layout)


## 把一次手势结果落到界面上（与输入层的私有分流同形——键盘这条路径没有坐标，
## 走不了 [code]CombatInputLayer._act[/code]，但它做的事一样：拒绝给提示、
## 出牌刷新手牌）。[br]
## [br][b]为什么不直接复用输入层[/b]：输入层的分流是鼠标事件驱动的私有方法，
## 从外面调它就得把 [code]_act[/code] 提成公开 API；而本方法只处理「卡被确认」
## 这一种结果（不会出现拖拽 / 点目标），逻辑比输入层那份窄得多。
func _apply_outcome(p_outcome: Dictionary) -> void:
	if p_outcome.is_empty():
		return
	var status: StringName = StringName(str(p_outcome.get("status", &"")))
	if status == &"rejected":
		var interaction: Variant = _layout.call(&"interaction")
		var toast: Variant = interaction.call(&"get_toast") if interaction != null else null
		if toast != null and toast.has_method(&"show_message"):
			toast.call(&"show_message", _rejection_text(p_outcome.get("result", {})))
		return
	if status == &"played":
		_on_play_committed()
		return
	# 选中 / 取消选中都由控制器信号驱动视觉（[code]selection_changed[/code] 已接），
	# 这里不重复刷。

## 拒绝原因 → 提示文本（文案表是唯一来源，不在这里另写一份）。
func _rejection_text(p_result: Variant) -> String:
	if not (p_result is Dictionary):
		return ""
	var result: Dictionary = p_result
	return String(PlayResultScript.message_for(
			StringName(str(result.get("reason", &""))), result.get("context", {})))


## 输入锁判定（与 [code]CombatInputLayer._input_allowed[/code] 同一口径——
## 键盘确认同样不该在动画锁 / 弹窗锁期间生效）。[br]
## [br][b]无 InputManager 时放行[/b]：桩环境不锁死（同先例）。
func _input_allowed() -> bool:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return true
	var im: Node = tree.root.get_node_or_null(NodePath("InputManager"))
	if im == null or not im.has_method(&"is_input_allowed"):
		return true
	return bool(im.call(&"is_input_allowed",
			im.get(&"ActionType").GAMEPLAY, im.get(&"DeviceType").KEYBOARD))
