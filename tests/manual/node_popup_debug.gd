extends Control
## node_popup_debug —— 节点交互弹窗视觉手动验证 debug 宿主（Story 006）。
##
## F6 运行本场景：以桩节点图 + 桩依赖挂载 [NodeInteractionPopupHost]，按 1-6 打开
## 五类弹窗、按 0 关闭、按 T 切换渡劫台修为圆满、按 M 切换 reduce_motion，
## 供人工截图、帧率抽查与走查——生产代码零改动。
##
## 验证剧本（对应 `production/qa/evidence/node-popups-evidence.md` §2 八项）：
##   [1] 战斗弹窗  [2] 商店  [3] 灵泉  [4] 回复点  [5] 渡劫台（80% 警示）
##   [6] 精英战斗  [0] 关闭  [T] 渡劫台修为圆满/未满  [M] reduce_motion
##
## 来源: exploration-ui Story 006 Test Evidence（UI 证据文档 §2）、
## tests/manual/deploy_panel_debug.gd 先例（TD-006）。

const HostScript := preload("res://src/ui/exploration/node_interaction_popup_host.gd")
const DATA_STUB := preload("res://src/ui/exploration/node_graph_data_stub.gd")
const SceneManagerScript := preload("res://src/foundation/scene_manager.gd")
const RealmSystemScript := preload("res://src/core/realm_system.gd")

## 弹窗锚点节点（renderer 桩坐标源）。
const ANCHOR_NODE_ID: int = 201

## 弹窗宿主。
var host: Control = null
## 视口桩（冻结/缩放面——真实 NodeGraphViewport 由节点图场景提供）。
var viewport: Control = null
## 渲染器桩（get_node_position 坐标源）。
var renderer: Control = null
## 渡劫台是否修为圆满（T 切换）。
var tribulation_ready: bool = true
## reduce_motion（M 切换）。
var reduce_motion: bool = false


func _ready() -> void:
	name = "NodePopupDebug"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_stubs()
	host = HostScript.new()
	host.name = "NodeInteractionPopupHost"
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(host)
	host.setup(renderer, viewport, _make_system(), _make_scene_manager(),
			_make_realm_system())
	host.set_reduce_motion(reduce_motion)
	host.apply_snapshot(_make_snapshot())
	host.popup_opened.connect(func(nid: int, kind: StringName) -> void:
		print("[popup_debug] 打开 %s（节点 %d）" % [kind, nid]))
	host.popup_closed.connect(func(nid: int, kind: StringName) -> void:
		print("[popup_debug] 关闭 %s（节点 %d）" % [kind, nid]))
	host.spring_used.connect(func(nid: int, restored: int) -> void:
		print("[popup_debug] 灵泉 节点%d 回复 %d 点（桩值）" % [nid, restored]))
	host.rest_used.connect(func(nid: int, healed: int) -> void:
		print("[popup_debug] 回复点 节点%d 治疗 %d 点（桩值）" % [nid, healed]))
	_print_instructions()


## 视口/渲染器桩——只用被宿主读写的字段与方法。
func _build_stubs() -> void:
	viewport = Control.new()
	viewport.name = "ViewportStub"
	viewport.set_script(_viewport_stub_script())
	viewport.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(viewport)
	renderer = Control.new()
	renderer.name = "RendererStub"
	renderer.set_script(_renderer_stub_script())
	renderer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(renderer)


func _viewport_stub_script() -> GDScript:
	var script := GDScript.new()
	script.source_code = """
extends Control
var input_frozen: bool = false
var zoom: float = 1.0
var offset: Vector2 = Vector2.ZERO
"""
	script.reload()
	return script


func _renderer_stub_script() -> GDScript:
	var script := GDScript.new()
	script.source_code = """
extends Control
## 桩坐标——锚点节点落在屏幕中偏左，便于观察「右下方弹出」与边缘翻转。
func get_node_position(node_id: int) -> Vector2:
	return Vector2(760.0 + float(node_id % 100) * 40.0, 420.0)
"""
	script.reload()
	return script


## 探索系统桩——灵泉/回复返回可辨识的固定值（走查时看得到数值来源）。
func _make_system() -> Node:
	var stub: Node = Node.new()
	stub.name = "SystemStub"
	stub.set_script(_system_stub_script())
	add_child(stub)
	return stub


func _system_stub_script() -> GDScript:
	var script := GDScript.new()
	script.source_code = """
extends Node
func use_action_spring(_node_id: int) -> int:
	return 3
func rest_at_node(_node_id: int) -> int:
	return 11
"""
	script.reload()
	return script


## 场景管理器桩——只记录请求并打印（不真实转场，便于连续走查）。
func _make_scene_manager() -> Node:
	var stub: Node = Node.new()
	stub.name = "SceneManagerStub"
	stub.set_script(_scene_stub_script())
	add_child(stub)
	return stub


func _scene_stub_script() -> GDScript:
	var script := GDScript.new()
	script.source_code = """
extends Node
func request_scene_change(from_scene: int, to_scene: int, transition_type: int) -> bool:
	print("[popup_debug] 转场请求 %d → %d（类型 %d）" % [from_scene, to_scene, transition_type])
	return true
"""
	script.reload()
	return script


## 境界系统桩——炼气期上限 2（推荐上场角色数按上限夹取）。
func _make_realm_system() -> Node:
	var stub: Node = Node.new()
	stub.name = "RealmSystemStub"
	stub.set_script(_realm_stub_script())
	add_child(stub)
	return stub


func _realm_stub_script() -> GDScript:
	var script := GDScript.new()
	script.source_code = """
extends Node
func get_realm_property(level: int, key: StringName) -> Variant:
	if key == &"max_deploy":
		return 2 if level <= 1 else 6
	return null
"""
	script.reload()
	return script


## 渲染快照——stub 节点表 + 当前节点 + 渡劫台可控判定位。
func _make_snapshot() -> Dictionary:
	var nodes: Dictionary = DATA_STUB.stub_node_details()
	nodes[401] = {
		"type": 9, "layer": 4, "idx": 0, "label": "渡劫台",
		"description": "雷云汇聚", "enemy_detail": "",
		"tribulation_ready": tribulation_ready,
	}
	return {
		"graph": DATA_STUB.stub_graph(),
		"nodes": nodes,
		"visited": [ANCHOR_NODE_ID] as Array,
		"current_node": ANCHOR_NODE_ID,
		"ap_remaining": 3,
		"realm_id": 1,
	}


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_1: _open_combat(&"combat")
		KEY_2: _open_shop()
		KEY_3: _open_interaction(203, &"action_spring")
		KEY_4: _open_interaction(303, &"rest")
		KEY_5: _open_interaction(401, &"tribulation")
		KEY_6: _open_combat(&"elite")
		KEY_0: host.close_popup()
		KEY_T: _toggle_tribulation()
		KEY_M: _toggle_reduce_motion()


func _open_combat(combat_type: StringName) -> void:
	host.on_combat_arrival([
		{"name": "青云剑宗外门弟子", "realm": 1},
		{"name": "青云剑宗外门弟子", "realm": 1},
	], combat_type)


func _open_shop() -> void:
	host.on_node_interaction(201, &"shop", {"inventory": {"goods": [1, 2, 3]}})


func _open_interaction(node_id: int, interaction_type: StringName) -> void:
	host.on_node_interaction(node_id, interaction_type, {})


## 切换渡劫台修为圆满——未满时按 5 应「无弹窗」（AC-7）。
func _toggle_tribulation() -> void:
	tribulation_ready = not tribulation_ready
	host.apply_snapshot(_make_snapshot())
	print("[popup_debug] 渡劫台修为%s" % ("已满（可弹窗）" if tribulation_ready else "未满（无弹窗）"))


func _toggle_reduce_motion() -> void:
	reduce_motion = not reduce_motion
	host.set_reduce_motion(reduce_motion)
	print("[popup_debug] reduce_motion = %s" % str(reduce_motion))


func _print_instructions() -> void:
	print("=== node_popup_debug ===")
	print("1 战斗  2 商店  3 灵泉  4 回复点  5 渡劫台  6 精英战斗  0 关闭")
	print("T 切换渡劫台修为圆满  M 切换 reduce_motion")
	print("走查清单见 production/qa/evidence/node-popups-evidence.md §2（八项，含 A8 帧率抽查）")
	print("桩数据：境界上限 %d，SceneManager=%s" % [
			int((RealmSystemScript.realm_table.get(1, {}) as Dictionary).get("max_deploy", 1)),
			str(SceneManagerScript.SceneID.TRIBULATION)])
