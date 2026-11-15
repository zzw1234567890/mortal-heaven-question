extends GutTest
## ExplorationExitFixture —— 探索退出闭环用例的共享夹具。[br]
## [br][b]为什么单独一处[/b]：用例文件要守在 300 行软上限内
## （.claude/docs/coding-standards.md），而「怎么进图、怎么按下退出」与「断言什么」
## 是两件事（同 [code]craft_node_fixture.gd[/code] 先例）。[br]
## [br][b]用法[/b]：子类 [code]extends "res://…/exploration_exit_fixture.gd"[/code]，
## 直接写 [code]test_*[/code] 方法即可；[code]before_each[/code] /
## [code]after_each[/code] 由本夹具提供，子类若要扩展需先 [code]super()[/code]。[br]
## [br][b]文件前缀[/b]：本文件不以 [code]test_[/code] 开头——GUT 按前缀收集，
## 因此它只作为基类被继承，不会被当作用例文件单独执行。[br]
## [br][b]用真实 Autoload[/b]：本组用例验证的正是生产接线（薄容器 → 系统 → GSM），
## 故不注入桩；探索系统经 [code]ExplorationBootstrap.mount[/code] 装配真实回调。[br]
## [br][b]隔离[/b]：GSM 的 exploration 域与 [code]player.resources[/code] 在
## [code]before_each[/code] 快照、[code]after_each[/code] 原样还原。
##
## 来源: design/gdd/exploration-system.md §5 结束条件 / §8 边界 + §AC 退回地图选择、
## ADR-0014 §决策 5 探索结束结算、ADR-0031 §2（UI 零状态所有权）。

const SceneScript := preload("res://src/feature/exploration/exploration_scene.gd")
const BootstrapScript := preload("res://src/feature/exploration/exploration_bootstrap.gd")

## 用例地图（真实生成——探明表里青云剑宗为炼气期地图）。
const MAP_ID: StringName = &"qing_yun_jian_zong"

## 本局收集的灵石数（断言全额保留）。
const COLLECTED_LING_SHI: int = 30

var gsm: Node = null
var es: Node = null
var scene: Control = null
var _exploration_before: Dictionary = {}
var _resources_before: Dictionary = {}
## 结算信号载荷（[code]exploration_ended[/code] 的 reason）。
var _ended_reasons: Array = []


func before_each() -> void:
	gsm = get_node_or_null(NodePath("/root/GameStateManager"))
	es = get_node_or_null(NodePath("/root/ExplorationSystem"))
	assert_not_null(es, "本文件需要真实 ExplorationSystem Autoload")
	_exploration_before = (GameStateManager.exploration as Dictionary).duplicate(true)
	_resources_before = (gsm.player.resources as Dictionary).duplicate(true)
	BootstrapScript.mount(es, get_node_or_null(NodePath("/root/AISystem")))
	if es.has_method(&"set_rng_seed"):
		es.call("set_rng_seed", 42)
	_ended_reasons.clear()
	if not es.exploration_ended.is_connected(_on_exploration_ended):
		es.exploration_ended.connect(_on_exploration_ended)
	_reset_gsm()
	scene = SceneScript.new()
	add_child_autofree(scene)


func after_each() -> void:
	if es != null and es.exploration_ended.is_connected(_on_exploration_ended):
		es.exploration_ended.disconnect(_on_exploration_ended)
	_reset_gsm()
	GameStateManager.exploration = _exploration_before
	gsm.player.resources = _resources_before
	if es != null and es.has_method(&"clear_dag_cache"):
		es.call("clear_dag_cache")


func _on_exploration_ended(reason: int, _summary: Dictionary) -> void:
	_ended_reasons.append(reason)


## 当前节点图（退出流程的断言焦点）。
func _graph() -> Control:
	return scene.get("node_graph_screen")


## 进真实地图（走薄容器的进入意图——节点图挂载 + enter_map 全链）。
func _enter_map() -> void:
	scene.call("_on_enter_map_requested", MAP_ID)
	assert_not_null(_graph(), "前置：节点图应已挂载")
	# 输入锁单独由 test_node_graph_status_bar.gd 覆盖；本组用例测的是结算接线，
	# 故显式放行，避免其他用例遗留的锁栈影响这条链路的断言。
	_graph().status_bar().set("input_allowed_cb", Callable(func() -> bool: return true))


## 当前节点图的退出按钮（真实 .tscn 节点路径）。
func _exit_button() -> Button:
	return _graph().get_node(NodePath("TopBar/ExitButton")) as Button


## 当前节点图的退出确认弹窗（真实 .tscn 节点路径）。
func _exit_dialog() -> ConfirmationDialog:
	return _graph().get_node(NodePath("ExitDialog")) as ConfirmationDialog


## 走完两步：按下退出 → 确认。
func _confirm_exit() -> void:
	_exit_button().pressed.emit()
	_exit_dialog().confirmed.emit()


## 重置 GSM 探索域（enter_map 会写 current_map / visited / ap / map_states）。
func _reset_gsm() -> void:
	if gsm == null:
		return
	gsm.exploration = {
		"current_map": &"",
		"node_position": {"layer": 0, "idx": 0},
		"visited_nodes": [],
		"action_points": 0,
		"max_action_points": 0,
		"map_states": {},
	}
	gsm.set("_signal_chain_depth", 0)
	var router: Variant = gsm.get("_signal_router")
	if router != null:
		router.set("_pending_changes", [])
