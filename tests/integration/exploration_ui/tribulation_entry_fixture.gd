extends GutTest
## TribulationEntryFixture —— 「渡劫入口」两个入口（节点图 / 修炼室）用例的共享装置。[br]
## [br][b]为什么单独一处[/b]：用例文件要守 300 行软上限
## （.claude/docs/coding-standards.md），而「怎么把宿主/场景挂起来、怎么点、怎么读」与
## 「断言什么」是两件事——后者才是用例的职责（同 [code]one_run_battle_fixture.gd[/code]
## 的拆因）。[br]
## [br][b]文件前缀[/b]：不以 [code]test_[/code] 开头——只作基类被继承。[br]
## [br][b]两个替身，各有各的必要[/b]：[br]
##   · 导航桩——真转场会换场景并拆掉 GUT 的测试树，之后就再也断言不到画面；[br]
##   · 战斗桩——只记 [code]battle_start[/code] 的配置，免得无头环境里真起一场仗。
##     [b]状态闸本身不替[/b]：[code]start_tribulation_combat[/code] 是真实实现，
##     「状态必须是 PREPARING」这道闸正是本组用例要钉住的现场。[br]
## [br][b]真实系统不替[/b]：触发走真实 [code]TribulationSystem[/code]（真实状态机 +
## 真实 GSM）、进境走真实 [code]RealmSystem.realm_up[/code]、失败走真实扣修为——
## 替掉任何一段都只是把断言换成「我调了那个桩」。[br]
##
## 来源: design/gdd/tribulation-system.md §1/§2、ADR-0021 §trigger_tribulation /
## §start_tribulation_combat、ADR-0031 §2。

const HostScript := preload("res://src/ui/exploration/node_interaction_popup_host.gd")
const Rules := preload("res://src/ui/exploration/node_interaction_rules.gd")
const SceneManagerScript := preload("res://src/foundation/scene_manager.gd")
const TS_SCRIPT := preload("res://src/feature/tribulation_system.gd")
## 修炼室场景（两条入口对照的另半边）。
const CultivationScene := preload("res://src/feature/cultivation/cultivation_scene.tscn")
## 配置读取面（修为上限从配置取，不硬编码 1000）。
const TableScript := preload("res://src/feature/exploration/exploration_breakthrough_table.gd")

## 渡劫台节点 ID（layer 4 idx 0——与节点图 stub 的渡劫台同号）。
const TRIB_NODE: int = 401
## [code]CombatResult[/code] 取值——[b]引真实枚举[/b]（源:
## [code]src/feature/combat_system.gd[/code] 的 [code]CombatResult[/code]）。[br]
## [br][b]原先这里是硬写的 0/1[/b]：注解还写着「胜 0 / 败 1」——那正是
## [code]tribulation_combat.gd[/code] 旧缺陷（用字面量 0 判胜）的翻版，
## 曲线（真实枚举是 VICTORY=1 / DEFEAT=2）。缺陷已修，本组常量随之改为
## 引用枚举：用例与生产判据同源，分叉不了。
const CombatScript := preload("res://src/feature/combat_system.gd")
const COMBAT_VICTORY: int = CombatScript.CombatResult.VICTORY
const COMBAT_DEFEAT: int = CombatScript.CombatResult.DEFEAT
## AISystem 全局名册的借用—归还守卫（见 [member _ai_roster_before]）。
const AiRosterGuard := preload("res://tests/fixtures/ai_roster_guard.gd")


## 导航桩——记录转场请求，不真跳场景（[member accept] = false 时模拟并发守卫拒绝）。
class SceneManagerStub extends Node:
	var requests: Array = []
	var current_id: int = 3
	var accept: bool = true

	func get_current_scene_id() -> int:
		return current_id

	func request_scene_change(from: int, to: int, type: int) -> bool:
		requests.append({"from": from, "to": to, "type": type})
		return accept


## 战斗桩——只记配置（见文件头「两个替身」）。
class CombatStub extends Node:
	var configs: Array = []

	func battle_start(config: Dictionary) -> void:
		configs.append(config)


## 桩渡劫系统——有对象但没方法（两个入口都须按「不可用」处理，而不是点了没反应）。
class BareTribulation extends Node:
	pass


var sm: SceneManagerStub = null
var host: Control = null
var screen: Control = null
var _player_before: Dictionary = {}
## AISystem 全局名册的借用凭据——本组用例走真实开战闸，开战前置会把天劫雷灵
## 写进那个跨套件共享的 Autoload（见 [AiRosterGuard]）。
var _ai_roster_before: Array = []


func before_each() -> void:
	_player_before = (GameStateManager.player as Dictionary).duplicate(true)
	_ai_roster_before = AiRosterGuard.capture()
	_reset_player(1)
	sm = SceneManagerStub.new()
	add_child_autofree(sm)


func after_each() -> void:
	if host != null and is_instance_valid(host):
		host.queue_free()
	if screen != null and is_instance_valid(screen):
		screen.queue_free()
	host = null
	screen = null
	# 全局 Autoload 上的注入点必须还原——留着会漏进下一个用例。
	TribulationSystem.set("_combat_override", null)
	AiRosterGuard.restore(_ai_roster_before)
	GameStateManager.player = _player_before
	sm = null


# ═══════════════════════════════════════════════════════════════════════════════
# 装置
# ═══════════════════════════════════════════════════════════════════════════════

## 基准存档：指定境界、修为刚好攒满（渡劫触发的前提）、未在渡劫流程中。[br]
## [br][b]直接写 player 域而不是走 API[/b]：修为写入口只增不减，构造「恰好满」只能置位
## （同 [code]test_cultivation_tribulation_entry.gd[/code] 口径）。
func _reset_player(p_realm: int) -> void:
	var required: int = TableScript.required_cultivation(p_realm)
	var player: Dictionary = GameStateManager.player
	player["realm"] = p_realm
	player["cultivation"] = required
	player["max_cultivation"] = required
	player["cultivation_full"] = true
	player["overflow_pool"] = 0
	player["tribulation_state"] = TS_SCRIPT.TribulationState.NOT_READY
	player["consecutive_tribulation_failures"] = 0
	GameStateManager.set("_pending_changes", {})
	GameStateManager.set("_flush_scheduled", false)


## 挂载真实节点图弹窗宿主（真实渡劫系统；[param p_trib] 非空时替换成桩）。[br]
## [br][b]探索系统传 null[/b]：渡劫那条路只碰 SceneManager 与渡劫系统，
## 灵泉/回复的接缝在本组用例里到不了。
func mount_host(p_trib: Node = null) -> void:
	var viewport: Control = Control.new()
	viewport.name = "ViewportStub"
	viewport.set_script(_stub_script("var input_frozen: bool = false\nvar zoom: float = 1.0"))
	viewport.mouse_filter = Control.MOUSE_FILTER_STOP
	viewport.size = Vector2(1920, 1080)
	add_child_autofree(viewport)
	var renderer: Control = Control.new()
	renderer.name = "RendererStub"
	renderer.set_script(_stub_script(
			"func get_node_position(node_id: int) -> Vector2:\n\treturn Vector2(500.0, 400.0)"))
	renderer.mouse_filter = Control.MOUSE_FILTER_STOP
	viewport.add_child(renderer)
	host = HostScript.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child_autofree(host)
	host.call(&"setup", renderer, viewport, null, sm,
			get_node_or_null(NodePath("/root/RealmSystem")),
			p_trib if p_trib != null else TribulationSystem)
	host.call(&"set_reduce_motion", true)
	host.call(&"apply_snapshot", {"nodes": {TRIB_NODE: {
		"type": 9, "label": "渡劫台", "tribulation_ready": true,
	}}, "current_node": TRIB_NODE})


## 挂载修炼室场景（第二动作行走真实按钮路径——对照那半边）。
func mount_cultivation(p_trib: Node = null) -> void:
	var instance: Control = CultivationScene.instantiate() as Control
	instance.set("scene_manager", sm)
	if p_trib != null:
		instance.set("tribulation_system", p_trib)
	add_child_autofree(instance)
	screen = instance


## 匿名脚本（视口 / 渲染器桩——宿主只读写这两处字段）。
func _stub_script(p_body: String) -> GDScript:
	var script := GDScript.new()
	script.source_code = "extends Control\n" + p_body
	script.reload()
	return script


## 从节点图点渡劫台并确认（走弹窗的真实确认按钮，不经私有方法）。
func confirm_tribulation() -> void:
	host.call(&"on_node_interaction", TRIB_NODE, Rules.KIND_TRIBULATION)
	var button: Button = host.get_node(
			NodePath("NodeInteractionPopup/ConfirmButton")) as Button
	assert_not_null(button, "前置：渡劫台弹窗已开且带确认按钮")
	button.pressed.emit()


## 把渡劫战推起来（真实状态闸；[code]battle_start[/code] 用桩接）。
func start_combat() -> CombatStub:
	var combat := CombatStub.new()
	add_child_autofree(combat)
	TribulationSystem.set("_combat_override", combat)
	TribulationSystem.call(&"start_tribulation_combat")
	return combat


## 收集入口结果（[code]TribulationLaunch.OUTCOME_*[/code] 令牌 / 中文句）。
func watch_launch_results() -> Dictionary:
	var texts: Array = []
	var outcomes: Array = []
	if host != null and is_instance_valid(host):
		host.connect(&"tribulation_launch_resolved",
				func(outcome: StringName, text: String) -> void:
					outcomes.append(outcome)
					texts.append(text))
	return {"outcomes": outcomes, "texts": texts}


# ═══════════════════════════════════════════════════════════════════════════════
# 只读查询
# ═══════════════════════════════════════════════════════════════════════════════

func trib_state() -> int:
	return int(GameStateManager.player.tribulation_state)


func realm() -> int:
	return int(GameStateManager.player.realm)


func cultivation() -> int:
	return int(GameStateManager.player.cultivation)


## 记录到的渡劫转场请求（[code]{from, to, type}[/code]——非渡劫目标的请求滤掉）。
func tribulation_requests() -> Array:
	var out: Array = []
	for request: Dictionary in sm.requests:
		if int(request["to"]) == SceneManagerScript.SceneID.TRIBULATION:
			out.append(request)
	return out
