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


## SceneManager 替身——记录转场请求（真转场会换掉测试进程的主场景）。
class MockSceneManager:
	extends Node

	var change_calls: Array = []

	func get_current_scene_id() -> int:
		return SM.SceneID.EXPLORATION  # 暂停菜单的典型调用场景

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


var menu: Control = null
var sl: MockSaveLoad = null
var sm: MockSceneManager = null
var gsm: MockGsm = null
var adapter: MockAudioAdapter = null


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
