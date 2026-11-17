extends GutTest
## PauseMenuFixture —— 暂停菜单「存档 / 读档 / 输入锁定」用例的共享装置。[br]
## [br][b]为什么单独一处[/b]：用例文件要守在 300 行软上限内
## （.claude/docs/coding-standards.md），而「怎么摆一桌菜单 + 三个替身」与
## 「断言什么」是两件事（同 [code]startup_loop_fixture.gd[/code] 先例）。[br]
## [br][b]用法[/b]：子类 [code]extends "res://…/pause_menu_fixture.gd"[/code]，
## 直接写 [code]test_*[/code] 方法；[code]before_each[/code] / [code]after_each[/code]
## 由本夹具提供。文件不以 [code]test_[/code] 开头（GUT 按前缀收集）。[br]
## [br][b]常量与替身全部由本夹具提供[/b]（[code]SLS[/code] / [code]SM[/code] /
## [code]IntentScript[/code] 与四个替身类）——子类重复声明同名成员在 GDScript 里是
## 解析错误，整个子类文件会被 GUT 静默忽略（[code]Ignoring script … because it
## does not extend GutTest[/code]），用例一条都不会跑。[br]
## [br][b]为什么直挂 PauseMenu.tscn 而不是 HUD.tscn[/b]：本组用例测的是菜单自己那条
## 动作链（存档写哪格、读档怎么导航、锁怎么配对），HUD 只是生产上的注入方——
## 整棵 HUD 挂进来会连带 RealmBar/LingshiDeckBar 的订阅与可见性矩阵，
## 把「菜单的错」和「HUD 的错」混在一起（HUD 侧接线另有
## [code]test_pause_menu.gd[/code] / [code]test_hud_bootstrap.gd[/code]）。[br]
## [br][b]三个替身都注入[/b]：SaveLoadSystem / SceneManager / GameStateManager——
## 菜单的动作层不直引 Autoload（ADR-0031 §2），换掉这三者即可脱离真实文件系统与
## 真实转场。[br]
## [br]来源: ADR-0031 §1.1/§2、design/ux/pause-menu.md、
## design/gdd/main-menu-system.md。

const PAUSE_SCENE: PackedScene = preload("res://src/ui/hud/PauseMenu.tscn")
## SaveLoadSystem 脚本常量——SaveSlotType / SaveResult / LoadResult 枚举真理来源
## （子类用例直接用，不必各自 preload）。
const SLS := preload("res://src/foundation/save_load_system.gd")
## SceneManager 脚本常量——SceneID / TransitionType 枚举真理来源。
const SM := preload("res://src/foundation/scene_manager.gd")
## 跨场景进入意图（读档成功后应留下 RESUME 意图）。
const IntentScript := preload("res://src/feature/exploration/exploration_entry_intent.gd")
## 二次确认那一步的共享实现（按钮路径的唯一真理来源——见该文件）。
const ConfirmStep := preload("res://tests/integration/hud/pause_confirm_step.gd")


## SaveLoadSystem 替身——[code]save_result[/code] / [code]load_result[/code] 可配置，
## 每次调用留痕（槽位、载荷、次数），并实现 [code]list_slots[/code] / [code]auto_save[/code]。
class MockSaveLoad:
	extends Node

	var save_result: int = 0  # SaveResult.SUCCESS
	var save_calls: Array = []
	var last_payload: Dictionary = {}
	var auto_save_calls: int = 0
	var slots: Array = []
	var load_result: int = 0  # LoadResult.SUCCESS
	var payload: Dictionary = {"game_state": {"player": {"realm": 1}}}
	var load_calls: Array = []

	func save_game(slot_type: int, slot_id: int, data: Dictionary,
			meta: Dictionary) -> int:
		save_calls.append([slot_type, slot_id, data, meta])
		last_payload = data
		return save_result

	func load_game(slot_type: int, slot_id: int) -> Dictionary:
		load_calls.append([slot_type, slot_id])
		if load_result != 0:
			return {"result": load_result, "data": {}}
		return {"result": 0, "data": payload}

	func list_slots() -> Array:
		return slots

	func auto_save() -> Variant:
		auto_save_calls += 1
		return save_result


## SceneManager 替身——记录转场请求（真转场会换掉测试进程的主场景）。[br]
## [br][b]场景 ID 可配[/b]（[member scene_id]）：暂停菜单按当前场景调按钮可见性
## （战斗中隐藏「保存并退出」），默认给探索——那是暂停菜单最典型的调用场景。
class MockSceneManager:
	extends Node

	var change_calls: Array = []
	## 当前场景 ID（缺省 EXPLORATION——探索中暂停是默认变体）。
	var scene_id: int = SM.SceneID.EXPLORATION

	func get_current_scene_id() -> int:
		return scene_id

	func request_scene_change(from: int, to: int, type: int) -> bool:
		change_calls.append([from, to, type])
		return true


## GameStateManager 替身——提供存档载荷（[code]serialize[/code]）与进度行读取面
## （[code]exploration[/code] 属性）。[br]
## [br][b]载荷可置空[/b]：空载荷是「序列化失败」的信号，动作层据此拒绝写盘。
class MockGsm:
	extends Node

	var payload: Dictionary = {"game_state": {"player": {"realm": 1}}}
	var exploration: Dictionary = {"node_position": {"layer": 2}}

	func serialize() -> Dictionary:
		return payload


## 音频 adapter 替身——记录暂停/恢复调用次数（配对断言）。
class MockAudioAdapter:
	extends PauseAudioAdapter

	var suspend_calls: int = 0
	var resume_calls: int = 0

	func suspend() -> void:
		suspend_calls += 1

	func resume() -> void:
		resume_calls += 1


## CombatSystem 替身——只提供暂停菜单真正会碰的那几个面：[br]
##   · [method is_battle_active] / [method confirm_retreat]（投降收尾）；[br]
##   · [method get_hand] / [method get_deck]（卡组查看的「已抽出/仍在牌库」标注）。[br]
## [br][b]为什么只给这几个方法[/b]：真实 [CombatSystem] 有 1600+ 行与一堆 Autoload
## 依赖，整场战斗跑起来才能问「撤回按钮接对没有」不划算；判据与调用都在被测代码里
## （[PauseMenuCombatExit] / [DeckViewRows] 都做能力探测），替身只如实记账。[br]
## [br][b]retreat_calls 是核心断言面[/b]：「战斗中点返回主菜单有没有真的走投降」
## 唯一的客观证据就是这一笔。
class MockCombat:
	extends Node

	## 是否有活跃战斗（决定「返回主菜单」走投降还是走导航）。
	var active: bool = true
	## [method confirm_retreat] 被调用的次数。
	var retreat_calls: int = 0
	## 投降那一刻的暂停 / 锁快照——「先解除暂停再投降」的顺序断言面（顺序反了
	## 新场景会停在冻结帧，而那是个只在真机上看得见的症状）。
	var tree_paused_at_retreat: bool = false
	var lock_held_at_retreat: bool = false
	## 手牌（卡组查看据此标「已抽出」）。
	var hand: Array = []
	## 牌库（本替身只用于「两个读取面都在」的能力探测，内容不参与断言）。
	var deck: Array = []

	func is_battle_active() -> bool:
		return active

	func confirm_retreat() -> void:
		retreat_calls += 1
		tree_paused_at_retreat = get_tree().paused
		lock_held_at_retreat = InputManager.has_lock(&"pause_menu")

	func get_hand() -> Array:
		return hand.duplicate()

	func get_deck() -> Array:
		return deck.duplicate()


## DeckEditingSystem 替身——只提供 [method get_deck_cards]（卡组查看的取数面）。
class MockDeck:
	extends Node

	var cards: Array = []

	func get_deck_cards() -> Array:
		return cards.duplicate()


## CardSystem 替身——按实例 ID 给模板（[method get_template_by_instance_id]）。[br]
## [br][b]模板是真 [CardTemplate] 资源[/b]（不是又一层替身）：行文案读的是它的
## [code]name[/code] / [code]type[/code] / [code]rarity[/code] / [code]cost[/code]
## 字段，用真资源才能验证「名字真的出现在行里」而不是验证替身自己编的字符串。
class MockCards:
	extends Node

	var templates: Dictionary = {}

	func get_template_by_instance_id(card_instance_id: int) -> CardTemplate:
		var raw: Variant = templates.get(card_instance_id)
		return raw if raw is CardTemplate else null


var menu: Control = null
var sl: MockSaveLoad = null
var sm: MockSceneManager = null
var gsm: MockGsm = null
var adapter: MockAudioAdapter = null
## 用例按需装的替身（[method attach_combat] / [method attach_deck]）——由
## [method after_each] 统一回收（见那边的注记）。
var _extras: Array[Node] = []


func before_each() -> void:
	IntentScript.clear()
	sl = MockSaveLoad.new()
	sm = MockSceneManager.new()
	gsm = MockGsm.new()
	adapter = MockAudioAdapter.new()
	add_child(sl)
	add_child(sm)
	add_child(gsm)
	menu = PAUSE_SCENE.instantiate()
	menu.animate = false
	menu.save_load = sl
	menu.scene_manager = sm
	menu.gsm = gsm
	menu.audio_adapter = adapter
	add_child(menu)


func after_each() -> void:
	# 泄漏 paused / 锁栈会污染后续套件（story 测试要求）
	get_tree().paused = false
	InputManager.clear_locks()
	IntentScript.clear()
	for node: Node in [menu, sl, sm, gsm]:
		if node != null and is_instance_valid(node):
			node.free()
	# 用例按需装的替身（战斗 / 卡组 / 卡牌）同样要收——留一个活跃替身在树上，
	# 下一条用例的 [code]attach_combat[/code] 会叠出第二个。
	for extra: Node in _extras:
		if extra != null and is_instance_valid(extra):
			extra.free()
	_extras.clear()
	menu = null
	sl = null
	sm = null
	gsm = null
	adapter = null


# ═══════════════════════════════════════════════════════════════════════════════
# 辅助
# ═══════════════════════════════════════════════════════════════════════════════

## 打开菜单（走真实统一入口——锁/暂停/adapter 一次性到位）。
func open_menu() -> void:
	menu.request_open(&"esc")


## 反馈行的文案（玩家实际看到的那一行）。
func status_text() -> String:
	return (menu.get_node("Panel/VBox/StatusLabel") as Label).text


## 反馈行的颜色（成功档 / 失败档由颜色区分，见 PauseMenu.COLOR_STATUS_*）。
func status_color() -> Color:
	return (menu.get_node("Panel/VBox/StatusLabel") as Label).get_theme_color(&"font_color")


## 进度行文案。
func progress_text() -> String:
	return (menu.get_node("Panel/VBox/ProgressLabel") as Label).text


## 读档面板（未打开过时为 null）。
func load_panel() -> Control:
	return menu.get_actions().get("_panel")


## 二次确认框（未弹出过时为 null）。
func confirm_dialog() -> Control:
	return menu.get_state().get("_confirm")


## 确认框里的某个按钮（路径归 [code]pause_confirm_step.gd[/code]——三处共用一个
## 真理来源，路径一改只改那一处）。
func confirm_button(button_name: String) -> Button:
	var dialog: Control = confirm_dialog()
	if dialog == null or not is_instance_valid(dialog):
		return null
	return dialog.get_node_or_null(ConfirmStep.BUTTONS_PATH + button_name) as Button


## 当前键盘/手柄焦点持有者（菜单内的按钮——4.6 双焦点下 grab_focus 只影响它）。
func focus_owner() -> Control:
	return menu.get_viewport().gui_get_focus_owner()


## 一格「有档」的槽位元数据（list_slots 返回契约镜像）。
func slot_meta(slot_type: int, slot_id: int, realm: String = "炼气期") -> Dictionary:
	return {
		"slot_type": slot_type, "slot_id": slot_id, "exists": true,
		"name": "测试档", "timestamp": "2026-11-16T00:00:00",
		"realm": realm, "playtime": 3600,
	}


## 合成一次 ESC 按下事件（暂停中引擎只派发给 ALWAYS 节点）。
func esc_event() -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	event.echo = false
	return event


## 只读卡组查看面板（未打开过时为 null——不触发建树）。
func deck_view() -> Control:
	return menu.get_deck_host().view()


## 菜单里某个按钮（名称取自 PauseMenu.tscn 的 [code]Panel/VBox[/code] 树序）。
func menu_button(button_name: String) -> Button:
	return menu.get_node("Panel/VBox/" + button_name) as Button


## 装一台战斗替身并注入菜单（返回替身本身——断言 [member MockCombat.retreat_calls]）。
func attach_combat() -> MockCombat:
	var combat: MockCombat = MockCombat.new()
	add_child(combat)
	_extras.append(combat)
	menu.combat_system = combat
	return combat


## 装一套卡组查看依赖（卡组 + 模板）并注入菜单。[br]
## [br][param p_cards] 实例 ID → [CardTemplate] 的映射。
func attach_deck(p_cards: Dictionary) -> MockDeck:
	var deck: MockDeck = MockDeck.new()
	var cards: MockCards = MockCards.new()
	deck.cards = p_cards.keys()
	cards.templates = p_cards
	add_child(deck)
	add_child(cards)
	_extras.append(deck)
	_extras.append(cards)
	menu.deck_system = deck
	menu.card_system = cards
	return deck


## 造一张卡牌模板（行文案读它的字段——见 [MockCards] 的注记）。
func make_template(p_name: String, p_rarity: int = 1, p_cost: int = 1,
		p_type: int = 0) -> CardTemplate:
	var template: CardTemplate = CardTemplate.new()
	template.name = p_name
	template.rarity = p_rarity
	template.cost = p_cost
	template.type = p_type
	return template
