extends GutTest
## exploration-ui Story 006 集成测试：节点交互弹窗宿主（分发表 → 弹窗 → 确认派发）。
##
## [b]覆盖[/b]（story Test Evidence 要求路径）：[br]
##   - AC-1 分发表路由：五类节点各自打开对应弹窗，且同时只存在一个弹窗实例
##   - AC-1/AC-9/AC-10：事件节点与传送节点不产生任何探索 UI 弹窗（防双面板）
##   - AC-2：战斗弹窗内容（敌人名称/数量/境界/推荐上场角色）+ 确认派发进入战斗
##   - AC-3：取消/ESC → 关闭 + 停留该节点 + 无场景切换
##   - AC-4/AC-5：灵泉/回复点确认调用系统 API 并回传系统返回值（UI 零数值计算）
##   - AC-6：渡劫台 80% 朱砂红警示 + 挑战派发 SceneManager TRIBULATION（非 Boss 50%）
##   - AC-7：渡劫台修为未满 → 无弹窗
##   - AC-8：商店确认发 shop_opened（UI overlay，非场景切换）
##   - AC-11：弹窗期间节点图冻结（缩放/平移/点击无效）+ 背景模糊遮罩可见
##
## 桩依赖见 `mocks/mock_popup_deps.gd`。
##
## 来源: story-006-node-interaction-popups.md QA Test Cases AC-1/AC-2，
## design/gdd/exploration-ui-system.md §4/§4b/§4c/§5。

const HostScript := preload("res://src/ui/exploration/node_interaction_popup_host.gd")
const Rules := preload("res://src/ui/exploration/node_interaction_rules.gd")
const MockDeps := preload("res://tests/integration/exploration_ui/mocks/mock_popup_deps.gd")
const SceneManagerScript := preload("res://src/foundation/scene_manager.gd")

var host: Control = null
var deps: Node = null
var viewport: Control = null
var renderer: Control = null


func before_each() -> void:
	deps = MockDeps.new()
	add_child_autofree(deps)
	# 视口桩：暴露 input_frozen/zoom/offset 三个字段（宿主读写面）
	viewport = Control.new()
	viewport.name = "ViewportStub"
	viewport.set_script(_viewport_stub_script())
	viewport.mouse_filter = Control.MOUSE_FILTER_STOP
	viewport.size = Vector2(1920, 1080)
	add_child_autofree(viewport)
	renderer = Control.new()
	renderer.name = "RendererStub"
	renderer.mouse_filter = Control.MOUSE_FILTER_STOP
	renderer.set_script(_renderer_stub_script())
	viewport.add_child(renderer)
	host = HostScript.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child_autofree(host)
	host.size = Vector2(1920, 1080)
	host.setup(renderer, viewport, deps, deps, deps)
	host.set_reduce_motion(true)


## 视口桩——NodeGraphViewport 的冻结/变换三字段（宿主只读写这三项）。
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
func get_node_position(node_id: int) -> Vector2:
	return Vector2(100.0 + float(node_id % 100) * 60.0, 120.0 + float(node_id / 100) * 70.0)
"""
	script.reload()
	return script


## 屏幕层快照注入（渡劫台 AC-7 判定源）。
func _inject_snapshot(nodes: Dictionary) -> void:
	host.apply_snapshot({"nodes": nodes, "current_node": 100})


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1：分发表路由
# ═══════════════════════════════════════════════════════════════════════════════

func test_shop_interaction_opens_shop_popup() -> void:
	host.on_node_interaction(201, &"shop", {"inventory": {}})
	assert_true(host.is_popup_open(), "商店节点应打开弹窗")
	assert_eq(host.get_open_kind(), Rules.KIND_SHOP, "弹窗种类应为商店")


func test_spring_interaction_opens_spring_popup() -> void:
	host.on_node_interaction(203, &"action_spring")
	assert_eq(host.get_open_kind(), Rules.KIND_SPRING, "灵泉节点应打开灵泉弹窗")


func test_rest_interaction_opens_rest_popup() -> void:
	host.on_node_interaction(303, &"rest")
	assert_eq(host.get_open_kind(), Rules.KIND_REST, "回复点应打开回复弹窗")


func test_tribulation_interaction_opens_tribulation_popup() -> void:
	_inject_snapshot({401: {"type": 9, "tribulation_ready": true}})
	host.on_node_interaction(401, &"tribulation")
	assert_eq(host.get_open_kind(), Rules.KIND_TRIBULATION, "渡劫台应打开渡劫弹窗")


func test_combat_arrival_opens_combat_popup() -> void:
	host.on_combat_arrival([{"name": "外门弟子", "realm": 1}], &"combat")
	assert_eq(host.get_open_kind(), Rules.KIND_COMBAT, "战斗到达应打开战斗弹窗")


func test_repeat_arrival_replaces_popup_without_duplicates() -> void:
	# 仅一个弹窗实例：连续两次到达后子节点中仍只有一个弹窗
	host.on_node_interaction(201, &"shop")
	host.on_node_interaction(203, &"action_spring")
	var count: int = 0
	for child: Node in host.get_children():
		if child is Control and (child as Control).name == "NodeInteractionPopup":
			count += 1
	assert_eq(count, 1, "同时只应存在一个弹窗实例")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1 / AC-9 / AC-10：显式排除
# ═══════════════════════════════════════════════════════════════════════════════

func test_event_node_produces_no_ui_popup() -> void:
	# AC-9：事件节点由 EventSystem 面板接管——探索 UI 不得弹窗（防双面板）
	host.on_node_interaction(102, &"event", {"event_pool": []})
	assert_false(host.is_popup_open(), "事件节点不得打开探索 UI 弹窗")
	assert_eq(host.get_open_kind(), Rules.KIND_NONE, "弹窗种类应保持空")


func test_teleport_node_produces_no_ui_popup() -> void:
	# AC-10 / B5：传送机制未闭合，按普通节点渲染，无任何交互
	host.on_node_interaction(402, &"teleport")
	assert_false(host.is_popup_open(), "传送节点不得打开任何弹窗")


func test_unknown_interaction_type_produces_no_popup() -> void:
	host.on_node_interaction(999, &"mystery")
	assert_false(host.is_popup_open(), "未知类型不得弹窗")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-2：战斗弹窗内容 + 进入战斗
# ═══════════════════════════════════════════════════════════════════════════════

func test_combat_popup_shows_enemy_name_count_realm_and_recommendation() -> void:
	var roster: Array = [
		{"name": "青云剑宗外门弟子", "realm": 1},
		{"name": "青云剑宗外门弟子", "realm": 1},
	]
	host.on_combat_arrival(roster, &"combat")
	var body: String = _body_text()
	assert_true(body.contains("青云剑宗外门弟子"), "正文应含敌人名称")
	assert_true(body.contains("×2"), "正文应含敌人数量")
	assert_true(body.contains("炼气期"), "正文应含境界")
	assert_true(body.contains("推荐上场角色"), "正文应含推荐战力（角色数版本）")


func test_combat_confirm_requests_combat_scene_change_once() -> void:
	host.on_combat_arrival([{"name": "敌", "realm": 1}], &"combat")
	var entries: Array = []
	var transitions: Array = []
	host.combat_entry_requested.connect(
			func(ctype: StringName) -> void: entries.append(ctype))
	# Act: 点击确认按钮（真实信号路径，不直调私有方法）
	_confirm_button().pressed.emit()
	# Assert
	assert_eq(entries.size(), 1, "应发一次战斗进入意图")
	assert_eq(entries[0], &"combat", "战斗类型应透传")
	assert_eq(deps.scene_changes.size(), 1, "应调用一次 SceneManager 转场")
	assert_eq(deps.scene_changes[0]["to"], SceneManagerScript.SceneID.COMBAT,
			"目标场景应为 COMBAT")
	assert_eq(deps.scene_changes[0]["type"],
			SceneManagerScript.TransitionType.EXPLORE_TO_COMBAT,
			"转场类型应为 EXPLORE_TO_COMBAT")
	assert_false(host.is_popup_open(), "确认后弹窗应关闭")


func test_elite_arrival_preserves_elite_combat_type() -> void:
	host.on_combat_arrival([{"name": "精英", "realm": 2}], &"elite")
	var entries: Array = []
	host.combat_entry_requested.connect(func(ctype: StringName) -> void: entries.append(ctype))
	_confirm_button().pressed.emit()
	assert_eq(entries[0], &"elite", "精英战斗类型应透传（不被压平为 combat）")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-3：取消路径（停留节点、AP 不回退、无场景切换）
# ═══════════════════════════════════════════════════════════════════════════════

func test_cancel_closes_popup_without_scene_change() -> void:
	host.on_combat_arrival([{"name": "敌", "realm": 1}], &"combat")
	var closed: Array = []
	host.popup_closed.connect(func(nid: int, kind: StringName) -> void: closed.append(kind))
	# Act: 点击「先等等」
	_cancel_button().pressed.emit()
	# Assert
	assert_false(host.is_popup_open(), "取消后弹窗应关闭")
	assert_eq(closed.size(), 1, "应发一次关闭通知")
	assert_eq(closed[0], Rules.KIND_COMBAT, "关闭通知应带弹窗种类")
	assert_eq(deps.scene_changes.size(), 0, "取消不得触发任何场景切换")


func test_escape_closes_popup() -> void:
	# AC-2 Edge：ESC 等效「先等等」
	host.on_node_interaction(301, &"shop", {"inventory": {}})
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_ESCAPE
	host._unhandled_key_input(event)
	assert_false(host.is_popup_open(), "ESC 应关闭弹窗")


func test_double_close_emits_closed_once() -> void:
	# 关闭动画期间弹窗仍 visible——重复调用 close_popup 不得重复发 popup_closed
	# （屏幕层据此恢复键盘路径，重复发会打乱冻结/恢复配对）。
	# 必须关掉 reduce_motion，否则关闭是直跳终态、走不到「仍在动画中」的窗口期。
	host.set_reduce_motion(false)
	host.on_node_interaction(201, &"shop")
	var closed: Array = []
	host.popup_closed.connect(func(nid: int, kind: StringName) -> void:
		closed.append([nid, kind]))
	host.close_popup()
	host.close_popup()
	assert_eq(closed.size(), 1, "重复关闭应只发一次 popup_closed")


func test_reopening_after_close_restores_open_state() -> void:
	# 关闭后再次到达应正常打开（_open_kind 复位不影响后续开窗）
	host.on_node_interaction(201, &"shop")
	host.close_popup()
	host.on_node_interaction(203, &"action_spring")
	assert_true(host.is_popup_open(), "关闭后再次到达应重新打开弹窗")
	assert_eq(host.get_open_kind(), Rules.KIND_SPRING, "种类应为新到达的灵泉")


func test_cancel_button_label_matches_wireframe() -> void:
	host.on_node_interaction(301, &"shop")
	assert_eq(_cancel_button().text, "离开", "商店弹窗取消按钮应为「离开」")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-4：灵泉（系统 API 返回值驱动，UI 不计算）
# ═══════════════════════════════════════════════════════════════════════════════

func test_spring_confirm_calls_system_api_and_reports_restored() -> void:
	deps.spring_restore_result = 7
	host.on_node_interaction(203, &"action_spring")
	var used: Array = []
	host.spring_used.connect(func(nid: int, restored: int) -> void:
		used.append([nid, restored]))
	_confirm_button().pressed.emit()
	assert_eq(deps.spring_calls, 1, "应调用一次探索系统灵泉 API")
	assert_eq(used.size(), 1, "应发一次 spring_used")
	assert_eq(int(used[0][1]), 7, "回复量应取系统返回值（UI 不自行计算）")
	assert_eq(int(used[0][0]), 203, "节点 ID 应透传")


func test_spring_without_system_api_reports_zero_and_warns() -> void:
	# Feature 层 API 未实现（story Out of Scope）——退化为 0 并留告警。
	# 用无方法节点替换探索系统接缝（真实缺失方法，不靠 has_method 覆盖）。
	var bare: Node = Node.new()
	bare.name = "BareSystem"
	add_child_autofree(bare)
	host.exploration_system = bare
	host.on_node_interaction(203, &"action_spring")
	var used: Array = []
	host.spring_used.connect(func(_nid: int, restored: int) -> void:
		used.append(restored))
	_confirm_button().pressed.emit()
	assert_eq(int(used[0]), 0, "API 缺失时回复量应为 0")
	assert_push_warning("探索系统缺少 use_action_spring()")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-5：回复点（全队回复 50% 已损失 HP——数值来自系统）
# ═══════════════════════════════════════════════════════════════════════════════

func test_rest_confirm_calls_system_api_and_reports_healed() -> void:
	deps.rest_heal_result = 11
	host.on_node_interaction(303, &"rest")
	var used: Array = []
	host.rest_used.connect(func(nid: int, healed: int) -> void: used.append([nid, healed]))
	_confirm_button().pressed.emit()
	assert_eq(deps.rest_calls, 1, "应调用一次探索系统回复 API")
	assert_eq(int(used[0][1]), 11, "治疗量应取系统返回值")
	assert_eq(int(used[0][0]), 303, "节点 ID 应透传")


func test_rest_popup_body_states_fifty_percent_lost_hp() -> void:
	host.on_node_interaction(303, &"rest")
	assert_true(_body_text().contains("50%已损失HP"), "正文应声明 50% 已损失 HP")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-6 / AC-7：渡劫台
# ═══════════════════════════════════════════════════════════════════════════════

func test_tribulation_popup_warns_eighty_percent_in_cinnabar() -> void:
	_inject_snapshot({401: {"type": 9, "tribulation_ready": true}})
	host.on_node_interaction(401, &"tribulation")
	var warning: Label = host.get_node(
			NodePath("NodeInteractionPopup/Warning")) as Label
	assert_not_null(warning, "渡劫弹窗应有警示行")
	assert_true(warning.visible, "警示行应可见")
	var lines: PackedStringArray = warning.text.split("\n")
	assert_true(str(lines[0]).contains("80%"), "警示首行必须写明 80% 修为损失")
	assert_false(str(lines[0]).contains("50%"),
			"警示首行不得是 Boss 的 50% 文案（GDD §4b 渡劫专属）")
	# 对照注显式引用 50% 以强化「远严于普通战败」——这是 GDD 线框原文
	assert_true(str(lines[1]).contains("50%"), "对照注应显式对照 Boss 的 50%")
	assert_eq(warning.get_theme_color("font_color").to_html(false).to_upper(),
			"B3424A", "警示必须为朱砂红 #B3424A（渡劫专属）")


func test_tribulation_confirm_requests_tribulation_transition() -> void:
	_inject_snapshot({401: {"type": 9, "tribulation_ready": true}})
	host.on_node_interaction(401, &"tribulation")
	var requests: Array = []
	host.tribulation_requested.connect(func(nid: int) -> void: requests.append(nid))
	_confirm_button().pressed.emit()
	assert_eq(requests.size(), 1, "应发一次渡劫请求")
	assert_eq(deps.scene_changes.size(), 1, "应调用一次 SceneManager 转场")
	assert_eq(deps.scene_changes[0]["to"], SceneManagerScript.SceneID.TRIBULATION,
			"目标场景应为 TRIBULATION")
	assert_eq(deps.scene_changes[0]["type"],
			SceneManagerScript.TransitionType.TRIBULATION, "转场类型应为 TRIBULATION")


func test_tribulation_unready_shows_no_popup() -> void:
	# AC-7：修为未满 → 无弹窗（节点渲染层已显示「修为尚未圆满」）
	_inject_snapshot({401: {"type": 9, "tribulation_ready": false}})
	host.on_node_interaction(401, &"tribulation")
	assert_false(host.is_popup_open(), "修为未满时渡劫台不得弹窗")
	assert_eq(host.get_open_kind(), Rules.KIND_NONE, "弹窗种类应保持空")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-8：商店（UI overlay，非场景切换）
# ═══════════════════════════════════════════════════════════════════════════════

func test_shop_confirm_opens_overlay_without_scene_change() -> void:
	# B9 裁决：商店是 UI overlay——节点图冻结，场景不变
	host.on_node_interaction(201, &"shop", {"inventory": {"goods": [1, 2]}})
	var opened: Array = []
	host.shop_opened.connect(func(nid: int, inv: Dictionary) -> void:
		opened.append([nid, inv]))
	_confirm_button().pressed.emit()
	assert_eq(opened.size(), 1, "应发一次 shop_opened")
	assert_eq(int(opened[0][0]), 201, "节点 ID 应透传")
	assert_true((opened[0][1] as Dictionary).has("goods"), "库存载荷应透传")
	assert_eq(deps.scene_changes.size(), 0, "商店不得触发场景切换（B9 裁决）")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-11：节点图冻结 + 背景模糊
# ═══════════════════════════════════════════════════════════════════════════════

func test_popup_freezes_viewport_and_renderer_input() -> void:
	host.on_node_interaction(201, &"shop")
	assert_true(bool(viewport.get(&"input_frozen")), "弹窗期间视口应冻结缩放/平移")
	assert_eq(renderer.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"弹窗期间节点图不应接收点击")


func test_closing_popup_restores_input_state() -> void:
	host.on_node_interaction(201, &"shop")
	host.close_popup()
	assert_false(bool(viewport.get(&"input_frozen")), "关闭后应解冻视口")
	assert_eq(renderer.mouse_filter, Control.MOUSE_FILTER_STOP,
			"关闭后应恢复渲染器原鼠标过滤模式")


func test_repeat_arrival_then_close_still_unfreezes() -> void:
	# 连续到达（弹窗未关就换下一类）会二次冻结——若不幂等，第二次把「已冻结」
	# 当原件保存，关闭后视口永远解不开冻（节点图彻底锁死）。
	host.on_node_interaction(201, &"shop")
	host.on_node_interaction(203, &"action_spring")
	assert_true(bool(viewport.get(&"input_frozen")), "换弹窗期间应保持冻结")
	host.close_popup()
	assert_false(bool(viewport.get(&"input_frozen")),
			"连续到达后关闭仍应解冻视口（不得保存「已冻结」为原值）")
	assert_eq(renderer.mouse_filter, Control.MOUSE_FILTER_STOP,
			"渲染器鼠标过滤应恢复原始值")


func test_popup_shows_blur_mask_at_forty_percent() -> void:
	host.on_node_interaction(201, &"shop")
	var mask: Control = host.get_node(NodePath("PopupMask")) as Control
	assert_not_null(mask, "应存在背景模糊遮罩")
	assert_true(mask.visible, "弹窗期间遮罩应可见")
	var rect: ColorRect = mask.get_node(NodePath("BlurRect")) as ColorRect
	assert_not_null(rect, "遮罩应含模糊矩形")
	assert_almost_eq(float(rect.material.get_shader_parameter(&"blur_amount")),
			Rules.BLUR_AMOUNT, 0.001, "模糊强度应为 40%（GDD §4）")


func test_popup_is_positioned_near_node_not_centered_fullscreen() -> void:
	host.on_node_interaction(201, &"shop")
	var popup: Control = host.get_node(NodePath("NodeInteractionPopup")) as Control
	# 节点 201 → renderer stub 坐标 (160, 260)；弹窗应在节点附近而非屏幕正中
	var anchor: Vector2 = renderer.get_node_position(201)
	assert_true(popup.position.distance_to(anchor) < 400.0,
			"弹窗应定位在节点附近（不覆盖全屏）")
	assert_true(popup.size.x < host.size.x, "弹窗宽度应小于宿主")


# ═══════════════════════════════════════════════════════════════════════════════
# 内部辅助
# ═══════════════════════════════════════════════════════════════════════════════

func _body_text() -> String:
	var body: Label = host.get_node(NodePath("NodeInteractionPopup/Body")) as Label
	return body.text if body != null else ""


func _confirm_button() -> Button:
	return host.get_node(NodePath("NodeInteractionPopup/ConfirmButton")) as Button


func _cancel_button() -> Button:
	return host.get_node(NodePath("NodeInteractionPopup/CancelButton")) as Button
