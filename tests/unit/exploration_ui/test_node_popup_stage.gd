extends GutTest
## NodePopupStage / NodePopupServices 单测（拆分后的两个组件）。[br]
## [br][b]覆盖[/b]：[br]
##   - 舞台：冻结幂等 / 解冻还原原值 / 弹窗定位夹入视口 / ESC 消费；[br]
##   - 服务面：灵泉与回复点缺 API 时返回 0 并告警、转场缺失时静默、
##     境界上限读 RealmSystem、渡劫判定默认宽松。[br]
##
## 来源: exploration-ui Story 006（AC-4/AC-5/AC-6/AC-7/AC-11）、
## 本轮「拆分 popup host 冻结/定位职责」任务。

const StageScript := preload("res://src/ui/exploration/node_popup_stage.gd")
const ServicesScript := preload("res://src/ui/exploration/node_popup_services.gd")
const Rules := preload("res://src/ui/exploration/node_interaction_rules.gd")

var host: Control = null
var viewport: Control = null
var renderer: Control = null
var stage: RefCounted = null


func before_each() -> void:
	host = Control.new()
	host.size = Vector2(1920, 1080)
	add_child_autofree(host)
	viewport = Control.new()
	viewport.set_script(_stub_script("""
extends Control
var input_frozen: bool = false
var zoom: float = 1.0
var offset: Vector2 = Vector2.ZERO
"""))
	viewport.size = Vector2(1920, 1080)
	host.add_child(viewport)
	renderer = Control.new()
	renderer.mouse_filter = Control.MOUSE_FILTER_STOP
	renderer.set_script(_stub_script("""
extends Control
func get_node_position(node_id: int) -> Vector2:
	return Vector2(100.0 + float(node_id % 100) * 60.0, 120.0 + float(node_id / 100) * 70.0)
"""))
	viewport.add_child(renderer)
	stage = StageScript.new()
	stage.call(&"bind", host, renderer, viewport)


# ═══════════════════════════════════════════════════════════════════════════════
# 冻结 / 解冻
# ═══════════════════════════════════════════════════════════════════════════════

func test_freeze_and_unfreeze_restore_original_values() -> void:
	# Arrange——视口原本已冻结（场景原值），renderer 为 STOP
	viewport.set(&"input_frozen", true)
	# Act
	stage.call(&"freeze")
	assert_true(bool(viewport.get(&"input_frozen")), "冻结期间视口保持冻结")
	assert_eq(renderer.mouse_filter, Control.MOUSE_FILTER_IGNORE, "冻结期间不接收点击")
	stage.call(&"unfreeze")
	# Assert——还原为冻结前的原值（true），不是硬编码 false
	assert_true(bool(viewport.get(&"input_frozen")), "解冻还原视口原值")
	assert_eq(renderer.mouse_filter, Control.MOUSE_FILTER_STOP, "解冻还原鼠标过滤")


func test_double_freeze_keeps_original_snapshot() -> void:
	# 连续到达会二次冻结——第二次不得把「已冻结」当原件保存
	stage.call(&"freeze")
	stage.call(&"freeze")
	stage.call(&"unfreeze")
	assert_false(bool(viewport.get(&"input_frozen")), "二次冻结后解冻仍回到 false")


func test_unfreeze_without_freeze_is_noop() -> void:
	renderer.mouse_filter = Control.MOUSE_FILTER_PASS
	stage.call(&"unfreeze")
	assert_eq(renderer.mouse_filter, Control.MOUSE_FILTER_PASS,
			"未冻结时解冻不得改写鼠标过滤")


# ═══════════════════════════════════════════════════════════════════════════════
# 定位
# ═══════════════════════════════════════════════════════════════════════════════

func test_place_near_node_applies_viewport_transform() -> void:
	var popup: Control = Control.new()
	host.add_child(popup)
	autofree(popup)
	viewport.set(&"zoom", 2.0)
	viewport.set(&"offset", Vector2(10, 20))
	stage.call(&"place", popup, 201)
	var world: Vector2 = renderer.get_node_position(201)
	var expected: Vector2 = Rules.popup_position(world * 2.0 + Vector2(10, 20),
			Rules.POPUP_SIZE, host.size)
	assert_eq(popup.position, expected, "定位应叠加视口缩放与平移")


func test_place_without_node_centers_offscreen_right() -> void:
	var popup: Control = Control.new()
	host.add_child(popup)
	autofree(popup)
	stage.call(&"place", popup, -1)
	var expected: Vector2 = Rules.popup_position(host.size * 0.5,
			Rules.POPUP_SIZE, host.size)
	assert_eq(popup.position, expected, "无节点锚点时居中偏右定位")
	assert_true(popup.position.x < host.size.x, "弹窗仍在视口内（不覆盖全屏）")


# ═══════════════════════════════════════════════════════════════════════════════
# ESC
# ═══════════════════════════════════════════════════════════════════════════════

func test_handle_escape_consumes_only_when_popup_open() -> void:
	var closed: Array = []
	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	# Act / Assert——无弹窗时不消费
	assert_false(bool(stage.call(&"handle_escape", escape,
			func() -> void: closed.append(true))), "无弹窗时不消费 ESC")
	assert_true(closed.is_empty(), "无弹窗时不应触发关闭")


# ═══════════════════════════════════════════════════════════════════════════════
# 服务面
# ═══════════════════════════════════════════════════════════════════════════════

func test_services_return_zero_when_system_missing() -> void:
	var services: RefCounted = ServicesScript.new()
	assert_eq(int(services.call(&"use_spring", null, 1)), 0, "探索系统缺失时回复量为 0")
	assert_eq(int(services.call(&"rest_party", null, 1)), 0, "探索系统缺失时治疗量为 0")


func test_services_forward_system_return_values() -> void:
	var stub: Node = Node.new()
	stub.set_script(_stub_script("""
extends Node
func use_action_spring(_node_id: int) -> int:
	return 7
func rest_at_node(_node_id: int) -> int:
	return 11
"""))
	add_child_autofree(stub)
	var services: RefCounted = ServicesScript.new()
	assert_eq(int(services.call(&"use_spring", stub, 1)), 7, "回复量取系统返回值")
	assert_eq(int(services.call(&"rest_party", stub, 1)), 11, "治疗量取系统返回值")


func test_services_request_scene_change_skips_when_missing() -> void:
	# 缺 SceneManager 时静默跳过——不崩、不改任何状态
	var services: RefCounted = ServicesScript.new()
	services.call(&"request_scene_change", null, 1, 0)
	pass_test("缺 SceneManager 时转场请求静默跳过")


func test_services_max_deploy_falls_back_to_realm_table() -> void:
	var services: RefCounted = ServicesScript.new()
	var expected: int = int((preload("res://src/core/realm_system.gd").realm_table
			.get(1, {}) as Dictionary).get("max_deploy", 1))
	assert_eq(int(services.call(&"max_deploy", null, 1, host)), expected,
			"RealmSystem 缺失时回退静态境界表")


func test_services_tribulation_ready_defaults_lenient() -> void:
	var services: RefCounted = ServicesScript.new()
	assert_true(bool(services.call(&"tribulation_ready",
			{"nodes": {401: {"type": 9}}}, 401)), "字段缺失时宽松视为圆满")
	assert_false(bool(services.call(&"tribulation_ready",
			{"nodes": {401: {"type": 9, "tribulation_ready": false}}}, 401)),
			"显式 false 判为未圆满")


func _stub_script(p_source: String) -> GDScript:
	var script := GDScript.new()
	script.source_code = p_source
	script.reload()
	return script
